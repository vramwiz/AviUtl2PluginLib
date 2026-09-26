unit MmdSimpleControllerSolver;

// 九つの操作対象への入力を振り分け、編集開始姿勢からPMX姿勢差分を作る。

interface

uses
  PmxModel,
  PmxPose;

type
  TMmdSimpleController = (scHead, scEyes, scUpperBody, scWaist, scLeftHand,
    scRightHand, scLeftFoot, scRightFoot, scCenter);

// 対象に必要なボーンと親子関係がモデルにあるか返す。モデルは変更しない。
function CanUseSimpleController(const Model: TPmxModel;
  Controller: TMmdSimpleController): Boolean;
// 選択マークの位置に使う代表ボーンを返す。操作不能なら-1。
function SimpleControllerTargetBone(const Model: TPmxModel;
  Controller: TMmdSimpleController): Integer;
// -1～1の画面ドラッグ量から新しい姿勢を返す。手足は二節IKで解き、BasePosesは変更しない。
function ApplySimpleController(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  DragX, DragY, CameraYaw, CameraPitch: Single;
  out NewPoses: TPmxBonePoses): Boolean;
// 画面ドラッグに奥行き入力を加えて新しい姿勢を返す。BasePosesは変更しない。
function ApplySimpleController3D(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  DragX, DragY, DragZ, CameraYaw, CameraPitch: Single;
  out NewPoses: TPmxBonePoses): Boolean;
// 軸回転を画面ドラッグと同じ編集開始姿勢へ合成し、新しい姿勢を返す。
function ApplySimpleController3DWithTwist(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  DragX, DragY, DragZ, DragTwist, CameraYaw, CameraPitch: Single;
  out NewPoses: TPmxBonePoses): Boolean;
// 入力時点の視点で増分をワールド方向へ加算する。視線だけは顔の軸を使う。
procedure AccumulateSimpleControllerViewInput(
  Controller: TMmdSimpleController; DeltaX, DeltaY, DeltaZ,
  CameraYaw, CameraPitch: Single; var WorldMove,
  WorldTurn: TPmxVector3);
// 蓄積済みワールド入力をBasePosesへ適用する。視点変更では姿勢が跳ねない。
function ApplySimpleControllerWorldWithTwist(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  const WorldMove, WorldTurn: TPmxVector3; DragTwist: Single;
  out NewPoses: TPmxBonePoses): Boolean;
// 手首・足首位置を保って肘・膝の曲げ方向を調整し、新しい姿勢を返す。
function ApplySimpleControllerWorldWithTwistAndBend(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  const WorldMove, WorldTurn: TPmxVector3; DragTwist, DragBend: Single;
  out NewPoses: TPmxBonePoses): Boolean;
// 手先・足先の視点基準回転を加える。手首・足首位置は変えず、新しい姿勢を返す。
function ApplySimpleControllerWorldWithExtras(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  const WorldMove, WorldTurn: TPmxVector3;
  DragTwist, DragBend, DragTipPitch, CameraYaw, CameraPitch: Single;
  out NewPoses: TPmxBonePoses): Boolean; overload;
// 全身回転後の表示方向を局所姿勢へ戻して手足先の向きを計算する。
function ApplySimpleControllerWorldWithExtras(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  const WorldMove, WorldTurn: TPmxVector3;
  DragTwist, DragBend, DragTipPitch, CameraYaw, CameraPitch: Single;
  const RootRotation: TPmxQuaternion;
  out NewPoses: TPmxBonePoses): Boolean; overload;
// 十字キー右で肘・膝が画面右へ動く符号を返す。姿勢は変更しない。
function SimpleControllerBendViewSign(const Model: TPmxModel;
  const Poses: TPmxBonePoses; Controller: TMmdSimpleController;
  CameraYaw, CameraPitch: Single): Single; overload;
// 全身回転後の画面右を基準に曲げ方向の符号を返す。
function SimpleControllerBendViewSign(const Model: TPmxModel;
  const Poses: TPmxBonePoses; Controller: TMmdSimpleController;
  CameraYaw, CameraPitch: Single;
  const RootRotation: TPmxQuaternion): Single; overload;
// 指定対象だけを初期姿勢へ戻した配列を返す。BasePosesは変更しない。
function ResetSimpleController(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  out NewPoses: TPmxBonePoses): Boolean;

implementation

uses
  System.Math,
  MmdSimpleControllerBones,
  MmdSimpleControllerEyes,
  MmdSimpleControllerLimbIK,
  MmdSimpleControllerTip,
  MmdSimpleControllerView,
  PmxPoseMath;

function CanUseSimpleController(const Model: TPmxModel;
  Controller: TMmdSimpleController): Boolean;
var
  Arm, Elbow, Wrist: Integer;
