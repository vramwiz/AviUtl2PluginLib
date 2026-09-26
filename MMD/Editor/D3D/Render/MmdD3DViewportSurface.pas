unit MmdD3DViewportSurface;

// VCL子ウィンドウとD3D Rendererの寿命を同期し、編集入力に依存しない描画面を提供する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  PmxModel,
  PmxMorph,
  PmxPose,
  MmdD3DRenderer,
  MmdD3DScene;

type
  TMmdD3DViewportSurface = class(TCustomControl)
  private
    function GetErrorText: string;
    function GetLoadedTextureCount: Integer;
  protected
    FCamera: TMmdPreviewCamera;
    FHoverTarget: TMmdPreviewTarget;
    FModel: TPmxModel;
    FMorphWeights: TPmxMorphWeights;
    FPoses: TPmxBonePoses;
    FRootRotation: TPmxQuaternion;
    FRenderer: TMmdD3DRenderer;
    FSelectedTarget: TMmdPreviewTarget;
    // モデル本体を含む確定シーンを更新する。カメラ値と初回フレームはRendererが維持する。
    procedure RebuildScene;
    // モデル本体を維持し、同じ最終ボーン計算で骨格オーバーレイだけを更新する。
    procedure RebuildSkeleton;
    // 頂点を再生成せず、カメラ定数だけを更新する。
    procedure UpdateCamera;
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure Paint; override;
    procedure Resize; override;
  public
    // 子ウィンドウ生成前のカメラ、選択値、背景描画属性を初期化する。
    constructor Create(AOwner: TComponent); override;
    // Rendererと子ウィンドウに結び付いたD3D資源を解放する。
    destructor Destroy; override;
    // 保存対象外の確認用モーフ係数を設定し、モデル本体を再構築する。
    procedure SetMorphWeights(const AWeights: TPmxMorphWeights);
    // 保存済み全身回転をモデルと骨格の描画へ反映する。
    procedure SetRootRotation(const Rotation: TPmxQuaternion);
    // 正面の既定表示へ戻す。
    procedure ResetPreviewCamera;
    // 指定ボーンを画面中央へ移し、指定倍率で表示する。
    function FocusPreviewBone(const BoneName: string; Zoom: Single): Boolean;
    // 頭を中央にし、無いモデルでは両目・左右目の中点・首へ退避する。
    function FocusPreviewFace(Zoom: Single): Boolean;
    // 現在の表示寸法とカメラで、骨格を除いたモデル画像を取得する。
    function CaptureModelImage(Bitmap: Vcl.Graphics.TBitmap): Boolean;
    // 確認用途に応じてモデルと骨格オーバーレイの表示を切り替える。
    procedure SetDisplayVisibility(ModelVisible, OverlayVisible: Boolean;
      MarkerOnlyVisible: Boolean = False);
    property Camera: TMmdPreviewCamera read FCamera;
    property ErrorText: string read GetErrorText;
    property LoadedTextureCount: Integer read GetLoadedTextureCount;
  end;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils;

constructor TMmdD3DViewportSurface.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCamera := DefaultPreviewCamera;
  FSelectedTarget := EmptyPreviewTarget;
  FHoverTarget := EmptyPreviewTarget;
  Color := RGB(14, 15, 19);
  ControlStyle := ControlStyle + [csOpaque];
end;

destructor TMmdD3DViewportSurface.Destroy;
begin
  FRenderer.Free;
  inherited Destroy;
end;

procedure TMmdD3DViewportSurface.SetMorphWeights(
  const AWeights: TPmxMorphWeights);
begin
  FMorphWeights := Copy(AWeights);
  RebuildScene;
  // TrackBar操作中もWM_PAINT待ちにせず、変更済みGPUバッファを即時表示する。
  Update;
end;

procedure TMmdD3DViewportSurface.ResetPreviewCamera;
begin
  FCamera := DefaultPreviewCamera;
  FRootRotation := IdentityQuaternion;
  UpdateCamera;
end;

procedure TMmdD3DViewportSurface.SetRootRotation(
  const Rotation: TPmxQuaternion);
begin
  FRootRotation := Rotation;
  RebuildScene;
end;

function TMmdD3DViewportSurface.FocusPreviewBone(const BoneName: string;
  Zoom: Single): Boolean;
var
  Camera: TMmdPreviewCamera;
  Joint: TMmdPreviewJoint;
  Point: TPmxVector3;
  Scene: TMmdPreviewScene;
begin
  Result := False;
  if (FModel = nil) or (ClientWidth <= 0) or (ClientHeight <= 0) then
    Exit;
  BuildPreviewScene(FModel, FPoses, FMorphWeights, EmptyPreviewTarget,
    EmptyPreviewTarget, FRootRotation, Scene);
  Camera := DefaultPreviewCamera;
  for Joint in Scene.Joints do
    if SameText(FModel.Bones[Joint.BoneIndex].Name, BoneName) then
    begin
      Point := ProjectPreviewPosition(Joint.Position, Scene.Projection,
        Camera, ClientWidth, ClientHeight);
      Camera.Zoom := EnsureRange(Zoom, 0.2, 5.0);
      Camera.PanX := -Point.X * Camera.Zoom * ClientWidth * 0.5;
      Camera.PanY := Point.Y * Camera.Zoom * ClientHeight * 0.5;
      FCamera := Camera;
      UpdateCamera;
      Exit(True);
    end;
end;

