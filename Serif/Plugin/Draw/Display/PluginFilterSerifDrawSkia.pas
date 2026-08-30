unit PluginFilterSerifDrawSkia;

// セリフと枠をSkiaで合成し、AviUtl2の映像バッファへ転送する描画境界を提供する。

interface

uses
  System.SysUtils,
  AviUtl2FilterTypes,
  PluginFilterSerifDrawAnimationTypes,
  PluginFilterSerifDrawReceiver,
  PluginFilterSerifDrawSettings,
  TextRendererTypes;

type
  TSerifSkiaRender = class
  private
    FCache: TObject;
    FCompositePixels: TBytes;
    FFrameRoleNames: TArray<string>;
    FImage: TTextRenderImage;
    FRoleNameItems: TObject;
    FSettings: TSerifDrawSettings;
    FPlacement: Byte;
    FPositionX: Double;
    FPositionY: Double;
    FRenderer: TObject;
    FRoleSignature: string;
{$IFDEF DEBUG}
    FSendLogCount: Integer;
{$ENDIF}
    FSignature: string;
    function BuildCacheIdentity(const ASnapshot: TSerifDrawSnapshot): string;
    function BuildCacheSignature(const ASnapshot: TSerifDrawSnapshot;
      const ASettings: TSerifDrawSettings;
      const AParameters: TSerifDrawAnimationParameters): string;
    function BuildSignature(const ASnapshots: TArray<TSerifDrawSnapshot>;
      const ASettings: TSerifDrawSettings;
      const AParameters: TSerifDrawAnimationParameters): string;
    procedure BlendImageToComposite(const AImage: TTextRenderImage;
      const AWidth, AHeight: Integer; const APlacement: Byte;
      const APositionX, APositionY: Double;
      const ATransform: TSerifDrawAnimationTransform);
    procedure RenderRoleNames(const ASnapshots: TArray<TSerifDrawSnapshot>;
      const ASettings: TSerifDrawSettings);
    procedure RenderSnapshots(const ASnapshots: TArray<TSerifDrawSnapshot>;
      const ASettings: TSerifDrawSettings;
      const AParameters: TSerifDrawAnimationParameters);
    procedure SetEmptyImage;
    function TrySendComposited(Video: PFILTER_PROC_VIDEO;
      const ATransform: TSerifDrawAnimationTransform): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    // Updateで生成した合成画像を現在のAviUtl2映像バッファへアルファ合成する。
    procedure SendToAviUtl2(Video: PFILTER_PROC_VIDEO;
      const ATransform: TSerifDrawAnimationTransform);
    // スナップショットと設定の署名を比較し、変更時だけ合成画像を再生成する。
    procedure Update(const ASnapshots: TArray<TSerifDrawSnapshot>;
      const ASettings: TSerifDrawSettings;
      const AParameters: TSerifDrawAnimationParameters);
  end;

// Skia描画基盤をプロセス単位で初期化する。FinalizeSerifDrawSkiaと対で呼び出す。
procedure InitializeSerifDrawSkia;
// Skia描画基盤が保持するプロセス単位の資源を解放する。
procedure FinalizeSerifDrawSkia;

implementation

uses
  System.Generics.Collections,
  System.Math,
  System.Types,
  System.UITypes,
  Winapi.Windows,
  PluginFilterSerifDrawDebugLog,
  PluginFilterSerifDrawFrameRaster,
  PluginFilterSerifDrawOverlap,
  PluginFilterSerifDrawPlacement,
  PluginFilterSerifDrawRoleNames,
  PluginFilterSerifDrawSyncBacking,
  PluginFilterSerifDrawSyncFront,
  PluginFilterSerifDrawSyncHighlight,
  PluginFilterSerifDrawSyncJump,
  PluginFilterSerifDrawSyncTextGlow,
  PluginFilterSerifDrawSyncUnderline,
  PluginFilterSerifDrawSyncZoom,
  TextRenderer,
  TextRendererSkia,
  TextRendererSkiaRuntime;

const
  SERIF_STYLE_REVISION = 9;

type
  TSerifRoleNameRenderLayout = record
    Layer: Integer;
    Placement: Byte;
    PositionX: Double;
    PositionY: Double;
  end;

  TSerifRoleNameRenderItem = class
  public
    Image: TTextRenderImage;
    Layout: TSerifRoleNameRenderLayout;
    destructor Destroy; override;
  end;

  TSerifRenderCacheEntry = class
  public
    DecorationImage: TTextRenderImage;
    GlowImage: TTextRenderImage;
    Image: TTextRenderImage;
    MotionImage: TTextRenderImage;
    SyncImage: TTextRenderImage;
    Signature: string;
    destructor Destroy; override;
  end;

  TSerifRenderCache = TObjectDictionary<string, TSerifRenderCacheEntry>;

var
  SkiaRuntimeAcquired: Boolean;

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
  if SourceAlpha = 255 then
  begin
    ADestination := ASource;
    Exit;
  end;
  DestinationAlpha := ADestination.A;
  AlphaDenominator := SourceAlpha * 255 +
    DestinationAlpha * (255 - SourceAlpha);
  if AlphaDenominator = 0 then
  begin
    ADestination := System.Default(TTextRenderPixel);
    Exit;
  end;
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

function PluginDirectory: string;
var
  Buffer: array[0..MAX_PATH - 1] of Char;
  PathLength: DWORD;
begin
  PathLength := GetModuleFileName(HInstance, Buffer, Length(Buffer));
  if PathLength = 0 then
    RaiseLastOSError;
  SetString(Result, Buffer, PathLength);
  Result := ExtractFilePath(Result);
end;

procedure InitializeSerifDrawSkia;
var
  LibraryFileName: string;
begin
  if SkiaRuntimeAcquired then
    Exit;
  LibraryFileName := PluginDirectory + 'sk4d.dll';
  TTextRendererSkiaRuntime.Acquire(LibraryFileName);
  SkiaRuntimeAcquired := True;
  SerifDrawDebugLog('Shared Skia text renderer initialized from ' +
    LibraryFileName + '.');
end;

procedure FinalizeSerifDrawSkia;
begin
  if not SkiaRuntimeAcquired then
    Exit;
  TTextRendererSkiaRuntime.Release;
  SkiaRuntimeAcquired := False;
end;

{ TSerifSkiaRender }

destructor TSerifRoleNameRenderItem.Destroy;
begin
  Image.Free;
  inherited;
end;

function TSerifSkiaRender.BuildCacheIdentity(
  const ASnapshot: TSerifDrawSnapshot): string;
begin
  Result := IntToStr(ASnapshot.Layer) + ':' +
    IntToStr(Length(ASnapshot.SourceObjectID)) + ':' +
    ASnapshot.SourceObjectID;
end;

function TSerifSkiaRender.BuildCacheSignature(
  const ASnapshot: TSerifDrawSnapshot;
  const ASettings: TSerifDrawSettings;
  const AParameters: TSerifDrawAnimationParameters): string;
begin
  Result := IntToStr(SERIF_STYLE_REVISION) + ':' +
    ASettings.Encode + ':' + IntToStr(AParameters.SyncKind) + ':' +
    IntToStr(AParameters.SyncPaintMode) + ':' +
    IntToStr(AParameters.SyncMode) + ':' + IntToStr(AParameters.SyncShape) + ':' +
    IntToStr(AParameters.SyncColor) + ':' + FloatToStr(AParameters.SyncSize) + ':' +
    FloatToStr(AParameters.SyncOffsetX) + ':' + FloatToStr(AParameters.SyncOffsetY) +
    ':' + FloatToStr(AParameters.SyncValue1) + ':' +
    FloatToStr(AParameters.SyncValue2) + ':' + FloatToStr(AParameters.SyncValue3) + ':' +
    IntToStr(Length(ASnapshot.Serif)) + ':' +
    ASnapshot.Serif + ':' + IntToStr(Length(ASnapshot.Chara)) + ':' +
    ASnapshot.Chara;
end;

function TSerifSkiaRender.BuildSignature(
  const ASnapshots: TArray<TSerifDrawSnapshot>;
  const ASettings: TSerifDrawSettings;
  const AParameters: TSerifDrawAnimationParameters): string;
var
  Snapshot: TSerifDrawSnapshot;
begin
  Result := ASettings.Encode + '|' + IntToStr(AParameters.SyncKind) + '|' +
    IntToStr(AParameters.SyncPaintMode) + '|' +
    IntToStr(AParameters.SyncMode) + '|' + IntToStr(AParameters.SyncShape) +
    '|' + IntToStr(AParameters.SyncColor) + '|' +
    FloatToStr(AParameters.SyncSize) + '|' +
    FloatToStr(AParameters.SyncOffsetX) + '|' +
    FloatToStr(AParameters.SyncOffsetY) + '|' +
    FloatToStr(AParameters.SyncValue1) + '|' +
    FloatToStr(AParameters.SyncValue2) + '|' + FloatToStr(AParameters.SyncValue3) + '|' +
    IntToStr(Length(ASnapshots)) + '|';
  for Snapshot in ASnapshots do
  begin
    Result := Result + IntToStr(Snapshot.Layer) + ':' +
      IntToStr(Length(Snapshot.SourceObjectID)) + ':' + Snapshot.SourceObjectID +
      ':' + IntToStr(Length(Snapshot.Serif)) + ':' + Snapshot.Serif + ':' +
      IntToStr(Length(Snapshot.Chara)) + ':' + Snapshot.Chara;
    if AParameters.SyncKind = SERIF_ANIMATION_SYNC_SPEECH_COLOR then
      Result := Result + ':' + BoolToStr(Snapshot.SpeechActive, True) + ':' +
        BoolToStr(Snapshot.HoldSpeechSync, True) + ':' +
        FloatToStr(Snapshot.SpeechProgress)
    else if AParameters.SyncKind in [SERIF_ANIMATION_SYNC_BACKING,
      SERIF_ANIMATION_SYNC_UNDERLINE, SERIF_ANIMATION_SYNC_ZOOM,
      SERIF_ANIMATION_SYNC_GLOW, SERIF_ANIMATION_SYNC_JUMP,
      SERIF_ANIMATION_SYNC_FRONT] then
      Result := Result + ':' + IntToStr(Snapshot.TimelineFrame) + ':' +
        IntToStr(Snapshot.TimelineTotalFrames);
    Result := Result + '|';
  end;
