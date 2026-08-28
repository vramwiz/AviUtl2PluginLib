unit HorizontalTrackBarRenderer;

interface

uses
  System.Types,
  Vcl.Graphics;

type
  THorizontalTrackBarRenderState = record
    BackgroundColor: TColor;
    ChannelColor: TColor;
    ClientRect: TRect;
    DisabledColor: TColor;
    Enabled: Boolean;
    FillColor: TColor;
    Focused: Boolean;
    Frequency: Integer;
    Maximum: Integer;
    Minimum: Integer;
    PPI: Integer;
    ShowTicks: Boolean;
    ThumbBorderColor: TColor;
    ThumbColor: TColor;
    ThumbX: Integer;
    TickColor: TColor;
    TrackRect: TRect;
  end;

procedure DrawHorizontalTrackBar(Canvas: TCanvas;
  const State: THorizontalTrackBarRenderState);

implementation

uses
  System.Math,
  Winapi.Windows;

function Scale(Value, PPI: Integer): Integer;
begin
  Result := MulDiv(Value, PPI, 96);
end;

procedure DrawHorizontalTrackBar(Canvas: TCanvas;
  const State: THorizontalTrackBarRenderState);
var
  ActiveColor: TColor;
  ChannelRect, FocusRect, ThumbRect: TRect;
  ChannelY, FrequencyValue, ThumbRadius, Tick, TickX: Integer;
begin
  Canvas.Brush.Color := State.BackgroundColor;
  Canvas.FillRect(State.ClientRect);
  ChannelY := State.TrackRect.Top;
  ChannelRect := Rect(State.TrackRect.Left, ChannelY - Scale(2, State.PPI),
    State.TrackRect.Right, ChannelY + Scale(2, State.PPI) + 1);
  Canvas.Brush.Color := State.ChannelColor;
  Canvas.Pen.Style := psClear;
  Canvas.Rectangle(ChannelRect);

  if State.Enabled then ActiveColor := State.FillColor
  else ActiveColor := State.DisabledColor;
  Canvas.Brush.Color := ActiveColor;
  Canvas.Rectangle(Rect(ChannelRect.Left, ChannelRect.Top, State.ThumbX,
    ChannelRect.Bottom));

  if State.ShowTicks then
  begin
    FrequencyValue := Max(State.Frequency, 1);
    Tick := State.Minimum;
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Color := State.TickColor;
    while Tick <= State.Maximum do
    begin
      if State.Maximum > State.Minimum then
        TickX := State.TrackRect.Left + MulDiv(Tick - State.Minimum,
          State.TrackRect.Width, State.Maximum - State.Minimum)
      else
        TickX := State.TrackRect.Left;
      Canvas.MoveTo(TickX, ChannelY + Scale(7, State.PPI));
      Canvas.LineTo(TickX, ChannelY + Scale(11, State.PPI));
      if Tick > State.Maximum - FrequencyValue then Break;
      Inc(Tick, FrequencyValue);
    end;
  end;

  ThumbRadius := Scale(6, State.PPI);
  ThumbRect := Rect(State.ThumbX - ThumbRadius, ChannelY - ThumbRadius,
    State.ThumbX + ThumbRadius + 1, ChannelY + ThumbRadius + 1);
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := Max(Scale(2, State.PPI), 1);
  if State.Enabled then
  begin
    Canvas.Brush.Color := State.ThumbColor;
    Canvas.Pen.Color := State.ThumbBorderColor;
  end
  else
  begin
    Canvas.Brush.Color := State.BackgroundColor;
    Canvas.Pen.Color := State.DisabledColor;
  end;
  Canvas.Ellipse(ThumbRect);
  Canvas.Pen.Width := 1;

  if State.Focused and State.Enabled then
  begin
    FocusRect := State.ClientRect;
    InflateRect(FocusRect, -1, -1);
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := State.FillColor;
    Canvas.DrawFocusRect(FocusRect);
  end;
end;

end.
