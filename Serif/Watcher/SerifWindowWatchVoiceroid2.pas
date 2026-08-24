unit SerifWindowWatchVoiceroid2;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.UIAutomation, System.Classes,
  System.SysUtils, SerifWindowWatchTarget;

type
  TSerifVoiceroidSaveFlowState = (
    vsfsIdle,
    vsfsWaitFileSaveDialog,
    vsfsWaitFinalOK
  );

type
  // VOICEROID2 が表示する保存系補助ウィンドウを処理するターゲット。
  TSerifWindowWatchVoiceroid2 = class(TSerifWindowWatchTarget)
  private
    FAutomation: IUIAutomation; // OKボタン探索に使う UI Automation インスタンス
    FFileSaveDialogScanCount: Integer; // ファイル保存ダイアログを探す残り回数
    FFileSaveDialogEnterCount: Integer; // ファイル保存ダイアログへ Enter を送った回数
    FFinalOKDialogScanCount: Integer; // 最終確認 OK ダイアログを探す残り回数
    FVoiceroidFlowState: TSerifVoiceroidSaveFlowState; // VOICEROID 保存処理の進行状態
    FFileSaveActionDone: Boolean; // ファイル保存ダイアログへの操作済みフラグ
    FFileSaveRetryWait: Integer; // ファイル保存ダイアログ再確認までの待機カウント
    FFinalOKActionDone: Boolean; // 最終確認 OK ダイアログへの操作済みフラグ
    FFinalOKRetryWait: Integer; // 最終確認 OK ダイアログ再確認までの待機カウント
    // VOICEROID のファイル保存ダイアログを探して操作する。
    procedure CheckVoiceroidFileSaveDialog;
    // VOICEROID の最終確認 OK ダイアログを探して操作する。
    procedure CheckVoiceroidFinalOKDialog;
    // VOICEROID 保存フローの状態を初期化して完了扱いにする。
    procedure FinishVoiceroidSaveFlow(const DebugName: string);
    // 指定ウィンドウが VOICEROID プロセスに属するかを判定する。
    function IsVoiceroidProcessWindow(Wnd: HWND): Boolean;
    // 指定ウィンドウが VOICEROID の音声保存ウィンドウかを判定する。
    function IsVoiceroidSaveWindow(Wnd: HWND): Boolean;
    // 指定ウィンドウが VOICEROID の名前を付けて保存ダイアログかを判定する。
    function IsVoiceroidFileSaveDialog(Wnd: HWND): Boolean;
    // 指定ウィンドウが VOICEROID の上書き確認ダイアログかを判定する。
    function IsVoiceroidOverwriteDialog(Wnd: HWND): Boolean;
    // 指定ウィンドウが VOICEROID の情報ダイアログかを判定する。
    function IsVoiceroidInfoDialog(Wnd: HWND): Boolean;
    // UI Automation インスタンスを遅延生成して返す。
    function GetAutomation: IUIAutomation;
    // デバッグ出力用にウィンドウ情報を整形する。
    function FormatWindowInfo(Wnd: HWND): string;
    // デバッグ出力用に UI Automation の要素情報を追加する。
    procedure AddUIAutomationInfo(Wnd: HWND; Lines: TStrings);
    // VOICEROID の音声保存ウィンドウで OK ボタンを押す。
    function InvokeVoiceroidSaveOK(Wnd: HWND): Boolean;
    // VOICEROID のファイル保存ダイアログへ Enter を送る。
    function InvokeVoiceroidFileSaveDialog(Wnd: HWND): Boolean;
    // VOICEROID の上書き確認ダイアログで上書きを選ぶ。
    function InvokeVoiceroidOverwriteDialog(Wnd: HWND): Boolean;
    // UI Automation で指定ウィンドウ内の OK ボタンを押す。
    function InvokeVoiceroidOKButton(Wnd: HWND; const DebugName: string): Boolean;
    // OK ボタン操作を UI Automation とメッセージ送信で試みる。
    function PushVoiceroidOKDialog(Wnd: HWND; const DebugName: string): Boolean;
    // 指定ウィンドウを前面化して Enter キーを送る。
    function SendEnterToWindow(Wnd: HWND; const DebugName: string): Boolean;
    // 複数行のデバッグ文字列を OutputDebugString へ出力する。
    procedure OutputWindowInfo(const Text: string);
  public
    // このターゲットが担当する音声合成アプリ種別を返す。
    function AppKind: TSerifSpeechAppKind; override;
    // 保存フローの状態を初期化する。
    procedure Reset; override;
    // 進行中の VOICEROID2 保存フローを確認する。
    procedure Tick; override;
    // 指定ウィンドウが VOICEROID2 保存フローの対象かを判定する。
    function CanHandleWindow(Wnd: HWND): Boolean; override;
    // 新しく検出された VOICEROID2 保存フローの対象ウィンドウを処理する。
    procedure HandleNewWindow(Wnd: HWND); override;
  end;

