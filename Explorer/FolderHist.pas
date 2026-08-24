unit FolderHist;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,System.StrUtils,ComCtrls,RTTIPersistentIni,
  System.Generics.Collections;

// フォルダの履歴管理するクラス
type
  TFolderHistItem = class(TRTTIPersistentIni)
  private
    FFolderName: string;
  public

  published
    property FolderName:  string read FFolderName  write FFolderName;
  end;

type
	TFolderHistItems  = class(TRTTIPersistentIniList<TFolderHistItem>)
	private
  protected
	public
		{ Public 宣言 }
    procedure AddHist(const FolderName : string);
    function IndexOfFolderName(const FolderName : string) : Integer;
	end;


implementation

uses System.RegularExpressions;

{ TFolderHistItems }


procedure TFolderHistItems.AddHist(const FolderName: string);
var
  i: Integer;
  Hist: TFolderHistItem;
  MaxHistCount: Integer;
begin
  i := IndexOfFolderName(FolderName);
  if i >= 0 then
    Delete(i); // すでにある → 一度削除（順番更新）

  // 新規作成して先頭に追加
  Hist := InsertNew(0); // ← AddNew ではなく先頭に追加したいなら Insert(0)
  Hist.FolderName := FolderName;

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

function TFolderHistItems.IndexOfFolderName(const FolderName: string): Integer;
var
  i: Integer;
begin
  result := -1;
  for i := 0 to Count-1 do begin
    if LowerCase(Trim(Items[i].FFolderName)) <> LowerCase(Trim(FolderName)) then continue;
    result := i;
    exit;
  end;
end;

end.