end;

procedure CompositeTextUnitPixels(const AUnitImage,
  ADestinationImage: TTextRenderImage; const AEffectX, AEffectY,
  ABandTop, ABandBottom: Integer; const AClipToBand: Boolean);
var
  Column: Integer;
  Destination: PTextRenderPixel;
  DestinationY: Integer;
  Row: Integer;
  Source: PTextRenderPixel;
begin
  if AUnitImage = nil then
    Exit;
  for Row := 0 to AUnitImage.Height - 1 do
  begin
    DestinationY := AEffectY + AUnitImage.Bounds.Top + Row;
    if (DestinationY < 0) or (DestinationY >= ADestinationImage.Height) or
      (AClipToBand and ((DestinationY < ABandTop) or
        (DestinationY >= ABandBottom))) then
      Continue;
    Source := PTextRenderPixel(PByte(AUnitImage.Data) +
      NativeInt(Row) * AUnitImage.Stride);
    Destination := PTextRenderPixel(PByte(ADestinationImage.Data) +
      NativeInt(DestinationY) * ADestinationImage.Stride +
      NativeInt(AEffectX + AUnitImage.Bounds.Left) *
        SizeOf(TTextRenderPixel));
    for Column := 0 to AUnitImage.Width - 1 do
    begin
      BlendStraightAlpha(Source^, Destination^);
      Inc(Source);
      Inc(Destination);
    end;
  end;
end;

procedure CopyImagePixels(const ASourceImage, ADestinationImage:
  TTextRenderImage; const ADestinationX, ADestinationY, ABandTop,
  ABandBottom: Integer; const AClipToBand: Boolean);
var
  CopyBytes: NativeInt;
  Destination: Pointer;
  DestinationY: Integer;
  Row: Integer;
  Source: Pointer;
begin
  if (ASourceImage = nil) or (ADestinationImage = nil) then
    Exit;
  CopyBytes := NativeInt(ASourceImage.Width) * SizeOf(TTextRenderPixel);
  for Row := 0 to ASourceImage.Height - 1 do
  begin
    DestinationY := ADestinationY + Row;
    if (DestinationY < 0) or
      (DestinationY >= ADestinationImage.Height) or
      (AClipToBand and ((DestinationY < ABandTop) or
        (DestinationY >= ABandBottom))) then
      Continue;
    Source := Pointer(PByte(ASourceImage.Data) +
      NativeInt(Row) * ASourceImage.Stride);
    Destination := Pointer(PByte(ADestinationImage.Data) +
      NativeInt(DestinationY) * ADestinationImage.Stride +
      NativeInt(ADestinationX) * SizeOf(TTextRenderPixel));
    Move(Source^, Destination^, CopyBytes);
  end;
end;

procedure CompositeTextUnitPixelsRange(const AUnitImage,
  ADestinationImage: TTextRenderImage; const AStartProgress,
  AEndProgress: Double;
  const AEffectX, AEffectY, ABandTop, ABandBottom: Integer;
  const AClipToBand: Boolean);
var
  ClipLeft: Integer;
  ClipRight: Integer;
  Column: Integer;
  Destination: PTextRenderPixel;
  DestinationY: Integer;
  InkLeft: Integer;
  InkRight: Integer;
  Row: Integer;
  Source: PTextRenderPixel;
begin
  if (AUnitImage = nil) or (AEndProgress <= AStartProgress) or
    (AEndProgress <= 0.0) or (AStartProgress >= 1.0) then
    Exit;
  if (AStartProgress <= 0.0) and (AEndProgress >= 1.0) then
  begin
    CompositeTextUnitPixels(AUnitImage, ADestinationImage, AEffectX, AEffectY,
      ABandTop, ABandBottom, AClipToBand);
    Exit;
  end;
  InkLeft := AUnitImage.Width;
  InkRight := -1;
  for Row := 0 to AUnitImage.Height - 1 do
  begin
    Source := PTextRenderPixel(PByte(AUnitImage.Data) +
      NativeInt(Row) * AUnitImage.Stride);
    for Column := 0 to AUnitImage.Width - 1 do
    begin
      if Source^.A <> 0 then
      begin
        InkLeft := Min(InkLeft, Column);
        InkRight := Max(InkRight, Column);
      end;
      Inc(Source);
    end;
  end;
  if InkRight < InkLeft then
    Exit;
  ClipLeft := InkLeft + Floor((InkRight - InkLeft + 1) *
    EnsureRange(AStartProgress, 0.0, 1.0));
  ClipRight := Min(InkRight + 1, InkLeft +
    Ceil((InkRight - InkLeft + 1) *
      EnsureRange(AEndProgress, 0.0, 1.0)));
  for Row := 0 to AUnitImage.Height - 1 do
  begin
    DestinationY := AEffectY + AUnitImage.Bounds.Top + Row;
    if (DestinationY < 0) or (DestinationY >= ADestinationImage.Height) or
      (AClipToBand and ((DestinationY < ABandTop) or
        (DestinationY >= ABandBottom))) then
      Continue;
    Source := PTextRenderPixel(PByte(AUnitImage.Data) +
      NativeInt(Row) * AUnitImage.Stride +
      NativeInt(ClipLeft) * SizeOf(TTextRenderPixel));
    Destination := PTextRenderPixel(PByte(ADestinationImage.Data) +
      NativeInt(DestinationY) * ADestinationImage.Stride +
      NativeInt(AEffectX + AUnitImage.Bounds.Left + ClipLeft) *
        SizeOf(TTextRenderPixel));
    for Column := ClipLeft to ClipRight - 1 do
    begin
      BlendStraightAlpha(Source^, Destination^);
      Inc(Source);
      Inc(Destination);
    end;
  end;
end;

procedure CompositeTextUnitPixelsPartial(const AUnitImage,
  ADestinationImage: TTextRenderImage; const AProgress: Double;
  const AEffectX, AEffectY, ABandTop, ABandBottom: Integer;
  const AClipToBand: Boolean);
begin
  CompositeTextUnitPixelsRange(AUnitImage, ADestinationImage, 0.0, AProgress,
    AEffectX, AEffectY, ABandTop, ABandBottom, AClipToBand);
end;

function IsAnimationSourcePixelVisible(const AImage: TTextRenderImage;
  const AX, AY: Integer; const AMode: TSerifDrawRevealMode;
  const ADirection: Integer; const AProgress: Double): Boolean;
var
  WorldX: Integer;
  WorldY: Integer;
begin
  if AMode = sdrmNone then
    Exit(True);
  if AProgress <= 0.0 then
    Exit(False);
  if AProgress >= 1.0 then
    Exit(True);
  WorldX := AX + AImage.Bounds.Left;
  WorldY := AY + AImage.Bounds.Top;
  case ADirection of
    SERIF_ANIMATION_DIRECTION_RIGHT:
      Result := WorldX >= AImage.LayoutBounds.Right -
        Round(AImage.LayoutBounds.Width * AProgress);
    SERIF_ANIMATION_DIRECTION_TOP:
      Result := WorldY < AImage.LayoutBounds.Top +
        Round(AImage.LayoutBounds.Height * AProgress);
    SERIF_ANIMATION_DIRECTION_BOTTOM:
      Result := WorldY >= AImage.LayoutBounds.Bottom -
        Round(AImage.LayoutBounds.Height * AProgress);
  else
    Result := WorldX < AImage.LayoutBounds.Left +
      Round(AImage.LayoutBounds.Width * AProgress);
  end;
end;

function SampleAnimationBlur(const AImage: TTextRenderImage;
  const AX, AY, ARadius: Integer): TTextRenderPixel;
var
  Count: Integer;
  DX: Integer;
  DY: Integer;
  Sample: PTextRenderPixel;
  SampleX: Integer;
  SampleY: Integer;
  SumA: Int64;
  SumB: Int64;
  SumG: Int64;
  SumR: Int64;
begin
  Result := System.Default(TTextRenderPixel);
  Count := 0;
  SumA := 0;
  SumR := 0;
  SumG := 0;
  SumB := 0;
  for DY := -1 to 1 do
    for DX := -1 to 1 do
    begin
      SampleX := AX + DX * ARadius;
      SampleY := AY + DY * ARadius;
      if (SampleX < 0) or (SampleX >= AImage.Width) or
        (SampleY < 0) or (SampleY >= AImage.Height) then
        Continue;
      Sample := PTextRenderPixel(PByte(AImage.Data) +
        NativeInt(SampleY) * AImage.Stride +
        NativeInt(SampleX) * SizeOf(TTextRenderPixel));
      Inc(Count);
      Inc(SumA, Sample^.A);
      Inc(SumR, Int64(Sample^.R) * Sample^.A);
      Inc(SumG, Int64(Sample^.G) * Sample^.A);
      Inc(SumB, Int64(Sample^.B) * Sample^.A);
    end;
  if (Count = 0) or (SumA = 0) then
    Exit;
  Result.A := EnsureRange(Round(SumA / Count), 0, 255);
  Result.R := EnsureRange(Round(SumR / SumA), 0, 255);
  Result.G := EnsureRange(Round(SumG / SumA), 0, 255);
  Result.B := EnsureRange(Round(SumB / SumA), 0, 255);
