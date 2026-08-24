unit ExplorerListViewFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,ExplorerFolderList,
  ExplorerListView, ExplorerHist,ListViewRTTI, Vcl.ExtCtrls, System.ImageList, Vcl.ImgList,
  Vcl.ComCtrls, Vcl.ToolWin,ExplorerFileList, Vcl.Menus,ToolbarButtons;

type TFrameExplorerListViewListClick   = procedure(Sender : TObject; Item : TExplorerFileItem) of object;
type TFrameExplorerListViewFolderOpen   = procedure(Sender : TObject; AFolder : string) of object;
type TFrameExplorerListViewStyleChange = procedure(Sender : TObject;const FolderName : string;const Style : Integer) of object;

type
  TFrameExplorerListView = class(TFrame)
    PanelExplorer: TPanel;
    PanelBase: TPanel;
    MenuPop: TPopupMenu;
    MenuItemUp: TMenuItem;
    MenuItemDown: TMenuItem;
    MenuPaste: TMenuItem;
    N1: TMenuItem;
    ImageList1: TImageList;
    MenuDelete: TMenuItem;
    procedure PanelResize(Sender: TObject);
    procedure tbPasteClick(Sender: TObject);
    procedure tbUpClick(Sender: TObject);
    procedure tbDownClick(Sender: TObject);
    procedure tbZoomInClick(Sender: TObject);
    procedure tbZoomOutClick(Sender: TObject);
    procedure MenuPasteClick(Sender: TObject);
    procedure MenuItemUpClick(Sender: TObject);
    procedure MenuItemDownClick(Sender: TObject);
    procedure MenuDeleteClick(Sender: TObject);
  private
    { Private 宣言 }
    FToolBar          : TToolbarButtons;            // 独自ツールバー
    FFolder           : string;                     // 表示中のフォルダ
    FStyle            : Integer;                    // 表示中のスタイル
    FFolders          : TExplorerFolderList;        // 管理するフォルダリスト
    FExplorer         : TExplorerListViewBase;      // エクスプローラー風表示リスト
    FPictureZoomIndex : Integer;
    FHist             : TExplorerHistItem;
    FFolderItem       : TExplorerFolderItem;

    FOnListClick    : TFrameExplorerListViewListClick;
    FOnStyleChange  : TFrameExplorerListViewStyleChange;
    FOnDataChange   : TNotifyEvent;
    FOnZoomChange   : TExplorerListViewZoomChangeEvent;
    FOnFolderOpen   : TFrameExplorerListViewFolderOpen;

    procedure ProcResize();
    procedure ShowToolBar;
    procedure ShowStyle;

    procedure ViewList;
    procedure ViewFolder(Style : Integer);

    procedure FolderStyle(Style : Integer);
    procedure FolderPicture;
    procedure FolderSound;
    procedure FolderAlias;
    procedure FolderNormal;
    // お気に入り登録
    procedure FolderFavorite;

    function GetFileItem(AStyle,Index : Integer) : TExplorerFileItem;

    procedure OnExplorerClick(Sender: TObject);
    procedure ZoomChange(Sender : TObject;ZoomIndex : Integer);
  protected
    procedure DoListClick( Item : TExplorerFileItem);virtual;
    procedure DoFolderOpen( AFolder : string);virtual;
    procedure DoStyleChange(const Style : Integer);virtual;
    procedure DoDataChange();virtual;
    // 拡大率変更イベント
    procedure DoZoomChange(ZoomIndex : Integer);
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowList(Hist : TExplorerHistItem);
    procedure ShowFolder(Item : TExplorerFolderItem;Style : Integer);
    procedure DeleteHistItem(const HistFolderName: string);
    function GetSelectItem : TExplorerFileItem;

    property PictureZoomIndex  : Integer read FPictureZoomIndex write FPictureZoomIndex;

    property Explorer : TExplorerListViewBase read FExplorer;

    // クリックイベント
    property OnListClick: TFrameExplorerListViewListClick  read FOnListClick write FOnListClick;
    property OnFolderOpen : TFrameExplorerListViewFolderOpen read FOnFolderOpen write FOnFolderOpen;
    // 画像音楽エリアス表示切り替えイベント
    property OnStyleChange : TFrameExplorerListViewStyleChange read FOnStyleChange write FOnStyleChange;
    // ファイル位置や値設定変更イベント
    property OnDataChange : TNotifyEvent read FOnDataChange write FOnDataChange;
    // 拡大率変更イベント
    property OnZoomChange : TExplorerListViewZoomChangeEvent  write FOnZoomChange;
  end;

