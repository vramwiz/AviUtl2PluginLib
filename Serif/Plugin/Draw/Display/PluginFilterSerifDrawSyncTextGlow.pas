unit PluginFilterSerifDrawSyncTextGlow;

interface

// 独立文字レイヤーのぼかし輪郭を、発光として字形表面へ重ねる。

uses
  System.Types,
  TextRendererTypes;

type
  TSerifSyncTextGlowItem = record
    BaseDestinationRect: TRect;
    BaseSourceImage: TTextRenderImage;
    Brightness: Double;
    DestinationRect: TRect;
    Opacity: Double;
    SourceImage: TTextRenderImage;
  end;

function CalculateSerifSyncTextGlowItems(const ABaseImage,
  AGlowImage: TTextRenderImage; const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncTextGlowItem>; overload;
function CalculateSerifSyncTextGlowItems(const ABaseImage,
  AGlowImage: TTextRenderImage; const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncTextGlowItem>; overload;
procedure ExpandSerifSyncTextGlowBounds(var AEffectRect: TRect;
  const AItems: TArray<TSerifSyncTextGlowItem>;
  const AEffectX, AEffectY: Integer);
procedure CompositeSerifSyncTextGlow(
  const AItems: TArray<TSerifSyncTextGlowItem>;
  const ADestinationImage: TTextRenderImage;
  const AEffectX, AEffectY, ABandTop, ABandBottom: Integer;
  const AClipToBand: Boolean);

implementation

uses
  System.Math,
  PluginFilterSerifDrawAnimationTypes;

function CalculateSerifSyncTextGlowItems(const ABaseImage,
  AGlowImage: TTextRenderImage; const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncTextGlowItem>;
begin
  Result := CalculateSerifSyncTextGlowItems(ABaseImage, AGlowImage,
    ACurrentFrame, ATotalFrames, ATrailEnabled,
    SERIF_ANIMATION_SYNC_PAINT_SMOOTH, ASizePercent, AOffsetX, AOffsetY);
end;

function CalculateSerifSyncTextGlowItems(const ABaseImage,
  AGlowImage: TTextRenderImage; const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncTextGlowItem>;
var
  CurrentIndex: Integer;
  DeltaX: Integer;
  DeltaY: Integer;
  I: Integer;
  ItemIndex: Integer;
  LocalProgress: Double;
  Opacity: Double;
  PathPosition: Double;
  Progress: Double;
  Strength: Double;
  UnitCount: Integer;
  UnitImage: TTextRenderImage;
begin
  Result := nil;
  if (ABaseImage = nil) or (AGlowImage = nil) then
    Exit;
  UnitCount := Length(AGlowImage.TextUnitImages);
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
  DeltaX := (AGlowImage.Bounds.Left - AGlowImage.LayoutBounds.Left) -
    (ABaseImage.Bounds.Left - ABaseImage.LayoutBounds.Left) + Round(AOffsetX);
  DeltaY := (AGlowImage.Bounds.Top - AGlowImage.LayoutBounds.Top) -
    (ABaseImage.Bounds.Top - ABaseImage.LayoutBounds.Top) + Round(AOffsetY);
  if ATrailEnabled then
    SetLength(Result, CurrentIndex + 1)
  else
    SetLength(Result, 1);
  ItemIndex := 0;
  for I := 0 to CurrentIndex do
  begin
    if not ATrailEnabled and (I <> CurrentIndex) then
      Continue;
    UnitImage := AGlowImage.TextUnitImages[I];
    if UnitImage = nil then
      Continue;
    if (APaintMode = SERIF_ANIMATION_SYNC_PAINT_CHARACTER) and
      ((ATrailEnabled and (I <= CurrentIndex)) or
       (not ATrailEnabled and (I = CurrentIndex))) then
      Opacity := 1.0
    else if ATrailEnabled and (I < CurrentIndex) then
      Opacity := 1.0
    else if ATrailEnabled then
      Opacity := Sin(LocalProgress * Pi * 0.5)
    else
      Opacity := Sin(LocalProgress * Pi);
    Strength := Opacity;
    // サイズは発光量と文字表面の明度倍率。100%=基準、80%=0.8倍、120%=1.2倍。
    Opacity := Strength * Max(0.0, ASizePercent) / 100.0;
    if (Opacity <= 0.0001) and
      (Abs((1.0 + (Max(0.0, ASizePercent) / 100.0 - 1.0) *
        Strength) - 1.0) <= 0.0001) then
      Continue;
    Result[ItemIndex].SourceImage := UnitImage;
    Result[ItemIndex].Opacity := Opacity;
    Result[ItemIndex].Brightness := 1.0 +
      (Max(0.0, ASizePercent) / 100.0 - 1.0) * Strength;
    if I < Length(ABaseImage.TextUnitImages) then
    begin
      Result[ItemIndex].BaseSourceImage := ABaseImage.TextUnitImages[I];
      if Result[ItemIndex].BaseSourceImage <> nil then
        Result[ItemIndex].BaseDestinationRect :=
          Result[ItemIndex].BaseSourceImage.Bounds;
    end;
    Result[ItemIndex].DestinationRect := UnitImage.Bounds;
    Result[ItemIndex].DestinationRect.Offset(DeltaX, DeltaY);
    Inc(ItemIndex);
  end;
  SetLength(Result, ItemIndex);
end;

procedure ExpandSerifSyncTextGlowBounds(var AEffectRect: TRect;
  const AItems: TArray<TSerifSyncTextGlowItem>;
  const AEffectX, AEffectY: Integer);
var
  Bounds: TRect;
  I: Integer;
begin
  for I := 0 to High(AItems) do
  begin
    Bounds := AItems[I].DestinationRect;
    Bounds.Offset(AEffectX, AEffectY);
    AEffectRect := TRect.Union(AEffectRect, Bounds);
  end;
end;

procedure BlendStraightAlpha(const ASource: TTextRenderPixel;
  var ADestination: TTextRenderPixel);
var
  AlphaDenominator: Cardinal;
  DestinationAlpha: Cardinal;
  SourceAlpha: Cardinal;
begin
  SourceAlpha := ASource.A;
  if SourceAlpha = 0 then
    Exit;
  DestinationAlpha := ADestination.A;
  AlphaDenominator := SourceAlpha * 255 +
    DestinationAlpha * (255 - SourceAlpha);
  if AlphaDenominator = 0 then
    Exit;
  ADestination.R := (Cardinal(ASource.R) * SourceAlpha * 255 +
    Cardinal(ADestination.R) * DestinationAlpha * (255 - SourceAlpha) +
    AlphaDenominator div 2) div AlphaDenominator;
  ADestination.G := (Cardinal(ASource.G) * SourceAlpha * 255 +
    Cardinal(ADestination.G) * DestinationAlpha * (255 - SourceAlpha) +
    AlphaDenominator div 2) div AlphaDenominator;
  ADestination.B := (Cardinal(ASource.B) * SourceAlpha * 255 +
    Cardinal(ADestination.B) * DestinationAlpha * (255 - SourceAlpha) +
    AlphaDenominator div 2) div AlphaDenominator;
  ADestination.A := (AlphaDenominator + 127) div 255;
end;

procedure CompositeSerifSyncTextGlow(
  const AItems: TArray<TSerifSyncTextGlowItem>;
  const ADestinationImage: TTextRenderImage;
  const AEffectX, AEffectY, ABandTop, ABandBottom: Integer;
  const AClipToBand: Boolean);
var
  Destination: PTextRenderPixel;
  DestinationY: Integer;
  I: Integer;
  Item: TSerifSyncTextGlowItem;
  Pixel: TTextRenderPixel;
  Row: Integer;
  Source: PTextRenderPixel;
  X: Integer;
begin
  for I := 0 to High(AItems) do
  begin
    Item := AItems[I];
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
        Pixel := Source^;
        Pixel.A := EnsureRange(Round(Pixel.A * Item.Opacity), 0, 255);
        BlendStraightAlpha(Pixel, Destination^);
        Inc(Source);
        Inc(Destination);
      end;
    end;
    // 発光合成後の文字表面へ明度倍率を掛ける。字形のアルファを
    // マスクにするため、透明な文字外や背面だけを暗くしない。
    if (Item.BaseSourceImage = nil) or
      (Abs(Item.Brightness - 1.0) <= 0.0001) then
      Continue;
    for Row := 0 to Item.BaseSourceImage.Height - 1 do
    begin
      DestinationY := AEffectY + Item.BaseDestinationRect.Top + Row;
      if (DestinationY < 0) or
        (DestinationY >= ADestinationImage.Height) or
        (AClipToBand and ((DestinationY < ABandTop) or
          (DestinationY >= ABandBottom))) then
        Continue;
      Source := PTextRenderPixel(PByte(Item.BaseSourceImage.Data) +
        NativeInt(Row) * Item.BaseSourceImage.Stride);
      Destination := PTextRenderPixel(PByte(ADestinationImage.Data) +
        NativeInt(DestinationY) * ADestinationImage.Stride +
        NativeInt(AEffectX + Item.BaseDestinationRect.Left) *
          SizeOf(TTextRenderPixel));
      for X := 0 to Item.BaseSourceImage.Width - 1 do
      begin
        if Source^.A <> 0 then
        begin
          Pixel.A := Source^.A;
          Pixel.R := EnsureRange(Round(Destination^.R *
            (1.0 + (Item.Brightness - 1.0) * Pixel.A / 255.0)), 0, 255);
          Pixel.G := EnsureRange(Round(Destination^.G *
            (1.0 + (Item.Brightness - 1.0) * Pixel.A / 255.0)), 0, 255);
          Pixel.B := EnsureRange(Round(Destination^.B *
            (1.0 + (Item.Brightness - 1.0) * Pixel.A / 255.0)), 0, 255);
          Destination^.R := Pixel.R;
          Destination^.G := Pixel.G;
          Destination^.B := Pixel.B;
        end;
        Inc(Source);
        Inc(Destination);
      end;
    end;
  end;
end;

end.
