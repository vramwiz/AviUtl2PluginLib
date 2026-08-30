unit SerifAviUtlObjectCreate;

// Serif送信が必要とするAviUtl2オブジェクト生成だけを提供する。
// Syncroh2のAliasManager型やバッチ管理には依存しない。

interface

uses AviUtl2PluginTypes;

function CreateSerifAviUtlObject(FrameStart, FrameLength,
  Layer: Integer; const AliasText: string): TObjectHandle;

implementation

uses AviUtl2PluginCore;

type
  PCreateSerifObjectParam = ^TCreateSerifObjectParam;
  TCreateSerifObjectParam = record
    FrameStart: Integer;
    FrameLength: Integer;
    Layer: Integer;
    AliasText: UTF8String;
    CreatedObject: TObjectHandle;
  end;

procedure CreateObjectCore(Param: Pointer; Edit: PEditSection); cdecl;
var
  Data: PCreateSerifObjectParam;
begin
  if (Param = nil) or (Edit = nil) or (Edit^.Info = nil) then Exit;
  Data := PCreateSerifObjectParam(Param);
  Data^.CreatedObject := Edit^.CreateObjectFromAlias(
    PAnsiChar(Data^.AliasText), Data^.Layer, Data^.FrameStart,
    Data^.FrameLength);
end;

function CreateSerifAviUtlObject(FrameStart, FrameLength,
  Layer: Integer; const AliasText: string): TObjectHandle;
var
  Data: TCreateSerifObjectParam;
begin
  Result := nil;
  if not Assigned(EditHandle) then Exit;
  Data.FrameStart := FrameStart;
  Data.FrameLength := FrameLength;
  Data.Layer := Layer;
  Data.AliasText := UTF8String(AliasText);
  Data.CreatedObject := nil;
  EditHandle^.CallEditSectionParam(@Data, @CreateObjectCore);
  Result := Data.CreatedObject;
end;

end.
