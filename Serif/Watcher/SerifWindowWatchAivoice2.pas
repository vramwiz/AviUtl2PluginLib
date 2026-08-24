unit SerifWindowWatchAivoice2;

interface

uses
  Winapi.Windows, Winapi.UIAutomation, System.Classes, System.SysUtils,
  SerifWindowWatchTarget;

type
  TSerifAivoice2ExportFlowState = (
    a2efsIdle,
    a2efsWaitFinalOK
  );

type
  // A.I.VOICE2 Editor が表示する書き出し関連ウィンドウを処理するターゲット。
  TSerifWindowWatchAivoice2 = class(TSerifWindowWatchTarget)
  private
    FAutomation: IUIAutomation;
    FExportFlowState: TSerifAivoice2ExportFlowState;
    FFinalOKScanCount: Integer;
    FFinalOKWaitCount: Integer;
    FMainSurfaceScanWaitCount: Integer;
    function GetAutomation: IUIAutomation;
    procedure CheckAivoice2FinalOKDialog;
    procedure CheckAivoice2MainSurface;
    procedure FinishAivoice2ExportFlow(const DebugName: string);
    function FindAivoice2MainWindow: HWND;
    function IsAivoice2ProcessWindow(Wnd: HWND): Boolean;
    function IsAivoice2MainWindow(Wnd: HWND): Boolean;
    function IsAivoice2ExportWindow(Wnd: HWND): Boolean;
    function IsAivoice2ExportSurface(Wnd: HWND): Boolean;
    function IsAivoice2ExportButtonPixelVisible(Wnd: HWND): Boolean;
    function IsAivoice2OverwriteDialog(Wnd: HWND): Boolean;
    function IsAivoice2FinalOKDialog(Wnd: HWND): Boolean;
    function UiaWindowHasText(Wnd: HWND; const Text1, Text2: string): Boolean;
    function InvokeAivoice2ButtonByText(Wnd: HWND; const ButtonText,
      DebugName: string): Boolean;
    function InvokeAivoice2ExportButton(Wnd: HWND): Boolean;
    function ClickAivoice2ExportButtonByPosition(Wnd: HWND): Boolean;
    function InvokeAivoice2OKButton(Wnd: HWND; const DebugName: string): Boolean;
    procedure StartFinalOKWait;
    function SendEnterToWindow(Wnd: HWND; const DebugName: string): Boolean;
    function FormatWindowInfo(Wnd: HWND): string;
    procedure AddUIAutomationInfo(Wnd: HWND; Lines: TStrings);
    procedure DebugLog(const Text: string);
    procedure OutputWindowInfo(const Text: string);
  public
    function AppKind: TSerifSpeechAppKind; override;
    procedure Reset; override;
    procedure Tick; override;
    function CanHandleWindow(Wnd: HWND): Boolean; override;
    procedure HandleNewWindow(Wnd: HWND); override;
  end;

implementation

uses
  Winapi.ActiveX, System.Win.ComObj, System.Types, SerifWindowWatchUtils
  {$IFDEF DEBUG}, PSDImageDebugLog{$ENDIF};

const
  AIVOICE2_DEBUG_DETAIL = True;
  AIVOICE2_FINAL_OK_SCAN_COUNT = 30;
  AIVOICE2_FINAL_OK_INITIAL_WAIT = 5;
  AIVOICE2_MAIN_SURFACE_SCAN_INTERVAL = 3;
  AIVOICE2_EXPORT_BUTTON_REL_X = 0.684;
  AIVOICE2_EXPORT_BUTTON_REL_Y = 0.662;

type
  PFindAivoice2FinalOKDialogContext = ^TFindAivoice2FinalOKDialogContext;
  TFindAivoice2FinalOKDialogContext = record
    Target: TSerifWindowWatchAivoice2;
    Found: Boolean;
  end;

  PFindAivoice2MainWindowContext = ^TFindAivoice2MainWindowContext;
  TFindAivoice2MainWindowContext = record
    Target: TSerifWindowWatchAivoice2;
    Wnd: HWND;
  end;

