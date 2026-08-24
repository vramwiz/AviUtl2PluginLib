// 複数行版VOICEVOX入力GUIについて、Engine準備・行編集・確認再生・送信をまとめて管理する。
unit SerifVoicevoxInputFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Generics.Collections,
  System.Math,
  Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Graphics,
  SerifCharaIconRenderer, SerifVoicevoxInputRow, SerifVoicevoxSpeakerCatalog,
  SerifVoicevoxSpeakerMenu, SerifVoicevoxSettingsFrame,
  SerifVoicevoxAudioSettings, SerifVoicevoxEngineConfig;

type
  TSerifVoicevoxPreviewState = (vpsIdle, vpsGenerating, vpsStopping,
    vpsPlaying);

  TSerifVoicevoxSendEvent = procedure(Sender: TObject;
    const Text: string; const SpeakerName: string; const StyleName: string;
    const AccentQueryJson: string; const StyleId: Integer;
    const AudioValues: TSerifVoicevoxAudioValues;
    var ErrorMessage: string) of object;

  TFrameSerifVoicevoxInput = class(TFrame)
  private const
    VOICEVOX_PREPARE_DEFER_MS = 50;
    VOICEVOX_PREPARE_INTERVAL_MS = 250;
    VOICEVOX_PREPARE_TIMEOUT_COUNT = 240;
    PREVIEW_COMPLETE_MESSAGE = WM_APP + $5721;
    PREVIEW_MEDIA_ALIAS = 'Syncroh2VoicevoxPreview';
    SERIF_ROW_GAP = 4;
    SETTINGS_FRAME_HEIGHT = 160;
    TEXT_WAIT = #$304A#$5F85#$3061#$304F#$3060#$3055#$3044;
    TEXT_SERIF = #$30BB#$30EA#$30D5;
    TEXT_SEND = #$9001#$4FE1;
    TEXT_GENERATING = #$751F#$6210#$4E2D;
    TEXT_PLAYING = #$518D#$751F#$4E2D;
    TEXT_STOPPING = #$505C#$6B62#$4E2D;
    TEXT_PLAY_FAILED = #$97F3#$58F0#$3092#$518D#$751F#$3067#$304D#$307E#$305B#$3093;
    TEXT_SENT = #$9001#$4FE1#$3057#$307E#$3057#$305F;
    TEXT_REQUIRED = #$30BB#$30EA#$30D5#$3092#$5165#$529B#$3057#$3066#$304F#$3060#$3055#$3044;
    TEXT_SEND_UNAVAILABLE = #$9001#$4FE1#$51E6#$7406#$3092#$5229#$7528#$3067#$304D#$307E#$305B#$3093;
    TEXT_ENGINE_EXITED = 'VOICEVOX Engine ' + #$304C#$7D42#$4E86#$3057#$307E#$3057#$305F;
    TEXT_ENGINE_NOT_FOUND = 'VOICEVOX Engine ' + #$304C#$898B#$3064#$304B#$308A#$307E#$305B#$3093;
    TEXT_ENGINE_START_FAILED = 'VOICEVOX Engine ' + #$3092#$8D77#$52D5#$3067#$304D#$307E#$305B#$3093;
    TEXT_ENGINE_PREPARE_FAILED = 'VOICEVOX Engine ' + #$306E#$6E96#$5099#$306B#$5931#$6557#$3057#$307E#$3057#$305F;
  private
    FPanelWaiting: TPanel;
    FLabelStatus: TLabel;
    FPanelInput: TPanel;
    FButtonSend: TButton;
    FLabelResult: TLabel;
    FScrollRows: TScrollBox;
    FPanelSettings: TPanel;
    FFrameSettings: TFrameSerifVoicevoxSettings;
    FRows: TObjectList<TSerifVoicevoxInputRow>;
    FRetiredRows: TObjectList<TSerifVoicevoxInputRow>;
    FCurrentRow: TSerifVoicevoxInputRow;
    FEditingRow: TSerifVoicevoxInputRow;
    FCharaIconRenderer: TSerifCharaIconRenderer;
    FSpeakerCatalog: TSerifVoicevoxSpeakerCatalog;
    FSpeakerMenu: TSerifVoicevoxSpeakerMenu;
    FSpeakerMenuRow: TSerifVoicevoxInputRow;
    FPrepareTimer: TTimer;
    FPreviewTimer: TTimer;
    FPreviewNotifyHandle: HWND;
    FPreviewOperationId: Cardinal;
    FPendingPreviewRow: TSerifVoicevoxInputRow;
    FPreviewRow: TSerifVoicevoxInputRow;
    FPreviewState: TSerifVoicevoxPreviewState;
    FPreviewThread: TThread;
    FPrepareStarted: Boolean;
    FReady: Boolean;
    FStartedEngine: Boolean;
    FProcessHandle: THandle;
    FPrepareCount: Integer;
    FPreviewWaveFileName: string;
    FPreviewTextFileName: string;
    FOnSend: TSerifVoicevoxSendEvent;
    function AddRow(const Index: Integer; const BeginEditing: Boolean):
      TSerifVoicevoxInputRow;
    procedure AccentChange(Sender: TObject; const QueryJson: string);
    procedure ButtonSendClick(Sender: TObject);
    procedure ClearPreviewFiles;
    procedure CommitEditingRow;
    procedure DeletePreviewFiles(const WaveFileName, TextFileName: string);
    procedure DeleteRow(ARow: TSerifVoicevoxInputRow;
      const MoveToPrevious: Boolean);
    procedure InputBackgroundClick(Sender: TObject);
    function IsApiReady: Boolean;
    function IsStartedEngineRunning: Boolean;
    procedure LayoutRows;
    function StartEngine: Boolean;
    procedure PrepareTimerTimer(Sender: TObject);
    procedure PreviewTimerTimer(Sender: TObject);
    procedure PreviewWindowProc(var Msg: TMessage);
    procedure ResetPreview(const StatusText: string);
    procedure SettingsError(Sender: TObject; const ErrorMessage: string);
    procedure SettingsPreview(Sender: TObject);
    procedure RowBeforeEdit(Row: TSerifVoicevoxInputRow);
    procedure RowEditFinished(Row: TSerifVoicevoxInputRow);
    procedure RowEnter(ARow: TSerifVoicevoxInputRow);
    procedure RowLayoutRequest(Row: TSerifVoicevoxInputRow);
    procedure RowPreview(Row: TSerifVoicevoxInputRow);
    procedure RowSpeakerClick(Row: TSerifVoicevoxInputRow;
      Button: TMouseButton);
    procedure RowTextChanged(Row: TSerifVoicevoxInputRow);
    procedure RowsResize(Sender: TObject);
    procedure SpeakerSelected(Sender: TObject; Speaker: TSerifVoicevoxSpeaker;
      Style: TSerifVoicevoxStyle);
    procedure ShowError(const MessageText: string);
    procedure ShowInput;
    procedure ShowRowSettings(Row: TSerifVoicevoxInputRow);
    procedure ShowWaiting;
    procedure StartPreview(Row: TSerifVoicevoxInputRow);
    procedure StopStartedEngine;
    procedure StopPreview;
  public
    // 入力行、話者メニュー、設定ページ、Engine準備・再生用タイマーを生成する。
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // 編集中の行を確定し、送信対象の本文へ反映する。
    procedure CommitPendingEdit;
    // 音声設定の保存先を指定したセリフプロジェクトへ切り替える。
    procedure OpenProject(const ProjectFolder: string);
    // 入力ページが初めて表示された時に VOICEVOX Engine の準備を開始する。
    procedure Prepare;
    // 送信時に本文、話者、編集済みaudio_query、音声設定を呼び出し元へ渡す。
    property OnSend: TSerifVoicevoxSendEvent read FOnSend write FOnSend;
  end;

