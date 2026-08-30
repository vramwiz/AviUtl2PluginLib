unit PluginFilterSerifDrawSyncGeometry;

interface

// 文字単位の横位置を保ったまま、所属行の共通縦基準を取得する。

uses
  System.Types;

function FindSerifSyncTextUnitLineBounds(const ATextUnitBounds: TRect;
  const ALineLayoutBounds: TArray<TRect>;
  const ALayoutBounds, AImageBounds: TRect): TRect;

implementation

uses
  System.Math;

function FindSerifSyncTextUnitLineBounds(const ATextUnitBounds: TRect;
  const ALineLayoutBounds: TArray<TRect>;
  const ALayoutBounds, AImageBounds: TRect): TRect;
var
  BestDistance: Integer;
  Distance: Integer;
  I: Integer;
  LineBounds: TRect;
  UnitCenterY: Integer;
begin
  if Length(ALineLayoutBounds) = 0 then
    Result := ALayoutBounds
  else
  begin
    Result := ALineLayoutBounds[0];
    UnitCenterY := (ATextUnitBounds.Top + ATextUnitBounds.Bottom) div 2;
    BestDistance := MaxInt;
    for I := 0 to High(ALineLayoutBounds) do
    begin
      LineBounds := ALineLayoutBounds[I];
      LineBounds.Offset(-AImageBounds.Left, -AImageBounds.Top);
      Distance := Abs(UnitCenterY -
        (LineBounds.Top + LineBounds.Bottom) div 2);
      if Distance < BestDistance then
      begin
        BestDistance := Distance;
        Result := ALineLayoutBounds[I];
      end;
    end;
  end;
  Result.Offset(-AImageBounds.Left, -AImageBounds.Top);
end;

end.
