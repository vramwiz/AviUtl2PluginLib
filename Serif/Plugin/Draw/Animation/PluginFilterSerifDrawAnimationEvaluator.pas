unit PluginFilterSerifDrawAnimationEvaluator;

interface

// キャッシュ済み描画へ適用する、時間に依存する変換値だけを計算する。

uses
  PluginFilterSerifDrawAnimationTypes;

function EvaluateSerifDrawActiveAnimation(
  const AParameters: TSerifDrawAnimationParameters;
  const AElapsedSeconds: Double): TSerifDrawAnimationTransform;
function EvaluateSerifDrawAfterAnimation(
  const AParameters: TSerifDrawAnimationParameters;
  const ATotalElapsedSeconds, AAfterElapsedSeconds: Double):
  TSerifDrawAnimationTransform;

implementation

uses
  System.Math,
  PluginFilterSerifDrawEmotionAnimation;

function Clamp01(const AValue: Double): Double;
begin
  Result := EnsureRange(AValue, 0.0, 1.0);
end;

function SmoothStep(const AValue: Double): Double;
var
  P: Double;
begin
  P := Clamp01(AValue);
  Result := P * P * (3.0 - 2.0 * P);
end;

procedure ApplyBeforeAnimation(const AParameters: TSerifDrawAnimationParameters;
  const AElapsedSeconds: Double;
  var ATransform: TSerifDrawAnimationTransform);
var
  Factor: Double;
  P: Double;
  StartOffset: Double;
