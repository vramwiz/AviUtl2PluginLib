// 入力→Enter送信を中心にした、1話者・1セリフ常時編集のVOICEVOX入力フレーム。
unit SerifVoicevoxSimpleInputFrame;

interface

uses
  System.Classes, System.Types, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  Vcl.StdCtrls,
  SerifCharaIconRenderer, SerifVoicevoxAudioSettings,
  SerifVoicevoxEngineConfig, SerifVoicevoxEngineSession,
  SerifVoicevoxPreviewController,
  SerifVoicevoxShortcutFrame, SerifVoicevoxSimpleInputView,
  SerifVoicevoxSpeakerCatalog,
  SerifVoicevoxSpeakerMenu, SerifVoicevoxSettingsFrame, AviUtl2Serif;

type
  // ReeditTargetが有効なら既存セリフの更新、未取得状態なら通常の新規追加を要求する。
  TSerifVoicevoxSimpleSendEvent = procedure(Sender: TObject;
    const Text: string; const SpeakerName: string; const StyleName: string;
    const AccentQueryJson: string; const StyleId: Integer;
    const AudioValues: TSerifVoicevoxAudioValues;
    const ReeditTarget: TSerifAviUtl2Selection;
    var ErrorMessage: string; var SavedUnsent: Boolean) of object;

  TSerifVoicevoxSimpleStatusEvent = procedure(Sender: TObject;
    const StatusText: string) of object;

  TFrameSerifVoicevoxSimpleInput = class(TFrame)
  private const
    COLLAPSED_HEIGHT = 26;
    COLLAPSED_BACKGROUND_COLOR = $00243F63;
    COLLAPSED_TEXT_COLOR = $00D8E8FF;
    EXPANDED_HEIGHT = 298;
    TEXT_EXPAND = '  クリックして音声合成ソフトを直接操作';
    TEXT_REQUIRED = #$3053#$3053#$306B#$30BB#$30EA#$30D5#$3092 +
      #$5165#$529B;
    TEXT_REEDIT_NOT_FOUND = #$9078#$629E#$4E2D#$306E#$30BB#$30EA#$30D5 +
      #$30AA#$30D6#$30B8#$30A7#$30AF#$30C8#$3092#$53D6#$5F97#$3067 +
      #$304D#$307E#$305B#$3093;
    TEXT_REEDIT_SPEAKER_NOT_FOUND = #$8A71#$8005#$30FB#$611F#$60C5 +
      #$3092#$0056#$004F#$0049#$0043#$0045#$0056#$004F#$0058 +
      #$3067#$89E3#$6C7A#$3067#$304D#$307E#$305B#$3093;
    TEXT_REEDIT_LOADED = #$518D#$7DE8#$96C6#$7528#$306B#$8AAD#$307F +
      #$8FBC#$307F#$307E#$3057#$305F;
    TEXT_SENT = #$9001#$4FE1#$3057#$307E#$3057#$305F;
    TEXT_SAVED_UNSENT = #$672A#$9001#$4FE1#$3068#$3057#$3066 +
      #$30BB#$30EA#$30D5#$30EA#$30B9#$30C8#$3078#$767B#$9332 +
      #$3057#$307E#$3057#$305F;
    TEXT_SENDING = #$9001#$4FE1#$4E2D;
    TEXT_WAIT = #$304A#$5F85#$3061#$304F#$3060#$3055#$3044;
    TEXT_SELECT_ENGINE = 'VOICEVOX' + #$306E#$5834#$6240#$3092 +
      #$6307#$5B9A;
    TEXT_ENGINE_PROMPT = 'VOICEVOX' + #$3092#$4F7F#$3046#$306B#$306F +
      #$5834#$6240#$306E#$6307#$5B9A#$304C#$5FC5#$8981#$3067#$3059 +
      #$3002#$4ECA#$3059#$3050#$6307#$5B9A#$3057#$307E#$3059#$304B +
      #$FF1F;
    TEXT_ENGINE_NOT_FOUND = 'VOICEVOX Engine ' +
      #$304C#$898B#$3064#$304B#$308A#$307E#$305B#$3093;
  private
    FButtonSelectEngine: TButton;
    FCharaIconRenderer: TSerifCharaIconRenderer;
    FEngine: TSerifVoicevoxEngineSession;
    FEngineConfig: TSerifVoicevoxEngineConfig;
    FEngineLocationChecked: Boolean;
    FEnginePromptHandled: Boolean;
    FExpanded: Boolean;
    FExpandedHeight: Integer;
    FFrameSettings: TFrameSerifVoicevoxSettings;
    FFocusExitTimer: TTimer;
    FLabelWaiting: TLabel;
    FOnSend: TSerifVoicevoxSimpleSendEvent;
    FOnExpandedChange: TNotifyEvent;
    FOnMoveEnd: TNotifyEvent;
    FOnStatus: TSerifVoicevoxSimpleStatusEvent;
    FProjectFolder: string;
    FPanelEngineSetup: TPanel;
    FPanelCollapsed: TPanel;
    FPanelInput: TPanel;
    FPanelSettings: TPanel;
    FPanelWaiting: TPanel;
    FPreview: TSerifVoicevoxPreviewController;
    FReady: Boolean;
    FReeditTarget: TSerifAviUtl2Selection; // F2取得後、送信成功まで保持する再編集対象。
    FSpeakerCatalog: TSerifVoicevoxSpeakerCatalog;
    FSpeakerMenu: TSerifVoicevoxSpeakerMenu;
    FShortcutFrame: TFrameSerifVoicevoxShortcuts;
    FView: TSerifVoicevoxSimpleInputView;
    FUpdatingHeight: Boolean;
    procedure AccentChange(Sender: TObject; const QueryJson: string);
    procedure ClearReeditTarget;
    procedure CollapsedClick(Sender: TObject);
    procedure EngineError(Sender: TObject; const ErrorMessage: string);
    procedure EnginePathRequired(Sender: TObject);
    procedure EngineReady(Sender: TObject);
    procedure EngineSetupResize(Sender: TObject);
    procedure FocusExitTimerTimer(Sender: TObject);
    procedure PreviewStatus(Sender: TObject; const Active: Boolean;
      const StatusText: string);
    procedure SettingsError(Sender: TObject; const ErrorMessage: string);
    procedure SettingsClose(Sender: TObject);
    procedure SettingsMoveEnd(Sender: TObject);
    procedure SettingsPreview(Sender: TObject);
    procedure SettingsSend(Sender: TObject);
    procedure ShortcutApply(Sender: TObject; const Index: Integer;
      Speaker: TSerifVoicevoxSpeaker; Style: TSerifVoicevoxStyle);
    procedure SpeakerSelected(Sender: TObject;
      Speaker: TSerifVoicevoxSpeaker; Style: TSerifVoicevoxStyle);
    procedure SetCurrentSpeaker(Speaker: TSerifVoicevoxSpeaker;
      Style: TSerifVoicevoxStyle; const ClearShortcutCursor: Boolean);
    function SendCurrent: Boolean;
    procedure SelectEngineClick(Sender: TObject);
    function SelectEngineFile(out EngineExe: string): Boolean;
    procedure ViewPreview(Sender: TObject);
    procedure ViewEditorExit(Sender: TObject);
    procedure ViewReedit(Sender: TObject);
    procedure ViewSend(Sender: TObject);
    procedure ViewSendAndPreview(Sender: TObject);
    procedure ViewShortcut(Sender: TObject; const Index: Integer);
    procedure ViewSpeakerClick(Sender: TObject);
    procedure ViewSpeakerWheel(Sender: TObject; const WheelDelta: Integer);
    procedure ViewStyleClick(Sender: TObject);
    procedure ViewStyleWheel(Sender: TObject; const WheelDelta: Integer);
    procedure ViewTextChanged(Sender: TObject);
    procedure ShowError(const ErrorMessage: string);
    procedure ShowEngineSetup;
    procedure ShowInput;
    procedure SetStatusText(const StatusText: string);
    procedure ShowWaiting;
    procedure SetExpanded(const Value: Boolean);
    procedure UpdateDpiLayout;
    procedure UpdateFrameHeight;
  protected
    procedure Resize; override;
  public
    // 1行入力ビュー、話者選択、設定ページ、Engineセッション、確認再生を接続する。
    constructor Create(AOwner: TComponent); override;
    // 話者メニュー、カタログ、共有アイコン描画器を所有順序に従って解放する。
    destructor Destroy; override;
    // 親ウィンドウへ接続後のDPIで、入力画面全体の実行時生成部品を再配置する。
    procedure ApplyDpi;
    // 常時編集のため確定処理は不要。旧GUIとSerifFrameの契約を合わせる。
    procedure CommitPendingEdit;
    // 台本を閉じる前に試聴と再編集状態を破棄し、入力パネルを折り畳む。
    procedure CloseProject;
    // 音声設定の保存先を指定した音声合成プロジェクトへ切り替える。
    procedure OpenProject(const ProjectFolder: string);
    // ショートカットとVOICEVOX固有設定の遅延保存を直ちに確定する。
    procedure SaveProjectSettings;
    // 初回表示時にEngineの起動とAPI応答待ちを開始する。
    procedure Prepare;
    // セリフ一覧上部の入力パネルが展開されている場合にTrue。
    property Expanded: Boolean read FExpanded;
    // 折り畳み状態が変化したとき、親へスプリッター表示の更新を要求する。
    property OnExpandedChange: TNotifyEvent read FOnExpandedChange
      write FOnExpandedChange;
    // 設定ツールバーからセリフ一覧の終了位置へ移動する要求を通知する。
    property OnMoveEnd: TNotifyEvent read FOnMoveEnd write FOnMoveEnd;
    // 生成・送信・再編集・エラーの状態をセリフモニターへ通知する。
    property OnStatus: TSerifVoicevoxSimpleStatusEvent read FOnStatus
      write FOnStatus;
    // Enterで現在の本文と合成設定一式を呼び出し元へ渡す。
    property OnSend: TSerifVoicevoxSimpleSendEvent read FOnSend write FOnSend;
  end;

