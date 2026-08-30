unit PluginFilterSerifDrawFrameRaster;

// 保存済み枠設定をBGRAピクセル配列へ合成する実出力処理を担当する。

interface

uses
  System.SysUtils,
  PluginFilterSerifDrawSettings;

// FrameKindが共通枠の場合だけ、Pixelsへ共通枠をアルファ合成する。
procedure CompositeSerifDrawCommonFrame(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer;
  const Settings: TSerifDrawSettings);
// FrameKindに応じて最新配役の共通枠またはキャラ別枠を合成する。
procedure CompositeSerifDrawFrames(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer; const Settings: TSerifDrawSettings;
  const ActiveRoleNames: array of string);

implementation

uses
  System.Math,
  System.Types,
  TextRendererTypes;

procedure BlendPixel(const Source: TTextRenderPixel;
  var Destination: TTextRenderPixel);
var
  AlphaDenominator: Cardinal;
  DestinationAlpha: Cardinal;
  SourceAlpha: Cardinal;
begin
  SourceAlpha := Source.A;
  if SourceAlpha = 0 then
    Exit;
  if SourceAlpha = 255 then
  begin
    Destination := Source;
    Exit;
  end;
  DestinationAlpha := Destination.A;
  AlphaDenominator := SourceAlpha * 255 +
    DestinationAlpha * (255 - SourceAlpha);
  if AlphaDenominator = 0 then
    Exit;
  Destination.R := (Cardinal(Source.R) * SourceAlpha * 255 +
    Cardinal(Destination.R) * DestinationAlpha * (255 - SourceAlpha) +
    AlphaDenominator div 2) div AlphaDenominator;
  Destination.G := (Cardinal(Source.G) * SourceAlpha * 255 +
    Cardinal(Destination.G) * DestinationAlpha * (255 - SourceAlpha) +
    AlphaDenominator div 2) div AlphaDenominator;
  Destination.B := (Cardinal(Source.B) * SourceAlpha * 255 +
    Cardinal(Destination.B) * DestinationAlpha * (255 - SourceAlpha) +
    AlphaDenominator div 2) div AlphaDenominator;
  Destination.A := (AlphaDenominator + 127) div 255;
end;

function PixelFromArgb(const Color: Cardinal;
  const Opacity: Byte): TTextRenderPixel;
begin
  Result.A := ((Color shr 24) * Cardinal(Opacity) + 127) div 255;
  Result.R := (Color shr 16) and $FF;
  Result.G := (Color shr 8) and $FF;
  Result.B := Color and $FF;
end;

procedure FillRect(var Pixels: TBytes; const ImageWidth, ImageHeight: Integer;
  const Rect: TRect; const Pixel: TTextRenderPixel);
var
  Clipped: TRect;
  Destination: PTextRenderPixel;
  X: Integer;
  Y: Integer;
begin
  Clipped := TRect.Intersect(Rect, System.Types.Rect(0, 0,
    ImageWidth, ImageHeight));
  if (Clipped.Width <= 0) or (Clipped.Height <= 0) then
    Exit;
  for Y := Clipped.Top to Clipped.Bottom - 1 do
  begin
    Destination := PTextRenderPixel(@Pixels[0]);
    Inc(Destination, NativeInt(Y) * ImageWidth + Clipped.Left);
    for X := Clipped.Left to Clipped.Right - 1 do
    begin
      BlendPixel(Pixel, Destination^);
      Inc(Destination);
    end;
  end;
end;

procedure FillRectRing(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer; const OuterRect,
  InnerRect: TRect; const Pixel: TTextRenderPixel);
begin
  FillRect(Pixels, ImageWidth, ImageHeight,
    Rect(OuterRect.Left, OuterRect.Top, OuterRect.Right, InnerRect.Top),
    Pixel);
  FillRect(Pixels, ImageWidth, ImageHeight,
    Rect(OuterRect.Left, InnerRect.Bottom, OuterRect.Right,
      OuterRect.Bottom), Pixel);
  FillRect(Pixels, ImageWidth, ImageHeight,
    Rect(OuterRect.Left, InnerRect.Top, InnerRect.Left, InnerRect.Bottom),
    Pixel);
  FillRect(Pixels, ImageWidth, ImageHeight,
    Rect(InnerRect.Right, InnerRect.Top, OuterRect.Right, InnerRect.Bottom),
    Pixel);
