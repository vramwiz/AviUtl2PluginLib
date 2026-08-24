// AviUtl2プロジェクトに属する音声合成設定の識別子と保存フォルダを管理する。
unit SerifSpeechSynthesisProject;

interface

type
  TSerifSpeechSynthesisSaveAction = (
    sssaNone,
    sssaOverwrite,
    sssaFirstSave,
    sssaSaveAs
  );

// ProjectLoadコールバック開始時に、直前のプロジェクト識別子を引き継がないよう現在値を破棄する。
procedure SerifSpeechSynthesisBeginProjectLoad;
// AviUtl2プロジェクト内の識別子を読み、対応する設定フォルダへ切り替える。
// 識別子がない既存プロジェクトでは新規発行し、旧セリフプロジェクト内の設定を一度だけ移行する。
procedure SerifSpeechSynthesisLoadProject(const ProjectFilePath,
  LegacySerifFolder: string);
// AviUtl2の保存種別を判定し、別名保存では新しい識別子を保存対象プロジェクトへ設定する。
function SerifSpeechSynthesisPrepareSave(const OldProjectFilePath,
  NewProjectFilePath: string; out SourceFolder,
  TargetFolder: string): TSerifSpeechSynthesisSaveAction;
// 保存先を確定し、必要なら旧識別子の設定を新識別子へ複製してメタデータを更新する。
procedure SerifSpeechSynthesisCompleteSave(
  const Action: TSerifSpeechSynthesisSaveAction;
  const SourceFolder, TargetFolder, ProjectFilePath: string);
// 現在のAviUtl2プロジェクトに対応する音声合成設定フォルダを返す。
function SerifSpeechSynthesisCurrentFolder: string;

implementation

uses
  System.Classes, System.IniFiles, System.IOUtils, System.SysUtils,
  AppFolderUtils, AviUtl2PluginProject;

const
  PROJECT_PARAM_KEY: AnsiString = 'SpeechSynthesisProjectID';
  PROJECT_INFO_FILE = 'Project.ini';
  SHORTCUTS_FILE = 'Shortcuts.ini';
  VOICEVOX_FILE = 'VOICEVOX.ini';
  LEGACY_SHORTCUTS_FILE = 'VoicevoxShortcuts.ini';
  LEGACY_VOICEVOX_FILE = 'VoicevoxSettings.ini';

var
  GCurrentProjectID: string;
  GCurrentFolder: string;

