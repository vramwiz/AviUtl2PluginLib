unit SerifFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,RTTIPersistentFrame,SerifProjectFrame,SerifProject,
  Vcl.ComCtrls,SerifSceneFrame,SerifSceneList,SerifCharaList,SerifWatcherList,
  SerifWatcherFrame,SerifMonitorFrame,SerifWindowWatcher,SerifWindowWatchTarget,SerifAnalyzer,SerifSceneMsgList,
  SerifCharaListFrame,SerifConfig,SerifConfigFrame,SerifAliasFrame,SerifScenarioFrame,
  SerifScenarioCharaList,SerifScenarioMsgList, Vcl.ToolWin,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ImgList, ToolBarPanelManager,SerifBoardFrame,SerifVoicevoxSimpleInputFrame,
  SerifVoicevoxAudioSettings,AviUtl2Serif,SerifDrawFrame;

type
  TFrameSerifBound = class(TRTTIFrame)
  private
    FWatchState: TSerifWatchState;
  public
    constructor Create;
    // フォームの座標情報をデータ化
    procedure FrameToSelf(AFrame : TFrame);override;
    // データをフォームの情報に復元
    procedure SelfToFrame(AFrame : TFrame);override;
  published
    property WatchState : TSerifWatchState read FWatchState write FWatchState;
  end;

type
  TFrameSerifCursorFocusEvent = TFrameSerifSceneCursorFocusEvent;

type
  TFrameSerif = class(TFrame)
    PanelClient: TPanel;
    PanelChara: TPanel;
    PanelConfig: TPanel;
    PanelProject: TPanel;
    PanelScenario: TPanel;
    PanelSerif: TPanel;
    PanelMonitor: TPanel;
    ToolBar1: TToolBar;
    tbProject: TToolButton;
    tbScenario: TToolButton;
    tbSerif: TToolButton;
    tbChara: TToolButton;
    tbConfig: TToolButton;
    tbNewText: TToolButton;
    tbView: TToolButton;
    PanelView: TPanel;
    tbBoard: TToolButton;
    PanelBoard: TPanel;
    PanelDraw: TPanel;
  private
    { Private 宣言 }
    FBound          : TFrameSerifBound;             // Windows位置とサイズ記憶クラス
    FProjects       : TSerifProjectList;            // プロジェクトリスト　名称とファイルのみ
    FScenes         : TSerifSceneList;              // シーンリスト プロジェクトリストのファイル名から
    FCharas         : TSerifCharaList;              // 配役リスト
    FWatchers       : TSerifWatcherList;            // 音声合成アプリ監視
    FCommonWatchers : TSerifWatcherList;            // 共通監視設定
    FWindowWatcher  : TSerifWindowWatcher;          // 音声合成アプリの補助ウィンドウ監視
    FAnalyzer       : TSerifAnalyzer;               // 音声号アプリ出力データ解析クラス
    FConfig         : TSerifConfigItem;             // セリフ用の設定クラス
    FMsgs           : TSerifSceneMsgList;           // 追加するセリフクラス
    FScenarioCharas : TSerifScenarioCharaList;      // 脚本配役クラス
    FScenarioMsgs   : TSerifScenarioMsgList;        // 脚本セリフクラス
    FSceneID        : Integer;
    FFormVisibleSerif: Boolean;                      // True:フォーム表示中

    FTBarManager    : TToolBarPanelManager;         // ツールバーによるページコントロール
    FToolbarImages  : TImageList;                   // DPIに合わせて生成するページ選択アイコン
    FFrameProject   : TFrameSerifProject;           // 台本プロジェクトリスト
    FFrameScene     : TFrameSerifScene;             // シーンとセリフリスト表示フレーム
    FFrameInput     : TFrameSerifVoicevoxSimpleInput; // 1行常時編集のVOICEVOX入力フレーム
    FSplitterInput  : TSplitter;                      // VOICEVOX入力とセリフ一覧の高さ調整
    FFrameChara     : TFrameSerifCharaList;         // 配役一覧表示設定フレーム
    FFrameWatcher   : TFrameSerifWatcher;           // 監視フォルダリスト
    FFrameMonitor   : TFrameSerifMonitor;           // フォルダ監視開始停止フレーム
    FVoicevoxStatusLabel: TLabel;                    // 監視欄右側のVOICEVOX状態表示
    FFrameConfig    : TFrameSerifConfig;            // 環境設定フレーム
    FFrameDraw      : TFrameSerifDraw;              // 新セリフ表示オブジェクト送信フレーム
    FFrameAlias     : TFrameSerifAlias;             // セリフ表示オブジェクト送信フレーム
    FFrameBoard     : TFrameSerifBoard;             // 表示枠背景オブジェクト送信フレーム
    FFrameScenario  : TFrameSerifScenario;          // シナリオ作成フレーム

    FSelectFolder   : string;
    FTemporaryLock  : TFileStream;                  // 未保存プロジェクトの作業台本を他プロセスから保護する
    FTabIndexOld    : Integer;                      // タブの変化を見るための以前の値
    FOnMoveCursorFocus: TFrameSerifCursorFocusEvent;
    procedure ApplyDpi;
    procedure UpdateToolbarIcons;
    procedure ResetConfig;
    procedure ApplyCharaColorDefaults;
    // 指定されたフォルダのセリフプロジェクトを開く
    procedure ShowProjectFolder(folder : string);
    // AviUtl2プロジェクトに台本の関連付けがない時、現在の台本を安全に閉じる。
    procedure CloseProject;
    function EnsureAutomaticProject: Boolean;
    procedure ProcWatcher(State: TSerifWatchState);
    procedure TabView;
    procedure TabHide;
    procedure ShowTabHint(TabIndex : Integer);

    procedure OnToolBarChange(Sender: TObject; Index: Integer);
    procedure OnInputExpandedChange(Sender: TObject);
    procedure OnVoicevoxMoveEnd(Sender: TObject);
    procedure OnVoicevoxStatus(Sender: TObject; const StatusText: string);
    procedure OnProjectSelect(Sender: TObject; const Index : Integer);
    // 監視設定値変更イベント
    procedure OnWatcherChange(Sender: TObject);
    // 監視開始終了維持イベント
    procedure OnWatcherStartAndStop(Sender: TObject;const State : TSerifWatchState);
    // 監視フォルダ変化発生直後イベントこのあと待ち時間待機
    procedure OnWatcherWaitFiles(Sender: TObject);
    // 監視フォルダ変化イベント※引数はに出力されたファイル
    procedure OnWatcherDetecredFiles(Sender: TObject; Files: TStringList;var ErrLine : Integer);
    // シーン変更イベント
    procedure OnSceneChange(Sender: TObject);
    // 配役追加イベント
    procedure OnSceneCharaChange(Sender: TObject);
    procedure OnSceneMoveCursorFocus(Sender: TObject; Layer, Frame: Integer);
    // VOICEVOX生成結果を、F2再編集対象の更新または通常の新規セリフ追加として反映する。
    procedure OnVoicevoxSend(Sender: TObject;
      const Text: string; const SpeakerName: string; const StyleName: string;
      const AccentQueryJson: string; const StyleId: Integer;
      const AudioValues: TSerifVoicevoxAudioValues;
      const ReeditTarget: TSerifAviUtl2Selection;
      var ErrorMessage: string; var SavedUnsent: Boolean);
    // 配役情報変更イベント
    procedure OnCharaChange(Sender: TObject);
    // 配役名変更イベント
    procedure OnCharaRename(Sender: TObject; const OldName, Keyword, NewName: string);
    // 環境設定変更イベント
    procedure OnConfigChange(Sender: TObject);
    // 改行位置変更イベント
    procedure OnConfigEnterPosChange(Sender: TObject);
    // キャラベクターiniフォルダを探す
    function FindCharaVectorFolder: string;
    function GetIsStartd: Boolean;
    // 埋め込みメモからキャラベクターiniを展開する
    procedure RestoreBundledCharaVectorData;
    function HasConfiguredWatcherFolder: Boolean;
    procedure LoadCommonWatchers;
    procedure ApplyCommonWatchersToProjectWatchers;
    procedure SaveCommonWatchersFromProject;
    function GetCommonWatcherFileName: string;
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure Show;
    // AviUtl2プロジェクトの台本を開き、読込完了後の現在シーンへ表示を同期する。
    function SyncProjectAndScene: Boolean;
    // 初回保存時、作業台本を正式フォルダへ移して現在表示を切り替える。
    procedure PromoteTemporaryProject(const Folder, ProjectFilePath: string);
    // 別フォルダへの名前付き保存時、空の正式台本へ表示を切り替える。
    procedure SwitchToEmptyProject(const Folder, ProjectFilePath: string);
    // 初回保存時、使用中の自動台本をAviUtl2プロジェクト名で一覧へ登録する。
    procedure RegisterAutomaticProject(const Folder, ProjectFilePath: string);
    // AviUtl2プロジェクトに対応する音声合成設定フォルダを開く。
    procedure OpenSpeechSynthesisProject(const Folder: string);
    // AviUtl2保存処理に合わせ、音声合成設定の遅延保存を直ちに確定する。
    procedure SaveSpeechSynthesisProject;
    // ランチャーから検出された音声合成ソフトのメインウィンドウを補助監視へ渡す
    procedure SetLauncherSpeechAppWindow(AppKind: Integer; Wnd: HWND);
    // シーンを変更する
    procedure SceneChange(SceneID: Integer);
    // 指定されたフレーム　レイヤーのセリフをアクティブに
    procedure ActiveSerif(frame,layerTxt,layerWav : Integer;UID : string);
    // 1回だけ発火し、以降は選択オブジェクトに変化まで発火しない
    procedure FrameActive;
    // VOICEVOXの入力ページを表示中か返す。AviUtl2選択同期による自動画面切り替えの抑止に使う。
    function IsInputPageActive: Boolean;
    property IsStartd : Boolean read GetIsStartd;
    property OnMoveCursorFocus : TFrameSerifCursorFocusEvent read FOnMoveCursorFocus write FOnMoveCursorFocus;
  end;

