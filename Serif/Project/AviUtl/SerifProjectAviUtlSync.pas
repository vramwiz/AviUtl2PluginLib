unit SerifProjectAviUtlSync;

interface

type
  TEnsureSerifProjectMethod = function: Boolean of object;
  TOpenSerifProjectMethod = procedure(Folder: string) of object;
  TApplySerifSceneMethod = procedure(SceneID: Integer) of object;

// AviUtl2プロジェクトへ関連付けられたセリフフォルダーを取得する。
function ReadSerifAviUtlProjectFolder: string;

// AviUtl2プロジェクトへ現在のセリフフォルダーを関連付ける。
procedure WriteSerifAviUtlProjectFolder(const Folder: string);

// 関連フォルダーを開いた後、AviUtl2の現在シーンをセリフ画面へ適用する。
function SyncSerifAviUtlProject(var SelectedFolder: string;
  var SceneID: Integer; EnsureProject: TEnsureSerifProjectMethod;
  OpenProject: TOpenSerifProjectMethod;
  ApplyScene: TApplySerifSceneMethod): Boolean;

// AviUtl2から通知されたシーンと関連フォルダーをセリフ画面へ適用する。
function SyncSerifAviUtlScene(const RequestedSceneID: Integer;
  var SelectedFolder: string; var SceneID: Integer;
  EnsureProject: TEnsureSerifProjectMethod;
  OpenProject: TOpenSerifProjectMethod;
  ApplyScene: TApplySerifSceneMethod): Boolean;

implementation

uses AviUtl2PluginProject, AviUtl2PluginScene, SerifAviUtlProfile;

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

function ReadSerifAviUtlProjectFolder: string;
var
  Profile: TSerifAviUtlProfile;
begin
  Profile := CurrentSerifAviUtlProfile;
  Result := string(AviUtl2GetProjectString(Profile.ProjectFolderKey));
end;

procedure WriteSerifAviUtlProjectFolder(const Folder: string);
var
  Profile: TSerifAviUtlProfile;
begin
  Profile := CurrentSerifAviUtlProfile;
  AviUtl2SetProjectString(Profile.ProjectFolderKey, AnsiString(Folder));
end;

function ResolveProjectFolder(var SelectedFolder: string;
  EnsureProject: TEnsureSerifProjectMethod; out Folder: string): Boolean;
begin
  Result := False;
  Folder := ReadSerifAviUtlProjectFolder;
  if Folder = '' then
  begin
    if not Assigned(EnsureProject) or not EnsureProject then Exit;
    Folder := SelectedFolder;
  end;
  Result := Folder <> '';
end;

function SyncSerifAviUtlProject(var SelectedFolder: string;
  var SceneID: Integer; EnsureProject: TEnsureSerifProjectMethod;
  OpenProject: TOpenSerifProjectMethod;
  ApplyScene: TApplySerifSceneMethod): Boolean;
var
  Folder: string;
  CurrentSceneID: Integer;
begin
  Result := False;
  if not ResolveProjectFolder(SelectedFolder, EnsureProject, Folder) then Exit;
  if Assigned(OpenProject) then OpenProject(Folder);

  CurrentSceneID := AviUtl2SceneGetID;
  if CurrentSceneID >= 0 then SceneID := CurrentSceneID;
  if (SceneID >= 0) and Assigned(ApplyScene) then ApplyScene(SceneID);
  Result := True;
end;

function SyncSerifAviUtlScene(const RequestedSceneID: Integer;
  var SelectedFolder: string; var SceneID: Integer;
  EnsureProject: TEnsureSerifProjectMethod;
  OpenProject: TOpenSerifProjectMethod;
  ApplyScene: TApplySerifSceneMethod): Boolean;
var
  Folder: string;
begin
  Result := False;
  SceneID := RequestedSceneID;
  if not ResolveProjectFolder(SelectedFolder, EnsureProject, Folder) then Exit;
  if Assigned(OpenProject) then OpenProject(Folder);
  if Assigned(ApplyScene) then ApplyScene(SceneID);
  Result := True;
end;

end.
