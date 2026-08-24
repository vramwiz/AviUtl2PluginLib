unit ProjectManagerFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,ProjectManager,ListBoxEx,
  Vcl.Menus, System.ImageList, Vcl.ImgList, Vcl.ComCtrls, Vcl.ToolWin,
  ConfirmDialogForm,ShortcutAction,SerifProject;

type
  TFrameProjectManagerOpen = procedure(Sender: TObject; const Index : Integer) of object;
  TFrameProjectManagerCopy = procedure(Sender: TObject;InfoTo,InfoFrom : TProjectInfo) of object;

type
  TFrameProjectManager = class(TFrame)
    ImageList1: TImageList;
    ToolBar1: TToolBar;
    tsAdd: TToolButton;
    tbCopy: TToolButton;
    tbDelete: TToolButton;
    ToolButton2: TToolButton;
    ToolButton1: TToolButton;
    tbUp: TToolButton;
    tbDown: TToolButton;
    tbFileOpen: TToolButton;
    procedure tbDownClick(Sender: TObject);
    procedure tbUpClick(Sender: TObject);
    procedure tbDeleteClick(Sender: TObject);
    procedure tbCopyClick(Sender: TObject);
    procedure tsAddClick(Sender: TObject);
    procedure tbFileOpenClick(Sender: TObject);
  private
    { Private 宣言 }
    FProjects      : TSerifProjectList;
    FListBox       : TListBoxExColor;
    FDialog        : TFormConfirmDialog;     // 独自ダイアログ
    FOnProjectOpen : TFrameProjectManagerOpen;
    FShortcuts     : TShortcutAction;
    FOnFileOpenClick: TNotifyEvent;         // 独自ショートカット管理

    procedure ItemAdd();
    procedure ItemCopy();
    procedure ItemDelete();
    procedure ItemReName();
    procedure ItemUp();
    procedure ItemDown();
    procedure OnListBoxExEditStart(Sender : TObject; var EditStr : string);
    procedure OnListBoxExEditOk(Sender : TObject;const  EditStr : string);
    procedure OnListBoxDblClick(Sender : TObject);
    procedure OnListBoxKeyDown(Sender : TObject;var Key: Word; Shift: TShiftState);
    procedure SetViewFileOpenIcon(const Value: Boolean);

  protected
    procedure DoProjectOpen(const Index : Integer);virtual;
    procedure DoFileOpenClick();virtual;
    //procedure DoProjectCopy(InfoTo,InfoFrom : TProjectInfo);virtual;
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowList(Projects : TSerifProjectList);

    property ViewFileOpenIcon : Boolean write SetViewFileOpenIcon;

    property OnProjectOpen : TFrameProjectManagerOpen read FOnProjectOpen write FOnProjectOpen;
    property OnFileOpenClick : TNotifyEvent read FOnFileOpenClick write FOnFileOpenClick;
    //property OnProjectCopy : TFrameProjectManagerCopy read FOnProjectCopy write FOnProjectCopy;
  end;

implementation

{$R *.dfm}

{ TFrameProjectManager }

constructor TFrameProjectManager.Create(AOwner: TComponent);
begin
  inherited;
  FListBox  := TListBoxExColor.Create(Self);
  FListBox.Parent := Self;
  FListBox.Align := alClient;
  FListBox.OnDblClick := OnListBoxDblClick;
  FListBox.OnEditStart := OnListBoxExEditStart;
  FListBox.OnEditOk := OnListBoxExEditOk;
  FListBox.OnKeyDown := OnListBoxKeyDown;

  FDialog := TFormConfirmDialog.Create(Self);

  FShortcuts := TShortcutAction.Create;
  FShortcuts.Add(VK_UP  ,[ssCtrl],ItemUp);
  FShortcuts.Add(VK_DOWN,[ssCtrl],ItemDown);
  FShortcuts.Add(VK_F2,[],ItemRename);
  FShortcuts.Add(Ord('D'),[ssCtrl],ItemAdd);
  FShortcuts.Add(Ord('C'),[ssCtrl],ItemCopy);
  FShortcuts.Add(VK_DELETE,[],ItemDelete);
end;

destructor TFrameProjectManager.Destroy;
begin
  FShortcuts.Free;
  FDialog.Free;
  FListBox.Free;
  inherited;
end;

procedure TFrameProjectManager.DoFileOpenClick;
begin
  if Assigned(FOnFileOpenClick) then FOnFileOpenClick(Self);
end;

procedure TFrameProjectManager.DoProjectOpen(const Index : Integer);
begin
  if Assigned(FOnProjectOpen) then FOnProjectOpen(Self,Index);
end;

procedure TFrameProjectManager.SetViewFileOpenIcon(const Value: Boolean);
begin
  tbFileOpen.Visible := Value;
end;

procedure TFrameProjectManager.ShowList(Projects: TSerifProjectList);
var
  i : Integer;
  Proj : TProjectInfo;
begin
  FProjects := Projects;

  FListBox.Items.BeginUpdate;
  try
    FListBox.Clear;
    for i := 0 to FProjects.Count-1 do begin
      Proj := FProjects[i];
      FListBox.Items.AddObject(Proj.ProjectName,Proj);
    end;
    if FListBox.Items.Count > 0 then begin
      FListBox.ItemIndex := 0;
    end;

  finally
    FListBox.Items.EndUpdate;
  end;
end;


procedure TFrameProjectManager.tbUpClick(Sender: TObject);
begin
  ItemUp;
end;

procedure TFrameProjectManager.tsAddClick(Sender: TObject);
begin
  ItemAdd;
