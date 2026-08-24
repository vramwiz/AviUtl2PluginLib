unit LauncherListFrame;

// ランチャー一覧、登録解除、名称変更、並び替えメニューを提供するフレームユニット。
interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus,LauncherListView,
  System.ImageList, Vcl.ImgList,ToolbarButtons,ShortcutAction;

type
  TLauncherListRequestEvent = procedure(Sender: TObject) of object;

type
  TFrameLauncherList = class(TFrame)
    MenuPopup: TPopupMenu;
    MenuAppAdd: TMenuItem;
    MenuAppDelete: TMenuItem;
    MenuAppRename: TMenuItem;
    N4: TMenuItem;
    MenuItemUp: TMenuItem;
    MenuItemDown: TMenuItem;
    N7: TMenuItem;
    ImageList1: TImageList;
    // 登録メニューからウィザード表示を要求する。
    procedure MenuAppAddClick(Sender: TObject);
    // 選択中の登録を解除する。
    procedure MenuAppDeleteClick(Sender: TObject);
    // 選択中項目の名称変更を開始する。
    procedure MenuAppRenameClick(Sender: TObject);
    // 選択中項目を上へ移動する。
    procedure MenuItemUpClick(Sender: TObject);
    // 選択中項目を下へ移動する。
    procedure MenuItemDownClick(Sender: TObject);
  private
    { Private 宣言 }
    FListView     : TLauncherListView;          // ランチャー項目を表示する一覧。
    FToolBar      : TToolbarButtons;           // 独自ツールバー
    FShortcuts     : TShortcutAction;            // ショートカット管理
    FOnAddRequest : TLauncherListRequestEvent; // 登録ウィザード表示要求。
    procedure ShowToolBar;

    procedure ItemEntry;
    procedure ItemDelete;
    procedure ItemRename;
    // ショートカット用キー降下イベント
    procedure OnListKeyDown(Sender: TObject;var Key: Word; Shift: TShiftState);
  public
    { Public 宣言 }
    // 一覧フレームを初期化する。
    constructor Create(AOwner: TComponent); override;
    // 一覧フレームを破棄する。
    destructor Destroy;override;
    // 一覧フレームを表示する。
    procedure Show;
    // 起動中状態を再判定して一覧表示を更新する。
    procedure RefreshRunningStates;
    // ドロップされたファイルをランチャー一覧へ登録する。
    function DropFiles(const Files: TArray<string>) : Boolean;
    property ListView : TLauncherListView read FListView;
    property OnAddRequest: TLauncherListRequestEvent read FOnAddRequest write FOnAddRequest;
  end;

implementation

uses AviUtl2StyleColors;

{$R *.dfm}

{ TFrameLauncherList }

constructor TFrameLauncherList.Create(AOwner: TComponent);
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

  FListView := TLauncherListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.PopupMenu := MenuPopup;
  FListView.Color := A2SCListViewBackground;
  FListView.Font.Color := A2SCListViewText;
  FListView.OnKeyDown := OnListKeyDown;

  FShortcuts   := TShortcutAction.Create;
  FShortcuts.Add(VK_UP  ,[ssCtrl],FListView.ItemUp);
  FShortcuts.Add(VK_DOWN,[ssCtrl],FListView.ItemDown);
  //FShortcuts.Add(Ord('D'),[ssCtrl],ItemEntry);
  //FShortcuts.Add(Ord('C'),[ssCtrl],FListView.ItemCopy);
  FShortcuts.Add(VK_F2,[],ItemReName);
  //FShortcuts.Add(VK_DELETE,[],FListView.ItemDelete);

end;

destructor TFrameLauncherList.Destroy;
begin
  FShortcuts.Free;
  FListView.Free;
  FToolBar.Free;
  inherited;
end;

function TFrameLauncherList.DropFiles(const Files: TArray<string>): Boolean;
begin
  Result := FListView.AddFiles(Files) > 0;
end;

procedure TFrameLauncherList.ItemDelete;
begin
  FListView.RemoveSelected;
end;

procedure TFrameLauncherList.ItemEntry;
begin
  if Assigned(FOnAddRequest) then FOnAddRequest(Self);
end;

procedure TFrameLauncherList.ItemRename;
begin
  FListView.BeginRenameSelected;
end;

procedure TFrameLauncherList.MenuAppAddClick(Sender: TObject);
begin
  ItemEntry;
end;

procedure TFrameLauncherList.MenuAppDeleteClick(Sender: TObject);
begin
  ItemDelete;
end;

procedure TFrameLauncherList.MenuAppRenameClick(Sender: TObject);
begin
  ItemRename;
end;

procedure TFrameLauncherList.MenuItemDownClick(Sender: TObject);
begin
  FListView.ItemDown;
end;

procedure TFrameLauncherList.MenuItemUpClick(Sender: TObject);
begin
  FListView.ItemUp;
end;

procedure TFrameLauncherList.OnListKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  FShortcuts.KeyDown(Key,Shift);
end;

procedure TFrameLauncherList.RefreshRunningStates;
begin
  FListView.RefreshRunningStates;
end;

procedure TFrameLauncherList.Show;
begin
  inherited Show;
  RefreshRunningStates;
  ShowToolBar;
end;

procedure TFrameLauncherList.ShowToolBar;
begin
  if FToolBar.Tag = 0 then begin
    FToolBar.AddIcon('アプリを登録',0,ItemEntry);
    //FToolBar.AddIcon('立ち絵設定をコピー',1,FListView.ItemCopy);
    FToolBar.AddIcon('アプリの登録を解除',1,ItemDelete);
    FToolBar.AddIcon('アプリ名の変更',2,ItemRename);
    FToolBar.AddIcon('上に移動',3,FListView.ItemUp);
    FToolBar.AddIcon('下に移動',4,FListView.ItemDown);
    FToolBar.Tag := 1;
  end;

end;

end.
