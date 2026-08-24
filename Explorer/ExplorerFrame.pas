unit ExplorerFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,RTTIPersistentFrame,ListViewThumbnail,
  Vcl.StdCtrls, Vcl.ExtCtrls,ExplorerFileList,ExplorerHistFrame,ExplorerHist,
  ExplorerListViewFrame,DropFile,ConfigPanel,ListViewRTTI,ExplorerFolderList,ToolBarPanelManager,ExplorerTreeFrame,
  Vcl.ComCtrls, Vcl.ToolWin;


type
  TFrameExplorerBound = class(TRTTIFrame)
  private
    FPictureZoomIndex  : Integer;
    FPanelConfigHeight : Integer;
    FPanelHistHeight   : Integer;
    FHistIndex         : Integer;
  public
    constructor Create;
    // フォームの座標情報をデータ化
    procedure FrameToSelf(AFrame : TFrame);override;
    // データをフォームの情報に復元
    procedure SelfToFrame(AFrame : TFrame);override;
  published
    property PictureZoomIndex  : Integer read FPictureZoomIndex  write FPictureZoomIndex;
    property PanelHistHeight  : Integer read FPanelHistHeight  write FPanelHistHeight;
    property PanelConfigHeight  : Integer read FPanelConfigHeight  write FPanelConfigHeight;
    property HistIndex : Integer read FHistIndex write FHistIndex;
  end;


type
  TFrameExplorer = class(TFrame)
    PanelFavorite: TPanel;
    TimerDandD: TTimer;
    PanelConfig: TPanel;
    Splitter1: TSplitter;
    PanelExplorer: TPanel;
    Splitter2: TSplitter;
    PanelTool: TPanel;
    ToolBar1: TToolBar;
    tbFavorite: TToolButton;
    tbTree: TToolButton;
    PanelTree: TPanel;
    PanelEdit: TPanel;
    procedure TimerDandDTimer(Sender: TObject);
  private
    { Private 宣言 }
    FBound          : TFrameExplorerBound;              // ズ記憶クラス

    FFrameFavorite  : TFrameExplorerHist;           // お気に入りリスト
    FFrameTree      : TFrameExplorerTree;           // フォルダツリー
    FFrameExplorer  : TFrameExplorerListView;       // フォルダ内のファイル表示リスト

    FFolderName     : string;
    FHists          : TExplorerHistList;
    FTBarManager   : TToolBarPanelManager;        // ツールバーによるページコントロール

    FDandDDisable   : Boolean;
    FPaneConfig     : TConfigPanel;           // 設定画面
    FShowed         : Boolean;

    procedure HistAddFolder(AFolder : string);
    procedure ShowConfig;

    procedure OnToolBarChange(Sender: TObject; Index: Integer);
    procedure OnHistClick(Sender : TObject;const FolderName : string);
    procedure OnHistDelete(Sender : TObject;const FolderName : string);
    procedure OnHistFolderOpen(Sender : TObject;const FolderName : string);

    procedure OnTreeFolderSelect(Sender: TObject);

    // フォルダオープン
    //procedure OnHistFolderOpen(Sender : TObject; AFolder : string);
    procedure OnExplorerClick(Sender : TObject;Item : TExplorerFileItem);
    // 表示レイアウト変更
    procedure OnExplorerStyleChange(Sender : TObject;const FolderName : string;const Style : Integer);
    procedure OnExplorerDataChange(Sender : TObject);
    // 拡大縮小率変更
    procedure OnExplorerZoomChange(Sender : TObject;ZoomIndex : Integer);
    // フォルダオープン
    procedure OnExplorerFolderOpen(Sender : TObject; AFolder : string);
    // 設定変更イベント
    procedure OnConfigChange(Sender: TObject);
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure Show;
    // ファイルドロップイベント
    procedure DropFile(const FileNames: TArray<string>);
  end;

procedure ExplorerAliasCopy(const Alias : string);


implementation

{$R *.dfm}

uses AppFolderUtils,Winapi.ShlObj,Winapi.KnownFolders,Winapi.ActiveX,
     AviUtl2StyleColors,ExplorerListPicture,ExplorerListSound,ExplorerListAlias,
     ExplorerListNormal;

{ TFrameExplorer }

constructor TFrameExplorer.Create(AOwner: TComponent);
var
  s : string;