implementation

uses
  Winapi.Windows, System.IOUtils, System.SysUtils, System.UITypes, Vcl.Dialogs,
  AviUtl2StyleColors, SerifVoicevoxDebugLog;

{$R *.dfm}

constructor TFrameSerifVoicevoxSimpleInput.Create(AOwner: TComponent);
begin
  inherited;
  ClearReeditTarget;
  VoicevoxDebugLog('SimpleInputFrame.Create enter');
  Color := A2SCPanelBackground;
  Font.Color := A2SCPanelText;
  FExpandedHeight := EXPANDED_HEIGHT;

  FCharaIconRenderer := TSerifCharaIconRenderer.Create;
  FSpeakerCatalog := TSerifVoicevoxSpeakerCatalog.Create;
  FSpeakerMenu := TSerifVoicevoxSpeakerMenu.Create(FSpeakerCatalog,
    FCharaIconRenderer);
  FSpeakerMenu.OnSelected := SpeakerSelected;

  FFocusExitTimer := TTimer.Create(Self);
  FFocusExitTimer.Enabled := False;
  FFocusExitTimer.Interval := 1;
  FFocusExitTimer.OnTimer := FocusExitTimerTimer;

  FPanelWaiting := TPanel.Create(Self);
  FPanelWaiting.Parent := Self;
  FPanelWaiting.Align := alClient;
  FPanelWaiting.BevelOuter := bvNone;
  FPanelWaiting.Color := A2SCPanelBackground;

  FLabelWaiting := TLabel.Create(Self);
  FLabelWaiting.Parent := FPanelWaiting;
  FLabelWaiting.Align := alClient;
  FLabelWaiting.Alignment := taCenter;
  FLabelWaiting.AutoSize := False;
  FLabelWaiting.Caption := TEXT_WAIT;
  FLabelWaiting.Font.Color := A2SCPanelText;
  FLabelWaiting.Font.Height := -14;
  FLabelWaiting.Layout := tlCenter;

  FPanelEngineSetup := TPanel.Create(Self);
  FPanelEngineSetup.Parent := Self;
  FPanelEngineSetup.Align := alClient;
  FPanelEngineSetup.BevelOuter := bvNone;
  FPanelEngineSetup.Color := A2SCPanelBackground;

  FButtonSelectEngine := TButton.Create(Self);
  FButtonSelectEngine.Parent := FPanelEngineSetup;
  FButtonSelectEngine.Caption := TEXT_SELECT_ENGINE;
  FButtonSelectEngine.Font.Height := -14;
  FButtonSelectEngine.Width := 220;
  FButtonSelectEngine.Height := 40;
  FButtonSelectEngine.OnClick := SelectEngineClick;
  FPanelEngineSetup.OnResize := EngineSetupResize;

  FPanelInput := TPanel.Create(Self);
  FPanelInput.Parent := Self;
  FPanelInput.Align := alClient;
  FPanelInput.BevelOuter := bvNone;
  FPanelInput.Color := A2SCPanelBackground;
  FPanelInput.Padding.SetBounds(10, 10, 10, 10);

  FPanelSettings := TPanel.Create(Self);
  FPanelSettings.Parent := FPanelInput;
  FPanelSettings.Align := alClient;
  FPanelSettings.BevelOuter := bvLowered;

  FFrameSettings := TFrameSerifVoicevoxSettings.Create(Self);
  FFrameSettings.Parent := FPanelSettings;
  FFrameSettings.Align := alClient;
  FFrameSettings.OnAccentChange := AccentChange;
  FFrameSettings.OnClose := SettingsClose;
  FFrameSettings.OnError := SettingsError;
  FFrameSettings.OnMoveEnd := SettingsMoveEnd;
  FFrameSettings.OnPreview := SettingsPreview;
  FFrameSettings.OnSend := SettingsSend;

  FShortcutFrame := TFrameSerifVoicevoxShortcuts.CreateWithRenderer(Self,
    FCharaIconRenderer, FSpeakerCatalog);
  FFrameSettings.AttachShortcutControl(FShortcutFrame);
  FShortcutFrame.OnApply := ShortcutApply;

  FView := TSerifVoicevoxSimpleInputView.Create(Self,
    FCharaIconRenderer);
  FView.Parent := FPanelInput;
  FView.Align := alTop;
  FView.OnPreview := ViewPreview;
  FView.OnEditorExit := ViewEditorExit;
  FView.OnReedit := ViewReedit;
  FView.OnSend := ViewSend;
  FView.OnSendAndPreview := ViewSendAndPreview;
  FView.OnShortcut := ViewShortcut;
  FView.OnSpeakerClick := ViewSpeakerClick;
  FView.OnSpeakerWheel := ViewSpeakerWheel;
  FView.OnStyleClick := ViewStyleClick;
  FView.OnStyleWheel := ViewStyleWheel;
  FView.OnTextChanged := ViewTextChanged;
  FView.Top := 0;

  FEngineConfig := TSerifVoicevoxEngineConfig.Create;
  FEngine := TSerifVoicevoxEngineSession.Create(Self);
  FEngine.OnError := EngineError;
  FEngine.OnEnginePathRequired := EnginePathRequired;
  FEngine.OnReady := EngineReady;
  FPreview := TSerifVoicevoxPreviewController.Create(Self);
  FPreview.OnStatus := PreviewStatus;

  FPanelCollapsed := TPanel.Create(Self);
  FPanelCollapsed.Parent := Self;
  FPanelCollapsed.Align := alClient;
  FPanelCollapsed.Alignment := taLeftJustify;
  FPanelCollapsed.BevelOuter := bvRaised;
  FPanelCollapsed.BevelWidth := 1;
  FPanelCollapsed.Caption := TEXT_EXPAND;
  FPanelCollapsed.ParentBackground := False;
  FPanelCollapsed.Color := COLLAPSED_BACKGROUND_COLOR;
  FPanelCollapsed.Cursor := crHandPoint;
  FPanelCollapsed.Font.Color := COLLAPSED_TEXT_COLOR;
  FPanelCollapsed.Font.Height := -14;
  FPanelCollapsed.OnClick := CollapsedClick;

  ShowWaiting;
  SetExpanded(False);
  VoicevoxDebugLog('SimpleInputFrame.Create leave');
