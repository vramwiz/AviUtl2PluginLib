unit VectorRenderer;

// VectorRendererData形式のデータをTBitmapへ描画する。

interface

uses
  System.UITypes,
  Vcl.Graphics,
  VectorRendererData;

type
  TVectorRendererBackground = (vrbWhite, vrbChecker, vrbTransparent);

  // ベクターデータを画像へ描画する。
  TVectorRenderer = class
  public
    // ベクターデータを指定サイズのビットマップへ描画する。
    class function RenderToBitmap(AData: TVectorRendererDataList;
      AWidth, AHeight: Integer;
      ABackground: TVectorRendererBackground = vrbWhite): TBitmap;
    // ベクターデータファイルを読み込んで指定サイズのビットマップへ描画する。
    class function RenderFileToBitmap(const AFileName: string;
      AWidth, AHeight: Integer;
      ABackground: TVectorRendererBackground = vrbWhite): TBitmap;
  end;

implementation

uses
  Winapi.Windows,
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  System.Types;

type
  TVectorPointArray = TArray<TPoint>;
  TVectorPointArrayList = TArray<TVectorPointArray>;

  TRGBQuadPixel = packed record
    Blue: Byte;
    Green: Byte;
    Red: Byte;
    Alpha: Byte;
  end;
  PRGBQuadArray = ^TRGBQuadArray;
  TRGBQuadArray = array[0..MaxInt div SizeOf(TRGBQuadPixel) - 1] of
    TRGBQuadPixel;

const
  TRANSPARENT_KEY_COLOR = TColor($00030201);

// GDIで描画したキー色背景を、アルファ付きの透明背景へ変換する。
procedure ConvertKeyColorToAlpha(ABitmap: Vcl.Graphics.TBitmap);
var
  X: Integer;
  Y: Integer;
  Row: PRGBQuadArray;
begin
  for Y := 0 to ABitmap.Height - 1 do
  begin
    Row := ABitmap.ScanLine[Y];
    for X := 0 to ABitmap.Width - 1 do
      if (Row[X].Red = 1) and (Row[X].Green = 2) and
        (Row[X].Blue = 3) then
      begin
        Row[X].Red := 0;
        Row[X].Green := 0;
        Row[X].Blue := 0;
        Row[X].Alpha := 0;
      end
      else
        Row[X].Alpha := 255;
  end;
  ABitmap.AlphaFormat := afPremultiplied;
end;

type
  // path文字列をTCanvasで描画できる点列へ変換する。
  TVectorPathParser = class
  private
    FTokens: TStringList;                  // path文字列を分解したトークン
    FIndex: Integer;                       // 現在の読み込み位置
    FScaleX: Double;                       // X方向の拡大率
    FScaleY: Double;                       // Y方向の拡大率
    FOffsetX: Double;                      // X方向の基準位置
    FOffsetY: Double;                      // Y方向の基準位置
    FTranslateX: Double;                   // X方向の移動量
    FTranslateY: Double;                   // Y方向の移動量
    FMatrixA: Double;
    FMatrixB: Double;
    FMatrixC: Double;
    FMatrixD: Double;
    FMatrixE: Double;
    FMatrixF: Double;
    FPoints: TList<TPointF>;               // 描画用の点列
    FSubpaths: TList<TVectorPointArray>;   // M命令ごとに分離した輪郭
    FCurrent: TPointF;                     // 現在位置
    FStart: TPointF;                       // 現在の図形の開始位置
    // トークンが残っているかを返す。
    function HasToken: Boolean;
    // 現在のトークンを読み進めずに返す。
    function PeekToken: string;
    // 現在のトークンを読み進めて返す。
    function NextToken: string;
    // 現在のトークンを数値として読み込む。
    function ReadNumber: Double;
    // トークンがpath命令かを返す。
    function IsCommandToken(const AToken: string): Boolean;
    // 描画用の点を追加する。
    procedure AddPoint(AX, AY: Double);
    // 現在の輪郭を描画用リストへ確定する。
    procedure FinishSubpath;
    // 3次ベジェ曲線を分割して点列へ追加する。
    procedure AddCubic(const AControl1, AControl2, AEndPoint: TPointF);
  public
    // 内部リストを生成する。
    constructor Create;
    // 内部リストを破棄する。
    destructor Destroy; override;
    // path文字列を描画用の点列へ変換する。
    function Parse(const APathData: string; AData: TVectorRendererDataList;
      ATargetWidth, ATargetHeight: Integer;
      AItem: TVectorRendererElementItem): TVectorPointArrayList;
  end;

// TPointFを作成する。
function MakePointF(AX, AY: Double): TPointF;
begin
  Result.X := AX;
  Result.Y := AY;
end;

