unit SerifWatcherController;

interface

uses SerifWatcherList, SerifWindowWatcher, SerifSceneFrame, SerifMonitorFrame;

// 旧swsWatchを現在の流し込み有効状態swsSendへ正規化する。
function NormalizeSerifWatchState(State: TSerifWatchState): TSerifWatchState;

// 補助ウィンドウ監視、フォルダー監視、自動送信、状態表示を同じ状態へ揃える。
procedure ApplySerifWatcherState(State: TSerifWatchState;
  WindowWatcher: TSerifWindowWatcher; Watchers: TSerifWatcherList;
  SceneFrame: TFrameSerifScene; MonitorFrame: TFrameSerifMonitor);

// 監視設定変更時に実行中監視を止め、表示更新と共通設定保存を行う。
procedure ApplySerifWatcherSettingsChange(Watchers,
  CommonWatchers: TSerifWatcherList; MonitorFrame: TFrameSerifMonitor);

implementation

uses SerifWatcherSettings;

function NormalizeSerifWatchState(State: TSerifWatchState): TSerifWatchState;
begin
  if State = swsWatch then Result := swsSend else Result := State;
end;

procedure ApplySerifWatcherState(State: TSerifWatchState;
  WindowWatcher: TSerifWindowWatcher; Watchers: TSerifWatcherList;
  SceneFrame: TFrameSerifScene; MonitorFrame: TFrameSerifMonitor);
begin
  State := NormalizeSerifWatchState(State);
  WindowWatcher.WatchState := State;
  case State of
    swsStandby:
      begin
        Watchers.Stop;
        SceneFrame.AutoSend := False;
      end;
    swsSend:
      begin
        Watchers.Start;
        SceneFrame.AutoSend := True;
      end;
  end;
  MonitorFrame.ShowStatus(Watchers);
end;

procedure ApplySerifWatcherSettingsChange(Watchers,
  CommonWatchers: TSerifWatcherList; MonitorFrame: TFrameSerifMonitor);
begin
  Watchers.Stop;
  MonitorFrame.ShowStatus(Watchers);
  SaveCommonSerifWatcherSettings(Watchers, CommonWatchers);
end;

end.
