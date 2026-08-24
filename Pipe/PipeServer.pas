unit PipeServer;

interface

uses
  Windows, Messages, Classes, Forms, PipeServerTThread;

type
  TPipeServer = class
  private
    FPipeName   : string;
    FBufferSize : Cardinal;

    FIsDuplex     : Boolean;
    FTimeout      : Cardinal;
    FMaxInstances : Cardinal;

    FThread     : TPipeServerTThread;
    FOnReceive  : TPipeServerTThreadReceiveEvent;

    // ★ メインスレッド受信用の隠しウィンドウ
    FMsgWnd: HWND;

    procedure OnPipeReceive(Sender: TObject; const ReceivedStr: string; var SendStr: string);
    procedure WndProc(var Msg: TMessage);
  protected
    procedure DoReceive(const ReceivedStr: string; var SendStr: string);
  public
    constructor Create; overload;
    constructor Create(ANotifyWnd: HWND); overload; // 互換用（ANotifyWndは未使用でもOK）
    destructor Destroy; override;

    function Start: Boolean;
    procedure Stop;

    // 互換用（外部WndProcで受ける設計の名残があるなら使える）
    procedure ProcessPipeMessage(WParam: WPARAM);

    property PipeName  : string read FPipeName write FPipeName;
    property BufferSize: Cardinal read FBufferSize write FBufferSize;
    property OnReceive : TPipeServerTThreadReceiveEvent read FOnReceive write FOnReceive;
  end;

implementation

constructor TPipeServer.Create;
begin
  Create(0);
end;

constructor TPipeServer.Create(ANotifyWnd: HWND);
begin
  inherited Create;

  FPipeName     := 'MyPipe';
  FIsDuplex     := True;
  FTimeout      := 1000;
  FMaxInstances := 1;
  FBufferSize   := 4096;

  FThread := nil;

  // ★ 受信用の隠しウィンドウ（FolderWatchと同じ）
  FMsgWnd := AllocateHWnd(WndProc);
end;

destructor TPipeServer.Destroy;
begin
  Stop;

  if FMsgWnd <> 0 then DeallocateHWnd(FMsgWnd);

  inherited;
end;

procedure TPipeServer.DoReceive(const ReceivedStr: string; var SendStr: string);
begin
  if Assigned(FOnReceive) then FOnReceive(Self, ReceivedStr, SendStr);
end;

procedure TPipeServer.OnPipeReceive(Sender: TObject; const ReceivedStr: string; var SendStr: string);
begin
  DoReceive(ReceivedStr, SendStr);
end;

function TPipeServer.Start: Boolean;
begin
  Result := False;
  if Assigned(FThread) then Exit;

  // ★ 通知先は AviUtl2 の HWND ではなく、自前の FMsgWnd
  FThread := TPipeServerTThread.Create(FPipeName, FBufferSize, FIsDuplex, FTimeout, FMaxInstances, FMsgWnd);
  FThread.OnReceive := OnPipeReceive;
  Result := True;
end;

procedure TPipeServer.ProcessPipeMessage(WParam: WPARAM);
var
  ServerThread: TPipeServerTThread;
begin
  ServerThread := TPipeServerTThread(WParam);
  if ServerThread = nil then Exit;
  ServerThread.ProcessMainThread;
end;

procedure TPipeServer.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = WM_PIPE_NOTIFY then
  begin
    // ★ メインスレッド側で実行（AviUtl2 API を触るのはここ）
    ProcessPipeMessage(Msg.WParam);
    Msg.Result := 0;
    Exit;
  end;

  Msg.Result := DefWindowProc(FMsgWnd, Msg.Msg, Msg.WParam, Msg.LParam);
end;

procedure FreeAndNil(var Obj);
var
  Temp: TObject;
begin
  Temp := TObject(Obj);
  TObject(Obj) := nil;
  Temp.Free;
end;

procedure TPipeServer.Stop;
var
  PipeHandle: THandle;
  FullName: string;
begin
  if not Assigned(FThread) then Exit;

  // ★ 先に止める意思表示
  FThread.Terminate;

  // ★ WaitForSingleObject(FEventHandle) 側で詰まらないよう解除
  FThread.ReleaseWait;

  // ★ ConnectNamedPipe を解除するためのダミー接続
  FullName := '\\.\pipe\' + FPipeName;
  PipeHandle := CreateFile(PChar(FullName), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
  if PipeHandle <> INVALID_HANDLE_VALUE then CloseHandle(PipeHandle);

  FThread.WaitFor;
  FreeAndNil(FThread);
end;

end.