function EnumAivoice2ChildInfoProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Lines: TStrings;
  ProcessID: DWORD;
  ThreadID: DWORD;
begin
  Lines := TStrings(Pointer(LParam));
  ThreadID := GetWindowThreadProcessId(Wnd, @ProcessID);
  Lines.Add(Format('  HWND=%p Class="%s" Text="%s" CtrlID=%d Visible=%s Enabled=%s ThreadID=%d ProcessID=%d Style=%s ExStyle=%s',
    [Pointer(Wnd), GetClassString(Wnd), GetWindowString(Wnd), GetDlgCtrlID(Wnd),
     BoolText(IsWindowVisible(Wnd)), BoolText(IsWindowEnabled(Wnd)), ThreadID, ProcessID,
     WindowStyleText(GetWindowLongPtr(Wnd, GWL_STYLE)),
     WindowStyleText(GetWindowLongPtr(Wnd, GWL_EXSTYLE))]));
  Result := True;
end;

function EnumFindAivoice2FinalOKDialogProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PFindAivoice2FinalOKDialogContext;
begin
  Context := PFindAivoice2FinalOKDialogContext(Pointer(LParam));
  if Context.Target.FExportFlowState <> a2efsWaitFinalOK then
  begin
    Result := False;
    Exit;
  end;

  if IsTopLevelVisibleWindow(Wnd) and
     Context.Target.IsAivoice2ProcessWindow(Wnd) then
  begin
    if Context.Target.IsAivoice2OverwriteDialog(Wnd) then
    begin
      Context.Target.InvokeAivoice2ButtonByText(Wnd, '上書き', 'A.I.VOICE2 overwrite');
      Result := False;
      Exit;
    end;

    if Context.Target.IsAivoice2ExportWindow(Wnd) then
    begin
      Result := True;
      Exit;
    end;

    if Context.Target.IsAivoice2FinalOKDialog(Wnd) then
    begin
      Context.Found := Context.Target.InvokeAivoice2OKButton(Wnd, 'A.I.VOICE2 final OK');
      Result := not Context.Found;
      Exit;
    end;
  end;

  Result := True;
end;

{ TSerifWindowWatchAivoice2 }

function TSerifWindowWatchAivoice2.AppKind: TSerifSpeechAppKind;
begin
  Result := ssakAivoice2;
end;

procedure TSerifWindowWatchAivoice2.AddUIAutomationInfo(Wnd: HWND;
  Lines: TStrings);
const
  MAX_UIA_ELEMENTS = 220;
var
  Automation: IUIAutomation;
  Root: IUIAutomationElement;
  Condition: IUIAutomationCondition;
  Elements: IUIAutomationElementArray;
  Element: IUIAutomationElement;
  Count: Integer;
  I: Integer;
  ControlType: UIA_CONTROLTYPE_ID;
  NativeHandle: HWND;
  Enabled: BOOL;
  OffScreen: BOOL;
  Rect: TRectF;
  Name: string;
  AutomationId: string;
  ClassName: string;
  HasInvoke: Boolean;
  ActionLines: TStringList;
  DetailLines: TStringList;