implementation

{$R *.dfm}

uses  AppFolderUtils, System.IOUtils,AviUtl2PluginProject,AviUtl2PluginScene,AviUtl2StyleColors,MainToolInfoService,
      CharaAnalyzer,SerifCharaVectorResource,SerifVoicevoxApi,
      SerifVoicevoxDebugLog,SerifToolbarIcons;

const
  SERIF_WATCHER_COMMON_FILE_NAME = 'SerifWatcherCommon.ini';

function NormalizeSerifWatchState(State: TSerifWatchState): TSerifWatchState;
begin
  // swsWatch は旧設定ファイル互換用。現在の開始状態は流し込み有効の swsSend に統一する。
  if State = swsWatch then
    Result := swsSend
  else
    Result := State;
end;

function TFrameSerif.GetCommonWatcherFileName: string;
begin
  Result := GetAppFolder('Serif') + SERIF_WATCHER_COMMON_FILE_NAME;
end;

function TFrameSerif.HasConfiguredWatcherFolder: Boolean;
var
  i: Integer;
begin
  Result := False;
  if FWatchers = nil then Exit;
  for i := 0 to FWatchers.Count - 1 do
    if Trim(FWatchers[i].Folder) <> '' then Exit(True);
end;

procedure TFrameSerif.LoadCommonWatchers;
begin
  if FCommonWatchers = nil then Exit;
  FCommonWatchers.Clear;
  FCommonWatchers.Filename := GetCommonWatcherFileName;
  if FileExists(FCommonWatchers.Filename) then
    FCommonWatchers.LoadFromFile;
end;

procedure TFrameSerif.ApplyCommonWatchersToProjectWatchers;
var
  i: Integer;
begin
  if FWatchers = nil then Exit;
  if HasConfiguredWatcherFolder then Exit;

  LoadCommonWatchers;
  if FCommonWatchers.Count = 0 then Exit;

  if FWatchers.Count = 0 then
  begin
    FWatchers.Assign(FCommonWatchers);
    Exit;
  end;

  for i := 0 to FWatchers.Count - 1 do
  begin
    if Trim(FWatchers[i].Folder) <> '' then Continue;
    if i >= FCommonWatchers.Count then Break;
    if Trim(FCommonWatchers[i].Folder) = '' then Continue;
    FWatchers[i].Folder := FCommonWatchers[i].Folder;
  end;
end;

procedure TFrameSerif.SaveCommonWatchersFromProject;
var
  i: Integer;
  CommonItem : TSerifWatcherItem;
begin
  if FCommonWatchers = nil then Exit;
  FCommonWatchers.Clear;
  FCommonWatchers.Filename := GetCommonWatcherFileName;

  for i := 0 to FWatchers.Count - 1 do
  begin
    if Trim(FWatchers[i].Folder) = '' then Continue;

    CommonItem := FCommonWatchers.AddNew as TSerifWatcherItem;
    CommonItem.Name := FWatchers[i].Name;
    CommonItem.Folder := FWatchers[i].Folder;
    CommonItem.DelaySec := FWatchers[i].DelaySec;
  end;

  if FCommonWatchers.Count > 0 then
    FCommonWatchers.SaveToFile
  else if FileExists(FCommonWatchers.Filename) then
    try
      TFile.Delete(FCommonWatchers.Filename);
    except
      // 共有中などで削除できない場合は共通設定の維持に任せる
    end;
end;

{ TFrameSerif }

constructor TFrameSerif.Create(AOwner: TComponent);
var
  I: Integer;
