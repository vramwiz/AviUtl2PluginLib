unit MmdSimpleControllerEyes;

// 両目の付与ボーンまたは左右の目ボーンを使い、視線を角度制限内で操作する。

interface

uses
  PmxModel,
  PmxPose;

// 視線を動かせる目ボーンがあるか返す。モデルは変更しない。
function CanUseEyeGaze(const Model: TPmxModel): Boolean;
// 選択マークを置く目ボーンを返す。見つからなければ-1。
function EyeGazeTargetBone(const Model: TPmxModel): Integer;
// 顔の左右・上下を基準にした回転増分を角度制限内で合成し、NewPosesだけを変更する。
function ApplyEyeGaze(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; var NewPoses: TPmxBonePoses;
  const WorldTurn: TPmxVector3): Boolean;
// 視線を動かすボーンだけを標準姿勢へ戻す。NewPosesだけを変更する。
function ResetEyeGaze(const Model: TPmxModel;
  var NewPoses: TPmxBonePoses): Boolean;

implementation

uses
  System.Math,
  MmdSimpleControllerBones,
  PmxPoseMath;

procedure FindEyeBones(const Model: TPmxModel;
  out SharedEye, LeftEye, RightEye: Integer);
begin
  SharedEye := FindNamedBone(Model,
    ['両目', 'BothEyes', 'BothEye', 'Eyes', 'eyes']);
  LeftEye := FindNamedBone(Model,
    ['左目', '左眼', 'LeftEye', 'left_eye', 'Eye_L', 'eye_L']);
  RightEye := FindNamedBone(Model,
    ['右目', '右眼', 'RightEye', 'right_eye', 'Eye_R', 'eye_R']);
end;

function SharedDrivesEye(const Model: TPmxModel;
  SharedEye, Eye: Integer): Boolean;
begin
  Result := (Eye < 0) or IsAncestor(Model, SharedEye, Eye) or
    (((Model.Bones[Eye].Flags and PMX_BONE_FLAG_INHERIT_ROTATION) <> 0) and
      (Model.Bones[Eye].InheritParentIndex = SharedEye) and
      (Abs(Model.Bones[Eye].InheritWeight) > 0.000001));
end;

function SharedEyeDriver(const Model: TPmxModel;
  SharedEye, LeftEye, RightEye: Integer): Integer;
begin
  Result := -1;
  if (SharedEye >= 0) and
    SharedDrivesEye(Model, SharedEye, LeftEye) and
    SharedDrivesEye(Model, SharedEye, RightEye) then
    Result := SharedEye;
end;

function CanUseEyeGaze(const Model: TPmxModel): Boolean;
var
  SharedEye, LeftEye, RightEye: Integer;
begin
  FindEyeBones(Model, SharedEye, LeftEye, RightEye);
  Result := (SharedEye >= 0) or (LeftEye >= 0) or (RightEye >= 0);
end;

function EyeGazeTargetBone(const Model: TPmxModel): Integer;
var
  SharedEye, LeftEye, RightEye: Integer;
begin
  FindEyeBones(Model, SharedEye, LeftEye, RightEye);
  Result := LeftEye;
  if Result < 0 then Result := RightEye;
  if Result < 0 then Result := SharedEye;
end;

function ApplyEyeGaze(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; var NewPoses: TPmxBonePoses;
  const WorldTurn: TPmxVector3): Boolean;
var
  SharedEye, LeftEye, RightEye, Driver: Integer;
  Angles: TPmxVector3;

  procedure TurnEye(Bone: Integer);
  begin
    if Bone < 0 then Exit;
    if (Abs(WorldTurn.X) + Abs(WorldTurn.Y)) < 0.000001 then Exit;
    Angles := QuaternionToEulerXYZ(BasePoses[Bone].Rotation);
    Angles.X := EnsureRange(Angles.X + WorldTurn.X, -0.35, 0.35);
    Angles.Y := EnsureRange(Angles.Y + WorldTurn.Y, -0.45, 0.45);
    NewPoses[Bone].Rotation := QuaternionFromEulerXYZ(
      Angles.X, Angles.Y, Angles.Z);
  end;
begin
  Result := (Model <> nil) and
    (Length(BasePoses) = Length(Model.Bones)) and
    (Length(NewPoses) = Length(Model.Bones));
  if not Result then Exit;
  FindEyeBones(Model, SharedEye, LeftEye, RightEye);
  Driver := SharedEyeDriver(Model, SharedEye, LeftEye, RightEye);
  Result := (Driver >= 0) or (LeftEye >= 0) or (RightEye >= 0);
  if not Result then Exit;
  if Driver >= 0 then TurnEye(Driver)
  else
  begin
    TurnEye(LeftEye);
    TurnEye(RightEye);
  end;
end;

function ResetEyeGaze(const Model: TPmxModel;
  var NewPoses: TPmxBonePoses): Boolean;
var
  SharedEye, LeftEye, RightEye, Driver: Integer;

  procedure ResetEye(Bone: Integer);
  begin
    if Bone < 0 then Exit;
    NewPoses[Bone] := Default(TPmxBonePose);
    NewPoses[Bone].Rotation := IdentityQuaternion;
  end;
begin
  Result := (Model <> nil) and (Length(NewPoses) = Length(Model.Bones));
  if not Result then Exit;
  FindEyeBones(Model, SharedEye, LeftEye, RightEye);
  Driver := SharedEyeDriver(Model, SharedEye, LeftEye, RightEye);
  Result := (Driver >= 0) or (LeftEye >= 0) or (RightEye >= 0);
  if Driver >= 0 then ResetEye(Driver)
  else
  begin
    ResetEye(LeftEye);
    ResetEye(RightEye);
  end;
end;

end.
