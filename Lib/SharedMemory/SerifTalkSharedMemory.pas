unit SerifTalkSharedMemory;

// Syncroh2互換のLocal\ShareTalkを、MMDの複数DLL間で排他して読み書きする。

interface

const
  SERIF_TALK_SHARED_NAME = 'Local\ShareTalk';
  SERIF_TALK_MAX_LINES = 100;
  SERIF_TALK_MAX_TEXT_LENGTH = 4000;

function PublishSerifTalkText(Layer: Integer; const Text: string): Boolean;
function TryReadSerifTalkText(Layer: Integer; out Text: string): Boolean;

implementation

uses
  Winapi.Windows,
  SharedMemoryBase;

const
  SERIF_TALK_MUTEX_NAME = 'Local\ShareTalk.Mutex';

var
  SharedMemory: TSharedMemoryStringList;
  SharedMutex: THandle;

function ValidLayer(Layer: Integer): Boolean;
begin
  Result := (Layer >= 0) and (Layer < SERIF_TALK_MAX_LINES);
end;

function LockSharedMemory: Boolean;
begin
  Result := (SharedMutex <> 0) and
    (WaitForSingleObject(SharedMutex, 1000) in
      [WAIT_OBJECT_0, WAIT_ABANDONED]);
end;

procedure UnlockSharedMemory;
begin
  if SharedMutex <> 0 then
    ReleaseMutex(SharedMutex);
end;

function PublishSerifTalkText(Layer: Integer; const Text: string): Boolean;
begin
  Result := False;
  if not ValidLayer(Layer) or (SharedMemory = nil) or
    not SharedMemory.IsOpened or
    (Length(Text) >= SERIF_TALK_MAX_TEXT_LENGTH) or
    not LockSharedMemory then Exit;
  try
    SharedMemory.Strings[Layer] := Text;
    Result := True;
  finally
    UnlockSharedMemory;
  end;
end;

function TryReadSerifTalkText(Layer: Integer; out Text: string): Boolean;
begin
  Text := '';
  Result := False;
  if not ValidLayer(Layer) or (SharedMemory = nil) or
    not SharedMemory.IsOpened or not LockSharedMemory then Exit;
  try
    Text := SharedMemory.Strings[Layer];
    Result := Text <> '';
  finally
    UnlockSharedMemory;
  end;
end;

procedure OpenSharedMemory;
begin
  SharedMutex := CreateMutex(nil, False, SERIF_TALK_MUTEX_NAME);
  if SharedMutex = 0 then Exit;
  try
    SharedMemory := TSharedMemoryStringList.Create(SERIF_TALK_SHARED_NAME,
      SERIF_TALK_MAX_LINES, SERIF_TALK_MAX_TEXT_LENGTH);
  except
    SharedMemory := nil;
  end;
end;

initialization
  OpenSharedMemory;

finalization
  SharedMemory.Free;
  if SharedMutex <> 0 then
    CloseHandle(SharedMutex);

end.
