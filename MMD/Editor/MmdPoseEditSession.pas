unit MmdPoseEditSession;

// PMX姿勢の読込、編集履歴、初期化、JSON変換を描画画面から独立して扱う。

interface

uses
  MmdPoseHistory,
  PmxModel,
  PmxPose;

type
  TMmdPoseEditSession = class
  private
    FHistory: TMmdPoseHistory;
    FRootRotation: TPmxQuaternion;
    FHasRootRotation: Boolean;
    FRelativeYaw, FRelativePitch: Single;
    FHasRelativeAngle: Boolean;
    function GetPreviewRotation: TPmxQuaternion;
  public
    constructor Create;
    destructor Destroy; override;
    // 新しい編集対象を読み込み、Undo/Redoを消去する。
    procedure Load(Model: TPmxModel; const PoseData: string;
      out Poses: TPmxBonePoses);
    // 外部姿勢を1件の編集として適用する。無効なJSONでは変更しない。
    function ApplyExternal(Model: TPmxModel; const PoseData: string;
      var Poses: TPmxBonePoses): Boolean;
    procedure ResetBone(Model: TPmxModel; BoneIndex: Integer;
      Symmetric: Boolean; var Poses: TPmxBonePoses);
    procedure ResetBranch(Model: TPmxModel; BoneIndex: Integer;
      Symmetric: Boolean; var Poses: TPmxBonePoses);
    procedure ResetAll(Model: TPmxModel; var Poses: TPmxBonePoses);
    function Undo(var Poses: TPmxBonePoses): Boolean;
    function Redo(var Poses: TPmxBonePoses): Boolean;
    function Encode(Model: TPmxModel; const Poses: TPmxBonePoses): string;
    property History: TMmdPoseHistory read FHistory;
    property RootRotation: TPmxQuaternion read FRootRotation;
    property RelativeYaw: Single read FRelativeYaw;
    property RelativePitch: Single read FRelativePitch;
    property PreviewRotation: TPmxQuaternion read GetPreviewRotation;
  end;

implementation

uses
  System.Math,
  MmdPoseEditOperations,
  MmdPoseSymmetry,
  PmxPoseCodec,
  PmxPoseMath;

function IsIdentity(const Pose: TPmxBonePose): Boolean;
begin
  Result := (Abs(Pose.Translation.X) < 0.000001) and
    (Abs(Pose.Translation.Y) < 0.000001) and
    (Abs(Pose.Translation.Z) < 0.000001) and
    (Abs(Pose.Rotation.X) < 0.000001) and
    (Abs(Pose.Rotation.Y) < 0.000001) and
    (Abs(Pose.Rotation.Z) < 0.000001) and
    (Abs(Abs(Pose.Rotation.W) - 1.0) < 0.000001);
end;

constructor TMmdPoseEditSession.Create;
begin
  inherited Create;
  FHistory := TMmdPoseHistory.Create;
  FRootRotation := IdentityQuaternion;
end;

function TMmdPoseEditSession.GetPreviewRotation: TPmxQuaternion;
begin
  Result := NormalizeQuaternion(MultiplyQuaternion(
    QuaternionFromYawPitchDegrees(FRelativeYaw, FRelativePitch),
    FRootRotation));
end;

destructor TMmdPoseEditSession.Destroy;
begin
  FHistory.Free;
  inherited;
end;

procedure TMmdPoseEditSession.Load(Model: TPmxModel;
  const PoseData: string; out Poses: TPmxBonePoses);
var
  NamedPoses: TPmxNamedBonePoses;
begin
  FHistory.Free;
  FHistory := TMmdPoseHistory.Create;
  Poses := nil;
  FRootRotation := IdentityQuaternion;
  FHasRootRotation := False;
  FRelativeYaw := 0;
  FRelativePitch := 0;
  FHasRelativeAngle := False;
  if Model = nil then Exit;
  InitializeBonePoses(Model, Poses);
  if TryDecodePoseDataWithRootAndAngle(PoseData, NamedPoses,
    FRootRotation, FHasRootRotation, FRelativeYaw, FRelativePitch,
    FHasRelativeAngle) then
    ApplyNamedBonePoses(Model, NamedPoses, Poses);
end;

function TMmdPoseEditSession.ApplyExternal(Model: TPmxModel;
  const PoseData: string; var Poses: TPmxBonePoses): Boolean;
var
  NamedPoses: TPmxNamedBonePoses;
  NewPoses: TPmxBonePoses;
  NewRootRotation: TPmxQuaternion;
  HasRootRotation: Boolean;
  NewYaw, NewPitch: Single;
  HasRelativeAngle: Boolean;
begin
  Result := False;
  if (Model = nil) or not TryDecodePoseDataWithRootAndAngle(PoseData,
    NamedPoses, NewRootRotation, HasRootRotation, NewYaw, NewPitch,
    HasRelativeAngle) then Exit;
  InitializeBonePoses(Model, NewPoses);
  ApplyNamedBonePoses(Model, NamedPoses, NewPoses);
  FHistory.RecordBeforeEdit(Poses, FRootRotation,
    FRelativeYaw, FRelativePitch);
  Poses := NewPoses;
  FRootRotation := NewRootRotation;
  FHasRootRotation := HasRootRotation;
  FRelativeYaw := NewYaw;
  FRelativePitch := NewPitch;
  FHasRelativeAngle := HasRelativeAngle;
  Result := True;