end;

function PointInRoundedRect(const X, Y: Integer; const Rect: TRect;
  const Radius: Integer): Boolean;
var
  CenterX: Integer;
  CenterY: Integer;
  DeltaX: Int64;
  DeltaY: Int64;
  EffectiveRadius: Integer;
  Radius2: Int64;
begin
  Result := False;
  if (X < Rect.Left) or (X >= Rect.Right) or (Y < Rect.Top) or
    (Y >= Rect.Bottom) then
    Exit;
  EffectiveRadius := Min(Max(0, Radius),
    Min(Rect.Width, Rect.Height) div 2);
  if (EffectiveRadius <= 0) or
    ((X >= Rect.Left + EffectiveRadius) and
      (X < Rect.Right - EffectiveRadius)) or
    ((Y >= Rect.Top + EffectiveRadius) and
      (Y < Rect.Bottom - EffectiveRadius)) then
    Exit(True);
  if X < Rect.Left + EffectiveRadius then
    CenterX := 2 * (Rect.Left + EffectiveRadius)
  else
    CenterX := 2 * (Rect.Right - EffectiveRadius);
  if Y < Rect.Top + EffectiveRadius then
    CenterY := 2 * (Rect.Top + EffectiveRadius)
  else
    CenterY := 2 * (Rect.Bottom - EffectiveRadius);
  DeltaX := (2 * X + 1) - CenterX;
  DeltaY := (2 * Y + 1) - CenterY;
  Radius2 := Int64(2 * EffectiveRadius) * (2 * EffectiveRadius);
  Result := DeltaX * DeltaX + DeltaY * DeltaY <= Radius2;
end;

procedure FillRoundedRect(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer; const Rect: TRect;
  const Radius: Integer; const Pixel: TTextRenderPixel);
var
  Clipped: TRect;
  Destination: PTextRenderPixel;
  X: Integer;
  Y: Integer;
begin
  if Radius <= 0 then
  begin
    FillRect(Pixels, ImageWidth, ImageHeight, Rect, Pixel);
    Exit;
  end;
  Clipped := TRect.Intersect(Rect, System.Types.Rect(0, 0,
    ImageWidth, ImageHeight));
  for Y := Clipped.Top to Clipped.Bottom - 1 do
  begin
    Destination := PTextRenderPixel(@Pixels[0]);
    Inc(Destination, NativeInt(Y) * ImageWidth + Clipped.Left);
    for X := Clipped.Left to Clipped.Right - 1 do
    begin
      if PointInRoundedRect(X, Y, Rect, Radius) then
        BlendPixel(Pixel, Destination^);
      Inc(Destination);
    end;
  end;
end;

procedure FillRoundedRectRing(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer; const OuterRect,
  InnerRect: TRect; const OuterRadius, InnerRadius: Integer;
  const Pixel: TTextRenderPixel);
var
  Clipped: TRect;
  Destination: PTextRenderPixel;
  X: Integer;
  Y: Integer;
begin
  if OuterRadius <= 0 then
  begin
    FillRectRing(Pixels, ImageWidth, ImageHeight, OuterRect, InnerRect,
      Pixel);
    Exit;
  end;
  Clipped := TRect.Intersect(OuterRect, System.Types.Rect(0, 0,
    ImageWidth, ImageHeight));
  for Y := Clipped.Top to Clipped.Bottom - 1 do
  begin
    Destination := PTextRenderPixel(@Pixels[0]);
    Inc(Destination, NativeInt(Y) * ImageWidth + Clipped.Left);
    for X := Clipped.Left to Clipped.Right - 1 do
    begin
      if PointInRoundedRect(X, Y, OuterRect, OuterRadius) and
        not PointInRoundedRect(X, Y, InnerRect, InnerRadius) then
        BlendPixel(Pixel, Destination^);
      Inc(Destination);
    end;
  end;
end;

function PointInFrameShape(const X, Y: Integer; const Rect: TRect;
  const Style: TSerifDrawFrameStyle; const Radius: Integer): Boolean;
