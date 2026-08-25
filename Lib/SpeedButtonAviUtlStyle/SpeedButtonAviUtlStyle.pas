unit SpeedButtonAviUtlStyle;

interface

uses
  Winapi.Windows,Winapi.Messages,System.Classes,System.SysUtils,Vcl.Buttons,Vcl.Controls,Vcl.Graphics;

type
  TSpeedButtonAviUtlStyle = class(TSpeedButton)
  private
    FNormalColor: TColor;
    FHotColor: TColor;
    FDownColor: TColor;
    FBorderColor: TColor;
    FHotBorderColor: TColor;
    FDownBorderColor: TColor;
    FTextColor: TColor;
    FDisabledColor: TColor;
    FDisabledTextColor: TColor;
    FMouseInControl: Boolean;
    FMousePressed: Boolean;
    FBorderWidth: Integer;
    FLightEdgeColor: TColor;
    FDarkEdgeColor: TColor;
    FHotLightEdgeColor: TColor;
    FHotDarkEdgeColor: TColor;
    FDownLightEdgeColor: TColor;
    FDownDarkEdgeColor: TColor;
    procedure SetBorderColor(const Value: TColor);
    procedure SetBorderWidth(const Value: Integer);
    procedure SetDarkEdgeColor(const Value: TColor);
    procedure SetDisabledColor(const Value: TColor);
    procedure SetDisabledTextColor(const Value: TColor);
    procedure SetDownBorderColor(const Value: TColor);
    procedure SetDownDarkEdgeColor(const Value: TColor);
    procedure SetDownLightEdgeColor(const Value: TColor);
    procedure SetDownColor(const Value: TColor);
    procedure SetHotBorderColor(const Value: TColor);
    procedure SetHotDarkEdgeColor(const Value: TColor);
    procedure SetHotLightEdgeColor(const Value: TColor);
    procedure SetHotColor(const Value: TColor);
    procedure SetLightEdgeColor(const Value: TColor);
    procedure SetNormalColor(const Value: TColor);
    procedure SetTextColor(const Value: TColor);
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function GetCurrentBackColor: TColor; virtual;
    function GetCurrentBorderColor: TColor; virtual;
    function GetCurrentLightEdgeColor: TColor; virtual;
    function GetCurrentDarkEdgeColor: TColor; virtual;
    function GetCurrentTextColor: TColor; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyDefaultColors; virtual;
  published
    property Align;
    property AllowAllUp;
    property Anchors;
    property BiDiMode;
    property Caption;
    property Constraints;
    property Down;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Flat;
    property Font;
    property GroupIndex;
    property Height;
    property Hint;
    property Layout;
    property Margin;
    property NumGlyphs;
    property ParentBiDiMode;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Spacing;
    property Visible;
    property Width;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDock;
    property OnStartDrag;

    property NormalColor: TColor read FNormalColor write SetNormalColor default $353535;
    property HotColor: TColor read FHotColor write SetHotColor default $454545;
    property DownColor: TColor read FDownColor write SetDownColor default $282828;
    property BorderColor: TColor read FBorderColor write SetBorderColor default $505050;
    property BorderWidth: Integer read FBorderWidth write SetBorderWidth default 1;
    property LightEdgeColor: TColor read FLightEdgeColor write SetLightEdgeColor default $707070;
    property DarkEdgeColor: TColor read FDarkEdgeColor write SetDarkEdgeColor default $1E1E1E;
    property HotBorderColor: TColor read FHotBorderColor write SetHotBorderColor default $505050;
    property HotLightEdgeColor: TColor read FHotLightEdgeColor write SetHotLightEdgeColor default $808080;
    property HotDarkEdgeColor: TColor read FHotDarkEdgeColor write SetHotDarkEdgeColor default $242424;
    property DownBorderColor: TColor read FDownBorderColor write SetDownBorderColor default $505050;
    property DownLightEdgeColor: TColor read FDownLightEdgeColor write SetDownLightEdgeColor default $242424;
    property DownDarkEdgeColor: TColor read FDownDarkEdgeColor write SetDownDarkEdgeColor default $808080;
    property TextColor: TColor read FTextColor write SetTextColor default clWhite;
    property DisabledColor: TColor read FDisabledColor write SetDisabledColor default $2A2A2A;
    property DisabledTextColor: TColor read FDisabledTextColor write SetDisabledTextColor default $888888;
  end;

