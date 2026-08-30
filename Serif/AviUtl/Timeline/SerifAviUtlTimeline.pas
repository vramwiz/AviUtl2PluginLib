unit SerifAviUtlTimeline;

interface

uses SerifSceneMsgList;

function SerifAviUtlIsSynchronized(Msg: TSerifSceneMsgItem): Boolean;
function SerifAviUtlSetText(const Layer, Frame: Integer;
  const Value: string): Boolean;
function SerifAviUtlSetDirection(const Layer, Frame: Integer;
  const Value: string): Boolean;
function SerifAviUtlSetEmotion(const Layer, Frame: Integer;
  const Value: string): Boolean;
function SerifAviUtlSetAiueo(const Layer, Frame: Integer;
  const Value: string): Boolean;
function SerifAviUtlGetText(const Layer, Frame: Integer): string;
function SerifAviUtlGetUID(const Layer, Frame: Integer): string;
function SerifAviUtlDelete(const Layer, Frame: Integer): Boolean;
function SerifAviUtlMove(const LayerTo, FrameTo, LayerFrom,
  FrameFrom: Integer): Boolean;

implementation

uses AviUtl2PluginTypes, AviUtl2PluginObjectFind, AviUtl2PluginObjectValue,
     AviUtl2PluginObjectControl, SerifAviUtlProfile;

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

function NormalizeDirectionValue(const Value: string): Integer;
begin
  Result := -1;
end;

function SerifAviUtlIsSynchronized(Msg: TSerifSceneMsgItem): Boolean;
begin
  Result := AviUtl2FindObject(Msg.SerifLayer, Msg.FrameStart) <> nil;
end;

function SerifAviUtlSetText(const Layer, Frame: Integer;
  const Value: string): Boolean;
var
  Obj: TObjectHandle;
  Profile: TSerifAviUtlProfile;
begin
  Result := False;
  Obj := AviUtl2FindObject(Layer, Frame);
  if Obj = nil then Exit;
  Profile := CurrentSerifAviUtlProfile;
  AviUtl2SetObjectItemValue(Obj, Profile.SerifEffectName,
    Profile.SerifTextItem, Value);
  Result := True;
end;

function SerifAviUtlSetDirection(const Layer, Frame: Integer;
  const Value: string): Boolean;
var
  Obj: TObjectHandle;
  Profile: TSerifAviUtlProfile;
begin
  Result := False;
  Obj := AviUtl2FindObject(Layer, Frame);
  if Obj = nil then Exit;
  Profile := CurrentSerifAviUtlProfile;
  AviUtl2SetObjectItemInt(Obj, Profile.SerifEffectName,
    Profile.DirectionItem,
    NormalizeDirectionValue(Value));
  Result := True;
end;

function SerifAviUtlSetEmotion(const Layer, Frame: Integer;
  const Value: string): Boolean;
var
  Obj: TObjectHandle;
  Profile: TSerifAviUtlProfile;
begin
  Result := False;
  Obj := AviUtl2FindObject(Layer, Frame);
  if Obj = nil then Exit;
  Profile := CurrentSerifAviUtlProfile;
  AviUtl2SetObjectItemValue(Obj, Profile.SerifEffectName,
    Profile.EmotionItem, Value);
  Result := True;
end;

function SerifAviUtlSetAiueo(const Layer, Frame: Integer;
  const Value: string): Boolean;
var
  Obj: TObjectHandle;
  Profile: TSerifAviUtlProfile;
begin
  Result := False;
  Obj := AviUtl2FindObject(Layer, Frame);
  if Obj = nil then Exit;
  Profile := CurrentSerifAviUtlProfile;
  AviUtl2SetObjectItemValue(Obj, Profile.SerifEffectName,
    Profile.AiueoItem, Value);
  Result := True;
end;

function SerifAviUtlGetText(const Layer, Frame: Integer): string;
var
  Obj: TObjectHandle;
  Profile: TSerifAviUtlProfile;
begin
  Result := '';
  Obj := AviUtl2FindObject(Layer, Frame);
  if Obj = nil then Exit;
  Profile := CurrentSerifAviUtlProfile;
  AviUtl2GetObjectItemValue(Obj, Profile.SerifEffectName,
    Profile.SerifTextItem, Result);
end;

function SerifAviUtlGetUID(const Layer, Frame: Integer): string;
var
  Obj: TObjectHandle;
  Profile: TSerifAviUtlProfile;
begin
  Result := '';
  Obj := AviUtl2FindObject(Layer, Frame);
  if Obj = nil then Exit;
  Profile := CurrentSerifAviUtlProfile;
  AviUtl2GetObjectItemValue(Obj, Profile.SerifEffectName,
    Profile.UIDItem, Result);
end;

function SerifAviUtlDelete(const Layer, Frame: Integer): Boolean;
var
  Obj: TObjectHandle;
begin
  Result := False;
  Obj := AviUtl2FindObject(Layer, Frame);
  if Obj = nil then Exit;
  AviUtl2DeleteObject(Obj);
  Result := True;
end;

function SerifAviUtlMove(const LayerTo, FrameTo, LayerFrom,
  FrameFrom: Integer): Boolean;
var
  Obj: TObjectHandle;
begin
  Result := False;
  Obj := AviUtl2FindObject(LayerFrom, FrameFrom);
  if Obj = nil then Exit;
  Result := AviUtl2MoveObject(Obj, LayerTo, FrameTo);
end;

end.
