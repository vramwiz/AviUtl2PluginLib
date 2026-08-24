{
  概要:
    TFolderSelect は、Windowsエクスプローラー風のフォルダ選択コンポーネントです。
    フォルダ構造を TreeView 形式で表示し、選択・新規作成・名前変更・削除といった
    一通りのフォルダ操作に対応しています。

  主な機能:
    - 現在の選択フォルダの取得・指定（SelectFolder プロパティ）
    - 選択フォルダに新しいフォルダを作成（SelectFolderCreateNew）
    - 選択フォルダの名前を変更（SelectFolderBeginEdit）
    - 選択フォルダをごみ箱に削除（SelectFolderDelete）
    - 外部イベント発火（OnFolderSelect）

  特徴:
    - エクスプローラーに近い自然な操作感
    - フレームではなく TCustomControl 派生で軽量
    - 右クリック時も選択状態を正しく更新
    - フォルダの展開・選択時のイベント誤発火を抑制

  対応バージョン:
    Delphi 10 以降（TPath 等を使用）／古いバージョンにも一部対応可能

  作者:VRAMの魔術師
  ライセンス:MIT
}

unit FolderSelect;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,Vcl.ExtCtrls,
  ShellApi,ShlObj,CommCtrl,System.Win.ComObj,Types,IOUtils,Winapi.ActiveX;

type
  TFolderSelectItem = class(TPersistent)
  private
    { Private 宣言 }
    FName        : string;
    FIndexIcon   : Integer;
    FIndexSelect : Integer;
    FIsChild     : Boolean;
    FPIDListFull : PItemIDList;
  public
    { Public 宣言 }
    procedure Assign(Source : TPersistent);override;

    function GetFileInfo(pList,pListEx : PItemIDList) : Boolean;
    function GetImageIndex(p : PWideChar;Flags : Cardinal) : Integer;
    function GetImageIcon(pList: PItemIDList) : THandle;

    property Name : string read FName;
    property IndexIcon : Integer   read FIndexIcon;
    property IndexSelect : Integer read FIndexSelect;
    property PIDListFull : PItemIDList read FPIDListFull;
    property IsChild : Boolean read FIsChild;
  end;

//--------------------------------------------------------------------------//
//  フォルダ情報リストを管理するクラス                                      //
//--------------------------------------------------------------------------//
type
	TFolderSelectItems = class(TList)
	private
		{ Private 宣言 }
    function GetItems(Index: Integer): TFolderSelectItem;
	public
		{ Public 宣言 }
    function Add() : TFolderSelectItem;
    destructor Destroy;override;
    procedure Delete(i : Integer);
    procedure Clear();override;

    function GetFolder(Handle : THandle ; pList   : PItemIDList;FFlags : Cardinal) : Boolean;

		property Folders[Index: Integer] : TFolderSelectItem read GetItems ;default;

	end;

