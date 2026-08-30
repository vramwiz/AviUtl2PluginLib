program SerifDrawSpeechSyncTest;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  System.Types,
  TextRendererTypes in 'Lib\TextRenderer\TextRendererTypes.pas',
  SerifSpeechSync in 'Serif\Plugin\Module\SerifSpeechSync.pas',
  PluginFilterSerifDrawAnimationTypes in
    'Serif\Plugin\Draw\Animation\PluginFilterSerifDrawAnimationTypes.pas',
  PluginFilterSerifDrawSyncBacking in
    'Serif\Plugin\Draw\Animation\PluginFilterSerifDrawSyncBacking.pas',
  PluginFilterSerifDrawSyncGeometry in
    'Serif\Plugin\Draw\Animation\PluginFilterSerifDrawSyncGeometry.pas',
  PluginFilterSerifDrawSyncHighlight in
    'Serif\Plugin\Draw\Animation\PluginFilterSerifDrawSyncHighlight.pas',
  PluginFilterSerifDrawSyncFront in
    'Serif\Plugin\Draw\Display\PluginFilterSerifDrawSyncFront.pas',
  PluginFilterSerifDrawSyncTextGlow in
    'Serif\Plugin\Draw\Display\PluginFilterSerifDrawSyncTextGlow.pas',
  PluginFilterSerifDrawSyncUnderline in
    'Serif\Plugin\Draw\Display\PluginFilterSerifDrawSyncUnderline.pas',
  PluginFilterSerifDrawSyncJump in
    'Serif\Plugin\Draw\Display\PluginFilterSerifDrawSyncJump.pas',
  PluginFilterSerifDrawSyncZoom in
    'Serif\Plugin\Draw\Display\PluginFilterSerifDrawSyncZoom.pas';

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

var
  BackingRegions: TArray<TSerifSyncBackingRegion>;
  BaseImage: TTextRenderImage;
  CharacterLineBounds: TArray<TRect>;
  GlowPixel: TTextRenderPixel;
  GlowRegions: TArray<TSerifSyncBackingRegion>;
  TextGlowImage: TTextRenderImage;
  TextGlowItems: TArray<TSerifSyncTextGlowItem>;
  TextGlowUnitImages: TArray<TTextRenderImage>;
  JumpItems: TArray<TSerifSyncJumpItem>;
  LineBounds: TArray<TRect>;
  Marker: TRect;
  Progress: Double;
  SmoothIndex: Integer;
  SmoothProgress: Double;
  SmoothRangeEnd: Double;
  SmoothRangeStart: Double;
  TextUnitBounds: TArray<TRect>;
  TextUnitImages: TArray<TTextRenderImage>;
  UnderlineRegions: TArray<TSerifSyncUnderlineRegion>;
  ZoomItems: TArray<TSerifSyncZoomItem>;
