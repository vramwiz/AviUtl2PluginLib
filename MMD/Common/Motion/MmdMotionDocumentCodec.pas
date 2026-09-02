unit MmdMotionDocumentCodec;

// MmdMotionDocumentと版付きUTF-8 JSONの相互変換・ファイル保存を担当する。

interface

uses
  MmdMotionDocument;

// 全トラックを版付きJSONに変換する。nilは空文字を返す。
function EncodeMmdMotionDocument(Document: TMmdMotionDocument): string;
// JSONを検証して編集可能な内部データへ復元する。失敗時はnil。
function TryDecodeMmdMotionDocument(const Data: string;
  out Document: TMmdMotionDocument): Boolean;
// 保存済みJSONを読み込み、検証済み内部データを返す。
function LoadMmdMotionDocument(const FileName: string;
  out Document: TMmdMotionDocument): Boolean;
// 内部データをUTF-8 JSONとして保存する。
function SaveMmdMotionDocument(const FileName: string;
  Document: TMmdMotionDocument): Boolean;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.Math,
  System.SysUtils,
  PmxPoseTypes;

const
  MaxMotionKeys = 2000000;

function NumberValue(Value: TJSONValue; out Number: Double): Boolean;
begin
  Result := Value is TJSONNumber;
  if not Result then Exit;
  Number := TJSONNumber(Value).AsDouble;
  Result := not IsNan(Number) and not IsInfinite(Number);
end;

function ReadSingle(Value: TJSONValue; out Number: Single): Boolean;
var
  Parsed: Double;
begin
  Result := NumberValue(Value, Parsed) and
    (Parsed >= -MaxSingle) and (Parsed <= MaxSingle);
  if Result then Number := Parsed;
end;

function ReadCardinal(Value: TJSONValue; out Number: Cardinal): Boolean;
var
  Parsed: Double;
begin
  Result := NumberValue(Value, Parsed) and (Parsed >= 0) and
    (Parsed <= High(Cardinal)) and (Frac(Parsed) = 0);
  if Result then Number := Trunc(Parsed);
end;

function EncodeCurve(const Curve: TMmdBezierCurve): TJSONArray;
begin
  Result := TJSONArray.Create;
  Result.Add(Curve.X1);
  Result.Add(Curve.Y1);
  Result.Add(Curve.X2);
  Result.Add(Curve.Y2);
end;

function DecodeCurve(Value: TJSONValue; out Curve: TMmdBezierCurve): Boolean;
var
  Array_: TJSONArray;
  I: Integer;
  Number: Cardinal;
  Values: array[0..3] of Byte;
begin
  Result := False;
  if not (Value is TJSONArray) then Exit;
  Array_ := TJSONArray(Value);
  if Array_.Count <> 4 then Exit;
  for I := 0 to 3 do
  begin
    if not ReadCardinal(Array_.Items[I], Number) or (Number > 127) then Exit;
    Values[I] := Number;
  end;
  Curve.X1 := Values[0];
  Curve.Y1 := Values[1];
  Curve.X2 := Values[2];
  Curve.Y2 := Values[3];
  Result := True;
end;

function EncodeVector(const X, Y, Z: Single): TJSONArray;
begin
  Result := TJSONArray.Create;
  Result.Add(X);
  Result.Add(Y);
  Result.Add(Z);
end;

function EncodeQuaternion(const Value: TPmxQuaternion): TJSONArray;
begin
  Result := TJSONArray.Create;
  Result.Add(Value.X);
  Result.Add(Value.Y);
  Result.Add(Value.Z);
  Result.Add(Value.W);
end;

function DecodeVector(Value: TJSONValue; out X, Y, Z: Single): Boolean;
var
  Array_: TJSONArray;
begin
  Result := Value is TJSONArray;
  if not Result then Exit;
  Array_ := TJSONArray(Value);
  Result := (Array_.Count = 3) and ReadSingle(Array_.Items[0], X) and
    ReadSingle(Array_.Items[1], Y) and ReadSingle(Array_.Items[2], Z);
end;

function DecodeQuaternion(Value: TJSONValue;
  out Rotation: TPmxQuaternion): Boolean;
var
  Array_: TJSONArray;
  LengthSquared, Scale: Double;
begin
  Result := Value is TJSONArray;
  if not Result then Exit;
  Array_ := TJSONArray(Value);
  Result := (Array_.Count = 4) and ReadSingle(Array_.Items[0], Rotation.X) and
    ReadSingle(Array_.Items[1], Rotation.Y) and
    ReadSingle(Array_.Items[2], Rotation.Z) and
    ReadSingle(Array_.Items[3], Rotation.W);
  if not Result then Exit;
  LengthSquared := Sqr(Rotation.X) + Sqr(Rotation.Y) + Sqr(Rotation.Z) +
    Sqr(Rotation.W);
  Result := LengthSquared > 0.000000000001;
  if not Result then Exit;
  Scale := 1 / Sqrt(LengthSquared);
  Rotation.X := Rotation.X * Scale;
  Rotation.Y := Rotation.Y * Scale;
  Rotation.Z := Rotation.Z * Scale;
  Rotation.W := Rotation.W * Scale;
