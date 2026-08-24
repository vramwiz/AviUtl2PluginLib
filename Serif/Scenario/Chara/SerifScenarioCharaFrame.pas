unit SerifScenarioCharaFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus,
  SerifScenarioCharaList, SerifScenarioCharaListView,ToolbarButtons,
  System.ImageList, Vcl.ImgList;

type
  TFrameSerifScenarioChara = class(TFrame)
    MenuPopChara: TPopupMenu;
    MenuCharaDelete: TMenuItem;
    MenuCharaPaste: TMenuItem;
    N3: TMenuItem;
    MenuCharaItemUp: TMenuItem;
    MenuCharaItemDown: TMenuItem;
    ImageList1: TImageList;
    procedure MenuCharaDeleteClick(Sender: TObject);
    procedure MenuCharaPasteClick(Sender: TObject);
    procedure MenuCharaItemUpClick(Sender: TObject);
    procedure MenuCharaItemDownClick(Sender: TObject);
  private
    { Private 宣言 }
    FToolBar       : TToolbarButtons;            // 独自ツールバー
    FListView: TSerifScenarioCharaListView;
    procedure ShowToolBar;
    procedure SetListPopupMenu(const Value: TPopupMenu);
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ShowCharas(Charas: TSerifScenarioCharaList);
    procedure ColumnAlign(const Index: Integer);

    property ListPopupMenu: TPopupMenu write SetListPopupMenu;
  end;

implementation

{$R *.dfm}

uses AviUtl2StyleColors;


{ TFrameSerifScenarioChara }

constructor TFrameSerifScenarioChara.Create(AOwner: TComponent);
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

  FListView := TSerifScenarioCharaListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.ReadOnly := True;
end;

destructor TFrameSerifScenarioChara.Destroy;
begin
  FListView.Free;
  FToolBar.Free;
  inherited;
end;

procedure TFrameSerifScenarioChara.ColumnAlign(const Index: Integer);
begin
  FListView.ColumnAlign(Index);
end;

procedure TFrameSerifScenarioChara.MenuCharaDeleteClick(Sender: TObject);
begin
  FListView.ItemDelete;
end;

procedure TFrameSerifScenarioChara.MenuCharaItemDownClick(Sender: TObject);
begin
  FListView.ItemDown;
end;

procedure TFrameSerifScenarioChara.MenuCharaItemUpClick(Sender: TObject);
begin
  FListView.ItemUp;
end;

procedure TFrameSerifScenarioChara.MenuCharaPasteClick(Sender: TObject);
begin
  FListView.ItemPaste;
end;

procedure TFrameSerifScenarioChara.SetListPopupMenu(const Value: TPopupMenu);
begin
  FListView.PopupMenu := Value;
end;

procedure TFrameSerifScenarioChara.ShowCharas(Charas: TSerifScenarioCharaList);
begin
  ShowToolBar;
  FListView.ShowCharas(Charas);
end;

procedure TFrameSerifScenarioChara.ShowToolBar;
begin
  if FToolBar.Tag = 0 then begin
    FToolBar.AddIcon('キャラのシグネチャを貼り付け',0,FListView.ItemPaste);
    FToolBar.AddIcon('キャラを削除',2,FListView.ItemDelete);
    FToolBar.AddSeparator;
    FToolBar.AddIcon('上に移動',3,FListView.ItemUp);
    FToolBar.AddIcon('下に移動',4,FListView.ItemDown);
    FToolBar.Tag := 1;
  end;

end;

end.
