unit DarkEdit;

// 通常・フォーカス・無効状態と内側余白を共通化した単行入力を提供する。
interface

uses
  Winapi.Messages,
  System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls,
  DarkThemeDpiContext;

type
  TDarkEdit = class(TEdit)
  private
    FDesignFontHeight: Integer;
    FDesignHeight: Integer;
    FDisabledBackgroundColor: TColor;
    FDisabledTextColor: TColor;
    FDpiContext: TDarkThemeDpiContext;
    FFocusBackgroundColor: TColor;
    FFocusBorderColor: TColor;
    FNormalBackgroundColor: TColor;
    FNormalBorderColor: TColor;
    FNormalTextColor: TColor;
    procedure CMDarkThemeDpiChanged(var Message: TMessage);
      message CM_DARKTHEME_DPICHANGED;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure CMEnter(var Message: TCMEnter); message CM_ENTER;
    procedure CMExit(var Message: TCMExit); message CM_EXIT;
    procedure SetDesignFontHeight(const Value: Integer);
    procedure SetDesignHeight(const Value: Integer);
    procedure SetDpiContext(const Value: TDarkThemeDpiContext);
    procedure UpdateVisualState;
    procedure WMNCPaint(var Message: TWMNCPaint); message WM_NCPAINT;
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    // 共通入力配色と基準高さを持つ単行入力を生成する。
    constructor Create(AOwner: TComponent); override;
    // 共有DPIコンテキストから切り離して入力Controlを破棄する。
    destructor Destroy; override;
    // 基準文字高・高さ・左右余白を現在DPIへ反映する。
    procedure ApplyDpi;
    // 有効状態とフォーカスに対応する背景・文字・枠色を再適用する。
    procedure ApplyTheme;
  published
    property DesignFontHeight: Integer read FDesignFontHeight
      write SetDesignFontHeight default 12;
    property DesignHeight: Integer read FDesignHeight write SetDesignHeight
      default 30;
    property DpiContext: TDarkThemeDpiContext read FDpiContext
      write SetDpiContext;
  end;

implementation

uses
  Winapi.Windows,
  DarkThemeColors, DarkThemeMetrics;

constructor TDarkEdit.Create(AOwner: TComponent);
begin
  inherited;
  FDesignFontHeight := DarkThemeDefaultFontHeight;
  FDesignHeight := 30;
  FNormalBackgroundColor := DarkThemeEditBackground;
  FFocusBackgroundColor := DarkThemeEditBackgroundFocus;
  FDisabledBackgroundColor := DarkThemeEditDisabled;
  FNormalBorderColor := DarkThemeEditBorder;
  FFocusBorderColor := DarkThemeEditBorderFocus;
  FNormalTextColor := DarkThemeEditText;
  FDisabledTextColor := DarkThemeEditDisabledText;
  AutoSize := False;
  ParentColor := False;
  ParentFont := False;
  Ctl3D := False;
  BorderStyle := bsSingle;
  ApplyTheme;
  ApplyDpi;
end;

destructor TDarkEdit.Destroy;
begin
  SetDpiContext(nil);
  inherited;
end;

procedure TDarkEdit.ApplyDpi;
var
  Metrics: TDarkThemeMetrics;
  Padding: Integer;
begin
  if FDpiContext <> nil then
    Metrics := FDpiContext.Metrics
  else
    Metrics := TDarkThemeMetrics.Create(CurrentPPI);
  Font.Height := Metrics.FontHeight(FDesignFontHeight);
  if FDesignHeight > 0 then
    Height := Metrics.Scale(FDesignHeight);
  Padding := Metrics.Scale(DarkThemeTextPadding);
  if HandleAllocated then
    SendMessage(Handle, EM_SETMARGINS, EC_LEFTMARGIN or EC_RIGHTMARGIN,
      MakeLParam(Padding, Padding));
  Invalidate;
  if HandleAllocated then
    RedrawWindow(Handle, nil, 0, RDW_FRAME or RDW_INVALIDATE);
