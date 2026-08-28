unit MmdPoseEditorTheme;

// 共通ポーズ編集GUIの暗色配色と、標準描画では白く残るVCL部品を提供する。

interface

uses
  System.Classes,
  System.Types,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls;

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

type
  TMmdDarkButton = class(TCustomControl)
  private
    FCancel: Boolean;
    FDefault: Boolean;
    FHot: Boolean;
    FModalResult: TModalResult;
    FPressed: Boolean;
    procedure CMDialogChar(var Message: TCMDialogChar); message CM_DIALOGCHAR;
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure SetCancel(Value: Boolean);
    procedure SetDefault(Value: Boolean);
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
  protected
    procedure Click; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Paint; override;
    procedure PaintButton(ACanvas: TCanvas);
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property Cancel: Boolean read FCancel write SetCancel default False;
    property Caption;
    property Default: Boolean read FDefault write SetDefault default False;
    property Enabled;
    property Font;
    property Hint;
    property ModalResult: TModalResult read FModalResult write FModalResult
      default mrNone;
    property ParentFont;
    property ParentShowHint;
    property ShowHint;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnClick;
  end;

  TMmdDarkListBox = class(TListBox)
  protected
    procedure CreateWnd; override;
    procedure DrawItem(Index: Integer; Rect: TRect;
      State: TOwnerDrawState); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TMmdDarkComboBox = class(TComboBox)
  private
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
  protected
    procedure CreateWnd; override;
    procedure DrawItem(Index: Integer; Rect: TRect;
      State: TOwnerDrawState); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

procedure ApplyMmdDarkTitleBar(Form: TCustomForm);

implementation

uses
  Winapi.Dwmapi,
  Winapi.UxTheme,
  Winapi.Windows;

procedure DrawDarkItem(Canvas: TCanvas; const Text: string; Rect: TRect;
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

constructor TMmdDarkButton.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csClickEvents, csCaptureMouse, csOpaque];
  Width := 75;
  Height := 25;
  TabStop := True;
  Font.Color := MmdEditorText;
end;

procedure TMmdDarkButton.CMDialogChar(var Message: TCMDialogChar);
begin
  if Enabled and IsAccel(Message.CharCode, Caption) then
  begin
    Click;
    Message.Result := 1;
  end
  else
    inherited;
end;

procedure TMmdDarkButton.CMDialogKey(var Message: TCMDialogKey);
begin
  if Enabled and (((Message.CharCode = VK_RETURN) and FDefault) or
    ((Message.CharCode = VK_ESCAPE) and FCancel)) then
  begin
    Click;
    Message.Result := 1;
  end
  else
    inherited;
end;

procedure TMmdDarkButton.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FHot := True;
  Invalidate;
end;

procedure TMmdDarkButton.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FHot := False;
  Invalidate;
end;

procedure TMmdDarkButton.Click;
var
  Form: TCustomForm;
begin
  inherited;
  if FModalResult <> mrNone then
  begin
    Form := GetParentForm(Self);
    if Assigned(Form) then
      Form.ModalResult := FModalResult;
  end;
end;

procedure TMmdDarkButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Enabled and (Key = VK_SPACE) then
  begin
    FPressed := True;
    Invalidate;
    Key := 0;
  end
  else
    inherited;
end;

procedure TMmdDarkButton.KeyUp(var Key: Word; Shift: TShiftState);
begin
  if FPressed and (Key = VK_SPACE) then
  begin
    FPressed := False;
    Invalidate;
    Click;
    Key := 0;
  end
  else
    inherited;
end;

procedure TMmdDarkButton.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
  if Enabled and (Button = mbLeft) then
  begin
    if CanFocus then
      SetFocus;
    FPressed := True;
    Invalidate;
  end;
end;

procedure TMmdDarkButton.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
  begin
    FPressed := False;
    Invalidate;
  end;
end;

procedure TMmdDarkButton.Paint;
begin
  PaintButton(Canvas);
end;

procedure TMmdDarkButton.PaintButton(ACanvas: TCanvas);
var
  Background, Border, TextColor: TColor;
  DrawRect: TRect;
begin
  if not Enabled then
  begin
    Background := MmdEditorPanel;
    Border := MmdEditorBorder;
    TextColor := MmdEditorDisabledText;
  end
  else if FPressed then
  begin
    Background := MmdEditorPressed;
    Border := MmdEditorSelection;
    TextColor := clWhite;
  end
  else if FHot then
  begin
    Background := MmdEditorHot;
    Border := MmdEditorSelection;
    TextColor := clWhite;
  end
  else
  begin
    Background := MmdEditorControl;
    Border := MmdEditorBorder;
    TextColor := MmdEditorText;
  end;

  DrawRect := ClientRect;
  ACanvas.Brush.Color := Background;
  ACanvas.FillRect(DrawRect);
  ACanvas.Brush.Style := bsClear;
  if Focused or FDefault then
    ACanvas.Pen.Color := MmdEditorSelection
  else
    ACanvas.Pen.Color := Border;
  ACanvas.Rectangle(DrawRect);
  ACanvas.Font.Assign(Font);
  ACanvas.Font.Color := TextColor;
  InflateRect(DrawRect, -4, -2);
  DrawText(ACanvas.Handle, PChar(Caption), Length(Caption), DrawRect,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or
    DT_NOPREFIX);
  if Focused and Enabled then
  begin
    InflateRect(DrawRect, -2, -2);
    ACanvas.DrawFocusRect(DrawRect);
  end;