begin
  VoicevoxDebugLog('SerifFrame.Create enter');
  inherited;
  RestoreBundledCharaVectorData;

  // Captionは操作名とヒントに残し、画面上はVOICEVOXと同系統のアイコンだけを表示する。
  FToolbarImages := TImageList.Create(Self);
  ToolBar1.ShowCaptions := False;
  ToolBar1.ShowHint := True;
  for I := 0 to ToolBar1.ButtonCount - 1 do
  begin
    ToolBar1.Buttons[I].Hint := ToolBar1.Buttons[I].Caption;
    ToolBar1.Buttons[I].ShowHint := True;
  end;
  FBound := TFrameSerifBound.Create;
  FBound.Filename  := GetAppFolder('Serif') +  'SerifFrame.ini';       // Windows状態保存ファイル名設定
  FBound.LoadFromFile;

  FProjects := TSerifProjectList.Create(GetAppFolder('Serif'),'SerifProject.Ini');
  // フォルダと同期を取る
  FProjects.SyncProjectFolders;

  FScenes   := TSerifSceneList.Create;
  FCharas   := TSerifCharaList.Create;
  FWatchers := TSerifWatcherList.Create;
  FWatchers.OnDetectedFiles := OnWatcherDetecredFiles;
  FWatchers.OnWaitFiles := OnWatcherWaitFiles;
  FCommonWatchers := TSerifWatcherList.Create;
  FWindowWatcher := TSerifWindowWatcher.Create;
  FAnalyzer := TSerifAnalyzer.Create;
  FConfig := TSerifConfigItem.Create;
  FMsgs := TSerifSceneMsgList.Create;
  FSceneID := -1;
  FTemporaryLock := nil;
  CleanupOrphanTemporarySerifProjects;

  FTabIndexOld := -1;                    // 初回を変化とするため存在しない値をセット

  FScenarioCharas := TSerifScenarioCharaList.Create;
  FScenarioCharas.Filename  := GetAppFolder('Serif') +  'ScenarioChara.ini';
  FScenarioCharas.LoadFromFile();

  FScenarioMsgs   := TSerifScenarioMsgList.Create;
  FScenarioMsgs.Filename  := GetAppFolder('Serif') +  'ScenarioMsg.ini';
  FScenarioMsgs.LoadFromFile();

  FTBarManager := TToolBarPanelManager.Create();
  FTBarManager.ToolBarBackgroundColor := A2SCToolBarBackground;
  FTBarManager.ToolBarFontColor := A2SCToolBarFont;
  FTBarManager.ToolBarCheckedColor := A2SCToolBarChecked;
  FTBarManager.ToolBarPressedColor := A2SCToolBarPressed;
  FTBarManager.ToolBarHotColor := A2SCToolBarHot;
  FTBarManager.ShowCaptions := False;
  FTBarManager.OnChange := OnToolBarChange;
  FTBarManager.AddPanel(PanelSerif);
  FTBarManager.AddPanel(PanelChara);
  FTBarManager.AddPanel(PanelConfig);
  FTBarManager.AddPanel(PanelDraw);
  FTBarManager.AddPanel(PanelView);
  FTBarManager.AddPanel(PanelBoard);
  FTBarManager.AddPanel(PanelScenario);
  FTBarManager.AddPanel(PanelProject);

  FFrameProject := TFrameSerifProject.Create(Self);
  //FFrameProject.Parent := tsProject;
  FFrameProject.Parent := PanelProject;
  FFrameProject.Align := alClient;
  FFrameProject.Projects := FProjects;
  FFrameProject.OnProjectOpen := OnProjectSelect;
  //FFrameProject.OnProjectCopy := OnProjectCopy;

  FFrameScenario := TFrameSerifScenario.Create(Self);
  //FFrameScenario.Parent := tsScenario;
  FFrameScenario.Parent := PanelScenario;
  FFrameScenario.Align := alClient;


  FFrameScene := TFrameSerifScene.Create(Self);
  //FFrameScene.Parent := tsSerif;
  FFrameScene.Parent := PanelSerif;
  FFrameScene.Align := alClient;
  FFrameScene.OnChange := OnSceneChange;
  FFrameScene.OnCharaChange := OnSceneCharaChange;
  // 2026-04: SceneFrame のカーソル移動通知を最上位へ中継する
  FFrameScene.OnMoveCursorFocus := OnSceneMoveCursorFocus;

  VoicevoxDebugLog('SerifFrame.Create creating SimpleInputFrame');
  FFrameInput := TFrameSerifVoicevoxSimpleInput.Create(Self);
  // 独立した入力ページではなく、セリフ一覧の上部へ折り畳み表示する。
  FFrameInput.Parent := PanelSerif;
  FFrameInput.Align := alTop;
  FFrameInput.Top := 0;
  FFrameInput.OnSend := OnVoicevoxSend;
  FFrameInput.OnExpandedChange := OnInputExpandedChange;
  FFrameInput.OnMoveEnd := OnVoicevoxMoveEnd;
  FFrameInput.OnStatus := OnVoicevoxStatus;
  FFrameInput.BringToFront;

  FSplitterInput := TSplitter.Create(Self);
  FSplitterInput.Parent := PanelSerif;
  FSplitterInput.Align := alTop;
  FSplitterInput.Top := FFrameInput.Height;
  FSplitterInput.Height := MulDiv(5, CurrentPPI, 96);
  FSplitterInput.MinSize := MulDiv(210, CurrentPPI, 96);
  FSplitterInput.AutoSnap := False;
  FSplitterInput.Beveled := True;
  FSplitterInput.Color := A2SCToolBarBackground;
  FSplitterInput.Cursor := crVSplit;
  FSplitterInput.ResizeStyle := rsUpdate;
  FSplitterInput.Visible := FFrameInput.Expanded;
  FSplitterInput.BringToFront;
  VoicevoxDebugLog('SerifFrame.Create created SimpleInputFrame (API not prepared)');

  FFrameChara := TFrameSerifCharaList.Create(Self);
  //FFrameChara.Parent := tsChara;
  FFrameChara.Parent := PanelChara;
  FFrameChara.Align := alClient;
  FFrameChara.OnChange := OnCharaChange;
  // 棒読みちゃん対応: 配役Name変更をKeyword基準でセリフ一覧へ反映する。
  FFrameChara.OnRenameChara := OnCharaRename;

  FFrameWatcher := TFrameSerifWatcher.Create(Self);
  // 監視フォルダ設定は独立ページにせず、一般設定と同じページへまとめる。
  FFrameWatcher.Parent := PanelConfig;
  FFrameWatcher.Align := alClient;
  FFrameWatcher.OnChange := OnWatcherChange;

  FFrameMonitor := TFrameSerifMonitor.Create(Self);
  FFrameMonitor.Parent := PanelMonitor;
  FFrameMonitor.Align := alClient;
  FFrameMonitor.OnChange := OnWatcherStartAndStop;

  FVoicevoxStatusLabel := TLabel.Create(Self);
  FVoicevoxStatusLabel.Parent := FFrameMonitor.PanelBase;
  FVoicevoxStatusLabel.Align := alRight;
  FVoicevoxStatusLabel.Width := 0;
  FVoicevoxStatusLabel.Alignment := taCenter;
  FVoicevoxStatusLabel.AutoSize := False;
  FVoicevoxStatusLabel.Font.Color := $00D8E8FF;
  FVoicevoxStatusLabel.Layout := tlCenter;
  FVoicevoxStatusLabel.Transparent := True;

  FFrameConfig := TFrameSerifConfig.Create(Self);
  FFrameConfig.Parent := PanelConfig;
  FFrameConfig.Align := alTop;
  FFrameConfig.Height := MulDiv(100, CurrentPPI, 96);
  FFrameConfig.OnChange := OnConfigChange;
  FFrameConfig.OnEnterPosChange := OnConfigEnterPosChange;

  FFrameDraw := TFrameSerifDraw.Create(Self);
  FFrameDraw.Parent := PanelDraw;
  FFrameDraw.Align := alClient;

  FFrameAlias := TFrameSerifAlias.Create(Self);
  //FFrameAlias.Parent := tsAlias;
  FFrameAlias.Parent := PanelView;
  FFrameAlias.Align := alClient;

  FFrameBoard := TFrameSerifBoard.Create(Self);
  FFrameBoard.Parent := PanelBoard;
  FFrameBoard.Align := alClient;

  VoicevoxDebugLog('SerifFrame.Create leave');
