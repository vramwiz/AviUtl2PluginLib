unit MmdPoseEditorButtonTheme;

// 標準VCLボタンに依存しない、暗色モーダル操作ボタンを提供する。

interface

uses
  System.Classes,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics;

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
    // キーボード、既定／取消、ModalResultに対応する暗色ボタンを生成する。
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

implementation

uses
  Winapi.Windows,
  MmdPoseEditorTheme;

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
  else inherited;
end;

procedure TMmdDarkButton.CMDialogKey(var Message: TCMDialogKey);
begin
  if Enabled and (((Message.CharCode = VK_RETURN) and FDefault) or
    ((Message.CharCode = VK_ESCAPE) and FCancel)) then
  begin
    Click;
    Message.Result := 1;
  end
  else inherited;
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
  FPressed := False;
  Invalidate;
end;

procedure TMmdDarkButton.Click;
var
  Form: TCustomForm;
begin
  inherited;
  if FModalResult = mrNone then Exit;
  Form := GetParentForm(Self);
  if Assigned(Form) then Form.ModalResult := FModalResult;
end;

procedure TMmdDarkButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Enabled and (Key = VK_SPACE) then
  begin
    FPressed := True;
    Invalidate;
    Key := 0;
  end
  else inherited;
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
  else inherited;
end;

procedure TMmdDarkButton.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
  if Enabled and (Button = mbLeft) then
  begin
    if CanFocus then SetFocus;
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
  if Focused or FDefault then ACanvas.Pen.Color := MmdEditorSelection
  else ACanvas.Pen.Color := Border;
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
  if FDefault = Value then Exit;
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

end.