implementation

uses
  Winapi.ActiveX, System.Win.ComObj, System.Types, SerifWindowWatchUtils;

const
  VOICEROID_FILE_SAVE_SCAN_COUNT = 10;
  VOICEROID_FINAL_OK_SCAN_COUNT = 15;
  VOICEROID_FILE_SAVE_RETRY_WAIT = 0;
  VOICEROID_DEBUG_DETAIL = False;
  VOICEROID_IGNORE_TARGET_WINDOW_FOR_DEBUG = False;

type
  PFindFileSaveDialogContext = ^TFindFileSaveDialogContext;
  TFindFileSaveDialogContext = record
    Target: TSerifWindowWatchVoiceroid2;
    Found: Boolean;
  end;

  PFindFinalOKDialogContext = ^TFindFinalOKDialogContext;
  TFindFinalOKDialogContext = record
    Target: TSerifWindowWatchVoiceroid2;
    Found: Boolean;
    DumpedCount: Integer;
  end;

function EnumFindFileSaveDialogProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PFindFileSaveDialogContext;
begin
  Context := PFindFileSaveDialogContext(Pointer(LParam));
  // 状態が変わっていたら、列挙を止めて古い探索結果を使わない。
  if Context.Target.FVoiceroidFlowState <> vsfsWaitFileSaveDialog then
  begin
    Result := False;
    Exit;
  end;
  // 保存ダイアログが見つかったら Enter を送り、以降の列挙は不要なので止める。
  if IsTopLevelVisibleWindow(Wnd) and
     (VOICEROID_IGNORE_TARGET_WINDOW_FOR_DEBUG or
      Context.Target.IsTargetProcessWindow(Wnd) or
      Context.Target.IsVoiceroidProcessWindow(Wnd)) and
     Context.Target.IsVoiceroidOverwriteDialog(Wnd) then
  begin
    // 上書き確認ルート: 既存ファイルがある場合は「新しいファイルで上書き」を選ぶ。
    if VOICEROID_DEBUG_DETAIL then
      Context.Target.OutputWindowInfo(Context.Target.FormatWindowInfo(Wnd));
    Context.Found := Context.Target.InvokeVoiceroidOverwriteDialog(Wnd);
    Result := False;
    Exit;
  end;
  if IsTopLevelVisibleWindow(Wnd) and
     (VOICEROID_IGNORE_TARGET_WINDOW_FOR_DEBUG or
      Context.Target.IsTargetProcessWindow(Wnd) or
      Context.Target.IsVoiceroidProcessWindow(Wnd)) and
     Context.Target.IsVoiceroidFileSaveDialog(Wnd) then
  begin
    // ファイル保存ルート: 標準保存ダイアログの既定ボタンへ Enter を送る。
    if VOICEROID_DEBUG_DETAIL then
      Context.Target.OutputWindowInfo(Context.Target.FormatWindowInfo(Wnd));
    Context.Found := Context.Target.InvokeVoiceroidFileSaveDialog(Wnd);
    Result := False;
    Exit;
  end;
  Result := True;
end;

function EnumFindFinalOKDialogProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PFindFinalOKDialogContext;
  ProcessID: DWORD;
  ProcessFileName: string;
  Title: string;
  ClassName: string;
  IsInfo: Boolean;
