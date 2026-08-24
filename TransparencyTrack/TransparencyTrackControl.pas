unit TransparencyTrackControl;

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  HorizontalScrollBarControl;

type
  TTransparencyTrackGlyphKind = (
    ttgText,
    ttgFrame
  );

  TTransparencyTrackControl = class(TCustomControl)
  private
    FAlpha: Byte;
    FBackgroundColor: TColor;
    FCaption: string;
    FGlyphColor: TColor;
    FGlyphKind: TTransparencyTrackGlyphKind;
    FOnChange: TNotifyEvent;
    FScrollBar: THorizontalScrollBarControl;
    FUpdating: Boolean;
    function CaptionWidth: Integer;
    function OpaqueGlyphRect: TRect;
    procedure ScrollBarChange(Sender: TObject);
    procedure SetAlpha(const Value: Byte);
    procedure SetBackgroundColor(const Value: TColor);
    procedure SetCaption(const Value: string);
    procedure SetGlyphKind(const Value: TTransparencyTrackGlyphKind);
    procedure SetGlyphColor(const Value: TColor);
    function TransparentGlyphRect: TRect;
    procedure UpdateLayout;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Alpha: Byte read FAlpha write SetAlpha default 255;
    property BackgroundColor: TColor read FBackgroundColor
      write SetBackgroundColor;
    property Caption: string read FCaption write SetCaption;
    property Font;
    property GlyphKind: TTransparencyTrackGlyphKind read FGlyphKind
      write SetGlyphKind default ttgText;
    property GlyphColor: TColor read FGlyphColor write SetGlyphColor;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

uses
  System.Math,
  Winapi.Windows;

function TrackScale(const Value, Ppi: Integer): Integer;
begin
  Result := MulDiv(Value, Ppi, 96);
end;

constructor TTransparencyTrackControl.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Cursor := crHandPoint;
  Height := 28;
  FAlpha := 255;
  FGlyphKind := ttgText;
  FGlyphColor := TColor($00E6E6E6);
  FBackgroundColor := TColor($00262626);
  FScrollBar := THorizontalScrollBarControl.Create(Self);
  FScrollBar.Parent := Self;
  FScrollBar.BackgroundColor := FBackgroundColor;
  FScrollBar.TrackColor := TColor($00707070);
  FScrollBar.ThumbColor := clHighlight;
  FScrollBar.SetRange(256, 1, 1);
  FScrollBar.Position := FAlpha;
  FScrollBar.OnChange := ScrollBarChange;
end;

function TTransparencyTrackControl.CaptionWidth: Integer;
begin
  Canvas.Font.Assign(Font);
  Result := Canvas.TextWidth(FCaption);
  if Result > 0 then
    Inc(Result, TrackScale(8, CurrentPPI));
end;

procedure TTransparencyTrackControl.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button <> mbLeft then
    Exit;
  if PtInRect(TransparentGlyphRect, Point(X, Y)) then
    Alpha := 0
  else if PtInRect(OpaqueGlyphRect, Point(X, Y)) then
    Alpha := 255;
end;

function TTransparencyTrackControl.OpaqueGlyphRect: TRect;
var
  Extent: Integer;
begin
  Extent := Min(ClientHeight, TrackScale(24, CurrentPPI));
  Result.Right := ClientWidth;
  Result.Left := Result.Right - Extent;
  Result.Top := (ClientHeight - Extent) div 2;
  Result.Bottom := Result.Top + Extent;
end;

procedure TTransparencyTrackControl.Paint;
var
  GlyphRect: TRect;
  InnerRect: TRect;
  TextRect: TRect;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FBackgroundColor;
  Canvas.FillRect(ClientRect);
  Canvas.Font.Assign(Font);
  Canvas.Font.Color := TColor($00E6E6E6);
  Canvas.Brush.Style := bsClear;
  TextRect := Rect(0, 0, CaptionWidth - TrackScale(6, CurrentPPI),
    ClientHeight);
  DrawText(Canvas.Handle, PChar(FCaption), Length(FCaption), TextRect,
    DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);

  GlyphRect := TransparentGlyphRect;
  InflateRect(GlyphRect, -TrackScale(2, CurrentPPI),
    -TrackScale(2, CurrentPPI));
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := FGlyphColor;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(GlyphRect);
  InnerRect := GlyphRect;
  InflateRect(InnerRect, -TrackScale(5, CurrentPPI),
    -TrackScale(5, CurrentPPI));
  Canvas.Pen.Style := psDot;
  Canvas.Rectangle(InnerRect);
  Canvas.Pen.Style := psSolid;

  GlyphRect := OpaqueGlyphRect;
  InflateRect(GlyphRect, -TrackScale(2, CurrentPPI),
    -TrackScale(2, CurrentPPI));
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := FGlyphColor;
  Canvas.Rectangle(GlyphRect);
  InnerRect := GlyphRect;
  InflateRect(InnerRect, -TrackScale(5, CurrentPPI),
    -TrackScale(5, CurrentPPI));
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FGlyphColor;
  Canvas.Pen.Color := FGlyphColor;
  Canvas.Rectangle(InnerRect);
end;

procedure TTransparencyTrackControl.Resize;
begin
  inherited;
  UpdateLayout;
end;

procedure TTransparencyTrackControl.ScrollBarChange(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FAlpha := Byte(FScrollBar.Position);
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TTransparencyTrackControl.SetAlpha(const Value: Byte);
begin
  if FAlpha = Value then
    Exit;
  FAlpha := Value;
  FUpdating := True;
  try
    FScrollBar.Position := FAlpha;
  finally
    FUpdating := False;
  end;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TTransparencyTrackControl.SetBackgroundColor(const Value: TColor);
begin
  if FBackgroundColor = Value then
    Exit;
  FBackgroundColor := Value;
  FScrollBar.BackgroundColor := Value;
  Invalidate;
end;

procedure TTransparencyTrackControl.SetCaption(const Value: string);
begin
  if FCaption = Value then
    Exit;
  FCaption := Value;
  UpdateLayout;
  Invalidate;
end;

procedure TTransparencyTrackControl.SetGlyphKind(
  const Value: TTransparencyTrackGlyphKind);
begin
  if FGlyphKind = Value then
    Exit;
  FGlyphKind := Value;
  Invalidate;
end;

procedure TTransparencyTrackControl.SetGlyphColor(const Value: TColor);
begin
  if FGlyphColor = Value then
    Exit;
  FGlyphColor := Value;
  Invalidate;
end;

function TTransparencyTrackControl.TransparentGlyphRect: TRect;
var
  Extent: Integer;
begin
  Extent := Min(ClientHeight, TrackScale(24, CurrentPPI));
  Result.Left := CaptionWidth;
  Result.Top := (ClientHeight - Extent) div 2;
  Result.Right := Result.Left + Extent;
  Result.Bottom := Result.Top + Extent;
end;

procedure TTransparencyTrackControl.UpdateLayout;
var
  LeftGlyph: TRect;
  RightGlyph: TRect;
  Gap: Integer;
  TrackLeft: Integer;
  TrackRight: Integer;
begin
  if FScrollBar = nil then
    Exit;
  Gap := TrackScale(5, CurrentPPI);
  LeftGlyph := TransparentGlyphRect;
  RightGlyph := OpaqueGlyphRect;
  TrackLeft := LeftGlyph.Right + Gap;
  TrackRight := RightGlyph.Left - Gap;
  FScrollBar.SetBounds(TrackLeft, 0, Max(1, TrackRight - TrackLeft),
    ClientHeight);
end;

end.
