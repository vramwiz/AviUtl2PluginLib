unit PluginFilterSerifDrawSyncUnderline;

interface

// 下線同期の領域計算、形状判定、文字画像への合成を担当する。

uses
  System.Types,
  TextRendererTypes;

type
  TSerifSyncUnderlineRegion = record
    Bounds: TRect;
    CenterX: Integer;
    CenterY: Integer;
    MarkerWidth: Integer;
    Thickness: Integer;
    TrailCompleted: Boolean;
    TrailEnabled: Boolean;
  end;

function CalculateSerifSyncUnderlineRegions(const ALineLayoutBounds:
  TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncUnderlineRegion>; overload;
function CalculateSerifSyncUnderlineRegions(const ALineLayoutBounds,
  ATextUnitBounds: TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncUnderlineRegion>; overload;
function IsSerifSyncUnderlinePixelVisible(
  const ARegion: TSerifSyncUnderlineRegion;
  const AX, AY, AShape: Integer): Boolean;
procedure ExpandSerifSyncUnderlineBounds(var AEffectRect: TRect;
  const ARegions: TArray<TSerifSyncUnderlineRegion>;
  const AEffectX, AEffectY: Integer);
procedure CompositeSerifSyncUnderline(const ARegions:
  TArray<TSerifSyncUnderlineRegion>; const AShape, AColor, AEffectX,
  AEffectY, ABandTop, ABandBottom: Integer; const AClipToBand: Boolean;
  const ADestinationImage: TTextRenderImage);

implementation

uses
  System.Math,
  PluginFilterSerifDrawAnimationTypes,
  PluginFilterSerifDrawSyncGeometry;

const
  UNDERLINE_GAP = 2;

function CalculateSerifSyncUnderlineRegions(const ALineLayoutBounds:
  TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncUnderlineRegion>;
var
  CenterX: Integer;
  CurrentLineIndex: Integer;
  EffectiveLines: TArray<TRect>;
  FirstLineIndex: Integer;
  I: Integer;
  LineBounds: TRect;
  LineWidth: Integer;
  MarkerWidth: Integer;
  OffsetX: Integer;
  OffsetY: Integer;
  PathIndex: Integer;
  RegionIndex: Integer;
  Remaining: Integer;
  Thickness: Integer;
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
    MarkerWidth := Max(1, Round(LineBounds.Height *
      Max(0.01, ASizePercent) / 100.0));
    Thickness := Max(1, Round(Max(2.0, LineBounds.Height * 0.08) *
      Max(0.01, ASizePercent) / 100.0));
    Result[RegionIndex].CenterY := LineBounds.Bottom + UNDERLINE_GAP +
      Thickness div 2 + OffsetY;
    Result[RegionIndex].MarkerWidth := MarkerWidth;
    Result[RegionIndex].Thickness := Thickness;
    Result[RegionIndex].TrailEnabled := ATrailEnabled;
    Result[RegionIndex].TrailCompleted := I < CurrentLineIndex;
    if Result[RegionIndex].TrailCompleted then
    begin
      Result[RegionIndex].CenterX := LineBounds.Right + OffsetX;
      Result[RegionIndex].Bounds := TRect.Create(LineBounds.Left,
        LineBounds.Bottom + UNDERLINE_GAP, LineBounds.Right,
        LineBounds.Bottom + UNDERLINE_GAP + Thickness);
    end
    else
    begin
      CenterX := LineBounds.Left + Min(Remaining, LineBounds.Width - 1);
      Result[RegionIndex].CenterX := CenterX + OffsetX;
      if ATrailEnabled then
        Result[RegionIndex].Bounds.Left := LineBounds.Left
      else
        Result[RegionIndex].Bounds.Left := Max(CenterX - MarkerWidth div 2,
          LineBounds.Left);
      Result[RegionIndex].Bounds.Top := LineBounds.Bottom + UNDERLINE_GAP;
      Result[RegionIndex].Bounds.Right := Min(
        CenterX + (MarkerWidth + 1) div 2, LineBounds.Right);
      Result[RegionIndex].Bounds.Bottom :=
        Result[RegionIndex].Bounds.Top + Thickness;
    end;
    Result[RegionIndex].Bounds.Offset(OffsetX, OffsetY);
    Inc(RegionIndex);
  end;
  SetLength(Result, RegionIndex);
end;

function CalculateSerifSyncUnderlineRegions(const ALineLayoutBounds,
  ATextUnitBounds: TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncUnderlineRegion>;
var
  Bounds: TRect;
  CenterX: Integer;
  CurrentIndex: Integer;
  FirstIndex: Integer;
  I: Integer;
  LineBounds: TRect;
  MarkerWidth: Integer;
  RegionIndex: Integer;
  Thickness: Integer;
begin
  if APaintMode <> SERIF_ANIMATION_SYNC_PAINT_CHARACTER then
    Exit(CalculateSerifSyncUnderlineRegions(ALineLayoutBounds,
      ALayoutBounds, AImageBounds, ACurrentFrame, ATotalFrames,
      ATrailEnabled, ASizePercent, AOffsetX, AOffsetY));

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
    MarkerWidth := Max(1, Round(Bounds.Width *
      Max(0.01, ASizePercent) / 100.0));
    Thickness := Max(1, Round(Max(2.0, LineBounds.Height * 0.08) *
      Max(0.01, ASizePercent) / 100.0));
    CenterX := (Bounds.Left + Bounds.Right) div 2 + Round(AOffsetX);
    Result[RegionIndex].CenterX := CenterX;
    Result[RegionIndex].CenterY := LineBounds.Bottom + UNDERLINE_GAP +
      Thickness div 2 + Round(AOffsetY);
    Result[RegionIndex].MarkerWidth := MarkerWidth;
    Result[RegionIndex].Thickness := Thickness;
    Result[RegionIndex].Bounds := TRect.Create(
      CenterX - MarkerWidth div 2,
      Result[RegionIndex].CenterY - Thickness div 2,
      CenterX + (MarkerWidth + 1) div 2,
      Result[RegionIndex].CenterY + (Thickness + 1) div 2);
    // 維持時も文字ごとの下線形状を残す。
    Result[RegionIndex].TrailEnabled := False;
    Result[RegionIndex].TrailCompleted := ATrailEnabled and
      (I < CurrentIndex);
    Inc(RegionIndex);
  end;
  SetLength(Result, RegionIndex);
end;

function IsSerifSyncUnderlinePixelVisible(
  const ARegion: TSerifSyncUnderlineRegion;
  const AX, AY, AShape: Integer): Boolean;
var
  Shape: Integer;

  function IsVisibleAtCenter: Boolean;
  var
    DX: Double;
    DY: Double;
    HalfHeight: Double;
    HalfWidth: Double;
    LocalX: Double;
  begin
    if ARegion.TrailEnabled then
      HalfWidth := ARegion.Thickness * 0.5
    else
      HalfWidth := ARegion.MarkerWidth * 0.5;
    HalfHeight := ARegion.Thickness * 0.5;
    DX := (AX + 0.5) - ARegion.CenterX;
    DY := (AY + 0.5) - ARegion.CenterY;
    case Shape of
      SERIF_ANIMATION_SYNC_SHAPE_CIRCLE:
        Result := Sqr(DX / Max(0.5, HalfWidth)) +
          Sqr(DY / Max(0.5, HalfHeight)) <= 1.0;
      SERIF_ANIMATION_SYNC_SHAPE_TRIANGLE:
        begin
          LocalX := DX + HalfWidth;
          Result := (LocalX >= 0.0) and (LocalX <= HalfWidth * 2.0) and
            (Abs(DY) <= HalfHeight * LocalX / Max(1.0, HalfWidth * 2.0));
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
    Exit(IsVisibleAtCenter);
  if ARegion.TrailCompleted or (AX < ARegion.CenterX) then
    Exit(True);
  Result := IsVisibleAtCenter;
end;

procedure ExpandSerifSyncUnderlineBounds(var AEffectRect: TRect;
  const ARegions: TArray<TSerifSyncUnderlineRegion>;
  const AEffectX, AEffectY: Integer);
var
  I: Integer;
  RegionBounds: TRect;
begin
  for I := 0 to High(ARegions) do
  begin
    RegionBounds := ARegions[I].Bounds;
    RegionBounds.Offset(AEffectX, AEffectY);
    if not RegionBounds.IsEmpty then
      AEffectRect := TRect.Union(AEffectRect, RegionBounds);
  end;
end;

procedure BlendStraightAlpha(const ASource: TTextRenderPixel;
  var ADestination: TTextRenderPixel);
var
  InverseAlpha: Integer;
  OutputAlpha: Integer;
begin
  if ASource.A = 0 then
    Exit;
  if ASource.A = 255 then
  begin
    ADestination := ASource;
    Exit;
  end;
  InverseAlpha := 255 - ASource.A;
  OutputAlpha := ASource.A + (ADestination.A * InverseAlpha + 127) div 255;
  if OutputAlpha = 0 then
  begin
    ADestination := System.Default(TTextRenderPixel);
    Exit;
  end;
  ADestination.R := (ASource.R * ASource.A +
    ADestination.R * ADestination.A * InverseAlpha div 255 +
    OutputAlpha div 2) div OutputAlpha;
  ADestination.G := (ASource.G * ASource.A +
    ADestination.G * ADestination.A * InverseAlpha div 255 +
    OutputAlpha div 2) div OutputAlpha;
  ADestination.B := (ASource.B * ASource.A +
    ADestination.B * ADestination.A * InverseAlpha div 255 +
    OutputAlpha div 2) div OutputAlpha;
  ADestination.A := OutputAlpha;
end;

procedure CompositeSerifSyncUnderline(const ARegions:
  TArray<TSerifSyncUnderlineRegion>; const AShape, AColor, AEffectX,
  AEffectY, ABandTop, ABandBottom: Integer; const AClipToBand: Boolean;
  const ADestinationImage: TTextRenderImage);
var
  Column: Integer;
  Destination: PTextRenderPixel;
  DestinationY: Integer;
  I: Integer;
  Pixel: TTextRenderPixel;
  Region: TSerifSyncUnderlineRegion;
  Row: Integer;
begin
  Pixel.A := Byte((AColor shr 24) and $FF);
  Pixel.R := Byte((AColor shr 16) and $FF);
  Pixel.G := Byte((AColor shr 8) and $FF);
  Pixel.B := Byte(AColor and $FF);
  for I := 0 to High(ARegions) do
  begin
    Region := ARegions[I];
    for Row := Region.Bounds.Top to Region.Bounds.Bottom - 1 do
    begin
      DestinationY := AEffectY + Row;
      if (DestinationY < 0) or
        (DestinationY >= ADestinationImage.Height) or
        (AClipToBand and ((DestinationY < ABandTop) or
          (DestinationY >= ABandBottom))) then
        Continue;
      Destination := PTextRenderPixel(PByte(ADestinationImage.Data) +
        NativeInt(DestinationY) * ADestinationImage.Stride +
        NativeInt(AEffectX + Region.Bounds.Left) *
          SizeOf(TTextRenderPixel));
      for Column := Region.Bounds.Left to Region.Bounds.Right - 1 do
      begin
        if IsSerifSyncUnderlinePixelVisible(Region, Column, Row, AShape) then
          BlendStraightAlpha(Pixel, Destination^);
        Inc(Destination);
      end;
    end;
  end;
end;

end.
