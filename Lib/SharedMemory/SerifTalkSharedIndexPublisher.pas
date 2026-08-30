unit SerifTalkSharedIndexPublisher;

// SerifDrawが参照する現在フレーム索引と履歴を発行する。

interface

function PublishSerifTalkIndex(CurrentFrame, Layer: Integer;
  const Chara, Emote, Direction, Serif: string): Boolean;

implementation

uses
  System.Math,
  System.SysUtils,
  Winapi.Windows,
  SerifSharedIndex,
  SharedMemoryBase;

const
  INDEX_MUTEX_NAME = 'Local\ShareTalkIndex.Mutex';

var
  HistoryMemory: TSharedMemoryStringList;
  IndexMemory: TSharedMemoryStringList;
  IndexMutex: THandle;

function NextGeneration(Value: Integer): Integer;
begin
  if Value >= MaxInt then
    Result := 1
  else
    Result := Value + 1;
end;

function EncodeRecordForSharedMemory(var RecordData: TSerifIndexRecord;
  out Text: string): Boolean;
var
  Excess: Integer;
  NewLength: Integer;
begin
  Text := EncodeSerifIndexRecord(RecordData);
  while Length(Text) >= SERIF_INDEX_MAX_TEXT_LENGTH do
  begin
    Excess := Length(Text) - (SERIF_INDEX_MAX_TEXT_LENGTH - 1);
    NewLength := Length(RecordData.Serif) - Max(1, Excess);
    if NewLength < 0 then
      NewLength := 0;
    if NewLength = Length(RecordData.Serif) then
      Break;
    RecordData.Serif := Copy(RecordData.Serif, 1, NewLength);
    Text := EncodeSerifIndexRecord(RecordData);
  end;
  Result := Length(Text) < SERIF_INDEX_MAX_TEXT_LENGTH;
end;

function PublishTo(Memory: TSharedMemoryStringList;
  CurrentFrame, Layer: Integer; const Chara, Emote, Direction, Serif: string;
  ResetOnFrameChange: Boolean): Boolean;
var
  EncodedRecord: string;
  EvictOldest: Boolean;
  ExistingRecord: TSerifIndexRecord;
  Header: TSerifIndexHeader;
  HeaderText: string;
  I: Integer;
  IsNewRecord: Boolean;
  MoveToEnd: Boolean;
  PreviousGeneration: Integer;
  RecordData: TSerifIndexRecord;
  RecordSlot: Integer;
begin
  Result := False;
  if (Memory = nil) or not Memory.IsOpened or
    (Layer < 0) or (Layer >= SERIF_INDEX_MAX_RECORDS) then
    Exit;

  HeaderText := Memory.Strings[0];
  PreviousGeneration := 0;
  if TryDecodeSerifIndexHeader(HeaderText, Header) then
    PreviousGeneration := Header.Generation;
  if not TryDecodeSerifIndexHeader(HeaderText, Header) or
    not Header.Ready or
    (ResetOnFrameChange and (Header.CurrentFrame <> CurrentFrame)) then
  begin
    Header := System.Default(TSerifIndexHeader);
    Header.Generation := PreviousGeneration;
  end;
  Header.CurrentFrame := CurrentFrame;
  Header.Generation := NextGeneration(Header.Generation);
  Header.PublishedTick := GetTickCount64;
  Header.Ready := False;
  Memory.Strings[0] := EncodeSerifIndexHeader(Header);

  RecordSlot := 0;
  EvictOldest := False;
  IsNewRecord := False;
  for I := 1 to Header.Count do
    if TryDecodeSerifIndexRecord(Memory.Strings[I], ExistingRecord) and
      (ExistingRecord.Layer = Layer) then
    begin
      RecordSlot := I;
      Break;
    end;
  if RecordSlot = 0 then
  begin
    if Header.Count >= SERIF_INDEX_MAX_RECORDS then
    begin
      if ResetOnFrameChange then
      begin
        Header.Ready := True;
        Memory.Strings[0] := EncodeSerifIndexHeader(Header);
        Exit;
      end;
      EvictOldest := True;
      RecordSlot := Header.Count;
    end;
    if RecordSlot = 0 then
    begin
      Inc(Header.Count);
      RecordSlot := Header.Count;
      IsNewRecord := True;
    end;
  end;

  RecordData.Layer := Layer;
  RecordData.Chara := Chara;
  RecordData.Emote := Emote;
  RecordData.Direction := Direction;
  RecordData.Serif := Serif;
  if not EncodeRecordForSharedMemory(RecordData, EncodedRecord) then
  begin
    if IsNewRecord then
      Dec(Header.Count);
    Header.Ready := True;
    Memory.Strings[0] := EncodeSerifIndexHeader(Header);
    Exit;
  end;

  MoveToEnd := not ResetOnFrameChange and (RecordSlot < Header.Count);
  if EvictOldest then
    for I := 1 to Header.Count - 1 do
      Memory.Strings[I] := Memory.Strings[I + 1]
  else if MoveToEnd then
  begin
    for I := RecordSlot to Header.Count - 1 do
      Memory.Strings[I] := Memory.Strings[I + 1];
    RecordSlot := Header.Count;
  end;
  Memory.Strings[RecordSlot] := EncodedRecord;
  Header.Ready := True;
  Memory.Strings[0] := EncodeSerifIndexHeader(Header);
  Result := True;
end;

function LockIndex: Boolean;
begin
  Result := (IndexMutex <> 0) and
    (WaitForSingleObject(IndexMutex, 1000) in
      [WAIT_OBJECT_0, WAIT_ABANDONED]);
end;

function PublishSerifTalkIndex(CurrentFrame, Layer: Integer;
  const Chara, Emote, Direction, Serif: string): Boolean;
begin
  Result := False;
  if not LockIndex then
    Exit;
  try
    Result := PublishTo(IndexMemory, CurrentFrame, Layer, Chara, Emote,
      Direction, Serif, True);
    PublishTo(HistoryMemory, CurrentFrame, Layer, Chara, Emote,
      Direction, Serif, False);
  finally
    ReleaseMutex(IndexMutex);
  end;
end;

procedure OpenSharedMemory;
begin
  IndexMutex := CreateMutex(nil, False, INDEX_MUTEX_NAME);
  if IndexMutex = 0 then
    Exit;
  try
    IndexMemory := TSharedMemoryStringList.Create(SERIF_INDEX_SHARED_NAME,
      SERIF_INDEX_MAX_RECORDS + 1, SERIF_INDEX_MAX_TEXT_LENGTH);
    HistoryMemory := TSharedMemoryStringList.Create(SERIF_HISTORY_SHARED_NAME,
      SERIF_INDEX_MAX_RECORDS + 1, SERIF_INDEX_MAX_TEXT_LENGTH);
  except
    FreeAndNil(HistoryMemory);
    FreeAndNil(IndexMemory);
  end;
end;

initialization
  OpenSharedMemory;

finalization
  HistoryMemory.Free;
  IndexMemory.Free;
  if IndexMutex <> 0 then
    CloseHandle(IndexMutex);

end.
