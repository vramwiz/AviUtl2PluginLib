unit SerifWindowWatcher;

interface

uses
  Winapi.Windows, System.Classes, System.Generics.Collections, Vcl.ExtCtrls,
  SerifMonitorFrame, SerifWindowWatchTarget;

type
  // 音声合成アプリが表示する補助ウィンドウを検出し、アプリ別ターゲットへ委譲する監視クラス。
  TSerifWindowWatcher = class(TPersistent)
  private
    FTimer: TTimer; // ウィンドウ監視を定期実行するタイマー
    FKnownWindows: TList<HWND>; // 既に検出済みのトップレベルウィンドウ一覧
    FTargets: TObjectList<TSerifWindowWatchTarget>; // アプリ別ウィンドウ処理ターゲット一覧
    FWatchState: TSerifWatchState; // 外部から指定される監視状態
    FDebugTimerCount: Integer;
    // 監視状態の変更を開始・停止処理へ反映する。
    procedure SetWatchState(const Value: TSerifWatchState);
    // Enabled プロパティの変更を開始・停止処理へ反映する。
    procedure SetEnabled(const Value: Boolean);
    // 現在タイマー監視が有効かを返す。
    function GetEnabled: Boolean;
    // タイマーごとにウィンドウ検出と各ターゲットの進行確認を行う。
    procedure OnTimer(Sender: TObject);
    // 現在表示されている対象ウィンドウを検出済み一覧へ登録する。
    procedure RefreshKnownWindows;
    // 閉じられたウィンドウを検出済み一覧から除外する。
    procedure RemoveClosedWindows;
    // 新しく表示された対象ウィンドウを確認する。
    procedure CheckNewWindows;
    // 新規ウィンドウを処理できるアプリ別ターゲットへ渡す。
    procedure HandleNewWindow(Wnd: HWND);
    // すべてのアプリ別ターゲットの進行中フローを確認する。
    procedure TickTargets;
    // すべてのアプリ別ターゲットの内部状態を初期化する。
    procedure ResetTargets;
    // 指定アプリ種別を担当するターゲットを返す。
    function FindTarget(AppKind: TSerifSpeechAppKind): TSerifWindowWatchTarget;
    procedure DebugLog(const Text: string);
    function AppKindText(AppKind: TSerifSpeechAppKind): string;
  public
    // 監視クラスを生成し内部タイマーとアプリ別ターゲットを初期化する。
    constructor Create;
    // 監視を停止して内部リソースを破棄する。
    destructor Destroy; override;
    // 現在のウィンドウを既知化して監視を開始する。
    procedure Start;
    // 監視を停止して保存フロー状態を初期化する。
    procedure Stop;
    // 指定音声合成アプリのメインウィンドウを登録し、0 の場合は登録を解除する。
    procedure SetWatchTargetWindow(AppKind: TSerifSpeechAppKind; Wnd: HWND);
    property Enabled: Boolean read GetEnabled write SetEnabled;
    property WatchState: TSerifWatchState read FWatchState write SetWatchState;
  end;

implementation

uses
  SerifWindowWatchUtils, SerifWindowWatchVoiceroid2, SerifWindowWatchAivoice,
  SerifWindowWatchAivoice2, SerifWindowWatchVoicepeak, SerifWindowWatchCeVIOAI,
  System.SysUtils
  {$IFDEF DEBUG}, PSDImageDebugLog{$ENDIF};

const
  VOICEROID_TIMER_INTERVAL_MS = 100;
  WINDOW_WATCHER_DEBUG_DETAIL = True;
  WINDOW_WATCHER_DEBUG_TIMER_INTERVAL = 50;

type
  PEnumWindowContext = ^TEnumWindowContext;
  TEnumWindowContext = record
    Watcher: TSerifWindowWatcher;
    Windows: TList<HWND>;
  end;

function EnumKnownWindowsProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PEnumWindowContext;
begin
  Context := PEnumWindowContext(Pointer(LParam));
  if IsTopLevelVisibleWindow(Wnd) then
    Context.Windows.Add(Wnd);
  Result := True;
