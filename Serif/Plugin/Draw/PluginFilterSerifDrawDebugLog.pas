unit PluginFilterSerifDrawDebugLog;

// DebugビルドだけでSerifDrawの診断ログと高精度時間計測を提供する。

interface

procedure ResetSerifDrawDebugLog;
procedure SerifDrawDebugLog(const Text: string);
function SerifDrawTimerStart: Int64;
function SerifDrawTimerElapsedMilliseconds(StartCounter: Int64): Double;

implementation

{$IFDEF DEBUG}

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows,
  SerifDrawPluginProfile;

var
  DebugLogLock: TRTLCriticalSection;
  DebugTimerFrequency: Int64;

procedure SerifDrawDebugLog(const Text: string);
var
  FileName: string;
  Line: string;
begin
  try
    FileName := CurrentSerifDrawPluginProfile.DebugLogFileName;
    if FileName = '' then Exit;
    EnterCriticalSection(DebugLogLock);
    try
      Line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
        Format(' [thread %d] ', [GetCurrentThreadId]) + Text + sLineBreak;
      TFile.AppendAllText(FileName, Line, TEncoding.UTF8);
    finally
      LeaveCriticalSection(DebugLogLock);
    end;
  except
    // 診断失敗をAviUtl2の処理へ伝播させない。
  end;
end;

procedure ResetSerifDrawDebugLog;
var
  FileName: string;
begin
  try
    FileName := CurrentSerifDrawPluginProfile.DebugLogFileName;
    if FileName = '' then Exit;
    EnterCriticalSection(DebugLogLock);
    try
      if TFile.Exists(FileName) then
        TFile.Delete(FileName);
    finally
      LeaveCriticalSection(DebugLogLock);
    end;
  except
    // 削除できない場合は既存ログへ追記する。
  end;
  SerifDrawDebugLog('Debug log started.');
end;

function SerifDrawTimerStart: Int64;
begin
  QueryPerformanceCounter(Result);
end;

function SerifDrawTimerElapsedMilliseconds(StartCounter: Int64): Double;
var
  CurrentCounter: Int64;
begin
  QueryPerformanceCounter(CurrentCounter);
  if DebugTimerFrequency > 0 then
    Result := (CurrentCounter - StartCounter) * 1000.0 / DebugTimerFrequency
  else
    Result := 0;
end;

initialization
  InitializeCriticalSection(DebugLogLock);
  QueryPerformanceFrequency(DebugTimerFrequency);

finalization
  DeleteCriticalSection(DebugLogLock);

{$ELSE}

procedure SerifDrawDebugLog(const Text: string);
begin
end;

procedure ResetSerifDrawDebugLog;
begin
end;

function SerifDrawTimerStart: Int64;
begin
  Result := 0;
end;

function SerifDrawTimerElapsedMilliseconds(StartCounter: Int64): Double;
begin
  Result := 0;
end;

{$ENDIF}

end.
