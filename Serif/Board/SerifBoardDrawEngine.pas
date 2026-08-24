unit SerifBoardDrawEngine;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.IOUtils, Vcl.Graphics, BitmapEx,
  Math, PngImage;

type
  TSerifBoardDrawEngine = class
  private
    FBitmap: TBitmapEx;  // 描画先のビットマップ
  protected
    // 1ピクセルを書き込む
    procedure SetPixel(const AX, AY: Integer; const AColor: TColor; const AAlpha: Byte = $FF);
  public
    // 描画エンジンを初期化する
    constructor Create;
    // 描画エンジンを破棄する
    destructor Destroy; override;

    // 指定サイズで描画を開始する
    procedure BeginDraw(const AWidth, AHeight: Integer);
    // 矩形を塗りつぶす
    procedure FillRect(const ARect: TRect; const AColor: TColor; const AAlpha: Byte = $FF);
    // 楕円を塗りつぶす
    procedure FillEllipse(const ARect: TRect; const AColor: TColor; const AAlpha: Byte = $FF);
    // 角丸矩形を塗りつぶす
    procedure FillRoundRect(const ARect: TRect; const ARadius: Integer; const AColor: TColor; const AAlpha: Byte = $FF);
    // 枠付きの角丸矩形を塗りつぶす
    procedure FillRoundRectFrame(const ARect: TRect; const ARadius: Integer;
      const AFrameColor, AFillColor: TColor; const AFrameThickness: Integer; const AAlpha: Byte = $FF);
    // 三角形を塗りつぶす
    procedure FillTriangle(const APoint1, APoint2, APoint3: TPoint; const AColor: TColor; const AAlpha: Byte = $FF);
    // 線を描画する
    procedure DrawLine(const AX1, AY1, AX2, AY2: Integer; const AColor: TColor; const AThickness: Integer = 1);
    // 矩形の枠線を描画する
    procedure DrawFrameRect(const ARect: TRect; const AColor: TColor; const AThickness: Integer = 1);
    // 動作確認用の図形を描画する
    procedure DrawTestShapes;
    // 描画結果をファイルへ保存する
    procedure EndDraw(const AFileName: string);

    property Bitmap: TBitmapEx read FBitmap;
  end;

implementation

{ TSerifBoardDrawEngine }

constructor TSerifBoardDrawEngine.Create;
begin
  inherited Create;
  FBitmap := TBitmapEx.Create;
end;

destructor TSerifBoardDrawEngine.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

procedure TSerifBoardDrawEngine.BeginDraw(const AWidth, AHeight: Integer);
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentOutOfRangeException.Create('BeginDraw requires positive width and height.');

  FBitmap.PixelFormat := pf32bit;
  FBitmap.SetSize(AWidth, AHeight);
  FBitmap.Clear;
end;

procedure TSerifBoardDrawEngine.EndDraw(const AFileName: string);
var
  Directory: string;
  TempFileName: string;
  MemoryStream: TMemoryStream;
  PNG: TPngImage;
  Y: Integer;
  X: Integer;
  SrcRow: PFourthArray;
  DstRow: PRGBLine;
begin
  if AFileName = '' then
    Exit;

  Directory := ExtractFilePath(AFileName);
  if (Directory <> '') and (not TDirectory.Exists(Directory)) then
    TDirectory.CreateDirectory(Directory);

  TempFileName := TPath.Combine(Directory,
    TPath.GetFileNameWithoutExtension(AFileName) + '.tmp');

  MemoryStream := TMemoryStream.Create;
  PNG := TPngImage.CreateBlank(COLOR_RGBALPHA, 8, FBitmap.Width, FBitmap.Height);
  try
    for Y := 0 to FBitmap.Height - 1 do
    begin
      SrcRow := PFourthArray(FBitmap.ScanLine[Y]);
      DstRow := PNG.ScanLine[Y];
      for X := 0 to FBitmap.Width - 1 do
      begin
        DstRow[X].rgbtBlue := SrcRow^[X].B;
        DstRow[X].rgbtGreen := SrcRow^[X].G;
        DstRow[X].rgbtRed := SrcRow^[X].R;
        PNG.AlphaScanline[Y]^[X] := SrcRow^[X].A;
      end;
    end;

    PNG.SaveToStream(MemoryStream);
    MemoryStream.Position := 0;
    MemoryStream.SaveToFile(TempFileName);
  finally
    PNG.Free;
    MemoryStream.Free;
  end;

  if TFile.Exists(AFileName) then
    TFile.Delete(AFileName);
  TFile.Move(TempFileName, AFileName);
end;

procedure TSerifBoardDrawEngine.FillEllipse(const ARect: TRect; const AColor: TColor; const AAlpha: Byte = $FF);
var
  X, Y: Integer;
  R: TRect;
  CenterX, CenterY: Double;
  RadiusX, RadiusY: Double;
  DX, DY: Double;
