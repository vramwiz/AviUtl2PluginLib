unit DarkMemo;

// 通常・フォーカス・無効状態を共通化した複数行入力を提供する。
interface

uses
  Winapi.Messages,
  System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls,
  DarkThemeDpiContext;

type
  TDarkMemo = class(TMemo)
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
    FUseThemeFont: Boolean;
    procedure CMDarkThemeDpiChanged(var Message: TMessage);
      message CM_DARKTHEME_DPICHANGED;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure CMEnter(var Message: TCMEnter); message CM_ENTER;
    procedure CMExit(var Message: TCMExit); message CM_EXIT;
    procedure SetDesignFontHeight(const Value: Integer);
    procedure SetDesignHeight(const Value: Integer);
    procedure SetDpiContext(const Value: TDarkThemeDpiContext);
    procedure SetUseThemeFont(const Value: Boolean);
    procedure UpdateVisualState;
    procedure WMNCPaint(var Message: TWMNCPaint); message WM_NCPAINT;
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    // 共通入力配色を持ち、高さを呼出側で選べる複数行入力を生成する。
    constructor Create(AOwner: TComponent); override;
    // 共有DPIコンテキストから切り離して複数行入力を破棄する。
    destructor Destroy; override;
    // 基準文字高と任意の基準高さを現在DPIへ反映する。
    procedure ApplyDpi;
    // 有効状態とフォーカスに対応する背景・文字・枠色を再適用する。
    procedure ApplyTheme;
  published
    property DesignFontHeight: Integer read FDesignFontHeight
      write SetDesignFontHeight default 12;
    property DesignHeight: Integer read FDesignHeight write SetDesignHeight
      default 0;
    property DpiContext: TDarkThemeDpiContext read FDpiContext
      write SetDpiContext;
    property UseThemeFont: Boolean read FUseThemeFont write SetUseThemeFont
      default True;
  end;

implementation

uses
  Winapi.Windows,
  DarkThemeColors, DarkThemeMetrics;

constructor TDarkMemo.Create(AOwner: TComponent);
begin
  inherited;
  FDesignFontHeight := DarkThemeDefaultFontHeight;
  FDesignHeight := 0;
  FUseThemeFont := True;
  FNormalBackgroundColor := DarkThemeEditBackground;
  FFocusBackgroundColor := DarkThemeEditBackgroundFocus;
  FDisabledBackgroundColor := DarkThemeEditDisabled;
  FNormalBorderColor := DarkThemeEditBorder;
  FFocusBorderColor := DarkThemeEditBorderFocus;
  FNormalTextColor := DarkThemeEditText;
  FDisabledTextColor := DarkThemeEditDisabledText;
  ParentColor := False;
  ParentFont := False;
  Ctl3D := False;
  ApplyTheme;
  ApplyDpi;
end;

destructor TDarkMemo.Destroy;
begin
  SetDpiContext(nil);
  inherited;
end;

procedure TDarkMemo.ApplyDpi;
var
  Metrics: TDarkThemeMetrics;
begin
  if FDpiContext <> nil then
    Metrics := FDpiContext.Metrics
  else
    Metrics := TDarkThemeMetrics.Create(CurrentPPI);
  if FUseThemeFont then
    Font.Height := Metrics.FontHeight(FDesignFontHeight);
  if FDesignHeight > 0 then
    Height := Metrics.Scale(FDesignHeight);
  Invalidate;
  if HandleAllocated then
    RedrawWindow(Handle, nil, 0, RDW_FRAME or RDW_INVALIDATE);
end;

procedure TDarkMemo.ApplyTheme;
begin
  UpdateVisualState;
end;

procedure TDarkMemo.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited;
  if FDpiContext <> nil then
    FDpiContext.Dpi := M
  else
    ApplyDpi;
end;

procedure TDarkMemo.CMDarkThemeDpiChanged(var Message: TMessage);
begin
  ApplyDpi;
end;

procedure TDarkMemo.CMEnabledChanged(var Message: TMessage);
begin
  inherited;
  UpdateVisualState;
end;

procedure TDarkMemo.CMEnter(var Message: TCMEnter);
begin
  inherited;
  UpdateVisualState;
end;

procedure TDarkMemo.CMExit(var Message: TCMExit);
begin
  inherited;
  UpdateVisualState;
end;

procedure TDarkMemo.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDpiContext) then
    FDpiContext := nil;
end;

procedure TDarkMemo.SetDesignFontHeight(const Value: Integer);
var
  NewValue: Integer;
begin
  if Value < 1 then NewValue := 1 else NewValue := Value;
  if FDesignFontHeight = NewValue then Exit;
  FDesignFontHeight := NewValue;
  ApplyDpi;
end;

procedure TDarkMemo.SetDesignHeight(const Value: Integer);
var
  NewValue: Integer;
begin
  if Value < 0 then NewValue := 0 else NewValue := Value;
  if FDesignHeight = NewValue then Exit;
  FDesignHeight := NewValue;
  ApplyDpi;
end;

procedure TDarkMemo.SetDpiContext(const Value: TDarkThemeDpiContext);
begin
  if FDpiContext = Value then Exit;
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

procedure TDarkMemo.SetUseThemeFont(const Value: Boolean);
begin
  if FUseThemeFont = Value then Exit;
  FUseThemeFont := Value;
  ApplyDpi;
end;

procedure TDarkMemo.UpdateVisualState;
begin
  if not Enabled then
  begin
    Color := FDisabledBackgroundColor;
    Font.Color := FDisabledTextColor;
  end
  else
  begin
    if Focused then Color := FFocusBackgroundColor
    else Color := FNormalBackgroundColor;
    Font.Color := FNormalTextColor;
  end;
  Invalidate;
  if HandleAllocated then
    RedrawWindow(Handle, nil, 0, RDW_FRAME or RDW_INVALIDATE);
end;

procedure TDarkMemo.WMNCPaint(var Message: TWMNCPaint);
var
  BorderColor: TColor;
  BorderWidth: Integer;
  Brush: HBRUSH;
  DC: HDC;
  I: Integer;
  R: TRect;
begin
  inherited;
  if BorderStyle = bsNone then Exit;
  if Enabled and Focused then BorderColor := FFocusBorderColor
  else BorderColor := FNormalBorderColor;
  if FDpiContext <> nil then
    BorderWidth := FDpiContext.Metrics.ScaleAtLeastOne(DarkThemeBorderWidth)
  else
    BorderWidth := TDarkThemeMetrics.Create(CurrentPPI).ScaleAtLeastOne(
      DarkThemeBorderWidth);
  DC := GetWindowDC(Handle);
  if DC = 0 then Exit;
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
  System.Classes.RegisterClass(TDarkMemo);

end.
