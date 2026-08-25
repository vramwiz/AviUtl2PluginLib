unit BitmapCache;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.IOUtils,
  Vcl.Graphics, PNGImage, RTTIPersistentIni;

type
  // キャッシュ要素
  TBitmapCacheItem = class(TRTTIPersistentIni)
  private
    FUID          : string;
    FWidth        : Integer;
    FHeight       : Integer;
    FCacheFileName: string;   // ファイル名のみ
    FCreatedAt    : TDateTime;
  published
    property UID: string read FUID write FUID;
    property Width: Integer read FWidth write FWidth;
    property Height: Integer read FHeight write FHeight;
    property CacheFileName: string read FCacheFileName write FCacheFileName;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

  // キャッシュ管理
  TBitmapCache = class(TRTTIPersistentIniList<TBitmapCacheItem>)
  private
    FCacheFolder: string;
    FCacheVersion : Integer;
    FBusy : Boolean;

    function FindItem(const UID: string; W, H: Integer): Integer;
    function IsCacheReady: Boolean;
    function GenerateCacheFileName: string;

  protected
    procedure DoSaveSection(ItemSL : TStringList); override;
    procedure DoLoadSection(ItemSL : TStringList); override;
  public
    // キャッシュフォルダ設定
    procedure SetCacheFolder(const Folder: string);

    // Bitmap を PNG でキャッシュ化して登録
    function AddCache(const UID: string; W, H: Integer;Src: TBitmap): TBitmapCacheItem;

    function IsSameKey(Item: TBitmapCacheItem;const UID: string; W, H: Integer): Boolean;
    // キャッシュ取得
    function GetCache(const UID: string; W, H: Integer;Dest: TBitmap): Boolean;
    // 指定したキャッシュ削除
    function DeleteCacheItem(const UID: string; W : Integer = -1; H: Integer=-1): Boolean;
    // キャッシュ削除（フォルダ＋ini）
    procedure ClearCache;

    property CacheFolder : string write  SetCacheFolder;
    property CacheVersion : Integer read FCacheVersion write FCacheVersion;
  end;

implementation

const

  CACHE_VERSION = 3;

var
  GCacheFileCounter: Integer = 0;

{-------------------------------------------------------------------------------
  キャッシュフォルダの状態チェック
-------------------------------------------------------------------------------}
function TBitmapCache.IsCacheReady: Boolean;
begin
  Result :=
    (FCacheFolder <> '') and
    DirectoryExists(FCacheFolder);
end;

function TBitmapCache.IsSameKey(Item: TBitmapCacheItem;
  const UID: string; W, H: Integer): Boolean;
begin
  Result :=
    (Item.UID = UID) and
    (Item.Width = W) and
    (Item.Height = H);
end;

{-------------------------------------------------------------------------------
  キャッシュファイル名生成（日時＋内部カウンタ）
-------------------------------------------------------------------------------}
function TBitmapCache.GenerateCacheFileName: string;
begin
  Result :=
    FormatDateTime('yyyymmddhhnnsszzz', Now) + '_' +
    Format('%.4d', [GCacheFileCounter]) + '.png';
  Inc(GCacheFileCounter);
end;

{-------------------------------------------------------------------------------
  キャッシュフォルダ設定
-------------------------------------------------------------------------------}
procedure TBitmapCache.SetCacheFolder(const Folder: string);
begin
  FCacheFolder := Trim(Folder);

  // キャッシュフォルダが無効なら何もしない
  if not IsCacheReady then Exit;

  // キャッシュ管理INIのパス設定
  FileName := IncludeTrailingPathDelimiter(FCacheFolder) + 'ListViewCache.ini';

  // 既存キャッシュ情報を読み込み
  if FileExists(FileName) then
    LoadFromFile;

  // キャッシュバージョンが異なる場合は全キャッシュを無効化
  if FCacheVersion <> CACHE_VERSION then
  begin
    ClearCache;                     // PNGキャッシュとINIを削除
    FCacheVersion := CACHE_VERSION; // 新バージョンを記録
    SaveToFile;                     // 空状態で再保存
  end;
end;