end;

destructor TFrameSerifVoicevoxSimpleInput.Destroy;
begin
  VoicevoxDebugLog('SimpleInputFrame.Destroy');
  // 子コンポーネントの破棄通知から、破棄中の親画面を更新させない。
  FOnStatus := nil;
  if Assigned(FPreview) then
    FPreview.OnStatus := nil;
  FEngineConfig.Free;
  FSpeakerMenu.Free;
  FSpeakerCatalog.Free;
  FCharaIconRenderer.Free;
  inherited;
end;

procedure TFrameSerifVoicevoxSimpleInput.AccentChange(Sender: TObject;
  const QueryJson: string);
begin
  FView.AccentQueryJson := QueryJson;
  SetStatusText('');
end;

procedure TFrameSerifVoicevoxSimpleInput.CommitPendingEdit;
begin
  // TMemoを常時編集状態に保つため何もしない。
  AviUtl2SerifResetContinuousSend;
end;

procedure TFrameSerifVoicevoxSimpleInput.CloseProject;
begin
  FFocusExitTimer.Enabled := False;
  AviUtl2SerifResetContinuousSend;
  ClearReeditTarget;
  if Assigned(FPreview) then FPreview.Stop;
  SetStatusText('');
  SetExpanded(False);
end;

procedure TFrameSerifVoicevoxSimpleInput.CollapsedClick(Sender: TObject);
begin
  if FExpanded then Exit;
  SetExpanded(True);
  Prepare;