type
  TFolderSelect = class(TCustomControl)
  private
    { Private 宣言 }
    FFlags            : Cardinal;
    FTreeDir          : TTreeView;                 // フォルダ表示TreeView
    FHWDIamge         : THandle;                   // TreeViewに使用する画像イメージハンドル
    FClickDisabled    : Boolean;                   // True:ツリー展開／閉じる中はクリックを無効
    FBuildingTree     : Boolean;                   // True:ツリー生成中は描画起因の再入を抑止
    FFolder           : string;                    // カーソルを合わせるフォルダ
    FClickByLeft      : Boolean;                   // 左クリック判定フラグ
    FLastSelectedNode : TTreeNode;                 // 最後に選択されたノード
    FOnFolderSelect   : TNotifyEvent;

    function GetFolderDesktop() : PItemIDList;

    function NodeExpand(Node : TTreeNode) : Boolean;
    //同名の子ノードが存在するか確認
    function HasChildNodeByName(Parent: TTreeNode; const Name: string): Boolean;

    function IndexOfFolderName(tns : TTreeNodes;const aFolderName : string) : Integer;
    function TreeNodetoPath(tn : TTreeNode) : string;

    procedure NodeSet(aNode : TTreeNode;d : TFolderSelectItem);
    // 指定したフォルダをゴミ箱に送る
    function ShellDeleteToRecycleBin(const FolderPath: string): Boolean;

    procedure OnTreeExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure OnTreeDeletion(Sender: TObject; Node: TTreeNode);
    procedure OnTreeClick(Sender: TObject);
    procedure OnTreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OnTreeEdited(Sender: TObject; Node: TTreeNode; var S: string);

    function GetSelectFolder: string;
    // 指定したフォルダパスに該当するツリーを展開して選択状態にする
    procedure SetSelectFolder(const Value: string);
    // フォルダ検索の再帰法処理
    procedure SetFolderSub(const aPath : string;tnn : TTreeNode;sd : TStringDynArray;aLevel : Integer);
  protected
    procedure DoFolderSelect();
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;
    // 指定したフォルダを選択状態にしてツリー表示
    procedure ShowFolder(const Folder : string);

    // 選択中のフォルダに新しいフォルダを作成
    function SelectFolderCreateNew(const BaseName: string = '新しいフォルダ'): string;
    // 選択中のフォルダ名を編集
    procedure SelectFolderBeginEdit;
    // 選択中のフォルダを削除
    procedure SelectFolderDelete;
    // フォルダを選択、また選択されているフォルダを取得
    property SelectFolder : string read GetSelectFolder write SetSelectFolder;

    property TreeDir  : TTreeView read FTreeDir;

    // フォルダクリックイベント
    property OnFolderSelect  : TNotifyEvent  read FOnFolderSelect write FOnFolderSelect;
  end;

implementation

uses System.StrUtils,System.UITypes;

{ TFolderSelect }

constructor TFolderSelect.Create(AOwner: TComponent);
begin
  inherited;
  FFlags :=  SHCONTF_INCLUDEHIDDEN or SHCONTF_FOLDERS;
  // 生成開始前は通常状態にしておく
  FLastSelectedNode := nil;
  FBuildingTree := False;

  FTreeDir := TTreeView.Create(Self);
  FTreeDir.Parent := Self;
  FTreeDir.Align := alClient;
  FTreeDir.HideSelection := False;
  FTreeDir.OnExpanding := OnTreeExpanding;
  FTreeDir.OnDeletion := OnTreeDeletion;
  FTreeDir.OnClick := OnTreeClick;
  FTreeDir.OnMouseDown := OnTreeMouseDown;
  FTreeDir.OnEdited := OnTreeEdited;

end;

destructor TFolderSelect.Destroy;
begin
  FTreeDir.Free;

  inherited;
end;

// 指定したフォルダを選択状態にしてツリー表示
procedure TFolderSelect.ShowFolder(const Folder: string);
var
  pList    : PItemIDList;
  d : TFolderSelectItem;
  i: Integer;
  n : TTreeNode;
  h : THandle;
  aFolders : TFolderSelectItems;
begin
  FFolder := Folder;
  // ツリー生成中は描画と選択イベントの再入を抑止する
  FBuildingTree := True;

  try
    FTreeDir.Items.BeginUpdate;
    try
      FTreeDir.Items.Clear;
      //FTreeDir.Perform(TVM_SETITEMHEIGHT, 50, 0);
      //SendMessage(FTreeDir.Handle,TV_FIRST+27,22,0); // リスト行の高さを指定
      pList := GetFolderDesktop();
      d := TFolderSelectItem.Create;
      try
        FHWDIamge := d.GetImageIcon(pList);
        h := FTreeDir.Handle;
        TreeView_SetImageList(h, FHWDIamge, TVSIL_NORMAL);

        d.GetFileInfo(pList,nil);
      finally
        d.Free;
      end;

      aFolders := TFolderSelectItems.Create;
      try
        aFolders.GetFolder(Handle,nil,FFlags);                    // デスクトップ下のフォルダを取得

        for i := 0 to aFolders.Count-1 do begin               // 取得したフォルダ数ループ
          d := aFolders[i];                                   // フォルダデータを参照
          n := FTreeDir.Items.AddChildObject(nil,d.FName,nil); // デスクトップ下にツリーを追加
          NodeSet(n,d);
        end;
        // ルート展開はイベント経由にせず直接ノードを構築する
        if FTreeDir.Items.Count > 0 then
          NodeExpand(FTreeDir.Items[0]);
      finally
        aFolders.Free;
      end;
    finally
      FTreeDir.Items.EndUpdate;
    end;
  finally
    FClickDisabled := False;
    FBuildingTree := False;
  end;

  SetSelectFolder(Folder);
