// VOICEVOX Engineの遅延起動と準備確認を、入力GUIから分離して管理する。
unit SerifVoicevoxEngineSession;

interface

uses
  Winapi.Windows, System.Classes, Vcl.ExtCtrls;

type
  TSerifVoicevoxEngineErrorEvent = procedure(Sender: TObject;
    const ErrorMessage: string) of object;

  TSerifVoicevoxEngineSession = class(TComponent)
  private const
    INITIAL_DELAY_MS = 50;
    POLL_INTERVAL_MS = 250;
    POLL_TIMEOUT_COUNT = 240;
  private
    FEngineExe: string;
    FOnError: TSerifVoicevoxEngineErrorEvent;
    FOnEnginePathRequired: TNotifyEvent;
    FOnReady: TNotifyEvent;
    FPrepareCount: Integer;
    FPrepareStarted: Boolean;
    FProcessHandle: THandle;
    FReady: Boolean;
    FStartedEngine: Boolean;
    FTimer: TTimer;
    function IsApiReady: Boolean;
    function IsStartedEngineRunning: Boolean;
    procedure ReportError(const ErrorMessage: string);
    procedure SetEngineExe(const Value: string);
    function StartEngine: Boolean;
    procedure StopStartedEngine;
    procedure TimerTimer(Sender: TObject);
  public
    // 準備確認用タイマーと通知先を初期化する。生成したEngineだけを破棄時に停止する。
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // API応答を確認し、未起動ならEngineを開始してReadyになるまで非同期に待機する。
    procedure Prepare;
    // 起動失敗、Engine終了、準備タイムアウトを通知する。
    property OnError: TSerifVoicevoxEngineErrorEvent
      read FOnError write FOnError;
    // APIが未起動でEngine実行パスも未設定の場合に通知する。
    property OnEnginePathRequired: TNotifyEvent
      read FOnEnginePathRequired write FOnEnginePathRequired;
    // APIが利用可能になった時に一度通知する。
    property OnReady: TNotifyEvent read FOnReady write FOnReady;
    // 起動する vv-engine\run.exe。起動済みAPIを使う場合は空でもよい。
    property EngineExe: string read FEngineExe write SetEngineExe;
    // Engine APIへ要求を送れる状態ならTrue。
    property Ready: Boolean read FReady;
  end;

implementation

uses
  Winapi.WinHttp, System.SysUtils, System.IOUtils,
  SerifVoicevoxDebugLog;

constructor TSerifVoicevoxEngineSession.Create(AOwner: TComponent);
begin
  inherited;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := POLL_INTERVAL_MS;
  FTimer.OnTimer := TimerTimer;
end;

destructor TSerifVoicevoxEngineSession.Destroy;
begin
  FTimer.Enabled := False;
  StopStartedEngine;
  inherited;
end;

function TSerifVoicevoxEngineSession.IsApiReady: Boolean;
var
  ConnectHandle: HINTERNET;
  RequestHandle: HINTERNET;
  SessionHandle: HINTERNET;
  StatusCode: Cardinal;
  StatusCodeSize: Cardinal;
