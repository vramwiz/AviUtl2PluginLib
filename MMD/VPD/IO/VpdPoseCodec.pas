unit VpdPoseCodec;

// MMD標準VPDのボーン姿勢を、名前付きローカル姿勢との間で変換する。

interface

uses
  PmxPose;

// 名前付き姿勢をVocaloid Pose Data形式のテキストへ変換する。
function EncodeVpdPose(const ModelName: string;
  const Poses: TPmxNamedBonePoses): string;
// VPDテキストを検証して名前付き姿勢へ変換する。失敗時はPosesを空にする。
function TryDecodeVpdPose(const Text: string;
  out Poses: TPmxNamedBonePoses): Boolean;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.SysUtils,
  PmxModel;

const
  VPD_HEADER = 'Vocaloid Pose Data file';
  MAX_VPD_BONES = 4096;

function StripComment(const Line: string): string;
var
  CommentPos: Integer;
begin
  Result := Line;
  CommentPos := Pos('//', Result);
  if CommentPos > 0 then
    Delete(Result, CommentPos, MaxInt);
  Result := Trim(Result);
end;

function NextContentLine(const Lines: TStrings; var Index: Integer;
  out Line: string): Boolean;
begin
  while Index < Lines.Count do
  begin
    Line := StripComment(Lines[Index]);
    Inc(Index);
    if Line <> '' then
      Exit(True);
  end;
  Line := '';
  Result := False;
end;

function RemoveTerminator(const Line: string; Terminator: Char;
  out Value: string): Boolean;
begin
  Value := Trim(Line);
  Result := (Value <> '') and (Value[Length(Value)] = Terminator);
  if Result then
  begin
    Delete(Value, Length(Value), 1);
    Value := Trim(Value);
  end;
end;

function TryParseNumbers(const Line: string; ExpectedCount: Integer;
  out Values: TArray<Single>): Boolean;
var
  Index: Integer;
  Parts: TArray<string>;
  ValueText: string;
begin
  Values := nil;
  Result := RemoveTerminator(Line, ';', ValueText);
  if not Result then
    Exit;
  Parts := ValueText.Split([',']);
  if Length(Parts) <> ExpectedCount then
    Exit(False);
  SetLength(Values, ExpectedCount);
  for Index := 0 to ExpectedCount - 1 do
    if not TryStrToFloat(Trim(Parts[Index]), Values[Index],
      TFormatSettings.Invariant) or IsNan(Values[Index]) or
      IsInfinite(Values[Index]) then
    begin
      Values := nil;
      Exit(False);
    end;
  Result := True;
end;

function TryReadBone(const Lines: TStrings; var LineIndex: Integer;
  out NamedPose: TPmxNamedBonePose): Boolean;
var
  BracePos: Integer;
  Line: string;
  RotationLengthSquared: Single;
  Values: TArray<Single>;
begin
  NamedPose := Default(TPmxNamedBonePose);
  if not NextContentLine(Lines, LineIndex, Line) then
    Exit(False);
  BracePos := Pos('{', Line);
  if BracePos <= 0 then
    Exit(False);
  NamedPose.BoneName := Trim(Copy(Line, BracePos + 1, MaxInt));
  if NamedPose.BoneName = '' then
    Exit(False);
  if not NextContentLine(Lines, LineIndex, Line) or
    not TryParseNumbers(Line, 3, Values) then
    Exit(False);
  NamedPose.Pose.Translation.X := Values[0];
  NamedPose.Pose.Translation.Y := Values[1];
  NamedPose.Pose.Translation.Z := Values[2];
  if not NextContentLine(Lines, LineIndex, Line) or
    not TryParseNumbers(Line, 4, Values) then
    Exit(False);
  NamedPose.Pose.Rotation.X := Values[0];
  NamedPose.Pose.Rotation.Y := Values[1];
  NamedPose.Pose.Rotation.Z := Values[2];
  NamedPose.Pose.Rotation.W := Values[3];
  RotationLengthSquared := Sqr(NamedPose.Pose.Rotation.X) +
    Sqr(NamedPose.Pose.Rotation.Y) + Sqr(NamedPose.Pose.Rotation.Z) +
    Sqr(NamedPose.Pose.Rotation.W);
  if RotationLengthSquared <= 0.000001 then
    Exit(False);
  NamedPose.Pose.Rotation := NormalizeQuaternion(NamedPose.Pose.Rotation);
  Result := NextContentLine(Lines, LineIndex, Line) and (Line = '}');
