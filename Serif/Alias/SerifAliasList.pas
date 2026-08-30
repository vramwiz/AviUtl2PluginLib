unit SerifAliasList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.ComCtrls,
  ExplorerFileList, ExplorerListView, DragAgent, BitmapCache, ConfirmDialogForm;

type
  TSerifAliasFileItem = class(TExplorerFileItem)
  private
    FLastWriteTime: TDateTime; // 最後に見た .object の更新日時
  public
    property LastWriteTime: TDateTime read FLastWriteTime write FLastWriteTime;
  end;
type
  TSerifAliasFileList = class(TExplorerFileList<TSerifAliasFileItem>)
  private
    // 指定位置のエイリアス項目を型付きで返す
    function GetFiles(Index: Integer): TSerifAliasFileItem;
  protected
    // 表示対象の拡張子か判定する
    function IsVisibleExtension(const FileName: string): Boolean; override;
  public
    // .object 拡張子を表示対象として初期化する
    constructor Create; override;
    property Files[Index: Integer]: TSerifAliasFileItem read GetFiles; default;
  end;
type
  TSerifAliasListView = class(TExplorerListView<TSerifAliasFileItem>)
  private
    FCache: TBitmapCache;   // サムネイルPNGのディスクキャッシュ
    FDialog: TFormConfirmDialog;  // 削除前に確認する共通ダイアログ
    FDrag: TDragShellFile; // シェルドラッグ用ヘルパ
    FIgnoreWatchFiles: TStringList;  // 自前操作で発生する遅延監視通知を吸収する
    FZoomIndex: Integer;  // 現在のズーム段階
    // 自前で触ったファイルを一時的に監視無視へ積む
    procedure AddIgnoreWatchFile(const FileName: string; Count: Integer = 1);
    // 監視通知から自前操作分を取り除く
    function BuildWatchTargetFiles(const FileNames: TStringList): TStringList;
    // 選択中のエイリアスをドラッグ対象として返す
    procedure OnDrag(Sender: TObject; FileNames: TStringList);
    // 指定位置のエイリアス項目を型付きで返す
    function GetFiles(Index: Integer): TSerifAliasFileItem;
    // キャッシュ識別に使うUIDを返す
    function GetCacheUID(Item: TSerifAliasFileItem): string;
    // 実ファイルの更新日時を取得する
    function GetFileLastWriteTime(const FileName: string): TDateTime;
  protected
    // 追加・削除通知時はリネームも含めてキャッシュ整合を取る。
    procedure DoWatchAdd(const FileNames: TStringList); override;
    procedure DoWatchDel(const FileNames: TStringList); override;
    // 更新通知時は変更ファイルだけ部分再描画する。
    procedure DoWatchChg(const FileNames: TStringList); override;
    // 名前変更終了後のファイル反映を行う
    procedure DoEndEdit();override;
    // Ctrl+ホイールでズーム変更する
    procedure WMMouseWheel(var Msg: TWMMouseWheel); message WM_MOUSEWHEEL;
    // サムネイル要求時にキャッシュ確認と必要な再生成を行う
    procedure DoGetDisplayBitmap(Index: Integer; Bitmap: TBitmap); override;
    // ウィンドウ生成後にアイコン配置を整える
    procedure CreateWnd; override;
    // ズーム段階を変更してサムネイルサイズへ反映する
    procedure SetZoomIndex(const Value: Integer); override;
  public
    // 一覧表示の初期設定と補助オブジェクト生成を行う
    constructor Create(AOwner: TComponent); override;
    // 補助オブジェクトを解放する
    destructor Destroy; override;
    // 新規エイリアスを追加する
    procedure ItemAdd;
    // 選択中エイリアスを複製する
    procedure ItemCopy;
    // 選択中エイリアスを削除する
    procedure ItemDelete; reintroduce;
    // キャッシュも含めて一覧表示を更新する
    procedure Refresh;
    // アイコン表示時に上詰めで再配置する
    procedure RealignIconsTop;
    // 初回表示時に一覧項目へ実ファイル日時も同期する。
    procedure ShowFolder(const Folder: string; const StoreFile: string = '');
    // ズームを1段階拡大する
    procedure ZoomIn; override;
    // ズームを1段階縮小する
    procedure ZoomOut; override;
    property Files[Index: Integer]: TSerifAliasFileItem read GetFiles; default;
    property ZoomIndex  : Integer read FZoomIndex  write SetZoomIndex;
  end;

