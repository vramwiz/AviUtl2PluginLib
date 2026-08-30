unit SerifWindowWatchCeVIOAI;


interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.UIAutomation, System.Classes,
  System.SysUtils, SerifWindowWatchTarget;

type
  // CeVIO AI が表示する保存補助ウィンドウを処理するターゲット。
  TSerifWindowWatchCeVIOAI = class(TSerifWindowWatchTarget)
  private
    FAutomation: IUIAutomation; // OK ボタン探索に使う UI Automation インスタンス
    FInvokeDone: Boolean; // 同じ保存画面で OK を連打しないためのフラグ
    function GetAutomation: IUIAutomation;
    function IsCeVIOAIProcessWindow(Wnd: HWND): Boolean;
    function IsCeVIOAIContinuousWavExportWindow(Wnd: HWND): Boolean;
    procedure CheckCeVIOAIContinuousWavExportWindow;
    function InvokeCeVIOAIOKButton(Wnd: HWND): Boolean;
    function InvokeNativeOKButton(Wnd: HWND): Boolean;
    function SendEnterToWindow(Wnd: HWND): Boolean;
  public
    function AppKind: TSerifSpeechAppKind; override;
    procedure Reset; override;
    procedure Tick; override;
    function CanHandleWindow(Wnd: HWND): Boolean; override;
    procedure HandleNewWindow(Wnd: HWND); override;
  end;

implementation

uses
  Winapi.ActiveX, System.Win.ComObj, SerifWindowWatchUtils;

const
  CEVIOAI_EXPORT_WINDOW_TITLE = 'セリフの連続WAV書き出し';

type
  PFindContinuousWavExportContext = ^TFindContinuousWavExportContext;
  TFindContinuousWavExportContext = record
    Target: TSerifWindowWatchCeVIOAI;
    Found: Boolean;
  end;

  PFindNativeButtonContext = ^TFindNativeButtonContext;
  TFindNativeButtonContext = record
    Found: Boolean;
  end;

function EnumFindContinuousWavExportProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PFindContinuousWavExportContext;
begin
  Context := PFindContinuousWavExportContext(Pointer(LParam));
  if IsTopLevelVisibleWindow(Wnd) and Context.Target.CanHandleWindow(Wnd) then
  begin
    Context.Found := Context.Target.InvokeCeVIOAIOKButton(Wnd);
    Result := False;
    Exit;
  end;
  Result := True;
end;

function EnumFindNativeOKButtonProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PFindNativeButtonContext;
begin
  Context := PFindNativeButtonContext(Pointer(LParam));
  if IsWindowVisible(Wnd) and IsWindowEnabled(Wnd) and
     SameText(GetWindowString(Wnd), 'OK') then
  begin
    SendMessage(Wnd, BM_CLICK, 0, 0);
    Context.Found := True;
    Result := False;
    Exit;
  end;
  Result := True;
end;

{ TSerifWindowWatchCeVIOAI }

function TSerifWindowWatchCeVIOAI.AppKind: TSerifSpeechAppKind;
begin
  Result := ssakCeVIOAI;
end;

function TSerifWindowWatchCeVIOAI.CanHandleWindow(Wnd: HWND): Boolean;
begin
  Result := IsTopLevelVisibleWindow(Wnd) and
            (IsTargetProcessWindow(Wnd) or IsCeVIOAIProcessWindow(Wnd) or
             (Pos('WindowsForms10.Window.8.app.', GetClassString(Wnd)) = 1)) and
            IsCeVIOAIContinuousWavExportWindow(Wnd);
end;

procedure TSerifWindowWatchCeVIOAI.CheckCeVIOAIContinuousWavExportWindow;
var
  Context: TFindContinuousWavExportContext;
begin
  // 連続 WAV 書き出し Tick: 開始時点で既に開いていた画面も拾って OK を押す。
  if FInvokeDone then
    Exit;

  Context.Target := Self;
  Context.Found := False;
  EnumWindows(@EnumFindContinuousWavExportProc, LPARAM(Pointer(@Context)));
  if Context.Found then
    FInvokeDone := True;
end;

function TSerifWindowWatchCeVIOAI.GetAutomation: IUIAutomation;
begin
  if FAutomation = nil then
    FAutomation := CreateComObject(CLSID_CUIAutomation) as IUIAutomation;
  Result := FAutomation;
end;

procedure TSerifWindowWatchCeVIOAI.HandleNewWindow(Wnd: HWND);
begin
  if not CanHandleWindow(Wnd) then
    Exit;
  if FInvokeDone then
    Exit;

  if InvokeCeVIOAIOKButton(Wnd) then
  begin
    FInvokeDone := True;
    OutputDebugString('[SerifWindowWatcher] CeVIO AI continuous WAV export OK invoked')
  end
  else
    OutputDebugString('[SerifWindowWatcher] CeVIO AI continuous WAV export OK failed');
end;

function TSerifWindowWatchCeVIOAI.InvokeCeVIOAIOKButton(Wnd: HWND): Boolean;
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

      if (Enabled = False) or
         (OffScreen <> False) then
        Continue;

      Name := Trim(UiaElementString(Element, UIA_NamePropertyId));
      if not SameText(Name, 'OK') then
        Continue;

      PatternObject := nil;
      if Failed(Element.GetCurrentPattern(UIA_InvokePatternId, PatternObject)) or
         (PatternObject = nil) then
        Continue;

      InvokePattern := PatternObject as IUIAutomationInvokePattern;
      if InvokePattern = nil then
        Continue;

      Result := Succeeded(InvokePattern.Invoke);
      Exit;
    end;
  except
    on E: Exception do
      OutputDebugString(PChar(Format('[SerifWindowWatcher] CeVIO AI OK invoke error=%s: %s', [E.ClassName, E.Message])));
  end;

  if not Result then
    Result := InvokeNativeOKButton(Wnd);
  if not Result then
    Result := SendEnterToWindow(Wnd);
end;

function TSerifWindowWatchCeVIOAI.InvokeNativeOKButton(Wnd: HWND): Boolean;
var
  Context: TFindNativeButtonContext;
begin
  // WinForms フォールバック: UIA で押せない場合は子ウィンドウの OK ボタンを直接クリックする。
  Context.Found := False;
  EnumChildWindows(Wnd, @EnumFindNativeOKButtonProc, LPARAM(Pointer(@Context)));
  Result := Context.Found;
  if Result then
    OutputDebugString('[SerifWindowWatcher] CeVIO AI native OK clicked');
end;

function TSerifWindowWatchCeVIOAI.IsCeVIOAIContinuousWavExportWindow(
  Wnd: HWND): Boolean;
begin
  Result := GetWindowString(Wnd) = CEVIOAI_EXPORT_WINDOW_TITLE;
end;

function TSerifWindowWatchCeVIOAI.IsCeVIOAIProcessWindow(Wnd: HWND): Boolean;
var
  ProcessID: DWORD;
  ProcessFileName: string;
begin
  GetWindowThreadProcessId(Wnd, @ProcessID);
  ProcessFileName := LowerCase(GetProcessFileName(ProcessID));
  Result := SameText(ExtractFileName(ProcessFileName), 'cevio ai.exe');
end;

procedure TSerifWindowWatchCeVIOAI.Reset;
begin
  FInvokeDone := False;
end;

function TSerifWindowWatchCeVIOAI.SendEnterToWindow(Wnd: HWND): Boolean;
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
end;

procedure TSerifWindowWatchCeVIOAI.Tick;
begin
  CheckCeVIOAIContinuousWavExportWindow;
end;

end.
