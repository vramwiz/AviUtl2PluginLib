unit ScanFolderAndFile;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils,System.Types;

{
  ScanFolderAndFiles
  -------------------------------------------------------------------
  ・ファイル名 + フォルダ名が混在する TArray<string> を入力として受け取る
  ・フォルダは再帰的に走査し、指定拡張子のファイルのみを抽出する
  ・結果は呼び出し側が渡す TStrings に追加する（生成/破棄は呼び出し側）
  ・拡張子はドット付き / 大文字小文字無視で扱う
}

procedure ScanFolderAndFiles(const FileNames: TArray<string>;const Exts: TArray<string>; Output: TStrings);

implementation

//===============================================================
// 内部関数（Sub）宣言
//===============================================================
procedure ScanFolderRecursiveSub(const Folder: string;
  const Exts: TArray<string>; Output: TStrings);
forward;

function IsTargetExtensionSub(const FileName: string;
  const Exts: TArray<string>): Boolean;
var
  Ext: string;
  x: string;
begin
  Result := False;

  x := LowerCase(ExtractFileExt(FileName));
  if x = '' then
    Exit;

  for Ext in Exts do
  begin
    if x = LowerCase(Ext) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

//---------------------------------------------------------------
// パスがフォルダかファイルか仕分けする（必要に応じてフォルダ再帰）
//---------------------------------------------------------------
procedure ProcessPathSub(const Path: string; const Exts: TArray<string>;
  Output: TStrings);
begin
  if DirectoryExists(Path) then
  begin
    // フォルダ → 再帰処理へ
    ScanFolderRecursiveSub(Path, Exts, Output);
  end
  else if FileExists(Path) then
  begin
    // ファイル → 拡張子チェック
    if IsTargetExtensionSub(Path, Exts) then
      Output.Add(Path);
  end;
end;

//===============================================================
// フォルダを再帰的に探索するサブ関数
//===============================================================
procedure ScanFolderRecursiveSub(const Folder: string;
  const Exts: TArray<string>; Output: TStrings);
var
  Files: TStringDynArray;
  Dirs: TStringDynArray;
  FileName: string;
  DirName: string;
begin
  // このフォルダ内のファイルを列挙
  Files := TDirectory.GetFiles(Folder);
  for FileName in Files do
  begin
    if IsTargetExtensionSub(FileName, Exts) then
      Output.Add(FileName);
  end;

  // サブフォルダを列挙 → 再帰呼び出し
  Dirs := TDirectory.GetDirectories(Folder);
  for DirName in Dirs do
  begin
    ScanFolderRecursiveSub(DirName, Exts, Output);
  end;
end;

//===============================================================
// 外部公開されるメイン関数
//===============================================================
procedure ScanFolderAndFiles(const FileNames: TArray<string>;
  const Exts: TArray<string>; Output: TStrings);
var
  S: string;
begin
  if Output = nil then
    Exit;

  for S in FileNames do
  begin
    ProcessPathSub(S, Exts, Output);
  end;
end;

end.