implementation

uses  AppFolderUtils,ExplorerListPicture,
      ExplorerListNormal,ExplorerListSound,ExplorerListAlias,
      AviUtl2PluginCore,AviUtl2StyleColors;


{$R *.dfm}

{ TFrameExplorerListView }

constructor TFrameExplorerListView.Create(AOwner: TComponent);
var
  s : string;
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

  FFolders := TExplorerFolderList.Create;
  s := GetAppFolder('Explorer');
  FFolders.Filename := s + 'Folders.ini';
  FFolders.LoadFromFile();

end;

destructor TFrameExplorerListView.Destroy;
begin

  if FExplorer <> nil then FreeAndNil(FExplorer);
  //if FFiles <> nil then FreeAndNil(FFiles);

  FToolBar.Free;
  inherited;
end;

procedure TFrameExplorerListView.ShowFolder(Item: TExplorerFolderItem;Style : Integer);
begin
  FFolderItem := Item;
  ViewFolder(Style);
end;

procedure TFrameExplorerListView.ViewFolder(Style: Integer);
var
  expNormal : TExplorerListViewNormal;
  expPicture : TExplorerListViewPicture;
  expSound : TExplorerListViewSound;
  expAlias : TExplorerListViewAlias;
begin
  if FExplorer <> nil then FreeAndNil(FExplorer);                 // 一度エクスプローラーを削除
  case Style of                                                   // スタイルによって種類を変える
    1 :   begin
            expPicture := TExplorerListViewPicture.Create(Self);
            expPicture.Parent := PanelExplorer;
            expPicture.Align := alClient;
            FExplorer := expPicture;
            FExplorer.OnZoomChange := ZoomChange;
            expPicture.ShowList(FFolderItem);
          end;
    2 :   begin
            expSound := TExplorerListViewSound.Create(Self);
            expSound.Parent := PanelExplorer;
            expSound.Align := alClient;
            FExplorer := expSound;
            expSound.ShowList(FFolderItem);
          end;
    3 :   begin
            expAlias := TExplorerListViewAlias.Create(Self);
            expAlias.Parent := PanelExplorer;
            expAlias.Align := alClient;
            FExplorer := expAlias;
            expAlias.ShowList(FFolderItem);
          end
    else  begin
            expNormal := TExplorerListViewNormal.Create(Self);
            expNormal.Parent := PanelExplorer;
            expNormal.Align := alClient;
            FExplorer := expNormal;
            expNormal.ShowList(FFolderItem);
          end;
  end;

  FExplorer.Parent := PanelExplorer;
  FExplorer.Align := alClient;
  FExplorer.OnClick := OnExplorerClick;
  FExplorer.PopupMenu := MenuPop;

  case Style of
    1 : begin
          FExplorer.ZoomIndex := FPictureZoomIndex;
        end;
  end;

end;

procedure TFrameExplorerListView.ShowList(Hist: TExplorerHistItem);
begin
  FHist := Hist;
  ViewList;
end;

procedure TFrameExplorerListView.ViewList;
var
  i,Style : Integer;
  Folder : string;
  Item : TExplorerFolderItem;
