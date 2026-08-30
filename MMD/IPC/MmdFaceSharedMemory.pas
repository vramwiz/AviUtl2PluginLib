unit MmdFaceSharedMemory;

// 表情レイヤーから表示モデルへ、レイヤー単位のモーフJSONを安全に渡す。

interface

uses
  AviUtl2FilterTypes;

type
  TMmdFaceSharedSnapshot = record
    WriterObjectID: Int64;
    WriterEffectID: Int64;
    TimelineFrame: Integer;
    ModelPathHash: UInt64;
    FaceData: string;
  end;

function HashFaceModelPath(const FileName: string): UInt64;
function PublishFaceSnapshot(Layer: Integer;
  const Snapshot: TMmdFaceSharedSnapshot): Boolean;
function TryReadFaceSnapshot(Layer: Integer; ModelPathHash: UInt64;
  out Snapshot: TMmdFaceSharedSnapshot): Boolean;
function GetFaceTimelineFrame(const ObjectInfo: POBJECT_INFO): Integer;

implementation

uses
  Winapi.Windows,
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils;

const
  MMD_FACE_SHARED_MAGIC = $4D4D4446; // MMDF
  MMD_FACE_SHARED_VERSION = 1;
  MMD_FACE_SHARED_DATA_SIZE = 1024 * 1024;

type
  PMmdFaceSharedBlock = ^TMmdFaceSharedBlock;
  TMmdFaceSharedBlock = packed record
    Magic: Cardinal;
    Version: Cardinal;
    Sequence: UInt64;
    WriterProcessID: Cardinal;
    WriterObjectID: Int64;
    WriterEffectID: Int64;
    TimelineFrame: Integer;
    ModelPathHash: UInt64;
    DataLength: Cardinal;
    Data: array[0..MMD_FACE_SHARED_DATA_SIZE - 1] of Byte;
  end;

  TMmdFaceSharedChannel = class
  private
    FMapping: THandle;
    FMutex: THandle;
    FView: PMmdFaceSharedBlock;
    function Lock: Boolean;
    procedure Unlock;
  public
    constructor Create(Layer: Integer);
    destructor Destroy; override;
    function Publish(const Snapshot: TMmdFaceSharedSnapshot): Boolean;
    function TryRead(ModelPathHash: UInt64;
      out Snapshot: TMmdFaceSharedSnapshot): Boolean;
  end;

var
  ChannelLock: TObject;
  Channels: TObjectDictionary<Integer, TMmdFaceSharedChannel>;

function ChannelName(const Kind: string; Layer: Integer): string;
begin
  Result := Format('Local\MMD.Face.%s.Layer.%d', [Kind, Layer]);
end;

constructor TMmdFaceSharedChannel.Create(Layer: Integer);
var
  IsOwner: Boolean;
begin
  inherited Create;
  FMutex := CreateMutex(nil, False, PChar(ChannelName('Mutex', Layer)));
  if FMutex = 0 then RaiseLastOSError;
  FMapping := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0,
    SizeOf(TMmdFaceSharedBlock), PChar(ChannelName('Memory', Layer)));
  if FMapping = 0 then RaiseLastOSError;
  IsOwner := GetLastError <> ERROR_ALREADY_EXISTS;
  FView := MapViewOfFile(FMapping, FILE_MAP_ALL_ACCESS, 0, 0,
    SizeOf(TMmdFaceSharedBlock));
  if FView = nil then RaiseLastOSError;
  if IsOwner then FillChar(FView^, SizeOf(FView^), 0);
end;

destructor TMmdFaceSharedChannel.Destroy;
begin
  if FView <> nil then UnmapViewOfFile(FView);
  if FMapping <> 0 then CloseHandle(FMapping);
  if FMutex <> 0 then CloseHandle(FMutex);
  inherited Destroy;
end;

function TMmdFaceSharedChannel.Lock: Boolean;
begin
  Result := (FMutex <> 0) and
    (WaitForSingleObject(FMutex, 1000) in [WAIT_OBJECT_0, WAIT_ABANDONED]);
end;

procedure TMmdFaceSharedChannel.Unlock;
begin
  ReleaseMutex(FMutex);
end;

function TMmdFaceSharedChannel.Publish(
  const Snapshot: TMmdFaceSharedSnapshot): Boolean;
var
  Bytes: TBytes;
