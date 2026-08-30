unit DarkLabel;

// 通常・無効文字色と基準文字高を共通化したダークラベルを提供する。
interface

uses
  Winapi.Messages,
  System.Classes,
  Vcl.Controls, Vcl.Graphics, Vcl.StdCtrls,
  DarkThemeDpiContext;

type
  TDarkLabel = class(TLabel)
  private
    FDesignFontHeight: Integer;
    FDesignHeight: Integer;
    FDisabledTextColor: TColor;
    FDpiContext: TDarkThemeDpiContext;
    FTextColor: TColor;
    FUseThemeFont: Boolean;
    procedure CMDarkThemeDpiChanged(var Message: TMessage);
      message CM_DARKTHEME_DPICHANGED;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure SetDesignFontHeight(const Value: Integer);
    procedure SetDesignHeight(const Value: Integer);
    procedure SetDisabledTextColor(const Value: TColor);
    procedure SetDpiContext(const Value: TDarkThemeDpiContext);
    procedure SetTextColor(const Value: TColor);
    procedure SetUseThemeFont(const Value: Boolean);
    procedure UpdateTextColor;
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    // 共通文字色と基準文字高を持つ透明ラベルを生成する。
    constructor Create(AOwner: TComponent); override;
    // 共有DPIコンテキストから切り離してラベルを破棄する。
    destructor Destroy; override;
    // 基準文字高と任意の基準高さを現在DPIへ反映する。
    procedure ApplyDpi;
    // 通常・無効状態に対応する共通文字色を再適用する。
    procedure ApplyTheme;
  published
    property DesignFontHeight: Integer read FDesignFontHeight
      write SetDesignFontHeight default 12;
    property DesignHeight: Integer read FDesignHeight write SetDesignHeight
      default 0;
    property DisabledTextColor: TColor read FDisabledTextColor
      write SetDisabledTextColor default $828282;
    property DpiContext: TDarkThemeDpiContext read FDpiContext
      write SetDpiContext;
    property TextColor: TColor read FTextColor write SetTextColor
      default $DCDCDC;
    property UseThemeFont: Boolean read FUseThemeFont write SetUseThemeFont
      default True;
  end;

implementation

uses
  DarkThemeColors, DarkThemeMetrics;

constructor TDarkLabel.Create(AOwner: TComponent);
begin
  inherited;
  FDesignFontHeight := DarkThemeDefaultFontHeight;
  FTextColor := DarkThemeTextNormal;
  FDisabledTextColor := DarkThemeTextDisabled;
  FUseThemeFont := True;
  ParentFont := False;
  ApplyTheme;
  ApplyDpi;
end;

destructor TDarkLabel.Destroy;
begin
  SetDpiContext(nil);
  inherited;
end;

procedure TDarkLabel.ApplyDpi;
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
end;

procedure TDarkLabel.ApplyTheme;
begin
  Transparent := True;
  UpdateTextColor;
end;

procedure TDarkLabel.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited;
  if FDpiContext <> nil then
    FDpiContext.Dpi := M
  else
    ApplyDpi;
end;

procedure TDarkLabel.CMDarkThemeDpiChanged(var Message: TMessage);
begin
  ApplyDpi;
end;

procedure TDarkLabel.CMEnabledChanged(var Message: TMessage);
begin
  inherited;
  UpdateTextColor;
end;

procedure TDarkLabel.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDpiContext) then
    FDpiContext := nil;
end;

procedure TDarkLabel.SetDesignFontHeight(const Value: Integer);
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

procedure TDarkLabel.SetDesignHeight(const Value: Integer);
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

procedure TDarkLabel.SetDisabledTextColor(const Value: TColor);
begin
  if FDisabledTextColor = Value then
    Exit;
  FDisabledTextColor := Value;
  UpdateTextColor;
end;

procedure TDarkLabel.SetDpiContext(const Value: TDarkThemeDpiContext);
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

procedure TDarkLabel.SetTextColor(const Value: TColor);
begin
  if FTextColor = Value then
    Exit;
  FTextColor := Value;
  UpdateTextColor;
end;

procedure TDarkLabel.SetUseThemeFont(const Value: Boolean);
begin
  if FUseThemeFont = Value then
    Exit;
  FUseThemeFont := Value;
  ParentFont := not FUseThemeFont;
  ApplyDpi;
end;

procedure TDarkLabel.UpdateTextColor;
begin
  if Enabled then
    Font.Color := FTextColor
  else
    Font.Color := FDisabledTextColor;
  Invalidate;
end;

initialization
  RegisterClass(TDarkLabel);

end.