end;

procedure TFrameProjectManager.tbCopyClick(Sender: TObject);
begin
  ItemCopy;
end;

procedure TFrameProjectManager.tbDeleteClick(Sender: TObject);
begin
  ItemDelete;
end;

procedure TFrameProjectManager.tbDownClick(Sender: TObject);
begin
  ItemDown;
end;

procedure TFrameProjectManager.tbFileOpenClick(Sender: TObject);
begin
  DoFileOpenClick;
end;

procedure TFrameProjectManager.ItemAdd;
var
  Item : TProjectInfo;
  i : Integer;
begin

  i := FListBox.ItemIndex;                       // カーソル位置を取得
  if i = -1 then begin                           // カーソルが無い場合
    Item := FProjects.ProjectAdd();              // 一番下に追加
    Item.ProjectName := '新しいプロジェクト';
    FListBox.Items.AddObject(Item.ProjectName,Item);
    FListBox.ItemIndex := FListBox.Items.Count-1;    // 追加したリストにカーソルを合わせる
    FListBox.TopIndex := FListBox.ItemIndex;        // カーソルが表示されるようにスクロール
  end
  else begin                                     // 選択中の場合
    Item := FProjects.ProjectInsert(i);            // 途中に追加
    Item.ProjectName := '新しいプロジェクト';
    FListBox.Items.InsertObject(i,Item.ProjectName,Item);
    FListBox.ItemIndex :=  i;                       // 追加したリストにカーソルを合わせる
    FListBox.TopIndex := FListBox.ItemIndex;        // カーソルが表示されるようにスクロール
  end;
  FProjects.SaveToFile();
end;

procedure TFrameProjectManager.ItemCopy;
var
  ddf,ddt : TProjectInfo;
  i : Integer;
begin
  i := FListBox.ItemIndex;                        // カーソル位置を取得
  if i = -1 then exit;                            // キャラが未選択であれば処理終了
  ddf := FProjects[i];
  ddt := FProjects.ProjectInsert(i+1);                  // 一番下に追加

  ddt.ProjectName := ddf.ProjectName + '(コピー)';            // 名称にコピーを追加
  FListBox.Items.InsertObject(i+1,ddt.ProjectName,ddt);

  FListBox.ItemIndex := i + 1;                    // カーソル位置を追加したデータに移動
  FListBox.TopIndex := FListBox.ItemIndex;        // カーソルが表示されるようにスクロール
  FProjects.SaveToFile();
  FProjects.ProjectCopy(i+1,i);
  //DoProjectCopy(ddt,ddf);
end;                                              // メイン側でコピーを行う

procedure TFrameProjectManager.ItemDelete;
var
  i : Integer;
begin
  if FDialog.Execute('削除しますか？') <> mrOk then Exit;
  i := FListBox.ItemIndex;
  if i = -1 then exit;
  FProjects.ProjectDelete(i);
  FListBox.Items.Delete(i);
  FListBox.ItemIndex := i - 1;
  FListBox.TopIndex := FListBox.ItemIndex;        // カーソルが表示されるようにスクロール
  FProjects.SaveToFile();
end;

procedure TFrameProjectManager.ItemUp;
var
  i : Integer;
begin
  i := FListBox.ItemIndex;
  if i = -1 then exit;
  if i-1 < 0 then exit;
  FProjects.Exchange(i,i-1);
  FListBox.Items.Exchange(i,i-1);
  FListBox.ItemIndex := i - 1;
  FListBox.TopIndex := FListBox.ItemIndex;        // カーソルが表示されるようにスクロール
  FProjects.SaveToFile();
end;

procedure TFrameProjectManager.ItemDown;
var
  i : Integer;
begin
  i := FListBox.ItemIndex;
  if i = -1 then exit;
  if i+1 >= FListBox.Items.Count then exit;
  FProjects.Exchange(i,i+1);
  FListBox.Items.Exchange(i,i+1);
  FListBox.ItemIndex := i + 1;
  FListBox.TopIndex := FListBox.ItemIndex;        // カーソルが表示されるようにスクロール
  FProjects.SaveToFile();
end;

procedure TFrameProjectManager.ItemReName;
begin
   FListBox.EditStart();
end;

procedure TFrameProjectManager.OnListBoxExEditStart(Sender: TObject;  var EditStr: string);
var
  i : Integer;
  Proj : TProjectInfo;
begin
  i := FListBox.ItemIndex;
  if i = -1 then exit;
  Proj := TProjectInfo(FListBox.Items.Objects[i]);
  if Proj = nil then Exit;
  EditStr := Proj.ProjectName;
end;

procedure TFrameProjectManager.OnListBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  FShortcuts.KeyDown(Key,Shift);
end;

procedure TFrameProjectManager.OnListBoxDblClick(Sender: TObject);
var
  i : Integer;
  Proj : TProjectInfo;
begin
  i := FListBox.ItemIndex;
  if i = -1 then exit;
  Proj := TProjectInfo(FListBox.Items.Objects[i]);
  if Proj = nil then Exit;
   DoProjectOpen(i);
end;

procedure TFrameProjectManager.OnListBoxExEditOk(Sender: TObject;  const EditStr: string);
var
  i : Integer;
  Proj : TProjectInfo;
begin
  i := FListBox.ItemIndex;
  if i = -1 then exit;
  Proj := TProjectInfo(FListBox.Items.Objects[i]);
  if Proj = nil then Exit;
  FListBox.Items.Strings[i] :=  EditStr;
  Proj.ProjectName := EditStr;
  FProjects.SaveToFile;
end;

end.
