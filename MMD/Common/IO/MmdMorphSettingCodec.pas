unit MmdMorphSettingCodec;

// Versioned JSON codec for model-independent, name-based morph weights.

interface

uses
  PmxModel,
  PmxMorph;

type
  TMmdNamedMorphWeight = record
    Name: string;
    Weight: Single;
  end;
  TMmdNamedMorphWeights = array of TMmdNamedMorphWeight;

const
  EmptyMmdMorphSettingData = '{"version":1,"morphs":[]}';
  MmdMorphSettingTextLimit = 16384;

// Decode strict version 1 JSON. Invalid values, duplicates, and unknown versions fail.
function TryDecodeMmdMorphSettingData(const Text: string;
  out Values: TMmdNamedMorphWeights): Boolean;
// Encode only non-zero weights using the corresponding PMX morph names.
function EncodeMmdMorphSettingData(const Model: TPmxModel;
  const Weights: TPmxMorphWeights): string;
// Resolve names against Model and build a model-sized weight array.
function ApplyMmdNamedMorphWeights(const Model: TPmxModel;
  const Values: TMmdNamedMorphWeights; out Weights: TPmxMorphWeights): Boolean;

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.Math,
  System.SysUtils;

function IsDuplicateName(const Values: TMmdNamedMorphWeights;
  Count: Integer; const Name: string): Boolean;
var
  Index: Integer;
begin
  for Index := 0 to Count - 1 do
    if SameText(Values[Index].Name, Name) then
      Exit(True);
  Result := False;
end;

function TryDecodeMmdMorphSettingData(const Text: string;
  out Values: TMmdNamedMorphWeights): Boolean;
var
  Entry: TJSONObject;
  Index: Integer;
  Items: TJSONArray;
  NameValue, VersionValue, WeightValue: TJSONValue;
  Root: TJSONValue;
  Weight: Double;
begin
  Result := False;
  Values := nil;
  try
    if (Text = '') or (Length(Text) > MmdMorphSettingTextLimit) then
      Exit;
    Root := TJSONObject.ParseJSONValue(Text);
    try
      if not (Root is TJSONObject) then
        Exit;
      VersionValue := TJSONObject(Root).GetValue('version');
      if not (VersionValue is TJSONNumber) or
        (TJSONNumber(VersionValue).AsDouble <> 1.0) then
        Exit;
      Items := TJSONObject(Root).GetValue<TJSONArray>('morphs');
      if Items = nil then
        Exit;
      SetLength(Values, Items.Count);
      for Index := 0 to Items.Count - 1 do
      begin
        if not (Items.Items[Index] is TJSONObject) then
          Exit;
        Entry := TJSONObject(Items.Items[Index]);
        NameValue := Entry.GetValue('name');
        WeightValue := Entry.GetValue('weight');
        if not (NameValue is TJSONString) or
          (TJSONString(NameValue).Value = '') or
          not (WeightValue is TJSONNumber) then
          Exit;
        Weight := TJSONNumber(WeightValue).AsDouble;
        if IsNan(Weight) or IsInfinite(Weight) or (Weight < 0.0) or
          (Weight > 1.0) or IsDuplicateName(Values, Index,
            TJSONString(NameValue).Value) then
          Exit;
        Values[Index].Name := TJSONString(NameValue).Value;
        Values[Index].Weight := Weight;
      end;
      Result := True;
    finally
      Root.Free;
    end;
  except
    Values := nil;
  end;
  if not Result then
    Values := nil;
end;

function EncodeMmdMorphSettingData(const Model: TPmxModel;
  const Weights: TPmxMorphWeights): string;
var
  Entry, Root: TJSONObject;
  Index: Integer;
  Items: TJSONArray;
  Weight: Single;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('version', TJSONNumber.Create(1));
    Items := TJSONArray.Create;
    Root.AddPair('morphs', Items);
    if Model <> nil then
      for Index := 0 to Min(High(Model.Morphs), High(Weights)) do
      begin
        Weight := EnsureRange(Weights[Index], 0.0, 1.0);
        if IsNan(Weight) or IsInfinite(Weight) then
          Continue;
        if Abs(Weight) <= 0.000001 then
          Continue;
        Entry := TJSONObject.Create;
        Entry.AddPair('name', Model.Morphs[Index].Name);
        Entry.AddPair('weight', TJSONNumber.Create(Weight));
        Items.AddElement(Entry);
      end;
    Result := Root.ToJSON;
    if Length(Result) > MmdMorphSettingTextLimit then
      raise EArgumentException.Create(
        'Initial expression data exceeds the AviUtl2 string limit');
  finally
    Root.Free;
  end;
end;

function ApplyMmdNamedMorphWeights(const Model: TPmxModel;
  const Values: TMmdNamedMorphWeights; out Weights: TPmxMorphWeights): Boolean;
var
  Index: Integer;
  Value: TMmdNamedMorphWeight;
begin
  Result := False;
  Weights := nil;
  if Model = nil then
    Exit;
  InitializeMorphWeights(Model, Weights);
  for Value in Values do
  begin
    Index := FindMorphIndex(Model, Value.Name);
    if Index < 0 then
      Continue;
    Weights[Index] := EnsureRange(Value.Weight, 0.0, 1.0);
    Result := Result or (Weights[Index] > 0.000001);
  end;
end;

end.