implementation

uses
  System.Math, System.IOUtils, AppFolderUtils, SerifAliasThumbnailRenderer,
  SerifAliasObjectAccessor, SerifAliasObjectFile;

const
  ZOOM_TBL: array[0..5] of Integer = (32, 64, 100, 128, 192, 256);
  THUMBNAIL_ASPECT_RATIO = 16 / 9;
  STYLE_TBL: array[0..5] of TViewStyle = (
    vsReport,
    vsReport,
    vsReport,
    vsIcon,
    vsIcon,
    vsIcon
  );

function GetThumbnailWidth(AHeight: Integer): Integer;
begin
  Result := Max(AHeight, Round(AHeight * THUMBNAIL_ASPECT_RATIO));
end;

function BuildNewAliasBaseName(const Folder: string): string;
var
  BaseName: string;
  Candidate: string;
  FileName: string;
  Index: Integer;
begin
  BaseName := 'NewSerifAlias';
  FileName := IncludeTrailingPathDelimiter(Folder) + BaseName + '.object';
  if not FileExists(FileName) then
    Exit(BaseName);

  Index := 1;
  while True do
  begin
    Candidate := BaseName + IntToStr(Index);
    FileName := IncludeTrailingPathDelimiter(Folder) + Candidate + '.object';
    if not FileExists(FileName) then
      Exit(Candidate);
    Inc(Index);
  end;
end;

function BuildCopyAliasBaseName(const Folder, BaseName: string): string;
var
  Candidate: string;
  FileName: string;
  Index: Integer;
begin
  // 複製元名の後ろに Copy 系サフィックスを付けつつ重複しない名前を作る。
  Candidate := BaseName + '(Copy)';
  FileName := IncludeTrailingPathDelimiter(Folder) + Candidate + '.object';
  if not FileExists(FileName) then
    Exit(Candidate);

  Index := 2;
  while True do
  begin
    Candidate := BaseName + '(Copy' + IntToStr(Index) + ')';
    FileName := IncludeTrailingPathDelimiter(Folder) + Candidate + '.object';
    if not FileExists(FileName) then
      Exit(Candidate);
    Inc(Index);
  end;
end;

{ TSerifAliasFileList }

constructor TSerifAliasFileList.Create;
begin
  inherited;
  FExtensions.Add('.object');
end;

function TSerifAliasFileList.GetFiles(Index: Integer): TSerifAliasFileItem;
begin
  Result := inherited Items[Index];
end;

function TSerifAliasFileList.IsVisibleExtension(const FileName: string): Boolean;
begin
  Result := SameText(ExtractFileExt(FileName), '.object');
end;

{ TSerifAliasListView }

constructor TSerifAliasListView.Create(AOwner: TComponent);
var
  H: Integer;
  W: Integer;
  S: string;
begin
  inherited;
  SortType := stNone;
  FFiles := TSerifAliasFileList.Create;
  // 削除確認は毎回同じ見た目で使うので生成時にまとめて用意する。
  FDialog := TFormConfirmDialog.Create(Self);
  FIgnoreWatchFiles := TStringList.Create;
  FIgnoreWatchFiles.CaseSensitive := False;
  IconOptions.Arrangement := iaTop;
  IconOptions.AutoArrange := True;

  FZoomIndex := 1;
  H := ZOOM_TBL[FZoomIndex];
  W := GetThumbnailWidth(H);
  SetThumbnailSize(STYLE_TBL[FZoomIndex], H, W, True);

  FCache := TBitmapCache.Create;
  S := GetAppFolder('Serif\Alias\Cache');
  FCache.CacheFolder := S;
  FCache.FileName := S + 'Cache.Ini';
  FCache.LoadFromFile;


  FDrag := TDragShellFile.Create(Self);
  FDrag.Attach(Self);
  FDrag.OnDragRequest := OnDrag;