end;

constructor TSerifSkiaRender.Create;
begin
  inherited Create;
  FCache := TSerifRenderCache.Create([doOwnsValues]);
  FRoleNameItems := TObjectList<TSerifRoleNameRenderItem>.Create(True);
  FRenderer := TSkiaTextRenderer.Create;
  FSignature := '';
  FRoleSignature := '';
  SetEmptyImage;
end;

destructor TSerifSkiaRender.Destroy;
begin
  FRenderer.Free;
  FCache.Free;
  FRoleNameItems.Free;
  FImage.Free;
  inherited;
end;

procedure TSerifSkiaRender.RenderSnapshots(
  const ASnapshots: TArray<TSerifDrawSnapshot>;
  const ASettings: TSerifDrawSettings;
  const AParameters: TSerifDrawAnimationParameters);
var
  BandBottom: Integer;
  BandTop: Integer;
  BackingIndex: Integer;
  BackingRegions: TArray<TSerifSyncBackingRegion>;
  Combined: TTextRenderImage;
  CompositeMilliseconds: Double;
  CompositeStarted: Int64;
  DecorationEffectX: Integer;
  DecorationEffectY: Integer;
  DecorationImage: TTextRenderImage;
  DecorationImages: TObjectList<TTextRenderImage>;
  ActiveIdentities: TDictionary<string, Byte>;
  CacheEntry: TSerifRenderCacheEntry;
  CacheIdentity: string;
  CacheKeys: TArray<string>;
  CacheSignature: string;
  Cache: TSerifRenderCache;
  Column: Integer;
  Destination: PTextRenderPixel;
  DestinationY: Integer;
  EffectBounds: TRect;
  EffectRect: TRect;
  EffectX: Integer;
  EffectY: Integer;
  HasEffectBounds: Boolean;
  FrontRegions: TArray<TSerifSyncBackingRegion>;
  GlowBlurRadius: Double;
  GlowExtent: Double;
  GlowImage: TTextRenderImage;
  GlowImages: TObjectList<TTextRenderImage>;
  GlowItems: TArray<TSerifSyncTextGlowItem>;
  HighlightImage: TTextRenderImage;
  HighlightEffectX: Integer;
  HighlightEffectY: Integer;
  HighlightImages: TObjectList<TTextRenderImage>;
  I: Integer;
  Image: TTextRenderImage;
  Images: TObjectList<TTextRenderImage>;
  IndexPosition: Integer;
  InvisibleOutlines: TArray<TTextRenderOutline>;
  JumpItems: TArray<TSerifSyncJumpItem>;
  LayoutBounds: TRect;
  LayoutHeight: Integer;
  LayoutWidth: Integer;
  LayoutX: Integer;
  LayoutY: Integer;
  MarkerPixel: TTextRenderPixel;
  MarkerRect: TRect;
  MotionEffectX: Integer;
  MotionEffectY: Integer;
  MotionImage: TTextRenderImage;
  MotionImages: TObjectList<TTextRenderImage>;
  SpeechHighlightIndex: Integer;
  SpeechHighlightProgress: Double;
  SmoothFillProgress: Double;
  SmoothRangeEnd: Double;
  SmoothRangeStart: Double;
  TrailHighlightIndex: Integer;
  Metrics: TTextRenderMetrics;
  NewRenderCount: Integer;
  OutlineIndex: Integer;
  OutlineBlurPixels: Double;
  OutlineWidthPixels: Double;
  Renderer: TCustomTextRenderer;
  Request: TTextRenderRequest;
  SavedOutlines: TArray<TTextRenderOutline>;
  SavedShadows: TArray<TTextRenderShadow>;
  Row: Integer;
  Shadow: TTextRenderShadow;
  Style: TSerifDrawLayerStyle;
  Source: PTextRenderPixel;
  TextUnitImage: TTextRenderImage;
  TotalDrawMilliseconds: Double;
  TotalLayoutMilliseconds: Double;
  TotalRenderMilliseconds: Double;
  UnderlineRegions: TArray<TSerifSyncUnderlineRegion>;
  VisibleIndices: TArray<Integer>;
  ZoomItems: TArray<TSerifSyncZoomItem>;
