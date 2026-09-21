unit SerifProject;

interface

uses
  Winapi.Windows, System.Classes, System.SysUtils, RTTI, RTTIPersistent,ProjectManager,
  System.IOUtils,System.Types;

type
  TSerifProjectItem = class(TProjectInfo)
  private
  published
  end;

function CreateAutomaticSerifProjectFolder: string;
function InitializeEmptySerifProjectFolder(const Folder: string): Boolean;
function CreateTemporarySerifProjectFolder(out LockStream: TFileStream): string;
procedure CleanupOrphanTemporarySerifProjects;
function IsTemporarySerifProjectFolder(const Folder: string): Boolean;
function PromoteTemporarySerifProject(const SourceFolder, DestinationFolder: string): Boolean;
procedure DeleteTemporarySerifProjectFolder(const Folder: string);
// 別フォルダーへ保存する際に、台本本文を除くプロジェクト設定を引き継ぐ。
function CopySerifProjectSettings(const SourceFolder, DestinationFolder: string): Boolean;

type
  TSerifProjectList = class(TProjectManager<TSerifProjectItem>)
  private
  public
    // プロジェクト追加
    function ProjectAdd: TSerifProjectItem;
    // プロジェクトをコピー
    function ProjectCopy(const IndexTo,IndexFrom : Integer) : Boolean;override;
  end;

implementation

uses AppFolderUtils, System.StrUtils, SerifSceneList, SerifCharaList,
  SerifWatcherList, SerifConfig;

const
  SERIF_TEMP_LOCK_FILE = '.syncroh2.lock';

function TemporarySerifProjectRoot: string;
begin
  Result := IncludeTrailingPathDelimiter(
    TPath.Combine(TPath.GetTempPath, TPath.Combine('Syncroh2', 'SerifWork')));
end;

function UniqueFolderName: string;
var
  ID: TGUID;
begin
  CreateGUID(ID);
  Result := FormatDateTime('yyyymmddhhnnsszzz', Now) + '_' +
    StringReplace(GUIDToString(ID), '-', '', [rfReplaceAll]).Substring(1, 8);
end;

function CreateAutomaticSerifProjectFolder: string;
var
  Root: string;
begin
  Result := '';
  try
    Root := GetAppFolder('Serif');
    if Root = '' then Exit;
    Result := IncludeTrailingPathDelimiter(TPath.Combine(Root, UniqueFolderName));
    TDirectory.CreateDirectory(Result);
  except
    Result := '';
  end;
end;

function InitializeEmptySerifProjectFolder(const Folder: string): Boolean;
var
  Charas: TSerifCharaList;
  Config: TSerifConfigItem;
  Index: Integer;
  Scene: TSerifSceneItem;
  Scenes: TSerifSceneList;
  Watcher: TSerifWatcherItem;
  Watchers: TSerifWatcherList;
begin
  Result := False;
  if Trim(Folder) = '' then Exit;
  Scenes := nil;
  Charas := nil;
  Watchers := nil;
  Config := nil;
  try
    TDirectory.CreateDirectory(Folder);

    Scenes := TSerifSceneList.Create;
    Scenes.Filename := TPath.Combine(Folder, 'Scene.ini');
    for Index := 0 to 99 do
    begin
      Scene := Scenes.AddNew;
      if Index = 0 then
        Scene.Name := 'Root'
      else
        Scene.Name := Format('%.2d', [Index - 1]);
    end;
    Scenes.SaveToFile;

    Charas := TSerifCharaList.Create;
    Charas.Filename := TPath.Combine(Folder, 'Charas.ini');
    Charas.SaveToFile;

    Watchers := TSerifWatcherList.Create;
    Watchers.Filename := TPath.Combine(Folder, 'Watchers.ini');
    Watcher := Watchers.AddNew;
    Watcher.Name := '音声合成ソフト';
    Watchers.SaveToFile;

    Config := TSerifConfigItem.Create;
    Config.Filename := TPath.Combine(Folder, 'Config.ini');
    Config.SaveToFile;
    Result := True;
  except
    Result := False;
  end;
  Config.Free;
  Watchers.Free;
  Charas.Free;
  Scenes.Free;
end;

function IsTemporarySerifProjectFolder(const Folder: string): Boolean;
var
  FullFolder: string;
  Root: string;
begin
  Result := False;
  if Trim(Folder) = '' then Exit;
  try
    FullFolder := IncludeTrailingPathDelimiter(TPath.GetFullPath(Folder));
    Root := IncludeTrailingPathDelimiter(TPath.GetFullPath(TemporarySerifProjectRoot));
    Result := StartsText(Root, FullFolder) and not SameText(Root, FullFolder);
  except
    Result := False;
  end;
end;

procedure CleanupOrphanTemporarySerifProjects;
var
  Folder: string;
  LockFile: string;
  LockHandle: THandle;
begin
  try
    if not TDirectory.Exists(TemporarySerifProjectRoot) then Exit;
    for Folder in TDirectory.GetDirectories(TemporarySerifProjectRoot) do
    begin
      try
        LockFile := TPath.Combine(Folder, SERIF_TEMP_LOCK_FILE);
        if TFile.Exists(LockFile) then
        begin
          // 使用中のロックは正常な状態なので、例外を発生させず戻り値で判定する。
          LockHandle := FileOpen(LockFile, fmOpenReadWrite or fmShareExclusive);
          if LockHandle = THandle(-1) then
            Continue;
          FileClose(LockHandle);
        end;
        TDirectory.Delete(Folder, True);
      except
        // 他のAviUtl2がロックしている作業台本は削除しない。
      end;
    end;
  except
    // 一時領域の清掃失敗は通常の台本操作を妨げない。
  end;
