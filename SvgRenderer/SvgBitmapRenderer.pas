unit SvgBitmapRenderer;

interface

uses
  System.SysUtils, Vcl.Graphics;

type
  TSvgBitmapRenderer = class
  public
    class function LoadFromFile(const AFileName: string; AWidth, AHeight: Integer): TBitmap;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.Types,
  System.Variants,
  Xml.XMLDoc,
  Xml.XMLIntf;

type
  TSvgViewBox = record
    X: Double;
    Y: Double;
    Width: Double;
    Height: Double;
  end;

  TSvgPathParser = class
  private
    FTokens: TStringList;
    FIndex: Integer;
    FScaleX: Double;
    FScaleY: Double;
    FOffsetX: Double;
    FOffsetY: Double;
    FTranslateX: Double;
    FTranslateY: Double;
    FPoints: TList<TPointF>;
    FCurrent: TPointF;
    FStart: TPointF;
    function HasToken: Boolean;
    function PeekToken: string;
    function NextToken: string;
    function ReadNumber: Double;
    function IsCommandToken(const AToken: string): Boolean;
    procedure AddPoint(AX, AY: Double);
    procedure AddCubic(const AControl1, AControl2, AEndPoint: TPointF);
  public
    constructor Create;
    destructor Destroy; override;
    function Parse(const AData: string; const AViewBox: TSvgViewBox;
      ATargetWidth, ATargetHeight: Integer; ATranslateX, ATranslateY: Double): TArray<TPoint>;
  end;

function SvgRGB(ARed, AGreen, ABlue: Integer): TColor;
begin
  Result := ARed or (AGreen shl 8) or (ABlue shl 16);
end;

function SvgColorToColor(const AValue: string; ADefault: TColor): TColor;
var
  S: string;
  P1: Integer;
  P2: Integer;
  Values: TStringList;
  R: Integer;
  G: Integer;
  B: Integer;
begin
  Result := ADefault;
  S := Trim(AValue);
  if S = '' then
    Exit;

  if SameText(S, 'none') then
    Exit(clNone);

  if (Length(S) = 7) and (S[1] = '#') then
  begin
    R := StrToIntDef('$' + Copy(S, 2, 2), 0);
    G := StrToIntDef('$' + Copy(S, 4, 2), 0);
    B := StrToIntDef('$' + Copy(S, 6, 2), 0);
    Exit(SvgRGB(R, G, B));
  end;

  if Pos('rgb', LowerCase(S)) = 1 then
  begin
    P1 := Pos('(', S);
    P2 := Pos(')', S);
    if (P1 <= 0) or (P2 <= P1) then
      Exit;

    Values := TStringList.Create;
    try
      Values.StrictDelimiter := True;
      Values.Delimiter := ',';
      Values.DelimitedText := Copy(S, P1 + 1, P2 - P1 - 1);
      if Values.Count < 3 then
        Exit;

      R := StrToIntDef(Trim(Values[0]), 0);
      G := StrToIntDef(Trim(Values[1]), 0);
      B := StrToIntDef(Trim(Values[2]), 0);
      Result := SvgRGB(R, G, B);
    finally
      Values.Free;
    end;
  end;
end;

function MakePointF(AX, AY: Double): TPointF;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function ParseViewBox(const AValue: string; ADefaultWidth, ADefaultHeight: Integer): TSvgViewBox;
var
  Values: TStringList;
  S: string;
begin
  Result.X := 0;
  Result.Y := 0;
  Result.Width := ADefaultWidth;
  Result.Height := ADefaultHeight;

  S := StringReplace(Trim(AValue), ',', ' ', [rfReplaceAll]);
  Values := TStringList.Create;
  try
    Values.StrictDelimiter := True;
    Values.Delimiter := ' ';
    Values.DelimitedText := S;
    while Values.IndexOf('') >= 0 do
      Values.Delete(Values.IndexOf(''));

    if Values.Count >= 4 then
    begin
      Result.X := StrToFloatDef(Values[0], 0);
      Result.Y := StrToFloatDef(Values[1], 0);
      Result.Width := StrToFloatDef(Values[2], ADefaultWidth);
      Result.Height := StrToFloatDef(Values[3], ADefaultHeight);
    end;
  finally
    Values.Free;
  end;
