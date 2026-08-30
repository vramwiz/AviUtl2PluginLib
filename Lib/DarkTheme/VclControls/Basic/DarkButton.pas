unit DarkButton;

// VCL標準ボタン相当の操作とダーク描画、共有DPI寸法を提供する。
interface

uses
  Winapi.Messages,
  System.Classes, System.Types,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics,
  DarkThemeDpiContext;

type
  TDarkButton = class(TCustomControl)
  private
    FCancel: Boolean;
    FDefault: Boolean;
    FDpiContext: TDarkThemeDpiContext;
    FHot: Boolean;
    FModalResult: TModalResult;
    FPressed: Boolean;
    procedure CMCursorChanged(var Message: TMessage); message CM_CURSORCHANGED;
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
    procedure CMDarkThemeDpiChanged(var Message: TMessage);
      message CM_DARKTHEME_DPICHANGED;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure SetDpiContext(const Value: TDarkThemeDpiContext);
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
    procedure Click; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
    procedure Paint; override;
  public
    // 共通テーマの既定寸法とキーボード操作を持つボタンを生成する。
    constructor Create(AOwner: TComponent); override;
    // 共有DPIコンテキストから切り離してボタンを破棄する。
    destructor Destroy; override;
    // 現在の共有DPIまたはCurrentPPIから文字高とボタン高を更新する。
    procedure ApplyDpi;
  published
    property Align;
    property Anchors;
    property Cancel: Boolean read FCancel write FCancel default False;
    property Caption;
    property Constraints;
    property Default: Boolean read FDefault write FDefault default False;
    property DpiContext: TDarkThemeDpiContext read FDpiContext write SetDpiContext;
    property Enabled;
    property Font;
    property ModalResult: TModalResult read FModalResult write FModalResult default 0;
    property ParentFont;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
  end;

implementation

uses
  Winapi.Windows,
  DarkThemeColors, DarkThemeMetrics;

constructor TDarkButton.Create(AOwner: TComponent);
var
  Metrics: TDarkThemeMetrics;
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque, csClickEvents, csDoubleClicks];
  TabStop := True;
  Metrics := TDarkThemeMetrics.Create(CurrentPPI);
  SetBounds(Left, Top, Metrics.Scale(DarkThemeButtonWidth),
    Metrics.Scale(DarkThemeButtonHeight));
  ParentFont := False;
  Font.Height := Metrics.FontHeight;
  Font.Color := DarkThemeControlText;
end;

destructor TDarkButton.Destroy;
begin
  SetDpiContext(nil);
  inherited;
end;

procedure TDarkButton.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited;
  if FDpiContext <> nil then
    FDpiContext.Dpi := M
  else
    ApplyDpi;
end;

procedure TDarkButton.ApplyDpi;
var
  Metrics: TDarkThemeMetrics;
begin
  if FDpiContext <> nil then
    Metrics := FDpiContext.Metrics
  else
    Metrics := TDarkThemeMetrics.Create(CurrentPPI);
  Font.Height := Metrics.FontHeight;
  if not (Align in [alTop, alBottom, alClient]) then
    Height := Metrics.Scale(DarkThemeButtonHeight);
  Invalidate;
end;

procedure TDarkButton.Click;
var
  Form: TCustomForm;
begin
  inherited;
  if FModalResult = 0 then
    Exit;
  Form := GetParentForm(Self);
  if Form <> nil then
    Form.ModalResult := FModalResult;
end;

procedure TDarkButton.CMCursorChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;

procedure TDarkButton.CMDialogKey(var Message: TCMDialogKey);
begin
  if Enabled and ((FDefault and (Message.CharCode = VK_RETURN)) or
    (FCancel and (Message.CharCode = VK_ESCAPE))) then
  begin
    Click;
    Message.Result := 1;
  end
  else
    inherited;
end;

procedure TDarkButton.CMDarkThemeDpiChanged(var Message: TMessage);
begin
  ApplyDpi;
end;

