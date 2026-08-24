unit SerifScenarioMsgFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus,
  SerifScenarioCharaList, SerifScenarioMsgList, SerifScenarioMsgListView,
  ToolbarButtons, System.ImageList, Vcl.ImgList;

type
  TFrameSerifScenarioMsg = class(TFrame)
    MenuPop: TPopupMenu;
    MenuMsgDelete: TMenuItem;
    MenuMsgPaste: TMenuItem;
    MenuMsgCopy: TMenuItem;
    MenuItem3: TMenuItem;
    MenuMsgUp: TMenuItem;
    MenuMsgDown: TMenuItem;
    ImageList1: TImageList;
    procedure MenuMsgDeleteClick(Sender: TObject);
    procedure MenuMsgPasteClick(Sender: TObject);
    procedure MenuMsgUpClick(Sender: TObject);
    procedure MenuMsgDownClick(Sender: TObject);
    procedure MenuMsgCopyClick(Sender: TObject);
  private
    { Private 宣言 }
    FToolBar       : TToolbarButtons;            // 独自ツールバー
    FListView: TSerifScenarioMsgListView;
    procedure ShowToolBar;
    procedure SetListPopupMenu(const Value: TPopupMenu);
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ShowMsg(Charas: TSerifScenarioCharaList; Msgs: TSerifScenarioMsgList);
    procedure ColumnAlign(const Index: Integer);

    property ListPopupMenu: TPopupMenu write SetListPopupMenu;
  end;

implementation

{$R *.dfm}

uses AviUtl2StyleColors;

{ TFrameSerifScenarioMsg }

constructor TFrameSerifScenarioMsg.Create(AOwner: TComponent);
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

  FListView := TSerifScenarioMsgListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.ReadOnly := True;
end;

destructor TFrameSerifScenarioMsg.Destroy;
begin
  FListView.Free;
  FToolBar.Free;
  inherited;
end;

procedure TFrameSerifScenarioMsg.ColumnAlign(const Index: Integer);
begin
  FListView.ColumnAlign(Index);
end;

procedure TFrameSerifScenarioMsg.MenuMsgCopyClick(Sender: TObject);
begin
   FListView.ItemCopy;
end;

procedure TFrameSerifScenarioMsg.MenuMsgDeleteClick(Sender: TObject);
begin
  FListView.ItemDelete;
end;

procedure TFrameSerifScenarioMsg.MenuMsgDownClick(Sender: TObject);
begin
  FListView.ItemDown;
end;

procedure TFrameSerifScenarioMsg.MenuMsgPasteClick(Sender: TObject);
begin
  FListView.ItemPaste;
end;

procedure TFrameSerifScenarioMsg.MenuMsgUpClick(Sender: TObject);
begin
  FListView.ItemUp;
end;

procedure TFrameSerifScenarioMsg.SetListPopupMenu(const Value: TPopupMenu);
begin
  FListView.PopupMenu := Value;
end;

procedure TFrameSerifScenarioMsg.ShowMsg(Charas: TSerifScenarioCharaList;
  Msgs: TSerifScenarioMsgList);
begin
  ShowToolBar;
  FListView.ShowMsg(Charas, Msgs);
end;

procedure TFrameSerifScenarioMsg.ShowToolBar;
begin
  if FToolBar.Tag = 0 then begin
    FToolBar.AddIcon('脚本を貼り付け',0,FListView.ItemPaste);
    FToolBar.AddIcon('脚本をコピー',1,FListView.ItemCopy);
    FToolBar.AddIcon('セリフを削除',2,FListView.ItemDelete);
    FToolBar.AddSeparator;
    FToolBar.AddIcon('上に移動',3,FListView.ItemUp);
    FToolBar.AddIcon('下に移動',4,FListView.ItemDown);
    FToolBar.Tag := 1;
  end;

end;

end.
