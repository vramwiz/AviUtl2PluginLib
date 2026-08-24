unit LauncherListItems;
// ランチャー項目と永続化リスト。

interface

uses
  Winapi.Windows,
  System.SysUtils,
  LauncherListTypes, RTTIPersistentIni;

type
  TLauncherListViewItem = class(TRTTIPersistentIni)
  private
    FFileName: string; // 起動対象の実行ファイルまたはショートカット。
    FName: string; // 一覧に表示するアプリ名。
    FRunningState: TLauncherRunningState; // 現在の起動・管理状態。
    FWindowHandle: HWND; // 起動中アプリとして管理するトップレベルウィンドウ。
    FLaunchedByLauncher: Boolean; // True:このランチャーから起動して管理対象にした項目。
  public
    constructor Create;
    destructor Destroy; override;
    property RunningState: TLauncherRunningState read FRunningState write FRunningState;
    property WindowHandle: HWND read FWindowHandle write FWindowHandle;
    property LaunchedByLauncher: Boolean read FLaunchedByLauncher write FLaunchedByLauncher;
  published
    property FileName: string read FFileName write FFileName;
    property Name: string read FName write FName;
  end;

type
  TLauncherListViewList = class(TRTTIPersistentIniList<TLauncherListViewItem>)
  private
    function GetFiles(Index: Integer): TLauncherListViewItem;
  public
    constructor Create;
    destructor Destroy; override;
    function AddFile(const FileName: string): TLauncherListViewItem;
    function IndexOfFileName(const FileName: string): Integer;
    property Files[Index: Integer]: TLauncherListViewItem read GetFiles; default;
  end;

implementation

{ TLauncherListViewList }

constructor TLauncherListViewList.Create;
begin
  inherited;
end;

destructor TLauncherListViewList.Destroy;
begin
  inherited;
end;

function TLauncherListViewList.GetFiles(Index: Integer): TLauncherListViewItem;
begin
  Result := inherited Items[Index];
end;

function TLauncherListViewList.AddFile(
  const FileName: string): TLauncherListViewItem;
var
  I: Integer;
begin
  I := IndexOfFileName(FileName);
  if I <> -1 then
    Exit(Files[I]);

  Result := AddNew;
  Result.FileName := FileName;
  Result.Name := ChangeFileExt(ExtractFileName(FileName), '');
end;

function TLauncherListViewList.IndexOfFileName(const FileName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Count - 1 do
  begin
    if not SameText(Files[I].FileName, FileName) then
      Continue;

    Result := I;
    Exit;
  end;
end;

{ TLauncherListViewItem }

constructor TLauncherListViewItem.Create;
begin
  inherited;
end;

destructor TLauncherListViewItem.Destroy;
begin
  inherited;
end;

end.
