unit MmdD3DViewport;

// D3D描画面へマウス・キー操作を接続し、選択、カメラ、作業用姿勢を管理する。

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  PmxModel,
  PmxPose,
  MmdD3DReferenceImage,
  MmdD3DViewportInputState,
  MmdD3DScene,
  MmdD3DViewportSurface;

type
  TMmdD3DViewport = class(TMmdD3DViewportSurface)
  private
    FDragDirection: TPmxVector3;
    FDragParentFrameRotation: TPmxQuaternion;
    FDragPoseBone: Integer;
    FDragMirrorBone: Integer;
    FDragProjection: TMmdPreviewProjection;
    FDragStartLocalRotation: TPmxQuaternion;
    FDragging: Boolean;
    FCameraRotating: Boolean;
    FInputState: TMmdD3DViewportInputState;
    FLastMouse: TPoint;
    FReadOnly: Boolean;
    FMouseDown: TPoint;
    FMouseDownTarget: TMmdPreviewTarget;
    FTargetDragging: Boolean;
    FTargetEditStarted: Boolean;
    FSelectedBone: Integer;
    FSymmetricEditing: Boolean;
    FOnBoneSelected: TNotifyEvent;
    FOnPoseChanged: TNotifyEvent;
    FOnPoseEditFinished: TNotifyEvent;
    FOnPoseEditStarted: TNotifyEvent;
    FReferenceImage: TMmdD3DReferenceImage;
    procedure BeginTargetDrag(const Target: TMmdPreviewTarget);
    function GetSelectedBoneLocked: Boolean;
    procedure SelectTarget(const Target: TMmdPreviewTarget);
    procedure ToggleSelectedBoneLock;
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    // 描画面へ編集用カーソル、ヒント、キーフォーカスを追加したControlを生成する。
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // モデルと姿勢の作業用コピーを設定し、GPU頂点を再構築する。
    procedure SetScene(AModel: TPmxModel; const APoses: TPmxBonePoses;
      ASelectedBone: Integer);
    // 編集中の姿勢作業用コピーを呼び出し側へ返す。
    procedure CopyPoses(out APoses: TPmxBonePoses);
    // 貼り付け画像をフォーム内の独立コピーとして保持し、半透明で重ねる。
    procedure SetReferenceImage(Bitmap: Vcl.Graphics.TBitmap);
    // 保持中の参照画像が描画可能な寸法を持つか返す。
    function HasReferenceImage: Boolean;
    // 参照画像を現在のViewportと同じ寸法・投影基準へ変換してコピーする。
    procedure CopyReferenceImageForViewport(Bitmap: Vcl.Graphics.TBitmap);
    // 指定ボーンが入力操作の固定対象か返す。範囲外の番号はFalseとする。
    function IsBoneLocked(BoneIndex: Integer): Boolean;
    property SelectedBoneLocked: Boolean read GetSelectedBoneLocked;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property SelectedBone: Integer read FSelectedBone;
    property SelectedTarget: TMmdPreviewTarget read FSelectedTarget;
    property SymmetricEditing: Boolean read FSymmetricEditing write FSymmetricEditing;
    property OnBoneSelected: TNotifyEvent read FOnBoneSelected write FOnBoneSelected;
    property OnPoseChanged: TNotifyEvent read FOnPoseChanged write FOnPoseChanged;
    property OnPoseEditFinished: TNotifyEvent read FOnPoseEditFinished
      write FOnPoseEditFinished;
    property OnPoseEditStarted: TNotifyEvent read FOnPoseEditStarted
      write FOnPoseEditStarted;
  end;

implementation

uses
  Winapi.Windows,
  System.Math,
  MmdD3DInteraction,
  MmdD3DLiveDragTest,
  MmdPoseSymmetry,
  PmxPoseMath;

