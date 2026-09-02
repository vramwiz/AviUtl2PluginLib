unit MmdMotionSharedMemory;

// モーションレイヤーから表示モデルへ、現在フレームで評価済みの
// 名前付きボーン姿勢とモーフウェイトをバイナリで渡す。

interface

uses
  MmdMotionSharedCodec;

type
  TMmdMotionSharedSnapshot = MmdMotionSharedCodec.TMmdMotionSharedSnapshot;

// 両プラグインで同じ絶対PMXパスを照合する安定ハッシュを返す。
function HashMotionModelPath(const FileName: string): UInt64;
// 指定レイヤーへ現在フレームの評価結果を発行する。
function PublishMotionSnapshot(Layer: Integer;
  const Snapshot: TMmdMotionSharedSnapshot): Boolean;
// 後続の受信実装とプロトコル検証用に、指定レイヤーの現在値を読む。
function TryReadMotionSnapshot(Layer: Integer; ModelPathHash: UInt64;
  out Snapshot: TMmdMotionSharedSnapshot): Boolean;

implementation

uses
  Winapi.Windows,
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils;

const
  MMD_MOTION_SHARED_MAGIC = $4D4D444D; // MMDM
  MMD_MOTION_SHARED_VERSION = 1;

type
  PMmdMotionSharedBlock = ^TMmdMotionSharedBlock;
  TMmdMotionSharedBlock = packed record
    Magic: Cardinal;
    Version: Cardinal;
    Sequence: UInt64;
    WriterProcessID: Cardinal;
    WriterObjectID: Int64;
    WriterEffectID: Int64;
    TimelineFrame: Integer;
    MotionFrame: Single;
    ModelPathHash: UInt64;
    BoneCount: Cardinal;
    MorphCount: Cardinal;
    DataLength: Cardinal;
    Data: array[0..MMD_MOTION_SHARED_DATA_SIZE - 1] of Byte;
  end;

  TMmdMotionSharedChannel = class
  private
    FMapping: THandle;
    FMutex: THandle;
    FView: PMmdMotionSharedBlock;
    function Lock: Boolean;
    procedure Unlock;
  public
    constructor Create(Layer: Integer);
    destructor Destroy; override;
    function Publish(const Snapshot: TMmdMotionSharedSnapshot): Boolean;
    function TryRead(ModelPathHash: UInt64;
      out Snapshot: TMmdMotionSharedSnapshot): Boolean;
  end;

var
  ChannelLock: TObject;
  Channels: TObjectDictionary<Integer, TMmdMotionSharedChannel>;

function ChannelName(const Kind: string; Layer: Integer): string;
begin
  Result := Format('Local\MMD.Motion.%s.Layer.%d', [Kind, Layer]);
end;

constructor TMmdMotionSharedChannel.Create(Layer: Integer);
var
  IsOwner: Boolean;
begin
  inherited Create;
  FMutex := CreateMutex(nil, False, PChar(ChannelName('Mutex', Layer)));
  if FMutex = 0 then RaiseLastOSError;
  FMapping := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0,
    SizeOf(TMmdMotionSharedBlock), PChar(ChannelName('Memory', Layer)));
  if FMapping = 0 then RaiseLastOSError;
  IsOwner := GetLastError <> ERROR_ALREADY_EXISTS;
  FView := MapViewOfFile(FMapping, FILE_MAP_ALL_ACCESS, 0, 0,
    SizeOf(TMmdMotionSharedBlock));
  if FView = nil then RaiseLastOSError;
  if IsOwner then FillChar(FView^, SizeOf(FView^), 0);
end;

destructor TMmdMotionSharedChannel.Destroy;
begin
  if FView <> nil then UnmapViewOfFile(FView);
  if FMapping <> 0 then CloseHandle(FMapping);
  if FMutex <> 0 then CloseHandle(FMutex);
  inherited;
end;

function TMmdMotionSharedChannel.Lock: Boolean;
begin
  Result := (FMutex <> 0) and
    (WaitForSingleObject(FMutex, 1000) in [WAIT_OBJECT_0, WAIT_ABANDONED]);
end;

procedure TMmdMotionSharedChannel.Unlock;
begin
  ReleaseMutex(FMutex);
