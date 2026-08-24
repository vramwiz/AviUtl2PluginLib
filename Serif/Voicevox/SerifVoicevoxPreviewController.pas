// 1行入力GUIの音声生成・停止・MCI再生を単一状態として管理する。
unit SerifVoicevoxPreviewController;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.MMSystem, System.Classes, Vcl.ExtCtrls,
  SerifVoicevoxAudioSettings;

type
  // 確認再生用の一時音声を生成するために必要な、現在の入力と音声設定一式。
  TSerifVoicevoxPreviewRequest = record
    // 合成時にaudio_queryへ適用する話速・音高・抑揚・音量・前後無音。
    AudioValues: TSerifVoicevoxAudioValues;
    // 一時ファイル名を組み立てるキャラクター名。
    CharacterName: string;
    // アクセント・イントネーション・音素長を含む編集済みaudio_query。
    QueryJson: string;
    // VOICEVOX Engineのstyle ID。
    SpeakerId: Integer;
    // 一時ファイル名を組み立てるstyle名。
    StyleName: string;
    // 合成対象として正規化済みのセリフ本文。
    Text: string;
  end;

  TSerifVoicevoxPreviewStatusEvent = procedure(Sender: TObject;
    const Active: Boolean; const StatusText: string) of object;

  TSerifVoicevoxPreviewController = class(TComponent)
  private const
    COMPLETE_MESSAGE = WM_APP + $5724;
    MEDIA_ALIAS = 'Syncroh2VoicevoxSimplePreview';
  private type
    TPreviewState = (psIdle, psGenerating, psStopping, psPlaying);
  private
    FNotifyHandle: HWND;
    FOnStatus: TSerifVoicevoxPreviewStatusEvent;
    FOperationId: Cardinal;
    FPending: Boolean;
    FPendingRequest: TSerifVoicevoxPreviewRequest;
    FState: TPreviewState;
    FThread: TThread;
    FTimer: TTimer;
    FWaveFileName: string;
    FTextFileName: string;
    FWarmupWaveOut: HWAVEOUT;
    procedure ClosePlaybackDevice;
    procedure ClearFiles;
    procedure DeleteFiles(const WaveFileName, TextFileName: string);
    procedure Notify(const Active: Boolean; const StatusText: string);
    procedure Reset(const StatusText: string);
    procedure Start(const Request: TSerifVoicevoxPreviewRequest);
    procedure TimerTimer(Sender: TObject);
    procedure WindowProc(var Msg: TMessage);
  public
    // 完了通知ウィンドウと、MCI再生終了を監視するタイマーを生成する。
    constructor Create(AOwner: TComponent); override;
    // 実行中のワーカーを待機し、MCIと確認再生用の一時ファイルを後始末する。
    destructor Destroy; override;
    // 音声生成・停止待ち・再生のいずれかならTrueを返す。
    function Busy: Boolean;
    // 入力画面の表示時に既定の音声出力デバイスを先行オープンして保持する。
    procedure PreparePlaybackDevice;
    // 進行中の生成結果を無効化し、再生中なら停止して一時ファイルを破棄する。
    procedure Stop;
    // 待機中なら生成・再生を開始し、処理中なら停止する。停止待ち中は最新要求を保留する。
    procedure Toggle(const Request: TSerifVoicevoxPreviewRequest);
    // プレビューの稼働状態と画面へ表示する状態文言を通知する。
    property OnStatus: TSerifVoicevoxPreviewStatusEvent
      read FOnStatus write FOnStatus;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  SerifVoicevoxApi, SerifVoicevoxDebugLog;

type
  TSerifVoicevoxPreviewWorker = class(TThread)
  private
    FErrorMessage: string;
    FNotifyHandle: HWND;
    FOperationId: Cardinal;
    FRequest: TSerifVoicevoxPreviewRequest;
    FSuccess: Boolean;
    FTextFileName: string;
    FWaveFileName: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const NotifyHandle: HWND; const OperationId: Cardinal;
      const Request: TSerifVoicevoxPreviewRequest);
    property ErrorMessage: string read FErrorMessage;
    property OperationId: Cardinal read FOperationId;
    property Success: Boolean read FSuccess;
    property TextFileName: string read FTextFileName;
    property WaveFileName: string read FWaveFileName;
  end;

constructor TSerifVoicevoxPreviewWorker.Create(const NotifyHandle: HWND;
  const OperationId: Cardinal; const Request: TSerifVoicevoxPreviewRequest);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FNotifyHandle := NotifyHandle;
  FOperationId := OperationId;
  FRequest := Request;
end;

