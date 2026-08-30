unit SerifAliasFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.IOUtils,
  StdCtrls,Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,ListBoxEdit,
  SerifCharaList,ListViewRTTI, Vcl.Menus,RTTIPersistentIni,ConfigPanel,DragAgent,
  SerifAliasList,RTTIPersistentFrame, System.ImageList, Vcl.ImgList,ToolbarButtons,
  ShortcutAction, DarkListBox;

type
  TFrameSerifAliasBound = class(TRTTIFrame)
  private
    FZoomIndex  : Integer;  // サムネイル拡大率
  public
    // 初期値を設定する
    constructor Create;
    // フォームの状態を保持する
    procedure FrameToSelf(AFrame : TFrame);override;
    // 保持した状態をフォームへ戻す
    procedure SelfToFrame(AFrame : TFrame);override;
  published
    property ZoomIndex  : Integer read FZoomIndex  write FZoomIndex;
  end;

//--------------------------------------------------------------------------//
//  セリフ表示用のオブジェクトと一覧を扱うフレーム                          //
//--------------------------------------------------------------------------//
type
  TSerifAliasItem = class(TRTTIPersistentIni)
  private
    FLayerSerif : Integer;  // セリフ参照レイヤー
  public
    // 初期値を設定する
    constructor Create();
    // インスタンスを破棄する
    destructor Destroy;override;
  published
    property LayerSerif : Integer read FLayerSerif write FLayerSerif;
  end;
type
  TFrameSerifAlias = class(TFrame)
    PanelList: TPanel;
    PanelInfo: TPanel;
    LBoxLayer: TDarkListBox;
    ImageList1: TImageList;
    MenuPop: TPopupMenu;
    MenuAdd: TMenuItem;
    MenuCopy: TMenuItem;
    MenuDelete: TMenuItem;
    MenuEdit: TMenuItem;
    N3: TMenuItem;
    MenuItemUp: TMenuItem;
    MenuItemDown: TMenuItem;
    N1: TMenuItem;
    MenuRefresh: TMenuItem;
    MenuPaste: TMenuItem;
    procedure LBoxLayerClick(Sender: TObject);
    procedure MenuAddClick(Sender: TObject);
    procedure MenuCopyClick(Sender: TObject);
    procedure MenuDeleteClick(Sender: TObject);
    procedure MenuEditClick(Sender: TObject);
    procedure MenuItemUpClick(Sender: TObject);
    procedure MenuItemDownClick(Sender: TObject);
    procedure MenuRefreshClick(Sender: TObject);
    procedure MenuPasteClick(Sender: TObject);
  private
    FToolBar       : TToolbarButtons;            // 独自ツールバー
    FShortcuts     : TShortcutAction;            // ショートカット管理
    FListView      : TSerifAliasListView;   // 一覧表示
    FAliasFolder   : string;             // エイリアスフォルダ
    FBound         : TFrameSerifAliasBound;    // 表示状態保存
    FShowed        : Boolean;
    // ツールバーを表示
    procedure ShowToolBar;
    // 選択項目の情報をUIへ反映する
    procedure ShowItem;
    // レイヤー一覧を初期化する
    procedure ShowLayer;
    // 表示前に既存 alias の不足引数を補完する
    procedure PrepareAliasFiles;
    // テキスト表示オブジェクトを貼り付け
    procedure ItemPaste;

    // 一覧クリック時に情報を更新する
    procedure OnListViewClick(Sender: TObject);
    // ショートカット用キー降下イベント
    procedure OnListKeyDown(Sender: TObject;var Key: Word; Shift: TShiftState);
  public
    // フレームを生成する
    constructor Create(AOwner: TComponent); override;
    // フレームを破棄する
    destructor Destroy;override;
    // 一覧表示を更新する
    procedure ShowList();
    // 渡されたエリアス文字列から同期させるファイルを探して同期
    procedure SyncAlias(AliasStr : string);
  end;

implementation

uses AppFolderUtils,ListViewEditPluginDialog,ListViewEditPluginLib,AviUtl2StyleColors,
     AviUtl2Serif,SerifAliasObjectFile,SerifAliasObjectAccessor,AviUtl2AliasSelected;
{$R *.dfm}
{ TFrameSerifAlias }

