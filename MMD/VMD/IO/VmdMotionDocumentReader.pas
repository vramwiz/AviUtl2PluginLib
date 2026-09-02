unit VmdMotionDocumentReader;

// VMD 0002のボーン／モーフ全キーとBezierをMmdMotionDocumentへ変換する。

interface

uses
  MmdMotionDocument;

// VMD原本を編集可能な全トラックへ変換する。破損時はFalseとnilを返す。
function TryReadVmdMotionDocument(const FileName: string;
  out Document: TMmdMotionDocument): Boolean;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Math,
  System.SysUtils,
  PmxPoseTypes;

const
  MaxVmdKeys = 2000000;
  VmdBoneInterpolationSize = 64;
  VmdBoneNameSize = 15;
  VmdHeaderSize = 30;
  VmdModelNameSize = 20;
  VmdMorphNameSize = 15;

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

function NormalizeRotation(var Value: TPmxQuaternion): Boolean;
var
  LengthSquared, Scale: Double;
begin
  LengthSquared := Sqr(Value.X) + Sqr(Value.Y) + Sqr(Value.Z) +
    Sqr(Value.W);
  Result := LengthSquared > 0.000000000001;
  if not Result then Exit;
  Scale := 1 / Sqrt(LengthSquared);
  Value.X := Value.X * Scale;
  Value.Y := Value.Y * Scale;
  Value.Z := Value.Z * Scale;
  Value.W := Value.W * Scale;
end;

function DecodeCurve(const Bytes: array of Byte; Channel: Integer;
  out Curve: TMmdBezierCurve): Boolean;
begin
  // VMDの64バイトは4チャンネルを列とする4x4配置の先頭16バイトを使う。
  Curve.X1 := Bytes[Channel];
  Curve.Y1 := Bytes[Channel + 4];
  Curve.X2 := Bytes[Channel + 8];
  Curve.Y2 := Bytes[Channel + 12];
  Result := (Curve.X1 <= 127) and (Curve.Y1 <= 127) and
    (Curve.X2 <= 127) and (Curve.Y2 <= 127);
end;

function ReadBoneKey(Stream: TStream; out Name: string;
  out Key: TMmdMotionBoneKey): Boolean;
var
  Interpolation: array[0..VmdBoneInterpolationSize - 1] of Byte;
begin
  Result := False;
  Name := ReadFixedText(Stream, VmdBoneNameSize);
  Key := Default(TMmdMotionBoneKey);
  Key.Frame := ReadCardinal(Stream);
  Key.Translation.X := ReadSingle(Stream);
  Key.Translation.Y := ReadSingle(Stream);
  Key.Translation.Z := ReadSingle(Stream);
  Key.Rotation.X := ReadSingle(Stream);
  Key.Rotation.Y := ReadSingle(Stream);
  Key.Rotation.Z := ReadSingle(Stream);
  Key.Rotation.W := ReadSingle(Stream);
  Stream.ReadBuffer(Interpolation, SizeOf(Interpolation));
  if (Name = '') or not Finite(Key.Translation.X) or
    not Finite(Key.Translation.Y) or not Finite(Key.Translation.Z) or
    not Finite(Key.Rotation.X) or not Finite(Key.Rotation.Y) or
    not Finite(Key.Rotation.Z) or not Finite(Key.Rotation.W) or
    not NormalizeRotation(Key.Rotation) then Exit;
  Result := DecodeCurve(Interpolation, 0, Key.TranslationXCurve) and
    DecodeCurve(Interpolation, 1, Key.TranslationYCurve) and
    DecodeCurve(Interpolation, 2, Key.TranslationZCurve) and
    DecodeCurve(Interpolation, 3, Key.RotationCurve);
end;

function ReadMorphKey(Stream: TStream; out Name: string;
  out Key: TMmdMotionMorphKey): Boolean;
