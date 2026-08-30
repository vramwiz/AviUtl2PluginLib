unit MmdMorphSettingListRenderer;

// モーフ設定一覧の分類見出し、名称、トラック、選択枠を暗色テーマで描画する。

interface

uses
  System.Types,
  System.UITypes,
  Vcl.Graphics;

// 分類見出しの背景、名称、上下罫線を指定範囲へ描画する。
procedure DrawMorphSettingHeader(Canvas: TCanvas; const RowBounds: TRect;
  ContentWidth, PPI: Integer; Panel: Byte);

// 1モーフ分の名称、ウェイトトラック、必要な場合の選択枠を指定範囲へ描画する。
procedure DrawMorphSettingRow(Canvas: TCanvas; const RowBounds, TrackBounds: TRect; PPI: Integer;
  const MorphName: string; Weight: Single; Enabled, Selected, Alternate: Boolean);

implementation

uses
  Winapi.Windows,
  System.Math,
  HorizontalTrackBarRenderer,
  MmdMorphSettingRows,
  MmdPoseEditorTheme;

function RenderScale(Value, PPI: Integer): Integer;
begin
  Result := MulDiv(Value, PPI, 96);
end;

procedure DrawMorphSettingHeader(Canvas: TCanvas; const RowBounds: TRect;
  ContentWidth, PPI: Integer; Panel: Byte);
var
  DrawBounds: TRect;
  LineInset: Integer;
  SavedStyle: TFontStyles;
begin
  Canvas.Brush.Color := MmdEditorControl;
  Canvas.FillRect(RowBounds);
  DrawBounds := RowBounds;
  DrawBounds.Left := RenderScale(8, PPI);
  DrawBounds.Right := ContentWidth - RenderScale(6, PPI);
  SavedStyle := Canvas.Font.Style;
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := MmdEditorText;
  Canvas.Font.Style := SavedStyle + [fsBold];
  DrawText(Canvas.Handle, PChar(MorphPanelCaption(Panel)), -1, DrawBounds,
    DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
  Canvas.Font.Style := SavedStyle;
  Canvas.Brush.Style := bsSolid;

  // 罫線は高DPI時のクリッピングを避けるため、行境界ではなく背景の内側へ描く。
  LineInset := RenderScale(1, PPI);
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := Max(LineInset, 1);
  Canvas.Pen.Color := TColor(RGB(220, 220, 220));
  Canvas.MoveTo(RowBounds.Left, RowBounds.Top + LineInset);
  Canvas.LineTo(RowBounds.Right, RowBounds.Top + LineInset);
  Canvas.MoveTo(RowBounds.Left, RowBounds.Bottom - LineInset - 1);
  Canvas.LineTo(RowBounds.Right, RowBounds.Bottom - LineInset - 1);
  Canvas.Pen.Width := 1;
end;

procedure DrawMorphSettingRow(Canvas: TCanvas; const RowBounds, TrackBounds: TRect; PPI: Integer;
  const MorphName: string; Weight: Single; Enabled, Selected, Alternate: Boolean);
var
  DrawBounds: TRect;
  RowColor: TColor;
  State: THorizontalTrackBarRenderState;
begin
  if Alternate then
    RowColor := MmdEditorPanel
  else
    RowColor := MmdEditorBackground;
  Canvas.Brush.Color := RowColor;
  Canvas.FillRect(RowBounds);

  DrawBounds := RowBounds;
  DrawBounds.Left := RenderScale(6, PPI);
  DrawBounds.Right := TrackBounds.Left - RenderScale(6, PPI);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := MmdEditorText;
  DrawText(Canvas.Handle, PChar(MorphName), Length(MorphName), DrawBounds,
    DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
  Canvas.Brush.Style := bsSolid;

  State.BackgroundColor := RowColor;
  State.ChannelColor := MmdEditorBorder;
  State.ClientRect := Rect(TrackBounds.Left, RowBounds.Top, TrackBounds.Right, RowBounds.Bottom);
  State.DisabledColor := MmdEditorDisabledText;
  State.Enabled := Enabled;
  State.FillColor := MmdEditorSelection;
  State.Focused := False;
  State.Frequency := 10;
  State.Maximum := 100;
  State.Minimum := 0;
  State.PPI := PPI;
  State.ShowTicks := False;
  State.ThumbBorderColor := MmdEditorText;
  State.ThumbColor := MmdEditorControl;
  State.ThumbX := TrackBounds.Left + MulDiv(Round(Weight * 100), TrackBounds.Width, 100);
  State.TickColor := MmdEditorDisabledText;
  State.TrackRect := TrackBounds;
  DrawHorizontalTrackBar(Canvas, State);

  // トラック描画の背景消去で欠けないよう、選択枠は行の全要素より後に重ねる。
  if Selected then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := MmdEditorSelection;
    Canvas.Rectangle(RowBounds);
    Canvas.Brush.Style := bsSolid;
  end;
end;

end.
