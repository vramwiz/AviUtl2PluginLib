unit MtlReader;

// Wavefront MTLの基本材質と通常テクスチャ参照をOBJ Reader向けに解析する。

interface

uses
  System.Classes,
  System.Generics.Collections,
  PmxModel;

type
  // OBJ材質名に対応する拡散色と解決済み通常テクスチャパスを保持する。
  TMtlMaterialDef = record
    Diffuse: TPmxVector4;
    TextureFile: string;
  end;

// newmtl、Kd、d、Tr、map_Kdを読み込み、参照MTLとテクスチャをDependenciesへ加える。
procedure LoadMtlMaterials(const FileName: string;
  Materials: TDictionary<string, TMtlMaterialDef>; Dependencies: TStrings);

implementation

uses
  System.IOUtils,
  System.Math,
  System.StrUtils,
  System.SysUtils;

function FirstToken(const Line: string; out Rest: string): string;
var
  P: Integer;
begin
  P := 1;
  while (P <= Length(Line)) and not CharInSet(Line[P], [' ', #9]) do Inc(P);
  Result := Copy(Line, 1, P - 1);
  Rest := Trim(Copy(Line, P + 1, MaxInt));
end;

function ParseFloat(const Value: string): Single;
begin
  if not TryStrToFloat(Value, Result, TFormatSettings.Invariant) then
    raise EConvertError.Create('Invalid MTL number');
end;

procedure LoadMtlMaterials(const FileName: string;
  Materials: TDictionary<string, TMtlMaterialDef>; Dependencies: TStrings);
var
  Def: TMtlMaterialDef;
  Key, Line, RawLine, Rest: string;
  Lines: TStringList;
  Parts: TArray<string>;
  Value: Single;
begin
  Dependencies.Add(TPath.GetFullPath(FileName));
  if not TFile.Exists(FileName) then Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName, TEncoding.UTF8);
    Key := '';
    Def := Default(TMtlMaterialDef);
    Def.Diffuse.X := 1;
    Def.Diffuse.Y := 1;
    Def.Diffuse.Z := 1;
    Def.Diffuse.W := 1;
    for RawLine in Lines do
    begin
      Line := Trim(RawLine);
      if (Line = '') or Line.StartsWith('#') then Continue;
      case IndexText(LowerCase(FirstToken(Line, Rest)),
        ['newmtl', 'kd', 'd', 'tr', 'map_kd']) of
        0:
          begin
            if Key <> '' then Materials.AddOrSetValue(Key, Def);
            Key := Rest;
            Def := Default(TMtlMaterialDef);
            Def.Diffuse.X := 1;
            Def.Diffuse.Y := 1;
            Def.Diffuse.Z := 1;
            Def.Diffuse.W := 1;
          end;
        1:
          begin
            Parts := Rest.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
            if Length(Parts) >= 3 then
            begin
              Def.Diffuse.X := ParseFloat(Parts[0]);
              Def.Diffuse.Y := ParseFloat(Parts[1]);
              Def.Diffuse.Z := ParseFloat(Parts[2]);
            end;
          end;
        2:
          if TryStrToFloat(Rest, Value, TFormatSettings.Invariant) then
            Def.Diffuse.W := EnsureRange(Value, 0, 1);
        3:
          if TryStrToFloat(Rest, Value, TFormatSettings.Invariant) then
            Def.Diffuse.W := 1 - EnsureRange(Value, 0, 1);
        4:
          begin
            Def.TextureFile := TPath.GetFullPath(TPath.Combine(
              TPath.GetDirectoryName(FileName), Rest));
            Dependencies.Add(Def.TextureFile);
          end;
      end;
    end;
    if Key <> '' then Materials.AddOrSetValue(Key, Def);
  finally
    Lines.Free;
  end;
end;

end.