begin
  inherited;

  s :=  GetAppFolder('Explorer');
  FBound := TFrameExplorerBound.Create;
  FBound.Filename  := s +  'ExplorerFrame.ini';       // Windows状態保存ファイル名設定
  FBound.LoadFromFile;

  FTBarManager := TToolBarPanelManager.Create();
  FTBarManager.ToolBarBackgroundColor := A2SCToolBarBackground;
  FTBarManager.ToolBarFontColor := A2SCToolBarFont;
  FTBarManager.ToolBarCheckedColor := A2SCToolBarChecked;
  FTBarManager.ToolBarPressedColor := A2SCToolBarPressed;
  FTBarManager.ToolBarHotColor := A2SCToolBarHot;
  FTBarManager.OnChange := OnToolBarChange;

  ToolBar1.Color := A2SCToolBarBackground;
  FHists := TExplorerHistList.Create;
  FHists.Filename  := s + 'ExplorerHist.Ini';
  FHists.LoadFromFile();

  FFrameFavorite := TFrameExplorerHist.Create(Self);
  FFrameFavorite.Parent := PanelFavorite;
  FFrameFavorite.Align := alClient;
  FFrameFavorite.OnListClick := OnHistClick;
  FFrameFavorite.OnListDelete := OnHistDelete;
  FFrameFavorite.OnFolderOpen := OnHistFolderOpen;

  FFrameTree := TFrameExplorerTree.Create(Self);            // TODO : ツリー表示追加
  FFrameTree.Parent := PanelTree;
  FFrameTree.Align := alClient;
  FFrameTree.OnFolderSelect := OnTreeFolderSelect;

  FFrameExplorer := TFrameExplorerListView.Create(Self);
  FFrameExplorer.Parent := PanelExplorer;
  FFrameExplorer.Align := alClient;
  FFrameExplorer.OnListClick := OnExplorerClick;
  FFrameExplorer.OnStyleChange := OnExplorerStyleChange;
  FFrameExplorer.OnDataChange := OnExplorerDataChange;
  FFrameExplorer.OnZoomChange := OnExplorerZoomChange;
  FFrameExplorer.OnFolderOpen := OnExplorerFolderOpen;

  FPaneConfig := TConfigPanel.Create(Self);
  FPaneConfig.Parent := PanelConfig;
  FPaneConfig.Align := alClient;
  FPaneConfig.Font.Height := -12;
  FPaneConfig.ListView.ItemHeight := 24;
  FPaneConfig.ListViewColor := A2SCListViewBackground;
  FPaneConfig.OnChange := OnConfigChange;

end;

destructor TFrameExplorer.Destroy;
begin
  FTBarManager.Free;

  FBound.FrameToSelf(Self);                           // 状態をデータ化
  FBound.SaveToFile;

  FPaneConfig.Free;
  FFrameFavorite.Free;
  FFrameExplorer.Free;
  FFrameTree.Free;
  FHists.Free;
  FBound.Free;
  inherited;
end;


function GetPicturesFolder: string;
var
  Path: PWideChar;
begin
  Result := '';
  if Succeeded(SHGetKnownFolderPath(FOLDERID_Pictures, 0, 0, Path)) then
  try
    Result := Path;
  finally
    CoTaskMemFree(Path);
  end;
end;

procedure TFrameExplorer.Show;
var
  i : Integer;
  s: string;
  Hist : TExplorerHistItem;
begin


  if FShowed then Exit;                     // DONE: 描画を初回のみに限定し高速化

  FBound.SelfToFrame(Self);
  //FormVisibleExplorer := True;

  if FHists.Count = 0 then begin                      // 履歴にドルだが1個も無ければ
    Hist := FHists.AddHist(GetPicturesFolder());      // 履歴に追加　表示スタイルの自動判定
    Hist.Style := 3;                                  // エリアスフォルダに設定
    FHists.SaveToFile();                              // 履歴リスト保存
  end;

  if FHists.IndexOfStyle(3) = -1 then begin           // エリアスフォルダがない場合
    s :=  GetAppFolder('Alias');                      // エリアスフォルダを指定
    FHists.AddHist(s);                                // 履歴に追加
    FHists.SaveToFile();                              // 履歴リスト保存
  end;

  FFrameFavorite.ShowList(FHists);                        // 履歴表示に反映

  FFrameExplorer.PictureZoomIndex := FBound.FPictureZoomIndex;

  if not FTBarManager.Attached then
  begin
    FTBarManager.AddPanel(PanelFavorite);
    FTBarManager.AddPanel(PanelTree);
    FTBarManager.Attach(ToolBar1);
  end;

  i := FBound.HistIndex;
  // 保存済み履歴インデックスが有効なときだけ前回選択を復元する
  if (i >= 0) and (i < FHists.Count) and (FHists.Count > 0) then begin    // TODO : 前回保存時の位置に移動
    FFrameFavorite.ItemIndex := i;
    FFolderName := FHists[i].FolderName;
    FFrameExplorer.ShowList(FHists[i]);               // 前回の履歴を表示
  end
  else if FHists.Count > 0 then begin                      // 履歴が1件以上ある場合
    FFrameFavorite.ItemIndex := 0;
    FFolderName := FHists[0].FolderName;
    FFrameExplorer.ShowList(FHists[0]);               // 1件目の履歴を表示
  end;
  inherited Show;
  FShowed := True;

