unit PipeClient;

interface

uses
  Windows, Messages, Classes, SysUtils, Forms;

type
  TPipeClientReceiveEvent =
    procedure(Sender: TObject; const Response: string; Success: Boolean; const ErrorMsg: string) of object;

const
  WM_PIPECLIENT_NOTIFY = WM_USER + $4300;

type
  TPipeClient = class
  private
    FPipeName  : string;
    FTimeout   : Cardinal;
    FOnReceive : TPipeClientReceiveEvent;
    FMsgWnd    : HWND;

    procedure ExecuteAsync(const Text: string; NeedResponse: Boolean);
    procedure DoReceive(const Response: string; Success: Boolean; const ErrorMsg: string);
    procedure WndProc(var Msg: TMessage);
  public
    constructor Create;
    destructor Destroy; override;

    function SendText(const Text: string): Boolean; // 非同期送信（返信あり）
    property PipeName: string read FPipeName write FPipeName;
    property Timeout: Cardinal read FTimeout write FTimeout;
    property OnReceive: TPipeClientReceiveEvent read FOnReceive write FOnReceive;
  end;

implementation

type
  TPipeClientWorker = class(TThread)
  private
    FOwner: TPipeClient;
    FText: string;
    FPipeName : string;
    FNeedResponse: Boolean;
    FResponse: string;
    FSuccess: Boolean;
    //FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TPipeClient; const PipeName,Text: string; NeedResponse: Boolean);
    procedure NotifyToMain;
  end;

{ ===== TPipeClient ===== }

constructor TPipeClient.Create;
begin
  inherited;
  FPipeName := 'MyPipe';
  FTimeout  := 5000;
  FMsgWnd   := AllocateHWnd(WndProc);
end;

destructor TPipeClient.Destroy;
begin
  if FMsgWnd <> 0 then
    DeallocateHWnd(FMsgWnd);
  inherited;
end;

function TPipeClient.SendText(const Text: string): Boolean;
begin
  ExecuteAsync(Text, True);
  Result := True;
end;

procedure TPipeClient.ExecuteAsync(const Text: string; NeedResponse: Boolean);
begin
  TPipeClientWorker.Create(Self, FPipeName,Text, NeedResponse);
end;

procedure TPipeClient.DoReceive(const Response: string; Success: Boolean; const ErrorMsg: string);
begin
  if Assigned(FOnReceive) then
    FOnReceive(Self, Response, Success, ErrorMsg);
end;

procedure TPipeClient.WndProc(var Msg: TMessage);
var
  Worker: TPipeClientWorker;
begin
  if Msg.Msg = WM_PIPECLIENT_NOTIFY then
  begin
    Worker := TPipeClientWorker(Msg.WParam);
    if Assigned(Worker) then
    begin
      // ★ PostMessage は非同期なので、Worker が完全終了してから使う
      Worker.WaitFor;
      try
        Worker.NotifyToMain;
      finally
        Worker.Free;
      end;
    end;

    Msg.Result := 0;
    Exit;
  end;

  Msg.Result := DefWindowProc(FMsgWnd, Msg.Msg, Msg.WParam, Msg.LParam);
end;


{ ===== TPipeClientWorker ===== }

constructor TPipeClientWorker.Create(AOwner: TPipeClient; const PipeName,Text: string; NeedResponse: Boolean);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FOwner    := AOwner;
  FPipeName := PipeName;
  FText     := Text;
  FNeedResponse := NeedResponse;
end;

procedure TPipeClientWorker.Execute;
var
  Pipe: THandle;
  BytesWritten, BytesRead: DWORD;
  Buffer: array[0..4095] of Byte;
  FullPipeName: string;
  Temp: UTF8String;
begin
  FSuccess := False;
  FResponse := '';
   FullPipeName := '\\.\pipe\' + FPipeName;

  // パイプ待機
  if not WaitNamedPipe(PChar(FullPipeName), FOwner.FTimeout) then Exit;

  // 接続
  Pipe := CreateFile(PChar(FullPipeName),GENERIC_READ or GENERIC_WRITE,0,nil,OPEN_EXISTING,0,0);

  if Pipe = INVALID_HANDLE_VALUE then Exit;

  try
    // ===== 送信 =====
    Temp := UTF8Encode(FText);

    if Length(Temp) > 0 then
    begin
      if not WriteFile(Pipe, Pointer(Temp)^, Length(Temp), BytesWritten, nil) then Exit;
    end;

    // ===== 応答受信 =====
    if FNeedResponse then
    begin
      if ReadFile(Pipe, Buffer, SizeOf(Buffer), BytesRead, nil) then
      begin
        if BytesRead > 0 then
        begin
          SetString(Temp, PAnsiChar(@Buffer[0]), BytesRead);
          FResponse := UTF8ToString(Temp);
        end;
      end
      else
      begin
        Exit;
      end;
    end;

    FSuccess := True;

  finally
    CloseHandle(Pipe);
  end;

  // ===== メインスレッド通知 =====
  if Assigned(FOwner) and (FOwner.FMsgWnd <> 0) then
    PostMessage(FOwner.FMsgWnd, WM_PIPECLIENT_NOTIFY, WPARAM(Self), 0);
end;


procedure TPipeClientWorker.NotifyToMain;
begin
  if Assigned(FOwner) then
    FOwner.DoReceive(FResponse, FSuccess, '');
end;

end.

