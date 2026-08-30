unit PluginFilterSerifDrawFrameEditorBinding;

// 枠設定レコードと編集フレームの相互変換、およびライブ外観の解決を担当する。

interface

uses
  PluginFilterSerifDrawFrameEditorFrame,
  PluginFilterSerifDrawSettings;

// 枠スタイル一式を編集フレームへ読み込む。設定レコード自体は変更しない。
procedure LoadSerifDrawFrameEditorStyle(
  const AEditor: TFrameSerifDrawFrameEditor;
  const AKind: TSerifDrawFrameKind; const AStyle: TSerifDrawFrameStyle);
// 編集フレームの現在値へ、呼び出し側が管理するLayerと位置を加えて返す。
function CaptureSerifDrawFrameEditorStyle(
  const AEditor: TFrameSerifDrawFrameEditor; const ALayer: Integer;
  const APositionX, APositionY: Double): TSerifDrawFrameStyle;
// 未確定の編集値と配役色を合成し、保存前のライブプレビュー外観を返す。
function ResolveSerifDrawFrameEditorAppearance(
  const ASettings: TSerifDrawSettings;
  const AEditor: TFrameSerifDrawFrameEditor;
  const AAccentLayer: Integer;
  const ARoleName: string): TSerifDrawFrameStyle;

implementation

procedure LoadSerifDrawFrameEditorStyle(
  const AEditor: TFrameSerifDrawFrameEditor;
  const AKind: TSerifDrawFrameKind; const AStyle: TSerifDrawFrameStyle);
begin
  AEditor.LoadFrameSettings(AKind, TSerifDrawFrameShape(AStyle.Shape),
    AStyle.AccentSource, AStyle.FillMode, AStyle.GradientStrength,
    AStyle.Width, AStyle.Height,
    AStyle.CornerRadius, AStyle.DottedDashLength, AStyle.DottedGapLength,
    AStyle.TabWidth, AStyle.TabHeight, AStyle.TabOffset,
    AStyle.BalloonTailDirection, AStyle.BalloonTailPosition,
    AStyle.BalloonTailWidth, AStyle.BalloonTailLength,
    AStyle.FillVisible, AStyle.OutlineVisible, AStyle.ShadowVisible,
    AStyle.FillColor, AStyle.OutlineColor, AStyle.ShadowColor,
    AStyle.InnerOutlineColor, AStyle.Layering, AStyle.InnerPanelColor,
    AStyle.InnerPanelInsetX, AStyle.InnerPanelInsetY,
    AStyle.InnerPanelRadius, AStyle.OutlineWidth, AStyle.OutlineStyle,
    AStyle.ShadowOffsetX, AStyle.ShadowOffsetY, AStyle.ShadowSpread,
    AStyle.ShadowBlur);
end;

function CaptureSerifDrawFrameEditorStyle(
  const AEditor: TFrameSerifDrawFrameEditor; const ALayer: Integer;
  const APositionX, APositionY: Double): TSerifDrawFrameStyle;
