unit ExplorerFolderList;

// フォルダごとのファイル一覧を管理する

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  ListViewEdit,ListViewEx,Vcl.Menus,System.Generics.Collections,
  Vcl.StdCtrls, Vcl.ExtCtrls,RTTIPersistentIni;


// ファイルの情報　これを継承して他の要素を追加
type
  TExplorerFolderItem = class(TRTTIPersistentIni)
  private
    FFolderName    : string;          // ファイル名
    FName          : string;          // 表示する名称
    FFileName      : string;          //Ini ファイル名
  protected
  public
  published
    property FolderName :string read FFolderName write FFolderName;
    property Name :string read FName write FName;
    property FileName :string read FFileName write FFileName;
  end;

// フォルダリスト
type
  TExplorerFolderList = class(TRTTIPersistentIniList<TExplorerFolderItem>)
	private
		{ Private 宣言 }
    function GetFolders(Index: Integer): TExplorerFolderItem;
  protected
    // 下位で継承してファイルリストクラスを生成して返す
	public
		{ Public 宣言 }
    // フォルダ名が一致するインデックス取得
    function IndexOfFolderName(const FolderName : string) : Integer;
    property Folders[Index : Integer] : TExplorerFolderItem read GetFolders;default;
	end;


implementation

{ TExplorerFolderList }

function TExplorerFolderList.GetFolders(Index: Integer): TExplorerFolderItem;
begin
  Result := Inherited items[Index];
end;

function TExplorerFolderList.IndexOfFolderName(const FolderName: string): Integer;
var
  i : Integer;
begin
  Result := -1;
  for i := 0 to Count-1 do begin
    if Folders[i].FFolderName = FolderName then Exit(i);
  end;
end;

end.
