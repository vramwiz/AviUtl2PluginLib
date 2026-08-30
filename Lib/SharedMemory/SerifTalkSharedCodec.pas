unit SerifTalkSharedCodec;

// MMDセリフ入力をSyncroh2のShareTalkキー文字列へ変換する。

interface

type
  TSerifTalkFrame = record
    UID: string;
    SourceObjectID: Int64;
    CurrentFrame: Integer;
    Frame: Integer;
    FrameRate: Integer;
    TotalFrames: Integer;
    TotalTime: Double;
    Serif: string;
    Character: string;
    Emotion: string;
    Direction: string;
    Aiueo: string;
    Lab: string;
  end;

// 現在フレームのLAB行と発話状態を含むSyncroh2互換文字列を返す。
function EncodeSerifTalkFrame(const Value: TSerifTalkFrame): string;

implementation

uses
  System.Classes,
  System.Math,
  System.StrUtils,
  System.SysUtils,
  KeyValueText;

function TryParseLabInterval(const Line: string; out StartSec,
  EndSec: Double): Boolean;
var
  Comma1, Comma2: Integer;
  Duration: Double;
  EndText, StartText: string;
  Start100ns, End100ns: Int64;
begin
  Result := False;
  Comma1 := Pos(',', Line);
  if Comma1 = 0 then Exit;
  Comma2 := PosEx(',', Line, Comma1 + 1);
  if Comma2 = 0 then Exit;
  StartText := Trim(Copy(Line, 1, Comma1 - 1));
  EndText := Trim(Copy(Line, Comma1 + 1, Comma2 - Comma1 - 1));
  if StartsText('t', StartText) then
  begin
    StartText := Copy(StartText, 2, MaxInt);
    if StartsText('.', StartText) then StartText := '0' + StartText;
    if StartsText('.', EndText) then EndText := '0' + EndText;
    if not TryStrToFloat(StartText, StartSec, TFormatSettings.Invariant) or
      not TryStrToFloat(EndText, Duration, TFormatSettings.Invariant) then Exit;
    EndSec := StartSec + Duration;
  end
  else
  begin
    if not TryStrToInt64(StartText, Start100ns) or
      not TryStrToInt64(EndText, End100ns) then Exit;
    StartSec := Start100ns / 10000000.0;
    EndSec := End100ns / 10000000.0;
  end;
  Result := EndSec > StartSec;
end;

function LabCommand(const Line: string): string;
var
  Comma: Integer;
begin
  Result := Trim(Line);
  Comma := LastDelimiter(',', Result);
  if Comma > 0 then Result := Trim(Copy(Result, Comma + 1, MaxInt));
end;

function CurrentLabLine(const Lab: string; Sec, TotalTime: Double): string;
var
  EndSec, StartSec: Double;
  I: Integer;
  Lines: TStringList;
begin
  Result := '';
  if (Trim(Lab) = '') or (Sec < 0) or
    ((TotalTime > 0) and (Sec >= TotalTime)) then Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := Lab;
    for I := 0 to Lines.Count - 1 do
      if TryParseLabInterval(Lines[I], StartSec, EndSec) and
        (Sec >= StartSec) and (Sec < EndSec) then
        Exit(Trim(Lines[I]));
  finally
    Lines.Free;
  end;
end;

function IsSpeechActive(const HasLab: Boolean; const LabLine, Serif: string;
  Sec, TotalTime: Double): Boolean;
var
  Command: string;
begin
  Result := Trim(Serif) <> '';
  if not Result then Exit;
  if not HasLab then
    Exit((TotalTime <= 0) or ((Sec >= 0) and (Sec < TotalTime)));
  Command := LabCommand(LabLine);
  if (Command = '') or SameText(Command, 'Pause') then Exit(False);
  if StartsText('vol:', Command) then
    Exit(StrToIntDef(Trim(Copy(Command, 5, MaxInt)), 0) > 0);
end;

function EncodeSerifTalkFrame(const Value: TSerifTalkFrame): string;
var
  HasLab, SpeechActive: Boolean;
  LabLine: string;
  Sec, SpeechProgress: Double;
begin
  Sec := 0;
  if Value.FrameRate > 0 then Sec := Value.Frame / Value.FrameRate;
  HasLab := Trim(Value.Lab) <> '';
  LabLine := CurrentLabLine(Value.Lab, Sec, Value.TotalTime);
  SpeechActive := IsSpeechActive(HasLab, LabLine, Value.Serif, Sec,
    Value.TotalTime);
  SpeechProgress := 0;
  if Value.TotalTime > 0 then
    SpeechProgress := EnsureRange(Sec / Value.TotalTime, 0.0, 1.0);
  Result := '';
  AddKeyValue(Result, 'uid', Value.UID);
  AddKeyValue(Result, 'source_object', IntToStr(Value.SourceObjectID));
  AddKeyValue(Result, 'current_frame', Value.CurrentFrame);
  AddKeyValue(Result, 'frame', Value.Frame);
  AddKeyValue(Result, 'framerate', Value.FrameRate);
  AddKeyValue(Result, 'total_frames', Value.TotalFrames);
  AddKeyValue(Result, 'serif', Value.Serif);
  AddKeyValue(Result, 'chara', Value.Character);
  AddKeyValue(Result, 'emote', Value.Emotion);
  AddKeyValue(Result, 'direction', Value.Direction);
  AddKeyValue(Result, 'aiueo', Value.Aiueo);
  AddKeyValue(Result, 'totaltime', Value.TotalTime);
  AddKeyValue(Result, 'lab', LabLine);
  AddKeyValue(Result, 'lab_data', HasLab);
  AddKeyValue(Result, 'speech_progress', SpeechProgress);
  AddKeyValue(Result, 'speech_active', SpeechActive);
end;

end.