begin
  Name := ReadFixedText(Stream, VmdMorphNameSize);
  Key.Frame := ReadCardinal(Stream);
  Key.Weight := ReadSingle(Stream);
  Result := (Name <> '') and Finite(Key.Weight);
  if Result then Key.Weight := EnsureRange(Key.Weight, 0.0, 1.0);
end;

procedure SortBoneKeys(Keys: TList<TMmdMotionBoneKey>);
begin
  Keys.Sort(TComparer<TMmdMotionBoneKey>.Construct(
    function(const Left, Right: TMmdMotionBoneKey): Integer
    begin
      if Left.Frame < Right.Frame then Result := -1
      else if Left.Frame > Right.Frame then Result := 1 else Result := 0;
    end));
end;

procedure SortMorphKeys(Keys: TList<TMmdMotionMorphKey>);
begin
  Keys.Sort(TComparer<TMmdMotionMorphKey>.Construct(
    function(const Left, Right: TMmdMotionMorphKey): Integer
    begin
      if Left.Frame < Right.Frame then Result := -1
      else if Left.Frame > Right.Frame then Result := 1 else Result := 0;
    end));
end;

function TryReadVmdMotionDocument(const FileName: string;
  out Document: TMmdMotionDocument): Boolean;
var
  BoneCount, MorphCount: Cardinal;
  BoneKey: TMmdMotionBoneKey;
  BoneMap, MorphMap: TDictionary<string, Integer>;
  BoneTrack: TMmdMotionBoneTrack;
  Header, Name: string;
  I, Index: Integer;
  MorphKey: TMmdMotionMorphKey;
  MorphTrack: TMmdMotionMorphTrack;
  Stream: TFileStream;
begin
  Result := False;
  Document := nil;
  BoneMap := TDictionary<string, Integer>.Create;
  MorphMap := TDictionary<string, Integer>.Create;
  try
    try
      Document := TMmdMotionDocument.Create;
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
      try
        Header := ReadFixedText(Stream, VmdHeaderSize);
        if not SameText(Header, 'Vocaloid Motion Data 0002') then Exit;
        Document.ModelName := ReadFixedText(Stream, VmdModelNameSize);
        BoneCount := ReadCardinal(Stream);
        if BoneCount > MaxVmdKeys then Exit;
        for I := 0 to Integer(BoneCount) - 1 do
        begin
          if not ReadBoneKey(Stream, Name, BoneKey) then Exit;
          if not BoneMap.TryGetValue(Name, Index) then
          begin
            BoneTrack := TMmdMotionBoneTrack.Create(Name);
            Index := Document.BoneTracks.Add(BoneTrack);
            BoneMap.Add(Name, Index);
          end;
          Document.BoneTracks[Index].Keys.Add(BoneKey);
        end;
        MorphCount := ReadCardinal(Stream);
        if MorphCount > MaxVmdKeys - BoneCount then Exit;
        for I := 0 to Integer(MorphCount) - 1 do
        begin
          if not ReadMorphKey(Stream, Name, MorphKey) then Exit;
          if not MorphMap.TryGetValue(Name, Index) then
          begin
            MorphTrack := TMmdMotionMorphTrack.Create(Name);
            Index := Document.MorphTracks.Add(MorphTrack);
            MorphMap.Add(Name, Index);
          end;
          Document.MorphTracks[Index].Keys.Add(MorphKey);
        end;
      finally
        Stream.Free;
      end;
      if (Document.BoneTracks.Count = 0) and
        (Document.MorphTracks.Count = 0) then Exit;
      for BoneTrack in Document.BoneTracks do SortBoneKeys(BoneTrack.Keys);
      for MorphTrack in Document.MorphTracks do SortMorphKeys(MorphTrack.Keys);
      Result := True;
    except
      Result := False;
    end;
  finally
    MorphMap.Free;
    BoneMap.Free;
    if not Result then FreeAndNil(Document);
  end;
end;

end.
