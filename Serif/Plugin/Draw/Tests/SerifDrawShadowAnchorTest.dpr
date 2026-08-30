program SerifDrawShadowAnchorTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  TextRendererTypes in 'Lib\TextRenderer\TextRendererTypes.pas',
  TextRenderer in 'Lib\TextRenderer\TextRenderer.pas',
  TextRendererSkiaBootstrap in
    'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererSkiaRuntime in 'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  TextRendererSkia in 'Lib\TextRenderer\TextRendererSkia.pas';

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function BodyLeftAt(const AImage: TTextRenderImage;
  const AAnchorX: Double): Double;
begin
  Result := AAnchorX -
    ((AImage.LayoutBounds.Left + AImage.LayoutBounds.Right) * 0.5 -
     AImage.Bounds.Left) + AImage.LayoutBounds.Left - AImage.Bounds.Left;
end;

function BodyTopAt(const AImage: TTextRenderImage;
  const AAnchorY: Double): Double;
begin
  Result := AAnchorY -
    ((AImage.LayoutBounds.Top + AImage.LayoutBounds.Bottom) * 0.5 -
     AImage.Bounds.Top) +
    AImage.LayoutBounds.Top - AImage.Bounds.Top;
end;

function LayoutCenterXAt(const AImage: TTextRenderImage;
  const AAnchorX: Double): Double;
begin
  Result := AAnchorX -
    ((AImage.LayoutBounds.Left + AImage.LayoutBounds.Right) * 0.5 -
     AImage.Bounds.Left) +
    (AImage.LayoutBounds.Left + AImage.LayoutBounds.Right) * 0.5 -
    AImage.Bounds.Left;
end;

function LayoutCenterYAt(const AImage: TTextRenderImage;
  const AAnchorY: Double): Double;
begin
  Result := AAnchorY -
    ((AImage.LayoutBounds.Top + AImage.LayoutBounds.Bottom) * 0.5 -
     AImage.Bounds.Top) +
    (AImage.LayoutBounds.Top + AImage.LayoutBounds.Bottom) * 0.5 -
    AImage.Bounds.Top;
end;

var
  BaseImage: TTextRenderImage;
  GlowImage: TTextRenderImage;
  Metrics: TTextRenderMetrics;
  OutlineBlurImage: TTextRenderImage;
  Renderer: TCustomTextRenderer;
  Request: TTextRenderRequest;
  Shadow: TTextRenderShadow;
  ShadowImage: TTextRenderImage;
  UnitImage: TTextRenderImage;