end;

procedure TMmdPoseEditSession.ResetBone(Model: TPmxModel;
  BoneIndex: Integer; Symmetric: Boolean; var Poses: TPmxBonePoses);
var
  MirrorIndex: Integer;
begin
  if (Model = nil) or (BoneIndex < 0) or
    (BoneIndex > High(Model.Bones)) or (BoneIndex > High(Poses)) then Exit;
  FHistory.RecordBeforeEdit(Poses, FRootRotation,
    FRelativeYaw, FRelativePitch);
  Poses[BoneIndex] := Default(TPmxBonePose);
  Poses[BoneIndex].Rotation := IdentityQuaternion;
  if Symmetric then
  begin
    MirrorIndex := FindSymmetricBone(Model, BoneIndex);
    if (MirrorIndex >= 0) and (MirrorIndex <= High(Poses)) then
      Poses[MirrorIndex] := MirrorBonePose(Poses[BoneIndex]);
  end;
end;

procedure TMmdPoseEditSession.ResetBranch(Model: TPmxModel;
  BoneIndex: Integer; Symmetric: Boolean; var Poses: TPmxBonePoses);
var
  MirrorIndex: Integer;
begin
  if (Model = nil) or (BoneIndex < 0) or
    (BoneIndex > High(Model.Bones)) or (BoneIndex > High(Poses)) then Exit;
  FHistory.RecordBeforeEdit(Poses, FRootRotation,
    FRelativeYaw, FRelativePitch);
  ResetBoneBranch(Model, BoneIndex, Poses);
  if Symmetric then
  begin
    MirrorIndex := FindSymmetricBone(Model, BoneIndex);
    if MirrorIndex >= 0 then ResetBoneBranch(Model, MirrorIndex, Poses);
  end;
end;

procedure TMmdPoseEditSession.ResetAll(Model: TPmxModel;
  var Poses: TPmxBonePoses);
begin
  if Model = nil then Exit;
  FHistory.RecordBeforeEdit(Poses, FRootRotation,
    FRelativeYaw, FRelativePitch);
  FHasRootRotation := FHasRootRotation or
    (Abs(FRootRotation.X) + Abs(FRootRotation.Y) +
     Abs(FRootRotation.Z) > 0.000001);
  FRootRotation := IdentityQuaternion;
  FHasRelativeAngle := FHasRelativeAngle or
    (Abs(FRelativeYaw) + Abs(FRelativePitch) > 0.0001);
  FRelativeYaw := 0;
  FRelativePitch := 0;
  InitializeBonePoses(Model, Poses);
end;

function TMmdPoseEditSession.Undo(var Poses: TPmxBonePoses): Boolean;
var
  Restored: TPmxBonePoses;
  RestoredRoot: TPmxQuaternion;
  RestoredYaw, RestoredPitch: Single;
begin
  Result := FHistory.Undo(Poses, FRootRotation, FRelativeYaw,
    FRelativePitch, Restored, RestoredRoot, RestoredYaw, RestoredPitch);
  if Result then
  begin
    Poses := Restored;
    FRootRotation := RestoredRoot;
    FRelativeYaw := RestoredYaw;
    FRelativePitch := RestoredPitch;
  end;
end;

function TMmdPoseEditSession.Redo(var Poses: TPmxBonePoses): Boolean;
var
  Restored: TPmxBonePoses;
  RestoredRoot: TPmxQuaternion;
  RestoredYaw, RestoredPitch: Single;
begin
  Result := FHistory.Redo(Poses, FRootRotation, FRelativeYaw,
    FRelativePitch, Restored, RestoredRoot, RestoredYaw, RestoredPitch);
  if Result then
  begin
    Poses := Restored;
    FRootRotation := RestoredRoot;
    FRelativeYaw := RestoredYaw;
    FRelativePitch := RestoredPitch;
  end;
end;

function TMmdPoseEditSession.Encode(Model: TPmxModel;
  const Poses: TPmxBonePoses): string;
var
  BoneIndex, Count: Integer;
  NamedPoses: TPmxNamedBonePoses;
begin
  Count := 0;
  if Model = nil then Exit('');
  SetLength(NamedPoses, Min(Length(Model.Bones), Length(Poses)));
  for BoneIndex := 0 to High(NamedPoses) do
    if not IsIdentity(Poses[BoneIndex]) then
    begin
      NamedPoses[Count].BoneName := Model.Bones[BoneIndex].Name;
      NamedPoses[Count].Pose := Poses[BoneIndex];
      Inc(Count);
    end;
  SetLength(NamedPoses, Count);
  Result := EncodePoseDataWithRootAndAngle(NamedPoses, FRootRotation,
    FHasRootRotation, FRelativeYaw, FRelativePitch, FHasRelativeAngle);
end;

end.