end;

// 選択中のフォルダに新しいフォルダを作成
function TFolderSelect.SelectFolderCreateNew(
  const BaseName: string): string;
var
  ParentNode    : TTreeNode;
  ParentPath    : string;
  NewFolderPath : string;
  i             : Integer;
  d             : TFolderSelectItem;
  NewNode       : TTreeNode;
  PIDL          : PItemIDList;
  Attrs         : ULONG;
begin
  Result := '';

  ParentNode := FTreeDir.Selected;
  if not Assigned(ParentNode) then Exit;

  ParentPath := TreeNodetoPath(ParentNode);  // ← 既存関数で選択中ノードのフルパスを取得

  //ParentPath := Folder;

  // 重複しないフォルダ名を生成（"新しいフォルダ", "新しいフォルダ (2)", ...）
  i := 0;
  repeat
    if i = 0 then
      NewFolderPath := IncludeTrailingPathDelimiter(ParentPath) + BaseName
    else
      NewFolderPath := IncludeTrailingPathDelimiter(ParentPath) + BaseName + ' (' + IntToStr(i) + ')';
    Inc(i);
  until not DirectoryExists(NewFolderPath);

  // 実際に作成
  if not CreateDir(NewFolderPath) then
  begin
    ShowMessage('フォルダを作成できませんでした。');
    Exit;
  end;


  PIDL := nil;
  Attrs := 0;
  // PIDL取得
  if SHParseDisplayName(PChar(NewFolderPath), nil, PIDL, 0, Attrs) <> S_OK then
  begin
    ShowMessage('PIDLを取得できませんでした。');
    Exit;
  end;


  // フォルダ情報作成
  d := TFolderSelectItem.Create;
  d.GetFileInfo(PIDL, nil); // ← PIDLのみ指定でOK
  d.FIsChild := False;


  // ノード追加
  NewNode := FTreeDir.Items.AddChildObject(ParentNode, d.Name, PIDL);
  NodeSet(NewNode, d);  // ← アイコンと子ノード情報をセット

  // 選択状態に＆表示更新
  ParentNode.Expand(False);
  FTreeDir.Selected := NewNode;
  FTreeDir.TopItem := NewNode;

  SelectFolderBeginEdit;

  //SetFolder(NewFolderPath);

  Result := NewFolderPath;
end;

// 選択中のフォルダを削除
procedure TFolderSelect.SelectFolderDelete;
var
  Node: TTreeNode;
  FolderPath: string;
begin
  Node := FTreeDir.Selected;
  if not Assigned(Node) then Exit;

  if Node.Level = 0 then
    raise Exception.Create('ルートフォルダは削除できません。');

  FolderPath := TreeNodetoPath(Node);
  if not DirectoryExists(FolderPath) then
    raise Exception.CreateFmt('フォルダが存在しません: %s', [FolderPath]);

  if MessageDlg(Format('"%s" を削除しますか？', [FolderPath]),
                mtWarning, [mbYes, mbNo], 0) <> mrYes then
    Exit;

if not ShellDeleteToRecycleBin(FolderPath) then
  raise Exception.Create('フォルダをごみ箱に送れませんでした。');
  // PIDL 解放
  //if Assigned(Node.Data) then
  //  CoTaskMemFree(PItemIDList(Node.Data));

  // ノード削除 & 親を選択
  if Assigned(Node.Parent) then
    FTreeDir.Selected := Node.Parent;

  FTreeDir.Items.Delete(Node);
end;