begin
  Folder := IncludeTrailingPathDelimiter(FHist.FolderName);
  Style := FHist.Style;
  if (Folder = FFolder) and (Style = FStyle) then Exit; // 表示中の状態と一致なら表示しない
  FFolder := ExcludeTrailingPathDelimiter(Folder);
  FStyle := Style;
  i := FFolders.IndexOfFolderName(FFolder);
  if i = -1 then begin
    Item := FFolders.AddNew();
    Item.FolderName := FFolder;
    Item.Name := ExtractFileName(FFolder);
    Item.FileName := FormatDateTime('yyyymmddhhnnsszzz', Now) + '.Ini';

    FFolders.SaveToFile();
  end
  else begin
    Item := FFolders[i];
  end;

  ShowFolder(Item,Style);
  ShowToolBar;
  ShowStyle;

end;



procedure TFrameExplorerListView.ShowStyle;
begin
  FToolBar.Items[6].Down := False;           // 選択中のアイコンを解除
  FToolBar.Items[7].Down := False;
  FToolBar.Items[8].Down := False;
  FToolBar.Items[9].Down := False;
  case FStyle of                         // フォルダの表示スタイルに合わせてアイコンを選択中に
    0 : FToolBar.Items[6].Down := True;
    1 : FToolBar.Items[7].Down := True;
    2 : FToolBar.Items[8].Down := True;
    3 : FToolBar.Items[9].Down := True;
  end;
end;

procedure TFrameExplorerListView.ShowToolBar;
begin
  if FExplorer = nil then Exit;

  if FToolBar.Tag = 0 then begin
    FToolBar.AddIcon('削除',2,FExplorer.ItemDelete);
    FToolBar.AddIcon('貼り付け',5,FExplorer.ItemPaste);
    FToolBar.AddSeparator;
    FToolBar.AddIcon('上に移動',3,FExplorer.ItemUp);
    FToolBar.AddIcon('下に移動',4,FExplorer.ItemDown);
    FToolBar.AddSeparator;
    FToolBar.AddIcon('お気に入りに登録',10,FolderFavorite);
    FToolBar.AddSeparator;
    FToolBar.AddIcon('通常フォルダとして設定'    ,6,FolderNormal);
    FToolBar.AddIcon('画像フォルダとして設定'    ,7,FolderPicture);
    FToolBar.AddIcon('音楽フォルダとして設定'    ,8,FolderSound);
    FToolBar.AddIcon('エリアスフォルダとして設定',9,FolderAlias);
    FToolBar.Tag := 1;
  end;

end;

procedure TFrameExplorerListView.tbDownClick(Sender: TObject);
begin
  FExplorer.ItemDown();
end;

procedure TFrameExplorerListView.tbPasteClick(Sender: TObject);
begin
  FExplorer.ItemPaste();
end;

procedure TFrameExplorerListView.tbUpClick(Sender: TObject);
begin
  FExplorer.ItemUp();
end;

procedure TFrameExplorerListView.tbZoomInClick(Sender: TObject);
begin
  if FExplorer = nil then Exit;
  FExplorer.ZoomIn();
end;

procedure TFrameExplorerListView.tbZoomOutClick(Sender: TObject);
begin
  if FExplorer = nil then Exit;
  FExplorer.ZoomOut();
end;

procedure TFrameExplorerListView.ZoomChange(Sender: TObject;  ZoomIndex: Integer);
begin
  DoZoomChange(ZoomIndex);
end;

procedure TFrameExplorerListView.DeleteHistItem(const HistFolderName: string);
var
  i : Integer;
  Folder,s : string;
  Item : TExplorerFolderItem;
begin
  s := IncludeTrailingPathDelimiter(HistFolderName);
  Folder := GetAppFolder('Explorer');
  //Folder := IncludeTrailingPathDelimiter(Hist.FolderName);
  i := FFolders.IndexOfFolderName(s);
  if i = -1 then Exit;
  Item := FFolders[i];
  s := Folder + Item.FileName;
  if FileExists(s) then DeleteFile(s);
  FFolders.Delete(i);
  FFolders.SaveToFile();