begin
  Result := False;
  VoicevoxDebugLog('SimpleEngine WinHTTP GET /version begin');
  SessionHandle := WinHttpOpen('Syncroh2 Voicevox Ready Check/1.0',
    WINHTTP_ACCESS_TYPE_NO_PROXY, WINHTTP_NO_PROXY_NAME,
    WINHTTP_NO_PROXY_BYPASS, 0);
  if not Assigned(SessionHandle) then Exit;
  try
    ConnectHandle := WinHttpConnect(SessionHandle, '127.0.0.1', 50021, 0);
    if not Assigned(ConnectHandle) then Exit;
    try
      RequestHandle := WinHttpOpenRequest(ConnectHandle, 'GET', '/version',
        nil, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, 0);
      if not Assigned(RequestHandle) then Exit;
      try
        WinHttpSetTimeouts(RequestHandle, 250, 250, 250, 500);
        if not WinHttpSendRequest(RequestHandle,
          WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0,
          0, 0) then
        begin
          VoicevoxDebugLog(Format('SimpleEngine /version send failed win32=%d',
            [GetLastError]));
          Exit;
        end;
        if not WinHttpReceiveResponse(RequestHandle, nil) then Exit;
        StatusCode := 0;
        StatusCodeSize := SizeOf(StatusCode);
        if not WinHttpQueryHeaders(RequestHandle,
          WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
          WINHTTP_HEADER_NAME_BY_INDEX, @StatusCode, StatusCodeSize,
          WINHTTP_NO_HEADER_INDEX) then Exit;
        Result := StatusCode = 200;
        VoicevoxDebugLog(Format('SimpleEngine /version HTTP=%d ready=%s',
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

function TSerifVoicevoxEngineSession.IsStartedEngineRunning: Boolean;
var
  ExitCode: Cardinal;
begin
  Result := (FProcessHandle <> 0) and
    GetExitCodeProcess(FProcessHandle, ExitCode) and
    (ExitCode = STILL_ACTIVE);
end;

procedure TSerifVoicevoxEngineSession.Prepare;
begin
  VoicevoxDebugLog(Format('SimpleEngine.Prepare ready=%s started=%s',
    [BoolToStr(FReady, True), BoolToStr(FPrepareStarted, True)]));
  if FReady then
  begin
    if Assigned(FOnReady) then FOnReady(Self);
    Exit;
  end;
  if FPrepareStarted then Exit;
  FPrepareStarted := True;
  FPrepareCount := 0;
  FTimer.Interval := INITIAL_DELAY_MS;
  FTimer.Enabled := True;
end;

procedure TSerifVoicevoxEngineSession.ReportError(
  const ErrorMessage: string);
begin
  FTimer.Enabled := False;
  FPrepareStarted := False;
  VoicevoxDebugLog('SimpleEngine error=' + ErrorMessage);
  if Assigned(FOnError) then FOnError(Self, ErrorMessage);
end;

procedure TSerifVoicevoxEngineSession.SetEngineExe(const Value: string);
begin
  if SameText(FEngineExe, Trim(Value)) then Exit;
  if FStartedEngine then StopStartedEngine;
  FEngineExe := Trim(Value);
  FPrepareStarted := False;
  FPrepareCount := 0;
  FReady := False;
end;

function TSerifVoicevoxEngineSession.StartEngine: Boolean;
var
  CommandLine: string;
  CurrentDirectory: string;
  ProcessInfo: TProcessInformation;
  StartupInfo: TStartupInfo;
begin
  Result := False;
  if not TFile.Exists(FEngineExe) then
  begin
    ReportError('VOICEVOX Engine ' +
      #$304C#$898B#$3064#$304B#$308A#$307E#$305B#$3093);
    Exit;
  end;
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));
  CommandLine := Format('"%s" --host 127.0.0.1 --port 50021 --output_log_utf8',
    [FEngineExe]);
  CurrentDirectory := TPath.GetDirectoryName(FEngineExe);
  if not CreateProcess(PChar(FEngineExe), PChar(CommandLine), nil, nil,
    False, CREATE_NO_WINDOW, nil, PChar(CurrentDirectory), StartupInfo,
    ProcessInfo) then
  begin
    ReportError('VOICEVOX Engine ' +
      #$3092#$8D77#$52D5#$3067#$304D#$307E#$305B#$3093);
    Exit;
  end;
  CloseHandle(ProcessInfo.hThread);
  FProcessHandle := ProcessInfo.hProcess;
  FStartedEngine := True;
  Result := True;
  VoicevoxDebugLog(Format('SimpleEngine started pid=%d',
    [ProcessInfo.dwProcessId]));
end;

procedure TSerifVoicevoxEngineSession.StopStartedEngine;
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

procedure TSerifVoicevoxEngineSession.TimerTimer(Sender: TObject);
begin
  FTimer.Enabled := False;
  if (FPrepareCount = 0) and not FStartedEngine then
  begin
    if IsApiReady then
    begin
      FReady := True;
      if Assigned(FOnReady) then FOnReady(Self);
      Exit;
    end;
    if FEngineExe = '' then
    begin
      FPrepareStarted := False;
      if Assigned(FOnEnginePathRequired) then
        FOnEnginePathRequired(Self);
      Exit;
    end;
    if not StartEngine then Exit;
  end
  else
  begin
    Inc(FPrepareCount);
    if IsApiReady then
    begin
      FReady := True;
      if Assigned(FOnReady) then FOnReady(Self);
      Exit;
    end;
    if FStartedEngine and not IsStartedEngineRunning then
    begin
      ReportError('VOICEVOX Engine ' +
        #$304C#$7D42#$4E86#$3057#$307E#$3057#$305F);
      Exit;
    end;
    if FPrepareCount >= POLL_TIMEOUT_COUNT then
    begin
      ReportError('VOICEVOX Engine ' +
        #$306E#$6E96#$5099#$306B#$5931#$6557#$3057#$307E#$3057#$305F);
      Exit;
    end;
  end;
  FTimer.Interval := POLL_INTERVAL_MS;
  FTimer.Enabled := True;
end;

end.
