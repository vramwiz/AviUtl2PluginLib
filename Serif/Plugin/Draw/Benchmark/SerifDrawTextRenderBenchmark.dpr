program SerifDrawTextRenderBenchmark;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.Skia,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  Winapi.Windows;

const
  SAMPLE_TEXT = 'SerifDraw LARGE TEXT';
  FONT_SIZE = 520.0;
  OUTLINE_WIDTH = 48.0;
  WARMUP_COUNT = 5;
  MEASURE_COUNT = 30;

type
  TByteBuffer = TArray<Byte>;

  TBenchmarkStats = record
    AverageMs: Double;
    MedianMs: Double;
    MinimumMs: Double;
    MaximumMs: Double;
  end;

  TGdiPlusRenderer = class
  private
    FBitmap: TGPBitmap;
    FBuffer: TByteBuffer;
    FFamily: TGPFontFamily;
    FFillBrush: TGPSolidBrush;
    FFormat: TGPStringFormat;
    FGraphics: TGPGraphics;
    FHeight: Integer;
    FOrigin: TGPPointF;
    FOutlinePen: TGPPen;
    FPath: TGPGraphicsPath;
    FWidth: Integer;
    procedure CopyBitmapToRgba;
    procedure DrawCached;
    procedure RecreateSurface;
  public
    constructor Create(const AWidth, AHeight: Integer);
    destructor Destroy; override;
    procedure RenderCached;
    procedure RenderCachedPathNewSurface;
    procedure RenderCurrentEquivalent;
    property Buffer: TByteBuffer read FBuffer;
  end;

  TSkiaRenderer = class
  private
    FBuffer: TByteBuffer;
    FCanvas: ISkCanvas;
    FFillPaint: ISkPaint;
    FFont: ISkFont;
    FHeight: Integer;
    FOutlinePaint: ISkPaint;
    FSurface: ISkSurface;
    FTextBlob: ISkTextBlob;
    FTextX: Single;
    FTextY: Single;
    FWidth: Integer;
  public
    constructor Create(const AWidth, AHeight: Integer);
    procedure RenderSimpleText;
    procedure RenderTextBlob;
    property Buffer: TByteBuffer read FBuffer;
  end;

var
  GdiPlusToken: ULONG_PTR;
  Results: TStringList;

procedure CheckGdiPlus(const AOperation: string; const AStatus: TStatus);
begin
  if AStatus <> Ok then
    raise Exception.CreateFmt('%s failed with GDI+ status %d',
      [AOperation, Ord(AStatus)]);
end;

function CreateFontFamily: TGPFontFamily;
const
  FONT_NAMES: array[0..2] of string =
    ('Yu Gothic UI', 'Meiryo UI', 'Segoe UI');
var
  FontName: string;
begin
  for FontName in FONT_NAMES do
  begin
    Result := TGPFontFamily.Create(FontName);
    if Result.IsAvailable then
      Exit;
    Result.Free;
  end;
  raise Exception.Create('No sample font is available');
end;

function CreateSkiaTypeface: ISkTypeface;
const
  FONT_NAMES: array[0..2] of string =
    ('Yu Gothic UI', 'Meiryo UI', 'Segoe UI');
var
  FontName: string;
begin
  for FontName in FONT_NAMES do
  begin
    Result := TSkTypeface.MakeFromName(FontName, TSkFontStyle.Bold);
    if Result <> nil then
      Exit;
  end;
  Result := TSkTypeface.MakeDefault;
end;

function QueryCounter: Int64;
begin
  QueryPerformanceCounter(Result);
end;

function ElapsedMilliseconds(const AStarted, AStopped, AFrequency: Int64): Double;
begin
  Result := (AStopped - AStarted) * 1000.0 / AFrequency;
end;

function CalculateStats(const AValues: TArray<Double>): TBenchmarkStats;
var
  I: Integer;
  Sorted: TArray<Double>;
  Total: Double;
begin
  Sorted := Copy(AValues);
  TArray.Sort<Double>(Sorted);
  Total := 0;
  for I := 0 to High(Sorted) do
    Total := Total + Sorted[I];
  Result.AverageMs := Total / Length(Sorted);
  Result.MinimumMs := Sorted[0];
  Result.MaximumMs := Sorted[High(Sorted)];
  if Odd(Length(Sorted)) then
    Result.MedianMs := Sorted[Length(Sorted) div 2]
  else
    Result.MedianMs := (Sorted[Length(Sorted) div 2 - 1] +
      Sorted[Length(Sorted) div 2]) / 2;
end;

function CountNonTransparentPixels(const ABuffer: TByteBuffer): NativeUInt;
var
  I: NativeInt;