var
  BodyRect: TRect;
  Cross1: Int64;
  Cross2: Int64;
  Cross3: Int64;
  EffectiveTabWidth: Integer;
  ShapeInset: Integer;
  TabRect: TRect;
  TailCenter: Integer;
  TailPoints: array[0..2] of TPoint;
begin
  if Style.Shape = 2 then
  begin
    // 内周でもタブ右端を同じ距離だけ内側へ寄せ、接合部の輪郭を連続させる。
    ShapeInset := (Style.Width - Rect.Width) div 2;
    EffectiveTabWidth := Max(1, Style.TabWidth - ShapeInset * 2);
    BodyRect := Rect;
    BodyRect.Top := Min(BodyRect.Bottom - 1,
      BodyRect.Top + EnsureRange(Style.TabHeight, 1,
        Max(1, BodyRect.Height - 1)));
    TabRect := System.Types.Rect(Rect.Left + EnsureRange(Style.TabOffset, 0,
      Max(0, Rect.Width - 1)), Rect.Top, 0, 0);
    TabRect.Right := Min(Rect.Right, TabRect.Left + EffectiveTabWidth);
    TabRect.Bottom := Min(Rect.Bottom, BodyRect.Top + Max(14, Radius));
    Result := PointInRoundedRect(X, Y, BodyRect, Radius) or
      PointInRoundedRect(X, Y, TabRect, Radius);
    Exit;
  end;
  if Style.Shape = 3 then
  begin
    if PointInRoundedRect(X, Y, Rect, Radius) then
      Exit(True);
    if Style.BalloonTailDirection in [2, 3] then
    begin
      TailCenter := EnsureRange((Rect.Top + Rect.Bottom) div 2 +
        Style.BalloonTailPosition, Rect.Top, Rect.Bottom);
      if Style.BalloonTailDirection = 2 then BodyRect.Left := Rect.Left
      else BodyRect.Left := Rect.Right - 1;
      TailPoints[0] := Point(BodyRect.Left, EnsureRange(TailCenter -
        Max(1, Style.BalloonTailWidth) div 2, Rect.Top, Rect.Bottom));
      TailPoints[1] := Point(BodyRect.Left, EnsureRange(TailCenter +
        Max(1, Style.BalloonTailWidth) div 2, Rect.Top, Rect.Bottom));
      if Style.BalloonTailDirection = 2 then
        TailPoints[2] := Point(Rect.Left - Max(1, Style.BalloonTailLength),
          TailCenter)
      else
        TailPoints[2] := Point(Rect.Right + Max(1, Style.BalloonTailLength),
          TailCenter);
    end
    else
    begin
      TailCenter := EnsureRange((Rect.Left + Rect.Right) div 2 +
        Style.BalloonTailPosition, Rect.Left, Rect.Right);
      if Style.BalloonTailDirection = 1 then BodyRect.Top := Rect.Top
      else BodyRect.Top := Rect.Bottom - 1;
      TailPoints[0] := Point(EnsureRange(TailCenter - Max(1,
        Style.BalloonTailWidth) div 2, Rect.Left, Rect.Right), BodyRect.Top);
      TailPoints[1] := Point(EnsureRange(TailCenter + Max(1,
        Style.BalloonTailWidth) div 2, Rect.Left, Rect.Right), BodyRect.Top);
      if Style.BalloonTailDirection = 1 then
        TailPoints[2] := Point(TailCenter,
          Rect.Top - Max(1, Style.BalloonTailLength))
      else
        TailPoints[2] := Point(TailCenter,
          Rect.Bottom + Max(1, Style.BalloonTailLength));
    end;
    Cross1 := Int64(TailPoints[1].X - TailPoints[0].X) *
      (Y - TailPoints[0].Y) - Int64(TailPoints[1].Y - TailPoints[0].Y) *
      (X - TailPoints[0].X);
    Cross2 := Int64(TailPoints[2].X - TailPoints[1].X) *
      (Y - TailPoints[1].Y) - Int64(TailPoints[2].Y - TailPoints[1].Y) *
      (X - TailPoints[1].X);
    Cross3 := Int64(TailPoints[0].X - TailPoints[2].X) *
      (Y - TailPoints[2].Y) - Int64(TailPoints[0].Y - TailPoints[2].Y) *
      (X - TailPoints[2].X);
    Result := ((Cross1 >= 0) and (Cross2 >= 0) and (Cross3 >= 0)) or
      ((Cross1 <= 0) and (Cross2 <= 0) and (Cross3 <= 0));
    Exit;
  end;
  Result := PointInRoundedRect(X, Y, Rect,
    IfThen(Style.Shape = 1, Radius, 0));
