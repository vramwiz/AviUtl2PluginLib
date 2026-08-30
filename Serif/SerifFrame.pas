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
  SerifVoicevoxAudioSettings,AviUtl2Serif,SerifDrawFrame, DarkLabel, DarkPanel,
  SerifRuntimeContext;

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
    PanelClient: TDarkPanel;
    PanelChara: TDarkPanel;
    PanelConfig: TDarkPanel;
    PanelProject: TDarkPanel;
    PanelScenario: TDarkPanel;
    PanelSerif: TDarkPanel;
    PanelMonitor: TDarkPanel;
    ToolBar1: TToolBar;
    tbProject: TToolButton;
    tbScenario: TToolButton;
    tbSerif: TToolButton;
    tbChara: TToolButton;
    tbConfig: TToolButton;
    tbNewText: TToolButton;
    tbView: TToolButton;
    PanelView: TDarkPanel;
    tbBoard: TToolButton;
    PanelBoard: TDarkPanel;
    PanelDraw: TDarkPanel;
  private
    { Private 宣言 }
    FRuntimeContext : TSerifRuntimeContext;          // 非表示データとサービスの所有者
    FBound          : TFrameSerifBound;             // Windows位置とサイズ記憶クラス
    FProjects       : TSerifProjectList;            // RuntimeContext所有の参照
    FScenes         : TSerifSceneList;              // RuntimeContext所有の参照
    FCharas         : TSerifCharaList;              // RuntimeContext所有の参照
    FWatchers       : TSerifWatcherList;            // RuntimeContext所有の参照
    FCommonWatchers : TSerifWatcherList;            // RuntimeContext所有の参照
    FWindowWatcher  : TSerifWindowWatcher;          // RuntimeContext所有の参照
    FAnalyzer       : TSerifAnalyzer;               // RuntimeContext所有の参照
    FConfig         : TSerifConfigItem;             // RuntimeContext所有の参照
    FMsgs           : TSerifSceneMsgList;           // RuntimeContext所有の参照
    FScenarioCharas : TSerifScenarioCharaList;      // RuntimeContext所有の参照
    FScenarioMsgs   : TSerifScenarioMsgList;        // RuntimeContext所有の参照
    FSceneID        : Integer;
    FFormVisibleSerif: Boolean;                      // True:フォーム表示中
    FDisplayPagesEnabled: Boolean;                   // 製品Profileが表示Aliasを提供する場合だけTrue

    FTBarManager    : TToolBarPanelManager;         // ツールバーによるページコントロール
    FToolbarImages  : TImageList;                   // DPIに合わせて生成するページ選択アイコン
    FFrameProject   : TFrameSerifProject;           // 台本プロジェクトリスト
    FFrameScene     : TFrameSerifScene;             // シーンとセリフリスト表示フレーム
    FFrameInput     : TFrameSerifVoicevoxSimpleInput; // 1行常時編集のVOICEVOX入力フレーム
    FSplitterInput  : TSplitter;                      // VOICEVOX入力とセリフ一覧の高さ調整
    FFrameChara     : TFrameSerifCharaList;         // 配役一覧表示設定フレーム
    FFrameWatcher   : TFrameSerifWatcher;           // 監視フォルダリスト
    FFrameMonitor   : TFrameSerifMonitor;           // フォルダ監視開始停止フレーム
    FVoicevoxStatusLabel: TDarkLabel;                // 監視欄右側のVOICEVOX状態表示
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
    procedure ApplySceneChange(SceneID: Integer);
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
    property DisplayPagesEnabled: Boolean read FDisplayPagesEnabled
      write FDisplayPagesEnabled;
    property OnMoveCursorFocus : TFrameSerifCursorFocusEvent read FOnMoveCursorFocus write FOnMoveCursorFocus;
  end;

implementation

{$R *.dfm}

uses  AppFolderUtils, System.IOUtils,AviUtl2StyleColors,
       SerifCharaVectorResource,
       SerifVoicevoxDebugLog,SerifToolbarIcons,
       SerifProjectSession,SerifProjectAviUtlSync,SerifProjectLifecycle,
       SerifRuntimeController,SerifUiComposition,SerifUiNavigation,
       SerifWatcherController;

{ TFrameSerif }

constructor TFrameSerif.Create(AOwner: TComponent);
var
  Handlers: TSerifUiHandlers;
  Hosts: TSerifUiHosts;
  I: Integer;
  Parts: TSerifUiParts;
