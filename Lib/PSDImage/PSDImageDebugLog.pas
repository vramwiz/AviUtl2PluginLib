unit PSDImageDebugLog;

interface

procedure PSDDebugLog(const Tag, S: string);
// Debugビルドでだけ、有効化ファイルの有無にかかわらず調査ログを記録する。
procedure PSDDebugLogDebug(const Tag, S: string);
function PSDDebugLogEnabled: Boolean;
function PSDDebugLogFileName: string;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, Winapi.Windows,
  AppFolderUtils;

var
  GDebugLogEnabledKnown: Boolean;
  GDebugLogEnabled: Boolean;

function FallbackTempFolder: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'Syncroh2');
  Result := TPath.Combine(Result, 'Temp');
  Result := IncludeTrailingPathDelimiter(Result);
end;

function PSDDebugLogFileName: string;
var
  Folder: string;
begin
  Folder := '';
  try
    Folder := GetAppFolder('Temp');
  except
    Folder := '';
  end;

  if Folder = '' then
    Folder := FallbackTempFolder;

  try
    ForceDirectories(Folder);
  except
  end;

  Result := TPath.Combine(Folder, 'PSDImageDebug.log');
end;

function PSDDebugLogEnabledFileName: string;
begin
  Result := TPath.Combine(ExtractFilePath(PSDDebugLogFileName),
    'PSDImageDebug.enabled');
end;

function PSDDebugLogEnabled: Boolean;
begin
  if not GDebugLogEnabledKnown then
  begin
    GDebugLogEnabled :=
      (GetEnvironmentVariable('SYNCROH2_PSD_DEBUG_LOG') <> '') or
      FileExists(PSDDebugLogEnabledFileName);
    GDebugLogEnabledKnown := True;
  end;

  Result := GDebugLogEnabled;
end;

procedure AppendLogLine(const FileName, Line: string);
var
  Stream: TFileStream;
  Bytes: TBytes;
begin
  Stream := nil;
  try
    if FileExists(FileName) then
      Stream := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
    else
      Stream := TFileStream.Create(FileName, fmCreate or fmShareDenyNone);

    Stream.Seek(0, soEnd);
    Bytes := TEncoding.UTF8.GetBytes(Line);
    if Length(Bytes) > 0 then
      Stream.WriteBuffer(Bytes[0], Length(Bytes));
  finally
    Stream.Free;
  end;
end;

procedure WriteLogLine(const Tag, S: string);
var
  Line: string;
begin
  Line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
    ' [' + Tag + '] ' + S + sLineBreak;

  OutputDebugString(PChar(Line));

  try
    AppendLogLine(PSDDebugLogFileName, Line);
  except
    // Debug logging must never affect PSD processing.
  end;
end;

procedure PSDDebugLog(const Tag, S: string);
begin
  if not PSDDebugLogEnabled then Exit;
  WriteLogLine(Tag, S);
end;

procedure PSDDebugLogDebug(const Tag, S: string);
begin
  {$IFDEF DEBUG}
  WriteLogLine(Tag, S);
  {$ENDIF}
end;

end.
