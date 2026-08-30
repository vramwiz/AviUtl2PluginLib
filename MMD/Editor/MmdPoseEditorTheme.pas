unit MmdPoseEditorTheme;

// 共通ポーズ編集GUIの配色、項目描画、Windowsタイトルバー配色を定義する。

interface

uses
  System.Types,
  Vcl.Forms,
  Vcl.Graphics;

const
  MmdEditorBackground = TColor($001E1E1E);
  MmdEditorPanel = TColor($002B2B2B);
  MmdEditorControl = TColor($003A3A3A);
  MmdEditorBorder = TColor($00505050);
  MmdEditorText = TColor($00DCDCDC);
  MmdEditorDisabledText = TColor($00808080);
  // TColorはBGR格納。画面上ではRGB(102, 102, 255)の青になる。
  MmdEditorSelection = TColor($00FF6666);
  MmdEditorHot = TColor($00454545);
  MmdEditorPressed = TColor($001F1F1F);

// 一覧とコンボの1項目を共通の背景、選択色、フォーカス枠で描画する。
procedure DrawMmdDarkItem(Canvas: TCanvas; const Text: string; Rect: TRect;
  Selected, Focused: Boolean);
// 生成済みフォームのタイトル、文字、境界を共通暗色へ設定する。
procedure ApplyMmdDarkTitleBar(Form: TCustomForm);

implementation

uses
  Winapi.Dwmapi,
  Winapi.Windows;

procedure DrawMmdDarkItem(Canvas: TCanvas; const Text: string; Rect: TRect;
  Selected, Focused: Boolean);
begin
  if Selected then
  begin
    Canvas.Brush.Color := MmdEditorSelection;
    Canvas.Font.Color := clWhite;
  end
  else
  begin
    Canvas.Brush.Color := MmdEditorControl;
    Canvas.Font.Color := MmdEditorText;
  end;
  Canvas.FillRect(Rect);
  Inc(Rect.Left, 6);
  Canvas.TextRect(Rect, Rect.Left,
    Rect.Top + (Rect.Height - Canvas.TextHeight(Text)) div 2, Text);
  if Focused then
  begin
    Dec(Rect.Left, 4);
    Canvas.DrawFocusRect(Rect);
  end;
end;

procedure ApplyMmdDarkTitleBar(Form: TCustomForm);
const
  DwmUseImmersiveDarkModeBefore20H1 = 19;
  DwmUseImmersiveDarkMode = 20;
  DwmBorderColor = 34;
  DwmCaptionColor = 35;
  DwmTextColor = 36;
var
  BorderColor, CaptionColor: COLORREF;
  Enabled: LongBool;
  TextColor: COLORREF;
begin
  if not Assigned(Form) or not Form.HandleAllocated then Exit;
  Enabled := True;
  if Failed(DwmSetWindowAttribute(Form.Handle, DwmUseImmersiveDarkMode,
    @Enabled, SizeOf(Enabled))) then
    DwmSetWindowAttribute(Form.Handle, DwmUseImmersiveDarkModeBefore20H1,
      @Enabled, SizeOf(Enabled));
  BorderColor := ColorToRGB(MmdEditorBorder);
  CaptionColor := ColorToRGB(MmdEditorPanel);
  TextColor := ColorToRGB(MmdEditorText);
  DwmSetWindowAttribute(Form.Handle, DwmBorderColor, @BorderColor,
    SizeOf(BorderColor));
  DwmSetWindowAttribute(Form.Handle, DwmCaptionColor, @CaptionColor,
    SizeOf(CaptionColor));
  DwmSetWindowAttribute(Form.Handle, DwmTextColor, @TextColor,
    SizeOf(TextColor));
end;

end.
