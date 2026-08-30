unit PluginFilterSerifDrawGdiPlus;

// GDI+で装飾済み文字画像を生成し、AviUtl2向けRGBAとして保持する。

interface

uses
  AviUtl2FilterTypes;

type
  TSerifGdiPlusRender = class
  private
    FHeight: Integer;
    FPixels: TArray<PIXEL_RGBA>;
{$IFDEF DEBUG}
    FSendLogCount: Integer;
{$ENDIF}
    FWidth: Integer;
    procedure GenerateSample;
  public
    constructor Create;
    procedure SendToAviUtl2(Video: PFILTER_PROC_VIDEO);
  end;

procedure InitializeSerifDrawGraphics;
procedure FinalizeSerifDrawGraphics;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  PluginFilterSerifDrawDebugLog;

const
  SAMPLE_HEIGHT = 2160;
  SAMPLE_WIDTH = 3840;

var
  GdiPlusToken: ULONG_PTR;

procedure CheckGdiPlus(const Operation: string; Status: TStatus);
begin
  if Status <> Ok then
    raise Exception.CreateFmt('%s failed with GDI+ status %d.',
      [Operation, Ord(Status)]);
end;

function CreateSampleFontFamily: TGPFontFamily;
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
  raise Exception.Create('No sample font is available.');
end;

procedure InitializeSerifDrawGraphics;
var
  Input: TGdiplusStartupInput;
begin
  if GdiPlusToken <> 0 then
    Exit;
  FillChar(Input, SizeOf(Input), 0);
  Input.GdiplusVersion := 1;
  CheckGdiPlus('GdiplusStartup', GdiplusStartup(GdiPlusToken, @Input, nil));
end;

procedure FinalizeSerifDrawGraphics;
begin
  if GdiPlusToken = 0 then
    Exit;
  GdiplusShutdown(GdiPlusToken);
  GdiPlusToken := 0;
end;

{ TSerifGdiPlusRender }

constructor TSerifGdiPlusRender.Create;
begin
  inherited Create;
  GenerateSample;
end;

procedure TSerifGdiPlusRender.GenerateSample;
const
  FONT_SIZE = 520.0;
  OUTLINE_WIDTH = 48.0;
  SAMPLE_TEXT = 'SerifDraw LARGE TEXT';
var
  Bitmap: TGPBitmap;
  BitmapData: TBitmapData;
  Destination: PPIXEL_RGBA;
  Family: TGPFontFamily;
  FillBrush: TGPSolidBrush;
  StringFormat: TGPStringFormat;
  Graphics: TGPGraphics;
  Origin: TGPPointF;
  OutlinePen: TGPPen;
  Path: TGPGraphicsPath;
  Rect: TGPRect;
  Source: PByte;
  X: Integer;
  Y: Integer;
{$IFDEF DEBUG}
  BitmapMilliseconds: Double;
  DrawMilliseconds: Double;
  PathMilliseconds: Double;
  StageStarted: Int64;
  TotalStarted: Int64;
  TransferMilliseconds: Double;
{$ENDIF}
begin
  if GdiPlusToken = 0 then
    raise Exception.Create('GDI+ is not initialized.');

  FWidth := SAMPLE_WIDTH;
  FHeight := SAMPLE_HEIGHT;
  SetLength(FPixels, FWidth * FHeight);