implementation

uses
  Winapi.MMSystem, Winapi.WinHttp, System.IOUtils, AviUtl2StyleColors,
  SerifVoicevoxApi,
  SerifVoicevoxDebugLog;

{$R *.dfm}

type
  TSerifVoicevoxPreviewThread = class(TThread)
  private
    FAudioValues: TSerifVoicevoxAudioValues;
    FCharacterName: string;
    FErrorMessage: string;
    FNotifyHandle: HWND;
    FOperationId: Cardinal;
    FQueryJson: string;
    FSpeakerId: Integer;
    FStyleName: string;
    FSuccess: Boolean;
    FText: string;
    FTextFileName: string;
    FWaveFileName: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const NotifyHandle: HWND; const OperationId: Cardinal;
      const Text, CharacterName, StyleName, QueryJson: string;
      const SpeakerId: Integer;
      const AudioValues: TSerifVoicevoxAudioValues);
    property ErrorMessage: string read FErrorMessage;
    property OperationId: Cardinal read FOperationId;
    property Success: Boolean read FSuccess;
    property TextFileName: string read FTextFileName;
    property WaveFileName: string read FWaveFileName;
  end;

constructor TSerifVoicevoxPreviewThread.Create(const NotifyHandle: HWND;
  const OperationId: Cardinal; const Text, CharacterName, StyleName,
  QueryJson: string; const SpeakerId: Integer;
  const AudioValues: TSerifVoicevoxAudioValues);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FNotifyHandle := NotifyHandle;
  FOperationId := OperationId;
  FText := Text;
  FCharacterName := CharacterName;
  FStyleName := StyleName;
  FQueryJson := QueryJson;
  FSpeakerId := SpeakerId;
  FAudioValues := AudioValues;
end;

procedure TSerifVoicevoxPreviewThread.Execute;
begin
  try
    if not Terminated then
      FSuccess := TSerifVoicevoxApi.CreateInputFiles(FText, FCharacterName,
        FStyleName, FSpeakerId, FAudioValues, FQueryJson, FWaveFileName,
        FTextFileName, FErrorMessage);
  except
    on E: Exception do
    begin
      FSuccess := False;
      FErrorMessage := E.Message;
    end;
  end;
  PostMessage(FNotifyHandle, TFrameSerifVoicevoxInput.PREVIEW_COMPLETE_MESSAGE,
    WPARAM(FOperationId), 0);
end;