end;

procedure TFrameExplorer.ShowConfig;
var
  Style : Integer;
  FileItem : TExplorerFileItem;
  lv : TListViewRTTI;
begin
  FileItem := FFrameExplorer.GetSelectItem;
  if FileItem = nil then Exit;

  Style := FFrameFavorite.GetItemStyle;
  if Style > 0 then begin
    lv := FPaneConfig.ListView;
    lv.Clear;
    case Style of
      1 :  ExplorerConfigPictureShow(lv,FileItem);   // 画像用設定画面
      2 :  ExplorerConfigSoundShow(lv,FileItem);     // 音声用設定画面
      3 :  ExplorerConfigAliasShow(lv,FileItem);     // エリアス用設定画面
    end;
    FPaneConfig.ShowConfig(FileItem);
    lv.FixedWidth := 120;
    PanelConfig.Visible := True;
    Splitter1.Top := PanelConfig.Top - Splitter1.Height -1;
  end;
end;


procedure TFrameExplorer.TimerDandDTimer(Sender: TObject);
begin
  TimerDandD.Enabled := False;
  FDandDDisable := False;
end;

procedure TFrameExplorer.HistAddFolder(AFolder: string);
var
  i : Integer;
  Hist : TExplorerHistItem;
begin
  if AFolder = '' then Exit;                                       // フォルダで無ければ処理しない

  i := FHists.IndexOfFolderName(AFolder);                          // すでに登録されているか？
  if i <> -1 then begin                                            // 登録されている場合
    Hist := FHists[i];                                             // 履歴を参照
    FFrameFavorite.SetSelectFolder(Hist.FolderName);               // 履歴のカーソル位置を合わせる
    FFrameExplorer.ShowList(Hist);                                 // フォルダ内のファイルを表示
    Exit;
  end;

  FHists.AddHist(AFolder);                                         // 履歴に追加
  FHists.SaveToFile();

  FFrameFavorite.ShowList(FHists);                                 // 履歴表示に反映
  // 追加したフォルダ名で履歴選択を同期する
  FFrameFavorite.SetSelectFolder(AFolder);                         // 履歴のカーソル位置を合わせる

  i := FHists.IndexOfFolderName(AFolder);                          // 履歴の追加された位置を探す
  if I = -1 then Exit;                                             // 見つからない場合は処理しない
  Hist := FHists[i];                                               // 履歴を参照
  FFrameExplorer.ShowList(Hist);                                   // フォルダ内のファイルを表示
end;

procedure ExplorerAliasCopy(const Alias : string);
var
  Folder, FileName : string;
  SL   : TStringList;
  Utf8 : TEncoding;
begin
  Folder   := GetAppFolder('Alias');
  FileName := Folder + FormatDateTime('yyyymmddhhnnsszzz', Now) + '.object';

  // ★ BOMなし UTF-8 を明示生成
  Utf8 := TUTF8Encoding.Create(False);  // emitBOM = False
  try
    SL := TStringList.Create;
    try
      SL.Text := Alias;
      SL.SaveToFile(FileName, Utf8);    // ← ここが重要
    finally
      SL.Free;
    end;
  finally
    Utf8.Free;
  end;
end;


procedure TFrameExplorer.OnConfigChange(Sender: TObject);
begin
  FFrameExplorer.Explorer.SaveToFile();
end;

procedure TFrameExplorer.DropFile(const FileNames: TArray<string>);
var
  s,Folder : string;
begin
  if FDandDDisable then Exit;                                     // 自分自身へのドロップ禁止

  Folder := '';
  if Length(FileNames) > 0 then s := FileNames[0] else s := '';   // ファイル1つ取得
  if ExtractFileExt(s) = '.object'then Exit;

  if DirectoryExists(s) then begin                                // フォルダなら
     Folder := s;                                                 // フォルダとする
  end
  else if FileExists(s) then begin                                // ファイルの場合
    s := ExtractFilePath(s);                                      // ファイルのフォルダを取得
    Folder := s;                                                  // フォルダを開く
  end;

  HistAddFolder(Folder);
end;

procedure TFrameExplorer.OnExplorerClick(Sender: TObject;
  Item: TExplorerFileItem);
begin
  ShowConfig;
end;