begin
  VoicevoxDebugLog('SerifFrame.Create enter');
  inherited;
  FDisplayPagesEnabled := True;
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

  FRuntimeContext := TSerifRuntimeContext.Create(GetAppFolder('Serif'),
    OnWatcherDetecredFiles, OnWatcherWaitFiles);
  FProjects := FRuntimeContext.Projects;
  FScenes := FRuntimeContext.Scenes;
  FCharas := FRuntimeContext.Charas;
  FWatchers := FRuntimeContext.Watchers;
  FCommonWatchers := FRuntimeContext.CommonWatchers;
  FWindowWatcher := FRuntimeContext.WindowWatcher;
  FAnalyzer := FRuntimeContext.Analyzer;
  FConfig := FRuntimeContext.Config;
  FMsgs := FRuntimeContext.Msgs;
  FScenarioCharas := FRuntimeContext.ScenarioCharas;
  FScenarioMsgs := FRuntimeContext.ScenarioMsgs;
  FSceneID := -1;
  FTemporaryLock := nil;

  FTabIndexOld := -1;                    // 初回を変化とするため存在しない値をセット

  FTBarManager := CreateSerifToolbarManager([PanelSerif, PanelChara,
    PanelConfig, PanelDraw, PanelView, PanelBoard, PanelScenario,
    PanelProject], OnToolBarChange);

  Hosts := Default(TSerifUiHosts);
  Hosts.ProjectPanel := PanelProject;
  Hosts.ScenarioPanel := PanelScenario;
  Hosts.SerifPanel := PanelSerif;
  Hosts.CharaPanel := PanelChara;
  Hosts.ConfigPanel := PanelConfig;
  Hosts.MonitorPanel := PanelMonitor;
  Hosts.DrawPanel := PanelDraw;
  Hosts.ViewPanel := PanelView;
  Hosts.BoardPanel := PanelBoard;

  Handlers := Default(TSerifUiHandlers);
  Handlers.ProjectOpen := OnProjectSelect;
  Handlers.SceneChange := OnSceneChange;
  Handlers.SceneCharaChange := OnSceneCharaChange;
  Handlers.SceneMoveCursorFocus := OnSceneMoveCursorFocus;
  Handlers.VoicevoxSend := OnVoicevoxSend;
  Handlers.InputExpandedChange := OnInputExpandedChange;
  Handlers.VoicevoxMoveEnd := OnVoicevoxMoveEnd;
  Handlers.VoicevoxStatus := OnVoicevoxStatus;
  Handlers.CharaChange := OnCharaChange;
  Handlers.CharaRename := OnCharaRename;
  Handlers.WatcherChange := OnWatcherChange;
  Handlers.MonitorChange := OnWatcherStartAndStop;
  Handlers.ConfigChange := OnConfigChange;
  Handlers.ConfigEnterPosChange := OnConfigEnterPosChange;

  ComposeSerifUi(Self, CurrentPPI, FProjects, Hosts, Handlers, Parts);
  FFrameProject := Parts.ProjectFrame;
  FFrameScenario := Parts.ScenarioFrame;
  FFrameScene := Parts.SceneFrame;
  FFrameInput := Parts.InputFrame;
  FSplitterInput := Parts.InputSplitter;
  FFrameChara := Parts.CharaFrame;
  FFrameWatcher := Parts.WatcherFrame;
  FFrameMonitor := Parts.MonitorFrame;
  FVoicevoxStatusLabel := Parts.VoicevoxStatusLabel;
  FFrameConfig := Parts.ConfigFrame;
  FFrameDraw := Parts.DrawFrame;
  FFrameAlias := Parts.AliasFrame;
  FFrameBoard := Parts.BoardFrame;
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
  FRuntimeContext.Free;
  FRuntimeContext := nil;
  FTemporaryLock.Free;
  FTemporaryLock := nil;
  DeleteTemporarySerifProjectFolder(TemporaryFolder);
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
begin
  Result := SyncSerifAviUtlProject(FSelectFolder, FSceneID,
    EnsureAutomaticProject, ShowProjectFolder, ApplySceneChange);
end;

procedure TFrameSerif.SceneChange(SceneID: Integer);
begin
  AviUtl2SerifResetContinuousSend;
  SyncSerifAviUtlScene(SceneID, FSelectFolder, FSceneID,
    EnsureAutomaticProject, ShowProjectFolder, ApplySceneChange);
end;

procedure TFrameSerif.ApplySceneChange(SceneID: Integer);
begin
  FFrameScene.SceneChange(SceneID);
end;

function TFrameSerif.EnsureAutomaticProject: Boolean;
var
  Folder: string;
  OldTemporaryFolder: string;
begin
  Result := False;
  if (Trim(FSelectFolder) <> '') and TDirectory.Exists(FSelectFolder) then
    Exit(True);

  if not PrepareAutomaticSerifProject(FSelectFolder, OldTemporaryFolder,
    Folder) then Exit;
  CloseProject;
  FTemporaryLock.Free;
  FTemporaryLock := nil;
  DeleteTemporarySerifProjectFolder(OldTemporaryFolder);

  ShowProjectFolder(Folder);
  FScenes.SaveToFile;
  Result := True;