{$IFDEF DEBUG}
  TotalStarted := SerifDrawTimerStart;
  StageStarted := SerifDrawTimerStart;
{$ENDIF}
  Bitmap := TGPBitmap.Create(FWidth, FHeight, PixelFormat32bppARGB);
  try
    CheckGdiPlus('Create bitmap', Bitmap.GetLastStatus);
    Graphics := TGPGraphics.Create(Bitmap);
    try
      CheckGdiPlus('Create graphics', Graphics.GetLastStatus);
      CheckGdiPlus('Clear bitmap', Graphics.Clear(MakeColor(0, 0, 0, 0)));
      CheckGdiPlus('Set smoothing mode',
        Graphics.SetSmoothingMode(SmoothingModeAntiAlias8x8));
{$IFDEF DEBUG}
      BitmapMilliseconds := SerifDrawTimerElapsedMilliseconds(StageStarted);
{$ENDIF}

      Family := CreateSampleFontFamily;
      try
        StringFormat := TGPStringFormat.Create;
        try
          Path := TGPGraphicsPath.Create;
          try
            Origin.X := 120;
            Origin.Y := 520;
{$IFDEF DEBUG}
            StageStarted := SerifDrawTimerStart;
{$ENDIF}
            CheckGdiPlus('Create text path', Path.AddString(SAMPLE_TEXT,
              Length(SAMPLE_TEXT), Family, FontStyleBold, FONT_SIZE, Origin,
              StringFormat));
{$IFDEF DEBUG}
            PathMilliseconds := SerifDrawTimerElapsedMilliseconds(StageStarted);
            StageStarted := SerifDrawTimerStart;
{$ENDIF}

            OutlinePen := TGPPen.Create(MakeColor(255, 36, 126, 255),
              OUTLINE_WIDTH);
            try
              CheckGdiPlus('Set outline join',
                OutlinePen.SetLineJoin(LineJoinRound));
              CheckGdiPlus('Draw outline', Graphics.DrawPath(OutlinePen, Path));
            finally
              OutlinePen.Free;
            end;

            FillBrush := TGPSolidBrush.Create(MakeColor(255, 255, 255, 255));
            try
              CheckGdiPlus('Draw text fill', Graphics.FillPath(FillBrush, Path));
            finally
              FillBrush.Free;
            end;
{$IFDEF DEBUG}
            DrawMilliseconds := SerifDrawTimerElapsedMilliseconds(StageStarted);
{$ENDIF}
          finally
            Path.Free;
          end;
        finally
          StringFormat.Free;
        end;
      finally
        Family.Free;
      end;
      Graphics.Flush;
    finally
      Graphics.Free;
    end;

    Rect.X := 0;
    Rect.Y := 0;
    Rect.Width := FWidth;
    Rect.Height := FHeight;
    FillChar(BitmapData, SizeOf(BitmapData), 0);
    CheckGdiPlus('Lock sample bitmap', Bitmap.LockBits(Rect,
      ImageLockModeRead, PixelFormat32bppARGB, BitmapData));
    try
{$IFDEF DEBUG}
      StageStarted := SerifDrawTimerStart;
{$ENDIF}
      for Y := 0 to FHeight - 1 do
      begin
        Source := PByte(NativeInt(BitmapData.Scan0) +
          NativeInt(Y) * BitmapData.Stride);
        Destination := @FPixels[Y * FWidth];
        for X := 0 to FWidth - 1 do
        begin
          Destination^.B := Source[0];
          Destination^.G := Source[1];
          Destination^.R := Source[2];
          Destination^.A := Source[3];
          Inc(Source, 4);
          Inc(Destination);
        end;
      end;
{$IFDEF DEBUG}
      TransferMilliseconds := SerifDrawTimerElapsedMilliseconds(StageStarted);
{$ENDIF}
    finally
      CheckGdiPlus('Unlock sample bitmap', Bitmap.UnlockBits(BitmapData));
    end;
  finally
    Bitmap.Free;
  end;
{$IFDEF DEBUG}
  SerifDrawDebugLog(Format(
    'Sample generation: textLength=%d canvas=%dx%d fontSize=%.1f outline=%.1f ms(bitmap=%.3f path=%.3f draw=%.3f rgba=%.3f total=%.3f).',
    [Length(SAMPLE_TEXT), FWidth, FHeight, FONT_SIZE, OUTLINE_WIDTH,
     BitmapMilliseconds, PathMilliseconds, DrawMilliseconds,
     TransferMilliseconds, SerifDrawTimerElapsedMilliseconds(TotalStarted)]));
{$ENDIF}
end;

procedure TSerifGdiPlusRender.SendToAviUtl2(Video: PFILTER_PROC_VIDEO);
{$IFDEF DEBUG}
var
  ElapsedMilliseconds: Double;
  SampleIndex: Integer;
  Started: Int64;
{$ENDIF}
begin
  if (Video = nil) or not Assigned(Video^.SetImageData) or
    (Length(FPixels) = 0) then
    Exit;
{$IFDEF DEBUG}
  Started := SerifDrawTimerStart;
{$ENDIF}
  Video^.SetImageData(@FPixels[0], FWidth, FHeight);
{$IFDEF DEBUG}
  ElapsedMilliseconds := SerifDrawTimerElapsedMilliseconds(Started);
  SampleIndex := InterlockedIncrement(FSendLogCount);
  if SampleIndex <= 12 then
    SerifDrawDebugLog(Format(
      'SetImageData: sample=%d canvas=%dx%d bytes=%d elapsed=%.3f ms.',
      [SampleIndex, FWidth, FHeight, Length(FPixels) * SizeOf(PIXEL_RGBA),
       ElapsedMilliseconds]));
{$ENDIF}
end;

end.