begin
  if Length(ASnapshots) = 0 then
  begin
    TSerifRenderCache(FCache).Clear;
    SetEmptyImage;
    SerifDrawDebugLog('Serif display updated: active=0 image=1x1.');
    Exit;
  end;

  ActiveIdentities := TDictionary<string, Byte>.Create;
  Images := TObjectList<TTextRenderImage>.Create(False);
  MotionImages := TObjectList<TTextRenderImage>.Create(False);
  DecorationImages := TObjectList<TTextRenderImage>.Create(False);
  HighlightImages := TObjectList<TTextRenderImage>.Create(False);
  GlowImages := TObjectList<TTextRenderImage>.Create(False);
  Cache := TSerifRenderCache(FCache);
  Renderer := TCustomTextRenderer(FRenderer);
  try
    LayoutWidth := 0;
    LayoutHeight := 0;
    TotalLayoutMilliseconds := 0;
    TotalDrawMilliseconds := 0;
    TotalRenderMilliseconds := 0;
    NewRenderCount := 0;
    VisibleIndices := SelectSerifDrawVisibleSnapshotIndices(ASnapshots);
    for IndexPosition := 0 to High(VisibleIndices) do
    begin
      I := VisibleIndices[IndexPosition];
      CacheIdentity := BuildCacheIdentity(ASnapshots[I]);
      ActiveIdentities.AddOrSetValue(CacheIdentity, 0);
      CacheSignature := BuildCacheSignature(ASnapshots[I], ASettings,
        AParameters);
      if not Cache.TryGetValue(CacheIdentity, CacheEntry) then
      begin
        CacheEntry := TSerifRenderCacheEntry.Create;
        Cache.Add(CacheIdentity, CacheEntry);
      end;
      if (CacheEntry.Image = nil) or
        (CacheEntry.Signature <> CacheSignature) then
      begin
        Style := ASettings.ResolveStyle(ASnapshots[I].Layer,
          ASnapshots[I].Chara);
        Request := TTextRenderRequest.Default;
        Request.Text := ASnapshots[I].Serif;
        Request.CaptureTextUnits := AParameters.SyncKind in
          [SERIF_ANIMATION_SYNC_GLOW];
        Request.Alignment := TTextRenderAlignment(Style.Alignment);
        Request.FontFamilies := [Style.FontName, 'Yu Gothic UI', 'Meiryo UI',
          'Segoe UI'];
        Request.FontSize := Style.FontSize;
        Request.LetterSpacing := Style.LetterSpacing;
        Request.LineSpacing := Style.LineSpacing;
        Request.FontStyle := [];
        if (Style.FontStyles and SERIF_FONT_BOLD) <> 0 then
          Include(Request.FontStyle, TTextRenderFontStyleItem.Bold);
        if (Style.FontStyles and SERIF_FONT_ITALIC) <> 0 then
          Include(Request.FontStyle, TTextRenderFontStyleItem.Italic);
        Request.FillColor := Style.FillColor;
        // キャッシュ署名には比率を残し、ラスタライズ境界でpx換算と負荷上限を適用する。
        OutlineWidthPixels := SerifDrawOutlineWidthPixels(Style.OutlineWidth,
          Style.FontSize);
        OutlineBlurPixels := SerifDrawOutlineBlurPixels(Style.OutlineBlur,
          Style.FontSize);
        if not Style.OutlineEnabled then
          Request.Outlines := nil
        else if OutlineBlurPixels <= 0 then
          Request.Outlines := [TTextRenderOutline.Create(OutlineWidthPixels,
            Style.OutlineColor)]
        else if Style.BlurColor = Style.OutlineColor then
          Request.Outlines := [TTextRenderOutline.Create(OutlineWidthPixels,
            OutlineBlurPixels,
            Style.BlurColor)]
        else
          Request.Outlines := [
            TTextRenderOutline.Create(OutlineWidthPixels, OutlineBlurPixels,
              Style.BlurColor),
            TTextRenderOutline.Create(OutlineWidthPixels,
              Style.OutlineColor)];
        if Style.ShadowEnabled then
        begin
          Shadow := System.Default(TTextRenderShadow);
          Shadow.Offset := PointF(
            SerifDrawShadowOffsetPixels(Style.ShadowOffsetX,
              Style.FontSize),
            SerifDrawShadowOffsetPixels(Style.ShadowOffsetY,
              Style.FontSize));
          Shadow.BlurRadius := SerifDrawShadowBlurPixels(Style.ShadowBlur,
            Style.FontSize);
          Shadow.SpreadRadius := SerifDrawShadowSpreadPixels(
            Style.ShadowSpread, Style.FontSize);
          Shadow.Color := Style.ShadowColor;
          Request.Shadows := [Shadow];
        end;
        Image := Renderer.Render(Request, Metrics);
        TotalLayoutMilliseconds := TotalLayoutMilliseconds +
          Metrics.LayoutMilliseconds;
        TotalDrawMilliseconds := TotalDrawMilliseconds +
          Metrics.DrawMilliseconds;
        TotalRenderMilliseconds := TotalRenderMilliseconds +
          Metrics.TotalMilliseconds;
        CacheEntry.Image.Free;
        CacheEntry.Image := Image;
        CacheEntry.MotionImage.Free;
        CacheEntry.MotionImage := nil;
        CacheEntry.DecorationImage.Free;
        CacheEntry.DecorationImage := nil;
        CacheEntry.SyncImage.Free;
        CacheEntry.SyncImage := nil;
        CacheEntry.GlowImage.Free;
        CacheEntry.GlowImage := nil;
        if AParameters.SyncKind in [SERIF_ANIMATION_SYNC_FRONT,
          SERIF_ANIMATION_SYNC_BACKING, SERIF_ANIMATION_SYNC_UNDERLINE,
          SERIF_ANIMATION_SYNC_ZOOM, SERIF_ANIMATION_SYNC_JUMP] then
        begin
          // 影を含む文字単位画像は非常に大きくなるため、動く本文と
          // 静止した影を分離する。毎フレーム変形するのは小さい本文だけ。
          SavedOutlines := Request.Outlines;
          SavedShadows := Request.Shadows;
          Request.Shadows := nil;
          Request.CaptureTextUnits := True;
          CacheEntry.MotionImage := Renderer.Render(Request, Metrics);
          TotalLayoutMilliseconds := TotalLayoutMilliseconds +
            Metrics.LayoutMilliseconds;
          TotalDrawMilliseconds := TotalDrawMilliseconds +
            Metrics.DrawMilliseconds;
          TotalRenderMilliseconds := TotalRenderMilliseconds +
            Metrics.TotalMilliseconds;
          if (AParameters.SyncKind in [SERIF_ANIMATION_SYNC_ZOOM,
            SERIF_ANIMATION_SYNC_JUMP]) and
            (Length(SavedShadows) > 0) then
          begin
            Request.FillColor := TAlphaColorRec.Null;
            SetLength(InvisibleOutlines, Length(SavedOutlines));
            for OutlineIndex := 0 to High(SavedOutlines) do
            begin
              InvisibleOutlines[OutlineIndex] := SavedOutlines[OutlineIndex];
              InvisibleOutlines[OutlineIndex].Color := TAlphaColorRec.Null;
            end;
            Request.Outlines := InvisibleOutlines;
            Request.Shadows := SavedShadows;
            Request.CaptureTextUnits := False;
            CacheEntry.DecorationImage := Renderer.Render(Request, Metrics);
            TotalLayoutMilliseconds := TotalLayoutMilliseconds +
              Metrics.LayoutMilliseconds;
            TotalDrawMilliseconds := TotalDrawMilliseconds +
              Metrics.DrawMilliseconds;
            TotalRenderMilliseconds := TotalRenderMilliseconds +
              Metrics.TotalMilliseconds;
          end;
          Request.FillColor := Style.FillColor;
          Request.Outlines := SavedOutlines;
          Request.Shadows := SavedShadows;
        end;
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_SPEECH_COLOR then
        begin
          // 同期色は本文だけを小さな文字単位画像にする。影と縁取りは
          // 完成済みの通常画像を一度転送し、毎フレーム再合成しない。
          Request.FillColor := AParameters.SyncColor;
          // 縁取りを削除すると行幅と中央揃え位置まで変わる。幅とぼかしは
          // 残して透明色にし、通常画像と完全に同じグリフ座標を維持する。
          SetLength(InvisibleOutlines, Length(Request.Outlines));
          for OutlineIndex := 0 to High(Request.Outlines) do
          begin
            InvisibleOutlines[OutlineIndex] := Request.Outlines[OutlineIndex];
            InvisibleOutlines[OutlineIndex].Color := TAlphaColorRec.Null;
          end;
          Request.Outlines := InvisibleOutlines;
          Request.Shadows := nil;
          Request.CaptureTextUnits := True;
          CacheEntry.SyncImage := Renderer.Render(Request, Metrics);
          TotalLayoutMilliseconds := TotalLayoutMilliseconds +
            Metrics.LayoutMilliseconds;
          TotalDrawMilliseconds := TotalDrawMilliseconds +
            Metrics.DrawMilliseconds;
          TotalRenderMilliseconds := TotalRenderMilliseconds +
            Metrics.TotalMilliseconds;
        end;
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_GLOW then
        begin
          // ぼかし範囲は文字サイズ基準で固定し、同期サイズは合成時の光量に使う。
          GlowExtent := Style.FontSize * 0.15;
          GlowBlurRadius := Max(1.0, GlowExtent / 2.0);
          Request.FillColor := TAlphaColorRec.Null;
          Request.Outlines := [TTextRenderOutline.Create(
            Max(1.0, Style.OutlineWidth), GlowBlurRadius,
            AParameters.SyncColor)];
          Request.Shadows := nil;
          CacheEntry.GlowImage := Renderer.Render(Request, Metrics);
          TotalLayoutMilliseconds := TotalLayoutMilliseconds +
            Metrics.LayoutMilliseconds;
          TotalDrawMilliseconds := TotalDrawMilliseconds +
            Metrics.DrawMilliseconds;
          TotalRenderMilliseconds := TotalRenderMilliseconds +
            Metrics.TotalMilliseconds;
        end;
        CacheEntry.Signature := CacheSignature;
        Inc(NewRenderCount);
      end;
      Image := CacheEntry.Image;
      Images.Add(Image);
      MotionImages.Add(CacheEntry.MotionImage);
      DecorationImages.Add(CacheEntry.DecorationImage);
      HighlightImages.Add(CacheEntry.SyncImage);
      GlowImages.Add(CacheEntry.GlowImage);
      if Image.LayoutBounds.Width > LayoutWidth then
        LayoutWidth := Image.LayoutBounds.Width;
      if Image.LayoutBounds.Height > LayoutHeight then
        LayoutHeight := Image.LayoutBounds.Height;
    end;

    CompositeStarted := SerifDrawTimerStart;
    HasEffectBounds := False;
    for I := 0 to Images.Count - 1 do
    begin
      Image := Images[I];
      LayoutX := (LayoutWidth - Image.LayoutBounds.Width) div 2;
      LayoutY := (LayoutHeight - Image.LayoutBounds.Height) div 2;
      EffectX := LayoutX + Image.Bounds.Left - Image.LayoutBounds.Left;
      EffectY := LayoutY + Image.Bounds.Top - Image.LayoutBounds.Top;
      EffectRect := TRect.Create(EffectX, EffectY,
        EffectX + Image.Width, EffectY + Image.Height);
      MotionImage := MotionImages[I];
      if MotionImage <> nil then
      begin
        MotionEffectX := LayoutX + MotionImage.Bounds.Left -
          MotionImage.LayoutBounds.Left;
        MotionEffectY := LayoutY + MotionImage.Bounds.Top -
          MotionImage.LayoutBounds.Top;
      end
      else
      begin
        MotionEffectX := EffectX;
        MotionEffectY := EffectY;
      end;
      if AParameters.SyncKind = SERIF_ANIMATION_SYNC_BACKING then
      begin
        BackingRegions := CalculateSerifSyncBackingRegions(
          MotionImage.LineLayoutBounds, MotionImage.TextUnitBounds,
          MotionImage.LayoutBounds, MotionImage.Bounds,
          ASnapshots[VisibleIndices[I]].TimelineFrame,
          ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
          AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
          AParameters.SyncPaintMode,
          AParameters.SyncSize, AParameters.SyncOffsetX,
          AParameters.SyncOffsetY);
        for BackingIndex := 0 to High(BackingRegions) do
        begin
          MarkerRect := BackingRegions[BackingIndex].Bounds;
          MarkerRect.Offset(MotionEffectX, MotionEffectY);
          if not MarkerRect.IsEmpty then
            EffectRect := TRect.Union(EffectRect, MarkerRect);
        end;
      end;
      if AParameters.SyncKind = SERIF_ANIMATION_SYNC_UNDERLINE then
      begin
        UnderlineRegions := CalculateSerifSyncUnderlineRegions(
          MotionImage.LineLayoutBounds, MotionImage.TextUnitBounds,
          MotionImage.LayoutBounds, MotionImage.Bounds,
          ASnapshots[VisibleIndices[I]].TimelineFrame,
          ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
          AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
          AParameters.SyncPaintMode,
          AParameters.SyncSize, AParameters.SyncOffsetX,
          AParameters.SyncOffsetY);
        ExpandSerifSyncUnderlineBounds(EffectRect, UnderlineRegions,
          MotionEffectX, MotionEffectY);
      end;
      if AParameters.SyncKind = SERIF_ANIMATION_SYNC_ZOOM then
      begin
        if AParameters.SyncPaintMode = SERIF_ANIMATION_SYNC_PAINT_SMOOTH then
          ExpandSerifSyncSmoothZoomBounds(EffectRect, MotionImage,
            AParameters.SyncSize, AParameters.SyncOffsetX,
            AParameters.SyncOffsetY)
        else
        begin
          ZoomItems := CalculateSerifSyncZoomItems(MotionImage.TextUnitImages,
            ASnapshots[VisibleIndices[I]].TimelineFrame,
            ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
            AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
            AParameters.SyncPaintMode,
            AParameters.SyncSize, AParameters.SyncOffsetX,
            AParameters.SyncOffsetY);
          ExpandSerifSyncZoomBounds(EffectRect, ZoomItems, MotionEffectX,
            MotionEffectY);
        end;
      end;
      if AParameters.SyncKind = SERIF_ANIMATION_SYNC_JUMP then
      begin
        if AParameters.SyncPaintMode = SERIF_ANIMATION_SYNC_PAINT_SMOOTH then
          ExpandSerifSyncSmoothJumpBounds(EffectRect, MotionImage,
            AParameters.SyncSize, AParameters.SyncOffsetY)
        else
        begin
          JumpItems := CalculateSerifSyncJumpItems(MotionImage.TextUnitImages,
            ASnapshots[VisibleIndices[I]].TimelineFrame,
            ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
            AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
            AParameters.SyncPaintMode,
            AParameters.SyncSize, AParameters.SyncOffsetX,
            AParameters.SyncOffsetY);
          ExpandSerifSyncJumpBounds(EffectRect, JumpItems, MotionEffectX,
            MotionEffectY);
        end;
      end;
      if AParameters.SyncKind = SERIF_ANIMATION_SYNC_FRONT then
      begin
        FrontRegions := CalculateSerifSyncFrontRegions(
          MotionImage.LineLayoutBounds, MotionImage.TextUnitBounds,
          MotionImage.LayoutBounds, MotionImage.Bounds,
          ASnapshots[VisibleIndices[I]].TimelineFrame,
          ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
          AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
          AParameters.SyncPaintMode,
          AParameters.SyncSize, AParameters.SyncOffsetX,
          AParameters.SyncOffsetY);
        ExpandSerifSyncFrontBounds(EffectRect, FrontRegions, MotionEffectX,
          MotionEffectY);
      end;
      if AParameters.SyncKind = SERIF_ANIMATION_SYNC_GLOW then
      begin
        GlowImage := GlowImages[I];
        GlowItems := CalculateSerifSyncTextGlowItems(Image, GlowImage,
          ASnapshots[VisibleIndices[I]].TimelineFrame,
          ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
          AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
          AParameters.SyncPaintMode,
          AParameters.SyncSize, AParameters.SyncOffsetX,
          AParameters.SyncOffsetY);
        ExpandSerifSyncTextGlowBounds(EffectRect, GlowItems, EffectX,
          EffectY);
      end;
      if not HasEffectBounds then
      begin
        EffectBounds := EffectRect;
        HasEffectBounds := True;
      end
      else
        EffectBounds := TRect.Union(EffectBounds, EffectRect);
    end;
    LayoutBounds := TRect.Create(0, 0, LayoutWidth, LayoutHeight);
    Combined := TTextRenderImage.Create(EffectBounds, LayoutBounds);
    try
      Combined.Clear;
      for I := 0 to Images.Count - 1 do
      begin
        Image := Images[I];
        LayoutX := (LayoutWidth - Image.LayoutBounds.Width) div 2;
        LayoutY := (LayoutHeight - Image.LayoutBounds.Height) div 2;
        EffectX := LayoutX + Image.Bounds.Left - Image.LayoutBounds.Left -
          EffectBounds.Left;
        EffectY := LayoutY + Image.Bounds.Top - Image.LayoutBounds.Top -
          EffectBounds.Top;
        SerifDrawSplitBand(Combined.Height, I, Images.Count,
          BandTop, BandBottom);
        MotionImage := MotionImages[I];
        if MotionImage <> nil then
        begin
          MotionEffectX := LayoutX + MotionImage.Bounds.Left -
            MotionImage.LayoutBounds.Left - EffectBounds.Left;
          MotionEffectY := LayoutY + MotionImage.Bounds.Top -
            MotionImage.LayoutBounds.Top - EffectBounds.Top;
        end
        else
        begin
          MotionEffectX := EffectX;
          MotionEffectY := EffectY;
        end;
        if AParameters.SyncKind in [SERIF_ANIMATION_SYNC_ZOOM,
          SERIF_ANIMATION_SYNC_JUMP] then
        begin
          DecorationImage := DecorationImages[I];
          if DecorationImage <> nil then
          begin
            DecorationEffectX := LayoutX + DecorationImage.Bounds.Left -
              DecorationImage.LayoutBounds.Left - EffectBounds.Left;
            DecorationEffectY := LayoutY + DecorationImage.Bounds.Top -
              DecorationImage.LayoutBounds.Top - EffectBounds.Top;
            // この帯は空なので、静止した影一枚は画素合成せず転送する。
            CopyImagePixels(DecorationImage, Combined, DecorationEffectX,
              DecorationEffectY, BandTop, BandBottom, Images.Count > 1);
          end;
        end;
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_BACKING then
        begin
          BackingRegions := CalculateSerifSyncBackingRegions(
            MotionImage.LineLayoutBounds, MotionImage.TextUnitBounds,
            MotionImage.LayoutBounds, MotionImage.Bounds,
            ASnapshots[VisibleIndices[I]].TimelineFrame,
            ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
            AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
            AParameters.SyncPaintMode,
            AParameters.SyncSize, AParameters.SyncOffsetX,
            AParameters.SyncOffsetY);
          MarkerPixel.A := SERIF_SYNC_BACKING_ALPHA;
          MarkerPixel.R := Byte((AParameters.SyncColor shr 16) and $FF);
          MarkerPixel.G := Byte((AParameters.SyncColor shr 8) and $FF);
          MarkerPixel.B := Byte(AParameters.SyncColor and $FF);
          for BackingIndex := 0 to High(BackingRegions) do
          begin
            MarkerRect := BackingRegions[BackingIndex].Bounds;
            for Row := MarkerRect.Top to MarkerRect.Bottom - 1 do
            begin
              DestinationY := MotionEffectY + Row;
              if (DestinationY < 0) or (DestinationY >= Combined.Height) or
                ((Images.Count > 1) and ((DestinationY < BandTop) or
                  (DestinationY >= BandBottom))) then
                Continue;
              Destination := PTextRenderPixel(PByte(Combined.Data) +
                NativeInt(DestinationY) * Combined.Stride +
                NativeInt(MotionEffectX + MarkerRect.Left) *
                  SizeOf(TTextRenderPixel));
              for Column := MarkerRect.Left to MarkerRect.Right - 1 do
              begin
                if IsSerifSyncBackingPixelVisible(
                  BackingRegions[BackingIndex], Column, Row,
                  AParameters.SyncShape) then
                  BlendStraightAlpha(MarkerPixel, Destination^);
                Inc(Destination);
              end;
            end;
          end;
        end;
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_UNDERLINE then
        begin
          UnderlineRegions := CalculateSerifSyncUnderlineRegions(
            MotionImage.LineLayoutBounds, MotionImage.TextUnitBounds,
            MotionImage.LayoutBounds, MotionImage.Bounds,
            ASnapshots[VisibleIndices[I]].TimelineFrame,
            ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
            AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
            AParameters.SyncPaintMode,
            AParameters.SyncSize, AParameters.SyncOffsetX,
            AParameters.SyncOffsetY);
          CompositeSerifSyncUnderline(UnderlineRegions,
            AParameters.SyncShape, Integer(AParameters.SyncColor),
            MotionEffectX, MotionEffectY, BandTop, BandBottom,
            Images.Count > 1, Combined);
        end;
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_ZOOM then
          if AParameters.SyncPaintMode = SERIF_ANIMATION_SYNC_PAINT_SMOOTH then
            ZoomItems := nil
          else
            ZoomItems := CalculateSerifSyncZoomItems(
              MotionImage.TextUnitImages,
              ASnapshots[VisibleIndices[I]].TimelineFrame,
              ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
              AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
              AParameters.SyncPaintMode,
              AParameters.SyncSize, AParameters.SyncOffsetX,
              AParameters.SyncOffsetY);
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_JUMP then
          if AParameters.SyncPaintMode = SERIF_ANIMATION_SYNC_PAINT_SMOOTH then
            JumpItems := nil
          else
            JumpItems := CalculateSerifSyncJumpItems(
              MotionImage.TextUnitImages,
              ASnapshots[VisibleIndices[I]].TimelineFrame,
              ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
              AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
              AParameters.SyncPaintMode,
              AParameters.SyncSize, AParameters.SyncOffsetX,
              AParameters.SyncOffsetY);
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_FRONT then
          FrontRegions := CalculateSerifSyncFrontRegions(
            MotionImage.LineLayoutBounds, MotionImage.TextUnitBounds,
            MotionImage.LayoutBounds, MotionImage.Bounds,
            ASnapshots[VisibleIndices[I]].TimelineFrame,
            ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
            AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
            AParameters.SyncPaintMode,
            AParameters.SyncSize, AParameters.SyncOffsetX,
            AParameters.SyncOffsetY);
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_GLOW then
        begin
          GlowImage := GlowImages[I];
          GlowItems := CalculateSerifSyncTextGlowItems(Image, GlowImage,
            ASnapshots[VisibleIndices[I]].TimelineFrame,
            ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
            AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
            AParameters.SyncPaintMode,
            AParameters.SyncSize, AParameters.SyncOffsetX,
            AParameters.SyncOffsetY);
        end;
        HighlightImage := HighlightImages[I];
        if HighlightImage <> nil then
        begin
          HighlightEffectX := LayoutX + HighlightImage.Bounds.Left -
            HighlightImage.LayoutBounds.Left - EffectBounds.Left;
          HighlightEffectY := LayoutY + HighlightImage.Bounds.Top -
            HighlightImage.LayoutBounds.Top - EffectBounds.Top;
        end
        else
        begin
          HighlightEffectX := EffectX;
          HighlightEffectY := EffectY;
        end;
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_SPEECH_COLOR then
          CopyImagePixels(Image, Combined, EffectX, EffectY, BandTop,
            BandBottom, Images.Count > 1);
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_ZOOM then
        begin
          if AParameters.SyncPaintMode = SERIF_ANIMATION_SYNC_PAINT_SMOOTH then
            CompositeSerifSyncSmoothZoom(MotionImage,
              MotionImage.LineLayoutBounds,
              ASnapshots[VisibleIndices[I]].TimelineFrame,
              ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
              AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
              AParameters.SyncSize, AParameters.SyncOffsetX,
              AParameters.SyncOffsetY, Combined, MotionEffectX,
              MotionEffectY,
              BandTop, BandBottom, Images.Count > 1)
          else
            CompositeSerifSyncZoom(ZoomItems, Combined, MotionEffectX,
              MotionEffectY,
              BandTop, BandBottom, Images.Count > 1);
        end
        else if AParameters.SyncKind = SERIF_ANIMATION_SYNC_JUMP then
        begin
          if AParameters.SyncPaintMode = SERIF_ANIMATION_SYNC_PAINT_SMOOTH then
            CompositeSerifSyncSmoothJump(MotionImage,
              MotionImage.LineLayoutBounds,
              ASnapshots[VisibleIndices[I]].TimelineFrame,
              ASnapshots[VisibleIndices[I]].TimelineTotalFrames,
              AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL,
              AParameters.SyncSize, AParameters.SyncOffsetX,
              AParameters.SyncOffsetY, Combined, MotionEffectX,
              MotionEffectY,
              BandTop, BandBottom, Images.Count > 1)
          else
            CompositeSerifSyncJump(JumpItems, Combined, MotionEffectX,
              MotionEffectY,
              BandTop, BandBottom, Images.Count > 1);
        end
        else if AParameters.SyncKind = SERIF_ANIMATION_SYNC_SPEECH_COLOR then
        begin
          SpeechHighlightIndex := -1;
          SpeechHighlightProgress := 0.0;
          if (HighlightImage <> nil) and
            (ASnapshots[VisibleIndices[I]].SpeechActive or
             ASnapshots[VisibleIndices[I]].HoldSpeechSync or
             (AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL)) then
            CalculateSerifSyncHighlightPosition(
              Length(HighlightImage.TextUnitImages),
              ASnapshots[VisibleIndices[I]].SpeechProgress,
              SpeechHighlightIndex, SpeechHighlightProgress);
          if HighlightImage <> nil then
          for TrailHighlightIndex := 0 to
            High(HighlightImage.TextUnitImages) do
          begin
            TextUnitImage :=
              HighlightImage.TextUnitImages[TrailHighlightIndex];
            if AParameters.SyncPaintMode =
              SERIF_ANIMATION_SYNC_PAINT_SMOOTH then
            begin
              if (SpeechHighlightIndex >= 0) and
                (TrailHighlightIndex < Length(HighlightImage.TextUnitImages)) then
              begin
                if (AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL) and
                  (TrailHighlightIndex < SpeechHighlightIndex) then
                  CompositeTextUnitPixels(TextUnitImage, Combined,
                    HighlightEffectX, HighlightEffectY, BandTop, BandBottom,
                    Images.Count > 1)
                else if (AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL) and
                  (TrailHighlightIndex = SpeechHighlightIndex) then
                begin
                  SmoothFillProgress := CalculateSerifSyncSmoothFillProgress(
                    SpeechHighlightProgress, AParameters.SyncSize);
                  CompositeTextUnitPixelsPartial(TextUnitImage, Combined,
                    SmoothFillProgress, HighlightEffectX, HighlightEffectY,
                    BandTop,
                    BandBottom, Images.Count > 1);
                end
                else if AParameters.SyncMode <> SERIF_ANIMATION_SYNC_MODE_TRAIL then
                begin
                  CalculateSerifSyncSmoothWindow(SpeechHighlightIndex,
                    SpeechHighlightProgress, AParameters.SyncSize,
                    SmoothRangeStart, SmoothRangeEnd);
                  CompositeTextUnitPixelsRange(TextUnitImage, Combined,
                    SmoothRangeStart - TrailHighlightIndex,
                    SmoothRangeEnd - TrailHighlightIndex, HighlightEffectX,
                    HighlightEffectY, BandTop, BandBottom,
                    Images.Count > 1);
                end;
              end;
            end
            else
            begin
              if (SpeechHighlightIndex >= 0) and
                ((AParameters.SyncMode = SERIF_ANIMATION_SYNC_MODE_TRAIL) and
                 (TrailHighlightIndex <= SpeechHighlightIndex) or
                 (AParameters.SyncMode <> SERIF_ANIMATION_SYNC_MODE_TRAIL) and
                 (TrailHighlightIndex = SpeechHighlightIndex)) and
                (TrailHighlightIndex < Length(HighlightImage.TextUnitImages)) then
                CompositeTextUnitPixels(TextUnitImage, Combined,
                  HighlightEffectX, HighlightEffectY, BandTop, BandBottom,
                  Images.Count > 1);
            end;
          end;
        end
        else
        begin
          if AParameters.SyncKind in [SERIF_ANIMATION_SYNC_BACKING,
            SERIF_ANIMATION_SYNC_UNDERLINE] then
          begin
            // 背面要素が先に描かれている場合だけアルファ合成が必要。
            for Row := 0 to Image.Height - 1 do
            begin
              DestinationY := EffectY + Row;
              if (Images.Count > 1) and
                ((DestinationY < BandTop) or
                 (DestinationY >= BandBottom)) then
                Continue;
              Source := PTextRenderPixel(PByte(Image.Data) +
                NativeInt(Row) * Image.Stride);
              Destination := PTextRenderPixel(PByte(Combined.Data) +
                NativeInt(DestinationY) * Combined.Stride +
                NativeInt(EffectX) * SizeOf(TTextRenderPixel));
              for Column := 0 to Image.Width - 1 do
              begin
                BlendStraightAlpha(Source^, Destination^);
                Inc(Source);
                Inc(Destination);
              end;
            end;
          end
          else
            // 空の帯へ描く通常文字は行単位コピーで済ませる。
            CopyImagePixels(Image, Combined, EffectX, EffectY, BandTop,
              BandBottom, Images.Count > 1);
        end;
        // 前面ライトはスクリーン色を、発光はぼかし輪郭を文字表面へ重ねる。
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_FRONT then
          CompositeSerifSyncFront(FrontRegions, AParameters.SyncShape,
            Integer(AParameters.SyncColor), MotionEffectX, MotionEffectY,
            BandTop, BandBottom, Images.Count > 1, Combined);
        if AParameters.SyncKind = SERIF_ANIMATION_SYNC_GLOW then
          CompositeSerifSyncTextGlow(GlowItems, Combined, EffectX, EffectY,
            BandTop, BandBottom, Images.Count > 1);

      end;
      CompositeMilliseconds :=
        SerifDrawTimerElapsedMilliseconds(CompositeStarted);
      FreeAndNil(FImage);
      FImage := Combined;
      Combined := nil;
    finally
      Combined.Free;
    end;

    CacheKeys := Cache.Keys.ToArray;
    for CacheIdentity in CacheKeys do
      if not ActiveIdentities.ContainsKey(CacheIdentity) then
        Cache.Remove(CacheIdentity);

    SerifDrawDebugLog(Format(
      'Serif display updated: active=%d visible=%d rendered=%d reused=%d ' +
      'image=%dx%d bytes=%d ms(layout=%.3f draw=%.3f renderTotal=%.3f composite=%.3f).',
      [Length(ASnapshots), Images.Count, NewRenderCount,
       Images.Count - NewRenderCount, FImage.Width, FImage.Height,
       FImage.Stride * FImage.Height, TotalLayoutMilliseconds,
       TotalDrawMilliseconds, TotalRenderMilliseconds,
       CompositeMilliseconds]));
  finally
    GlowImages.Free;
    HighlightImages.Free;
    DecorationImages.Free;
    MotionImages.Free;
    Images.Free;
    ActiveIdentities.Free;
  end;