constructor TFrameSerifVoicevoxInput.Create(AOwner: TComponent);
begin
  VoicevoxDebugLog('InputFrame.Create enter');
  inherited;

  FPreviewState := vpsIdle;
  FPreviewNotifyHandle := AllocateHWnd(PreviewWindowProc);
  FProcessHandle := 0;
  FCharaIconRenderer := TSerifCharaIconRenderer.Create;
  FSpeakerCatalog := TSerifVoicevoxSpeakerCatalog.Create;
  FSpeakerMenu := TSerifVoicevoxSpeakerMenu.Create(FSpeakerCatalog,
    FCharaIconRenderer);
  FSpeakerMenu.OnSelected := SpeakerSelected;
  FRows := TObjectList<TSerifVoicevoxInputRow>.Create(True);
  FRetiredRows := TObjectList<TSerifVoicevoxInputRow>.Create(True);
  Color := A2SCPanelBackground;
  Font.Color := A2SCPanelText;

  FPanelWaiting := TPanel.Create(Self);
  FPanelWaiting.Parent := Self;
  FPanelWaiting.Align := alClient;
  FPanelWaiting.BevelOuter := bvNone;
  FPanelWaiting.Color := A2SCPanelBackground;

  FLabelStatus := TLabel.Create(Self);
  FLabelStatus.Parent := FPanelWaiting;
  FLabelStatus.Align := alClient;
  FLabelStatus.Alignment := taCenter;
  FLabelStatus.AutoSize := False;
  FLabelStatus.Caption := TEXT_WAIT;
  FLabelStatus.Font.Color := A2SCPanelText;
  FLabelStatus.Layout := tlCenter;

  FPanelInput := TPanel.Create(Self);
  FPanelInput.Parent := Self;
  FPanelInput.Align := alClient;
  FPanelInput.BevelOuter := bvNone;
  FPanelInput.Color := A2SCPanelBackground;
  FPanelInput.Padding.SetBounds(12, 12, 12, 12);
  FPanelInput.Visible := False;

  FPanelSettings := TPanel.Create(Self);
  FPanelSettings.Parent := FPanelInput;
  FPanelSettings.Align := alBottom;
  FPanelSettings.BevelOuter := bvLowered;
  FPanelSettings.BevelWidth := 1;
  FPanelSettings.Height := SETTINGS_FRAME_HEIGHT;

  FFrameSettings := TFrameSerifVoicevoxSettings.Create(Self);
  FFrameSettings.Parent := FPanelSettings;
  FFrameSettings.Align := alClient;
  FFrameSettings.OnAccentChange := AccentChange;
  FFrameSettings.OnError := SettingsError;
  FFrameSettings.OnPreview := SettingsPreview;

  FButtonSend := TButton.Create(Self);
  FButtonSend.Parent := FPanelInput;
  FButtonSend.Align := alTop;
  FButtonSend.AlignWithMargins := True;
  FButtonSend.Caption := TEXT_SEND;
  FButtonSend.Height := 28;
  FButtonSend.Margins.Left := 0;
  FButtonSend.Margins.Top := 0;
  FButtonSend.Margins.Right := 0;
  FButtonSend.Margins.Bottom := 0;
  FButtonSend.OnClick := ButtonSendClick;
  FButtonSend.Top := 0;

  FLabelResult := TLabel.Create(Self);
  FLabelResult.Parent := FPanelInput;
  FLabelResult.Align := alTop;
  FLabelResult.AutoSize := False;
  FLabelResult.Font.Color := A2SCPanelText;
  FLabelResult.Height := 24;
  FLabelResult.Top := 28;

  FScrollRows := TScrollBox.Create(Self);
  FScrollRows.Parent := FPanelInput;
  FScrollRows.Align := alClient;
  FScrollRows.BorderStyle := bsNone;
  FScrollRows.Color := A2SCPanelBackground;
  FScrollRows.OnClick := InputBackgroundClick;
  FScrollRows.OnResize := RowsResize;
  FScrollRows.Top := 52;

  AddRow(0, False);

  FPrepareTimer := TTimer.Create(Self);
  FPrepareTimer.Enabled := False;
  FPrepareTimer.Interval := VOICEVOX_PREPARE_INTERVAL_MS;
  FPrepareTimer.OnTimer := PrepareTimerTimer;

  FPreviewTimer := TTimer.Create(Self);
  FPreviewTimer.Enabled := False;
  FPreviewTimer.Interval := 100;
  FPreviewTimer.OnTimer := PreviewTimerTimer;

  ShowWaiting;
  VoicevoxDebugLog('InputFrame.Create leave ready=False prepareStarted=False');
end;

procedure TFrameSerifVoicevoxInput.AccentChange(Sender: TObject;
  const QueryJson: string);
begin
  if Assigned(FCurrentRow) and (FRows.IndexOf(FCurrentRow) >= 0) then
  begin
    FCurrentRow.AccentQueryJson := QueryJson;
    FLabelResult.Caption := '';
  end;
end;

function TFrameSerifVoicevoxInput.AddRow(const Index: Integer;
  const BeginEditing: Boolean): TSerifVoicevoxInputRow;
var
  InsertIndex: Integer;
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  InsertIndex := EnsureRange(Index, 0, FRows.Count);
  Result := TSerifVoicevoxInputRow.Create(Self, FCharaIconRenderer);
  Result.OnBeforeEdit := RowBeforeEdit;
  Result.OnDelete := DeleteRow;
  Result.OnEditFinished := RowEditFinished;
  Result.OnEnterRow := RowEnter;
  Result.OnLayoutRequest := RowLayoutRequest;
  Result.OnPreview := RowPreview;
  Result.OnSpeakerClick := RowSpeakerClick;
  Result.OnTextChanged := RowTextChanged;
  Result.Parent := FScrollRows;
  if (InsertIndex > 0) and (InsertIndex - 1 < FRows.Count) then
    Result.SetSpeaker(FRows[InsertIndex - 1].SpeakerName,
      FRows[InsertIndex - 1].SpeakerUUID, FRows[InsertIndex - 1].StyleName,
      FRows[InsertIndex - 1].StyleId)
  else if FSpeakerCatalog.GetDefault(Speaker, Style) then
    Result.SetSpeaker(Speaker.Name, Speaker.UUID, Style.Name, Style.Id);
  FRows.Insert(InsertIndex, Result);
  LayoutRows;
  if BeginEditing then
    Result.BeginEdit;
  if FReady and ((FRows.Count = 1) or BeginEditing) then
    ShowRowSettings(Result);
end;

procedure TFrameSerifVoicevoxInput.ClearPreviewFiles;
var
  TextFileName: string;
  WaveFileName: string;
