unit SerifWindowWatchVoicepeak;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.UIAutomation, System.SysUtils, System.Types,
  SerifWindowWatchTarget;

type
  TSerifWindowWatchVoicepeak = class(TSerifWindowWatchTarget)
  private
    FAutomation: IUIAutomation;
    FOutputActionDone: Boolean;
    FFolderActionDone: Boolean;
    FOutputSettingsWnd: HWND;
    FFolderSelectWnd: HWND;
    FDebugScanCount: Integer;
    procedure DebugLog(const Text: string);
    function DebugWindowText(Wnd: HWND): string;
    procedure ClearClosedActionFlags;
    function GetAutomation: IUIAutomation;
    function FindVoicepeakMainWindow: HWND;
    function IsVoicepeakProcessWindow(Wnd: HWND): Boolean;
    function IsVoicepeakOutputSettingsWindow(Wnd: HWND): Boolean;
    function IsVoicepeakFolderSelectWindow(Wnd: HWND): Boolean;
    function IsVoicepeakOutputSurface(Wnd: HWND): Boolean;
    function UiaWindowHasText(Wnd: HWND; const Text1, Text2: string): Boolean;
    procedure CheckVoicepeakOutputSettingsWindow;
    procedure CheckVoicepeakFolderSelectWindow;
    function InvokeVoicepeakButtonByText(Wnd: HWND; const ButtonText,
      DebugName: string): Boolean;
    function InvokeVoicepeakOutputButton(Wnd: HWND): Boolean;
    function InvokeVoicepeakFolderSelectButton(Wnd: HWND): Boolean;
    function ClickVoicepeakOutputButtonByPosition(Wnd: HWND): Boolean;
    function SendEnterToWindow(Wnd: HWND; const DebugName: string): Boolean;
  public
    function AppKind: TSerifSpeechAppKind; override;
    procedure Reset; override;
    procedure Tick; override;
    function CanHandleWindow(Wnd: HWND): Boolean; override;
    procedure HandleNewWindow(Wnd: HWND); override;
  end;

implementation

uses
  Winapi.ActiveX, System.Win.ComObj, SerifWindowWatchUtils
  {$IFDEF DEBUG}, PSDImageDebugLog{$ENDIF};

const
  VOICEPEAK_OUTPUT_BUTTON_REL_X = 0.65;
  VOICEPEAK_OUTPUT_BUTTON_REL_Y = 0.945;
  VOICEPEAK_DEBUG_DETAIL = True;
  VOICEPEAK_DEBUG_SCAN_INTERVAL = 10;

function SVoicepeakOutputSettingsTitle: string;
begin
  Result := #$51FA#$529B#$8A2D#$5B9A; // output settings
end;

function SVoicepeakOutputButton: string;
begin
  Result := #$51FA#$529B; // output
end;

function SVoicepeakFileName: string;
begin
  Result := #$30D5#$30A1#$30A4#$30EB#$540D; // file name
end;

function SVoicepeakFormat: string;
begin
  Result := #$30D5#$30A9#$30FC#$30DE#$30C3#$30C8; // format
end;

function SVoicepeakSplitByBlock: string;
begin
  Result := #$30D6#$30ED#$30C3#$30AF#$3054#$3068#$306B#$5206#$5272#$3057#$3066#$4FDD#$5B58; // save split by block
end;

function SVoicepeakFolderSelectTitle: string;
begin
  Result := #$4FDD#$5B58#$5148#$306E#$30D5#$30A9#$30EB#$30C0#$30FC#$3092#$6307#$5B9A#$3057#$3066#$304F#$3060#$3055#$3044; // choose save destination folder
end;

function SVoicepeakFolderSelectButton: string;
begin
  Result := #$30D5#$30A9#$30EB#$30C0#$30FC#$306E#$9078#$629E; // select folder
end;

type
  PFindVoicepeakOutputSettingsContext = ^TFindVoicepeakOutputSettingsContext;
  TFindVoicepeakOutputSettingsContext = record
    Target: TSerifWindowWatchVoicepeak;
    Found: Boolean;
    LogScan: Boolean;
  end;

  PFindVoicepeakFolderSelectContext = ^TFindVoicepeakFolderSelectContext;
  TFindVoicepeakFolderSelectContext = record
    Target: TSerifWindowWatchVoicepeak;
    Found: Boolean;
    LogScan: Boolean;
  end;

  PFindVoicepeakMainWindowContext = ^TFindVoicepeakMainWindowContext;
  TFindVoicepeakMainWindowContext = record
    Target: TSerifWindowWatchVoicepeak;
    Wnd: HWND;
  end;

function EnumFindVoicepeakOutputSettingsProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PFindVoicepeakOutputSettingsContext;
  CanHandle: Boolean;
begin
  Context := PFindVoicepeakOutputSettingsContext(Pointer(LParam));
  if IsTopLevelVisibleWindow(Wnd) then
  begin
    CanHandle := Context.Target.CanHandleWindow(Wnd);
    if Context.LogScan and (GetWindowString(Wnd) <> '') then
      Context.Target.DebugLog(Format('VOICEPEAK enum visible CanHandle=%s %s',
        [BoolText(CanHandle), Context.Target.DebugWindowText(Wnd)]));
    if CanHandle then
    begin
      Context.Target.DebugLog('VOICEPEAK enum output candidate ' +
        Context.Target.DebugWindowText(Wnd));
      Context.Found := Context.Target.InvokeVoicepeakOutputButton(Wnd);
      Result := not Context.Found;
      Exit;
    end;
  end;
  Result := True;
end;

function EnumFindVoicepeakFolderSelectProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PFindVoicepeakFolderSelectContext;
  CanHandle: Boolean;
begin
  Context := PFindVoicepeakFolderSelectContext(Pointer(LParam));
  if IsTopLevelVisibleWindow(Wnd) then
  begin
    CanHandle := Context.Target.IsVoicepeakFolderSelectWindow(Wnd);
    if Context.LogScan and CanHandle then
      Context.Target.DebugLog('VOICEPEAK folder enum candidate ' +
        Context.Target.DebugWindowText(Wnd));
    if CanHandle then
    begin
      Context.Found := Context.Target.InvokeVoicepeakFolderSelectButton(Wnd);
      Result := not Context.Found;
      Exit;
    end;
  end;
  Result := True;
end;

function EnumFindVoicepeakMainWindowProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PFindVoicepeakMainWindowContext;
begin
  Context := PFindVoicepeakMainWindowContext(Pointer(LParam));
  if IsTopLevelVisibleWindow(Wnd) and Context.Target.IsVoicepeakProcessWindow(Wnd) then
  begin
    Context.Target.DebugLog('VOICEPEAK enum process window candidate ' +
      Context.Target.DebugWindowText(Wnd));
    Context.Wnd := Wnd;
    Result := False;
    Exit;
  end;
  Result := True;
end;

{ TSerifWindowWatchVoicepeak }

function TSerifWindowWatchVoicepeak.AppKind: TSerifSpeechAppKind;
begin
  Result := ssakVoicepeak;
end;

function TSerifWindowWatchVoicepeak.CanHandleWindow(Wnd: HWND): Boolean;
begin
  Result := IsTopLevelVisibleWindow(Wnd) and
            (IsVoicepeakOutputSettingsWindow(Wnd) or
             IsVoicepeakFolderSelectWindow(Wnd));
  if VOICEPEAK_DEBUG_DETAIL and Result then
    DebugLog(Format('VOICEPEAK CanHandle result=%s %s',
      [BoolText(Result), DebugWindowText(Wnd)]));
end;

procedure TSerifWindowWatchVoicepeak.CheckVoicepeakFolderSelectWindow;
var
  Context: TFindVoicepeakFolderSelectContext;
begin
  if FFolderActionDone then
    Exit;

  Context.Target := Self;
  Context.Found := False;
  Context.LogScan := VOICEPEAK_DEBUG_DETAIL and
    ((FDebugScanCount = 1) or
     ((FDebugScanCount mod VOICEPEAK_DEBUG_SCAN_INTERVAL) = 0));
  EnumWindows(@EnumFindVoicepeakFolderSelectProc, LPARAM(Pointer(@Context)));
  if Context.Found then
    FFolderActionDone := True;
end;

procedure TSerifWindowWatchVoicepeak.CheckVoicepeakOutputSettingsWindow;
var
  Context: TFindVoicepeakOutputSettingsContext;
  Wnd: HWND;
