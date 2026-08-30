unit PluginFilterSerifDrawAnimationTypes;

interface

const
  SERIF_ANIMATION_NONE = 0;
  SERIF_ANIMATION_BEFORE_FADE = 1;
  SERIF_ANIMATION_BEFORE_SLIDE = 2;
  SERIF_ANIMATION_BEFORE_ZOOM = 3;
  SERIF_ANIMATION_BEFORE_POP = 4;
  SERIF_ANIMATION_BEFORE_WIPE = 5;
  SERIF_ANIMATION_BEFORE_BLUR = 6;
  SERIF_ANIMATION_BEFORE_ROTATE = 10;
  SERIF_ANIMATION_BEFORE_BOUNCE = 11;
  SERIF_ANIMATION_SYNC_SPEECH_COLOR = 1;
  // AviUtl2は選択肢をValue順に表示するため、画面上の希望順と同じ値にする。
  SERIF_ANIMATION_SYNC_FRONT = 2;
  SERIF_ANIMATION_SYNC_BACKING = 3;
  SERIF_ANIMATION_SYNC_UNDERLINE = 4;
  SERIF_ANIMATION_SYNC_ZOOM = 5;
  SERIF_ANIMATION_SYNC_GLOW = 6;
  SERIF_ANIMATION_SYNC_JUMP = 7;
  SERIF_ANIMATION_SYNC_MODE_STANDARD = 0;
  SERIF_ANIMATION_SYNC_MODE_TRAIL = 1;
  SERIF_ANIMATION_SYNC_PAINT_CHARACTER = 0;
  SERIF_ANIMATION_SYNC_PAINT_SMOOTH = 1;
  SERIF_ANIMATION_SYNC_SHAPE_AUTO = 0;
  SERIF_ANIMATION_SYNC_SHAPE_CIRCLE = 1;
  SERIF_ANIMATION_SYNC_SHAPE_SQUARE = 2;
  SERIF_ANIMATION_SYNC_SHAPE_TRIANGLE = 3;
  SERIF_ANIMATION_AFTER_FADE = 1;
  SERIF_ANIMATION_AFTER_SLIDE = 2;
  SERIF_ANIMATION_AFTER_ZOOM = 3;
  SERIF_ANIMATION_AFTER_WIPE = 5;
  SERIF_ANIMATION_AFTER_BLUR = 6;
  SERIF_ANIMATION_AFTER_ROTATE = 11;
  SERIF_ANIMATION_DIRECTION_DEFAULT = 0;
  SERIF_ANIMATION_DIRECTION_LEFT = 1;
  SERIF_ANIMATION_DIRECTION_RIGHT = 2;
  SERIF_ANIMATION_DIRECTION_TOP = 3;
  SERIF_ANIMATION_DIRECTION_BOTTOM = 4;
  SERIF_ANIMATION_ZOOM_FROM_BACK = 0;
  SERIF_ANIMATION_ZOOM_FROM_FRONT = 1;
  SERIF_ANIMATION_ZOOM_TO_BACK = 0;
  SERIF_ANIMATION_ZOOM_TO_FRONT = 1;
  SERIF_BEFORE_FADE_SECONDS = 0.30;
  SERIF_BEFORE_SLIDE_SECONDS = 0.18;
  SERIF_BEFORE_ZOOM_SECONDS = 0.20;
  SERIF_BEFORE_POP_SECONDS = 0.24;
  SERIF_BEFORE_WIPE_SECONDS = 0.20;
  SERIF_BEFORE_BLUR_SECONDS = 0.18;
  SERIF_BEFORE_ROTATE_SECONDS = 0.20;
  SERIF_BEFORE_BOUNCE_SECONDS = 0.26;
  SERIF_AFTER_FADE_SECONDS = 0.30;
  SERIF_AFTER_SLIDE_SECONDS = 0.22;
  SERIF_AFTER_ZOOM_SECONDS = 0.24;
  SERIF_AFTER_WIPE_SECONDS = 0.22;
  SERIF_AFTER_BLUR_SECONDS = 0.24;
  SERIF_AFTER_ROTATE_SECONDS = 0.26;

type
  TSerifDrawRevealMode = (sdrmNone, sdrmWipe);

  TSerifDrawAnimationParameters = record
    BeforeKind: Integer;
    BeforeDirection: Integer;
    BeforeZoomOrigin: Integer;
    DuringEmotionEnabled: Boolean;
    DuringSpeed: Double;
    SyncKind: Integer;
    SyncMode: Integer;
    SyncPaintMode: Integer;
    SyncShape: Integer;
    SyncColor: Cardinal;
    SyncSize: Double;
    SyncOffsetX: Double;
    SyncOffsetY: Double;
    SyncSpeed: Double;
    SyncValue1: Double;
    SyncValue2: Double;
    SyncValue3: Double;
    AfterKind: Integer;
    AfterDirection: Integer;
    AfterZoomDestination: Integer;
    RuntimeEmote: string;
  end;

  TSerifDrawAnimationTransform = record
    Alpha: Double;
    OffsetX: Double;
    OffsetY: Double;
    BlurRadius: Double;
    RevealMode: TSerifDrawRevealMode;
    RevealDirection: Integer;
    RevealProgress: Double;
    RotationDegrees: Double;
    ScaleX: Double;
    ScaleY: Double;
    Visible: Boolean;
    class function Identity: TSerifDrawAnimationTransform; static;
  end;

implementation

class function TSerifDrawAnimationTransform.Identity:
  TSerifDrawAnimationTransform;
begin
  Result := System.Default(TSerifDrawAnimationTransform);
  Result.Alpha := 1.0;
  Result.ScaleX := 1.0;
  Result.ScaleY := 1.0;
  Result.RevealProgress := 1.0;
  Result.Visible := True;
end;

end.
