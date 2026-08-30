unit SerifRuntimeController;

// SerifFrameのイベントから非表示データの変更・保存処理を分離する。
// UI部品は参照せず、セリフ一覧への追加だけをコールバックで要求する。

interface

uses
  System.Classes,
  AviUtl2Serif,
  SerifAnalyzer,
  SerifCharaList,
  SerifConfig,
  SerifSceneList,
  SerifSceneMsgList,
  SerifVoicevoxAudioSettings,
  SerifVoicevoxRegistration;

// 配役名変更を読込済みシーンと監視取込中リストへ反映し、変更時だけ保存する。
function ReassignSerifCharacter(const OldName, Keyword, NewName: string;
  Scenes: TSerifSceneList; WorkMsgs: TSerifSceneMsgList): Boolean;
// 配役設定の変更を保存する。
procedure SaveSerifCharacterChange(Charas: TSerifCharaList);
// 通常設定の変更を保存する。
procedure SaveSerifConfigChange(Config: TSerifConfigItem);
// 改行設定と、それにより更新されたシーンデータを保存する。
procedure SaveSerifEnterPositionChange(Config: TSerifConfigItem;
  Scenes: TSerifSceneList);
// シーン内容の変更を保存する。
procedure SaveSerifSceneChange(Scenes: TSerifSceneList);

// 監視検出ファイルを解析・登録し、配置失敗時は未送信として保持して保存する。
function ImportSerifWatcherFiles(const ProjectFolder: string;
  Files: TStringList; Analyzer: TSerifAnalyzer; WorkMsgs: TSerifSceneMsgList;
  Charas: TSerifCharaList; Config: TSerifConfigItem;
  Scenes: TSerifSceneList; AddMessages: TSerifAddMessagesMethod;
  var ErrLine: Integer): Boolean;

// VOICEVOX生成結果を登録し、成功後のシーンと配役を保存する。
function RegisterSerifVoicevoxAndSave(const ProjectFolder, Text,
  SpeakerName, StyleName, AccentQueryJson: string; const StyleId: Integer;
  const AudioValues: TSerifVoicevoxAudioValues;
  const ReeditTarget: TSerifAviUtl2Selection;
  SceneMsgs, WorkMsgs: TSerifSceneMsgList; Charas: TSerifCharaList;
  Config: TSerifConfigItem; Scenes: TSerifSceneList;
  AddMessages: TSerifAddMessagesMethod; var ErrorMessage: string;
  var SavedUnsent: Boolean): Boolean;

implementation

uses
  System.SysUtils;

function ReassignSerifCharacter(const OldName, Keyword, NewName: string;
  Scenes: TSerifSceneList; WorkMsgs: TSerifSceneMsgList): Boolean;
var
  I: Integer;
  J: Integer;
  Msg: TSerifSceneMsgItem;
  Scene: TSerifSceneItem;

  function ShouldReassign(MsgItem: TSerifSceneMsgItem): Boolean;
  begin
    Result := False;
    if MsgItem = nil then Exit;
    if (Trim(Keyword) <> '') and
       SameText(Trim(MsgItem.Keyword), Trim(Keyword)) then
      Exit(True);
    Result := (Trim(MsgItem.Keyword) = '') and
      SameText(Trim(MsgItem.Chara), Trim(OldName));
  end;

  procedure Reassign(MsgItem: TSerifSceneMsgItem);
  begin
    if not ShouldReassign(MsgItem) then Exit;
    if Trim(MsgItem.Keyword) = '' then
      MsgItem.Keyword := Keyword;
    MsgItem.Chara := NewName;
    Result := True;
  end;

begin
  Result := False;
  for I := 0 to Scenes.Count - 1 do
  begin
    Scene := Scenes[I];
    if Scene = nil then Continue;
    for J := 0 to Scene.Msgs.Count - 1 do
      Reassign(Scene.Msgs[J]);
  end;
  for I := 0 to WorkMsgs.Count - 1 do
  begin
    Msg := WorkMsgs[I];
    Reassign(Msg);
  end;
  if Result then
    Scenes.SaveToFile;
end;

procedure SaveSerifCharacterChange(Charas: TSerifCharaList);
begin
  Charas.SaveToFile;
end;

procedure SaveSerifConfigChange(Config: TSerifConfigItem);
begin
  Config.SaveToFile;
end;

procedure SaveSerifEnterPositionChange(Config: TSerifConfigItem;
  Scenes: TSerifSceneList);
begin
  Config.SaveToFile;
  Scenes.SaveToFile;
end;

procedure SaveSerifSceneChange(Scenes: TSerifSceneList);
begin
  Scenes.SaveToFile;
end;

function ImportSerifWatcherFiles(const ProjectFolder: string;
  Files: TStringList; Analyzer: TSerifAnalyzer; WorkMsgs: TSerifSceneMsgList;
  Charas: TSerifCharaList; Config: TSerifConfigItem;
  Scenes: TSerifSceneList; AddMessages: TSerifAddMessagesMethod;
  var ErrLine: Integer): Boolean;
begin
  Result := Analyzer.Execute(WorkMsgs, Charas, ProjectFolder, Files,
    Config, ErrLine);
  if not Result then Exit;
  Result := AddMessages(WorkMsgs, False, False, False);
  if not Result then
    Result := AddMessages(WorkMsgs, False, False, True);
  if not Result then Exit;
  Scenes.SaveToFile;
  Charas.SaveToFile;
end;

function RegisterSerifVoicevoxAndSave(const ProjectFolder, Text,
  SpeakerName, StyleName, AccentQueryJson: string; const StyleId: Integer;
  const AudioValues: TSerifVoicevoxAudioValues;
  const ReeditTarget: TSerifAviUtl2Selection;
  SceneMsgs, WorkMsgs: TSerifSceneMsgList; Charas: TSerifCharaList;
  Config: TSerifConfigItem; Scenes: TSerifSceneList;
  AddMessages: TSerifAddMessagesMethod; var ErrorMessage: string;
  var SavedUnsent: Boolean): Boolean;
begin
  Result := RegisterSerifVoicevoxResult(ProjectFolder, Text, SpeakerName,
    StyleName, AccentQueryJson, StyleId, AudioValues, ReeditTarget,
    SceneMsgs, WorkMsgs, Charas, Config, AddMessages, ErrorMessage,
    SavedUnsent);
  if not Result then Exit;
  Scenes.SaveToFile;
  Charas.SaveToFile;
end;

end.