end;

procedure TFrameSerifVoicevoxSimpleInput.FocusExitTimerTimer(Sender: TObject);
var
  FocusControl: TWinControl;
begin
  FFocusExitTimer.Enabled := False;
  FocusControl := FindControl(GetFocus);
  if (FocusControl = nil) or
    not ((FocusControl = FPanelInput) or FPanelInput.ContainsControl(FocusControl)) then
    AviUtl2SerifResetContinuousSend;
end;

procedure TFrameSerifVoicevoxSimpleInput.EngineError(Sender: TObject;
  const ErrorMessage: string);
begin
  ShowEngineSetup;
  MessageDlg(ErrorMessage, mtError, [mbOK], 0);
end;

procedure TFrameSerifVoicevoxSimpleInput.ApplyDpi;
begin
  UpdateDpiLayout;
end;

procedure TFrameSerifVoicevoxSimpleInput.EnginePathRequired(Sender: TObject);
var
  EngineExe: string;
begin
  if FEnginePromptHandled then
  begin
    ShowEngineSetup;
    Exit;
  end;
  FEnginePromptHandled := True;
  if MessageDlg(TEXT_ENGINE_PROMPT, mtConfirmation, [mbYes, mbNo], 0) =
    mrYes then
  begin
    if SelectEngineFile(EngineExe) then
    begin
      FEngineConfig.Save(EngineExe);
      FEngine.EngineExe := EngineExe;
      ShowWaiting;
      FEngine.Prepare;
      Exit;
    end;
  end;
  ShowEngineSetup;
end;

procedure TFrameSerifVoicevoxSimpleInput.EngineReady(Sender: TObject);
var
  ErrorMessage: string;
begin
  if FSpeakerCatalog.Speakers.Count = 0 then
  begin
    if not FSpeakerCatalog.LoadFromApi(ErrorMessage) then
    begin
      ShowError(ErrorMessage);
      Exit;
    end;
    FSpeakerMenu.Build;
  end;
  FShortcutFrame.ShowCatalog(FSpeakerCatalog);
  ShowInput;
end;

procedure TFrameSerifVoicevoxSimpleInput.EngineSetupResize(Sender: TObject);
begin
  FButtonSelectEngine.Left :=
    (FPanelEngineSetup.ClientWidth - FButtonSelectEngine.Width) div 2;
  FButtonSelectEngine.Top :=
    (FPanelEngineSetup.ClientHeight - FButtonSelectEngine.Height) div 2;
end;

