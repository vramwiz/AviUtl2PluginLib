unit PmxMorph;

// モーフ係数のグループ展開と、頂点・ボーン変位の合成を担当する。

interface

uses
  PmxModel,
  PmxPoseTypes;

type
  TPmxMorphWeights = array of Single;
  TPmxVertexPositions = array of TPmxVector3;

// Modelのモーフ数に合わせ、全要素が0の係数配列を作る。
procedure InitializeMorphWeights(const Model: TPmxModel; var Weights: TPmxMorphWeights);
// 日本語名に一致するモーフIndexを返す。見つからない場合は-1を返す。
function FindMorphIndex(const Model: TPmxModel; const MorphName: string): Integer;
// グループ・フリップ参照を再帰展開し、実際に適用するモーフ別係数へ変換する。
procedure ResolveMorphWeights(const Model: TPmxModel; const Input: TPmxMorphWeights;
  var Effective: TPmxMorphWeights);
// 材質モーフを基礎材質のコピーへ適用する。共有Model自体は変更しない。
procedure ResolveMorphMaterials(const Model: TPmxModel;
  const Weights: TPmxMorphWeights; out Materials: TArray<TPmxMaterial>);
// 入力またはグループ・フリップ展開先に、指定表示枠の有効モーフがあればTrueを返す。
function MorphWeightsUsePanel(const Model: TPmxModel;
  const Weights: TPmxMorphWeights; Panel: Byte): Boolean;
// 係数を初期頂点位置と既存ローカル姿勢へ合成する。Model自体は変更しない。
procedure ApplyMorphs(const Model: TPmxModel; const Weights: TPmxMorphWeights;
  var Poses: TPmxBonePoses; var Positions: TPmxVertexPositions);

implementation

uses
  System.Math,
  System.SysUtils,
  PmxPoseMath;

type
  TExpansionStack = array of Boolean;

procedure ExpandMorph(const Model: TPmxModel; MorphIndex: Integer; Weight: Single;
  var Stack: TExpansionStack; var Effective: TPmxMorphWeights);
var
  Offset: TPmxGroupMorphOffset;
begin
  if Abs(Weight) <= 0.000001 then
    Exit;
  if Stack[MorphIndex] then
    raise EInvalidOpException.CreateFmt('PMX morph reference cycle at index %d',
      [MorphIndex]);
  if Model.Morphs[MorphIndex].MorphType in [pmtGroup, pmtFlip] then
  begin
    Stack[MorphIndex] := True;
    try
      for Offset in Model.Morphs[MorphIndex].GroupOffsets do
        ExpandMorph(Model, Offset.MorphIndex, Weight * Offset.Weight,
          Stack, Effective);
    finally
      Stack[MorphIndex] := False;
    end;
  end
  else
    Effective[MorphIndex] := Effective[MorphIndex] + Weight;
end;

procedure InitializeMorphWeights(const Model: TPmxModel; var Weights: TPmxMorphWeights);
begin
  SetLength(Weights, Length(Model.Morphs));
  if Length(Weights) > 0 then
    FillChar(Weights[0], Length(Weights) * SizeOf(Single), 0);
end;

function FindMorphIndex(const Model: TPmxModel; const MorphName: string): Integer;
begin
  for Result := 0 to High(Model.Morphs) do
    if SameText(Model.Morphs[Result].Name, MorphName) then
      Exit;
  Result := -1;
end;

procedure ResolveMorphWeights(const Model: TPmxModel; const Input: TPmxMorphWeights;
  var Effective: TPmxMorphWeights);
var
  I: Integer;
  Stack: TExpansionStack;
begin
  InitializeMorphWeights(Model, Effective);
  SetLength(Stack, Length(Model.Morphs));
  for I := 0 to Min(High(Input), High(Model.Morphs)) do
    ExpandMorph(Model, I, Input[I], Stack, Effective);
end;

function MorphMultiply(BaseValue, MorphValue, Weight: Single): Single;
begin
  Result := BaseValue * (1.0 + (MorphValue - 1.0) * Weight);
end;

procedure ApplyMaterialOffset(var Material: TPmxMaterial;
  const Offset: TPmxMaterialMorphOffset; Weight: Single);
