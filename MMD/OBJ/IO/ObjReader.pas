unit ObjReader;

// Wavefront OBJとMTLを静的アクセサリ用TPmxModelへ変換する。

interface

uses
  PmxModel;

// 頂点、UV、法線、多角形面、MTL材質とmap_Kdを読み込む。
// Dependenciesには実在有無にかかわらずMTLとテクスチャの解決済みパスを返す。
function LoadObjModel(const FileName: string; out Dependencies: TArray<string>):
  TPmxModel;
// 絶対パス単位の共有キャッシュから不変Modelを返し、未読込時だけOBJを解析する。
function GetCachedObjModel(const FileName: string): TPmxModel;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.Math,
  System.StrUtils,
  System.SysUtils,
  MtlReader;

var
  ModelCache: TObjectDictionary<string, TPmxModel>;
  ModelCacheLock: TObject;

function ParseFloat(const Value: string): Single;
begin
  if not TryStrToFloat(Value, Result, TFormatSettings.Invariant) then
    raise EConvertError.Create('Invalid OBJ number');
end;

function ResolveIndex(Value, Count: Integer): Integer;
begin
  if Value > 0 then Result := Value - 1
  else if Value < 0 then Result := Count + Value
  else Result := -1;
  if (Result < 0) or (Result >= Count) then
    raise ERangeError.Create('OBJ index is out of range');
end;

function FirstToken(const Line: string; out Rest: string): string;
var
  P: Integer;