end;

destructor TFrameSerif.Destroy;
var
  TemporaryFolder: string;
begin
  TemporaryFolder := '';
  if IsTemporarySerifProjectFolder(FSelectFolder) then
    TemporaryFolder := FSelectFolder;
  FBound.FrameToSelf(Self);                          // フォームの状態をデータ化
  FBound.SaveToFile;

  FFrameBoard.Free;
  FFrameAlias.Free;
  FFrameDraw.Free;
  FFrameConfig.Free;
  FFrameMonitor.Free;
  FFrameWatcher.Free;
  FFrameChara.Free;
  FSplitterInput.Free;
  FFrameInput.Free;
  FFrameScene.Free;
  FFrameScenario.Free;
  FFrameProject.Free;

  FTBarManager.Free;
  FScenarioMsgs.Free;
  FScenarioCharas.Free;
  FMsgs.Free;
  FConfig.Free;
  FAnalyzer.Free;
  FWindowWatcher.Free;
  FWatchers.Free;
  FCommonWatchers.Free;
  FCharas.Free;
  if FScenes.Filename<>'' then begin
    FScenes.SaveToFile();
  end;
  FScenes.Free;
  FTemporaryLock.Free;
  FTemporaryLock := nil;
  DeleteTemporarySerifProjectFolder(TemporaryFolder);
  FProjects.Free;
  FBound.Free;

  inherited;
end;

procedure TFrameSerif.FrameActive;
begin
  if FFrameScene = nil then Exit;
  FFrameScene.FrameActive;
end;

procedure TFrameSerif.ApplyDpi;
begin
  UpdateToolbarIcons;
  if Assigned(FFrameScene) then FFrameScene.ApplyDpi;
  if Assigned(FFrameConfig) then
    FFrameConfig.Height := MulDiv(100, CurrentPPI, 96);
  if Assigned(FFrameInput) then FFrameInput.ApplyDpi;
  if Assigned(FVoicevoxStatusLabel) then
  begin
    if FVoicevoxStatusLabel.Caption <> '' then
      FVoicevoxStatusLabel.Width := MulDiv(90, CurrentPPI, 96)
    else
      FVoicevoxStatusLabel.Width := 0;
    FVoicevoxStatusLabel.Font.Height := -MulDiv(13, CurrentPPI, 96);
  end;
  if Assigned(FSplitterInput) then
  begin
    FSplitterInput.Height := MulDiv(5, CurrentPPI, 96);
    FSplitterInput.MinSize := MulDiv(210, CurrentPPI, 96);
  end;
end;

procedure TFrameSerif.UpdateToolbarIcons;
var
  ButtonSize: Integer;
  IconSize: Integer;
begin
  if not Assigned(FToolbarImages) then Exit;

  // コンストラクタ中のSetImagesは、親ウィンドウ未接続のToolBarへ
  // ハンドル生成を要求してしまうため、表示直前のここで関連付ける。
  if ToolBar1.Images <> FToolbarImages then
    ToolBar1.Images := FToolbarImages;

  // 横幅の狭いドッキング時にも主要7ボタンが1行へ収まる寸法にする。
  ButtonSize := MulDiv(28, CurrentPPI, 96);
  IconSize := MulDiv(20, CurrentPPI, 96);
  ToolBar1.ButtonWidth := ButtonSize;
  ToolBar1.ButtonHeight := ButtonSize;
  BuildSerifToolbarIcons(FToolbarImages, IconSize, A2SCToolBarFont);
  ToolBar1.Invalidate;
end;

function TFrameSerif.FindCharaVectorFolder: string;
begin
  Result := GetAppFolder('Vector');
end;

function TFrameSerif.GetIsStartd: Boolean;
begin
  Result := FWatchers.IsStartd;
end;

function TFrameSerif.IsInputPageActive: Boolean;
begin
  Result := Assigned(FTBarManager) and (FTBarManager.ActiveIndex = 0) and
    Assigned(FFrameInput) and FFrameInput.Expanded;
end;

procedure TFrameSerif.RestoreBundledCharaVectorData;
begin
  RestoreSerifCharaVectorResourceToFolder(FindCharaVectorFolder);
end;

procedure TFrameSerif.Show;
var
  proj : TSerifProjectItem;
  WatchState: TSerifWatchState;
begin
  // 最上位フレームがAviUtl2またはフォームへ接続された後にだけ、
  // ClientWidthを使うVOICEVOX子フレームのDPI再配置を実行する。
  ApplyDpi;
  if FFormVisibleSerif then begin
    if not SyncProjectAndScene then Exit;
    // ShowProjectFolder で監視を止めるため、表示済みフレームでも復元状態を再適用する。
    WatchState := NormalizeSerifWatchState(FBound.WatchState);
    FBound.WatchState := WatchState;
    FFrameMonitor.WatchState := WatchState;
    ProcWatcher(WatchState);
    Exit;
  end;

  FBound.SelfToFrame(Self);
  FFormVisibleSerif := True;
  if FProjects.Count = 0 then begin
    proj := FProjects.ProjectAdd();
    proj.ProjectName := '新しいプロジェクト';
    FProjects.SaveToFile();
  end;

  FFrameProject.ShowList();
  FFrameMonitor.ShowStatus(FWatchers);
  FFrameScenario.ShowScenario(FScenarioCharas,FScenarioMsgs);

  TabHide;

  // Attachは未選択時に0番を自動表示するため、未関連付け時の内部ページを先に選んでおく。
  FTBarManager.ActiveIndex := 7;
  FTBarManager.Attach(ToolBar1);

  if not SyncProjectAndScene then Exit;
  // 以前の監視状態を復元
  // 旧 swsWatch が保存されていても、現在は流し込み開始の swsSend として再開する。
  WatchState := NormalizeSerifWatchState(FBound.WatchState);
  FBound.WatchState := WatchState;
  FFrameMonitor.WatchState := WatchState;
  ProcWatcher(WatchState);

  //FFrameBoard.Show;
end;

function TFrameSerif.SyncProjectAndScene: Boolean;
var
  Folder: string;
  SceneID: Integer;
