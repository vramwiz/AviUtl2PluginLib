unit LauncherRunningState;
// ランチャー項目の起動状態判定。

interface

uses
  Winapi.Windows,
  LauncherListItems, LauncherListTypes, WindowInfoList;

type
  TLauncherRunningStateDetector = class
  private
    FAppInfos: TWindowInfoList;
    function FindApplicationInfo(const FileName: string): TWindowInfo;
    procedure RefreshApplicationInfos;
  public
    constructor Create;
    destructor Destroy; override;
    function FindApplicationWindow(const FileName: string): HWND;
    function DetectRunningState(Item: TLauncherListViewItem;
      out Wnd: HWND): TLauncherRunningState;
    function IsApplicationRunning(const FileName: string): Boolean;
    function TryDetectSpeechAppKind(const FileName: string;
      out AppKind: Integer): Boolean;
  end;

implementation

uses
  Winapi.TlHelp32, Winapi.PsAPI,
  System.SysUtils,
  LauncherShellUtils;

{ TLauncherRunningStateDetector }

constructor TLauncherRunningStateDetector.Create;
begin
  inherited;
  FAppInfos := TWindowInfoList.Create;
end;

destructor TLauncherRunningStateDetector.Destroy;
begin
  FAppInfos.Free;
  inherited;
end;

procedure TLauncherRunningStateDetector.RefreshApplicationInfos;
begin
  if FAppInfos <> nil then
    FAppInfos.LoadActiveWindows([lwDuplicates, lwUWP]);
end;

function TLauncherRunningStateDetector.FindApplicationInfo(
  const FileName: string): TWindowInfo;
var
  TargetFileName: string;
  TargetExecName: string;
  I: Integer;
  Info: TWindowInfo;
begin
  Result := nil;
  if FAppInfos = nil then
    Exit;

  TargetFileName := FileName;
  if SameText(ExtractFileExt(TargetFileName), '.lnk') then
    TargetFileName := ResolveLauncherShortcut(TargetFileName);
  if TargetFileName = '' then
    Exit;

  TargetFileName := ExpandFileName(TargetFileName);
  TargetExecName := ChangeFileExt(ExtractFileName(TargetFileName), '');

  for I := 0 to FAppInfos.Count - 1 do
  begin
    Info := FAppInfos[I];
    if Info.ExeName = '' then
      Continue;

    if SameText(ExpandFileName(Info.ExeName), TargetFileName) then
      Exit(Info);
  end;

  for I := 0 to FAppInfos.Count - 1 do
  begin
    Info := FAppInfos[I];
    if Info.ExeName = '' then
      Continue;

    if SameText(ChangeFileExt(ExtractFileName(Info.ExeName), ''),
      TargetExecName) then
      Exit(Info);
  end;
end;

function TLauncherRunningStateDetector.FindApplicationWindow(
  const FileName: string): HWND;
var
  Info: TWindowInfo;
begin
  Result := 0;

  RefreshApplicationInfos;
  Info := FindApplicationInfo(FileName);
  if (Info <> nil) and (Info.Handle <> 0) and IsWindow(Info.Handle) then
    Exit(Info.Handle);
end;

function TLauncherRunningStateDetector.DetectRunningState(
  Item: TLauncherListViewItem; out Wnd: HWND): TLauncherRunningState;
begin
  Wnd := 0;
  if Item = nil then
    Exit(lrsStopped);

  if not IsApplicationRunning(Item.FileName) then
  begin
    Item.LaunchedByLauncher := False;
    Exit(lrsStopped);
  end;

  Wnd := FindApplicationWindow(Item.FileName);
  if Wnd = 0 then
    Exit(lrsRunningNoWindow);

  if Item.LaunchedByLauncher then
    Result := lrsRunningManaged
  else
    Result := lrsRunningAdopted;
end;

function TLauncherRunningStateDetector.IsApplicationRunning(
  const FileName: string): Boolean;
var
  TargetFileName: string;
  Snapshot: THandle;
  Entry: TProcessEntry32;
  ProcessHandle: THandle;
  Buffer: array[0..MAX_PATH - 1] of Char;
  Size: DWORD;
begin
  Result := False;

  RefreshApplicationInfos;
  if FindApplicationInfo(FileName) <> nil then
    Exit(True);

  TargetFileName := FileName;
  if SameText(ExtractFileExt(TargetFileName), '.lnk') then
    TargetFileName := ResolveLauncherShortcut(TargetFileName);

  if TargetFileName = '' then
    Exit;

  TargetFileName := ExpandFileName(TargetFileName);

  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
    Exit;
  try
    ZeroMemory(@Entry, SizeOf(Entry));
    Entry.dwSize := SizeOf(Entry);

    if not Process32First(Snapshot, Entry) then
      Exit;

    repeat
      ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ,
        False, Entry.th32ProcessID);
      if ProcessHandle = 0 then
        Continue;
      try
        Size := GetModuleFileNameEx(ProcessHandle, 0, Buffer, Length(Buffer));
        if (Size > 0) and SameText(ExpandFileName(string(PChar(@Buffer[0]))),
          TargetFileName) then
        begin
          Result := True;
          Exit;
        end;
      finally
        CloseHandle(ProcessHandle);
      end;
    until not Process32Next(Snapshot, Entry);
  finally
    CloseHandle(Snapshot);
  end;
end;

function TLauncherRunningStateDetector.TryDetectSpeechAppKind(
  const FileName: string; out AppKind: Integer): Boolean;
var
  TargetFileName: string;
  ExecName: string;
  Kind: TLauncherSpeechAppKind;
begin
  Result := False;
  AppKind := 0;

  TargetFileName := FileName;
  if SameText(ExtractFileExt(TargetFileName), '.lnk') then
    TargetFileName := ResolveLauncherShortcut(TargetFileName);
  if TargetFileName = '' then
    Exit;

  ExecName := ChangeFileExt(ExtractFileName(TargetFileName), '');
  for Kind := Low(TLauncherSpeechAppKind) to High(TLauncherSpeechAppKind) do
  begin
    if not SameText(ExecName, SPEECH_APP_EXECUTABLE_NAMES[Kind]) then
      Continue;

    AppKind := Ord(Kind);
    Result := True;
    Exit;
  end;
end;

end.
