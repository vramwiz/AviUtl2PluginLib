unit MmdSimpleControllerTip;

// 腕の軸捩りと手首・足首の視点基準回転を、手足先の位置を保って適用する。

interface

uses
  PmxModel,
  PmxPose;

// 指定側の前腕を軸回転し、Posesを直接更新する。
function TwistHand(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; Twist: Single): Boolean;
// 指定側の手首をカメラ上下方向に回し、Posesを直接更新する。
function PitchHand(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; Pitch, CameraYaw, CameraPitch: Single): Boolean;
// 指定側の足首を脚軸の周りに回し、Posesを直接更新する。
function TwistFoot(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; Twist: Single): Boolean;
// 指定側の足先をカメラ上下方向に回し、Posesを直接更新する。
function PitchFoot(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; Pitch, CameraYaw, CameraPitch: Single): Boolean;


implementation

uses
  System.SysUtils,
  MmdSimpleControllerBones,
  MmdSimpleControllerView,
  PmxBoneSolver,
  PmxPoseMath;

function TwistHand(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; Twist: Single): Boolean;
var
  Arm, Elbow, Wrist, Parent: Integer;
  Axis, AxisLocal: TPmxVector3;
  ParentRotation, Rotation: TPmxQuaternion;
  Transforms: TPmxBoneTransforms;
begin
  HandBones(Model, Left, Arm, Elbow, Wrist);
  Result := (Elbow >= 0) and (Wrist >= 0);
  if not Result or (Abs(Twist) < 0.000001) then Exit;
  CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
  Axis := SubtractVector(Transforms[Wrist].Position,
    Transforms[Elbow].Position);
  if VectorLength(Axis) <= 0.000001 then Exit(False);
  // ひじから手首への軸をひじで回すと、手首位置を保ったまま前腕を捩れる。
  Parent := Model.Bones[Elbow].ParentIndex;
  if Parent >= 0 then
    ParentRotation := Transforms[Parent].Rotation
  else
    ParentRotation := IdentityQuaternion;
  AxisLocal := RotateVector(InverseQuaternion(ParentRotation), Axis);
  Rotation := QuaternionFromAxisAngle(AxisLocal, Twist * 1.2);
  Poses[Elbow].Rotation := NormalizeQuaternion(MultiplyQuaternion(
    Rotation, Poses[Elbow].Rotation));
end;

function HandForwardBone(const Model: TPmxModel; Wrist: Integer): Integer;
var
  I, Pass: Integer;
  Name: string;
  Distance, BestDistance: Single;
begin
  Result := -1;
  // 手の向きは中指を優先し、モデルに無い場合だけ人差し指で補う。
  for Pass := 0 to 1 do
  begin
    BestDistance := 0;
    for I := 0 to High(Model.Bones) do
    begin
      if not IsAncestor(Model, Wrist, I) then Continue;
      Name := LowerCase(Model.Bones[I].Name);
      if Pass = 0 then
      begin
        if (Pos('中指', Name) = 0) and
          (Pos('middle', Name) = 0) then Continue;
      end
      else if (Pos('人指', Name) = 0) and
        (Pos('index', Name) = 0) then Continue;
      Distance := VectorLength(SubtractVector(
        Model.Bones[I].Position, Model.Bones[Wrist].Position));
      if Distance > BestDistance then
      begin
        Result := I;
        BestDistance := Distance;
      end;
    end;
    if Result >= 0 then Exit;
  end;
end;

function PitchHand(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; Pitch, CameraYaw, CameraPitch: Single): Boolean;
var
  Arm, Elbow, Wrist, Finger, Parent: Integer;
  HandForward, ViewUp, AxisWorld, AxisLocal: TPmxVector3;
  ParentRotation, Rotation: TPmxQuaternion;
  Transforms: TPmxBoneTransforms;