begin
  R := ARect;
  NormalizeRect(R);
  if (R.Left >= R.Right) or (R.Top >= R.Bottom) then
    Exit;

  CenterX := (R.Left + R.Right - 1) / 2;
  CenterY := (R.Top + R.Bottom - 1) / 2;
  RadiusX := (R.Right - R.Left) / 2;
  RadiusY := (R.Bottom - R.Top) / 2;
  if (RadiusX <= 0) or (RadiusY <= 0) then
    Exit;

  for Y := Max(R.Top, 0) to Min(R.Bottom - 1, FBitmap.Height - 1) do
  begin
    for X := Max(R.Left, 0) to Min(R.Right - 1, FBitmap.Width - 1) do
    begin
      DX := (X - CenterX) / RadiusX;
      DY := (Y - CenterY) / RadiusY;
      if (DX * DX + DY * DY) <= 1.0 then
        SetPixel(X, Y, AColor, AAlpha);
    end;
  end;
end;

procedure TSerifBoardDrawEngine.FillRect(const ARect: TRect; const AColor: TColor; const AAlpha: Byte = $FF);
var
  X, Y: Integer;
  R: TRect;
begin
  R := ARect;
  NormalizeRect(R);
  if (R.Left >= R.Right) or (R.Top >= R.Bottom) then
    Exit;

  for Y := Max(R.Top, 0) to Min(R.Bottom - 1, FBitmap.Height - 1) do
  begin
    for X := Max(R.Left, 0) to Min(R.Right - 1, FBitmap.Width - 1) do
      SetPixel(X, Y, AColor, AAlpha);
  end;
end;

procedure TSerifBoardDrawEngine.SetPixel(const AX, AY: Integer; const AColor: TColor; const AAlpha: Byte = $FF);
var
  PixelRow: PFourthArray;
  RGBValue: LongInt;
begin
  if (AX < 0) or (AX >= FBitmap.Width) or (AY < 0) or (AY >= FBitmap.Height) then
    Exit;

  PixelRow := PFourthArray(FBitmap.ScanLine[AY]);
  RGBValue := ColorToRGB(AColor);
  PixelRow^[AX].R := GetRValue(RGBValue);
  PixelRow^[AX].G := GetGValue(RGBValue);
  PixelRow^[AX].B := GetBValue(RGBValue);
  PixelRow^[AX].A := AAlpha;
end;

procedure TSerifBoardDrawEngine.DrawTestShapes;
begin
  if (FBitmap.Width <= 0) or (FBitmap.Height <= 0) then
    Exit;

  // 透明背景のまま、四角と丸を描画するテスト
  FillRect(Rect(120, 120, 620, 420), clRed, $FF);
  FillEllipse(Rect(760, 140, 1160, 540), clLime, $FF);
  FillRect(Rect(1000, 700, 1500, 900), clBlue, $FF);
  FillEllipse(Rect(300, 680, 620, 980), clYellow, $FF);
end;

procedure TSerifBoardDrawEngine.DrawLine(const AX1, AY1, AX2, AY2: Integer; const AColor: TColor; const AThickness: Integer = 1);
var
  I, J: Integer;
  DX, DY, Steps: Integer;
  X, Y: Double;
  StepX, StepY: Double;
begin
  DX := AX2 - AX1;
  DY := AY2 - AY1;
  Steps := Max(Abs(DX), Abs(DY));
  if Steps = 0 then
  begin
    for I := -AThickness div 2 to (AThickness + 1) div 2 do
      for J := -AThickness div 2 to (AThickness + 1) div 2 do
        SetPixel(AX1 + I, AY1 + J, AColor);
    Exit;
  end;

  StepX := DX / Steps;
  StepY := DY / Steps;
  X := AX1;
  Y := AY1;

  for I := 0 to Steps do
  begin
    for J := -AThickness div 2 to (AThickness + 1) div 2 do
    begin
      SetPixel(Round(X), Round(Y) + J, AColor);
      if AThickness > 1 then
        SetPixel(Round(X) + 1, Round(Y) + J, AColor);
    end;
    X := X + StepX;
    Y := Y + StepY;
  end;
end;

procedure TSerifBoardDrawEngine.FillRoundRect(const ARect: TRect; const ARadius: Integer; const AColor: TColor; const AAlpha: Byte = $FF);
var
  R: TRect;
  Radius: Integer;
  X, Y: Integer;
  CenterX, CenterY: Double;
  DX, DY: Double;
  TestRadius: Double;
