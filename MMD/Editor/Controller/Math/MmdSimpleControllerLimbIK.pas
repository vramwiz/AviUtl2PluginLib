unit MmdSimpleControllerLimbIK;

// 手首・足首の移動目標から二節関節を解き、肘・膝の曲げ方向を制御する。

interface

uses
  PmxModel,
  PmxPose;

// 手首をワールド方向へ動かし、肘の曲げ量を調整する。Posesを直接更新する。
function MoveHand(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; const WorldMove: TPmxVector3; Bend: Single): Boolean;
// 足首をワールド方向へ動かし、膝の曲げ量を調整する。Posesを直接更新する。
function MoveFoot(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; const WorldMove: TPmxVector3; Bend: Single): Boolean;


implementation

uses
  System.Math,
  MmdSimpleControllerBones,
  MmdSimpleControllerView,
  PmxBoneSolver,
  PmxPoseMath;

function RotationToward(const FromDirection,
  ToDirection: TPmxVector3): TPmxQuaternion;
var
  Axis, FromUnit, ToUnit: TPmxVector3;
  Angle, DotValue: Single;
begin
  FromUnit := NormalizeVector(FromDirection);
  ToUnit := NormalizeVector(ToDirection);
  DotValue := EnsureRange(DotVector(FromUnit, ToUnit), -1.0, 1.0);
  Axis := CrossVector(FromUnit, ToUnit);
  if VectorLength(Axis) <= 0.000001 then Exit(IdentityQuaternion);
  Angle := Min(ArcCos(DotValue), 0.35);
  Result := QuaternionFromAxisAngle(Axis, Angle);
end;

procedure TurnJointToward(const Model: TPmxModel;
  var Poses: TPmxBonePoses; Joint, Wrist: Integer;
  const Target: TPmxVector3; var Transforms: TPmxBoneTransforms);
var
  DeltaLocal, DeltaWorld, ParentRotation: TPmxQuaternion;
  Parent: Integer;
begin
  CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
  DeltaWorld := RotationToward(
    SubtractVector(Transforms[Wrist].Position, Transforms[Joint].Position),
    SubtractVector(Target, Transforms[Joint].Position));
  Parent := Model.Bones[Joint].ParentIndex;
  if Parent >= 0 then
    ParentRotation := Transforms[Parent].Rotation
  else
    ParentRotation := IdentityQuaternion;
  DeltaLocal := MultiplyQuaternion(
    MultiplyQuaternion(InverseQuaternion(ParentRotation), DeltaWorld),
    ParentRotation);
  Poses[Joint].Rotation := NormalizeQuaternion(MultiplyQuaternion(
    DeltaLocal, Poses[Joint].Rotation));
end;

function MoveLimb(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Root, Joint, Tip: Integer; const WorldMove: TPmxVector3;
  MoveScale, PoleTurn: Single; IsLeg: Boolean): Boolean;
var
  I, Parent: Integer;
  Distance, LimbLength, Reach, UpperLength, LowerLength,
    AlongLength, BendHeight, PoleAngle: Single;
  RootPosition, Target, Direction, Pole, JointTarget, ReferencePole,
    BindDirection, BindPole, FallbackAxis: TPmxVector3;
  ParentRotation: TPmxQuaternion;
  Transforms: TPmxBoneTransforms;