begin
  if FOutputActionDone then
    Exit;

  Inc(FDebugScanCount);
  if VOICEPEAK_DEBUG_DETAIL and
     ((FDebugScanCount = 1) or
      ((FDebugScanCount mod VOICEPEAK_DEBUG_SCAN_INTERVAL) = 0)) then
  begin
    DebugLog(Format('VOICEPEAK scan start count=%d Target=%s Foreground=%s',
      [FDebugScanCount, DebugWindowText(TargetMainWindow),
       DebugWindowText(GetForegroundWindow)]));
  end;

  Context.Target := Self;
  Context.Found := False;
  Context.LogScan := VOICEPEAK_DEBUG_DETAIL and
    ((FDebugScanCount = 1) or
     ((FDebugScanCount mod VOICEPEAK_DEBUG_SCAN_INTERVAL) = 0));
  EnumWindows(@EnumFindVoicepeakOutputSettingsProc, LPARAM(Pointer(@Context)));
  if Context.Found then
  begin
    FOutputActionDone := True;
    Exit;
  end;

  Wnd := FindVoicepeakMainWindow;
  if VOICEPEAK_DEBUG_DETAIL then
    DebugLog('VOICEPEAK main window resolved ' + DebugWindowText(Wnd));
  if (Wnd <> 0) and IsVoicepeakOutputSurface(Wnd) and
     InvokeVoicepeakOutputButton(Wnd) then
    FOutputActionDone := True;
end;

function TSerifWindowWatchVoicepeak.ClickVoicepeakOutputButtonByPosition(
  Wnd: HWND): Boolean;
var
  Rect: TRect;
  X: Integer;
  Y: Integer;
begin
  Result := False;
  if not GetWindowRect(Wnd, Rect) then
  begin
    DebugLog('VOICEPEAK output position click failed: GetWindowRect ' +
      DebugWindowText(Wnd));
    Exit;
  end;

  X := Rect.Left + Round((Rect.Right - Rect.Left) * VOICEPEAK_OUTPUT_BUTTON_REL_X);
  Y := Rect.Top + Round((Rect.Bottom - Rect.Top) * VOICEPEAK_OUTPUT_BUTTON_REL_Y);

  ShowWindow(Wnd, SW_SHOWNORMAL);
  BringWindowToTop(Wnd);
  SetForegroundWindow(Wnd);
  SetActiveWindow(Wnd);
  SetCursorPos(X, Y);
  mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
  mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
  Result := True;
  DebugLog(Format('VOICEPEAK output position click sent x=%d y=%d rect=(%d,%d,%d,%d) %s',
    [X, Y, Rect.Left, Rect.Top, Rect.Right, Rect.Bottom, DebugWindowText(Wnd)]));
end;

procedure TSerifWindowWatchVoicepeak.ClearClosedActionFlags;
begin
  if FOutputActionDone and
     ((FOutputSettingsWnd = 0) or (not IsWindow(FOutputSettingsWnd))) then
  begin
    FOutputActionDone := False;
    FOutputSettingsWnd := 0;
    DebugLog('VOICEPEAK output action flag cleared');
  end;

  if FFolderActionDone and
     ((FFolderSelectWnd = 0) or (not IsWindow(FFolderSelectWnd))) then
  begin
    FFolderActionDone := False;
    FFolderSelectWnd := 0;
    DebugLog('VOICEPEAK folder action flag cleared');
  end;
end;

procedure TSerifWindowWatchVoicepeak.DebugLog(const Text: string);
begin
  {$IFDEF DEBUG}
  PSDDebugLog('SerifWindowWatcher', Text);
  {$ELSE}
  OutputDebugString(PChar('[SerifWindowWatcher] ' + Text));
  {$ENDIF}
end;

function TSerifWindowWatchVoicepeak.DebugWindowText(Wnd: HWND): string;
var
  ProcessID: DWORD;
  Rect: TRect;
  ClassName: array[0..255] of Char;
  ProcessFileName: string;
  RectText: string;