constructor TMmdD3DViewport.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FReferenceImage := TMmdD3DReferenceImage.Create;
  FInputState := TMmdD3DViewportInputState.Create;
  FSelectedBone := -1;
  FMouseDownTarget := EmptyPreviewTarget;
  FDragMirrorBone := -1;
  Cursor := crSizeAll;
  Hint := '関節・ボーン左ドラッグ: 回転  /  空白左ドラッグ: プレビュー移動  /  右ドラッグ: カメラ回転';
  Hint := Hint + '  /  操作中X・Y(C)・Z: ローカル軸制限';
  Hint := Hint + '  /  操作中G: 5°スナップ';
  Hint := Hint + '  /  L: 選択ボーン固定';
  ShowHint := True;
  TabStop := True;
end;

procedure TMmdD3DViewport.KeyDown(var Key: Word; Shift: TShiftState);
var
  ApplyView, ToggleLock: Boolean;
  View: TMmdFixedView;
begin
  inherited KeyDown(Key, Shift);
  if not FInputState.KeyDown(Key, FTargetDragging, View, ApplyView,
    ToggleLock) then
    Exit;
  if ToggleLock then
    ToggleSelectedBoneLock
  else if ApplyView then
  begin
    ApplyFixedPreviewView(FCamera, View, FInputState.FixedViewOpposite);
    UpdateCamera;
  end;
  Key := 0;
end;

procedure TMmdD3DViewport.KeyUp(var Key: Word; Shift: TShiftState);
begin
  FInputState.KeyUp(Key);
  inherited KeyUp(Key, Shift);
end;

function TMmdD3DViewport.GetSelectedBoneLocked: Boolean;
begin
  Result := (FSelectedBone >= 0) and
    FInputState.IsBoneLocked(FSelectedBone);
end;

procedure TMmdD3DViewport.ToggleSelectedBoneLock;
begin
  if FReadOnly then
    Exit;
  if FSelectedBone < 0 then
    Exit;
  FSelectedTarget.Locked := FInputState.ToggleBoneLock(FSelectedBone);
  RebuildSkeleton;
end;

procedure TMmdD3DViewport.SelectTarget(const Target: TMmdPreviewTarget);
var
  Selected: TMmdPreviewTarget;
begin
  Selected := Target;
  Selected.Locked := FInputState.IsBoneLocked(Selected.JointIndex);
  if (Selected.Kind = FSelectedTarget.Kind) and
    (Selected.JointIndex = FSelectedTarget.JointIndex) and
    (Selected.BoneIndex = FSelectedTarget.BoneIndex) and
    (Selected.Locked = FSelectedTarget.Locked) then
    Exit;
  FSelectedTarget := Selected;
  FSelectedBone := Selected.JointIndex;
  RebuildSkeleton;
  if Assigned(FOnBoneSelected) then
    FOnBoneSelected(Self);
end;

procedure TMmdD3DViewport.BeginTargetDrag(const Target: TMmdPreviewTarget);
var
  EndJointIndex, GrandParentIndex, PoseBoneIndex: Integer;
  Transforms: TPmxBoneTransforms;
begin
  FTargetDragging := False;
  FTargetEditStarted := False;
  FDragMirrorBone := -1;
  if FReadOnly then
    Exit;
  if (FModel = nil) or (Target.JointIndex < 0) then
    Exit;
  if Target.Kind = ptJoint then
  begin
    EndJointIndex := Target.JointIndex;
    PoseBoneIndex := FModel.Bones[EndJointIndex].ParentIndex;
  end
  else if Target.Kind = ptBone then
  begin
    EndJointIndex := Target.BoneIndex;
    PoseBoneIndex := Target.JointIndex;
  end
  else
    Exit;
  if (PoseBoneIndex < 0) or (EndJointIndex < 0) then
    Exit;
  if FInputState.IsBoneLocked(PoseBoneIndex) then
    Exit;
  if FSymmetricEditing then
  begin
    FDragMirrorBone := FindSymmetricBone(FModel, PoseBoneIndex);
    if FInputState.IsBoneLocked(FDragMirrorBone) then
      FDragMirrorBone := -1;
  end;
  CalculateBoneTransforms(FModel, FPoses, Transforms);
  FDragDirection := SubtractVector(Transforms[EndJointIndex].Position,
    Transforms[PoseBoneIndex].Position);
  if DotVector(FDragDirection, FDragDirection) <= 0.000001 then
    Exit;
  FDragPoseBone := PoseBoneIndex;
  FDragStartLocalRotation := FPoses[PoseBoneIndex].Rotation;
  GrandParentIndex := FModel.Bones[PoseBoneIndex].ParentIndex;
  if GrandParentIndex < 0 then
    FDragParentFrameRotation := IdentityQuaternion
  else
    FDragParentFrameRotation := Transforms[GrandParentIndex].Rotation;
  FDragProjection := FRenderer.Projection;
  FTargetDragging := True;
