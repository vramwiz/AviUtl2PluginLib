// Resolves and persists the application-wide VOICEVOX Engine executable path.
unit SerifVoicevoxEngineConfig;

interface

type
  TSerifVoicevoxEngineConfig = class
  private const
    FILE_NAME = 'VoicevoxEngine.ini';
    SECTION_NAME = 'VOICEVOX';
    ENGINE_EXE_KEY = 'EngineExe';
    ENGINE_UUID = '074fc39e-678b-4c13-8916-ffca8d505d1d';
  private
    FFileName: string;
    class function FindDownloadedEngine(out EngineExe: string): Boolean; static;
    class function InstalledVoicevoxFolder: string; static;
  public
    constructor Create;
    // Accepts VOICEVOX.exe or run.exe, including separately downloaded engines.
    class function NormalizeEngineSelection(const FileName: string;
      out EngineExe: string): Boolean; static;
    // Uses a valid saved path first, then downloaded and bundled engines.
    function Resolve(out EngineExe: string): Boolean;
    // Persists only an existing run.exe path.
    function Save(const EngineExe: string): Boolean;
    property FileName: string read FFileName;
  end;

implementation

uses
  System.Classes, System.IniFiles, System.IOUtils, System.SysUtils, System.JSON,
  AppFolderUtils;

constructor TSerifVoicevoxEngineConfig.Create;
begin
  inherited;
  FFileName := TPath.Combine(GetAppFolder('Serif'), FILE_NAME);
end;

class function TSerifVoicevoxEngineConfig.FindDownloadedEngine(out EngineExe: string): Boolean;
var
  EngineFolder: string;
  EngineRoot: string;
  Manifest: TJSONValue;
  ManifestFile: string;
  UUIDValue: TJSONValue;
begin
  Result := False;
  EngineExe := '';
  EngineRoot := GetEnvironmentVariable('APPDATA');
  if EngineRoot = '' then Exit;
  EngineRoot := TPath.Combine(EngineRoot, 'voicevox\vvpp-engines');
  try
    if not TDirectory.Exists(EngineRoot) then Exit;
    // Only completed official Engine installations are eligible for auto-start.
    for EngineFolder in TDirectory.GetDirectories(EngineRoot) do
    begin
      if not TPath.GetFileName(EngineFolder).EndsWith('+' + ENGINE_UUID, True) then Continue;
      ManifestFile := TPath.Combine(EngineFolder, 'engine_manifest.json');
      try
        if not TFile.Exists(ManifestFile) then Continue;
        Manifest := TJSONObject.ParseJSONValue(TFile.ReadAllText(ManifestFile, TEncoding.UTF8));
        try
          if not (Manifest is TJSONObject) then Continue;
          UUIDValue := TJSONObject(Manifest).GetValue('uuid');
          if not (UUIDValue is TJSONString) then Continue;
          if not SameText(UUIDValue.Value, ENGINE_UUID) then Continue;
          if not NormalizeEngineSelection(TPath.Combine(EngineFolder, 'run.exe'), EngineExe) then Continue;
          Exit(True);
        finally
          Manifest.Free;
        end;
      except
        // An incomplete or unreadable installation must not hide other candidates.
        EngineExe := '';
      end;
    end;
  except
    EngineExe := '';
  end;
end;

class function TSerifVoicevoxEngineConfig.InstalledVoicevoxFolder: string;
var
  LocalAppData: string;
begin
  Result := '';
  LocalAppData := GetEnvironmentVariable('LOCALAPPDATA');
  if LocalAppData = '' then Exit;
  Result := TPath.Combine(TPath.Combine(LocalAppData, 'Programs'),
    'VOICEVOX');
end;

class function TSerifVoicevoxEngineConfig.NormalizeEngineSelection(
  const FileName: string; out EngineExe: string): Boolean;
var
  Candidate: string;
begin
  Result := False;
  EngineExe := '';
  Candidate := Trim(FileName);
  if Candidate = '' then Exit;
  try
    Candidate := TPath.GetFullPath(Candidate);
    if not TFile.Exists(Candidate) then Exit;
    if SameText(TPath.GetFileName(Candidate), 'VOICEVOX.exe') then
    begin
      Candidate := TPath.Combine(TPath.Combine(
        TPath.GetDirectoryName(Candidate), 'vv-engine'), 'run.exe');
      if not TFile.Exists(Candidate) then Exit(FindDownloadedEngine(EngineExe));
    end;
    if not SameText(TPath.GetFileName(Candidate), 'run.exe') or
      not TFile.Exists(Candidate) then Exit;
    EngineExe := Candidate;
    Result := True;
  except
    EngineExe := '';
  end;
end;

function TSerifVoicevoxEngineConfig.Resolve(out EngineExe: string): Boolean;
var
  Candidate: string;
  Ini: TMemIniFile;
  InstallFolder: string;
begin
  Result := False;
  EngineExe := '';
  try
    Ini := TMemIniFile.Create(FFileName, TEncoding.UTF8);
    try
      Candidate := Ini.ReadString(SECTION_NAME, ENGINE_EXE_KEY, '');
    finally
      Ini.Free;
    end;
    if NormalizeEngineSelection(Candidate, EngineExe) then Exit(True);

    // Since 0.26, the standard installer downloads the Engine into user data.
    if FindDownloadedEngine(EngineExe) then
    begin
      Save(EngineExe);
      Exit(True);
    end;

    InstallFolder := InstalledVoicevoxFolder;
    if InstallFolder = '' then Exit;
    Candidate := TPath.Combine(InstallFolder, 'VOICEVOX.exe');
    if NormalizeEngineSelection(Candidate, EngineExe) then
    begin
      Save(EngineExe);
      Exit(True);
    end;
  except
    EngineExe := '';
  end;
end;

function TSerifVoicevoxEngineConfig.Save(
  const EngineExe: string): Boolean;
var
  Ini: TMemIniFile;
  Normalized: string;
begin
  Result := False;
  if not NormalizeEngineSelection(EngineExe, Normalized) then Exit;
  try
    Ini := TMemIniFile.Create(FFileName, TEncoding.UTF8);
    try
      Ini.WriteString(SECTION_NAME, ENGINE_EXE_KEY, Normalized);
      Ini.UpdateFile;
      Result := True;
    finally
      Ini.Free;
    end;
  except
    Result := False;
  end;
end;

end.
