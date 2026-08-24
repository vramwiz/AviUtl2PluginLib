unit ExplorerListNormal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  ListViewEdit,ListViewEx,Vcl.Menus,System.Generics.Collections,DragAgent,
  Vcl.StdCtrls, Vcl.ExtCtrls,RTTIPersistent,ExplorerFileList,ExplorerListView;



// 標準ファイルの情報　このクラスは拡張しない
type
  TExplorerFileNormalItem = class(TExplorerFileItem)
  private
  protected
  public
  published
  end;

// ファイルリスト
type
  TExplorerFileNormalList = class(TExplorerFileList<TExplorerFileNormalItem>)
	private
		{ Private 宣言 }
    function GetFiles(Index: Integer): TExplorerFileNormalItem;
  protected
    function IsVisibleExtension(const FileName : string) : Boolean;override;
	public
		{ Public 宣言 }
    constructor Create;override;
    destructor Destroy; override;


    property Files[Index : Integer] : TExplorerFileNormalItem read GetFiles;default;
	end;
                                                           // ExplorerListView2
  //TExplorerListViewNormal<T: TExplorerFile2Item, constructor> = class(TListViewThumbnail)
  TExplorerListViewNormal = class(TExplorerListView<TExplorerFileNormalItem>)
  private
    FDrag        : TDragShellFile;
    procedure OnDrag(Sender: TObject;FileNames : TStringList);
    function GetFiles(Index: Integer): TExplorerFileNormalItem;
  protected
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Files[Index : Integer] : TExplorerFileNormalItem read GetFiles;default;
  end;


implementation




{ TExplorerFileNormalList }

constructor TExplorerFileNormalList.Create;
begin
  inherited;
end;

destructor TExplorerFileNormalList.Destroy;
begin

  inherited;
end;

function TExplorerFileNormalList.GetFiles(Index: Integer): TExplorerFileNormalItem;
begin
  Result := inherited Items[Index];
end;

function TExplorerFileNormalList.IsVisibleExtension(
  const FileName: string): Boolean;
begin
  Result := True;
end;

{ TExplorerListViewNormal }

constructor TExplorerListViewNormal.Create(AOwner: TComponent);
begin
  inherited;
  SetThumbnailSize(vsReport,24,24,True);

  FFiles := TExplorerFileNormalList.Create;

  FDrag := TDragShellFile.Create(Self);
  FDrag.Attach(Self);
  FDrag.OnDragRequest := OnDrag;

end;

destructor TExplorerListViewNormal.Destroy;
begin
  FDrag.Free;
  FFiles.Free;
  inherited;
end;

function TExplorerListViewNormal.GetFiles(
  Index: Integer): TExplorerFileNormalItem;
begin
  Result := TExplorerFileNormalItem(FFiles[Index]);
end;

procedure TExplorerListViewNormal.OnDrag(Sender: TObject; FileNames: TStringList);
var
  i : Integer;
  Item : TExplorerFileNormalItem;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  Item := TExplorerFileNormalItem(FFiles[i]);
  if Item = nil  then Exit;

  FileNames.Clear;
  FileNames.Add(Item.FileName);
end;

end.
