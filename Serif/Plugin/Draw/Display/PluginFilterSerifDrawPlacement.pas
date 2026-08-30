unit PluginFilterSerifDrawPlacement;

interface

uses
  System.Types;

// LayoutBounds上の9方向アンカーを、効果画像Bounds左上からの相対座標で返す。
function SerifDrawPlacementAnchor(const APlacement: Byte;
  const ABounds, ALayoutBounds: TRect): TPointF;
function SerifDrawPlacementName(const APlacement: Byte): string;
function SnapSerifDrawPositionX(const AValue: Double;
  const ATolerance: Double = 2.0): Double;
function SnapSerifDrawPositionY(const AValue: Double;
  const ATolerance: Double = 2.0): Double;

implementation

uses
  PluginFilterSerifDrawSettings;

function SerifDrawPlacementAnchor(const APlacement: Byte;
  const ABounds, ALayoutBounds: TRect): TPointF;
var
  Column: Integer;
  Row: Integer;
begin
  Column := APlacement mod 3;
  Row := APlacement div 3;
  case Column of
    0: Result.X := ALayoutBounds.Left - ABounds.Left;
    1: Result.X := (ALayoutBounds.Left + ALayoutBounds.Right) * 0.5 -
         ABounds.Left;
  else
    Result.X := ALayoutBounds.Right - ABounds.Left;
  end;
  case Row of
    0: Result.Y := ALayoutBounds.Top - ABounds.Top;
    1: Result.Y := (ALayoutBounds.Top + ALayoutBounds.Bottom) * 0.5 -
         ABounds.Top;
  else
    Result.Y := ALayoutBounds.Bottom - ABounds.Top;
  end;
end;

function SerifDrawPlacementName(const APlacement: Byte): string;
begin
  case APlacement of
    SERIF_PLACEMENT_TOP_LEFT: Result := '左上';
    SERIF_PLACEMENT_TOP_CENTER: Result := '上中央';
    SERIF_PLACEMENT_TOP_RIGHT: Result := '右上';
    SERIF_PLACEMENT_CENTER_LEFT: Result := '左中央';
    SERIF_PLACEMENT_CENTER: Result := '中央';
    SERIF_PLACEMENT_CENTER_RIGHT: Result := '右中央';
    SERIF_PLACEMENT_BOTTOM_LEFT: Result := '左下';
    SERIF_PLACEMENT_BOTTOM_CENTER: Result := '下中央';
    SERIF_PLACEMENT_BOTTOM_RIGHT: Result := '右下';
  else
    Result := '中央';
  end;
end;

function SnapSerifDrawPositionX(const AValue,
  ATolerance: Double): Double;
begin
  if Abs(AValue) <= ATolerance then
    Result := 0.0
  else
    Result := AValue;
end;

function SnapSerifDrawPositionY(const AValue,
  ATolerance: Double): Double;
var
  GridValue: Double;
begin
  GridValue := Round(AValue / 10.0) * 10.0;
  if Abs(AValue - GridValue) <= ATolerance then
    Result := GridValue
  else
    Result := AValue;
end;

end.