begin
  WaveFileName := FPreviewWaveFileName;
  TextFileName := FPreviewTextFileName;
  FPreviewWaveFileName := '';
  FPreviewTextFileName := '';
  FPreviewTimer.Enabled := False;
  mciSendString(PChar('stop ' + PREVIEW_MEDIA_ALIAS), nil, 0, 0);
  mciSendString(PChar('close ' + PREVIEW_MEDIA_ALIAS), nil, 0, 0);
  DeletePreviewFiles(WaveFileName, TextFileName);
end;

procedure TFrameSerifVoicevoxInput.DeletePreviewFiles(const WaveFileName,
  TextFileName: string);
var
  PreviewFolder: string;
begin
  if WaveFileName = '' then Exit;
  PreviewFolder := TPath.GetDirectoryName(WaveFileName);
  try
    if TFile.Exists(WaveFileName) then TFile.Delete(WaveFileName);
    if TFile.Exists(TextFileName) then TFile.Delete(TextFileName);
    if TDirectory.Exists(PreviewFolder) then
      TDirectory.Delete(PreviewFolder, False);
  except
    // プレビュー終了後の一時ファイル削除失敗は画面終了や次回再生を妨げない。
  end;
end;

procedure TFrameSerifVoicevoxInput.ButtonSendClick(Sender: TObject);
var
  ErrorMessage: string;
  Row: TSerifVoicevoxInputRow;
  PendingRows: TList<TSerifVoicevoxInputRow>;
  SentRows: TList<TSerifVoicevoxInputRow>;
begin
  if FPreviewState <> vpsIdle then
  begin
    StopPreview;
    Exit;
  end;

  PendingRows := TList<TSerifVoicevoxInputRow>.Create;
  SentRows := TList<TSerifVoicevoxInputRow>.Create;
  try
    for Row in FRows do
    begin
      if Row.Editing then
        Row.CommitEdit;
      if Row.SerifText <> '' then
        PendingRows.Add(Row);
    end;

    if PendingRows.Count = 0 then
    begin
      FLabelResult.Caption := TEXT_REQUIRED;
      Exit;
    end;

    if not Assigned(FOnSend) then
    begin
      FLabelResult.Caption := TEXT_SEND_UNAVAILABLE;
      Exit;
    end;

    ClearPreviewFiles;
    FButtonSend.Enabled := False;
    for Row in FRows do
      Row.SetEditingEnabled(False);
    FLabelResult.Caption := TEXT_GENERATING;
    FPanelInput.Update;
    try
      ErrorMessage := '';
      for Row in PendingRows do
      begin
        try
          FOnSend(Self, Row.SerifText, Row.SpeakerName, Row.StyleName,
            Row.AccentQueryJson, Row.StyleId,
            FFrameSettings.GetValues(Row.SpeakerUUID, Row.StyleId),
            ErrorMessage);
        except
          on E: Exception do
            ErrorMessage := E.Message;
        end;
        if ErrorMessage <> '' then Break;
        SentRows.Add(Row);
      end;

      for Row in SentRows do
      begin
        if FCurrentRow = Row then FCurrentRow := nil;
        FRows.Extract(Row);
        Row.Free;
      end;

      if ErrorMessage = '' then
      begin
        FRows.Clear;
        AddRow(0, False);
        FFrameSettings.ShowAccent('', -1);
        FLabelResult.Caption := TEXT_SENT;
      end
      else
      begin
        if FRows.Count = 0 then
          AddRow(0, False)
        else
          LayoutRows;
        FLabelResult.Caption := ErrorMessage;
      end;
    finally
      for Row in FRows do
        Row.SetEditingEnabled(True);
      FButtonSend.Enabled := True;
    end;
  finally
    SentRows.Free;
    PendingRows.Free;
  end;
end;

procedure TFrameSerifVoicevoxInput.CommitEditingRow;
var
  Row: TSerifVoicevoxInputRow;
begin
  Row := FEditingRow;
  if Assigned(Row) and Row.Editing then
    Row.CommitEdit
  else
    FEditingRow := nil;
end;

procedure TFrameSerifVoicevoxInput.CommitPendingEdit;
begin
  CommitEditingRow;
end;

procedure TFrameSerifVoicevoxInput.DeleteRow(ARow: TSerifVoicevoxInputRow;
  const MoveToPrevious: Boolean);
var
  DeleteIndex: Integer;
  TargetIndex: Integer;
begin
  DeleteIndex := FRows.IndexOf(ARow);
  if DeleteIndex < 0 then Exit;

  if ARow.Editing then
    ARow.CommitEdit;

  if FCurrentRow = ARow then
  begin
    FCurrentRow := nil;
    FFrameSettings.ShowAccent('', -1);
  end;

  FRows.Extract(ARow);
  ARow.SetEditingEnabled(False);
  ARow.Visible := False;
  FRetiredRows.Add(ARow);

  if FRows.Count = 0 then
  begin
    AddRow(0, True);
    Exit;
  end;

  if MoveToPrevious then
    TargetIndex := DeleteIndex - 1
  else
    TargetIndex := DeleteIndex;
  TargetIndex := EnsureRange(TargetIndex, 0, FRows.Count - 1);
  LayoutRows;
  FRows[TargetIndex].BeginEdit;
  FScrollRows.ScrollInView(FRows[TargetIndex]);
end;

procedure TFrameSerifVoicevoxInput.InputBackgroundClick(Sender: TObject);
begin
  CommitEditingRow;
end;

destructor TFrameSerifVoicevoxInput.Destroy;
var
  PreviewThread: TSerifVoicevoxPreviewThread;
