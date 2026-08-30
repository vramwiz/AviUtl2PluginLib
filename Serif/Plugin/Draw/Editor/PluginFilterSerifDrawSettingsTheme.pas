unit PluginFilterSerifDrawSettingsTheme;

interface

uses
  Vcl.Graphics,
  FormattingToolbarButtons;

const
  SERIF_DRAW_BACKGROUND_COLOR = TColor($00202020);
  SERIF_DRAW_PANEL_COLOR = TColor($00262626);
  SERIF_DRAW_CONTROL_COLOR = TColor($00303030);
  SERIF_DRAW_TEXT_COLOR = TColor($00E6E6E6);
  SERIF_DRAW_ICON_GLYPH_COLOR = TColor($00F0F0F0);
  SERIF_DRAW_FRAME_HANDLE_GLYPH_COLOR = TColor($00F0F0F0);
  SERIF_DRAW_FRAME_SHADOW_GLYPH_COLOR = TColor($00888888);
  SERIF_DRAW_FRAME_SHADOW_GLYPH_BORDER_COLOR = TColor($00C0C0C0);
  SERIF_DRAW_ICON_HOVER_COLOR = TColor($00604428);
  SERIF_DRAW_ICON_MIXED_COLOR = TColor($00785030);
  SERIF_DRAW_ICON_SELECTED_COLOR = TColor($00906028);
  SERIF_DRAW_ICON_PRESSED_COLOR = TColor($00B87830);
  SERIF_DRAW_ICON_STATE_BORDER_COLOR = TColor($00E0A060);
  SERIF_DRAW_ICON_SELECTED_GLYPH_COLOR = TColor($00FFD8A0);

procedure ApplySerifDrawToolbarTheme(
  const Toolbar: TFormattingToolbarButtons);

implementation

procedure ApplySerifDrawToolbarTheme(
  const Toolbar: TFormattingToolbarButtons);
begin
  if Toolbar = nil then
    Exit;
  Toolbar.Color := SERIF_DRAW_PANEL_COLOR;
  Toolbar.ParentBackground := False;
  Toolbar.HotColor := SERIF_DRAW_ICON_HOVER_COLOR;
  Toolbar.MixedColor := SERIF_DRAW_ICON_MIXED_COLOR;
  Toolbar.CheckedColor := SERIF_DRAW_ICON_SELECTED_COLOR;
  Toolbar.PressedColor := SERIF_DRAW_ICON_PRESSED_COLOR;
  Toolbar.StateBorderColor := SERIF_DRAW_ICON_STATE_BORDER_COLOR;
end;

end.