end;

procedure TSerifAliasListView.CreateWnd;
begin
  inherited;
  if ViewStyle = vsIcon then Arrange(arAlignTop);
end;

procedure TSerifAliasListView.RealignIconsTop;
begin
  if HandleAllocated and (ViewStyle = vsIcon) then Arrange(arAlignTop);
end;

destructor TSerifAliasListView.Destroy;
begin
  FDialog.Free;
  FIgnoreWatchFiles.Free;
  FDrag.Free;
  FCache.Free;
  FFiles.Free;
  inherited;
end;

// 標準の再描画処理をそのまま公開する。
procedure TSerifAliasListView.Refresh;
begin
  FCache.ClearCache;
  inherited Refresh;
end;

procedure TSerifAliasListView.ShowFolder(const Folder, StoreFile: string);
var
  I: Integer;
  Item: TSerifAliasFileItem;
begin
  // 共通ルートで一覧を再構築した直後は LastWriteTime が未同期のため、
  // SerifAlias 側だけ実ファイル日時を補完してキャッシュ判定を安定させる。
  inherited ShowFolder(Folder, StoreFile);

  if FFiles = nil then
    Exit;

  // 初回表示や一覧復元直後でも更新判定が安定するよう、
  // 実ファイルの更新日時を一覧アイテム側へ同期する。
  for I := 0 to FFiles.Count - 1 do
  begin
    Item := Files[I];
    if Item = nil then
      Continue;
    Item.LastWriteTime := GetFileLastWriteTime(Item.FileName);
  end;
end;

procedure TSerifAliasListView.DoEndEdit;
var
  i: Integer;
  Item: TExplorerFileItem;
  FileNameFrom,FileNameTo : string;
  FileNameNew: string;
  AliasObj: TSerifAliasObject;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if FFiles = nil then Exit;
  Item := FFiles.Files[i];
  if Item = nil then Exit;

  FileNameFrom := Item.FileName;
  FileNameTo := Trim(Items[i].Caption);
  if FileNameTo = '' then
  begin
    Items[i].Caption := Item.Name;
    Exit;
  end;

  // 元のフォルダと拡張子を維持して表示名だけで .object をリネームする。
  FileNameNew :=
    IncludeTrailingPathDelimiter(ExtractFilePath(FileNameFrom)) +
    FileNameTo +
    ExtractFileExt(FileNameFrom);

  if SameText(FileNameFrom, FileNameNew) then
  begin
    Item.Name := FileNameTo;
    FFiles.SaveToFile();
    Exit;
  end;

  if FileExists(FileNameNew) then
  begin
    Items[i].Caption := Item.Name;
    Exit;
  end;

  if not RenameFile(FileNameFrom, FileNameNew) then
  begin
    Items[i].Caption := Item.Name;
    Exit;
  end;

  // リネーム直後に届く add/chg/del 系の遅延通知で編集中UIを壊さないようにする。
  AddIgnoreWatchFile(FileNameFrom, 2);
  AddIgnoreWatchFile(FileNameNew, 4);

  AliasObj := TSerifAliasObject.Create;
  try
    AliasObj.FileName := FileNameNew;
    if AliasObj.LoadFromFile and AliasObj.IsSyncroh2SerifObject then
    begin
      AliasObj.ScriptFileName := ChangeFileExt(ExtractFileName(FileNameNew), '');
      AliasObj.SaveToFile;
    end;
  finally
    AliasObj.Free;
  end;

  Item.FileName := FileNameNew;
  Item.Name := FileNameTo;
  FFiles.SaveToFile();
end;