begin
  VoicevoxDebugLog('InputFrame.Destroy enter');
  FPrepareTimer.Enabled := False;
  FPreviewTimer.Enabled := False;
  if Assigned(FPreviewThread) then
  begin
    PreviewThread := TSerifVoicevoxPreviewThread(FPreviewThread);
    PreviewThread.Terminate;
    PreviewThread.WaitFor;
    DeletePreviewFiles(PreviewThread.WaveFileName,
      PreviewThread.TextFileName);
    FreeAndNil(FPreviewThread);
  end;
  ClearPreviewFiles;
  if FPreviewNotifyHandle <> 0 then
  begin
    DeallocateHWnd(FPreviewNotifyHandle);
    FPreviewNotifyHandle := 0;
  end;
  StopStartedEngine;
  FRows.Free;
  FRetiredRows.Free;
  FSpeakerMenu.Free;
  FSpeakerCatalog.Free;
  FCharaIconRenderer.Free;
  VoicevoxDebugLog('InputFrame.Destroy leave');
  inherited;
end;

function TFrameSerifVoicevoxInput.IsApiReady: Boolean;
var
  ConnectHandle: HINTERNET;
  ErrorCode: Cardinal;
  RequestHandle: HINTERNET;
  SessionHandle: HINTERNET;
  StatusCode: Cardinal;
  StatusCodeSize: Cardinal;
begin
  Result := False;
  VoicevoxDebugLog('InputFrame.IsApiReady WinHTTP GET /version begin');
  SessionHandle := WinHttpOpen('Syncroh2 Voicevox Ready Check/1.0',
    WINHTTP_ACCESS_TYPE_NO_PROXY, WINHTTP_NO_PROXY_NAME,
    WINHTTP_NO_PROXY_BYPASS, 0);
  if not Assigned(SessionHandle) then
  begin
    VoicevoxDebugLog(Format('InputFrame.IsApiReady WinHttpOpen failed win32=%d',
      [GetLastError]));
    Exit;
  end;
  try
    ConnectHandle := WinHttpConnect(SessionHandle, '127.0.0.1', 50021, 0);
    if not Assigned(ConnectHandle) then
    begin
      VoicevoxDebugLog(Format('InputFrame.IsApiReady WinHttpConnect failed win32=%d',
        [GetLastError]));
      Exit;
    end;
    try
      RequestHandle := WinHttpOpenRequest(ConnectHandle, 'GET', '/version',
        nil, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, 0);
      if not Assigned(RequestHandle) then
      begin
        VoicevoxDebugLog(Format('InputFrame.IsApiReady WinHttpOpenRequest failed win32=%d',
          [GetLastError]));
        Exit;
      end;
      try
        WinHttpSetTimeouts(RequestHandle, 250, 250, 250, 500);
        if not WinHttpSendRequest(RequestHandle,
          WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0,
          0, 0) then
        begin
          ErrorCode := GetLastError;
          VoicevoxDebugLog(Format('InputFrame.IsApiReady send failed win32=%d',
            [ErrorCode]));
          Exit;
        end;
        if not WinHttpReceiveResponse(RequestHandle, nil) then
        begin
          ErrorCode := GetLastError;
          VoicevoxDebugLog(Format('InputFrame.IsApiReady receive failed win32=%d',
            [ErrorCode]));
          Exit;
        end;
        StatusCode := 0;
        StatusCodeSize := SizeOf(StatusCode);
        if not WinHttpQueryHeaders(RequestHandle,
          WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
          WINHTTP_HEADER_NAME_BY_INDEX, @StatusCode, StatusCodeSize,
          WINHTTP_NO_HEADER_INDEX) then
        begin
          VoicevoxDebugLog(Format('InputFrame.IsApiReady status query failed win32=%d',
            [GetLastError]));
          Exit;
        end;
        Result := StatusCode = 200;
        VoicevoxDebugLog(Format('InputFrame.IsApiReady GET /version HTTP=%d ready=%s',
          [StatusCode, BoolToStr(Result, True)]));
      finally
        WinHttpCloseHandle(RequestHandle);
      end;
    finally
      WinHttpCloseHandle(ConnectHandle);
    end;
  finally
    WinHttpCloseHandle(SessionHandle);
  end;
end;

function TFrameSerifVoicevoxInput.IsStartedEngineRunning: Boolean;
var
  ExitCode: Cardinal;
begin
  Result := (FProcessHandle <> 0) and GetExitCodeProcess(FProcessHandle, ExitCode) and
    (ExitCode = STILL_ACTIVE);
end;

procedure TFrameSerifVoicevoxInput.LayoutRows;
var
  I: Integer;
  RowTop: Integer;
  RowWidth: Integer;
begin
  if not FReady or not Assigned(FScrollRows) then Exit;
  RowWidth := Max(FScrollRows.ClientWidth, 1);
  for I := 0 to FRows.Count - 1 do
    FRows[I].Width := RowWidth;
  RowTop := 0;
  for I := 0 to FRows.Count - 1 do
  begin
    FRows[I].SetBounds(0, RowTop, RowWidth, FRows[I].DesiredHeight);
    Inc(RowTop, FRows[I].Height + SERIF_ROW_GAP);
  end;
end;

procedure TFrameSerifVoicevoxInput.RowBeforeEdit(
  Row: TSerifVoicevoxInputRow);
begin
  if not FReady then Exit;
  if FEditingRow <> Row then CommitEditingRow;
  FCurrentRow := Row;
  FEditingRow := Row;
  ShowRowSettings(Row);
  FFrameSettings.ShowAccent(Row.SerifText, Row.StyleId,
    Row.AccentQueryJson);
