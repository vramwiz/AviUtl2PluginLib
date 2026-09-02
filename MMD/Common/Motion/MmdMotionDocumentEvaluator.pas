unit MmdMotionDocumentEvaluator;

// 編集可能なモーション文書を指定フレームで評価し、モデル非依存の
// 名前付きボーン姿勢とモーフウェイトへ変換する。

interface

uses
  MmdMotionDocument,
  MmdMorphSettingCodec,
  PmxPose;

// VMD Bezier、Quaternion Slerp、線形モーフ補間で現在状態を求める。
function EvaluateMmdMotionDocument(Document: TMmdMotionDocument;
  Frame: Single; out Poses: TPmxNamedBonePoses;
  out Morphs: TMmdNamedMorphWeights): Boolean;

implementation

uses
  System.Math,
  PmxPoseMath;

function BezierValue(const Curve: TMmdBezierCurve; X: Single): Single;
var
  C, F, S, T: Double;
  I: Integer;
  X1, X2, Y1, Y2: Double;
begin
  if X <= 0 then Exit(0);
  if X >= 1 then Exit(1);
  X1 := Curve.X1 / 127.0;
  Y1 := Curve.Y1 / 127.0;
  X2 := Curve.X2 / 127.0;
  Y2 := Curve.Y2 / 127.0;
  C := 0.5;
  T := C;
  for I := 0 to 14 do
  begin
    S := 1.0 - T;
    F := 3.0 * S * S * T * X1 + 3.0 * S * T * T * X2 +
      T * T * T - X;
    if Abs(F) < 0.00001 then Break;
    C := C * 0.5;
    if F < 0 then T := T + C else T := T - C;
  end;
  S := 1.0 - T;
  Result := 3.0 * S * S * T * Y1 + 3.0 * S * T * T * Y2 +
    T * T * T;
end;

function SlerpQuaternion(const A, B: TPmxQuaternion;
  Amount: Single): TPmxQuaternion;
var
  Angle, Dot, ScaleA, ScaleB, SinAngle: Single;
  EndValue: TPmxQuaternion;
begin
  EndValue := B;
  Dot := A.X * B.X + A.Y * B.Y + A.Z * B.Z + A.W * B.W;
  if Dot < 0 then
  begin
    Dot := -Dot;
    EndValue.X := -EndValue.X;
    EndValue.Y := -EndValue.Y;
    EndValue.Z := -EndValue.Z;
    EndValue.W := -EndValue.W;
  end;
  Dot := EnsureRange(Dot, -1.0, 1.0);
  if Dot > 0.9995 then
  begin
    Result.X := A.X + (EndValue.X - A.X) * Amount;
    Result.Y := A.Y + (EndValue.Y - A.Y) * Amount;
    Result.Z := A.Z + (EndValue.Z - A.Z) * Amount;
    Result.W := A.W + (EndValue.W - A.W) * Amount;
    Exit(NormalizeQuaternion(Result));
  end;
  Angle := ArcCos(Dot);
  SinAngle := Sin(Angle);
  ScaleA := Sin((1 - Amount) * Angle) / SinAngle;
  ScaleB := Sin(Amount * Angle) / SinAngle;
  Result.X := A.X * ScaleA + EndValue.X * ScaleB;
  Result.Y := A.Y * ScaleA + EndValue.Y * ScaleB;
  Result.Z := A.Z * ScaleA + EndValue.Z * ScaleB;
  Result.W := A.W * ScaleA + EndValue.W * ScaleB;
  Result := NormalizeQuaternion(Result);
end;

function EvaluateBone(Track: TMmdMotionBoneTrack;
  Frame: Single): TPmxBonePose;
var
  Amount, RotationAmount: Single;
  HighIndex, LowIndex, Mid: Integer;
  LeftKey, RightKey: TMmdMotionBoneKey;