begin
  Lines.Add('UIAutomation:');
  ActionLines := TStringList.Create;
  DetailLines := TStringList.Create;
  try
    try
      Automation := GetAutomation;
      if Automation = nil then
      begin
        Lines.Add('  Not available');
        Exit;
      end;

      if Failed(Automation.ElementFromHandle(Wnd, Root)) or (Root = nil) then
      begin
        Lines.Add('  ElementFromHandle failed');
        Exit;
      end;
      if Failed(Automation.CreateTrueCondition(Condition)) or (Condition = nil) then
      begin
        Lines.Add('  CreateTrueCondition failed');
        Exit;
      end;
      if Failed(Root.FindAll(TreeScope_Subtree, Condition, Elements)) or (Elements = nil) then
      begin
        Lines.Add('  FindAll failed');
        Exit;
      end;
      if Failed(Elements.get_Length(Count)) then
      begin
        Lines.Add('  get_Length failed');
        Exit;
      end;

      Lines.Add(Format('  Count=%d', [Count]));
      if Count > MAX_UIA_ELEMENTS then
        Count := MAX_UIA_ELEMENTS;

      for I := 0 to Count - 1 do
      begin
        if Failed(Elements.GetElement(I, Element)) or (Element = nil) then
          Continue;

        ControlType := 0;
        NativeHandle := 0;
        Enabled := False;
        OffScreen := False;
        FillChar(Rect, SizeOf(Rect), 0);

        Element.get_CurrentControlType(ControlType);
        Element.get_CurrentNativeWindowHandle(NativeHandle);
        Element.get_CurrentIsEnabled(Enabled);
        Element.get_CurrentIsOffscreen(OffScreen);
        Element.get_CurrentBoundingRectangle(Rect);
        Name := UiaElementString(Element, UIA_NamePropertyId);
        AutomationId := UiaElementString(Element, UIA_AutomationIdPropertyId);
        ClassName := UiaElementString(Element, UIA_ClassNamePropertyId);
        HasInvoke := UiaHasInvokePattern(Element);

        DetailLines.Add(Format('  [%d] Type=%s Name="%s" AutomationId="%s" Class="%s" HWND=%p Enabled=%s OffScreen=%s Invoke=%s Rect=(%.0f,%.0f,%.0f,%.0f)',
          [I, UiaControlTypeText(ControlType), Name, AutomationId, ClassName,
           Pointer(NativeHandle), BoolText(Enabled <> False), BoolText(OffScreen <> False),
           BoolText(HasInvoke), Rect.Left, Rect.Top, Rect.Right, Rect.Bottom]));

        if (ControlType = UIA_ButtonControlTypeId) or HasInvoke then
          ActionLines.Add(Format('  [%d] Type=%s Name="%s" AutomationId="%s" Class="%s" HWND=%p Enabled=%s OffScreen=%s Invoke=%s',
            [I, UiaControlTypeText(ControlType), Name, AutomationId, ClassName,
             Pointer(NativeHandle), BoolText(Enabled <> False), BoolText(OffScreen <> False),
             BoolText(HasInvoke)]));
      end;

      Lines.Add('  Actionable:');
      if ActionLines.Count = 0 then
        Lines.Add('    None')
      else
        Lines.AddStrings(ActionLines);
      Lines.Add('  AllElements:');
      Lines.AddStrings(DetailLines);
    except
      on E: Exception do
        Lines.Add('  Error=' + E.ClassName + ': ' + E.Message);
    end;
  finally
    DetailLines.Free;
    ActionLines.Free;
  end;
end;

function TSerifWindowWatchAivoice2.CanHandleWindow(Wnd: HWND): Boolean;
var
  TopLevel: Boolean;
  TargetProcess: Boolean;
  ExportWindow: Boolean;
  OverwriteDialog: Boolean;
  FinalOKDialog: Boolean;
begin
  TopLevel := IsTopLevelVisibleWindow(Wnd);
  TargetProcess := TopLevel and (IsTargetProcessWindow(Wnd) or IsAivoice2ProcessWindow(Wnd));
  ExportWindow := TargetProcess and IsAivoice2ExportWindow(Wnd);
  OverwriteDialog := TargetProcess and IsAivoice2OverwriteDialog(Wnd);
  FinalOKDialog := TargetProcess and IsAivoice2FinalOKDialog(Wnd);
  Result := TargetProcess and (ExportWindow or OverwriteDialog or FinalOKDialog);

  if AIVOICE2_DEBUG_DETAIL and TargetProcess then
  begin
    DebugLog(Format('A.I.VOICE2 CanHandle HWND=%p Result=%s Export=%s Overwrite=%s FinalOK=%s Title="%s" Class="%s"',
      [Pointer(Wnd), BoolText(Result), BoolText(ExportWindow), BoolText(OverwriteDialog),
       BoolText(FinalOKDialog), GetWindowString(Wnd), GetClassString(Wnd)]));
    OutputWindowInfo(FormatWindowInfo(Wnd));
  end;
end;