end;

procedure FillFrameShape(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer; const Rect: TRect;
  const Style: TSerifDrawFrameStyle; const Radius: Integer;
  const Pixel: TTextRenderPixel;
  const FillMode: Integer = SERIF_FRAME_FILL_SOLID;
  const GradientStrength: Integer = 0);
var
  BaseColor: Cardinal;
  Clipped: TRect;
  Destination: PTextRenderPixel;
  RowPixel: TTextRenderPixel;
  X: Integer;
  Y: Integer;
begin
  BaseColor := (Cardinal(Pixel.A) shl 24) or (Cardinal(Pixel.R) shl 16) or
    (Cardinal(Pixel.G) shl 8) or Cardinal(Pixel.B);
  Clipped := Rect;
  if Style.Shape = 3 then
    case Style.BalloonTailDirection of
      1: Clipped.Top := Clipped.Top - Max(1, Style.BalloonTailLength);
      2: Clipped.Left := Clipped.Left - Max(1, Style.BalloonTailLength);
      3: Clipped.Right := Clipped.Right + Max(1, Style.BalloonTailLength);
    else
      Clipped.Bottom := Clipped.Bottom + Max(1, Style.BalloonTailLength);
    end;
  Clipped := TRect.Intersect(Clipped, System.Types.Rect(0, 0,
    ImageWidth, ImageHeight));
  for Y := Clipped.Top to Clipped.Bottom - 1 do
  begin
    RowPixel := PixelFromArgb(SerifDrawFrameGradientColor(BaseColor,
      FillMode, GradientStrength, Y, Rect.Top, Rect.Bottom), 255);
    Destination := PTextRenderPixel(@Pixels[0]);
    Inc(Destination, NativeInt(Y) * ImageWidth + Clipped.Left);
    for X := Clipped.Left to Clipped.Right - 1 do
    begin
      if PointInFrameShape(X, Y, Rect, Style, Radius) then
        BlendPixel(RowPixel, Destination^);
      Inc(Destination);
    end;
  end;
end;

procedure FillFrameShapeRing(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer; const OuterRect,
  InnerRect: TRect; const Style: TSerifDrawFrameStyle;
  const OuterRadius, InnerRadius: Integer; const Pixel: TTextRenderPixel);
var
  Clipped: TRect;
  Destination: PTextRenderPixel;
  X: Integer;
  Y: Integer;
begin
  Clipped := OuterRect;
  if Style.Shape = 3 then
    case Style.BalloonTailDirection of
      1: Clipped.Top := Clipped.Top - Max(1, Style.BalloonTailLength);
      2: Clipped.Left := Clipped.Left - Max(1, Style.BalloonTailLength);
      3: Clipped.Right := Clipped.Right + Max(1, Style.BalloonTailLength);
    else
      Clipped.Bottom := Clipped.Bottom + Max(1, Style.BalloonTailLength);
    end;
  Clipped := TRect.Intersect(Clipped, System.Types.Rect(0, 0,
    ImageWidth, ImageHeight));
  for Y := Clipped.Top to Clipped.Bottom - 1 do
  begin
    Destination := PTextRenderPixel(@Pixels[0]);
    Inc(Destination, NativeInt(Y) * ImageWidth + Clipped.Left);
    for X := Clipped.Left to Clipped.Right - 1 do
    begin
      if PointInFrameShape(X, Y, OuterRect, Style, OuterRadius) and
        not PointInFrameShape(X, Y, InnerRect, Style, InnerRadius) then
        BlendPixel(Pixel, Destination^);
      Inc(Destination);
    end;
  end;
end;