begin
  TTextRendererSkiaRuntime.Acquire(
    IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'sk4d.dll');
  try
    Renderer := TSkiaTextRenderer.Create;
    try
      Request := TTextRenderRequest.Default;
      Request.Text := '影の基準座標😀' + sLineBreak + '複数行テスト';
      Request.Alignment := TTextRenderAlignment.Center;
      Request.LetterSpacing := 8;
      Request.LineSpacing := 12;
      Request.FontSize := 120;
      Request.FontStyle := [TTextRenderFontStyleItem.Bold];
      Request.Outlines := [TTextRenderOutline.Create(12, $FF247EFF)];
      Request.CaptureTextUnits := True;
      Request.Text := '長いセリフ、  A';
      UnitImage := Renderer.Render(Request, Metrics);
      try
        Require(Length(UnitImage.TextUnitBounds) = 9,
          'Text-unit bounds count mismatch.');
        Require(not UnitImage.TextUnitBounds[0].IsEmpty and
          UnitImage.TextUnitBounds[6].IsEmpty and
          UnitImage.TextUnitBounds[7].IsEmpty and
          not UnitImage.TextUnitBounds[8].IsEmpty,
          'Text-unit bounds did not preserve punctuation or spaces.');
        Require(UnitImage.TextUnitBounds[0].Width <>
          UnitImage.TextUnitBounds[8].Width,
          'Text-unit bounds still use equal-width division.');
        Require((Length(UnitImage.TextUnitImages) = 9) and
          (UnitImage.TextUnitImages[0] <> nil) and
          (UnitImage.TextUnitImages[6] = nil) and
          (UnitImage.TextUnitImages[7] = nil) and
          (UnitImage.TextUnitImages[8] <> nil) and
          (UnitImage.TextUnitImages[0].Bounds = UnitImage.TextUnitBounds[0]),
          'Independent text-unit images were not captured correctly.');
      finally
        UnitImage.Free;
      end;
      Request.Text := '影の基準座標😀' + sLineBreak + '複数行テスト';
      BaseImage := Renderer.Render(Request, Metrics);
      try
        Request.FillColor := TAlphaColorRec.Null;
        Request.Outlines := [TTextRenderOutline.Create(12, 7,
          $FFFFFF00)];
        Request.Shadows := nil;
        GlowImage := Renderer.Render(Request, Metrics);
        try
          Require((Metrics.NonTransparentPixelCount > 0) and
            (Length(GlowImage.TextUnitImages) > 0) and
            (GlowImage.TextUnitImages[0] <> nil) and
            (GlowImage.Bounds.Width > BaseImage.Bounds.Width) and
            (GlowImage.Bounds.Height > BaseImage.Bounds.Height),
            'The colored text-unit glow layer was not rendered.');
        finally
          GlowImage.Free;
        end;
        Request.FillColor := TAlphaColorRec.White;
        Request.Outlines := [TTextRenderOutline.Create(12, 7,
          $FF247EFF)];
        OutlineBlurImage := Renderer.Render(Request, Metrics);
        try
          Require(BaseImage.LayoutBounds = OutlineBlurImage.LayoutBounds,
            'Layout bounds changed when outline blur was enabled.');
          Require((OutlineBlurImage.Bounds.Left < BaseImage.Bounds.Left) and
            (OutlineBlurImage.Bounds.Top < BaseImage.Bounds.Top) and
            (OutlineBlurImage.Bounds.Right > BaseImage.Bounds.Right) and
            (OutlineBlurImage.Bounds.Bottom > BaseImage.Bounds.Bottom),
            'Outline blur did not extend the effect bounds.');
        finally
          OutlineBlurImage.Free;
        end;
        Request.Outlines := [TTextRenderOutline.Create(12, $FF247EFF)];
        Shadow := System.Default(TTextRenderShadow);
        Shadow.Offset := PointF(30, 24);
        Shadow.BlurRadius := 8;
        Shadow.SpreadRadius := 4;
        Shadow.Color := $A0000000;
        Request.Shadows := [Shadow];
        ShadowImage := Renderer.Render(Request, Metrics);
        try
          Require(BaseImage.LayoutBounds = ShadowImage.LayoutBounds,
            'Layout bounds changed when the shadow was enabled.');
          Require((ShadowImage.Bounds.Right > BaseImage.Bounds.Right) and
            (ShadowImage.Bounds.Bottom > BaseImage.Bounds.Bottom),
            'Shadow did not extend the effect bounds.');
          Require(Abs(BodyLeftAt(BaseImage, 960) -
            BodyLeftAt(ShadowImage, 960)) < 0.001,
            'Body X changed at the same anchor.');
          Require(Abs(BodyTopAt(BaseImage, 540) -
            BodyTopAt(ShadowImage, 540)) < 0.001,
            'Body Y changed at the same anchor.');
          Require(Abs(LayoutCenterXAt(BaseImage, 960) - 960) < 0.001,
            'Layout center X does not match the anchor.');
          Require(Abs(LayoutCenterYAt(BaseImage, 540) - 540) < 0.001,
            'Layout center Y does not match the anchor.');
        finally
          ShadowImage.Free;
        end;
      finally
        BaseImage.Free;
      end;
    finally
      Renderer.Free;
    end;
  finally
    TTextRendererSkiaRuntime.Release;
  end;
  Writeln('SerifDraw shadow anchor tests passed.');
end.