begin
  Require(Abs(CalculateSerifSpeechProgress(0.5, 2.0) - 0.25) < 0.000001,
    'Speech progress mismatch.');
  Require(IsSerifSpeechActive(True, '0,10000000,a', 'test', 0.5, 2.0),
    'A LAB vowel must be active.');
  Require(not IsSerifSpeechActive(True, '0,10000000,Pause', 'test',
    0.5, 2.0), 'A LAB pause must be inactive.');
  Require(not IsSerifSpeechActive(True, '0,10000000,vol:0', 'test',
    0.5, 2.0), 'Zero LAB volume must be inactive.');
  Require(IsSerifSpeechActive(False, '', 'test', 0.5, 2.0),
    'A serif without LAB must use total time.');
  Progress := CalculateSerifSpeechProgressFromLab(
    '0,10000000,a' + sLineBreak +
    '10000000,20000000,i' + sLineBreak +
    '20000000,100000000,Pause', '10000000,20000000,i', 1.5, 10.0);
  Require(Abs(Progress - 1.0) < 0.000001,
    'The last spoken LAB element must reach the final text position.');
  Progress := CalculateSerifSpeechProgressFromLab(
    '0,10000000,a' + sLineBreak +
    '10000000,20000000,Pause' + sLineBreak +
    '20000000,30000000,i' + sLineBreak +
    '30000000,40000000,Pause' + sLineBreak +
    '40000000,50000000,u', '10000000,20000000,Pause', 1.5, 5.0);
  Require(Abs(Progress - (1.0 / 3.0)) < 0.000001,
    'A LAB pause must retain the number of completed speech elements.');
  Progress := CalculateSerifSpeechProgressFromLab(
    '0,10000000,a' + sLineBreak +
    '10000000,20000000,Pause' + sLineBreak +
    '20000000,30000000,i' + sLineBreak +
    '30000000,40000000,Pause' + sLineBreak +
    '40000000,50000000,u', '30000000,40000000,Pause', 3.5, 5.0);
  Require(Abs(Progress - (2.0 / 3.0)) < 0.000001,
    'Successive LAB pauses must never move maintained progress backward.');
  Progress := CalculateSerifSpeechProgressFromLab(
    't0,.1,a' + sLineBreak +
    't.1,.1,i' + sLineBreak +
    't.2,.1,u', '', 0.35, 0.5);
  Require(Abs(Progress - 1.0) < 0.000001,
    'Trailing time outside LAB must retain the final speech position.');
  Progress := CalculateSerifSpeechProgressFromLab(
    't.1,.1,a' + sLineBreak +
    't.3,.1,i', '', 0.05, 0.5);
  Require(Abs(Progress) < 0.000001,
    'Leading time outside LAB must stay before the first speech position.');
  Require(CalculateSerifSyncHighlightIndex(4, 0.5) = 2,
    'Speech highlight index mismatch.');
  Require(CalculateSerifSyncHighlightIndex(4, 1.0) = 3,
    'The last spoken LAB element did not select the final text unit.');
  CalculateSerifSyncHighlightPosition(4, 0.3, SmoothIndex, SmoothProgress);
  Require((SmoothIndex = 1) and (Abs(SmoothProgress - 0.2) < 0.000001),
    'Smooth color position must retain progress inside the current text unit.');
  CalculateSerifSyncHighlightPosition(4, 1.0, SmoothIndex, SmoothProgress);
  Require((SmoothIndex = 3) and (Abs(SmoothProgress - 1.0) < 0.000001),
    'Smooth color position must completely fill the final text unit.');
  Require((Abs(CalculateSerifSyncSmoothFillProgress(0.5, 120.0) - 0.6) <
      0.000001) and
    (Abs(CalculateSerifSyncSmoothFillProgress(0.5, 80.0) - 0.4) <
      0.000001) and
    (Abs(CalculateSerifSyncSmoothFillProgress(0.8, 200.0) - 1.0) <
      0.000001),
    'Smooth color size must scale and clamp the fill width.');
  CalculateSerifSyncSmoothWindow(3, 0.25, 500.0, SmoothRangeStart,
    SmoothRangeEnd);
  Require((Abs((SmoothRangeEnd - SmoothRangeStart) - 5.0) < 0.000001) and
    (SmoothRangeStart < 3.0) and (SmoothRangeEnd > 4.0),
    'A 500-percent smooth reset must span five text-unit widths.');
  SetLength(LineBounds, 2);
  LineBounds[0] := TRect.Create(0, 0, 100, 40);
  LineBounds[1] := TRect.Create(20, 50, 220, 90);
  BackingRegions := CalculateSerifSyncBackingRegions(LineBounds,
    TRect.Create(0, 0, 220, 90), TRect.Create(-10, -10, 230, 100),
    0, 300, False, 100.0, 0.0, 0.0);
  Require(Length(BackingRegions) = 1,
    'Standard backing must contain only the moving marker.');
  Marker := BackingRegions[0].Bounds;
  Require(Marker.Left = 10,
    'Frame zero must be clipped at the first line left pixel.');
  BackingRegions := CalculateSerifSyncBackingRegions(LineBounds,
    TRect.Create(0, 0, 220, 90), TRect.Create(-10, -10, 230, 100),
    50, 300, False, 100.0, 0.0, 0.0);
  Marker := BackingRegions[0].Bounds;
  Require((Marker.Width = 40) and (Marker.Height = 40),
    'A 100-percent backing marker must match the measured line height.');
  BackingRegions := CalculateSerifSyncBackingRegions(LineBounds,
    TRect.Create(0, 0, 220, 90), TRect.Create(-10, -10, 230, 100),
    50, 300, False, 120.0, 0.0, 0.0);
  Marker := BackingRegions[0].Bounds;
  Require((Marker.Height = 48) and (Marker.Top = 6) and
    (Marker.Bottom = 54),
    'A 120-percent backing marker must extend outside the text height.');
  Require(IsSerifSyncBackingPixelVisible(BackingRegions[0],
    Marker.Left, Marker.Top, SERIF_ANIMATION_SYNC_SHAPE_SQUARE) and
    not IsSerifSyncBackingPixelVisible(BackingRegions[0],
      Marker.Left, Marker.Top, SERIF_ANIMATION_SYNC_SHAPE_CIRCLE) and
    IsSerifSyncBackingPixelVisible(BackingRegions[0],
      BackingRegions[0].CenterX, BackingRegions[0].CenterY,
      SERIF_ANIMATION_SYNC_SHAPE_CIRCLE),
    'Backing shape mask mismatch.');
  Require(not IsSerifSyncBackingPixelVisible(BackingRegions[0],
    Marker.Left, Marker.Top, SERIF_ANIMATION_SYNC_SHAPE_TRIANGLE) and
    IsSerifSyncBackingPixelVisible(BackingRegions[0],
      BackingRegions[0].CenterX, Marker.Bottom - 1,
      SERIF_ANIMATION_SYNC_SHAPE_TRIANGLE),
    'Triangular backing shape mask mismatch.');
  BackingRegions := CalculateSerifSyncBackingRegions(LineBounds,
    TRect.Create(0, 0, 220, 90), TRect.Create(-10, -10, 230, 100),
    299, 300, False, 100.0, 0.0, 0.0);
  Marker := BackingRegions[0].Bounds;
  Require(Marker.Right = 230,
    'The final frame must be clipped at the last line right pixel.');
  BackingRegions := CalculateSerifSyncBackingRegions(LineBounds,
    TRect.Create(0, 0, 220, 90), TRect.Create(-10, -10, 230, 100),
    149, 300, True, 100.0, 0.0, 0.0);
  Require((Length(BackingRegions) = 2) and
    (BackingRegions[0].Bounds.Left = 10) and
    (BackingRegions[0].Bounds.Right = 110) and
    (BackingRegions[1].Bounds.Left = 30) and
    (BackingRegions[1].Bounds.Right > 30),
    'Backing trail must retain completed lines and extend the current line.');
  Require(IsSerifSyncBackingPixelVisible(BackingRegions[1],
    BackingRegions[1].Bounds.Left, BackingRegions[1].Bounds.Top,
    SERIF_ANIMATION_SYNC_SHAPE_CIRCLE) and
    IsSerifSyncBackingPixelVisible(BackingRegions[1],
      BackingRegions[1].CenterX - 1,
      BackingRegions[1].Bounds.Top,
      SERIF_ANIMATION_SYNC_SHAPE_CIRCLE) and
    not IsSerifSyncBackingPixelVisible(BackingRegions[1],
      BackingRegions[1].Bounds.Right - 1, BackingRegions[1].Bounds.Top,
      SERIF_ANIMATION_SYNC_SHAPE_CIRCLE),
    'A round backing trail must be continuous and retain a round leading cap.');
  BackingRegions := CalculateSerifSyncBackingRegions(LineBounds,
    TRect.Create(0, 0, 220, 90), TRect.Create(-10, -10, 230, 100),
    0, 300, False, 200.0, 5.0, -3.0);
  Require((Length(BackingRegions) = 1) and
    (BackingRegions[0].Bounds.Left = 15) and
    (BackingRegions[0].Bounds.Right = 55) and
    (BackingRegions[0].Bounds.Top = -13) and
    (BackingRegions[0].Bounds.Bottom = 67),
    'Backing size and offsets were not applied to the marker.');
  UnderlineRegions := CalculateSerifSyncUnderlineRegions(LineBounds,
    TRect.Create(0, 0, 220, 90), TRect.Create(-10, -10, 230, 100),
    50, 300, False, 100.0, 0.0, 0.0);
  Require((Length(UnderlineRegions) = 1) and
    (UnderlineRegions[0].Bounds.Left = 40) and
    (UnderlineRegions[0].Bounds.Right = 80) and
    (UnderlineRegions[0].Bounds.Top = 52) and
    (UnderlineRegions[0].Bounds.Bottom = 55),
    'Standard underline marker geometry mismatch.');
  Require(not IsSerifSyncUnderlinePixelVisible(UnderlineRegions[0],
    UnderlineRegions[0].Bounds.Left, UnderlineRegions[0].Bounds.Top,
    SERIF_ANIMATION_SYNC_SHAPE_CIRCLE) and
    IsSerifSyncUnderlinePixelVisible(UnderlineRegions[0],
      UnderlineRegions[0].CenterX, UnderlineRegions[0].CenterY,
      SERIF_ANIMATION_SYNC_SHAPE_CIRCLE),
    'Underline shape mask mismatch.');
  UnderlineRegions := CalculateSerifSyncUnderlineRegions(LineBounds,
    TRect.Create(0, 0, 220, 90), TRect.Create(-10, -10, 230, 100),
    149, 300, True, 100.0, 0.0, 0.0);
  Require((Length(UnderlineRegions) = 2) and
    (UnderlineRegions[0].Bounds.Left = 10) and
    (UnderlineRegions[0].Bounds.Right = 110) and
    (UnderlineRegions[1].Bounds.Left = 30) and
    (UnderlineRegions[1].Bounds.Right > 30),
    'Underline trail must retain completed lines and extend the current line.');
  SetLength(TextUnitBounds, 4);
  TextUnitBounds[0] := TRect.Create(10, 10, 50, 110);
  TextUnitBounds[1] := TRect.Create(55, 10, 140, 110);
  TextUnitBounds[2] := TRect.Empty;
  TextUnitBounds[3] := TRect.Create(160, 10, 300, 110);
  SetLength(CharacterLineBounds, 1);
  CharacterLineBounds[0] := TRect.Create(0, 0, 300, 120);
  Require((CalculateSerifSyncHighlightIndex(Length(TextUnitBounds), 0.3) = 1) and
    (CalculateSerifSyncHighlightRectAtIndex(TextUnitBounds, 1) =
      TextUnitBounds[1]) and
    CalculateSerifSyncHighlightRectAtIndex(TextUnitBounds, 2).IsEmpty,
    'Color sync must use measured text-unit bounds.');
  // 同じ行でも字形の上下端は異なるため、縦基準は行矩形へ揃える。
  TextUnitBounds[1] := TRect.Create(55, 30, 140, 90);
  BackingRegions := CalculateSerifSyncBackingRegions(CharacterLineBounds,
    TextUnitBounds, TRect.Create(0, 0, 300, 110),
    TRect.Create(0, 0, 300, 110), 3, 9, False,
    SERIF_ANIMATION_SYNC_PAINT_CHARACTER, 100.0, 5.0, -3.0);
  Require((Length(BackingRegions) = 1) and
    (BackingRegions[0].CenterX = 102) and
    (BackingRegions[0].CenterY = 57) and
    (BackingRegions[0].Size = 120) and
    not BackingRegions[0].TrailEnabled,
    'Character backing must follow one measured text unit and its offsets.');
  BackingRegions := CalculateSerifSyncBackingRegions(CharacterLineBounds,
    TextUnitBounds, TRect.Create(0, 0, 300, 110),
    TRect.Create(0, 0, 300, 110), 3, 9, True,
    SERIF_ANIMATION_SYNC_PAINT_CHARACTER, 100.0, 0.0, 0.0);
  Require((Length(BackingRegions) = 2) and
    (BackingRegions[0].CenterX = 30) and
    (BackingRegions[1].CenterX = 97) and
    not BackingRegions[0].TrailEnabled and
    BackingRegions[0].TrailCompleted,
    'Character backing maintain must retain separate completed shapes.');
  UnderlineRegions := CalculateSerifSyncUnderlineRegions(CharacterLineBounds,
    TextUnitBounds, TRect.Create(0, 0, 300, 110),
    TRect.Create(0, 0, 300, 110), 3, 9, False,
    SERIF_ANIMATION_SYNC_PAINT_CHARACTER, 100.0, 5.0, -3.0);
  Require((Length(UnderlineRegions) = 1) and
    (UnderlineRegions[0].CenterX = 102) and
    (UnderlineRegions[0].Bounds.Width = 85) and
    (UnderlineRegions[0].Bounds.Top = 119) and
    not UnderlineRegions[0].TrailEnabled,
    'Character underline must use the measured unit width and offsets.');
  UnderlineRegions := CalculateSerifSyncUnderlineRegions(CharacterLineBounds,
    TextUnitBounds, TRect.Create(0, 0, 300, 110),
    TRect.Create(0, 0, 300, 110), 3, 9, True,
    SERIF_ANIMATION_SYNC_PAINT_CHARACTER, 100.0, 0.0, 0.0);
  Require((Length(UnderlineRegions) = 2) and
    (UnderlineRegions[0].Bounds.Width = 40) and
    (UnderlineRegions[1].Bounds.Width = 85),
    'Character underline maintain must retain one marker per text unit.');
  GlowRegions := CalculateSerifSyncFrontRegions(CharacterLineBounds,
    TextUnitBounds, TRect.Create(0, 0, 300, 110),
    TRect.Create(0, 0, 300, 110), 3, 9, True,
    SERIF_ANIMATION_SYNC_PAINT_CHARACTER, 100.0, 0.0, 0.0);
  Require((Length(GlowRegions) = 2) and
    (GlowRegions[0].CenterX = 30) and (GlowRegions[1].CenterX = 97),
    'Character front light must reuse character backing regions.');
  TextUnitBounds[1] := TRect.Create(55, 10, 140, 110);
  SetLength(TextUnitImages, Length(TextUnitBounds));
  TextUnitImages[0] := TTextRenderImage.Create(TextUnitBounds[0]);
  TextUnitImages[1] := TTextRenderImage.Create(TextUnitBounds[1]);
  TextUnitImages[2] := nil;
  TextUnitImages[3] := TTextRenderImage.Create(TextUnitBounds[3]);
  try
    ZoomItems := CalculateSerifSyncZoomItems(TextUnitImages,
      1, 9, False, 120.0, 0.0, 0.0);
    Require((Length(ZoomItems) = 4) and
      (ZoomItems[0].SourceImage = TextUnitImages[0]) and
      (ZoomItems[0].DestinationRect.Width > TextUnitBounds[0].Width) and
      (ZoomItems[0].DestinationRect.Height > TextUnitBounds[0].Height) and
      (ZoomItems[1].DestinationRect = TextUnitBounds[1]),
      'Standard zoom must transform only the current independent text unit.');
    ZoomItems := CalculateSerifSyncZoomItems(TextUnitImages,
      0, 9, False, SERIF_ANIMATION_SYNC_PAINT_CHARACTER,
      120.0, 0.0, 0.0);
    Require((ZoomItems[0].DestinationRect.Width > TextUnitBounds[0].Width) and
      (ZoomItems[1].DestinationRect = TextUnitBounds[1]),
      'Character-unit zoom must apply its completed state immediately.');
    ZoomItems := CalculateSerifSyncZoomItems(TextUnitImages,
      3, 9, True, 120.0, 0.0, 0.0);
    Require((Length(ZoomItems) = 4) and
      (ZoomItems[1].SourceImage = TextUnitImages[1]) and
      (ZoomItems[0].DestinationRect.Width > TextUnitBounds[0].Width) and
      (ZoomItems[1].DestinationRect.Width > TextUnitBounds[1].Width) and
      (ZoomItems[3].DestinationRect = TextUnitBounds[3]),
      'Zoom trail must retain enlarged text units.');
    ZoomItems := CalculateSerifSyncZoomItems(TextUnitImages,
      5, 9, False, 100.0, 0.0, 0.0);
    Require((ZoomItems[2].SourceImage = nil) and
      (ZoomItems[0].DestinationRect = TextUnitBounds[0]) and
      (ZoomItems[1].DestinationRect = TextUnitBounds[1]) and
      (ZoomItems[3].DestinationRect = TextUnitBounds[3]),
      'A space without ink must advance without moving adjacent text.');
    ZoomItems := CalculateSerifSyncZoomItems(TextUnitImages,
      1, 9, False, 100.0, 0.0, 0.0);
    Require(ZoomItems[0].DestinationRect = TextUnitBounds[0],
      'A 100-percent zoom must preserve the original size.');
    ZoomItems := CalculateSerifSyncZoomItems(TextUnitImages,
      1, 9, False, 80.0, 0.0, 0.0);
    Require((ZoomItems[0].DestinationRect.Width < TextUnitBounds[0].Width) and
      (ZoomItems[0].DestinationRect.Height < TextUnitBounds[0].Height),
      'A zoom size below 100 percent must shrink the text unit.');
    JumpItems := CalculateSerifSyncJumpItems(TextUnitImages,
      1, 9, False, 120.0, 0.0, 0.0);
    Require((Length(JumpItems) = 4) and
      (JumpItems[0].DestinationRect.Left = TextUnitBounds[0].Left) and
      (JumpItems[0].DestinationRect.Top = TextUnitBounds[0].Top - 20) and
      (JumpItems[1].DestinationRect = TextUnitBounds[1]),
      'Standard jump must move only the current text unit.');
    JumpItems := CalculateSerifSyncJumpItems(TextUnitImages,
      0, 9, False, SERIF_ANIMATION_SYNC_PAINT_CHARACTER,
      120.0, 0.0, 0.0);
    Require(JumpItems[0].DestinationRect.Top = TextUnitBounds[0].Top - 20,
      'Character-unit jump must apply its completed position immediately.');
    JumpItems := CalculateSerifSyncJumpItems(TextUnitImages,
      2, 9, False, 120.0, 0.0, 0.0);
    Require(JumpItems[0].DestinationRect = TextUnitBounds[0],
      'A standard jump must land before the next text unit starts.');
    JumpItems := CalculateSerifSyncJumpItems(TextUnitImages,
      3, 9, True, 120.0, 0.0, 0.0);
    Require((JumpItems[0].DestinationRect.Top = TextUnitBounds[0].Top - 20) and
      (JumpItems[1].DestinationRect.Top < TextUnitBounds[1].Top) and
      (JumpItems[3].DestinationRect = TextUnitBounds[3]),
      'Jump trail must retain completed text units above their origin.');
    JumpItems := CalculateSerifSyncJumpItems(TextUnitImages,
      5, 9, False, 120.0, 0.0, 0.0);
    Require((JumpItems[2].SourceImage = nil) and
      (JumpItems[0].DestinationRect = TextUnitBounds[0]) and
      (JumpItems[1].DestinationRect = TextUnitBounds[1]) and
      (JumpItems[3].DestinationRect = TextUnitBounds[3]),
      'A jump over a space must not move adjacent text units.');
    JumpItems := CalculateSerifSyncJumpItems(TextUnitImages,
      1, 9, False, 120.0, 5.0, -3.0);
    Require((JumpItems[0].DestinationRect.Left = TextUnitBounds[0].Left + 5) and
      (JumpItems[0].DestinationRect.Top = TextUnitBounds[0].Top - 23),
      'Jump offsets were not applied to the active text unit.');
    JumpItems := CalculateSerifSyncJumpItems(TextUnitImages,
      1, 9, False, 100.0, 0.0, 0.0);
    Require(JumpItems[0].DestinationRect = TextUnitBounds[0],
      'A 100-percent jump must preserve the original position.');
  finally
    TextUnitImages[0].Free;
    TextUnitImages[1].Free;
    TextUnitImages[3].Free;
  end;
  GlowRegions := CalculateSerifSyncFrontRegions(LineBounds,
    TRect.Create(0, 0, 220, 90), TRect.Create(-10, -10, 230, 100),
    50, 300, False, 120.0, 5.0, -3.0);
  Require((Length(GlowRegions) = 1) and
    (GlowRegions[0].Bounds.Height = 48) and
    (GlowRegions[0].CenterX = 65) and
    (GlowRegions[0].CenterY = 27),
    'Front-light geometry must reuse backing size and offsets.');
  GlowRegions := CalculateSerifSyncFrontRegions(LineBounds,
    TRect.Create(0, 0, 220, 90), TRect.Create(-10, -10, 230, 100),
    149, 300, True, 120.0, 0.0, 0.0);
  Require(Length(GlowRegions) = 2,
    'Front-light trail must retain completed lines.');
  GlowPixel.R := 20;
  GlowPixel.G := 30;
  GlowPixel.B := 40;
  GlowPixel.A := 255;
  BlendSerifSyncFrontPixel(Integer($FFFF0000), SERIF_SYNC_FRONT_ALPHA,
    GlowPixel);
  Require((GlowPixel.R > 20) and (GlowPixel.G = 30) and
    (GlowPixel.B = 40) and (GlowPixel.A = 255),
    'Front light must brighten with screen blending without hiding text.');
  BaseImage := TTextRenderImage.Create(TRect.Create(0, 0, 100, 100),
    TRect.Create(0, 0, 100, 100));
  TextGlowImage := TTextRenderImage.Create(TRect.Create(-10, -10, 110, 110),
    TRect.Create(0, 0, 100, 100));
  try
    SetLength(TextGlowUnitImages, 1);
    TextGlowUnitImages[0] := TTextRenderImage.Create(
      TRect.Create(10, 10, 110, 110));
    TextGlowImage.SetTextUnitImages(TextGlowUnitImages);
    TextGlowItems := CalculateSerifSyncTextGlowItems(BaseImage,
      TextGlowImage, 1, 3, False, 100.0, 0.0, 0.0);
    Require((Length(TextGlowItems) = 1) and
      (TextGlowItems[0].DestinationRect = TRect.Create(0, 0, 100, 100)) and
      (Abs(TextGlowItems[0].Opacity - 1.0) < 0.000001),
      'The original text-surface glow must remain independent from front light.');
    TextGlowItems := CalculateSerifSyncTextGlowItems(BaseImage,
      TextGlowImage, 0, 3, False, SERIF_ANIMATION_SYNC_PAINT_CHARACTER,
      100.0, 0.0, 0.0);
    Require((Length(TextGlowItems) = 1) and
      (Abs(TextGlowItems[0].Opacity - 1.0) < 0.000001),
      'Character-unit glow must apply its completed light immediately.');
    TextGlowItems := CalculateSerifSyncTextGlowItems(BaseImage,
      TextGlowImage, 1, 3, False, 80.0, 0.0, 0.0);
    Require((Abs(TextGlowItems[0].Opacity - 0.8) < 0.000001) and
      (Abs(TextGlowItems[0].Brightness - 0.8) < 0.000001),
      'An 80-percent glow must reduce light and text brightness to 0.8.');
    TextGlowItems := CalculateSerifSyncTextGlowItems(BaseImage,
      TextGlowImage, 1, 3, False, 120.0, 0.0, 0.0);
    Require((Abs(TextGlowItems[0].Opacity - 1.2) < 0.000001) and
      (Abs(TextGlowItems[0].Brightness - 1.2) < 0.000001),
      'A 120-percent glow must increase light and text brightness to 1.2.');
  finally
    TextGlowImage.Free;
    BaseImage.Free;
  end;
  Writeln('SerifDraw speech sync tests passed.');
end.