function SanitizeAliasBaseName(const S: string): string;
const
  REMOVE_CHARS: array[0..10] of Char = ('\', '/', ':', '*', '?', '"', '<', '>', '|', '#', '.');
var
  RemoveChar: Char;
begin
  // .object 化できない文字を落として保存名に使える形へ寄せる。
  Result := Trim(S);
  for RemoveChar in REMOVE_CHARS do
    Result := Result.Replace(RemoveChar, '');
end;

function BuildPasteAliasBaseName(const Folder, PreferredBaseName: string): string;
var
  BaseName: string;
  Candidate: string;
  FileName: string;
  Index: Integer;
begin
  BaseName := SanitizeAliasBaseName(PreferredBaseName);
  if BaseName = '' then
    BaseName := 'PasteSerifAlias';

  // 貼り付け時は既存ファイルと重複しないベース名へ連番で逃がす。
  Candidate := BaseName;
  FileName := IncludeTrailingPathDelimiter(Folder) + Candidate + '.object';
  if not FileExists(FileName) then
    Exit(Candidate);

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

// フレームを生成する
constructor TFrameSerifAlias.Create(AOwner: TComponent);
begin
  inherited;

  GetAppFolder('Serif');       // Windows状態保存ファイル設定
  FAliasFolder := GetAppFolder('Serif\Alias');

  CreateSerifAliasObjectFiles(FAliasFolder);  // サンプルの文字スタイルを生成

  FBound := TFrameSerifAliasBound.Create;
  FBound.Filename  := FAliasFolder +  'SerifAliasFrame.ini';       // Windows状態保存ファイル名設定

  FToolBar := TToolbarButtons.Create(Self);
  FToolBar.Parent := Self;
  FToolBar.Align := alTop;
  FToolBar.Height := 24;
  FToolBar.NormalColor := A2SCToolBarBackground;
  FToolBar.HoverColor := A2SCToolBarHot;
  FToolBar.DownColor := A2SCToolBarChecked;
  FToolBar.Images := ImageList1;

  FShortcuts   := TShortcutAction.Create;
  FShortcuts.Add(Ord('D'),[ssCtrl],FListView.ItemAdd);
  //FShortcuts.Add(VK_UP  ,[ssCtrl],FListView.ItemUp);
  //FShortcuts.Add(VK_DOWN,[ssCtrl],FListView.ItemDown);
  FShortcuts.Add(VK_DELETE,[],FListView.ItemDelete);
  FShortcuts.Add(Ord('V'),[ssCtrl],ItemPaste);
  FShortcuts.Add(VK_F2,[],FListView.ItemEditName);

  LBoxLayer.DesignFontHeight := 13;
  LBoxLayer.DesignItemHeight := 22;

  FListView  := TSerifAliasListView.Create(Self);
  FListView.Parent := PanelList;
  FListView.Align := alClient;
  FListView.Color := A2SCListViewBackground;
  FListView.Font.Height := -12;
  FListView.ItemHeight := 24;
  FListView.PopupMenu := MenuPop;
  FListView.OnClick := OnListViewClick;
  FListView.OnKeyDown := OnListKeyDown;
end;

// フレームを破棄する
destructor TFrameSerifAlias.Destroy;
begin
  FBound.FrameToSelf(Self);
  FBound.SaveToFile;
  FShortcuts.Free;
  FListView.Free;
  FToolBar.Free;
  FBound.Free;
  inherited;
end;

// 一覧表示を更新する
procedure TFrameSerifAlias.ShowList;
begin
  if FShowed then Exit;

  FBound.LoadFromFile;
  FBound.SelfToFrame(Self);

  ShowLayer;
  ShowToolBar;

  ForceDirectories(FAliasFolder);
  // 一覧表示前に旧式スクリプトの get_text 引数を現行形式へ補完する。
  PrepareAliasFiles;

  FListView.Clear;
  FListView.ShowFolder(FAliasFolder);
  FListView.RealignIconsTop;
  FShowed := True;
end;

procedure TFrameSerifAlias.PrepareAliasFiles;
var
  FileName: string;
  AliasObj: TSerifAliasObject;
  MsgExpr: string;
begin
  // 既存 .object を走査し、引数不足の get_text 呼び出しだけ保存し直す。
  for FileName in TDirectory.GetFiles(FAliasFolder, '*.object') do
  begin
    AliasObj := TSerifAliasObject.Create;
    try
      AliasObj.FileName := FileName;
      if not AliasObj.LoadFromFile then
        Continue;
      if not AliasObj.IsSyncroh2SerifObject then
        Continue;

      MsgExpr := Trim(AliasObj.MessageExpression);

      // 旧形式の get_text 呼び出しを obj.id / obj.frame 付きへ補完する。
      if SameText(MsgExpr, 'func.get_text(layer)') or
         SameText(MsgExpr, 'func.get_text(layer_id)') or
         SameText(MsgExpr, 'func.get_text(layer,obj.id)') or
         SameText(MsgExpr, 'func.get_text(layer_id,obj.id)') or
         SameText(MsgExpr, 'func.get_text(layer,layout,uid)') or
         SameText(MsgExpr, 'func.get_text(layer_id,layout,uid)') then
      begin
        AliasObj.MessageExpression := 'func.get_text(layer,obj.id,obj.frame)';
        AliasObj.SaveToFile;
      end;
    finally
      AliasObj.Free;
    end;
  end;
end;

procedure TFrameSerifAlias.ShowToolBar;
begin
  if FToolBar.Tag = 0 then begin
    FToolBar.AddIcon('テキストを新規追加',0,FListView.ItemAdd);
    FToolBar.AddIcon('テキストをコピー',1,FListView.ItemCopy);
    FToolBar.AddIcon('テキストを削除',2,FListView.ItemDelete);
    FToolBar.AddIcon('選択中のテキストを貼り付け',6,ItemPaste);
    FToolBar.AddIcon('テキストの名称変更',5,FListView.ItemEditName);
    FToolBar.AddSeparator;
    FToolBar.AddIcon('上に移動',3,FListView.ItemUp);
    FToolBar.AddIcon('下に移動',4,FListView.ItemDown);

    FToolBar.Tag := 1;
  end;

end;

procedure TFrameSerifAlias.SyncAlias(AliasStr: string);
var
  AliasObj: TSerifAliasObject;
  AliasText: string;
  AliasFileName: string;
  SaveFileName: string;
begin
  // 受信文字列は必要に応じて変換を差し込めるよう変数で持つ。
  AliasText := AliasStr;
  // AviUtl2 由来のエスケープ文字列を受ける場合は、ここで復元してから読ませる。
  //AliasText := AviUtl2TextToStringListText(AliasText);

  //SaveFileName := IncludeTrailingPathDelimiter(FAliasFolder) + 'test.object';
  // 復元確認後は TSerifAliasObject.ScriptFileName で取得した
  // alias 内の filename を保存先へ採用する。
  //SaveFileName := IncludeTrailingPathDelimiter(FAliasFolder) + AliasFileName + '.object';

  AliasObj := TSerifAliasObject.Create;
  try
    // 受信 alias を復元し、想定しているセリフ object だけ後続処理へ流す。
    if not AliasObj.LoadFromText(AliasText) then Exit;
    if not AliasObj.IsSyncroh2SerifObject then Exit;

    // alias 内スクリプトの filename を保存先ファイル名として採用する。
    AliasFileName := Trim(AliasObj.ScriptFileName);
    if AliasFileName <> '' then
      SaveFileName := IncludeTrailingPathDelimiter(FAliasFolder) + AliasFileName + '.object';

    // 復元した alias を確定した .object ファイルへ保存する。
    AliasObj.FileName := SaveFileName;
    AliasObj.SaveToFile;
  finally
    AliasObj.Free;
  end;
end;

procedure TFrameSerifAlias.ItemPaste;
var
  Alias : string;
  AliasObj: TSerifAliasObject;
  ts : TStringList;
  BaseName: string;
  FileName: string;
begin
  ts := TStringList.Create;
  try
    AviUtl2GetSelectedAlias(ts);
    Alias := ts.Text;
  finally
    ts.Free;
  end;

  if Alias = '' then Exit;

  ForceDirectories(FAliasFolder);

  AliasObj := TSerifAliasObject.Create;
  try
    if not AliasObj.LoadFromText(Alias) then Exit;
    if not AliasObj.IsSyncroh2SerifObject then Exit;

    // alias 内の filename を優先しつつ、保存先は FAliasFolder 内の未使用名で確定する。
    BaseName := BuildPasteAliasBaseName(FAliasFolder, AliasObj.ScriptFileName);
    FileName := IncludeTrailingPathDelimiter(FAliasFolder) + BaseName + '.object';

    AliasObj.FileName := FileName;
    // 物理ファイル名と script 内 filename を同じ名前へそろえて保存する。
    AliasObj.ScriptFileName := BaseName;
    if LBoxLayer.ItemIndex >= 0 then
      AliasObj.LayerIndex := LBoxLayer.ItemIndex;
    AliasObj.SaveToFile;
  finally
    AliasObj.Free;
  end;

  FListView.Refresh;
end;



// レイヤー変更を選択中ファイルへ反映する
procedure TFrameSerifAlias.LBoxLayerClick(Sender: TObject);
var
  i: Integer;
  FileName: string;
  AliasObj: TSerifAliasObject;
begin
  i := FListView.ItemIndex;
  if i = -1 then Exit;

  FileName := FListView.Files[i].FileName;
  if not FileExists(FileName) then Exit;

  AliasObj := TSerifAliasObject.Create;
  try
    AliasObj.FileName := FileName;
    if not AliasObj.LoadFromFile then Exit;
    if not AliasObj.IsSyncroh2SerifObject then Exit;

    AliasObj.LayerIndex := LBoxLayer.ItemIndex;
    AliasObj.SaveToFile;
  finally
    AliasObj.Free;
  end;
end;

procedure TFrameSerifAlias.MenuAddClick(Sender: TObject);
begin
  FListView.ItemAdd;
end;

procedure TFrameSerifAlias.MenuCopyClick(Sender: TObject);
begin
  FListView.ItemCopy;
end;

procedure TFrameSerifAlias.MenuDeleteClick(Sender: TObject);
begin
  FListView.ItemDelete;
end;

procedure TFrameSerifAlias.MenuEditClick(Sender: TObject);
begin
  FListView.ItemEditname;
end;

procedure TFrameSerifAlias.MenuItemDownClick(Sender: TObject);
begin
  FListView.ItemDown;
end;

procedure TFrameSerifAlias.MenuItemUpClick(Sender: TObject);
begin
  FListView.ItemUp;
end;

procedure TFrameSerifAlias.MenuPasteClick(Sender: TObject);
begin
  ItemPaste;
end;

procedure TFrameSerifAlias.MenuRefreshClick(Sender: TObject);
begin
  FListView.Refresh;
end;

// レイヤー一覧を初期化する
procedure TFrameSerifAlias.ShowLayer;
var
  i : Integer;
begin
  if LBoxLayer.Items.Count > 0 then Exit;

  LBoxLayer.Items.BeginUpdate;
  LBoxLayer.Clear;
  for i := 1 to 100 do begin
    LBoxLayer.Items.AddObject('レイヤー ' + IntToStr(i),TObject(i));
  end;
  LBoxLayer.Items.EndUpdate;
end;

// 選択項目の情報をUIへ反映する
procedure TFrameSerifAlias.ShowItem;
var
  i : Integer;
  FileName : string;
  AliasObj: TSerifAliasObject;
begin
  i := FListView.ItemIndex;
  if i = -1 then Exit;
  FileName := FListView.Files[i].FileName;

  if not FileExists(FileName) then Exit;

  LBoxLayer.ItemIndex := -1;

  AliasObj := TSerifAliasObject.Create;
  try
    AliasObj.FileName := FileName;
    if not AliasObj.LoadFromFile then Exit;
    if not AliasObj.IsSyncroh2SerifObject then Exit;
    LBoxLayer.ItemIndex := AliasObj.LayerIndex;
  finally
    AliasObj.Free;
  end;
end;

procedure TFrameSerifAlias.OnListKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  FShortcuts.KeyDown(Key,Shift);
end;

// 一覧クリック時に情報を更新する
procedure TFrameSerifAlias.OnListViewClick(Sender: TObject);
begin
  ShowItem;
end;

{ TSerifAliasItem }

// 初期値を設定する
constructor TSerifAliasItem.Create;
begin
  FLayerSerif := 1;
end;

// インスタンスを破棄する
destructor TSerifAliasItem.Destroy;
begin
  inherited;
end;

{ TFrameSerifAliasBound }

// 初期値を設定する
constructor TFrameSerifAliasBound.Create;
begin
  FZoomIndex  := 2;
end;

// フォームの状態を保持する
procedure TFrameSerifAliasBound.FrameToSelf(AFrame: TFrame);
begin
  FZoomIndex := TFrameSerifAlias(AFrame).FListView.ZoomIndex;
end;

// 保持した状態をフォームへ戻す
procedure TFrameSerifAliasBound.SelfToFrame(AFrame: TFrame);
begin
  TFrameSerifAlias(AFrame).FListView.ZoomIndex := FZoomIndex;
end;
end.
