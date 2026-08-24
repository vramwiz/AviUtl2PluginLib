unit ExplorerHist;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,System.StrUtils,ComCtrls,RTTIPersistentIni,
  System.Generics.Collections;

// フォルダの履歴管理するクラス
type
  TExplorerHistItem = class(TRTTIPersistentIni)
  private
    FFolderName : string;      // フォルダ名
    FStyle      : Integer;     // 表示形式     0:一般 1:画像 2:音楽 3:エリアス
    FName       : string;      // 表示する名称
  public

  published
    property FolderName:  string read FFolderName  write FFolderName;
    property Name : string read FName write FName;
    property Style : Integer read FStyle write FStyle;
  end;

type
	TExplorerHistList  = class(TRTTIPersistentIniList<TExplorerHistItem>)
	private
    // 拡張子に一致するファイル数を返す
    function GetExtensionScore(FileNames : TStringList) :Integer;
    function GetExtensionStyle(FileNames : TStringList) :Integer;
    function ExtInTable(const Ext: string;const Table: array of string): Boolean;
    function GetExtensionKind(const FileName: string): Integer;
    function GetHists(Index: Integer): TExplorerHistItem;
    function FolderNameToStyle(const FolderName :string) : Integer;
  protected
	public
		{ Public 宣言 }
    // フォルダの履歴にフォルダを追加　一致確認、専用ファイルを作成
    function AddHist(const FolderName : string) : TExplorerHistItem;
    // フォルダ履歴から削除　専用ファイルを削除
    procedure DeleteHist(const Index : Integer);
    function IndexOfFolderName(const FolderName : string) : Integer;
    // 指定したスタイルをリストから探索
    function IndexOfStyle(const Style  : Integer) : Integer;
    property Hists[Index : Integer] : TExplorerHistItem read GetHists;default;
    //    property Files[Index : Integer] : TExplorerFileItem read GetFiles;default;

	end;


implementation

uses System.RegularExpressions,ExplorerFileList,
     ExplorerListNormal,ExplorerListPicture;

{ TExplorerHistList }


function TExplorerHistList.AddHist(const FolderName: string) : TExplorerHistItem;
var
  i: Integer;
  Hist: TExplorerHistItem;
  MaxHistCount: Integer;
begin
  i := IndexOfFolderName(FolderName);
  if i >= 0 then
    Delete(i); // すでにある → 一度削除（順番更新）

  // 新規作成して先頭に追加
  Hist := InsertNew(0); // ← AddNew ではなく先頭に追加したいなら Insert(0)
  Hist.FolderName := FolderName;
  Hist.Name := ExtractFileName(ExcludeTrailingPathDelimiter(FolderName));
  Hist.Style := FolderNameToStyle(Hist.FolderName);
  Result := Hist;

  // フォルダが存在しなければ削除
  for i := Count-1 downto 0 do begin
    if not DirectoryExists(Items[i].FFolderName) then begin
      Delete(i);
    end;
  end;


  // 最大履歴数を超えていたら最後を削除（ここでは10件に制限）
  MaxHistCount := 10;
  while Count > MaxHistCount do
    Delete(Count - 1);
  SaveToFile;
end;

procedure TExplorerHistList.DeleteHist(const Index: Integer);
var
  i: Integer;
begin
  i := Index;
  if i = -1 then Exit;
  if i >= Count then Exit;
  Delete(Index);
end;



function TExplorerHistList.IndexOfFolderName(const FolderName: string): Integer;
var
  i: Integer;
  s1,s2 : string;
begin
  result := -1;
  s2 := ExcludeTrailingPathDelimiter(FolderName);
  for i := 0 to Count-1 do begin
    s1 := ExcludeTrailingPathDelimiter(Trim(Items[i].FFolderName));
    if LowerCase(s1) <> LowerCase(s2) then continue;
    result := i;
    exit;
  end;
end;

function TExplorerHistList.IndexOfStyle(const Style: Integer): Integer;
var
  i: Integer;
begin
  result := -1;
  for i := 0 to Count-1 do begin
    if Items[i].FStyle <> Style then continue;
    result := i;
    exit;
  end;
end;

function TExplorerHistList.FolderNameToStyle(const FolderName: string): Integer;
var
  SR: System.SysUtils.TSearchRec;
  FileName: string;
  ts : TStringList;
begin
  ts := nil;
  if System.SysUtils.FindFirst(FolderName + '\*.*', faAnyFile, SR) = 0 then
  ts := TStringList.Create;
  try
    repeat
      // . と .. を除外
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      FileName := SR.Name;

      ts.Add(FileName);
    until System.SysUtils.FindNext(SR) <> 0;

    Result := GetExtensionStyle(ts);
  finally
    ts.Free;
    System.SysUtils.FindClose(SR);
  end;
end;

function TExplorerHistList.ExtInTable(const Ext: string;const Table: array of string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(Table) to High(Table) do
    if Ext = Table[i] then
      Exit(True);
end;

function TExplorerHistList.GetExtensionKind(const FileName: string): Integer;
const
  IMAGE_EXTS: array[0..6] of string =
    ('.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp', '.tga');

  MUSIC_EXTS: array[0..5] of string =
    ('.wav', '.mp3', '.ogg', '.flac', '.aac', '.m4a');

  ALIAS_EXTS: array[0..0] of string =
    ('.object');
var
  Ext: string;
begin
  Result := 0; // 不明

  Ext := LowerCase(ExtractFileExt(FileName));
  if Ext = '' then
    Exit;

  if ExtInTable(Ext, ALIAS_EXTS) then
    Exit(3);

  if ExtInTable(Ext, IMAGE_EXTS) then
    Exit(1);

  if ExtInTable(Ext, MUSIC_EXTS) then
    Exit(2);
end;

function TExplorerHistList.GetExtensionScore(FileNames: TStringList): Integer;
var
  i: Integer;
  ImgCnt, MusCnt, AliCnt: Integer;
begin
  Result := 0;

  if (FileNames = nil) or (FileNames.Count = 0) then
    Exit;

  ImgCnt := 0;
  MusCnt := 0;
  AliCnt := 0;

  for i := 0 to FileNames.Count - 1 do
  begin
    case GetExtensionKind(FileNames[i]) of
      1: Inc(ImgCnt);
      2: Inc(MusCnt);
      3: Inc(AliCnt);
    end;
  end;

  if ImgCnt > 1023 then ImgCnt := 1023;
  if MusCnt > 1023 then MusCnt := 1023;
  if AliCnt > 1023 then AliCnt := 1023;

  Result := (AliCnt shl 20) or (MusCnt shl 10) or ImgCnt;
end;


function TExplorerHistList.GetExtensionStyle(FileNames: TStringList): Integer;
var
  Score: Integer;
  ImgCnt, MusCnt, AliCnt: Integer;
  KindCount: Integer;
begin
  Result := 0;

  Score := GetExtensionScore(FileNames);
  if Score = 0 then
    Exit;

  ImgCnt := (Score        ) and $3FF;
  MusCnt := (Score shr 10 ) and $3FF;
  AliCnt := (Score shr 20 ) and $3FF;

  KindCount := 0;
  if ImgCnt > 0 then Inc(KindCount);
  if MusCnt > 0 then Inc(KindCount);
  if AliCnt > 0 then Inc(KindCount);

  if KindCount <> 1 then
    Exit;

  if AliCnt > 0 then
    Result := 3
  else if ImgCnt > 0 then
    Result := 1
  else if MusCnt > 0 then
    Result := 2;
end;


function TExplorerHistList.GetHists(Index: Integer): TExplorerHistItem;
begin
  Result := inherited Items[Index];
end;


end.
