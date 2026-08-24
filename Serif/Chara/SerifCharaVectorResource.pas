unit SerifCharaVectorResource;

interface

uses
  System.Classes;

const
  SERIF_CHARA_VECTOR_RESOURCE_NAME = 'SERIF_CHARA_VECTOR_DATA';
  SERIF_CHARA_VECTOR_SIGNATURE_RESOURCE_NAME = 'SERIF_CHARA_VECTOR_SIGNATURE';
  SERIF_CHARA_VECTOR_RES = 'SerifCharaVectorResource.RES';
  SERIF_CHARA_VECTOR_SIGNATURE_FILE = 'SerifCharaVectorResourceSignature.txt';

function BuildSerifCharaVectorResourceFiles(out ACharactersFileName,
  ADesktopResourceFileName, AExtension2ResourceFileName: string): Boolean;
function LoadSerifCharaVectorResource(AStrings: TStrings): Boolean;
function RestoreSerifCharaVectorResourceToFolder(const AFolder: string): Integer;
function FindSerifCharaVectorFolder: string;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.IniFiles,
  System.Hash,
  VectorRendererImageList;

const
  SERIF_CHARA_VECTOR_CACHE_FILE = '.SerifCharaVector.cache';
  SERIF_CHARA_VECTOR_CACHE_VERSION = 1;
  SERIF_CHARA_VECTOR_CACHE_SECTION = 'Cache';
  SERIF_CHARA_VECTOR_CACHE_FILE_SECTION_PREFIX = 'File';

function CurrentModuleFileName: string;
var
  Buffer: array[0..MAX_PATH] of Char;
  Size: DWORD;
begin
  Size := GetModuleFileName(HInstance, Buffer, Length(Buffer));
  if Size = 0 then
    Exit('');
  SetString(Result, Buffer, Size);
end;

{$IFDEF DEBUG}
function FindConfiguredCharacterFolder: string;
var
  PathFileName: string;
begin
  Result := '';
  PathFileName := TPath.Combine(ExtractFilePath(CurrentModuleFileName),
    'VectorCharacterSourcePath.txt');
  if not FileExists(PathFileName) then
    Exit;
  Result := TFile.ReadAllText(PathFileName, TEncoding.Default).Trim;
  if not TDirectory.Exists(Result) then
    Result := '';
end;
{$ENDIF}

function FindFolderUpward(const ARelativeFolder: string): string;
var
  Candidates: TStringList;
  BaseFolder: string;
  FolderName: string;
  I: Integer;
  J: Integer;
begin
  Result := '';
  Candidates := TStringList.Create;
  try
    Candidates.Add(TDirectory.GetCurrentDirectory);
    Candidates.Add(ExtractFilePath(ParamStr(0)));
    Candidates.Add(ExtractFilePath(CurrentModuleFileName));
    for I := 0 to Candidates.Count - 1 do
    begin
      BaseFolder := ExcludeTrailingPathDelimiter(Candidates[I]);
      for J := 0 to 8 do
      begin
        FolderName := TPath.Combine(BaseFolder, ARelativeFolder);
        if TDirectory.Exists(FolderName) then
          Exit(FolderName);
        BaseFolder := TDirectory.GetParent(BaseFolder);
        if BaseFolder = '' then
          Break;
      end;
    end;
  finally
    Candidates.Free;
  end;
end;

function FindSerifCharaVectorFolder: string;
begin
  {$IFDEF DEBUG}
  Result := FindConfiguredCharacterFolder;
  if Result <> '' then
    Exit;
  {$ENDIF}
  Result := FindFolderUpward('Img\Character');
  if Result = '' then
    Result := FindFolderUpward('img\Character');
end;

function FindProjectCharactersFile: string;
var
  CharacterFolder: string;
begin
  Result := '';
  CharacterFolder := FindSerifCharaVectorFolder;
  if CharacterFolder = '' then
    Exit;

  Result := TPath.Combine(CharacterFolder, 'Characters.ini');
  if not FileExists(Result) then
    Result := '';
end;

function FindResourceSourceFolder: string;
var
  BaseFolder: string;
  Candidate: string;
  I: Integer;
