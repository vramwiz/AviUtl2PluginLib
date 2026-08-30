unit PluginFilterSerifDrawSyncFront;

interface

// 背面マーカーと同じ領域を文字の前面へスクリーン合成し、色付きライトにする。

uses
  System.Types,
  PluginFilterSerifDrawSyncBacking,
  TextRendererTypes;

const
  SERIF_SYNC_FRONT_ALPHA = 144;

function CalculateSerifSyncFrontRegions(const ALineLayoutBounds:
  TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncBackingRegion>; overload;
function CalculateSerifSyncFrontRegions(const ALineLayoutBounds,
  ATextUnitBounds: TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncBackingRegion>; overload;
procedure ExpandSerifSyncFrontBounds(var AEffectRect: TRect;
  const ARegions: TArray<TSerifSyncBackingRegion>;
  const AEffectX, AEffectY: Integer);
procedure BlendSerifSyncFrontPixel(const AColor: Integer;
  const AOpacity: Byte; var APixel: TTextRenderPixel);
procedure CompositeSerifSyncFront(
  const ARegions: TArray<TSerifSyncBackingRegion>;
  const AShape, AColor, AEffectX, AEffectY, ABandTop,
  ABandBottom: Integer; const AClipToBand: Boolean;
  const ADestinationImage: TTextRenderImage);

implementation

function CalculateSerifSyncFrontRegions(const ALineLayoutBounds:
  TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncBackingRegion>;
begin
  Result := CalculateSerifSyncBackingRegions(ALineLayoutBounds,
    ALayoutBounds, AImageBounds, ACurrentFrame, ATotalFrames, ATrailEnabled,
    ASizePercent, AOffsetX, AOffsetY);
end;

function CalculateSerifSyncFrontRegions(const ALineLayoutBounds,
  ATextUnitBounds: TArray<TRect>; const ALayoutBounds, AImageBounds: TRect;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncBackingRegion>;
begin
  Result := CalculateSerifSyncBackingRegions(ALineLayoutBounds,
    ATextUnitBounds, ALayoutBounds, AImageBounds, ACurrentFrame,
    ATotalFrames, ATrailEnabled, APaintMode, ASizePercent, AOffsetX,
    AOffsetY);
end;

procedure ExpandSerifSyncFrontBounds(var AEffectRect: TRect;
  const ARegions: TArray<TSerifSyncBackingRegion>;
  const AEffectX, AEffectY: Integer);
var
  Bounds: TRect;
  I: Integer;
begin
  for I := 0 to High(ARegions) do
  begin
    Bounds := ARegions[I].Bounds;
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

procedure BlendSerifSyncFrontPixel(const AColor: Integer;
  const AOpacity: Byte; var APixel: TTextRenderPixel);
var
  ColorAlpha: Integer;
  LightPixel: TTextRenderPixel;
begin
  ColorAlpha := (AColor shr 24) and $FF;
  if ColorAlpha = 0 then
    ColorAlpha := 255;
  LightPixel.A := (AOpacity * ColorAlpha + 127) div 255;
  // スクリーン色を半透明合成する。暗部は指定色で明るくなり、明部は潰れない。
  LightPixel.R := 255 - (255 - APixel.R) *
    (255 - ((AColor shr 16) and $FF)) div 255;
  LightPixel.G := 255 - (255 - APixel.G) *
    (255 - ((AColor shr 8) and $FF)) div 255;
  LightPixel.B := 255 - (255 - APixel.B) *
    (255 - (AColor and $FF)) div 255;
  BlendStraightAlpha(LightPixel, APixel);
end;

procedure CompositeSerifSyncFront(
  const ARegions: TArray<TSerifSyncBackingRegion>;
  const AShape, AColor, AEffectX, AEffectY, ABandTop,
  ABandBottom: Integer; const AClipToBand: Boolean;
  const ADestinationImage: TTextRenderImage);
var
  Column: Integer;
  Destination: PTextRenderPixel;
  DestinationY: Integer;
  I: Integer;
  Region: TSerifSyncBackingRegion;
  Row: Integer;
begin
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
        if IsSerifSyncBackingPixelVisible(Region, Column, Row, AShape) then
          BlendSerifSyncFrontPixel(AColor, SERIF_SYNC_FRONT_ALPHA,
            Destination^);
        Inc(Destination);
      end;
    end;
  end;
end;

end.