function EnumFindAivoice2MainWindowProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PFindAivoice2MainWindowContext;
begin
  Context := PFindAivoice2MainWindowContext(Pointer(LParam));
  if Context.Target.IsAivoice2MainWindow(Wnd) then
  begin
    Context.Wnd := Wnd;
    Result := False;
    Exit;
  end;

  Result := True;
end;

procedure TSerifWindowWatchAivoice2.CheckAivoice2FinalOKDialog;
var
  Context: TFindAivoice2FinalOKDialogContext;
begin
  if FExportFlowState <> a2efsWaitFinalOK then
    Exit;

  if FFinalOKWaitCount > 0 then
  begin
    Dec(FFinalOKWaitCount);
    Exit;
  end;

  if FFinalOKScanCount <= 0 then
  begin
    FinishAivoice2ExportFlow('A.I.VOICE2 final OK scan timeout');
    Exit;
  end;

  Dec(FFinalOKScanCount);
  Context.Target := Self;
  Context.Found := False;
  EnumWindows(@EnumFindAivoice2FinalOKDialogProc, LPARAM(Pointer(@Context)));

  if Context.Found then
    FinishAivoice2ExportFlow('A.I.VOICE2 final OK');
end;

procedure TSerifWindowWatchAivoice2.CheckAivoice2MainSurface;
var
  Wnd: HWND;
begin
  if FExportFlowState <> a2efsIdle then
    Exit;

  if FMainSurfaceScanWaitCount > 0 then
  begin
    Dec(FMainSurfaceScanWaitCount);
    Exit;
  end;
  FMainSurfaceScanWaitCount := AIVOICE2_MAIN_SURFACE_SCAN_INTERVAL;

  Wnd := FindAivoice2MainWindow;
  if Wnd = 0 then
    Exit;

  if not IsAivoice2ExportSurface(Wnd) then
    Exit;

  DebugLog(Format('A.I.VOICE2 export surface detected HWND=%p', [Pointer(Wnd)]));
  InvokeAivoice2ExportButton(Wnd);
end;

function TSerifWindowWatchAivoice2.ClickAivoice2ExportButtonByPosition(
  Wnd: HWND): Boolean;
var
  Rect: TRect;
  X: Integer;
  Y: Integer;
begin
  Result := False;
  if not GetWindowRect(Wnd, Rect) then
    Exit;

  X := Rect.Left + Round((Rect.Right - Rect.Left) * AIVOICE2_EXPORT_BUTTON_REL_X);
  Y := Rect.Top + Round((Rect.Bottom - Rect.Top) * AIVOICE2_EXPORT_BUTTON_REL_Y);

  ShowWindow(Wnd, SW_SHOWNORMAL);
  BringWindowToTop(Wnd);
  SetForegroundWindow(Wnd);
  SetActiveWindow(Wnd);
  SetCursorPos(X, Y);
  mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
  mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
  Result := True;
  DebugLog(Format('A.I.VOICE2 export execute position click sent x=%d y=%d rect=(%d,%d,%d,%d)',
    [X, Y, Rect.Left, Rect.Top, Rect.Right, Rect.Bottom]));
end;

procedure TSerifWindowWatchAivoice2.FinishAivoice2ExportFlow(
  const DebugName: string);
begin
  Reset;
  DebugLog(Format('%s flow finished', [DebugName]));
end;

function TSerifWindowWatchAivoice2.FindAivoice2MainWindow: HWND;
var
  Context: TFindAivoice2MainWindowContext;
begin
  Result := TargetMainWindow;
  if IsAivoice2MainWindow(Result) then
    Exit;

  Context.Target := Self;
  Context.Wnd := 0;
  EnumWindows(@EnumFindAivoice2MainWindowProc, LPARAM(Pointer(@Context)));
  Result := Context.Wnd;
end;

function TSerifWindowWatchAivoice2.FormatWindowInfo(Wnd: HWND): string;
var
  Lines: TStringList;
  ProcessID: DWORD;
  ThreadID: DWORD;
  OwnerWnd: HWND;
  ParentWnd: HWND;
  Rect: TRect;
