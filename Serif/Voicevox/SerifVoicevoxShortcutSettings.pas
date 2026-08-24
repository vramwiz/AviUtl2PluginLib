// VOICEVOX話者ショートカット10枠をセリフプロジェクト単位で保存・復元する。
unit SerifVoicevoxShortcutSettings;

interface

type
  // 1つのCtrl+数字へ割り当てたエンジン、話者UUID、VOICEVOX style ID。
  TSerifVoicevoxShortcutAssignment = record
    // 話者名がエンジン間で重複しても割り当てを区別する、固定の内部エンジンID。
    EngineID: string;
    // 話者カタログを再読込しても同じ話者を解決するためのUUID。空文字は未設定。
    SpeakerUUID: string;
    // VOICEVOX Engineのstyle ID。-1は未設定。
    StyleId: Integer;
  end;

  TSerifVoicevoxShortcutSettings = class
  private const
    FILE_NAME = 'Shortcuts.ini';
    VOICEVOX_ENGINE_ID = 'VOICEVOX';
    ITEM_COUNT = 10;
  private
    FAssignments: array[0..ITEM_COUNT - 1] of
      TSerifVoicevoxShortcutAssignment;
    FDirty: Boolean;
    FFileName: string;
    procedure Clear;
    procedure Load;
    class function SectionName(const Index: Integer): string; static;
  public
    // 10枠を未設定状態で初期化する。保存先はOpenProjectまで持たない。
    constructor Create;
    // 保存待ちの割り当てをINIへ書き出してから破棄する。
    destructor Destroy; override;
    // 指定枠の保存値を返す。未設定または範囲外ならStyleId=-1を返す。
    function GetAssignment(
      const Index: Integer): TSerifVoicevoxShortcutAssignment;
    // 旧プロジェクトを保存してから指定フォルダの割り当てへ切り替える。
    procedure OpenProject(const ProjectFolder: string);
    // 変更がある場合だけ10枠をUTF-8のINIへ保存する。
    procedure Save;
    // 指定枠を更新し、保存待ち状態にする。
    procedure SetAssignment(const Index: Integer;
      const Assignment: TSerifVoicevoxShortcutAssignment);
  end;

implementation

uses
  System.IniFiles, System.IOUtils, System.SysUtils, System.Classes;

constructor TSerifVoicevoxShortcutSettings.Create;
begin
  inherited;
  Clear;
end;

destructor TSerifVoicevoxShortcutSettings.Destroy;
begin
  Save;
  inherited;
end;

procedure TSerifVoicevoxShortcutSettings.Clear;
var
  I: Integer;
begin
  for I := 0 to ITEM_COUNT - 1 do
  begin
    FAssignments[I].EngineID := '';
    FAssignments[I].SpeakerUUID := '';
    FAssignments[I].StyleId := -1;
  end;
end;

function TSerifVoicevoxShortcutSettings.GetAssignment(
  const Index: Integer): TSerifVoicevoxShortcutAssignment;
begin
  Result.EngineID := '';
  Result.SpeakerUUID := '';
  Result.StyleId := -1;
  if (Index >= 0) and (Index < ITEM_COUNT) then
    Result := FAssignments[Index];
end;

procedure TSerifVoicevoxShortcutSettings.Load;
var
  I: Integer;
  Ini: TMemIniFile;
  Section: string;
begin
  Clear;
  FDirty := False;
  if (FFileName = '') or not TFile.Exists(FFileName) then Exit;
  Ini := TMemIniFile.Create(FFileName, TEncoding.UTF8);
  try
    for I := 0 to ITEM_COUNT - 1 do
    begin
      Section := SectionName(I);
      FAssignments[I].EngineID := Trim(
        Ini.ReadString(Section, 'EngineID', ''));
      FAssignments[I].SpeakerUUID := Trim(
        Ini.ReadString(Section, 'SpeakerUUID', ''));
      FAssignments[I].StyleId := Ini.ReadInteger(Section, 'StyleId', -1);
      // 旧VoicevoxShortcuts.iniから移行した値はVOICEVOXとして扱う。
      if (FAssignments[I].EngineID = '') and
        (FAssignments[I].SpeakerUUID <> '') and
        (FAssignments[I].StyleId >= 0) then
      begin
        FAssignments[I].EngineID := VOICEVOX_ENGINE_ID;
        FDirty := True;
      end;
    end;
  finally
    Ini.Free;
  end;
end;

procedure TSerifVoicevoxShortcutSettings.OpenProject(
  const ProjectFolder: string);
begin
  Save;
  Clear;
  FDirty := False;
  FFileName := '';
  if Trim(ProjectFolder) <> '' then
    FFileName := TPath.Combine(ProjectFolder, FILE_NAME);
  Load;
end;

procedure TSerifVoicevoxShortcutSettings.Save;
var
  I: Integer;
  Ini: TMemIniFile;
  Section: string;
  Sections: TStringList;
begin
  if not FDirty or (FFileName = '') then Exit;
  try
    TDirectory.CreateDirectory(TPath.GetDirectoryName(FFileName));
    Sections := TStringList.Create;
    Ini := TMemIniFile.Create(FFileName, TEncoding.UTF8);
    try
      Ini.ReadSections(Sections);
      for Section in Sections do Ini.EraseSection(Section);
      for I := 0 to ITEM_COUNT - 1 do
      begin
        Section := SectionName(I);
        Ini.WriteString(Section, 'EngineID', FAssignments[I].EngineID);
        Ini.WriteString(Section, 'SpeakerUUID',
          FAssignments[I].SpeakerUUID);
        Ini.WriteInteger(Section, 'StyleId', FAssignments[I].StyleId);
      end;
      Ini.UpdateFile;
      FDirty := False;
    finally
      Ini.Free;
      Sections.Free;
    end;
  except
    // プロジェクト切り替えまたは終了時に再試行できるよう変更状態を保持する。
  end;
end;

class function TSerifVoicevoxShortcutSettings.SectionName(
  const Index: Integer): string;
begin
  if Index = ITEM_COUNT - 1 then
    Result := 'Shortcut.0'
  else
    Result := 'Shortcut.' + IntToStr(Index + 1);
end;

procedure TSerifVoicevoxShortcutSettings.SetAssignment(
  const Index: Integer;
  const Assignment: TSerifVoicevoxShortcutAssignment);
begin
  if (Index < 0) or (Index >= ITEM_COUNT) then Exit;
  if SameText(FAssignments[Index].EngineID, Assignment.EngineID) and
    SameText(FAssignments[Index].SpeakerUUID,
    Assignment.SpeakerUUID) and
    (FAssignments[Index].StyleId = Assignment.StyleId) then Exit;
  FAssignments[Index] := Assignment;
  FDirty := True;
end;

end.
