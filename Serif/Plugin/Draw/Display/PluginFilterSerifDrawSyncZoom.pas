unit PluginFilterSerifDrawSyncZoom;

interface

// 独立した文字レイヤーを使い、拡大対象と通常文字を同じ座標系で合成する。

uses
  System.Types,
  TextRendererTypes;

type
  TSerifSyncZoomItem = record
    DestinationRect: TRect;
    SourceImage: TTextRenderImage;
  end;

function CalculateSerifSyncZoomItems(
  const ATextUnitImages: TArray<TTextRenderImage>;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncZoomItem>; overload;
function CalculateSerifSyncZoomItems(
  const ATextUnitImages: TArray<TTextRenderImage>;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncZoomItem>; overload;
procedure ExpandSerifSyncZoomBounds(var AEffectRect: TRect;
  const AItems: TArray<TSerifSyncZoomItem>;
  const AEffectX, AEffectY: Integer);
procedure CompositeSerifSyncZoom(const AItems: TArray<TSerifSyncZoomItem>;
  const ADestinationImage: TTextRenderImage;
  const AEffectX, AEffectY, ABandTop, ABandBottom: Integer;
  const AClipToBand: Boolean);
procedure ExpandSerifSyncSmoothZoomBounds(var AEffectRect: TRect;
  const AImage: TTextRenderImage; const ASizePercent, AOffsetX,
  AOffsetY: Double);
procedure CompositeSerifSyncSmoothZoom(const AImage: TTextRenderImage;
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

function CalculateSerifSyncZoomItems(
  const ATextUnitImages: TArray<TTextRenderImage>;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncZoomItem>;
begin
  Result := CalculateSerifSyncZoomItems(ATextUnitImages, ACurrentFrame,
    ATotalFrames, ATrailEnabled, SERIF_ANIMATION_SYNC_PAINT_SMOOTH,
    ASizePercent, AOffsetX, AOffsetY);
end;

function CalculateSerifSyncZoomItems(
  const ATextUnitImages: TArray<TTextRenderImage>;
  const ACurrentFrame, ATotalFrames: Integer;
  const ATrailEnabled: Boolean; const APaintMode: Integer;
  const ASizePercent, AOffsetX,
  AOffsetY: Double): TArray<TSerifSyncZoomItem>;
var
  ScaleDelta: Double;
  CenterX: Integer;
  CenterY: Integer;
  CurrentIndex: Integer;
  DestinationHeight: Integer;
  DestinationWidth: Integer;
  I: Integer;
  LocalProgress: Double;
  PathPosition: Double;
  Progress: Double;
  Scale: Double;
  SourceImage: TTextRenderImage;
  SourceRect: TRect;
  UnitCount: Integer;
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
  // サイズは倍率そのもの。100%=等倍、120%=1.2倍、80%=0.8倍。
  ScaleDelta := Max(0.01, ASizePercent) / 100.0 - 1.0;
  for I := 0 to UnitCount - 1 do
  begin
    SourceImage := ATextUnitImages[I];
    if SourceImage = nil then
      Continue;
    SourceRect := SourceImage.Bounds;
    Scale := 1.0;
    CenterX := (SourceRect.Left + SourceRect.Right) div 2;
    CenterY := (SourceRect.Top + SourceRect.Bottom) div 2;
    if (APaintMode = SERIF_ANIMATION_SYNC_PAINT_CHARACTER) and
      ((ATrailEnabled and (I <= CurrentIndex)) or
       (not ATrailEnabled and (I = CurrentIndex))) then
      Scale := 1.0 + ScaleDelta
    else if ATrailEnabled and (I < CurrentIndex) then
      Scale := 1.0 + ScaleDelta
    else if I = CurrentIndex then
    begin
      if ATrailEnabled then
        Scale := 1.0 + ScaleDelta * Sin(LocalProgress * Pi * 0.5)
      else
        Scale := 1.0 + ScaleDelta * Sin(LocalProgress * Pi);
    end;
    if (I = CurrentIndex) or (ATrailEnabled and (I < CurrentIndex)) then
    begin
      Inc(CenterX, Round(AOffsetX));
      Inc(CenterY, Round(AOffsetY));
    end;
    DestinationWidth := Max(1, Round(SourceRect.Width * Scale));
    DestinationHeight := Max(1, Round(SourceRect.Height * Scale));
    Result[I].SourceImage := SourceImage;
    Result[I].DestinationRect := TRect.Create(
      CenterX - DestinationWidth div 2,
      CenterY - DestinationHeight div 2,
      CenterX + (DestinationWidth + 1) div 2,
      CenterY + (DestinationHeight + 1) div 2);
  end;
end;

procedure ExpandSerifSyncZoomBounds(var AEffectRect: TRect;
  const AItems: TArray<TSerifSyncZoomItem>;
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

procedure CompositeSerifSyncZoom(const AItems: TArray<TSerifSyncZoomItem>;
  const ADestinationImage: TTextRenderImage;
  const AEffectX, AEffectY, ABandTop, ABandBottom: Integer;
  const AClipToBand: Boolean);
var
  Destination: PTextRenderPixel;
  DestinationY: Integer;
  I: Integer;
  Item: TSerifSyncZoomItem;
  Source: PTextRenderPixel;
  SourceX: Integer;
  SourceY: Integer;
  X: Integer;
  Y: Integer;
begin
  for I := 0 to High(AItems) do
  begin
    Item := AItems[I];
    if Item.SourceImage = nil then
      Continue;
    for Y := Item.DestinationRect.Top to Item.DestinationRect.Bottom - 1 do
    begin
      DestinationY := AEffectY + Y;
      if (DestinationY < 0) or
        (DestinationY >= ADestinationImage.Height) or
        (AClipToBand and ((DestinationY < ABandTop) or
          (DestinationY >= ABandBottom))) then
        Continue;
      SourceY := (Y - Item.DestinationRect.Top) * Item.SourceImage.Height div
        Item.DestinationRect.Height;
      Destination := PTextRenderPixel(PByte(ADestinationImage.Data) +
        NativeInt(DestinationY) * ADestinationImage.Stride +
        NativeInt(AEffectX + Item.DestinationRect.Left) *
          SizeOf(TTextRenderPixel));
      for X := Item.DestinationRect.Left to Item.DestinationRect.Right - 1 do
      begin
        SourceX := (X - Item.DestinationRect.Left) * Item.SourceImage.Width div
          Item.DestinationRect.Width;
        Source := PTextRenderPixel(PByte(Item.SourceImage.Data) +
          NativeInt(SourceY) * Item.SourceImage.Stride +
          NativeInt(SourceX) * SizeOf(TTextRenderPixel));
        BlendStraightAlpha(Source^, Destination^);
        Inc(Destination);
      end;
    end;
  end;
end;

procedure ExpandSerifSyncSmoothZoomBounds(var AEffectRect: TRect;
  const AImage: TTextRenderImage; const ASizePercent, AOffsetX,
  AOffsetY: Double);
var
  PadX: Integer;
  PadY: Integer;
  Scale: Double;
begin
  if AImage = nil then
    Exit;
  Scale := EnsureRange(Max(0.01, ASizePercent) / 100.0, 0.1, 5.0);
  PadX := Ceil((AImage.Width * 0.5 + Abs(AOffsetX)) *
    Abs(Scale - 1.0));
  PadY := Ceil((AImage.Height * 0.5 + Abs(AOffsetY)) *
    Abs(Scale - 1.0));
  AEffectRect.Inflate(PadX, PadY);
end;

function SmoothZoomWeight(const AX, ACenterX, ARadius: Double;
  const ATrailEnabled: Boolean): Double;
var
  Distance: Double;
begin
  if ATrailEnabled and (AX <= ACenterX) then
    Exit(1.0);
  Distance := Abs(AX - ACenterX);
  if ATrailEnabled then
    Distance := Max(0.0, AX - ACenterX);
  if Distance >= ARadius then
    Exit(0.0);
  Result := 0.5 + 0.5 * Cos(Pi * Distance / ARadius);
end;

function SmoothZoomScaleAt(const AX, ACenterX, ARadius,
  ATargetScale: Double; const ATrailEnabled: Boolean): Double;
begin
  Result := 1.0 + (ATargetScale - 1.0) *
    SmoothZoomWeight(AX, ACenterX, ARadius, ATrailEnabled);
end;

procedure CompositeSerifSyncSmoothZoom(const AImage: TTextRenderImage;
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
  DX: Integer;
  DY: Integer;
  I: Integer;
  LineBounds: TRect;
  LineWidth: Integer;
  PadX: Integer;
  PadY: Integer;
  PathPosition: Double;
  PivotY: Double;
  Progress: Double;
  Radius: Double;
  Remaining: Double;
  Scale: Double;
  Source: PTextRenderPixel;
  SourceX: Double;
  SourceXi: Integer;
  SourceY: Double;
  SourceYi: Integer;
  TargetScale: Double;
  TotalWidth: Integer;
  WarpBottom: Double;
  WarpTop: Double;
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
  // オフセットは支点座標ではなく見た目の移動方向として扱う。
  // 拡大支点は逆方向へ動くため、正値で変形結果が下へ移動する。
  PivotY := (LineBounds.Top + LineBounds.Bottom) * 0.5 - AOffsetY;
  Radius := Max(1.0, LineBounds.Height * 0.5 + Abs(AOffsetX));
  TargetScale := EnsureRange(Max(0.01, ASizePercent) / 100.0, 0.1, 5.0);
  PadX := Ceil((AImage.Width * 0.5 + Abs(AOffsetX)) *
    Abs(TargetScale - 1.0));
  PadY := Ceil((AImage.Height * 0.5 + Abs(AOffsetY)) *
    Abs(TargetScale - 1.0));
  WarpTop := Min(LineBounds.Top,
    PivotY + (LineBounds.Top - PivotY) * TargetScale);
  WarpBottom := Max(LineBounds.Bottom,
    PivotY + (LineBounds.Bottom - PivotY) * TargetScale);
  for DY := -PadY to AImage.Height + PadY - 1 do
  begin
    DestinationY := AEffectY + DY;
    if (DestinationY < 0) or (DestinationY >= ADestinationImage.Height) or
      (AClipToBand and ((DestinationY < ABandTop) or
        (DestinationY >= ABandBottom))) then
      Continue;
    Destination := PTextRenderPixel(PByte(ADestinationImage.Data) +
      NativeInt(DestinationY) * ADestinationImage.Stride +
      NativeInt(AEffectX - PadX) * SizeOf(TTextRenderPixel));
    for DX := -PadX to AImage.Width + PadX - 1 do
    begin
      SourceX := DX;
      SourceY := DY;
      if (DY >= Floor(WarpTop)) and (DY < Ceil(WarpBottom)) then
      begin
        // 逆変換を反復し、局所倍率で変形した元のX座標を求める。
        for I := 0 to 7 do
        begin
          Scale := SmoothZoomScaleAt(SourceX, CenterX, Radius,
            TargetScale, ATrailEnabled);
          SourceX := CenterX + (DX - CenterX) / Scale;
        end;
        Scale := SmoothZoomScaleAt(SourceX, CenterX, Radius,
          TargetScale, ATrailEnabled);
        SourceY := PivotY + (DY - PivotY) / Scale;
      end;
      SourceXi := Round(SourceX);
      SourceYi := Round(SourceY);
      if (SourceXi >= 0) and (SourceXi < AImage.Width) and
        (SourceYi >= 0) and (SourceYi < AImage.Height) then
      begin
        // 変形帯では現在行だけを採用し、元の字形が背後へ残らないようにする。
        if ((DY < Floor(WarpTop)) or (DY >= Ceil(WarpBottom))) or
          ((SourceY >= LineBounds.Top) and (SourceY < LineBounds.Bottom)) then
        begin
          Source := PTextRenderPixel(PByte(AImage.Data) +
            NativeInt(SourceYi) * AImage.Stride +
            NativeInt(SourceXi) * SizeOf(TTextRenderPixel));
          BlendStraightAlpha(Source^, Destination^);
        end;
      end;
      Inc(Destination);
    end;
  end;
end;

end.
