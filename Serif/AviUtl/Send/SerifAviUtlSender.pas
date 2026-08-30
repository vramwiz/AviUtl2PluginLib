unit SerifAviUtlSender;

interface

uses SerifCharaList, SerifSceneMsgList, SerifConfig;

function SendSerifMessages(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem; Send: Boolean): string;
function SendSerifMessagesNow(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem): Boolean;
function SendSerifMessagesContinuous(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem): Boolean;
procedure ResetSerifContinuousSend;

implementation

uses System.SysUtils, System.Math, AviUtl2PluginTypes,
     AviUtl2TimeConvert, AviUtl2PluginCursorControl,
     SerifAviUtlObjectCreate, AviUtl2PluginObjectFind,
     AviUtl2PluginObjectInfo, AviUtl2PluginScene, AviUtl2TextUtils,
     SerifVoicevoxDebugLog, SerifAviUtlAliasProvider, SerifAviUtlTimeline;

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

var
  GBaseLayer: Integer;
  GSceneId: Integer;

type
  TSerifContinuousSendState = record
    Valid: Boolean;
    ProjectFolder: string;
    SceneId: Integer;
    CursorFrame: Integer;
    CursorLayer: Integer;
    NextFrame: Integer;
    LastUID: string;
    LastLayer: Integer;
    LastFrameStart: Integer;
    LastFrameEnd: Integer;
  end;

var
  GContinuousSend: TSerifContinuousSendState;

procedure ResetSerifContinuousSend;
begin
  Finalize(GContinuousSend);
  FillChar(GContinuousSend, SizeOf(GContinuousSend), 0);
  GContinuousSend.CursorFrame := -1;
  GContinuousSend.CursorLayer := -1;
  GContinuousSend.NextFrame := -1;
  GContinuousSend.LastLayer := -1;
  GContinuousSend.LastFrameStart := -1;
  GContinuousSend.LastFrameEnd := -1;
end;

function ContinuousSendMatches(const ProjectFolder: string;
  const SceneId, CursorFrame, CursorLayer: Integer): Boolean;
var
  FrameEnd: Integer;
  FrameStart: Integer;
  Layer: Integer;
  Obj: TObjectHandle;
begin
  Result := False;
  if not GContinuousSend.Valid then Exit;
  if not SameText(ExcludeTrailingPathDelimiter(ProjectFolder),
    ExcludeTrailingPathDelimiter(GContinuousSend.ProjectFolder)) then Exit;
  if SceneId <> GContinuousSend.SceneId then Exit;
  if CursorFrame <> GContinuousSend.CursorFrame then Exit;
  if CursorLayer <> GContinuousSend.CursorLayer then Exit;

  Obj := AviUtl2FindObject(GContinuousSend.LastLayer,
    GContinuousSend.LastFrameStart);
  if Obj = nil then Exit;
  if not AviUtl2GetObjectLayerFrame(Obj, Layer, FrameStart, FrameEnd) then Exit;
  if (Layer <> GContinuousSend.LastLayer) or
    (FrameStart <> GContinuousSend.LastFrameStart) or
    (FrameEnd <> GContinuousSend.LastFrameEnd) then Exit;
  Result := SameText(SerifAviUtlGetUID(Layer, FrameStart),
    GContinuousSend.LastUID);
end;

procedure SetBaseLayer(const Layer: Integer);
begin
  if (GBaseLayer = -1) or (GBaseLayer > Layer) then
    GBaseLayer := Layer;
end;

function NormalizeDirectionValue(const Value: string): Integer;
begin
  Result := -1;
end;

procedure CreateAudioObject(const ProjectFolder: string;
  Msg: TSerifSceneMsgItem; Chara: TSerifCharaItem;
  StartFrame, LenFrame, Group: Integer);
var
  AliasData: TSerifAviUtlAudioAliasData;