begin
  Result := (Root >= 0) and (Joint >= 0) and (Tip >= 0) and
    IsAncestor(Model, Root, Joint) and IsAncestor(Model, Joint, Tip);
  if not Result then Exit;
  CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
  RootPosition := Transforms[Root].Position;
  UpperLength := VectorLength(SubtractVector(Transforms[Joint].Position,
    RootPosition));
  LowerLength := VectorLength(SubtractVector(Transforms[Tip].Position,
    Transforms[Joint].Position));
  LimbLength := UpperLength + LowerLength;
  if LimbLength <= 0.000001 then Exit(False);
  Target := AddVector(Transforms[Tip].Position,
    ScaleVector(WorldMove, LimbLength * MoveScale));
  Distance := VectorLength(SubtractVector(Target, RootPosition));
  Reach := Max(LimbLength * 0.97,
    VectorLength(SubtractVector(Transforms[Tip].Position, RootPosition)));
  if Distance > Reach then
    Target := AddVector(RootPosition, ScaleVector(
      SubtractVector(Target, RootPosition), Reach / Distance));
  // 肘・膝の曲げ方向は現在の関節だけに依存させない。伸び切った時や
  // 誤った側へ折れた時には、モデルの休止姿勢と胴体側の向きから復元する。
  Direction := SubtractVector(Target, RootPosition);
  Distance := VectorLength(Direction);
  if Distance <= 0.000001 then Exit(False);
  Direction := ScaleVector(Direction, 1 / Distance);
  Parent := Model.Bones[Root].ParentIndex;
  if Parent >= 0 then
    ParentRotation := Transforms[Parent].Rotation
  else
    ParentRotation := IdentityQuaternion;
  BindDirection := NormalizeVector(SubtractVector(
    Model.Bones[Tip].Position, Model.Bones[Root].Position));
  BindPole := SubtractVector(Model.Bones[Joint].Position,
    Model.Bones[Root].Position);
  BindPole := SubtractVector(BindPole, ScaleVector(BindDirection,
    DotVector(BindPole, BindDirection)));
  if VectorLength(BindPole) >= LimbLength * 0.01 then
    ReferencePole := RotateVector(ParentRotation, BindPole)
  else
  begin
    FallbackAxis := Default(TPmxVector3);
    FallbackAxis.Z := 1;
    ReferencePole := RotateVector(ParentRotation, FallbackAxis);
  end;
  ReferencePole := SubtractVector(ReferencePole, ScaleVector(Direction,
    DotVector(ReferencePole, Direction)));
  if VectorLength(ReferencePole) < 0.000001 then
  begin
    FallbackAxis := Default(TPmxVector3);
    if IsLeg then FallbackAxis.Y := 1
    else FallbackAxis.Y := -1;
    ReferencePole := RotateVector(ParentRotation, FallbackAxis);
    ReferencePole := SubtractVector(ReferencePole, ScaleVector(Direction,
      DotVector(ReferencePole, Direction)));
  end;
  if VectorLength(ReferencePole) < 0.000001 then
  begin
    FallbackAxis := Default(TPmxVector3);
    FallbackAxis.X := 1;
    ReferencePole := CrossVector(Direction, FallbackAxis);
  end;
  ReferencePole := NormalizeVector(ReferencePole);
  Pole := SubtractVector(Transforms[Joint].Position, RootPosition);
  Pole := SubtractVector(Pole, ScaleVector(Direction,
    DotVector(Pole, Direction)));
  if VectorLength(Pole) < LimbLength * 0.03 then
    Pole := ReferencePole
  else
    Pole := NormalizeVector(Pole);
  PoleAngle := ArcTan2(DotVector(CrossVector(ReferencePole, Pole),
    Direction), DotVector(ReferencePole, Pole));
  // 解剖学的な曲げ半面を越えない範囲だけ、現在の向きと手動調整を保持する。
  PoleAngle := EnsureRange(PoleAngle + PoleTurn * 0.8, -1.2, 1.2);
  Pole := RotateVector(QuaternionFromAxisAngle(Direction, PoleAngle),
    ReferencePole);
  AlongLength := (Sqr(UpperLength) - Sqr(LowerLength) +
    Sqr(Distance)) / (2 * Distance);
  AlongLength := EnsureRange(AlongLength, -UpperLength, UpperLength);
  BendHeight := Sqrt(Max(0, Sqr(UpperLength) - Sqr(AlongLength)));
  JointTarget := AddVector(RootPosition, AddVector(
    ScaleVector(Direction, AlongLength), ScaleVector(Pole, BendHeight)));
  for I := 0 to 11 do
  begin
    TurnJointToward(Model, Poses, Root, Joint, JointTarget, Transforms);
    TurnJointToward(Model, Poses, Joint, Tip, Target, Transforms);
    CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
    if VectorLength(SubtractVector(Transforms[Tip].Position, Target)) <
      LimbLength * 0.002 then Break;
  end;
end;

procedure RestoreTipRotation(const Model: TPmxModel;
  var Poses: TPmxBonePoses; Tip: Integer;
  const BeforeRotation: TPmxQuaternion);
var
  Parent: Integer;
  AfterRotation, ParentRotation, DeltaWorld,
    DeltaLocal: TPmxQuaternion;
  Transforms: TPmxBoneTransforms;
begin
  CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
  AfterRotation := Transforms[Tip].Rotation;
  Parent := Model.Bones[Tip].ParentIndex;
  if Parent >= 0 then
    ParentRotation := Transforms[Parent].Rotation
  else
    ParentRotation := IdentityQuaternion;
  DeltaWorld := MultiplyQuaternion(BeforeRotation,
    InverseQuaternion(AfterRotation));
  DeltaLocal := MultiplyQuaternion(MultiplyQuaternion(
    InverseQuaternion(ParentRotation), DeltaWorld), ParentRotation);
  Poses[Tip].Rotation := NormalizeQuaternion(MultiplyQuaternion(
    DeltaLocal, Poses[Tip].Rotation));
end;

function MoveHand(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; const WorldMove: TPmxVector3; Bend: Single): Boolean;
var
  Arm, Elbow, Wrist: Integer;
  BeforeRotation: TPmxQuaternion;
  Transforms: TPmxBoneTransforms;
begin
  HandBones(Model, Left, Arm, Elbow, Wrist);
  if Abs(Bend) > 0.000001 then
  begin
    CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
    BeforeRotation := Transforms[Wrist].Rotation;
  end;
  Result := MoveLimb(Model, Poses, Arm, Elbow, Wrist, WorldMove, 0.45,
    Bend, False);
  if Result and (Abs(Bend) > 0.000001) then
    RestoreTipRotation(Model, Poses, Wrist, BeforeRotation);
end;

function MoveFoot(const Model: TPmxModel; var Poses: TPmxBonePoses;
  Left: Boolean; const WorldMove: TPmxVector3; Bend: Single): Boolean;
var
  Leg, Knee, Ankle: Integer;
  BeforeRotation: TPmxQuaternion;
  Transforms: TPmxBoneTransforms;
begin
  FootBones(Model, Left, Leg, Knee, Ankle);
  if (Leg < 0) or (Knee < 0) or (Ankle < 0) then Exit(False);
  CalculateInteractiveBoneTransforms(Model, Poses, Transforms);
  BeforeRotation := Transforms[Ankle].Rotation;
  Result := MoveLimb(Model, Poses, Leg, Knee, Ankle, WorldMove, 0.35,
    Bend, True);
  if not Result then Exit;
  // 膝の向きが変わっても、足先は移動前のワールド方向を保つ。
  // 足首位置を変えず、親の回転差だけを足首のローカル回転で打ち消す。
  RestoreTipRotation(Model, Poses, Ankle, BeforeRotation);
end;

end.
