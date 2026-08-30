program SerifDrawSettingsTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Lib\AviUtl2Filter\AviUtl2FilterTypes.pas',
  PluginFilterSerifDrawSettings in
    'Serif\Plugin\Draw\PluginFilterSerifDrawSettings.pas';

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

var
  Decoded: TSerifDrawSettings;
  ErrorText: string;
  Colors: TSerifDrawLayerColors;
  FrameStyle: TSerifDrawFrameStyle;
  Settings: TSerifDrawSettings;
  Style: TSerifDrawLayerStyle;
  Text: string;
begin
  Settings := TSerifDrawSettings.Default;
  Require(Settings.FontSize = 54,
    'Default font size must be approximately one third of the old value.');
  Require(Abs(SerifDrawOutlineWidthPixels(Settings.OutlineWidth,
    Settings.FontSize) - 16.2) < 0.001,
    'Default outline ratio must preserve the previous visual width.');
  Require(SerifDrawOutlineWidthPixels(
    SERIF_TEXT_OUTLINE_WIDTH_MAX_PERCENT, 2000) =
    SERIF_TEXT_OUTLINE_WIDTH_MAX_PIXELS,
    'Large fonts must obey the absolute outline raster limit.');
  Require(SerifDrawShadowBlurPixels(
    SERIF_TEXT_SHADOW_BLUR_MAX_PERCENT, 2000) =
    SERIF_TEXT_SHADOW_BLUR_MAX_PIXELS,
    'Large fonts must obey the absolute shadow blur raster limit.');
  Require(SerifDrawOutlineBlurPixels(
    SERIF_TEXT_OUTLINE_BLUR_MAX_PERCENT, 100) = 20,
    'Outline blur must allow the relaxed 20 percent range.');
  Require((SerifDrawShadowOffsetPixels(60, 100) = 60) and
    (SerifDrawShadowOffsetPixels(-60, 100) = -60),
    'Shadow offsets must preserve their signed font-size ratio.');
  Require(SerifDrawShadowSpreadPixels(30, 100) = 30,
    'Shadow spread must use its font-size ratio.');
  Require((Settings.FillColor = $FFFFFFFF) and
    (Settings.OutlineColor = $FF000000) and
    (Settings.BlurColor = $FF000000) and
    (Settings.ShadowColor = $A0000000),
    'Default serif colors must be white text with black effects.');
  Require((Settings.RoleNameFillColor = $FFFFFFFF) and
    (Settings.RoleNameOutlineColor = $FF000000) and
    (Settings.RoleNameBlurColor = $FF000000) and
    (Settings.RoleNameShadowColor = $FF000000) and
    not Settings.RoleNameShadowEnabled and
    not Settings.RoleNameVisible and
    (Settings.RoleNameOutlineBlur = 0),
    'Default role name style must be hidden white text with black effects.');

  Require(TSerifDrawSettings.TryDecode(
    'SD2;fs=120;ow=10;fc=FFFFFFFF;oc=FF112233;pl=4;x=-5.236;y=384',
    Settings, ErrorText) and (Settings.FontSize = 120) and
    (Settings.OutlineWidth = 10) and
    (Settings.OutlineColor = $FF112233) and
    (Settings.Placement = 4) and
    (Abs(Settings.PositionX + 5.236) < 0.001) and
    (Settings.PositionY = 384),
    'Compatible SD2 text settings must be migrated at read time.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD3;fk=1;fw=1280;fh=180;colors=', Settings, ErrorText),
    'Obsolete SD3 data must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD4;fk=1;fw=1280;fh=180;colors=', Settings, ErrorText),
    'Obsolete SD4 data must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD5;fk=1;fw=1280;fh=180;colors=', Settings, ErrorText),
    'Obsolete SD5 data must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD6;fk=1;fw=1280;fh=180;colors=', Settings, ErrorText),
    'Obsolete SD6 data must not be accepted.');
  Require(TSerifDrawSettings.TryDecode(
    'SD7;fk=1;fw=1280;fh=180;colors=', Settings, ErrorText) and
    (Settings.FrameShape = 0) and
    (Settings.FrameFillMode = SERIF_FRAME_FILL_SOLID) and
    (Settings.FrameGradientStrength = 30) and
    (Settings.RoleNamePlacement = SERIF_PLACEMENT_CENTER) and
    (Settings.RoleNamePositionX = 0) and
    (Settings.RoleNamePositionY = 0) and
    not Settings.RoleNameVisible and
    (Length(Settings.LayerFrames) = 0),
    'Minimal SD7 frame settings must keep rectangle defaults.');
  Require(TSerifDrawSettings.TryDecode(
    'SD7;foc=FF102030;colors=', Settings, ErrorText) and
    (Settings.FrameInnerOutlineColor = $FF102030),
    'SD7 settings must inherit the outline color for the inner line.');
  Require(TSerifDrawSettings.TryDecode(
    'SD7;fs=88;fc=FF102938;ow=9;colors=', Settings, ErrorText) and
    (Settings.RoleNameFontSize = 88) and
    (Settings.RoleNameFillColor = $FFFFFFFF) and
    (Settings.RoleNameOutlineColor = $FF000000) and
    (Settings.RoleNameOutlineWidth = 9) and
    not Settings.RoleNameVisible,
    'Minimal SD7 data must retain the default role name appearance.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD7;ffm=2;colors=', Settings, ErrorText),
    'An invalid frame fill mode must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD7;fgs=101;colors=', Settings, ErrorText),
    'An invalid frame gradient strength must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD7;rp=9;colors=', Settings, ErrorText),
    'An invalid role name placement must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD7;rv=2;colors=', Settings, ErrorText),
    'An invalid role name visibility must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD7;ow=101;colors=', Settings, ErrorText),
    'An outline ratio above 100 percent must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD7;ob=21;colors=', Settings, ErrorText),
    'An outline blur ratio above 20 percent must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD7;sb=21;colors=', Settings, ErrorText),
    'A shadow blur ratio above 20 percent must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD7;sx=61;colors=', Settings, ErrorText),
    'A shadow offset above 60 percent must not be accepted.');
  Require(not TSerifDrawSettings.TryDecode(
    'SD7;ss=31;colors=', Settings, ErrorText),
    'A shadow spread above 30 percent must not be accepted.');

  Settings := TSerifDrawSettings.Default;
  Settings.PositionX := -123.5;
  Settings.PositionY := 456.25;
  Settings.Placement := SERIF_PLACEMENT_BOTTOM_RIGHT;
  Settings.RoleNamePlacement := SERIF_PLACEMENT_TOP_LEFT;
  Settings.RoleNamePositionX := -640.25;
  Settings.RoleNamePositionY := -300.5;
  Settings.RoleNameFontName := 'Role Font';
  Settings.RoleNameFontSize := 42;
  Settings.RoleNameFontStyles := SERIF_FONT_ITALIC;
  Settings.RoleNameFillColor := $FF123456;
  Settings.RoleNameOutlineColor := $FF654321;
  Settings.RoleNameBlurColor := $80112233;
  Settings.RoleNameOutlineWidth := 6;
  Settings.RoleNameOutlineBlur := 2;
  Settings.RoleNameLetterSpacing := 1.5;
  Settings.RoleNameLineSpacing := -2.5;
  Settings.RoleNameVisible := False;
  Settings.RoleNameShadowEnabled := True;
  Settings.RoleNameShadowOffsetX := 4;
  Settings.RoleNameShadowOffsetY := 5;
  Settings.RoleNameShadowBlur := 3;
  Settings.RoleNameShadowSpread := 1;
  Settings.RoleNameShadowColor := $70010203;
  Colors.RoleName := 'Role A';
  Colors.Layer := 7;
  Colors.FillColor := $FFAA0000;
  Colors.OutlineColor := $FF00AA00;
  Colors.ShadowColor := $800000AA;
  Colors.BlurColor := $40123456;
  Settings.SetRoleNameLayerColors(Colors);
  Settings.FontSize := 120;
  Settings.FontName := 'Test Font';
  Settings.FontStyles := SERIF_FONT_BOLD or SERIF_FONT_ITALIC;
  Settings.LetterSpacing := 3.25;
  Settings.LineSpacing := -7.5;
  Settings.OutlineWidth := 10;
  Settings.OutlineBlur := 3.5;
  Settings.ShadowEnabled := True;
  Settings.ShadowOffsetX := 12.5;
  Settings.ShadowOffsetY := -3.25;
  Settings.ShadowBlur := 6;
  Settings.ShadowSpread := 2;
  Settings.FrameKind := 1;
  Settings.FrameAccentSource := 1;
  Settings.FrameShape := 1;
  Settings.FrameCornerRadius := 48;
  Settings.FrameDottedDashLength := 18;
  Settings.FrameDottedGapLength := 30;
  Settings.FrameTabWidth := 300;
  Settings.FrameTabHeight := 70;
  Settings.FrameTabOffset := 30;
  Settings.FrameBalloonTailPosition := -80;
  Settings.FrameBalloonTailWidth := 140;
  Settings.FrameBalloonTailLength := 75;
  Settings.FrameBalloonTailDirection := 2;
  Settings.FramePositionX := -240.5;
  Settings.FramePositionY := 120.25;
  Settings.FrameWidth := 1440;
  Settings.FrameHeight := 240;
  Settings.FrameFillVisible := True;
  Settings.FrameOutlineVisible := False;
  Settings.FrameOutlineWidth := 24;
  Settings.FrameOutlineStyle := 3;
  Settings.FrameShadowVisible := True;
  Settings.FrameShadowBlur := 17.75;
  Settings.FrameShadowOffsetX := -18.5;
  Settings.FrameShadowOffsetY := 22.25;
  Settings.FrameShadowSpread := 13.5;
  Settings.FrameFillColor := $FF112233;
  Settings.FrameFillMode := SERIF_FRAME_FILL_VERTICAL_GRADIENT;
  Settings.FrameGradientStrength := 42;
  Settings.FrameOutlineColor := $FF445566;
  Settings.FrameInnerOutlineColor := $FFAABBCC;
  Settings.FrameLayering := 1;
  Settings.FrameInnerPanelColor := $DDEEFF11;
  Settings.FrameInnerPanelInsetX := 36;
  Settings.FrameInnerPanelInsetY := 24;
  Settings.FrameInnerPanelRadius := 18;
  Settings.FrameShadowColor := $FF778899;

  FrameStyle := Settings.CommonFrameStyle;
  FrameStyle.RoleName := 'Role A';
  FrameStyle.Layer := 7;
  FrameStyle.AccentSource := 1;
  FrameStyle.Shape := 3;
  FrameStyle.CornerRadius := 72;
  FrameStyle.DottedDashLength := 12;
  FrameStyle.DottedGapLength := 22;
  FrameStyle.TabWidth := 280;
  FrameStyle.TabHeight := 68;
  FrameStyle.TabOffset := 36;
  FrameStyle.BalloonTailPosition := 90;
  FrameStyle.BalloonTailWidth := 160;
  FrameStyle.BalloonTailLength := 85;
  FrameStyle.BalloonTailDirection := 3;
  FrameStyle.PositionX := 320.5;
  FrameStyle.Width := 900;
  FrameStyle.FillColor := $C0102030;
  FrameStyle.FillMode := SERIF_FRAME_FILL_VERTICAL_GRADIENT;
  FrameStyle.GradientStrength := 67;
  FrameStyle.OutlineStyle := 1;
  FrameStyle.InnerOutlineColor := $FF123456;
  FrameStyle.Layering := 1;
  FrameStyle.InnerPanelColor := $CCFEDCBA;
  FrameStyle.InnerPanelInsetX := 42;
  FrameStyle.InnerPanelInsetY := 26;
  FrameStyle.InnerPanelRadius := 20;
  Settings.SetLayerFrameStyle(FrameStyle);
  Require(Settings.HasLayerFrameStyle('Role A'),
    'Explicit role frame style was not detected.');
  Settings.RemoveLayerFrameStyle('Role A');
  Require(not Settings.HasLayerFrameStyle('Role A'),
    'Role frame style was not removed.');
  Require((Settings.ResolveFrameStyle(99, 'Role A').Layer = 99) and
    (Settings.ResolveFrameStyle(99, 'Role A').CornerRadius =
      Settings.FrameCornerRadius),
    'Removed role frame did not inherit the common frame.');
  Settings.SetLayerFrameStyle(FrameStyle);

  Colors.RoleName := 'Role A';
  Colors.Layer := 7;
  Colors.FillColor := $80FF0000;
  Colors.OutlineColor := $6000FF00;
  Colors.ShadowColor := $80010203;
  Colors.BlurColor := $40304050;
  Settings.SetLayerColors(Colors);
  Colors.Layer := 99;
  Colors.FillColor := $81FF0000;
  Settings.SetLayerColors(Colors);
  Require(Length(Settings.LayerColors) = 1,
    'Same role created duplicate color records after a layer change.');

  Colors.RoleName := 'Role B';
  Colors.Layer := 12;
  Colors.FillColor := $FF00FFFF;
  Colors.OutlineColor := $FFFF00FF;
  Colors.ShadowColor := $7F654321;
  Colors.BlurColor := $7F123456;
  Settings.SetLayerColors(Colors);
  Require(Length(Settings.LayerColors) = 2,
    'Second role colors were not retained.');

  Text := Settings.Encode;
  Require(Copy(Text, 1, 4) = 'SD7;', 'Settings were not encoded as SD7.');
  Require(Pos(';colors=', Text) > 0, 'SD7 color section is missing.');
  Require(Pos(';frames=', Text) > 0, 'SD7 role frame section is missing.');
  Require(TSerifDrawSettings.TryDecode(Text, Decoded, ErrorText),
    'SD7 decode failed: ' + ErrorText);
  Require((Decoded.PositionX = -123.5) and (Decoded.PositionY = 456.25),
    'Common position roundtrip mismatch.');
  Require((Decoded.RoleNamePlacement = SERIF_PLACEMENT_TOP_LEFT) and
    (Decoded.RoleNamePositionX = -640.25) and
    (Decoded.RoleNamePositionY = -300.5),
    'Role name placement roundtrip mismatch.');
  Require((Decoded.RoleNameFontName = 'Role Font') and
    (Decoded.RoleNameFontSize = 42) and
    (Decoded.RoleNameFontStyles = SERIF_FONT_ITALIC) and
    (Decoded.RoleNameFillColor = $FF123456) and
    (Decoded.RoleNameOutlineColor = $FF654321) and
    (Decoded.RoleNameBlurColor = $80112233) and
    (Decoded.RoleNameOutlineWidth = 6) and
    (Decoded.RoleNameOutlineBlur = 2) and
    (Decoded.RoleNameLetterSpacing = 1.5) and
    (Decoded.RoleNameLineSpacing = -2.5) and
    not Decoded.RoleNameVisible and
    Decoded.RoleNameShadowEnabled and
    (Decoded.RoleNameShadowOffsetX = 4) and
    (Decoded.RoleNameShadowOffsetY = 5) and
    (Decoded.RoleNameShadowBlur = 3) and
    (Decoded.RoleNameShadowSpread = 1) and
    (Decoded.RoleNameShadowColor = $70010203),
    'Role name text style roundtrip mismatch.');
  Style := Decoded.ResolveRoleNameStyle(99, 'Role A');
  Require((Style.FillColor = $FFAA0000) and
    (Style.OutlineColor = $FF00AA00) and
    (Style.ShadowColor = $800000AA) and
    (Style.BlurColor = $40123456),
    'Per-role role name colors roundtrip mismatch after a layer change.');
  Decoded.RemoveRoleNameLayerColors('Role A');
  Style := Decoded.ResolveRoleNameStyle(99, 'Role A');
  Require((Style.FillColor = Decoded.RoleNameFillColor) and
    (Style.OutlineColor = Decoded.RoleNameOutlineColor),
    'Role name colors did not reset to the common colors.');
  Require((Decoded.FontSize = 120) and
    (Decoded.FontName = 'Test Font') and
    (Decoded.FontStyles = SERIF_FONT_BOLD or SERIF_FONT_ITALIC),
    'Common font roundtrip mismatch.');
  Require((Decoded.OutlineWidth = 10) and (Decoded.OutlineBlur = 3.5) and
    Decoded.ShadowEnabled and (Decoded.ShadowOffsetX = 12.5) and
    (Decoded.ShadowOffsetY = -3.25) and (Decoded.ShadowBlur = 6) and
    (Decoded.ShadowSpread = 2),
    'Common decoration roundtrip mismatch.');
  Require((Decoded.FrameKind = 1) and (Decoded.FrameAccentSource = 1) and
    (Decoded.FrameShape = 1) and
    (Decoded.FrameCornerRadius = 48) and
    (Decoded.FrameDottedDashLength = 18) and
    (Decoded.FrameDottedGapLength = 30) and
    (Decoded.FrameTabWidth = 300) and (Decoded.FrameTabHeight = 70) and
    (Decoded.FrameTabOffset = 30) and
    (Decoded.FrameBalloonTailPosition = -80) and
    (Decoded.FrameBalloonTailWidth = 140) and
    (Decoded.FrameBalloonTailLength = 75) and
    (Decoded.FrameBalloonTailDirection = 2) and
    (Decoded.FrameWidth = 1440) and
    (Decoded.FrameHeight = 240) and (Decoded.FramePositionX = -240.5) and
    (Decoded.FramePositionY = 120.25),
    'Common frame geometry roundtrip mismatch.');
  Require(Decoded.FrameFillVisible and
    not Decoded.FrameOutlineVisible and Decoded.FrameShadowVisible and
    (Decoded.FrameShadowBlur = 17.75) and
    (Decoded.FrameOutlineWidth = 24) and
    (Decoded.FrameOutlineStyle = 3) and
    (Decoded.FrameShadowOffsetX = -18.5) and
    (Decoded.FrameShadowOffsetY = 22.25) and
    (Decoded.FrameShadowSpread = 13.5) and
    (Decoded.FrameFillColor = $FF112233) and
    (Decoded.FrameFillMode = SERIF_FRAME_FILL_VERTICAL_GRADIENT) and
    (Decoded.FrameGradientStrength = 42) and
    (Decoded.FrameOutlineColor = $FF445566) and
    (Decoded.FrameInnerOutlineColor = $FFAABBCC) and
    (Decoded.FrameLayering = 1) and
    (Decoded.FrameInnerPanelColor = $DDEEFF11) and
    (Decoded.FrameInnerPanelInsetX = 36) and
    (Decoded.FrameInnerPanelInsetY = 24) and
    (Decoded.FrameInnerPanelRadius = 18) and
    (Decoded.FrameShadowColor = $FF778899),
    'Common frame appearance roundtrip mismatch.');
  FrameStyle := Decoded.ResolveCommonFrameAppearance('Role A');
  Require((FrameStyle.Shape = 1) and (FrameStyle.Width = 1440) and
    (FrameStyle.PositionX = -240.5) and
    (FrameStyle.FillColor = $FF00FF00) and
    (FrameStyle.OutlineColor = $FF00FF00) and
    (FrameStyle.InnerOutlineColor = $FF00FF00) and
    (FrameStyle.InnerPanelColor = $DDEEFF11),
    'Common frame appearance used character frame geometry or base color.');
  FrameStyle := Decoded.ResolveFrameAppearance(99, 'Role A');
  Require((FrameStyle.Layer = 99) and (FrameStyle.Shape = 3) and
    (FrameStyle.CornerRadius = 72) and
    (FrameStyle.DottedDashLength = 12) and
    (FrameStyle.DottedGapLength = 22) and
    (FrameStyle.TabWidth = 280) and (FrameStyle.TabHeight = 68) and
    (FrameStyle.TabOffset = 36) and
    (FrameStyle.BalloonTailPosition = 90) and
    (FrameStyle.BalloonTailWidth = 160) and
    (FrameStyle.BalloonTailLength = 85) and
    (FrameStyle.BalloonTailDirection = 3) and
    (FrameStyle.PositionX = 320.5) and (FrameStyle.Width = 900) and
    (FrameStyle.AccentSource = 1) and
    (FrameStyle.FillColor = $C000FF00) and
    (FrameStyle.FillMode = SERIF_FRAME_FILL_VERTICAL_GRADIENT) and
    (FrameStyle.GradientStrength = 67) and
    (FrameStyle.OutlineColor = $FF00FF00) and
    (FrameStyle.OutlineStyle = 1) and
    (FrameStyle.InnerOutlineColor = $FF00FF00) and
    (FrameStyle.ShadowColor = $FF00FF00) and
    (FrameStyle.Layering = 1) and
    (FrameStyle.InnerPanelColor = $CCFEDCBA) and
    (FrameStyle.InnerPanelInsetX = 42) and
    (FrameStyle.InnerPanelInsetY = 26) and
    (FrameStyle.InnerPanelRadius = 20),
    'Role frame roundtrip mismatch after a layer change.');
  FrameStyle := Decoded.ResolveFrameAppearance(99, 'Unknown Role');
  Require((FrameStyle.Layer = 99) and
    (FrameStyle.Shape = Decoded.FrameShape) and
    (FrameStyle.FillColor = ((Decoded.FrameFillColor and $FF000000) or
      (Decoded.OutlineColor and $00FFFFFF))),
    'Unset role frame did not inherit common settings.');

  Style := Decoded.ResolveStyle(99, 'Role A');
  Require((Style.FontSize = 120) and (Style.FillColor = $81FF0000) and
    (Style.OutlineColor = $6000FF00) and
    (Style.ShadowColor = $80010203) and
    (Style.BlurColor = $40304050),
    'Role A resolved style mismatch after a layer change.');
  Style := Decoded.ResolveStyle(7, 'Role B');
  Require((Style.FontSize = 120) and (Style.FillColor = $FF00FFFF) and
    (Style.OutlineColor = $FFFF00FF) and
    (Style.ShadowColor = $7F654321) and
    (Style.BlurColor = $7F123456),
    'Role B resolved style mismatch after a layer change.');
  Style := Decoded.ResolveStyle(99, 'Unknown Role');
  Require((Style.FontSize = 120) and
    (Style.FillColor = Decoded.FillColor),
    'Unset role did not use common values.');

  Decoded.RemoveLayerColors('Role A');
  Require(Length(Decoded.LayerColors) = 1,
    'Role color removal did not shrink the list.');
  Style := Decoded.ResolveStyle(7, 'Role A');
  Require(Style.FillColor = Decoded.FillColor,
    'Removed role did not use the common color.');
  Writeln('SerifDraw SD7 settings tests passed.');
end.