begin
  Context := PFindFinalOKDialogContext(Pointer(LParam));
  // 状態が変わっていたら、列挙を止めて古い探索結果を使わない。
  if Context.Target.FVoiceroidFlowState <> vsfsWaitFinalOK then
  begin
    Result := False;
    Exit;
  end;
  // 最終 OK 探索中だけは周辺ウィンドウを少量ログに出して判定材料を残す。
  if IsTopLevelVisibleWindow(Wnd) and (Context.DumpedCount < 30) then
  begin
    GetWindowThreadProcessId(Wnd, @ProcessID);
    ProcessFileName := GetProcessFileName(ProcessID);
    Title := GetWindowString(Wnd);
    ClassName := GetClassString(Wnd);
    IsInfo := Context.Target.IsVoiceroidInfoDialog(Wnd);
    OutputDebugString(PChar(Format('[SerifWindowWatcher] FinalOK scan HWND=%p Title="%s" Class="%s" Process="%s" IsInfo=%s',
      [Pointer(Wnd), Title, ClassName, ProcessFileName, BoolText(IsInfo)])));
    Inc(Context.DumpedCount);
  end;
  // 上書き確認ルート: 保存ダイアログ後に final OK 待ちへ進んでから出る場合も拾う。
  if IsTopLevelVisibleWindow(Wnd) and
     (VOICEROID_IGNORE_TARGET_WINDOW_FOR_DEBUG or
      Context.Target.IsTargetProcessWindow(Wnd) or
      Context.Target.IsVoiceroidProcessWindow(Wnd)) and
     Context.Target.IsVoiceroidOverwriteDialog(Wnd) then
  begin
    if VOICEROID_DEBUG_DETAIL then
      Context.Target.OutputWindowInfo(Context.Target.FormatWindowInfo(Wnd));
    Context.Found := Context.Target.InvokeVoiceroidOverwriteDialog(Wnd);
    Result := False;
    Exit;
  end;
  // 情報ダイアログを見つけたら一度だけ OK 操作し、閉じるまでは Found として待つ。
  if IsTopLevelVisibleWindow(Wnd) and
     (VOICEROID_IGNORE_TARGET_WINDOW_FOR_DEBUG or
      Context.Target.IsTargetProcessWindow(Wnd) or
      Context.Target.IsVoiceroidProcessWindow(Wnd)) and
     Context.Target.IsVoiceroidInfoDialog(Wnd) then
  begin
    if not Context.Target.FFinalOKActionDone then
    begin
      if VOICEROID_DEBUG_DETAIL then
        Context.Target.OutputWindowInfo(Context.Target.FormatWindowInfo(Wnd));
      Context.Target.FFinalOKActionDone := Context.Target.PushVoiceroidOKDialog(Wnd, 'Voiceroid final OK');
    end;
    Context.Found := True;
    Result := False;
    Exit;
  end;
  Result := True;
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

{ TSerifWindowWatchVoiceroid2 }

function TSerifWindowWatchVoiceroid2.AppKind: TSerifSpeechAppKind;
begin
  Result := ssakVoiceroid2;
end;

procedure TSerifWindowWatchVoiceroid2.AddUIAutomationInfo(Wnd: HWND; Lines: TStrings);
const
  MAX_UIA_ELEMENTS = 120;
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

function TSerifWindowWatchVoiceroid2.CanHandleWindow(Wnd: HWND): Boolean;
begin
  Result := IsTopLevelVisibleWindow(Wnd) and
            (VOICEROID_IGNORE_TARGET_WINDOW_FOR_DEBUG or
             IsTargetProcessWindow(Wnd) or
             IsVoiceroidProcessWindow(Wnd)) and
            (IsVoiceroidSaveWindow(Wnd) or
             IsVoiceroidFileSaveDialog(Wnd) or
             IsVoiceroidOverwriteDialog(Wnd) or
             IsVoiceroidInfoDialog(Wnd));
end;

procedure TSerifWindowWatchVoiceroid2.CheckVoiceroidFileSaveDialog;
var
  Context: TFindFileSaveDialogContext;
