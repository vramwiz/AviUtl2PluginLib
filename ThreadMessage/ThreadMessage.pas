unit ThreadMessage;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes;

type
  //============================================================
  // 送信側スレッド
  //============================================================
  TThreadMessageSender = class(TThread)
  private
    FReceiver: TObject;              // レシーバー
    FWaitingAck: Boolean;            // DoMessage 用 ACK 待ち
    FWaitingFinishAck: Boolean;      // DoFinish 用 ACK 待ち
  protected
    function SendMessageToReceiver(const Index: Integer): Boolean;
    function SendFinishToReceiver: Boolean;
  public
    constructor Create(AReceiver: TObject); virtual;
    destructor Destroy; override;

    procedure ResetAck;
    procedure ResetFinishAck;
  end;


  //============================================================
  // 受信側（隠しウインドウ）
  //============================================================
  TThreadMessageReceiver = class
  private
    FHandle: HWND;
    FMsgID: UINT;            // Message 用
    FMsgIDFinish: UINT;
    FOnFinish: TNotifyEvent;      // Finish 用（追加）

    procedure InternalWndProc(var Msg: TMessage);
  protected
    FSender: TThreadMessageSender;

    procedure WndProc(var Msg: TMessage); virtual;

    // 既存互換
    procedure DoMessage(Index: Integer); virtual; abstract;

    // 追加分：Finish 処理
    procedure DoFinish; virtual;

    // Sender を生成（継承側で実装）
    function DoCreate: TThreadMessageSender; virtual; abstract;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure StartThread; virtual;

    property Handle: HWND read FHandle;
    property MsgID: UINT read FMsgID write FMsgID;
    property MsgIDFinish: UINT read FMsgIDFinish write FMsgIDFinish;
    property OnFinish : TNotifyEvent read FOnFinish write FOnFinish;
  end;

implementation

//============================================================
// TThreadMessageReceiver
//============================================================
constructor TThreadMessageReceiver.Create;
begin
  inherited;

  FHandle := AllocateHWnd(InternalWndProc);

  // 既存のメッセージ
  FMsgID := RegisterWindowMessage('ThreadMessage.Receiver');

  // 新規追加：Finish メッセージ
  FMsgIDFinish := RegisterWindowMessage('ThreadMessage.Receiver.Finish');
end;

destructor TThreadMessageReceiver.Destroy;
begin
  if Assigned(FSender) then
  begin
    FSender.Terminate;
    FSender.WaitFor;
    FSender.Free;
  end;

  DeallocateHWnd(FHandle);

  inherited;
end;

procedure TThreadMessageReceiver.InternalWndProc(var Msg: TMessage);
begin
  if (Msg.Msg = FMsgID) or (Msg.Msg = FMsgIDFinish) then
  begin
    WndProc(Msg);
    Msg.Result := 0;
  end
  else
    Msg.Result := DefWindowProc(FHandle, Msg.Msg, Msg.WParam, Msg.LParam);
end;

procedure TThreadMessageReceiver.StartThread;
begin
  if Assigned(FSender) then
  begin
    FSender.Terminate;
    Sleep(10);
    FSender.WaitFor;
    Sleep(10);
    FSender.Free;
  end;

  FSender := DoCreate;
  FSender.Start;
end;

procedure TThreadMessageReceiver.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = FMsgID then
  begin
    // 既存互換
    DoMessage(Msg.WParam);
  end
  else
  if Msg.Msg = FMsgIDFinish then
  begin
    // 新規：終了メッセージ
    DoFinish;
  end;
end;

procedure TThreadMessageReceiver.DoFinish;
begin
  // デフォルト実装は空
  // 派生クラスで必要に応じて実装
  if Assigned(FOnFinish) then FOnFinish(Self);
end;


//============================================================
// TThreadMessageSender
//============================================================

constructor TThreadMessageSender.Create(AReceiver: TObject);
begin
  FReceiver := AReceiver;
  FWaitingAck := False;
  FWaitingFinishAck := False;
  inherited Create(True);
end;

destructor TThreadMessageSender.Destroy;
begin
  inherited;
end;

procedure TThreadMessageSender.ResetAck;
begin
  FWaitingAck := False;
end;

procedure TThreadMessageSender.ResetFinishAck;
begin
  FWaitingFinishAck := False;
end;

function TThreadMessageSender.SendMessageToReceiver(const Index: Integer): Boolean;
var
  R: TThreadMessageReceiver;
begin
  Result := False;

  if FWaitingAck then Exit(False);

  R := TThreadMessageReceiver(FReceiver);
  if (R = nil) or (R.Handle = 0) then Exit(False);

  if PostMessage(R.Handle, R.MsgID, Index, 0) then
  begin
    FWaitingAck := True;
    Result := True;
  end;
end;

function TThreadMessageSender.SendFinishToReceiver: Boolean;
var
  R: TThreadMessageReceiver;
begin
  Result := False;

  if FWaitingFinishAck then Exit(False);

  R := TThreadMessageReceiver(FReceiver);
  if (R = nil) or (R.Handle = 0) then Exit(False);

  if PostMessage(R.Handle, R.MsgIDFinish, 0, 0) then
  begin
    FWaitingFinishAck := True;
    Result := True;
  end;
end;

end.

