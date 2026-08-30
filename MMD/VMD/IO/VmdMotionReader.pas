unit VmdMotionReader;

// VMD 0002のボーン／モーフキーを保持し、ホバープレビュー用の任意フレームを線形評価する。

interface

uses
  System.Generics.Collections,
  PmxPose,
  MmdMorphSettingCodec;

type
  TVmdBoneKeyframe = record
    Frame: Cardinal;
    Pose: TPmxBonePose;
  end;
  TVmdMorphKeyframe = record
    Frame: Cardinal;
    Weight: Single;
  end;
  TVmdBoneTrack = class
  public
    Name: string;
    Keys: TList<TVmdBoneKeyframe>;
    constructor Create(const AName: string);
    destructor Destroy; override;
  end;
  TVmdMorphTrack = class
  public
    Name: string;
    Keys: TList<TVmdMorphKeyframe>;
    constructor Create(const AName: string);
    destructor Destroy; override;
  end;
  TVmdMotionData = class
  private
    FBoneTracks: TObjectList<TVmdBoneTrack>;
    FMaxFrame: Cardinal;
    FMorphTracks: TObjectList<TVmdMorphTrack>;
  public
    // 空のモーションデータを生成する。
    constructor Create;
    destructor Destroy; override;
    // VMD 0002のボーン／モーフキーを全件読み込む。破損時は空へ戻してFalseを返す。
    function LoadFromFile(const FileName: string): Boolean;
    // 指定フレームの名前付き姿勢とモーフ値を線形補間して返す。
    function Evaluate(Frame: Single; out Poses: TPmxNamedBonePoses;
      out Morphs: TMmdNamedMorphWeights): Boolean;
    property MaxFrame: Cardinal read FMaxFrame;
  end;

implementation

uses
  System.Classes,
  System.Generics.Defaults,
  System.Math,
  System.SysUtils;

const
  VmdHeaderSize = 30;
  VmdModelNameSize = 20;
  VmdBoneNameSize = 15;
  VmdMorphNameSize = 15;
  VmdBoneInterpolationSize = 64;
  MaxVmdKeys = 2000000;

constructor TVmdBoneTrack.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  Keys := TList<TVmdBoneKeyframe>.Create;
end;

destructor TVmdBoneTrack.Destroy;
begin
  Keys.Free;
  inherited;
end;

constructor TVmdMorphTrack.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  Keys := TList<TVmdMorphKeyframe>.Create;
end;

destructor TVmdMorphTrack.Destroy;
begin
  Keys.Free;
  inherited;
end;

constructor TVmdMotionData.Create;
begin
  inherited;
  FBoneTracks := TObjectList<TVmdBoneTrack>.Create(True);
  FMorphTracks := TObjectList<TVmdMorphTrack>.Create(True);
end;

destructor TVmdMotionData.Destroy;
begin
  FMorphTracks.Free;
  FBoneTracks.Free;
  inherited;
end;

function ReadFixedText(Stream: TStream; Size: Integer): string;
var
  Bytes: TBytes;
  Count: Integer;
  Encoding: TEncoding;
begin
  SetLength(Bytes, Size);
  Stream.ReadBuffer(Bytes[0], Size);
  Count := 0;
  while (Count < Size) and (Bytes[Count] <> 0) do Inc(Count);
  Encoding := TEncoding.GetEncoding(932);
  try
    Result := Encoding.GetString(Bytes, 0, Count);
  finally
    Encoding.Free;
  end;
end;

function ReadCardinal(Stream: TStream): Cardinal;
begin
  Stream.ReadBuffer(Result, SizeOf(Result));
end;

function ReadSingle(Stream: TStream): Single;
begin
  Stream.ReadBuffer(Result, SizeOf(Result));
end;

function Finite(Value: Single): Boolean;
begin
  Result := not IsNan(Value) and not IsInfinite(Value);
end;

function ReadBoneKey(Stream: TStream; out Name: string;
  out Key: TVmdBoneKeyframe): Boolean;
var
  Skip: array[0..VmdBoneInterpolationSize - 1] of Byte;
begin
  Result := False;
  Name := ReadFixedText(Stream, VmdBoneNameSize);
  Key := Default(TVmdBoneKeyframe);
  Key.Frame := ReadCardinal(Stream);
  Key.Pose.Translation.X := ReadSingle(Stream);
  Key.Pose.Translation.Y := ReadSingle(Stream);
  Key.Pose.Translation.Z := ReadSingle(Stream);
  Key.Pose.Rotation.X := ReadSingle(Stream);
  Key.Pose.Rotation.Y := ReadSingle(Stream);
  Key.Pose.Rotation.Z := ReadSingle(Stream);
  Key.Pose.Rotation.W := ReadSingle(Stream);
  Stream.ReadBuffer(Skip, SizeOf(Skip));
  if (Name = '') or not Finite(Key.Pose.Translation.X) or
    not Finite(Key.Pose.Translation.Y) or not Finite(Key.Pose.Translation.Z) or
    not Finite(Key.Pose.Rotation.X) or not Finite(Key.Pose.Rotation.Y) or
    not Finite(Key.Pose.Rotation.Z) or not Finite(Key.Pose.Rotation.W) then Exit;
  Key.Pose.Rotation := NormalizeQuaternion(Key.Pose.Rotation);
  Result := True;
