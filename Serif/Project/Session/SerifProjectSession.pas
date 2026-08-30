unit SerifProjectSession;


interface

uses SerifSceneList, SerifCharaList, SerifWatcherList, SerifConfig;

// 指定フォルダーのセリフデータを各リストへ読み込み、新規プロジェクトでは
// 前プロジェクトの値を残さず既定状態を作る。Configは必要に応じて再生成する。
procedure LoadSerifProjectData(const Folder: string; Scenes: TSerifSceneList;
  Charas: TSerifCharaList; Watchers, CommonWatchers: TSerifWatcherList;
  var Config: TSerifConfigItem);

// 現在のプロジェクトデータを各設定ファイルへ保存する。
procedure SaveSerifProjectData(Scenes: TSerifSceneList;
  Charas: TSerifCharaList; Watchers: TSerifWatcherList;
  Config: TSerifConfigItem);

// シーンを保存して監視を止め、次のプロジェクトへ旧ファイル名を持ち越さない。
procedure CloseSerifProjectData(Scenes: TSerifSceneList;
  Charas: TSerifCharaList; Watchers: TSerifWatcherList;
  Config: TSerifConfigItem);

implementation

uses System.SysUtils, Vcl.Graphics, CharaAnalyzer, SerifWatcherSettings;

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

procedure ApplyCharaColorDefaults(Charas: TSerifCharaList);
var
  I: Integer;
  Chara: TSerifCharaItem;
  CharaName: string;
  ColorLight: TColor;
  ColorBase: TColor;
  ColorDark: TColor;
  ColorCharas: TSerifAnalyzerCharaList;
  Changed: Boolean;
begin
  if Charas = nil then Exit;
  ColorCharas := TSerifAnalyzerCharaList.Create;
  try
    Changed := False;
    for I := 0 to Charas.Count - 1 do
    begin
      Chara := Charas[I];
      if Chara = nil then Continue;
      CharaName := Trim(Chara.Name);
      if CharaName = '' then CharaName := Trim(Chara.Keyword);
      if not ColorCharas.TryGetCharaColors(CharaName, ColorLight,
        ColorBase, ColorDark) then Continue;
      if (Chara.ColorLight = ColorLight) and
         (Chara.ColorBase = ColorBase) and
         (Chara.ColorDark = ColorDark) then Continue;
      Chara.SetImageColors(ColorLight, ColorBase, ColorDark);
      Changed := True;
    end;
    if Changed then Charas.SaveToFile;
  finally
    ColorCharas.Free;
  end;
end;

procedure LoadSerifProjectData(const Folder: string; Scenes: TSerifSceneList;
  Charas: TSerifCharaList; Watchers, CommonWatchers: TSerifWatcherList;
  var Config: TSerifConfigItem);
var
  FileName: string;
  Watcher: TSerifWatcherItem;
begin
  FileName := Folder + 'Scene.ini';
  Scenes.Filename := FileName;
  Scenes.LoadFromFile;

  FileName := Folder + 'Charas.ini';
  Charas.Filename := FileName;
  if FileExists(FileName) then
    Charas.LoadFromFile
  else
    Charas.Clear;
  ApplyCharaColorDefaults(Charas);

  FileName := Folder + 'Watchers.ini';
  Watchers.Stop;
  Watchers.Filename := FileName;
  if FileExists(FileName) then
    Watchers.LoadFromFile
  else
    Watchers.Clear;
  ApplyCommonSerifWatcherSettings(Watchers, CommonWatchers);
  if Watchers.Count = 0 then
  begin
    Watcher := Watchers.AddNew;
    Watcher.Name := '音声合成ソフト';
  end;

  FileName := Folder + 'Config.ini';
  if FileExists(FileName) then
  begin
    Config.Filename := FileName;
    Config.LoadFromFile;
  end
  else
  begin
    Config.Free;
    Config := TSerifConfigItem.Create;
    Config.Filename := FileName;
  end;
end;

procedure SaveSerifProjectData(Scenes: TSerifSceneList;
  Charas: TSerifCharaList; Watchers: TSerifWatcherList;
  Config: TSerifConfigItem);
begin
  Scenes.SaveToFile;
  Charas.SaveToFile;
  Watchers.SaveToFile;
  Config.SaveToFile;
end;

procedure CloseSerifProjectData(Scenes: TSerifSceneList;
  Charas: TSerifCharaList; Watchers: TSerifWatcherList;
  Config: TSerifConfigItem);
begin
  Watchers.Stop;
  if Scenes.Filename <> '' then Scenes.SaveToFile;
  Scenes.Filename := '';
  Charas.Filename := '';
  Watchers.Filename := '';
  Config.Filename := '';
end;

end.
