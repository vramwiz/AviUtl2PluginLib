unit SerifProjectFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,ProjectManager,ProjectManagerListBox,
  Vcl.Menus, System.ImageList, Vcl.ImgList, Vcl.ComCtrls, Vcl.ToolWin,
  ConfirmDialogForm,ShortcutAction,SerifProject,ToolbarButtons;

type
  TFrameProjectManagerOpen = procedure(Sender: TObject; const Index : Integer) of object;
  TFrameProjectManagerCopy = procedure(Sender: TObject;InfoTo,InfoFrom : TProjectInfo) of object;

type
  TFrameSerifProject = class(TFrame)
    MenuPop: TPopupMenu;
    MenuAdd: TMenuItem;
    MenuCopy: TMenuItem;
    MenuDelete: TMenuItem;
    MenuEdit: TMenuItem;
    N3: TMenuItem;
    MenuItemUp: TMenuItem;
    MenuItemDown: TMenuItem;
    ImageList1: TImageList;
    procedure tbDownClick(Sender: TObject);
    procedure tbUpClick(Sender: TObject);
    procedure tbDeleteClick(Sender: TObject);
    procedure tbCopyClick(Sender: TObject);
    procedure tsAddClick(Sender: TObject);
    procedure tbReNameClick(Sender: TObject);
    procedure MenuAddClick(Sender: TObject);
    procedure MenuCopyClick(Sender: TObject);
    procedure MenuDeleteClick(Sender: TObject);
    procedure MenuEditClick(Sender: TObject);
    procedure MenuItemUpClick(Sender: TObject);
    procedure MenuItemDownClick(Sender: TObject);
  private
    { Private 宣言 }
    FToolBar       : TToolbarButtons;            // 独自ツールバー
    FProjects      : TSerifProjectList;
    FListBox       : TProjectManagerListBox<TSerifProjectItem>;
    FDialog        : TFormConfirmDialog;     // 独自ダイアログ
    FOnProjectOpen : TFrameProjectManagerOpen;
    //FShortcuts     : TShortcutAction;
    FOnFileOpenClick: TNotifyEvent;         // 独自ショートカット管理

    procedure ShowToolBar;
    procedure ItemAdd();
    procedure ItemCopy();
    procedure ItemDelete();
    procedure ItemReName();
    procedure ItemUp();
    procedure ItemDown();

    procedure OnListBoxDblClick(Sender : TObject);
    procedure SetProjects(const Value : TSerifProjectList);

  protected
    procedure DoProjectOpen(const Index : Integer);virtual;
    procedure DoFileOpenClick();virtual;
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowList();

    property Projects : TSerifProjectList write SetProjects;

    property OnProjectOpen : TFrameProjectManagerOpen read FOnProjectOpen write FOnProjectOpen;
    property OnFileOpenClick : TNotifyEvent read FOnFileOpenClick write FOnFileOpenClick;
  end;

implementation

uses AviUtl2StyleColors;

{$R *.dfm}

{ TFrameProjectManager }

constructor TFrameSerifProject.Create(AOwner: TComponent);
begin
  inherited;
  FToolBar := TToolbarButtons.Create(Self);
  FToolBar.Parent := Self;
  FToolBar.Align := alTop;
  FToolBar.Height := 24;
  FToolBar.NormalColor := A2SCToolBarBackground;
  FToolBar.HoverColor := A2SCToolBarHot;
  FToolBar.DownColor := A2SCToolBarChecked;
  FToolBar.Images := ImageList1;

  FListBox  := TProjectManagerListBox<TSerifProjectItem>.Create(Self);
  FListBox.Parent := Self;
  FListBox.Align := alClient;
  FListBox.Font.Height := -12;
  FListBox.ItemHeight := 24;
  FListBox.PopupMenu := MenuPop;
  FListBox.Color := A2SCListBoxBackground;
  FListBox.OnDblClick := OnListBoxDblClick;

  FDialog := TFormConfirmDialog.Create(Self);
end;

destructor TFrameSerifProject.Destroy;
begin
  //FShortcuts.Free;
  FDialog.Free;
  FListBox.Free;
  FToolBar.Free;
  inherited;
end;

procedure TFrameSerifProject.DoFileOpenClick;
begin
  if Assigned(FOnFileOpenClick) then FOnFileOpenClick(Self);
end;

procedure TFrameSerifProject.DoProjectOpen(const Index : Integer);
begin
  if Assigned(FOnProjectOpen) then FOnProjectOpen(Self,Index);
end;

procedure TFrameSerifProject.SetProjects(const Value : TSerifProjectList);
begin
  FProjects := Value;
  FListBox.Projects := Value;
end;

procedure TFrameSerifProject.ShowList();
var
  i : Integer;
  Proj : TProjectInfo;
begin
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
  ShowToolBar;
end;


procedure TFrameSerifProject.ShowToolBar;
begin
  if FToolBar.Tag = 0 then begin
    FToolBar.AddIcon(string('台本を新規追加'),0,FListBox.ItemAdd);
    FToolBar.AddIcon(string('台本をコピー（設定のみ）'),1,FListBox.ItemCopy);
    FToolBar.AddIcon(string('台本を削除'),2,ItemDelete);
    FToolBar.AddSeparator;
    FToolBar.AddIcon(string('台本の名称変更'),5,ItemReName);
    FToolBar.AddIcon(string('上に移動'),3,FListBox.ItemUp);
    FToolBar.AddIcon(string('下に移動'),4,FListBox.ItemDown);
    FToolBar.Tag := 1;
  end;
end;

procedure TFrameSerifProject.tbUpClick(Sender: TObject);
begin
  ItemUp;
end;

procedure TFrameSerifProject.tsAddClick(Sender: TObject);
begin
  ItemAdd;
end;

procedure TFrameSerifProject.tbCopyClick(Sender: TObject);
begin
  ItemCopy;
end;

procedure TFrameSerifProject.tbDeleteClick(Sender: TObject);
begin
  ItemDelete;
end;

procedure TFrameSerifProject.tbDownClick(Sender: TObject);
begin
  ItemDown;
end;

procedure TFrameSerifProject.tbReNameClick(Sender: TObject);
begin
  ItemReName;
end;

procedure TFrameSerifProject.ItemAdd;
begin
  FListBox.ItemAdd;
end;

procedure TFrameSerifProject.ItemCopy;
begin
  FListBox.ItemCopy;
  ItemReName;
end;                                              // メイン側でコピーを行う

procedure TFrameSerifProject.ItemDelete;
begin
  FListBox.ItemDelete;
end;

procedure TFrameSerifProject.ItemUp;
begin
  FListBox.ItemUp;
end;

procedure TFrameSerifProject.MenuAddClick(Sender: TObject);
begin
  ItemAdd;
end;

procedure TFrameSerifProject.MenuCopyClick(Sender: TObject);
begin
  ItemCopy;
end;

procedure TFrameSerifProject.MenuDeleteClick(Sender: TObject);
begin
  ItemDelete;
end;

procedure TFrameSerifProject.MenuEditClick(Sender: TObject);
begin
  ItemReName;
end;

procedure TFrameSerifProject.MenuItemDownClick(Sender: TObject);
begin
  ItemDown;
end;

procedure TFrameSerifProject.MenuItemUpClick(Sender: TObject);
begin
  ItemUp;
end;

procedure TFrameSerifProject.ItemDown;
begin
  FListBox.ItemDown;
end;

procedure TFrameSerifProject.ItemReName;
begin
  FListBox.ItemReName;
end;

procedure TFrameSerifProject.OnListBoxDblClick(Sender: TObject);
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

end.
