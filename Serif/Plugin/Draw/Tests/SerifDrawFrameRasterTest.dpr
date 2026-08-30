program SerifDrawFrameRasterTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  PluginFilterSerifDrawFrameRaster in
    'Serif\Plugin\Draw\Display\PluginFilterSerifDrawFrameRaster.pas',
  PluginFilterSerifDrawSettings in
    'Serif\Plugin\Draw\PluginFilterSerifDrawSettings.pas',
  AviUtl2FilterTypes in 'Lib\AviUtl2Filter\AviUtl2FilterTypes.pas',
  TextRendererTypes in 'Lib\TextRenderer\TextRendererTypes.pas';

procedure Require(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function PixelAt(var Pixels: TBytes; const Width, X, Y: Integer):
  TTextRenderPixel;
var
  PixelPointer: PTextRenderPixel;
begin
  PixelPointer := PTextRenderPixel(@Pixels[0]);
  Inc(PixelPointer, Y * Width + X);
  Result := PixelPointer^;
end;

var
  Colors: TSerifDrawLayerColors;
  FrameStyle: TSerifDrawFrameStyle;
  Pixel: TTextRenderPixel;
  Pixels: TBytes;
  Settings: TSerifDrawSettings;
begin
  SetLength(Pixels, 40 * 40 * SizeOf(TTextRenderPixel));
  Settings := TSerifDrawSettings.Default;
  Settings.FrameKind := 1;
  Settings.FrameWidth := 10;
  Settings.FrameHeight := 10;
  Settings.FrameFillVisible := True;
  Settings.FrameOutlineVisible := False;
  Settings.FrameShadowVisible := False;
  Settings.FrameFillColor := $70FF0000;
  CompositeSerifDrawCommonFrame(Pixels, 40, 40, Settings);
  Pixel := PixelAt(Pixels, 40, 20, 20);
  Require((Pixel.R = 255) and (Pixel.G = 0) and (Pixel.B = 0) and
    (Pixel.A = 112), 'Semi-transparent frame fill mismatch.');
  Require(PixelAt(Pixels, 40, 14, 20).A = 0,
    'Frame fill escaped its bounds.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameFillVisible := False;
  Settings.FrameOutlineVisible := True;
  Settings.FrameOutlineWidth := 3;
  Settings.FrameOutlineColor := $FF00FF00;
  CompositeSerifDrawCommonFrame(Pixels, 40, 40, Settings);
  Pixel := PixelAt(Pixels, 40, 15, 15);
  Require((Pixel.G = 255) and (Pixel.A = 255),
    'Frame outline mismatch.');
  Require(PixelAt(Pixels, 40, 20, 20).A = 0,
    'Frame outline filled the interior.');
  Require(PixelAt(Pixels, 40, 17, 20).G = 255,
    'Configured frame outline width was not applied.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameWidth := 20;
  Settings.FrameHeight := 20;
  Settings.FrameOutlineWidth := 6;
  Settings.FrameOutlineStyle := 1;
  Settings.FrameInnerOutlineColor := $FF0000FF;
  CompositeSerifDrawCommonFrame(Pixels, 40, 40, Settings);
  Require(PixelAt(Pixels, 40, 10, 20).G = 255,
    'Double frame outer line was not rendered.');
  Require(PixelAt(Pixels, 40, 12, 20).A = 0,
    'Double frame line gap was not preserved.');
  Require(PixelAt(Pixels, 40, 14, 20).B = 255,
    'Double frame inner line was not rendered.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameOutlineStyle := 2;
  Settings.FrameOutlineColor := $FFFF0000;
  Settings.FrameInnerOutlineColor := $FF0000FF;
  CompositeSerifDrawCommonFrame(Pixels, 40, 40, Settings);
  Pixel := PixelAt(Pixels, 40, 7, 20);
  Require((Pixel.R = 255) and (Pixel.A > 0) and (Pixel.A < 255),
    'Neon frame glow was not rendered with falloff.');
  Require(PixelAt(Pixels, 40, 10, 20).B = 255,
    'Neon frame core was not rendered.');
  Require(PixelAt(Pixels, 40, 3, 20).A = 0,
    'Neon frame glow escaped its configured range.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameOutlineStyle := 3;
  Settings.FrameOutlineColor := $FF00FF00;
  Settings.FrameDottedDashLength := 4;
  Settings.FrameDottedGapLength := 4;
  CompositeSerifDrawCommonFrame(Pixels, 40, 40, Settings);
  Require(PixelAt(Pixels, 40, 10, 20).G = 255,
    'Dotted frame visible segment was not rendered.');
  Require(PixelAt(Pixels, 40, 10, 22).A = 0,
    'Dotted frame gap was not preserved.');
  Require(PixelAt(Pixels, 40, 29, 20).G = 255,
    'Dotted frame right edge was not rendered.');
  Require(PixelAt(Pixels, 40, 20, 29).G = 255,
    'Dotted frame bottom edge was not rendered.');
  Require(PixelAt(Pixels, 40, 29, 22).A = 0,
    'Dotted frame right edge gap was not preserved.');
  Require(PixelAt(Pixels, 40, 14, 29).A = 0,
    'Dotted frame bottom edge gap was not preserved.');
  Require(PixelAt(Pixels, 40, 13, 15).G = 255,
    'Dotted frame corner segment was tapered.');
  Require(PixelAt(Pixels, 40, 14, 15).A = 0,
    'Dotted frame corner gap was stretched.');
  Settings.FrameWidth := 10;
  Settings.FrameHeight := 10;

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameOutlineVisible := False;
  Settings.FrameOutlineStyle := 0;
  Settings.FrameShadowVisible := True;
  Settings.FrameShadowColor := $6E0000FF;
  Settings.FrameShadowOffsetX := -5;
  Settings.FrameShadowOffsetY := 7;
  Settings.FrameShadowSpread := 2;
  Settings.FrameShadowBlur := 2;
  CompositeSerifDrawCommonFrame(Pixels, 40, 40, Settings);
  Pixel := PixelAt(Pixels, 40, 10, 22);
  Require((Pixel.B = 255) and (Pixel.A = 110),
    'Frame shadow mismatch.');
  Require(PixelAt(Pixels, 40, 20, 14).A = 0,
    'Frame shadow was not offset.');
  Require(PixelAt(Pixels, 40, 8, 22).B = 255,
    'Frame shadow spread was not applied.');
  Pixel := PixelAt(Pixels, 40, 6, 22);
  Require((Pixel.B = 255) and (Pixel.A > 0) and (Pixel.A < 110),
    'Frame shadow blur falloff was not applied.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameShape := 1;
  Settings.FrameCornerRadius := 4;
  Settings.FrameFillVisible := True;
  Settings.FrameShadowVisible := False;
  Settings.FrameFillColor := $FFFF0000;
  CompositeSerifDrawCommonFrame(Pixels, 40, 40, Settings);
  Require(PixelAt(Pixels, 40, 15, 15).A = 0,
    'Rounded frame corner was not clipped.');
  Require(PixelAt(Pixels, 40, 18, 15).R = 255,
    'Rounded frame top edge was not filled.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameKind := 2;
  Settings.FrameShape := 0;
  Settings.FrameWidth := 6;
  Settings.FrameHeight := 6;
  Settings.FrameFillVisible := True;
  Settings.FrameOutlineVisible := False;
  Settings.FrameShadowVisible := False;
  FrameStyle := Settings.ResolveFrameStyle(7, 'Role A');
  FrameStyle.RoleName := 'Role A';
  FrameStyle.Layer := 7;
  FrameStyle.PositionX := -10;
  FrameStyle.FillColor := $FF00FF00;
  Settings.SetLayerFrameStyle(FrameStyle);
  FrameStyle := Settings.ResolveFrameStyle(12, 'Role B');
  FrameStyle.RoleName := 'Role B';
  FrameStyle.Layer := 12;
  FrameStyle.PositionX := 10;
  FrameStyle.FillColor := $FF0000FF;
  Settings.SetLayerFrameStyle(FrameStyle);
  CompositeSerifDrawFrames(Pixels, 40, 40, Settings,
    ['Role A', 'Role B']);
  Require(PixelAt(Pixels, 40, 10, 20).A = 0,
    'The old Role A character frame was rendered.');
  Require(PixelAt(Pixels, 40, 30, 20).B = 255,
    'The latest Role B character frame was not rendered.');
  Require(PixelAt(Pixels, 40, 20, 20).A = 0,
    'Character frames escaped their configured positions.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings := TSerifDrawSettings.Default;
  Settings.FrameKind := 1;
  Settings.FrameAccentSource := 1;
  Settings.FrameWidth := 10;
  Settings.FrameHeight := 10;
  Settings.FrameFillVisible := False;
  Settings.FrameOutlineVisible := True;
  Settings.FrameOutlineWidth := 2;
  Settings.FrameOutlineColor := $FFFF0000;
  Colors.RoleName := 'Role A';
  Colors.Layer := 7;
  Colors.FillColor := $FF00FF00;
  Colors.OutlineColor := $FF0000FF;
  Colors.ShadowColor := $FF000000;
  Colors.BlurColor := $FF000000;
  Settings.SetLayerColors(Colors);
  Colors.RoleName := 'Role B';
  Colors.Layer := 12;
  Colors.OutlineColor := $FF00FF00;
  Settings.SetLayerColors(Colors);
  CompositeSerifDrawFrames(Pixels, 40, 40, Settings,
    ['Role A', 'Role B']);
  Require(PixelAt(Pixels, 40, 15, 20).G = 255,
    'The latest role color was not applied to the common frame accent.');

  SetLength(Pixels, 100 * 100 * SizeOf(TTextRenderPixel));
  FillChar(Pixels[0], Length(Pixels), 0);
  Settings := TSerifDrawSettings.Default;
  Settings.FrameKind := 1;
  Settings.FrameWidth := 80;
  Settings.FrameHeight := 60;
  Settings.FrameOutlineVisible := False;
  Settings.FrameFillColor := $FFFF0000;
  Settings.FrameLayering := 1;
  Settings.FrameInnerPanelColor := $FF0000FF;
  Settings.FrameInnerPanelInsetX := 10;
  Settings.FrameInnerPanelInsetY := 8;
  Settings.FrameInnerPanelRadius := 4;
  Settings.FrameShadowVisible := True;
  Settings.FrameShadowColor := $FF00FF00;
  Settings.FrameShadowOffsetX := 4;
  Settings.FrameShadowOffsetY := 0;
  CompositeSerifDrawCommonFrame(Pixels, 100, 100, Settings);
  Require(PixelAt(Pixels, 100, 19, 50).R = 255,
    'Layered frame outer band was not rendered.');
  Require((PixelAt(Pixels, 100, 20, 50).B = 255) and
    (PixelAt(Pixels, 100, 50, 27).R = 255) and
    (PixelAt(Pixels, 100, 50, 28).B = 255),
    'Layered frame inner panel was not rendered.');
  Require(PixelAt(Pixels, 100, 82, 50).G = 255,
    'Inner panel shadow was not rendered behind the card.');
  Require(PixelAt(Pixels, 100, 92, 50).A = 0,
    'Layered frame shadow was incorrectly applied to the outer band.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings := TSerifDrawSettings.Default;
  Settings.FrameKind := 1;
  Settings.FrameShape := 2;
  Settings.FrameWidth := 60;
  Settings.FrameHeight := 40;
  Settings.FrameTabWidth := 20;
  Settings.FrameTabHeight := 10;
  Settings.FrameTabOffset := 5;
  Settings.FrameFillVisible := True;
  Settings.FrameOutlineVisible := False;
  Settings.FrameShadowVisible := False;
  Settings.FrameFillColor := $FFFF0000;
  CompositeSerifDrawCommonFrame(Pixels, 100, 100, Settings);
  Require(PixelAt(Pixels, 100, 30, 32).R = 255,
    'Tab body was not rendered.');
  Require(PixelAt(Pixels, 100, 47, 32).A = 0,
    'Tab shape filled outside the upper tab.');
  Require(PixelAt(Pixels, 100, 47, 55).R = 255,
    'Tab shape main body was not rendered.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameFillColor := $FFFFFFFF;
  Settings.FrameOutlineVisible := True;
  Settings.FrameOutlineStyle := 1;
  Settings.FrameOutlineWidth := 6;
  Settings.FrameOutlineColor := $FF00FF00;
  Settings.FrameInnerOutlineColor := $FF0000FF;
  CompositeSerifDrawCommonFrame(Pixels, 100, 100, Settings);
  Require(PixelAt(Pixels, 100, 45, 40).G = 255,
    'Double-line tab interrupted the outer line at its attachment edge.');
  Require(PixelAt(Pixels, 100, 41, 44).B = 255,
    'Double-line tab interrupted the inner line at its attachment edge.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameFillVisible := False;
  Settings.FrameOutlineStyle := 3;
  Settings.FrameOutlineWidth := 6;
  Settings.FrameDottedDashLength := 4;
  Settings.FrameDottedGapLength := 4;
  CompositeSerifDrawCommonFrame(Pixels, 100, 100, Settings);
  Require(PixelAt(Pixels, 100, 46, 40).G = 255,
    'Dotted tab body top did not render its dash segment.');
  Require(PixelAt(Pixels, 100, 48, 40).A = 0,
    'Dotted tab body top was rendered as a solid line.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameShape := 3;
  Settings.FrameFillVisible := True;
  Settings.FrameFillColor := $FFFF0000;
  Settings.FrameOutlineVisible := False;
  Settings.FrameOutlineStyle := 0;
  Settings.FrameWidth := 60;
  Settings.FrameHeight := 30;
  Settings.FrameCornerRadius := 6;
  Settings.FrameBalloonTailPosition := 0;
  Settings.FrameBalloonTailWidth := 20;
  Settings.FrameBalloonTailLength := 15;
  CompositeSerifDrawCommonFrame(Pixels, 100, 100, Settings);
  Require(PixelAt(Pixels, 100, 50, 50).R = 255,
    'Balloon body was not rendered.');
  Require(PixelAt(Pixels, 100, 50, 75).R = 255,
    'Balloon tail was not rendered.');
  Require(PixelAt(Pixels, 100, 38, 75).A = 0,
    'Balloon tail filled outside its triangle.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameBalloonTailDirection := 1;
  CompositeSerifDrawCommonFrame(Pixels, 100, 100, Settings);
  Require(PixelAt(Pixels, 100, 50, 25).R = 255,
    'Upper balloon tail was not rendered.');
  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameBalloonTailDirection := 2;
  CompositeSerifDrawCommonFrame(Pixels, 100, 100, Settings);
  Require(PixelAt(Pixels, 100, 10, 50).R = 255,
    'Left balloon tail was not rendered.');
  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameBalloonTailDirection := 3;
  CompositeSerifDrawCommonFrame(Pixels, 100, 100, Settings);
  Require(PixelAt(Pixels, 100, 90, 50).R = 255,
    'Right balloon tail was not rendered.');

  SetLength(Pixels, 40 * 40 * SizeOf(TTextRenderPixel));
  FillChar(Pixels[0], Length(Pixels), 0);
  Settings := TSerifDrawSettings.Default;
  Settings.FrameKind := 1;
  Settings.FrameWidth := 10;
  Settings.FrameHeight := 9;
  Settings.FrameOutlineVisible := False;
  Settings.FrameShadowVisible := False;
  Settings.FrameFillColor := $FF808080;
  Settings.FrameFillMode := SERIF_FRAME_FILL_VERTICAL_GRADIENT;
  Settings.FrameGradientStrength := 50;
  CompositeSerifDrawCommonFrame(Pixels, 40, 40, Settings);
  Require((PixelAt(Pixels, 40, 20, 16).R = 192) and
    (PixelAt(Pixels, 40, 20, 20).R = 128) and
    (PixelAt(Pixels, 40, 20, 24).R = 64),
    'Vertical frame gradient did not keep the base color at its center.');

  FillChar(Pixels[0], Length(Pixels), 0);
  Settings.FrameKind := 0;
  Settings.FrameFillVisible := True;
  CompositeSerifDrawCommonFrame(Pixels, 40, 40, Settings);
  Require(PixelAt(Pixels, 40, 20, 20).A = 0,
    'Disabled frame was rendered.');
  Writeln('SerifDraw frame raster tests passed.');
end.
