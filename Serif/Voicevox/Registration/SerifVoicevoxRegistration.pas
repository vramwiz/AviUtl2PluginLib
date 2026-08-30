unit SerifVoicevoxRegistration;


interface

uses SerifSceneMsgList, SerifCharaList, SerifConfig,
     SerifVoicevoxAudioSettings, AviUtl2Serif;

type
  TSerifAddMessagesMethod = function(Msgs: TSerifSceneMsgList;
    ForceSend, ContinuousSend, RegisterOnly: Boolean): Boolean of object;

// VOICEVOXの生成結果をプロジェクトデータへ登録する。
// 再編集対象が有効なら既存データとAviUtl2オブジェクトを更新し、
// それ以外はAddMessagesを通じて新規配置または未送信登録する。
function RegisterSerifVoicevoxResult(const ProjectFolder, Text, SpeakerName,
  StyleName, AccentQueryJson: string; const StyleId: Integer;
  const AudioValues: TSerifVoicevoxAudioValues;
  const ReeditTarget: TSerifAviUtl2Selection;
  SceneMsgs, WorkMsgs: TSerifSceneMsgList; Charas: TSerifCharaList;
  Config: TSerifConfigItem; AddMessages: TSerifAddMessagesMethod;
  var ErrorMessage: string; var SavedUnsent: Boolean): Boolean;

implementation

uses System.SysUtils, System.Classes, System.IOUtils, SerifAnalyzer,
     SerifVoicevoxApi, SerifVoicevoxDebugLog;

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

function ProjectFileName(const ProjectFolder,
  RelativeFileName: string): string;
begin
  if RelativeFileName = '' then Exit('');
  if TPath.IsPathRooted(RelativeFileName) then
    Exit(RelativeFileName);
  Result := TPath.Combine(ProjectFolder, RelativeFileName);
end;

procedure DeleteFileSafe(const FileName: string);
begin
  if (FileName = '') or not FileExists(FileName) then Exit;
  try
    DeleteFile(FileName);
  except
    // AviUtl2などが旧ファイルを開いている場合は登録結果を優先する。
  end;
end;

function ResolveReeditMessage(SceneMsgs: TSerifSceneMsgList;
  const ReeditTarget: TSerifAviUtl2Selection; const Layer,
  FrameStart: Integer; out ReeditMsg: TSerifSceneMsgItem;
  out ErrorMessage: string): Boolean;
var
  I: Integer;
  MatchCount: Integer;
begin
  Result := False;
  ReeditMsg := nil;
  if ReeditTarget.UID = '' then
  begin
    ErrorMessage := 'UIDのないセリフオブジェクトは更新できません';
    Exit;
  end;

  MatchCount := 0;
  for I := 0 to SceneMsgs.Count - 1 do
  begin
    if SceneMsgs[I].UID <> ReeditTarget.UID then Continue;
    Inc(MatchCount);
    if (SceneMsgs[I].SerifLayer = Layer) and
       (SceneMsgs[I].FrameStart = FrameStart) then
      ReeditMsg := SceneMsgs[I];
  end;
  if (ReeditMsg = nil) and (MatchCount = 1) then
    ReeditMsg := SceneMsgs[SceneMsgs.IndexOfUID(ReeditTarget.UID)];
  if ReeditMsg = nil then
  begin
    ErrorMessage := '選択中のセリフに対応する内部データを特定できません';
    Exit;
  end;
  Result := True;
end;

function RegisterSerifVoicevoxResult(const ProjectFolder, Text, SpeakerName,
  StyleName, AccentQueryJson: string; const StyleId: Integer;
  const AudioValues: TSerifVoicevoxAudioValues;
  const ReeditTarget: TSerifAviUtl2Selection;
  SceneMsgs, WorkMsgs: TSerifSceneMsgList; Charas: TSerifCharaList;
  Config: TSerifConfigItem; AddMessages: TSerifAddMessagesMethod;
  var ErrorMessage: string; var SavedUnsent: Boolean): Boolean;
var
  ActualWaveLayer: Integer;
  Analyzer: TSerifAnalyzer;
  ErrLine: Integer;
  Files: TStringList;
  FrameEnd: Integer;
  FrameStart: Integer;
  GeneratedFilesOwned: Boolean;
  GeneratedMsg: TSerifSceneMsgItem;
  I: Integer;
  Layer: Integer;
  LabFileName: string;
  NewTextFileName: string;
  NewWaveFileName: string;
  ObjectLabText: string;
  OldTextFileName: string;
  OldWaveFileName: string;
  ReeditMsg: TSerifSceneMsgItem;
  ReeditSelected: Boolean;
  TextFileName: string;
  WaveFileName: string;
