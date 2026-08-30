program SerifDrawAnimationTest;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  SharedMemoryBase in 'Lib\SharedMemory\SharedMemoryBase.pas',
  SerifSharedIndex in 'Lib\SharedMemory\SerifSharedIndex.pas',
  EmotionCategory in 'Lib\Emotion\EmotionCategory.pas',
  PluginFilterSerifDrawAnimationTypes in
    'Serif\Plugin\Draw\Animation\PluginFilterSerifDrawAnimationTypes.pas',
  PluginFilterSerifDrawAnimationEvaluator in
    'Serif\Plugin\Draw\Animation\PluginFilterSerifDrawAnimationEvaluator.pas',
  PluginFilterSerifDrawEmotionAnimation in
    'Serif\Plugin\Draw\Animation\PluginFilterSerifDrawEmotionAnimation.pas',
  PluginFilterSerifDrawAnimationController in
    'Serif\Plugin\Draw\Animation\PluginFilterSerifDrawAnimationController.pas',
  PluginFilterSerifDrawReceiver in
    'Serif\Plugin\Draw\PluginFilterSerifDrawReceiver.pas';

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function Near(const AActual, AExpected: Double): Boolean;
begin
  Result := Abs(AActual - AExpected) < 0.000001;
end;

function Snapshot(const AId, AText: string): TSerifDrawSnapshot;
begin
  Result := System.Default(TSerifDrawSnapshot);
  Result.Layer := 1;
  Result.SourceObjectID := AId;
  Result.Serif := AText;
end;

var
  Active: TArray<TSerifDrawSnapshot>;
  Controller: TSerifDrawAnimationController;
  Parameters: TSerifDrawAnimationParameters;
  Rendered: TArray<TSerifDrawSnapshot>;
  Transform: TSerifDrawAnimationTransform;