begin
  if (Track.Keys.Count = 1) or (Frame <= Track.Keys[0].Frame) then
  begin
    Result.Translation := Track.Keys[0].Translation;
    Result.Rotation := Track.Keys[0].Rotation;
    Exit;
  end;
  HighIndex := Track.Keys.Count - 1;
  if Frame >= Track.Keys[HighIndex].Frame then
  begin
    Result.Translation := Track.Keys[HighIndex].Translation;
    Result.Rotation := Track.Keys[HighIndex].Rotation;
    Exit;
  end;
  LowIndex := 0;
  while HighIndex - LowIndex > 1 do
  begin
    Mid := (LowIndex + HighIndex) div 2;
    if Track.Keys[Mid].Frame <= Frame then LowIndex := Mid
    else HighIndex := Mid;
  end;
  LeftKey := Track.Keys[LowIndex];
  RightKey := Track.Keys[HighIndex];
  if RightKey.Frame <= LeftKey.Frame then
  begin
    Result.Translation := RightKey.Translation;
    Result.Rotation := RightKey.Rotation;
    Exit;
  end;
  Amount := (Frame - LeftKey.Frame) / (RightKey.Frame - LeftKey.Frame);
  Result.Translation.X := LeftKey.Translation.X +
    (RightKey.Translation.X - LeftKey.Translation.X) *
    BezierValue(RightKey.TranslationXCurve, Amount);
  Result.Translation.Y := LeftKey.Translation.Y +
    (RightKey.Translation.Y - LeftKey.Translation.Y) *
    BezierValue(RightKey.TranslationYCurve, Amount);
  Result.Translation.Z := LeftKey.Translation.Z +
    (RightKey.Translation.Z - LeftKey.Translation.Z) *
    BezierValue(RightKey.TranslationZCurve, Amount);
  RotationAmount := BezierValue(RightKey.RotationCurve, Amount);
  Result.Rotation := SlerpQuaternion(LeftKey.Rotation,
    RightKey.Rotation, RotationAmount);
end;

function EvaluateMorph(Track: TMmdMotionMorphTrack; Frame: Single): Single;
var
  Amount: Single;
  HighIndex, LowIndex, Mid: Integer;
  LeftKey, RightKey: TMmdMotionMorphKey;
begin
  if (Track.Keys.Count = 1) or (Frame <= Track.Keys[0].Frame) then
    Exit(Track.Keys[0].Weight);
  HighIndex := Track.Keys.Count - 1;
  if Frame >= Track.Keys[HighIndex].Frame then
    Exit(Track.Keys[HighIndex].Weight);
  LowIndex := 0;
  while HighIndex - LowIndex > 1 do
  begin
    Mid := (LowIndex + HighIndex) div 2;
    if Track.Keys[Mid].Frame <= Frame then LowIndex := Mid
    else HighIndex := Mid;
  end;
  LeftKey := Track.Keys[LowIndex];
  RightKey := Track.Keys[HighIndex];
  if RightKey.Frame <= LeftKey.Frame then Exit(RightKey.Weight);
  Amount := (Frame - LeftKey.Frame) / (RightKey.Frame - LeftKey.Frame);
  Result := LeftKey.Weight + (RightKey.Weight - LeftKey.Weight) * Amount;
end;

function EvaluateMmdMotionDocument(Document: TMmdMotionDocument;
  Frame: Single; out Poses: TPmxNamedBonePoses;
  out Morphs: TMmdNamedMorphWeights): Boolean;
var
  I: Integer;
begin
  Poses := nil;
  Morphs := nil;
  Result := Assigned(Document) and
    ((Document.BoneTracks.Count > 0) or (Document.MorphTracks.Count > 0));
  if not Result then Exit;
  Frame := EnsureRange(Frame, 0.0, Single(Document.MaxFrame));
  SetLength(Poses, Document.BoneTracks.Count);
  for I := 0 to Document.BoneTracks.Count - 1 do
  begin
    Poses[I].BoneName := Document.BoneTracks[I].Name;
    Poses[I].Pose := EvaluateBone(Document.BoneTracks[I], Frame);
  end;
  SetLength(Morphs, Document.MorphTracks.Count);
  for I := 0 to Document.MorphTracks.Count - 1 do
  begin
    Morphs[I].Name := Document.MorphTracks[I].Name;
    Morphs[I].Weight := EvaluateMorph(Document.MorphTracks[I], Frame);
  end;
end;

end.
