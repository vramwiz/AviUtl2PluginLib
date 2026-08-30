unit VmdFirstFrameReader;

// VMD 0002のボーン／モーフキーを検証し、一覧サムネイル用の先頭状態だけを読み出す。

interface

uses
  PmxPose,
  MmdMorphSettingCodec;

// VMD原本から各トラックの最初のキーを抽出する。破損時は出力を空にしてFalseを返す。
function TryReadVmdFirstFrame(const FileName: string;
  out Poses: TPmxNamedBonePoses; out Morphs: TMmdNamedMorphWeights;
  out FirstFrame: Cardinal; out ModelName: string): Boolean;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.SysUtils,
  PmxModel;

const
  VmdHeaderSize = 30;
  VmdModelNameSize = 20;
  VmdBoneNameSize = 15;
  VmdMorphNameSize = 15;
  VmdBoneInterpolationSize = 64;
  MaxVmdKeys = 2000000;

type
  TVmdBoneFirst = record
    Frame: Cardinal;
    Pose: TPmxNamedBonePose;
  end;
  TVmdMorphFirst = record
    Frame: Cardinal;
    Morph: TMmdNamedMorphWeight;
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

function ReadBoneKey(Stream: TStream; out Name: string; out Frame: Cardinal;
  out Pose: TPmxBonePose): Boolean;
var
  Skip: TBytes;
begin
  Result := False;
  Name := ReadFixedText(Stream, VmdBoneNameSize);
  Frame := ReadCardinal(Stream);
  Pose := Default(TPmxBonePose);
  Pose.Translation.X := ReadSingle(Stream);
  Pose.Translation.Y := ReadSingle(Stream);
  Pose.Translation.Z := ReadSingle(Stream);
  Pose.Rotation.X := ReadSingle(Stream);
  Pose.Rotation.Y := ReadSingle(Stream);
  Pose.Rotation.Z := ReadSingle(Stream);
  Pose.Rotation.W := ReadSingle(Stream);
  SetLength(Skip, VmdBoneInterpolationSize);
  Stream.ReadBuffer(Skip[0], Length(Skip));
  if (Name = '') or not Finite(Pose.Translation.X) or
    not Finite(Pose.Translation.Y) or not Finite(Pose.Translation.Z) or
    not Finite(Pose.Rotation.X) or not Finite(Pose.Rotation.Y) or
    not Finite(Pose.Rotation.Z) or not Finite(Pose.Rotation.W) then Exit;
  Pose.Rotation := NormalizeQuaternion(Pose.Rotation);
  Result := True;
end;

function ReadMorphKey(Stream: TStream; out Name: string; out Frame: Cardinal;
  out Weight: Single): Boolean;
begin
  Name := ReadFixedText(Stream, VmdMorphNameSize);
  Frame := ReadCardinal(Stream);
  Weight := ReadSingle(Stream);
  Result := (Name <> '') and Finite(Weight);
  if Result then Weight := EnsureRange(Weight, 0.0, 1.0);
end;

function IsVmdHeader(const Value: string): Boolean;
begin
  // 0001 はモデル名フィールド長が異なるため、この軽量リーダーでは扱わない。
  Result := SameText(Value, 'Vocaloid Motion Data 0002');
end;

function TryReadVmdFirstFrame(const FileName: string;
  out Poses: TPmxNamedBonePoses; out Morphs: TMmdNamedMorphWeights;
  out FirstFrame: Cardinal; out ModelName: string): Boolean;
var
  Bone: TVmdBoneFirst;
  BoneCount, Frame: Cardinal;
  I, Index: Integer;
  BoneKeys: TList<TVmdBoneFirst>;
  BoneMap: TDictionary<string, Integer>;
  Header, Name: string;
  Morph: TVmdMorphFirst;
  MorphCount: Cardinal;
  MorphKeys: TList<TVmdMorphFirst>;
  MorphMap: TDictionary<string, Integer>;
  Pose: TPmxBonePose;
  Stream: TFileStream;
  Weight: Single;
begin
  Result := False;
  Poses := nil;
  Morphs := nil;
  FirstFrame := 0;
  ModelName := '';
  BoneKeys := TList<TVmdBoneFirst>.Create;
  MorphKeys := TList<TVmdMorphFirst>.Create;
  BoneMap := TDictionary<string, Integer>.Create;
  MorphMap := TDictionary<string, Integer>.Create;
  try
    try
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
      try
        Header := ReadFixedText(Stream, VmdHeaderSize);
        if not IsVmdHeader(Header) then Exit;
        ModelName := ReadFixedText(Stream, VmdModelNameSize);
        BoneCount := ReadCardinal(Stream);
        if BoneCount > MaxVmdKeys then Exit;
        for I := 0 to Integer(BoneCount) - 1 do
        begin
          if not ReadBoneKey(Stream, Name, Frame, Pose) then Exit;
          if BoneMap.TryGetValue(Name, Index) then
          begin
            if Frame < BoneKeys[Index].Frame then
            begin
              Bone := BoneKeys[Index];
              Bone.Frame := Frame;
              Bone.Pose.BoneName := Name;
              Bone.Pose.Pose := Pose;
              BoneKeys[Index] := Bone;
            end;
          end
          else
          begin
            Bone := Default(TVmdBoneFirst);
            Bone.Frame := Frame;
            Bone.Pose.BoneName := Name;
            Bone.Pose.Pose := Pose;
            BoneMap.Add(Name, BoneKeys.Add(Bone));
          end;
        end;
        MorphCount := ReadCardinal(Stream);
        if MorphCount > MaxVmdKeys then Exit;
        for I := 0 to Integer(MorphCount) - 1 do
        begin
          if not ReadMorphKey(Stream, Name, Frame, Weight) then Exit;
          if MorphMap.TryGetValue(Name, Index) then
          begin
            if Frame < MorphKeys[Index].Frame then
            begin
              Morph := MorphKeys[Index];
              Morph.Frame := Frame;
              Morph.Morph.Name := Name;
              Morph.Morph.Weight := Weight;
              MorphKeys[Index] := Morph;
            end;
          end
          else
          begin
            Morph := Default(TVmdMorphFirst);
            Morph.Frame := Frame;
            Morph.Morph.Name := Name;
            Morph.Morph.Weight := Weight;
            MorphMap.Add(Name, MorphKeys.Add(Morph));
          end;
        end;
      finally
        Stream.Free;
      end;
      if (BoneKeys.Count = 0) and (MorphKeys.Count = 0) then Exit;
      FirstFrame := High(Cardinal);
      SetLength(Poses, BoneKeys.Count);
      for I := 0 to BoneKeys.Count - 1 do
      begin
        Poses[I] := BoneKeys[I].Pose;
        if BoneKeys[I].Frame < FirstFrame then FirstFrame := BoneKeys[I].Frame;
      end;
      SetLength(Morphs, MorphKeys.Count);
      for I := 0 to MorphKeys.Count - 1 do
      begin
        Morphs[I] := MorphKeys[I].Morph;
        if MorphKeys[I].Frame < FirstFrame then FirstFrame := MorphKeys[I].Frame;
      end;
      if FirstFrame = High(Cardinal) then FirstFrame := 0;
      Result := True;
    except
      Poses := nil;
      Morphs := nil;
      ModelName := '';
    end;
  finally
    MorphMap.Free;
    BoneMap.Free;
    MorphKeys.Free;
    BoneKeys.Free;
  end;
end;

end.