end;

procedure ParseTranslate(const AValue: string; out AX, AY: Double);
var
  S: string;
  P1: Integer;
  P2: Integer;
  Values: TStringList;
begin
  AX := 0;
  AY := 0;
  S := Trim(AValue);
  if Pos('translate', LowerCase(S)) <> 1 then
    Exit;

  P1 := Pos('(', S);
  P2 := Pos(')', S);
  if (P1 <= 0) or (P2 <= P1) then
    Exit;

  S := StringReplace(Copy(S, P1 + 1, P2 - P1 - 1), ',', ' ', [rfReplaceAll]);
  Values := TStringList.Create;
  try
    Values.StrictDelimiter := True;
    Values.Delimiter := ' ';
    Values.DelimitedText := S;
    while Values.IndexOf('') >= 0 do
      Values.Delete(Values.IndexOf(''));

    if Values.Count >= 1 then
      AX := StrToFloatDef(Values[0], 0);
    if Values.Count >= 2 then
      AY := StrToFloatDef(Values[1], 0);
  finally
    Values.Free;
  end;
end;

procedure TokenizePath(const AData: string; ATokens: TStringList);
var
  I: Integer;
  Start: Integer;
  C: Char;
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

function GetNodeAttribute(const ANode: IXMLNode; const AName: string): string;
begin
  Result := '';
  if Assigned(ANode) and ANode.HasAttribute(AName) then
    Result := VarToStr(ANode.Attributes[AName]);
end;

function RemoveXmlDoctype(const AText: string): string;
var
  StartPos: Integer;
  EndPos: Integer;
  BracketDepth: Integer;
  QuoteChar: Char;