// サムネイル要求時にキャッシュ確認と必要な再生成を行う。
procedure TSerifAliasListView.DoGetDisplayBitmap(Index: Integer; Bitmap: TBitmap);
var
  Item: TSerifAliasFileItem;
  S: string;
  LastWriteTime: TDateTime;
  UID: string;
  TempBitmap: TBitmap;
  HasCache: Boolean;
begin
  if FFiles = nil then Exit;
  if Index < 0 then Exit;
  if Index >= FFiles.Count then Exit;

  Item := Files[Index];
  if Item = nil then Exit;

  S := Item.Name;
  if S = '' then
    S := ChangeFileExt(ExtractFileName(Item.FileName), '');

  UID := GetCacheUID(Item);
  HasCache := (FCache <> nil) and FCache.GetCache(UID, Bitmap.Width, Bitmap.Height, Bitmap);

  LastWriteTime := GetFileLastWriteTime(Item.FileName);
  if Item.LastWriteTime <> LastWriteTime then
  begin
    TempBitmap := TBitmap.Create;
    try
      TempBitmap.PixelFormat := Bitmap.PixelFormat;
      TempBitmap.SetSize(Bitmap.Width, Bitmap.Height);

      if TryDrawSerifAliasPreview(Item.FileName, TempBitmap) then
      begin
        Bitmap.Assign(TempBitmap);
        if FCache <> nil then
        begin
          FCache.DeleteCacheItem(UID, Bitmap.Width, Bitmap.Height);
          FCache.AddCache(UID, Bitmap.Width, Bitmap.Height, Bitmap);
        end;
        Item.LastWriteTime := LastWriteTime;
        Exit;
      end;
    finally
      TempBitmap.Free;
    end;

    if HasCache then
      Exit;
  end;

  if HasCache then
    Exit;

  DrawSerifAliasThumbnail(Item.FileName, S, Bitmap);

  if FCache <> nil then
    FCache.AddCache(UID, Bitmap.Width, Bitmap.Height, Bitmap);

  Item.LastWriteTime := LastWriteTime;
end;

// ファイル名を元にキャッシュ識別子を返す。
function TSerifAliasListView.GetCacheUID(Item: TSerifAliasFileItem): string;
begin
  Result := '';
  if Item = nil then
    Exit;
  Result := Item.FileName;
end;

procedure TSerifAliasListView.AddIgnoreWatchFile(const FileName: string;
  Count: Integer);
var
  Index: Integer;
begin
  if FileName = '' then Exit;
  if Count <= 0 then Exit;

  Index := FIgnoreWatchFiles.IndexOf(FileName);
  if Index = -1 then
    FIgnoreWatchFiles.AddObject(FileName, TObject(Count))
  else
    FIgnoreWatchFiles.Objects[Index] :=
      TObject(Integer(FIgnoreWatchFiles.Objects[Index]) + Count);
end;

function TSerifAliasListView.BuildWatchTargetFiles(
  const FileNames: TStringList): TStringList;
var
  I: Integer;
  Index: Integer;
  Count: Integer;
begin
  Result := TStringList.Create;
  if FileNames = nil then
    Exit;

  for I := 0 to FileNames.Count - 1 do
  begin
    Index := FIgnoreWatchFiles.IndexOf(FileNames[I]);
    if Index = -1 then
    begin
      Result.Add(FileNames[I]);
      Continue;
    end;

    // 一度握りつぶしたらカウントを減らし、必要回数だけ自前通知を無視する。
    Count := Integer(FIgnoreWatchFiles.Objects[Index]) - 1;
    if Count <= 0 then
      FIgnoreWatchFiles.Delete(Index)
    else
      FIgnoreWatchFiles.Objects[Index] := TObject(Count);
  end;
end;

// 追加されたエイリアスは一覧再同期後にキャッシュ状態を初期化する。
procedure TSerifAliasListView.DoWatchAdd(const FileNames: TStringList);
var
  I: Integer;
  FirstNewIndex: Integer;
  Item: TSerifAliasFileItem;
  TargetFiles: TStringList;
  FileName: string;
  AddedCount: Integer;