begin
  Result := False;
  Bytes := TEncoding.UTF8.GetBytes(Snapshot.FaceData);
  if Length(Bytes) > MMD_FACE_SHARED_DATA_SIZE then Exit;
  if not Lock then Exit;
  try
    Inc(FView^.Sequence);
    FView^.Magic := MMD_FACE_SHARED_MAGIC;
    FView^.Version := MMD_FACE_SHARED_VERSION;
    FView^.WriterProcessID := GetCurrentProcessId;
    FView^.WriterObjectID := Snapshot.WriterObjectID;
    FView^.WriterEffectID := Snapshot.WriterEffectID;
    FView^.TimelineFrame := Snapshot.TimelineFrame;
    FView^.ModelPathHash := Snapshot.ModelPathHash;
    FView^.DataLength := Length(Bytes);
    if Length(Bytes) > 0 then
      Move(Bytes[0], FView^.Data[0], Length(Bytes));
    Inc(FView^.Sequence);
    Result := True;
  finally
    Unlock;
  end;
end;

function TMmdFaceSharedChannel.TryRead(ModelPathHash: UInt64;
  out Snapshot: TMmdFaceSharedSnapshot): Boolean;
var
  Bytes: TBytes;
begin
  Snapshot := Default(TMmdFaceSharedSnapshot);
  Result := False;
  if not Lock then Exit;
  try
    if (FView^.Magic <> MMD_FACE_SHARED_MAGIC) or
      (FView^.Version <> MMD_FACE_SHARED_VERSION) or
      ((FView^.Sequence and 1) <> 0) or
      (FView^.ModelPathHash <> ModelPathHash) or
      (FView^.DataLength > MMD_FACE_SHARED_DATA_SIZE) then Exit;
    Snapshot.WriterObjectID := FView^.WriterObjectID;
    Snapshot.WriterEffectID := FView^.WriterEffectID;
    Snapshot.TimelineFrame := FView^.TimelineFrame;
    Snapshot.ModelPathHash := FView^.ModelPathHash;
    SetLength(Bytes, FView^.DataLength);
    if Length(Bytes) > 0 then
      Move(FView^.Data[0], Bytes[0], Length(Bytes));
    Snapshot.FaceData := TEncoding.UTF8.GetString(Bytes);
    Result := True;
  finally
    Unlock;
  end;
end;

function GetChannel(Layer: Integer): TMmdFaceSharedChannel;
begin
  TMonitor.Enter(ChannelLock);
  try
    if not Channels.TryGetValue(Layer, Result) then
    begin
      Result := TMmdFaceSharedChannel.Create(Layer);
      Channels.Add(Layer, Result);
    end;
  finally
    TMonitor.Exit(ChannelLock);
  end;
end;

function HashFaceModelPath(const FileName: string): UInt64;
const
  HASH_SEED: UInt64 = $9E3779B97F4A7C15;
var
  Character: Char;
  Normalized: string;
begin
  Result := 0;
  if FileName = '' then Exit;
  try
    Normalized := UpperCase(TPath.GetFullPath(FileName));
  except
    Exit;
  end;
  Result := HASH_SEED;
  for Character in Normalized do
  begin
    Result := (Result shl 5) or (Result shr 59);
    Result := Result xor Ord(Character);
  end;
end;

function PublishFaceSnapshot(Layer: Integer;
  const Snapshot: TMmdFaceSharedSnapshot): Boolean;
begin
  Result := (Layer >= 0) and GetChannel(Layer).Publish(Snapshot);
end;

function TryReadFaceSnapshot(Layer: Integer; ModelPathHash: UInt64;
  out Snapshot: TMmdFaceSharedSnapshot): Boolean;
begin
  Result := (Layer >= 0) and (ModelPathHash <> 0) and
    GetChannel(Layer).TryRead(ModelPathHash, Snapshot);
end;

function GetFaceTimelineFrame(const ObjectInfo: POBJECT_INFO): Integer;
begin
  if ObjectInfo = nil then Exit(Low(Integer));
  Result := ObjectInfo^.FrameS + ObjectInfo^.Frame;
end;

initialization
  ChannelLock := TObject.Create;
  Channels := TObjectDictionary<Integer, TMmdFaceSharedChannel>.Create(
    [doOwnsValues]);

finalization
  Channels.Free;
  ChannelLock.Free;

end.
