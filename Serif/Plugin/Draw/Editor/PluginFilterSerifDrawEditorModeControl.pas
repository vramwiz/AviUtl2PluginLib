unit PluginFilterSerifDrawEditorModeControl;

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  Winapi.Messages;

type
  TSerifDrawEditorMode = (sdemText, sdemRoleName, sdemFrame);

  TSerifDrawEditorModeControl = class(TCustomControl)
  private
    FExtent: Integer;
    FGap: Integer;
    FHoverMode: Integer;
    FMode: TSerifDrawEditorMode;
    FOnChange: TNotifyEvent;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    function HitTestMode(const X, Y: Integer): Integer;
    procedure SetExtent(const Value: Integer);
    procedure SetMode(const Value: TSerifDrawEditorMode);
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Extent: Integer read FExtent write SetExtent;
    property Mode: TSerifDrawEditorMode read FMode write SetMode;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

uses
  System.Math,
  PluginFilterSerifDrawSettingsTheme,
  Winapi.Windows;

constructor TSerifDrawEditorModeControl.Create(AOwner: TComponent);
begin
  inherited;
  FExtent := 28;
  FGap := 8;
  FHoverMode := -1;
  FMode := sdemText;
  Color := SERIF_DRAW_PANEL_COLOR;
  Cursor := crHandPoint;
  ParentBackground := False;
  TabStop := True;
  Width := FExtent * 3 + FGap * 2;
  Height := FExtent;
end;

procedure TSerifDrawEditorModeControl.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FHoverMode <> -1 then
  begin
    FHoverMode := -1;
    Invalidate;
  end;
end;

function TSerifDrawEditorModeControl.HitTestMode(
  const X, Y: Integer): Integer;
var
  ModeIndex: Integer;
  ModeLeft: Integer;
begin
  Result := -1;
  if (Y < 0) or (Y >= Height) then
    Exit;
  for ModeIndex := Ord(Low(TSerifDrawEditorMode)) to
    Ord(High(TSerifDrawEditorMode)) do
  begin
    ModeLeft := ModeIndex * (FExtent + FGap);
    if (X >= ModeLeft) and (X < ModeLeft + FExtent) then
      Exit(ModeIndex);
  end;
end;

procedure TSerifDrawEditorModeControl.KeyDown(var Key: Word;
  Shift: TShiftState);
begin
  inherited;
  case Key of
    VK_LEFT:
      begin
        if FMode = Low(TSerifDrawEditorMode) then
          Mode := High(TSerifDrawEditorMode)
        else
          Mode := TSerifDrawEditorMode(Ord(FMode) - 1);
        Key := 0;
      end;
    VK_RIGHT:
      begin
        if FMode = High(TSerifDrawEditorMode) then
          Mode := Low(TSerifDrawEditorMode)
        else
          Mode := TSerifDrawEditorMode(Ord(FMode) + 1);
        Key := 0;
      end;
  end;
end;

procedure TSerifDrawEditorModeControl.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  HitMode: Integer;
begin
  inherited;
  if Button <> mbLeft then
    Exit;
  SetFocus;
  HitMode := HitTestMode(X, Y);
  if HitMode >= 0 then
    Mode := TSerifDrawEditorMode(HitMode);
end;

procedure TSerifDrawEditorModeControl.MouseMove(Shift: TShiftState;
  X, Y: Integer);
var
  HitMode: Integer;
begin
  inherited;
  HitMode := HitTestMode(X, Y);
  if FHoverMode <> HitMode then
  begin
    FHoverMode := HitMode;
    Invalidate;
  end;
end;

procedure TSerifDrawEditorModeControl.Paint;
var
  FrameRect: TRect;
  HeadRadius: Integer;
  IconColor: TColor;
  ModeIndex: Integer;
  ModeRect: TRect;
  TextRect: TRect;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  for ModeIndex := Ord(Low(TSerifDrawEditorMode)) to
    Ord(High(TSerifDrawEditorMode)) do
  begin
    ModeRect := Rect(ModeIndex * (FExtent + FGap), 0,
      ModeIndex * (FExtent + FGap) + FExtent, Height);
    if ModeIndex = Ord(FMode) then
    begin
      Canvas.Brush.Color := SERIF_DRAW_ICON_SELECTED_COLOR;
      Canvas.FillRect(ModeRect);
    end
    else if FHoverMode = ModeIndex then
    begin
      Canvas.Brush.Color := SERIF_DRAW_ICON_HOVER_COLOR;
      Canvas.FillRect(ModeRect);
    end;
    if ModeIndex = Ord(FMode) then
      IconColor := SERIF_DRAW_ICON_SELECTED_GLYPH_COLOR
    else
      IconColor := SERIF_DRAW_TEXT_COLOR;

    if ModeIndex = Ord(sdemText) then
    begin
      TextRect := ModeRect;
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Name := 'Segoe UI';
      Canvas.Font.Height := -Max(12, FExtent * 70 div 100);
      Canvas.Font.Style := [];
      Canvas.Font.Color := IconColor;
      DrawTextW(Canvas.Handle, PWideChar('A'), 1, TextRect,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    end
    else if ModeIndex = Ord(sdemRoleName) then
    begin
      HeadRadius := Max(3, FExtent div 8);
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := IconColor;
      Canvas.Pen.Color := IconColor;
      Canvas.Ellipse((ModeRect.Left + ModeRect.Right) div 2 - HeadRadius,
        ModeRect.Top + Max(3, FExtent div 7),
        (ModeRect.Left + ModeRect.Right) div 2 + HeadRadius,
        ModeRect.Top + Max(3, FExtent div 7) + HeadRadius * 2);
      FrameRect := Rect(ModeRect.Left + Max(5, FExtent div 5),
        ModeRect.Top + FExtent div 2,
        ModeRect.Right - Max(5, FExtent div 5),
        ModeRect.Bottom - Max(4, FExtent div 7));
      Canvas.RoundRect(FrameRect.Left, FrameRect.Top, FrameRect.Right,
        FrameRect.Bottom, HeadRadius * 2, HeadRadius * 2);
    end
    else
    begin
      FrameRect := ModeRect;
      InflateRect(FrameRect, -Max(5, FExtent div 5),
        -Max(5, FExtent div 5));
      Canvas.Brush.Style := bsClear;
      Canvas.Pen.Color := IconColor;
      Canvas.Pen.Width := Max(2, FExtent div 12);
      Canvas.Rectangle(FrameRect);
    end;

    if ModeIndex = Ord(FMode) then
    begin
      Canvas.Pen.Color := SERIF_DRAW_ICON_SELECTED_GLYPH_COLOR;
      Canvas.Pen.Width := Max(2, FExtent div 14);
      Canvas.MoveTo(ModeRect.Left + Max(3, FExtent div 7), Height - 2);
      Canvas.LineTo(ModeRect.Right - Max(3, FExtent div 7), Height - 2);
    end;
  end;
end;

procedure TSerifDrawEditorModeControl.SetExtent(const Value: Integer);
begin
  if FExtent = Max(16, Value) then
    Exit;
  FExtent := Max(16, Value);
  FGap := Max(4, FExtent div 4);
  SetBounds(Left, Top, FExtent * 3 + FGap * 2, FExtent);
  Invalidate;
end;

procedure TSerifDrawEditorModeControl.SetMode(
  const Value: TSerifDrawEditorMode);
begin
  if FMode = Value then
    Exit;
  FMode := Value;
  Invalidate;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

end.
