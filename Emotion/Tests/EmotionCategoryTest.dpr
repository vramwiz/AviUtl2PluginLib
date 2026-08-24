program EmotionCategoryTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  EmotionCategory in 'Emotion\EmotionCategory.pas';

const
  NORMAL_PRESET = #$30CE#$30FC#$30DE#$30EB;
  JOY_PRESET = #$3042#$307E#$3042#$307E;
  ANGER_PRESET = #$30C4#$30F3#$30C4#$30F3;
  SORROW_PRESET = #$3073#$3048#$30FC#$3093;
  FUN_PRESET = #$697D#$3005;

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

begin
  Require(ResolveEmotionCategory(NORMAL_PRESET) = ecNormal,
    'Normal preset mismatch.');
  Require(ResolveEmotionCategory(JOY_PRESET) = ecJoy,
    'Joy preset mismatch.');
  Require(ResolveEmotionCategory(ANGER_PRESET) = ecAnger,
    'Anger preset mismatch.');
  Require(ResolveEmotionCategory(SORROW_PRESET) = ecSorrow,
    'Sorrow preset mismatch.');
  Require(ResolveEmotionCategory(FUN_PRESET) = ecFun,
    'Fun preset mismatch.');
  Require(ResolveEmotionCategory('preset_' + #$4E0D#$6A5F#$5ACC + '_2') =
    ecAnger,
    'Substring matching mismatch.');
  Require(ResolveEmotionCategory('undefined') = ecUnknown,
    'Unknown preset mismatch.');
  Require((EmotionCategoryName(ecJoy) = #$559C) and
    (EmotionCategoryName(ecAnger) = #$6012) and
    (EmotionCategoryName(ecSorrow) = #$54C0) and
    (EmotionCategoryName(ecFun) = #$697D),
    'Category names mismatch.');
  Writeln('Emotion category test passed.');
end.