procedure TFrameSerifVoicevoxSimpleInput.Resize;
begin
  // スプリッターによる高さ変更は96 DPI基準で保持し、閉じて再展開しても再利用する。
  if FExpanded and not FUpdatingHeight and (Height > 0) then
    FExpandedHeight := MulDiv(Height, 96, CurrentPPI);
  inherited;
  UpdateDpiLayout;
end;

procedure TFrameSerifVoicevoxSimpleInput.UpdateDpiLayout;
begin
  // AviUtl2の親ウィンドウへ接続される前にClientWidthを参照する子フレームを
  // 再配置すると、VCLが無効なParentWindowでハンドルを生成するため待機する。
  if not Assigned(Parent) or not Assigned(FPanelInput) or
    not Assigned(FButtonSelectEngine) or
    not Assigned(FShortcutFrame) or not Assigned(FView) or
    not Assigned(FFrameSettings) then Exit;
  FButtonSelectEngine.SetBounds(FButtonSelectEngine.Left,
    FButtonSelectEngine.Top, MulDiv(220, CurrentPPI, 96),
    MulDiv(40, CurrentPPI, 96));
  FPanelInput.Padding.SetBounds(MulDiv(10, CurrentPPI, 96),
    MulDiv(10, CurrentPPI, 96), MulDiv(10, CurrentPPI, 96),
    MulDiv(10, CurrentPPI, 96));
  FShortcutFrame.ApplyDpi;
  FView.ApplyDpi;
  FFrameSettings.ApplyDpi;
  // 96 DPIで14px、150%で21px、200%で28pxとなる比率を維持する。
  FLabelWaiting.Font.Height := -MulDiv(14, CurrentPPI, 96);
  FButtonSelectEngine.Font.Height := -MulDiv(14, CurrentPPI, 96);
  if Assigned(FPanelCollapsed) then
    FPanelCollapsed.Font.Height := -MulDiv(14, CurrentPPI, 96);
  UpdateFrameHeight;
  EngineSetupResize(nil);
end;

procedure TFrameSerifVoicevoxSimpleInput.OpenProject(
  const ProjectFolder: string);
var
  ProjectChanged: Boolean;
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  AviUtl2SerifResetContinuousSend;
  ProjectChanged := not SameText(
    ExcludeTrailingPathDelimiter(FProjectFolder),
    ExcludeTrailingPathDelimiter(ProjectFolder));
  FProjectFolder := ProjectFolder;
  // 初期話者をCtrl+1から取得できるよう、ショートカットを先に読み込む。
  FShortcutFrame.OpenProject(ProjectFolder);
  FFrameSettings.OpenProject(ProjectFolder);
  if not ProjectChanged then Exit;

  FShortcutFrame.ClearApplied;
  FView.SetSpeaker('', '', '', -1);
  FView.AccentQueryJson := '';
  if not FReady then Exit;

  FShortcutFrame.RequestApply(0);
  if (FView.StyleId < 0) and FSpeakerCatalog.GetDefault(Speaker, Style) then
    SetCurrentSpeaker(Speaker, Style, True);
end;

procedure TFrameSerifVoicevoxSimpleInput.SaveProjectSettings;
begin
  FShortcutFrame.Save;
  FFrameSettings.Save;
end;

procedure TFrameSerifVoicevoxSimpleInput.Prepare;
var
  EngineExe: string;
begin
  ShowWaiting;
  FPreview.PreparePlaybackDevice;
  if not FEngineLocationChecked then
  begin
    FEngineLocationChecked := True;
    if FEngineConfig.Resolve(EngineExe) then
      FEngine.EngineExe := EngineExe;
  end;
  FEngine.Prepare;
end;

procedure TFrameSerifVoicevoxSimpleInput.PreviewStatus(Sender: TObject;
  const Active: Boolean; const StatusText: string);
begin
  FFrameSettings.SetPreviewActive(Active);
  SetStatusText(StatusText);
end;

procedure TFrameSerifVoicevoxSimpleInput.SettingsError(Sender: TObject;
  const ErrorMessage: string);
begin
  SetStatusText(ErrorMessage);
end;

procedure TFrameSerifVoicevoxSimpleInput.SettingsPreview(Sender: TObject);
begin
  ViewPreview(Sender);
end;

procedure TFrameSerifVoicevoxSimpleInput.SettingsClose(Sender: TObject);
begin
  SetExpanded(False);
end;

procedure TFrameSerifVoicevoxSimpleInput.SettingsMoveEnd(Sender: TObject);
begin
  if Assigned(FOnMoveEnd) then FOnMoveEnd(Self);
end;

procedure TFrameSerifVoicevoxSimpleInput.SettingsSend(Sender: TObject);
begin
  SendCurrent;
end;

procedure TFrameSerifVoicevoxSimpleInput.ShortcutApply(Sender: TObject;
  const Index: Integer; Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle);
begin
  SetCurrentSpeaker(Speaker, Style, False);
end;

procedure TFrameSerifVoicevoxSimpleInput.ShowError(
  const ErrorMessage: string);