end;

function ReadMorphKey(Stream: TStream; out Name: string;
  out Key: TVmdMorphKeyframe): Boolean;
begin
  Name := ReadFixedText(Stream, VmdMorphNameSize);
  Key.Frame := ReadCardinal(Stream);
  Key.Weight := ReadSingle(Stream);
  Result := (Name <> '') and Finite(Key.Weight);
  if Result then Key.Weight := EnsureRange(Key.Weight, 0.0, 1.0);
end;

procedure SortBoneKeys(Keys: TList<TVmdBoneKeyframe>);
begin
  Keys.Sort(TComparer<TVmdBoneKeyframe>.Construct(
    function(const Left, Right: TVmdBoneKeyframe): Integer
    begin
      if Left.Frame < Right.Frame then Result := -1
      else if Left.Frame > Right.Frame then Result := 1 else Result := 0;
    end));
end;

procedure SortMorphKeys(Keys: TList<TVmdMorphKeyframe>);
begin
  Keys.Sort(TComparer<TVmdMorphKeyframe>.Construct(
    function(const Left, Right: TVmdMorphKeyframe): Integer
    begin
      if Left.Frame < Right.Frame then Result := -1
      else if Left.Frame > Right.Frame then Result := 1 else Result := 0;
    end));
end;

function TVmdMotionData.LoadFromFile(const FileName: string): Boolean;
var
  BoneCount, MorphCount: Cardinal;
  I, Index: Integer;
  BoneKey: TVmdBoneKeyframe;
  BoneMap, MorphMap: TDictionary<string, Integer>;
  BoneTrack: TVmdBoneTrack;
  Header, Name: string;
  MorphKey: TVmdMorphKeyframe;
  MorphTrack: TVmdMorphTrack;
  Stream: TFileStream;
begin
  Result := False;
  FBoneTracks.Clear;
  FMorphTracks.Clear;
  FMaxFrame := 0;
  BoneMap := TDictionary<string, Integer>.Create;
  MorphMap := TDictionary<string, Integer>.Create;
  try
    try
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
      try
        Header := ReadFixedText(Stream, VmdHeaderSize);
        if not SameText(Header, 'Vocaloid Motion Data 0002') then Exit;
        ReadFixedText(Stream, VmdModelNameSize);
        BoneCount := ReadCardinal(Stream);
        if BoneCount > MaxVmdKeys then Exit;
        for I := 0 to Integer(BoneCount) - 1 do
        begin
          if not ReadBoneKey(Stream, Name, BoneKey) then Exit;
          if not BoneMap.TryGetValue(Name, Index) then
          begin
            BoneTrack := TVmdBoneTrack.Create(Name);
            Index := FBoneTracks.Add(BoneTrack);
            BoneMap.Add(Name, Index);
          end;
          FBoneTracks[Index].Keys.Add(BoneKey);
          if BoneKey.Frame > FMaxFrame then FMaxFrame := BoneKey.Frame;
        end;
        MorphCount := ReadCardinal(Stream);
        if MorphCount > MaxVmdKeys then Exit;
        for I := 0 to Integer(MorphCount) - 1 do
        begin
          if not ReadMorphKey(Stream, Name, MorphKey) then Exit;
          if not MorphMap.TryGetValue(Name, Index) then
          begin
            MorphTrack := TVmdMorphTrack.Create(Name);
            Index := FMorphTracks.Add(MorphTrack);
            MorphMap.Add(Name, Index);
          end;
          FMorphTracks[Index].Keys.Add(MorphKey);
          if MorphKey.Frame > FMaxFrame then FMaxFrame := MorphKey.Frame;
        end;
      finally
        Stream.Free;
      end;
      if (FBoneTracks.Count = 0) and (FMorphTracks.Count = 0) then Exit;
      for BoneTrack in FBoneTracks do SortBoneKeys(BoneTrack.Keys);
      for MorphTrack in FMorphTracks do SortMorphKeys(MorphTrack.Keys);
      Result := True;
    except
      Result := False;
    end;
  finally
    MorphMap.Free;
    BoneMap.Free;
    if not Result then
    begin
      FBoneTracks.Clear;
      FMorphTracks.Clear;
      FMaxFrame := 0;
    end;
  end;
end;

function SlerpQuaternion(const A, B: TPmxQuaternion;
  Amount: Single): TPmxQuaternion;
var
  Angle, Dot, ScaleA, ScaleB, SinAngle: Single;
  EndValue: TPmxQuaternion;