begin
  Result := AText;
  StartPos := Pos('<!DOCTYPE', UpperCase(Result));
  if StartPos <= 0 then
    Exit;

  EndPos := StartPos + Length('<!DOCTYPE');
  BracketDepth := 0;
  QuoteChar := #0;
  while EndPos <= Length(Result) do
  begin
    if QuoteChar <> #0 then
    begin
      if Result[EndPos] = QuoteChar then
        QuoteChar := #0;
    end
    else if (Result[EndPos] = '"') or (Result[EndPos] = '''') then
      QuoteChar := Result[EndPos]
    else if Result[EndPos] = '[' then
      Inc(BracketDepth)
    else if (Result[EndPos] = ']') and (BracketDepth > 0) then
      Dec(BracketDepth)
    else if (Result[EndPos] = '>') and (BracketDepth = 0) then
      Break;
    Inc(EndPos);
  end;

  if EndPos <= Length(Result) then
    Delete(Result, StartPos, EndPos - StartPos + 1);
end;

procedure LoadSvgXmlDocument(const AFileName: string; AXml: IXMLDocument);
var
  Text: string;
begin
  Text := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  AXml.LoadFromXML(RemoveXmlDoctype(Text));
  AXml.Active := True;
end;

procedure DrawPaths(const ANode: IXMLNode; ABitmap: TBitmap; const AViewBox: TSvgViewBox);
var
  I: Integer;
  Child: IXMLNode;
  PathData: string;
  FillColor: TColor;
  TranslateX: Double;
  TranslateY: Double;
  Parser: TSvgPathParser;
  Points: TArray<TPoint>;
begin
  if not Assigned(ANode) then
    Exit;

  Parser := TSvgPathParser.Create;
  try
    for I := 0 to ANode.ChildNodes.Count - 1 do
    begin
      Child := ANode.ChildNodes[I];
      if SameText(Child.LocalName, 'path') or SameText(Child.NodeName, 'path') then
      begin
        PathData := GetNodeAttribute(Child, 'd');
        FillColor := SvgColorToColor(GetNodeAttribute(Child, 'fill'), clBlack);
        if (PathData <> '') and (FillColor <> clNone) then
        begin
          ParseTranslate(GetNodeAttribute(Child, 'transform'), TranslateX, TranslateY);
          Points := Parser.Parse(PathData, AViewBox, ABitmap.Width, ABitmap.Height,
            TranslateX, TranslateY);
          if Length(Points) >= 3 then
          begin
            ABitmap.Canvas.Brush.Style := bsSolid;
            ABitmap.Canvas.Brush.Color := FillColor;
            ABitmap.Canvas.Pen.Style := psClear;
            ABitmap.Canvas.Polygon(Points);
          end;
        end;
      end;

      if Child.HasChildNodes then
        DrawPaths(Child, ABitmap, AViewBox);
    end;
  finally
    Parser.Free;
  end;
end;

{ TSvgPathParser }

constructor TSvgPathParser.Create;
begin
  inherited Create;
  FTokens := TStringList.Create;
  FPoints := TList<TPointF>.Create;
end;

destructor TSvgPathParser.Destroy;
begin
  FPoints.Free;
  FTokens.Free;
  inherited;
end;

procedure TSvgPathParser.AddCubic(const AControl1, AControl2, AEndPoint: TPointF);
const
  SegmentCount = 24;
var
  I: Integer;
  T: Double;
  U: Double;
  X: Double;
  Y: Double;
  StartPoint: TPointF;
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

procedure TSvgPathParser.AddPoint(AX, AY: Double);
begin
  FCurrent := MakePointF(AX, AY);
  FPoints.Add(MakePointF(
    (AX + FTranslateX - FOffsetX) * FScaleX,
    (AY + FTranslateY - FOffsetY) * FScaleY));
end;

function TSvgPathParser.HasToken: Boolean;
begin
  Result := FIndex < FTokens.Count;
end;

function TSvgPathParser.IsCommandToken(const AToken: string): Boolean;
begin
  Result := (Length(AToken) = 1) and CharInSet(AToken[1],
    ['M', 'm', 'L', 'l', 'C', 'c', 'Z', 'z']);
end;

function TSvgPathParser.NextToken: string;
begin
  Result := FTokens[FIndex];
  Inc(FIndex);
end;

function TSvgPathParser.Parse(const AData: string; const AViewBox: TSvgViewBox;
  ATargetWidth, ATargetHeight: Integer; ATranslateX, ATranslateY: Double): TArray<TPoint>;
var
  Command: Char;
  Token: string;
  X: Double;
  Y: Double;
  C1: TPointF;
  C2: TPointF;
  EndPoint: TPointF;
  I: Integer;
begin
  FIndex := 0;
  FPoints.Clear;
  TokenizePath(AData, FTokens);

  FOffsetX := AViewBox.X;
  FOffsetY := AViewBox.Y;
  FTranslateX := ATranslateX;
  FTranslateY := ATranslateY;
  if AViewBox.Width <> 0 then
    FScaleX := ATargetWidth / AViewBox.Width
  else
    FScaleX := 1;
  if AViewBox.Height <> 0 then
    FScaleY := ATargetHeight / AViewBox.Height
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
          Command := #0;
        end;
    else
      Break;
    end;
  end;

  SetLength(Result, FPoints.Count);
  for I := 0 to FPoints.Count - 1 do
    Result[I] := Point(Round(FPoints[I].X), Round(FPoints[I].Y));
end;

function TSvgPathParser.PeekToken: string;
begin
  Result := FTokens[FIndex];
end;

function TSvgPathParser.ReadNumber: Double;
begin
  Result := StrToFloatDef(NextToken, 0);
end;

{ TSvgBitmapRenderer }

class function TSvgBitmapRenderer.LoadFromFile(const AFileName: string; AWidth,
  AHeight: Integer): TBitmap;
var
  Xml: IXMLDocument;
  Root: IXMLNode;
  ViewBox: TSvgViewBox;
begin
  if AWidth <= 0 then
    AWidth := 1;
  if AHeight <= 0 then
    AHeight := 1;

  Result := TBitmap.Create;
  try
    Result.PixelFormat := pf32bit;
    Result.SetSize(AWidth, AHeight);
    Result.Canvas.Brush.Color := clWhite;
    Result.Canvas.FillRect(Rect(0, 0, Result.Width, Result.Height));

    Xml := TXMLDocument.Create(nil);
    LoadSvgXmlDocument(AFileName, Xml);
    Root := Xml.DocumentElement;
    ViewBox := ParseViewBox(GetNodeAttribute(Root, 'viewBox'), AWidth, AHeight);
    DrawPaths(Root, Result, ViewBox);
  except
    Result.Free;
    raise;
  end;
end;

end.
