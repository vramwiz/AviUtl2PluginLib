unit ExplorerListView;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Winapi.Windows, Winapi.Messages, Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics, Vcl.ImgList,
  ListViewEdit,ListViewThumbnail,FolderWatch,ExplorerFileList,ShortcutAction,
  ExplorerFolderList, Winapi.CommCtrl,ConfirmDialogForm;


type TExplorerListViewZoomChangeEvent = procedure(Sender : TObject;ZoomIndex : Integer) of object;

type
  TExplorerListViewBase = class(TListViewThumbnail)
  private
    FDialog        : TFormConfirmDialog;     // 独自ダイアログ
    FOnZoomChange: TExplorerListViewZoomChangeEvent;
    procedure SetZoomIndex(const Value: Integer);
  protected

    function GetFileNames(Index: Integer): string; virtual;abstract;
    procedure SetFileNames(Index: Integer; const Value: string);virtual;abstract;
    // 拡大率変更イベント
    procedure DoZoomChange(ZoomIndex : Integer);virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ItemUp();virtual;abstract;
    procedure ItemDown(); virtual;abstract;
    procedure ItemPaste();virtual;abstract;
    procedure ItemDelete();virtual;

    procedure ZoomIn(); virtual;abstract;
    procedure ZoomOut();virtual;abstract;

    procedure SaveToFile;virtual;abstract;

    // サムネイル拡大率
    property ZoomIndex  : Integer write SetZoomIndex;
    property FileNames[Index : Integer] : string read GetFileNames write SetFileNames;
    // 拡大率変更イベント
    property OnZoomChange : TExplorerListViewZoomChangeEvent read FOnZoomChange write FOnZoomChange;
  end;


                                     //= class(TListViewThumbnail)
