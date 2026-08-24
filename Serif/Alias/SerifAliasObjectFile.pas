unit SerifAliasObjectFile;

interface

type
  TSerifAliasObjectFileParam = record
    FileName: string;
    TextColor: string;
    InnerEdgeColor: string;
    OuterEdgeColor: string;
  end;

procedure CreateSerifAliasObjectFile(const AFolder: string; const AParam: TSerifAliasObjectFileParam);
procedure CreateSerifAliasObjectFiles(const AFolder: string);

implementation

uses
  System.SysUtils, System.Classes, ALiasList;

type
  TCharaDef = record
    Name: string;
    TextColor: string;   // #RRGGBB
    EdgeColor1: string;  // #RRGGBB
    EdgeColor2: string;  // #RRGGBB
  end;

const
  CTextColorWhite = 'ffffff';
  CEdgeColorWhite = 'ffffff';
  CEdgeColorBlack = '000000';

const
  CHARA_DEFS: array[0..51] of TCharaDef = (
    (Name: '00_黒_文字色';   TextColor: '#000000'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '01_赤_文字色';   TextColor: '#FF8080'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '02_赤橙_文字色'; TextColor: '#FF9A66'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '03_橙_文字色';   TextColor: '#FFB366'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '04_黄橙_文字色'; TextColor: '#FFD166'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '05_黄_文字色';   TextColor: '#E6E66B'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '06_黄緑_文字色'; TextColor: '#B7D96D'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '07_緑_文字色';   TextColor: '#73C66D'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '08_青緑_文字色'; TextColor: '#66CDB3'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '09_青_文字色';   TextColor: '#6FA8FF'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '0A_青紫_文字色'; TextColor: '#8B80FF'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '0B_紫_文字色';   TextColor: '#B784E6'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '0C_赤紫_文字色'; TextColor: '#E67AB8'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),

    (Name: '10_白_文字色';   TextColor: '#FFFFFF'; EdgeColor1: '#000000'; EdgeColor2: '#000000'),
    (Name: '11_赤_縁1色';   TextColor: '#FFFFFF'; EdgeColor1: '#FF8080'; EdgeColor2: '#000000'),
    (Name: '12_赤橙_縁1色'; TextColor: '#FFFFFF'; EdgeColor1: '#FF9A66'; EdgeColor2: '#000000'),
    (Name: '13_橙_縁1色';   TextColor: '#FFFFFF'; EdgeColor1: '#FFB366'; EdgeColor2: '#000000'),
    (Name: '14_黄橙_縁1色'; TextColor: '#FFFFFF'; EdgeColor1: '#FFD166'; EdgeColor2: '#000000'),
    (Name: '15_黄_縁1色';   TextColor: '#FFFFFF'; EdgeColor1: '#E6E66B'; EdgeColor2: '#000000'),
    (Name: '16_黄緑_縁1色'; TextColor: '#FFFFFF'; EdgeColor1: '#B7D96D'; EdgeColor2: '#000000'),
    (Name: '17_緑_縁1色';   TextColor: '#FFFFFF'; EdgeColor1: '#73C66D'; EdgeColor2: '#000000'),
    (Name: '18_青緑_縁1色'; TextColor: '#FFFFFF'; EdgeColor1: '#66CDB3'; EdgeColor2: '#000000'),
    (Name: '19_青_縁1色';   TextColor: '#FFFFFF'; EdgeColor1: '#6FA8FF'; EdgeColor2: '#000000'),
    (Name: '1A_青紫_縁1色'; TextColor: '#FFFFFF'; EdgeColor1: '#8B80FF'; EdgeColor2: '#000000'),
    (Name: '1B_紫_縁1色';   TextColor: '#FFFFFF'; EdgeColor1: '#B784E6'; EdgeColor2: '#000000'),
    (Name: '1C_赤紫_縁1色'; TextColor: '#FFFFFF'; EdgeColor1: '#E67AB8'; EdgeColor2: '#000000'),

    (Name: '20_黒_文字色_縁反転';   TextColor: '#000000'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '21_赤_文字色_縁反転';   TextColor: '#FF8080'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '22_赤橙_文字色_縁反転'; TextColor: '#FF9A66'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '23_橙_文字色_縁反転';   TextColor: '#FFB366'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '24_黄橙_文字色_縁反転'; TextColor: '#FFD166'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '25_黄_文字色_縁反転';   TextColor: '#E6E66B'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '26_黄緑_文字色_縁反転'; TextColor: '#B7D96D'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '27_緑_文字色_縁反転';   TextColor: '#73C66D'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '28_青緑_文字色_縁反転'; TextColor: '#66CDB3'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '29_青_文字色_縁反転';   TextColor: '#6FA8FF'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '2A_青紫_文字色_縁反転'; TextColor: '#8B80FF'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '2B_紫_文字色_縁反転';   TextColor: '#B784E6'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),
    (Name: '2C_赤紫_文字色_縁反転'; TextColor: '#E67AB8'; EdgeColor1: '#000000'; EdgeColor2: '#FFFFFF'),

    (Name: '30_黒_文字縁外色';   TextColor: '#000000'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#000000'),
    (Name: '31_赤_文字縁外色';   TextColor: '#FF8080'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#FF8080'),
    (Name: '32_赤橙_文字縁外色'; TextColor: '#FF9A66'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#FF9A66'),
    (Name: '33_橙_文字縁外色';   TextColor: '#FFB366'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#FFB366'),
    (Name: '34_黄橙_文字縁外色'; TextColor: '#FFD166'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#FFD166'),
    (Name: '35_黄_文字縁外色';   TextColor: '#E6E66B'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#E6E66B'),
    (Name: '36_黄緑_文字縁外色'; TextColor: '#B7D96D'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#B7D96D'),
    (Name: '37_緑_文字縁外色';   TextColor: '#73C66D'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#73C66D'),
    (Name: '38_青緑_文字縁外色'; TextColor: '#66CDB3'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#66CDB3'),
    (Name: '39_青_文字縁外色';   TextColor: '#6FA8FF'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#6FA8FF'),
    (Name: '3A_青紫_文字縁外色'; TextColor: '#8B80FF'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#8B80FF'),
    (Name: '3B_紫_文字縁外色';   TextColor: '#B784E6'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#B784E6'),
    (Name: '3C_赤紫_文字縁外色'; TextColor: '#E67AB8'; EdgeColor1: '#FFFFFF'; EdgeColor2: '#E67AB8')
  );

function HexToRgbNoHash(const SHexColor: string): string;
begin
  Result := SHexColor.Trim;
  if (Result <> '') and (Result[1] = '#') then
    Delete(Result, 1, 1);
  Result := LowerCase(Result);
end;

function SanitizeFileName(const S: string): string;
const
  REMOVE_CHARS: array[0..11] of Char = ('\', '/', ':', '*', '?', '"', '<', '>', '|', '#', '.', '†');
var
  RemoveChar: Char;
begin
  Result := Trim(S);
  for RemoveChar in REMOVE_CHARS do
    Result := Result.Replace(RemoveChar, '', [rfReplaceAll]);
end;

procedure AddAliasParams(var AParams: TArray<TSerifAliasObjectFileParam>; const ACharas: array of TCharaDef);
var
  I: Integer;
  Param: TSerifAliasObjectFileParam;
begin
  for I := 0 to High(ACharas) do
  begin
    Param.FileName := SanitizeFileName(ACharas[I].Name) + '.object';
    Param.TextColor := HexToRgbNoHash(ACharas[I].TextColor);
    Param.InnerEdgeColor := HexToRgbNoHash(ACharas[I].EdgeColor1);
    Param.OuterEdgeColor := HexToRgbNoHash(ACharas[I].EdgeColor2);
    AParams := AParams + [Param];
  end;
end;

function BuildAliasParams: TArray<TSerifAliasObjectFileParam>;
begin
  Result := [];
  AddAliasParams(Result, CHARA_DEFS);
end;

function EscapeLuaString(const S: string): string;
begin
  Result := S.Replace('\', '\\', [rfReplaceAll]);
  Result := Result.Replace('"', '\"', [rfReplaceAll]);
end;

function BuildSerifScript(const ALayer: Integer; const AFileName: string): string;
begin
  Result := '<?\n';
  Result := Result + 'local layer=' + IntToStr(ALayer) + '\n';
  Result := Result + 'local filename="' + EscapeLuaString(AFileName) + '"\n\n';
  Result := Result + 'local func = obj.module("Syncroh2_Module")\n';
  //Result := Result + 'mes(func.get_text(layer));\n';
  Result := Result + 'mes(func.get_text(layer,obj.id,obj.frame));\n';
  Result := Result + '?>\n';
end;

procedure CreateSerifAliasObjectFile(const AFolder: string; const AParam: TSerifAliasObjectFileParam);
var
  AliasFolder: string;
  FileName: string;
  Lines: TStringList;
  Alias: TALiasList;
begin
  AliasFolder := IncludeTrailingPathDelimiter(AFolder);
  ForceDirectories(AliasFolder);

  FileName := AParam.FileName;
  if ExtractFileExt(FileName) = '' then
    FileName := FileName + '.object';
  FileName := AliasFolder + FileName;
  if FileExists(FileName) then
    Exit;

  Lines := TStringList.Create;
  Alias := TALiasList.Create;
  try
    Lines.Add('[0]');
    Lines.Add('layer=0');
    Lines.Add('frame=0,1712');
    Lines.Add('group=1');
    Lines.Add('[0.0]');
    Lines.Add('effect.name=テキスト');
    Lines.Add('サイズ=79.50');
    Lines.Add('字間=0.00');
    Lines.Add('行間=0.00');
    Lines.Add('表示速度=0.00');
    Lines.Add('フォント=ラノベPOP v2');
    Lines.Add('文字色=' + AParam.TextColor);
    Lines.Add('影・縁色=000000');
    Lines.Add('文字装飾=標準文字');
    Lines.Add('文字揃え=中央揃え[中]');
    Lines.Add('B=0');
    Lines.Add('I=0');
    Lines.Add('テキスト=' + BuildSerifScript(0, ChangeFileExt(ExtractFileName(FileName), '')));
    Lines.Add('文字毎に個別オブジェクト=0');
    Lines.Add('自動スクロール=0');
    Lines.Add('移動座標上に表示=0');
    Lines.Add('オブジェクトの長さを自動調節=0');
    Lines.Add('[0.1]');
    Lines.Add('effect.name=標準描画');
    Lines.Add('X=0.00');
    Lines.Add('Y=370.00');
    Lines.Add('Z=0.00');
    Lines.Add('Group=1');
    Lines.Add('中心X=0.00');
    Lines.Add('中心Y=0.00');
    Lines.Add('中心Z=0.00');
    Lines.Add('X軸回転=0.00');
    Lines.Add('Y軸回転=0.00');
    Lines.Add('Z軸回転=0.00');
    Lines.Add('拡大率=100.000');
    Lines.Add('縦横比=0.000');
    Lines.Add('透明度=0.00');
    Lines.Add('合成モード=通常');
    Lines.Add('[0.2]');
    Lines.Add('effect.name=縁取り');
    Lines.Add('サイズ=5');
    Lines.Add('ぼかし=5');
    Lines.Add('縁色=' + AParam.InnerEdgeColor);
    Lines.Add('パターン画像=');
    Lines.Add('[0.3]');
    Lines.Add('effect.name=縁取り');
    Lines.Add('サイズ=5');
    Lines.Add('ぼかし=5');
    Lines.Add('縁色=' + AParam.OuterEdgeColor);
    Lines.Add('パターン画像=');
    Lines.Add('[0.4]');
    Lines.Add('effect.name=ドロップシャドウ');
    Lines.Add('X=10');
    Lines.Add('Y=9');
    Lines.Add('濃さ=40.0');
    Lines.Add('拡散=10');
    Lines.Add('影色=000000');
    Lines.Add('影を別オブジェクトで描画=0');

    Alias.LoadFromStrings(Lines);
    Alias.SaveToAlias(FileName);
  finally
    Alias.Free;
    Lines.Free;
  end;
end;

procedure CreateSerifAliasObjectFiles(const AFolder: string);
var
  Params: TArray<TSerifAliasObjectFileParam>;
  Param: TSerifAliasObjectFileParam;
begin
  Params := BuildAliasParams;
  for Param in Params do
    CreateSerifAliasObjectFile(AFolder, Param);
end;

end.