begin
  // ファイル保存待ち Tick: 名前を付けて保存、または上書き確認を探して進める。
  if FVoiceroidFlowState <> vsfsWaitFileSaveDialog then
    Exit;
  // 保存ダイアログが一定回数見つからなければ、フローを戻して待ち続けない。
  if FFileSaveDialogScanCount <= 0 then
  begin
    FinishVoiceroidSaveFlow('Voiceroid file save dialog scan timeout');
    Exit;
  end;

  // 直前の操作結果を少し待ってから、ダイアログが閉じたか再確認する。
  if FFileSaveRetryWait > 0 then
  begin
    Dec(FFileSaveRetryWait);
    Exit;
  end;

  Dec(FFileSaveDialogScanCount);
  Context.Target := Self;
  Context.Found := False;
  EnumWindows(@EnumFindFileSaveDialogProc, LPARAM(Pointer(@Context)));

  // ダイアログがまだ見えている場合は、閉じるまで次回以降に再確認する。
  if Context.Found then
  begin
    FFileSaveRetryWait := VOICEROID_FILE_SAVE_RETRY_WAIT;
  end
  // Enter 送信後にダイアログが消えたら、保存完了の情報ダイアログ待ちへ進む。
  else if FFileSaveActionDone then
  begin
    FVoiceroidFlowState := vsfsWaitFinalOK;
    FFinalOKDialogScanCount := VOICEROID_FINAL_OK_SCAN_COUNT;
    FFileSaveDialogScanCount := 0;
    FFileSaveActionDone := False;
    OutputDebugString('[SerifWindowWatcher] Voiceroid file save dialog closed');
    FFinalOKActionDone := False;
    FFinalOKRetryWait := 0;
  end
  // 保存ダイアログを押せないまま探索上限に達しても、最終 OK が出る可能性を確認する。
  else if FFileSaveDialogScanCount = 0 then
  begin
    FVoiceroidFlowState := vsfsWaitFinalOK;
    FFinalOKDialogScanCount := VOICEROID_FINAL_OK_SCAN_COUNT;
    FFinalOKActionDone := False;
    FFinalOKRetryWait := 0;
    OutputDebugString('[SerifWindowWatcher] Voiceroid final OK scan started after file save timeout');
  end;
end;

procedure TSerifWindowWatchVoiceroid2.CheckVoiceroidFinalOKDialog;
var
  Context: TFindFinalOKDialogContext;
  WasActionDone: Boolean;
begin
  if FVoiceroidFlowState <> vsfsWaitFinalOK then
    Exit;
  // 最終 OK ダイアログが一定回数見つからなければ、保存フローを終了する。
  if FFinalOKDialogScanCount <= 0 then
  begin
    FinishVoiceroidSaveFlow('Voiceroid final OK scan timeout');
    Exit;
  end;

  // OK 操作直後は、ダイアログが閉じるまで次回以降に再確認する。
  if FFinalOKRetryWait > 0 then
  begin
    Dec(FFinalOKRetryWait);
    Exit;
  end;

  Dec(FFinalOKDialogScanCount);
  Context.Target := Self;
  Context.Found := False;
  Context.DumpedCount := 0;
  WasActionDone := FFinalOKActionDone;
  EnumWindows(@EnumFindFinalOKDialogProc, LPARAM(Pointer(@Context)));

  // ダイアログが残っている場合は、次回もう一度閉じたか確認する。
  if Context.Found then
  begin
    FFinalOKRetryWait := VOICEROID_FILE_SAVE_RETRY_WAIT;
    // 操作済みフラグを戻して、閉じなかった場合に再操作できるようにする。
    if WasActionDone then
      FFinalOKActionDone := False;
  end
  // OK 操作後にダイアログが消えていれば、保存フローを完了する。
  else if WasActionDone then
    FinishVoiceroidSaveFlow('Voiceroid final OK')
  // 未操作のまま探索上限に達した場合も、待機状態へ戻す。
  else if FFinalOKDialogScanCount = 0 then
    FinishVoiceroidSaveFlow('Voiceroid final OK scan timeout');
end;

procedure TSerifWindowWatchVoiceroid2.FinishVoiceroidSaveFlow(const DebugName: string);
begin
  Reset;
  OutputDebugString(PChar(Format('[SerifWindowWatcher] %s flow finished', [DebugName])));
end;