procedure TSerifVoicevoxPreviewWorker.Execute;
begin
  try
    if not Terminated then
      FSuccess := TSerifVoicevoxApi.CreateInputFiles(FRequest.Text,
        FRequest.CharacterName, FRequest.StyleName, FRequest.SpeakerId,
        FRequest.AudioValues, FRequest.QueryJson, FWaveFileName,
        FTextFileName, FErrorMessage);
  except
    on E: Exception do
    begin
      FSuccess := False;
      FErrorMessage := E.Message;
    end;
  end;
  PostMessage(FNotifyHandle,
    TSerifVoicevoxPreviewController.COMPLETE_MESSAGE,
    WPARAM(FOperationId), 0);
end;

constructor TSerifVoicevoxPreviewController.Create(AOwner: TComponent);
begin
  inherited;
  FNotifyHandle := AllocateHWnd(WindowProc);
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 100;
  FTimer.OnTimer := TimerTimer;
end;

destructor TSerifVoicevoxPreviewController.Destroy;
var
  Worker: TSerifVoicevoxPreviewWorker;
begin
  FTimer.Enabled := False;
  if Assigned(FThread) then
  begin
    Worker := TSerifVoicevoxPreviewWorker(FThread);
    Worker.Terminate;
    Worker.WaitFor;
    DeleteFiles(Worker.WaveFileName, Worker.TextFileName);
    FreeAndNil(FThread);
  end;
  Reset('');
  ClosePlaybackDevice;
  if FNotifyHandle <> 0 then DeallocateHWnd(FNotifyHandle);
  inherited;
end;

function TSerifVoicevoxPreviewController.Busy: Boolean;
begin
  Result := FState <> psIdle;
end;

procedure TSerifVoicevoxPreviewController.ClosePlaybackDevice;
begin
  if FWarmupWaveOut = 0 then Exit;
  waveOutReset(FWarmupWaveOut);
  waveOutClose(FWarmupWaveOut);
  FWarmupWaveOut := 0;
  VoicevoxDebugLog('PreviewController playback device closed');
end;

procedure TSerifVoicevoxPreviewController.ClearFiles;
var
  TextFileName: string;
  WaveFileName: string;
begin
  WaveFileName := FWaveFileName;
  TextFileName := FTextFileName;
  FWaveFileName := '';
  FTextFileName := '';
  FTimer.Enabled := False;
  mciSendString(PChar('close ' + MEDIA_ALIAS), nil, 0, 0);
  DeleteFiles(WaveFileName, TextFileName);
end;

procedure TSerifVoicevoxPreviewController.DeleteFiles(const WaveFileName,
  TextFileName: string);
var
  Folder: string;
begin
  if TFile.Exists(TextFileName) then TFile.Delete(TextFileName);
  if TFile.Exists(WaveFileName) then TFile.Delete(WaveFileName);
  // 初回再生前は一時ファイル名が未設定なので、空文字をTPathへ渡さない。
  if WaveFileName <> '' then
    Folder := TPath.GetDirectoryName(WaveFileName)
  else if TextFileName <> '' then
    Folder := TPath.GetDirectoryName(TextFileName)
  else
    Exit;
  if (Folder <> '') and TDirectory.Exists(Folder) then
    try
      TDirectory.Delete(Folder, False);
    except
      // 一時ファイル後始末の失敗で操作を止めない。
    end;
end;

procedure TSerifVoicevoxPreviewController.Notify(const Active: Boolean;
  const StatusText: string);
begin
  if Assigned(FOnStatus) then FOnStatus(Self, Active, StatusText);
end;

procedure TSerifVoicevoxPreviewController.PreparePlaybackDevice;
const
  CHANNEL_COUNT = 1;
  SAMPLE_RATE = 24000;
  BITS_PER_SAMPLE = 16;
var
  OpenResult: MMRESULT;
  WaveFormat: TWaveFormatEx;
begin
  if FWarmupWaveOut <> 0 then Exit;
  FillChar(WaveFormat, SizeOf(WaveFormat), 0);
  WaveFormat.wFormatTag := WAVE_FORMAT_PCM;
  WaveFormat.nChannels := CHANNEL_COUNT;
  WaveFormat.nSamplesPerSec := SAMPLE_RATE;
  WaveFormat.wBitsPerSample := BITS_PER_SAMPLE;
  WaveFormat.nBlockAlign := WaveFormat.nChannels *
    (WaveFormat.wBitsPerSample div 8);
  WaveFormat.nAvgBytesPerSec := WaveFormat.nSamplesPerSec *
    WaveFormat.nBlockAlign;
  OpenResult := waveOutOpen(@FWarmupWaveOut, WAVE_MAPPER, @WaveFormat,
    0, 0, CALLBACK_NULL);
  if OpenResult = MMSYSERR_NOERROR then
    VoicevoxDebugLog('PreviewController playback device opened early')
  else
  begin
    FWarmupWaveOut := 0;
    VoicevoxDebugLog(Format(
      'PreviewController playback device open failed mmresult=%d',
      [OpenResult]));
  end;
