program SerifDrawFramePreviewTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  PluginFilterSerifDrawSettings in
    'Serif\Plugin\Draw\PluginFilterSerifDrawSettings.pas',
  PluginFilterSerifDrawTextPreviewDrag in
    'Serif\Plugin\Draw\Editor\PluginFilterSerifDrawTextPreviewDrag.pas',
  PluginFilterSerifDrawFramePreview in
    'Serif\Plugin\Draw\Editor\PluginFilterSerifDrawFramePreview.pas',
  PluginFilterSerifDrawFramePreviewDrag in
    'Serif\Plugin\Draw\Editor\PluginFilterSerifDrawFramePreviewDrag.pas',
  PluginFilterSerifDrawTextPreviewLayout in
    'Serif\Plugin\Draw\Editor\PluginFilterSerifDrawTextPreviewLayout.pas',
  PluginFilterSerifDrawTextPreviewHandles in
    'Serif\Plugin\Draw\Editor\PluginFilterSerifDrawTextPreviewHandles.pas';

procedure Require(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Bitmap: TBitmap;
  FrameHeight: Integer;
  FrameDragCurrent: TSerifDrawFrameStyle;
  FrameDragResult: TSerifDrawFrameDragResult;
  FrameDragStart: TSerifDrawFrameStyle;
  FrameRect: TRect;
  FrameWidth: Integer;
  PositionX: Double;
  PositionY: Double;
  OutlineHandle: TRect;
  ShadowHandle: TRect;
  Settings: TSerifDrawSettings;
  SpreadHandle: TRect;
  TabRect: TRect;
  BlurHandle: TRect;
  CornerHandle: TRect;
  DottedDashHandle: TRect;
  DottedGapHandle: TRect;
  InnerPanelHandle: TRect;
  BalloonTip: TPoint;
  TextHandleState: TSerifDrawTextPreviewHandleState;
  TextDragResult: TSerifDrawTextDragResult;
  TextDragStart: TSerifDrawTextDragStart;
  TextLayout: TSerifDrawTextPreviewLayout;
  TextLayoutChanged: TSerifDrawTextPreviewLayout;
  TextStyle: TSerifDrawLayerStyle;
begin
  FrameRect := SerifDrawCommonFrameRect(Rect(100, 50, 1060, 590),
    1920, 1280, 180);
  Require(FrameRect = Rect(260, 275, 900, 365),
    'Centered common frame rectangle mismatch.');

  FrameDragStart := Default(TSerifDrawFrameStyle);
  FrameDragStart.Width := 600;
  FrameDragStart.Height := 200;
  FrameDragStart.TabOffset := 20;
  FrameDragStart.TabWidth := 100;
  FrameDragStart.PositionX := 4;
  FrameDragStart.PositionY := -3;
  FrameDragCurrent := FrameDragStart;
  FrameDragResult := SerifDrawCalculateFrameDrag(sdfhTabWidth,
    FrameDragStart, FrameDragCurrent, Point(100, 100), Point(140, 100),
    2.0, 96, Rect(100, 100, 700, 300), False, False);
  Require(FrameDragResult.Style.TabWidth = 120,
    'Frame tab width drag calculation mismatch.');
  FrameDragResult := SerifDrawCalculateFrameDrag(sdfhMove,
    FrameDragStart, FrameDragCurrent, Point(100, 100), Point(92, 106),
    2.0, 96, Rect(100, 100, 700, 300), False, False);
  Require((FrameDragResult.Style.PositionX = 0) and
    (FrameDragResult.Style.PositionY = 0) and
    FrameDragResult.SnapXActive and FrameDragResult.SnapYActive,
    'Frame position snapping mismatch.');

  TextStyle := Default(TSerifDrawLayerStyle);
  TextStyle.FontSize := 40;
  TextStyle.OutlineBlur := 8;
  TextStyle.OutlineWidth := 10;
  TextStyle.ShadowBlur := 6;
  TextStyle.ShadowOffsetX := 4;
  TextStyle.ShadowOffsetY := 5;
  TextStyle.ShadowSpread := 3;
  TextLayout := SerifDrawTextPreviewLayout(Rect(0, 0, 500, 400),
    Rect(100, 100, 300, 200), Rect(95, 95, 310, 210), 96, 1.0,
    TextStyle);
  Require(TextLayout.OutlineBlurRect = Rect(352, 60, 380, 88),
    'Outline blur handle layout mismatch.');
  Require(TextLayout.OutlineWidthRect = Rect(312, 60, 340, 88),
    'Outline width handle layout mismatch.');
  Require(TextLayout.ShadowBlurRect = Rect(312, 252, 340, 280),
    'Shadow blur handle layout mismatch.');
  Require(TextLayout.ShadowOffsetRect = Rect(312, 212, 340, 240),
    'Shadow offset handle layout mismatch.');
  Require(TextLayout.ShadowSpreadRect = Rect(352, 212, 380, 240),
    'Shadow spread handle layout mismatch.');
  TextStyle.OutlineBlur := 30;
  TextStyle.OutlineWidth := 80;
  TextStyle.ShadowBlur := 50;
  TextStyle.ShadowOffsetX := 60;
  TextStyle.ShadowOffsetY := -60;
  TextStyle.ShadowSpread := 100;
  TextLayoutChanged := SerifDrawTextPreviewLayout(Rect(0, 0, 500, 400),
    Rect(100, 100, 300, 200), Rect(20, 20, 380, 280), 96, 1.0,
    TextStyle);
  Require((TextLayoutChanged.OutlineBlurRect =
    TextLayout.OutlineBlurRect) and
    (TextLayoutChanged.OutlineWidthRect = TextLayout.OutlineWidthRect) and
    (TextLayoutChanged.ShadowBlurRect = TextLayout.ShadowBlurRect) and
    (TextLayoutChanged.ShadowOffsetRect = TextLayout.ShadowOffsetRect) and
    (TextLayoutChanged.ShadowSpreadRect = TextLayout.ShadowSpreadRect),
    'Decoration handles must remain fixed while their values change.');
  Require(((TextLayout.OutlineWidthRect.Top +
    TextLayout.OutlineWidthRect.Bottom) div 2 =
    (TextLayout.OutlineBlurRect.Top +
    TextLayout.OutlineBlurRect.Bottom) div 2) and
    ((TextLayout.ShadowOffsetRect.Left +
    TextLayout.ShadowOffsetRect.Right) div 2 =
    (TextLayout.ShadowBlurRect.Left +
    TextLayout.ShadowBlurRect.Right) div 2) and
    ((TextLayout.ShadowOffsetRect.Top +
    TextLayout.ShadowOffsetRect.Bottom) div 2 =
    (TextLayout.ShadowSpreadRect.Top +
    TextLayout.ShadowSpreadRect.Bottom) div 2),
    'Related decoration handles must align horizontally or vertically.');
  Require(SerifDrawHitTestTextPreview(Point(366, 74), TextLayout, 96) =
    spdmOutlineBlur, 'Outline blur handle hit test mismatch.');
  Require(SerifDrawHitTestTextPreview(Point(100, 100), TextLayout, 96) =
    spdmFontSizeNorthWest, 'North-west handle hit test mismatch.');
  Require(SerifDrawTextPreviewCursor(spdmShadowSpread) = crSizeNWSE,
    'Shadow spread cursor mismatch.');
  Require((SerifDrawTextPreviewCursor(spdmOutlineWidth) = crSizeNESW) and
    (SerifDrawTextPreviewCursor(spdmOutlineBlur) = crSizeNESW),
    'Upper-right decoration cursors must point south-west/north-east.');
  Require((SerifDrawTextPreviewCursor(spdmShadowBlur) = crSizeNWSE) and
    (SerifDrawTextPreviewCursor(spdmShadowOffset) = crSizeAll),
    'Lower-right and shadow position cursors mismatch.');

  TextDragStart := Default(TSerifDrawTextDragStart);
  TextDragStart.Mouse := Point(100, 100);
  TextDragStart.FontSize := 40;
  TextDragStart.OutlineBlur := 30;
  TextDragStart.OutlineWidth := 10;
  TextDragStart.ShadowBlur := 10;
  TextDragStart.ShadowOffsetX := 5;
  TextDragStart.ShadowOffsetY := -5;
  TextDragStart.ShadowSpread := 30;
  TextDragStart.PositionX := 4;
  TextDragStart.PositionY := 18;
  TextDragResult := SerifDrawCalculateTextDrag(spdmFontSizeSouthEast,
    TextDragStart, Point(120, 110), 2.0, False, False, False, 0);
  Require(Abs(TextDragResult.FontSize - 47.5) < 0.001,
    'Font size drag calculation mismatch.');
  TextDragResult := SerifDrawCalculateTextDrag(spdmOutlineWidth,
    TextDragStart, Point(120, 80), 2.0, False, False, False, 0);
  Require(Abs(TextDragResult.OutlineWidth - 35) < 0.001,
    'Upper-right outward drag must increase outline width.');
  TextDragResult := SerifDrawCalculateTextDrag(spdmOutlineBlur,
    TextDragStart, Point(80, 120), 2.0, False, False, False, 0);
  Require(Abs(TextDragResult.OutlineBlur - 5) < 0.001,
    'Upper-right inward drag must decrease outline blur.');
  TextDragResult := SerifDrawCalculateTextDrag(spdmShadowBlur,
    TextDragStart, Point(120, 120), 2.0, False, False, False, 0);
  Require(Abs(TextDragResult.ShadowBlur - 35) < 0.001,
    'Lower-right outward drag must increase shadow blur.');
  TextDragResult := SerifDrawCalculateTextDrag(spdmShadowSpread,
    TextDragStart, Point(80, 80), 2.0, False, False, False, 0);
  Require(Abs(TextDragResult.ShadowSpread - 5) < 0.001,
    'Lower-right inward drag must decrease shadow spread.');
  TextDragResult := SerifDrawCalculateTextDrag(spdmShadowOffset,
    TextDragStart, Point(120, 110), 2.0, False, False, False, 0);
  Require((Abs(TextDragResult.ShadowOffsetX - 30) < 0.001) and
    (Abs(TextDragResult.ShadowOffsetY - 7.5) < 0.001),
    'Shadow offset ratio drag calculation mismatch.');
  TextDragResult := SerifDrawCalculateTextDrag(spdmMove, TextDragStart,
    Point(92, 104), 2.0, True, False, False, 0);
  Require((TextDragResult.PositionX = 0) and
    (TextDragResult.PositionY = 20) and TextDragResult.SnapXActive and
    TextDragResult.SnapYActive,
    'Text position snapping mismatch.');
  SerifDrawFrameLayoutPreset(1920, 1080, 1, FrameWidth, FrameHeight,
    PositionX, PositionY);
  Require((FrameWidth = 1920) and (FrameHeight = 230) and
    (PositionX = 0) and (PositionY = 425),
    'Full frame layout preset mismatch.');
  SerifDrawFrameLayoutPreset(1920, 1080, 2, FrameWidth, FrameHeight,
    PositionX, PositionY);
  Require((FrameWidth = 1650) and (PositionX = 135),
    'Right frame layout preset mismatch.');
  SerifDrawFrameLayoutPreset(1280, 720, 4, FrameWidth, FrameHeight,
    PositionX, PositionY);
  Require((FrameWidth = 920) and (FrameHeight = 153) and
    (PositionX = 0) and (PositionY = 283.5),
    'Scaled middle frame layout preset mismatch.');
  Settings := TSerifDrawSettings.Default;
  FrameDragCurrent := Settings.CommonFrameStyle;
  FrameDragCurrent.Shape := 1;
  FrameDragCurrent.OutlineVisible := False;
  FrameDragCurrent.ShadowVisible := True;
  FrameDragCurrent.ShadowOffsetX := 10;
  FrameDragCurrent.ShadowOffsetY := 10;
  FrameDragCurrent.ShadowSpread := 0;
  FrameDragCurrent.ShadowBlur := 0;
  SerifDrawFrameLayoutPreset(1920, 1080, 1, FrameWidth, FrameHeight,
    PositionX, PositionY);
  SerifDrawFitFrameAppearanceInLayout(FrameDragCurrent, FrameWidth,
    FrameHeight, PositionX, PositionY);
  Require((FrameWidth = 1910) and (FrameHeight = 220) and
    (PositionX = -5) and (PositionY = 420),
    'White legacy frame envelope mismatch.');
  FrameDragCurrent.ShadowVisible := False;
  FrameDragCurrent.OutlineVisible := True;
  FrameDragCurrent.OutlineStyle := 2;
  FrameDragCurrent.OutlineWidth := 8;
  SerifDrawFrameLayoutPreset(1920, 1080, 1, FrameWidth, FrameHeight,
    PositionX, PositionY);
  SerifDrawFitFrameAppearanceInLayout(FrameDragCurrent, FrameWidth,
    FrameHeight, PositionX, PositionY);
  Require((FrameWidth = 1904) and (FrameHeight = 214) and
    (PositionX = 0) and (PositionY = 425),
    'Black legacy neon envelope mismatch.');
  FrameDragCurrent.Shape := 3;
  FrameDragCurrent.OutlineVisible := False;
  FrameDragCurrent.ShadowVisible := True;
  FrameDragCurrent.BalloonTailDirection := 2;
  FrameDragCurrent.BalloonTailLength := 48;
  SerifDrawFrameLayoutPreset(1920, 1080, 4, FrameWidth, FrameHeight,
    PositionX, PositionY);
  SerifDrawFitFrameAppearanceInLayout(FrameDragCurrent, FrameWidth,
    FrameHeight, PositionX, PositionY);
  Require((FrameWidth = 1274) and (FrameHeight = 220) and
    (PositionX = -5) and (PositionY = 420),
    'Speech-balloon legacy frame envelope mismatch.');
  FrameDragCurrent.Shape := 0;
  FrameDragCurrent.Layering := 1;
  SerifDrawFrameLayoutPreset(1920, 1080, 4, FrameWidth, FrameHeight,
    PositionX, PositionY);
  SerifDrawFitFrameAppearanceInLayout(FrameDragCurrent, FrameWidth,
    FrameHeight, PositionX, PositionY);
  Require((FrameWidth = 1380) and (FrameHeight = 230) and
    (PositionX = 0) and (PositionY = 425),
    'Color legacy inner-panel envelope mismatch.');
  Require(SerifDrawHitTestCommonFrame(Point(260, 275), FrameRect, 5) =
    sdfhNorthWest, 'North-west handle hit test failed.');
  Require(SerifDrawHitTestCommonFrame(Point(900, 320), FrameRect, 5) =
    sdfhEast, 'East handle hit test failed.');
  Require(SerifDrawHitTestCommonFrame(Point(580, 320), FrameRect, 5) =
    sdfhMove, 'Frame interior move hit test failed.');
  Require(not SerifDrawFrameAdjustmentVisible(sdfhOutlineWidth,
    False, True), 'Hidden outline must hide its adjustment handle.');
  Require(not SerifDrawFrameAdjustmentVisible(sdfhDottedDashLength,
    False, True), 'Hidden outline must hide dotted adjustment handles.');
  Require(not SerifDrawFrameAdjustmentVisible(sdfhShadowOffset,
    True, False), 'Hidden shadow must hide its adjustment handles.');
  Require(SerifDrawFrameAdjustmentVisible(sdfhOutlineWidth, True, False) and
    SerifDrawFrameAdjustmentVisible(sdfhShadowBlur, False, True) and
    SerifDrawFrameAdjustmentVisible(sdfhCornerRadius, False, False),
    'Visible effects and frame geometry must retain adjustment handles.');
  CornerHandle := SerifDrawFrameCornerRadiusHandleRect(FrameRect, 96,
    32, 0.5);
  Require(CornerHandle = Rect(266, 285, 286, 305),
    'Frame corner radius handle rectangle mismatch.');
  TabRect := SerifDrawFrameTabRect(FrameRect, 250, 64, 24, 0.5);
  Require(TabRect = Rect(272, 275, 397, 307),
    'Frame tab rectangle mismatch.');
  Require(SerifDrawFrameTabOffsetHandleRect(TabRect, 96) =
    Rect(262, 249, 282, 269), 'Tab offset handle mismatch.');
  Require(SerifDrawFrameTabWidthHandleRect(TabRect, 96) =
    Rect(387, 249, 407, 269), 'Tab width handle mismatch.');
  Require(SerifDrawFrameTabHeightHandleRect(TabRect, 96) =
    Rect(324, 297, 344, 317), 'Tab height handle mismatch.');
  BalloonTip := SerifDrawFrameBalloonTipPoint(FrameRect, 0, 40, 60, 0.5);
  Require(BalloonTip = Point(600, 395), 'Balloon tip point mismatch.');
  Require(SerifDrawFrameBalloonTipHandleRect(FrameRect, 96, 0, 40, 60, 0.5) =
    Rect(590, 401, 610, 421), 'Balloon tip handle mismatch.');
  Require(SerifDrawFrameBalloonWidthHandleRect(FrameRect, 96, 0, 40, 100,
    0.5) = Rect(631, 355, 651, 375),
    'Balloon width handle mismatch.');
  Require(SerifDrawFrameBalloonTipPoint(FrameRect, 1, -40, 60, 0.5) =
    Point(560, 245), 'Upper balloon tip point mismatch.');
  Require(SerifDrawFrameBalloonTipPoint(FrameRect, 2, 20, 60, 0.5) =
    Point(230, 330), 'Left balloon tip point mismatch.');
  Require(SerifDrawFrameBalloonTipPoint(FrameRect, 3, -20, 60, 0.5) =
    Point(930, 310), 'Right balloon tip point mismatch.');
  OutlineHandle := SerifDrawFrameOutlineWidthHandleRect(FrameRect, 96);
  Require(OutlineHandle = Rect(908, 239, 936, 267),
    'Frame outline width handle rectangle mismatch.');
  DottedDashHandle := SerifDrawFrameDottedDashHandleRect(OutlineHandle, 96);
  DottedGapHandle := SerifDrawFrameDottedGapHandleRect(OutlineHandle, 96);
  Require(DottedDashHandle = Rect(874, 239, 902, 267),
    'Dotted dash length handle mismatch.');
  Require(DottedGapHandle = Rect(840, 239, 868, 267),
    'Dotted gap length handle mismatch.');
  InnerPanelHandle := SerifDrawFrameInnerPanelInsetXHandleRect(FrameRect,
    96, 28, 0.5);
  Require(InnerPanelHandle = Rect(264, 310, 284, 330),
    'Inner panel horizontal inset handle mismatch.');
  InnerPanelHandle := SerifDrawFrameInnerPanelInsetYHandleRect(FrameRect,
    96, 20, 0.5);
  Require(InnerPanelHandle = Rect(570, 275, 590, 295),
    'Inner panel vertical inset handle mismatch.');
  InnerPanelHandle := SerifDrawFrameInnerPanelRadiusHandleRect(FrameRect,
    96, 28, 20, 16, 0.5);
  Require(InnerPanelHandle = Rect(274, 275, 294, 295),
    'Inner panel radius handle mismatch.');
  ShadowHandle := SerifDrawFrameShadowOffsetHandleRect(FrameRect, 96,
    -12, 20);
  Require(ShadowHandle = Rect(896, 393, 924, 421),
    'Frame shadow offset handle rectangle mismatch.');
  SpreadHandle := SerifDrawFrameShadowSpreadHandleRect(ShadowHandle, 96, 6);
  Require(SpreadHandle = Rect(938, 393, 966, 421),
    'Frame shadow spread handle rectangle mismatch.');
  BlurHandle := SerifDrawFrameShadowBlurHandleRect(ShadowHandle, 96, 6);
  Require(BlurHandle = Rect(854, 393, 882, 421),
    'Frame shadow blur handle rectangle mismatch.');
  FrameRect := SerifDrawCommonFrameRect(Rect(100, 50, 1060, 590),
    1920, 1280, 180, 40, -20);
  Require(FrameRect = Rect(280, 265, 920, 355),
    'Common frame position offset mismatch.');

  SerifDrawResizeCommonFrame(sdfhEast, 1280, 180, 20, 0, 0.5,
    FrameWidth, FrameHeight);
  Require((FrameWidth = 1360) and (FrameHeight = 180),
    'Centered east resize mismatch.');
  SerifDrawResizeCommonFrame(sdfhNorthWest, 1280, 180, -20, -10, 0.5,
    FrameWidth, FrameHeight);
  Require((FrameWidth = 1360) and (FrameHeight = 220),
    'Centered corner resize mismatch.');
  Bitmap := TBitmap.Create;
  try
    Bitmap.SetSize(320, 240);
    Bitmap.Canvas.Brush.Color := clBlack;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    DrawSerifDrawCommonFrameAppearance(Bitmap.Canvas,
      Rect(20, 30, 80, 70), 96,
      2, 6, 20, 10, 5,
      0, 0, 20, 15,
      0, 10, 8, 4,
      6, 1, 4, 4,
      0, 0, 0, 0,
      True, True, False,
      $FFFFFFFF, $FF00FF00, $FF0000FF, $FFFFFFFF, $FF000000);
    Require(Bitmap.Canvas.Pixels[45, 40] = clLime,
      'Preview double-line tab interrupted the outer attachment line.');
    Require(Bitmap.Canvas.Pixels[41, 44] = clBlue,
      'Preview double-line tab interrupted the inner attachment line.');
    Bitmap.Canvas.Brush.Color := clBlack;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    DrawSerifDrawCommonFrameAppearance(Bitmap.Canvas,
      Rect(20, 30, 80, 70), 96,
      2, 6, 20, 10, 5,
      0, 0, 20, 15,
      0, 10, 8, 4,
      6, 3, 4, 4,
      0, 0, 0, 0,
      False, True, False,
      $FFFFFFFF, $FF00FF00, $FF0000FF, $FFFFFFFF, $FF000000);
    Require(Bitmap.Canvas.Pixels[46, 40] = clLime,
      'Preview dotted tab body top did not render its dash segment.');
    Require(Bitmap.Canvas.Pixels[48, 40] = clBlack,
      'Preview dotted tab body top was rendered as a solid line.');
    Bitmap.Canvas.Brush.Color := clBlack;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    DrawSerifDrawCommonFrameAppearance(Bitmap.Canvas,
      Rect(20, 30, 80, 39), 96,
      0, 0, 20, 10, 5,
      0, 0, 20, 15,
      0, 10, 8, 4,
      0, 0, 4, 4,
      0, 0, 0, 0,
      True, False, False,
      $FF808080, $FF00FF00, $FF0000FF, $FFFFFFFF, $FF000000,
      SERIF_FRAME_FILL_VERTICAL_GRADIENT, 50);
    Require((Bitmap.Canvas.Pixels[40, 30] = TColor($00C0C0C0)) and
      (Bitmap.Canvas.Pixels[40, 34] = TColor($00808080)) and
      (Bitmap.Canvas.Pixels[40, 38] = TColor($00404040)),
      'Preview vertical gradient did not match the raster gradient.');
    Bitmap.Canvas.Brush.Color := clBlack;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    TextHandleState := System.Default(TSerifDrawTextPreviewHandleState);
    TextHandleState.Dpi := 96;
    TextHandleState.LayoutRect := Rect(50, 50, 180, 140);
    TextHandleState.OutlineBlurRect := Rect(10, 10, 40, 40);
    TextHandleState.OutlineWidthRect := Rect(200, 20, 240, 60);
    TextHandleState.ShadowBlurRect := Rect(10, 160, 50, 200);
    TextHandleState.ShadowOffsetRect := Rect(200, 160, 240, 200);
    TextHandleState.ShadowSpreadRect := Rect(260, 160, 300, 200);
    TextHandleState.ActiveHandle := sdthOutlineWidth;
    DrawSerifDrawTextPreviewHandles(Bitmap.Canvas, TextHandleState);
    Require(Bitmap.Canvas.Pixels[100, 50] = clYellow,
      'Text preview selection guide was not drawn.');
    Require(Bitmap.Canvas.Pixels[200, 40] = clAqua,
      'Active text decoration handle was not highlighted.');
  finally
    Bitmap.Free;
  end;
  Writeln('SerifDraw frame preview tests passed.');
end.