end;

function TryDecodeVpdPose(const Text: string;
  out Poses: TPmxNamedBonePoses): Boolean;
var
  BoneCount, BoneIndex, LineIndex: Integer;
  CountText, Header, Line: string;
  Lines: TStringList;
  Names: TDictionary<string, Byte>;
begin
  Poses := nil;
  Result := False;
  Lines := TStringList.Create;
  Names := TDictionary<string, Byte>.Create;
  try
    Lines.Text := Text;
    LineIndex := 0;
    if not NextContentLine(Lines, LineIndex, Header) then
      Exit;
    if (Header <> '') and (Header[1] = #$FEFF) then
      Delete(Header, 1, 1);
    if Header <> VPD_HEADER then
      Exit;
    if not NextContentLine(Lines, LineIndex, Line) or
      not RemoveTerminator(Line, ';', CountText) then
      Exit;
    // モデル名行はVPD上の参考情報であり、姿勢のモデル解決には使用しない。
    if not NextContentLine(Lines, LineIndex, Line) or
      not RemoveTerminator(Line, ';', CountText) or
      not TryStrToInt(CountText, BoneCount) or (BoneCount < 0) or
      (BoneCount > MAX_VPD_BONES) then
      Exit;
    SetLength(Poses, BoneCount);
    for BoneIndex := 0 to BoneCount - 1 do
    begin
      if not TryReadBone(Lines, LineIndex, Poses[BoneIndex]) or
        Names.ContainsKey(Poses[BoneIndex].BoneName) then
      begin
        Poses := nil;
        Exit;
      end;
      Names.Add(Poses[BoneIndex].BoneName, 0);
    end;
    Result := True;
  finally
    Names.Free;
    Lines.Free;
  end;
end;

function SafeModelName(const Value: string): string;
begin
  Result := Trim(Value).Replace(#13, '_').Replace(#10, '_').Replace(';', '_');
  if Result = '' then
    Result := 'MMDAIPreview';
end;

function VpdFloat(Value: Single): string;
begin
  if IsNan(Value) or IsInfinite(Value) then
    raise EArgumentException.Create('VPD pose contains a non-finite number');
  Result := FormatFloat('0.000000', Value, TFormatSettings.Invariant);
end;

function EncodeVpdPose(const ModelName: string;
  const Poses: TPmxNamedBonePoses): string;
var
  BoneIndex: Integer;
  Lines: TStringList;
  Pose: TPmxBonePose;
begin
  if Length(Poses) > MAX_VPD_BONES then
    raise EArgumentOutOfRangeException.Create('VPD bone count exceeds the limit');
  Lines := TStringList.Create;
  try
    Lines.LineBreak := sLineBreak;
    Lines.Add(VPD_HEADER);
    Lines.Add('');
    Lines.Add(SafeModelName(ModelName) + '.osm;');
    Lines.Add(IntToStr(Length(Poses)) + ';');
    Lines.Add('');
    for BoneIndex := 0 to High(Poses) do
    begin
      if (Poses[BoneIndex].BoneName = '') or
        (Pos('{', Poses[BoneIndex].BoneName) > 0) or
        (Pos('}', Poses[BoneIndex].BoneName) > 0) or
        (Pos(#13, Poses[BoneIndex].BoneName) > 0) or
        (Pos(#10, Poses[BoneIndex].BoneName) > 0) then
        raise EArgumentException.Create('VPD bone name is invalid');
      Pose := Poses[BoneIndex].Pose;
      Pose.Rotation := NormalizeQuaternion(Pose.Rotation);
      Lines.Add(Format('Bone%d{%s', [BoneIndex, Poses[BoneIndex].BoneName]));
      Lines.Add(Format('  %s,%s,%s;', [VpdFloat(Pose.Translation.X),
        VpdFloat(Pose.Translation.Y), VpdFloat(Pose.Translation.Z)]));
      Lines.Add(Format('  %s,%s,%s,%s;', [VpdFloat(Pose.Rotation.X),
        VpdFloat(Pose.Rotation.Y), VpdFloat(Pose.Rotation.Z),
        VpdFloat(Pose.Rotation.W)]));
      Lines.Add('}');
      Lines.Add('');
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