begin
  Result := 0;
  I := 3;
  while I < Length(ABuffer) do
  begin
    if ABuffer[I] <> 0 then
      Inc(Result);
    Inc(I, 4);
  end;
end;

function HashBuffer(const ABuffer: TByteBuffer): UInt64;
const
  FNV_OFFSET = UInt64($CBF29CE484222325);
  FNV_PRIME = UInt64($00000100000001B3);
var
  B: Byte;
begin
  Result := FNV_OFFSET;
  for B in ABuffer do
  begin
    Result := Result xor B;
    Result := Result * FNV_PRIME;
  end;
end;

procedure SaveRgbaPng(const AFileName: string; const ABuffer: TByteBuffer;
  const AWidth, AHeight: Integer);
var
  Info: TSkImageInfo;
begin
  Info := TSkImageInfo.Create(AWidth, AHeight, TSkColorType.RGBA8888,
    TSkAlphaType.Unpremul);
  if not TSkImageEncoder.EncodeToFile(AFileName, Info, @ABuffer[0],
    AWidth * 4, TSkEncodedImageFormat.PNG, 100) then
    raise Exception.CreateFmt('Failed to save %s', [AFileName]);
end;

procedure RunTimed(const AName: string; const AWidth, AHeight: Integer;
  const ARender: TProc; const AGetBuffer: TFunc<TByteBuffer>;
  const ASaveFileName: string);
var
  Buffer: TByteBuffer;
  Frequency: Int64;
  I: Integer;
  Started: Int64;
  Stats: TBenchmarkStats;
  Stopped: Int64;
  Times: TArray<Double>;
begin
  for I := 1 to WARMUP_COUNT do
    ARender();

  QueryPerformanceFrequency(Frequency);
  SetLength(Times, MEASURE_COUNT);
  for I := 0 to High(Times) do
  begin
    Started := QueryCounter;
    ARender();
    Stopped := QueryCounter;
    Times[I] := ElapsedMilliseconds(Started, Stopped, Frequency);
  end;

  Buffer := AGetBuffer();
  Stats := CalculateStats(Times);
  Writeln(Format('%-36s %4dx%-4d avg=%8.3f median=%8.3f min=%8.3f max=%8.3f ms',
    [AName, AWidth, AHeight, Stats.AverageMs, Stats.MedianMs,
     Stats.MinimumMs, Stats.MaximumMs]));
  Results.Add(Format('%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%.16x',
    [AName, AWidth, AHeight, Stats.AverageMs, Stats.MedianMs,
     Stats.MinimumMs, Stats.MaximumMs, CountNonTransparentPixels(Buffer),
     HashBuffer(Buffer)]));
  if ASaveFileName <> '' then
    SaveRgbaPng(ASaveFileName, Buffer, AWidth, AHeight);
end;

{ TGdiPlusRenderer }

constructor TGdiPlusRenderer.Create(const AWidth, AHeight: Integer);
begin
  inherited Create;
  FWidth := AWidth;
  FHeight := AHeight;
  SetLength(FBuffer, FWidth * FHeight * 4);
  FFamily := CreateFontFamily;
  FFormat := TGPStringFormat.Create;
  FPath := TGPGraphicsPath.Create;
  if FHeight >= 1200 then
    FOrigin.Y := 520
  else
    FOrigin.Y := 80;
  FOrigin.X := 120;
  CheckGdiPlus('Create cached text path', FPath.AddString(SAMPLE_TEXT,
    Length(SAMPLE_TEXT), FFamily, FontStyleBold, FONT_SIZE, FOrigin, FFormat));
  FOutlinePen := TGPPen.Create(MakeColor(255, 36, 126, 255), OUTLINE_WIDTH);
  CheckGdiPlus('Set outline join', FOutlinePen.SetLineJoin(LineJoinRound));
  FFillBrush := TGPSolidBrush.Create(MakeColor(255, 255, 255, 255));
  RecreateSurface;
end;

destructor TGdiPlusRenderer.Destroy;
begin
  FGraphics.Free;
  FBitmap.Free;
  FFillBrush.Free;
  FOutlinePen.Free;
  FPath.Free;
  FFormat.Free;
  FFamily.Free;
  inherited;
end;

procedure TGdiPlusRenderer.RecreateSurface;
begin
  FreeAndNil(FGraphics);
  FreeAndNil(FBitmap);
  FBitmap := TGPBitmap.Create(FWidth, FHeight, PixelFormat32bppARGB);
  CheckGdiPlus('Create bitmap', FBitmap.GetLastStatus);
  FGraphics := TGPGraphics.Create(FBitmap);
  CheckGdiPlus('Create graphics', FGraphics.GetLastStatus);
  CheckGdiPlus('Set smoothing mode',
    FGraphics.SetSmoothingMode(SmoothingModeAntiAlias8x8));
