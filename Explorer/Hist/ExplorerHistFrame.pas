unit ExplorerHistFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,ListBoxEdit,ExplorerHist,
  Vcl.Menus, System.ImageList, Vcl.ImgList,ShortcutAction, Vcl.ComCtrls,
  Vcl.ToolWin,ExplorerHistListBox,ToolbarButtons;

type TFrameExplorerHistListClick       = procedure(Sender : TObject;const FolderName : string) of object;


type
  TFrameExplorerHist = class(TFrame)
    ImageListType: TImageList;
    DlgOpen: TFileOpenDialog;
    MenuPop: TPopupMenu;
    MenuOpen: TMenuItem;
    MenuDelete: TMenuItem;
    N6: TMenuItem;
    MenuItemUp: TMenuItem;
    MenuItemDown: TMenuItem;
    N3: TMenuItem;
    ImageList1: TImageList;
    procedure MenuOpenClick(Sender: TObject);
    procedure MenuDeleteClick(Sender: TObject);
    procedure MenuItemUpClick(Sender: TObject);
    procedure MenuItemDownClick(Sender: TObject);
  private
    { Private 宣言 }
    FToolBar       : TToolbarButtons;            // 独自ツールバー
    FListBox       : TListBoxExplorerHist;
    FShortCut      : TShortcutAction;            // 独自ショートカット管理
    FOnListClick   : TFrameExplorerHistListClick;
    FOnListDelete  : TFrameExplorerHistListClick;
    FOnFolderOpen  : TFrameExplorerHistListClick;

    procedure ShowToolBar;

    procedure OnListBoxClick(Sender: TObject);
    procedure OnListBoxDblClick(Sender: TObject);
    procedure OnListBoxKeyDown(Sender : TObject;var Key: Word; Shift: TShiftState);
    function GetItemIndex: Integer;
    procedure SetItemIndex(const Value: Integer);

  protected
    procedure DoListClick(const FolderName : string);virtual;
    procedure DoListDelete(const FolderName : string);virtual;
    procedure DoFolderOpen(const FolderName : string);virtual;
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowList(Hists : TExplorerHistList);
    procedure ViewList();
    procedure SetSelectFolder(const Value: string);

    procedure ItemDelete;
    property ItemIndex : Integer read GetItemIndex write SetItemIndex;

    procedure FolderOpen;
    function GetItemStyle: Integer;

    property OnListClick: TFrameExplorerHistListClick  read FOnListClick write FOnListClick;
    property OnListDelete: TFrameExplorerHistListClick  read FOnListDelete write FOnListDelete;
    property OnFolderOpen : TFrameExplorerHistListClick read FOnFolderOpen write FOnFolderOpen;
  end;

implementation

uses AviUtl2StyleColors;

{$R *.dfm}

{ TFrameExplorerHist }


constructor TFrameExplorerHist.Create(AOwner: TComponent);
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

  FListBox := TListBoxExplorerHist.Create(Self);
  FListBox.Parent := Self;
  FListBox.Align := alClient;
  FListBox.ItemHeight := 24;
  FListBox.ImageList := ImageListType;
  FListBox.Color :=  A2SCListBoxBackground;
  FListBox.PopupMenu := MenuPop;
  FListBox.OnClick := OnListBoxClick;
  FListBox.OnDblClick := OnListBoxDblClick;
  //FListBox.OnEditStart := OnListEditStart;
  FListBox.OnKeyDown   := OnListBoxKeyDown;

  FShortCut := TShortcutAction.Create;
  FShortCut.Add(VK_UP    ,[ssCtrl],FListBox.ItemUp);
  FShortCut.Add(VK_DOWN  ,[ssCtrl],FListBox.ItemDown);
  FShortCut.Add(VK_DELETE,[      ],ItemDelete);
  FShortCut.Add(VK_F2,[      ],FListBox.ItemEditName);

end;

destructor TFrameExplorerHist.Destroy;
begin
  FShortCut.Free;
  FListBox.Free;
  FToolBar.Free;

  inherited;