begin
  if Wnd = 0 then
    Exit('HWND=0');

  FillChar(ClassName, SizeOf(ClassName), 0);
  GetClassName(Wnd, ClassName, Length(ClassName));
  GetWindowThreadProcessId(Wnd, @ProcessID);
  ProcessFileName := GetProcessFileName(ProcessID);
  if GetWindowRect(Wnd, Rect) then
    RectText := Format('Rect=(%d,%d,%d,%d)', [Rect.Left, Rect.Top, Rect.Right, Rect.Bottom])
  else
    RectText := 'Rect=?';

  Result := Format('HWND=%p PID=%d Process="%s" Title="%s" Class="%s" Visible=%s %s',
    [Pointer(Wnd), ProcessID, ProcessFileName, GetWindowString(Wnd), string(ClassName),
     BoolText(IsWindowVisible(Wnd)), RectText]);
end;

function TSerifWindowWatchVoicepeak.GetAutomation: IUIAutomation;
begin
  if FAutomation = nil then
    FAutomation := CreateComObject(CLSID_CUIAutomation) as IUIAutomation;
  Result := FAutomation;
end;

function TSerifWindowWatchVoicepeak.FindVoicepeakMainWindow: HWND;
var
  Context: TFindVoicepeakMainWindowContext;
begin
  Result := TargetMainWindow;
  if VOICEPEAK_DEBUG_DETAIL then
    DebugLog('VOICEPEAK FindMain TargetMainWindow ' + DebugWindowText(Result));
  if (Result <> 0) and IsTopLevelVisibleWindow(Result) and IsVoicepeakProcessWindow(Result) then
    Exit;

  Result := GetForegroundWindow;
  if VOICEPEAK_DEBUG_DETAIL then
    DebugLog('VOICEPEAK FindMain Foreground ' + DebugWindowText(Result));
  if (Result <> 0) and IsTopLevelVisibleWindow(Result) and IsVoicepeakProcessWindow(Result) then
    Exit;

  Context.Target := Self;
  Context.Wnd := 0;
  EnumWindows(@EnumFindVoicepeakMainWindowProc, LPARAM(Pointer(@Context)));
  Result := Context.Wnd;
end;

procedure TSerifWindowWatchVoicepeak.HandleNewWindow(Wnd: HWND);
begin
  if VOICEPEAK_DEBUG_DETAIL then
    DebugLog('VOICEPEAK HandleNewWindow ' + DebugWindowText(Wnd));

  if not CanHandleWindow(Wnd) then
    Exit;

  if IsVoicepeakOutputSettingsWindow(Wnd) and InvokeVoicepeakOutputButton(Wnd) then
    FOutputActionDone := True;
  if IsVoicepeakFolderSelectWindow(Wnd) and InvokeVoicepeakFolderSelectButton(Wnd) then
    FFolderActionDone := True;
end;

function TSerifWindowWatchVoicepeak.InvokeVoicepeakButtonByText(Wnd: HWND;
  const ButtonText, DebugName: string): Boolean;
var
  Automation: IUIAutomation;
  Root: IUIAutomationElement;
  Condition: IUIAutomationCondition;
  Elements: IUIAutomationElementArray;
  Element: IUIAutomationElement;
  PatternObject: IUnknown;
  InvokePattern: IUIAutomationInvokePattern;
  Count: Integer;
  I: Integer;
  ControlType: UIA_CONTROLTYPE_ID;
  Enabled: BOOL;
  OffScreen: BOOL;
  Name: string;
  Rect: TRectF;
  X: Integer;
  Y: Integer;