begin
  if Offset.Operation = pmmoMultiply then
  begin
    Material.Diffuse.X := MorphMultiply(Material.Diffuse.X, Offset.Diffuse.X,
      Weight);
    Material.Diffuse.Y := MorphMultiply(Material.Diffuse.Y, Offset.Diffuse.Y,
      Weight);
    Material.Diffuse.Z := MorphMultiply(Material.Diffuse.Z, Offset.Diffuse.Z,
      Weight);
    Material.Diffuse.W := MorphMultiply(Material.Diffuse.W, Offset.Diffuse.W,
      Weight);
    Material.SpecularStrength := MorphMultiply(Material.SpecularStrength,
      Offset.SpecularStrength, Weight);
  end
  else
  begin
    Material.Diffuse.X := Material.Diffuse.X + Offset.Diffuse.X * Weight;
    Material.Diffuse.Y := Material.Diffuse.Y + Offset.Diffuse.Y * Weight;
    Material.Diffuse.Z := Material.Diffuse.Z + Offset.Diffuse.Z * Weight;
    Material.Diffuse.W := Material.Diffuse.W + Offset.Diffuse.W * Weight;
    Material.SpecularStrength := Material.SpecularStrength +
      Offset.SpecularStrength * Weight;
  end;
end;

procedure ResolveMorphMaterials(const Model: TPmxModel;
  const Weights: TPmxMorphWeights; out Materials: TArray<TPmxMaterial>);
var
  Effective: TPmxMorphWeights;
  I, MaterialIndex: Integer;
  Offset: TPmxMaterialMorphOffset;
begin
  if Model = nil then
  begin
    Materials := nil;
    Exit;
  end;
  Materials := Copy(Model.Materials);
  ResolveMorphWeights(Model, Weights, Effective);
  for I := 0 to High(Model.Morphs) do
    if (Model.Morphs[I].MorphType = pmtMaterial) and
      (Abs(Effective[I]) > 0.000001) then
      for Offset in Model.Morphs[I].MaterialOffsets do
        if Offset.MaterialIndex = -1 then
        begin
          for MaterialIndex := 0 to High(Materials) do
            ApplyMaterialOffset(Materials[MaterialIndex], Offset, Effective[I]);
        end
        else if Offset.MaterialIndex < Length(Materials) then
          ApplyMaterialOffset(Materials[Offset.MaterialIndex], Offset,
            Effective[I]);
end;

function MorphWeightsUsePanel(const Model: TPmxModel;
  const Weights: TPmxMorphWeights; Panel: Byte): Boolean;
var
  Effective: TPmxMorphWeights;
  I: Integer;
begin
  Result := False;
  if Model = nil then
    Exit;

  // グループ自身の表示枠も分類として扱う。
  for I := 0 to Min(High(Weights), High(Model.Morphs)) do
    if (Abs(Weights[I]) > 0.000001) and
      (Model.Morphs[I].Panel = Panel) then
      Exit(True);

  // 「その他」のグループから目・口モーフを参照する場合も占有扱いにする。
  ResolveMorphWeights(Model, Weights, Effective);
  for I := 0 to High(Effective) do
    if (Abs(Effective[I]) > 0.000001) and
      (Model.Morphs[I].Panel = Panel) then
      Exit(True);
end;

function MorphQuaternion(const Value: TPmxVector4): TPmxQuaternion;
begin
  Result.X := Value.X;
  Result.Y := Value.Y;
  Result.Z := Value.Z;
  Result.W := Value.W;
end;

procedure ApplyMorphs(const Model: TPmxModel; const Weights: TPmxMorphWeights;
  var Poses: TPmxBonePoses; var Positions: TPmxVertexPositions);
var
  BoneOffset: TPmxBoneMorphOffset;
  Effective: TPmxMorphWeights;
  I: Integer;
  Rotation: TPmxQuaternion;
  VertexOffset: TPmxVertexMorphOffset;
begin
  SetLength(Positions, Length(Model.Vertices));
  for I := 0 to High(Model.Vertices) do
    Positions[I] := Model.Vertices[I].Position;
  ResolveMorphWeights(Model, Weights, Effective);
  for I := 0 to High(Model.Morphs) do
    if Abs(Effective[I]) > 0.000001 then
    begin
      for VertexOffset in Model.Morphs[I].VertexOffsets do
        Positions[VertexOffset.VertexIndex] := AddVector(
          Positions[VertexOffset.VertexIndex],
          ScaleVector(VertexOffset.Offset, Effective[I]));
      for BoneOffset in Model.Morphs[I].BoneOffsets do
      begin
        if BoneOffset.BoneIndex >= Length(Poses) then
          Continue;
        Poses[BoneOffset.BoneIndex].Translation := AddVector(
          Poses[BoneOffset.BoneIndex].Translation,
          ScaleVector(BoneOffset.Translation, Effective[I]));
        Rotation := ScaleQuaternionRotation(MorphQuaternion(BoneOffset.Rotation),
          Effective[I]);
        Poses[BoneOffset.BoneIndex].Rotation := NormalizeQuaternion(
          MultiplyQuaternion(Poses[BoneOffset.BoneIndex].Rotation, Rotation));
      end;
    end;
end;

end.
