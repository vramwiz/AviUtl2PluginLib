unit PmxPoseCodec;

// AviUtl2オブジェクトへ保存するバージョン付き姿勢JSONの変換を担当する。

interface

uses
  PmxPose;

// 版付き姿勢JSONを検証して名前付き姿勢へ変換する。失敗時はPosesを空にしてFalseを返す。
function TryDecodePoseData(const Text: string;
  out Poses: TPmxNamedBonePoses): Boolean;
// 任意の全身回転も読み取る。旧データでは単位Quaternionを返す。
function TryDecodePoseDataWithRoot(const Text: string;
  out Poses: TPmxNamedBonePoses; out RootRotation: TPmxQuaternion): Boolean; overload;
// 全身回転の明示有無も返す。
function TryDecodePoseDataWithRoot(const Text: string;
  out Poses: TPmxNamedBonePoses; out RootRotation: TPmxQuaternion;
  out HasRootRotation: Boolean): Boolean; overload;
// モデル表示に対するポーズ固有の相対Yaw/Pitchも読み取る。単位は度。
function TryDecodePoseDataWithRootAndAngle(const Text: string;
  out Poses: TPmxNamedBonePoses; out RootRotation: TPmxQuaternion;
  out HasRootRotation: Boolean; out YawDegrees, PitchDegrees: Single;
  out HasRelativeAngle: Boolean): Boolean;
// 名前付き姿勢を版付きJSONへ変換する。不正なボーン名や上限超過は例外となる。
function EncodePoseData(const Poses: TPmxNamedBonePoses): string;
// 全身回転を足元原点まわりの姿勢値として保存する。
function EncodePoseDataWithRoot(const Poses: TPmxNamedBonePoses;
  const RootRotation: TPmxQuaternion;
  IncludeRootRotation: Boolean = True): string;
// 全身回転とモデル表示に対する相対アングルを別々に保存する。
function EncodePoseDataWithRootAndAngle(const Poses: TPmxNamedBonePoses;
  const RootRotation: TPmxQuaternion; IncludeRootRotation: Boolean;
  YawDegrees, PitchDegrees: Single; IncludeRelativeAngle: Boolean): string;

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.Math,
  System.SysUtils,
  PmxModel;

const
  MAX_POSE_COUNT = 4096;
  MAX_POSE_TEXT_LENGTH = 1024 * 1024;
  POSE_DATA_VERSION = 1;

function TryReadNumber(const Values: TJSONArray; Index: Integer;
  out Number: Single): Boolean;
var
  Value: TJSONValue;
begin
  Result := (Values <> nil) and (Index >= 0) and (Index < Values.Count);
  if not Result then
    Exit;
  Value := Values.Items[Index];
  Result := Value is TJSONNumber;
  if not Result then
    Exit;
  Number := TJSONNumber(Value).AsDouble;
  Result := not IsNan(Number) and not IsInfinite(Number);
end;

function TryReadVector3(const Value: TJSONValue; out Vector: TPmxVector3): Boolean;
var
  Values: TJSONArray;
begin
  Result := Value is TJSONArray;
  if not Result then
    Exit;
  Values := TJSONArray(Value);
  Result := (Values.Count = 3) and TryReadNumber(Values, 0, Vector.X) and
    TryReadNumber(Values, 1, Vector.Y) and
    TryReadNumber(Values, 2, Vector.Z);
end;

function TryReadQuaternion(const Value: TJSONValue;
  out Rotation: TPmxQuaternion): Boolean;
var
  LengthSquared: Single;
  Values: TJSONArray;
begin
  Result := Value is TJSONArray;
  if not Result then
    Exit;
  Values := TJSONArray(Value);
  Result := (Values.Count = 4) and TryReadNumber(Values, 0, Rotation.X) and
    TryReadNumber(Values, 1, Rotation.Y) and
    TryReadNumber(Values, 2, Rotation.Z) and
    TryReadNumber(Values, 3, Rotation.W);
  if not Result then
    Exit;
  LengthSquared := Rotation.X * Rotation.X + Rotation.Y * Rotation.Y +
    Rotation.Z * Rotation.Z + Rotation.W * Rotation.W;
  Result := LengthSquared > 0.000001;
  if Result then
    Rotation := NormalizeQuaternion(Rotation);