begin
  Result := False;
  try
    Automation := GetAutomation;
    if Automation = nil then
      Exit;
    if Failed(Automation.ElementFromHandle(Wnd, Root)) or (Root = nil) then
      Exit;
    if Failed(Automation.CreateTrueCondition(Condition)) or (Condition = nil) then
      Exit;
    if Failed(Root.FindAll(TreeScope_Subtree, Condition, Elements)) or (Elements = nil) then
      Exit;
    if Failed(Elements.get_Length(Count)) then
      Exit;

    for I := 0 to Count - 1 do
    begin
      if Failed(Elements.GetElement(I, Element)) or (Element = nil) then
        Continue;

      ControlType := 0;
      Enabled := False;
      OffScreen := True;
      Element.get_CurrentControlType(ControlType);
      Element.get_CurrentIsEnabled(Enabled);
      Element.get_CurrentIsOffscreen(OffScreen);
      FillChar(Rect, SizeOf(Rect), 0);
      Element.get_CurrentBoundingRectangle(Rect);

      if (Enabled = False) or (OffScreen <> False) then
        Continue;

      Name := UiaElementString(Element, UIA_NamePropertyId);
      if Pos(ButtonText, Name) = 0 then
        Continue;

      PatternObject := nil;
      if Succeeded(Element.GetCurrentPattern(UIA_InvokePatternId, PatternObject)) and
         (PatternObject <> nil) then
      begin
        InvokePattern := PatternObject as IUIAutomationInvokePattern;
        if InvokePattern <> nil then
        begin
          Result := Succeeded(InvokePattern.Invoke);
          DebugLog(Format('%s invoke result=%s', [DebugName, BoolText(Result)]));
          if Result then
            Exit;
        end;
      end;

      if (Rect.Right > Rect.Left) and (Rect.Bottom > Rect.Top) then
      begin
        X := Round((Rect.Left + Rect.Right) / 2);
        Y := Round((Rect.Top + Rect.Bottom) / 2);
        SetCursorPos(X, Y);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
        Result := True;
        DebugLog(Format('%s UIA rect click sent x=%d y=%d rect=(%.0f,%.0f,%.0f,%.0f)',
          [DebugName, X, Y, Rect.Left, Rect.Top, Rect.Right, Rect.Bottom]));
        Exit;
      end;
    end;

    DebugLog(Format('%s button was not found', [DebugName]));
  except
    on E: Exception do
      DebugLog(Format('%s invoke error=%s: %s', [DebugName, E.ClassName, E.Message]));
  end;
end;

function TSerifWindowWatchVoicepeak.InvokeVoicepeakOutputButton(
  Wnd: HWND): Boolean;
begin
  Result := False;
  // VOICEPEAK の出力設定は独自描画フォームで、キーボード操作や UIA Invoke が効かないことがある。
  // タイトル一致で対象を絞れている場合は、まず実ボタン位置をクリックする。
  if IsVoicepeakOutputSettingsWindow(Wnd) then
  if IsVoicepeakOutputSettingsWindow(Wnd) then
    Result := ClickVoicepeakOutputButtonByPosition(Wnd)
  else
    Result := False;
  if not Result then
    Result := InvokeVoicepeakButtonByText(Wnd, SVoicepeakOutputButton, 'VOICEPEAK output');
  if not Result then
    Result := ClickVoicepeakOutputButtonByPosition(Wnd);
  if not Result then
    Result := SendEnterToWindow(Wnd, 'VOICEPEAK output fallback');
  if Result then
  begin
    FOutputSettingsWnd := Wnd;
    DebugLog('VOICEPEAK output settings advanced');
  end;
end;

function TSerifWindowWatchVoicepeak.InvokeVoicepeakFolderSelectButton(
  Wnd: HWND): Boolean;
const
  IDOK = 1;
begin
  Result := InvokeVoicepeakButtonByText(Wnd, SVoicepeakFolderSelectButton,
    'VOICEPEAK folder select');
  if not Result then
  begin
    DebugLog('VOICEPEAK folder select send IDOK ' + DebugWindowText(Wnd));
    SendMessage(Wnd, WM_COMMAND, IDOK, 0);
    Result := True;
  end;
  if not Result then
    Result := SendEnterToWindow(Wnd, 'VOICEPEAK folder select fallback');
  if Result then
  begin
    FFolderSelectWnd := Wnd;
    DebugLog('VOICEPEAK folder select advanced');
  end;
end;

function TSerifWindowWatchVoicepeak.IsVoicepeakOutputSettingsWindow(
  Wnd: HWND): Boolean;
begin
  Result := GetWindowString(Wnd) = SVoicepeakOutputSettingsTitle;
end;

function TSerifWindowWatchVoicepeak.IsVoicepeakFolderSelectWindow(
  Wnd: HWND): Boolean;
var
  ClassName: string;
begin
  ClassName := GetClassString(Wnd);
  Result := (Pos(SVoicepeakFolderSelectTitle, GetWindowString(Wnd)) > 0) and
            ((ClassName = '#32770') or
             (ClassName = 'CabinetWClass') or
             IsVoicepeakProcessWindow(Wnd));