begin
  R := ARect;
  NormalizeRect(R);
  if (R.Left >= R.Right) or (R.Top >= R.Bottom) then
    Exit;

  Radius := Max(0, Min(ARadius, Min((R.Right - R.Left) div 2, (R.Bottom - R.Top) div 2)));
  if Radius = 0 then
  begin
    FillRect(R, AColor, AAlpha);
    Exit;
  end;

  TestRadius := Radius - 0.5;
  for Y := Max(R.Top, 0) to Min(R.Bottom - 1, FBitmap.Height - 1) do
  begin
    for X := Max(R.Left, 0) to Min(R.Right - 1, FBitmap.Width - 1) do
    begin
      if ((X >= R.Left + Radius) and (X < R.Right - Radius)) or
         ((Y >= R.Top + Radius) and (Y < R.Bottom - Radius)) then
      begin
        SetPixel(X, Y, AColor, AAlpha);
        Continue;
      end;

      if X < R.Left + Radius then
        CenterX := R.Left + Radius - 0.5
      else
        CenterX := R.Right - Radius - 0.5;

      if Y < R.Top + Radius then
        CenterY := R.Top + Radius - 0.5
      else
        CenterY := R.Bottom - Radius - 0.5;

      DX := X - CenterX;
      DY := Y - CenterY;
      if (DX * DX + DY * DY) <= (TestRadius * TestRadius) then
        SetPixel(X, Y, AColor, AAlpha);
    end;
  end;
end;

procedure TSerifBoardDrawEngine.FillRoundRectFrame(const ARect: TRect; const ARadius: Integer;
  const AFrameColor, AFillColor: TColor; const AFrameThickness: Integer; const AAlpha: Byte = $FF);
var
  InnerRect: TRect;
  InnerRadius: Integer;
begin
  if AFrameThickness <= 0 then
  begin
    FillRoundRect(ARect, ARadius, AFillColor, AAlpha);
    Exit;
  end;

  FillRoundRect(ARect, ARadius, AFrameColor, AAlpha);
  InnerRect := Rect(
    ARect.Left + AFrameThickness,
    ARect.Top + AFrameThickness,
    ARect.Right - AFrameThickness,
    ARect.Bottom - AFrameThickness);
  InnerRadius := Max(0, ARadius - AFrameThickness);
  FillRoundRect(InnerRect, InnerRadius, AFillColor, AAlpha);
end;

procedure TSerifBoardDrawEngine.FillTriangle(const APoint1, APoint2, APoint3: TPoint; const AColor: TColor;
  const AAlpha: Byte = $FF);
var
  MinX, MaxX, MinY, MaxY: Integer;
  X, Y: Integer;
  Area1, Area2, Area3: Int64;
  HasNegative, HasPositive: Boolean;
  function Sign(const P1, P2, P3: TPoint): Int64;
  begin
    Result := Int64(P1.X - P3.X) * Int64(P2.Y - P3.Y) - Int64(P2.X - P3.X) * Int64(P1.Y - P3.Y);
  end;
begin
  MinX := Max(Min(APoint1.X, Min(APoint2.X, APoint3.X)), 0);
  MaxX := Min(Max(APoint1.X, Max(APoint2.X, APoint3.X)), FBitmap.Width - 1);
  MinY := Max(Min(APoint1.Y, Min(APoint2.Y, APoint3.Y)), 0);
  MaxY := Min(Max(APoint1.Y, Max(APoint2.Y, APoint3.Y)), FBitmap.Height - 1);

  if (MinX > MaxX) or (MinY > MaxY) then
    Exit;

  for Y := MinY to MaxY do
  begin
    for X := MinX to MaxX do
    begin
      Area1 := Sign(Point(X, Y), APoint1, APoint2);
      Area2 := Sign(Point(X, Y), APoint2, APoint3);
      Area3 := Sign(Point(X, Y), APoint3, APoint1);

      HasNegative := (Area1 < 0) or (Area2 < 0) or (Area3 < 0);
      HasPositive := (Area1 > 0) or (Area2 > 0) or (Area3 > 0);
      if not (HasNegative and HasPositive) then
        SetPixel(X, Y, AColor, AAlpha);
    end;
  end;
end;

procedure TSerifBoardDrawEngine.DrawFrameRect(const ARect: TRect; const AColor: TColor; const AThickness: Integer = 1);
var
  R: TRect;
  I: Integer;
begin
  R := ARect;
  NormalizeRect(R);
  if (R.Left >= R.Right) or (R.Top >= R.Bottom) then
    Exit;

  for I := 0 to AThickness - 1 do
  begin
    DrawLine(R.Left + I, R.Top + I, R.Right - I - 1, R.Top + I, AColor);
    DrawLine(R.Left + I, R.Bottom - I - 1, R.Right - I - 1, R.Bottom - I - 1, AColor);
    DrawLine(R.Left + I, R.Top + I, R.Left + I, R.Bottom - I - 1, AColor);
    DrawLine(R.Right - I - 1, R.Top + I, R.Right - I - 1, R.Bottom - I - 1, AColor);
  end;
end;

end.