end;

function EnumCheckWindowsProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Context: PEnumWindowContext;
begin
  Context := PEnumWindowContext(Pointer(LParam));
  if IsTopLevelVisibleWindow(Wnd) then
  begin
    // 既知ウィンドウは再処理せず、新規ウィンドウだけをアプリ別ターゲットへ渡す。
    if Context.Watcher.FKnownWindows.IndexOf(Wnd) < 0 then
    begin
      Context.Watcher.FKnownWindows.Add(Wnd);
      Context.Watcher.HandleNewWindow(Wnd);
    end;
  end;
  Result := True;
end;

{ TSerifWindowWatcher }

function TSerifWindowWatcher.AppKindText(AppKind: TSerifSpeechAppKind): string;
begin
  case AppKind of
    ssakVoiceroid2:
      Result := 'VOICEROID2';
    ssakAivoice:
      Result := 'A.I.VOICE';
    ssakAivoice2:
      Result := 'A.I.VOICE2';
    ssakVoicepeak:
      Result := 'VOICEPEAK';
    ssakCeVIOAI:
      Result := 'CeVIO AI';
  else
    Result := Format('Unknown(%d)', [Ord(AppKind)]);
  end;
end;

procedure TSerifWindowWatcher.CheckNewWindows;
var
  Context: TEnumWindowContext;
begin
  Context.Watcher := Self;
  Context.Windows := nil;
  EnumWindows(@EnumCheckWindowsProc, LPARAM(Pointer(@Context)));
end;

constructor TSerifWindowWatcher.Create;
begin
  inherited;
  FKnownWindows := TList<HWND>.Create;
  FTargets := TObjectList<TSerifWindowWatchTarget>.Create(True);
  FTargets.Add(TSerifWindowWatchAivoice.Create);
  FTargets.Add(TSerifWindowWatchAivoice2.Create);
  FTargets.Add(TSerifWindowWatchVoicepeak.Create);
  FTargets.Add(TSerifWindowWatchVoiceroid2.Create);
  FTargets.Add(TSerifWindowWatchCeVIOAI.Create);
  FWatchState := swsStandby;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := VOICEROID_TIMER_INTERVAL_MS;
  FTimer.OnTimer := OnTimer;
  DebugLog(Format('Watcher create targets=%d interval=%d',
    [FTargets.Count, FTimer.Interval]));
end;

procedure TSerifWindowWatcher.DebugLog(const Text: string);
begin
  {$IFDEF DEBUG}
  PSDDebugLog('SerifWindowWatcher', Text);
  {$ELSE}
  OutputDebugString(PChar('[SerifWindowWatcher] ' + Text));
  {$ENDIF}
end;

destructor TSerifWindowWatcher.Destroy;
begin
  Stop;
  FTimer.Free;
  FTargets.Free;
  FKnownWindows.Free;
  inherited;
end;

function TSerifWindowWatcher.FindTarget(AppKind: TSerifSpeechAppKind): TSerifWindowWatchTarget;
var
  Target: TSerifWindowWatchTarget;
begin
  Result := nil;
  for Target in FTargets do
  begin
    if Target.AppKind = AppKind then
    begin
      Result := Target;
      Exit;
    end;
  end;
end;

function TSerifWindowWatcher.GetEnabled: Boolean;
begin
  Result := FTimer.Enabled;
end;

procedure TSerifWindowWatcher.HandleNewWindow(Wnd: HWND);
var
  Target: TSerifWindowWatchTarget;
begin
  for Target in FTargets do
  begin
    // 最初に一致したターゲットへ処理を任せ、別アプリ処理との二重操作を避ける。
    if Target.CanHandleWindow(Wnd) then
    begin
      DebugLog(Format('HandleNewWindow app=%s hwnd=%p title="%s"',
        [AppKindText(Target.AppKind), Pointer(Wnd), GetWindowString(Wnd)]));
      Target.HandleNewWindow(Wnd);
      Break;
    end;
  end;
end;