{-------------------------------------------------------------------------------
  キャッシュアイテム検索（UID + Width + Height）
-------------------------------------------------------------------------------}
function TBitmapCache.FindItem(const UID: string; W, H: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Count - 1 do
  begin
    if (Items[i].UID = UID) and
       (Items[i].Width = W) and
       (Items[i].Height = H) then
      Exit(i);
  end;
end;

{-------------------------------------------------------------------------------
  キャッシュ登録（Bitmap → PNG）
-------------------------------------------------------------------------------}
function TBitmapCache.AddCache(const UID: string; W, H: Integer;
  Src: TBitmap): TBitmapCacheItem;
var
  Item: TBitmapCacheItem;
  PngPath: string;
  CacheName: string;
  png : TPngImage;
begin
  Result := nil;

  // キャッシュフォルダ無効 → 何もしない
  if not IsCacheReady then
    Exit;

  if FBusy then Exit;
  FBusy := True;
  DeleteCacheItem(UID,W,H);
  CacheName := GenerateCacheFileName;
  PngPath := IncludeTrailingPathDelimiter(FCacheFolder) + CacheName;

  // Bitmap → PNG 保存
  Png := TPngImage.Create;
  try
    Png.Assign(Src);
    Png.SaveToFile(PngPath);
  finally
    Png.Free;
  end;

  // INI 登録
  Item := AddNew();
  Item.UID := UID;
  Item.Width := W;
  Item.Height := H;
  Item.CacheFileName := CacheName;  // ファイル名のみ保持
  Item.CreatedAt := Now;

  SaveToFile;

  Result := Item;
  FBusy := False;

end;

{-------------------------------------------------------------------------------
  キャッシュ取得（PNG → Bitmap）
-------------------------------------------------------------------------------}
function TBitmapCache.GetCache(const UID: string; W, H: Integer;
  Dest: TBitmap): Boolean;
var
  Idx: Integer;
  PngPath: string;
  Png: TPngImage;
  Stream: TFileStream;
begin
  Result := False;

  if not IsCacheReady then
    Exit;

  Idx := FindItem(UID, W, H);
  if Idx = -1 then
    Exit;

  PngPath := IncludeTrailingPathDelimiter(FCacheFolder) +
             Items[Idx].CacheFileName;

  if not FileExists(PngPath) then begin
    DeleteCacheItem(UID,W,H);
    Exit;
  end;

  Png := TPngImage.Create;
  Stream := nil;
  try
    try
      Stream := TFileStream.Create(PngPath, fmOpenRead or fmShareDenyWrite);
      Png.LoadFromStream(Stream);
      Dest.Assign(Png);
      Result := True;
    except
      DeleteCacheItem(UID,W,H);
      Result := False;
    end;
  finally
    Stream.Free;
    Png.Free;
  end;
end;


{-------------------------------------------------------------------------------
  キャッシュ完全削除
-------------------------------------------------------------------------------}
procedure TBitmapCache.ClearCache;
var
  Files: TStringDynArray;
  F: string;
begin
  if not IsCacheReady then
    Exit;

  // PNG 全削除
  Files := TDirectory.GetFiles(FCacheFolder, '*.png');
  for F in Files do
    TFile.Delete(F);

  // INI 削除
  if FileExists(FileName) then
    DeleteFile(FileName);

  // メモリ上のリストもクリア
  Clear;
end;

function TBitmapCache.DeleteCacheItem(const UID: string;  W : Integer = -1; H: Integer=-1): Boolean;
var
  i: Integer;
  Item: TBitmapCacheItem;
  Path: string;
  Deleted: Boolean;
begin
  Result := False;

  if not IsCacheReady then
    Exit;

  Deleted := False;

  // 逆順に走査して削除（安全）
  for i := Count - 1 downto 0 do  begin
    Item := Items[i];
    if H = -1 then begin                                 // UIDだけ一致で消す指定の場合
      if Item.FUID <> UID then continue;                 // UIDだけで判定
    end
    else begin
      // UID / Width / Height が一致するものを削除       // 通常の場合
      if not IsSameKey(Item, UID, W, H) then continue;   // UID とサイズが一致した場合のみ削除
    end;
    // PNG 削除
    Path := IncludeTrailingPathDelimiter(FCacheFolder) +
            Item.CacheFileName;

    if FileExists(Path) then
      TFile.Delete(Path);

    // INI 要素を削除
    Delete(i);

    Deleted := True;
  end;

  if Deleted then
    SaveToFile;

  Result := Deleted;
end;

procedure TBitmapCache.DoLoadSection(ItemSL: TStringList);
var
  i: Integer;
  Key, Val: string;
begin
  for i := 0 to ItemSL.Count - 1 do
  begin
    Key := ItemSL.Names[i];
    Val := ItemSL.ValueFromIndex[i];

    if SameText(Key,'CacheVersion') then
      FCacheVersion := StrToIntDef(Val,0);
  end;
end;

procedure TBitmapCache.DoSaveSection(ItemSL: TStringList);
begin
  ItemSL.Add('CacheVersion=' + IntToStr(FCacheVersion));
end;

end.