function TSerifWindowWatchVoiceroid2.FormatWindowInfo(Wnd: HWND): string;
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

    Lines.Add('[SerifWindowWatcher] New window detected');
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
	    Lines.Add(Format('VoiceroidSaveWindow=%s', [BoolText(IsVoiceroidSaveWindow(Wnd))]));
	    Lines.Add(Format('VoiceroidFileSaveDialog=%s', [BoolText(IsVoiceroidFileSaveDialog(Wnd))]));
	    Lines.Add(Format('VoiceroidOverwriteDialog=%s', [BoolText(IsVoiceroidOverwriteDialog(Wnd))]));
	    Lines.Add(Format('VoiceroidInfoDialog=%s', [BoolText(IsVoiceroidInfoDialog(Wnd))]));
    Lines.Add('Children:');
    EnumChildWindows(Wnd, @EnumChildInfoProc, LPARAM(Pointer(Lines)));
    // VOICEROID 関連ウィンドウだけ UI Automation の詳細も追加する。
    if CanHandleWindow(Wnd) then
      AddUIAutomationInfo(Wnd, Lines);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function TSerifWindowWatchVoiceroid2.GetAutomation: IUIAutomation;
begin
  // UI Automation は必要になるまで生成せず、以後は同じインスタンスを使い回す。
  if FAutomation = nil then
    FAutomation := CreateComObject(CLSID_CUIAutomation) as IUIAutomation;
  Result := FAutomation;
end;

procedure TSerifWindowWatchVoiceroid2.HandleNewWindow(Wnd: HWND);
begin
  if not CanHandleWindow(Wnd) then
    Exit;

  if VOICEROID_DEBUG_DETAIL then
    OutputWindowInfo(FormatWindowInfo(Wnd));

  // 音声保存ウィンドウが出たら OK を押してファイル保存ダイアログ待ちへ進める。
  if IsVoiceroidSaveWindow(Wnd) and
     (FVoiceroidFlowState = vsfsIdle) then
    InvokeVoiceroidSaveOK(Wnd);
  // 既にファイル保存ダイアログが出ている場合は、直接そのダイアログ待ちから始める。
  if IsVoiceroidFileSaveDialog(Wnd) and
     (FVoiceroidFlowState = vsfsIdle) then
  begin
    FVoiceroidFlowState := vsfsWaitFileSaveDialog;
    FFileSaveActionDone := False;
    FFileSaveRetryWait := 0;
    FFileSaveDialogScanCount := VOICEROID_FILE_SAVE_SCAN_COUNT;
    OutputDebugString('[SerifWindowWatcher] Voiceroid direct file save dialog flow started');
  end;
  // 上書き確認が新規検出された場合は、上書きを選択して保存完了待ちへ進める。
  if IsVoiceroidOverwriteDialog(Wnd) and
     ((FVoiceroidFlowState = vsfsWaitFileSaveDialog) or
      (FVoiceroidFlowState = vsfsWaitFinalOK)) then
    InvokeVoiceroidOverwriteDialog(Wnd);
  // 保存後の情報ダイアログを新規検出した場合は、最終 OK として押してフローを終える。
  if IsVoiceroidInfoDialog(Wnd) and
     (FVoiceroidFlowState <> vsfsIdle) then
  begin
    FVoiceroidFlowState := vsfsWaitFinalOK;
    FFileSaveDialogScanCount := 0;
    FFileSaveActionDone := False;
    if PushVoiceroidOKDialog(Wnd, 'Voiceroid info OK') then
      FinishVoiceroidSaveFlow('Voiceroid info OK');
  end;
end;

function TSerifWindowWatchVoiceroid2.InvokeVoiceroidFileSaveDialog(Wnd: HWND): Boolean;
var
  Text: string;
begin
  Result := False;
  // 同じ保存ダイアログに Enter を連打しないよう、操作済みなら抜ける。
  if FFileSaveActionDone then
  begin
    OutputDebugString('[SerifWindowWatcher] Voiceroid file save skipped because action already ran');
    Exit;
  end;

  Text := Format('[SerifWindowWatcher] Voiceroid file save targeted enter HWND=%p Title="%s" Class="%s"',
    [Pointer(Wnd), GetWindowString(Wnd), GetClassString(Wnd)]);
  OutputDebugString(PChar(Text));

  FFileSaveActionDone := True;
  FFileSaveDialogEnterCount := 0;

  // 前面化してから Enter を送ることで、標準保存ダイアログの既定ボタンを実行する。
  ShowWindow(Wnd, SW_SHOWNORMAL);
  BringWindowToTop(Wnd);
  SetForegroundWindow(Wnd);
  SetActiveWindow(Wnd);
  keybd_event(VK_RETURN, 0, 0, 0);
  keybd_event(VK_RETURN, 0, KEYEVENTF_KEYUP, 0);
  Result := True;
  OutputDebugString('[SerifWindowWatcher] Voiceroid file save dialog enter sent');
