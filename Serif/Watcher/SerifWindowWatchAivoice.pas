unit SerifWindowWatchAivoice;

interface

uses
  Winapi.Windows, Winapi.UIAutomation, System.Classes, System.SysUtils,
  SerifWindowWatchTarget;

type
  TSerifAivoiceSaveFlowState = (
    asfsIdle,
    asfsWaitFinalOK
  );

type
  // A.I.VOICE が表示する補助ウィンドウの調査用ターゲット。
  TSerifWindowWatchAivoice = class(TSerifWindowWatchTarget)
  private
    FAutomation: IUIAutomation; // デバッグ出力に使う UI Automation インスタンス
    FAivoiceFlowState: TSerifAivoiceSaveFlowState;
    FFinalOKScanCount: Integer;
    FFinalOKWaitCount: Integer;
    FFinalOKActionDone: Boolean;
    function GetAutomation: IUIAutomation;
    procedure CheckAivoiceFinalOKDialog;
    procedure FinishAivoiceSaveFlow(const DebugName: string);
    function IsAivoiceProcessWindow(Wnd: HWND): Boolean;
    function IsAivoiceSaveWindow(Wnd: HWND): Boolean;
    function IsAivoiceConfirmDialog(Wnd: HWND): Boolean;
    function IsAivoiceOverwriteConfirmDialog(Wnd: HWND): Boolean;
    function IsAivoiceBusyErrorDialog(Wnd: HWND): Boolean;
    function IsAivoiceFinalOKDialog(Wnd: HWND): Boolean;
    function IsAivoiceFileSaveDialog(Wnd: HWND): Boolean;
    function UiaWindowHasText(Wnd: HWND; const Text1, Text2: string): Boolean;
    function InvokeAivoiceOKButton(Wnd: HWND; const DebugName: string;
      LogNotFound: Boolean = True): Boolean;
    function InvokeAivoiceButtonByText(Wnd: HWND; const ButtonText,
      DebugName: string): Boolean;
    function InvokeAivoiceYesButton(Wnd: HWND; const DebugName: string): Boolean;
    function InvokeAivoiceSaveOK(Wnd: HWND): Boolean;
    procedure StartFinalOKWait;
    function SendEnterToWindow(Wnd: HWND; const DebugName: string): Boolean;
    function FormatWindowInfo(Wnd: HWND): string;
    procedure AddUIAutomationInfo(Wnd: HWND; Lines: TStrings);
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
  Winapi.ActiveX, System.Win.ComObj, System.Types, SerifWindowWatchUtils;

const
  AIVOICE_DEBUG_DETAIL = False;
  AIVOICE_IGNORE_TARGET_WINDOW_FOR_DEBUG = False;
  AIVOICE_FINAL_OK_SCAN_COUNT = 600;
  AIVOICE_FINAL_OK_INITIAL_WAIT = 5;

type
  PFindFinalOKDialogContext = ^TFindFinalOKDialogContext;
  TFindFinalOKDialogContext = record
    Target: TSerifWindowWatchAivoice;
    Found: Boolean;
  end;

function EnumChildInfoProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
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

function EnumFindFinalOKDialogProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PFindFinalOKDialogContext;
begin
  Context := PFindFinalOKDialogContext(Pointer(LParam));
  if Context.Target.FAivoiceFlowState <> asfsWaitFinalOK then
  begin
    Result := False;
    Exit;
  end;

  if IsTopLevelVisibleWindow(Wnd) and
     Context.Target.IsAivoiceProcessWindow(Wnd) then
  begin
    // 上書き確認ルート: 既存ファイルがある場合は「上書き」を選ぶ。
    if Context.Target.IsAivoiceOverwriteConfirmDialog(Wnd) then
    begin
      Context.Target.InvokeAivoiceButtonByText(Wnd, '上書き', 'A.I.VOICE overwrite');
      Result := False;
      Exit;
    end;

    // ビジーエラールート: 前回の合成処理が残っている警告を閉じる。
    if Context.Target.IsAivoiceBusyErrorDialog(Wnd) then
    begin
      Context.Target.InvokeAivoiceOKButton(Wnd, 'A.I.VOICE busy error OK', False);
      Result := False;
      Exit;
    end;

    // 保存設定/保存ダイアログ除外: まだ完了 OK ではないため監視を続ける。
    if Context.Target.IsAivoiceSaveWindow(Wnd) or
       Context.Target.IsAivoiceFileSaveDialog(Wnd) then
    begin
      Result := True;
      Exit;
    end;

    if not Context.Target.IsAivoiceFinalOKDialog(Wnd) then
    begin
      Result := True;
      Exit;
    end;

    // 完了 OK ルート: 進捗完了後の情報ダイアログを閉じる。
    Context.Found := Context.Target.InvokeAivoiceOKButton(Wnd, 'A.I.VOICE final OK', False);
    if Context.Found then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

