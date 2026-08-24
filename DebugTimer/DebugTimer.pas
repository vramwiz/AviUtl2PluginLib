unit DebugTimer;

interface

procedure DebugTimerBegin(const Title: string);
procedure DebugTimerEnd;

implementation

uses
  Winapi.Windows,
  System.SysUtils;

{$IFDEF DEBUG}

var
  GDebugTimerFreq  : Int64 = 0;
  GDebugTimerStart : Int64 = 0;
  GDebugTimerTitle : string = '';

procedure DebugTimerBegin(const Title: string);
begin
  if GDebugTimerFreq = 0 then begin
    QueryPerformanceFrequency(GDebugTimerFreq);
  end;

  GDebugTimerTitle := Title;
  QueryPerformanceCounter(GDebugTimerStart);
end;

procedure DebugTimerEnd;
var
  TimeEnd : Int64;
  Elapsed : Double;
  S       : string;
begin
  QueryPerformanceCounter(TimeEnd);

  Elapsed := (TimeEnd - GDebugTimerStart) * 1000 / GDebugTimerFreq;

  S := Format('[%s] %.3f ms', [
    GDebugTimerTitle,
    Elapsed
  ]);

  OutputDebugString(PChar(S));
end;

{$ELSE}

procedure DebugTimerBegin(const Title: string);
begin
end;

procedure DebugTimerEnd;
begin
end;

{$ENDIF}

end.