begin
  FReady := False;
  FLabelWaiting.Caption := ErrorMessage;
  FPanelInput.Visible := False;
  FPanelEngineSetup.Visible := False;
  FPanelWaiting.Visible := True;
  FPanelWaiting.BringToFront;
  if Assigned(FPanelCollapsed) and not FExpanded then
    FPanelCollapsed.BringToFront;
end;

procedure TFrameSerifVoicevoxSimpleInput.ShowEngineSetup;
begin
  FReady := False;
  FPanelInput.Visible := False;
  FPanelWaiting.Visible := False;
  FPanelEngineSetup.Visible := True;
  FPanelEngineSetup.BringToFront;
  EngineSetupResize(nil);
  if Assigned(FPanelCollapsed) and not FExpanded then
    FPanelCollapsed.BringToFront;
end;

procedure TFrameSerifVoicevoxSimpleInput.ShowInput;
var
  InitializedByShortcut: Boolean;
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  InitializedByShortcut := False;
  if FView.StyleId < 0 then
  begin
    // ShowCatalog後のCtrl+1を通常の適用経路で選び、選択表示も一致させる。
    FShortcutFrame.RequestApply(0);
    InitializedByShortcut := FView.StyleId >= 0;
    // カタログが空などCtrl+1を解決できない場合だけ従来値へフォールバックする。
    if not InitializedByShortcut and
      FSpeakerCatalog.GetDefault(Speaker, Style) then
      FView.SetSpeaker(Speaker.Name, Speaker.UUID, Style.Name, Style.Id);
  end;
  // RequestApply成功時はSetCurrentSpeaker内ですでに設定表示まで更新される。
  if not InitializedByShortcut then
  begin
    FFrameSettings.ShowStyle(FView.SpeakerUUID, FView.StyleId);
    FFrameSettings.ShowAccent(FView.SerifText, FView.StyleId,
      FView.AccentQueryJson);
  end;
  FReady := True;
  FLabelWaiting.Caption := TEXT_WAIT;
  FPanelWaiting.Visible := False;
  FPanelEngineSetup.Visible := False;
  FPanelInput.Visible := True;
  FPanelInput.BringToFront;
  if FExpanded then
    FView.FocusEditor
  else if Assigned(FPanelCollapsed) then
    FPanelCollapsed.BringToFront;
end;

procedure TFrameSerifVoicevoxSimpleInput.SetStatusText(
  const StatusText: string);
begin
  if Assigned(FOnStatus) then FOnStatus(Self, StatusText);
end;

procedure TFrameSerifVoicevoxSimpleInput.ShowWaiting;
begin
  if FReady then Exit;
  FLabelWaiting.Caption := TEXT_WAIT;
  FPanelInput.Visible := False;
  FPanelEngineSetup.Visible := False;
  FPanelWaiting.Visible := True;
  FPanelWaiting.BringToFront;
  if Assigned(FPanelCollapsed) and not FExpanded then
    FPanelCollapsed.BringToFront;
end;

procedure TFrameSerifVoicevoxSimpleInput.SetExpanded(const Value: Boolean);
var
  WasExpanded: Boolean;
begin
  WasExpanded := FExpanded;
  FExpanded := Value;
  if WasExpanded and not Value then
  begin
    CommitPendingEdit;
    if Assigned(FPreview) then FPreview.Stop;
  end;
  if Assigned(FPanelCollapsed) then
  begin
    FPanelCollapsed.Visible := not Value;
    if not Value then FPanelCollapsed.BringToFront;
  end;
  UpdateFrameHeight;
  if Value then
  begin
    if FReady then ShowInput else ShowWaiting;
  end;
  if (WasExpanded <> Value) and Assigned(FOnExpandedChange) then
    FOnExpandedChange(Self);
end;

procedure TFrameSerifVoicevoxSimpleInput.UpdateFrameHeight;
var
  NewHeight: Integer;
begin
  if FUpdatingHeight then Exit;
  if FExpanded then
    NewHeight := MulDiv(FExpandedHeight, CurrentPPI, 96)
  else
    NewHeight := MulDiv(COLLAPSED_HEIGHT, CurrentPPI, 96);
  if Height = NewHeight then Exit;
  FUpdatingHeight := True;
  try
    Height := NewHeight;
  finally
    FUpdatingHeight := False;
  end;
end;

procedure TFrameSerifVoicevoxSimpleInput.SpeakerSelected(Sender: TObject;
  Speaker: TSerifVoicevoxSpeaker; Style: TSerifVoicevoxStyle);
begin
  SetCurrentSpeaker(Speaker, Style, True);
end;

procedure TFrameSerifVoicevoxSimpleInput.SetCurrentSpeaker(
  Speaker: TSerifVoicevoxSpeaker; Style: TSerifVoicevoxStyle;
  const ClearShortcutCursor: Boolean);
begin
  if not Assigned(Speaker) or not Assigned(Style) then Exit;
  if ClearShortcutCursor then FShortcutFrame.ClearApplied;
  FView.SetSpeaker(Speaker.Name, Speaker.UUID, Style.Name, Style.Id);
  FFrameSettings.ShowStyle(Speaker.UUID, Style.Id);
  FFrameSettings.ShowAccent(FView.SerifText, Style.Id,
    FView.AccentQueryJson);
  FView.FocusEditor;