implementation

uses
  AviUtl2StyleColors;

{ TSpeedButtonAviUtlStyle }

constructor TSpeedButtonAviUtlStyle.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  ControlStyle := ControlStyle + [csOpaque];
  Width := 96;
  Height := 28;
  Flat := True;
  Font.Color := A2SCSpeedButtonText;
  FBorderWidth := 1;

  ApplyDefaultColors;
end;

procedure TSpeedButtonAviUtlStyle.ApplyDefaultColors;
begin
  FNormalColor := A2SCSpeedButtonBackground;
  FHotColor := A2SCSpeedButtonHot;
  FDownColor := A2SCSpeedButtonPressed;
  FBorderColor := A2SCSpeedButtonBorder;
  FHotBorderColor := A2SCSpeedButtonBorder;
  FDownBorderColor := A2SCSpeedButtonBorder;
  FTextColor := A2SCSpeedButtonText;
  FDisabledColor := A2SCSpeedButtonDisabled;
  FDisabledTextColor := A2SCSpeedButtonDisabledText;
  FLightEdgeColor := $707070;
  FDarkEdgeColor := $1E1E1E;
  FHotLightEdgeColor := $808080;
  FHotDarkEdgeColor := $242424;
  FDownLightEdgeColor := $242424;
  FDownDarkEdgeColor := $808080;
  Invalidate;
end;

procedure TSpeedButtonAviUtlStyle.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FMouseInControl := True;
  Invalidate;
end;

procedure TSpeedButtonAviUtlStyle.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FMouseInControl := False;
  FMousePressed := False;
  Invalidate;
end;

function TSpeedButtonAviUtlStyle.GetCurrentBackColor: TColor;
begin
  if not Enabled then
    Exit(FDisabledColor);

  if FMousePressed or Down then
    Exit(FDownColor);

  if FMouseInControl then
    Exit(FHotColor);

  Result := FNormalColor;
end;

function TSpeedButtonAviUtlStyle.GetCurrentBorderColor: TColor;
begin
  if not Enabled then
    Exit(FBorderColor);

  if FMousePressed or Down then
    Exit(FDownBorderColor);

  if FMouseInControl then
    Exit(FHotBorderColor);

  Result := FBorderColor;
end;

function TSpeedButtonAviUtlStyle.GetCurrentLightEdgeColor: TColor;
begin
  if not Enabled then
    Exit(FLightEdgeColor);

  if FMousePressed or Down then
    Exit(FDownLightEdgeColor);

  if FMouseInControl then
    Exit(FHotLightEdgeColor);

  Result := FLightEdgeColor;
end;

function TSpeedButtonAviUtlStyle.GetCurrentDarkEdgeColor: TColor;
begin
  if not Enabled then
    Exit(FDarkEdgeColor);

  if FMousePressed or Down then
    Exit(FDownDarkEdgeColor);

  if FMouseInControl then
    Exit(FHotDarkEdgeColor);

  Result := FDarkEdgeColor;
end;

function TSpeedButtonAviUtlStyle.GetCurrentTextColor: TColor;
begin
  if Enabled then
    Result := FTextColor
  else
    Result := FDisabledTextColor;
end;

procedure TSpeedButtonAviUtlStyle.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and Enabled then
  begin
    FMousePressed := True;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
  begin
    FMousePressed := False;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.Paint;