begin
  case AParameters.BeforeKind of
    SERIF_ANIMATION_BEFORE_FADE:
      ATransform.Alpha := Clamp01(AElapsedSeconds /
        SERIF_BEFORE_FADE_SECONDS);
    SERIF_ANIMATION_BEFORE_SLIDE:
      begin
        P := SmoothStep(AElapsedSeconds / SERIF_BEFORE_SLIDE_SECONDS);
        StartOffset := 48.0 * (1.0 - P);
        case AParameters.BeforeDirection of
          SERIF_ANIMATION_DIRECTION_RIGHT:
            ATransform.OffsetX := ATransform.OffsetX + StartOffset;
          SERIF_ANIMATION_DIRECTION_TOP:
            ATransform.OffsetY := ATransform.OffsetY - StartOffset;
          SERIF_ANIMATION_DIRECTION_BOTTOM:
            ATransform.OffsetY := ATransform.OffsetY + StartOffset;
        else
          ATransform.OffsetX := ATransform.OffsetX - StartOffset;
        end;
        ATransform.Alpha := Clamp01(AElapsedSeconds / 0.08);
      end;
    SERIF_ANIMATION_BEFORE_ZOOM:
      begin
        P := SmoothStep(AElapsedSeconds / SERIF_BEFORE_ZOOM_SECONDS);
        if AParameters.BeforeZoomOrigin = SERIF_ANIMATION_ZOOM_FROM_FRONT then
          Factor := 1.28 - 0.28 * P
        else
          Factor := 0.72 + 0.28 * P;
        ATransform.ScaleX := ATransform.ScaleX * Factor;
        ATransform.ScaleY := ATransform.ScaleY * Factor;
        ATransform.Alpha := Clamp01(AElapsedSeconds / 0.10);
      end;
    SERIF_ANIMATION_BEFORE_POP:
      begin
        P := Clamp01(AElapsedSeconds / SERIF_BEFORE_POP_SECONDS);
        if AParameters.BeforeZoomOrigin = SERIF_ANIMATION_ZOOM_FROM_FRONT then
        begin
          if P < 0.7 then
            Factor := 1.28 + (0.92 - 1.28) * (P / 0.7)
          else
            Factor := 0.92 + 0.08 * ((P - 0.7) / 0.3);
        end
        else if P < 0.7 then
          Factor := 0.72 + (1.08 - 0.72) * (P / 0.7)
        else
          Factor := 1.08 - 0.08 * ((P - 0.7) / 0.3);
        ATransform.ScaleX := ATransform.ScaleX * Factor;
        ATransform.ScaleY := ATransform.ScaleY * Factor;
        ATransform.Alpha := Clamp01(AElapsedSeconds / 0.08);
      end;
    SERIF_ANIMATION_BEFORE_WIPE:
      begin
        ATransform.RevealMode := sdrmWipe;
        ATransform.RevealDirection := AParameters.BeforeDirection;
        ATransform.RevealProgress := SmoothStep(AElapsedSeconds /
          SERIF_BEFORE_WIPE_SECONDS);
      end;
    SERIF_ANIMATION_BEFORE_BLUR:
      begin
        P := SmoothStep(AElapsedSeconds / SERIF_BEFORE_BLUR_SECONDS);
        ATransform.BlurRadius := 6.0 * (1.0 - P);
        ATransform.Alpha := Clamp01(AElapsedSeconds / 0.10);
      end;
    SERIF_ANIMATION_BEFORE_ROTATE:
      begin
        P := SmoothStep(AElapsedSeconds / SERIF_BEFORE_ROTATE_SECONDS);
        if AParameters.BeforeDirection = SERIF_ANIMATION_DIRECTION_RIGHT then
          ATransform.RotationDegrees := 8.0 * (1.0 - P)
        else
          ATransform.RotationDegrees := -8.0 * (1.0 - P);
        Factor := 0.90 + 0.10 * P;
        ATransform.ScaleX := ATransform.ScaleX * Factor;
        ATransform.ScaleY := ATransform.ScaleY * Factor;
        ATransform.Alpha := Clamp01(AElapsedSeconds / 0.08);
      end;
    SERIF_ANIMATION_BEFORE_BOUNCE:
      begin
        P := Clamp01(AElapsedSeconds / SERIF_BEFORE_BOUNCE_SECONDS);
        if P < 0.62 then
          StartOffset := 32.0 * (1.0 - SmoothStep(P / 0.62))
        else if P < 0.78 then
          StartOffset := 7.0 * SmoothStep((P - 0.62) / 0.16)
        else
          StartOffset := 7.0 *
            (1.0 - SmoothStep((P - 0.78) / 0.22));
        case AParameters.BeforeDirection of
          SERIF_ANIMATION_DIRECTION_LEFT:
            ATransform.OffsetX := ATransform.OffsetX - StartOffset;
          SERIF_ANIMATION_DIRECTION_RIGHT:
            ATransform.OffsetX := ATransform.OffsetX + StartOffset;
          SERIF_ANIMATION_DIRECTION_BOTTOM:
            ATransform.OffsetY := ATransform.OffsetY + StartOffset;
        else
          ATransform.OffsetY := ATransform.OffsetY - StartOffset;
        end;
        ATransform.Alpha := Clamp01(AElapsedSeconds / 0.08);
      end;
  end;
end;

procedure ApplyDuringAnimation(
  const AParameters: TSerifDrawAnimationParameters;
  const AElapsedSeconds: Double;
  var ATransform: TSerifDrawAnimationTransform);
begin
  if AParameters.DuringEmotionEnabled then
    ApplySerifDrawEmotionAnimation(AParameters.RuntimeEmote,
      AElapsedSeconds, AParameters.DuringSpeed, ATransform);
end;

procedure ApplyAfterAnimation(const AParameters: TSerifDrawAnimationParameters;
  const AAfterElapsedSeconds: Double;
  var ATransform: TSerifDrawAnimationTransform);
var
  Direction: Integer;
  Factor: Double;
  P: Double;
  Travel: Double;
