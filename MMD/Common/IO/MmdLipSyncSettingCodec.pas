unit MmdLipSyncSettingCodec;

// Model-independent mouth-open and phoneme morph assignment JSON codec.

interface

type
  TMmdLipSyncPhoneme = (mlpA, mlpI, mlpU, mlpE, mlpO, mlpN);
  TMmdLipSyncMorphSetting = record
    MorphName: string;
    Weight: Single;
  end;
  TMmdLipSyncSetting = record
    Initialized: Boolean;
    OpenClose: TMmdLipSyncMorphSetting;
    Phonemes: array[TMmdLipSyncPhoneme] of TMmdLipSyncMorphSetting;
    SpeedSec: Double;
    Strength: Single;
  end;

const
  DefaultMmdLipSyncSpeedSec = 0.1;
  DefaultMmdLipSyncStrength = 1.0;
  EmptyMmdLipSyncSettingData =
    '{"version":2,"initialized":false,' +
    '"openClose":{"morph":"","weight":0},' +
    '"phonemes":{"a":{"morph":"","weight":0},' +
    '"i":{"morph":"","weight":0},' +
    '"u":{"morph":"","weight":0},' +
    '"e":{"morph":"","weight":0},' +
    '"o":{"morph":"","weight":0},' +
    '"n":{"morph":"","weight":0}},"speed":0.1,"strength":1}';
  MmdLipSyncSettingTextLimit = 8192;

function DefaultMmdLipSyncSetting: TMmdLipSyncSetting;
function TryDecodeMmdLipSyncSettingData(const Text: string;
  out Setting: TMmdLipSyncSetting): Boolean;
function EncodeMmdLipSyncSettingData(
  const Setting: TMmdLipSyncSetting): string;

implementation

uses
  System.JSON,
  System.Math,
  System.SysUtils;

const
  PhonemeKeys: array[TMmdLipSyncPhoneme] of string =
    ('a', 'i', 'u', 'e', 'o', 'n');

function DefaultMmdLipSyncSetting: TMmdLipSyncSetting;
var
  Phoneme: TMmdLipSyncPhoneme;
begin
  Result.Initialized := False;
  Result.OpenClose.MorphName := '';
  Result.OpenClose.Weight := 0;
  for Phoneme := Low(TMmdLipSyncPhoneme) to High(TMmdLipSyncPhoneme) do
  begin
    Result.Phonemes[Phoneme].MorphName := '';
    Result.Phonemes[Phoneme].Weight := 0;
  end;
  Result.SpeedSec := DefaultMmdLipSyncSpeedSec;
  Result.Strength := DefaultMmdLipSyncStrength;
end;

function DecodeMorph(Value: TJSONValue;
  out Morph: TMmdLipSyncMorphSetting): Boolean;
var
  MorphValue, WeightValue: TJSONValue;
  Weight: Double;
begin
  Result := False;
  Morph.MorphName := '';
  Morph.Weight := 0;
  if not (Value is TJSONObject) then
    Exit;
  MorphValue := TJSONObject(Value).GetValue('morph');
  WeightValue := TJSONObject(Value).GetValue('weight');
  if not (MorphValue is TJSONString) or
    not (WeightValue is TJSONNumber) then
    Exit;
  Weight := TJSONNumber(WeightValue).AsDouble;
  if IsNan(Weight) or IsInfinite(Weight) or (Weight < 0.0) or
    (Weight > 1.0) then
    Exit;
  Morph.MorphName := TJSONString(MorphValue).Value;
  if (Morph.MorphName = '') and (Abs(Weight) > 0.000001) then
    Exit;
  Morph.Weight := Weight;
  Result := True;
end;

function TryDecodeMmdLipSyncSettingData(const Text: string;
  out Setting: TMmdLipSyncSetting): Boolean;
var
  InitializedValue, OpenCloseValue, PhonemesValue, Root, SpeedValue,
    StrengthValue, VersionValue: TJSONValue;
  Phoneme: TMmdLipSyncPhoneme;
  Speed, Strength, Version: Double;
  HasAssignedMorph: Boolean;