begin
  HandBones(Model, Left, Arm, Elbow, Wrist);
  Result := (Elbow >= 0) and (Wrist >= 0);
  if not Result or (Abs(Pitch) < 0.000001) then Exit;
  Finger := HandForwardBone(Model, Wrist);
  CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
  HandForward := Default(TPmxVector3);
  if Finger >= 0 then
    HandForward := SubtractVector(Transforms[Finger].Position,
      Transforms[Wrist].Position);
  if VectorLength(HandForward) < 0.000001 then
    HandForward := SubtractVector(Transforms[Wrist].Position,
      Transforms[Elbow].Position);
  if VectorLength(HandForward) < 0.000001 then
  begin
    HandForward.X := 1;
    if not Left then HandForward.X := -1;
    HandForward := RotateVector(Transforms[Wrist].Rotation,
      HandForward);
  end;
  ViewUp := ScreenOffset(0, 1, CameraYaw, CameraPitch, 1);
  AxisWorld := CrossVector(HandForward, ViewUp);
  if VectorLength(AxisWorld) < 0.000001 then
    AxisWorld := ScreenOffset(1, 0, CameraYaw, CameraPitch, 1);
  Parent := Model.Bones[Wrist].ParentIndex;
  if Parent >= 0 then
    ParentRotation := Transforms[Parent].Rotation
  else
    ParentRotation := IdentityQuaternion;
  AxisLocal := RotateVector(InverseQuaternion(ParentRotation),
    AxisWorld);
  Rotation := QuaternionFromAxisAngle(AxisLocal, Pitch * 0.8);
  Poses[Wrist].Rotation := NormalizeQuaternion(MultiplyQuaternion(
    Rotation, Poses[Wrist].Rotation));
end;

function TwistFoot(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; Twist: Single): Boolean;
var
  Leg, Knee, Ankle, Parent: Integer;
  Axis, AxisLocal: TPmxVector3;
  ParentRotation, Rotation: TPmxQuaternion;
  Transforms: TPmxBoneTransforms;
begin
  FootBones(Model, Left, Leg, Knee, Ankle);
  Result := (Knee >= 0) and (Ankle >= 0);
  if not Result or (Abs(Twist) < 0.000001) then Exit;
  CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
  Axis := SubtractVector(Transforms[Ankle].Position,
    Transforms[Knee].Position);
  if VectorLength(Axis) <= 0.000001 then Exit(False);
  Parent := Model.Bones[Ankle].ParentIndex;
  if Parent >= 0 then
    ParentRotation := Transforms[Parent].Rotation
  else
    ParentRotation := IdentityQuaternion;
  AxisLocal := RotateVector(InverseQuaternion(ParentRotation), Axis);
  Rotation := QuaternionFromAxisAngle(AxisLocal, Twist * 1.2);
  // 足首自身を回して足先の向きだけを変え、足首の位置は維持する。
  Poses[Ankle].Rotation := NormalizeQuaternion(MultiplyQuaternion(
    Rotation, Poses[Ankle].Rotation));
end;

function PitchFoot(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; Pitch, CameraYaw, CameraPitch: Single): Boolean;
var
  Leg, Knee, Ankle, Toe, Parent: Integer;
  FootForward, ViewUp, AxisWorld, AxisLocal: TPmxVector3;
  ParentRotation, Rotation: TPmxQuaternion;
  Transforms: TPmxBoneTransforms;
begin
  FootBones(Model, Left, Leg, Knee, Ankle);
  Result := Ankle >= 0;
  if not Result or (Abs(Pitch) < 0.000001) then Exit;
  if Left then
    Toe := FindNamedBone(Model, ['左つま先', '左足先EX', '左足先',
      'LeftToe', 'left_toe'])
  else
    Toe := FindNamedBone(Model, ['右つま先', '右足先EX', '右足先',
      'RightToe', 'right_toe']);
  CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
  FootForward := Default(TPmxVector3);
  if (Toe >= 0) and IsAncestor(Model, Ankle, Toe) then
    FootForward := SubtractVector(Transforms[Toe].Position,
      Transforms[Ankle].Position);
  if VectorLength(FootForward) < 0.000001 then
  begin
    // 足先ボーンがないモデルでは、MMDの前方を足首の向きで補う。
    FootForward.Z := -1;
    FootForward := RotateVector(Transforms[Ankle].Rotation, FootForward);
  end;
  ViewUp := ScreenOffset(0, 1, CameraYaw, CameraPitch, 1);
  AxisWorld := CrossVector(FootForward, ViewUp);
  if VectorLength(AxisWorld) < 0.000001 then
    AxisWorld := ScreenOffset(1, 0, CameraYaw, CameraPitch, 1);
  Parent := Model.Bones[Ankle].ParentIndex;
  if Parent >= 0 then
    ParentRotation := Transforms[Parent].Rotation
  else
    ParentRotation := IdentityQuaternion;
  AxisLocal := RotateVector(InverseQuaternion(ParentRotation),
    AxisWorld);
  Rotation := QuaternionFromAxisAngle(AxisLocal, Pitch * 0.8);
  Poses[Ankle].Rotation := NormalizeQuaternion(MultiplyQuaternion(
    Rotation, Poses[Ankle].Rotation));
end;

end.