end;

procedure TFrameSerifVoicevoxSimpleInput.SelectEngineClick(Sender: TObject);
var
  EngineExe: string;
begin
  if not SelectEngineFile(EngineExe) then Exit;
  FEngineConfig.Save(EngineExe);
  FEngine.EngineExe := EngineExe;
  FEnginePromptHandled := False;
  ShowWaiting;
  FEngine.Prepare;
end;

function TFrameSerifVoicevoxSimpleInput.SelectEngineFile(
  out EngineExe: string): Boolean;
var
  Dialog: TOpenDialog;
  LocalAppData: string;
begin
  Result := False;
  EngineExe := '';
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := TEXT_SELECT_ENGINE;
    Dialog.Filter := 'VOICEVOX|VOICEVOX.exe;run.exe|' +
      'Executable files (*.exe)|*.exe';
    Dialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];
    LocalAppData := GetEnvironmentVariable('LOCALAPPDATA');
    if LocalAppData <> '' then
      Dialog.InitialDir := TPath.Combine(TPath.Combine(
        TPath.Combine(LocalAppData, 'Programs'), 'VOICEVOX'), '');
    if not Dialog.Execute then Exit;
    if not TSerifVoicevoxEngineConfig.NormalizeEngineSelection(
      Dialog.FileName, EngineExe) then
    begin
      MessageDlg(TEXT_ENGINE_NOT_FOUND, mtError, [mbOK], 0);
      Exit;
    end;
    Result := True;
  finally
    Dialog.Free;
  end;
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewPreview(Sender: TObject);
var
  Request: TSerifVoicevoxPreviewRequest;
begin
  if not FReady then Exit;
  if FView.SerifText = '' then
  begin
    SetStatusText(TEXT_REQUIRED);
    Exit;
  end;
  Request.Text := FView.SerifText;
  Request.CharacterName := FView.SpeakerName;
  Request.StyleName := FView.StyleName;
  Request.QueryJson := FView.AccentQueryJson;
  Request.SpeakerId := FView.StyleId;
  Request.AudioValues := FFrameSettings.GetValues(FView.SpeakerUUID,
    FView.StyleId);
  FPreview.Toggle(Request);
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewEditorExit(Sender: TObject);
begin
  // OnExit中は次のフォーカス先が未確定の場合があるため、メッセージ処理後に判定する。
  FFocusExitTimer.Enabled := False;
  FFocusExitTimer.Enabled := True;
end;

