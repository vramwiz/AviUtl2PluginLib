unit PluginFilterSerifDrawSyncBacking;

interface

// 背面同期の移動図形と、通過済み領域を行単位の描画領域へ変換する。

uses
  System.Types;

const
  SERIF_SYNC_BACKING_ALPHA = 160;

type
  TSerifSyncBackingRegion = record
    Bounds: TRect;
    CenterX: Integer;
    CenterY: Integer;
    Size: Integer;
    TrailEnabled: Boolean;
    TrailCompleted: Boolean;
  end;

function CalculateSerifSyncBackingRegions(const ALineLayoutBounds:
  TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncBackingRegion>; overload;
function CalculateSerifSyncBackingRegions(const ALineLayoutBounds,
  ATextUnitBounds: TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncBackingRegion>; overload;
function IsSerifSyncBackingPixelVisible(const ARegion: TSerifSyncBackingRegion;
  const AX, AY, AShape: Integer): Boolean;

implementation

uses
  System.Math,
  PluginFilterSerifDrawAnimationTypes,
  PluginFilterSerifDrawSyncGeometry;

function CalculateSerifSyncBackingRegions(const ALineLayoutBounds:
  TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncBackingRegion>;
var
  CenterX: Integer;
  CenterY: Integer;
  CurrentLineIndex: Integer;
  EffectiveLines: TArray<TRect>;
  FirstLineIndex: Integer;
  I: Integer;
  LineBounds: TRect;
  LineWidth: Integer;
  OffsetX: Integer;
  OffsetY: Integer;
  PathIndex: Integer;
  RegionIndex: Integer;
  Remaining: Integer;
  Size: Integer;
  TotalWidth: Integer;
begin
  Result := nil;
  EffectiveLines := ALineLayoutBounds;
  if Length(EffectiveLines) = 0 then
  begin
    SetLength(EffectiveLines, 1);
    EffectiveLines[0] := ALayoutBounds;
  end;

  TotalWidth := 0;
  for I := 0 to High(EffectiveLines) do
    if EffectiveLines[I].Width > 0 then
      Inc(TotalWidth, EffectiveLines[I].Width);
  if TotalWidth <= 0 then
    Exit;

  if ATotalFrames <= 1 then
    PathIndex := 0
  else
    PathIndex := Round(EnsureRange(ACurrentFrame, 0, ATotalFrames - 1) /
      (ATotalFrames - 1) * (TotalWidth - 1));
  Remaining := PathIndex;
  CurrentLineIndex := -1;
  for I := 0 to High(EffectiveLines) do
  begin
    LineWidth := EffectiveLines[I].Width;
    if LineWidth <= 0 then
      Continue;
    CurrentLineIndex := I;
    if Remaining < LineWidth then
      Break;
    Dec(Remaining, LineWidth);
  end;
  if CurrentLineIndex < 0 then
    Exit;

  if ATrailEnabled then
  begin
    SetLength(Result, CurrentLineIndex + 1);
    FirstLineIndex := 0;
  end
  else
  begin
    SetLength(Result, 1);
    FirstLineIndex := CurrentLineIndex;
  end;
  OffsetX := -AImageBounds.Left + Round(AOffsetX);
  OffsetY := -AImageBounds.Top + Round(AOffsetY);
  RegionIndex := 0;
  for I := FirstLineIndex to CurrentLineIndex do
  begin
    LineBounds := EffectiveLines[I];
    if LineBounds.Width <= 0 then
      Continue;
    // 100%は文字行の実測高さと同じ正方形／帯幅とする。
    Size := Max(1, Round(LineBounds.Height * Max(0.01, ASizePercent) /
      100.0));
    CenterY := (LineBounds.Top + LineBounds.Bottom) div 2;
    Result[RegionIndex].Size := Size;
    Result[RegionIndex].CenterY := CenterY + OffsetY;
    Result[RegionIndex].TrailEnabled := ATrailEnabled;
    Result[RegionIndex].TrailCompleted := I < CurrentLineIndex;
    if Result[RegionIndex].TrailCompleted then
    begin
      Result[RegionIndex].CenterX := LineBounds.Right + OffsetX;
      Result[RegionIndex].Bounds := TRect.Create(LineBounds.Left,
        CenterY - Size div 2, LineBounds.Right,
        CenterY + (Size + 1) div 2);
    end
    else
    begin
      CenterX := LineBounds.Left + Min(Remaining, LineBounds.Width - 1);
      Result[RegionIndex].CenterX := CenterX + OffsetX;
      if ATrailEnabled then
        Result[RegionIndex].Bounds.Left := LineBounds.Left
      else
        Result[RegionIndex].Bounds.Left := Max(CenterX - Size div 2,
          LineBounds.Left);
      Result[RegionIndex].Bounds.Top := CenterY - Size div 2;
      Result[RegionIndex].Bounds.Right := Min(CenterX + (Size + 1) div 2,
        LineBounds.Right);
      Result[RegionIndex].Bounds.Bottom :=
        CenterY + (Size + 1) div 2;
    end;
    Result[RegionIndex].Bounds.Offset(OffsetX, OffsetY);
    Inc(RegionIndex);
  end;
  SetLength(Result, RegionIndex);
end;

function CalculateSerifSyncBackingRegions(const ALineLayoutBounds,
  ATextUnitBounds: TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncBackingRegion>;
var
  Bounds: TRect;
  CenterX: Integer;
  CenterY: Integer;
  CurrentIndex: Integer;
  FirstIndex: Integer;
  I: Integer;
  LineBounds: TRect;
  RegionIndex: Integer;
  Size: Integer;
begin
  if APaintMode <> SERIF_ANIMATION_SYNC_PAINT_CHARACTER then
    Exit(CalculateSerifSyncBackingRegions(ALineLayoutBounds, ALayoutBounds,
      AImageBounds, ACurrentFrame, ATotalFrames, ATrailEnabled,
      ASizePercent, AOffsetX, AOffsetY));

  Result := nil;
  if Length(ATextUnitBounds) = 0 then
    Exit;
  if ATotalFrames <= 1 then
    CurrentIndex := 0
  else
    CurrentIndex := Min(High(ATextUnitBounds), Trunc(
      EnsureRange(ACurrentFrame, 0, ATotalFrames - 1) /
      (ATotalFrames - 1) * Length(ATextUnitBounds)));
  if ATrailEnabled then
    FirstIndex := 0
  else
    FirstIndex := CurrentIndex;

  SetLength(Result, CurrentIndex - FirstIndex + 1);
  RegionIndex := 0;
  for I := FirstIndex to CurrentIndex do
  begin
    Bounds := ATextUnitBounds[I];
    if Bounds.IsEmpty then
      Continue;
    LineBounds := FindSerifSyncTextUnitLineBounds(Bounds,
      ALineLayoutBounds, ALayoutBounds, AImageBounds);
    Size := Max(1, Round(LineBounds.Height *
      Max(0.01, ASizePercent) / 100.0));
    CenterX := (Bounds.Left + Bounds.Right) div 2 + Round(AOffsetX);
    CenterY := (LineBounds.Top + LineBounds.Bottom) div 2 + Round(AOffsetY);
    Result[RegionIndex].Bounds := TRect.Create(
      CenterX - Size div 2, CenterY - Size div 2,
      CenterX + (Size + 1) div 2, CenterY + (Size + 1) div 2);
    Result[RegionIndex].CenterX := CenterX;
    Result[RegionIndex].CenterY := CenterY;
    Result[RegionIndex].Size := Size;
    // 文字単位では軌跡も個々の形を維持し、連続した帯へ変換しない。
    Result[RegionIndex].TrailEnabled := False;
    Result[RegionIndex].TrailCompleted := ATrailEnabled and
      (I < CurrentIndex);
    Inc(RegionIndex);
  end;
  SetLength(Result, RegionIndex);
end;

function IsSerifSyncBackingPixelVisible(const ARegion: TSerifSyncBackingRegion;
  const AX, AY, AShape: Integer): Boolean;
var
  Shape: Integer;

  function IsVisibleAtCenter(const ACenterX: Integer): Boolean;
  var
    DX: Double;
    DY: Double;
    HalfSize: Double;
    LocalY: Double;
  begin
    HalfSize := ARegion.Size / 2.0;
    DX := (AX + 0.5) - ACenterX;
    DY := (AY + 0.5) - ARegion.CenterY;
    case Shape of
      SERIF_ANIMATION_SYNC_SHAPE_CIRCLE:
        Result := Sqr(DX / HalfSize) + Sqr(DY / HalfSize) <= 1.0;
      SERIF_ANIMATION_SYNC_SHAPE_TRIANGLE:
        begin
          LocalY := DY + HalfSize;
          Result := (LocalY >= 0.0) and (LocalY <= ARegion.Size) and
            (Abs(DX) <= HalfSize * LocalY / ARegion.Size);
        end;
    else
      Result := True;
    end;
  end;
begin
  if not ARegion.Bounds.Contains(Point(AX, AY)) then
    Exit(False);
  Shape := AShape;
  if Shape = SERIF_ANIMATION_SYNC_SHAPE_AUTO then
    Shape := SERIF_ANIMATION_SYNC_SHAPE_SQUARE;
  if Shape = SERIF_ANIMATION_SYNC_SHAPE_SQUARE then
    Exit(True);
  if not ARegion.TrailEnabled then
    Exit(IsVisibleAtCenter(ARegion.CenterX));
  // 図形を連続移動させた軌跡は帯になり、現在位置より先だけが形状別の先端になる。
  if ARegion.TrailCompleted or (AX < ARegion.CenterX) then
    Exit(True);
  Result := IsVisibleAtCenter(ARegion.CenterX);
end;

end.
