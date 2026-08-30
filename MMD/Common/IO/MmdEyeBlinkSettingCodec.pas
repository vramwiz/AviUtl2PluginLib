unit MmdEyeBlinkSettingCodec;

// A model-independent, name-based eye-blink morph setting JSON codec.

interface

type
  TMmdEyeBlinkSetting = record
    MorphName: string;
    ClosedWeight: Single;
    IntervalSec: Double;
    SpeedSec: Double;
    OffsetSec: Double;
  end;

const
  DefaultMmdEyeBlinkIntervalSec = 4.0;
  DefaultMmdEyeBlinkSpeedSec = 0.1;
  DefaultMmdEyeBlinkOffsetSec = 0.0;
  EmptyMmdEyeBlinkSettingData =
    '{"version":2,"morph":"","closedWeight":0,"interval":4,"speed":0.1,"offset":0}';
  MmdEyeBlinkSettingTextLimit = 4096;

// Decode strict version 1 JSON. "none" is represented by an empty name and zero.
function TryDecodeMmdEyeBlinkSettingData(const Text: string;
  out Setting: TMmdEyeBlinkSetting): Boolean;
// Encode a normalized setting. An empty morph name always produces the empty value.
function EncodeMmdEyeBlinkSettingData(const MorphName: string;
  ClosedWeight: Single): string; overload;
function EncodeMmdEyeBlinkSettingData(const MorphName: string;
  ClosedWeight: Single; IntervalSec, SpeedSec, OffsetSec: Double): string;
  overload;

implementation

uses
  System.JSON,
  System.Math,
  System.SysUtils;

function TryDecodeMmdEyeBlinkSettingData(const Text: string;
  out Setting: TMmdEyeBlinkSetting): Boolean;
var
  IntervalValue, MorphValue, OffsetValue, Root, SpeedValue, VersionValue,
    WeightValue: TJSONValue;
  IntervalSec, OffsetSec, SpeedSec, Version, Weight: Double;
begin
  Result := False;
  Setting.MorphName := '';
  Setting.ClosedWeight := 0;
  Setting.IntervalSec := DefaultMmdEyeBlinkIntervalSec;
  Setting.SpeedSec := DefaultMmdEyeBlinkSpeedSec;
  Setting.OffsetSec := DefaultMmdEyeBlinkOffsetSec;
  try
    if (Text = '') or (Length(Text) > MmdEyeBlinkSettingTextLimit) then
      Exit;
    Root := TJSONObject.ParseJSONValue(Text);
    try
      if not (Root is TJSONObject) then
        Exit;
      VersionValue := TJSONObject(Root).GetValue('version');
      MorphValue := TJSONObject(Root).GetValue('morph');
      WeightValue := TJSONObject(Root).GetValue('closedWeight');
      if not (VersionValue is TJSONNumber) or
        not (MorphValue is TJSONString) or
        not (WeightValue is TJSONNumber) then
        Exit;
      Version := TJSONNumber(VersionValue).AsDouble;
      if (Version <> 1.0) and (Version <> 2.0) then
        Exit;
      Weight := TJSONNumber(WeightValue).AsDouble;
      if IsNan(Weight) or IsInfinite(Weight) or (Weight < 0.0) or
        (Weight > 1.0) then
        Exit;
      Setting.MorphName := TJSONString(MorphValue).Value;
      if (Setting.MorphName = '') and (Abs(Weight) > 0.000001) then
        Exit;
      Setting.ClosedWeight := Weight;
      if Version = 2.0 then
      begin
        IntervalValue := TJSONObject(Root).GetValue('interval');
        SpeedValue := TJSONObject(Root).GetValue('speed');
        OffsetValue := TJSONObject(Root).GetValue('offset');
        if not (IntervalValue is TJSONNumber) or
          not (SpeedValue is TJSONNumber) or
          not (OffsetValue is TJSONNumber) then
          Exit;
        IntervalSec := TJSONNumber(IntervalValue).AsDouble;
        SpeedSec := TJSONNumber(SpeedValue).AsDouble;
        OffsetSec := TJSONNumber(OffsetValue).AsDouble;
        if IsNan(IntervalSec) or IsInfinite(IntervalSec) or
          (IntervalSec < 1.0) or (IntervalSec > 20.0) or
          IsNan(SpeedSec) or IsInfinite(SpeedSec) or
          (SpeedSec < 0.01) or (SpeedSec > 100.0) or
          IsNan(OffsetSec) or IsInfinite(OffsetSec) or
          (OffsetSec < -20.0) or (OffsetSec > 20.0) then
          Exit;
        Setting.IntervalSec := IntervalSec;
        Setting.SpeedSec := SpeedSec;
        Setting.OffsetSec := OffsetSec;
      end;
      Result := True;
    finally
      Root.Free;
    end;
  except
    Setting.MorphName := '';
    Setting.ClosedWeight := 0;
    Setting.IntervalSec := DefaultMmdEyeBlinkIntervalSec;
    Setting.SpeedSec := DefaultMmdEyeBlinkSpeedSec;
    Setting.OffsetSec := DefaultMmdEyeBlinkOffsetSec;
  end;
end;

function EncodeMmdEyeBlinkSettingData(const MorphName: string;
  ClosedWeight: Single): string;
begin
  Result := EncodeMmdEyeBlinkSettingData(MorphName, ClosedWeight,
    DefaultMmdEyeBlinkIntervalSec, DefaultMmdEyeBlinkSpeedSec,
    DefaultMmdEyeBlinkOffsetSec);
end;

function EncodeMmdEyeBlinkSettingData(const MorphName: string;
  ClosedWeight: Single; IntervalSec, SpeedSec, OffsetSec: Double): string;
var
  Root: TJSONObject;
  Weight: Single;
begin
  Weight := EnsureRange(ClosedWeight, 0.0, 1.0);
  if IsNan(Weight) or IsInfinite(Weight) then
    Weight := 0;
  if MorphName = '' then
    Weight := 0;
  if IsNan(IntervalSec) or IsInfinite(IntervalSec) then
    IntervalSec := DefaultMmdEyeBlinkIntervalSec;
  if IsNan(SpeedSec) or IsInfinite(SpeedSec) then
    SpeedSec := DefaultMmdEyeBlinkSpeedSec;
  if IsNan(OffsetSec) or IsInfinite(OffsetSec) then
    OffsetSec := DefaultMmdEyeBlinkOffsetSec;
  IntervalSec := EnsureRange(IntervalSec, 1.0, 20.0);
  SpeedSec := EnsureRange(SpeedSec, 0.01, 100.0);
  OffsetSec := EnsureRange(OffsetSec, -20.0, 20.0);
  Root := TJSONObject.Create;
  try
    Root.AddPair('version', TJSONNumber.Create(2));
    Root.AddPair('morph', MorphName);
    Root.AddPair('closedWeight', TJSONNumber.Create(Weight));
    Root.AddPair('interval', TJSONNumber.Create(IntervalSec));
    Root.AddPair('speed', TJSONNumber.Create(SpeedSec));
    Root.AddPair('offset', TJSONNumber.Create(OffsetSec));
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

end.
