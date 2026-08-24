unit SerifBoardRenderThread;

interface

uses
  Winapi.Windows, Winapi.Messages, System.Classes, System.SysUtils;

const
  WM_SERIFBOARD_RENDER_FINISH = WM_USER + $4701;

type
  TSerifBoardRenderThreadFinishEvent = procedure(const AException: Exception) of object;

  ISerifBoardRenderThreadHandle = interface
    ['{0C4FBBF3-C558-448E-9BE6-410358E02F48}']
    procedure Detach;
    function IsRunning: Boolean;
  end;

  TSerifBoardRenderThread = class(TThread)
  private
    FWorkProc: TThreadMethod;
    FOwnedObject: TObject;
    FFreeOwnedObject: Boolean;
    FHandleRef: ISerifBoardRenderThreadHandle;
    FHandleOwner: TObject;
    FExceptionClassName: string;
    FExceptionMessage: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const AWorkProc: TThreadMethod; AOwnedObject: TObject = nil;
      const AFreeOwnedObject: Boolean = False);
    destructor Destroy; override;

    class function Run(const AWorkProc: TThreadMethod; AOwnedObject: TObject = nil;
      const AFreeOwnedObject: Boolean = False;
      const AOnFinish: TSerifBoardRenderThreadFinishEvent = nil): ISerifBoardRenderThreadHandle;
  end;

implementation

type
  TSerifBoardRenderThreadHandle = class(TInterfacedObject, ISerifBoardRenderThreadHandle)
  private
    FOnFinish: TSerifBoardRenderThreadFinishEvent;
    FRunning: Boolean;
    FHandle: HWND;
    FHasException: Boolean;
    FExceptionClassName: string;
    FExceptionMessage: string;
    FSelfRef: ISerifBoardRenderThreadHandle;
    procedure InternalWndProc(var Msg: TMessage);
    procedure PostThreadTerminated(const AExceptionClassName, AExceptionMessage: string);
    procedure ThreadTerminated;
  public
    constructor Create(const AOnFinish: TSerifBoardRenderThreadFinishEvent);
    destructor Destroy; override;
    procedure Detach;
    function IsRunning: Boolean;
  end;

constructor TSerifBoardRenderThreadHandle.Create(const AOnFinish: TSerifBoardRenderThreadFinishEvent);
begin
  inherited Create;
  FOnFinish := AOnFinish;
  FRunning := True;
  FHandle := AllocateHWnd(InternalWndProc);
end;

destructor TSerifBoardRenderThreadHandle.Destroy;
begin
  if FHandle <> 0 then
    DeallocateHWnd(FHandle);
  inherited;
end;

procedure TSerifBoardRenderThreadHandle.Detach;
begin
  FOnFinish := nil;
end;

function TSerifBoardRenderThreadHandle.IsRunning: Boolean;
begin
  Result := FRunning;
end;

procedure TSerifBoardRenderThreadHandle.InternalWndProc(var Msg: TMessage);
begin
  if Msg.Msg = WM_SERIFBOARD_RENDER_FINISH then
  begin
    ThreadTerminated;
    Msg.Result := 0;
  end
  else
    Msg.Result := DefWindowProc(FHandle, Msg.Msg, Msg.WParam, Msg.LParam);
end;

procedure TSerifBoardRenderThreadHandle.PostThreadTerminated(
  const AExceptionClassName, AExceptionMessage: string);
begin
  FHasException := (AExceptionClassName <> '') or (AExceptionMessage <> '');
  FExceptionClassName := AExceptionClassName;
  FExceptionMessage := AExceptionMessage;

  FSelfRef := Self;
  if not PostMessage(FHandle, WM_SERIFBOARD_RENDER_FINISH, 0, 0) then
  begin
    FRunning := False;
    FSelfRef := nil;
  end;
end;

procedure TSerifBoardRenderThreadHandle.ThreadTerminated;
var
  RaisedException: Exception;
begin
  FRunning := False;

  RaisedException := nil;
  try
    if FHasException then
    begin
      if (FExceptionClassName <> '') and (FExceptionMessage <> '') then
        RaisedException := Exception.CreateFmt('%s: %s', [FExceptionClassName, FExceptionMessage])
      else if FExceptionMessage <> '' then
        RaisedException := Exception.Create(FExceptionMessage)
      else
        RaisedException := Exception.Create(FExceptionClassName);
    end;

    if Assigned(FOnFinish) then
      FOnFinish(RaisedException);
  finally
    RaisedException.Free;
    FSelfRef := nil;
  end;
end;

constructor TSerifBoardRenderThread.Create(const AWorkProc: TThreadMethod; AOwnedObject: TObject;
  const AFreeOwnedObject: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkProc := AWorkProc;
  FOwnedObject := AOwnedObject;
  FFreeOwnedObject := AFreeOwnedObject;
end;

destructor TSerifBoardRenderThread.Destroy;
begin
  if FFreeOwnedObject then
    FreeAndNil(FOwnedObject);
  inherited;
end;

procedure TSerifBoardRenderThread.Execute;
begin
  try
    try
      if Assigned(FWorkProc) then
        FWorkProc;
    except
      on E: Exception do
      begin
        FExceptionClassName := E.ClassName;
        FExceptionMessage := E.Message;
        raise;
      end;
    end;
  finally
    if Assigned(FHandleOwner) then
      TSerifBoardRenderThreadHandle(FHandleOwner).PostThreadTerminated(
        FExceptionClassName, FExceptionMessage);
  end;
end;

class function TSerifBoardRenderThread.Run(const AWorkProc: TThreadMethod; AOwnedObject: TObject;
  const AFreeOwnedObject: Boolean; const AOnFinish: TSerifBoardRenderThreadFinishEvent): ISerifBoardRenderThreadHandle;
var
  Handle: TSerifBoardRenderThreadHandle;
  Thread: TSerifBoardRenderThread;
begin
  Handle := TSerifBoardRenderThreadHandle.Create(AOnFinish);
  Thread := TSerifBoardRenderThread.Create(AWorkProc, AOwnedObject, AFreeOwnedObject);
  Thread.FHandleRef := Handle;
  Thread.FHandleOwner := Handle;
  Thread.FreeOnTerminate := True;
  Thread.Start;
  Result := Handle;
end;

end.