procedure FillFrameShapeDottedRing(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer; const OuterRect,
  InnerRect: TRect; const Style: TSerifDrawFrameStyle;
  const OuterRadius, InnerRadius, DashLength, GapLength: Integer;
  const Pixel: TTextRenderPixel);
var
  Clipped: TRect;
  Destination: PTextRenderPixel;
  InnerBodyTop: Integer;
  OuterBodyTop: Integer;
  PatternOffset: Integer;
  X: Integer;
  Y: Integer;
begin
  OuterBodyTop := 0;
  InnerBodyTop := 0;
  if Style.Shape = 2 then
  begin
    // タブより一段下の本体上辺にも、横方向のダッシュ位相を適用する。
    OuterBodyTop := Min(OuterRect.Bottom, OuterRect.Top +
      EnsureRange(Style.TabHeight, 1, Max(1, OuterRect.Height - 1)));
    InnerBodyTop := Min(InnerRect.Bottom, InnerRect.Top +
      EnsureRange(Style.TabHeight, 1, Max(1, InnerRect.Height - 1)));
  end;
  Clipped := OuterRect;
  if Style.Shape = 3 then
    case Style.BalloonTailDirection of
      1: Clipped.Top := Clipped.Top - Max(1, Style.BalloonTailLength);
      2: Clipped.Left := Clipped.Left - Max(1, Style.BalloonTailLength);
      3: Clipped.Right := Clipped.Right + Max(1, Style.BalloonTailLength);
    else
      Clipped.Bottom := Clipped.Bottom + Max(1, Style.BalloonTailLength);
    end;
  Clipped := TRect.Intersect(Clipped, System.Types.Rect(0, 0,
    ImageWidth, ImageHeight));
  for Y := Clipped.Top to Clipped.Bottom - 1 do
  begin
    Destination := PTextRenderPixel(@Pixels[0]);
    Inc(Destination, NativeInt(Y) * ImageWidth + Clipped.Left);
    for X := Clipped.Left to Clipped.Right - 1 do
    begin
      if PointInFrameShape(X, Y, OuterRect, Style, OuterRadius) and
        not PointInFrameShape(X, Y, InnerRect, Style, InnerRadius) then
      begin
        if (Y < InnerRect.Top) or (Y >= InnerRect.Bottom) or
          ((Style.Shape = 2) and (Y >= OuterBodyTop) and
           (Y < InnerBodyTop)) then
          PatternOffset := X - OuterRect.Left
        else
          PatternOffset := Y - OuterRect.Top;
        PatternOffset := PatternOffset mod Max(1,
          DashLength + GapLength);
        if (PatternOffset >= 0) and (PatternOffset < DashLength) then
          BlendPixel(Pixel, Destination^);
      end;
      Inc(Destination);
    end;
  end;
end;

procedure CompositeFrameStyle(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer;
  const Style: TSerifDrawFrameStyle);
var
  CornerRadius: Integer;
  FrameRect: TRect;
  GlowDistance: Integer;
  InnerOutlineRect: TRect;
  InnerShadowRect: TRect;
  InnerPanelRect: TRect;
  InnerPanelRadius: Integer;
  InnerPanelStyle: TSerifDrawFrameStyle;
  OuterOutlineRect: TRect;
  OutlineLineWidth: Integer;
  OutlineWidth: Integer;
  RingOpacity: Byte;

  procedure DrawShadow(const TargetRect: TRect;
    const TargetStyle: TSerifDrawFrameStyle; const TargetRadius: Integer);
  var
    Distance: Integer;
    InnerRect: TRect;
    OuterRect: TRect;
    Opacity: Byte;
    Radius: Integer;
    Rect: TRect;
  begin
    Rect := TargetRect;
    InflateRect(Rect, Round(TargetStyle.ShadowSpread),
      Round(TargetStyle.ShadowSpread));
    OffsetRect(Rect, Round(TargetStyle.ShadowOffsetX),
      Round(TargetStyle.ShadowOffsetY));
    Radius := EnsureRange(Round(TargetStyle.ShadowBlur), 0, 500);
    for Distance := Radius downto 1 do
    begin
      OuterRect := Rect;
      InflateRect(OuterRect, Distance, Distance);
      InnerRect := Rect;
      InflateRect(InnerRect, Distance - 1, Distance - 1);
      Opacity := EnsureRange(Round(255 *
        (Radius - Distance + 1) / (Radius + 1)), 0, 255);
      FillFrameShapeRing(Pixels, ImageWidth, ImageHeight, OuterRect,
        InnerRect, TargetStyle,
        TargetRadius + Round(TargetStyle.ShadowSpread) + Distance,
        TargetRadius + Round(TargetStyle.ShadowSpread) + Distance - 1,
        PixelFromArgb(TargetStyle.ShadowColor, Opacity));
    end;
    FillFrameShape(Pixels, ImageWidth, ImageHeight, Rect, TargetStyle,
      TargetRadius + Round(TargetStyle.ShadowSpread),
      PixelFromArgb(TargetStyle.ShadowColor, 255));
  end;