end;

function TSerifWindowWatchVoiceroid2.InvokeVoiceroidOverwriteDialog(
  Wnd: HWND): Boolean;
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
  Enabled: BOOL;
  OffScreen: BOOL;
  Name: string;
begin
  // 上書き確認押下: UIA で「新しいファイルで上書き」を探し、失敗時は Enter で進める。
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

      Enabled := False;
      OffScreen := True;
      Element.get_CurrentIsEnabled(Enabled);
      Element.get_CurrentIsOffscreen(OffScreen);
      if (Enabled = False) or (OffScreen <> False) or
         (not UiaHasInvokePattern(Element)) then
        Continue;

      Name := UiaElementString(Element, UIA_NamePropertyId);
      if Pos('新しいファイルで上書き', Name) = 0 then
        Continue;

      PatternObject := nil;
      if Failed(Element.GetCurrentPattern(UIA_InvokePatternId, PatternObject)) or
         (PatternObject = nil) then
        Continue;

      InvokePattern := PatternObject as IUIAutomationInvokePattern;
      if InvokePattern = nil then
        Continue;

      Result := Succeeded(InvokePattern.Invoke);
      OutputDebugString(PChar(Format('[SerifWindowWatcher] Voiceroid overwrite invoke result=%s', [BoolText(Result)])));
      Break;
    end;
  except
    on E: Exception do
      OutputDebugString(PChar(Format('[SerifWindowWatcher] Voiceroid overwrite invoke error=%s: %s', [E.ClassName, E.Message])));
  end;

  if not Result then
  begin
    OutputDebugString('[SerifWindowWatcher] Voiceroid overwrite invoke fallback enter');
    Result := SendEnterToWindow(Wnd, 'Voiceroid overwrite');
  end;

  if Result then
  begin
    FFileSaveActionDone := True;
    FFileSaveDialogScanCount := 0;
    FFileSaveRetryWait := 0;
    FVoiceroidFlowState := vsfsWaitFinalOK;
    FFinalOKDialogScanCount := VOICEROID_FINAL_OK_SCAN_COUNT;
    FFinalOKActionDone := False;
    FFinalOKRetryWait := 0;
  end;
end;

function TSerifWindowWatchVoiceroid2.InvokeVoiceroidOKButton(Wnd: HWND; const DebugName: string): Boolean;
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
  Result := False;
  try
    Automation := GetAutomation;
    // UI Automation の初期化や要素取得に失敗したら、呼び元のフォールバックへ任せる。
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

    // サブツリー内から、表示中で有効な OK ボタンだけを対象にする。
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
      // VOICEROID の確認ダイアログでは Name=OK / Class=Button の要素を押す。
      if (Name <> 'OK') or (ClassName <> 'Button') then
        Continue;

      PatternObject := nil;
      // InvokePattern を持たない要素はボタンに見えても操作対象外にする。
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

function TSerifWindowWatchVoiceroid2.InvokeVoiceroidSaveOK(Wnd: HWND): Boolean;
begin
  Result := InvokeVoiceroidOKButton(Wnd, 'Voiceroid save OK');
  // 音声保存ウィンドウの OK が押せたときだけ、次の保存ダイアログ待ちへ進む。
  if Result then
  begin
    FVoiceroidFlowState := vsfsWaitFileSaveDialog;
    FFileSaveActionDone := False;
    FFileSaveRetryWait := 0;
    FFileSaveDialogScanCount := VOICEROID_FILE_SAVE_SCAN_COUNT;
    FFileSaveDialogEnterCount := 0;
    FFinalOKActionDone := False;
    FFinalOKRetryWait := 0;
    OutputDebugString('[SerifWindowWatcher] Voiceroid file save dialog scan started');
  end;
end;

function TSerifWindowWatchVoiceroid2.IsVoiceroidFileSaveDialog(Wnd: HWND): Boolean;
begin
  Result := Pos('名前を付けて保存', GetWindowString(Wnd)) > 0;