// 選択中のフォルダ名を編集
procedure TFolderSelect.SelectFolderBeginEdit;
var
  Node: TTreeNode;
begin
  Node := FTreeDir.Selected;
  if Assigned(Node) then
    Node.EditText;
end;

function TFolderSelect.ShellDeleteToRecycleBin(
  const FolderPath: string): Boolean;
var
  OpStruct: TSHFileOpStructW;
  WidePath: array[0..MAX_PATH + 1] of WideChar;
  CleanPath: string;
  PathLen: Integer;
begin
  Result := False;

  // 安全なパス整形（末尾の \ を除去）
  CleanPath := ExcludeTrailingPathDelimiter(FolderPath);
  if not DirectoryExists(CleanPath) then
    Exit;

  // ダブルNULL終端にする
  FillChar(WidePath, SizeOf(WidePath), 0);
  PathLen := Length(CleanPath);
  StringToWideChar(CleanPath, @WidePath[0], MAX_PATH);

  // 明示的に #0#0 を追加（必須）
  WidePath[PathLen] := #0;
  WidePath[PathLen + 1] := #0;

  ZeroMemory(@OpStruct, SizeOf(OpStruct));
  with OpStruct do
  begin
    Wnd := FTreeDir.Handle; // 有効なウィンドウハンドル
    wFunc := FO_DELETE;
    pFrom := @WidePath;
    fFlags := FOF_ALLOWUNDO or FOF_NOCONFIRMATION or FOF_SILENT;
  end;

  Result := (SHFileOperationW(OpStruct) = 0) and not OpStruct.fAnyOperationsAborted;
end;


function TFolderSelect.GetSelectFolder: string;
var
  s : string;
  n : TTreeNode;
  pList    : PItemIDList;
  FolderPath: array[0..MAX_PATH] of Char;
begin
  n := FTreeDir.Selected;
  pList := PItemIDList(n.Data);
  SHGetPathFromIDList(pList, FolderPath);
  s := FolderPath;
  result := IncludeTrailingPathDelimiter(s);
end;

function TFolderSelect.GetFolderDesktop: PItemIDList;
begin
  SHGetSpecialFolderLocation(0, CSIDL_DESKTOP, result);
end;

