unit PluginFilterSerifDrawPlacementPopup;

interface

uses
  System.Classes,
  System.Types,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.Forms;

type
  TSerifDrawPlacementSelectedEvent = procedure(Sender: TObject;
    const APlacement: Byte) of object;

  TSerifDrawPlacementGrid = class(TCustomControl)
  private
    FHotPlacement: Integer;
    FOnSelected: TSerifDrawPlacementSelectedEvent;
    FPlacement: Byte;
    function PlacementAt(const X, Y: Integer): Integer;
    procedure SetPlacement(const Value: Byte);
  protected
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property OnSelected: TSerifDrawPlacementSelectedEvent read FOnSelected write FOnSelected;
    property Placement: Byte read FPlacement write SetPlacement;
  end;

  TSerifDrawPlacementPopup = class(TCustomForm)
  private
    FGrid: TSerifDrawPlacementGrid;
    FOnSelected: TSerifDrawPlacementSelectedEvent;
    procedure FormDeactivate(Sender: TObject);
    procedure GridSelected(Sender: TObject; const APlacement: Byte);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Popup(const APoint: TPoint; const APlacement: Byte);
    property OnSelected: TSerifDrawPlacementSelectedEvent read FOnSelected write FOnSelected;
  end;

implementation

uses
  System.Math,
  PluginFilterSerifDrawSettingsTheme,
  Vcl.Graphics,
  Winapi.Windows,
  PluginFilterSerifDrawSettings;

const
  CELL_SIZE = 28;
  GRID_PADDING = 2;

constructor TSerifDrawPlacementGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  FHotPlacement := -1;
  FPlacement := SERIF_PLACEMENT_CENTER;
end;

procedure TSerifDrawPlacementGrid.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FHotPlacement <> -1 then
  begin
    FHotPlacement := -1;
    Invalidate;
  end;
end;

procedure TSerifDrawPlacementGrid.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  SelectedPlacement: Integer;
begin
  inherited;
  if Button <> mbLeft then
    Exit;
  SelectedPlacement := PlacementAt(X, Y);
  if (SelectedPlacement >= SERIF_PLACEMENT_TOP_LEFT) and
    (SelectedPlacement <= SERIF_PLACEMENT_BOTTOM_RIGHT) and
    Assigned(FOnSelected) then
    FOnSelected(Self, SelectedPlacement);
end;

procedure TSerifDrawPlacementGrid.MouseMove(Shift: TShiftState;
  X, Y: Integer);
var
  NewHotPlacement: Integer;
begin
  inherited;
  NewHotPlacement := PlacementAt(X, Y);
  if FHotPlacement <> NewHotPlacement then
  begin
    FHotPlacement := NewHotPlacement;
    Invalidate;
  end;
end;

procedure TSerifDrawPlacementGrid.Paint;
const
  DARK_BACKGROUND = SERIF_DRAW_PANEL_COLOR;
  DARK_BORDER = TColor($00505050);
  DARK_HOT = SERIF_DRAW_ICON_HOVER_COLOR;
  DARK_SELECTED = SERIF_DRAW_ICON_SELECTED_COLOR;
  DARK_PLACEMENT = TColor($00C8C8C8);
var
  CellHeight: Integer;
  CellRect: TRect;
  CellWidth: Integer;
  Column: Integer;
  GlyphHeight: Integer;
  GlyphRect: TRect;
  GlyphWidth: Integer;
  LineIndex: Integer;
  LineLeft: Integer;
  LineRight: Integer;
  LineY: Integer;
  Padding: Integer;
  PlacementIndex: Integer;
  Row: Integer;
