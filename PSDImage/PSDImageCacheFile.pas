unit PSDImageCacheFile;

interface

uses
  System.SysUtils, Winapi.Windows,
  System.Classes,
  System.Generics.Collections,
  PSDImageAviUtl2; // TPSDImageAviUtl2

type
  {------------------------------------------------------------
    PSDファイルキャッシュ要素（1ファイル）
  ------------------------------------------------------------}
  TPSDImageCacheFileItem = class
  private
    FFileName : string;
    FPsd      : TPSDImageAviUtl2;
  public
    constructor Create(const AFileName: string; APsd: TPSDImageAviUtl2);
    destructor Destroy; override;

    property FileName : string           read FFileName;
    property Psd      : TPSDImageAviUtl2 read FPsd;
  end;

  {------------------------------------------------------------
    PSDファイルキャッシュリスト
  ------------------------------------------------------------}
  TPSDImageCacheFileList = class(TObjectList<TPSDImageCacheFileItem>)
  public
    constructor Create;
    destructor Destroy; override;

    function FindByFileName(const FileName: string): TPSDImageCacheFileItem;
    function GetOrCreate(const FileName: string): TPSDImageAviUtl2;
  end;

{--------------------------------------------------------------
  グローバルキャッシュ実体
--------------------------------------------------------------}
var
  GPSDImageCacheFiles : TPSDImageCacheFileList;

{--------------------------------------------------------------
  グローバルキャッシュ管理関数
--------------------------------------------------------------}
//procedure InitializePSDImageCacheFiles;
//procedure FinalizePSDImageCacheFiles;

implementation

{$IFDEF DEBUG}
uses
  PSDImageDebugLog;

var
  GPSDCachePerfFreq: Int64 = 0;

function PSDCachePerfNow: Int64;
begin
  if GPSDCachePerfFreq = 0 then
    QueryPerformanceFrequency(GPSDCachePerfFreq);
  QueryPerformanceCounter(Result);
end;

function PSDCachePerfMs(const AStart, AEnd: Int64): Double;
begin
  if GPSDCachePerfFreq = 0 then
    Result := 0
  else
    Result := (AEnd - AStart) * 1000 / GPSDCachePerfFreq;
end;
{$ENDIF}

{ TPSDImageCacheFileItem }

constructor TPSDImageCacheFileItem.Create(const AFileName: string;
  APsd: TPSDImageAviUtl2);
begin
  inherited Create;
  FFileName := AFileName;
  FPsd      := APsd;
end;

destructor TPSDImageCacheFileItem.Destroy;
begin
  FPsd.Free;
  FPsd := nil;
  inherited Destroy;
end;

{ TPSDImageCacheFileList }

constructor TPSDImageCacheFileList.Create;
begin
  inherited Create(True); // OwnsObjects = True
end;

destructor TPSDImageCacheFileList.Destroy;
begin
  inherited Destroy;
end;
function NormalizeCacheFileName(const FileName: string): string;
begin
  Result := Trim(FileName);
  if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
  Result := StringReplace(Result, '/', '\\', [rfReplaceAll]);
  if Result <> '' then
    Result := ExpandFileName(Result);
end;
function TPSDImageCacheFileList.FindByFileName(
  const FileName: string): TPSDImageCacheFileItem;
var
  Item : TPSDImageCacheFileItem;
  Key  : string;
begin
  Key := NormalizeCacheFileName(FileName);

  for Item in Self do
    if SameText(Item.FileName, Key) then
      Exit(Item);
  Result := nil;
end;

function TPSDImageCacheFileList.GetOrCreate(
  const FileName: string): TPSDImageAviUtl2;
var
  Item : TPSDImageCacheFileItem;
  Psd  : TPSDImageAviUtl2;
  Key  : string;
  I    : Integer;
  {$IFDEF DEBUG}
  T0, TNorm, TSearch, TExists, TLoad, TAdd: Int64;
  Exists: Boolean;
  {$ENDIF}
begin
  Result := nil;

  {$IFDEF DEBUG}
  T0 := PSDCachePerfNow;
  {$ENDIF}

  Key := NormalizeCacheFileName(FileName);
  {$IFDEF DEBUG}
  TNorm := PSDCachePerfNow;
  {$ENDIF}
  if Key = '' then Exit;

  for I := 0 to Count - 1 do
  begin
    Item := Items[I];
    if SameText(Item.FileName, Key) then
    begin
      {$IFDEF DEBUG}
      TSearch := PSDCachePerfNow;
      if PSDCachePerfMs(T0, TSearch) >= 1.0 then
        PSDDebugLog('PSDCache', Format(
          'action=hit count=%d hit_index=%d norm=%.3f search=%.3f total=%.3f key="%s"',
          [Count, I, PSDCachePerfMs(T0, TNorm), PSDCachePerfMs(TNorm, TSearch),
           PSDCachePerfMs(T0, TSearch), Key]));
      {$ENDIF}
      Exit(Item.Psd);
    end;
  end;
  {$IFDEF DEBUG}
  TSearch := PSDCachePerfNow;
  {$ENDIF}

  {$IFDEF DEBUG}
  Exists := FileExists(Key);
  TExists := PSDCachePerfNow;
  if not Exists then
  begin
    PSDDebugLog('PSDCache', Format(
      'action=missing count=%d norm=%.3f search=%.3f exists=%.3f total=%.3f key="%s"',
      [Count, PSDCachePerfMs(T0, TNorm), PSDCachePerfMs(TNorm, TSearch),
       PSDCachePerfMs(TSearch, TExists), PSDCachePerfMs(T0, TExists), Key]));
    Exit;
  end;
  {$ELSE}
  if not FileExists(Key) then Exit;
  {$ENDIF}

  Psd := TPSDImageAviUtl2.Create;
  try
    // 再生中に描画フィルタ用キャッシュへ初回登録されることがあるため、
    // 全レイヤー画像の展開はロード時へ前倒ししない。前倒しすると1フレームに
    // 数十msのロードが集中し、キャッシュ未ヒット時のカクつきになりやすい。
    Psd.PreloadAllLayerBitmapsOnLoad := False;
    // 表情変更プレビューで同じ下層描画を再利用する実験機能。無効にする場合は False に戻す。
    Psd.UseRenderDiffCache := True;
    Psd.LoadFromFile(Key);
    {$IFDEF DEBUG}
    TLoad := PSDCachePerfNow;
    {$ENDIF}
  except
    Psd.Free;
    raise;
  end;

  Item := TPSDImageCacheFileItem.Create(Key, Psd);
  Add(Item);
  {$IFDEF DEBUG}
  TAdd := PSDCachePerfNow;
  PSDDebugLog('PSDCache', Format(
    'action=load count=%d norm=%.3f search=%.3f exists=%.3f load=%.3f add=%.3f total=%.3f key="%s"',
    [Count, PSDCachePerfMs(T0, TNorm), PSDCachePerfMs(TNorm, TSearch),
     PSDCachePerfMs(TSearch, TExists), PSDCachePerfMs(TExists, TLoad),
     PSDCachePerfMs(TLoad, TAdd), PSDCachePerfMs(T0, TAdd), Key]));
  {$ENDIF}

  Result := Psd;
end;


end.

