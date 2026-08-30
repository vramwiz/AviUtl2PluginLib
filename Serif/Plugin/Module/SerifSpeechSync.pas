unit SerifSpeechSync;

interface

function CalculateSerifSpeechProgress(const ASeconds,
  ATotalTime: Double): Double;
function CalculateSerifSpeechProgressFromLab(const ALab,
  ACurrentLabLine: string; const ASeconds, ATotalTime: Double): Double;
function IsSerifSpeechActive(const AHasLab: Boolean;
  const ACurrentLabLine, ASerif: string; const ASeconds,
  ATotalTime: Double): Boolean;

implementation

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  System.StrUtils;

function LabCommand(const ALine: string): string;
var
  FirstComma: Integer;
  SecondComma: Integer;
begin
  Result := '';
  FirstComma := Pos(',', ALine);
  if FirstComma = 0 then
    Exit;
  SecondComma := PosEx(',', ALine, FirstComma + 1);
  if SecondComma = 0 then
    Exit;
  Result := Trim(Copy(ALine, SecondComma + 1, MaxInt));
end;

function TryParseCompactLabTime(const AText: string;
  out ASeconds: Double): Boolean;
var
  Normalized: string;
begin
  Normalized := Trim(AText);
  if StartsText('.', Normalized) then
    Normalized := '0' + Normalized;
  Result := TryStrToFloat(Normalized, ASeconds, TFormatSettings.Invariant);
end;

function TryParseLabInterval(const ALine: string; out AStartSeconds,
  AEndSeconds: Double): Boolean;
var
  DurationSeconds: Double;
  EndText: string;
  FirstComma: Integer;
  SecondComma: Integer;
  StartText: string;
  StartValue: Int64;
  EndValue: Int64;
begin
  Result := False;
  FirstComma := Pos(',', ALine);
  if FirstComma = 0 then
    Exit;
  SecondComma := PosEx(',', ALine, FirstComma + 1);
  if SecondComma = 0 then
    Exit;
  StartText := Trim(Copy(ALine, 1, FirstComma - 1));
  EndText := Trim(Copy(ALine, FirstComma + 1,
    SecondComma - FirstComma - 1));
  if StartsText('t', StartText) then
  begin
    if not TryParseCompactLabTime(Copy(StartText, 2, MaxInt),
      AStartSeconds) or
      not TryParseCompactLabTime(EndText, DurationSeconds) then
      Exit;
    AEndSeconds := AStartSeconds + DurationSeconds;
  end
  else
  begin
    if not TryStrToInt64(StartText, StartValue) or
      not TryStrToInt64(EndText, EndValue) then
      Exit;
    AStartSeconds := StartValue / 10000000.0;
    AEndSeconds := EndValue / 10000000.0;
  end;
  Result := AEndSeconds > AStartSeconds;
end;

function CalculateSerifSpeechProgress(const ASeconds,
  ATotalTime: Double): Double;
begin
  if ATotalTime <= 0.0 then
    Exit(0.0);
  Result := EnsureRange(ASeconds / ATotalTime, 0.0, 1.0);
end;

function IsActiveLabCommand(const ACommand: string): Boolean;
var
  Volume: Integer;
begin
  Result := False;
  if (ACommand = '') or SameText(ACommand, 'Pause') then
    Exit;
  if StartsText('vol:', ACommand) then
  begin
    Volume := StrToIntDef(Trim(Copy(ACommand, 5, MaxInt)), 0);
    Exit(Volume > 0);
  end;
  Result := True;
end;

function CalculateSerifSpeechProgressFromLab(const ALab,
  ACurrentLabLine: string; const ASeconds, ATotalTime: Double): Double;
var
  ActiveCount: Integer;
  CompletedActiveCount: Integer;
  CurrentActiveIndex: Integer;
  CurrentLineIndex: Integer;
  EndSeconds: Double;
  I: Integer;
  Lines: TStringList;
  StartSeconds: Double;
begin
  Result := CalculateSerifSpeechProgress(ASeconds, ATotalTime);
  if Trim(ALab) = '' then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := ALab;
    ActiveCount := 0;
    for I := 0 to Lines.Count - 1 do
      if IsActiveLabCommand(LabCommand(Lines[I])) then
        Inc(ActiveCount);
    CurrentLineIndex := -1;
    if Trim(ACurrentLabLine) <> '' then
      for I := 0 to Lines.Count - 1 do
        if SameText(Trim(Lines[I]), Trim(ACurrentLabLine)) then
        begin
          CurrentLineIndex := I;
          Break;
        end;
    CompletedActiveCount := 0;
    CurrentActiveIndex := -1;
    for I := 0 to Lines.Count - 1 do
      if IsActiveLabCommand(LabCommand(Lines[I])) then
      begin
        if I = CurrentLineIndex then
          CurrentActiveIndex := CompletedActiveCount;
        if (CurrentLineIndex >= 0) and (I < CurrentLineIndex) then
          Inc(CompletedActiveCount)
        else if (CurrentLineIndex < 0) and
          TryParseLabInterval(Lines[I], StartSeconds, EndSeconds) and
          (ASeconds >= EndSeconds) then
          Inc(CompletedActiveCount);
      end;
    // 最後の発音要素を必ず1.0へ割り当て、末尾無音があっても最終文字へ届かせる。
    if (CurrentActiveIndex >= 0) and (ActiveCount > 1) then
      Result := CurrentActiveIndex / (ActiveCount - 1);
    // 無音区間は全体時間へ戻さず、直前までに完了した発音数を保持する。
    // これにより維持モードの色位置がPauseごとに後退しない。
    if (CurrentActiveIndex < 0) and (ActiveCount > 0) then
      Result := CompletedActiveCount / ActiveCount;
  finally
    Lines.Free;
  end;
end;

function IsSerifSpeechActive(const AHasLab: Boolean;
  const ACurrentLabLine, ASerif: string; const ASeconds,
  ATotalTime: Double): Boolean;
var
  Command: string;
begin
  Result := False;
  if Trim(ASerif) = '' then
    Exit;
  if not AHasLab then
    Exit((ATotalTime <= 0.0) or
      ((ASeconds >= 0.0) and (ASeconds < ATotalTime)));

  Command := LabCommand(ACurrentLabLine);
  Result := IsActiveLabCommand(Command);
end;

end.