end;

procedure TGdiPlusRenderer.DrawCached;
begin
  CheckGdiPlus('Clear bitmap', FGraphics.Clear(MakeColor(0, 0, 0, 0)));
  CheckGdiPlus('Draw outline', FGraphics.DrawPath(FOutlinePen, FPath));
  CheckGdiPlus('Draw fill', FGraphics.FillPath(FFillBrush, FPath));
  FGraphics.Flush;
end;

procedure TGdiPlusRenderer.CopyBitmapToRgba;
var
  BitmapData: TBitmapData;
  Destination: PByte;
  Rect: TGPRect;
  Source: PByte;
  X: Integer;
  Y: Integer;
begin
  Rect.X := 0;
  Rect.Y := 0;
  Rect.Width := FWidth;
  Rect.Height := FHeight;
  FillChar(BitmapData, SizeOf(BitmapData), 0);
  CheckGdiPlus('Lock bitmap', FBitmap.LockBits(Rect, ImageLockModeRead,
    PixelFormat32bppARGB, BitmapData));
  try
    for Y := 0 to FHeight - 1 do
    begin
      Source := PByte(NativeInt(BitmapData.Scan0) +
        NativeInt(Y) * BitmapData.Stride);
      Destination := @FBuffer[Y * FWidth * 4];
      for X := 0 to FWidth - 1 do
      begin
        Destination[0] := Source[2];
        Destination[1] := Source[1];
        Destination[2] := Source[0];
        Destination[3] := Source[3];
        Inc(Source, 4);
        Inc(Destination, 4);
      end;
    end;
  finally
    CheckGdiPlus('Unlock bitmap', FBitmap.UnlockBits(BitmapData));
  end;
end;

procedure TGdiPlusRenderer.RenderCached;
begin
  DrawCached;
  CopyBitmapToRgba;
end;

procedure TGdiPlusRenderer.RenderCachedPathNewSurface;
begin
  RecreateSurface;
  DrawCached;
  CopyBitmapToRgba;
end;

procedure TGdiPlusRenderer.RenderCurrentEquivalent;
var
  FillBrush: TGPSolidBrush;
  Format: TGPStringFormat;
  OutlinePen: TGPPen;
  Path: TGPGraphicsPath;
begin
  RecreateSurface;
  CheckGdiPlus('Clear bitmap', FGraphics.Clear(MakeColor(0, 0, 0, 0)));
  Format := TGPStringFormat.Create;
  try
    Path := TGPGraphicsPath.Create;
    try
      CheckGdiPlus('Create text path', Path.AddString(SAMPLE_TEXT,
        Length(SAMPLE_TEXT), FFamily, FontStyleBold, FONT_SIZE, FOrigin, Format));
      OutlinePen := TGPPen.Create(MakeColor(255, 36, 126, 255), OUTLINE_WIDTH);
      try
        CheckGdiPlus('Set outline join', OutlinePen.SetLineJoin(LineJoinRound));
        CheckGdiPlus('Draw outline', FGraphics.DrawPath(OutlinePen, Path));
      finally
        OutlinePen.Free;
      end;
      FillBrush := TGPSolidBrush.Create(MakeColor(255, 255, 255, 255));
      try
        CheckGdiPlus('Draw fill', FGraphics.FillPath(FillBrush, Path));
      finally
        FillBrush.Free;
      end;
    finally
      Path.Free;
    end;
  finally
    Format.Free;
  end;
  FGraphics.Flush;
  CopyBitmapToRgba;
end;

{ TSkiaRenderer }

constructor TSkiaRenderer.Create(const AWidth, AHeight: Integer);
var
  Info: TSkImageInfo;
  Typeface: ISkTypeface;
begin
  inherited Create;
  FWidth := AWidth;
  FHeight := AHeight;
  SetLength(FBuffer, FWidth * FHeight * 4);
  Info := TSkImageInfo.Create(FWidth, FHeight, TSkColorType.RGBA8888,
    TSkAlphaType.Unpremul);
  FSurface := TSkSurface.MakeRasterDirect(Info, @FBuffer[0], FWidth * 4);
  if FSurface = nil then
    raise Exception.Create('Failed to create Skia raster-direct surface');
  FCanvas := FSurface.Canvas;
  Typeface := CreateSkiaTypeface;
  FFont := TSkFont.Create(Typeface, FONT_SIZE);
  FFont.Edging := TSkFontEdging.AntiAlias;
  FTextBlob := TSkTextBlob.MakeFromText(SAMPLE_TEXT, FFont);

  FOutlinePaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  FOutlinePaint.AntiAlias := True;
  FOutlinePaint.Color := $FF247EFF;
  FOutlinePaint.StrokeWidth := OUTLINE_WIDTH;
  FOutlinePaint.StrokeJoin := TSkStrokeJoin.Round;

  FFillPaint := TSkPaint.Create(TSkPaintStyle.Fill);
  FFillPaint.AntiAlias := True;
  FFillPaint.Color := TAlphaColorRec.White;

  FTextX := 120;
  if FHeight >= 1200 then
    FTextY := 1020
  else
    FTextY := 580;