begin
  Result := False;
  Folder := string(AviUtl2GetProjectString(AnsiString('SerifFolderName')));
  if Folder = '' then
  begin
    if not EnsureAutomaticProject then Exit;
    Folder := FSelectFolder;
  end;

  ShowProjectFolder(Folder);

  // 初回通知はフレーム生成前やProjectFile設定前に届くことがあるため、台本読込後に現在値を取得し直す。
  SceneID := AviUtl2SceneGetID;
  if SceneID >= 0 then
    FSceneID := SceneID;
  if FSceneID >= 0 then
    FFrameScene.SceneChange(FSceneID);
  Result := True;
end;

procedure TFrameSerif.SceneChange(SceneID: Integer);
var
  folder : string;
begin
  AviUtl2SerifResetContinuousSend;
  FSceneID := SceneID;
  // AviUtl2のプロジェクトファイルからセリフに使うフォルダ名取得
  folder := string(AviUtl2GetProjectString(AnsiString('SerifFolderName')));
  if folder = '' then
  begin
    if not EnsureAutomaticProject then Exit;
    folder := FSelectFolder;
  end;
  ShowProjectFolder(folder);
  FFrameScene.SceneChange(FSceneID);

end;

function TFrameSerif.EnsureAutomaticProject: Boolean;
var
  Folder: string;
  OldTemporaryFolder: string;
begin
  Result := False;
  if (Trim(FSelectFolder) <> '') and TDirectory.Exists(FSelectFolder) then
    Exit(True);

  OldTemporaryFolder := '';
  if IsTemporarySerifProjectFolder(FSelectFolder) then
    OldTemporaryFolder := FSelectFolder;
  CloseProject;
  FTemporaryLock.Free;
  FTemporaryLock := nil;
  DeleteTemporarySerifProjectFolder(OldTemporaryFolder);

  // 音声オブジェクトは作成時の絶対WAVパスを保持する。保存後に一時台本を
  // 別フォルダへ昇格すると参照先だけが一時領域に残るため、最初から恒久領域を使う。
  Folder := CreateAutomaticSerifProjectFolder;
  if Folder = '' then Exit;
  ShowProjectFolder(Folder);
  FScenes.SaveToFile;
  Result := True;
end;

procedure TFrameSerif.RegisterAutomaticProject(const Folder,
  ProjectFilePath: string);
var
  FolderName: string;
  Index: Integer;
begin
  FolderName := TPath.GetFileName(ExcludeTrailingPathDelimiter(Folder));
  FProjects.SyncProjectFolders;
  Index := FProjects.IndexOfFolder(FolderName);
  if Index >= 0 then
    FProjects[Index].ProjectName := TPath.GetFileNameWithoutExtension(ProjectFilePath);
  FProjects.SaveToFile;
  FFrameProject.ShowList;
end;

procedure TFrameSerif.PromoteTemporaryProject(const Folder,
  ProjectFilePath: string);
var
  TemporaryFolder: string;
begin
  if not IsTemporarySerifProjectFolder(FSelectFolder) then
  begin
    SwitchToEmptyProject(Folder, ProjectFilePath);
    Exit;
  end;

  TemporaryFolder := FSelectFolder;
  FWatchers.Stop;
  FFrameInput.CloseProject;
  if FScenes.Filename <> '' then FScenes.SaveToFile;
  FFrameScene.CloseList;

  if not PromoteTemporarySerifProject(TemporaryFolder, Folder) then Exit;

  FTemporaryLock.Free;
  FTemporaryLock := nil;
  DeleteTemporarySerifProjectFolder(TemporaryFolder);
  FSelectFolder := '';
  ShowProjectFolder(Folder);
  RegisterAutomaticProject(Folder, ProjectFilePath);
  SyncProjectAndScene;
end;

procedure TFrameSerif.SwitchToEmptyProject(const Folder,
  ProjectFilePath: string);
begin
  if Trim(Folder) = '' then Exit;
  CloseProject;
  ShowProjectFolder(Folder);
  FScenes.SaveToFile;
  FCharas.SaveToFile;
  FWatchers.SaveToFile;
  FConfig.SaveToFile;
  RegisterAutomaticProject(Folder, ProjectFilePath);
  SyncProjectAndScene;
end;

procedure TFrameSerif.CloseProject;
begin
  AviUtl2SerifResetContinuousSend;
  FWatchers.Stop;
  FFrameInput.CloseProject;

  // 遅延保存通知を止める前に、編集済みの旧台本を元のファイルへ保存する。
  if FScenes.Filename <> '' then
    FScenes.SaveToFile;
  FFrameScene.CloseList;

  FSelectFolder := '';
  FSceneID := -1;
  FScenes.Filename := '';
  FCharas.Filename := '';
  FWatchers.Filename := '';
  FConfig.Filename := '';

  FFrameMonitor.ShowStatus(FWatchers);
  TabHide;
  FTBarManager.Activate(7);
  FFrameProject.ShowList;
end;

procedure TFrameSerif.SetLauncherSpeechAppWindow(AppKind: Integer; Wnd: HWND);
begin
  if (AppKind < Ord(Low(TSerifSpeechAppKind))) or
     (AppKind > Ord(High(TSerifSpeechAppKind))) then
    Exit;

  FWindowWatcher.SetWatchTargetWindow(TSerifSpeechAppKind(AppKind), Wnd);
end;

procedure TFrameSerif.ActiveSerif(frame, layerTxt, layerWav: Integer;UID : string);
begin
  FFrameScene.ActiveSerif(frame,layerTxt,layerWav,UID);
end;


procedure TFrameSerif.ShowProjectFolder(folder: string);
var
  filename : string;
  Watcher : TSerifWatcherItem;
begin
  if folder <> FSelectFolder then begin
    AviUtl2SerifResetContinuousSend;
    filename := folder + 'Scene.ini';
    FScenes.Filename := filename;
    FScenes.LoadFromFile();

    filename := folder + 'Charas.ini';
    FCharas.Filename := filename;
    // 新規プロジェクトは ini がまだ無いので、前に開いたプロジェクトの配役を残さない
    if FileExists(filename) then
      FCharas.LoadFromFile()
    else
      FCharas.Clear;
    ApplyCharaColorDefaults;

    filename := folder + 'Watchers.ini';
    // 読み替え前に監視を止め、ini が無い場合は前プロジェクトの監視設定を破棄する
    FWatchers.Stop;
    FWatchers.Filename := filename;
    if FileExists(filename) then
      FWatchers.LoadFromFile()
    else
      FWatchers.Clear;
    ApplyCommonWatchersToProjectWatchers;

    if FWatchers.Count = 0 then begin
      Watcher := FWatchers.AddNew();
      Watcher.Name := '音声合成ソフト';
    end;

    filename := folder + 'Config.ini';
    // 設定ファイルが無い新規プロジェクトでは、前プロジェクトの設定値を引き継がない
    if FileExists(filename) then begin
      FConfig.Filename := filename;
      FConfig.LoadFromFile();
    end
    else begin
      ResetConfig;
      FConfig.Filename := filename;
    end;

    FFrameMonitor.ShowStatus(FWatchers);
    FFrameBoard.Show;
    FSelectFolder := folder;
  end;

  AviUtl2SetProjectString(AnsiString('SerifFolderName'), AnsiString(folder));
  TabView;
  FTBarManager.Activate(0);