end;

procedure TFrameExplorerHist.ShowList(Hists: TExplorerHistList);
begin
  ShowToolBar;
  FListBox.ShowList(Hists);
end;

procedure TFrameExplorerHist.ShowToolBar;
begin
  if FToolBar.Tag = 0 then begin
    FToolBar.AddIcon('フォルダを登録',0,FolderOpen);
    FToolBar.AddIcon('フォルダの登録を解除',2,ItemDelete);
    FToolBar.AddSeparator;
    FToolBar.AddIcon('上に移動',3,FListBox.ItemUp);
    FToolBar.AddIcon('下に移動',4,FListBox.ItemDown);
    FToolBar.Tag := 1;
  end;
end;

procedure TFrameExplorerHist.ViewList;
begin
  FListBox.ViewList;
end;


procedure TFrameExplorerHist.FolderOpen;
begin
  DlgOpen.Options := DlgOpen.Options + [TFileDialogOption.fdoPickFolders];
  DlgOpen.Title := 'フォルダの選択';
  if not DlgOpen.Execute() then exit;
  DoFolderOpen(DlgOpen.FileName)
end;

procedure TFrameExplorerHist.MenuDeleteClick(Sender: TObject);
begin
  FListBox.ItemDelete;
end;

procedure TFrameExplorerHist.MenuItemDownClick(Sender: TObject);
begin
  FListBox.ItemDown;
end;

procedure TFrameExplorerHist.MenuItemUpClick(Sender: TObject);
begin
  FListBox.ItemUp;
end;

procedure TFrameExplorerHist.MenuOpenClick(Sender: TObject);
begin
  FolderOpen;
end;

procedure TFrameExplorerHist.ItemDelete;
var
  i: Integer;
  Hist : TExplorerHistItem;
begin
  Hist := FListBox.GetSelectItem;
  if Hist = nil then Exit;

  DoListDelete(Hist.FolderName);  //  関連するファイル削除のための発火

  FListBox.ItemDelete;

  i := FListBox.ItemIndex;
  if i = -1 then Exit;
  Hist := TExplorerHistItem(FListBox.Items.Objects[i]);
  DoListClick(Hist.FolderName);
end;

procedure TFrameExplorerHist.OnListBoxClick(Sender: TObject);
var
  Hist : TExplorerHistItem;
begin
  Hist := FListBox.GetSelectItem;
  if Hist = nil then Exit;
  DoListClick(Hist.FolderName);
end;

procedure TFrameExplorerHist.OnListBoxDblClick(Sender: TObject);
begin
  FListBox.BeginEdit(FListBox.ItemIndex);
end;


procedure TFrameExplorerHist.OnListBoxKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  FShortCut.KeyDown(Key,Shift);
end;

procedure TFrameExplorerHist.SetSelectFolder(const Value: string);
begin
  FListBox.SetSelectFolder(Value);
end;

procedure TFrameExplorerHist.DoFolderOpen(const FolderName: string);
begin
  if Assigned(FOnFolderOpen) then FOnFolderOpen(Self,FolderName);
end;

procedure TFrameExplorerHist.DoListClick(const FolderName : string);
begin
  if Assigned(FOnListClick) then FOnListClick(Self,FolderName);;
end;

procedure TFrameExplorerHist.DoListDelete(const FolderName: string);
begin
  if Assigned(FOnListDelete) then FOnListDelete(Self,FolderName);;
end;

function TFrameExplorerHist.GetItemIndex: Integer;
begin
  Result := FListBox.ItemIndex;
end;

procedure TFrameExplorerHist.SetItemIndex(const Value: Integer);
begin
  FListBox.ItemIndex := Value;
end;

function TFrameExplorerHist.GetItemStyle: Integer;
var
  Hist : TExplorerHistItem;
begin
  Result := 0;
  Hist := FListBox.GetSelectItem;
  if Hist = nil then Exit;
  Result := Hist.Style;
end;


end.