begin
  // DebugプラグインはProgramData配下から動くため、設定済みの素材フォルダーを基準に
  // プロジェクト側のリソース保存先を探す。
  BaseFolder := FindSerifCharaVectorFolder;
  for I := 0 to 4 do
  begin
    if BaseFolder = '' then Break;
    Candidate := TPath.Combine(BaseFolder, 'AviUtl2PluginLib\Serif\Chara');
    if TDirectory.Exists(Candidate) then
      Exit(Candidate);
    BaseFolder := TDirectory.GetParent(ExcludeTrailingPathDelimiter(BaseFolder));
  end;

  Result := FindFolderUpward('AviUtl2PluginLib\Serif\Chara');
end;

function FindResourceCompiler: string;
var
  Buffer: array[0..MAX_PATH] of Char;
  FilePart: PChar;
  BdsFolder: string;
  StudioRoot: string;
  StudioFolders: TArray<string>;
  StudioFolder: string;
begin
  Result := '';
  if SearchPath(nil, 'brcc32.exe', nil, Length(Buffer), Buffer, FilePart) > 0 then
  begin
    Result := Buffer;
    Exit;
  end;

  BdsFolder := GetEnvironmentVariable('BDS');
  if BdsFolder <> '' then
  begin
    Result := TPath.Combine(BdsFolder, 'bin\brcc32.exe');
    if FileExists(Result) then
      Exit;
  end;

  StudioRoot := 'C:\Program Files (x86)\Embarcadero\Studio';
  if not TDirectory.Exists(StudioRoot) then
  begin
    Result := '';
    Exit;
  end;

  StudioFolders := TDirectory.GetDirectories(StudioRoot);
  for StudioFolder in StudioFolders do
  begin
    Result := TPath.Combine(StudioFolder, 'bin\brcc32.exe');
    if FileExists(Result) then
      Exit;
  end;
  Result := '';
end;

function RunResourceCompiler(const ARcFileName, AResFileName: string): Boolean;
var
  ResourceCompiler: string;
  CommandLine: string;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  ExitCode: DWORD;
begin
  Result := False;
  ResourceCompiler := FindResourceCompiler;
  if ResourceCompiler = '' then
    Exit;

  CommandLine := Format('"%s" "-fo%s" "%s"',
    [ResourceCompiler, AResFileName, ARcFileName]);
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));
  if not CreateProcess(nil, PChar(CommandLine), nil, nil, False, CREATE_NO_WINDOW,
    nil, PChar(TPath.GetDirectoryName(ARcFileName)), StartupInfo, ProcessInfo) then
    Exit;
  try
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    if GetExitCodeProcess(ProcessInfo.hProcess, ExitCode) then
      Result := ExitCode = 0;
  finally
    CloseHandle(ProcessInfo.hThread);
    CloseHandle(ProcessInfo.hProcess);
  end;
end;

function BuildResourceFile(const ACharactersFileName, AResFileName: string): Boolean;
var
  TempFolder: string;
  TempTextFileName: string;
  TempSignatureFileName: string;
  TempRcFileName: string;
  ResourceSignature: string;
  ResourceSource: TStringList;
begin
  TempFolder := TPath.Combine(TPath.GetTempPath,
    TPath.GetFileNameWithoutExtension(AResFileName) + '_' + IntToHex(GetTickCount, 8));
  ForceDirectories(TempFolder);
  TempTextFileName := TPath.Combine(TempFolder, 'Characters.ini');
  TempSignatureFileName := TPath.Combine(TempFolder, 'Signature.txt');
  TempRcFileName := TPath.Combine(TempFolder, 'CharaVector.rc');

  ResourceSource := TStringList.Create;
  try
    TFile.Copy(ACharactersFileName, TempTextFileName, True);
    ResourceSignature := LowerCase(
      THashSHA2.GetHashStringFromFile(ACharactersFileName));
    TFile.WriteAllText(TempSignatureFileName, ResourceSignature,
      TEncoding.ASCII);
    ResourceSource.Add(Format('%s RCDATA "%s"',
      [SERIF_CHARA_VECTOR_RESOURCE_NAME, TempTextFileName]));
    ResourceSource.Add(Format('%s RCDATA "%s"',
      [SERIF_CHARA_VECTOR_SIGNATURE_RESOURCE_NAME, TempSignatureFileName]));
    ResourceSource.SaveToFile(TempRcFileName, TEncoding.ASCII);
    Result := RunResourceCompiler(TempRcFileName, AResFileName) and FileExists(AResFileName);
    if Result then
      TFile.WriteAllText(TPath.Combine(TPath.GetDirectoryName(AResFileName),
        SERIF_CHARA_VECTOR_SIGNATURE_FILE), ResourceSignature,
        TEncoding.ASCII);
  finally
    ResourceSource.Free;
    if TDirectory.Exists(TempFolder) then
    begin
      try
        TDirectory.Delete(TempFolder, True);
      except
      end;
    end;
  end;