end;

procedure TSerifSkiaRender.RenderRoleNames(
  const ASnapshots: TArray<TSerifDrawSnapshot>;
  const ASettings: TSerifDrawSettings);
var
  I: Integer;
  Item: TSerifRoleNameRenderItem;
  Metrics: TTextRenderMetrics;
  OutlineBlurPixels: Double;
  OutlineWidthPixels: Double;
  Request: TTextRenderRequest;
  RoleName: string;
  Shadow: TTextRenderShadow;
  Style: TSerifDrawLayerStyle;
  TotalMilliseconds: Double;
  VisibleIndices: TArray<Integer>;
begin
  TObjectList<TSerifRoleNameRenderItem>(FRoleNameItems).Clear;
  if not ASettings.RoleNameVisible or (Length(ASnapshots) = 0) then
    Exit;
  TotalMilliseconds := 0;
  VisibleIndices := SelectSerifDrawVisibleSnapshotIndices(ASnapshots);
  if Length(VisibleIndices) = 0 then
    Exit;
  // 複数配役の特殊表示では、個別名を並べず最新配役のスタイルで人数を1件表示する。
  I := VisibleIndices[High(VisibleIndices)];
  RoleName := SerifDrawRoleNameDisplayText(Length(VisibleIndices),
    ASnapshots[I].Chara);
  if SerifDrawRoleNameKey(RoleName) = '' then
    Exit;
  Style := ASettings.ResolveRoleNameStyle(ASnapshots[I].Layer,
    ASnapshots[I].Chara);
  Item := TSerifRoleNameRenderItem.Create;
  try
    Item.Layout.Layer := ASnapshots[I].Layer;
    Item.Layout.Placement := ASettings.RoleNamePlacement;
    Item.Layout.PositionX := ASettings.RoleNamePositionX;
    Item.Layout.PositionY := ASettings.RoleNamePositionY;
    Request := TTextRenderRequest.Default;
    Request.Text := RoleName;
    Request.Alignment := TTextRenderAlignment(Item.Layout.Placement mod 3);
    Request.FontFamilies := [Style.FontName, 'Yu Gothic UI', 'Meiryo UI',
      'Segoe UI'];
    Request.FontSize := Style.FontSize;
    Request.LetterSpacing := Style.LetterSpacing;
    Request.LineSpacing := Style.LineSpacing;
    Request.FontStyle := [];
    if (Style.FontStyles and SERIF_FONT_BOLD) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.Bold);
    if (Style.FontStyles and SERIF_FONT_ITALIC) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.Italic);
    Request.FillColor := Style.FillColor;
    // 配役名も本文と同じ換算規則を通し、大きな文字で描画負荷が突出するのを防ぐ。
    OutlineWidthPixels := SerifDrawOutlineWidthPixels(Style.OutlineWidth,
      Style.FontSize);
    OutlineBlurPixels := SerifDrawOutlineBlurPixels(Style.OutlineBlur,
      Style.FontSize);
    if not Style.OutlineEnabled then
      Request.Outlines := nil
    else if OutlineBlurPixels <= 0 then
      Request.Outlines := [TTextRenderOutline.Create(OutlineWidthPixels,
        Style.OutlineColor)]
    else if Style.BlurColor = Style.OutlineColor then
      Request.Outlines := [TTextRenderOutline.Create(OutlineWidthPixels,
        OutlineBlurPixels,
        Style.BlurColor)]
    else
      Request.Outlines := [
        TTextRenderOutline.Create(OutlineWidthPixels, OutlineBlurPixels,
          Style.BlurColor),
        TTextRenderOutline.Create(OutlineWidthPixels,
          Style.OutlineColor)];
    if Style.ShadowEnabled then
    begin
      Shadow := System.Default(TTextRenderShadow);
      Shadow.Offset := PointF(
        SerifDrawShadowOffsetPixels(Style.ShadowOffsetX, Style.FontSize),
        SerifDrawShadowOffsetPixels(Style.ShadowOffsetY, Style.FontSize));
      Shadow.BlurRadius := SerifDrawShadowBlurPixels(Style.ShadowBlur,
        Style.FontSize);
      Shadow.SpreadRadius := SerifDrawShadowSpreadPixels(
        Style.ShadowSpread, Style.FontSize);
      Shadow.Color := Style.ShadowColor;
      Request.Shadows := [Shadow];
    end;
    Item.Image := TCustomTextRenderer(FRenderer).Render(Request, Metrics);
    TotalMilliseconds := TotalMilliseconds + Metrics.TotalMilliseconds;
    TObjectList<TSerifRoleNameRenderItem>(FRoleNameItems).Add(Item);
    Item := nil;
  finally
    Item.Free;
  end;
  SerifDrawDebugLog(Format(
    'Role name display updated: active=%d visible=%d elapsed=%.3fms.',
    [Length(ASnapshots),
     TObjectList<TSerifRoleNameRenderItem>(FRoleNameItems).Count,
     TotalMilliseconds]));