begin
  // 自前作成の遅延通知は除外し、外部変更だけ通常の再同期へ流す。
  TargetFiles := BuildWatchTargetFiles(FileNames);
  try
    if TargetFiles.Count = 0 then
      Exit;

    if FFiles = nil then
      Exit;

    FirstNewIndex := -1;
    AddedCount := 0;

    // 追加通知では一覧全体を作り直さず、新規 .object だけ末尾へ積み増す。
    Items.BeginUpdate;
    try
    for I := 0 to TargetFiles.Count - 1 do
    begin
      FileName := TargetFiles[I];
      if not SameText(ExtractFileExt(FileName), '.object') then
        Continue;
      if not FileExists(FileName) then
        Continue;
      if FFiles.IndexOfFileName(FileName) <> -1 then
        Continue;

      if FirstNewIndex = -1 then
        FirstNewIndex := Items.Count;

      Item := TSerifAliasFileItem(FFiles.AddNew);
      Item.FileName := FileName;
      Item.Name := ChangeFileExt(ExtractFileName(FileName), '');
      Item.LastWriteTime := 0;

      if FCache <> nil then
        FCache.DeleteCacheItem(GetCacheUID(Item));

      ShowItem(Item.Name);
      Inc(AddedCount);
    end;
    finally
      Items.EndUpdate;
    end;

    if AddedCount > 0 then
    begin
      FFiles.SaveToFile();
      // 既存サムネイルはそのままに、追加分の先頭からだけ描画要求を出す。
      RequestThumbnail(FirstNewIndex);
    end;

    RealignIconsTop;
  finally
    TargetFiles.Free;
  end;
end;

// 更新されたエイリアスファイルだけキャッシュ破棄と再描画を行う。
procedure TSerifAliasListView.DoWatchChg(const FileNames: TStringList);
var
  I: Integer;
  Index: Integer;
  Item: TSerifAliasFileItem;
  TargetFiles: TStringList;
begin
  // 自前save由来の更新通知では再構築せず、外部変更だけ反映する。
  TargetFiles := BuildWatchTargetFiles(FileNames);
  try
    if TargetFiles.Count = 0 then Exit;

    if FFiles = nil then
    begin
      inherited DoWatchChg(TargetFiles);
      RealignIconsTop;
      Exit;
    end;

    for I := 0 to TargetFiles.Count - 1 do
    begin
      Index := FFiles.IndexOfFileName(TargetFiles[I]);
      if Index = -1 then Continue;

      Item := Files[Index];
      if Item = nil then Continue;

      Item.LastWriteTime := 0;
      if FCache <> nil then FCache.DeleteCacheItem(GetCacheUID(Item));
      ReLoadThumbnail(Index);
    end;

    FFiles.SaveToFile();
    RealignIconsTop;
  finally
    TargetFiles.Free;
  end;
end;

// 削除されたエイリアスは一覧再同期前に旧パスのキャッシュを破棄する。
procedure TSerifAliasListView.DoWatchDel(const FileNames: TStringList);
var
  I: Integer;
  TargetFiles: TStringList;
begin
  // 自前renameで発生する旧ファイル削除通知はここで吸収する。
  TargetFiles := BuildWatchTargetFiles(FileNames);
  try
    if TargetFiles.Count = 0 then
      Exit;

    // 削除済みファイルは一覧再同期前に旧パスのキャッシュだけ先に消す。
    for I := 0 to TargetFiles.Count - 1 do
      if FCache <> nil then
        FCache.DeleteCacheItem(TargetFiles[I]);

    inherited DoWatchDel(TargetFiles);
    RealignIconsTop;
  finally
    TargetFiles.Free;
  end;
end;

// .object の最終更新日時を取得する。
function TSerifAliasListView.GetFileLastWriteTime(const FileName: string): TDateTime;
begin
  Result := 0;
  if (FileName = '') or not FileExists(FileName) then
    Exit;
  Result := TFile.GetLastWriteTime(FileName);