end;

function TryDecodePoseObject(const Value: TJSONValue;
  out NamedPose: TPmxNamedBonePose): Boolean;
var
  NameValue: TJSONValue;
  PoseObject: TJSONObject;
begin
  Result := Value is TJSONObject;
  if not Result then
    Exit;
  PoseObject := TJSONObject(Value);
  NameValue := PoseObject.GetValue('name');
  Result := (NameValue is TJSONString) and
    (TJSONString(NameValue).Value <> '') and
    TryReadVector3(PoseObject.GetValue('translation'),
      NamedPose.Pose.Translation) and
    TryReadQuaternion(PoseObject.GetValue('rotation'),
      NamedPose.Pose.Rotation);
  if Result then
    NamedPose.BoneName := TJSONString(NameValue).Value;
end;

function TryDecodePoseDataWithRootAndAngle(const Text: string;
  out Poses: TPmxNamedBonePoses; out RootRotation: TPmxQuaternion;
  out HasRootRotation: Boolean; out YawDegrees, PitchDegrees: Single;
  out HasRelativeAngle: Boolean): Boolean;
var
  AngleArray: TJSONArray;
  BoneArray: TJSONArray;
  Index: Integer;
  Root: TJSONValue;
  RootObject: TJSONObject;
  VersionValue: TJSONValue;
begin
  Poses := nil;
  RootRotation := IdentityQuaternion;
  HasRootRotation := False;
  YawDegrees := 0;
  PitchDegrees := 0;
  HasRelativeAngle := False;
  Result := False;
  if (Text = '') or (Length(Text) > MAX_POSE_TEXT_LENGTH) then
    Exit;
  Root := TJSONObject.ParseJSONValue(Text);
  try
    if not (Root is TJSONObject) then
      Exit;
    RootObject := TJSONObject(Root);
    VersionValue := RootObject.GetValue('version');
    if not (VersionValue is TJSONNumber) or
      (TJSONNumber(VersionValue).AsInt <> POSE_DATA_VERSION) then
      Exit;
    if not (RootObject.GetValue('bones') is TJSONArray) then
      Exit;
    HasRootRotation := RootObject.GetValue('rootRotation') <> nil;
    if HasRootRotation and
      not TryReadQuaternion(RootObject.GetValue('rootRotation'),
        RootRotation) then Exit;
    HasRelativeAngle := RootObject.GetValue('relativeAngles') <> nil;
    if HasRelativeAngle then
    begin
      if not (RootObject.GetValue('relativeAngles') is TJSONArray) then Exit;
      AngleArray := TJSONArray(RootObject.GetValue('relativeAngles'));
      if (AngleArray.Count <> 2) or
        not TryReadNumber(AngleArray, 0, YawDegrees) or
        not TryReadNumber(AngleArray, 1, PitchDegrees) or
        (Abs(YawDegrees) > 180.001) or
        (Abs(PitchDegrees) > 89.001) then Exit;
      YawDegrees := EnsureRange(YawDegrees, -180.0, 180.0);
      PitchDegrees := EnsureRange(PitchDegrees, -89.0, 89.0);
    end;
    BoneArray := TJSONArray(RootObject.GetValue('bones'));
    if BoneArray.Count > MAX_POSE_COUNT then
      Exit;
    SetLength(Poses, BoneArray.Count);
    for Index := 0 to BoneArray.Count - 1 do
      if not TryDecodePoseObject(BoneArray.Items[Index], Poses[Index]) then
      begin
        Poses := nil;
        Exit;
      end;
    Result := True;
  finally
    Root.Free;
  end;
end;

function TryDecodePoseDataWithRoot(const Text: string;
  out Poses: TPmxNamedBonePoses; out RootRotation: TPmxQuaternion;
  out HasRootRotation: Boolean): Boolean;
var
  HasRelativeAngle: Boolean;
  YawDegrees, PitchDegrees: Single;
begin
  Result := TryDecodePoseDataWithRootAndAngle(Text, Poses, RootRotation,
    HasRootRotation, YawDegrees, PitchDegrees, HasRelativeAngle);
end;

function TryDecodePoseDataWithRoot(const Text: string;
  out Poses: TPmxNamedBonePoses; out RootRotation: TPmxQuaternion): Boolean;