end;

procedure TMmdDarkButton.SetCancel(Value: Boolean);
begin
  FCancel := Value;
end;

procedure TMmdDarkButton.SetDefault(Value: Boolean);
begin
  if FDefault = Value then
    Exit;
  FDefault := Value;
  Invalidate;
end;

procedure TMmdDarkButton.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  FPressed := False;
  Invalidate;
end;

procedure TMmdDarkButton.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

constructor TMmdDarkListBox.Create(AOwner: TComponent);
begin
  inherited;
  Style := lbOwnerDrawFixed;
  Color := MmdEditorControl;
  Font.Color := MmdEditorText;
end;

procedure TMmdDarkListBox.CreateWnd;
begin
  inherited;
  SetWindowTheme(Handle, 'DarkMode_Explorer', nil);
end;

procedure TMmdDarkListBox.DrawItem(Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  Text: string;
begin
  Text := '';
  if (Index >= 0) and (Index < Items.Count) then
    Text := Items[Index];
  DrawDarkItem(Canvas, Text, Rect, odSelected in State, odFocused in State);
end;

constructor TMmdDarkComboBox.Create(AOwner: TComponent);
begin
  inherited;
  Style := csOwnerDrawFixed;
  Color := MmdEditorControl;
  Font.Color := MmdEditorText;
end;

procedure TMmdDarkComboBox.CreateWnd;
begin
  inherited;
  SetWindowTheme(Handle, 'DarkMode_CFD', nil);
end;

procedure TMmdDarkComboBox.DrawItem(Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  Text: string;
begin
  Text := '';
  if (Index >= 0) and (Index < Items.Count) then
    Text := Items[Index];
  DrawDarkItem(Canvas, Text, Rect, odSelected in State, odFocused in State);
end;

procedure TMmdDarkComboBox.WMPaint(var Message: TWMPaint);
var
  ArrowRect, DrawRect, TextRect: TRect;
  ArrowColor: TColor;
  Canvas: TControlCanvas;
  CenterX, CenterY: Integer;
  Text: string;
begin
  inherited;
  Canvas := TControlCanvas.Create;
  try
    Canvas.Control := Self;
    DrawRect := ClientRect;
    Canvas.Brush.Color := MmdEditorControl;
    Canvas.FillRect(DrawRect);
    Canvas.Brush.Style := bsClear;
    if Focused then
      Canvas.Pen.Color := MmdEditorSelection
    else
      Canvas.Pen.Color := MmdEditorBorder;
    Canvas.Rectangle(DrawRect);

    ArrowRect := DrawRect;
    ArrowRect.Left := ArrowRect.Right - GetSystemMetrics(SM_CXVSCROLL);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := MmdEditorPanel;
    Canvas.FillRect(ArrowRect);
    Canvas.Pen.Color := MmdEditorBorder;
    Canvas.MoveTo(ArrowRect.Left, ArrowRect.Top + 1);
    Canvas.LineTo(ArrowRect.Left, ArrowRect.Bottom - 1);
    CenterX := (ArrowRect.Left + ArrowRect.Right) div 2;
    CenterY := (ArrowRect.Top + ArrowRect.Bottom) div 2;
    if Enabled then
      ArrowColor := MmdEditorText
    else
      ArrowColor := MmdEditorDisabledText;
    Canvas.Brush.Color := ArrowColor;
    Canvas.Pen.Color := ArrowColor;
    Canvas.Polygon([Point(CenterX - 4, CenterY - 2),
      Point(CenterX + 4, CenterY - 2), Point(CenterX, CenterY + 3)]);

    Text := '';
    if (ItemIndex >= 0) and (ItemIndex < Items.Count) then
      Text := Items[ItemIndex];
    TextRect := DrawRect;
    Inc(TextRect.Left, 6);
    TextRect.Right := ArrowRect.Left - 4;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Assign(Font);
    if Enabled then
      Canvas.Font.Color := MmdEditorText
    else
      Canvas.Font.Color := MmdEditorDisabledText;
    DrawText(Canvas.Handle, PChar(Text), Length(Text), TextRect,
      DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
  finally
    Canvas.Free;
  end;
end;

procedure ApplyMmdDarkTitleBar(Form: TCustomForm);
const
  DwmUseImmersiveDarkModeBefore20H1 = 19;
  DwmUseImmersiveDarkMode = 20;
var
  Enabled: LongBool;
begin
  if not Assigned(Form) or not Form.HandleAllocated then
    Exit;
  Enabled := True;
  if Failed(DwmSetWindowAttribute(Form.Handle, DwmUseImmersiveDarkMode,
    @Enabled, SizeOf(Enabled))) then
    DwmSetWindowAttribute(Form.Handle, DwmUseImmersiveDarkModeBefore20H1,
      @Enabled, SizeOf(Enabled));
end;

end.
