unit SerifWatcherSettings;

// セリフ監視の製品共通設定を管理する。
// GUIやAviUtl2接続を持たず、共通INIの読書きだけを担当する。

interface

uses
  SerifWatcherList;

// プロジェクト側に監視フォルダーが無い場合だけ、共通設定で空欄を補完する。
procedure ApplyCommonSerifWatcherSettings(Watchers,
  CommonWatchers: TSerifWatcherList);

// 現在のプロジェクトにある監視フォルダーを製品共通設定へ保存する。
procedure SaveCommonSerifWatcherSettings(Watchers,
  CommonWatchers: TSerifWatcherList);

implementation

uses
  System.IOUtils,
  System.SysUtils,
  AppFolderUtils;

const
  SERIF_WATCHER_COMMON_FILE_NAME = 'SerifWatcherCommon.ini';

function CommonWatcherFileName: string;
begin
  Result := GetAppFolder('Serif') + SERIF_WATCHER_COMMON_FILE_NAME;
end;

function HasConfiguredWatcherFolder(Watchers: TSerifWatcherList): Boolean;
var
  Index: Integer;
begin
  Result := False;
  if Watchers = nil then Exit;
  for Index := 0 to Watchers.Count - 1 do
    if Trim(Watchers[Index].Folder) <> '' then Exit(True);
end;

procedure LoadCommonWatchers(CommonWatchers: TSerifWatcherList);
begin
  if CommonWatchers = nil then Exit;
  CommonWatchers.Clear;
  CommonWatchers.Filename := CommonWatcherFileName;
  if FileExists(CommonWatchers.Filename) then
    CommonWatchers.LoadFromFile;
end;

procedure ApplyCommonSerifWatcherSettings(Watchers,
  CommonWatchers: TSerifWatcherList);
var
  Index: Integer;
begin
  if (Watchers = nil) or (CommonWatchers = nil) then Exit;
  if HasConfiguredWatcherFolder(Watchers) then Exit;

  LoadCommonWatchers(CommonWatchers);
  if CommonWatchers.Count = 0 then Exit;

  if Watchers.Count = 0 then
  begin
    Watchers.Assign(CommonWatchers);
    Exit;
  end;

  for Index := 0 to Watchers.Count - 1 do
  begin
    if Trim(Watchers[Index].Folder) <> '' then Continue;
    if Index >= CommonWatchers.Count then Break;
    if Trim(CommonWatchers[Index].Folder) = '' then Continue;
    Watchers[Index].Folder := CommonWatchers[Index].Folder;
  end;
end;

procedure SaveCommonSerifWatcherSettings(Watchers,
  CommonWatchers: TSerifWatcherList);
var
  CommonItem: TSerifWatcherItem;
  Index: Integer;
begin
  if (Watchers = nil) or (CommonWatchers = nil) then Exit;
  CommonWatchers.Clear;
  CommonWatchers.Filename := CommonWatcherFileName;

  for Index := 0 to Watchers.Count - 1 do
  begin
    if Trim(Watchers[Index].Folder) = '' then Continue;
    CommonItem := CommonWatchers.AddNew as TSerifWatcherItem;
    CommonItem.Name := Watchers[Index].Name;
    CommonItem.Folder := Watchers[Index].Folder;
    CommonItem.DelaySec := Watchers[Index].DelaySec;
  end;

  if CommonWatchers.Count > 0 then
    CommonWatchers.SaveToFile
  else if FileExists(CommonWatchers.Filename) then
    try
      TFile.Delete(CommonWatchers.Filename);
    except
      // 共有中などで削除できない場合は、既存の共通設定を維持する。
    end;
end;

end.