begin
  Result := False;
  Setting := DefaultMmdLipSyncSetting;
  try
    if (Text = '') or (Length(Text) > MmdLipSyncSettingTextLimit) then
      Exit;
    Root := TJSONObject.ParseJSONValue(Text);
    try
      if not (Root is TJSONObject) then
        Exit;
      VersionValue := TJSONObject(Root).GetValue('version');
      OpenCloseValue := TJSONObject(Root).GetValue('openClose');
      PhonemesValue := TJSONObject(Root).GetValue('phonemes');
      SpeedValue := TJSONObject(Root).GetValue('speed');
      StrengthValue := TJSONObject(Root).GetValue('strength');
      if not (VersionValue is TJSONNumber) or
        not (PhonemesValue is TJSONObject) or
        not (SpeedValue is TJSONNumber) or
        not (StrengthValue is TJSONNumber) or
        not DecodeMorph(OpenCloseValue, Setting.OpenClose) then
        Exit;
      Version := TJSONNumber(VersionValue).AsDouble;
      if (Version <> 1.0) and (Version <> 2.0) then
        Exit;
      if Version = 2.0 then
      begin
        InitializedValue := TJSONObject(Root).GetValue('initialized');
        if InitializedValue is TJSONTrue then
          Setting.Initialized := True
        else if InitializedValue is TJSONFalse then
          Setting.Initialized := False
        else
          Exit;
      end;
      HasAssignedMorph := Setting.OpenClose.MorphName <> '';
      for Phoneme := Low(TMmdLipSyncPhoneme) to High(TMmdLipSyncPhoneme) do
      begin
        if not DecodeMorph(TJSONObject(PhonemesValue).GetValue(
          PhonemeKeys[Phoneme]), Setting.Phonemes[Phoneme]) then
          Exit;
        HasAssignedMorph := HasAssignedMorph or
          (Setting.Phonemes[Phoneme].MorphName <> '');
      end;
      // Version 1 had no explicit state. Non-empty assignments were configured;
      // the all-empty value is treated as the pre-auto-assignment default.
      if Version = 1.0 then
        Setting.Initialized := HasAssignedMorph;
      Speed := TJSONNumber(SpeedValue).AsDouble;
      Strength := TJSONNumber(StrengthValue).AsDouble;
      if IsNan(Speed) or IsInfinite(Speed) or (Speed < 0.01) or
        (Speed > 100.0) or IsNan(Strength) or IsInfinite(Strength) or
        (Strength < 0.0) or (Strength > 1.0) then
        Exit;
      Setting.SpeedSec := Speed;
      Setting.Strength := Strength;
      Result := True;
    finally
      Root.Free;
    end;
  except
    Setting := DefaultMmdLipSyncSetting;
  end;
end;

function EncodeMorph(const Morph: TMmdLipSyncMorphSetting): TJSONObject;
var
  Weight: Single;
begin
  Weight := EnsureRange(Morph.Weight, 0.0, 1.0);
  if IsNan(Weight) or IsInfinite(Weight) or (Morph.MorphName = '') then
    Weight := 0;
  Result := TJSONObject.Create;
  Result.AddPair('morph', Morph.MorphName);
  Result.AddPair('weight', TJSONNumber.Create(Weight));
end;

function EncodeMmdLipSyncSettingData(
  const Setting: TMmdLipSyncSetting): string;
var
  Phonemes, Root: TJSONObject;
  Phoneme: TMmdLipSyncPhoneme;
  Speed, Strength: Double;
begin
  Speed := Setting.SpeedSec;
  if IsNan(Speed) or IsInfinite(Speed) then
    Speed := DefaultMmdLipSyncSpeedSec;
  Speed := EnsureRange(Speed, 0.01, 100.0);
  Strength := Setting.Strength;
  if IsNan(Strength) or IsInfinite(Strength) then
    Strength := DefaultMmdLipSyncStrength;
  Strength := EnsureRange(Strength, 0.0, 1.0);
  Root := TJSONObject.Create;
  try
    Root.AddPair('version', TJSONNumber.Create(2));
    Root.AddPair('initialized', TJSONBool.Create(Setting.Initialized));
    Root.AddPair('openClose', EncodeMorph(Setting.OpenClose));
    Phonemes := TJSONObject.Create;
    Root.AddPair('phonemes', Phonemes);
    for Phoneme := Low(TMmdLipSyncPhoneme) to High(TMmdLipSyncPhoneme) do
      Phonemes.AddPair(PhonemeKeys[Phoneme],
        EncodeMorph(Setting.Phonemes[Phoneme]));
    Root.AddPair('speed', TJSONNumber.Create(Speed));
    Root.AddPair('strength', TJSONNumber.Create(Strength));
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

end.