end;

{ TSerifRenderCacheEntry }

destructor TSerifRenderCacheEntry.Destroy;
begin
  DecorationImage.Free;
  GlowImage.Free;
  MotionImage.Free;
  SyncImage.Free;
  Image.Free;
  inherited;
end;

procedure TSerifSkiaRender.SendToAviUtl2(Video: PFILTER_PROC_VIDEO;
  const ATransform: TSerifDrawAnimationTransform);
{$IFDEF DEBUG}
var
  ElapsedMilliseconds: Double;
  SampleIndex: Integer;
  Started: Int64;
{$ENDIF}
begin
  if (Video = nil) or not Assigned(Video^.SetImageData) or
    (FImage = nil) or FImage.IsEmpty then
    Exit;
  if TrySendComposited(Video, ATransform) then
    Exit;
{$IFDEF DEBUG}
  Started := SerifDrawTimerStart;
{$ENDIF}
  Video^.SetImageData(PPIXEL_RGBA(FImage.Data), FImage.Width, FImage.Height);
{$IFDEF DEBUG}
  ElapsedMilliseconds := SerifDrawTimerElapsedMilliseconds(Started);
  SampleIndex := InterlockedIncrement(FSendLogCount);
  if SampleIndex <= 20 then
    SerifDrawDebugLog(Format(
      'SetImageData (shared Skia): sample=%d image=%dx%d bytes=%d elapsed=%.3f ms.',
      [SampleIndex, FImage.Width, FImage.Height,
       FImage.Stride * FImage.Height, ElapsedMilliseconds]));
{$ENDIF}
end;