begin
  Result := False;
  if Model = nil then Exit;
  case Controller of
    scHead: Result := HeadBone(Model) >= 0;
    scEyes: Result := CanUseEyeGaze(Model);
    scUpperBody: Result := UpperBone(Model) >= 0;
    scWaist: Result := WaistBone(Model) >= 0;
    scCenter: Result := CenterBone(Model) >= 0;
    scLeftHand, scRightHand:
      begin
        HandBones(Model, Controller = scLeftHand, Arm, Elbow, Wrist);
        Result := (Arm >= 0) and (Elbow >= 0) and (Wrist >= 0) and
          IsAncestor(Model, Arm, Elbow) and IsAncestor(Model, Elbow, Wrist);
      end;
    scLeftFoot, scRightFoot:
      begin
        FootBones(Model, Controller = scLeftFoot, Arm, Elbow, Wrist);
        Result := (Arm >= 0) and (Elbow >= 0) and (Wrist >= 0) and
          IsAncestor(Model, Arm, Elbow) and IsAncestor(Model, Elbow, Wrist);
      end;
  end;
end;

function SimpleControllerTargetBone(const Model: TPmxModel;
  Controller: TMmdSimpleController): Integer;
var
  Root, Joint: Integer;
begin
  Result := -1;
  if not CanUseSimpleController(Model, Controller) then Exit;
  case Controller of
    scHead: Result := HeadBone(Model);
    scEyes: Result := EyeGazeTargetBone(Model);
    scUpperBody: Result := UpperBone(Model);
    scWaist: Result := WaistBone(Model);
    scCenter: Result := CenterBone(Model);
    scLeftHand, scRightHand:
      HandBones(Model, Controller = scLeftHand, Root, Joint, Result);
    scLeftFoot, scRightFoot:
      FootBones(Model, Controller = scLeftFoot, Root, Joint, Result);
  end;
end;

function SimpleControllerBendViewSign(const Model: TPmxModel;
  const Poses: TPmxBonePoses; Controller: TMmdSimpleController;
  CameraYaw, CameraPitch: Single): Single;
begin
  Result := SimpleControllerBendViewSign(Model, Poses, Controller,
    CameraYaw, CameraPitch, IdentityQuaternion);
end;

function SimpleControllerBendViewSign(const Model: TPmxModel;
  const Poses: TPmxBonePoses; Controller: TMmdSimpleController;
  CameraYaw, CameraPitch: Single;
  const RootRotation: TPmxQuaternion): Single;
var
  Root, Joint, Tip: Integer;
begin
  Result := 1;
  if (Model = nil) or (Length(Poses) <> Length(Model.Bones)) then Exit;
  case Controller of
    scLeftHand, scRightHand:
      HandBones(Model, Controller = scLeftHand, Root, Joint, Tip);
    scLeftFoot, scRightFoot:
      FootBones(Model, Controller = scLeftFoot, Root, Joint, Tip);
  else
    Exit;
  end;
  Result := BendViewSign(Model, Poses, Root, Joint, Tip,
    CameraYaw, CameraPitch, RootRotation);
end;

function ApplySimpleController(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  DragX, DragY, CameraYaw, CameraPitch: Single;
  out NewPoses: TPmxBonePoses): Boolean;
begin
  Result := ApplySimpleController3D(Model, BasePoses, Controller,
    DragX, DragY, 0, CameraYaw, CameraPitch, NewPoses);
end;

function ApplySimpleController3D(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  DragX, DragY, DragZ, CameraYaw, CameraPitch: Single;
  out NewPoses: TPmxBonePoses): Boolean;
begin
  Result := ApplySimpleController3DWithTwist(Model, BasePoses, Controller,
    DragX, DragY, DragZ, 0, CameraYaw, CameraPitch, NewPoses);
end;

function ApplySimpleController3DWithTwist(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  DragX, DragY, DragZ, DragTwist, CameraYaw, CameraPitch: Single;
  out NewPoses: TPmxBonePoses): Boolean;
var
  WorldMove, WorldTurn: TPmxVector3;
begin
  DragX := EnsureRange(DragX, -1.0, 1.0);
  DragY := EnsureRange(DragY, -1.0, 1.0);
  DragZ := EnsureRange(DragZ, -1.0, 1.0);
  WorldMove := Default(TPmxVector3);
  WorldTurn := Default(TPmxVector3);
  AccumulateSimpleControllerViewInput(Controller, DragX, DragY, DragZ,
    CameraYaw, CameraPitch, WorldMove, WorldTurn);
  Result := ApplySimpleControllerWorldWithTwist(Model, BasePoses,
    Controller, WorldMove, WorldTurn, DragTwist, NewPoses);
end;

procedure AccumulateSimpleControllerViewInput(
  Controller: TMmdSimpleController; DeltaX, DeltaY, DeltaZ,
  CameraYaw, CameraPitch: Single; var WorldMove,
  WorldTurn: TPmxVector3);
