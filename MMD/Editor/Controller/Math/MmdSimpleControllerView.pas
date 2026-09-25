unit MmdSimpleControllerView;

// カメラ基準の入力をワールドベクトルへ変換し、局所ボーン姿勢へ適用する。

interface

uses
  PmxModel,
  PmxPose;

// ワールドベクトルの長さを返す。入力は変更しない。
function VectorLength(const Value: TPmxVector3): Single;
// 画面の左右・上下をカメラ角に応じたワールド方向へ変換する。
function ScreenOffset(X, Y, Yaw, Pitch, Scale: Single): TPmxVector3;
// カメラの奥行き入力をワールド方向へ変換する。
function DepthOffset(Depth, Yaw, Pitch, Scale: Single): TPmxVector3;
// 二節関節の曲げが画面右へ進む符号を返す。姿勢は変更しない。
function BendViewSign(const Model: TPmxModel; const Poses: TPmxBonePoses;
  Root, Joint, Tip: Integer; CameraYaw, CameraPitch: Single): Single;
// 開始姿勢を基準にワールド移動・回転を局所姿勢へ合成し、NewPosesだけを変更する。
procedure ApplyWorldBoneTransform(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; var NewPoses: TPmxBonePoses;
  Bone: Integer; const WorldMove, WorldTurn, TwistAxis: TPmxVector3;
  MoveScale, DragTwist: Single);


implementation

uses
  System.Math,
  PmxBoneSolver,
  PmxPoseMath;

function VectorLength(const Value: TPmxVector3): Single;
begin
  Result := Sqrt(DotVector(Value, Value));
end;

function ScreenOffset(X, Y, Yaw, Pitch, Scale: Single): TPmxVector3;
var
  CosPitch, CosYaw, SinPitch, SinYaw: Single;
begin
  SinCos(Yaw, SinYaw, CosYaw);
  SinCos(Pitch, SinPitch, CosPitch);
  Result.X := Scale * (X * CosYaw + Y * SinPitch * SinYaw);
  Result.Y := Scale * Y * CosPitch;
  Result.Z := Scale * (X * SinYaw - Y * SinPitch * CosYaw);
end;

function DepthOffset(Depth, Yaw, Pitch, Scale: Single): TPmxVector3;
var
  CosPitch, CosYaw, SinPitch, SinYaw: Single;
begin
  SinCos(Yaw, SinYaw, CosYaw);
  SinCos(Pitch, SinPitch, CosPitch);
  Result.X := -Scale * Depth * SinYaw * CosPitch;
  Result.Y := Scale * Depth * SinPitch;
  Result.Z := Scale * Depth * CosYaw * CosPitch;
end;

function BendViewSign(const Model: TPmxModel;
  const Poses: TPmxBonePoses; Root, Joint, Tip: Integer;
  CameraYaw, CameraPitch: Single): Single;
var
  Parent: Integer;
  Direction, Pole, Tangent, ViewUp, ViewRight,
    FallbackAxis: TPmxVector3;
  Transforms: TPmxBoneTransforms;
  Alignment: Single;
begin
  Result := 1;
  if (Model = nil) or (Length(Poses) <> Length(Model.Bones)) then Exit;
  if (Root < 0) or (Joint < 0) or (Tip < 0) then Exit;
  CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
  Direction := NormalizeVector(SubtractVector(
    Transforms[Tip].Position, Transforms[Root].Position));
  Pole := SubtractVector(Transforms[Joint].Position,
    Transforms[Root].Position);
  Pole := SubtractVector(Pole, ScaleVector(Direction,
    DotVector(Pole, Direction)));
  if VectorLength(Pole) < 0.000001 then
  begin
    Parent := Model.Bones[Root].ParentIndex;
    FallbackAxis := Default(TPmxVector3);
    FallbackAxis.Z := 1;
    if Parent >= 0 then
      Pole := RotateVector(Transforms[Parent].Rotation, FallbackAxis)
    else
      Pole := FallbackAxis;
    Pole := SubtractVector(Pole, ScaleVector(Direction,
      DotVector(Pole, Direction)));
  end;
  if VectorLength(Pole) < 0.000001 then Exit;
  Tangent := CrossVector(Direction, NormalizeVector(Pole));
  ViewRight := ScreenOffset(1, 0, CameraYaw, CameraPitch, 1);
  Alignment := DotVector(Tangent, ViewRight);
  if Abs(Alignment) < 0.1 then
  begin
    // 横から見て関節が画面右へ動けない角度では上方向を使う。
    ViewUp := ScreenOffset(0, 1, CameraYaw, CameraPitch, 1);
    Alignment := DotVector(Tangent, ViewUp);
  end;
  if Alignment < 0 then Result := -1;
end;

procedure ApplyWorldBoneTransform(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; var NewPoses: TPmxBonePoses;
  Bone: Integer; const WorldMove, WorldTurn,
  TwistAxis: TPmxVector3; MoveScale, DragTwist: Single);
var
  Angle: Single;
  LocalMove, LocalTurn: TPmxVector3;
  Parent: Integer;
  ParentRotation, Rotation: TPmxQuaternion;
  Transforms: TPmxBoneTransforms;
begin
  Parent := Model.Bones[Bone].ParentIndex;
  ParentRotation := IdentityQuaternion;
  if Parent >= 0 then
  begin
    CalculateInteractiveBoneTransforms(Model, BasePoses, Transforms);
    ParentRotation := Transforms[Parent].Rotation;
  end;
  LocalMove := RotateVector(InverseQuaternion(ParentRotation), WorldMove);
  NewPoses[Bone].Translation := AddVector(NewPoses[Bone].Translation,
    ScaleVector(LocalMove, MoveScale));
  LocalTurn := RotateVector(InverseQuaternion(ParentRotation), WorldTurn);
  Angle := Min(VectorLength(LocalTurn), 1.2);
  if Angle > 0.000001 then
  begin
    Rotation := QuaternionFromAxisAngle(LocalTurn, Angle);
    NewPoses[Bone].Rotation := NormalizeQuaternion(MultiplyQuaternion(
      Rotation, NewPoses[Bone].Rotation));
  end;
  if Abs(DragTwist) > 0.000001 then
  begin
    Rotation := QuaternionFromAxisAngle(TwistAxis, DragTwist * 0.8);
    NewPoses[Bone].Rotation := NormalizeQuaternion(MultiplyQuaternion(
      NewPoses[Bone].Rotation, Rotation));
  end;
end;

end.
