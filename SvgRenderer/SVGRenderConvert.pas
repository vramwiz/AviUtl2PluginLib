unit SVGRenderConvert;

// SVGファイルをVectorRendererData形式へ変換して保存する。

interface

uses
  VectorRendererData;

type
  // SVGのpath要素をVectorRendererDataへ変換する。
  TSvgRenderConvert = class
  public
    // SVGファイルを読み込んでVectorRendererDataを生成する。
    class function LoadFromFile(const AFileName: string): TVectorRendererDataList;
    // SVGファイルを読み込んでVectorRendererData形式のファイルへ保存する。
    class procedure ConvertFileToFile(const ASvgFileName, AOutputFileName: string);
  end;

// SVG変換の診断ログファイル名を返す。
function SvgConvertLogFileName: string;

implementation

uses
  Winapi.Windows,
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  System.Variants,
  Vcl.Graphics,
  Xml.XMLDoc,
  Xml.XMLIntf;

// SVG変換の診断ログファイル名を返す。
function SvgConvertLogFileName: string;
begin
  Result := TPath.Combine(TPath.Combine(TPath.GetTempPath, 'Syncroh2\Temp'),
    'Syncroh2_SvgConvert.log');
end;

// ログ出力の失敗によってSVG変換を止めない。
procedure SvgConvertLog(const AText: string);
var
  Line: string;
begin
  Line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
    ' [SVGConvert] ' + AText + sLineBreak;
  OutputDebugString(PChar(Line));
  try
    ForceDirectories(TPath.GetDirectoryName(SvgConvertLogFileName));
    TFile.AppendAllText(SvgConvertLogFileName, Line, TEncoding.UTF8);
  except
    // 診断ログを書けない環境でも変換処理は継続する。
  end;
end;

type
  TSvgMatrix = record
    A: Double;
    B: Double;
    C: Double;
    D: Double;
    E: Double;
    F: Double;
  end;

// Delphi標準のTColor形式でRGB値を作成する。
function SvgRGB(ARed, AGreen, ABlue: Integer): TColor;
begin
  Result := ARed or (AGreen shl 8) or (ABlue shl 16);
end;

// ロケールに依存しない小数値を読み込む。
function SvgStrToFloatDef(const AValue: string; ADefault: Double): Double;
begin
  Result := StrToFloatDef(AValue, ADefault, TFormatSettings.Invariant);
end;

// 属性文字列から数値部分を読み込む。
function SvgAttributeToFloatDef(const AValue: string; ADefault: Double): Double;
var
  I: Integer;
  S: string;
begin
  S := '';
  for I := 1 to Length(AValue) do
  begin
    if CharInSet(AValue[I], ['0'..'9', '.', '-', '+', 'e', 'E']) then
      S := S + AValue[I]
    else if S <> '' then
      Break;
  end;
  Result := SvgStrToFloatDef(S, ADefault);
end;

// XMLノードの属性を文字列で取得する。
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

function SvgIdentityMatrix: TSvgMatrix;
begin
  Result.A := 1;
  Result.B := 0;
  Result.C := 0;
  Result.D := 1;
  Result.E := 0;
  Result.F := 0;
end;

function SvgMultiplyMatrix(const ALeft, ARight: TSvgMatrix): TSvgMatrix;
begin
  Result.A := ALeft.A * ARight.A + ALeft.C * ARight.B;
  Result.B := ALeft.B * ARight.A + ALeft.D * ARight.B;
  Result.C := ALeft.A * ARight.C + ALeft.C * ARight.D;
  Result.D := ALeft.B * ARight.C + ALeft.D * ARight.D;
  Result.E := ALeft.A * ARight.E + ALeft.C * ARight.F + ALeft.E;
  Result.F := ALeft.B * ARight.E + ALeft.D * ARight.F + ALeft.F;
end;

procedure ParseNumberList(const AValue: string; AValues: TStrings);
var
  I: Integer;
  Start: Integer;
  S: string;