end;

function LoadSerifCharaVectorResourceSignature(out ASignature: string): Boolean;
var
  ResourceStream: TResourceStream;
  SignatureStrings: TStringList;
begin
  Result := False;
  ASignature := '';
  if FindResource(HInstance, PChar(SERIF_CHARA_VECTOR_SIGNATURE_RESOURCE_NAME),
    RT_RCDATA) = 0 then
    Exit;

  ResourceStream := TResourceStream.Create(HInstance,
    SERIF_CHARA_VECTOR_SIGNATURE_RESOURCE_NAME, RT_RCDATA);
  SignatureStrings := TStringList.Create;
  try
    SignatureStrings.LoadFromStream(ResourceStream, TEncoding.ASCII);
    ASignature := SignatureStrings.Text.Trim;
    Result := ASignature <> '';
  finally
    SignatureStrings.Free;
    ResourceStream.Free;
  end;
end;

function VectorFileDateTimeText(const AFileName: string): string;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz',
    TFile.GetLastWriteTime(AFileName), TFormatSettings.Invariant);
end;

function IsSerifCharaVectorRestoreCacheValid(const AFolder,
  AResourceSignature: string): Boolean;
var
  CacheFileName: string;
  FileCount: Integer;
  FileName: string;
  FileSection: string;
  I: Integer;
  Ini: TMemIniFile;
begin
  Result := False;
  CacheFileName := TPath.Combine(AFolder, SERIF_CHARA_VECTOR_CACHE_FILE);
  if not FileExists(CacheFileName) then
    Exit;

  try
    Ini := TMemIniFile.Create(CacheFileName, TEncoding.UTF8);
    try
      if Ini.ReadInteger(SERIF_CHARA_VECTOR_CACHE_SECTION, 'Version', 0) <>
        SERIF_CHARA_VECTOR_CACHE_VERSION then
        Exit;
      if not SameText(Ini.ReadString(SERIF_CHARA_VECTOR_CACHE_SECTION,
        'ResourceSignature', ''), AResourceSignature) then
        Exit;

      FileCount := Ini.ReadInteger(SERIF_CHARA_VECTOR_CACHE_SECTION,
        'FileCount', -1);
      if (FileCount <= 0) or (FileCount > 10000) then
        Exit;
      for I := 0 to FileCount - 1 do
      begin
        FileSection := SERIF_CHARA_VECTOR_CACHE_FILE_SECTION_PREFIX +
          IntToStr(I);
        FileName := Ini.ReadString(FileSection, 'Name', '');
        if (FileName = '') or
          not SameText(TPath.GetFileName(FileName), FileName) then
          Exit;
        FileName := TPath.Combine(AFolder, FileName);
        if not FileExists(FileName) then
          Exit;
        if Ini.ReadString(FileSection, 'FileDateTime', '') <>
          VectorFileDateTimeText(FileName) then
          Exit;
      end;
      Result := True;
    finally
      Ini.Free;
    end;
  except
    Result := False;
  end;
end;

procedure SaveSerifCharaVectorRestoreCache(const AFolder,
  AResourceSignature: string; AImageList: TVectorRendererImageList);
var
  CacheFileName: string;
  FileName: string;
  FileSection: string;
  I: Integer;
  Ini: TMemIniFile;
  TempCacheFileName: string;