end;

procedure TMmdD3DViewport.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if CanFocus then
    SetFocus;
  if not (Button in [mbLeft, mbRight]) then
    Exit;
  if FRenderer = nil then
    FMouseDownTarget := EmptyPreviewTarget
  else
    FMouseDownTarget := FRenderer.HitTestTarget(X, Y);
  FDragging := (Button = mbRight) or
    ((Button = mbLeft) and (FMouseDownTarget.Kind = ptNone));
  FCameraRotating := Button = mbRight;
  FMouseDown := Point(X, Y);
  FLastMouse := Point(X, Y);
  FTargetDragging := False;
  if (Button = mbLeft) and
    (FMouseDownTarget.Kind in [ptJoint, ptBone]) then
  begin
    SelectTarget(FMouseDownTarget);
    BeginTargetDrag(FMouseDownTarget);
  end;
  MouseCapture := True;
end;

procedure TMmdD3DViewport.MouseMove(Shift: TShiftState; X, Y: Integer);
const
  ROTATION_PER_PIXEL = 0.01;
var
  ModelDelta: TPmxVector3;
  HoverTarget: TMmdPreviewTarget;
  Rotation: TPmxQuaternion;
begin
  inherited MouseMove(Shift, X, Y);
  if FTargetDragging then
  begin
    if not FTargetEditStarted then
    begin
      FTargetEditStarted := True;
      if Assigned(FOnPoseEditStarted) then
        FOnPoseEditStarted(Self);
    end;
    ModelDelta := PreviewScreenDeltaToModel(X - FMouseDown.X,
      Y - FMouseDown.Y, FDragProjection, FCamera, ClientWidth, ClientHeight);
    Rotation := BoneDragLocalRotationForBone(FModel.Bones[FDragPoseBone],
      FDragDirection, ModelDelta, FDragParentFrameRotation,
      FDragStartLocalRotation, ActivePreviewDragAxis, X - FMouseDown.X);
    if GetKeyState(Ord('G')) < 0 then
      Rotation := SnapLocalRotation(FDragStartLocalRotation, Rotation,
        DegToRad(5));
    FPoses[FDragPoseBone].Rotation := Rotation;
    if FDragMirrorBone >= 0 then
      FPoses[FDragMirrorBone] := MirrorBonePose(FPoses[FDragPoseBone]);
    if TEMPORARY_LIVE_MODEL_DRAG_TEST then
    begin
      RebuildScene;
      Update;
    end
    else
      RebuildSkeleton;
    if Assigned(FOnPoseChanged) then
      FOnPoseChanged(Self);
    Exit;
  end;
  if not FDragging then
  begin
    if FRenderer = nil then
      Exit;
    HoverTarget := FRenderer.HitTestTarget(X, Y);
    if (HoverTarget.Kind <> FHoverTarget.Kind) or
      (HoverTarget.JointIndex <> FHoverTarget.JointIndex) or
      (HoverTarget.BoneIndex <> FHoverTarget.BoneIndex) then
    begin
      FHoverTarget := HoverTarget;
      RebuildSkeleton;
    end;
    Exit;
  end;
  if FCameraRotating then
  begin
    FCamera.Yaw := FCamera.Yaw + (X - FLastMouse.X) * ROTATION_PER_PIXEL;
    FCamera.Pitch := EnsureRange(FCamera.Pitch +
      (Y - FLastMouse.Y) * ROTATION_PER_PIXEL, -Pi * 0.47, Pi * 0.47);
  end
  else
  begin
    FCamera.PanX := FCamera.PanX + X - FLastMouse.X;
    FCamera.PanY := FCamera.PanY + Y - FLastMouse.Y;
  end;
  FLastMouse := Point(X, Y);
  UpdateCamera;