procedure TDarkButton.CMEnabledChanged(var Message: TMessage);
begin
  inherited;
  FPressed := False;
  Invalidate;
end;

procedure TDarkButton.CMFontChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;

procedure TDarkButton.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FHot := True;
  Invalidate;
end;

procedure TDarkButton.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FHot := False;
  if not (csLButtonDown in ControlState) then
    FPressed := False;
  Invalidate;
end;

procedure TDarkButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if not Enabled or (Shift <> []) then
    Exit;
  if Key = VK_RETURN then
  begin
    Click;
    Key := 0;
  end
  else if Key = VK_SPACE then
  begin
    FPressed := True;
    Invalidate;
    Key := 0;
  end;
end;

procedure TDarkButton.KeyUp(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if Enabled and FPressed and (Key = VK_SPACE) then
  begin
    FPressed := False;
    Invalidate;
    Click;
    Key := 0;
  end;
end;

procedure TDarkButton.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
  if Enabled and (Button = mbLeft) then
  begin
    FPressed := True;
    MouseCapture := True;
    if CanFocus then
      SetFocus;
    Invalidate;
  end;
end;

procedure TDarkButton.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  DoClick: Boolean;
begin
  inherited;
  if Button <> mbLeft then
    Exit;
  DoClick := Enabled and FPressed and PtInRect(ClientRect, Point(X, Y));
  FPressed := False;
  MouseCapture := False;
  Invalidate;
  if DoClick then
    Click;
end;

procedure TDarkButton.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDpiContext) then
    FDpiContext := nil;
end;

procedure TDarkButton.Paint;
var
  BorderWidth: Integer;
  FocusRect: TRect;
  R: TRect;
  TextFlags: Longint;
  TextPadding: Integer;
begin
  R := ClientRect;
  if not Enabled then
    Canvas.Brush.Color := DarkThemeControlDisabled
  else if FPressed then
    Canvas.Brush.Color := DarkThemeControlPressed
  else if FHot then
    Canvas.Brush.Color := DarkThemeControlHot
  else
    Canvas.Brush.Color := DarkThemeControlBackground;
  Canvas.Brush.Style := bsSolid;
  Canvas.FillRect(R);

  if FDpiContext <> nil then
  begin
    BorderWidth := FDpiContext.Metrics.ScaleAtLeastOne(DarkThemeBorderWidth);
    TextPadding := FDpiContext.Metrics.Scale(DarkThemeTextPadding);
  end
  else
  begin
    BorderWidth := TDarkThemeMetrics.Create(CurrentPPI).ScaleAtLeastOne(
      DarkThemeBorderWidth);
    TextPadding := TDarkThemeMetrics.Create(CurrentPPI).Scale(
      DarkThemeTextPadding);
  end;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := DarkThemeControlBorder;
  Canvas.Pen.Width := BorderWidth;
  Canvas.Rectangle(R.Left, R.Top, R.Right, R.Bottom);

  InflateRect(R, -(BorderWidth + TextPadding), -(BorderWidth + TextPadding));
  Canvas.Font.Assign(Font);
  if Enabled then
    Canvas.Font.Color := DarkThemeControlText
  else
    Canvas.Font.Color := DarkThemeControlDisabledText;
  SetBkMode(Canvas.Handle, TRANSPARENT);
  TextFlags := DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS;
  DrawText(Canvas.Handle, PChar(Caption), Length(Caption), R, TextFlags);

  if Focused then
  begin
    FocusRect := ClientRect;
    if FDpiContext <> nil then
      InflateRect(FocusRect, -FDpiContext.Metrics.ScaleAtLeastOne(
        DarkThemeFocusInset), -FDpiContext.Metrics.ScaleAtLeastOne(
        DarkThemeFocusInset))
    else
      InflateRect(FocusRect, -DarkThemeFocusInset, -DarkThemeFocusInset);
    DrawFocusRect(Canvas.Handle, FocusRect);
  end;
end;

procedure TDarkButton.SetDpiContext(const Value: TDarkThemeDpiContext);
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

end.