end;

function CreateTemporarySerifProjectFolder(out LockStream: TFileStream): string;
var
  LockFile: string;
begin
  Result := '';
  LockStream := nil;
  try
    CleanupOrphanTemporarySerifProjects;
    TDirectory.CreateDirectory(TemporarySerifProjectRoot);
    Result := IncludeTrailingPathDelimiter(
      TPath.Combine(TemporarySerifProjectRoot, UniqueFolderName));
    TDirectory.CreateDirectory(Result);
    LockFile := TPath.Combine(Result, SERIF_TEMP_LOCK_FILE);
    LockStream := TFileStream.Create(LockFile, fmCreate or fmShareExclusive);
  except
    LockStream.Free;
    LockStream := nil;
    Result := '';
  end;
end;

procedure CopyFolderContents(const SourceFolder, DestinationFolder: string);
var
  DirectoryName: string;
  FileName: string;
  DestinationName: string;
begin
  TDirectory.CreateDirectory(DestinationFolder);
  for FileName in TDirectory.GetFiles(SourceFolder) do
  begin
    if SameText(TPath.GetFileName(FileName), SERIF_TEMP_LOCK_FILE) then Continue;
    DestinationName := TPath.Combine(DestinationFolder, TPath.GetFileName(FileName));
    TFile.Copy(FileName, DestinationName, True);
  end;
  for DirectoryName in TDirectory.GetDirectories(SourceFolder) do
  begin
    DestinationName := TPath.Combine(DestinationFolder, TPath.GetFileName(DirectoryName));
    CopyFolderContents(DirectoryName, DestinationName);
  end;
end;

function PromoteTemporarySerifProject(const SourceFolder,
  DestinationFolder: string): Boolean;
begin
  Result := False;
  if not IsTemporarySerifProjectFolder(SourceFolder) then Exit;
  if Trim(DestinationFolder) = '' then Exit;
  try
    CopyFolderContents(SourceFolder, DestinationFolder);
    Result := True;
  except
    Result := False;
  end;
end;

procedure DeleteTemporarySerifProjectFolder(const Folder: string);
begin
  if not IsTemporarySerifProjectFolder(Folder) then Exit;
  try
    if TDirectory.Exists(Folder) then
      TDirectory.Delete(Folder, True);
  except
    // 残った作業台本は次回起動時の清掃対象になる。
  end;
end;

{ TSerifProjectList }


function CopyProjectFile(const FolderTo, FolderFrom, FileName: string): Boolean;
var
  Src, Dst: string;
begin
  Result := False;

  try
    // 引数チェック
    if (FolderTo = '') or (FolderFrom = '') or (FileName = '') then
      Exit;

    // フォルダチェック
    if not TDirectory.Exists(FolderFrom) then
      Exit;

    // 先フォルダが無ければ作成（必要に応じて）
    if not TDirectory.Exists(FolderTo) then
      TDirectory.CreateDirectory(FolderTo);

    // パス生成
    Src := TPath.Combine(FolderFrom, FileName);
    Dst := TPath.Combine(FolderTo,   FileName);

    // 元ファイル存在チェック
    if not TFile.Exists(Src) then
      Exit;

    // コピー（上書き許可）
    TFile.Copy(Src, Dst, True);

    Result := True;
  except
    // 例外は False として扱う
    Result := False;
  end;
end;

function CopySerifProjectSettings(const SourceFolder,
  DestinationFolder: string): Boolean;
begin
  // Scene.ini は台本本文なのでコピーしない。配役・監視・表示設定だけを
  // 新しい AviUtl2 プロジェクト用のフォルダーへ引き継ぐ。
  Result := CopyProjectFile(DestinationFolder, SourceFolder, 'Charas.ini');
  if CopyProjectFile(DestinationFolder, SourceFolder, 'Styles.ini') then
    Result := True;
  if CopyProjectFile(DestinationFolder, SourceFolder, 'Watchers.ini') then
    Result := True;
  if CopyProjectFile(DestinationFolder, SourceFolder, 'Config.ini') then
    Result := True;
end;



function TSerifProjectList.ProjectAdd: TSerifProjectItem;
begin
  Result := inherited ProjectAdd;
end;

function TSerifProjectList.ProjectCopy(const IndexTo,
  IndexFrom: Integer): Boolean;
var
  ffolder,FolderTo,folderFrom : string;
begin
  inherited;
  ffolder := IncludeTrailingPathDelimiter(ProjectFolder);

  folderFrom := ffolder + IncludeTrailingPathDelimiter(Projects[IndexFrom].FolderName);
  folderTo   := ffolder + IncludeTrailingPathDelimiter(Projects[IndexTo].FolderName);

  CopyProjectFile(folderTo, folderFrom ,'Charas.ini');
  CopyProjectFile(folderTo, folderFrom ,'Watchers.ini');
  CopyProjectFile(folderTo, folderFrom ,'Config.ini');
  CopyProjectFile(folderTo, folderFrom ,'Styles.ini');
  Result := True;
end;

end.