begin
  if AResourceSignature = '' then
    Exit;

  ForceDirectories(AFolder);
  CacheFileName := TPath.Combine(AFolder, SERIF_CHARA_VECTOR_CACHE_FILE);
  TempCacheFileName := CacheFileName + '.' +
    IntToHex(GetCurrentProcessId, 8) + '.' + IntToHex(GetCurrentThreadId, 8) +
    '.' + IntToHex(GetTickCount64, 16) + '.tmp';
  try
    try
      Ini := TMemIniFile.Create(TempCacheFileName, TEncoding.UTF8);
      try
        Ini.WriteInteger(SERIF_CHARA_VECTOR_CACHE_SECTION, 'Version',
          SERIF_CHARA_VECTOR_CACHE_VERSION);
        Ini.WriteString(SERIF_CHARA_VECTOR_CACHE_SECTION,
          'ResourceSignature', AResourceSignature);
        Ini.WriteInteger(SERIF_CHARA_VECTOR_CACHE_SECTION, 'FileCount',
          AImageList.Count);
        for I := 0 to AImageList.Count - 1 do
        begin
          FileName := AImageList.Images[I].FileName;
          if (FileName = '') or
            not SameText(TPath.GetFileName(FileName), FileName) then
            Exit;
          FileName := TPath.Combine(AFolder, FileName);
          if not FileExists(FileName) then
            Exit;
          FileSection := SERIF_CHARA_VECTOR_CACHE_FILE_SECTION_PREFIX +
            IntToStr(I);
          Ini.WriteString(FileSection, 'Name',
            AImageList.Images[I].FileName);
          Ini.WriteString(FileSection, 'FileDateTime',
            VectorFileDateTimeText(FileName));
        end;
        Ini.UpdateFile;
      finally
        Ini.Free;
      end;
      if not MoveFileEx(PChar(TempCacheFileName), PChar(CacheFileName),
        MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
        RaiseLastOSError;
    except
      // キャッシュ保存の失敗は、復元したベクターデータの利用を妨げない。
    end;
  finally
    if FileExists(TempCacheFileName) then
    begin
      try
        TFile.Delete(TempCacheFileName);
      except
      end;
    end;
  end;
end;

function BuildSerifCharaVectorResourceFiles(out ACharactersFileName,
  ADesktopResourceFileName, AExtension2ResourceFileName: string): Boolean;
var
  ResourceFolder: string;
  ResourceFileName: string;
begin
  Result := False;
  ACharactersFileName := FindProjectCharactersFile;
  ADesktopResourceFileName := '';
  AExtension2ResourceFileName := '';
  if ACharactersFileName = '' then
    Exit;

  ResourceFolder := FindResourceSourceFolder;
  if ResourceFolder = '' then
    Exit;

  ResourceFileName := TPath.Combine(ResourceFolder, SERIF_CHARA_VECTOR_RES);
  ADesktopResourceFileName := ResourceFileName;
  AExtension2ResourceFileName := ResourceFileName;

  Result := BuildResourceFile(ACharactersFileName, ResourceFileName);
end;

function LoadSerifCharaVectorResource(AStrings: TStrings): Boolean;
var
  ResourceStream: TResourceStream;
begin
  Result := False;
  AStrings.Clear;
  if FindResource(HInstance, PChar(SERIF_CHARA_VECTOR_RESOURCE_NAME), RT_RCDATA) = 0 then
    Exit;

  ResourceStream := TResourceStream.Create(HInstance,
    SERIF_CHARA_VECTOR_RESOURCE_NAME, RT_RCDATA);
  try
    if ResourceStream.Size = 0 then
      Exit;
    AStrings.LoadFromStream(ResourceStream, TEncoding.UTF8);
    Result := AStrings.Text.Trim <> '';
  finally
    ResourceStream.Free;
  end;
end;

function RestoreSerifCharaVectorResourceToFolder(const AFolder: string): Integer;
var
  ImageList: TVectorRendererImageList;
  ResourceSignature: string;
  ResourceStrings: TStringList;
begin
  Result := 0;
  ResourceSignature := '';
  if LoadSerifCharaVectorResourceSignature(ResourceSignature) and
    IsSerifCharaVectorRestoreCacheValid(AFolder, ResourceSignature) then
    Exit;

  ResourceStrings := TStringList.Create;
  try
    if not LoadSerifCharaVectorResource(ResourceStrings) then
      Exit;

    ForceDirectories(AFolder);
    ImageList := TVectorRendererImageList.Create;
    try
      Result := ImageList.RestoreFilesFromStrings(ResourceStrings, AFolder);
      SaveSerifCharaVectorRestoreCache(AFolder, ResourceSignature, ImageList);
    finally
      ImageList.Free;
    end;
  finally
    ResourceStrings.Free;
  end;
end;

end.
