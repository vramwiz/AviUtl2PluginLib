unit LauncherGlobalHotkeys;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.Classes;

const
  // False: do not register Ctrl+Alt+number global hotkeys.
  GLOBAL_LAUNCHER_HOTKEYS_ENABLED = True;
  // True: include aviutl2.exe in Ctrl+Alt+0 switching.
  GLOBAL_LAUNCHER_HOTKEYS_INCLUDE_AVIUTL2_IN_SWITCHING = True;

type
  TLauncherGlobalHotkeyEvent = procedure(Sender: TObject;
    KeyNumber: Integer) of object;

type
  TLauncherGlobalHotkeys = class
  private
    FWindowHandle: HWND;
    FOnHotkey: TLauncherGlobalHotkeyEvent;
    FRegistered: Boolean;
    procedure WndProc(var Msg: TMessage);
    procedure RegisterAll;
    procedure UnregisterAll;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enable;
    procedure Disable;
    property OnHotkey: TLauncherGlobalHotkeyEvent read FOnHotkey write FOnHotkey;
  end;

function ActivateAviUtl2Window: Boolean;

implementation

uses
  System.SysUtils,
  Vcl.Forms,
  LauncherShellUtils,
  WindowInfoList;

const
  HOTKEY_ID_BASE = $534C3000;
  HOTKEY_MODIFIERS = MOD_CONTROL or MOD_ALT;
  AVIUTL2_EXECUTABLE_NAME = 'aviutl2';

{ TLauncherGlobalHotkeys }

constructor TLauncherGlobalHotkeys.Create;
begin
  inherited Create;
  // OnHotkey を設定してから登録したいので、Create ではまだ RegisterHotKey しない。
end;

destructor TLauncherGlobalHotkeys.Destroy;
begin
  Disable;
  inherited;
end;

procedure TLauncherGlobalHotkeys.Disable;
begin
  // DLL/フレーム破棄時に OS 側のホットキー登録と隠しウィンドウを必ず解放する。
  UnregisterAll;
  if FWindowHandle <> 0 then
  begin
    DeallocateHWnd(FWindowHandle);
    FWindowHandle := 0;
  end;
end;

procedure TLauncherGlobalHotkeys.Enable;
begin
  if not GLOBAL_LAUNCHER_HOTKEYS_ENABLED then
    Exit;

  // Safe to call again when the parent frame becomes visible.
  if FRegistered then
    Exit;

  if FWindowHandle = 0 then
    // RegisterHotKey の通知を受けるためのメッセージ専用ウィンドウ。
    FWindowHandle := AllocateHWnd(WndProc);

  RegisterAll;
end;

procedure TLauncherGlobalHotkeys.RegisterAll;
var
  KeyNumber: Integer;
  VirtualKey: UINT;
  SuccessCount: Integer;
begin
  if FWindowHandle = 0 then
    Exit;

  SuccessCount := 0;
  for KeyNumber := 0 to 9 do
  begin
    // Ctrl+Alt+0..9 をまとめて登録する。既に他アプリが使っているキーは失敗ログだけ残す。
    VirtualKey := Ord('0') + KeyNumber;
    if RegisterHotKey(FWindowHandle, HOTKEY_ID_BASE + KeyNumber,
      HOTKEY_MODIFIERS, VirtualKey) then
      Inc(SuccessCount)
    else
      OutputDebugString(PChar(Format(
        '[Launcher] RegisterHotKey failed Ctrl+Alt+%d Error=%d',
        [KeyNumber, GetLastError])));
  end;

  // 全滅した時だけ未登録扱いにして、次の Enable で再試行できるようにする。
  FRegistered := SuccessCount > 0;
end;

procedure TLauncherGlobalHotkeys.UnregisterAll;
var
  KeyNumber: Integer;
begin
  if (not FRegistered) or (FWindowHandle = 0) then
    Exit;

  for KeyNumber := 0 to 9 do
    UnregisterHotKey(FWindowHandle, HOTKEY_ID_BASE + KeyNumber);

  FRegistered := False;
end;

procedure TLauncherGlobalHotkeys.WndProc(var Msg: TMessage);
var
  KeyNumber: Integer;
begin
  if Msg.Msg <> WM_HOTKEY then
  begin
    Msg.Result := DefWindowProc(FWindowHandle, Msg.Msg, Msg.WParam, Msg.LParam);
    Exit;
  end;

  KeyNumber := Integer(Msg.WParam) - HOTKEY_ID_BASE;
  if (KeyNumber < 0) or (KeyNumber > 9) then
  begin
    Msg.Result := 0;
    Exit;
  end;

  if Assigned(FOnHotkey) then
    FOnHotkey(Self, KeyNumber);
  Msg.Result := 1;
end;

function ActivateAviUtl2Window: Boolean;
var
  Infos: TWindowInfoList;
  I: Integer;
  Info: TWindowInfo;
  ExecName: string;
begin
  Result := False;

  Infos := TWindowInfoList.Create;
  try
    Infos.LoadActiveWindows([lwDuplicates, lwUWP, lwSelfProcess]);
    for I := 0 to Infos.Count - 1 do
    begin
      Info := Infos[I];
      ExecName := ChangeFileExt(ExtractFileName(Info.ExeName), '');
      if ExecName = '' then
        ExecName := ChangeFileExt(ExtractFileName(Info.ProcessName), '');
      if not SameText(ExecName, AVIUTL2_EXECUTABLE_NAME) then
        Continue;

      Result := ActivateLauncherWindow(Info.Handle);
      Exit;
    end;
  finally
    Infos.Free;
  end;
end;

end.