end;

procedure TSerifVoicevoxPreviewController.Reset(const StatusText: string);
begin
  ClearFiles;
  FPending := False;
  FState := psIdle;
  Notify(False, StatusText);
end;

procedure TSerifVoicevoxPreviewController.Start(
  const Request: TSerifVoicevoxPreviewRequest);
begin
  if (FState <> psIdle) or Assigned(FThread) then Exit;
  ClearFiles;
  Inc(FOperationId);
  if FOperationId = 0 then Inc(FOperationId);
  FState := psGenerating;
  Notify(True, #$751F#$6210#$4E2D);
  try
    FThread := TSerifVoicevoxPreviewWorker.Create(FNotifyHandle,
      FOperationId, Request);
    FThread.Start;
  except
    on E: Exception do
    begin
      FreeAndNil(FThread);
      Reset(E.Message);
    end;
  end;
end;

procedure TSerifVoicevoxPreviewController.Stop;
begin
  case FState of
    psGenerating:
      begin
        if Assigned(FThread) then FThread.Terminate;
        FState := psStopping;
        Notify(True, #$505C#$6B62#$4E2D);
      end;
    psPlaying:
      Reset('');
  end;
end;

procedure TSerifVoicevoxPreviewController.TimerTimer(Sender: TObject);
var
  Mode: array[0..31] of Char;
begin
  Mode[0] := #0;
  if (mciSendString(PChar('status ' + MEDIA_ALIAS + ' mode'), Mode,
    Length(Mode), 0) = 0) and SameText(Mode, 'playing') then Exit;
  Reset('');
end;

procedure TSerifVoicevoxPreviewController.Toggle(
  const Request: TSerifVoicevoxPreviewRequest);
begin
  if FState = psStopping then
  begin
    FPendingRequest := Request;
    FPending := True;
    Exit;
  end;
  if FState <> psIdle then
  begin
    Stop;
    Exit;
  end;
  Start(Request);
end;

procedure TSerifVoicevoxPreviewController.WindowProc(var Msg: TMessage);
var
  ErrorMessage: string;
  Pending: Boolean;
  PendingRequest: TSerifVoicevoxPreviewRequest;
  Success: Boolean;
  TextFileName: string;
  WaveFileName: string;
  Worker: TSerifVoicevoxPreviewWorker;
begin
  if Msg.Msg <> COMPLETE_MESSAGE then
  begin
    Msg.Result := DefWindowProc(FNotifyHandle, Msg.Msg, Msg.WParam,
      Msg.LParam);
    Exit;
  end;
  Msg.Result := 0;
  if not Assigned(FThread) then Exit;
  Worker := TSerifVoicevoxPreviewWorker(FThread);
  if Cardinal(Msg.WParam) <> Worker.OperationId then Exit;
  Worker.WaitFor;
  Success := Worker.Success and not Worker.Terminated;
  ErrorMessage := Worker.ErrorMessage;
  WaveFileName := Worker.WaveFileName;
  TextFileName := Worker.TextFileName;
  FThread := nil;
  Worker.Free;

  if (Cardinal(Msg.WParam) <> FOperationId) or
    (FState = psStopping) then
  begin
    DeleteFiles(WaveFileName, TextFileName);
    Pending := FPending;
    PendingRequest := FPendingRequest;
    Reset('');
    if Pending then Start(PendingRequest);
    Exit;
  end;
  if not Success then
  begin
    DeleteFiles(WaveFileName, TextFileName);
    Reset(ErrorMessage);
    Exit;
  end;

  FWaveFileName := WaveFileName;
  FTextFileName := TextFileName;
  if (mciSendString(PChar('open "' + FWaveFileName + '" type waveaudio alias ' +
    MEDIA_ALIAS), nil, 0, 0) <> 0) or
    (mciSendString(PChar('play ' + MEDIA_ALIAS), nil, 0, 0) <> 0) then
  begin
    Reset(#$97F3#$58F0#$3092#$518D#$751F#$3067#$304D#$307E#$305B#$3093);
    Exit;
  end;
  FState := psPlaying;
  Notify(True, #$518D#$751F#$4E2D);
  FTimer.Enabled := True;
end;

end.