end;

function TSerifWindowWatchVoicepeak.IsVoicepeakOutputSurface(Wnd: HWND): Boolean;
begin
  Result := IsVoicepeakOutputSettingsWindow(Wnd) or
            (IsVoicepeakProcessWindow(Wnd) and
             UiaWindowHasText(Wnd, SVoicepeakFileName, SVoicepeakFormat) and
             (UiaWindowHasText(Wnd, SVoicepeakSplitByBlock, '') or
              UiaWindowHasText(Wnd, SVoicepeakOutputButton, '')));
end;

function TSerifWindowWatchVoicepeak.IsVoicepeakProcessWindow(Wnd: HWND): Boolean;
var
  ProcessID: DWORD;
  ProcessFileName: string;
begin
  GetWindowThreadProcessId(Wnd, @ProcessID);
  ProcessFileName := LowerCase(GetProcessFileName(ProcessID));
  Result := ExtractFileName(ProcessFileName) = 'voicepeak.exe';
  if VOICEPEAK_DEBUG_DETAIL and (ProcessFileName <> '') then
    DebugLog(Format('VOICEPEAK process check result=%s %s',
      [BoolText(Result), DebugWindowText(Wnd)]));
end;

procedure TSerifWindowWatchVoicepeak.Reset;
begin
  FOutputActionDone := False;
  FFolderActionDone := False;
  FOutputSettingsWnd := 0;
  FFolderSelectWnd := 0;
  FDebugScanCount := 0;
  DebugLog('VOICEPEAK reset');
end;

function TSerifWindowWatchVoicepeak.SendEnterToWindow(Wnd: HWND;
  const DebugName: string): Boolean;
begin
  Result := False;
  if Wnd = 0 then
    Exit;

  ShowWindow(Wnd, SW_SHOWNORMAL);
  BringWindowToTop(Wnd);
  SetForegroundWindow(Wnd);
  SetActiveWindow(Wnd);
  keybd_event(VK_RETURN, 0, 0, 0);
  keybd_event(VK_RETURN, 0, KEYEVENTF_KEYUP, 0);
  Result := True;
  DebugLog(Format('%s enter sent %s', [DebugName, DebugWindowText(Wnd)]));
end;

procedure TSerifWindowWatchVoicepeak.Tick;
begin
  ClearClosedActionFlags;
  CheckVoicepeakOutputSettingsWindow;
  CheckVoicepeakFolderSelectWindow;
end;

function TSerifWindowWatchVoicepeak.UiaWindowHasText(Wnd: HWND; const Text1,
  Text2: string): Boolean;
var
  Automation: IUIAutomation;
  Root: IUIAutomationElement;
  Condition: IUIAutomationCondition;
  Elements: IUIAutomationElementArray;
  Element: IUIAutomationElement;
  Count: Integer;
  I: Integer;
  Name: string;
  Found1: Boolean;
  Found2: Boolean;
begin
  Result := False;
  Found1 := Text1 = '';
  Found2 := Text2 = '';
  try
    Automation := GetAutomation;
    if Automation = nil then
      Exit;
    if Failed(Automation.ElementFromHandle(Wnd, Root)) or (Root = nil) then
    begin
      DebugLog('VOICEPEAK text scan ElementFromHandle failed ' + DebugWindowText(Wnd));
      Exit;
    end;
    if Failed(Automation.CreateTrueCondition(Condition)) or (Condition = nil) then
      Exit;
    if Failed(Root.FindAll(TreeScope_Subtree, Condition, Elements)) or (Elements = nil) then
      Exit;
    if Failed(Elements.get_Length(Count)) then
      Exit;

    for I := 0 to Count - 1 do
    begin
      if Failed(Elements.GetElement(I, Element)) or (Element = nil) then
        Continue;

      Name := UiaElementString(Element, UIA_NamePropertyId);
      if (not Found1) and (Pos(Text1, Name) > 0) then
        Found1 := True;
      if (not Found2) and (Pos(Text2, Name) > 0) then
        Found2 := True;

      if Found1 and Found2 then
        Exit(True);
    end;
  except
    on E: Exception do
      DebugLog(Format('VOICEPEAK text scan error=%s: %s', [E.ClassName, E.Message]));
  end;
end;

end.