end;

procedure TSkiaRenderer.RenderSimpleText;
begin
  FCanvas.Clear(TAlphaColorRec.Null);
  FCanvas.DrawSimpleText(SAMPLE_TEXT, FTextX, FTextY, FFont, FOutlinePaint);
  FCanvas.DrawSimpleText(SAMPLE_TEXT, FTextX, FTextY, FFont, FFillPaint);
  FSurface.Flush;
end;

procedure TSkiaRenderer.RenderTextBlob;
begin
  FCanvas.Clear(TAlphaColorRec.Null);
  FCanvas.DrawTextBlob(FTextBlob, FTextX, FTextY, FOutlinePaint);
  FCanvas.DrawTextBlob(FTextBlob, FTextX, FTextY, FFillPaint);
  FSurface.Flush;
end;

procedure BenchmarkSize(const AWidth, AHeight: Integer; const ATag: string);
var
  Gdi: TGdiPlusRenderer;
  OutputDirectory: string;
  Skia: TSkiaRenderer;
begin
  OutputDirectory := ExtractFilePath(ParamStr(0)) + 'results\';
  ForceDirectories(OutputDirectory);

  Gdi := TGdiPlusRenderer.Create(AWidth, AHeight);
  try
    if AHeight >= 1200 then
      RunTimed('GDI+ current-equivalent', AWidth, AHeight,
        Gdi.RenderCurrentEquivalent,
        function: TByteBuffer begin Result := Gdi.Buffer end,
        '');
    RunTimed('GDI+ cached-path/new-surface', AWidth, AHeight,
      Gdi.RenderCachedPathNewSurface,
      function: TByteBuffer begin Result := Gdi.Buffer end,
      '');
    RunTimed('GDI+ cached-surface/path', AWidth, AHeight,
      Gdi.RenderCached,
      function: TByteBuffer begin Result := Gdi.Buffer end,
      OutputDirectory + 'gdi_' + ATag + '.png');
  finally
    Gdi.Free;
  end;

  Skia := TSkiaRenderer.Create(AWidth, AHeight);
  try
    RunTimed('Skia raster-direct/simple-text', AWidth, AHeight,
      Skia.RenderSimpleText,
      function: TByteBuffer begin Result := Skia.Buffer end,
      '');
    RunTimed('Skia raster-direct/text-blob', AWidth, AHeight,
      Skia.RenderTextBlob,
      function: TByteBuffer begin Result := Skia.Buffer end,
      OutputDirectory + 'skia_' + ATag + '.png');
  finally
    Skia.Free;
  end;
end;

procedure InitializeGdiPlus;
var
  Input: TGdiplusStartupInput;
begin
  FillChar(Input, SizeOf(Input), 0);
  Input.GdiplusVersion := 1;
  CheckGdiPlus('GdiplusStartup', GdiplusStartup(GdiPlusToken, @Input, nil));
end;

procedure Run;
var
  CsvFileName: string;
begin
  TSkGraphics.Init;
  InitializeGdiPlus;
  Results := TStringList.Create;
  try
    Results.Add('method,width,height,average_ms,median_ms,min_ms,max_ms,nontransparent_pixels,fnv1a64');
    Writeln('SerifDraw decorated text rendering benchmark');
    Writeln(Format('text="%s" font=520px outline=48px warmup=%d samples=%d',
      [SAMPLE_TEXT, WARMUP_COUNT, MEASURE_COUNT]));
    Writeln;
    BenchmarkSize(3840, 2160, '3840x2160');
    Writeln;
    BenchmarkSize(3840, 800, '3840x800');
    CsvFileName := ExtractFilePath(ParamStr(0)) + 'results\benchmark.csv';
    Results.SaveToFile(CsvFileName, TEncoding.UTF8);
    Writeln;
    Writeln('CSV and preview PNG files: ' + ExtractFilePath(CsvFileName));
  finally
    Results.Free;
    GdiplusShutdown(GdiPlusToken);
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
