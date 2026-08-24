unit SerifWindowWatchUtils;

interface

uses
  Winapi.Windows, Winapi.UIAutomation;

function GetWindowString(Wnd: HWND): string;
function GetClassString(Wnd: HWND): string;
function BoolText(Value: Boolean): string;
function WindowStyleText(Value: NativeUInt): string;
function UiaStringToText(Value: PChar): string;
function UiaControlTypeText(ControlType: Integer): string;
function UiaHasInvokePattern(Element: IUIAutomationElement): Boolean;
function UiaElementString(Element: IUIAutomationElement; PropertyID: Integer): string;
function GetProcessFileName(ProcessID: DWORD): string;
function IsTopLevelVisibleWindow(Wnd: HWND): Boolean;

implementation

uses
  Winapi.ActiveX, Winapi.PsAPI, System.SysUtils;

function GetWindowString(Wnd: HWND): string;
var
  Len: Integer;
begin
  Len := GetWindowTextLength(Wnd);
  SetLength(Result, Len);
  if Len > 0 then
    GetWindowText(Wnd, PChar(Result), Len + 1);
end;

function GetClassString(Wnd: HWND): string;
var
  Buffer: array[0..255] of Char;
begin
  if GetClassName(Wnd, Buffer, Length(Buffer)) = 0 then
    Result := ''
  else
    Result := Buffer;
end;

function BoolText(Value: Boolean): string;
begin
  if Value then
    Result := 'True'
  else
    Result := 'False';
end;

function WindowStyleText(Value: NativeUInt): string;
begin
  Result := '$' + IntToHex(Value, SizeOf(Value) * 2);
end;

function UiaStringToText(Value: PChar): string;
begin
  if Value = nil then
    Result := ''
  else
    Result := Value;
  if Value <> nil then
    SysFreeString(PWideChar(Value));
end;

function UiaControlTypeText(ControlType: Integer): string;
begin
  case ControlType of
    UIA_ButtonControlTypeId: Result := 'Button';
    UIA_CheckBoxControlTypeId: Result := 'CheckBox';
    UIA_ComboBoxControlTypeId: Result := 'ComboBox';
    UIA_EditControlTypeId: Result := 'Edit';
    UIA_HyperlinkControlTypeId: Result := 'Hyperlink';
    UIA_ImageControlTypeId: Result := 'Image';
    UIA_ListControlTypeId: Result := 'List';
    UIA_ListItemControlTypeId: Result := 'ListItem';
    UIA_MenuControlTypeId: Result := 'Menu';
    UIA_MenuBarControlTypeId: Result := 'MenuBar';
    UIA_MenuItemControlTypeId: Result := 'MenuItem';
    UIA_PaneControlTypeId: Result := 'Pane';
    UIA_ProgressBarControlTypeId: Result := 'ProgressBar';
    UIA_RadioButtonControlTypeId: Result := 'RadioButton';
    UIA_ScrollBarControlTypeId: Result := 'ScrollBar';
    UIA_SliderControlTypeId: Result := 'Slider';
    UIA_TabControlTypeId: Result := 'Tab';
    UIA_TabItemControlTypeId: Result := 'TabItem';
    UIA_TextControlTypeId: Result := 'Text';
    UIA_TreeControlTypeId: Result := 'Tree';
    UIA_TreeItemControlTypeId: Result := 'TreeItem';
    UIA_WindowControlTypeId: Result := 'Window';
  else
    Result := IntToStr(ControlType);
  end;
end;

function UiaHasInvokePattern(Element: IUIAutomationElement): Boolean;
var
  PatternObject: IUnknown;
begin
  PatternObject := nil;
  Result := (Element <> nil) and
            Succeeded(Element.GetCurrentPattern(UIA_InvokePatternId, PatternObject)) and
            (PatternObject <> nil);
end;

function UiaElementString(Element: IUIAutomationElement; PropertyID: Integer): string;
var
  Text: PChar;
begin
  Text := nil;
  if Element = nil then
    Exit('');

  case PropertyID of
    UIA_NamePropertyId:
      Element.get_CurrentName(Text);
    UIA_AutomationIdPropertyId:
      Element.get_CurrentAutomationId(Text);
    UIA_ClassNamePropertyId:
      Element.get_CurrentClassName(Text);
  end;
  Result := UiaStringToText(Text);
end;

function GetProcessFileName(ProcessID: DWORD): string;
var
  ProcessHandle: THandle;
  Buffer: array[0..MAX_PATH - 1] of Char;
begin
  Result := '';
  ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, ProcessID);
  if ProcessHandle = 0 then
    Exit;
  try
    if GetModuleFileNameEx(ProcessHandle, 0, Buffer, Length(Buffer)) > 0 then
      Result := Buffer;
  finally
    CloseHandle(ProcessHandle);
  end;
end;

function IsTopLevelVisibleWindow(Wnd: HWND): Boolean;
begin
  // 子ウィンドウを除いた可視トップレベルウィンドウだけを監視対象にする。
  Result := IsWindow(Wnd) and
            IsWindowVisible(Wnd) and
            ((GetWindowLongPtr(Wnd, GWL_STYLE) and WS_CHILD) = 0);
end;

end.