procedure TFrameExplorer.OnExplorerDataChange(Sender: TObject);
begin

end;

procedure TFrameExplorer.OnExplorerFolderOpen(Sender: TObject; AFolder: string);
begin
  HistAddFolder(AFolder);
end;

procedure TFrameExplorer.OnExplorerStyleChange(Sender: TObject;const FolderName : string;const Style : Integer);
var
  i : Integer;
  Hist : TExplorerHistItem;
begin
  FDandDDisable := True;
  TimerDandD.Enabled := False;                                    // ドロップ判定防止タイマー
  TimerDandD.Enabled := True;
  i := FHists.IndexOfFolderName(FolderName);
  if i = -1 then Exit;
  Hist := FHists[i];                                              // 履歴を参照
  Hist.Style := Style;
  FFrameFavorite.ViewList;
  FHists.SaveToFile();
end;

procedure TFrameExplorer.OnExplorerZoomChange(Sender: TObject;
  ZoomIndex: Integer);
begin
  FBound.FPictureZoomIndex := ZoomIndex;
end;

procedure TFrameExplorer.OnHistClick(Sender: TObject; const FolderName: string);
var
  i : Integer;
  Hist : TExplorerHistItem;
begin
  PanelConfig.Visible := False;
  TimerDandD.Enabled := False;
  FDandDDisable := True;
  TimerDandD.Enabled := True;
  i := FHists.IndexOfFolderName(FolderName);                      // 履歴の追加された位置を探す
  if i = -1 then Exit;                                            // 見つからない場合は処理しない
  Hist := FHists[i];                                              // 履歴を参照
  FFolderName := Hist.FolderName;
  FFrameExplorer.ShowList(Hist);                                  // フォルダ内のファイルを表示
  FBound.HistIndex := i;
  FBound.SaveToFile;
end;

procedure TFrameExplorer.OnHistDelete(Sender: TObject;
  const FolderName: string);
begin
  FFrameExplorer.DeleteHistItem(FolderName);
end;

procedure TFrameExplorer.OnHistFolderOpen(Sender: TObject;  const FolderName: string);
begin
  HistAddFolder(FolderName);
end;

procedure TFrameExplorer.OnToolBarChange(Sender: TObject; Index: Integer);
begin
  case Index of
    1 : FFrameTree.ShowFolder(FFolderName);
  end;
end;

procedure TFrameExplorer.OnTreeFolderSelect(Sender: TObject);
var
  i : Integer;
  FolderName : string;
  Hist : TExplorerHistItem;
begin
  PanelConfig.Visible := False;
  TimerDandD.Enabled := False;
  FDandDDisable := True;
  TimerDandD.Enabled := True;
  FolderName := FFrameTree.SelectFolder;
  i := FHists.IndexOfFolderName(FolderName);                      // 履歴の追加された位置を探す
  if i = -1 then begin;                                            // 見つからない場合は処理しない
    Hist := FHists.AddHist(FolderName);
    FHists.SaveToFile();
    FFrameFavorite.ViewList;
    // ツリーから新規追加した履歴のインデックスを取り直す
    i := FHists.IndexOfFolderName(FolderName);
  end
  else begin
    Hist := FHists[i];                                              // 履歴を参照
  end;
  // ツリー選択後は履歴リスト側の選択位置も合わせる
  FFrameFavorite.SetSelectFolder(FolderName);
  FFolderName := Hist.FolderName;
  FFrameExplorer.ShowList(Hist);                                  // フォルダ内のファイルを表示
  FBound.HistIndex := i;
  FBound.SaveToFile;
  FTBarManager.Activate(0);
end;

{ TFrameExplorerBound }

constructor TFrameExplorerBound.Create;
begin
  FPictureZoomIndex  := 1;
end;

procedure TFrameExplorerBound.FrameToSelf(AFrame: TFrame);
begin
  FPanelHistHeight   := TFrameExplorer(AFrame).PanelFavorite.Height;
  FPanelConfigHeight := TFrameExplorer(AFrame).PanelConfig.Height;
  FPictureZoomIndex := TFrameExplorer(AFrame).FFrameExplorer.PictureZoomIndex;
end;

procedure TFrameExplorerBound.SelfToFrame(AFrame: TFrame);
begin
  if FPanelHistHeight <> 0 then TFrameExplorer(AFrame).PanelFavorite.Height :=  FPanelHistHeight;
  if FPanelConfigHeight <> 0 then TFrameExplorer(AFrame).PanelConfig.Height :=  FPanelConfigHeight;
  TFrameExplorer(AFrame).FFrameExplorer.PictureZoomIndex := FPictureZoomIndex;
end;

end.

