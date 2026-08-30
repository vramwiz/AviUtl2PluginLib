unit PluginFilterSerifDrawEmotionAnimation;

interface

// Moduleから受信した感情名を、本文全体へ適用する常時変換へ変換する。

uses
  PluginFilterSerifDrawAnimationTypes;

procedure ApplySerifDrawEmotionAnimation(const AEmote: string;
  const AElapsedSeconds, ASpeed: Double;
  var ATransform: TSerifDrawAnimationTransform);

implementation

uses
  System.Math,
  EmotionCategory;

procedure ApplySerifDrawEmotionAnimation(const AEmote: string;
  const AElapsedSeconds, ASpeed: Double;
  var ATransform: TSerifDrawAnimationTransform);
var
  EffectiveSpeed: Double;
  JumpPhase: Double;
begin
  EffectiveSpeed := Max(0.0, ASpeed);
  case ResolveEmotionCategory(AEmote) of
    ecAnger:
      begin
        ATransform.ScaleX := ATransform.ScaleX * 1.08;
        ATransform.ScaleY := ATransform.ScaleY * 1.08;
        ATransform.OffsetX := ATransform.OffsetX +
          Sin(AElapsedSeconds * EffectiveSpeed * 9.0 * 2.0 * Pi) * 3.0;
        ATransform.OffsetY := ATransform.OffsetY +
          Sin(AElapsedSeconds * EffectiveSpeed * 13.0 * 2.0 * Pi) * 1.5;
      end;
    ecSorrow:
      begin
        ATransform.ScaleX := ATransform.ScaleX * 0.96;
        ATransform.ScaleY := ATransform.ScaleY * 0.96;
        ATransform.OffsetX := ATransform.OffsetX +
          Sin(AElapsedSeconds * EffectiveSpeed * 11.0 * 2.0 * Pi) * 0.8;
        ATransform.OffsetY := ATransform.OffsetY +
          Sin(AElapsedSeconds * EffectiveSpeed * 7.0 * 2.0 * Pi) * 0.4;
      end;
    ecJoy, ecFun:
      begin
        JumpPhase := Sin(AElapsedSeconds * EffectiveSpeed * 2.0 * Pi);
        ATransform.OffsetY := ATransform.OffsetY -
          JumpPhase * JumpPhase * 10.0;
      end;
  end;
end;

end.
