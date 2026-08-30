unit SerifProjectLifecycle;

interface

uses SerifProject;

// 現在フォルダーが利用不能な場合に恒久的な自動プロジェクトフォルダーを作る。
// 呼出側はOldTemporaryFolderを閉じた後に削除し、NewFolderを開く。
function PrepareAutomaticSerifProject(const CurrentFolder: string;
  out OldTemporaryFolder, NewFolder: string): Boolean;

// 保存先フォルダーをプロジェクト一覧へ同期し、表示名をAviUtl2ファイル名へ揃える。
procedure RegisterAutomaticSerifProject(Projects: TSerifProjectList;
  const Folder, ProjectFilePath: string);

// 一時プロジェクトの内容を正式保存先へ昇格する。
function PromoteAutomaticSerifProject(const SourceFolder,
  DestinationFolder: string): Boolean;

implementation

uses System.SysUtils, System.IOUtils;

function PrepareAutomaticSerifProject(const CurrentFolder: string;
  out OldTemporaryFolder, NewFolder: string): Boolean;
begin
  OldTemporaryFolder := '';
  NewFolder := '';
  if IsTemporarySerifProjectFolder(CurrentFolder) then
    OldTemporaryFolder := CurrentFolder;
  NewFolder := CreateAutomaticSerifProjectFolder;
  Result := NewFolder <> '';
end;

procedure RegisterAutomaticSerifProject(Projects: TSerifProjectList;
  const Folder, ProjectFilePath: string);
var
  FolderName: string;
  Index: Integer;
begin
  FolderName := TPath.GetFileName(ExcludeTrailingPathDelimiter(Folder));
  Projects.SyncProjectFolders;
  Index := Projects.IndexOfFolder(FolderName);
  if Index >= 0 then
    Projects[Index].ProjectName :=
      TPath.GetFileNameWithoutExtension(ProjectFilePath);
  Projects.SaveToFile;
end;

function PromoteAutomaticSerifProject(const SourceFolder,
  DestinationFolder: string): Boolean;
begin
  Result := PromoteTemporarySerifProject(SourceFolder, DestinationFolder);
end;

end.
