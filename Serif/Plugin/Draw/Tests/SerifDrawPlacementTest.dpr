program SerifDrawPlacementTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  AviUtl2FilterTypes in 'Lib\AviUtl2Filter\AviUtl2FilterTypes.pas',
  PluginFilterSerifDrawSettings in
    'Serif\Plugin\Draw\PluginFilterSerifDrawSettings.pas',
  PluginFilterSerifDrawPlacement in
    'Serif\Plugin\Draw\Display\PluginFilterSerifDrawPlacement.pas';

procedure RequirePoint(const APlacement: Byte;
  const AExpectedX, AExpectedY: Single);
var
  Actual: TPointF;
begin
  Actual := SerifDrawPlacementAnchor(APlacement,
    Rect(-10, -20, 110, 80), Rect(0, 0, 100, 60));
  if (Abs(Actual.X - AExpectedX) > 0.001) or
    (Abs(Actual.Y - AExpectedY) > 0.001) then
    raise Exception.CreateFmt('Placement %d mismatch: %.3f, %.3f',
      [APlacement, Actual.X, Actual.Y]);
end;

begin
  RequirePoint(SERIF_PLACEMENT_TOP_LEFT, 10, 20);
  RequirePoint(SERIF_PLACEMENT_TOP_CENTER, 60, 20);
  RequirePoint(SERIF_PLACEMENT_TOP_RIGHT, 110, 20);
  RequirePoint(SERIF_PLACEMENT_CENTER_LEFT, 10, 50);
  RequirePoint(SERIF_PLACEMENT_CENTER, 60, 50);
  RequirePoint(SERIF_PLACEMENT_CENTER_RIGHT, 110, 50);
  RequirePoint(SERIF_PLACEMENT_BOTTOM_LEFT, 10, 80);
  RequirePoint(SERIF_PLACEMENT_BOTTOM_CENTER, 60, 80);
  RequirePoint(SERIF_PLACEMENT_BOTTOM_RIGHT, 110, 80);
  if (SnapSerifDrawPositionX(-2) <> 0) or
    (SnapSerifDrawPositionX(2) <> 0) or
    (SnapSerifDrawPositionX(2.01) <> 2.01) then
    raise Exception.Create('X position snapping mismatch.');
  if (SnapSerifDrawPositionY(8) <> 10) or
    (SnapSerifDrawPositionY(12) <> 10) or
    (SnapSerifDrawPositionY(-8) <> -10) or
    (SnapSerifDrawPositionY(-12) <> -10) or
    (SnapSerifDrawPositionY(7.9) <> 7.9) or
    (SnapSerifDrawPositionY(13) <> 13) then
    raise Exception.Create('Y position snapping mismatch.');
  if (SnapSerifDrawPositionX(3.4, 3.5) <> 0) or
    (SnapSerifDrawPositionY(13.4, 3.5) <> 10) then
    raise Exception.Create('Scaled position snapping mismatch.');
  Writeln('SerifDraw placement tests passed.');
end.