begin
  Lines := TStringList.Create;
  try
    ThreadID := GetWindowThreadProcessId(Wnd, @ProcessID);
    OwnerWnd := GetWindow(Wnd, GW_OWNER);
    ParentWnd := GetParent(Wnd);
    GetWindowRect(Wnd, Rect);

    Lines.Add('[SerifWindowWatcher] A.I.VOICE2 window detected');
    Lines.Add(Format('HWND=%p', [Pointer(Wnd)]));
    Lines.Add(Format('Title="%s"', [GetWindowString(Wnd)]));
    Lines.Add(Format('Class="%s"', [GetClassString(Wnd)]));
    Lines.Add(Format('Visible=%s Enabled=%s', [BoolText(IsWindowVisible(Wnd)), BoolText(IsWindowEnabled(Wnd))]));
    Lines.Add(Format('ThreadID=%d ProcessID=%d', [ThreadID, ProcessID]));
    Lines.Add(Format('Process="%s"', [GetProcessFileName(ProcessID)]));
    Lines.Add(Format('ParentHWND=%p OwnerHWND=%p', [Pointer(ParentWnd), Pointer(OwnerWnd)]));
    Lines.Add(Format('Rect=(Left:%d Top:%d Right:%d Bottom:%d Width:%d Height:%d)',
      [Rect.Left, Rect.Top, Rect.Right, Rect.Bottom, Rect.Right - Rect.Left, Rect.Bottom - Rect.Top]));
    Lines.Add(Format('Style=%s ExStyle=%s',
      [WindowStyleText(GetWindowLongPtr(Wnd, GWL_STYLE)),
       WindowStyleText(GetWindowLongPtr(Wnd, GWL_EXSTYLE))]));
    Lines.Add(Format('Aivoice2Process=%s', [BoolText(IsAivoice2ProcessWindow(Wnd))]));
    Lines.Add(Format('Aivoice2ExportWindow=%s', [BoolText(IsAivoice2ExportWindow(Wnd))]));
    Lines.Add(Format('Aivoice2OverwriteDialog=%s', [BoolText(IsAivoice2OverwriteDialog(Wnd))]));
    Lines.Add(Format('Aivoice2FinalOKDialog=%s', [BoolText(IsAivoice2FinalOKDialog(Wnd))]));
    Lines.Add('Children:');
    EnumChildWindows(Wnd, @EnumAivoice2ChildInfoProc, LPARAM(Pointer(Lines)));
    AddUIAutomationInfo(Wnd, Lines);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure TSerifWindowWatchAivoice2.DebugLog(const Text: string);
begin
  {$IFDEF DEBUG}
  PSDDebugLog('SerifWindowWatcher', Text);
  {$ELSE}
  OutputDebugString(PChar('[SerifWindowWatcher] ' + Text));
  {$ENDIF}
end;

function TSerifWindowWatchAivoice2.GetAutomation: IUIAutomation;
begin
  if FAutomation = nil then
    FAutomation := CreateComObject(CLSID_CUIAutomation) as IUIAutomation;
  Result := FAutomation;
end;

procedure TSerifWindowWatchAivoice2.HandleNewWindow(Wnd: HWND);
begin
  if not CanHandleWindow(Wnd) then
    Exit;

  if AIVOICE2_DEBUG_DETAIL then
    DebugLog(Format('A.I.VOICE2 HandleNewWindow HWND=%p Title="%s"', [Pointer(Wnd), GetWindowString(Wnd)]));

  if IsAivoice2ExportWindow(Wnd) and (FExportFlowState = a2efsIdle) then
    InvokeAivoice2ExportButton(Wnd);

  if IsAivoice2OverwriteDialog(Wnd) then
    InvokeAivoice2ButtonByText(Wnd, '上書き', 'A.I.VOICE2 overwrite');

  if IsAivoice2FinalOKDialog(Wnd) then
  begin
    if InvokeAivoice2OKButton(Wnd, 'A.I.VOICE2 final OK') then
      FinishAivoice2ExportFlow('A.I.VOICE2 final OK');
  end;
end;

