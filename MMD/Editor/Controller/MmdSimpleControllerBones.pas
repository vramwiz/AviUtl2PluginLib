unit MmdSimpleControllerBones;

// 簡易ポーズ操作が使う人体ボーンを名前と親子関係から特定する。

interface

uses
  PmxModel;

// 候補名を優先順に調べ、見つからなければ-1を返す。モデルは変更しない。
function FindNamedBone(const Model: TPmxModel; const Names: array of string): Integer;
// 頭の代表ボーンを返す。見つからなければ-1。
function HeadBone(const Model: TPmxModel): Integer;
// 上半身の代表ボーンを返す。見つからなければ-1。
function UpperBone(const Model: TPmxModel): Integer;
// 腰操作に使う胴体の付け根を返す。見つからなければ-1。
function WaistBone(const Model: TPmxModel): Integer;
// 全身移動に使うセンターボーンを返す。見つからなければ-1。
function CenterBone(const Model: TPmxModel): Integer;
// 指定側の腕・ひじ・手首を返す。個別に見つからないボーンは-1。
procedure HandBones(const Model: TPmxModel; Left: Boolean; out Arm, Elbow, Wrist: Integer);
// 指定側の脚・ひざ・足首を返す。個別に見つからないボーンは-1。
procedure FootBones(const Model: TPmxModel; Left: Boolean; out Leg, Knee, Ankle: Integer);
// 親をたどり、Ancestor自身を含む祖先関係ならTrueを返す。
function IsAncestor(const Model: TPmxModel; Ancestor, Child: Integer): Boolean;


implementation

uses
  PmxPose;

function FindNamedBone(const Model: TPmxModel;
  const Names: array of string): Integer;
var
  Candidate: string;
begin
  Result := -1;
  if Model = nil then Exit;
  for Candidate in Names do
  begin
    Result := FindBoneIndex(Model, Candidate);
    if Result >= 0 then Exit;
  end;
end;

function HeadBone(const Model: TPmxModel): Integer;
begin
  Result := FindNamedBone(Model, ['頭', 'Head', 'head']);
end;

function UpperBone(const Model: TPmxModel): Integer;
begin
  Result := FindNamedBone(Model,
    ['上半身2', '上半身', 'UpperBody2', 'UpperBody']);
end;

function WaistBone(const Model: TPmxModel): Integer;
begin
  // 「腰」ボーンは脚の親になっているモデルもあるため、胴体の付け根を選ぶ。
  Result := FindNamedBone(Model, ['上半身', 'UpperBody', 'upper_body']);
end;

function CenterBone(const Model: TPmxModel): Integer;
begin
  Result := FindNamedBone(Model, ['センター', 'Center', 'center']);
end;

procedure HandBones(const Model: TPmxModel; Left: Boolean;
  out Arm, Elbow, Wrist: Integer);
begin
  if Left then
  begin
    Arm := FindNamedBone(Model, ['左腕', 'LeftArm', 'left_arm']);
    Elbow := FindNamedBone(Model, ['左ひじ', '左肘', 'LeftElbow',
      'left_elbow']);
    Wrist := FindNamedBone(Model, ['左手首', 'LeftWrist', 'left_wrist']);
  end
  else
  begin
    Arm := FindNamedBone(Model, ['右腕', 'RightArm', 'right_arm']);
    Elbow := FindNamedBone(Model, ['右ひじ', '右肘', 'RightElbow',
      'right_elbow']);
    Wrist := FindNamedBone(Model, ['右手首', 'RightWrist', 'right_wrist']);
  end;
end;

procedure FootBones(const Model: TPmxModel; Left: Boolean;
  out Leg, Knee, Ankle: Integer);
begin
  if Left then
  begin
    Leg := FindNamedBone(Model, ['左足', 'LeftLeg', 'left_leg']);
    Knee := FindNamedBone(Model, ['左ひざ', '左膝', 'LeftKnee',
      'left_knee']);
    Ankle := FindNamedBone(Model, ['左足首', 'LeftAnkle', 'left_ankle']);
  end
  else
  begin
    Leg := FindNamedBone(Model, ['右足', 'RightLeg', 'right_leg']);
    Knee := FindNamedBone(Model, ['右ひざ', '右膝', 'RightKnee',
      'right_knee']);
    Ankle := FindNamedBone(Model, ['右足首', 'RightAnkle',
      'right_ankle']);
  end;
end;

function IsAncestor(const Model: TPmxModel; Ancestor, Child: Integer): Boolean;
var
  Steps: Integer;
begin
  Result := False;
  Steps := 0;
  while (Child >= 0) and (Child < Length(Model.Bones)) and
    (Steps < Length(Model.Bones)) do
  begin
    if Child = Ancestor then Exit(True);
    Child := Model.Bones[Child].ParentIndex;
    Inc(Steps);
  end;
end;

end.
