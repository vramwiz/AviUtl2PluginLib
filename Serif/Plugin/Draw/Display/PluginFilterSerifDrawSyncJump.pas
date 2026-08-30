unit PluginFilterSerifDrawSyncJump;

interface

// 独立した文字レイヤーを使い、発音位置の文字だけを跳躍させる。

uses
  System.Types,
  TextRendererTypes;

type
  TSerifSyncJumpItem = record
    DestinationRect: TRect;
    SourceImage: TTextRenderImage;
  end;

function CalculateSerifSyncJumpItems(
  const ATextUnitImages: TArray<TTextRenderImage>;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncJumpItem>; overload;
function CalculateSerifSyncJumpItems(
  const ATextUnitImages: TArray<TTextRenderImage>;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncJumpItem>; overload;
procedure ExpandSerifSyncJumpBounds(var AEffectRect: TRect;
  const AItems: TArray<TSerifSyncJumpItem>;
  const AEffectX, AEffectY: Integer);
procedure CompositeSerifSyncJump(const AItems: TArray<TSerifSyncJumpItem>;
  const ADestinationImage: TTextRenderImage;
  const AEffectX, AEffectY, ABandTop, ABandBottom: Integer;
  const AClipToBand: Boolean);
procedure ExpandSerifSyncSmoothJumpBounds(var AEffectRect: TRect;
  const AImage: TTextRenderImage; const ASizePercent, AOffsetY: Double);
procedure CompositeSerifSyncSmoothJump(const AImage: TTextRenderImage;
  const ALineLayoutBounds: TArray<TRect>;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double; const ADestinationImage: TTextRenderImage;
  const AEffectX, AEffectY, ABandTop, ABandBottom: Integer;
  const AClipToBand: Boolean);

implementation

uses
  System.Math,
  PluginFilterSerifDrawAnimationTypes;

function CalculateSerifSyncJumpItems(
  const ATextUnitImages: TArray<TTextRenderImage>;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncJumpItem>;
begin
  Result := CalculateSerifSyncJumpItems(ATextUnitImages, ACurrentFrame,
    ATotalFrames, ATrailEnabled, SERIF_ANIMATION_SYNC_PAINT_SMOOTH,
    ASizePercent, AOffsetX, AOffsetY);
end;

function CalculateSerifSyncJumpItems(
  const ATextUnitImages: TArray<TTextRenderImage>;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncJumpItem>;
var
  CurrentIndex: Integer;
  I: Integer;
  JumpHeight: Double;
  LocalProgress: Double;
  PathPosition: Double;
  Phase: Double;
  Progress: Double;
  SourceImage: TTextRenderImage;
  UnitCount: Integer;
  X: Integer;
  Y: Integer;
begin
  Result := nil;
  UnitCount := Length(ATextUnitImages);
  if UnitCount <= 0 then
    Exit;
  if ATotalFrames <= 1 then
    Progress := 0.0
  else
    Progress := EnsureRange(ACurrentFrame / (ATotalFrames - 1), 0.0, 1.0);
  PathPosition := Progress * UnitCount;
  if Progress >= 1.0 then
  begin
    CurrentIndex := UnitCount - 1;
    LocalProgress := 1.0;
  end
  else
  begin
    CurrentIndex := Min(UnitCount - 1, Floor(PathPosition));
    LocalProgress := Frac(PathPosition);
  end;

  SetLength(Result, UnitCount);
  for I := 0 to UnitCount - 1 do
  begin
    SourceImage := ATextUnitImages[I];
    if SourceImage = nil then
      Continue;
    Phase := 0.0;
    if (APaintMode = SERIF_ANIMATION_SYNC_PAINT_CHARACTER) and
      ((ATrailEnabled and (I <= CurrentIndex)) or
       (not ATrailEnabled and (I = CurrentIndex))) then
      Phase := 1.0
    else if ATrailEnabled and (I < CurrentIndex) then
      Phase := 1.0
    else if I = CurrentIndex then
    begin
      if ATrailEnabled then
        Phase := Sin(LocalProgress * Pi * 0.5)
      else
        Phase := Sin(LocalProgress * Pi);
    end;
    // サイズは共通の百分率。100%=元位置、120%=文字高の20%上昇。
    JumpHeight := SourceImage.Height *
      (Max(0.01, ASizePercent) / 100.0 - 1.0);
    X := Round(AOffsetX * Phase);
    Y := Round((AOffsetY - JumpHeight) * Phase);
    Result[I].SourceImage := SourceImage;
    Result[I].DestinationRect := SourceImage.Bounds;
    Result[I].DestinationRect.Offset(X, Y);
  end;
end;

procedure ExpandSerifSyncJumpBounds(var AEffectRect: TRect;
  const AItems: TArray<TSerifSyncJumpItem>;
  const AEffectX, AEffectY: Integer);
var
  Bounds: TRect;
  I: Integer;
begin
  for I := 0 to High(AItems) do
  begin
    if AItems[I].SourceImage = nil then
      Continue;
    Bounds := AItems[I].DestinationRect;
    Bounds.Offset(AEffectX, AEffectY);
    AEffectRect := TRect.Union(AEffectRect, Bounds);
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

procedure CompositeSerifSyncJump(const AItems: TArray<TSerifSyncJumpItem>;
  const ADestinationImage: TTextRenderImage;
  const AEffectX, AEffectY, ABandTop, ABandBottom: Integer;
  const AClipToBand: Boolean);
var
  Destination: PTextRenderPixel;
  DestinationY: Integer;
  I: Integer;
  Item: TSerifSyncJumpItem;
  Row: Integer;
  Source: PTextRenderPixel;
  X: Integer;
begin
  for I := 0 to High(AItems) do
  begin
    Item := AItems[I];
    if Item.SourceImage = nil then
      Continue;
    for Row := 0 to Item.SourceImage.Height - 1 do
    begin
      DestinationY := AEffectY + Item.DestinationRect.Top + Row;
      if (DestinationY < 0) or
        (DestinationY >= ADestinationImage.Height) or
        (AClipToBand and ((DestinationY < ABandTop) or
          (DestinationY >= ABandBottom))) then
        Continue;
      Source := PTextRenderPixel(PByte(Item.SourceImage.Data) +
        NativeInt(Row) * Item.SourceImage.Stride);
      Destination := PTextRenderPixel(PByte(ADestinationImage.Data) +
        NativeInt(DestinationY) * ADestinationImage.Stride +
        NativeInt(AEffectX + Item.DestinationRect.Left) *
          SizeOf(TTextRenderPixel));
      for X := 0 to Item.SourceImage.Width - 1 do
      begin
        BlendStraightAlpha(Source^, Destination^);
        Inc(Source);
        Inc(Destination);
      end;
    end;
  end;
end;

procedure ExpandSerifSyncSmoothJumpBounds(var AEffectRect: TRect;
  const AImage: TTextRenderImage; const ASizePercent, AOffsetY: Double);
var
  PadY: Integer;
begin
  if AImage = nil then
    Exit;
  PadY := Ceil(Abs(AOffsetY) + AImage.Height *
    Abs(Max(0.01, ASizePercent) / 100.0 - 1.0));
  AEffectRect.Inflate(0, PadY);
end;

function SmoothJumpWeight(const AX, ACenterX, ARadius: Double;
  const ATrailEnabled: Boolean): Double;
var
  Distance: Double;
begin
  if ATrailEnabled and (AX <= ACenterX) then
    Exit(1.0);
  if ATrailEnabled then
    Distance := Max(0.0, AX - ACenterX)
  else
    Distance := Abs(AX - ACenterX);
  if Distance >= ARadius then
    Exit(0.0);
  Result := 0.5 + 0.5 * Cos(Pi * Distance / ARadius);
end;

procedure CompositeSerifSyncSmoothJump(const AImage: TTextRenderImage;
  const ALineLayoutBounds: TArray<TRect>;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double; const ADestinationImage: TTextRenderImage;
  const AEffectX, AEffectY, ABandTop, ABandBottom: Integer;
  const AClipToBand: Boolean);
var
  CenterX: Double;
  CurrentLine: Integer;
  Destination: PTextRenderPixel;
  DestinationY: Integer;
  Displacement: Double;
  DX: Integer;
  DY: Integer;
  I: Integer;
  LineBounds: TRect;
  LineWidth: Integer;
  PadY: Integer;
  PathPosition: Double;
  Progress: Double;
  Radius: Double;
  Remaining: Double;
  Source: PTextRenderPixel;
  SourceY: Double;
  SourceYi: Integer;
  TotalWidth: Integer;
  WarpBottom: Double;
  WarpTop: Double;
  Weight: Double;
begin
  if (AImage = nil) or (ADestinationImage = nil) or
    (Length(ALineLayoutBounds) = 0) then
    Exit;
  TotalWidth := 0;
  for I := 0 to High(ALineLayoutBounds) do
    Inc(TotalWidth, Max(0, ALineLayoutBounds[I].Width));
  if TotalWidth <= 0 then
    Exit;
  if ATotalFrames <= 1 then
    Progress := 0.0
  else
    Progress := EnsureRange(ACurrentFrame / (ATotalFrames - 1), 0.0, 1.0);
  PathPosition := Progress * Max(0, TotalWidth - 1);
  Remaining := PathPosition;
  CurrentLine := 0;
  for I := 0 to High(ALineLayoutBounds) do
  begin
    LineWidth := Max(0, ALineLayoutBounds[I].Width);
    CurrentLine := I;
    if Remaining < LineWidth then
      Break;
    Remaining := Remaining - LineWidth;
  end;
  LineBounds := ALineLayoutBounds[CurrentLine];
  LineBounds.Offset(-AImage.Bounds.Left, -AImage.Bounds.Top);
  CenterX := LineBounds.Left + Min(Remaining, Max(0, LineBounds.Width - 1));
  Radius := Max(1.0, LineBounds.Height * 0.5 + Abs(AOffsetX));
  Displacement := AOffsetY - LineBounds.Height *
    (Max(0.01, ASizePercent) / 100.0 - 1.0);
  PadY := Ceil(Abs(AOffsetY) + AImage.Height *
    Abs(Max(0.01, ASizePercent) / 100.0 - 1.0));
  WarpTop := Min(LineBounds.Top, LineBounds.Top + Displacement);
  WarpBottom := Max(LineBounds.Bottom, LineBounds.Bottom + Displacement);
  for DY := -PadY to AImage.Height + PadY - 1 do
  begin
    DestinationY := AEffectY + DY;
    if (DestinationY < 0) or (DestinationY >= ADestinationImage.Height) or
      (AClipToBand and ((DestinationY < ABandTop) or
        (DestinationY >= ABandBottom))) then
      Continue;
    Destination := PTextRenderPixel(PByte(ADestinationImage.Data) +
      NativeInt(DestinationY) * ADestinationImage.Stride +
      NativeInt(AEffectX) * SizeOf(TTextRenderPixel));
    for DX := 0 to AImage.Width - 1 do
    begin
      SourceY := DY;
      if (DY >= Floor(WarpTop)) and (DY < Ceil(WarpBottom)) then
      begin
        Weight := SmoothJumpWeight(DX, CenterX, Radius, ATrailEnabled);
        SourceY := DY - Displacement * Weight;
      end;
      SourceYi := Round(SourceY);
      if (SourceYi >= 0) and (SourceYi < AImage.Height) then
      begin
        if ((DY < Floor(WarpTop)) or (DY >= Ceil(WarpBottom))) or
          ((SourceY >= LineBounds.Top) and (SourceY < LineBounds.Bottom)) then
        begin
          Source := PTextRenderPixel(PByte(AImage.Data) +
            NativeInt(SourceYi) * AImage.Stride +
            NativeInt(DX) * SizeOf(TTextRenderPixel));
          BlendStraightAlpha(Source^, Destination^);
        end;
      end;
      Inc(Destination);
    end;
  end;
end;

end.