end;

procedure TFrameSerifVoicevoxInput.RowEditFinished(
  Row: TSerifVoicevoxInputRow);
begin
  if FEditingRow = Row then FEditingRow := nil;
end;

procedure TFrameSerifVoicevoxInput.RowEnter(
  ARow: TSerifVoicevoxInputRow);
var
  NewRow: TSerifVoicevoxInputRow;
  RowIndex: Integer;
begin
  RowIndex := FRows.IndexOf(ARow);
  if RowIndex < 0 then Exit;
  NewRow := AddRow(RowIndex + 1, True);
  FScrollRows.ScrollInView(NewRow);
end;

procedure TFrameSerifVoicevoxInput.RowLayoutRequest(
  Row: TSerifVoicevoxInputRow);
begin
  LayoutRows;
  if FReady and Assigned(Row) then FScrollRows.ScrollInView(Row);
end;

procedure TFrameSerifVoicevoxInput.RowPreview(
  Row: TSerifVoicevoxInputRow);
begin
  if not FReady or not Assigned(Row) or (FRows.IndexOf(Row) < 0) then Exit;
  if FPreviewState = vpsStopping then
  begin
    FPendingPreviewRow := Row;
    Exit;
  end;
  if FPreviewState <> vpsIdle then
  begin
    StopPreview;
    Exit;
  end;

  CommitEditingRow;
  ShowRowSettings(Row);
  if Row.SerifText = '' then
  begin
    FLabelResult.Caption := TEXT_REQUIRED;
    Exit;
  end;
  StartPreview(Row);
end;

procedure TFrameSerifVoicevoxInput.SettingsPreview(Sender: TObject);
begin
  RowPreview(FCurrentRow);
end;

procedure TFrameSerifVoicevoxInput.SettingsError(Sender: TObject;
  const ErrorMessage: string);
begin
  FLabelResult.Caption := ErrorMessage;
end;

procedure TFrameSerifVoicevoxInput.RowSpeakerClick(
  Row: TSerifVoicevoxInputRow; Button: TMouseButton);
var
  PopupPoint: TPoint;
begin
  if not FReady or not Assigned(Row) then Exit;
  CommitEditingRow;
  ShowRowSettings(Row);
  FSpeakerMenuRow := Row;
  PopupPoint := Row.SpeakerPopupPoint;
  if Button = mbRight then
    FSpeakerMenu.PopupStyles(PopupPoint.X, PopupPoint.Y, Row.StyleId)
  else
    FSpeakerMenu.Popup(PopupPoint.X, PopupPoint.Y, Row.StyleId);
end;

procedure TFrameSerifVoicevoxInput.RowTextChanged(
  Row: TSerifVoicevoxInputRow);
begin
  if FReady and (FEditingRow = Row) then
    FFrameSettings.ShowAccent(Row.CurrentText, Row.StyleId,
      Row.AccentQueryJson);
end;

procedure TFrameSerifVoicevoxInput.RowsResize(Sender: TObject);
begin
  LayoutRows;
end;

procedure TFrameSerifVoicevoxInput.Prepare;
begin
  VoicevoxDebugLog(Format('InputFrame.Prepare called ready=%s prepareStarted=%s',
    [BoolToStr(FReady, True), BoolToStr(FPrepareStarted, True)]));
  if FReady or FPrepareStarted then
  begin
    VoicevoxDebugLog('InputFrame.Prepare skipped');
    Exit;
  end;

  FPrepareStarted := True;
  FPrepareCount := 0;
  ShowWaiting;
  // ツールバー選択イベント内で通信を始めると、入力パネルの初回描画が
  // 接続タイムアウト後まで遅れる。短いTimerへ送って先に画面を描画させる。
  FPrepareTimer.Enabled := False;
  FPrepareTimer.Interval := VOICEVOX_PREPARE_DEFER_MS;
  FPrepareTimer.Enabled := True;
  VoicevoxDebugLog(Format('InputFrame.Prepare deferred by %dms so UI can paint first',
    [VOICEVOX_PREPARE_DEFER_MS]));
end;

procedure TFrameSerifVoicevoxInput.OpenProject(
  const ProjectFolder: string);
begin
  FFrameSettings.OpenProject(ProjectFolder);
end;

procedure TFrameSerifVoicevoxInput.PrepareTimerTimer(Sender: TObject);
begin
  FPrepareTimer.Enabled := False;

  if (FPrepareCount = 0) and not FStartedEngine then
  begin
    VoicevoxDebugLog('InputFrame.PrepareTimer initial readiness check');
    if IsApiReady then
    begin
      VoicevoxDebugLog('InputFrame.PrepareTimer API already ready -> ShowInput');
      ShowInput;
      Exit;
    end;
    if not StartEngine then
    begin
      VoicevoxDebugLog('InputFrame.PrepareTimer StartEngine failed');
      Exit;
    end;
    FPrepareTimer.Interval := VOICEVOX_PREPARE_INTERVAL_MS;
    FPrepareTimer.Enabled := True;
    VoicevoxDebugLog('InputFrame.PrepareTimer engine started; readiness polling enabled');
    Exit;
  end;

  Inc(FPrepareCount);
  VoicevoxDebugLog(Format('InputFrame.PrepareTimer count=%d', [FPrepareCount]));

  if IsApiReady then
  begin
    VoicevoxDebugLog('InputFrame.PrepareTimer API ready -> ShowInput');
    FPrepareTimer.Enabled := False;
    ShowInput;
    Exit;
  end;

  if FStartedEngine and not IsStartedEngineRunning then
  begin
    VoicevoxDebugLog('InputFrame.PrepareTimer started engine exited');
    ShowError(TEXT_ENGINE_EXITED);
    Exit;
  end;

  if FPrepareCount >= VOICEVOX_PREPARE_TIMEOUT_COUNT then
  begin
    VoicevoxDebugLog('InputFrame.PrepareTimer timeout');
    ShowError(TEXT_ENGINE_PREPARE_FAILED);
    Exit;
  end;

  FPrepareTimer.Interval := VOICEVOX_PREPARE_INTERVAL_MS;
  FPrepareTimer.Enabled := True;