function TFolderSelect.HasChildNodeByName(Parent: TTreeNode;
  const Name: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  if not Assigned(Parent) then Exit;

  for i := 0 to Parent.Count - 1 do
  begin
    if CompareText(Parent.Item[i].Text, Name) = 0 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TFolderSelect.IndexOfFolderName(tns: TTreeNodes;
  const aFolderName: string): Integer;
var
  i: Integer;
  tn : TTreeNode;
  aPath : string;
begin
  result := -1;
  for i := 0 to tns.Count-1 do begin
    tn := tns[i];
    aPath := TreeNodetoPath(tn);

    if CompareText(aPath,aFolderName) = 0 then begin
    //if aPath = aFolderName then begin
      result := i;
      exit;
    end;
  end;
end;

function TFolderSelect.NodeExpand(Node: TTreeNode): Boolean;
var
  p : PItemIDList;
  i : Integer;
  n2 : TTreeNode;
  d : TFolderSelectItem;
  aFolders : TFolderSelectItems;
begin
  aFolders := TFolderSelectItems.Create;
  FTreeDir.Items.BeginUpdate();
  try
    p := PItemIDList(Node.Data);
    aFolders.GetFolder(Handle,p,FFlags);

    for i := 0 to aFolders.Count-1 do begin                      // 取得したフォルダ数ループ
      d := aFolders[i];                                          // フォルダデータを参照
      if HasChildNodeByName(Node, d.Name) then Continue;
      n2 := FTreeDir.Items.AddChildObject(Node,d.FName,nil);     // デスクトップ下にツリーを追加
      NodeSet(n2,d);
    end;
    result := True;
  finally
    FTreeDir.Items.EndUpdate();
    aFolders.Free;
  end;
end;

procedure TFolderSelect.NodeSet(aNode: TTreeNode;d : TFolderSelectItem);
begin
  aNode.ImageIndex    := d.FIndexIcon;
  aNode.SelectedIndex := d.FIndexSelect;
  aNode.HasChildren   := d.FIsChild;
  aNode.Data          := d.FPIDListFull;
end;

procedure TFolderSelect.OnTreeClick(Sender: TObject);
var
  CurrentNode: TTreeNode;
begin
  // 生成中のクリック通知は破棄して未完成ノードへのアクセスを防ぐ
  if FBuildingTree then Exit;
  if not FClickByLeft then Exit;                // 左クリック以外は無視

  if FClickDisabled then
  begin
    FClickDisabled := False;                    // 1クリック分だけ抑制
    Exit;
  end;
  FClickByLeft := False;                        // 一度使ったらリセット

  CurrentNode := FTreeDir.Selected;
  if CurrentNode = FLastSelectedNode then Exit; // 選択が変わってなければ無視

  FLastSelectedNode := CurrentNode;
  DoFolderSelect();                                    // ここで外部通知
end;

// ツリーを閉じた時のイベント
procedure TFolderSelect.OnTreeDeletion(Sender: TObject; Node: TTreeNode);
begin
  FClickDisabled := True;
  if Node <> nil then CoTaskMemFree(Node.Data);
  Node.Data := nil;
end;

// ツリーを展開した時のイベント
procedure TFolderSelect.OnTreeExpanding(Sender: TObject; Node: TTreeNode;
  var AllowExpansion: Boolean);
begin
  FClickDisabled := True;
  // ツリー生成中の展開は外部イベントなしでノード構築だけ行う
  //if Node.Level = 0 then exit;                          // ルートフォルダは処理しない
  NodeExpand(Node);
end;

procedure TFolderSelect.OnTreeMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Node: TTreeNode;
begin
  if Button = mbRight then
  begin
    Node := FTreeDir.GetNodeAt(X, Y);
    if Assigned(Node) then
      FTreeDir.Selected := Node;  // 右クリック対象を選択にする
  end;
  FClickByLeft := (Button = mbLeft);
end;

procedure TFolderSelect.OnTreeEdited(Sender: TObject; Node: TTreeNode;
  var S: string);
var
  OldPath, NewPath: string;
  PIDL: PItemIDList;
  Attrs: ULONG;
begin
  // 現在のパスを取得
  OldPath := TreeNodetoPath(Node);
  if OldPath = '' then Exit;

  // 新しいパスを構築
  NewPath := IncludeTrailingPathDelimiter(ExtractFilePath(ExcludeTrailingPathDelimiter(OldPath))) + S;

  // 変更がない or 既に存在するならキャンセル
  if SameText(OldPath, NewPath) or DirectoryExists(NewPath) then
  begin
    ShowMessage('その名前は無効または既に存在します。');
    Node.Text := ExtractFileName(OldPath); // ラベル戻す
    Exit;
  end;

  // フォルダ名変更
  if not RenameFile(OldPath, NewPath) then
  begin
    ShowMessage('フォルダ名を変更できませんでした。');
    Node.Text := ExtractFileName(OldPath); // ラベル戻す
    Exit;
  end;

  // PIDLの更新
  PIDL := nil;
  Attrs := 0;
  if SHParseDisplayName(PChar(NewPath), nil, PIDL, 0, Attrs) = S_OK then
  begin
    CoTaskMemFree(PItemIDList(Node.Data));
    Node.Data := PIDL;
  end
  else
  begin
    ShowMessage('PIDLを更新できませんでした。');
  end;
end;

procedure TFolderSelect.SetSelectFolder(const Value: string);
var
  sd : TStringDynArray;
  i : Integer;
  sf : string;
  tns : TTreeNodes;
  tn : TTreeNode;
begin
  // パス選択中は描画起因の再入を抑止する
  FBuildingTree := True;
  FTreeDir.Items.BeginUpdate;
  try
    sf := IncludeTrailingPathDelimiter(Value);      // 末尾に「\」がなければ追加

    sd := SplitString(sf,'\');                      // 「\」で分解
    //cnt := High(sd) + 1;                            // 指定パスが何階層か取得
    //s := '';
    tns := FTreeDir.Items;                          // 親TreeNodesを参照
    i := IndexOfFolderName(tns,sd[0]+'\');          // 親TreeNodesの何番に一致するドライブ名があるか
    if i = -1 then exit;                            // なければ処理しない
    tn := tns[i];                                   // 該当Nodeを参照
    SetFolderSub(Value,tn,sd,1);                    // 再帰法でNode内の階層を探す

    tn := FTreeDir.Selected;
    if tn<>nil then begin
      FTreeDir.TopItem := tn;
    end;

    //FTreeDir.SetFocus;                              // フォーカスが欲しいがなぜか得られない

  finally
    FTreeDir.Items.EndUpdate;
    FBuildingTree := False;
  end;
end;

procedure TFolderSelect.SetFolderSub(const aPath: string; tnn: TTreeNode;
  sd: TStringDynArray; aLevel: Integer);
var
  j : Integer;
  tn : TTreeNode;
  s,sPath : string;
begin
  if aLevel > High(sd) then begin            // 処理階層が指定フォルダ階層を超えるとき
    FTreeDir.Selected := tnn;                // 処理中のNodeを選択状態に
    exit;                                    // 処理終了
  end;

  sPath := '';                               // 検索Pathを初期化
  for j := 0 to aLevel do begin              // 現在の階層数に該当するPathを作成
    if sd[j]= '' then begin                  // それ以上Pathが無い場合
      FTreeDir.Selected := tnn;              // 処理中のNodeを選択状態に
      exit;                                  // 処理終了
    end;
    sPath := sPath + sd[j] + '\';            // 検索Pathに追加
  end;

  tnn.Expand(False);                             // 処理するNodeを展開しておく
  for j := 0 to tnn.Count-1 do begin             // 子ノード数分ループ
    tn := tnn[j];                                // 子ノード参照
    s := TreeNodetoPath(tn);                     // ノードからPathを取得
    if CompareText(s,sPath) <> 0 then continue;  // 一致しない場合は次のループへ
    SetFolderSub(aPath,tn,sd,aLevel+1);          // そのノードの子ノードを処理する
    break;                                       // 一度階層に入って出てきた処理は終了させる
  end;
end;
function TFolderSelect.TreeNodetoPath(tn: TTreeNode): string;
var
  p : PItemIDList;
  sTbl: array[0..MAX_PATH] of WideChar;
  str : string;
begin
  p := PItemIDList(tn.Data);
  SHGetPathFromIDList(p,sTbl);
  str := sTbl;
  result := IncludeTrailingPathDelimiter(str);
end;



procedure TFolderSelect.DoFolderSelect;
begin
  if Assigned(FOnFolderSelect) then FOnFolderSelect(Self);
end;


{ TFolderSelectItem }

function TFolderSelectItems.Add: TFolderSelectItem;
var
  d : TFolderSelectItem;
begin
  d := TFolderSelectItem.Create;
  inherited Add(d);
  result := d;
end;

procedure TFolderSelectItems.Clear;
var
  i : Integer;
begin
  for i := 0 to Count-1 do begin
    Folders[i].Free;
  end;

  inherited;
end;

procedure TFolderSelectItems.Delete(i: Integer);
begin
  Folders[i].Free;
  inherited Delete(i);
end;

destructor TFolderSelectItems.Destroy;
begin
  Clear();
  inherited;
end;

function TFolderSelectItems.GetFolder(Handle: THandle;
  pList: PItemIDList; FFlags: Cardinal): Boolean;
var
  pList2,pListC    : PItemIDList;
  Fetched      : Cardinal;
  d : TFolderSelectItem;
  sf  : IShellFolder;
  sf2 : IShellFolder2;
  eList  : IEnumIDList;
  f : Cardinal;
begin
  result := False;

  SHGetDesktopFolder(sf);                        // デスクトップのルートフォルダを取得
  if pList = nil then begin                      // デスクトップのフォルダ情報の場合
    sf2 := IShellFolder2(sf);                    // デスクトップフォルダ情報を反映
    pListC := nil;                               // ルートフォルダ情報は nil
  end
  else begin                                     // デスクトップ以外のフォルダ情報の場合
    pListC := ILClone(pList);                    // ルートフォルダとしてコピー
    if sf.BindToObject(pListC, nil,
                      IShellFolder,Pointer(sf2)) <> S_OK then begin // 取得失敗の場合
      if sf2 <> nil then sf2 := nil;                                // 確保したメモリを解放
      if pListC   <> nil then CoTaskMemFree(pListC);
      exit;
    end;
  end;

  Clear;
  if (sf2.EnumObjects(Handle,FFlags, eList)) <> S_OK then exit;

  while (eList.Next(1, pList2, Fetched) = S_OK) do begin
    d := Add();
    d.GetFileInfo(pList2,pListC);
    f := SFGAO_HASSUBFOLDER;
    sf2.GetAttributesOf(1, pList2, f);                    // フォルダの属性を取得
    if (SFGAO_HASSUBFOLDER and f) <> 0 then begin         // その下にフォルダがある場合
      d.FIsChild := True;                                 // フォルダ存在フラグをセット
    end;

  end;
  result := True;
end;

function TFolderSelectItems.GetItems(
  Index: Integer): TFolderSelectItem;
begin
  result := inherited Items[Index];
end;

{ TFolderSelectItem }

procedure TFolderSelectItem.Assign(Source: TPersistent);
var
  a : TFolderSelectItem;
begin
  if Source is TFolderSelectItem then begin
    a := TFolderSelectItem(Source);
    FName    :=  a.FName;
    //FPath    :=  a.FPath;

    FIndexIcon   := a.FIndexIcon;
    FIndexSelect := a.FIndexSelect;
    FIsChild     := a.FIsChild;
    FPIDListFull := a.FPIDListFull;        // FPIDListFullは解放されないのでリストが消えてもOK
  end
  else begin
    inherited;
  end;
end;

function TFolderSelectItem.GetFileInfo(pList,
  pListEx: PItemIDList): Boolean;
  // 渡すファイル名はファイル識別IDリストなので PIDLを指定
const
  FLAG_DISPLAYNAME = SHGFI_DISPLAYNAME or SHGFI_PIDL;
  FLAG_ICON = SHGFI_PIDL or SHGFI_SYSICONINDEX;
  FLAG_ICON_SELECT = SHGFI_PIDL or SHGFI_SYSICONINDEX or SHGFI_OPENICON;
var
  pList2 : PItemIDList;
  aInfo   : TSHFileInfo;
  p : PWideChar;
begin
  pList2 := ILCombine(pListEx, pList);
  FPIDListFull := pList2;

  p := Pointer(pList2);
  FillChar(aInfo, SizeOf(SHFileInfo), #0);
  SHGetFileInfo(p,0, aInfo,SizeOf(aInfo), FLAG_DISPLAYNAME);
  FName := aInfo.szDisplayName;
  FIndexIcon := GetImageIndex(p, FLAG_ICON);
  FIndexSelect := GetImageIndex(p, FLAG_ICON_SELECT);
  result := True;
end;

function TFolderSelectItem.GetImageIcon(pList: PItemIDList): THandle;
const
  FLAG = SHGFI_PIDL or SHGFI_SYSICONINDEX or SHGFI_SMALLICON;
var
  aInfo   : TSHFileInfo;
  p : PWideChar;
begin
  FillChar(aInfo, SizeOf(aInfo), #0);
  p := Pointer(pList);
  result := SHGetFileInfo(p,0,aInfo,SizeOf(aInfo),FLAG);
end;

function TFolderSelectItem.GetImageIndex(p: PWideChar;
  Flags: Cardinal): Integer;
var
  aInfo   : TSHFileInfo;
begin
  FillChar(aInfo, SizeOf(SHFileInfo), #0);
  SHGetFileInfo(p,0,aInfo,SizeOf(aInfo),Flags);
  result := aInfo.iIcon;
end;

end.