begin
  Parameters := System.Default(TSerifDrawAnimationParameters);
  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_FADE;
  Parameters.DuringSpeed := 1.0;
  Parameters.AfterKind := SERIF_ANIMATION_AFTER_FADE;

  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.Alpha, 0.0),
    'Before fade must start transparent.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.15);
  Require(Near(Transform.Alpha, 0.5),
    'Before fade midpoint mismatch.');
  Transform := EvaluateSerifDrawAfterAnimation(Parameters, 1.25, 0.15);
  Require(Near(Transform.Alpha, 0.5),
    'After fade midpoint mismatch.');

  Parameters.DuringEmotionEnabled := True;
  Parameters.DuringSpeed := 1.0;
  Parameters.RuntimeEmote := 'ツンツン';
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.ScaleX, 1.08) and Near(Transform.ScaleY, 1.08),
    'Angry emotion must enlarge the serif.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.025);
  Require(not Near(Transform.OffsetX, 0.0),
    'Angry emotion must shake the serif.');
  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_ZOOM;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_ZOOM_SECONDS);
  Require(Near(Transform.ScaleX, 1.08) and Near(Transform.ScaleY, 1.08),
    'Emotion scale must remain underneath a completed before animation.');
  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_FADE;

  Parameters.RuntimeEmote := 'びえーん';
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.ScaleX, 0.96) and Near(Transform.ScaleY, 0.96),
    'Sad emotion must shrink the serif.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.02);
  Require(not Near(Transform.OffsetX, 0.0),
    'Sad emotion must tremble the serif.');

  Parameters.RuntimeEmote := 'わーい';
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.125);
  Require(Near(Transform.OffsetY, -5.0),
    'Happy emotion must jump the serif.');

  Parameters.RuntimeEmote := 'ノーマル';
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.125);
  Require(Near(Transform.ScaleX, 1.0) and Near(Transform.OffsetX, 0.0) and
    Near(Transform.OffsetY, 0.0),
    'Unknown emotions must keep the normal transform.');
  Parameters.DuringEmotionEnabled := False;
  Parameters.RuntimeEmote := '';

  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_SLIDE;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.OffsetX, -48.0) and Near(Transform.Alpha, 0.0),
    'Slide-in must start left and transparent.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_SLIDE_SECONDS);
  Require(Near(Transform.OffsetX, 0.0) and Near(Transform.Alpha, 1.0),
    'Slide-in must finish at the normal position.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_RIGHT;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.OffsetX, 48.0) and Near(Transform.OffsetY, 0.0),
    'Right slide-in must start on the right.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_TOP;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.OffsetX, 0.0) and Near(Transform.OffsetY, -48.0),
    'Top slide-in must start above.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_BOTTOM;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.OffsetX, 0.0) and Near(Transform.OffsetY, 48.0),
    'Bottom slide-in must start below.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_DEFAULT;

  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_ZOOM;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.ScaleX, 0.72) and Near(Transform.ScaleY, 0.72),
    'Zoom-in must start at the fixed small scale.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_ZOOM_SECONDS);
  Require(Near(Transform.ScaleX, 1.0) and Near(Transform.ScaleY, 1.0),
    'Zoom-in must finish at the normal scale.');
  Parameters.BeforeZoomOrigin := SERIF_ANIMATION_ZOOM_FROM_FRONT;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.ScaleX, 1.28) and Near(Transform.ScaleY, 1.28),
    'Front zoom-in must start at the fixed large scale.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_ZOOM_SECONDS);
  Require(Near(Transform.ScaleX, 1.0) and Near(Transform.ScaleY, 1.0),
    'Front zoom-in must finish at the normal scale.');
  Parameters.BeforeZoomOrigin := SERIF_ANIMATION_ZOOM_FROM_BACK;

  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_POP;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_POP_SECONDS * 0.7);
  Require(Near(Transform.ScaleX, 1.08),
    'Pop-in must use the fixed overshoot.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_POP_SECONDS);
  Require(Near(Transform.ScaleX, 1.0),
    'Pop-in must settle at the normal scale.');
  Parameters.BeforeZoomOrigin := SERIF_ANIMATION_ZOOM_FROM_FRONT;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.ScaleX, 1.28),
    'Front pop-in must start at the fixed large scale.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_POP_SECONDS * 0.7);
  Require(Near(Transform.ScaleX, 0.92),
    'Front pop-in must use the fixed undershoot.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_POP_SECONDS);
  Require(Near(Transform.ScaleX, 1.0),
    'Front pop-in must settle at the normal scale.');
  Parameters.BeforeZoomOrigin := SERIF_ANIMATION_ZOOM_FROM_BACK;

  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_WIPE;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require((Transform.RevealMode = sdrmWipe) and
    Near(Transform.RevealProgress, 0.0),
    'Wipe-in must start fully clipped.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_BOTTOM;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Transform.RevealDirection = SERIF_ANIMATION_DIRECTION_BOTTOM,
    'Wipe-in must expose its selected direction to the compositor.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_DEFAULT;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_WIPE_SECONDS);
  Require(Near(Transform.RevealProgress, 1.0),
    'Wipe-in must finish fully visible.');

  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_BLUR;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.BlurRadius, 6.0) and Near(Transform.Alpha, 0.0),
    'Blur-in must start blurred and transparent.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_BLUR_SECONDS);
  Require(Near(Transform.BlurRadius, 0.0) and Near(Transform.Alpha, 1.0),
    'Blur-in must finish sharp and opaque.');

  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_ROTATE;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.RotationDegrees, -8.0) and
    Near(Transform.ScaleX, 0.90) and Near(Transform.ScaleY, 0.90) and
    Near(Transform.Alpha, 0.0),
    'Rotate-in must start rotated, small, and transparent.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_ROTATE_SECONDS);
  Require(Near(Transform.RotationDegrees, 0.0) and
    Near(Transform.ScaleX, 1.0) and Near(Transform.ScaleY, 1.0) and
    Near(Transform.Alpha, 1.0),
    'Rotate-in must finish at the normal transform.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_RIGHT;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.RotationDegrees, 8.0),
    'Right rotate-in must reverse the initial angle.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_DEFAULT;

  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_BOUNCE;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.OffsetY, -32.0) and Near(Transform.Alpha, 0.0),
    'Bounce-in must start above and transparent.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_BOUNCE_SECONDS * 0.62);
  Require(Near(Transform.OffsetY, 0.0),
    'Bounce-in must reach the normal position before rebounding.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_BOUNCE_SECONDS * 0.78);
  Require(Near(Transform.OffsetY, -7.0),
    'Bounce-in must use the fixed rebound height.');
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_BOUNCE_SECONDS);
  Require(Near(Transform.OffsetY, 0.0) and Near(Transform.Alpha, 1.0),
    'Bounce-in must settle at the normal position.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_LEFT;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters, 0.0);
  Require(Near(Transform.OffsetX, -32.0) and Near(Transform.OffsetY, 0.0),
    'Left bounce-in must use the horizontal axis.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_RIGHT;
  Transform := EvaluateSerifDrawActiveAnimation(Parameters,
    SERIF_BEFORE_BOUNCE_SECONDS * 0.78);
  Require(Near(Transform.OffsetX, 7.0) and Near(Transform.OffsetY, 0.0),
    'Right bounce-in must rebound on the horizontal axis.');
  Parameters.BeforeDirection := SERIF_ANIMATION_DIRECTION_DEFAULT;

  Parameters.AfterKind := SERIF_ANIMATION_AFTER_SLIDE;
  Parameters.AfterDirection := SERIF_ANIMATION_DIRECTION_LEFT;
  Transform := EvaluateSerifDrawAfterAnimation(Parameters, 1.0,
    SERIF_AFTER_SLIDE_SECONDS);
  Require(Near(Transform.OffsetX, -64.0) and Near(Transform.Alpha, 0.0) and
    not Transform.Visible,
    'Left slide-out must finish left and hidden.');

  Parameters.AfterKind := SERIF_ANIMATION_AFTER_ZOOM;
  Parameters.AfterZoomDestination := SERIF_ANIMATION_ZOOM_TO_BACK;
  Transform := EvaluateSerifDrawAfterAnimation(Parameters, 1.0,
    SERIF_AFTER_ZOOM_SECONDS);
  Require(Near(Transform.ScaleX, 0.72) and Near(Transform.Alpha, 0.0) and
    not Transform.Visible,
    'Back zoom-out must finish small and hidden.');
  Parameters.AfterZoomDestination := SERIF_ANIMATION_ZOOM_TO_FRONT;
  Transform := EvaluateSerifDrawAfterAnimation(Parameters, 1.0,
    SERIF_AFTER_ZOOM_SECONDS);
  Require(Near(Transform.ScaleX, 1.28) and not Transform.Visible,
    'Front zoom-out must finish large and hidden.');

  Parameters.AfterKind := SERIF_ANIMATION_AFTER_WIPE;
  Parameters.AfterDirection := SERIF_ANIMATION_DIRECTION_TOP;
  Transform := EvaluateSerifDrawAfterAnimation(Parameters, 1.0,
    SERIF_AFTER_WIPE_SECONDS * 0.5);
  Require((Transform.RevealMode = sdrmWipe) and
    (Transform.RevealDirection = SERIF_ANIMATION_DIRECTION_TOP) and
    (Transform.RevealProgress > 0.0) and
    (Transform.RevealProgress < 1.0) and Transform.Visible,
    'Top wipe-out must clip toward the selected edge.');
  Transform := EvaluateSerifDrawAfterAnimation(Parameters, 1.0,
    SERIF_AFTER_WIPE_SECONDS);
  Require(Near(Transform.RevealProgress, 0.0) and not Transform.Visible,
    'Wipe-out must finish fully clipped.');

  Parameters.AfterKind := SERIF_ANIMATION_AFTER_BLUR;
  Transform := EvaluateSerifDrawAfterAnimation(Parameters, 1.0,
    SERIF_AFTER_BLUR_SECONDS);
  Require(Near(Transform.BlurRadius, 8.0) and Near(Transform.Alpha, 0.0) and
    not Transform.Visible,
    'Blur-out must finish blurred and hidden.');

  Parameters.AfterKind := SERIF_ANIMATION_AFTER_ROTATE;
  Parameters.AfterDirection := SERIF_ANIMATION_DIRECTION_LEFT;
  Transform := EvaluateSerifDrawAfterAnimation(Parameters, 1.0,
    SERIF_AFTER_ROTATE_SECONDS);
  Require(Near(Transform.RotationDegrees, -12.0) and
    Near(Transform.ScaleX, 0.90) and not Transform.Visible,
    'Left rotate-out must finish rotated, small, and hidden.');

  Parameters.BeforeKind := SERIF_ANIMATION_BEFORE_FADE;
  Parameters.DuringEmotionEnabled := False;
  Parameters.AfterKind := SERIF_ANIMATION_AFTER_FADE;
  Parameters.AfterDirection := SERIF_ANIMATION_DIRECTION_DEFAULT;
  Parameters.AfterZoomDestination := SERIF_ANIMATION_ZOOM_TO_BACK;

  SetLength(Active, 1);
  Active[0] := Snapshot('one', 'first');
  Active[0].SpeechActive := True;
  Active[0].SpeechProgress := 1.0;
  Controller := TSerifDrawAnimationController.Create;
  try
    Transform := Controller.Update(Active, 100, 10.0, Parameters, Rendered);
    Require((Length(Rendered) = 1) and Near(Transform.Alpha, 0.0),
      'A new serif must begin with the before fade.');
    Transform := Controller.Update(Active, 103, 10.0, Parameters, Rendered);
    Require(Near(Transform.Alpha, 1.0),
      'The before fade did not finish at its duration.');

    Active := nil;
    Transform := Controller.Update(Active, 110, 10.0, Parameters, Rendered);
    Require((Length(Rendered) = 1) and Near(Transform.Alpha, 1.0) and
      not Rendered[0].SpeechActive and Rendered[0].HoldSpeechSync and
      Near(Rendered[0].SpeechProgress, 1.0),
      'The after fade must retain the ended serif and its final sync state.');
    Transform := Controller.Update(Active, 112, 10.0, Parameters, Rendered);
    Require((Length(Rendered) = 1) and
      Near(Transform.Alpha, 1.0 / 3.0),
      'The retained serif did not fade after its end.');

    SetLength(Active, 1);
    Active[0] := Snapshot('two', 'second');
    Transform := Controller.Update(Active, 113, 10.0, Parameters, Rendered);
    Require((Length(Rendered) = 1) and (Rendered[0].Serif = 'second') and
      Near(Transform.Alpha, 0.0),
      'A new serif must interrupt the previous after fade.');
  finally
    Controller.Free;
  end;

  Writeln('SerifDraw animation test passed.');
end.
