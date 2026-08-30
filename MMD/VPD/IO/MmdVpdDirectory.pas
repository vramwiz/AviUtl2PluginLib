unit MmdVpdDirectory;

// MMDAnimationStudio製品群が共有するVPD保存先を検証し、必要なら作成する。

interface

// テストや将来の保存先切替でも同じ検証を使えるよう、任意パス版を公開する。
function EnsureMmdVpdDirectoryAt(const DirectoryPath: string): string;
function EnsureMmdVpdDirectory: string;

implementation

uses
  System.IOUtils,
  System.SysUtils;

function EnsureMmdVpdDirectoryAt(const DirectoryPath: string): string;
begin
  if Trim(DirectoryPath) = '' then
    raise EArgumentException.Create('VPD directory path must not be empty.');
  Result := TPath.GetFullPath(DirectoryPath);
  if TFile.Exists(Result) then
    raise EInOutError.CreateFmt(
      'VPD directory path is occupied by a file: %s', [Result]);
  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
  if not TDirectory.Exists(Result) then
    raise EInOutError.CreateFmt('VPD directory could not be created: %s',
      [Result]);
end;

function EnsureMmdVpdDirectory: string;
begin
  Result := EnsureMmdVpdDirectoryAt(TPath.Combine(
    TPath.Combine(TPath.GetDocumentsPath, 'MMDAnimationStudio'), 'VPD'));
end;

end.