function TMmdD3DViewportSurface.FocusPreviewFace(Zoom: Single): Boolean;
var
  Camera: TMmdPreviewCamera;
  HasLeftEye, HasRightEye: Boolean;
  Joint: TMmdPreviewJoint;
  LeftEye, Point, RightEye: TPmxVector3;
  Scene: TMmdPreviewScene;

  function IsBone(const Name: string): Boolean;
  begin
    Result := SameText(FModel.Bones[Joint.BoneIndex].Name, Name);
  end;

  procedure ApplyPoint(const Position: TPmxVector3);
  begin
    Camera := DefaultPreviewCamera;
    Point := ProjectPreviewPosition(Position, Scene.Projection, Camera,
      ClientWidth, ClientHeight);
    Camera.Zoom := EnsureRange(Zoom, 0.2, 5.0);
    Camera.PanX := -Point.X * Camera.Zoom * ClientWidth * 0.5;
    Camera.PanY := Point.Y * Camera.Zoom * ClientHeight * 0.5;
    FCamera := Camera;
    UpdateCamera;
  end;

begin
  Result := False;
  if (FModel = nil) or (ClientWidth <= 0) or (ClientHeight <= 0) then Exit;
  BuildPreviewScene(FModel, FPoses, FMorphWeights, EmptyPreviewTarget,
    EmptyPreviewTarget, FRootRotation, Scene);
  HasLeftEye := False;
  HasRightEye := False;
  for Joint in Scene.Joints do
    if IsBone(#$982D) then
    begin
      ApplyPoint(Joint.Position);
      Exit(True);
    end
    else if IsBone(#$4E21#$76EE) then
    begin
      ApplyPoint(Joint.Position);
      Exit(True);
    end
    else if IsBone(#$5DE6#$76EE) then
    begin
      LeftEye := Joint.Position;
      HasLeftEye := True;
    end
    else if IsBone(#$53F3#$76EE) then
    begin
      RightEye := Joint.Position;
      HasRightEye := True;
    end;
  if HasLeftEye and HasRightEye then
  begin
    Point.X := (LeftEye.X + RightEye.X) * 0.5;
    Point.Y := (LeftEye.Y + RightEye.Y) * 0.5;
    Point.Z := (LeftEye.Z + RightEye.Z) * 0.5;
    ApplyPoint(Point);
    Exit(True);
  end;
  Result := FocusPreviewBone(#$9996, Zoom);
end;

function TMmdD3DViewportSurface.CaptureModelImage(
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  Result := (FRenderer <> nil) and FRenderer.CaptureModelImage(Bitmap);
end;

procedure TMmdD3DViewportSurface.SetDisplayVisibility(ModelVisible,
  OverlayVisible, MarkerOnlyVisible: Boolean);
begin
  if FRenderer <> nil then
    FRenderer.SetDisplayVisibility(ModelVisible, OverlayVisible,
      MarkerOnlyVisible);
  Invalidate;
end;

procedure TMmdD3DViewportSurface.CreateWnd;
begin
  inherited CreateWnd;
  FreeAndNil(FRenderer);
  FRenderer := TMmdD3DRenderer.Create(Handle, ClientWidth, ClientHeight);
  RebuildScene;
end;

procedure TMmdD3DViewportSurface.DestroyWnd;
begin
  FreeAndNil(FRenderer);
  inherited DestroyWnd;
end;

procedure TMmdD3DViewportSurface.Resize;
begin
  inherited Resize;
  if FRenderer <> nil then
    FRenderer.Resize(ClientWidth, ClientHeight);
  Invalidate;
end;

procedure TMmdD3DViewportSurface.Paint;
var
  Message_: string;
begin
  if FRenderer <> nil then
  begin
    FRenderer.Render;
    Message_ := FRenderer.ErrorText;
  end
  else
    Message_ := 'Direct3Dを初期化できませんでした。';
  if Message_ <> '' then
  begin
    Canvas.Brush.Color := Color;
    Canvas.FillRect(ClientRect);
    Canvas.Font.Color := clSilver;
    Canvas.TextOut(12, 12, Message_);
  end;
end;

procedure TMmdD3DViewportSurface.RebuildScene;
begin
  if (FRenderer <> nil) and (FModel <> nil) then
  begin
    FRenderer.SetRootRotation(FRootRotation);
    FRenderer.SetScene(FModel, FPoses, FMorphWeights, FSelectedTarget,
      FHoverTarget);
    FRenderer.SetCamera(FCamera);
  end;
  Invalidate;
end;

procedure TMmdD3DViewportSurface.RebuildSkeleton;
begin
  if (FRenderer <> nil) and (FModel <> nil) then
  begin
    FRenderer.SetRootRotation(FRootRotation);
    FRenderer.SetSkeleton(FModel, FPoses, FMorphWeights, FSelectedTarget,
      FHoverTarget);
    FRenderer.SetCamera(FCamera);
  end;
  Invalidate;
end;

procedure TMmdD3DViewportSurface.UpdateCamera;
begin
  if FRenderer <> nil then
    FRenderer.SetCamera(FCamera);
  Invalidate;
end;

function TMmdD3DViewportSurface.GetErrorText: string;
begin
  if FRenderer = nil then
    Result := 'Direct3Dを初期化できませんでした。'
  else
    Result := FRenderer.ErrorText;
end;

function TMmdD3DViewportSurface.GetLoadedTextureCount: Integer;
begin
  if FRenderer = nil then
    Result := 0
  else
    Result := FRenderer.LoadedTextureCount;
end;

end.