{ TSerifWindowWatchAivoice }

procedure TSerifWindowWatchAivoice.AddUIAutomationInfo(Wnd: HWND; Lines: TStrings);
const
  MAX_UIA_ELEMENTS = 160;
var
  Automation: IUIAutomation;
  Root: IUIAutomationElement;
  Condition: IUIAutomationCondition;
  Elements: IUIAutomationElementArray;
  Element: IUIAutomationElement;
  Count: Integer;
  I: Integer;
  ControlType: UIA_CONTROLTYPE_ID;
  NameText: PChar;
  AutomationIdText: PChar;
  ClassText: PChar;
  Name: string;
  AutomationId: string;
  ClassName: string;
  NativeHandle: HWND;
  Enabled: BOOL;
  OffScreen: BOOL;
  Rect: TRectF;
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

        NameText := nil;
        AutomationIdText := nil;
        ClassText := nil;
        Element.get_CurrentControlType(ControlType);
        Element.get_CurrentName(NameText);
        Element.get_CurrentAutomationId(AutomationIdText);
        Element.get_CurrentClassName(ClassText);
        Element.get_CurrentNativeWindowHandle(NativeHandle);
        Element.get_CurrentIsEnabled(Enabled);
        Element.get_CurrentIsOffscreen(OffScreen);
        Element.get_CurrentBoundingRectangle(Rect);
        HasInvoke := UiaHasInvokePattern(Element);

        Name := UiaStringToText(NameText);
        AutomationId := UiaStringToText(AutomationIdText);
        ClassName := UiaStringToText(ClassText);

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

function TSerifWindowWatchAivoice.AppKind: TSerifSpeechAppKind;
begin
  Result := ssakAivoice;
end;

function TSerifWindowWatchAivoice.CanHandleWindow(Wnd: HWND): Boolean;
begin
  Result := IsTopLevelVisibleWindow(Wnd) and
            (AIVOICE_IGNORE_TARGET_WINDOW_FOR_DEBUG or
            IsTargetProcessWindow(Wnd) or
             IsAivoiceProcessWindow(Wnd)) and
            (IsAivoiceSaveWindow(Wnd) or
             IsAivoiceConfirmDialog(Wnd) or
             IsAivoiceOverwriteConfirmDialog(Wnd) or
             IsAivoiceBusyErrorDialog(Wnd) or
             IsAivoiceFinalOKDialog(Wnd) or
             IsAivoiceFileSaveDialog(Wnd));
end;

procedure TSerifWindowWatchAivoice.CheckAivoiceFinalOKDialog;
var
  Context: TFindFinalOKDialogContext;
begin
  // 完了待ち Tick: 保存開始後、進捗ウィンドウが完了 OK に変わるまで監視する。
  if FAivoiceFlowState <> asfsWaitFinalOK then
    Exit;

  if FFinalOKWaitCount > 0 then
  begin
    Dec(FFinalOKWaitCount);
    Exit;
  end;

  if FFinalOKScanCount <= 0 then
  begin
    FinishAivoiceSaveFlow('A.I.VOICE final OK scan timeout');
    Exit;
  end;

  Dec(FFinalOKScanCount);
  Context.Target := Self;
  Context.Found := False;
  EnumWindows(@EnumFindFinalOKDialogProc, LPARAM(Pointer(@Context)));

  if Context.Found then
  begin
    FFinalOKActionDone := True;
    FinishAivoiceSaveFlow('A.I.VOICE final OK');
  end;