var
  Right, Up, Depth: TPmxVector3;
begin
  Right := ScreenOffset(1, 0, CameraYaw, CameraPitch, 1);
  Up := ScreenOffset(0, 1, CameraYaw, CameraPitch, 1);
  Depth := DepthOffset(1, CameraYaw, CameraPitch, 1);
  case Controller of
    scEyes:
      begin
        WorldTurn.X := WorldTurn.X + DeltaY * 0.35;
        WorldTurn.Y := WorldTurn.Y - DeltaX * 0.45;
      end;
    scHead:
      begin
        WorldTurn := AddVector(WorldTurn,
          AddVector(ScaleVector(Up, DeltaX * 0.55),
            ScaleVector(Right, -DeltaY * 0.35)));
        WorldMove := AddVector(WorldMove, ScaleVector(Depth, DeltaZ));
      end;
    scUpperBody:
      begin
        WorldTurn := AddVector(WorldTurn,
          AddVector(ScaleVector(Depth, -DeltaX * 0.25),
            ScaleVector(Right, DeltaY * 0.25)));
        WorldMove := AddVector(WorldMove, ScaleVector(Depth, DeltaZ));
      end;
    scWaist:
      begin
        // 胴体のひねりはカメラ傾斜に引かれず、人物の鉛直軸を使う。
        WorldTurn.Y := WorldTurn.Y + DeltaX * 0.35;
        WorldTurn := AddVector(WorldTurn,
          ScaleVector(Right, DeltaY * 0.25));
        WorldMove := AddVector(WorldMove, ScaleVector(Depth, DeltaZ));
      end;
  else
    WorldMove := AddVector(WorldMove,
      AddVector(AddVector(ScaleVector(Right, DeltaX),
        ScaleVector(Up, DeltaY)), ScaleVector(Depth, DeltaZ)));
  end;
end;

function ApplySimpleControllerWorldWithTwist(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  const WorldMove, WorldTurn: TPmxVector3; DragTwist: Single;
  out NewPoses: TPmxBonePoses): Boolean;
begin
  Result := ApplySimpleControllerWorldWithTwistAndBend(Model, BasePoses,
    Controller, WorldMove, WorldTurn, DragTwist, 0, NewPoses);
end;

function ApplySimpleControllerWorldWithTwistAndBend(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  const WorldMove, WorldTurn: TPmxVector3; DragTwist, DragBend: Single;
  out NewPoses: TPmxBonePoses): Boolean;
begin
  Result := ApplySimpleControllerWorldWithExtras(Model, BasePoses,
    Controller, WorldMove, WorldTurn, DragTwist, DragBend, 0,
    0, 0, NewPoses);
end;

function ApplySimpleControllerWorldWithExtras(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  const WorldMove, WorldTurn: TPmxVector3;
  DragTwist, DragBend, DragTipPitch, CameraYaw, CameraPitch: Single;
  out NewPoses: TPmxBonePoses): Boolean;
begin
  Result := ApplySimpleControllerWorldWithExtras(Model, BasePoses,
    Controller, WorldMove, WorldTurn, DragTwist, DragBend, DragTipPitch,
    CameraYaw, CameraPitch, IdentityQuaternion, NewPoses);
end;

function ApplySimpleControllerWorldWithExtras(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  const WorldMove, WorldTurn: TPmxVector3;
  DragTwist, DragBend, DragTipPitch, CameraYaw, CameraPitch: Single;
  const RootRotation: TPmxQuaternion;
  out NewPoses: TPmxBonePoses): Boolean;
var
  Bone, Center, Head, Parent: Integer;
  Height: Single;
  TwistAxis: TPmxVector3;