begin
  Direction := AParameters.AfterDirection;
  case AParameters.AfterKind of
    SERIF_ANIMATION_AFTER_FADE:
      begin
        P := Clamp01(AAfterElapsedSeconds / SERIF_AFTER_FADE_SECONDS);
        ATransform.Alpha := 1.0 - P;
      end;
    SERIF_ANIMATION_AFTER_SLIDE:
      begin
        P := Clamp01(AAfterElapsedSeconds / SERIF_AFTER_SLIDE_SECONDS);
        Travel := 64.0 * SmoothStep(P);
        case Direction of
          SERIF_ANIMATION_DIRECTION_LEFT:
            ATransform.OffsetX := ATransform.OffsetX - Travel;
          SERIF_ANIMATION_DIRECTION_TOP:
            ATransform.OffsetY := ATransform.OffsetY - Travel;
          SERIF_ANIMATION_DIRECTION_BOTTOM:
            ATransform.OffsetY := ATransform.OffsetY + Travel;
        else
          ATransform.OffsetX := ATransform.OffsetX + Travel;
        end;
        ATransform.Alpha := 1.0 - Clamp01((P - 0.55) / 0.45);
      end;
    SERIF_ANIMATION_AFTER_ZOOM:
      begin
        P := SmoothStep(AAfterElapsedSeconds / SERIF_AFTER_ZOOM_SECONDS);
        if AParameters.AfterZoomDestination = SERIF_ANIMATION_ZOOM_TO_FRONT then
          Factor := 1.0 + 0.28 * P
        else
          Factor := 1.0 - 0.28 * P;
        ATransform.ScaleX := ATransform.ScaleX * Factor;
        ATransform.ScaleY := ATransform.ScaleY * Factor;
        ATransform.Alpha := 1.0 - Clamp01((P - 0.45) / 0.55);
      end;
    SERIF_ANIMATION_AFTER_WIPE:
      begin
        P := SmoothStep(AAfterElapsedSeconds / SERIF_AFTER_WIPE_SECONDS);
        if Direction = SERIF_ANIMATION_DIRECTION_DEFAULT then
          Direction := SERIF_ANIMATION_DIRECTION_RIGHT;
        ATransform.RevealMode := sdrmWipe;
        ATransform.RevealDirection := Direction;
        ATransform.RevealProgress := 1.0 - P;
      end;
    SERIF_ANIMATION_AFTER_BLUR:
      begin
        P := SmoothStep(AAfterElapsedSeconds / SERIF_AFTER_BLUR_SECONDS);
        ATransform.BlurRadius := 8.0 * P;
        ATransform.Alpha := 1.0 - P;
      end;
    SERIF_ANIMATION_AFTER_ROTATE:
      begin
        P := SmoothStep(AAfterElapsedSeconds / SERIF_AFTER_ROTATE_SECONDS);
        if Direction = SERIF_ANIMATION_DIRECTION_LEFT then
          ATransform.RotationDegrees := -12.0 * P
        else
          ATransform.RotationDegrees := 12.0 * P;
        Factor := 1.0 - 0.10 * P;
        ATransform.ScaleX := ATransform.ScaleX * Factor;
        ATransform.ScaleY := ATransform.ScaleY * Factor;
        ATransform.Alpha := 1.0 - Clamp01((P - 0.45) / 0.55);
      end;
  else
    ATransform.Alpha := 0.0;
    ATransform.Visible := False;
    Exit;
  end;
  ATransform.Visible := P < 1.0;
end;

function EvaluateSerifDrawActiveAnimation(
  const AParameters: TSerifDrawAnimationParameters;
  const AElapsedSeconds: Double): TSerifDrawAnimationTransform;
begin
  Result := TSerifDrawAnimationTransform.Identity;
  ApplyDuringAnimation(AParameters, Max(0.0, AElapsedSeconds), Result);
  ApplyBeforeAnimation(AParameters, Max(0.0, AElapsedSeconds), Result);
end;

function EvaluateSerifDrawAfterAnimation(
  const AParameters: TSerifDrawAnimationParameters;
  const ATotalElapsedSeconds, AAfterElapsedSeconds: Double):
  TSerifDrawAnimationTransform;
begin
  Result := TSerifDrawAnimationTransform.Identity;
  ApplyDuringAnimation(AParameters, Max(0.0, ATotalElapsedSeconds), Result);
  ApplyAfterAnimation(AParameters, Max(0.0, AAfterElapsedSeconds), Result);
end;

end.