function TSerifWindowWatchAivoice2.InvokeAivoice2ButtonByText(Wnd: HWND;
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

      if (ControlType <> UIA_ButtonControlTypeId) or
         (Enabled = False) or
         (OffScreen <> False) then
        Continue;

      Name := UiaElementString(Element, UIA_NamePropertyId);
      if AIVOICE2_DEBUG_DETAIL and (ControlType = UIA_ButtonControlTypeId) then
        DebugLog(Format('%s candidate button Name="%s" Enabled=%s OffScreen=%s',
          [DebugName, Name, BoolText(Enabled <> False), BoolText(OffScreen <> False)]));
      if Pos(ButtonText, Name) = 0 then
        Continue;

      PatternObject := nil;
      if Failed(Element.GetCurrentPattern(UIA_InvokePatternId, PatternObject)) or
         (PatternObject = nil) then
        Continue;

      InvokePattern := PatternObject as IUIAutomationInvokePattern;
      if InvokePattern = nil then
        Continue;

      Result := Succeeded(InvokePattern.Invoke);
      DebugLog(Format('%s invoke result=%s', [DebugName, BoolText(Result)]));
      Exit;
    end;

    DebugLog(Format('%s button was not found', [DebugName]));
  except
    on E: Exception do
      DebugLog(Format('%s invoke error=%s: %s', [DebugName, E.ClassName, E.Message]));
  end;
end;

function TSerifWindowWatchAivoice2.InvokeAivoice2ExportButton(Wnd: HWND): Boolean;
begin
  Result := InvokeAivoice2ButtonByText(Wnd, '書き出しを実行', 'A.I.VOICE2 export execute');
  if (not Result) and IsAivoice2ExportButtonPixelVisible(Wnd) then
    Result := ClickAivoice2ExportButtonByPosition(Wnd);
  if not Result then
    Result := SendEnterToWindow(Wnd, 'A.I.VOICE2 export execute fallback');
  if Result then
  begin
    StartFinalOKWait;
    DebugLog('A.I.VOICE2 export execute invoked');
  end;
end;

function TSerifWindowWatchAivoice2.InvokeAivoice2OKButton(Wnd: HWND;
  const DebugName: string): Boolean;
begin
  Result := InvokeAivoice2ButtonByText(Wnd, 'OK', DebugName);
  if not Result then
    Result := SendEnterToWindow(Wnd, DebugName);
end;

function TSerifWindowWatchAivoice2.IsAivoice2ExportWindow(Wnd: HWND): Boolean;
begin
  Result := (GetWindowString(Wnd) = '書き出し（命名規則）') and
            IsAivoice2ProcessWindow(Wnd) and
            UiaWindowHasText(Wnd, '保存先フォルダ', '命名規則') and
            UiaWindowHasText(Wnd, '書き出しを実行', '');
end;

function TSerifWindowWatchAivoice2.IsAivoice2ExportButtonPixelVisible(
  Wnd: HWND): Boolean;
var
  Rect: TRect;
  DC: HDC;
  X: Integer;
  Y: Integer;
  Pixel: COLORREF;
  R: Byte;
  G: Byte;
  B: Byte;
begin
  Result := False;
  if not IsAivoice2MainWindow(Wnd) then
    Exit;
  if not GetWindowRect(Wnd, Rect) then
    Exit;

  X := Rect.Left + Round((Rect.Right - Rect.Left) * AIVOICE2_EXPORT_BUTTON_REL_X);
  Y := Rect.Top + Round((Rect.Bottom - Rect.Top) * AIVOICE2_EXPORT_BUTTON_REL_Y);
  DC := GetDC(0);
  if DC = 0 then
    Exit;
  try
    Pixel := GetPixel(DC, X, Y);
  finally
    ReleaseDC(0, DC);
  end;

  if Pixel = CLR_INVALID then
    Exit;

  R := GetRValue(Pixel);
  G := GetGValue(Pixel);
  B := GetBValue(Pixel);

  // 添付画像の「書き出しを実行」ボタンは明るい青緑。UIA で見えない時の安全弁にする。
  Result := (G >= 150) and (B >= 140) and (R <= 140) and
            (Abs(Integer(G) - Integer(B)) <= 80);
  if Result or AIVOICE2_DEBUG_DETAIL then
    DebugLog(Format('A.I.VOICE2 export button pixel x=%d y=%d rgb=(%d,%d,%d) match=%s',
      [X, Y, R, G, B, BoolText(Result)]));
end;

function TSerifWindowWatchAivoice2.IsAivoice2ExportSurface(Wnd: HWND): Boolean;
begin
  Result := IsAivoice2ExportWindow(Wnd) or
            (IsAivoice2MainWindow(Wnd) and
             (UiaWindowHasText(Wnd, '保存先フォルダ', '書き出しを実行') or
              IsAivoice2ExportButtonPixelVisible(Wnd)));
end;

function TSerifWindowWatchAivoice2.IsAivoice2MainWindow(Wnd: HWND): Boolean;
begin
  Result := IsTopLevelVisibleWindow(Wnd) and
            IsAivoice2ProcessWindow(Wnd) and
            (GetClassString(Wnd) = 'FLUTTER_RUNNER_WIN32_WINDOW') and
            (Pos('A.I.VOICE2 Editor', GetWindowString(Wnd)) > 0);
end;

procedure TSerifWindowWatchAivoice2.OutputWindowInfo(const Text: string);
var
  DebugText: string;
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := Text;
    for I := 0 to Lines.Count - 1 do
    begin
      DebugText := Lines[I];
      DebugLog(DebugText);
    end;
  finally
    Lines.Free;
  end;
end;

function TSerifWindowWatchAivoice2.IsAivoice2FinalOKDialog(Wnd: HWND): Boolean;
begin
  Result := ((GetWindowString(Wnd) = '情報') or
             (GetWindowString(Wnd) = '完了')) and
            IsAivoice2ProcessWindow(Wnd) and
            (UiaWindowHasText(Wnd, '書き出し', '完了') or
             UiaWindowHasText(Wnd, '保存', '完了'));
end;

function TSerifWindowWatchAivoice2.IsAivoice2OverwriteDialog(Wnd: HWND): Boolean;
begin
  Result := ((GetWindowString(Wnd) = '確認') or
             (GetWindowString(Wnd) = 'ファイル保存')) and
            IsAivoice2ProcessWindow(Wnd) and
            UiaWindowHasText(Wnd, '既に存在', '上書き');
end;

function TSerifWindowWatchAivoice2.IsAivoice2ProcessWindow(Wnd: HWND): Boolean;
var
  ProcessID: DWORD;
  ProcessFileName: string;
begin
  GetWindowThreadProcessId(Wnd, @ProcessID);
  ProcessFileName := LowerCase(GetProcessFileName(ProcessID));
  Result := ExtractFileName(ProcessFileName) = 'aivoice.exe';
end;

procedure TSerifWindowWatchAivoice2.Reset;
begin
  FExportFlowState := a2efsIdle;
  FFinalOKScanCount := 0;
  FFinalOKWaitCount := 0;
  FMainSurfaceScanWaitCount := 0;
end;

function TSerifWindowWatchAivoice2.SendEnterToWindow(Wnd: HWND;
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
  DebugLog(Format('%s enter sent', [DebugName]));
end;

procedure TSerifWindowWatchAivoice2.StartFinalOKWait;
begin
  FExportFlowState := a2efsWaitFinalOK;
  FFinalOKScanCount := AIVOICE2_FINAL_OK_SCAN_COUNT;
  FFinalOKWaitCount := AIVOICE2_FINAL_OK_INITIAL_WAIT;
end;

procedure TSerifWindowWatchAivoice2.Tick;
begin
  CheckAivoice2MainSurface;
  CheckAivoice2FinalOKDialog;
end;

function TSerifWindowWatchAivoice2.UiaWindowHasText(Wnd: HWND; const Text1,
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
      DebugLog(Format('A.I.VOICE2 text scan error=%s: %s', [E.ClassName, E.Message]));
  end;
end;

end.