end;

procedure TFrameSerif.OpenSpeechSynthesisProject(const Folder: string);
begin
  FFrameInput.OpenProject(Folder);
end;

procedure TFrameSerif.SaveSpeechSynthesisProject;
begin
  FFrameInput.SaveProjectSettings;
end;

procedure TFrameSerif.ApplyCharaColorDefaults;
var
  i: Integer;
  Chara: TSerifCharaItem;
  CharaName: string;
  ColorLight, ColorBase, ColorDark: TColor;
  ColorCharas: TSerifAnalyzerCharaList;
  Changed: Boolean;
begin
  if FCharas = nil then Exit;

  ColorCharas := TSerifAnalyzerCharaList.Create;
  try
    Changed := False;
    for i := 0 to FCharas.Count - 1 do
    begin
      Chara := FCharas[i];
      if Chara = nil then Continue;

      CharaName := Trim(Chara.Name);
      if CharaName = '' then
        CharaName := Trim(Chara.Keyword);

      // 配役色定義に存在する配役だけイメージカラーを上書きする。未定義の配役はユーザー設定を触らない。
      if not ColorCharas.TryGetCharaColors(CharaName, ColorLight, ColorBase, ColorDark) then
        Continue;

      if (Chara.ColorLight = ColorLight) and
         (Chara.ColorBase = ColorBase) and
         (Chara.ColorDark = ColorDark) then
        Continue;

      Chara.SetImageColors(ColorLight, ColorBase, ColorDark);
      Changed := True;
    end;

    // 自動補正で変化があった時だけ Charas.ini を保存する。
    if Changed then
      FCharas.SaveToFile;
  finally
    ColorCharas.Free;
  end;
end;

procedure TFrameSerif.ResetConfig;
begin
  FConfig.Free;
  FConfig := TSerifConfigItem.Create;
end;

procedure TFrameSerif.ShowTabHint(TabIndex: Integer);
begin
  if TabIndex = FTabIndexOld then Exit;
  FTabIndexOld := TabIndex;

  case TabIndex of
    0 : ShowMainToolInfo('リストからセリフを選択し編集や削除するとAviUtl2へ同期します。D&&Dでもセリフを送れます');
    1 : ShowMainToolInfo('キャラ毎に出力先レイヤーを指定すると流し込み先のレイヤーになります');
    2 : ShowMainToolInfo('改行位置、セリフ間隔、音声合成ソフトの監視フォルダを設定します');
    3 : ShowMainToolInfo('リストの「新セリフ表示」をAviUtl2へD&&Dします');
    4 : ShowMainToolInfo('セリフ表示オブジェクトをAviUtl2へ送信します。参照レイヤーにセリフがあると表示します');
    5 : ShowMainToolInfo('3分待つと表示されます。セリフの背景枠をAviUtl2へ送信します。同期を有効にするとセリフがあるときに表示します');
    6 : ShowMainToolInfo('VOICEROId AI.Voiceeなど「＞」でキャラ名を指定するアプリでテキストから「＞」付きのテキストが生成できます');
    7 : ShowMainToolInfo('動画1本毎に台本を1つ作ります。コピーするとセリフ以外の設定が引き継がれるので便利です');
  end;
end;

procedure TFrameSerif.TabView;
begin
  tbSerif.Visible    := True;
  tbChara.Visible    := True;
  tbConfig.Visible   := True;
  tbNewText.Visible  := True;
  tbView.Visible     := True;
  tbBoard.Visible    := True;
  tbScenario.Visible := True;
  // 他のボタンを表示してAutoSizeの高さを確定してから、台本ボタンだけを隠す。
  tbProject.Visible  := False;
end;

procedure TFrameSerif.TabHide;
begin
  tbSerif.Visible    := False;
  tbChara.Visible    := False;
  tbConfig.Visible   := False;
  tbNewText.Visible  := False;
  tbView.Visible     := False;
  tbBoard.Visible    := False;
  tbScenario.Visible := False;
  tbProject.Visible  := False;
end;

procedure TFrameSerif.OnCharaChange(Sender: TObject);
begin
  FCharas.SaveToFile();
  FFrameScene.View();
end;

procedure TFrameSerif.OnCharaRename(Sender: TObject; const OldName, Keyword,
  NewName: string);
var
  i, j: Integer;
  Scene: TSerifSceneItem;
  Msg: TSerifSceneMsgItem;
  Changed: Boolean;

  function ShouldReassignMsg(Msg: TSerifSceneMsgItem): Boolean;
  begin
    Result := False;
    if Msg = nil then Exit;

    // 棒読みちゃん対応: 新形式ではMsg.Keywordを元に配役Nameを再割り当てする。
    if (Trim(Keyword) <> '') and SameText(Trim(Msg.Keyword), Trim(Keyword)) then
      Exit(True);

    // 棒読みちゃん対応: Keyword追加前の既存データは旧Name一致で救済する。
    Result := (Trim(Msg.Keyword) = '') and SameText(Trim(Msg.Chara), Trim(OldName));
  end;
begin
  Changed := False;

  // 棒読みちゃん対応: Keywordに割り当てたName変更を、既存セリフ一覧の配役名へ反映する。
  for i := 0 to FScenes.Count - 1 do
  begin
    Scene := FScenes[i];
    if Scene = nil then Continue;

    for j := 0 to Scene.Msgs.Count - 1 do
    begin
      Msg := Scene.Msgs[j];
      if not ShouldReassignMsg(Msg) then Continue;

      if Trim(Msg.Keyword) = '' then
        Msg.Keyword := Keyword;
      Msg.Chara := NewName;
      Changed := True;
    end;
  end;

  // 棒読みちゃん対応: 監視取り込み直後の一時リストにも同じ置換をかける。
  for i := 0 to FMsgs.Count - 1 do
  begin
    Msg := FMsgs[i];
    if not ShouldReassignMsg(Msg) then Continue;

    if Trim(Msg.Keyword) = '' then
      Msg.Keyword := Keyword;
    Msg.Chara := NewName;
    Changed := True;
  end;

  if not Changed then Exit;

  FScenes.SaveToFile;
  FFrameScene.View;
end;

procedure TFrameSerif.OnConfigChange(Sender: TObject);
begin
  FConfig.SaveToFile();
end;

procedure TFrameSerif.OnConfigEnterPosChange(Sender: TObject);
begin
  FConfig.SaveToFile();
  FFrameScene.SetLinePosition(FConfig.EnterPos);      // 改行位置を変更
  FScenes.SaveToFile;                                 // シーンとセリフ保存
  FFrameScene.View();
end;

procedure TFrameSerif.OnProjectSelect(Sender: TObject; const Index: Integer);
var
  folder : string;
begin
  // フォルダ末尾に区切りを付与
  folder := IncludeTrailingPathDelimiter(FProjects.GetAbsoluteFolderByIndex(Index));
  ShowProjectFolder(folder);
end;

procedure TFrameSerif.OnSceneChange(Sender: TObject);
begin
  FScenes.SaveToFile();