end;


procedure TFrameExplorerListView.DoDataChange;
begin
  if Assigned(FOnDataChange) then FOnDataChange(Self);;
end;

procedure TFrameExplorerListView.DoFolderOpen(AFolder: string);
begin
  if Assigned(FOnFolderOpen) then FOnFolderOpen(Self,AFolder);;
end;

procedure TFrameExplorerListView.DoListClick(Item: TExplorerFileItem);
begin
  if Assigned(FOnListClick) then FOnListClick(Self,Item);;
end;

procedure TFrameExplorerListView.DoStyleChange(const Style : Integer);
begin
  if Assigned(FOnStyleChange) then FOnStyleChange(Self,FFolder,Style);
end;

procedure TFrameExplorerListView.DoZoomChange(ZoomIndex: Integer);
begin
  if Assigned(FOnZoomChange) then FOnZoomChange(Self,ZoomIndex);
end;

procedure TFrameExplorerListView.FolderAlias;
begin
  FolderStyle(3);
end;

procedure TFrameExplorerListView.FolderFavorite;
begin

end;

procedure TFrameExplorerListView.FolderNormal;
begin
  FolderStyle(0);
end;

procedure TFrameExplorerListView.FolderPicture;
begin
  FolderStyle(1);
end;

procedure TFrameExplorerListView.FolderSound;
begin
  FolderStyle(2);
end;

procedure TFrameExplorerListView.FolderStyle(Style: Integer);
begin
  FStyle := Style;
  ViewFolder(Style);
  ShowStyle;
  DoStyleChange(Style);
end;

function TFrameExplorerListView.GetFileItem(AStyle,Index: Integer): TExplorerFileItem;
begin
  case AStyle of      // スタイルによって種類を変える
    1 :  Result := TExplorerListViewPicture(FExplorer).Files[Index];
    2 :  Result := TExplorerListViewSound(FExplorer).Files[Index];
    3 :  Result := TExplorerListViewAlias(FExplorer).Files[Index];
    else Result := TExplorerListViewNormal(FExplorer).Files[Index];
  end;
end;

function TFrameExplorerListView.GetSelectItem: TExplorerFileItem;
var
  i : Integer;
begin
  Result := nil;
  if FExplorer = nil then Exit;
  i := FExplorer.ItemIndex;
  if i = -1  then Exit;

  Result := GetFileItem(FStyle,i);
end;

procedure TFrameExplorerListView.MenuDeleteClick(Sender: TObject);
begin
  FExplorer.ItemDelete;
end;

procedure TFrameExplorerListView.MenuItemDownClick(Sender: TObject);
begin
  if FExplorer <> nil then FExplorer.ItemDown;
end;

procedure TFrameExplorerListView.MenuItemUpClick(Sender: TObject);
begin
  if FExplorer <> nil then FExplorer.ItemUp;
end;

procedure TFrameExplorerListView.MenuPasteClick(Sender: TObject);
begin
  if FExplorer <> nil then FExplorer.ItemPaste();
end;

procedure TFrameExplorerListView.OnExplorerClick(Sender: TObject);
var
  i : Integer;
  Item : TExplorerFileItem;
begin
  if FExplorer = nil then Exit;
  i := FExplorer.ItemIndex;
  if i = -1  then Exit;

  Item := GetFileItem(FStyle,i);
  //Item := TExplorerFileItem(FExplorer.Files[i]);
  if Item = nil  then Exit;

  DoListClick(Item);
end;


procedure TFrameExplorerListView.PanelResize(Sender: TObject);
begin
  ProcResize();
end;

procedure TFrameExplorerListView.ProcResize;
begin
  if FExplorer <> nil then FExplorer.ColumnAlign(0);
end;


end.