procedure TSerifWindowWatcher.OnTimer(Sender: TObject);
begin
  Inc(FDebugTimerCount);
  if WINDOW_WATCHER_DEBUG_DETAIL then
  begin
    if (FDebugTimerCount = 1) or
       ((FDebugTimerCount mod WINDOW_WATCHER_DEBUG_TIMER_INTERVAL) = 0) then
      DebugLog(Format('OnTimer count=%d enabled=%s known=%d state=%d',
        [FDebugTimerCount, BoolText(FTimer.Enabled), FKnownWindows.Count, Ord(FWatchState)]));
  end;
  // 既知一覧の整理、新規検出、進行中フローの確認を毎 tick 順番に行う。
  RemoveClosedWindows;
  CheckNewWindows;
  TickTargets;
end;

procedure TSerifWindowWatcher.RefreshKnownWindows;
var
  Context: TEnumWindowContext;
begin
  FKnownWindows.Clear;
  Context.Watcher := Self;
  Context.Windows := FKnownWindows;
  // 開始時点で存在するウィンドウを既知扱いにし、古いダイアログへ反応しないようにする。
  EnumWindows(@EnumKnownWindowsProc, LPARAM(Pointer(@Context)));
end;

procedure TSerifWindowWatcher.RemoveClosedWindows;
var
  I: Integer;
begin
  // 削除しながら走査するため、末尾から逆順に確認する。
  for I := FKnownWindows.Count - 1 downto 0 do
  begin
    if not IsWindow(FKnownWindows[I]) then
      FKnownWindows.Delete(I);
  end;
end;

procedure TSerifWindowWatcher.ResetTargets;
var
  Target: TSerifWindowWatchTarget;
begin
  for Target in FTargets do
  begin
    if WINDOW_WATCHER_DEBUG_DETAIL then
      DebugLog('ResetTarget app=' + AppKindText(Target.AppKind));
    Target.Reset;
  end;
end;

procedure TSerifWindowWatcher.SetEnabled(const Value: Boolean);
begin
  if Value then
    Start
  else
    Stop;
end;

procedure TSerifWindowWatcher.SetWatchTargetWindow(AppKind: TSerifSpeechAppKind; Wnd: HWND);
var
  Target: TSerifWindowWatchTarget;
begin
  DebugLog(Format('SetWatchTargetWindow app=%s hwnd=%p title="%s"',
    [AppKindText(AppKind), Pointer(Wnd), GetWindowString(Wnd)]));
  Target := FindTarget(AppKind);
  if Target <> nil then
    Target.SetTargetWindow(Wnd);
end;

procedure TSerifWindowWatcher.SetWatchState(const Value: TSerifWatchState);
begin
  DebugLog(Format('SetWatchState old=%d new=%d enabled=%s',
    [Ord(FWatchState), Ord(Value), BoolText(FTimer.Enabled)]));
  FWatchState := Value;
  // swsWatch は旧状態名。補助ウィンドウ自動操作も必要なので swsSend と同じ扱いにする。
  if FWatchState = swsWatch then
    FWatchState := swsSend;
  case FWatchState of
    // 待機中はウィンドウ監視を止める。
    swsStandby:
      Stop;
    // 送信中だけ音声合成アプリの保存ダイアログ自動操作を有効にする。
    swsSend:
      Start;
  end;
end;

procedure TSerifWindowWatcher.Start;
begin
  RefreshKnownWindows;
  FDebugTimerCount := 0;
  FTimer.Enabled := True;
  DebugLog(Format('Start known=%d enabled=%s',
    [FKnownWindows.Count, BoolText(FTimer.Enabled)]));
end;

procedure TSerifWindowWatcher.Stop;
begin
  DebugLog(Format('Stop enabled=%s known=%d', [BoolText(FTimer.Enabled), FKnownWindows.Count]));
  FTimer.Enabled := False;
  FKnownWindows.Clear;
  ResetTargets;
end;

procedure TSerifWindowWatcher.TickTargets;
var
  Target: TSerifWindowWatchTarget;
begin
  for Target in FTargets do
    Target.Tick;
end;

end.