end;

function TSerifWindowWatchVoiceroid2.IsVoiceroidOverwriteDialog(
  Wnd: HWND): Boolean;
var
  ClassName: string;
begin
  // 上書き確認判定: VOICEROID2 の「ファイル保存」確認ダイアログ。
  ClassName := GetClassString(Wnd);
  Result := (GetWindowString(Wnd) = 'ファイル保存') and
            (IsVoiceroidProcessWindow(Wnd) or
             IsTargetProcessWindow(Wnd) or
             (Pos('HwndWrapper[VoiceroidEditor.exe;', ClassName) = 1));
end;

function TSerifWindowWatchVoiceroid2.IsVoiceroidInfoDialog(Wnd: HWND): Boolean;
begin
  Result := (Pos('情報', GetWindowString(Wnd)) > 0) and
            ((GetClassString(Wnd) = '#32770') or IsVoiceroidProcessWindow(Wnd));
end;

function TSerifWindowWatchVoiceroid2.IsVoiceroidProcessWindow(Wnd: HWND): Boolean;
var
  ProcessID: DWORD;
  ProcessFileName: string;
begin
  GetWindowThreadProcessId(Wnd, @ProcessID);
  ProcessFileName := LowerCase(GetProcessFileName(ProcessID));
  Result := ExtractFileName(ProcessFileName) = 'voiceroideditor.exe';
end;

function TSerifWindowWatchVoiceroid2.IsVoiceroidSaveWindow(Wnd: HWND): Boolean;
var
  ProcessID: DWORD;
  ProcessFileName: string;
  ClassName: string;
begin
  GetWindowThreadProcessId(Wnd, @ProcessID);
  ProcessFileName := LowerCase(GetProcessFileName(ProcessID));
  ClassName := GetClassString(Wnd);
  // VOICEROID の WPF ウィンドウはクラス名の先頭も合わせて誤検出を抑える。
  Result := (GetWindowString(Wnd) = '音声保存') and
            (ExtractFileName(ProcessFileName) = 'voiceroideditor.exe') and
            (Pos('HwndWrapper[VoiceroidEditor.exe;', ClassName) = 1);
end;

procedure TSerifWindowWatchVoiceroid2.OutputWindowInfo(const Text: string);
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

function TSerifWindowWatchVoiceroid2.PushVoiceroidOKDialog(Wnd: HWND; const DebugName: string): Boolean;
const
  IDOK = 1;
begin
  Result := InvokeVoiceroidOKButton(Wnd, DebugName);
  if Result then
    Exit;

  // UI Automation で押せない場合は、標準ダイアログ向けの IDOK と Enter を保険で送る。
  OutputDebugString(PChar(Format('[SerifWindowWatcher] %s send IDOK', [DebugName])));
  SendMessage(Wnd, WM_COMMAND, IDOK, 0);
  SendEnterToWindow(Wnd, DebugName);
  Result := True;
end;

procedure TSerifWindowWatchVoiceroid2.Reset;
begin
  // 保存フロー関連のカウンタとフラグをすべて初期状態へ戻す。
  FFileSaveDialogScanCount := 0;
  FFileSaveDialogEnterCount := 0;
  FFinalOKDialogScanCount := 0;
  FVoiceroidFlowState := vsfsIdle;
  FFileSaveActionDone := False;
  FFileSaveRetryWait := 0;
  FFinalOKActionDone := False;
  FFinalOKRetryWait := 0;
end;

function TSerifWindowWatchVoiceroid2.SendEnterToWindow(Wnd: HWND; const DebugName: string): Boolean;
begin
  Result := False;
  if Wnd = 0 then
    Exit;

  SetForegroundWindow(Wnd);
  keybd_event(VK_RETURN, 0, 0, 0);
  keybd_event(VK_RETURN, 0, KEYEVENTF_KEYUP, 0);
  Result := True;
  OutputDebugString(PChar(Format('[SerifWindowWatcher] %s enter sent', [DebugName])));
end;

procedure TSerifWindowWatchVoiceroid2.Tick;
begin
  CheckVoiceroidFileSaveDialog;
  CheckVoiceroidFinalOKDialog;
end;

end.
