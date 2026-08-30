unit DarkComboBox;

// 選択欄・候補一覧・フォーカスを共通描画するダークコンボを提供する。
interface

uses
  Winapi.Messages,
  System.Classes, System.Types,
  Vcl.Controls, Vcl.StdCtrls,
  DarkThemeDpiContext;

type
  TDarkComboBox = class(TComboBox)
  private
    FDesignFontHeight: Integer;
    FDesignItemHeight: Integer;
    FDpiContext: TDarkThemeDpiContext;
    procedure CMDarkThemeDpiChanged(var Message: TMessage); message CM_DARKTHEME_DPICHANGED;
    procedure SetDesignFontHeight(const Value: Integer);
    procedure SetDesignItemHeight(const Value: Integer);
    procedure SetDpiContext(const Value: TDarkThemeDpiContext);
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
    procedure CreateWnd; override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    // 固定高のオーナー描画コンボを共通配色で生成する。
    constructor Create(AOwner: TComponent); override;
    // 共有DPIコンテキストから切り離してコンボを破棄する。
    destructor Destroy; override;
    // 基準文字高と項目高を現在DPIへ反映する。
    procedure ApplyDpi;
    // 選択欄と候補一覧の共通配色を再適用する。
    procedure ApplyTheme;
  published
    property DesignFontHeight: Integer read FDesignFontHeight write SetDesignFontHeight default 12;
    property DesignItemHeight: Integer read FDesignItemHeight write SetDesignItemHeight default 24;
    property DpiContext: TDarkThemeDpiContext read FDpiContext write SetDpiContext;
  end;

implementation

uses
  Winapi.UxTheme, Winapi.Windows,
  Vcl.Graphics,
  DarkThemeColors, DarkThemeMetrics;

constructor TDarkComboBox.Create(AOwner: TComponent);
begin
  inherited;
  FDesignFontHeight := DarkThemeDefaultFontHeight;
  FDesignItemHeight := 24;
  ParentColor := False;
  ParentFont := False;
  Style := csOwnerDrawFixed;
  ApplyTheme;
  ApplyDpi;
end;

destructor TDarkComboBox.Destroy;
begin
  SetDpiContext(nil);
  inherited;
end;

procedure TDarkComboBox.ApplyDpi;
var
  Metrics: TDarkThemeMetrics;
begin
  if FDpiContext <> nil then Metrics := FDpiContext.Metrics
  else Metrics := TDarkThemeMetrics.Create(CurrentPPI);
  Font.Height := Metrics.FontHeight(FDesignFontHeight);
  ItemHeight := Metrics.Scale(FDesignItemHeight);
  Invalidate;
end;

procedure TDarkComboBox.ApplyTheme;
begin
  Color := DarkThemeComboBackground;
  Font.Color := DarkThemeComboText;
  Invalidate;
end;

procedure TDarkComboBox.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited;
  if FDpiContext <> nil then FDpiContext.Dpi := M else ApplyDpi;
end;

procedure TDarkComboBox.CMDarkThemeDpiChanged(var Message: TMessage);
begin
  ApplyDpi;
end;

procedure TDarkComboBox.CreateWnd;
begin
  inherited;
  SetWindowTheme(Handle, 'DarkMode_CFD', nil);
end;

procedure TDarkComboBox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  TextValue: string;
begin
  if odSelected in State then
  begin
    Canvas.Brush.Color := DarkThemeComboHighlight;
    Canvas.Font.Color := DarkThemeComboText;
  end
  else
  begin
    Canvas.Brush.Color := DarkThemeComboBackground;
    if Enabled then Canvas.Font.Color := DarkThemeComboText
    else Canvas.Font.Color := DarkThemeControlDisabledText;
  end;
  Canvas.FillRect(Rect);
  TextValue := '';
  if (Index >= 0) and (Index < Items.Count) then TextValue := Items[Index];
  Inc(Rect.Left, 6);
  Canvas.TextRect(Rect, Rect.Left,
    Rect.Top + (Rect.Height - Canvas.TextHeight(TextValue)) div 2, TextValue);
  if odFocused in State then
  begin
    Dec(Rect.Left, 4);
    Canvas.DrawFocusRect(Rect);
  end;
end;

procedure TDarkComboBox.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDpiContext) then FDpiContext := nil;
end;

procedure TDarkComboBox.SetDesignFontHeight(const Value: Integer);
begin
  if (Value < 1) or (FDesignFontHeight = Value) then Exit;
  FDesignFontHeight := Value;
  ApplyDpi;
end;

procedure TDarkComboBox.SetDesignItemHeight(const Value: Integer);
begin
  if (Value < 1) or (FDesignItemHeight = Value) then Exit;
  FDesignItemHeight := Value;
  ApplyDpi;
end;

procedure TDarkComboBox.SetDpiContext(const Value: TDarkThemeDpiContext);
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
  else ApplyDpi;
end;

procedure TDarkComboBox.WMPaint(var Message: TWMPaint);
var
  ArrowRect, DrawRect, TextRect: TRect;
  ArrowColor: TColor;
  PaintCanvas: TControlCanvas;
  CenterX, CenterY: Integer;
  TextValue: string;
begin
  inherited;
  PaintCanvas := TControlCanvas.Create;
  try
    PaintCanvas.Control := Self;
    DrawRect := ClientRect;
    PaintCanvas.Brush.Color := DarkThemeComboBackground;
    PaintCanvas.FillRect(DrawRect);
    PaintCanvas.Brush.Style := bsClear;
    if Focused then PaintCanvas.Pen.Color := DarkThemeEditBorderFocus
    else PaintCanvas.Pen.Color := DarkThemeControlBorder;
    PaintCanvas.Rectangle(DrawRect);
    ArrowRect := DrawRect;
    ArrowRect.Left := ArrowRect.Right - GetSystemMetrics(SM_CXVSCROLL);
    PaintCanvas.Brush.Style := bsSolid;
    PaintCanvas.Brush.Color := DarkThemeComboButton;
    PaintCanvas.FillRect(ArrowRect);
    PaintCanvas.Pen.Color := DarkThemeControlBorder;
    PaintCanvas.MoveTo(ArrowRect.Left, ArrowRect.Top + 1);
    PaintCanvas.LineTo(ArrowRect.Left, ArrowRect.Bottom - 1);
    CenterX := (ArrowRect.Left + ArrowRect.Right) div 2;
    CenterY := (ArrowRect.Top + ArrowRect.Bottom) div 2;
    if Enabled then ArrowColor := DarkThemeComboText
    else ArrowColor := DarkThemeControlDisabledText;
    PaintCanvas.Brush.Color := ArrowColor;
    PaintCanvas.Pen.Color := ArrowColor;
    PaintCanvas.Polygon([Point(CenterX - 4, CenterY - 2),
      Point(CenterX + 4, CenterY - 2), Point(CenterX, CenterY + 3)]);
    TextValue := '';
    if (ItemIndex >= 0) and (ItemIndex < Items.Count) then TextValue := Items[ItemIndex];
    TextRect := DrawRect;
    Inc(TextRect.Left, 6);
    TextRect.Right := ArrowRect.Left - 4;
    PaintCanvas.Brush.Style := bsClear;
    PaintCanvas.Font.Assign(Font);
    if Enabled then PaintCanvas.Font.Color := DarkThemeComboText
    else PaintCanvas.Font.Color := DarkThemeControlDisabledText;
    DrawText(PaintCanvas.Handle, PChar(TextValue), Length(TextValue), TextRect,
      DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
  finally
    PaintCanvas.Free;
  end;
end;

initialization
  System.Classes.RegisterClass(TDarkComboBox);

end.
