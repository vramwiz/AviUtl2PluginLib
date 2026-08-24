unit ExplorerFileList;

// フォルダごとのファイル一覧を管理する

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  ListViewEdit,ListViewEx,Vcl.Menus,System.Generics.Collections,
  Vcl.StdCtrls, Vcl.ExtCtrls,RTTIPersistentIni;

// ファイルの基本情報。これを継承して他の要素を追加する
type
  TExplorerFileItem = class(TRTTIPersistentIni)
  private
    FFileName    : string;          // ファイル名
    FName        : string;          // 表示名
  protected
  public
  published
    property FileName :string read FFileName write FFileName;
    property Name :string read FName write FName;
  end;

// ファイルリスト
type
  TExplorerFileList<T: TExplorerFileItem, constructor> =class(TRTTIPersistentIniList<T>)
	private
		{ Private 宣言 }
    function GetFiles(Index: Integer): TExplorerFileItem;
  protected
    FExtensions : TStringList;      // 表示対象の拡張子リスト
    // 下位で継承してファイル情報クラスを生成して返す
    //function DoCreate() : TRTTIPersistentIni;override;
    // 一覧へ出したくないファイルを除外する
    function IsExcludedFile(const FileName: string): Boolean; virtual;
    // 「.psd」などの拡張子が表示対象かどうかを判定
    function IsVisibleExtension(const FileName : string) : Boolean;virtual;

	public
		{ Public 宣言 }
    constructor Create;virtual;
    destructor Destroy; override;
    function IndexOfFileName(FileName : string) : Integer;
    // 拡張子に一致するファイル数を返す
    function GetExtensionScore(FileNames : TStringList) :Integer;
    // ファイル一覧を追加
    procedure AddFiles(FileNames : TStringList);virtual;
    procedure DelFiles(FileNames : TStringList);virtual;
    property Files[Index : Integer] : TExplorerFileItem read GetFiles;default;
	end;

implementation


{ TExplorerFileList }

constructor TExplorerFileList<T>.Create;
begin
  inherited;
  FExtensions := TStringList.Create;
end;

destructor TExplorerFileList<T>.Destroy;
begin
  FExtensions.Free;
  inherited;
end;

procedure TExplorerFileList<T>.AddFiles(FileNames: TStringList);
var
  i, j : Integer;
  Item : TExplorerFileItem;
  Exists : Boolean;
  s : string;
begin
  {--------------------------------------------
    ① 実ファイルに存在しない項目を削除
  --------------------------------------------}
  i := Count - 1;
  while i >= 0 do
  begin
    Item := Files[i];
    // 表示対象外のファイルは保存リストからも除外する
    if IsExcludedFile(Item.FileName) then
    begin
      Delete(i);
      Dec(i);
      Continue;
    end;
    Exists := False;
    for j := 0 to FileNames.Count - 1 do
    begin
      if FileNames[j] = Item.FileName then
      begin
        Exists := True;             // 実ファイルに存在する
        Break;
      end;
    end;
    if not Exists then
      Delete(i);                    // 実ファイルに無いので削除
    Dec(i);
  end;

  {--------------------------------------------
    ② 実ファイルに存在し、リストに無いものを追加
  --------------------------------------------}
  for j := 0 to FileNames.Count - 1 do
  begin
    s := FileNames[j];
    // 表示対象外のファイルは一覧へ追加しない
    if IsExcludedFile(s) then Continue;
    if not IsVisibleExtension(s) then Continue;                 // 対象外の拡張子なので無視
    if IndexOfFileName(s) <> -1 then Continue;                  // すでにリストに存在する

    Item := TExplorerFileItem(AddNew);
    Item.FileName := s;             // 実ファイル名を登録
    Item.Name := ChangeFileExt(ExtractFileName(s), ''); // 表示名を生成
  end;
end;


procedure TExplorerFileList<T>.DelFiles(FileNames: TStringList);
begin

end;
{
function TExplorerFileList<T>.DoCreate: TRTTIPersistentIni;
begin
  Result := TRTTIPersistentIni(TExplorerFileItem.Create);
end;
}

function TExplorerFileList<T>.GetFiles(Index: Integer): TExplorerFileItem;
begin
  Result := inherited Items[Index];
end;

function TExplorerFileList<T>.GetExtensionScore(FileNames : TStringList): Integer;
var
  i : Integer;
  s: string;
begin
  Result := 0;
  for i := 0 to FileNames.Count-1 do begin
    s := FileNames[i];
    if IsVisibleExtension(s) then Result := Result + 1;
  end;
end;

function TExplorerFileList<T>.IndexOfFileName(FileName: string): Integer;
var
  i : Integer;
begin
  Result := -1;
  for i := 0 to Count-1 do begin
    if Files[i].FileName <> FileName then COntinue;
    Result := i;
  end;
end;

function TExplorerFileList<T>.IsExcludedFile(const FileName: string): Boolean;
begin
  // L-SMASH Works が生成する .lwi は一覧対象から除外
  Result := SameText(ExtractFileExt(FileName), '.lwi');
end;

function TExplorerFileList<T>.IsVisibleExtension(const FileName: string): Boolean;
var
  i : Integer;
  se : string;
begin
  se := ExtractFileExt(FileName);
  se := LowerCase(se);
  i := FExtensions.IndexOf(se);
  Result :=(i <> -1);
end;


end.