type                                // <T: TListBoxRTTIItem, constructor> = class(TListBoxEdit)
                                 // <T: TExplorerFile2Item, constructor> = class(TListViewThumbnail)
  TExplorerListView<T: TExplorerFileItem, constructor> = class(TExplorerListViewBase)
  private
    //FFolder    : string;           // 表示しているフォルダ
    FWatch     : TFolderWatch;       // フォルダ監視クラス
    FShortcuts  : TShortcutAction;
    //FOnZoomChange: TExplorerListViewZoomChangeEvent;    // 独自ショートカット管理

    procedure FolderScan(const Folder : string;AFolders : TStringList);
    procedure SyncFolderFiles;
    procedure RebuildItems;

    procedure OnWatchAdd(Sender: TObject; const FileNames: TStringList);
    procedure OnWatchDel(Sender: TObject; const FileNames: TStringList);
    procedure OnWatchChg(Sender: TObject; const FileNames: TStringList);

    //procedure SetFolder(const Value: string);
  protected
    //FFolders   : TExplorerFolderList;    // 管理するファイル名リスト 参照
    FFolder    : string;                   // 表示中のフォルダ
    FFiles     :  TExplorerFileList<T>;   // 表示しているファイル
    FZoomIndex     : Integer;              // ズーム段階のインデックス

    procedure DoCaptionEdited(Item: TListItem; const NewCaption: string; var Accept: Boolean); override;

    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure WMLButtonDblClk(var Msg: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;

    procedure Resize; override;
    procedure DoStartEdit();virtual;
    procedure DoEndEdit();virtual;
    procedure DoWatchAdd(const FileNames: TStringList); virtual;
    procedure DoWatchChg(const FileNames: TStringList); virtual;
    procedure DoWatchDel(const FileNames: TStringList); virtual;
    procedure CNNotify(var Msg: TWMNotify); message CN_NOTIFY;
    // 範囲が異なるため下位にて値を確定
    procedure SetZoomIndex(const Value: Integer);virtual;
    function GetFileNames(Index: Integer): string; override;
    procedure SetFileNames(Index: Integer; const Value: string);override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ShowList(Item : TExplorerFolderItem);
    procedure ShowFolder(const Folder: string; const StoreFile: string = '');
    procedure SaveToFile;override;

    procedure ItemUp();override;
    procedure ItemDown(); override;
    procedure ItemPaste();override;
    procedure  ItemEditname;

    procedure ZoomIn(); override;
    procedure ZoomOut();override;

    function IsItemPaste() : Boolean;virtual;

    property  Files     : TExplorerFileList<T> read FFiles write FFiles;
  end;

implementation

uses System.IOUtils,StrUtils,AppFolderUtils;


{ TExplorerListView }

constructor TExplorerListView<T>.Create(AOwner: TComponent);
begin
  inherited;

  //FFolders := TExplorerFolderList.Create;

  ViewStyle := vsReport;
  RowSelect := True;
  Font.Color := clWhite;
  Font.Height := -11;

  FShortcuts := TShortcutAction.Create;
  FShortcuts.Add(VK_UP  ,[ssCtrl],ItemUp);
  FShortcuts.Add(VK_DOWN,[ssCtrl],ItemDown);
  FShortcuts.Add(Ord('V'),[ssCtrl],ItemPaste);
  FShortcuts.Add(VK_F2,[],ItemEditName);

  FWatch := TFolderWatch.Create;
  FWatch.OnFileAdd := OnWatchAdd;
  FWatch.OnFileUpdate := OnWatchChg;
  FWatch.OnFileDelete := OnWatchDel;
end;

destructor TExplorerListView<T>.Destroy;
begin
  //FFolders.Free;
  FShortcuts.Free;

  FWatch.Stop();
  FWatch.Free;
  inherited;
end;

procedure TExplorerListView<T>.FolderScan(const Folder: string; AFolders: TStringList);
var
  SR: System.SysUtils.TSearchRec;
  FileName: string;
begin
  AFolders.Clear;

  if System.SysUtils.FindFirst(Folder + '\*.*', faAnyFile, SR) = 0 then
  try
    repeat
      // . と .. を除外
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      FileName := IncludeTrailingPathDelimiter(Folder) + SR.Name;

      AFolders.Add(FileName);
    until System.SysUtils.FindNext(SR) <> 0;
  finally
    System.SysUtils.FindClose(SR);
  end;
end;

procedure TExplorerListView<T>.SyncFolderFiles;
var
  ts: TStringList;
begin
  if FFiles = nil then Exit;
  if not DirectoryExists(FFolder) then
  begin
    // 監視イベントの取りこぼしがあっても実フォルダ基準で一覧を空に戻す
    FFiles.Clear;
    Exit;
  end;

  ts := TStringList.Create;
  try
    // 差分イベントではなく現在のフォルダ状態でファイル一覧を再同期する
    FolderScan(FFolder, ts);
    FFiles.AddFiles(ts);
  finally
    ts.Free;
  end;
end;

procedure TExplorerListView<T>.RebuildItems;
var
  i: Integer;
begin
  // 内部一覧に合わせて表示項目を毎回作り直し、残留表示を防ぐ
  // 一覧再構築後は先頭からサムネイル再描画を開始する。
  RestorePopupAfterCaptionEdit; // 再構築でラベル編集が中断されてもPopupMenuを復元する
  ShowBegin(0);
  Items.BeginUpdate;
  try
    Items.Clear;
    for i := 0 to FFiles.Count - 1 do
      ShowItem(FFiles[i].Name);
  finally
    Items.EndUpdate;
    ShowEnd();
  end;
end;


procedure TExplorerListView<T>.ItemUp;
var
  i: Integer;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if i < 1  then Exit;
  if FFiles = nil then Exit;

  FFiles.Exchange(i,i-1);
  Exchange(i,i-1);
  FFiles.SaveToFile();
  ItemIndex := i - 1;
  TopIndex := ItemIndex;
end;

function TExplorerListView<T>.IsItemPaste: Boolean;
begin
  Result := False;
end;

procedure TExplorerListView<T>.ItemDown;
var
  i: Integer;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if i >= Items.Count-1  then Exit;
  if FFiles = nil then Exit;

  FFiles.Exchange(i,i+1);
  Exchange(i,i+1);
  FFiles.SaveToFile();
  ItemIndex := i + 1;
  TopIndex := ItemIndex;
end;

procedure TExplorerListView<T>.ItemEditname;
var
  i: Integer;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if i >= Items.Count  then Exit;
  if FFiles = nil then Exit;
  BeginEdit(i);
end;

procedure TExplorerListView<T>.ItemPaste;
var
  s : string;
begin
  s :='tet';
end;

procedure TExplorerListView<T>.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  FShortcuts.KeyDown(Key,Shift);
end;

procedure TExplorerListView<T>.OnWatchAdd(Sender: TObject; const FileNames: TStringList);
begin
  DoWatchAdd(FileNames);
end;

procedure TExplorerListView<T>.OnWatchChg(Sender: TObject;const FileNames: TStringList);
begin
  DoWatchChg(FileNames);
end;

procedure TExplorerListView<T>.OnWatchDel(Sender: TObject;  const FileNames: TStringList);
begin
  DoWatchDel(FileNames);
end;

// 追加イベント時の既定動作として一覧全体を再同期する。
procedure TExplorerListView<T>.DoWatchAdd(const FileNames: TStringList);
begin
  SyncFolderFiles;
  RebuildItems;
  FFiles.SaveToFile();
end;

// 更新イベント時の既定動作として一覧全体を再同期する。
procedure TExplorerListView<T>.DoWatchChg(const FileNames: TStringList);
begin
  SyncFolderFiles;
  RebuildItems;
  FFiles.SaveToFile();
end;

// 削除イベント時の既定動作として一覧全体を再同期する。
procedure TExplorerListView<T>.DoWatchDel(const FileNames: TStringList);
begin
  SyncFolderFiles;
  RebuildItems;
  FFiles.SaveToFile();
end;


procedure TExplorerListView<T>.Resize;
begin
  inherited;
  if Columns.Count > 0 then
  Columns[0].Width := ClientWidth;
end;

function TExplorerListView<T>.GetFileNames(Index: Integer): string;
begin
  Result := FFiles[Index].FileName;
end;

procedure TExplorerListView<T>.SaveToFile;
begin
  FFiles.SaveToFile;
end;

procedure TExplorerListView<T>.SetFileNames(Index: Integer;
  const Value: string);
begin
  FFiles[Index].FileName := Value;
end;

procedure TExplorerListView<T>.SetZoomIndex(const Value: Integer);
begin
end;

procedure TExplorerListView<T>.ShowList(Item : TExplorerFolderItem);
begin
  ShowFolder(
    Item.FolderName,
    GetAppFolder('Explorer') + Item.FileName
  );
end;

procedure TExplorerListView<T>.ShowFolder(const Folder, StoreFile: string);
begin
  if FFiles = nil then Exit;

  ShowBegin;

  FFiles.Filename := StoreFile;
  if StoreFile <> '' then
    FFiles.LoadFromFile()
  else
    FFiles.Clear;

  FFolder := IncludeTrailingPathDelimiter(Folder);
  FWatch.Stop();

  Items.Clear;

  Columns.Clear;
  Columns.Add;
  AutoAdjustColumnWidth(0);
  Columns[0].AutoSize := True;

  if not DirectoryExists(FFolder) then Exit;

  SyncFolderFiles;
  RebuildItems;

  SaveToFile();

  FWatch.FolderPath := FFolder;
  FWatch.FirstScanDone := True;
  FWatch.Start();
end;


procedure TExplorerListView<T>.WMLButtonDblClk(var Msg: TWMLButtonDblClk);
begin
end;

procedure TExplorerListView<T>.ZoomIn;
begin

end;

procedure TExplorerListView<T>.ZoomOut;
begin

end;

procedure TExplorerListView<T>.CNNotify(var Msg: TWMNotify);
begin
  inherited;

  case Msg.NMHdr^.code of
    LVN_BEGINLABELEDITW: DoStartEdit();      // 編集開始
    LVN_ENDLABELEDITW:  DoEndEdit();        // 編集終了
  end;
end;

procedure TExplorerListView<T>.DoStartEdit;
begin

end;

procedure TExplorerListView<T>.DoCaptionEdited(Item: TListItem;
  const NewCaption: string; var Accept: Boolean);
var
  i: Integer;
  ItemEx: TExplorerFileItem;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if FFiles = nil then Exit;
  ItemEx := FFiles.Files[i];
  ItemEx.Name :=   NewCaption;
  FFiles.SaveToFile();
end;

procedure TExplorerListView<T>.DoEndEdit;
var
  i: Integer;
  Item: TExplorerFileItem;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if FFiles = nil then Exit;
  Item := FFiles.Files[i];
  Item.Name :=   Items[i].Caption;
  FFiles.SaveToFile();
end;


{ TExplorerListViewBase }

constructor TExplorerListViewBase.Create(AOwner: TComponent);
begin
  inherited;
  FDialog := TFormConfirmDialog.Create(Self);
end;

destructor TExplorerListViewBase.Destroy;
begin
  FDialog.Free;
  inherited;
end;

procedure TExplorerListViewBase.DoZoomChange(ZoomIndex: Integer);
begin
  if Assigned(FOnZoomChange) then FOnZoomChange(Self,ZoomIndex);
end;

procedure TExplorerListViewBase.ItemDelete;
var
  i : Integer;
  FileName : string;
  Attr: DWORD;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if FDialog.Execute('削除しますか？') <> mrOk then Exit;
  FileName := FileNames[i];
  if FileName = '' then Exit;
  if not FileExists(FileName) then Exit;

  Attr := Winapi.Windows.GetFileAttributes(PChar(FileName));
  if (Attr <> INVALID_FILE_ATTRIBUTES) and ((Attr and FILE_ATTRIBUTE_READONLY) <> 0) then
    Winapi.Windows.SetFileAttributes(PChar(FileName), Attr and not FILE_ATTRIBUTE_READONLY);

  if not Winapi.Windows.DeleteFile(PChar(FileName)) then Exit;
end;

procedure TExplorerListViewBase.SetZoomIndex(const Value: Integer);
begin

end;

end.
