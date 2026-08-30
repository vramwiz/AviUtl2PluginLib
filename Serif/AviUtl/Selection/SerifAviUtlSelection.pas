unit SerifAviUtlSelection;


{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

// Syncroh2形式のセリフ入力オブジェクトを選択・再編集するAviUtl2境界。
// セリフ生成や一覧GUIを持たず、選択対象の識別と値更新だけを担当する。

interface

uses
  AviUtl2PluginTypes;

type
  TSerifAviUtl2Selection = record
    ObjectHandle: TObjectHandle;
    UID: string;
    Layer: Integer;
    FrameStart: Integer;
    FrameEnd: Integer;
  end;

// 選択中のSyncroh2セリフ入力から、再編集に必要な値と識別情報を取得する。
function SerifAviUtlGetSelected(out SerifText, Character,
  Emotion: string; out Selection: TSerifAviUtl2Selection): Boolean;

// 取得時と同じオブジェクトが現在も選択中なら、現在の配置位置を返す。
function SerifAviUtlResolveSelected(const Selection: TSerifAviUtl2Selection;
  out Layer, FrameStart, FrameEnd: Integer): Boolean;

// 選択中セリフと対応音声を、タイムライン上の尺を維持したまま更新する。
function SerifAviUtlUpdateSelected(const Selection: TSerifAviUtl2Selection;
  const PreferredWaveLayer: Integer; const OldWaveFileName,
  NewWaveFileName: string; const NewWaveLength: Double;
  const SerifText, Character, Emotion, Direction, AIUEO,
  LabText: string; out ActualWaveLayer: Integer): Boolean;

implementation

uses
  System.SysUtils,
  AviUtl2ObjectAliasValue,
  AviUtl2PluginCursorControl,
  AviUtl2PluginObjectFind,
  AviUtl2PluginObjectInfo,
  AviUtl2PluginObjectValue,
  AviUtl2TextUtils,
  SerifVoicevoxDebugLog,
  SerifAviUtlProfile;

procedure ClearSelection(out Selection: TSerifAviUtl2Selection);
begin
  Selection.ObjectHandle := nil;
  Selection.UID := '';
  Selection.Layer := -1;
  Selection.FrameStart := -1;
  Selection.FrameEnd := -1;
end;

function TryGetSerifObjectValues(const Obj: TObjectHandle;
  out SerifText, Character, Emotion: string;
  out Selection: TSerifAviUtl2Selection): Boolean;
var
  AliasLoaded: Boolean;
  AliasValue: TAviUtl2ObjectAliasValue;
  CharacterOk: Boolean;
  EmotionOk: Boolean;
  LogCharacter: string;
  LogEmotion: string;
  LogSerif: string;
  Profile: TSerifAviUtlProfile;
  SerifOk: Boolean;
begin
  ClearSelection(Selection);
  SerifText := '';
  Character := '';
  Emotion := '';
  if not Assigned(Obj) then
  begin
    VoicevoxDebugLog('Reedit library object=nil');
    Exit(False);
  end;
  AliasValue := TAviUtl2ObjectAliasValue.Create(VoicevoxDebugLog);
  try
    Profile := CurrentSerifAviUtlProfile;
    AliasLoaded := AliasValue.LoadFromAviUtl2Object(Obj);
    SerifOk := AliasLoaded and AliasValue.TryGetValue(Profile.SerifEffectName,
      Profile.SerifTextItem, SerifText);
    CharacterOk := AliasLoaded and AliasValue.TryGetValue(
      Profile.SerifEffectName, Profile.CharacterItem, Character);
    EmotionOk := AliasLoaded and AliasValue.TryGetValue(
      Profile.SerifEffectName, Profile.EmotionItem, Emotion);
    if AliasLoaded then
      AliasValue.TryGetValue(Profile.SerifEffectName, Profile.UIDItem,
        Selection.UID);
  finally
    AliasValue.Free;
  end;
  LogSerif := StringReplace(StringReplace(SerifText, #13, '\r',
    [rfReplaceAll]), #10, '\n', [rfReplaceAll]);
  LogCharacter := StringReplace(StringReplace(Character, #13, '\r',
    [rfReplaceAll]), #10, '\n', [rfReplaceAll]);
  LogEmotion := StringReplace(StringReplace(Emotion, #13, '\r',
    [rfReplaceAll]), #10, '\n', [rfReplaceAll]);
  VoicevoxDebugLog(Format(
    'Reedit library alias_loaded=%s object=%s serif_ok=%s char_ok=%s emotion_ok=%s serif="%s" char="%s" emotion="%s"',
    [BoolToStr(AliasLoaded, True),
     IntToHex(NativeUInt(Obj), SizeOf(Pointer) * 2),
     BoolToStr(SerifOk, True), BoolToStr(CharacterOk, True),
     BoolToStr(EmotionOk, True), LogSerif, LogCharacter, LogEmotion]));
  Result := SerifOk;
  if not Result then Exit;
  SerifText := AvrUtl2_AviUtlToStr(SerifText);
  Character := AvrUtl2_AviUtlToStr(Character);
  Emotion := AvrUtl2_AviUtlToStr(Emotion);
  if not AviUtl2GetObjectLayerFrame(Obj, Selection.Layer,
    Selection.FrameStart, Selection.FrameEnd) then Exit(False);
  Selection.ObjectHandle := Obj;
end;

function SerifAviUtlGetSelected(out SerifText, Character,
  Emotion: string; out Selection: TSerifAviUtl2Selection): Boolean;
var
  CursorObject: TObjectHandle;
  FocusObject: TObjectHandle;
  Index: Integer;
  Obj: TObjectHandle;
  SelectedCount: Integer;
begin
  Result := False;
  ClearSelection(Selection);
  SerifText := '';
  Character := '';
  Emotion := '';
  SelectedCount := AviUtl2FindObjectSelectedNum;
  FocusObject := AviUtl2FindObjectFocus;
  VoicevoxDebugLog(Format('Reedit library selected_count=%d focus=%s',
    [SelectedCount, IntToHex(NativeUInt(FocusObject),
      SizeOf(Pointer) * 2)]));

  if Assigned(FocusObject) and
    TryGetSerifObjectValues(FocusObject, SerifText, Character,
      Emotion, Selection) then
  begin
    VoicevoxDebugLog('Reedit library result=success source=focus');
    Exit(True);
  end;

  CursorObject := AviUtl2FindObjectCursor;
  if Assigned(CursorObject) and (CursorObject <> FocusObject) and
    TryGetSerifObjectValues(CursorObject, SerifText, Character,
      Emotion, Selection) then
  begin
    VoicevoxDebugLog('Reedit library result=success source=cursor');
    Exit(True);
  end;

  for Index := 0 to SelectedCount - 1 do
  begin
    Obj := AviUtl2FindObjectSelected(Index);
    if Obj = FocusObject then Continue;
    if TryGetSerifObjectValues(Obj, SerifText, Character, Emotion,
      Selection) then
    begin
      VoicevoxDebugLog(Format(
        'Reedit library result=success source=selected index=%d', [Index]));
      Exit(True);
    end;
  end;
  VoicevoxDebugLog('Reedit library result=failed reason=no serif effect');
end;

function SerifAviUtlResolveSelected(const Selection: TSerifAviUtl2Selection;
  out Layer, FrameStart, FrameEnd: Integer): Boolean;
var
  FocusObject: TObjectHandle;
  Index: Integer;
  Obj: TObjectHandle;
begin
  Result := False;
  Layer := -1;
  FrameStart := -1;
  FrameEnd := -1;
  if not Assigned(Selection.ObjectHandle) then Exit;

  FocusObject := AviUtl2FindObjectFocus;
  if FocusObject = Selection.ObjectHandle then
    Exit(AviUtl2GetObjectLayerFrame(FocusObject, Layer, FrameStart,
      FrameEnd));

  for Index := 0 to AviUtl2FindObjectSelectedNum - 1 do
  begin
    Obj := AviUtl2FindObjectSelected(Index);
    if Obj <> Selection.ObjectHandle then Continue;
    Exit(AviUtl2GetObjectLayerFrame(Obj, Layer, FrameStart, FrameEnd));
  end;
end;

function NormalizeFileNameForCompare(const FileName: string): string;
begin
  Result := Trim(FileName);
  if Result = '' then Exit;
  try
    Result := ExpandFileName(Result);
  except
    // 比較不能な古いパスでも元文字列による比較は続ける。
  end;
end;

function TryFindWaveObject(const SerifLayer, FrameStart,
  PreferredWaveLayer: Integer; const ExpectedFileName: string;
  out WaveObject: TObjectHandle; out WaveLayer: Integer): Boolean;
var
  CandidateLayers: array[0..2] of Integer;
  CurrentFileName: string;
  ExpectedNormalized: string;
  Index: Integer;
  Profile: TSerifAviUtlProfile;
begin
  Result := False;
  WaveObject := nil;
  WaveLayer := -1;
  CandidateLayers[0] := PreferredWaveLayer;
  CandidateLayers[1] := SerifLayer + 1;
  CandidateLayers[2] := SerifLayer - 1;
  ExpectedNormalized := NormalizeFileNameForCompare(ExpectedFileName);
  Profile := CurrentSerifAviUtlProfile;

  for Index := Low(CandidateLayers) to High(CandidateLayers) do
  begin
    if CandidateLayers[Index] < 0 then Continue;
    if (Index > Low(CandidateLayers)) and
      ((CandidateLayers[Index] = CandidateLayers[0]) or
       ((Index = High(CandidateLayers)) and
        (CandidateLayers[Index] = CandidateLayers[1]))) then Continue;
    WaveObject := AviUtl2FindObject(CandidateLayers[Index], FrameStart);
    if not Assigned(WaveObject) then Continue;
    if not AviUtl2GetObjectItemValue(WaveObject, Profile.AudioEffectName,
      Profile.AudioFileItem, CurrentFileName) then Continue;
    if (ExpectedNormalized <> '') and not SameText(
      NormalizeFileNameForCompare(CurrentFileName), ExpectedNormalized) then
      Continue;
    WaveLayer := CandidateLayers[Index];
    Exit(True);
  end;
  WaveObject := nil;
end;

function SerifAviUtlUpdateSelected(const Selection: TSerifAviUtl2Selection;
  const PreferredWaveLayer: Integer; const OldWaveFileName,
  NewWaveFileName: string; const NewWaveLength: Double;
  const SerifText, Character, Emotion, Direction, AIUEO,
  LabText: string; out ActualWaveLayer: Integer): Boolean;
var
  FrameEnd: Integer;
  FrameStart: Integer;
  Layer: Integer;
  PlaybackRange: string;
  Profile: TSerifAviUtlProfile;
  SerifObject: TObjectHandle;
  WaveObject: TObjectHandle;
begin
  Result := False;
  ActualWaveLayer := -1;
  if not SerifAviUtlResolveSelected(Selection, Layer, FrameStart,
    FrameEnd) then Exit;
  if not TryFindWaveObject(Layer, FrameStart, PreferredWaveLayer,
    OldWaveFileName, WaveObject, ActualWaveLayer) then Exit;
  Profile := CurrentSerifAviUtlProfile;

  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle,
    Profile.SerifEffectName, Profile.SerifTextItem, SerifText) then Exit;
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle,
    Profile.SerifEffectName, Profile.CharacterItem, Character) then Exit;
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle,
    Profile.SerifEffectName, Profile.EmotionItem, Emotion) then Exit;
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle,
    Profile.SerifEffectName, Profile.DirectionItem, Direction) then Exit;
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle,
    Profile.SerifEffectName, Profile.AiueoItem, AIUEO) then Exit;
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle,
    Profile.SerifEffectName, Profile.LabItem,
    AvrUtl2_StrToAviutl(LabText)) then Exit;

  PlaybackRange := '0.000,' + FloatToStr(NewWaveLength,
    TFormatSettings.Invariant) + ',再生範囲,0';
  if not AviUtl2SetObjectItemValue(WaveObject, Profile.AudioEffectName,
    Profile.AudioFileItem, NewWaveFileName) then Exit;
  if not AviUtl2SetObjectItemValue(WaveObject, Profile.AudioEffectName,
    Profile.AudioPlaybackItem, PlaybackRange) then Exit;

  SerifObject := AviUtl2FindObject(Layer, FrameStart);
  if Assigned(SerifObject) then
    AviUtl2CursorSetFocusObject(SerifObject);
  Result := True;
end;

end.