begin
  P := 1;
  while (P <= Length(Line)) and not CharInSet(Line[P], [' ', #9]) do Inc(P);
  Result := Copy(Line, 1, P - 1);
  Rest := Trim(Copy(Line, P + 1, MaxInt));
end;

function CrossNormal(const A, B, C: TPmxVector3): TPmxVector3;
var
  L, X1, X2, Y1, Y2, Z1, Z2: Single;
begin
  X1 := B.X - A.X; Y1 := B.Y - A.Y; Z1 := B.Z - A.Z;
  X2 := C.X - A.X; Y2 := C.Y - A.Y; Z2 := C.Z - A.Z;
  Result.X := Y1 * Z2 - Z1 * Y2;
  Result.Y := Z1 * X2 - X1 * Z2;
  Result.Z := X1 * Y2 - Y1 * X2;
  L := Sqrt(Sqr(Result.X) + Sqr(Result.Y) + Sqr(Result.Z));
  if L > 1E-8 then
  begin
    Result.X := Result.X / L; Result.Y := Result.Y / L;
    Result.Z := Result.Z / L;
  end
  else Result.Z := 1;
end;

function LoadObjModel(const FileName: string;
  out Dependencies: TArray<string>): TPmxModel;
var
  CurrentMaterial: string;
  Def: TMtlMaterialDef;
  DependencyList, Lines: TStringList;
  Indices: TList<Integer>;
  Materials: TList<TPmxMaterial>;
  MaterialDefs: TDictionary<string, TMtlMaterialDef>;
  Normals, Positions: TList<TPmxVector3>;
  Textures: TStringList;
  UVs: TList<TPmxVector2>;
  Vertices: TList<TPmxVertex>;

  procedure EnsureBatch;
  var
    M: TPmxMaterial;
  begin
    if (Materials.Count > 0) and
      SameText(Materials[Materials.Count - 1].Name, CurrentMaterial) then Exit;
    M := Default(TPmxMaterial);
    M.Name := CurrentMaterial;
    M.Diffuse.X := 1; M.Diffuse.Y := 1; M.Diffuse.Z := 1; M.Diffuse.W := 1;
    M.TextureIndex := -1;
    M.SurfaceStart := Indices.Count;
    if MaterialDefs.TryGetValue(CurrentMaterial, Def) then
    begin
      M.Diffuse := Def.Diffuse;
      if Def.TextureFile <> '' then
      begin
        M.TextureIndex := Textures.IndexOf(Def.TextureFile);
        if M.TextureIndex < 0 then M.TextureIndex := Textures.Add(Def.TextureFile);
      end;
    end;
    Materials.Add(M);
  end;

  procedure AddTriangle(const A, B, C: string);
  var
    FaceNormal: TPmxVector3;
    M: TPmxMaterial;
    Refs: array[0..2] of TArray<string>;
    Tokens: array[0..2] of string;
    I, N, P, T: Integer;
    V: TPmxVertex;
  begin
    Tokens[0] := A; Tokens[1] := B; Tokens[2] := C;
    for I := 0 to 2 do Refs[I] := Tokens[I].Split(['/']);
    FaceNormal := CrossNormal(
      Positions[ResolveIndex(StrToInt(Refs[0][0]), Positions.Count)],
      Positions[ResolveIndex(StrToInt(Refs[1][0]), Positions.Count)],
      Positions[ResolveIndex(StrToInt(Refs[2][0]), Positions.Count)]);
    EnsureBatch;
    for I := 0 to 2 do
    begin
      V := Default(TPmxVertex);
      P := ResolveIndex(StrToInt(Refs[I][0]), Positions.Count);
      V.Position := Positions[P];
      V.Normal := FaceNormal;
      if (Length(Refs[I]) > 1) and (Refs[I][1] <> '') then
      begin
        T := ResolveIndex(StrToInt(Refs[I][1]), UVs.Count);
        V.UV := UVs[T]; V.UV.Y := 1 - V.UV.Y;
      end;
      if (Length(Refs[I]) > 2) and (Refs[I][2] <> '') then
      begin
        N := ResolveIndex(StrToInt(Refs[I][2]), Normals.Count);
        V.Normal := Normals[N];
      end;
      V.DeformType := pdtBdef1;
      V.BoneIndices[0] := -1;
      V.BoneWeights[0] := 1;
      Indices.Add(Vertices.Add(V));
    end;
    M := Materials[Materials.Count - 1];
    Inc(M.SurfaceCount, 3);
    Materials[Materials.Count - 1] := M;
  end;

var
  I, J: Integer;
  Line, RawLine, Rest: string;
  Parts: TArray<string>;
  V2: TPmxVector2;
  V3: TPmxVector3;
begin
  Dependencies := nil;
  if not TFile.Exists(FileName) then raise EFileNotFoundException.Create(FileName);
  Lines := TStringList.Create;
  DependencyList := TStringList.Create;
  MaterialDefs := TDictionary<string, TMtlMaterialDef>.Create;
  Positions := TList<TPmxVector3>.Create;
  Normals := TList<TPmxVector3>.Create;
  UVs := TList<TPmxVector2>.Create;
  Vertices := TList<TPmxVertex>.Create;
  Indices := TList<Integer>.Create;
  Materials := TList<TPmxMaterial>.Create;
  Textures := TStringList.Create;
  try
    DependencyList.CaseSensitive := False;
    DependencyList.Sorted := True;
    DependencyList.Duplicates := dupIgnore;
    Textures.CaseSensitive := False;
    Lines.LoadFromFile(FileName, TEncoding.UTF8);
    for RawLine in Lines do
    begin
      Line := Trim(RawLine);
      if SameText(FirstToken(Line, Rest), 'mtllib') and (Rest <> '') then
        LoadMtlMaterials(TPath.GetFullPath(TPath.Combine(TPath.GetDirectoryName(FileName),
          Rest)), MaterialDefs, DependencyList);
    end;
    CurrentMaterial := 'default';
    for RawLine in Lines do
    begin
      Line := Trim(RawLine);
      if (Line = '') or Line.StartsWith('#') then Continue;
      case IndexText(LowerCase(FirstToken(Line, Rest)),
        ['v', 'vn', 'vt', 'usemtl', 'f']) of
        0:
          begin
            Parts := Rest.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
            if Length(Parts) < 3 then raise EConvertError.Create('Invalid OBJ vertex');
            V3.X := ParseFloat(Parts[0]); V3.Y := ParseFloat(Parts[1]);
            V3.Z := ParseFloat(Parts[2]); Positions.Add(V3);
          end;
        1:
          begin
            Parts := Rest.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
            if Length(Parts) < 3 then raise EConvertError.Create('Invalid OBJ normal');
            V3.X := ParseFloat(Parts[0]); V3.Y := ParseFloat(Parts[1]);
            V3.Z := ParseFloat(Parts[2]); Normals.Add(V3);
          end;
        2:
          begin
            Parts := Rest.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
            if Length(Parts) < 2 then raise EConvertError.Create('Invalid OBJ UV');
            V2.X := ParseFloat(Parts[0]); V2.Y := ParseFloat(Parts[1]); UVs.Add(V2);
          end;
        3: CurrentMaterial := Rest;
        4:
          begin
            Parts := Rest.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
            if Length(Parts) < 3 then raise EConvertError.Create('Invalid OBJ face');
            for J := 1 to High(Parts) - 1 do AddTriangle(Parts[0], Parts[J], Parts[J + 1]);
          end;
      end;
    end;
    if (Vertices.Count = 0) or (Indices.Count = 0) then
      raise EConvertError.Create('OBJ has no faces');
    Result := TPmxModel.Create;
    Result.SourcePath := TPath.GetFullPath(FileName);
    Result.Name := TPath.GetFileNameWithoutExtension(FileName);
    Result.Vertices := Vertices.ToArray;
    Result.Indices := Indices.ToArray;
    Result.Materials := Materials.ToArray;
    Result.Textures := Textures.ToStringArray;
    SetLength(Result.TextureAvailable, Length(Result.Textures));
    for I := 0 to High(Result.Textures) do
      Result.TextureAvailable[I] := TFile.Exists(Result.Textures[I]);
    Dependencies := DependencyList.ToStringArray;
  finally
    Textures.Free; Materials.Free; Indices.Free; Vertices.Free;
    UVs.Free; Normals.Free; Positions.Free; MaterialDefs.Free;
    DependencyList.Free; Lines.Free;
  end;
end;

function GetCachedObjModel(const FileName: string): TPmxModel;
var
  CacheKey: string;
  Dependencies: TArray<string>;
begin
  CacheKey := LowerCase(TPath.GetFullPath(FileName));
  TMonitor.Enter(ModelCacheLock);
  try
    if not ModelCache.TryGetValue(CacheKey, Result) then
    begin
      Result := LoadObjModel(FileName, Dependencies);
      ModelCache.Add(CacheKey, Result);
    end;
  finally
    TMonitor.Exit(ModelCacheLock);
  end;
end;

initialization
  ModelCacheLock := TObject.Create;
  ModelCache := TObjectDictionary<string, TPmxModel>.Create([doOwnsValues]);

finalization
  ModelCache.Free;
  ModelCacheLock.Free;

end.