end;

// 型付きファイル項目として取得する。
function TSerifAliasListView.GetFiles(Index: Integer): TSerifAliasFileItem;
begin
  Result := TSerifAliasFileItem(FFiles[Index]);
end;

procedure TSerifAliasListView.ItemAdd;
var
  InsertIndex: Integer;
  ListItem: TListItem;
  Item: TSerifAliasFileItem;
  Param: TSerifAliasObjectFileParam;
  BaseName: string;
begin
  if FFiles = nil then Exit;
  if FFolder = '' then Exit;

  ForceDirectories(FFolder);

  BaseName := BuildNewAliasBaseName(FFolder);

  Param.FileName := BaseName + '.object';
  Param.TextColor := 'ffffff';
  Param.InnerEdgeColor := 'ffffff';
  Param.OuterEdgeColor := '000000';
  CreateSerifAliasObjectFile(FFolder, Param);
  // 新規作成直後の監視通知でラベル編集がキャンセルされないよう予約しておく。
  AddIgnoreWatchFile(IncludeTrailingPathDelimiter(FFolder) + Param.FileName, 3);

  InsertIndex := ItemIndex;

  ShowBegin(0);
  try
    if InsertIndex = -1 then
    begin
      Item := TSerifAliasFileItem(FFiles.AddNew);
      ListItem := Items.Add;
      InsertIndex := Items.Count - 1;
    end
    else
    begin
      Item := TSerifAliasFileItem(FFiles.InsertNew(InsertIndex));
      ListItem := Insert(InsertIndex);
    end;

    Item.FileName := IncludeTrailingPathDelimiter(FFolder) + Param.FileName;
    Item.Name := BaseName;
    Item.LastWriteTime := 0;

    ListItem.Caption := Item.Name;
    ListItem.ImageIndex := -1;

    ItemIndex := InsertIndex;
    TopIndex := ItemIndex;
  finally
    ShowEnd;
  end;

  FFiles.SaveToFile;
  ReLoadThumbnail(InsertIndex);
  ItemEditName;
end;

procedure TSerifAliasListView.ItemCopy;
var
  SourceIndex: Integer;
  InsertIndex: Integer;
  SourceItem: TSerifAliasFileItem;
  NewItem: TSerifAliasFileItem;
  ListItem: TListItem;
  SourceFileName: string;
  NewBaseName: string;
  NewFileName: string;
  AliasObj: TSerifAliasObject;
begin
  if FFiles = nil then Exit;
  if FFolder = '' then Exit;

  SourceIndex := ItemIndex;
  if SourceIndex = -1 then Exit;

  SourceItem := Files[SourceIndex];
  if SourceItem = nil then Exit;

  SourceFileName := SourceItem.FileName;
  if (SourceFileName = '') or not FileExists(SourceFileName) then Exit;

  // 物理ファイルも内部スクリプト名も複製先の名前へそろえる。
  NewBaseName := BuildCopyAliasBaseName(FFolder, ChangeFileExt(ExtractFileName(SourceFileName), ''));
  NewFileName := IncludeTrailingPathDelimiter(FFolder) + NewBaseName + '.object';

  TFile.Copy(SourceFileName, NewFileName, False);

  AliasObj := TSerifAliasObject.Create;
  try
    AliasObj.FileName := NewFileName;
    if AliasObj.LoadFromFile and AliasObj.IsSyncroh2SerifObject then
    begin
      AliasObj.ScriptFileName := NewBaseName;
      AliasObj.SaveToFile;
    end;
  finally
    AliasObj.Free;
  end;

  // 複製直後の add/chg 通知でラベル編集がキャンセルされないよう予約しておく。
  AddIgnoreWatchFile(NewFileName, 4);

  InsertIndex := SourceIndex + 1;

  ShowBegin(0);
  try
    // コピー項目は元項目の直後へ挿入して、そのまま名前編集へつなげる。
    NewItem := TSerifAliasFileItem(FFiles.InsertNew(InsertIndex));
    ListItem := Insert(InsertIndex);

    NewItem.FileName := NewFileName;
    NewItem.Name := NewBaseName;
    NewItem.LastWriteTime := 0;

    ListItem.Caption := NewItem.Name;
    ListItem.ImageIndex := -1;

    ItemIndex := InsertIndex;
    TopIndex := ItemIndex;
  finally
    ShowEnd;
  end;

  FFiles.SaveToFile;
  ReLoadThumbnail(InsertIndex);
  ItemEditName;