end;

procedure TFrameSerifVoicevoxInput.PreviewTimerTimer(Sender: TObject);
var
  Mode: array[0..31] of Char;
begin
  Mode[0] := #0;
  if (mciSendString(PChar('status ' + PREVIEW_MEDIA_ALIAS + ' mode'), Mode,
    Length(Mode), 0) = 0) and SameText(Mode, 'playing') then Exit;

  ResetPreview('');
end;

procedure TFrameSerifVoicevoxInput.PreviewWindowProc(var Msg: TMessage);
var
  ErrorMessage: string;
  PendingRow: TSerifVoicevoxInputRow;
  PreviewThread: TSerifVoicevoxPreviewThread;
  Success: Boolean;
  TextFileName: string;
  WaveFileName: string;
begin
  if Msg.Msg <> PREVIEW_COMPLETE_MESSAGE then
  begin
    Msg.Result := DefWindowProc(FPreviewNotifyHandle, Msg.Msg, Msg.WParam,
      Msg.LParam);
    Exit;
  end;

  Msg.Result := 0;
  if not Assigned(FPreviewThread) then Exit;
  PreviewThread := TSerifVoicevoxPreviewThread(FPreviewThread);
  if Cardinal(Msg.WParam) <> PreviewThread.OperationId then Exit;

  PreviewThread.WaitFor;
  Success := PreviewThread.Success;
  ErrorMessage := PreviewThread.ErrorMessage;
  WaveFileName := PreviewThread.WaveFileName;
  TextFileName := PreviewThread.TextFileName;
  FPreviewThread := nil;
  PreviewThread.Free;

  if (Cardinal(Msg.WParam) <> FPreviewOperationId) or
    (FPreviewState = vpsStopping) then
  begin
    DeletePreviewFiles(WaveFileName, TextFileName);
    PendingRow := FPendingPreviewRow;
    ResetPreview('');
    if Assigned(PendingRow) and (FRows.IndexOf(PendingRow) >= 0) then
      StartPreview(PendingRow);
    Exit;
  end;

  if not Success then
  begin
    DeletePreviewFiles(WaveFileName, TextFileName);
    ResetPreview(ErrorMessage);
    Exit;
  end;

  FPreviewWaveFileName := WaveFileName;
  FPreviewTextFileName := TextFileName;
  if (mciSendString(PChar('open "' + FPreviewWaveFileName +
    '" type waveaudio alias ' + PREVIEW_MEDIA_ALIAS), nil, 0, 0) <> 0) or
    (mciSendString(PChar('play ' + PREVIEW_MEDIA_ALIAS), nil, 0, 0) <> 0) then
  begin
    ResetPreview(TEXT_PLAY_FAILED);
    Exit;
  end;

  FPreviewState := vpsPlaying;
  FLabelResult.Caption := TEXT_PLAYING;
  FPreviewTimer.Enabled := True;
end;

procedure TFrameSerifVoicevoxInput.ResetPreview(const StatusText: string);
begin
  ClearPreviewFiles;
  if Assigned(FPreviewRow) then FPreviewRow.SetPreviewActive(False);
  FPendingPreviewRow := nil;
  FPreviewRow := nil;
  FPreviewState := vpsIdle;
  FButtonSend.Enabled := True;
  FLabelResult.Caption := StatusText;
end;

procedure TFrameSerifVoicevoxInput.ShowError(const MessageText: string);
begin
  FPrepareTimer.Enabled := False;
  FLabelStatus.Caption := MessageText;
  FPanelWaiting.Visible := True;
  FPanelInput.Visible := False;
end;

procedure TFrameSerifVoicevoxInput.ShowInput;
var
  ErrorMessage: string;
  Row: TSerifVoicevoxInputRow;
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  VoicevoxDebugLog(Format('InputFrame.ShowInput enter speakerCount=%d',
    [FSpeakerCatalog.Speakers.Count]));
  if FSpeakerCatalog.Speakers.Count = 0 then
  begin
    VoicevoxDebugLog('InputFrame.ShowInput loading /speakers');
    if not FSpeakerCatalog.LoadFromApi(ErrorMessage) then
    begin
      VoicevoxDebugLog('InputFrame.ShowInput /speakers failed: ' + ErrorMessage);
      ShowError(ErrorMessage);
      Exit;
    end;
    FSpeakerMenu.Build;
    VoicevoxDebugLog(Format('InputFrame.ShowInput /speakers loaded count=%d',
      [FSpeakerCatalog.Speakers.Count]));
  end;
  if FSpeakerCatalog.GetDefault(Speaker, Style) then
    for Row in FRows do
      if Row.StyleId < 0 then
        Row.SetSpeaker(Speaker.Name, Speaker.UUID, Style.Name, Style.Id);
  FReady := True;
  FLabelStatus.Caption := '';
  FPanelWaiting.Visible := False;
  FPanelInput.Visible := True;
  if FRows.Count > 0 then ShowRowSettings(FRows[0]);
  LayoutRows;
  VoicevoxDebugLog('InputFrame.ShowInput leave ready=True');
end;