begin
  Canvas.Brush.Color := DARK_BACKGROUND;
  Canvas.FillRect(ClientRect);
  Padding := Max(2, MulDiv(GRID_PADDING, CurrentPPI, 96));
  CellWidth := Max(1, (ClientWidth - Padding * 2) div 3);
  CellHeight := Max(1, (ClientHeight - Padding * 2) div 3);
  for PlacementIndex := SERIF_PLACEMENT_TOP_LEFT to
    SERIF_PLACEMENT_BOTTOM_RIGHT do
  begin
    Column := PlacementIndex mod 3;
    Row := PlacementIndex div 3;
    CellRect := Rect(Padding + Column * CellWidth,
      Padding + Row * CellHeight,
      Padding + (Column + 1) * CellWidth,
      Padding + (Row + 1) * CellHeight);
    if PlacementIndex = FPlacement then
      Canvas.Brush.Color := DARK_SELECTED
    else if PlacementIndex = FHotPlacement then
      Canvas.Brush.Color := DARK_HOT
    else
      Canvas.Brush.Color := DARK_BACKGROUND;
    Canvas.Pen.Color := DARK_BORDER;
    Canvas.Rectangle(CellRect);

    GlyphWidth := Min(MulDiv(19, CurrentPPI, 96),
      CellRect.Width - MulDiv(8, CurrentPPI, 96));
    GlyphHeight := Min(MulDiv(11, CurrentPPI, 96),
      CellRect.Height - MulDiv(8, CurrentPPI, 96));
    GlyphRect := Rect(
      (CellRect.Left + CellRect.Right - GlyphWidth) div 2,
      (CellRect.Top + CellRect.Bottom - GlyphHeight) div 2,
      (CellRect.Left + CellRect.Right + GlyphWidth) div 2,
      (CellRect.Top + CellRect.Bottom + GlyphHeight) div 2);
    Canvas.Pen.Color := DARK_PLACEMENT;
    Canvas.Pen.Width := Max(1, MulDiv(1, CurrentPPI, 96));
    for LineIndex := 0 to 2 do
    begin
      LineY := GlyphRect.Top + MulDiv(LineIndex,
        GlyphRect.Bottom - GlyphRect.Top - 1, 2);
      if LineIndex = Row then
      begin
        LineLeft := GlyphRect.Left;
        LineRight := GlyphRect.Right;
      end
      else
      begin
        case Column of
          0: LineLeft := GlyphRect.Left;
          1: LineLeft := (GlyphRect.Left + GlyphRect.Right) div 2 -
            (GlyphRect.Right - GlyphRect.Left) div 4;
        else
          LineLeft := GlyphRect.Right -
            (GlyphRect.Right - GlyphRect.Left) div 2;
        end;
        LineRight := LineLeft + (GlyphRect.Right - GlyphRect.Left) div 2;
      end;
      Canvas.MoveTo(LineLeft, LineY);
      Canvas.LineTo(LineRight, LineY);
    end;
    Canvas.Pen.Width := 1;
  end;
end;

function TSerifDrawPlacementGrid.PlacementAt(const X, Y: Integer): Integer;
var
  CellHeight: Integer;
  CellWidth: Integer;
  Column: Integer;
  Padding: Integer;
  Row: Integer;
begin
  Padding := Max(2, MulDiv(GRID_PADDING, CurrentPPI, 96));
  CellWidth := Max(1, (ClientWidth - Padding * 2) div 3);
  CellHeight := Max(1, (ClientHeight - Padding * 2) div 3);
  Column := (X - Padding) div CellWidth;
  Row := (Y - Padding) div CellHeight;
  if (X < Padding) or (Y < Padding) or
    (Column < 0) or (Column > 2) or (Row < 0) or (Row > 2) then
    Exit(-1);
  Result := Row * 3 + Column;
end;

procedure TSerifDrawPlacementGrid.SetPlacement(const Value: Byte);
begin
  if FPlacement = Value then
    Exit;
  FPlacement := Value;
  Invalidate;
end;

constructor TSerifDrawPlacementPopup.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  BorderStyle := bsNone;
  Color := TColor($00262626);
  KeyPreview := True;
  OnDeactivate := FormDeactivate;
  FGrid := TSerifDrawPlacementGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.OnSelected := GridSelected;
end;

procedure TSerifDrawPlacementPopup.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW;
end;

procedure TSerifDrawPlacementPopup.FormDeactivate(Sender: TObject);
begin
  Hide;
end;

procedure TSerifDrawPlacementPopup.GridSelected(Sender: TObject;
  const APlacement: Byte);
begin
  FGrid.Placement := APlacement;
  Hide;
  if Assigned(FOnSelected) then
    FOnSelected(Self, APlacement);
end;

procedure TSerifDrawPlacementPopup.KeyDown(var Key: Word;
  Shift: TShiftState);
begin
  inherited;
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    Hide;
  end;
end;

procedure TSerifDrawPlacementPopup.Popup(const APoint: TPoint;
  const APlacement: Byte);
var
  Monitor: TMonitor;
  PopupHeight: Integer;
  PopupLeft: Integer;
  PopupTop: Integer;
  PopupWidth: Integer;
begin
  FGrid.Placement := APlacement;
  HandleNeeded;
  PopupWidth := MulDiv(GRID_PADDING * 2 + CELL_SIZE * 3, CurrentPPI, 96);
  PopupHeight := PopupWidth;
  PopupLeft := APoint.X;
  PopupTop := APoint.Y;
  Monitor := Screen.MonitorFromPoint(APoint);
  if Monitor <> nil then
  begin
    PopupLeft := EnsureRange(PopupLeft, Monitor.WorkareaRect.Left,
      Monitor.WorkareaRect.Right - PopupWidth);
    PopupTop := EnsureRange(PopupTop, Monitor.WorkareaRect.Top,
      Monitor.WorkareaRect.Bottom - PopupHeight);
  end;
  SetBounds(PopupLeft, PopupTop, PopupWidth, PopupHeight);
  Show;
  BringToFront;
end;

end.
