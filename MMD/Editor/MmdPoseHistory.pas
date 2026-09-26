unit MmdPoseHistory;

// ポーズ編集GUIのUndo / Redo用に、姿勢全体の独立したスナップショットを保持する。

interface

uses
  PmxPose;

type
  TMmdPoseSnapshot = record
    Poses: TPmxBonePoses;
    RootRotation: TPmxQuaternion;
    RelativeYaw, RelativePitch: Single;
  end;
  TMmdPoseStacks = array of TMmdPoseSnapshot;

  TMmdPoseHistory = class
  private
    FRedo: TMmdPoseStacks;
    FUndo: TMmdPoseStacks;
    procedure Push(var Stack: TMmdPoseStacks; const Poses: TPmxBonePoses;
      const RootRotation: TPmxQuaternion; RelativeYaw,
      RelativePitch: Single);
  public
    // 編集直前の姿勢をUndoへ追加し、新しい編集系列としてRedoを破棄する。
    procedure RecordBeforeEdit(const Poses: TPmxBonePoses); overload;
    // 全身回転を含む姿勢を一件として記録する。
    procedure RecordBeforeEdit(const Poses: TPmxBonePoses;
      const RootRotation: TPmxQuaternion); overload;
    // 相対アングルも含む姿勢を記録する。
    procedure RecordBeforeEdit(const Poses: TPmxBonePoses;
      const RootRotation: TPmxQuaternion; RelativeYaw,
      RelativePitch: Single); overload;
    // 現在姿勢をRedoへ保存して直前姿勢を返す。履歴がなければFalseを返す。
    function Undo(const Current: TPmxBonePoses;
      out Restored: TPmxBonePoses): Boolean; overload;
    // 全身回転も復元する。
    function Undo(const Current: TPmxBonePoses;
      const CurrentRoot: TPmxQuaternion; out Restored: TPmxBonePoses;
      out RestoredRoot: TPmxQuaternion): Boolean; overload;
    function Undo(const Current: TPmxBonePoses;
      const CurrentRoot: TPmxQuaternion; CurrentYaw,
      CurrentPitch: Single; out Restored: TPmxBonePoses;
      out RestoredRoot: TPmxQuaternion; out RestoredYaw,
      RestoredPitch: Single): Boolean; overload;
    // 現在姿勢をUndoへ保存してやり直し姿勢を返す。履歴がなければFalseを返す。
    function Redo(const Current: TPmxBonePoses;
      out Restored: TPmxBonePoses): Boolean; overload;
    // 全身回転もやり直す。
    function Redo(const Current: TPmxBonePoses;
      const CurrentRoot: TPmxQuaternion; out Restored: TPmxBonePoses;
      out RestoredRoot: TPmxQuaternion): Boolean; overload;
    function Redo(const Current: TPmxBonePoses;
      const CurrentRoot: TPmxQuaternion; CurrentYaw,
      CurrentPitch: Single; out Restored: TPmxBonePoses;
      out RestoredRoot: TPmxQuaternion; out RestoredYaw,
      RestoredPitch: Single): Boolean; overload;
    // Undo可能な姿勢スナップショットがあるかを返す。
    function CanUndo: Boolean;
    // Redo可能な姿勢スナップショットがあるかを返す。
    function CanRedo: Boolean;
  end;

implementation

const
  MAX_HISTORY_COUNT = 100;

procedure TMmdPoseHistory.Push(var Stack: TMmdPoseStacks;
  const Poses: TPmxBonePoses; const RootRotation: TPmxQuaternion;
  RelativeYaw, RelativePitch: Single);
var
  Index: Integer;
begin
  if Length(Stack) >= MAX_HISTORY_COUNT then
  begin
    for Index := 1 to High(Stack) do
      Stack[Index - 1] := Stack[Index];
    SetLength(Stack, MAX_HISTORY_COUNT - 1);
  end;
  SetLength(Stack, Length(Stack) + 1);
  Stack[High(Stack)].Poses := Copy(Poses);
  Stack[High(Stack)].RootRotation := RootRotation;
  Stack[High(Stack)].RelativeYaw := RelativeYaw;
  Stack[High(Stack)].RelativePitch := RelativePitch;
end;