var
  DrawRect: TRect;
  BorderRect: TRect;
  TextFlags: Longint;
  I: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := GetCurrentBackColor;
  Canvas.FillRect(ClientRect);

  if FBorderWidth > 0 then
  begin
    BorderRect := ClientRect;
    for I := 1 to FBorderWidth do
    begin
      Canvas.Pen.Color := GetCurrentBorderColor;
      Canvas.Brush.Style := bsClear;
      Canvas.Rectangle(BorderRect.Left, BorderRect.Top, BorderRect.Right - 1, BorderRect.Bottom - 1);

      Canvas.Pen.Color := GetCurrentLightEdgeColor;
      Canvas.MoveTo(BorderRect.Left + 1, BorderRect.Bottom - 2);
      Canvas.LineTo(BorderRect.Left + 1, BorderRect.Top + 1);
      Canvas.LineTo(BorderRect.Right - 2, BorderRect.Top + 1);

      Canvas.Pen.Color := GetCurrentDarkEdgeColor;
      Canvas.MoveTo(BorderRect.Right - 2, BorderRect.Top + 1);
      Canvas.LineTo(BorderRect.Right - 2, BorderRect.Bottom - 2);
      Canvas.LineTo(BorderRect.Left + 1, BorderRect.Bottom - 2);

      InflateRect(BorderRect, -1, -1);
      if IsRectEmpty(BorderRect) then
        Break;
    end;
  end;

  DrawRect := ClientRect;
  InflateRect(DrawRect, -(FBorderWidth + 2), -(FBorderWidth + 2));
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Assign(Font);
  Canvas.Font.Color := GetCurrentTextColor;

  TextFlags := DT_CENTER or DT_VCENTER or DT_SINGLELINE;
  if Caption = '' then
    Exit;

  DrawText(Canvas.Handle, PChar(Caption), Length(Caption), DrawRect, TextFlags);
end;

procedure TSpeedButtonAviUtlStyle.SetBorderColor(const Value: TColor);
begin
  if FBorderColor <> Value then
  begin
    FBorderColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetBorderWidth(const Value: Integer);
begin
  if FBorderWidth <> Value then
  begin
    FBorderWidth := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetDarkEdgeColor(const Value: TColor);
begin
  if FDarkEdgeColor <> Value then
  begin
    FDarkEdgeColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetDisabledColor(const Value: TColor);
begin
  if FDisabledColor <> Value then
  begin
    FDisabledColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetDisabledTextColor(const Value: TColor);
begin
  if FDisabledTextColor <> Value then
  begin
    FDisabledTextColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetDownBorderColor(const Value: TColor);
begin
  if FDownBorderColor <> Value then
  begin
    FDownBorderColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetDownDarkEdgeColor(const Value: TColor);
begin
  if FDownDarkEdgeColor <> Value then
  begin
    FDownDarkEdgeColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetDownLightEdgeColor(const Value: TColor);
begin
  if FDownLightEdgeColor <> Value then
  begin
    FDownLightEdgeColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetDownColor(const Value: TColor);
begin
  if FDownColor <> Value then
  begin
    FDownColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetHotBorderColor(const Value: TColor);
begin
  if FHotBorderColor <> Value then
  begin
    FHotBorderColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetHotDarkEdgeColor(const Value: TColor);
begin
  if FHotDarkEdgeColor <> Value then
  begin
    FHotDarkEdgeColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetHotLightEdgeColor(const Value: TColor);
begin
  if FHotLightEdgeColor <> Value then
  begin
    FHotLightEdgeColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetHotColor(const Value: TColor);
begin
  if FHotColor <> Value then
  begin
    FHotColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetNormalColor(const Value: TColor);
begin
  if FNormalColor <> Value then
  begin
    FNormalColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetLightEdgeColor(const Value: TColor);
begin
  if FLightEdgeColor <> Value then
  begin
    FLightEdgeColor := Value;
    Invalidate;
  end;
end;

procedure TSpeedButtonAviUtlStyle.SetTextColor(const Value: TColor);
begin
  if FTextColor <> Value then
  begin
    FTextColor := Value;
    Invalidate;
  end;
end;

end.