procedure TFrameSerifVoicevoxInput.SpeakerSelected(Sender: TObject;
  Speaker: TSerifVoicevoxSpeaker; Style: TSerifVoicevoxStyle);
begin
  if Assigned(FSpeakerMenuRow) and (FRows.IndexOf(FSpeakerMenuRow) >= 0) and
    Assigned(Speaker) and Assigned(Style) then
  begin
    FSpeakerMenuRow.SetSpeaker(Speaker.Name, Speaker.UUID, Style.Name, Style.Id);
    ShowRowSettings(FSpeakerMenuRow);
    if FCurrentRow = FSpeakerMenuRow then
      FFrameSettings.ShowAccent(FSpeakerMenuRow.SerifText,
        FSpeakerMenuRow.StyleId, FSpeakerMenuRow.AccentQueryJson);
  end;
  FSpeakerMenuRow := nil;
end;

procedure TFrameSerifVoicevoxInput.ShowRowSettings(
  Row: TSerifVoicevoxInputRow);
begin
  if not Assigned(Row) then Exit;
  FFrameSettings.ShowStyle(Row.SpeakerUUID, Row.StyleId);
end;

procedure TFrameSerifVoicevoxInput.ShowWaiting;
begin
  FReady := False;
  FLabelStatus.Caption := TEXT_WAIT;
  FPanelInput.Visible := False;
  FPanelWaiting.Visible := True;
end;

procedure TFrameSerifVoicevoxInput.StartPreview(
  Row: TSerifVoicevoxInputRow);
var
  AudioValues: TSerifVoicevoxAudioValues;
begin
  VoicevoxDebugLog(Format('InputFrame.StartPreview requested styleId=%d textLength=%d queryOverride=%s',
    [Row.StyleId, Length(Row.SerifText),
     BoolToStr(Row.AccentQueryJson <> '', True)]));
  if (FPreviewState <> vpsIdle) or Assigned(FPreviewThread) then Exit;

  ClearPreviewFiles;
  AudioValues := FFrameSettings.GetValues(Row.SpeakerUUID, Row.StyleId);
  Inc(FPreviewOperationId);
  if FPreviewOperationId = 0 then Inc(FPreviewOperationId);
  FPreviewRow := Row;
  FPreviewRow.SetPreviewActive(True);
  FPreviewState := vpsGenerating;
  FButtonSend.Enabled := False;
  FLabelResult.Caption := TEXT_GENERATING;

  try
    FPreviewThread := TSerifVoicevoxPreviewThread.Create(
      FPreviewNotifyHandle, FPreviewOperationId, Row.SerifText,
      Row.SpeakerName, Row.StyleName, Row.AccentQueryJson, Row.StyleId,
      AudioValues);
    FPreviewThread.Start;
    VoicevoxDebugLog(Format('InputFrame.StartPreview worker started operationId=%d',
      [FPreviewOperationId]));
  except
    on E: Exception do
    begin
      FreeAndNil(FPreviewThread);
      ResetPreview(E.Message);
    end;
  end;
end;

function TFrameSerifVoicevoxInput.StartEngine: Boolean;
var
  CommandLine: string;
  CurrentDirectory: string;
  EngineConfig: TSerifVoicevoxEngineConfig;
  EngineExe: string;
  ProcessInfo: TProcessInformation;
  StartupInfo: TStartupInfo;
begin
  Result := False;
  EngineConfig := TSerifVoicevoxEngineConfig.Create;
  try
    if not EngineConfig.Resolve(EngineExe) then
      EngineExe := '';
  finally
    EngineConfig.Free;
  end;
  VoicevoxDebugLog('InputFrame.StartEngine enter exe=' + EngineExe);
  if not TFile.Exists(EngineExe) then
  begin
    VoicevoxDebugLog('InputFrame.StartEngine executable not found');
    ShowError(TEXT_ENGINE_NOT_FOUND);
    Exit;
  end;

  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));
  CommandLine := Format('"%s" --host 127.0.0.1 --port 50021 --output_log_utf8',
    [EngineExe]);
  CurrentDirectory := TPath.GetDirectoryName(EngineExe);

  if not CreateProcess(PChar(EngineExe), PChar(CommandLine), nil, nil, False,
    CREATE_NO_WINDOW, nil, PChar(CurrentDirectory), StartupInfo, ProcessInfo) then
  begin
    VoicevoxDebugLog(Format('InputFrame.StartEngine CreateProcess failed win32=%d',
      [GetLastError]));
    ShowError(TEXT_ENGINE_START_FAILED);
    Exit;
  end;

  CloseHandle(ProcessInfo.hThread);
  FProcessHandle := ProcessInfo.hProcess;
  FStartedEngine := True;
  Result := True;
  VoicevoxDebugLog(Format('InputFrame.StartEngine success pid=%d',
    [ProcessInfo.dwProcessId]));
end;

procedure TFrameSerifVoicevoxInput.StopStartedEngine;
begin
  if FProcessHandle = 0 then Exit;

  if FStartedEngine and IsStartedEngineRunning then
  begin
    TerminateProcess(FProcessHandle, 0);
    WaitForSingleObject(FProcessHandle, 3000);
  end;

  CloseHandle(FProcessHandle);
  FProcessHandle := 0;
  FStartedEngine := False;
end;

procedure TFrameSerifVoicevoxInput.StopPreview;
begin
  case FPreviewState of
    vpsGenerating:
      begin
        if Assigned(FPreviewThread) then FPreviewThread.Terminate;
        FPreviewState := vpsStopping;
        FLabelResult.Caption := TEXT_STOPPING;
      end;
    vpsPlaying:
      ResetPreview('');
  end;
end;

end.