begin
  Result := False;
  ErrorMessage := '';
  SavedUnsent := False;
  if ProjectFolder = '' then
  begin
    ErrorMessage := 'セリフプロジェクトが選択されていません';
    Exit;
  end;
  if SceneMsgs = nil then
  begin
    ErrorMessage := '登録先のシーンが選択されていません';
    Exit;
  end;

  ReeditSelected := AviUtl2SerifResolveSelected(ReeditTarget, Layer,
    FrameStart, FrameEnd);
  ReeditMsg := nil;
  if ReeditSelected and not ResolveReeditMessage(SceneMsgs, ReeditTarget,
    Layer, FrameStart, ReeditMsg, ErrorMessage) then Exit;

  if not TSerifVoicevoxApi.CreateInputFiles(Text, SpeakerName, StyleName,
    StyleId, AudioValues, AccentQueryJson, WaveFileName, TextFileName,
    LabFileName, ErrorMessage) then Exit;

  Files := TStringList.Create;
  Analyzer := TSerifAnalyzer.Create;
  GeneratedFilesOwned := False;
  try
    Files.Add(TextFileName);
    Files.Add(WaveFileName);
    Files.Add(LabFileName);
    ErrLine := -1;
    if not Analyzer.Execute(WorkMsgs, Charas, ProjectFolder, Files, Config,
      ErrLine) then
    begin
      ErrorMessage := 'VOICEVOX音声をセリフデータへ登録できませんでした';
      Exit;
    end;
    GeneratedFilesOwned := WorkMsgs.Count > 0;

    if ReeditSelected then
    begin
      if WorkMsgs.Count <> 1 then
      begin
        ErrorMessage := '更新用のVOICEVOX音声を1件に特定できませんでした';
        Exit;
      end;
      GeneratedMsg := WorkMsgs[0];
      OldWaveFileName := ProjectFileName(ProjectFolder,
        ReeditMsg.FileNameWave);
      OldTextFileName := ProjectFileName(ProjectFolder,
        ReeditMsg.FileNameText);
      NewWaveFileName := ProjectFileName(ProjectFolder,
        GeneratedMsg.FileNameWave);
      NewTextFileName := ProjectFileName(ProjectFolder,
        GeneratedMsg.FileNameText);
      if Config.SendLab then
        ObjectLabText := GeneratedMsg.LabStr
      else
        ObjectLabText := '';

      if not AviUtl2SerifUpdateSelected(ReeditTarget,
        ReeditMsg.WaveLayer, OldWaveFileName, NewWaveFileName,
        GeneratedMsg.WaveLength, GeneratedMsg.Voice,
        GeneratedMsg.Chara, GeneratedMsg.Emotion,
        ReeditMsg.Direction, GeneratedMsg.AIUEO,
        ObjectLabText, ActualWaveLayer) then
      begin
        ErrorMessage := '選択中のセリフまたは対応する音声を更新できませんでした';
        Exit;
      end;

      ReeditMsg.FileNameWave := GeneratedMsg.FileNameWave;
      ReeditMsg.FileNameText := GeneratedMsg.FileNameText;
      ReeditMsg.Text := GeneratedMsg.Text;
      ReeditMsg.Voice := GeneratedMsg.Voice;
      ReeditMsg.Chara := GeneratedMsg.Chara;
      ReeditMsg.Keyword := GeneratedMsg.Keyword;
      ReeditMsg.Emotion := GeneratedMsg.Emotion;
      ReeditMsg.AIUEO := GeneratedMsg.AIUEO;
      ReeditMsg.WaveLength := GeneratedMsg.WaveLength;
      ReeditMsg.LabStr := GeneratedMsg.LabStr;
      ReeditMsg.SerifLayer := Layer;
      ReeditMsg.WaveLayer := ActualWaveLayer;

      GeneratedFilesOwned := False;
      if not SameText(OldWaveFileName, NewWaveFileName) then
        DeleteFileSafe(OldWaveFileName);
      if not SameText(OldTextFileName, NewTextFileName) then
        DeleteFileSafe(OldTextFileName);
      Result := True;
      Exit;
    end;

    if not Assigned(AddMessages) then
    begin
      ErrorMessage := 'セリフ配置処理が接続されていません';
      Exit;
    end;
    if not AddMessages(WorkMsgs, True, True, False) then
    begin
      if not AddMessages(WorkMsgs, False, False, True) then
      begin
        ErrorMessage := 'セリフを現在のシーンへ追加できませんでした';
        Exit;
      end;
      SavedUnsent := True;
      VoicevoxDebugLog(
        'VOICEVOX placement failed; registered generated serif as unsent');
    end;
    GeneratedFilesOwned := False;
    Result := True;
  finally
    if GeneratedFilesOwned then
      for I := 0 to WorkMsgs.Count - 1 do
        WorkMsgs[I].DeleteItemFile(ProjectFolder);
    Analyzer.Free;
    Files.Free;
    if FileExists(TextFileName) then DeleteFile(TextFileName);
    if FileExists(WaveFileName) then DeleteFile(WaveFileName);
    if FileExists(LabFileName) then DeleteFile(LabFileName);
    if DirectoryExists(ExtractFileDir(TextFileName)) then
      try
        TDirectory.Delete(ExtractFileDir(TextFileName), False);
      except
        // 登録結果を優先し、一時フォルダの後始末失敗は通知しない。
      end;
  end;
end;

end.
