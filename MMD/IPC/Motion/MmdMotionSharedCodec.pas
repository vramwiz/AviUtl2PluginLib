unit MmdMotionSharedCodec;

// 評価済みモーションの名前付き姿勢とモーフを共有メモリ用バイナリへ相互変換する。

interface

uses
  System.SysUtils,
  MmdMorphSettingCodec,
  PmxPose;

const
  MMD_MOTION_SHARED_DATA_SIZE = 1024 * 1024;

type
  TMmdMotionSharedSnapshot = record
    WriterObjectID: Int64;
    WriterEffectID: Int64;
    TimelineFrame: Integer;
    MotionFrame: Single;
    ModelPathHash: UInt64;
    Poses: TPmxNamedBonePoses;
    Morphs: TMmdNamedMorphWeights;
  end;

// Snapshotを共有領域のペイロードへ変換する。名前や総容量が上限を超えた場合はFalseを返す。
function EncodeMmdMotionPayload(const Snapshot: TMmdMotionSharedSnapshot;
  out Bytes: TBytes): Boolean;
// 件数とペイロードを検証して復元する。不正データの場合は出力を空にしてFalseを返す。
function DecodeMmdMotionPayload(const Bytes: TBytes;
  BoneCount, MorphCount: Cardinal; out Poses: TPmxNamedBonePoses;
  out Morphs: TMmdNamedMorphWeights): Boolean;

implementation

uses
  System.Classes;

const
  MMD_MOTION_SHARED_MAX_NAME_SIZE = 4096;

procedure WriteCardinal(Stream: TStream; Value: Cardinal);
begin
  Stream.WriteBuffer(Value, SizeOf(Value));
end;

procedure WriteSingle(Stream: TStream; Value: Single);
begin
  Stream.WriteBuffer(Value, SizeOf(Value));
end;

function WriteName(Stream: TStream; const Value: string): Boolean;
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(Value);
  Result := (Length(Bytes) > 0) and
    (Length(Bytes) <= MMD_MOTION_SHARED_MAX_NAME_SIZE);
  if not Result then Exit;
  WriteCardinal(Stream, Length(Bytes));
  Stream.WriteBuffer(Bytes[0], Length(Bytes));
end;

function EncodeMmdMotionPayload(const Snapshot: TMmdMotionSharedSnapshot;
  out Bytes: TBytes): Boolean;
var
  I: Integer;
  Stream: TBytesStream;
begin
  Result := False;
  Bytes := nil;
  Stream := TBytesStream.Create;
  try
    for I := 0 to High(Snapshot.Poses) do
    begin
      if not WriteName(Stream, Snapshot.Poses[I].BoneName) then Exit;
      WriteSingle(Stream, Snapshot.Poses[I].Pose.Translation.X);
      WriteSingle(Stream, Snapshot.Poses[I].Pose.Translation.Y);
      WriteSingle(Stream, Snapshot.Poses[I].Pose.Translation.Z);
      WriteSingle(Stream, Snapshot.Poses[I].Pose.Rotation.X);
      WriteSingle(Stream, Snapshot.Poses[I].Pose.Rotation.Y);
      WriteSingle(Stream, Snapshot.Poses[I].Pose.Rotation.Z);
      WriteSingle(Stream, Snapshot.Poses[I].Pose.Rotation.W);
    end;
    for I := 0 to High(Snapshot.Morphs) do
    begin
      if not WriteName(Stream, Snapshot.Morphs[I].Name) then Exit;
      WriteSingle(Stream, Snapshot.Morphs[I].Weight);
    end;
    if Stream.Size > MMD_MOTION_SHARED_DATA_SIZE then Exit;
    SetLength(Bytes, Stream.Size);
    if Stream.Size > 0 then Move(Stream.Bytes[0], Bytes[0], Stream.Size);
    Result := True;
  finally
    Stream.Free;
  end;
end;

function ReadBytes(const Bytes: TBytes; var Offset: Integer;
  Target: Pointer; Count: Integer): Boolean;
begin
  Result := (Count >= 0) and (Offset >= 0) and
    (Offset <= Length(Bytes) - Count);
  if not Result then Exit;
  if Count > 0 then Move(Bytes[Offset], Target^, Count);
  Inc(Offset, Count);
end;

function ReadCardinal(const Bytes: TBytes; var Offset: Integer;
  out Value: Cardinal): Boolean;
begin
  Result := ReadBytes(Bytes, Offset, @Value, SizeOf(Value));
end;

function ReadSingle(const Bytes: TBytes; var Offset: Integer;
  out Value: Single): Boolean;
begin
  Result := ReadBytes(Bytes, Offset, @Value, SizeOf(Value));
end;

function ReadName(const Bytes: TBytes; var Offset: Integer;
  out Value: string): Boolean;
var
  Count: Cardinal;
  NameBytes: TBytes;
begin
  Result := False;
  Value := '';
  if not ReadCardinal(Bytes, Offset, Count) or (Count = 0) or
    (Count > MMD_MOTION_SHARED_MAX_NAME_SIZE) or
    (Count > Cardinal(Length(Bytes) - Offset)) then Exit;
  SetLength(NameBytes, Count);
  if not ReadBytes(Bytes, Offset, @NameBytes[0], Count) then Exit;
  Value := TEncoding.UTF8.GetString(NameBytes);
  Result := Value <> '';
end;

function DecodeMmdMotionPayload(const Bytes: TBytes;
  BoneCount, MorphCount: Cardinal; out Poses: TPmxNamedBonePoses;
  out Morphs: TMmdNamedMorphWeights): Boolean;
var
  I, Offset: Integer;
begin
  Result := False;
  Poses := nil;
  Morphs := nil;
  if (BoneCount > Cardinal(Length(Bytes) div 32)) or
    (MorphCount > Cardinal(Length(Bytes) div 8)) then Exit;
  SetLength(Poses, BoneCount);
  SetLength(Morphs, MorphCount);
  Offset := 0;
  for I := 0 to Integer(BoneCount) - 1 do
    if not ReadName(Bytes, Offset, Poses[I].BoneName) or
      not ReadSingle(Bytes, Offset, Poses[I].Pose.Translation.X) or
      not ReadSingle(Bytes, Offset, Poses[I].Pose.Translation.Y) or
      not ReadSingle(Bytes, Offset, Poses[I].Pose.Translation.Z) or
      not ReadSingle(Bytes, Offset, Poses[I].Pose.Rotation.X) or
      not ReadSingle(Bytes, Offset, Poses[I].Pose.Rotation.Y) or
      not ReadSingle(Bytes, Offset, Poses[I].Pose.Rotation.Z) or
      not ReadSingle(Bytes, Offset, Poses[I].Pose.Rotation.W) then Exit;
  for I := 0 to Integer(MorphCount) - 1 do
    if not ReadName(Bytes, Offset, Morphs[I].Name) or
      not ReadSingle(Bytes, Offset, Morphs[I].Weight) then Exit;
  Result := Offset = Length(Bytes);
  if not Result then
  begin
    Poses := nil;
    Morphs := nil;
  end;
end;

end.
