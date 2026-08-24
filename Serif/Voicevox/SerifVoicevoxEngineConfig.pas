// Resolves and persists the application-wide VOICEVOX Engine executable path.
unit SerifVoicevoxEngineConfig;

interface

type
  TSerifVoicevoxEngineConfig = class
  private const
    FILE_NAME = 'VoicevoxEngine.ini';
    SECTION_NAME = 'VOICEVOX';
    ENGINE_EXE_KEY = 'EngineExe';
  private
    FFileName: string;
    class function InstalledVoicevoxFolder: string; static;
  public
    constructor Create;
    // Accepts either VOICEVOX.exe or vv-engine\run.exe and returns the Engine path.
    class function NormalizeEngineSelection(const FileName: string;
      out EngineExe: string): Boolean; static;
    // Uses a valid saved path first, then the standard per-user installation.
    function Resolve(out EngineExe: string): Boolean;
    // Persists only a validated vv-engine\run.exe path.
    function Save(const EngineExe: string): Boolean;
    property FileName: string read FFileName;
  end;

implementation

uses
  System.Classes, System.IniFiles, System.IOUtils, System.SysUtils,
  AppFolderUtils;

constructor TSerifVoicevoxEngineConfig.Create;
begin
  inherited;
  FFileName := TPath.Combine(GetAppFolder('Serif'), FILE_NAME);
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
    if SameText(TPath.GetFileName(Candidate), 'VOICEVOX.exe') then
      Candidate := TPath.Combine(TPath.Combine(
        TPath.GetDirectoryName(Candidate), 'vv-engine'), 'run.exe');
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