end;

procedure TDarkEdit.ApplyTheme;
begin
  UpdateVisualState;
end;

procedure TDarkEdit.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited;
  if FDpiContext <> nil then
    FDpiContext.Dpi := M
  else
    ApplyDpi;
end;

procedure TDarkEdit.CMDarkThemeDpiChanged(var Message: TMessage);
begin
  ApplyDpi;
end;

procedure TDarkEdit.CMEnabledChanged(var Message: TMessage);
begin
  inherited;
  UpdateVisualState;
end;

procedure TDarkEdit.CMEnter(var Message: TCMEnter);
begin
  inherited;
  UpdateVisualState;
end;

procedure TDarkEdit.CMExit(var Message: TCMExit);
begin
  inherited;
  UpdateVisualState;
end;

procedure TDarkEdit.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDpiContext) then
    FDpiContext := nil;
end;

procedure TDarkEdit.SetDesignFontHeight(const Value: Integer);
var
  NewValue: Integer;
begin
  if Value < 1 then
    NewValue := 1
  else
    NewValue := Value;
  if FDesignFontHeight = NewValue then
    Exit;
  FDesignFontHeight := NewValue;
  ApplyDpi;
end;

procedure TDarkEdit.SetDesignHeight(const Value: Integer);
var
  NewValue: Integer;
begin
  if Value < 0 then
    NewValue := 0
  else
    NewValue := Value;
  if FDesignHeight = NewValue then
    Exit;
  FDesignHeight := NewValue;
  ApplyDpi;
end;

procedure TDarkEdit.SetDpiContext(const Value: TDarkThemeDpiContext);
begin
  if FDpiContext = Value then
    Exit;
  if FDpiContext <> nil then
  begin
    FDpiContext.UnregisterControl(Self);
    FDpiContext.RemoveFreeNotification(Self);
  end;
  FDpiContext := Value;
  if FDpiContext <> nil then
  begin
    FDpiContext.FreeNotification(Self);
    FDpiContext.RegisterControl(Self);
  end
  else
    ApplyDpi;
end;

procedure TDarkEdit.UpdateVisualState;
begin
  if not Enabled then
  begin
    Color := FDisabledBackgroundColor;
    Font.Color := FDisabledTextColor;
  end
  else
  begin
    if Focused then
      Color := FFocusBackgroundColor
    else
      Color := FNormalBackgroundColor;
    Font.Color := FNormalTextColor;
  end;
  Invalidate;
  if HandleAllocated then
    RedrawWindow(Handle, nil, 0, RDW_FRAME or RDW_INVALIDATE);
end;

procedure TDarkEdit.WMNCPaint(var Message: TWMNCPaint);
var
  BorderColor: TColor;
  BorderWidth: Integer;
  Brush: HBRUSH;
  DC: HDC;
  I: Integer;
  R: TRect;
begin
  inherited;
  if not Enabled then
    BorderColor := FNormalBorderColor
  else if Focused then
    BorderColor := FFocusBorderColor
  else
    BorderColor := FNormalBorderColor;
  if FDpiContext <> nil then
    BorderWidth := FDpiContext.Metrics.ScaleAtLeastOne(DarkThemeBorderWidth)
  else
    BorderWidth := TDarkThemeMetrics.Create(CurrentPPI).ScaleAtLeastOne(
      DarkThemeBorderWidth);

  DC := GetWindowDC(Handle);
  if DC = 0 then
    Exit;
  try
    GetWindowRect(Handle, R);
    OffsetRect(R, -R.Left, -R.Top);
    Brush := CreateSolidBrush(ColorToRGB(BorderColor));
    try
      for I := 1 to BorderWidth do
      begin
        FrameRect(DC, R, Brush);
        InflateRect(R, -1, -1);
      end;
    finally
      DeleteObject(Brush);
    end;
  finally
    ReleaseDC(Handle, DC);
  end;
end;

initialization
  System.Classes.RegisterClass(TDarkEdit);

end.
