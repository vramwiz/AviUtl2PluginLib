unit FileInfoList;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls;

type
  TFileInfoListItem = class(TPersistent)
  private
    { Private éŒ¾ }
    FFileName      : string;
    FLastWriteTime : TDateTime;
  public
    { Public éŒ¾ }
    property FileName : string read FFileName write FFileName;
    property LastWriteTime: TDateTime read FLastWriteTime write FLastWriteTime;
  end;

type
	TFileListInfoItems = class(TList)
	private
		{ Private éŒ¾ }
    function CheckFile(const Filename : string) : Boolean;
    function GetFiles(Index: Integer): TFileInfoListItem;
	public
		{ Public éŒ¾ }
    destructor Destroy;override;
    function Add() : TFileInfoListItem;
    procedure Delete(i : Integer);
    procedure Clear();override;

    procedure FolderScan(const Folder : string);
    function IndexOfFileNameWriteTime(d : TFileInfoListItem) : Integer;

    procedure SortByLastWriteTime;

		property Files[Index: Integer] : TFileInfoListItem read GetFiles ;default;

	end;


function IsTemporaryDownloadFile(const FileName: string): Boolean;
function IsImageFile(const FileName: string): Boolean;


implementation

uses System.IOUtils,StrUtils;


destructor TFileListInfoItems.Destroy;
begin
  Clear();
  inherited;
end;

function IsTemporaryDownloadFile(const FileName: string): Boolean;
const
  TempExtensions: array[0..2] of string = ('.tmp', '.crdownload', '.part');
begin
  Result := MatchStr(LowerCase(ExtractFileExt(FileName)), TempExtensions);
end;

function IsImageFile(const FileName: string): Boolean;
const
  TempExtensions: array[0..4] of string = ('.bmp', '.gif', '.jpeg','.jpg','.png');
begin
  Result := MatchStr(LowerCase(ExtractFileExt(FileName)), TempExtensions);
end;

procedure TFileListInfoItems.FolderScan(const Folder : string);
var
  SR: TSearchRec;
  FileName: string;
  d : TFileInfoListItem;
begin
  Clear;
  if FindFirst(Folder + '\*.*', faAnyFile, SR) = 0 then begin
    repeat
      FileName := IncludeTrailingPathDelimiter(Folder) + SR.Name;
      if not CheckFile(FileName) then continue;
      if not IsImageFile(FileName) then continue;
      if IsTemporaryDownloadFile(FileName) then continue;
      d := Add();
      d.FFileName := FileName;
      d.FLastWriteTime := TFile.GetLastWriteTime(FileName);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  SortByLastWriteTime();
end;

function TFileListInfoItems.Add: TFileInfoListItem;
var
  d : TFileInfoListItem;
begin
  d := TFileInfoListItem.Create;
  inherited Add(d);
  result := d;
end;

function TFileListInfoItems.CheckFile(const Filename: string): Boolean;
begin
  result := False;
  if FileExists(FileName) then result := True;
  if DirectoryExists(FileName) then result := False;
  if ExtractFileName(FileName) = '..' then result := False;
  if ExtractFileName(FileName) = '.' then result := False;
end;

procedure TFileListInfoItems.Clear;
var
  i : Integer;
begin
  for i := 0 to Count-1 do begin
    Files[i].Free;
  end;
  inherited;
end;

procedure TFileListInfoItems.Delete(i: Integer);
begin
  Files[i].Free;
  inherited Delete(i);
end;

function TFileListInfoItems.GetFiles(Index: Integer): TFileInfoListItem;
begin
  result := inherited Items[Index];
end;



function TFileListInfoItems.IndexOfFileNameWriteTime(d: TFileInfoListItem): Integer;
var
  i: Integer;
begin
  result := -1;
  for i := 0 to Count-1 do begin
    if Files[i].FFileName <> d.FFileName then continue;
    if Files[i].FLastWriteTime <> d.FLastWriteTime then continue;
    result := i;
    exit;
  end;
end;

function SortByDate(Item1, Item2: Pointer): Integer;
var
  A, B: TFileInfoListItem;
begin
  A := TFileInfoListItem(Item1);
  B := TFileInfoListItem(Item2);
  if A.LastWriteTime < B.LastWriteTime then
    Result := -1
  else if A.LastWriteTime > B.LastWriteTime then
    Result := 1
  else
    Result := 0;
end;
procedure TFileListInfoItems.SortByLastWriteTime;
begin
  Sort(@SortByDate);
end;

end.