function IsProjectIDText(const Value: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (Length(Value) <> 38) or (Value[1] <> '{') or
    (Value[38] <> '}') then Exit;
  for I := 2 to 37 do
    if I in [10, 15, 20, 25] then
    begin
      if Value[I] <> '-' then Exit;
    end
    else if not CharInSet(Value[I], ['0'..'9', 'A'..'F', 'a'..'f']) then
      Exit;
  Result := True;
end;

function NormalizeProjectID(const Value: string): string;
var
  ID: TGUID;
  Text: string;
begin
  Result := '';
  Text := Trim(Value);
  if not IsProjectIDText(Text) then Exit;
  ID := StringToGUID(Text);
  Result := GUIDToString(ID);
end;

function CreateProjectID: string;
var
  ID: TGUID;
begin
  CreateGUID(ID);
  Result := GUIDToString(ID);
end;

function ProjectFolder(const ProjectID: string): string;
var
  FolderName: string;
begin
  Result := '';
  FolderName := StringReplace(StringReplace(ProjectID, '{', '', []),
    '}', '', []);
  if FolderName = '' then Exit;
  Result := IncludeTrailingPathDelimiter(
    TPath.Combine(GetAppFolder('Serif\SpeechSynthesis'), FolderName));
end;

procedure CopyFileIfMissing(const SourceFile, TargetFile: string);
begin
  if not TFile.Exists(SourceFile) or TFile.Exists(TargetFile) then Exit;
  TDirectory.CreateDirectory(TPath.GetDirectoryName(TargetFile));
  TFile.Copy(SourceFile, TargetFile, False);
end;

procedure MigrateLegacySettings(const LegacySerifFolder,
  TargetFolder: string);
begin
  if (Trim(LegacySerifFolder) = '') or (Trim(TargetFolder) = '') then Exit;
  CopyFileIfMissing(
    TPath.Combine(LegacySerifFolder, LEGACY_SHORTCUTS_FILE),
    TPath.Combine(TargetFolder, SHORTCUTS_FILE));
  CopyFileIfMissing(
    TPath.Combine(LegacySerifFolder, LEGACY_VOICEVOX_FILE),
    TPath.Combine(TargetFolder, VOICEVOX_FILE));
end;

procedure WriteProjectInfo(const Folder, ProjectID,
  ProjectFilePath: string);
var
  Ini: TMemIniFile;
begin
  if (Trim(Folder) = '') or (Trim(ProjectID) = '') then Exit;
  TDirectory.CreateDirectory(Folder);
  Ini := TMemIniFile.Create(TPath.Combine(Folder, PROJECT_INFO_FILE),
    TEncoding.UTF8);
  try
    Ini.WriteString('Project', 'ID', ProjectID);
    Ini.WriteString('Project', 'FilePath', ProjectFilePath);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

procedure CopySettingsFolder(const SourceFolder, TargetFolder: string);
var
  FileName: string;
  TargetFileName: string;
begin
  if (Trim(SourceFolder) = '') or (Trim(TargetFolder) = '') or
    SameText(ExcludeTrailingPathDelimiter(SourceFolder),
      ExcludeTrailingPathDelimiter(TargetFolder)) or
    not TDirectory.Exists(SourceFolder) then Exit;
  TDirectory.CreateDirectory(TargetFolder);
  for FileName in TDirectory.GetFiles(SourceFolder, '*.ini') do
  begin
    if SameText(TPath.GetFileName(FileName), PROJECT_INFO_FILE) then Continue;
    TargetFileName := TPath.Combine(TargetFolder, TPath.GetFileName(FileName));
    TFile.Copy(FileName, TargetFileName, True);
  end;
end;

procedure SetCurrentProject(const ProjectID: string);
begin
  GCurrentProjectID := NormalizeProjectID(ProjectID);
  GCurrentFolder := ProjectFolder(GCurrentProjectID);
end;

procedure SerifSpeechSynthesisBeginProjectLoad;
begin
  GCurrentProjectID := '';
  GCurrentFolder := '';
end;

procedure SerifSpeechSynthesisLoadProject(const ProjectFilePath,
  LegacySerifFolder: string);
var
  FirstAssociation: Boolean;
  ProjectID: string;
begin
  ProjectID := NormalizeProjectID(string(AviUtl2GetProjectString(
    PROJECT_PARAM_KEY)));
  if ProjectID = '' then
  begin
    ProjectID := CreateProjectID;
    AviUtl2SetProjectString(PROJECT_PARAM_KEY, AnsiString(ProjectID));
  end;
  SetCurrentProject(ProjectID);
  try
    FirstAssociation := not TFile.Exists(
      TPath.Combine(GCurrentFolder, PROJECT_INFO_FILE));
    if FirstAssociation then
      MigrateLegacySettings(LegacySerifFolder, GCurrentFolder);
    if Trim(ProjectFilePath) <> '' then
      WriteProjectInfo(GCurrentFolder, GCurrentProjectID, ProjectFilePath);
  except
    // 設定領域が一時的に利用できなくても、AviUtl2プロジェクトの読込は継続する。
  end;
end;

function SerifSpeechSynthesisPrepareSave(const OldProjectFilePath,
  NewProjectFilePath: string; out SourceFolder,
  TargetFolder: string): TSerifSpeechSynthesisSaveAction;
var
  NewProjectID: string;
begin
  Result := sssaNone;
  SourceFolder := GCurrentFolder;
  TargetFolder := GCurrentFolder;
  if Trim(NewProjectFilePath) = '' then Exit;

  if GCurrentProjectID = '' then
  begin
    NewProjectID := CreateProjectID;
    SetCurrentProject(NewProjectID);
    SourceFolder := '';
    TargetFolder := GCurrentFolder;
    Result := sssaFirstSave;
  end
  else if Trim(OldProjectFilePath) = '' then
    Result := sssaFirstSave
  else if not SameText(Trim(OldProjectFilePath),
    Trim(NewProjectFilePath)) then
  begin
    NewProjectID := CreateProjectID;
    SetCurrentProject(NewProjectID);
    TargetFolder := GCurrentFolder;
    Result := sssaSaveAs;
  end
  else
    Result := sssaOverwrite;

  AviUtl2SetProjectString(PROJECT_PARAM_KEY,
    AnsiString(GCurrentProjectID));
end;

procedure SerifSpeechSynthesisCompleteSave(
  const Action: TSerifSpeechSynthesisSaveAction;
  const SourceFolder, TargetFolder, ProjectFilePath: string);
begin
  if Action = sssaNone then Exit;
  try
    if Action = sssaSaveAs then
      CopySettingsFolder(SourceFolder, TargetFolder);
    WriteProjectInfo(TargetFolder, GCurrentProjectID, ProjectFilePath);
  except
    // 外部設定の保存失敗をAviUtl2の保存完了後のUIイベントへ伝播させない。
  end;
end;

function SerifSpeechSynthesisCurrentFolder: string;
begin
  Result := GCurrentFolder;
end;

end.