begin
  AliasData := Default(TSerifAviUtlAudioAliasData);
  AliasData.FileName := ProjectFolder + Msg.FileNameWave;
  AliasData.Layer := Chara.LayerWave;
  AliasData.StartPos := 0;
  AliasData.EndPos := Msg.WaveLength;
  AliasData.FrameStart := StartFrame;
  AliasData.FrameLength := LenFrame;
  AliasData.Group := Group;
  AliasData.Volume := Chara.Volume;
  AliasData.Pan := Chara.Pan;
  AddSerifAviUtlAudioAlias(AliasData);
  SetBaseLayer(AliasData.Layer);
end;

procedure CreateSerifObject(Msg: TSerifSceneMsgItem;
  Chara: TSerifCharaItem; StartFrame, LenFrame, NextFrame, NextSpace,
  Group: Integer; Send: Boolean; const LabText: string);
var
  AliasData: TSerifAviUtlInputAliasData;
  FrameEnd: Integer;
begin
  AliasData := Default(TSerifAviUtlInputAliasData);
  AliasData.Character := Chara.Name;
  AliasData.Emotion := Msg.Emotion;
  AliasData.Direction := NormalizeDirectionValue(Msg.Direction);
  AliasData.Serif := Msg.Voice;
  AliasData.Layer := Chara.LayerSerif;
  AliasData.FrameStart := StartFrame;
  AliasData.FrameLength := LenFrame;
  AliasData.Group := Group;
  AliasData.Lab := LabText;
  AliasData.UID := Msg.UID;
  AddSerifAviUtlInputAlias(AliasData, FrameEnd);

  if not Send then Exit;
  SetBaseLayer(AliasData.Layer);
  Msg.FrameStart := AliasData.FrameStart;
  Msg.FrameEnd := FrameEnd;
  Msg.FrameNext := NextFrame;
  Msg.FrameSpaceE := NextSpace;
  Msg.SerifLayer := Chara.LayerSerif;
  Msg.WaveLayer := Chara.LayerWave;
  Msg.SceneId := GSceneId;
  Msg.IsOutput := True;
end;

function SendSerifMessagesCore(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem; Send, ContinuousSend: Boolean;
  out SendSucceeded: Boolean): string;
var
  J, I, StartFrame, LenFrame, AddStart, NextFrame, AddEnd: Integer;
  CreateFrame: Integer;
  CursorFrame: Integer;
  CursorLayer: Integer;
  KeepFirstFrameAtZero: Boolean;
  LenSec, Convert: Double;
  CreatedObject: TObjectHandle;
  LastMsg: TSerifSceneMsgItem;
  Msg: TSerifSceneMsgItem;
  Chara: TSerifCharaItem;
  LabText: string;
