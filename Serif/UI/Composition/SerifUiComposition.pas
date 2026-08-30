unit SerifUiComposition;

interface

uses Winapi.Windows, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.ExtCtrls,
     Vcl.StdCtrls, DarkLabel,
     SerifProject, SerifProjectFrame, SerifScenarioFrame, SerifSceneFrame,
     SerifVoicevoxSimpleInputFrame, SerifCharaListFrame, SerifWatcherFrame,
     SerifMonitorFrame, SerifConfigFrame, SerifDrawFrame, SerifAliasFrame,
     SerifBoardFrame;

type
  TSerifUiHosts = record
    ProjectPanel: TWinControl;
    ScenarioPanel: TWinControl;
    SerifPanel: TWinControl;
    CharaPanel: TWinControl;
    ConfigPanel: TWinControl;
    MonitorPanel: TWinControl;
    DrawPanel: TWinControl;
    ViewPanel: TWinControl;
    BoardPanel: TWinControl;
  end;

  TSerifUiHandlers = record
    ProjectOpen: TFrameProjectManagerOpen;
    SceneChange: TNotifyEvent;
    SceneCharaChange: TNotifyEvent;
    SceneMoveCursorFocus: TFrameSerifSceneCursorFocusEvent;
    VoicevoxSend: TSerifVoicevoxSimpleSendEvent;
    InputExpandedChange: TNotifyEvent;
    VoicevoxMoveEnd: TNotifyEvent;
    VoicevoxStatus: TSerifVoicevoxSimpleStatusEvent;
    CharaChange: TNotifyEvent;
    CharaRename: TSerifCharaRenameEvent;
    WatcherChange: TNotifyEvent;
    MonitorChange: TFrameSerifMonitorEvent;
    ConfigChange: TNotifyEvent;
    ConfigEnterPosChange: TNotifyEvent;
  end;

  TSerifUiParts = record
    ProjectFrame: TFrameSerifProject;
    ScenarioFrame: TFrameSerifScenario;
    SceneFrame: TFrameSerifScene;
    InputFrame: TFrameSerifVoicevoxSimpleInput;
    InputSplitter: TSplitter;
    CharaFrame: TFrameSerifCharaList;
    WatcherFrame: TFrameSerifWatcher;
    MonitorFrame: TFrameSerifMonitor;
    VoicevoxStatusLabel: TDarkLabel;
    ConfigFrame: TFrameSerifConfig;
    DrawFrame: TFrameSerifDraw;
    AliasFrame: TFrameSerifAlias;
    BoardFrame: TFrameSerifBoard;
  end;

// SerifFrame配下の子フレームを生成し、親・配置・イベントを一括接続する。
// 所有者は従来どおりOwnerで、呼出側は返された参照を既存順序で破棄できる。
procedure ComposeSerifUi(Owner: TComponent; const CurrentPPI: Integer;
  Projects: TSerifProjectList; const Hosts: TSerifUiHosts;
  const Handlers: TSerifUiHandlers; out Parts: TSerifUiParts);

implementation

uses AviUtl2StyleColors, SerifVoicevoxDebugLog;

procedure ComposeSerifUi(Owner: TComponent; const CurrentPPI: Integer;
  Projects: TSerifProjectList; const Hosts: TSerifUiHosts;
  const Handlers: TSerifUiHandlers; out Parts: TSerifUiParts);
