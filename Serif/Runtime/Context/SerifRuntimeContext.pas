unit SerifRuntimeContext;

// セリフ画面が利用する非表示データとサービスの生成・破棄を一括所有する。
// VCL子フレームと一時プロジェクトのロックは画面固有のため所有しない。

interface

uses
  System.Classes,
  SerifAnalyzer,
  SerifCharaList,
  SerifConfig,
  SerifProject,
  SerifScenarioCharaList,
  SerifScenarioMsgList,
  SerifSceneList,
  SerifSceneMsgList,
  SerifWatcherList,
  SerifWindowWatcher;

type
  TSerifRuntimeContext = class
  private
    FProjects: TSerifProjectList;
    FScenes: TSerifSceneList;
    FCharas: TSerifCharaList;
    FWatchers: TSerifWatcherList;
    FCommonWatchers: TSerifWatcherList;
    FWindowWatcher: TSerifWindowWatcher;
    FAnalyzer: TSerifAnalyzer;
    FConfig: TSerifConfigItem;
    FMsgs: TSerifSceneMsgList;
    FScenarioCharas: TSerifScenarioCharaList;
    FScenarioMsgs: TSerifScenarioMsgList;
  public
    // Serif保存フォルダーを基準に全データを生成し、監視通知を接続する。
    constructor Create(const SerifFolder: string;
      const OnDetectedFiles: TSerifVoiceWatcherEvent;
      const OnWaitFiles: TNotifyEvent);
    // 読込済みシーンを保存してから、生成と逆順に全データを破棄する。
    destructor Destroy; override;

    property Projects: TSerifProjectList read FProjects;
    property Scenes: TSerifSceneList read FScenes;
    property Charas: TSerifCharaList read FCharas;
    property Watchers: TSerifWatcherList read FWatchers;
    property CommonWatchers: TSerifWatcherList read FCommonWatchers;
    property WindowWatcher: TSerifWindowWatcher read FWindowWatcher;
    property Analyzer: TSerifAnalyzer read FAnalyzer;
    property Config: TSerifConfigItem read FConfig;
    property Msgs: TSerifSceneMsgList read FMsgs;
    property ScenarioCharas: TSerifScenarioCharaList read FScenarioCharas;
    property ScenarioMsgs: TSerifScenarioMsgList read FScenarioMsgs;
  end;

implementation

uses
  SerifProjectLifecycle;

constructor TSerifRuntimeContext.Create(const SerifFolder: string;
  const OnDetectedFiles: TSerifVoiceWatcherEvent;
  const OnWaitFiles: TNotifyEvent);
begin
  inherited Create;

  FProjects := TSerifProjectList.Create(SerifFolder, 'SerifProject.Ini');
  FProjects.SyncProjectFolders;
  FScenes := TSerifSceneList.Create;
  FCharas := TSerifCharaList.Create;
  FWatchers := TSerifWatcherList.Create;
  FWatchers.OnDetectedFiles := OnDetectedFiles;
  FWatchers.OnWaitFiles := OnWaitFiles;
  FCommonWatchers := TSerifWatcherList.Create;
  FWindowWatcher := TSerifWindowWatcher.Create;
  FAnalyzer := TSerifAnalyzer.Create;
  FConfig := TSerifConfigItem.Create;
  FMsgs := TSerifSceneMsgList.Create;

  CleanupOrphanTemporarySerifProjects;

  FScenarioCharas := TSerifScenarioCharaList.Create;
  FScenarioCharas.Filename := SerifFolder + 'ScenarioChara.ini';
  FScenarioCharas.LoadFromFile;
  FScenarioMsgs := TSerifScenarioMsgList.Create;
  FScenarioMsgs.Filename := SerifFolder + 'ScenarioMsg.ini';
  FScenarioMsgs.LoadFromFile;
end;

destructor TSerifRuntimeContext.Destroy;
begin
  FScenarioMsgs.Free;
  FScenarioCharas.Free;
  FMsgs.Free;
  FConfig.Free;
  FAnalyzer.Free;
  FWindowWatcher.Free;
  FWatchers.Free;
  FCommonWatchers.Free;
  FCharas.Free;
  if Assigned(FScenes) and (FScenes.Filename <> '') then
    FScenes.SaveToFile;
  FScenes.Free;
  FProjects.Free;
  inherited;
end;

end.
