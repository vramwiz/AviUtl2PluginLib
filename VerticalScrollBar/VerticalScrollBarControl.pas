unit VerticalScrollBarControl;

interface

uses
  System.Classes, System.Types, Vcl.Controls, Vcl.Graphics;

type
  // Voicevox編集画面の横スクロールバーと同じ操作・配色を縦方向へ適用する。
  TVerticalScrollBarControl = class(TCustomControl)
  private
    FBackgroundColor: TColor;
    FDragOffset: Integer;
    FDragging: Boolean;
    FMaximum: Integer;
    FOnChange: TNotifyEvent;
    FPageSize: Integer;
    FPosition: Integer;
    FSmallChange: Integer;
    FThumbColor: TColor;
    FTrackColor: TColor;
    FWheelRemainder: Integer;
    function ThumbRect: TRect;
    procedure SetBackgroundColor(const Value: TColor);
    procedure SetPosition(const Value: Integer);
    procedure SetThumbColor(const Value: TColor);
    procedure SetTrackColor(const Value: TColor);
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetRange(const ContentSize, PageSize, SmallChange: Integer);
    property Maximum: Integer read FMaximum;
    property PageSize: Integer read FPageSize;
    property Position: Integer read FPosition write SetPosition;
  published
    property Align;
    property Anchors;
    property BackgroundColor: TColor read FBackgroundColor
      write SetBackgroundColor;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property ThumbColor: TColor read FThumbColor write SetThumbColor;
    property TrackColor: TColor read FTrackColor write SetTrackColor;
    property Visible;
  end;

implementation

uses
  Winapi.Windows, System.Math;

function ScrollScale(const Value, Ppi: Integer): Integer;
begin
  Result := MulDiv(Value, Ppi, 96);
end;

constructor TVerticalScrollBarControl.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Cursor := crHandPoint;
  Width := 12;
  FBackgroundColor := clBtnFace;
  FTrackColor := clBtnShadow;
  FThumbColor := clHighlight;
  FSmallChange := 1;
end;

function TVerticalScrollBarControl.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  Steps: Integer;
begin
  Inc(FWheelRemainder, WheelDelta);
  Steps := FWheelRemainder div WHEEL_DELTA;
  FWheelRemainder := FWheelRemainder mod WHEEL_DELTA;
  if Steps <> 0 then Position := Position - Steps * FSmallChange;
  Result := WheelDelta <> 0;
end;

procedure TVerticalScrollBarControl.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Thumb: TRect;
begin
  inherited;
  if (Button <> mbLeft) or (FMaximum <= 0) then Exit;
  Thumb := ThumbRect;
  if PtInRect(Thumb, Point(X, Y)) then
    FDragOffset := Y - Thumb.Top
  else
    FDragOffset := Thumb.Height div 2;
  FDragging := True;
  MouseCapture := True;
  if not PtInRect(Thumb, Point(X, Y)) then MouseMove(Shift, X, Y);
end;

procedure TVerticalScrollBarControl.MouseMove(Shift: TShiftState;
  X, Y: Integer);
var
  Thumb: TRect;
  Travel: Integer;
begin
  inherited;
  if not FDragging or (FMaximum <= 0) then Exit;
  Thumb := ThumbRect;
  Travel := Max(ClientHeight - Thumb.Height, 1);
  Position := MulDiv(Y - FDragOffset, FMaximum, Travel);
end;

procedure TVerticalScrollBarControl.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button <> mbLeft then Exit;
  FDragging := False;
  MouseCapture := False;
end;

procedure TVerticalScrollBarControl.Paint;
var
  Thumb: TRect;
  TrackX: Integer;
begin
  Canvas.Brush.Color := FBackgroundColor;
  Canvas.FillRect(ClientRect);
  TrackX := ClientWidth div 2;
  Canvas.Pen.Color := FTrackColor;
  Canvas.MoveTo(TrackX, ScrollScale(3, CurrentPPI));
  Canvas.LineTo(TrackX, ClientHeight - ScrollScale(3, CurrentPPI));
  if FMaximum <= 0 then Exit;
  Thumb := ThumbRect;
  Canvas.Brush.Color := FThumbColor;
  Canvas.Pen.Color := FThumbColor;
  Canvas.RoundRect(Thumb.Left, Thumb.Top, Thumb.Right, Thumb.Bottom,
    ScrollScale(3, CurrentPPI), ScrollScale(3, CurrentPPI));
end;

procedure TVerticalScrollBarControl.SetBackgroundColor(const Value: TColor);
begin
  if FBackgroundColor = Value then Exit;
  FBackgroundColor := Value;
  Invalidate;
end;

procedure TVerticalScrollBarControl.SetPosition(const Value: Integer);
var
  DirtyRect: TRect;
  NewPosition: Integer;
  OldThumb: TRect;
  NewThumb: TRect;
begin
  NewPosition := EnsureRange(Value, 0, FMaximum);
  if FPosition = NewPosition then Exit;
  OldThumb := ThumbRect;
  FPosition := NewPosition;
  NewThumb := ThumbRect;
  DirtyRect := Rect(Min(OldThumb.Left, NewThumb.Left),
    Min(OldThumb.Top, NewThumb.Top), Max(OldThumb.Right, NewThumb.Right),
    Max(OldThumb.Bottom, NewThumb.Bottom));
  InflateRect(DirtyRect, 1, 1);
  if HandleAllocated then
    Winapi.Windows.InvalidateRect(Handle, @DirtyRect, False)
  else
    Invalidate;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TVerticalScrollBarControl.SetRange(const ContentSize, PageSize,
  SmallChange: Integer);
begin
  FPageSize := Max(PageSize, 1);
  FMaximum := Max(ContentSize - FPageSize, 0);
  FSmallChange := Max(SmallChange, 1);
  SetPosition(FPosition);
  Visible := FMaximum > 0;
  Invalidate;
end;

procedure TVerticalScrollBarControl.SetThumbColor(const Value: TColor);
begin
  if FThumbColor = Value then Exit;
  FThumbColor := Value;
  Invalidate;
end;

procedure TVerticalScrollBarControl.SetTrackColor(const Value: TColor);
begin
  if FTrackColor = Value then Exit;
  FTrackColor := Value;
  Invalidate;
end;

function TVerticalScrollBarControl.ThumbRect: TRect;
var
  ThumbHeight: Integer;
  ThumbWidth: Integer;
  Travel: Integer;
begin
  ThumbWidth := Min(Max(ScrollScale(6, CurrentPPI), 2),
    Max(ClientWidth - ScrollScale(4, CurrentPPI), 1));
  ThumbHeight := Max(ScrollScale(20, CurrentPPI),
    MulDiv(ClientHeight, FPageSize, FPageSize + FMaximum));
  ThumbHeight := Min(ThumbHeight, ClientHeight);
  Travel := Max(ClientHeight - ThumbHeight, 0);
  Result.Left := (ClientWidth - ThumbWidth) div 2;
  Result.Top := MulDiv(FPosition, Travel, Max(FMaximum, 1));
  Result.Right := Result.Left + ThumbWidth;
  Result.Bottom := Result.Top + ThumbHeight;
end;

end.