end;

procedure TFrameSerif.RegisterAutomaticProject(const Folder,
  ProjectFilePath: string);
begin
  RegisterAutomaticSerifProject(FProjects, Folder, ProjectFilePath);
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

  if not PromoteAutomaticSerifProject(TemporaryFolder, Folder) then Exit;

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
  SaveSerifProjectData(FScenes, FCharas, FWatchers, FConfig);
  RegisterAutomaticProject(Folder, ProjectFilePath);
  SyncProjectAndScene;
end;

procedure TFrameSerif.CloseProject;
begin
  AviUtl2SerifResetContinuousSend;
  FFrameInput.CloseProject;
  FFrameScene.CloseList;

  CloseSerifProjectData(FScenes, FCharas, FWatchers, FConfig);

  FSelectFolder := '';
  FSceneID := -1;
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
begin
  if folder <> FSelectFolder then begin
    AviUtl2SerifResetContinuousSend;
    LoadSerifProjectData(folder, FScenes, FCharas, FWatchers,
      FCommonWatchers, FConfig);

    FFrameMonitor.ShowStatus(FWatchers);
    FFrameBoard.Show;
    FSelectFolder := folder;
  end;

  WriteSerifAviUtlProjectFolder(folder);
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

procedure TFrameSerif.ShowTabHint(TabIndex: Integer);
begin
  ShowSerifPageHint(TabIndex, FTabIndexOld);
end;

procedure TFrameSerif.TabView;
begin
  SetSerifTabButtonsVisible([tbSerif, tbChara, tbConfig, tbNewText,
    tbScenario], True);
  SetSerifTabButtonsVisible([tbView, tbBoard], FDisplayPagesEnabled);
  tbProject.Visible := False;
end;

procedure TFrameSerif.TabHide;
begin
  SetSerifTabButtonsVisible([tbSerif, tbChara, tbConfig, tbNewText,
    tbView, tbBoard, tbScenario, tbProject], False);
end;

procedure TFrameSerif.OnCharaChange(Sender: TObject);
begin
  SaveSerifCharacterChange(FCharas);
  FFrameScene.View;
end;

procedure TFrameSerif.OnCharaRename(Sender: TObject; const OldName, Keyword,
  NewName: string);
begin
  if ReassignSerifCharacter(OldName, Keyword, NewName, FScenes, FMsgs) then
    FFrameScene.View;
end;

procedure TFrameSerif.OnConfigChange(Sender: TObject);
begin
  SaveSerifConfigChange(FConfig);
end;

procedure TFrameSerif.OnConfigEnterPosChange(Sender: TObject);
begin
  SaveSerifEnterPositionChange(FConfig, FScenes);
  FFrameScene.SetLinePosition(FConfig.EnterPos);      // 改行位置を変更
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
  SaveSerifSceneChange(FScenes);
end;

procedure TFrameSerif.OnSceneCharaChange(Sender: TObject);
begin
  FFrameChara.ShowList(FCharas);
  SaveSerifCharacterChange(FCharas);
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
  ActivateSerifPage(Index, FSelectFolder, FScenes, FCharas, FWatchers,
    FConfig, FFrameInput, FFrameScene, FFrameChara, FFrameConfig,
    FFrameWatcher, FFrameAlias, FFrameBoard);
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
  ApplySerifWatcherSettingsChange(FWatchers, FCommonWatchers, FFrameMonitor);
end;

procedure TFrameSerif.OnWatcherDetecredFiles(Sender: TObject;
  Files: TStringList; var ErrLine: Integer);
begin
  FFrameMonitor.ShowWatch('');                        // 解析終了表示
  if not ImportSerifWatcherFiles(FSelectFolder, Files, FAnalyzer, FMsgs,
    FCharas, FConfig, FScenes, FFrameScene.AddsMsg, ErrLine) then Exit;
  FFrameChara.ShowList(FCharas);                      // 配役リストを表示
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
  SceneMsgs: TSerifSceneMsgList;
begin
  SceneMsgs := nil;
  if Assigned(FFrameScene.SelectScene) then
    SceneMsgs := FFrameScene.SelectScene.Msgs;

  if not RegisterSerifVoicevoxAndSave(FSelectFolder, Text, SpeakerName,
    StyleName, AccentQueryJson, StyleId, AudioValues, ReeditTarget,
    SceneMsgs, FMsgs, FCharas, FConfig, FScenes, FFrameScene.AddsMsg,
    ErrorMessage, SavedUnsent) then Exit;

  FFrameScene.View;
  FFrameChara.ShowList(FCharas);
end;
procedure TFrameSerif.ProcWatcher(State: TSerifWatchState);
begin
  ApplySerifWatcherState(State, FWindowWatcher, FWatchers, FFrameScene,
    FFrameMonitor);
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