procedure TMmdPoseHistory.RecordBeforeEdit(const Poses: TPmxBonePoses);
begin
  RecordBeforeEdit(Poses, IdentityQuaternion);
end;

procedure TMmdPoseHistory.RecordBeforeEdit(const Poses: TPmxBonePoses;
  const RootRotation: TPmxQuaternion);
begin
  RecordBeforeEdit(Poses, RootRotation, 0, 0);
end;

procedure TMmdPoseHistory.RecordBeforeEdit(const Poses: TPmxBonePoses;
  const RootRotation: TPmxQuaternion; RelativeYaw,
  RelativePitch: Single);
begin
  Push(FUndo, Poses, RootRotation, RelativeYaw, RelativePitch);
  SetLength(FRedo, 0);
end;

function TMmdPoseHistory.Undo(const Current: TPmxBonePoses;
  out Restored: TPmxBonePoses): Boolean;
var
  RestoredRoot: TPmxQuaternion;
begin
  Result := Undo(Current, IdentityQuaternion, Restored, RestoredRoot);
end;

function TMmdPoseHistory.Undo(const Current: TPmxBonePoses;
  const CurrentRoot: TPmxQuaternion; out Restored: TPmxBonePoses;
  out RestoredRoot: TPmxQuaternion): Boolean;
var
  RestoredYaw, RestoredPitch: Single;
begin
  Result := Undo(Current, CurrentRoot, 0, 0, Restored,
    RestoredRoot, RestoredYaw, RestoredPitch);
end;

function TMmdPoseHistory.Undo(const Current: TPmxBonePoses;
  const CurrentRoot: TPmxQuaternion; CurrentYaw,
  CurrentPitch: Single; out Restored: TPmxBonePoses;
  out RestoredRoot: TPmxQuaternion; out RestoredYaw,
  RestoredPitch: Single): Boolean;
begin
  Result := Length(FUndo) > 0;
  if not Result then
    Exit;
  Push(FRedo, Current, CurrentRoot, CurrentYaw, CurrentPitch);
  Restored := Copy(FUndo[High(FUndo)].Poses);
  RestoredRoot := FUndo[High(FUndo)].RootRotation;
  RestoredYaw := FUndo[High(FUndo)].RelativeYaw;
  RestoredPitch := FUndo[High(FUndo)].RelativePitch;
  SetLength(FUndo, Length(FUndo) - 1);
end;

function TMmdPoseHistory.Redo(const Current: TPmxBonePoses;
  out Restored: TPmxBonePoses): Boolean;
var
  RestoredRoot: TPmxQuaternion;
begin
  Result := Redo(Current, IdentityQuaternion, Restored, RestoredRoot);
end;

function TMmdPoseHistory.Redo(const Current: TPmxBonePoses;
  const CurrentRoot: TPmxQuaternion; out Restored: TPmxBonePoses;
  out RestoredRoot: TPmxQuaternion): Boolean;
var
  RestoredYaw, RestoredPitch: Single;
begin
  Result := Redo(Current, CurrentRoot, 0, 0, Restored,
    RestoredRoot, RestoredYaw, RestoredPitch);
end;

function TMmdPoseHistory.Redo(const Current: TPmxBonePoses;
  const CurrentRoot: TPmxQuaternion; CurrentYaw,
  CurrentPitch: Single; out Restored: TPmxBonePoses;
  out RestoredRoot: TPmxQuaternion; out RestoredYaw,
  RestoredPitch: Single): Boolean;
begin
  Result := Length(FRedo) > 0;
  if not Result then
    Exit;
  Push(FUndo, Current, CurrentRoot, CurrentYaw, CurrentPitch);
  Restored := Copy(FRedo[High(FRedo)].Poses);
  RestoredRoot := FRedo[High(FRedo)].RootRotation;
  RestoredYaw := FRedo[High(FRedo)].RelativeYaw;
  RestoredPitch := FRedo[High(FRedo)].RelativePitch;
  SetLength(FRedo, Length(FRedo) - 1);
end;

function TMmdPoseHistory.CanUndo: Boolean;
begin
  Result := Length(FUndo) > 0;
end;

function TMmdPoseHistory.CanRedo: Boolean;
begin
  Result := Length(FRedo) > 0;
end;

end.
