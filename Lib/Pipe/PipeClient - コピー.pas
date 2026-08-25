unit PipeClient;

interface

uses
  Windows;

type
  TPipeClient = class
  private
    FPipeName   : string;
    FTimeout    : Cardinal;
    FPipeHandle : THandle;
    FConnected  : Boolean;

    procedure OpenPipe;
    procedure ClosePipe;

  public
    constructor Create;
    destructor Destroy; override;

    // サーバーに接続を試みる
    function Connect: Boolean;

    // サーバーとの接続を終了する
    procedure Disconnect;

    // サーバーへ文字列を送信する
    function SendText(const Text: string): Boolean;

    // サーバーから文字列を受信する
    function ReceiveText: string;

    // 現在接続中かどうかを返す
    function IsConnected: Boolean;

    // 接続対象のパイプ名（例："MyPipe"）
    property PipeName: string read FPipeName write FPipeName;

    // 接続タイムアウト（ミリ秒）
    property Timeout: Cardinal read FTimeout write FTimeout;
  end;

implementation

{ TPipeClient }

constructor TPipeClient.Create;
begin
  inherited;
  FPipeName   := 'MyPipe';      // デフォルトパイプ名
  FTimeout    := 5000;          // デフォルトの接続タイムアウト（ミリ秒）
  FPipeHandle := INVALID_HANDLE_VALUE;
  FConnected  := False;
end;

destructor TPipeClient.Destroy;
begin
  Disconnect;
  inherited;
end;

function TPipeClient.Connect: Boolean;
var
  FullPipeName: string;
begin
  Result := False;
  FConnected := False;

  OpenPipe;

  if FPipeHandle = INVALID_HANDLE_VALUE then
    Exit;

  FConnected := True;
  Result := True;
end;

procedure TPipeClient.Disconnect;
begin
  ClosePipe;
  FConnected := False;
end;

function TPipeClient.IsConnected: Boolean;
begin
  Result := FConnected and (FPipeHandle <> INVALID_HANDLE_VALUE);
end;

procedure TPipeClient.OpenPipe;
var
  FullPipeName: UnicodeString;
begin
  FullPipeName := '\\.\pipe\' + FPipeName;

  if not WaitNamedPipeW(PWideChar(FullPipeName), FTimeout) then Exit;

  FPipeHandle := CreateFileW(
    PWideChar(FullPipeName),
    GENERIC_READ or GENERIC_WRITE,
    0,
    nil,
    OPEN_EXISTING,
    0,
    0
  );
end;


procedure TPipeClient.ClosePipe;
begin
  if FPipeHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FPipeHandle);
    FPipeHandle := INVALID_HANDLE_VALUE;
  end;
end;

function TPipeClient.ReceiveText: string;
var
  Buffer: array [0..1023] of Byte;
  BytesRead: DWORD;
  Temp: UTF8String;
begin
  Result := '';

  if (not FConnected) or (FPipeHandle = INVALID_HANDLE_VALUE) then
    Exit;

  if ReadFile(FPipeHandle, Buffer, SizeOf(Buffer), BytesRead, nil) and (BytesRead > 0) then
  begin
    SetString(Temp, PAnsiChar(@Buffer[0]), BytesRead);
    Result := UTF8Decode(Temp);
  end;
end;


function TPipeClient.SendText(const Text: string): Boolean;
var
  BytesWritten: DWORD;
  Buffer: UTF8String;
begin
  Result := False;

  if (not FConnected) or (FPipeHandle = INVALID_HANDLE_VALUE) then
    Exit;

  // Unicode → UTF-8（明示）
  Buffer := UTF8Encode(Text);

  Result := WriteFile(
    FPipeHandle,
    Pointer(Buffer)^,
    Length(Buffer),
    BytesWritten,
    nil
  ) and (BytesWritten = DWORD(Length(Buffer)));
end;


end.

