unit ProjectManagerListBox;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,ProjectManager,ListBoxEdit,
  Vcl.Menus, System.ImageList, Vcl.ImgList, Vcl.ComCtrls, Vcl.ToolWin,ConfirmDialogForm,
  ShortcutAction;

type
  TProjectManagerListBoxBase = class(TListBoxEditColor)
  private
  protected
    function GetFileNames(Index: Integer): string; virtual;abstract;
    procedure SetFileNames(Index: Integer; const Value: string);virtual;abstract;

  public
    procedure ItemAdd();virtual;abstract;
    procedure ItemCopy();virtual;abstract;
    procedure ItemDelete();virtual;abstract;
    procedure ItemReName();virtual;abstract;
    procedure ItemUp();virtual;abstract;
    procedure ItemDown();virtual;abstract;

    procedure SaveToFile;virtual;abstract;
    property FileNames[Index : Integer] : string read GetFileNames write SetFileNames;
  end;


type

  TProjectManagerListBox<T: TProjectInfo, constructor> = class(TProjectManagerListBoxBase)
  private

  protected
    FProjects      :  TProjectManager<T>;    // プロジェクトリスト
    FDialog        : TFormConfirmDialog;     // 独自ダイアログ
    FShortcuts     : TShortcutAction;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;

    procedure Resize; override;
    procedure DoStartEdit();
    procedure DoEndEdit(AEditIndex : Integer;Apply: Boolean);override;
    procedure CNNotify(var Msg: TWMNotify); message CN_NOTIFY;
    // 範囲が異なるため下位にて値を確定
    procedure SetZoomIndex(const Value: Integer);virtual;
    function GetFileNames(Index: Integer): string; override;
    procedure SetFileNames(Index: Integer; const Value: string);override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ShowList(Item : T);
    procedure SaveToFile;override;

    procedure ItemAdd();override;
    procedure ItemCopy();override;
    procedure ItemDelete();override;
    procedure ItemReName();override;
    procedure ItemUp();override;
    procedure ItemDown(); override;

    property  Projects     : TProjectManager<T> read FProjects write FProjects;
  end;


implementation

{ TProjectManagerListBox<T> }

constructor TProjectManagerListBox<T>.Create(AOwner: TComponent);
begin
  inherited;
  FDialog := TFormConfirmDialog.Create(Self);

  FShortcuts := TShortcutAction.Create;
  FShortcuts.Add(VK_UP  ,[ssCtrl],ItemUp);
  FShortcuts.Add(VK_DOWN,[ssCtrl],ItemDown);
  FShortcuts.Add(VK_F2,[],ItemRename);
  FShortcuts.Add(Ord('D'),[ssCtrl],ItemAdd);
  FShortcuts.Add(Ord('C'),[ssCtrl],ItemCopy);
  FShortcuts.Add(VK_DELETE,[],ItemDelete);
end;

destructor TProjectManagerListBox<T>.Destroy;
begin
  FShortcuts.Free;
  FDialog.Free;
  inherited;
end;

procedure TProjectManagerListBox<T>.DoEndEdit(AEditIndex : Integer;Apply: Boolean);
var
  i : Integer;
  Item : TProjectInfo;
begin
  i := AEditIndex;
  inherited;
  if not Apply then Exit;
  if i = -1 then Exit;
  Item := FProjects[i];
  if Item = nil then Exit;
  Item.ProjectName := Items.Strings[i];
  FProjects.SaveToFile;
end;

procedure TProjectManagerListBox<T>.DoStartEdit;
begin

end;

function TProjectManagerListBox<T>.GetFileNames(Index: Integer): string;
begin

end;

procedure TProjectManagerListBox<T>.ItemAdd;
var
  Item : TProjectInfo;
  i : Integer;
begin

  i := ItemIndex;                                // カーソル位置を取得
  if i = -1 then begin                           // カーソルが無い場合
    Item := FProjects.ProjectAdd();              // 一番下に追加
    Item.ProjectName := '新しいプロジェクト';
    Items.AddObject(Item.ProjectName,Item);
    ItemIndex := Items.Count-1;                  // 追加したリストにカーソルを合わせる
    TopIndex := ItemIndex;                       // カーソルが表示されるようにスクロール
  end
  else begin                                     // 選択中の場合
    Item := FProjects.ProjectInsert(i);          // 途中に追加
    Item.ProjectName := '新しいプロジェクト';
    Items.InsertObject(i,Item.ProjectName,Item);
    ItemIndex :=  i;                             // 追加したリストにカーソルを合わせる
    TopIndex := ItemIndex;                       // カーソルが表示されるようにスクロール
  end;
  FProjects.SaveToFile();
end;

procedure TProjectManagerListBox<T>.ItemCopy;
var
  ddf,ddt : TProjectInfo;
  i : Integer;
begin
  i := ItemIndex;                                   // カーソル位置を取得
  if i = -1 then exit;                              // キャラが未選択であれば処理終了
  ddf := FProjects[i];
  ddt := FProjects.ProjectInsert(i+1);              // 一番下に追加

  ddt.ProjectName := ddf.ProjectName + '(コピー)';  // 名称にコピーを追加
  Items.InsertObject(i+1,ddt.ProjectName,ddt);

  ItemIndex := i + 1;                               // カーソル位置を追加したデータに移動
  TopIndex := ItemIndex;                            // カーソルが表示されるようにスクロール
  FProjects.SaveToFile();
  FProjects.ProjectCopy(i+1,i);
end;

procedure TProjectManagerListBox<T>.ItemDelete;
var
  i : Integer;
begin
  if FDialog.Execute('削除しますか？') <> mrOk then Exit;
  i := ItemIndex;
  if i = -1 then exit;
  FProjects.ProjectDelete(i);
  Items.Delete(i);
  ItemIndex := i - 1;
  TopIndex := ItemIndex;        // カーソルが表示されるようにスクロール
  FProjects.SaveToFile();
end;

procedure TProjectManagerListBox<T>.ItemReName;
begin
   BeginEdit(ItemIndex);
end;

procedure TProjectManagerListBox<T>.ItemUp;
var
  i : Integer;
begin
  i := ItemIndex;
  if i = -1 then exit;
  if i-1 < 0 then exit;
  FProjects.Exchange(i,i-1);
  Items.Exchange(i,i-1);
  ItemIndex := i - 1;
  TopIndex := ItemIndex;        // カーソルが表示されるようにスクロール
  FProjects.SaveToFile();
end;

procedure TProjectManagerListBox<T>.ItemDown;
var
  i : Integer;
begin
  i := ItemIndex;
  if i = -1 then exit;
  if i+1 >= Items.Count then exit;
  FProjects.Exchange(i,i+1);
  Items.Exchange(i,i+1);
  ItemIndex := i + 1;
  TopIndex := ItemIndex;        // カーソルが表示されるようにスクロール
  FProjects.SaveToFile();
end;

procedure TProjectManagerListBox<T>.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  FShortcuts.KeyDown(Key,Shift);
end;

procedure TProjectManagerListBox<T>.Resize;
begin
  inherited;

end;

procedure TProjectManagerListBox<T>.SaveToFile;
begin
  FProjects.SaveToFile;
end;

procedure TProjectManagerListBox<T>.SetFileNames(Index: Integer;
  const Value: string);
begin

end;

procedure TProjectManagerListBox<T>.SetZoomIndex(const Value: Integer);
begin

end;

procedure TProjectManagerListBox<T>.ShowList(Item: T);
begin

end;

procedure TProjectManagerListBox<T>.CNNotify(var Msg: TWMNotify);
begin

end;



end.