begin
  if (ImageWidth <= 0) or (ImageHeight <= 0) or
    (Length(Pixels) < NativeInt(ImageWidth) * ImageHeight *
      SizeOf(TTextRenderPixel)) then
    Exit;
  FrameRect.Left := Round(ImageWidth * 0.5 + Style.PositionX -
    Style.Width * 0.5);
  FrameRect.Top := Round(ImageHeight * 0.5 + Style.PositionY -
    Style.Height * 0.5);
  FrameRect.Right := FrameRect.Left + Style.Width;
  FrameRect.Bottom := FrameRect.Top + Style.Height;
  if Style.Shape in [1, 2, 3] then
    CornerRadius := EnsureRange(Style.CornerRadius, 0,
      Min(FrameRect.Width, FrameRect.Height) div 2)
  else
    CornerRadius := 0;

  InnerPanelRect := FrameRect;
  InflateRect(InnerPanelRect, -Style.InnerPanelInsetX,
    -Style.InnerPanelInsetY);
  InnerPanelStyle := Style;
  InnerPanelStyle.Shape := 1;
  if Style.ShadowVisible and ((Style.Layering <> 1) or
    (InnerPanelRect.Width <= 0) or (InnerPanelRect.Height <= 0)) then
    DrawShadow(FrameRect, Style, CornerRadius);
  if Style.FillVisible then
    FillFrameShape(Pixels, ImageWidth, ImageHeight, FrameRect, Style,
      CornerRadius,
      PixelFromArgb(Style.FillColor, 255), Style.FillMode,
      Style.GradientStrength);
  if Style.Layering = 1 then
  begin
    if (InnerPanelRect.Width > 0) and (InnerPanelRect.Height > 0) then
    begin
      InnerPanelRadius := Min(Style.InnerPanelRadius, Min(InnerPanelRect.Width,
        InnerPanelRect.Height) div 2);
      if Style.ShadowVisible then
        DrawShadow(InnerPanelRect, InnerPanelStyle, InnerPanelRadius);
      FillFrameShape(Pixels, ImageWidth, ImageHeight, InnerPanelRect,
        InnerPanelStyle, InnerPanelRadius,
        PixelFromArgb(Style.InnerPanelColor, 255), Style.FillMode,
        Style.GradientStrength);
    end;
  end;
  if Style.OutlineVisible then
  begin
    OutlineWidth := Min(Style.OutlineWidth,
      Min(FrameRect.Width, FrameRect.Height) div 2);
    if OutlineWidth <= 0 then
      Exit;
    if Style.OutlineStyle = 3 then
    begin
      InnerOutlineRect := FrameRect;
      InflateRect(InnerOutlineRect, -OutlineWidth, -OutlineWidth);
      FillFrameShapeDottedRing(Pixels, ImageWidth, ImageHeight, FrameRect,
        InnerOutlineRect, Style, CornerRadius,
        Max(0, CornerRadius - OutlineWidth),
        Max(1, Style.DottedDashLength), Max(1, Style.DottedGapLength),
        PixelFromArgb(Style.OutlineColor, 255));
    end
    else if Style.OutlineStyle = 2 then
    begin
      for GlowDistance := OutlineWidth downto 1 do
      begin
        OuterOutlineRect := FrameRect;
        InflateRect(OuterOutlineRect, GlowDistance, GlowDistance);
        InnerOutlineRect := FrameRect;
        InflateRect(InnerOutlineRect, GlowDistance - 1, GlowDistance - 1);
        RingOpacity := EnsureRange(Round(255 *
          (OutlineWidth - GlowDistance + 1) / (OutlineWidth + 1)), 0, 255);
        FillFrameShapeRing(Pixels, ImageWidth, ImageHeight, OuterOutlineRect,
          InnerOutlineRect, Style, CornerRadius + GlowDistance,
          CornerRadius + GlowDistance - 1,
          PixelFromArgb(Style.OutlineColor, RingOpacity));
      end;
      OutlineLineWidth := Max(1, OutlineWidth div 3);
      InnerOutlineRect := FrameRect;
      InflateRect(InnerOutlineRect, -OutlineLineWidth, -OutlineLineWidth);
      FillFrameShapeRing(Pixels, ImageWidth, ImageHeight, FrameRect,
        InnerOutlineRect, Style, CornerRadius,
        Max(0, CornerRadius - OutlineLineWidth),
        PixelFromArgb(Style.InnerOutlineColor, 255));
    end
    else if (Style.OutlineStyle = 1) and (OutlineWidth >= 3) then
    begin
      OutlineLineWidth := Max(1, OutlineWidth div 3);
      InnerOutlineRect := FrameRect;
      InflateRect(InnerOutlineRect, -OutlineLineWidth, -OutlineLineWidth);
      FillFrameShapeRing(Pixels, ImageWidth, ImageHeight, FrameRect,
        InnerOutlineRect, Style, CornerRadius,
        Max(0, CornerRadius - OutlineLineWidth),
        PixelFromArgb(Style.OutlineColor, 255));
      OuterOutlineRect := FrameRect;
      InflateRect(OuterOutlineRect, -(OutlineWidth - OutlineLineWidth),
        -(OutlineWidth - OutlineLineWidth));
      InnerOutlineRect := FrameRect;
      InflateRect(InnerOutlineRect, -OutlineWidth, -OutlineWidth);
      FillFrameShapeRing(Pixels, ImageWidth, ImageHeight, OuterOutlineRect,
        InnerOutlineRect, Style,
        Max(0, CornerRadius - OutlineWidth + OutlineLineWidth),
        Max(0, CornerRadius - OutlineWidth),
        PixelFromArgb(Style.InnerOutlineColor, 255));
    end
    else
    begin
      InnerShadowRect := FrameRect;
      InflateRect(InnerShadowRect, -OutlineWidth, -OutlineWidth);
      FillFrameShapeRing(Pixels, ImageWidth, ImageHeight, FrameRect,
        InnerShadowRect, Style, CornerRadius,
        Max(0, CornerRadius - OutlineWidth),
        PixelFromArgb(Style.OutlineColor, 255));
    end;
  end;
end;

procedure CompositeSerifDrawCommonFrame(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer;
  const Settings: TSerifDrawSettings);
begin
  if Settings.FrameKind <> 1 then
    Exit;
  CompositeFrameStyle(Pixels, ImageWidth, ImageHeight,
    Settings.ResolveCommonFrameAppearance(''));
end;

procedure CompositeSerifDrawFrames(var Pixels: TBytes;
  const ImageWidth, ImageHeight: Integer; const Settings: TSerifDrawSettings;
  const ActiveRoleNames: array of string);
begin
  case Settings.FrameKind of
    1:
      if Length(ActiveRoleNames) > 0 then
        CompositeFrameStyle(Pixels, ImageWidth, ImageHeight,
          Settings.ResolveCommonFrameAppearance(
            ActiveRoleNames[High(ActiveRoleNames)]))
      else
        CompositeFrameStyle(Pixels, ImageWidth, ImageHeight,
          Settings.ResolveCommonFrameAppearance(''));
    2:
      if Length(ActiveRoleNames) > 0 then
        CompositeFrameStyle(Pixels, ImageWidth, ImageHeight,
          Settings.ResolveFrameAppearance(-1,
            ActiveRoleNames[High(ActiveRoleNames)]));
  end;
end;

end.