end;

function EncodeBoneKey(const Key: TMmdMotionBoneKey): TJSONObject;
var
  Curves: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('frame', TJSONNumber.Create(Key.Frame));
  Result.AddPair('translation', EncodeVector(Key.Translation.X,
    Key.Translation.Y, Key.Translation.Z));
  Result.AddPair('rotation', EncodeQuaternion(Key.Rotation));
  Curves := TJSONObject.Create;
  Curves.AddPair('x', EncodeCurve(Key.TranslationXCurve));
  Curves.AddPair('y', EncodeCurve(Key.TranslationYCurve));
  Curves.AddPair('z', EncodeCurve(Key.TranslationZCurve));
  Curves.AddPair('rotation', EncodeCurve(Key.RotationCurve));
  Result.AddPair('curves', Curves);
end;

function DecodeBoneKey(Value: TJSONValue; out Key: TMmdMotionBoneKey): Boolean;
var
  Curves, KeyObject: TJSONObject;
begin
  Result := False;
  Key := Default(TMmdMotionBoneKey);
  if not (Value is TJSONObject) then Exit;
  KeyObject := TJSONObject(Value);
  Curves := KeyObject.GetValue<TJSONObject>('curves');
  Result := Assigned(Curves) and
    ReadCardinal(KeyObject.GetValue('frame'), Key.Frame) and
    DecodeVector(KeyObject.GetValue('translation'), Key.Translation.X,
      Key.Translation.Y, Key.Translation.Z) and
    DecodeQuaternion(KeyObject.GetValue('rotation'), Key.Rotation) and
    DecodeCurve(Curves.GetValue('x'), Key.TranslationXCurve) and
    DecodeCurve(Curves.GetValue('y'), Key.TranslationYCurve) and
    DecodeCurve(Curves.GetValue('z'), Key.TranslationZCurve) and
    DecodeCurve(Curves.GetValue('rotation'), Key.RotationCurve);
end;

function EncodeMmdMotionDocument(Document: TMmdMotionDocument): string;
var
  BoneKey: TMmdMotionBoneKey;
  BoneKeys, BoneTracks, MorphKeys, MorphTracks: TJSONArray;
  BoneTrack: TMmdMotionBoneTrack;
  MorphKey: TMmdMotionMorphKey;
  MorphTrack: TMmdMotionMorphTrack;
  KeyObject, Root, Track: TJSONObject;
begin
  Result := '';
  if not Assigned(Document) then Exit;
  Root := TJSONObject.Create;
  try
    Root.AddPair('version', TJSONNumber.Create(MmdMotionDocumentVersion));
    Root.AddPair('frameRate', TJSONNumber.Create(Document.FrameRate));
    Root.AddPair('modelName', Document.ModelName);
    BoneTracks := TJSONArray.Create;
    Root.AddPair('boneTracks', BoneTracks);
    for BoneTrack in Document.BoneTracks do
    begin
      Track := TJSONObject.Create;
      Track.AddPair('name', BoneTrack.Name);
      BoneKeys := TJSONArray.Create;
      Track.AddPair('keys', BoneKeys);
      for BoneKey in BoneTrack.Keys do BoneKeys.AddElement(EncodeBoneKey(BoneKey));
      BoneTracks.AddElement(Track);
    end;
    MorphTracks := TJSONArray.Create;
    Root.AddPair('morphTracks', MorphTracks);
    for MorphTrack in Document.MorphTracks do
    begin
      Track := TJSONObject.Create;
      Track.AddPair('name', MorphTrack.Name);
      MorphKeys := TJSONArray.Create;
      Track.AddPair('keys', MorphKeys);
      for MorphKey in MorphTrack.Keys do
      begin
        KeyObject := TJSONObject.Create;
        KeyObject.AddPair('frame', TJSONNumber.Create(MorphKey.Frame));
        KeyObject.AddPair('weight', TJSONNumber.Create(MorphKey.Weight));
        MorphKeys.AddElement(KeyObject);
      end;
      MorphTracks.AddElement(Track);
    end;
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function DecodeBoneTracks(Root: TJSONObject; Document: TMmdMotionDocument;
  var TotalKeys: Integer): Boolean;
var
  I, J: Integer;
  Key: TMmdMotionBoneKey;
  Keys, Tracks: TJSONArray;
  Name: string;
  Names: TDictionary<string, Byte>;
  Track: TMmdMotionBoneTrack;
  TrackObject: TJSONObject;