end;

procedure TMmdD3DViewport.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Target: TMmdPreviewTarget;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if not (Button in [mbLeft, mbRight]) then
    Exit;
  FDragging := False;
  MouseCapture := False;
  if FTargetDragging then
  begin
    FTargetDragging := False;
    RebuildScene;
    if FTargetEditStarted and Assigned(FOnPoseEditFinished) then
      FOnPoseEditFinished(Self);
    FTargetEditStarted := False;
    Exit;
  end;
  if Button <> mbLeft then
    Exit;
  if (Abs(X - FMouseDown.X) > 3) or (Abs(Y - FMouseDown.Y) > 3) or
    (FRenderer = nil) then
    Exit;
  Target := FRenderer.HitTestTarget(X, Y);
  SelectTarget(Target);
end;

procedure TMmdD3DViewport.CopyPoses(out APoses: TPmxBonePoses);
begin
  APoses := Copy(FPoses);
end;

destructor TMmdD3DViewport.Destroy;
begin
  FInputState.Free;
  FReferenceImage.Free;
  inherited Destroy;
end;

function TMmdD3DViewport.HasReferenceImage: Boolean;
begin
  Result := FReferenceImage.HasImage;
end;

function TMmdD3DViewport.IsBoneLocked(BoneIndex: Integer): Boolean;
begin
  Result := FInputState.IsBoneLocked(BoneIndex);
end;

procedure TMmdD3DViewport.SetReferenceImage(Bitmap: Vcl.Graphics.TBitmap);
begin
  FReferenceImage.SetImage(Bitmap);
  Invalidate;
end;

procedure TMmdD3DViewport.CopyReferenceImageForViewport(
  Bitmap: Vcl.Graphics.TBitmap);
begin
  FReferenceImage.CopyForViewport(Bitmap, ClientWidth, ClientHeight);
end;

procedure TMmdD3DViewport.Paint;
begin
  inherited Paint;
  FReferenceImage.Draw(Canvas, ClientWidth, ClientHeight);
end;

function TMmdD3DViewport.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  FCamera.Zoom := EnsureRange(FCamera.Zoom * Power(1.1,
    WheelDelta / WHEEL_DELTA), 0.2, 5.0);
  UpdateCamera;
  Result := True;
end;

procedure TMmdD3DViewport.SetScene(AModel: TPmxModel;
  const APoses: TPmxBonePoses; ASelectedBone: Integer);
begin
  if AModel <> FModel then
  begin
    if AModel = nil then
      FInputState.ResetBoneLocks(0)
    else
      FInputState.ResetBoneLocks(Length(AModel.Bones));
  end;
  FModel := AModel;
  FPoses := Copy(APoses);
  if ASelectedBone = FSelectedBone then
  begin
    RebuildScene;
    Exit;
  end;
  FSelectedBone := ASelectedBone;
  FSelectedTarget := EmptyPreviewTarget;
  if ASelectedBone >= 0 then
  begin
    FSelectedTarget.Kind := ptJoint;
    FSelectedTarget.JointIndex := ASelectedBone;
    FSelectedTarget.Locked := GetSelectedBoneLocked;
  end;
  RebuildScene;
end;

end.
