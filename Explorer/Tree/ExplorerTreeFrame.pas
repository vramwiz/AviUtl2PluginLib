unit ExplorerTreeFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  FolderSelect, System.ImageList, Vcl.ImgList,
  ToolbarButtons;

type
  TFrameExplorerTree = class(TFrame)
    ImageList1: TImageList;
  private
    { Private 宣言 }
    FToolBar          : TToolbarButtons;            // 独自ツールバー
    FFolderTree : TFolderSelect;
    FOnFolderSelect: TNotifyEvent;

    procedure ShowToolBar;

    procedure FolderNew;
    procedure FolderDelete;
    procedure FolderReName;

    procedure OnTreeDblClick(Sender: TObject);

    function GetSelectFolder: string;
    procedure SetSelectFolder(const Value: string);
  protected
    procedure DoFolderSelect();
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    // フォルダを選択、また選択されているフォルダを取得
    property SelectFolder : string read GetSelectFolder write SetSelectFolder;

    procedure ShowFolder(const Folder : string);
    // フォルダクリックイベント
    property OnFolderSelect  : TNotifyEvent  write FOnFolderSelect;
  end;

implementation

{$R *.dfm}

uses AviUtl2StyleColors;

{ TFrameExplorerTree }

constructor TFrameExplorerTree.Create(AOwner: TComponent);
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

  FFolderTree := TFolderSelect.Create(Self);
  FFolderTree.Parent := Self;
  FFolderTree.Align := alClient;
  FFolderTree.TreeDir.OnDblClick := OnTreeDblClick;    // TODO : ツリーの選択をダブルクリックに
end;

destructor TFrameExplorerTree.Destroy;
begin
  FFolderTree.Free;
  FToolBar.Free;
  inherited;
end;

function TFrameExplorerTree.GetSelectFolder: string;
begin
  Result := FFolderTree.SelectFolder;
end;

procedure TFrameExplorerTree.OnTreeDblClick(Sender: TObject);
begin
   DoFolderSelect;
end;

procedure TFrameExplorerTree.SetSelectFolder(const Value: string);
begin
  FFolderTree.SelectFolder := Value;
end;

procedure TFrameExplorerTree.ShowFolder(const Folder : string);
begin
  FFolderTree.ShowFolder(Folder);
  ShowToolBar;
  Show;
end;

procedure TFrameExplorerTree.ShowToolBar;
begin
  if FToolBar.Tag = 0 then begin
    FToolBar.AddIcon('フォルダを作成',0,FolderNew);
    FToolBar.AddIcon('フォルダを削除',1,FolderDelete);
    FToolBar.AddSeparator;
    FToolBar.AddIcon('繝輔か繝ｫ繝蜷榊､画峩',2,FolderReName);
    FToolBar.Tag := 1;
  end;
end;

procedure TFrameExplorerTree.DoFolderSelect;
begin
  if Assigned(FOnFolderSelect) then FOnFolderSelect(Self);
end;

procedure TFrameExplorerTree.FolderDelete;
begin
  FFolderTree.SelectFolderDelete;
end;

procedure TFrameExplorerTree.FolderNew;
begin
  FFolderTree.SelectFolderCreateNew();
end;

procedure TFrameExplorerTree.FolderReName;
begin
  FFolderTree.SelectFolderBeginEdit;
end;

end.