begin
  Result := System.Default(TSerifDrawFrameStyle);
  Result.Layer := ALayer;
  Result.AccentSource := AEditor.AccentSource;
  Result.Shape := Ord(AEditor.FrameShape);
  Result.CornerRadius := AEditor.CornerRadius;
  Result.DottedDashLength := AEditor.DottedDashLength;
  Result.DottedGapLength := AEditor.DottedGapLength;
  Result.TabWidth := AEditor.TabWidth;
  Result.TabHeight := AEditor.TabHeight;
  Result.TabOffset := AEditor.TabOffset;
  Result.BalloonTailPosition := AEditor.BalloonTailPosition;
  Result.BalloonTailDirection := AEditor.BalloonTailDirection;
  Result.BalloonTailWidth := AEditor.BalloonTailWidth;
  Result.BalloonTailLength := AEditor.BalloonTailLength;
  Result.PositionX := APositionX;
  Result.PositionY := APositionY;
  Result.Width := AEditor.CommonFrameWidth;
  Result.Height := AEditor.CommonFrameHeight;
  Result.FillVisible := AEditor.FillVisible;
  Result.OutlineVisible := AEditor.OutlineVisible;
  Result.OutlineWidth := AEditor.OutlineWidth;
  Result.OutlineStyle := AEditor.OutlineStyle;
  Result.ShadowVisible := AEditor.ShadowVisible;
  Result.ShadowBlur := AEditor.ShadowBlur;
  Result.ShadowOffsetX := AEditor.ShadowOffsetX;
  Result.ShadowOffsetY := AEditor.ShadowOffsetY;
  Result.ShadowSpread := AEditor.ShadowSpread;
  Result.FillColor := AEditor.FillColor;
  Result.FillMode := AEditor.FillMode;
  Result.GradientStrength := AEditor.GradientStrength;
  Result.OutlineColor := AEditor.OutlineColor;
  Result.InnerOutlineColor := AEditor.InnerOutlineColor;
  Result.Layering := AEditor.Layering;
  Result.InnerPanelColor := AEditor.InnerPanelColor;
  Result.InnerPanelInsetX := AEditor.InnerPanelInsetX;
  Result.InnerPanelInsetY := AEditor.InnerPanelInsetY;
  Result.InnerPanelRadius := AEditor.InnerPanelRadius;
  Result.ShadowColor := AEditor.ShadowColor;
end;

function ResolveSerifDrawFrameEditorAppearance(
  const ASettings: TSerifDrawSettings;
  const AEditor: TFrameSerifDrawFrameEditor;
  const AAccentLayer: Integer;
  const ARoleName: string): TSerifDrawFrameStyle;
var
  EditorStyle: TSerifDrawFrameStyle;
begin
  if AEditor.FrameKind = sdfkCommon then
    Result := ASettings.ResolveCommonFrameAppearance(ARoleName)
  else
    Result := ASettings.ResolveFrameAppearance(AAccentLayer, ARoleName);
  EditorStyle := CaptureSerifDrawFrameEditorStyle(AEditor, Result.Layer,
    Result.PositionX, Result.PositionY);
  Result.Shape := EditorStyle.Shape;
  Result.CornerRadius := EditorStyle.CornerRadius;
  Result.DottedDashLength := EditorStyle.DottedDashLength;
  Result.DottedGapLength := EditorStyle.DottedGapLength;
  Result.TabWidth := EditorStyle.TabWidth;
  Result.TabHeight := EditorStyle.TabHeight;
  Result.TabOffset := EditorStyle.TabOffset;
  Result.BalloonTailPosition := EditorStyle.BalloonTailPosition;
  Result.BalloonTailDirection := EditorStyle.BalloonTailDirection;
  Result.BalloonTailWidth := EditorStyle.BalloonTailWidth;
  Result.BalloonTailLength := EditorStyle.BalloonTailLength;
  Result.Width := EditorStyle.Width;
  Result.Height := EditorStyle.Height;
  Result.FillMode := EditorStyle.FillMode;
  Result.GradientStrength := EditorStyle.GradientStrength;
  Result.FillVisible := EditorStyle.FillVisible;
  Result.OutlineVisible := EditorStyle.OutlineVisible;
  Result.OutlineWidth := EditorStyle.OutlineWidth;
  Result.OutlineStyle := EditorStyle.OutlineStyle;
  Result.ShadowVisible := EditorStyle.ShadowVisible;
  Result.ShadowBlur := EditorStyle.ShadowBlur;
  Result.ShadowOffsetX := EditorStyle.ShadowOffsetX;
  Result.ShadowOffsetY := EditorStyle.ShadowOffsetY;
  Result.ShadowSpread := EditorStyle.ShadowSpread;
  Result.Layering := EditorStyle.Layering;
  Result.InnerPanelInsetX := EditorStyle.InnerPanelInsetX;
  Result.InnerPanelInsetY := EditorStyle.InnerPanelInsetY;
  Result.InnerPanelRadius := EditorStyle.InnerPanelRadius;
end;

end.