end;

procedure TSerifWindowWatchAivoice.FinishAivoiceSaveFlow(
  const DebugName: string);
begin
  Reset;
  OutputDebugString(PChar(Format('[SerifWindowWatcher] %s flow finished', [DebugName])));
end;

function TSerifWindowWatchAivoice.FormatWindowInfo(Wnd: HWND): string;
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

    Lines.Add('[SerifWindowWatcher] A.I.VOICE window detected');
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
    Lines.Add(Format('AivoiceSaveWindow=%s', [BoolText(IsAivoiceSaveWindow(Wnd))]));
    Lines.Add(Format('AivoiceConfirmDialog=%s', [BoolText(IsAivoiceConfirmDialog(Wnd))]));
    Lines.Add(Format('AivoiceOverwriteConfirmDialog=%s', [BoolText(IsAivoiceOverwriteConfirmDialog(Wnd))]));
    Lines.Add(Format('AivoiceBusyErrorDialog=%s', [BoolText(IsAivoiceBusyErrorDialog(Wnd))]));
    Lines.Add(Format('AivoiceFinalOKDialog=%s', [BoolText(IsAivoiceFinalOKDialog(Wnd))]));
    Lines.Add(Format('AivoiceFileSaveDialog=%s', [BoolText(IsAivoiceFileSaveDialog(Wnd))]));
    Lines.Add('Children:');
    EnumChildWindows(Wnd, @EnumChildInfoProc, LPARAM(Pointer(Lines)));
    AddUIAutomationInfo(Wnd, Lines);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function TSerifWindowWatchAivoice.GetAutomation: IUIAutomation;
begin
  if FAutomation = nil then
    FAutomation := CreateComObject(CLSID_CUIAutomation) as IUIAutomation;
  Result := FAutomation;
end;

procedure TSerifWindowWatchAivoice.HandleNewWindow(Wnd: HWND);
begin
  if not CanHandleWindow(Wnd) then
    Exit;

  if AIVOICE_DEBUG_DETAIL then
    OutputWindowInfo(FormatWindowInfo(Wnd));

  // 保存設定 OK ルート: 「音声保存」ウィンドウの OK を押して出力を開始する。
  if IsAivoiceSaveWindow(Wnd) and (FAivoiceFlowState = asfsIdle) then
    InvokeAivoiceSaveOK(Wnd);
  // プロジェクト設定確認ルート: 設定に従って保存する確認で「はい」を押す。
  if IsAivoiceConfirmDialog(Wnd) then
    InvokeAivoiceYesButton(Wnd, 'A.I.VOICE confirm Yes');
  // 上書き確認ルート: 既存ファイルがある場合の上書き確認を進める。
  if IsAivoiceOverwriteConfirmDialog(Wnd) then
    InvokeAivoiceButtonByText(Wnd, '上書き', 'A.I.VOICE overwrite');
  // ビジーエラールート: 合成処理が残っている警告 OK を閉じる。
  if IsAivoiceBusyErrorDialog(Wnd) then
    InvokeAivoiceOKButton(Wnd, 'A.I.VOICE busy error OK', False);
  // 完了 OK ルート: 新規ウィンドウとして検出できた場合はここで閉じる。
  if IsAivoiceFinalOKDialog(Wnd) then
  begin
    if InvokeAivoiceOKButton(Wnd, 'A.I.VOICE final OK', False) then
      FinishAivoiceSaveFlow('A.I.VOICE final OK');
  end;
end;

function TSerifWindowWatchAivoice.InvokeAivoiceOKButton(Wnd: HWND;
  const DebugName: string; LogNotFound: Boolean): Boolean;
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
  ClassName: string;
