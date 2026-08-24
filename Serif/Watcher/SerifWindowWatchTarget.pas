unit SerifWindowWatchTarget;

interface

uses
  Winapi.Windows, System.Classes;

type
  TSerifSpeechAppKind = (
    ssakVoiceroid2,
    ssakAivoice,
    ssakAivoice2,
    ssakVoicepeak,
    ssakCeVIOAI
  );

type
  // 音声合成アプリごとの補助ウィンドウ処理を差し替えるための基底クラス。
  TSerifWindowWatchTarget = class(TPersistent)
  private
    FTargetMainWindow: HWND; // 厳密判定の基準にする音声合成アプリのメインウィンドウハンドル
    FTargetProcessID: DWORD; // 対象メインウィンドウから取得したプロセス ID
  protected
    // メインウィンドウ内に描画されるモーダルを監視するターゲット用。
    function TargetMainWindow: HWND;
    // 対象メインウィンドウから取得したプロセス ID を返す。
    function TargetProcessID: DWORD;
  public
    // 厳密判定が有効な場合に、指定ウィンドウが対象プロセス由来かを確認する。
    function IsTargetProcessWindow(Wnd: HWND): Boolean;
    // 対象アプリのメインウィンドウが登録されているかを返す。
    function HasTargetWindow: Boolean;
    // このターゲットが担当する音声合成アプリ種別を返す。
    function AppKind: TSerifSpeechAppKind; virtual; abstract;
    // 監視停止時やフロー終了時に内部状態を初期化する。
    procedure Reset; virtual; abstract;
    // タイマーごとに進行中のアプリ固有フローを確認する。
    procedure Tick; virtual; abstract;
    // 指定ウィンドウをこのターゲットが扱うか判定する。
    function CanHandleWindow(Wnd: HWND): Boolean; virtual; abstract;
    // 新しく検出された対象ウィンドウを処理する。
    procedure HandleNewWindow(Wnd: HWND); virtual; abstract;
    // 対象アプリのメインウィンドウを登録し、0 の場合は登録を解除する。
    procedure SetTargetWindow(Wnd: HWND);
  end;

implementation

function TSerifWindowWatchTarget.IsTargetProcessWindow(Wnd: HWND): Boolean;
var
  WindowProcessID: DWORD;
begin
  Result := False;
  if (FTargetMainWindow = 0) or
     (FTargetProcessID = 0) or
     (not IsWindow(FTargetMainWindow)) or
     (not IsWindow(Wnd)) then
    Exit;

  WindowProcessID := 0;
  GetWindowThreadProcessId(Wnd, @WindowProcessID);
  Result := WindowProcessID = FTargetProcessID;
end;

function TSerifWindowWatchTarget.HasTargetWindow: Boolean;
begin
  Result := (FTargetMainWindow <> 0) and
            (FTargetProcessID <> 0) and
            IsWindow(FTargetMainWindow);
end;

function TSerifWindowWatchTarget.TargetMainWindow: HWND;
begin
  if HasTargetWindow then
    Result := FTargetMainWindow
  else
    Result := 0;
end;

function TSerifWindowWatchTarget.TargetProcessID: DWORD;
begin
  if HasTargetWindow then
    Result := FTargetProcessID
  else
    Result := 0;
end;

procedure TSerifWindowWatchTarget.SetTargetWindow(Wnd: HWND);
begin
  FTargetMainWindow := Wnd;
  FTargetProcessID := 0;
  if IsWindow(FTargetMainWindow) then
    GetWindowThreadProcessId(FTargetMainWindow, @FTargetProcessID);
end;

end.