var
  HasRootRotation: Boolean;
begin
  Result := TryDecodePoseDataWithRoot(Text, Poses, RootRotation,
    HasRootRotation);
end;

function TryDecodePoseData(const Text: string;
  out Poses: TPmxNamedBonePoses): Boolean;
var
  RootRotation: TPmxQuaternion;
begin
  Result := TryDecodePoseDataWithRoot(Text, Poses, RootRotation);
end;

function CreateVector3Array(const Value: TPmxVector3): TJSONArray;
begin
  Result := TJSONArray.Create;
  Result.AddElement(TJSONNumber.Create(Value.X));
  Result.AddElement(TJSONNumber.Create(Value.Y));
  Result.AddElement(TJSONNumber.Create(Value.Z));
end;

function CreateQuaternionArray(const Value: TPmxQuaternion): TJSONArray;
begin
  Result := TJSONArray.Create;
  Result.AddElement(TJSONNumber.Create(Value.X));
  Result.AddElement(TJSONNumber.Create(Value.Y));
  Result.AddElement(TJSONNumber.Create(Value.Z));
  Result.AddElement(TJSONNumber.Create(Value.W));
end;

function EncodePoseDataWithRootAndAngle(const Poses: TPmxNamedBonePoses;
  const RootRotation: TPmxQuaternion;
  IncludeRootRotation: Boolean; YawDegrees, PitchDegrees: Single;
  IncludeRelativeAngle: Boolean): string;
var
  AngleArray: TJSONArray;
  BoneArray: TJSONArray;
  NamedPose: TPmxNamedBonePose;
  PoseObject: TJSONObject;
  RootObject: TJSONObject;
begin
  if Length(Poses) > MAX_POSE_COUNT then
    raise EArgumentOutOfRangeException.Create('Pose count exceeds the limit');
  if IncludeRelativeAngle and
    (IsNan(YawDegrees) or IsInfinite(YawDegrees) or
     IsNan(PitchDegrees) or IsInfinite(PitchDegrees) or
     (Abs(YawDegrees) > 180.001) or
     (Abs(PitchDegrees) > 89.001)) then
    raise EArgumentOutOfRangeException.Create('Relative pose angle is invalid');
  RootObject := TJSONObject.Create;
  try
    RootObject.AddPair('version', TJSONNumber.Create(POSE_DATA_VERSION));
    if IncludeRootRotation then
      RootObject.AddPair('rootRotation',
        CreateQuaternionArray(NormalizeQuaternion(RootRotation)));
    if IncludeRelativeAngle then
    begin
      AngleArray := TJSONArray.Create;
      AngleArray.AddElement(TJSONNumber.Create(
        EnsureRange(YawDegrees, -180.0, 180.0)));
      AngleArray.AddElement(TJSONNumber.Create(
        EnsureRange(PitchDegrees, -89.0, 89.0)));
      RootObject.AddPair('relativeAngles', AngleArray);
    end;
    BoneArray := TJSONArray.Create;
    RootObject.AddPair('bones', BoneArray);
    for NamedPose in Poses do
    begin
      if NamedPose.BoneName = '' then
        raise EArgumentException.Create('Pose bone name must not be empty');
      PoseObject := TJSONObject.Create;
      BoneArray.AddElement(PoseObject);
      PoseObject.AddPair('name', NamedPose.BoneName);
      PoseObject.AddPair('translation',
        CreateVector3Array(NamedPose.Pose.Translation));
      PoseObject.AddPair('rotation',
        CreateQuaternionArray(NormalizeQuaternion(NamedPose.Pose.Rotation)));
    end;
    Result := RootObject.ToJSON;
  finally
    RootObject.Free;
  end;
end;

function EncodePoseDataWithRoot(const Poses: TPmxNamedBonePoses;
  const RootRotation: TPmxQuaternion;
  IncludeRootRotation: Boolean): string;
begin
  Result := EncodePoseDataWithRootAndAngle(Poses, RootRotation,
    IncludeRootRotation, 0, 0, False);
end;

function EncodePoseData(const Poses: TPmxNamedBonePoses): string;
begin
  Result := EncodePoseDataWithRoot(Poses, IdentityQuaternion, False);
end;

end.