procedure TFrameSerifVoicevoxSimpleInput.ClearReeditTarget;
begin
  FReeditTarget.ObjectHandle := nil;
  FReeditTarget.UID := '';
  FReeditTarget.Layer := -1;
  FReeditTarget.FrameStart := -1;
  FReeditTarget.FrameEnd := -1;
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewReedit(Sender: TObject);
var
  Character: string;
  Emotion: string;
  I: Integer;
  J: Integer;
  SerifText: string;
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  AviUtl2SerifResetContinuousSend;
  VoicevoxDebugLog(Format('Reedit F2 received ready=%s',
    [BoolToStr(FReady, True)]));
  if not FReady then Exit;
  // 取得失敗時に以前のF2対象を誤って更新しないよう、毎回先に破棄する。
  ClearReeditTarget;
  if not AviUtl2SerifGetSelected(SerifText, Character, Emotion,
    FReeditTarget) then
  begin
    VoicevoxDebugLog('Reedit UI result=failed selected serif not found');
    SetStatusText(TEXT_REEDIT_NOT_FOUND);
    Exit;
  end;

  VoicevoxDebugLog(Format(
    'Reedit UI acquired text="%s" character="%s" emotion="%s"',
    [StringReplace(StringReplace(SerifText, #13, '\r', [rfReplaceAll]),
       #10, '\n', [rfReplaceAll]), Character, Emotion]));

  Speaker := nil;
  Style := nil;
  for I := 0 to FSpeakerCatalog.Speakers.Count - 1 do
    if SameText(Trim(FSpeakerCatalog.Speakers[I].Name), Trim(Character)) then
    begin
      Speaker := FSpeakerCatalog.Speakers[I];
      for J := 0 to Speaker.Styles.Count - 1 do
        if SameText(Trim(Speaker.Styles[J].Name), Trim(Emotion)) then
        begin
          Style := Speaker.Styles[J];
          Break;
        end;
      Break;
    end;

  FView.SetText(SerifText);
  if Assigned(Speaker) and Assigned(Style) then
  begin
    VoicevoxDebugLog(Format(
      'Reedit UI catalog resolved speaker="%s" style="%s" id=%d',
      [Speaker.Name, Style.Name, Style.Id]));
    SetCurrentSpeaker(Speaker, Style, True);
    SetStatusText(TEXT_REEDIT_LOADED);
  end
  else
  begin
    VoicevoxDebugLog(Format(
      'Reedit UI catalog unresolved character="%s" emotion="%s"',
      [Character, Emotion]));
    FFrameSettings.ShowAccent(FView.SerifText, FView.StyleId, '');
    SetStatusText(TEXT_REEDIT_SPEAKER_NOT_FOUND);
    FView.FocusEditor;
  end;
end;

function TFrameSerifVoicevoxSimpleInput.SendCurrent: Boolean;
var
  AudioValues: TSerifVoicevoxAudioValues;
  ErrorMessage: string;
  SavedUnsent: Boolean;
begin
  Result := False;
  if not FReady then Exit;
  if FPreview.Busy then
  begin
    FPreview.Stop;
    Exit;
  end;
  if FView.SerifText = '' then
  begin
    SetStatusText(TEXT_REQUIRED);
    Exit;
  end;
  if not Assigned(FOnSend) then Exit;
  ErrorMessage := '';
  SavedUnsent := False;
  AudioValues := FFrameSettings.GetValues(FView.SpeakerUUID,
    FView.StyleId);
  SetStatusText(TEXT_SENDING);
  FOnSend(Self, FView.SerifText, FView.SpeakerName, FView.StyleName,
    FView.AccentQueryJson, FView.StyleId, AudioValues, FReeditTarget,
    ErrorMessage, SavedUnsent);
  if ErrorMessage <> '' then
  begin
    SetStatusText(ErrorMessage);
    Exit;
  end;
  // 同じ対象を続けて更新するには改めてF2で取得させる。
  ClearReeditTarget;
  if SavedUnsent then
    SetStatusText(TEXT_SAVED_UNSENT)
  else
    SetStatusText(TEXT_SENT);
  FView.FocusEditor(True);
  Result := True;
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewSend(Sender: TObject);
begin
  SendCurrent;
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewSendAndPreview(Sender: TObject);
begin
  if SendCurrent then ViewPreview(Self);
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewShortcut(Sender: TObject;
  const Index: Integer);
begin
  if FReady then FShortcutFrame.RequestApply(Index);
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewSpeakerClick(Sender: TObject);
var
  PopupPoint: TPoint;
begin
  if not FReady then Exit;
  PopupPoint := FView.SpeakerPopupPoint;
  FSpeakerMenu.PopupSpeakers(PopupPoint.X, PopupPoint.Y,
    FView.SpeakerUUID);
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewSpeakerWheel(Sender: TObject;
  const WheelDelta: Integer);
var
  CurrentIndex: Integer;
  I: Integer;
  NextIndex: Integer;
  Speaker: TSerifVoicevoxSpeaker;
begin
  if not FReady or (WheelDelta = 0) or
    (FSpeakerCatalog.Speakers.Count = 0) then Exit;
  CurrentIndex := -1;
  for I := 0 to FSpeakerCatalog.Speakers.Count - 1 do
    if SameText(FSpeakerCatalog.Speakers[I].UUID, FView.SpeakerUUID) then
    begin
      CurrentIndex := I;
      Break;
    end;
  if CurrentIndex < 0 then CurrentIndex := 0;
  NextIndex := CurrentIndex;
  for I := 1 to FSpeakerCatalog.Speakers.Count do
  begin
    if WheelDelta > 0 then
      NextIndex := (NextIndex + FSpeakerCatalog.Speakers.Count - 1) mod
        FSpeakerCatalog.Speakers.Count
    else
      NextIndex := (NextIndex + 1) mod FSpeakerCatalog.Speakers.Count;
    Speaker := FSpeakerCatalog.Speakers[NextIndex];
    if Speaker.Styles.Count > 0 then
    begin
      SetCurrentSpeaker(Speaker, Speaker.Styles[0], True);
      Exit;
    end;
  end;
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewStyleClick(Sender: TObject);
var
  PopupPoint: TPoint;
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  if not FReady or not FSpeakerCatalog.FindStyle(FView.StyleId,
    Speaker, Style) then Exit;
  PopupPoint := FView.StylePopupPoint;
  FSpeakerMenu.PopupStylesForSpeaker(PopupPoint.X, PopupPoint.Y,
    Speaker, FView.StyleId);
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewStyleWheel(Sender: TObject;
  const WheelDelta: Integer);
var
  I: Integer;
  NextIndex: Integer;
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  if not FReady or (WheelDelta = 0) or
    not FSpeakerCatalog.FindStyle(FView.StyleId, Speaker, Style) or
    (Speaker.Styles.Count = 0) then Exit;
  NextIndex := 0;
  for I := 0 to Speaker.Styles.Count - 1 do
    if Speaker.Styles[I].Id = FView.StyleId then
    begin
      NextIndex := I;
      Break;
    end;
  if WheelDelta > 0 then
    NextIndex := (NextIndex + Speaker.Styles.Count - 1) mod
      Speaker.Styles.Count
  else
    NextIndex := (NextIndex + 1) mod Speaker.Styles.Count;
  SetCurrentSpeaker(Speaker, Speaker.Styles[NextIndex], True);
end;

procedure TFrameSerifVoicevoxSimpleInput.ViewTextChanged(Sender: TObject);
begin
  if not FReady then Exit;
  FFrameSettings.ShowAccent(FView.SerifText, FView.StyleId,
    FView.AccentQueryJson);
end;

end.