begin
  AValues.Clear;
  S := StringReplace(AValue, ',', ' ', [rfReplaceAll]);
  I := 1;
  while I <= Length(S) do
  begin
    while (I <= Length(S)) and CharInSet(S[I], [' ', #9, #10, #13]) do
      Inc(I);
    Start := I;
    while (I <= Length(S)) and not CharInSet(S[I], [' ', #9, #10, #13]) do
      Inc(I);
    if Start < I then
      AValues.Add(Copy(S, Start, I - Start));
  end;
end;

function ParseTransformPart(const AName, AArgs: string): TSvgMatrix;
var
  Values: TStringList;
  X: Double;
  Y: Double;
begin
  Result := SvgIdentityMatrix;
  Values := TStringList.Create;
  try
    ParseNumberList(AArgs, Values);
    if SameText(AName, 'matrix') and (Values.Count >= 6) then
    begin
      Result.A := SvgStrToFloatDef(Values[0], 1);
      Result.B := SvgStrToFloatDef(Values[1], 0);
      Result.C := SvgStrToFloatDef(Values[2], 0);
      Result.D := SvgStrToFloatDef(Values[3], 1);
      Result.E := SvgStrToFloatDef(Values[4], 0);
      Result.F := SvgStrToFloatDef(Values[5], 0);
    end
    else if SameText(AName, 'translate') and (Values.Count >= 1) then
    begin
      Result.E := SvgStrToFloatDef(Values[0], 0);
      if Values.Count >= 2 then
        Result.F := SvgStrToFloatDef(Values[1], 0);
    end
    else if SameText(AName, 'scale') and (Values.Count >= 1) then
    begin
      X := SvgStrToFloatDef(Values[0], 1);
      Y := X;
      if Values.Count >= 2 then
        Y := SvgStrToFloatDef(Values[1], X);
      Result.A := X;
      Result.D := Y;
    end;
  finally
    Values.Free;
  end;
end;

function ParseTransformMatrix(const AValue: string): TSvgMatrix;
var
  I: Integer;
  NameStart: Integer;
  ArgsStart: Integer;
  Depth: Integer;
  Name: string;
  Args: string;
begin
  Result := SvgIdentityMatrix;
  I := 1;
  while I <= Length(AValue) do
  begin
    while (I <= Length(AValue)) and CharInSet(AValue[I], [' ', #9, #10, #13]) do
      Inc(I);
    NameStart := I;
    while (I <= Length(AValue)) and CharInSet(AValue[I], ['A'..'Z', 'a'..'z']) do
      Inc(I);
    Name := Copy(AValue, NameStart, I - NameStart);
    while (I <= Length(AValue)) and (AValue[I] <> '(') do
      Inc(I);
    if (Name = '') or (I > Length(AValue)) then
      Break;
    Inc(I);
    ArgsStart := I;
    Depth := 1;
    while (I <= Length(AValue)) and (Depth > 0) do
    begin
      if AValue[I] = '(' then
        Inc(Depth)
      else if AValue[I] = ')' then
        Dec(Depth);
      Inc(I);
    end;
    Args := Copy(AValue, ArgsStart, I - ArgsStart - 1);
    Result := SvgMultiplyMatrix(Result, ParseTransformPart(Name, Args));
  end;
end;

function ExtractStyleValue(const AStyle, AName: string): string;
var
  Parts: TStringList;
  I: Integer;
  P: Integer;
  Key: string;
begin
  Result := '';
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ';';
    Parts.DelimitedText := AStyle;
    for I := 0 to Parts.Count - 1 do
    begin
      P := Pos(':', Parts[I]);
      if P <= 0 then
        Continue;
      Key := Trim(Copy(Parts[I], 1, P - 1));
      if SameText(Key, AName) then
        Exit(Trim(Copy(Parts[I], P + 1, MaxInt)));
    end;
  finally
    Parts.Free;
  end;
end;

function ResolveFillSource(const ANode: IXMLNode; const AInheritedFill: string): string;
begin
  Result := GetNodeAttribute(ANode, 'fill');
  if Result = '' then
    Result := ExtractStyleValue(GetNodeAttribute(ANode, 'style'), 'fill');
  if Result = '' then
    Result := AInheritedFill;
end;

// SVG変換元に含まれる、見た目には透明な補助pathを判定する。
// 現在のベクターレンダラーはpath単位の半透明描画を持たないため、
// 透明度を無視して不透明に描くよりも、1%以下は描画しない方が原画に近い。
function IsEffectivelyTransparentFill(const ANode: IXMLNode): Boolean;
const
  TRANSPARENT_FILL_THRESHOLD = 0.01;
var
  OpacitySource: string;
  Opacity: Double;
begin
  OpacitySource := GetNodeAttribute(ANode, 'fill-opacity');
  if OpacitySource = '' then
    OpacitySource := ExtractStyleValue(GetNodeAttribute(ANode, 'style'),
      'fill-opacity');
  if OpacitySource = '' then
    Exit(False);

  Opacity := SvgStrToFloatDef(OpacitySource, 1);
  Result := Opacity <= TRANSPARENT_FILL_THRESHOLD;
end;

function SvgColorToColor(const AValue: string; ADefault: TColor): TColor; forward;

function ColorToSvgRGB(AColor: TColor): string;
begin
  Result := Format('rgb(%d,%d,%d)', [
    AColor and $FF,
    (AColor shr 8) and $FF,
    (AColor shr 16) and $FF]);
end;

function ExtractUrlId(const AValue: string): string;
var
  S: string;
  P1: Integer;
  P2: Integer;
begin
  Result := '';
  S := Trim(AValue);
  if Pos('url', LowerCase(S)) <> 1 then
    Exit;
  P1 := Pos('(#', S);
  P2 := Pos(')', S);
  if (P1 <= 0) or (P2 <= P1 + 2) then
    Exit;
  Result := Copy(S, P1 + 2, P2 - P1 - 2);
end;

procedure AddGradientColor(const AGradientNode: IXMLNode; AColors: TStrings);
var
  I: Integer;
  StopNode: IXMLNode;
  StopColor: string;
  Color: TColor;
  Red: Integer;
  Green: Integer;
  Blue: Integer;
  Count: Integer;
  GradientId: string;
begin
  GradientId := GetNodeAttribute(AGradientNode, 'id');
  if GradientId = '' then
    Exit;

  Red := 0;
  Green := 0;
  Blue := 0;
  Count := 0;
  for I := 0 to AGradientNode.ChildNodes.Count - 1 do
  begin
    StopNode := AGradientNode.ChildNodes[I];
    if not (SameText(StopNode.LocalName, 'stop') or
      SameText(StopNode.NodeName, 'stop')) then
      Continue;

    StopColor := GetNodeAttribute(StopNode, 'stop-color');
    if StopColor = '' then
      StopColor := ExtractStyleValue(GetNodeAttribute(StopNode, 'style'), 'stop-color');
    if StopColor = '' then
      Continue;

    Color := SvgColorToColor(StopColor, clNone);
    if Color = clNone then
      Continue;

    Inc(Red, Color and $FF);
    Inc(Green, (Color shr 8) and $FF);
    Inc(Blue, (Color shr 16) and $FF);
    Inc(Count);
  end;

  if Count > 0 then
    AColors.Values[GradientId] := ColorToSvgRGB(SvgRGB(
      Round(Red / Count),
      Round(Green / Count),
      Round(Blue / Count)));
end;

procedure CollectGradientColors(const ANode: IXMLNode; AColors: TStrings);
var
  I: Integer;
  Child: IXMLNode;
begin
  if not Assigned(ANode) then
    Exit;

  if SameText(ANode.LocalName, 'linearGradient') or
    SameText(ANode.NodeName, 'linearGradient') or
    SameText(ANode.LocalName, 'radialGradient') or
    SameText(ANode.NodeName, 'radialGradient') then
    AddGradientColor(ANode, AColors);

  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    Child := ANode.ChildNodes[I];
    if Child.HasChildNodes then
      CollectGradientColors(Child, AColors);
  end;
end;

function ResolveGradientFillSource(const AFillSource: string;
  AGradientColors: TStrings): string;
var
  GradientId: string;
begin
  Result := AFillSource;
  if not Assigned(AGradientColors) then
    Exit;
  GradientId := ExtractUrlId(AFillSource);
  if GradientId = '' then
    Exit;
  if AGradientColors.Values[GradientId] <> '' then
    Result := AGradientColors.Values[GradientId];
end;

// SVGのfill属性をTColorへ変換する。
function SvgColorToColor(const AValue: string; ADefault: TColor): TColor;
var
  S: string;                              // 変換対象の色文字列
  P1: Integer;                            // 開始括弧の位置
  P2: Integer;                            // 終了括弧の位置
  Values: TStringList;                    // rgb値の分割リスト
  R: Integer;                             // 赤成分
  G: Integer;                             // 緑成分
  B: Integer;                             // 青成分
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

// SVGのviewBox属性をRoot情報へ反映する。
procedure LoadViewBox(const AValue: string; ARoot: TVectorRendererRootItem);
var
  Values: TStringList;                    // viewBox値の分割リスト
  S: string;                              // 区切りを正規化したviewBox文字列
begin
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
      ARoot.ViewBoxX := SvgStrToFloatDef(Values[0], 0);
      ARoot.ViewBoxY := SvgStrToFloatDef(Values[1], 0);
      ARoot.ViewBoxWidth := SvgStrToFloatDef(Values[2], 0);
      ARoot.ViewBoxHeight := SvgStrToFloatDef(Values[3], 0);
    end;
  finally
    Values.Free;
  end;
end;

// translate属性をX/Y移動量へ分解する。
procedure ParseTranslate(const AValue: string; out AX, AY: Double);
var
  S: string;                              // 解析対象のtransform文字列
  P1: Integer;                            // 開始括弧の位置
  P2: Integer;                            // 終了括弧の位置
  Values: TStringList;                    // translate値の分割リスト
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
      AX := SvgStrToFloatDef(Values[0], 0);
    if Values.Count >= 2 then
      AY := SvgStrToFloatDef(Values[1], 0);
  finally
    Values.Free;
  end;
end;

// pathノードをDataListへ追加する。
procedure AddPathNode(const ANode: IXMLNode; AData: TVectorRendererDataList;
  const ATransform: TSvgMatrix; const AFillSource: string;
  AGradientColors: TStrings);
var
  Item: TVectorRendererElementItem;       // 追加するpath要素
  FillSource: string;                     // SVGのfill属性
  Transform: TSvgMatrix;
begin
  Transform := SvgMultiplyMatrix(ATransform,
    ParseTransformMatrix(GetNodeAttribute(ANode, 'transform')));
  Item := AData.AddElement;
  Item.Name := 'Path' + IntToStr(AData.Count);
  Item.SourceTransform := GetNodeAttribute(ANode, 'transform');
  Item.PathData := GetNodeAttribute(ANode, 'd');
  FillSource := ResolveGradientFillSource(ResolveFillSource(ANode, AFillSource),
    AGradientColors);
  Item.FillSource := FillSource;
  Item.FillColor := SvgColorToColor(FillSource, clBlack);
  if IsEffectivelyTransparentFill(ANode) then
    Item.FillColor := clNone;
  Item.TranslateX := 0;
  Item.TranslateY := 0;
  Item.MatrixA := Transform.A;
  Item.MatrixB := Transform.B;
  Item.MatrixC := Transform.C;
  Item.MatrixD := Transform.D;
  Item.MatrixE := Transform.E;
  Item.MatrixF := Transform.F;
end;

// 子ノードからpath要素を再帰的に収集する。
procedure LoadPathNodes(const ANode: IXMLNode; AData: TVectorRendererDataList;
  const ATransform: TSvgMatrix; const AFillSource: string;
  AGradientColors: TStrings);
var
  I: Integer;                             // 子ノードの走査位置
  Child: IXMLNode;                        // 現在の子ノード
  ChildTransform: TSvgMatrix;
  ChildFillSource: string;
begin
  if not Assigned(ANode) then
    Exit;
  ChildTransform := SvgMultiplyMatrix(ATransform,
    ParseTransformMatrix(GetNodeAttribute(ANode, 'transform')));
  ChildFillSource := ResolveGradientFillSource(ResolveFillSource(ANode,
    AFillSource), AGradientColors);
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    Child := ANode.ChildNodes[I];
    if SameText(Child.LocalName, 'path') or SameText(Child.NodeName, 'path') then
      AddPathNode(Child, AData, ChildTransform, ChildFillSource, AGradientColors);
    if Child.HasChildNodes then
      LoadPathNodes(Child, AData, ChildTransform, ChildFillSource, AGradientColors);
  end;
end;

procedure IncrementDiagnosticCount(AValues: TStrings; const AName: string);
var
  Count: Integer;
begin
  Count := StrToIntDef(AValues.Values[AName], 0);
  AValues.Values[AName] := IntToStr(Count + 1);
end;

function IsUnsupportedGraphicElement(const AName: string): Boolean;
begin
  Result := SameText(AName, 'rect') or SameText(AName, 'circle') or
    SameText(AName, 'ellipse') or SameText(AName, 'line') or
    SameText(AName, 'polyline') or SameText(AName, 'polygon') or
    SameText(AName, 'text') or SameText(AName, 'image') or
    SameText(AName, 'use');
end;

procedure CollectSvgDiagnostics(const ANode: IXMLNode;
  AUnsupportedElements, AUnsupportedCommands: TStrings;
  var AEmptyPathCount: Integer);
const
  SUPPORTED_PATH_LETTERS = 'MmLlCcZzEe';
var
  I: Integer;
  J: Integer;
  Child: IXMLNode;
  ElementName: string;
  PathData: string;
  C: Char;
begin
  if not Assigned(ANode) then Exit;
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    Child := ANode.ChildNodes[I];
    ElementName := Child.LocalName;
    if ElementName = '' then
      ElementName := Child.NodeName;
    if IsUnsupportedGraphicElement(ElementName) then
      IncrementDiagnosticCount(AUnsupportedElements, ElementName);
    if SameText(ElementName, 'path') then
    begin
      PathData := GetNodeAttribute(Child, 'd');
      if Trim(PathData) = '' then
        Inc(AEmptyPathCount)
      else
        for J := 1 to Length(PathData) do
        begin
          C := PathData[J];
          if CharInSet(C, ['A'..'Z', 'a'..'z']) and
            (Pos(C, SUPPORTED_PATH_LETTERS) = 0) and
            (AUnsupportedCommands.IndexOf(C) < 0) then
            AUnsupportedCommands.Add(C);
        end;
    end;
    if Child.HasChildNodes then
      CollectSvgDiagnostics(Child, AUnsupportedElements,
        AUnsupportedCommands, AEmptyPathCount);
  end;
end;

function DiagnosticListText(AList: TStrings): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to AList.Count - 1 do
  begin
    if Result <> '' then Result := Result + ',';
    Result := Result + AList[I];
  end;
  if Result = '' then Result := 'none';
end;

function BuildSvgDiagnostics(const ARootNode: IXMLNode;
  AData: TVectorRendererDataList): string;
var
  EmptyPathCount: Integer;
  UnsupportedCommands: TStringList;
  UnsupportedElements: TStringList;
begin
  UnsupportedElements := TStringList.Create;
  UnsupportedCommands := TStringList.Create;
  try
    UnsupportedElements.NameValueSeparator := '=';
    UnsupportedElements.Sorted := True;
    UnsupportedCommands.Sorted := True;
    UnsupportedCommands.Duplicates := dupIgnore;
    EmptyPathCount := 0;
    CollectSvgDiagnostics(ARootNode, UnsupportedElements,
      UnsupportedCommands, EmptyPathCount);
    Result := Format(
      'width=%d height=%d viewBox=%g,%g,%g,%g paths=%d empty-paths=%d ' +
      'unsupported-elements=%s unsupported-path-commands=%s',
      [AData.Root.Width, AData.Root.Height, AData.Root.ViewBoxX,
       AData.Root.ViewBoxY, AData.Root.ViewBoxWidth, AData.Root.ViewBoxHeight,
       AData.Count, EmptyPathCount, DiagnosticListText(UnsupportedElements),
       DiagnosticListText(UnsupportedCommands)]);
  finally
    UnsupportedCommands.Free;
    UnsupportedElements.Free;
  end;
end;

{ TSvgRenderConvert }

// SVGファイルを読み込んでVectorRendererData形式のファイルへ保存する。
class procedure TSvgRenderConvert.ConvertFileToFile(const ASvgFileName,
  AOutputFileName: string);
var
  Data: TVectorRendererDataList;          // 変換後のベクターデータ
  Stage: string;
begin
  Data := nil;
  Stage := 'source-info';
  try
    try
      SvgConvertLog(Format('start source="%s" output="%s" source-size=%d',
        [ASvgFileName, AOutputFileName, TFile.GetSize(ASvgFileName)]));
      Stage := 'load-svg';
      Data := LoadFromFile(ASvgFileName);
      Stage := 'save-ini';
      Data.Filename := AOutputFileName;
      Data.SaveToFile;
      SvgConvertLog(Format(
        'success source="%s" output="%s" paths=%d output-size=%d',
        [ASvgFileName, AOutputFileName, Data.Count,
         TFile.GetSize(AOutputFileName)]));
    except
      on E: Exception do
      begin
        SvgConvertLog(Format(
          'failure stage=%s source="%s" output="%s" exception=%s message="%s"',
          [Stage, ASvgFileName, AOutputFileName, E.ClassName, E.Message]));
        raise;
      end;
    end;
  finally
    Data.Free;
  end;
end;

// SVGファイルを読み込んでVectorRendererDataを生成する。
class function TSvgRenderConvert.LoadFromFile(
  const AFileName: string): TVectorRendererDataList;
var
  Xml: IXMLDocument;                      // 読み込むSVG XML
  RootNode: IXMLNode;                     // SVGのルートノード
  GradientColors: TStringList;            // gradient参照を単色化する対応表
  Stage: string;
begin
  Result := TVectorRendererDataList.Create;
  Stage := 'load-xml';
  try
    Xml := TXMLDocument.Create(nil);
    LoadSvgXmlDocument(AFileName, Xml);
    Stage := 'read-root';
    RootNode := Xml.DocumentElement;
    if not Assigned(RootNode) then
      raise Exception.Create('SVG root element was not found');
    Result.Root.Width := Round(SvgAttributeToFloatDef(GetNodeAttribute(RootNode, 'width'), 0));
    Result.Root.Height := Round(SvgAttributeToFloatDef(GetNodeAttribute(RootNode, 'height'), 0));
    Result.Root.PreserveAspectRatio := GetNodeAttribute(RootNode, 'preserveAspectRatio');
    LoadViewBox(GetNodeAttribute(RootNode, 'viewBox'), Result.Root);
    GradientColors := TStringList.Create;
    try
      Stage := 'collect-gradients';
      GradientColors.NameValueSeparator := '=';
      CollectGradientColors(RootNode, GradientColors);
      Stage := 'collect-paths';
      LoadPathNodes(RootNode, Result, SvgIdentityMatrix, '', GradientColors);
    finally
      GradientColors.Free;
    end;
    SvgConvertLog(Format('parsed source="%s" %s',
      [AFileName, BuildSvgDiagnostics(RootNode, Result)]));
  except
    on E: Exception do
    begin
      SvgConvertLog(Format(
        'parse-failure stage=%s source="%s" exception=%s message="%s"',
        [Stage, AFileName, E.ClassName, E.Message]));
      Result.Free;
      raise;
    end;
  end;
end;

initialization
  SvgConvertLog('session begin');

finalization
  SvgConvertLog('session end');

end.