procedure TSerifSkiaRender.BlendImageToComposite(
  const AImage: TTextRenderImage; const AWidth, AHeight: Integer;
  const APlacement: Byte; const APositionX, APositionY: Double;
  const ATransform: TSerifDrawAnimationTransform);
var
  AdjustedSource: TTextRenderPixel;
  Anchor: TPointF;
  Alpha: Double;
  AngleRadians: Double;
  CornerX: array[0..3] of Double;
  CornerY: array[0..3] of Double;
  CosAngle: Double;
  DeltaX: Double;
  DeltaY: Double;
  DestinationAnchorX: Double;
  DestinationAnchorY: Double;
  Destination: PTextRenderPixel;
  DestinationBottom: Integer;
  DestinationLeft: Integer;
  DestinationRight: Integer;
  DestinationTop: Integer;
  DestinationX: Integer;
  DestinationY: Integer;
  BlurRadius: Integer;
  I: Integer;
  PixelCount: Integer;
  RotatedX: Double;
  RotatedY: Double;
  ScaleX: Double;
  ScaleY: Double;
  SinAngle: Double;
  Source: PTextRenderPixel;
  SourceColumn: Integer;
  SourceRow: Integer;
begin
  Alpha := EnsureRange(ATransform.Alpha, 0.0, 1.0);
  if not ATransform.Visible or (Alpha <= 0.0) or (AImage = nil) or
    AImage.IsEmpty or (Length(FCompositePixels) = 0) then
    Exit;
  Anchor := SerifDrawPlacementAnchor(APlacement, AImage.Bounds,
    AImage.LayoutBounds);
  ScaleX := EnsureRange(ATransform.ScaleX, 0.01, 100.0);
  ScaleY := EnsureRange(ATransform.ScaleY, 0.01, 100.0);
  BlurRadius := Max(0, Round(ATransform.BlurRadius));
  AngleRadians := DegToRad(ATransform.RotationDegrees);
  CosAngle := Cos(AngleRadians);
  SinAngle := Sin(AngleRadians);
  DestinationAnchorX := AWidth * 0.5 + APositionX + ATransform.OffsetX;
  DestinationAnchorY := AHeight * 0.5 + APositionY + ATransform.OffsetY;
  if SameValue(ScaleX, 1.0) and SameValue(ScaleY, 1.0) and
    SameValue(ATransform.RotationDegrees, 0.0) and (BlurRadius = 0) and
    (ATransform.RevealMode = sdrmNone) then
  begin
    // 無変形時は出力画素ごとの回転・拡縮逆変換を避ける。
    DestinationLeft := Floor(DestinationAnchorX - Anchor.X);
    DestinationTop := Floor(DestinationAnchorY - Anchor.Y);
    DestinationRight := Ceil(DestinationAnchorX + AImage.Width - Anchor.X);
    DestinationBottom := Ceil(DestinationAnchorY + AImage.Height - Anchor.Y);
    for DestinationY := Max(0, DestinationTop) to
      Min(AHeight, DestinationBottom) - 1 do
    begin
      SourceRow := Floor(Anchor.Y + (DestinationY + 0.5) -
        DestinationAnchorY);
      if (SourceRow < 0) or (SourceRow >= AImage.Height) then
        Continue;
      DestinationX := Max(0, DestinationLeft);
      SourceColumn := Floor(Anchor.X + (DestinationX + 0.5) -
        DestinationAnchorX);
      if SourceColumn < 0 then
      begin
        Inc(DestinationX, -SourceColumn);
        SourceColumn := 0;
      end;
      PixelCount := Min(Min(AWidth, DestinationRight) - DestinationX,
        AImage.Width - SourceColumn);
      if PixelCount <= 0 then
        Continue;
      Source := PTextRenderPixel(PByte(AImage.Data) +
        NativeInt(SourceRow) * AImage.Stride +
        NativeInt(SourceColumn) * SizeOf(TTextRenderPixel));
      Destination := PTextRenderPixel(@FCompositePixels[0]);
      Inc(Destination, NativeInt(DestinationY) * AWidth + DestinationX);
      for I := 0 to PixelCount - 1 do
      begin
        if Source^.A <> 0 then
        begin
          AdjustedSource := Source^;
          if Alpha < 1.0 then
            AdjustedSource.A := Round(AdjustedSource.A * Alpha);
          if AdjustedSource.A = 255 then
            Destination^ := AdjustedSource
          else if AdjustedSource.A <> 0 then
            BlendStraightAlpha(AdjustedSource, Destination^);
        end;
        Inc(Source);
        Inc(Destination);
      end;
    end;
    Exit;
  end;
  CornerX[0] := -Anchor.X * ScaleX;
  CornerY[0] := -Anchor.Y * ScaleY;
  CornerX[1] := (AImage.Width - Anchor.X) * ScaleX;
  CornerY[1] := CornerY[0];
  CornerX[2] := CornerX[1];
  CornerY[2] := (AImage.Height - Anchor.Y) * ScaleY;
  CornerX[3] := CornerX[0];
  CornerY[3] := CornerY[2];
  DestinationLeft := MaxInt;
  DestinationTop := MaxInt;
  DestinationRight := -MaxInt;
  DestinationBottom := -MaxInt;
  for I := 0 to 3 do
  begin
    RotatedX := CornerX[I] * CosAngle - CornerY[I] * SinAngle;
    RotatedY := CornerX[I] * SinAngle + CornerY[I] * CosAngle;
    DestinationLeft := Min(DestinationLeft,
      Floor(DestinationAnchorX + RotatedX));
    DestinationTop := Min(DestinationTop,
      Floor(DestinationAnchorY + RotatedY));
    DestinationRight := Max(DestinationRight,
      Ceil(DestinationAnchorX + RotatedX));
    DestinationBottom := Max(DestinationBottom,
      Ceil(DestinationAnchorY + RotatedY));
  end;
  for DestinationY := Max(0, DestinationTop) to
    Min(AHeight, DestinationBottom) - 1 do
  begin
    for DestinationX := Max(0, DestinationLeft) to
      Min(AWidth, DestinationRight) - 1 do
    begin
      DeltaX := (DestinationX + 0.5) - DestinationAnchorX;
      DeltaY := (DestinationY + 0.5) - DestinationAnchorY;
      SourceColumn := Floor(Anchor.X +
        (CosAngle * DeltaX + SinAngle * DeltaY) / ScaleX);
      SourceRow := Floor(Anchor.Y +
        (-SinAngle * DeltaX + CosAngle * DeltaY) / ScaleY);
      if (SourceColumn < 0) or (SourceColumn >= AImage.Width) or
        (SourceRow < 0) or (SourceRow >= AImage.Height) then
        Continue;
      if not IsAnimationSourcePixelVisible(AImage, SourceColumn, SourceRow,
        ATransform.RevealMode, ATransform.RevealDirection,
        ATransform.RevealProgress) then
        Continue;
      Source := PTextRenderPixel(PByte(AImage.Data) +
        NativeInt(SourceRow) * AImage.Stride +
        NativeInt(SourceColumn) * SizeOf(TTextRenderPixel));
      if BlurRadius > 0 then
        AdjustedSource := SampleAnimationBlur(AImage, SourceColumn,
          SourceRow, BlurRadius)
      else
        AdjustedSource := Source^;
      if AdjustedSource.A <> 0 then
      begin
        Destination := PTextRenderPixel(@FCompositePixels[0]);
        Inc(Destination, NativeInt(DestinationY) * AWidth + DestinationX);
        AdjustedSource.A := Round(AdjustedSource.A * Alpha);
        BlendStraightAlpha(AdjustedSource, Destination^);
      end;
    end;
  end;