end;

procedure TFrameSerif.OnSceneCharaChange(Sender: TObject);
begin
  FFrameChara.ShowList(FCharas);
  FCharas.SaveToFile;
end;

procedure TFrameSerif.OnSceneMoveCursorFocus(Sender: TObject; Layer,
  Frame: Integer);
begin
  // 2026-04: ガード要求を PluginExSyncroh2Frame 側へ受け渡す
  if Assigned(FOnMoveCursorFocus) then
    FOnMoveCursorFocus(Self, Layer, Frame);
end;

procedure TFrameSerif.OnToolBarChange(Sender: TObject; Index: Integer);
begin
  VoicevoxDebugLog(Format('SerifFrame.OnToolBarChange index=%d input_expanded=%s',
    [Index, BoolToStr(Assigned(FFrameInput) and FFrameInput.Expanded, True)]));
  if (Index <> 0) and Assigned(FFrameInput) then
    FFrameInput.CommitPendingEdit;
  case index of
    0 : FFrameScene.ShowList(FSelectFolder,FScenes,FCharas,FWatchers,FConfig);
    1 : FFrameChara.ShowList(FCharas);
    2 :
      begin
        FFrameConfig.ShowItem(FConfig);
        FFrameWatcher.ShowList(FWatchers);
      end;
    4 : FFrameAlias.ShowList();
    5 : FFrameBoard.ShowBoard;
  end;
  ShowTabHint(Index);
end;

procedure TFrameSerif.OnInputExpandedChange(Sender: TObject);
begin
  if not Assigned(FSplitterInput) or not Assigned(FFrameInput) then Exit;
  FSplitterInput.Visible := FFrameInput.Expanded;
  if FSplitterInput.Visible then
  begin
    FSplitterInput.Top := FFrameInput.Top + FFrameInput.Height;
    FSplitterInput.BringToFront;
  end;
end;

procedure TFrameSerif.OnVoicevoxMoveEnd(Sender: TObject);
begin
  if Assigned(FFrameScene) then FFrameScene.CursorMoveLast;
end;

procedure TFrameSerif.OnVoicevoxStatus(Sender: TObject;
  const StatusText: string);
begin
  if (csDestroying in ComponentState) or
    not Assigned(FVoicevoxStatusLabel) or
    (csDestroying in FVoicevoxStatusLabel.ComponentState) then Exit;
  FVoicevoxStatusLabel.Caption := StatusText;
  if StatusText <> '' then
    FVoicevoxStatusLabel.Width := MulDiv(90, CurrentPPI, 96)
  else
    FVoicevoxStatusLabel.Width := 0;
  FVoicevoxStatusLabel.Hint := StatusText;
  FVoicevoxStatusLabel.ShowHint := StatusText <> '';
  FVoicevoxStatusLabel.Update;
end;

procedure TFrameSerif.OnWatcherChange(Sender: TObject);
begin
  FWatchers.Stop();
  FFrameMonitor.ShowStatus(FWatchers);
  SaveCommonWatchersFromProject;
end;

procedure TFrameSerif.OnWatcherDetecredFiles(Sender: TObject;
  Files: TStringList; var ErrLine: Integer);
var
  folder : string;
begin
  FFrameMonitor.ShowWatch('');                        // 解析終了表示
  folder := FSelectFolder;                            // プロジェクトフォルダ取得
  if not FAnalyzer.Execute(FMsgs,FCharas,folder,Files,FConfig,ErrLine) then Exit;               // 解析してファイルを移動
  if not FFrameScene.AddsMsg(FMsgs) then              // 表示中のシーンにセリフ追加
  begin
    // 解析とファイル登録が完了していれば、AviUtl2への配置失敗だけで
    // セリフを失わない。未送信項目として残し、D&Dで再配置可能にする。
    if not FFrameScene.AddsMsg(FMsgs, False, False, True) then Exit;
  end;
  FFrameChara.ShowList(FCharas);                      // 配役リストを表示
  FScenes.SaveToFile;                                 // シーンとセリフ保存
  FCharas.SaveToFile;                                 // 配役情報を保存
end;

procedure TFrameSerif.OnWatcherStartAndStop(Sender: TObject;
  const State: TSerifWatchState);
var
  WatchState: TSerifWatchState;
begin
  // UI や旧 ini から swsWatch が来ても、保存値と実行状態は swsSend にそろえる。
  WatchState := NormalizeSerifWatchState(State);
  ProcWatcher(WatchState);
  FBound.WatchState := WatchState;
  FBound.SaveToFile;
end;

procedure TFrameSerif.OnWatcherWaitFiles(Sender: TObject);
begin
  FFrameMonitor.ShowWatch('解析中');
end;

procedure TFrameSerif.OnVoicevoxSend(Sender: TObject;
  const Text: string; const SpeakerName: string; const StyleName: string;
  const AccentQueryJson: string; const StyleId: Integer;
  const AudioValues: TSerifVoicevoxAudioValues;
  const ReeditTarget: TSerifAviUtl2Selection;
  var ErrorMessage: string; var SavedUnsent: Boolean);
var
  ActualWaveLayer: Integer;
  Analyzer: TSerifAnalyzer;
  ErrLine: Integer;
  Files: TStringList;
  FrameEnd: Integer;
  FrameStart: Integer;
  GeneratedFilesOwned: Boolean; // Trueなら失敗時にFMsgs内の生成ファイルをこの処理が削除する。
  GeneratedMsg: TSerifSceneMsgItem;
  I: Integer;
  Layer: Integer;
  LabFileName: string;
  MatchCount: Integer;
  NewTextFileName: string;
  NewWaveFileName: string;
  ObjectLabText: string;
  OldTextFileName: string;
  OldWaveFileName: string;
  ReeditMsg: TSerifSceneMsgItem;
  ReeditSelected: Boolean;
  SceneMsgs: TSerifSceneMsgList;
  TextFileName: string;
  WaveFileName: string;

  function ProjectFileName(const RelativeFileName: string): string;
  begin
    if RelativeFileName = '' then Exit('');
    if TPath.IsPathRooted(RelativeFileName) then
      Exit(RelativeFileName);
    Result := TPath.Combine(FSelectFolder, RelativeFileName);
  end;

  procedure DeleteFileSafe(const FileName: string);
  begin
    if FileName = '' then Exit;
    if not FileExists(FileName) then Exit;
    try
      DeleteFile(FileName);
    except
      // AviUtl2などがまだ開いている旧ファイルは残し、更新結果を優先する。
    end;
  end;