end;

function TMmdMotionSharedChannel.Publish(
  const Snapshot: TMmdMotionSharedSnapshot): Boolean;
var
  Bytes: TBytes;
begin
  Result := False;
  if not EncodeMmdMotionPayload(Snapshot, Bytes) or not Lock then Exit;
  try
    Inc(FView^.Sequence);
    FView^.Magic := MMD_MOTION_SHARED_MAGIC;
    FView^.Version := MMD_MOTION_SHARED_VERSION;
    FView^.WriterProcessID := GetCurrentProcessId;
    FView^.WriterObjectID := Snapshot.WriterObjectID;
    FView^.WriterEffectID := Snapshot.WriterEffectID;
    FView^.TimelineFrame := Snapshot.TimelineFrame;
    FView^.MotionFrame := Snapshot.MotionFrame;
    FView^.ModelPathHash := Snapshot.ModelPathHash;
    FView^.BoneCount := Length(Snapshot.Poses);
    FView^.MorphCount := Length(Snapshot.Morphs);
    FView^.DataLength := Length(Bytes);
    if Length(Bytes) > 0 then Move(Bytes[0], FView^.Data[0], Length(Bytes));
    Inc(FView^.Sequence);
    Result := True;
  finally
    Unlock;
  end;
end;

function TMmdMotionSharedChannel.TryRead(ModelPathHash: UInt64;
  out Snapshot: TMmdMotionSharedSnapshot): Boolean;
var
  BoneCount, MorphCount: Cardinal;
  Bytes: TBytes;
begin
  Snapshot := Default(TMmdMotionSharedSnapshot);
  Result := False;
  if not Lock then Exit;
  try
    if (FView^.Magic <> MMD_MOTION_SHARED_MAGIC) or
      (FView^.Version <> MMD_MOTION_SHARED_VERSION) or
      ((FView^.Sequence and 1) <> 0) or
      (FView^.ModelPathHash <> ModelPathHash) or
      (FView^.DataLength > MMD_MOTION_SHARED_DATA_SIZE) then Exit;
    Snapshot.WriterObjectID := FView^.WriterObjectID;
    Snapshot.WriterEffectID := FView^.WriterEffectID;
    Snapshot.TimelineFrame := FView^.TimelineFrame;
    Snapshot.MotionFrame := FView^.MotionFrame;
    Snapshot.ModelPathHash := FView^.ModelPathHash;
    BoneCount := FView^.BoneCount;
    MorphCount := FView^.MorphCount;
    SetLength(Bytes, FView^.DataLength);
    if Length(Bytes) > 0 then Move(FView^.Data[0], Bytes[0], Length(Bytes));
  finally
    Unlock;
  end;
  Result := DecodeMmdMotionPayload(Bytes, BoneCount, MorphCount,
    Snapshot.Poses, Snapshot.Morphs);
end;

function GetChannel(Layer: Integer): TMmdMotionSharedChannel;
begin
  TMonitor.Enter(ChannelLock);
  try
    if not Channels.TryGetValue(Layer, Result) then
    begin
      Result := TMmdMotionSharedChannel.Create(Layer);
      Channels.Add(Layer, Result);
    end;
  finally
    TMonitor.Exit(ChannelLock);
  end;
end;

function HashMotionModelPath(const FileName: string): UInt64;
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

function PublishMotionSnapshot(Layer: Integer;
  const Snapshot: TMmdMotionSharedSnapshot): Boolean;
begin
  Result := (Layer >= 0) and (Snapshot.ModelPathHash <> 0) and
    GetChannel(Layer).Publish(Snapshot);
end;

function TryReadMotionSnapshot(Layer: Integer; ModelPathHash: UInt64;
  out Snapshot: TMmdMotionSharedSnapshot): Boolean;
begin
  Result := (Layer >= 0) and (ModelPathHash <> 0) and
    GetChannel(Layer).TryRead(ModelPathHash, Snapshot);
end;

initialization
  ChannelLock := TObject.Create;
  Channels := TObjectDictionary<Integer, TMmdMotionSharedChannel>.Create(
    [doOwnsValues]);

finalization
  Channels.Free;
  ChannelLock.Free;

end.