// path文字列をトークンに分解する。
procedure TokenizePath(const AData: string; ATokens: TStringList);
var
  I: Integer;                              // path文字列の走査位置
  Start: Integer;                          // 現在トークンの開始位置
  C: Char;                                 // 現在の文字
begin
  ATokens.Clear;
  I := 1;
  while I <= Length(AData) do
  begin
    C := AData[I];
    if CharInSet(C, [' ', #9, #10, #13, ',']) then
    begin
      Inc(I);
      Continue;
    end;
    if CharInSet(C, ['M', 'm', 'L', 'l', 'C', 'c', 'Z', 'z']) then
    begin
      ATokens.Add(C);
      Inc(I);
      Continue;
    end;
    Start := I;
    Inc(I);
    while (I <= Length(AData)) and not CharInSet(AData[I],
      [' ', #9, #10, #13, ',', 'M', 'm', 'L', 'l', 'C', 'c', 'Z', 'z']) do
    begin
      if (CharInSet(AData[I], ['-', '+'])) and
        not CharInSet(AData[I - 1], ['e', 'E']) then
        Break;
      Inc(I);
    end;
    ATokens.Add(Copy(AData, Start, I - Start));
  end;
end;

{ TVectorPathParser }

// 内部リストを生成する。
constructor TVectorPathParser.Create;
begin
  inherited Create;
  FTokens := TStringList.Create;
  FPoints := TList<TPointF>.Create;
  FSubpaths := TList<TVectorPointArray>.Create;
end;

// 内部リストを破棄する。
destructor TVectorPathParser.Destroy;
begin
  FSubpaths.Free;
  FPoints.Free;
  FTokens.Free;
  inherited;
end;

// 3次ベジェ曲線を分割して点列へ追加する。
procedure TVectorPathParser.AddCubic(const AControl1, AControl2,
  AEndPoint: TPointF);
const
  SegmentCount = 24;
var
  I: Integer;                              // 分割位置
  T: Double;                               // 曲線上の位置
  U: Double;                               // 1-Tの値
  X: Double;                               // 計算後のX座標
  Y: Double;                               // 計算後のY座標
  StartPoint: TPointF;                     // 曲線の開始位置
begin
  StartPoint := FCurrent;
  for I := 1 to SegmentCount do
  begin
    T := I / SegmentCount;
    U := 1 - T;
    X := U * U * U * StartPoint.X +
      3 * U * U * T * AControl1.X +
      3 * U * T * T * AControl2.X +
      T * T * T * AEndPoint.X;
    Y := U * U * U * StartPoint.Y +
      3 * U * U * T * AControl1.Y +
      3 * U * T * T * AControl2.Y +
      T * T * T * AEndPoint.Y;
    AddPoint(X, Y);
  end;
  FCurrent := AEndPoint;
end;

// 描画用の点を追加する。
procedure TVectorPathParser.AddPoint(AX, AY: Double);
var
  TransformedX: Double;
  TransformedY: Double;
begin
  FCurrent := MakePointF(AX, AY);
  TransformedX := AX * FMatrixA + AY * FMatrixC + FMatrixE + FTranslateX;
  TransformedY := AX * FMatrixB + AY * FMatrixD + FMatrixF + FTranslateY;
  FPoints.Add(MakePointF(
    (TransformedX - FOffsetX) * FScaleX,
    (TransformedY - FOffsetY) * FScaleY));
end;

// 現在の輪郭を描画用リストへ確定する。
procedure TVectorPathParser.FinishSubpath;
var
  I: Integer;
  Points: TVectorPointArray;
begin
  if FPoints.Count = 0 then Exit;
  SetLength(Points, FPoints.Count);
  for I := 0 to FPoints.Count - 1 do
    Points[I] := Point(Round(FPoints[I].X), Round(FPoints[I].Y));
  FSubpaths.Add(Points);
  FPoints.Clear;
end;

// トークンが残っているかを返す。
function TVectorPathParser.HasToken: Boolean;
begin
  Result := FIndex < FTokens.Count;
end;

// トークンがpath命令かを返す。
function TVectorPathParser.IsCommandToken(const AToken: string): Boolean;
begin
  Result := (Length(AToken) = 1) and CharInSet(AToken[1],
    ['M', 'm', 'L', 'l', 'C', 'c', 'Z', 'z']);
end;

// 現在のトークンを読み進めて返す。
function TVectorPathParser.NextToken: string;
begin
  Result := FTokens[FIndex];
  Inc(FIndex);
end;

// path文字列を描画用の点列へ変換する。
function TVectorPathParser.Parse(const APathData: string;
  AData: TVectorRendererDataList; ATargetWidth, ATargetHeight: Integer;
  AItem: TVectorRendererElementItem): TVectorPointArrayList;
var
  Command: Char;                           // 現在のpath命令
  Token: string;                           // 現在のトークン
  X: Double;                               // X座標
  Y: Double;                               // Y座標
  C1: TPointF;                             // 3次ベジェの制御点1
  C2: TPointF;                             // 3次ベジェの制御点2
  EndPoint: TPointF;                       // 3次ベジェの終点
  I: Integer;                              // 輪郭の走査位置
begin
  FIndex := 0;
  FPoints.Clear;
  FSubpaths.Clear;
  FCurrent := MakePointF(0, 0);
  FStart := FCurrent;
  TokenizePath(APathData, FTokens);
  FOffsetX := AData.Root.ViewBoxX;
  FOffsetY := AData.Root.ViewBoxY;
  FTranslateX := AItem.TranslateX;
  FTranslateY := AItem.TranslateY;
  FMatrixA := AItem.MatrixA;
  FMatrixB := AItem.MatrixB;
  FMatrixC := AItem.MatrixC;
  FMatrixD := AItem.MatrixD;
  FMatrixE := AItem.MatrixE;
  FMatrixF := AItem.MatrixF;
  if AData.Root.ViewBoxWidth <> 0 then
    FScaleX := ATargetWidth / AData.Root.ViewBoxWidth
  else
    FScaleX := 1;
  if AData.Root.ViewBoxHeight <> 0 then
    FScaleY := ATargetHeight / AData.Root.ViewBoxHeight
  else
    FScaleY := 1;
  Command := #0;
  while HasToken do
  begin
    Token := PeekToken;
    if IsCommandToken(Token) then
      Command := NextToken[1];
    case Command of
      'M', 'm':
        begin
          FinishSubpath;
          X := ReadNumber;
          Y := ReadNumber;
          if Command = 'm' then
          begin
            X := FCurrent.X + X;
            Y := FCurrent.Y + Y;
          end;
          AddPoint(X, Y);
          FStart := FCurrent;
          if Command = 'm' then
            Command := 'l'
          else
            Command := 'L';
        end;
      'L', 'l':
        begin
          X := ReadNumber;
          Y := ReadNumber;
          if Command = 'l' then
          begin
            X := FCurrent.X + X;
            Y := FCurrent.Y + Y;
          end;
          AddPoint(X, Y);
        end;
      'C', 'c':
        begin
          C1 := MakePointF(ReadNumber, ReadNumber);
          C2 := MakePointF(ReadNumber, ReadNumber);
          EndPoint := MakePointF(ReadNumber, ReadNumber);
          if Command = 'c' then
          begin
            C1 := MakePointF(FCurrent.X + C1.X, FCurrent.Y + C1.Y);
            C2 := MakePointF(FCurrent.X + C2.X, FCurrent.Y + C2.Y);
            EndPoint := MakePointF(FCurrent.X + EndPoint.X, FCurrent.Y + EndPoint.Y);
          end;
          AddCubic(C1, C2, EndPoint);
        end;
      'Z', 'z':
        begin
          AddPoint(FStart.X, FStart.Y);
          FinishSubpath;
          Command := #0;
        end;
    else
      Break;
    end;
  end;
  FinishSubpath;
  SetLength(Result, FSubpaths.Count);
  for I := 0 to FSubpaths.Count - 1 do
    Result[I] := FSubpaths[I];
end;

// 現在のトークンを読み進めずに返す。
function TVectorPathParser.PeekToken: string;
begin
  Result := FTokens[FIndex];
end;

// 現在のトークンを数値として読み込む。
function TVectorPathParser.ReadNumber: Double;
begin
  Result := StrToFloatDef(NextToken, 0, TFormatSettings.Invariant);
end;

{ TVectorRenderer }

// ベクターデータファイルを読み込んで指定サイズのビットマップへ描画する。
class function TVectorRenderer.RenderFileToBitmap(const AFileName: string;
  AWidth, AHeight: Integer;
  ABackground: TVectorRendererBackground): Vcl.Graphics.TBitmap;
var
  Data: TVectorRendererDataList;           // 読み込むベクターデータ
begin
  Data := TVectorRendererDataList.Create;
  try
    Data.Filename := AFileName;
    Data.LoadFromFile;
    Result := RenderToBitmap(Data, AWidth, AHeight, ABackground);
  finally
    Data.Free;
  end;
end;

// ベクターデータを指定サイズのビットマップへ描画する。
procedure FillCheckerBackground(ABitmap: Vcl.Graphics.TBitmap);
const
  CELL_SIZE = 12;
  LIGHT_COLOR = TColor($00E0E0E0);
  DARK_COLOR = TColor($00B8B8B8);
var
  X: Integer;
  Y: Integer;
begin
  for Y := 0 to (ABitmap.Height - 1) div CELL_SIZE do
    for X := 0 to (ABitmap.Width - 1) div CELL_SIZE do
    begin
      if Odd(X + Y) then
        ABitmap.Canvas.Brush.Color := DARK_COLOR
      else
        ABitmap.Canvas.Brush.Color := LIGHT_COLOR;
      ABitmap.Canvas.FillRect(Rect(X * CELL_SIZE, Y * CELL_SIZE,
        (X + 1) * CELL_SIZE, (Y + 1) * CELL_SIZE));
    end;
end;

// 分離した輪郭を1つのSVG pathとしてnonzero規則で塗りつぶす。
procedure FillCompoundPath(ACanvas: TCanvas;
  const ASubpaths: TVectorPointArrayList);
var
  I: Integer;
  J: Integer;
  PolygonCount: Integer;
  PointIndex: Integer;
  TotalPointCount: Integer;
  Counts: TArray<Integer>;
  Points: TVectorPointArray;
  RegionBrush: HBRUSH;
  Region: HRGN;
  Filled: Boolean;
begin
  if Length(ASubpaths) = 0 then Exit;
  PolygonCount := 0;
  TotalPointCount := 0;
  for I := 0 to High(ASubpaths) do
    if Length(ASubpaths[I]) >= 3 then
    begin
      Inc(PolygonCount);
      Inc(TotalPointCount, Length(ASubpaths[I]));
    end;
  if PolygonCount = 0 then Exit;

  SetLength(Counts, PolygonCount);
  SetLength(Points, TotalPointCount);
  PolygonCount := 0;
  PointIndex := 0;
  for I := 0 to High(ASubpaths) do
  begin
    if Length(ASubpaths[I]) < 3 then Continue;
    Counts[PolygonCount] := Length(ASubpaths[I]);
    Inc(PolygonCount);
    for J := 0 to High(ASubpaths[I]) do
    begin
      Points[PointIndex] := ASubpaths[I][J];
      Inc(PointIndex);
    end;
  end;

  Region := CreatePolyPolygonRgn(Points[0], Counts[0], PolygonCount, WINDING);
  if Region = 0 then
  begin
    for I := 0 to High(ASubpaths) do
      if Length(ASubpaths[I]) >= 3 then
        ACanvas.Polygon(ASubpaths[I]);
    Exit;
  end;
  Filled := False;
  try
    RegionBrush := CreateSolidBrush(ColorToRGB(ACanvas.Brush.Color));
    if RegionBrush <> 0 then
    try
      Filled := FillRgn(ACanvas.Handle, Region, RegionBrush);
    finally
      DeleteObject(RegionBrush);
    end;
  finally
    DeleteObject(Region);
  end;
  if not Filled then
    for I := 0 to High(ASubpaths) do
      if Length(ASubpaths[I]) >= 3 then
        ACanvas.Polygon(ASubpaths[I]);
end;

class function TVectorRenderer.RenderToBitmap(AData: TVectorRendererDataList;
  AWidth, AHeight: Integer;
  ABackground: TVectorRendererBackground): Vcl.Graphics.TBitmap;
var
  I: Integer;                              // 要素の走査位置
  Item: TVectorRendererElementItem;        // 現在のpath要素
  Parser: TVectorPathParser;               // path文字列の解析器
  Subpaths: TVectorPointArrayList;         // M命令ごとに分離した輪郭
begin
  if AWidth <= 0 then
    AWidth := 1;
  if AHeight <= 0 then
    AHeight := 1;
  Result := Vcl.Graphics.TBitmap.Create;
  try
    Result.PixelFormat := pf32bit;
    Result.SetSize(AWidth, AHeight);
    case ABackground of
      vrbChecker:
        FillCheckerBackground(Result);
      vrbTransparent:
        begin
          Result.Canvas.Brush.Color := TRANSPARENT_KEY_COLOR;
          Result.Canvas.FillRect(Rect(0, 0, Result.Width, Result.Height));
        end;
    else
      Result.Canvas.Brush.Color := clWhite;
      Result.Canvas.FillRect(Rect(0, 0, Result.Width, Result.Height));
    end;
    Parser := TVectorPathParser.Create;
    try
      for I := 0 to AData.Count - 1 do
      begin
        Item := AData.Elements[I];
        if Item.FillColor = clNone then
          Continue;
        Subpaths := Parser.Parse(Item.PathData, AData, AWidth, AHeight, Item);
        if Length(Subpaths) > 0 then
        begin
          Result.Canvas.Brush.Style := bsSolid;
          Result.Canvas.Brush.Color := Item.FillColor;
          Result.Canvas.Pen.Style := psClear;
          FillCompoundPath(Result.Canvas, Subpaths);
        end;
      end;
    finally
      Parser.Free;
    end;
    if ABackground = vrbTransparent then
      ConvertKeyColorToAlpha(Result);
  except
    Result.Free;
    raise;
  end;
end;

end.