begin
  Result := False;
  Tracks := Root.GetValue<TJSONArray>('boneTracks');
  if not Assigned(Tracks) then Exit;
  Names := TDictionary<string, Byte>.Create;
  try
    for I := 0 to Tracks.Count - 1 do
    begin
      if not (Tracks.Items[I] is TJSONObject) then Exit;
      TrackObject := TJSONObject(Tracks.Items[I]);
      Name := TrackObject.GetValue<string>('name', '');
      Keys := TrackObject.GetValue<TJSONArray>('keys');
      if (Name = '') or Names.ContainsKey(Name) or not Assigned(Keys) or
        (Keys.Count = 0) or (TotalKeys + Keys.Count > MaxMotionKeys) then Exit;
      Names.Add(Name, 0);
      Track := TMmdMotionBoneTrack.Create(Name);
      Document.BoneTracks.Add(Track);
      for J := 0 to Keys.Count - 1 do
      begin
        if not DecodeBoneKey(Keys.Items[J], Key) or
          ((J > 0) and (Key.Frame < Track.Keys[J - 1].Frame)) then Exit;
        Track.Keys.Add(Key);
      end;
      Inc(TotalKeys, Keys.Count);
    end;
    Result := True;
  finally
    Names.Free;
  end;
end;

function DecodeMorphTracks(Root: TJSONObject; Document: TMmdMotionDocument;
  var TotalKeys: Integer): Boolean;
var
  I, J: Integer;
  Key: TMmdMotionMorphKey;
  KeyObject, TrackObject: TJSONObject;
  Keys, Tracks: TJSONArray;
  Name: string;
  Names: TDictionary<string, Byte>;
  Track: TMmdMotionMorphTrack;
begin
  Result := False;
  Tracks := Root.GetValue<TJSONArray>('morphTracks');
  if not Assigned(Tracks) then Exit;
  Names := TDictionary<string, Byte>.Create;
  try
    for I := 0 to Tracks.Count - 1 do
    begin
      if not (Tracks.Items[I] is TJSONObject) then Exit;
      TrackObject := TJSONObject(Tracks.Items[I]);
      Name := TrackObject.GetValue<string>('name', '');
      Keys := TrackObject.GetValue<TJSONArray>('keys');
      if (Name = '') or Names.ContainsKey(Name) or not Assigned(Keys) or
        (Keys.Count = 0) or (TotalKeys + Keys.Count > MaxMotionKeys) then Exit;
      Names.Add(Name, 0);
      Track := TMmdMotionMorphTrack.Create(Name);
      Document.MorphTracks.Add(Track);
      for J := 0 to Keys.Count - 1 do
      begin
        if not (Keys.Items[J] is TJSONObject) then Exit;
        KeyObject := TJSONObject(Keys.Items[J]);
        if not ReadCardinal(KeyObject.GetValue('frame'), Key.Frame) or
          not ReadSingle(KeyObject.GetValue('weight'), Key.Weight) or
          (Key.Weight < 0) or (Key.Weight > 1) or
          ((J > 0) and (Key.Frame < Track.Keys[J - 1].Frame)) then Exit;
        Track.Keys.Add(Key);
      end;
      Inc(TotalKeys, Keys.Count);
    end;
    Result := True;
  finally
    Names.Free;
  end;
end;

function TryDecodeMmdMotionDocument(const Data: string;
  out Document: TMmdMotionDocument): Boolean;
var
  FrameRate: Single;
  RootValue: TJSONValue;
  Root: TJSONObject;
  TotalKeys: Integer;
  Version: Cardinal;
begin
  Result := False;
  Document := nil;
  RootValue := nil;
  try
    try
      RootValue := TJSONObject.ParseJSONValue(Data);
      if not (RootValue is TJSONObject) then Exit;
      Root := TJSONObject(RootValue);
      if not ReadCardinal(Root.GetValue('version'), Version) or
        (Version <> MmdMotionDocumentVersion) or
        not ReadSingle(Root.GetValue('frameRate'), FrameRate) or
        (FrameRate <= 0) or (FrameRate > 1000) then Exit;
      Document := TMmdMotionDocument.Create;
      Document.FrameRate := FrameRate;
      Document.ModelName := Root.GetValue<string>('modelName', '');
      TotalKeys := 0;
      if not DecodeBoneTracks(Root, Document, TotalKeys) or
        not DecodeMorphTracks(Root, Document, TotalKeys) or
        (TotalKeys = 0) then Exit;
      Result := True;
    except
      Result := False;
    end;
  finally
    RootValue.Free;
    if not Result then FreeAndNil(Document);
  end;
end;

function LoadMmdMotionDocument(const FileName: string;
  out Document: TMmdMotionDocument): Boolean;
begin
  Document := nil;
  try
    Result := TFile.Exists(FileName) and TryDecodeMmdMotionDocument(
      TFile.ReadAllText(FileName, TEncoding.UTF8), Document);
  except
    FreeAndNil(Document);
    Result := False;
  end;
end;

function SaveMmdMotionDocument(const FileName: string;
  Document: TMmdMotionDocument): Boolean;
var
  Data: string;
begin
  Result := False;
  try
    Data := EncodeMmdMotionDocument(Document);
    if (Data = '') or not ForceDirectories(TPath.GetDirectoryName(FileName)) then Exit;
    TFile.WriteAllText(FileName, Data, TEncoding.UTF8);
    Result := True;
  except
    Result := False;
  end;
end;

end.