begin
  Parts := Default(TSerifUiParts);

  Parts.ProjectFrame := TFrameSerifProject.Create(Owner);
  Parts.ProjectFrame.Parent := Hosts.ProjectPanel;
  Parts.ProjectFrame.Align := alClient;
  Parts.ProjectFrame.Projects := Projects;
  Parts.ProjectFrame.OnProjectOpen := Handlers.ProjectOpen;

  Parts.ScenarioFrame := TFrameSerifScenario.Create(Owner);
  Parts.ScenarioFrame.Parent := Hosts.ScenarioPanel;
  Parts.ScenarioFrame.Align := alClient;

  Parts.SceneFrame := TFrameSerifScene.Create(Owner);
  Parts.SceneFrame.Parent := Hosts.SerifPanel;
  Parts.SceneFrame.Align := alClient;
  Parts.SceneFrame.OnChange := Handlers.SceneChange;
  Parts.SceneFrame.OnCharaChange := Handlers.SceneCharaChange;
  Parts.SceneFrame.OnMoveCursorFocus := Handlers.SceneMoveCursorFocus;

  VoicevoxDebugLog('SerifFrame.Create creating SimpleInputFrame');
  Parts.InputFrame := TFrameSerifVoicevoxSimpleInput.Create(Owner);
  Parts.InputFrame.Parent := Hosts.SerifPanel;
  Parts.InputFrame.Align := alTop;
  Parts.InputFrame.Top := 0;
  Parts.InputFrame.OnSend := Handlers.VoicevoxSend;
  Parts.InputFrame.OnExpandedChange := Handlers.InputExpandedChange;
  Parts.InputFrame.OnMoveEnd := Handlers.VoicevoxMoveEnd;
  Parts.InputFrame.OnStatus := Handlers.VoicevoxStatus;
  Parts.InputFrame.BringToFront;

  Parts.InputSplitter := TSplitter.Create(Owner);
  Parts.InputSplitter.Parent := Hosts.SerifPanel;
  Parts.InputSplitter.Align := alTop;
  Parts.InputSplitter.Top := Parts.InputFrame.Height;
  Parts.InputSplitter.Height := MulDiv(5, CurrentPPI, 96);
  Parts.InputSplitter.MinSize := MulDiv(210, CurrentPPI, 96);
  Parts.InputSplitter.AutoSnap := False;
  Parts.InputSplitter.Beveled := True;
  Parts.InputSplitter.Color := A2SCToolBarBackground;
  Parts.InputSplitter.Cursor := crVSplit;
  Parts.InputSplitter.ResizeStyle := rsUpdate;
  Parts.InputSplitter.Visible := Parts.InputFrame.Expanded;
  Parts.InputSplitter.BringToFront;
  VoicevoxDebugLog('SerifFrame.Create created SimpleInputFrame (API not prepared)');

  Parts.CharaFrame := TFrameSerifCharaList.Create(Owner);
  Parts.CharaFrame.Parent := Hosts.CharaPanel;
  Parts.CharaFrame.Align := alClient;
  Parts.CharaFrame.OnChange := Handlers.CharaChange;
  Parts.CharaFrame.OnRenameChara := Handlers.CharaRename;

  Parts.WatcherFrame := TFrameSerifWatcher.Create(Owner);
  Parts.WatcherFrame.Parent := Hosts.ConfigPanel;
  Parts.WatcherFrame.Align := alClient;
  Parts.WatcherFrame.OnChange := Handlers.WatcherChange;

  Parts.MonitorFrame := TFrameSerifMonitor.Create(Owner);
  Parts.MonitorFrame.Parent := Hosts.MonitorPanel;
  Parts.MonitorFrame.Align := alClient;
  Parts.MonitorFrame.OnChange := Handlers.MonitorChange;

  Parts.VoicevoxStatusLabel := TDarkLabel.Create(Owner);
  Parts.VoicevoxStatusLabel.Parent := Parts.MonitorFrame.PanelBase;
  Parts.VoicevoxStatusLabel.Align := alRight;
  Parts.VoicevoxStatusLabel.Width := 0;
  Parts.VoicevoxStatusLabel.Alignment := taCenter;
  Parts.VoicevoxStatusLabel.AutoSize := False;
  Parts.VoicevoxStatusLabel.DesignFontHeight := 13;
  Parts.VoicevoxStatusLabel.TextColor := $00D8E8FF;
  Parts.VoicevoxStatusLabel.Layout := tlCenter;

  Parts.ConfigFrame := TFrameSerifConfig.Create(Owner);
  Parts.ConfigFrame.Parent := Hosts.ConfigPanel;
  Parts.ConfigFrame.Align := alTop;
  Parts.ConfigFrame.Height := MulDiv(100, CurrentPPI, 96);
  Parts.ConfigFrame.OnChange := Handlers.ConfigChange;
  Parts.ConfigFrame.OnEnterPosChange := Handlers.ConfigEnterPosChange;

  Parts.DrawFrame := TFrameSerifDraw.Create(Owner);
  Parts.DrawFrame.Parent := Hosts.DrawPanel;
  Parts.DrawFrame.Align := alClient;

  Parts.AliasFrame := TFrameSerifAlias.Create(Owner);
  Parts.AliasFrame.Parent := Hosts.ViewPanel;
  Parts.AliasFrame.Align := alClient;

  Parts.BoardFrame := TFrameSerifBoard.Create(Owner);
  Parts.BoardFrame.Parent := Hosts.BoardPanel;
  Parts.BoardFrame.Align := alClient;
end;

end.