begin
  // 汎用 OK 押下: UI Automation で表示中かつ有効な OK ボタンを探して Invoke する。
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
      ClassName := UiaElementString(Element, UIA_ClassNamePropertyId);
      if Name <> 'OK' then
        Continue;

      PatternObject := nil;
      if Failed(Element.GetCurrentPattern(UIA_InvokePatternId, PatternObject)) or
         (PatternObject = nil) then
        Continue;

      InvokePattern := PatternObject as IUIAutomationInvokePattern;
      if InvokePattern = nil then
        Continue;

      Result := Succeeded(InvokePattern.Invoke);
      OutputDebugString(PChar(Format('[SerifWindowWatcher] %s invoke result=%s', [DebugName, BoolText(Result)])));
      Exit;
    end;

    if LogNotFound then
      OutputDebugString(PChar(Format('[SerifWindowWatcher] %s button was not found', [DebugName])));
  except
    on E: Exception do
      OutputDebugString(PChar(Format('[SerifWindowWatcher] %s invoke error=%s: %s', [DebugName, E.ClassName, E.Message])));
  end;
end;

function TSerifWindowWatchAivoice.InvokeAivoiceButtonByText(Wnd: HWND;
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
  // テキスト指定ボタン押下: 「上書き」など OK 以外のボタンを名前部分一致で押す。
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
      OutputDebugString(PChar(Format('[SerifWindowWatcher] %s invoke result=%s', [DebugName, BoolText(Result)])));
      Exit;
    end;

    OutputDebugString(PChar(Format('[SerifWindowWatcher] %s button was not found', [DebugName])));
  except
    on E: Exception do
      OutputDebugString(PChar(Format('[SerifWindowWatcher] %s invoke error=%s: %s', [DebugName, E.ClassName, E.Message])));
  end;
end;

function TSerifWindowWatchAivoice.InvokeAivoiceSaveOK(Wnd: HWND): Boolean;
begin
  // 保存設定 OK 押下: UIA で押せない場合は Enter 送信にフォールバックする。
  Result := InvokeAivoiceOKButton(Wnd, 'A.I.VOICE save OK');
  if not Result then
    Result := SendEnterToWindow(Wnd, 'A.I.VOICE save OK fallback');
  if Result then
  begin
    StartFinalOKWait;
    OutputDebugString('[SerifWindowWatcher] A.I.VOICE save OK invoked');
  end;
end;

function TSerifWindowWatchAivoice.InvokeAivoiceYesButton(Wnd: HWND;
  const DebugName: string): Boolean;
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
  // 「はい」押下: プロジェクト設定に従って保存する確認ダイアログ専用。
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
      if Pos('はい', Name) <> 1 then
        Continue;

      PatternObject := nil;
      if Failed(Element.GetCurrentPattern(UIA_InvokePatternId, PatternObject)) or
         (PatternObject = nil) then
        Continue;

      InvokePattern := PatternObject as IUIAutomationInvokePattern;
      if InvokePattern = nil then
        Continue;

      Result := Succeeded(InvokePattern.Invoke);
      OutputDebugString(PChar(Format('[SerifWindowWatcher] %s invoke result=%s', [DebugName, BoolText(Result)])));
      if Result then
      begin
        StartFinalOKWait;
        OutputDebugString('[SerifWindowWatcher] A.I.VOICE confirm Yes invoked');
      end;
      Exit;
    end;

    OutputDebugString(PChar(Format('[SerifWindowWatcher] %s button was not found', [DebugName])));
  except
    on E: Exception do
      OutputDebugString(PChar(Format('[SerifWindowWatcher] %s invoke error=%s: %s', [DebugName, E.ClassName, E.Message])));
  end;
end;

function TSerifWindowWatchAivoice.IsAivoiceConfirmDialog(Wnd: HWND): Boolean;
begin
  // プロジェクト設定確認判定: 終了確認を誤操作しないよう本文の語句も見る。
  Result := (GetWindowString(Wnd) = '確認') and
            IsAivoiceProcessWindow(Wnd) and
            UiaWindowHasText(Wnd, 'プロジェクト設定', '音声保存');
end;

function TSerifWindowWatchAivoice.IsAivoiceBusyErrorDialog(
  Wnd: HWND): Boolean;
begin
  // ビジーエラー判定: 前回の合成処理が完了していない警告。
  Result := (GetWindowString(Wnd) = 'エラー') and
            IsAivoiceProcessWindow(Wnd) and
            UiaWindowHasText(Wnd, '前回の合成処理が完了していません', '');
end;

function TSerifWindowWatchAivoice.IsAivoiceFinalOKDialog(Wnd: HWND): Boolean;
begin
  // 完了 OK 判定: 保存完了を知らせる情報ダイアログ。
  Result := (GetWindowString(Wnd) = '情報') and
            IsAivoiceProcessWindow(Wnd) and
            UiaWindowHasText(Wnd, '合成音声をファイルに保存しました', '');
end;

function TSerifWindowWatchAivoice.IsAivoiceOverwriteConfirmDialog(
  Wnd: HWND): Boolean;
begin
  // 上書き確認判定: 既存ファイルがある場合に出る確認ダイアログ。
  Result := (GetWindowString(Wnd) = 'ファイル保存') and
            IsAivoiceProcessWindow(Wnd) and
            UiaWindowHasText(Wnd, '既に存在', '上書き');
end;

function TSerifWindowWatchAivoice.IsAivoiceFileSaveDialog(Wnd: HWND): Boolean;
begin
  Result := (Pos('名前を付けて保存', GetWindowString(Wnd)) > 0) and
            ((GetClassString(Wnd) = '#32770') or IsAivoiceProcessWindow(Wnd));
end;

function TSerifWindowWatchAivoice.IsAivoiceProcessWindow(Wnd: HWND): Boolean;
var
  ProcessID: DWORD;
  ProcessFileName: string;
begin
  GetWindowThreadProcessId(Wnd, @ProcessID);
  ProcessFileName := LowerCase(GetProcessFileName(ProcessID));
  Result := ExtractFileName(ProcessFileName) = 'aivoiceeditor.exe';
end;

function TSerifWindowWatchAivoice.IsAivoiceSaveWindow(Wnd: HWND): Boolean;
var
  ClassName: string;
begin
  // 保存設定ウィンドウ判定: 「音声保存」設定画面本体だけを対象にする。
  ClassName := GetClassString(Wnd);
  Result := (GetWindowString(Wnd) = '音声保存') and
            IsAivoiceProcessWindow(Wnd) and
            (Pos('HwndWrapper[AIVoiceEditor.exe;', ClassName) = 1) and
            UiaWindowHasText(Wnd, 'ファイル分割', 'ファイル形式');
end;

procedure TSerifWindowWatchAivoice.StartFinalOKWait;
begin
  // 完了待ち開始: 進捗ウィンドウの内容変化を Tick 側で追う。
  FAivoiceFlowState := asfsWaitFinalOK;
  FFinalOKScanCount := AIVOICE_FINAL_OK_SCAN_COUNT;
  FFinalOKWaitCount := AIVOICE_FINAL_OK_INITIAL_WAIT;
  FFinalOKActionDone := False;
end;

procedure TSerifWindowWatchAivoice.OutputWindowInfo(const Text: string);
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
      OutputDebugString(PChar(DebugText));
    end;
  finally
    Lines.Free;
  end;
end;

procedure TSerifWindowWatchAivoice.Reset;
begin
  FAivoiceFlowState := asfsIdle;
  FFinalOKScanCount := 0;
  FFinalOKWaitCount := 0;
  FFinalOKActionDone := False;
end;

function TSerifWindowWatchAivoice.SendEnterToWindow(Wnd: HWND;
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
  OutputDebugString(PChar(Format('[SerifWindowWatcher] %s enter sent', [DebugName])));
end;

procedure TSerifWindowWatchAivoice.Tick;
begin
  CheckAivoiceFinalOKDialog;
end;

function TSerifWindowWatchAivoice.UiaWindowHasText(Wnd: HWND; const Text1,
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
  // UIA テキスト確認: 同名タイトルの別ダイアログを誤操作しないための本文判定。
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
      OutputDebugString(PChar(Format('[SerifWindowWatcher] A.I.VOICE confirm text scan error=%s: %s', [E.ClassName, E.Message])));
  end;
end;

end.
