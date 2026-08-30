unit SerifModulePublisher;

// 製品別Script Moduleから受け取ったセリフ1フレームを、共通の
// ShareTalk、SerifIndex、履歴へ同じ形式で発行する。

interface

type
  TSerifModuleFrame = record
    FrameRate: Integer;
    Frame: Integer;
    Layer: Integer;
    Serif: string;
    Character: string;
    Emotion: string;
    Direction: string;
    Aiueo: string;
    TotalTime: Double;
    Lab: string;
    SourceObjectID: string;
    CurrentFrame: Integer;
  end;

// 入力値を検証し、現在フレームの共有本文、索引、履歴を発行する。
// 発行できた場合だけTrueを返し、共有メモリ例外は呼出側へ漏らさない。
function PublishSerifModuleFrame(const Value: TSerifModuleFrame): Boolean;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils,
  SerifTalkSharedCodec,
  SerifTalkSharedIndexPublisher,
  SerifTalkSharedMemory;

function NewRuntimeUID: string;
var
  Value: TGUID;
begin
  Result := '';
  if CreateGUID(Value) = S_OK then
    Result := GUIDToString(Value);
end;

function PublishSerifModuleFrame(const Value: TSerifModuleFrame): Boolean;
var
  Encoded: string;
  Frame: TSerifTalkFrame;
begin
  Result := False;
  try
    if (Value.Layer < 0) or (Value.Layer >= SERIF_TALK_MAX_LINES) or
      not TryStrToInt64(Trim(Value.SourceObjectID), Frame.SourceObjectID) or
      (Frame.SourceObjectID = 0) then
      Exit;

    Frame.UID := NewRuntimeUID;
    if Frame.UID = '' then
      Exit;
    Frame.FrameRate := Value.FrameRate;
    Frame.Frame := Value.Frame;
    Frame.CurrentFrame := Value.CurrentFrame;
    Frame.TotalTime := Value.TotalTime;
    Frame.TotalFrames := Max(1, Ceil(Value.TotalTime * Value.FrameRate));
    Frame.Serif := Value.Serif;
    Frame.Character := Value.Character;
    Frame.Emotion := Value.Emotion;
    Frame.Direction := Value.Direction;
    Frame.Aiueo := Value.Aiueo;
    Frame.Lab := Value.Lab;

    Encoded := EncodeSerifTalkFrame(Frame);
    if not PublishSerifTalkText(Value.Layer, Encoded) then
      Exit;
    PublishSerifTalkIndex(Value.CurrentFrame, Value.Layer, Value.Character,
      Value.Emotion, Value.Direction, Value.Serif);
    Result := True;
  except
    Result := False;
  end;
end;

end.
