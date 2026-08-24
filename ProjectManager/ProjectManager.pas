unit ProjectManager;

interface

uses
  System.Classes, System.SysUtils, RTTI, RTTIPersistentIni;

type
  TProjectInfo = class(TRTTIPersistentIni)
  private
    FProjectName : string;     // プロジェクトの名称
    FFolderName  : string;     // プロジェクトのフォルダ名
  protected
  published
    property ProjectName: string read FProjectName write FProjectName;
    property FolderName: string read FFolderName write FFolderName;
  end;

  // <T: TProjectInfo, constructor> =class(TRTTIPersistentIniList<T>)
  // = class(TRTTIPersistentIniList<TProjectInfo>)
  TProjectManager <T: TProjectInfo, constructor> =class(TRTTIPersistentIniList<T>)
  private
    FProjectFolder : string;
    FProjectFile   : string;
    // フォルダ名を年月日時分秒ミリ秒の形式で生成するプライベート関数
    function GenerateUniqueFolderName: string;
    function GetProjects(Index: Integer): T;
  public
    constructor Create(const ProjectFolder, ProjectFile: string);
    destructor Destroy; override;

    function IndexOfFolder(const Folder : string) : Integer;
    // プロジェクト追加
    function ProjectAdd: T;
    // プロジェクトに挿入
    function ProjectInsert(const Index: Integer): T;
    // プロジェクト削除
    function ProjectDelete(const Index: Integer): Boolean;
    // プロジェクトをコピー
    function ProjectCopy(const IndexTo,IndexFrom : Integer) : Boolean;virtual;
    // プロジェクトとフォルダの同期を取る
    procedure SyncProjectFolders;
    // プロジェクトのフルパスを返す
    function GetAbsoluteFolderByIndex(const Index: Integer): string;
    property Projects[Index : Integer] : T read GetProjects;default;
    property ProjectFolder : string read FProjectFolder;
  end;

implementation

uses System.IOUtils,System.Types;

{ TProjectManager }

constructor TProjectManager<T>.Create(const ProjectFolder, ProjectFile: string);
var
  s: string;
begin
  inherited Create;
  // フォルダ名の末尾に '\' がない場合は追加
  FProjectFolder := ProjectFolder;
  if not FProjectFolder.EndsWith('\') then
    FProjectFolder := FProjectFolder + '\';

  FProjectFile := ProjectFile;

  // フォルダ名とファイル名を結合して完全なファイルパスを作成
  s := FProjectFolder + FProjectFile;

  // Filenameに完全なファイルパスを設定
  Filename := s;

  // プロジェクトリストをファイルから読み込む
  LoadFromFile();
end;


destructor TProjectManager<T>.Destroy;
begin
  inherited Destroy;
end;

function TProjectManager<T>.ProjectAdd: T;
var
  NewProject: T;
  FolderPath,FolderName: string;
begin
  // 新しいフォルダ名を生成
  FolderName := GenerateUniqueFolderName;

  // フォルダの絶対パスを作成
  FolderPath := FProjectFolder + FolderName;

  // フォルダが存在しない場合、生成
  if not DirectoryExists(FolderPath) then
    CreateDir(FolderPath);

  // プロジェクト情報を作成
  NewProject := AddNew();
  NewProject.FolderName := FolderName;

  // 追加したプロジェクトオブジェクトを返す
  Result := NewProject;
end;

function TProjectManager<T>.ProjectInsert(const Index: Integer): T;
var
  NewProject: T;
  FolderPath,FolderName: string;
begin

  // 新しいフォルダ名を生成
  FolderName := GenerateUniqueFolderName;

  // フォルダの絶対パスを作成
  FolderPath := FProjectFolder + FolderName;

  // フォルダが存在しない場合、生成
  if not DirectoryExists(FolderPath) then
    CreateDir(FolderPath);

  // 新しいプロジェクト情報を作成
  NewProject := InsertNew(Index);
  NewProject.FolderName := FolderName;

  // 追加したプロジェクトオブジェクトを返す
  Result := NewProject;
end;


procedure TProjectManager<T>.SyncProjectFolders;
var
  i, j      : Integer;
  FolderPath: string;
  FolderName: string;
  Dirs      : TStringDynArray;
  Info      : TProjectInfo;
begin
  // -----------------------------
  // ① プロジェクト → フォルダ の不整合を削除
  // -----------------------------
  i := Count - 1;
  while i >= 0 do
  begin
    Info := Items[i];

    // フォルダ名が空 → 削除
    if Info.FolderName = '' then
    begin
      Delete(i);
      Dec(i);
      Continue;
    end;

    // フルパス取得
    FolderPath := TPath.Combine(ProjectFolder, Info.FolderName);

    // フォルダが存在しない → 削除
    if not TDirectory.Exists(FolderPath) then
    begin
      Delete(i);
      Dec(i);
      Continue;
    end;

    Dec(i);
  end;

  // -----------------------------
  // ② フォルダ → プロジェクト の不足分を追加
  // -----------------------------
  Dirs := TDirectory.GetDirectories(ProjectFolder);

  for FolderPath in Dirs do
  begin
    // フォルダ名部分だけ取り出す
    FolderName := TPath.GetFileName(FolderPath);
    if FolderName = '' then
      Continue;

    // すでに同じ FolderName のプロジェクトがあるかチェック
    j := IndexOfFolder(FolderName);
    // なければ新規プロジェクトとして追加
    if j = -1 then
    begin
      Info := AddNew;
      Info.FolderName := FolderName;
      Info.ProjectName := FolderName;
    end;
  end;
end;

function TProjectManager<T>.ProjectDelete(const Index: Integer): Boolean;
var
  FolderPath: string;
begin
  Result := False;

  // インデックスが範囲内であるか確認
  if (Index < 0) or (Index >= Count) then
    Exit;

  // 削除するプロジェクトのフォルダパス（絶対パス）を取得
  FolderPath := GetAbsoluteFolderByIndex(Index);

  // フォルダが存在する場合、削除（中身ごと削除）
  if TDirectory.Exists(FolderPath) then
  begin
    try
      TDirectory.Delete(FolderPath, True);
    except
      Exit; // 削除失敗時は False のまま抜ける
    end;
  end;

  // リストから削除
  Delete(Index);
  Result := True;
end;

function TProjectManager<T>.ProjectCopy(const IndexTo,  IndexFrom: Integer): Boolean;
begin
  Result := True;
end;


// プライベート関数：年月日時分秒ミリ秒で一意のフォルダ名を生成
function TProjectManager<T>.GenerateUniqueFolderName: string;
var
  CurrentDateTime: TDateTime;
  DateTimeStr: string;
begin
  // 現在の日時を取得
  CurrentDateTime := Now;

  // 年月日時分秒ミリ秒の形式にフォーマット
  DateTimeStr := FormatDateTime('yyyymmddhhnnsszzz', CurrentDateTime);

  Result := DateTimeStr;
end;



function TProjectManager<T>.GetAbsoluteFolderByIndex(const Index: Integer): string;
begin
  Result := FProjectFolder + Items[Index].FolderName;
end;

function TProjectManager<T>.GetProjects(Index: Integer): T;
begin
  Result := inherited Items[Index];
end;

function TProjectManager<T>.IndexOfFolder(const Folder: string): Integer;
var
  i : Integer;
begin
  Result := -1;
  for i := 0 to Count-1 do begin
    if Projects[i].FFolderName =  Folder then Exit(i);
  end;
end;

end.