begin
  ErrorMessage := '';
  SavedUnsent := False;
  if FSelectFolder = '' then
  begin
    ErrorMessage := 'セリフプロジェクトが選択されていません';
    Exit;
  end;
  if FFrameScene.SelectScene = nil then
  begin
    ErrorMessage := '登録先のシーンが選択されていません';
    Exit;
  end;

  // Enter時にもF2取得対象が選択中なら更新し、それ以外は通常の新規追加として扱う。
  ReeditSelected := AviUtl2SerifResolveSelected(ReeditTarget, Layer,
    FrameStart, FrameEnd);
  ReeditMsg := nil;
  if ReeditSelected then
  begin
    if ReeditTarget.UID = '' then
    begin
      ErrorMessage := 'UIDのないセリフオブジェクトは更新できません';
      Exit;
    end;
    SceneMsgs := FFrameScene.SelectScene.Msgs;
    MatchCount := 0;
    // UID重複の可能性がある旧データでは、取得時のタイムライン位置も使って対象を絞る。
    for I := 0 to SceneMsgs.Count - 1 do
    begin
      if SceneMsgs[I].UID <> ReeditTarget.UID then Continue;
      Inc(MatchCount);
      if (SceneMsgs[I].SerifLayer = Layer) and
        (SceneMsgs[I].FrameStart = FrameStart) then
        ReeditMsg := SceneMsgs[I];
    end;
    if (ReeditMsg = nil) and (MatchCount = 1) then
      ReeditMsg := SceneMsgs[SceneMsgs.IndexOfUID(ReeditTarget.UID)];
    if ReeditMsg = nil then
    begin
      ErrorMessage := '選択中のセリフに対応する内部データを特定できません';
      Exit;
    end;
  end;

  if not TSerifVoicevoxApi.CreateInputFiles(Text, SpeakerName, StyleName,
    StyleId, AudioValues, AccentQueryJson, WaveFileName, TextFileName,
    LabFileName, ErrorMessage) then Exit;

  Files := TStringList.Create;
  Analyzer := TSerifAnalyzer.Create;
  GeneratedFilesOwned := False;
  try
    Files.Add(TextFileName);
    Files.Add(WaveFileName);
    Files.Add(LabFileName);
    ErrLine := -1;
    if not Analyzer.Execute(FMsgs, FCharas, FSelectFolder, Files, FConfig, ErrLine) then
    begin
      ErrorMessage := 'VOICEVOX音声をセリフデータへ登録できませんでした';
      Exit;
    end;
    GeneratedFilesOwned := FMsgs.Count > 0;

    if ReeditSelected then
    begin
      if FMsgs.Count <> 1 then
      begin
        ErrorMessage := '更新用のVOICEVOX音声を1件に特定できませんでした';
        Exit;
      end;
      GeneratedMsg := FMsgs[0];
      OldWaveFileName := ProjectFileName(ReeditMsg.FileNameWave);
      OldTextFileName := ProjectFileName(ReeditMsg.FileNameText);
      NewWaveFileName := ProjectFileName(GeneratedMsg.FileNameWave);
      NewTextFileName := ProjectFileName(GeneratedMsg.FileNameText);
      if FConfig.SendLab then
        ObjectLabText := GeneratedMsg.LabStr
      else
        ObjectLabText := '';

      // AviUtl2側の更新成功後にだけ内部データを上書きし、不整合を残さない。
      if not AviUtl2SerifUpdateSelected(ReeditTarget,
        ReeditMsg.WaveLayer, OldWaveFileName, NewWaveFileName,
        GeneratedMsg.WaveLength, GeneratedMsg.Voice,
        GeneratedMsg.Chara, GeneratedMsg.Emotion,
        ReeditMsg.Direction, GeneratedMsg.AIUEO,
        ObjectLabText, ActualWaveLayer) then
      begin
        ErrorMessage := '選択中のセリフまたは対応する音声を更新できませんでした';
        Exit;
      end;

      // UID、開始・終了フレーム、次位置、シーン、出力状態は維持する。
      ReeditMsg.FileNameWave := GeneratedMsg.FileNameWave;
      ReeditMsg.FileNameText := GeneratedMsg.FileNameText;
      ReeditMsg.Text := GeneratedMsg.Text;
      ReeditMsg.Voice := GeneratedMsg.Voice;
      ReeditMsg.Chara := GeneratedMsg.Chara;
      ReeditMsg.Keyword := GeneratedMsg.Keyword;
      ReeditMsg.Emotion := GeneratedMsg.Emotion;
      ReeditMsg.AIUEO := GeneratedMsg.AIUEO;
      ReeditMsg.WaveLength := GeneratedMsg.WaveLength;
      ReeditMsg.LabStr := GeneratedMsg.LabStr;
      ReeditMsg.SerifLayer := Layer;
      ReeditMsg.WaveLayer := ActualWaveLayer;

      FFrameScene.View;
      FFrameChara.ShowList(FCharas);
      FScenes.SaveToFile;
      FCharas.SaveToFile;
      GeneratedFilesOwned := False;
      if not SameText(OldWaveFileName, NewWaveFileName) then
        DeleteFileSafe(OldWaveFileName);
      if not SameText(OldTextFileName, NewTextFileName) then
        DeleteFileSafe(OldTextFileName);
      Exit;
    end;

    if not FFrameScene.AddsMsg(FMsgs, True, True) then
    begin
      // 音声生成とプロジェクト登録は完了しているため、配置だけ失敗した場合は
      // 未送信セリフとして残し、既存のD&D経路から再配置できるようにする。
      if not FFrameScene.AddsMsg(FMsgs, False, False, True) then
      begin
        ErrorMessage := 'セリフを現在のシーンへ追加できませんでした';
        Exit;
      end;
      SavedUnsent := True;
      VoicevoxDebugLog(
        'VOICEVOX placement failed; registered generated serif as unsent');
    end;
    GeneratedFilesOwned := False;

    FFrameChara.ShowList(FCharas);
    FScenes.SaveToFile;
    FCharas.SaveToFile;
  finally
    if GeneratedFilesOwned then
      for I := 0 to FMsgs.Count - 1 do
        FMsgs[I].DeleteItemFile(FSelectFolder);
    Analyzer.Free;
    Files.Free;
    if FileExists(TextFileName) then
      DeleteFile(TextFileName);
    if FileExists(WaveFileName) then
      DeleteFile(WaveFileName);
    if FileExists(LabFileName) then
      DeleteFile(LabFileName);
    if DirectoryExists(ExtractFileDir(TextFileName)) then
      try
        TDirectory.Delete(ExtractFileDir(TextFileName), False);
      except
        // 登録結果を優先し、一時フォルダの後始末失敗は通知しない。
      end;
  end;
end;

procedure TFrameSerif.ProcWatcher(State: TSerifWatchState);
begin
  // swsWatch は使わず、監視開始時は AviUtl2 への流し込みも有効にする。
  State := NormalizeSerifWatchState(State);
  FWindowWatcher.WatchState := State;
  case State of
    swsStandby : begin
                   FWatchers.Stop();
                   FFrameScene.AutoSend := False;
                  end;
    swsSend    : begin
                   FWatchers.Start();
                   FFrameScene.AutoSend := True;
                 end;
  end;
  FFrameMonitor.ShowStatus(FWatchers);
end;

{ TFrameSerifBound }

constructor TFrameSerifBound.Create;
begin

end;

procedure TFrameSerifBound.FrameToSelf(AFrame: TFrame);
begin
  inherited;

end;

procedure TFrameSerifBound.SelfToFrame(AFrame: TFrame);
begin
  inherited;

end;

end.