end;

function TSerifSkiaRender.TrySendComposited(
  Video: PFILTER_PROC_VIDEO;
  const ATransform: TSerifDrawAnimationTransform): Boolean;
const
  MAX_IMAGE_DIMENSION = 16384;
var
  Anchor: TPointF;
  ByteCount: NativeInt;
  Height: Integer;
  HasRoleBounds: Boolean;
  I: Integer;
  RoleBounds: TRect;
  RoleItem: TSerifRoleNameRenderItem;
  RoleOffset: TPoint;
  RoleRect: TRect;
  RoleTransform: TSerifDrawAnimationTransform;
  Width: Integer;
{$IFDEF DEBUG}
  FrameMilliseconds: Double;
  GetImageMilliseconds: Double;
  ElapsedMilliseconds: Double;
  RoleMilliseconds: Double;
  SampleIndex: Integer;
  SetImageMilliseconds: Double;
  StageStarted: Int64;
  Started: Int64;
  TextMilliseconds: Double;
{$ENDIF}
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or
    not Assigned(Video^.GetImageData) or not Assigned(Video^.SetImageData) then
    Exit;
  Width := Video^.Object_^.Width;
  Height := Video^.Object_^.Height;
  if (Width <= 0) or (Height <= 0) or
    (Width > MAX_IMAGE_DIMENSION) or (Height > MAX_IMAGE_DIMENSION) then
    Exit;
  ByteCount := NativeInt(Width) * Height * SizeOf(TTextRenderPixel);
  if ByteCount <= 0 then
    Exit;
  SetLength(FCompositePixels, ByteCount);
{$IFDEF DEBUG}
  Started := SerifDrawTimerStart;
  StageStarted := SerifDrawTimerStart;
{$ENDIF}
  Video^.GetImageData(PPIXEL_RGBA(@FCompositePixels[0]));
{$IFDEF DEBUG}
  GetImageMilliseconds := SerifDrawTimerElapsedMilliseconds(StageStarted);
  StageStarted := SerifDrawTimerStart;
{$ENDIF}
  CompositeSerifDrawFrames(FCompositePixels, Width, Height, FSettings,
    FFrameRoleNames);
{$IFDEF DEBUG}
  FrameMilliseconds := SerifDrawTimerElapsedMilliseconds(StageStarted);
  StageStarted := SerifDrawTimerStart;
{$ENDIF}
  HasRoleBounds := False;
  RoleBounds := TRect.Empty;
  for I := 0 to TObjectList<TSerifRoleNameRenderItem>(FRoleNameItems).Count - 1 do
  begin
    RoleItem := TObjectList<TSerifRoleNameRenderItem>(FRoleNameItems)[I];
    Anchor := SerifDrawPlacementAnchor(RoleItem.Layout.Placement,
      RoleItem.Image.Bounds, RoleItem.Image.LayoutBounds);
    RoleRect.Left := Round(Width * 0.5 + RoleItem.Layout.PositionX - Anchor.X);
    RoleRect.Top := Round(Height * 0.5 + RoleItem.Layout.PositionY - Anchor.Y);
    RoleRect.Right := RoleRect.Left + RoleItem.Image.Width;
    RoleRect.Bottom := RoleRect.Top + RoleItem.Image.Height;
    if not HasRoleBounds then
    begin
      RoleBounds := RoleRect;
      HasRoleBounds := True;
    end
    else
    begin
      RoleBounds.Left := Min(RoleBounds.Left, RoleRect.Left);
      RoleBounds.Top := Min(RoleBounds.Top, RoleRect.Top);
      RoleBounds.Right := Max(RoleBounds.Right, RoleRect.Right);
      RoleBounds.Bottom := Max(RoleBounds.Bottom, RoleRect.Bottom);
    end;
  end;
  if HasRoleBounds then
    RoleOffset := SerifDrawRoleNameViewportOffset(RoleBounds, Width, Height, 4)
  else
    RoleOffset := Point(0, 0);
  RoleTransform := TSerifDrawAnimationTransform.Identity;
  for I := 0 to TObjectList<TSerifRoleNameRenderItem>(FRoleNameItems).Count - 1 do
  begin
    RoleItem := TObjectList<TSerifRoleNameRenderItem>(FRoleNameItems)[I];
    BlendImageToComposite(RoleItem.Image, Width, Height,
      RoleItem.Layout.Placement, RoleItem.Layout.PositionX + RoleOffset.X,
      RoleItem.Layout.PositionY + RoleOffset.Y, RoleTransform);
  end;
{$IFDEF DEBUG}
  RoleMilliseconds := SerifDrawTimerElapsedMilliseconds(StageStarted);
  StageStarted := SerifDrawTimerStart;
{$ENDIF}
  BlendImageToComposite(FImage, Width, Height, FPlacement,
    FPositionX, FPositionY, ATransform);
{$IFDEF DEBUG}
  TextMilliseconds := SerifDrawTimerElapsedMilliseconds(StageStarted);
  StageStarted := SerifDrawTimerStart;
{$ENDIF}
  Video^.SetImageData(PPIXEL_RGBA(@FCompositePixels[0]), Width, Height);
{$IFDEF DEBUG}
  SetImageMilliseconds := SerifDrawTimerElapsedMilliseconds(StageStarted);
  ElapsedMilliseconds := SerifDrawTimerElapsedMilliseconds(Started);
  SampleIndex := InterlockedIncrement(FSendLogCount);
  if SampleIndex <= 20 then
    SerifDrawDebugLog(Format(
      'SetImageData (input composite): sample=%d input=%dx%d text=%dx%d ' +
      'placement=%d pos=(%.3f,%.3f) bytes=%d ' +
      'ms(get=%.3f frame=%.3f role=%.3f text=%.3f set=%.3f total=%.3f).',
      [SampleIndex, Width, Height, FImage.Width, FImage.Height,
       FPlacement, FPositionX, FPositionY, ByteCount,
       GetImageMilliseconds, FrameMilliseconds, RoleMilliseconds,
       TextMilliseconds, SetImageMilliseconds, ElapsedMilliseconds]));
{$ENDIF}
  Result := True;
end;

procedure TSerifSkiaRender.SetEmptyImage;
var
  EmptyImage: TTextRenderImage;
begin
  EmptyImage := TTextRenderImage.Create(TRect.Create(0, 0, 1, 1));
  EmptyImage.Clear;
  FreeAndNil(FImage);
  FImage := EmptyImage;
end;

procedure TSerifSkiaRender.Update(
  const ASnapshots: TArray<TSerifDrawSnapshot>;
  const ASettings: TSerifDrawSettings;
  const AParameters: TSerifDrawAnimationParameters);
var
  NewSignature: string;
  NewRoleSignature: string;
  RoleParameters: TSerifDrawAnimationParameters;
begin
  FSettings := ASettings;
  if Length(ASnapshots) > 0 then
  begin
    SetLength(FFrameRoleNames, 1);
    FFrameRoleNames[0] := ASnapshots[High(ASnapshots)].Chara;
  end
  else
    FFrameRoleNames := nil;
  FPlacement := ASettings.Placement;
  FPositionX := ASettings.PositionX;
  FPositionY := ASettings.PositionY;
  NewSignature := BuildSignature(ASnapshots, ASettings, AParameters);
  RoleParameters := AParameters;
  RoleParameters.SyncKind := SERIF_ANIMATION_NONE;
  NewRoleSignature := BuildSignature(ASnapshots, ASettings, RoleParameters);
  if (NewSignature = FSignature) and (NewRoleSignature = FRoleSignature) then
    Exit;
  if NewSignature <> FSignature then
  begin
    RenderSnapshots(ASnapshots, ASettings, AParameters);
    FSignature := NewSignature;
  end;
  if NewRoleSignature <> FRoleSignature then
  begin
    RenderRoleNames(ASnapshots, ASettings);
    FRoleSignature := NewRoleSignature;
  end;
end;

end.