end;

procedure TSerifAliasListView.ItemDelete;
var
  DeleteIndex: Integer;
  NextIndex: Integer;
  FileName: string;
begin
  if FFiles = nil then Exit;

  DeleteIndex := ItemIndex;
  if DeleteIndex = -1 then Exit;
  if DeleteIndex >= FFiles.Count then Exit;

  // 実ファイル削除なので確認ダイアログでユーザー確定を取る。
  if FDialog.Execute('削除しますか？') <> mrOk then Exit;

  FileName := Files[DeleteIndex].FileName;
  if FileName = '' then Exit;
  if not FileExists(FileName) then Exit;
  if not System.SysUtils.DeleteFile(FileName) then Exit;

  // 自前削除の監視通知は吸収して、一覧側は先に選択位置を安定させる。
  AddIgnoreWatchFile(FileName, 2);

  if FCache <> nil then
    FCache.DeleteCacheItem(FileName);

  FFiles.Delete(DeleteIndex);
  Items.Delete(DeleteIndex);

  // 削除後も近い行へカーソルを残して操作感を途切れさせない。
  if Items.Count = 0 then
    NextIndex := -1
  else if DeleteIndex >= Items.Count then
    NextIndex := Items.Count - 1
  else
    NextIndex := DeleteIndex;

  ItemIndex := NextIndex;
  TopIndex := ItemIndex;
  FFiles.SaveToFile;
  RealignIconsTop;
end;

// 選択中のエイリアスファイルをドラッグ対象として返す。
procedure TSerifAliasListView.OnDrag(Sender: TObject; FileNames: TStringList);
var
  I: Integer;
  Item: TSerifAliasFileItem;
begin
  I := ItemIndex;
  if I = -1 then Exit;

  Item := Files[I];
  if Item = nil then Exit;

  FileNames.Clear;
  FileNames.Add(Item.FileName);
end;

// ズーム段階をサムネイル表示ありの範囲で切り替える。
procedure TSerifAliasListView.SetZoomIndex(const Value: Integer);
var
  H: Integer;
  W: Integer;
  NewValue: Integer;
begin
  NewValue := Value;
  if NewValue < 0 then
    NewValue := 0;
  if NewValue > High(ZOOM_TBL) then Exit;

  FZoomIndex := NewValue;
  H := ZOOM_TBL[FZoomIndex];
  W := GetThumbnailWidth(H);
  SetThumbnailSize(STYLE_TBL[FZoomIndex], H, W, True);
  RealignIconsTop;
  DoZoomChange(FZoomIndex);
end;

// Ctrl+ホイールでズーム変更し、それ以外は既定処理へ渡す。
procedure TSerifAliasListView.WMMouseWheel(var Msg: TWMMouseWheel);
begin
  if GetKeyState(VK_CONTROL) >= 0 then
  begin
    inherited;
    Exit;
  end;

  if Msg.WheelDelta > 0 then
    ZoomIn
  else if Msg.WheelDelta < 0 then
    ZoomOut;

  Msg.Result := 1;
end;

// ズームを1段階拡大する。
procedure TSerifAliasListView.ZoomIn;
begin
  if FZoomIndex >= High(ZOOM_TBL) then Exit;
  SetZoomIndex(FZoomIndex + 1);
end;

// ズームを1段階縮小する。
procedure TSerifAliasListView.ZoomOut;
begin
  if FZoomIndex <= 0 then Exit;
  SetZoomIndex(FZoomIndex - 1);
end;

end.
