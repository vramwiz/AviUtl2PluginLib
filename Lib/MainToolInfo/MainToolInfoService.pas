// 離れた機能ユニットから、製品ホストの情報欄へ文字列を通知する。
unit MainToolInfoService;

interface

type
  TMainToolInfoEvent = procedure(const AText: string) of object;

procedure RegisterMainToolInfo(AReceiver: TObject;
  AShowEvent: TMainToolInfoEvent);
procedure UnregisterMainToolInfo(AReceiver: TObject);
procedure ShowMainToolInfo(const AText: string);
procedure ClearMainToolInfo;

implementation

uses System.SysUtils;

var
  GReceiver: TObject;
  GShowEvent: TMainToolInfoEvent;

function NormalizeInfoText(const Value: string): string;
begin
  Result := StringReplace(Value, #13#10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
  Result := Trim(Result);
end;

procedure RegisterMainToolInfo(AReceiver: TObject;
  AShowEvent: TMainToolInfoEvent);
begin
  GReceiver := AReceiver;
  GShowEvent := AShowEvent;
end;

procedure UnregisterMainToolInfo(AReceiver: TObject);
begin
  if GReceiver <> AReceiver then Exit;
  GShowEvent := nil;
  GReceiver := nil;
end;

procedure ShowMainToolInfo(const AText: string);
begin
  if Assigned(GShowEvent) then
    GShowEvent(NormalizeInfoText(AText));
end;

procedure ClearMainToolInfo;
begin
  ShowMainToolInfo('');
end;

initialization
  GReceiver := nil;
  GShowEvent := nil;

finalization
  GShowEvent := nil;
  GReceiver := nil;

end.