begin
  Result := '';
  SendSucceeded := not Send;
  GBaseLayer := -1;
  Convert := AviUtl2Convert;
  GSceneId := AviUtl2SceneGetID;

  CursorFrame := AviUtl2CursorGetFrame;
  CursorLayer := AviUtl2CursorGetLayer;
  KeepFirstFrameAtZero := False;
  StartFrame := CursorFrame;
  if Send and ContinuousSend and ContinuousSendMatches(ProjectFolder,
    GSceneId, CursorFrame, CursorLayer) then
  begin
    StartFrame := GContinuousSend.NextFrame;
    VoicevoxDebugLog(Format(
      'Serif continuous send accepted cursor=%d/%d next=%d uid=%s',
      [CursorFrame, CursorLayer, StartFrame, GContinuousSend.LastUID]));
  end
  else if Send then
  begin
    if ContinuousSend then
    begin
      if GContinuousSend.Valid then
        VoicevoxDebugLog('Serif continuous send discarded: timeline state changed');
      if CursorFrame > 0 then
        StartFrame := CursorFrame + 1
      else
        KeepFirstFrameAtZero := True;
      VoicevoxDebugLog(Format(
        'Serif continuous send fallback cursor=%d/%d start=%d',
        [CursorFrame, CursorLayer, StartFrame]));
    end;
    ResetSerifContinuousSend;
  end;
  CreateFrame := StartFrame;

  AddStart := Ceil(Config.SecStart / Convert);
  AddEnd := Ceil(Config.SecEnd / Convert);
  BeginSerifAviUtlAliasBatch;
  LastMsg := nil;

  if Send then
    for J := 0 to Msgs.Count - 1 do
      Msgs[J].IsOutput := False;

  for J := 0 to Msgs.Count - 1 do
  begin
    Msg := Msgs[J];
    I := Charas.IndexOfKeyword(Msg.Chara);
    if I = -1 then Continue;
    Chara := Charas[I];
    LenSec := Msg.WaveLength;
    LenFrame := Ceil(LenSec / Convert);

    if KeepFirstFrameAtZero then
      KeepFirstFrameAtZero := False
    else
      StartFrame := StartFrame + AddStart;
    NextFrame := StartFrame + LenFrame + AddEnd + 1;

    CreateAudioObject(ProjectFolder, Msg, Chara, StartFrame, LenFrame, 1);
    if Assigned(Config) and Config.SendLab then
      LabText := AvrUtl2_StrToAviutl(Msg.LabStr)
    else
      LabText := '';
    CreateSerifObject(Msg, Chara, StartFrame, LenFrame, NextFrame,
      AddEnd, 1, Send, LabText);
    LastMsg := Msg;
    StartFrame := NextFrame;
  end;

  if Send then
  begin
    CreatedObject := CreateSerifAviUtlObject(CreateFrame, CreateFrame,
      GBaseLayer,
      BuildSerifAviUtlAliasBatch);
    SendSucceeded := CreatedObject <> nil;
    if not SendSucceeded then
      for J := 0 to Msgs.Count - 1 do
        Msgs[J].IsOutput := False;
    if SendSucceeded then
      AviUtl2CursorMoveFrame(StartFrame);

    ResetSerifContinuousSend;
    if SendSucceeded and ContinuousSend and Assigned(LastMsg) then
    begin
      GContinuousSend.Valid := True;
      GContinuousSend.ProjectFolder := ProjectFolder;
      GContinuousSend.SceneId := GSceneId;
      GContinuousSend.CursorFrame := AviUtl2CursorGetFrame;
      GContinuousSend.CursorLayer := AviUtl2CursorGetLayer;
      GContinuousSend.NextFrame := StartFrame;
      GContinuousSend.LastUID := LastMsg.UID;
      GContinuousSend.LastLayer := LastMsg.SerifLayer;
      GContinuousSend.LastFrameStart := LastMsg.FrameStart;
      GContinuousSend.LastFrameEnd := LastMsg.FrameEnd;
      VoicevoxDebugLog(Format(
        'Serif continuous send stored cursor=%d/%d next=%d uid=%s frame=%d-%d',
        [GContinuousSend.CursorFrame, GContinuousSend.CursorLayer,
         GContinuousSend.NextFrame, GContinuousSend.LastUID,
         GContinuousSend.LastFrameStart, GContinuousSend.LastFrameEnd]));
    end;
  end
  else
  begin
    Result := SaveSerifAviUtlAliasBatch;
  end;
end;

function SendSerifMessages(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem; Send: Boolean): string;
var
  SendSucceeded: Boolean;
begin
  Result := SendSerifMessagesCore(ProjectFolder, Msgs, Charas, Config,
    Send, False, SendSucceeded);
end;

function SendSerifMessagesNow(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem): Boolean;
var
  Unused: string;
begin
  Unused := SendSerifMessagesCore(ProjectFolder, Msgs, Charas, Config,
    True, False, Result);
end;

function SendSerifMessagesContinuous(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem): Boolean;
var
  Unused: string;
begin
  Unused := SendSerifMessagesCore(ProjectFolder, Msgs, Charas, Config,
    True, True, Result);
end;

initialization
  ResetSerifContinuousSend;

end.