begin
  EndValue := B;
  Dot := A.X * B.X + A.Y * B.Y + A.Z * B.Z + A.W * B.W;
  if Dot < 0 then
  begin
    Dot := -Dot;
    EndValue.X := -EndValue.X;
    EndValue.Y := -EndValue.Y;
    EndValue.Z := -EndValue.Z;
    EndValue.W := -EndValue.W;
  end;
  Dot := EnsureRange(Dot, -1.0, 1.0);
  if Dot > 0.9995 then
  begin
    Result.X := A.X + (EndValue.X - A.X) * Amount;
    Result.Y := A.Y + (EndValue.Y - A.Y) * Amount;
    Result.Z := A.Z + (EndValue.Z - A.Z) * Amount;
    Result.W := A.W + (EndValue.W - A.W) * Amount;
    Exit(NormalizeQuaternion(Result));
  end;
  Angle := ArcCos(Dot);
  SinAngle := Sin(Angle);
  ScaleA := Sin((1 - Amount) * Angle) / SinAngle;
  ScaleB := Sin(Amount * Angle) / SinAngle;
  Result.X := A.X * ScaleA + EndValue.X * ScaleB;
  Result.Y := A.Y * ScaleA + EndValue.Y * ScaleB;
  Result.Z := A.Z * ScaleA + EndValue.Z * ScaleB;
  Result.W := A.W * ScaleA + EndValue.W * ScaleB;
  Result := NormalizeQuaternion(Result);
end;

function EvaluateBone(Track: TVmdBoneTrack; Frame: Single): TPmxBonePose;
var
  Amount: Single;
  HighIndex, LowIndex, Mid: Integer;
  LeftKey, RightKey: TVmdBoneKeyframe;
begin
  if (Track.Keys.Count = 1) or (Frame <= Track.Keys[0].Frame) then
    Exit(Track.Keys[0].Pose);
  HighIndex := Track.Keys.Count - 1;
  if Frame >= Track.Keys[HighIndex].Frame then Exit(Track.Keys[HighIndex].Pose);
  LowIndex := 0;
  while HighIndex - LowIndex > 1 do
  begin
    Mid := (LowIndex + HighIndex) div 2;
    if Track.Keys[Mid].Frame <= Frame then LowIndex := Mid else HighIndex := Mid;
  end;
  LeftKey := Track.Keys[LowIndex];
  RightKey := Track.Keys[HighIndex];
  Amount := (Frame - LeftKey.Frame) / (RightKey.Frame - LeftKey.Frame);
  Result.Translation.X := LeftKey.Pose.Translation.X +
    (RightKey.Pose.Translation.X - LeftKey.Pose.Translation.X) * Amount;
  Result.Translation.Y := LeftKey.Pose.Translation.Y +
    (RightKey.Pose.Translation.Y - LeftKey.Pose.Translation.Y) * Amount;
  Result.Translation.Z := LeftKey.Pose.Translation.Z +
    (RightKey.Pose.Translation.Z - LeftKey.Pose.Translation.Z) * Amount;
  Result.Rotation := SlerpQuaternion(LeftKey.Pose.Rotation,
    RightKey.Pose.Rotation, Amount);
end;

function EvaluateMorph(Track: TVmdMorphTrack; Frame: Single): Single;
var
  Amount: Single;
  HighIndex, LowIndex, Mid: Integer;
  LeftKey, RightKey: TVmdMorphKeyframe;
begin
  if (Track.Keys.Count = 1) or (Frame <= Track.Keys[0].Frame) then
    Exit(Track.Keys[0].Weight);
  HighIndex := Track.Keys.Count - 1;
  if Frame >= Track.Keys[HighIndex].Frame then Exit(Track.Keys[HighIndex].Weight);
  LowIndex := 0;
  while HighIndex - LowIndex > 1 do
  begin
    Mid := (LowIndex + HighIndex) div 2;
    if Track.Keys[Mid].Frame <= Frame then LowIndex := Mid else HighIndex := Mid;
  end;
  LeftKey := Track.Keys[LowIndex];
  RightKey := Track.Keys[HighIndex];
  Amount := (Frame - LeftKey.Frame) / (RightKey.Frame - LeftKey.Frame);
  Result := LeftKey.Weight + (RightKey.Weight - LeftKey.Weight) * Amount;
end;

function TVmdMotionData.Evaluate(Frame: Single;
  out Poses: TPmxNamedBonePoses;
  out Morphs: TMmdNamedMorphWeights): Boolean;
var
  I: Integer;
begin
  Poses := nil;
  Morphs := nil;
  Result := (FBoneTracks.Count > 0) or (FMorphTracks.Count > 0);
  if not Result then Exit;
  Frame := EnsureRange(Frame, 0.0, Single(FMaxFrame));
  SetLength(Poses, FBoneTracks.Count);
  for I := 0 to FBoneTracks.Count - 1 do
  begin
    Poses[I].BoneName := FBoneTracks[I].Name;
    Poses[I].Pose := EvaluateBone(FBoneTracks[I], Frame);
  end;
  SetLength(Morphs, FMorphTracks.Count);
  for I := 0 to FMorphTracks.Count - 1 do
  begin
    Morphs[I].Name := FMorphTracks[I].Name;
    Morphs[I].Weight := EvaluateMorph(FMorphTracks[I], Frame);
  end;
end;

end.