begin
  NewPoses := nil;
  Result := (Model <> nil) and
    (Length(BasePoses) = Length(Model.Bones)) and
    CanUseSimpleController(Model, Controller);
  if not Result then Exit;
  NewPoses := Copy(BasePoses);
  DragTwist := EnsureRange(DragTwist, -1.0, 1.0);
  DragBend := EnsureRange(DragBend, -1.0, 1.0);
  DragTipPitch := EnsureRange(DragTipPitch, -1.0, 1.0);
  if (VectorLength(WorldMove) < 0.000001) and
    (VectorLength(WorldTurn) < 0.000001) and
    (Abs(DragTwist) < 0.000001) and
    (Abs(DragBend) < 0.000001) and
    (Abs(DragTipPitch) < 0.000001) then Exit;
  TwistAxis := Default(TPmxVector3);
  case Controller of
    scEyes: Result := ApplyEyeGaze(Model, BasePoses, NewPoses, WorldTurn);
    scHead:
      begin
        Bone := HeadBone(Model);
        Parent := Model.Bones[Bone].ParentIndex;
        Height := 1.0;
        if Parent >= 0 then
          Height := Max(VectorLength(SubtractVector(
            Model.Bones[Bone].Position,
            Model.Bones[Parent].Position)), 0.1);
        TwistAxis.Z := 1;
        ApplyWorldBoneTransform(Model, BasePoses, NewPoses, Bone,
          WorldMove, WorldTurn, TwistAxis, Height * 0.45, DragTwist);
      end;
    scUpperBody:
      begin
        Bone := UpperBone(Model);
        Center := CenterBone(Model);
        Head := HeadBone(Model);
        Height := 10.0;
        if (Center >= 0) and (Head >= 0) then
          Height := Max(Abs(Model.Bones[Head].Position.Y -
            Model.Bones[Center].Position.Y) * 2.0, 0.1);
        TwistAxis.Y := 1;
        ApplyWorldBoneTransform(Model, BasePoses, NewPoses, Bone,
          WorldMove, WorldTurn, TwistAxis, Height * 0.08, DragTwist);
      end;
    scWaist:
      begin
        Bone := WaistBone(Model);
        Center := CenterBone(Model);
        Head := HeadBone(Model);
        Height := 10.0;
        if (Center >= 0) and (Head >= 0) then
          Height := Max(Abs(Model.Bones[Head].Position.Y -
            Model.Bones[Center].Position.Y) * 2.0, 0.1);
        TwistAxis.Y := 1;
        ApplyWorldBoneTransform(Model, BasePoses, NewPoses, Bone,
          WorldMove, WorldTurn, TwistAxis, Height * 0.08, DragTwist);
      end;
    scLeftHand, scRightHand:
      begin
        if (VectorLength(WorldMove) > 0.000001) or
          (Abs(DragBend) > 0.000001) then
          Result := MoveHand(Model, NewPoses, Controller = scLeftHand,
            WorldMove, DragBend);
        if Result then
          Result := TwistHand(Model, NewPoses, Controller = scLeftHand,
            DragTwist);
        if Result then
          Result := PitchHand(Model, NewPoses, Controller = scLeftHand,
            DragTipPitch, CameraYaw, CameraPitch, RootRotation);
      end;
    scLeftFoot, scRightFoot:
      begin
        if (VectorLength(WorldMove) > 0.000001) or
          (Abs(DragBend) > 0.000001) then
          Result := MoveFoot(Model, NewPoses, Controller = scLeftFoot,
            WorldMove, DragBend);
        if Result then
          Result := TwistFoot(Model, NewPoses, Controller = scLeftFoot,
            DragTwist);
        if Result then
          Result := PitchFoot(Model, NewPoses, Controller = scLeftFoot,
            DragTipPitch, CameraYaw, CameraPitch, RootRotation);
      end;
    scCenter:
      begin
        Bone := CenterBone(Model);
        Center := Bone;
        Head := HeadBone(Model);
        Height := 10.0;
        if Head >= 0 then
          Height := Max(Abs(Model.Bones[Head].Position.Y -
            Model.Bones[Center].Position.Y) * 2.0, 0.1);
        TwistAxis.Y := 1;
        ApplyWorldBoneTransform(Model, BasePoses, NewPoses, Bone,
          WorldMove, WorldTurn, TwistAxis, Height * 0.12, DragTwist);
      end;
  end;
end;

function ResetSimpleController(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController;
  out NewPoses: TPmxBonePoses): Boolean;
var
  Arm, Elbow, Wrist: Integer;

  procedure ResetBone(Index: Integer);
  begin
    if Index < 0 then Exit;
    NewPoses[Index] := Default(TPmxBonePose);
    NewPoses[Index].Rotation := IdentityQuaternion;
  end;
begin
  NewPoses := nil;
  Result := (Model <> nil) and
    (Length(BasePoses) = Length(Model.Bones)) and
    CanUseSimpleController(Model, Controller);
  if not Result then Exit;
  NewPoses := Copy(BasePoses);
  case Controller of
    scHead: ResetBone(HeadBone(Model));
    scEyes: Result := ResetEyeGaze(Model, NewPoses);
    scUpperBody: ResetBone(UpperBone(Model));
    scWaist: ResetBone(WaistBone(Model));
    scCenter: ResetBone(CenterBone(Model));
    scLeftHand, scRightHand:
      begin
        HandBones(Model, Controller = scLeftHand, Arm, Elbow, Wrist);
        ResetBone(Arm);
        ResetBone(Elbow);
        ResetBone(Wrist);
      end;
    scLeftFoot, scRightFoot:
      begin
        FootBones(Model, Controller = scLeftFoot, Arm, Elbow, Wrist);
        ResetBone(Arm);
        ResetBone(Elbow);
        ResetBone(Wrist);
      end;
  end;
end;

end.
