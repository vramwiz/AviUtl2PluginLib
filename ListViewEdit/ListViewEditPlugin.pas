unit ListViewEditPlugin;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Controls, Vcl.Graphics,
  ListViewEx, ListViewRTTIList;

// プラグイン変更イベント
type
  TListViewEditPluginChanged = procedure(Sender: TObject; const EditStr: string) of object;

//--------------------------------------------------------------------------//
//  外部編集プラグインの基礎クラス（互換性維持）                           //
//--------------------------------------------------------------------------//
type
  TListViewEditPlugin = class(TPersistent)
  private
    FId           : Integer;                 // プラグインID
    FParent       : TWinControl;             // 親コンポーネント（編集配置用）
    FOnEdited     : TListViewEditPluginChanged;  // 編集完了
    FOnEditCancel : TNotifyEvent;            // 編集キャンセル
  protected
    // 要素描画
    procedure DoDraw(Canvas: TCanvas; r: TRect; dr: TListViewRowItem); virtual;
    // 編集開始
    procedure DoEditing(Parent: TWinControl; var Component: TWinControl;
                        r: TRect; dr: TListViewRowItem); virtual; abstract;
    // 編集完了
    procedure DoEdited(const EditStr: string); virtual;
    // 編集キャンセル
    procedure DoEditCancel; virtual;
  public
    constructor Create; virtual;
    // 描画呼び出し
    procedure Draw(Canvas: TCanvas; r: TRect; dr: TListViewRowItem);

    property Id           : Integer read FId;
    property Parent       : TWinControl read FParent;
    property OnEdited     : TListViewEditPluginChanged read FOnEdited write FOnEdited;
    property OnEditCancel : TNotifyEvent read FOnEditCancel write FOnEditCancel;
  end;

// 継承クラス型を受け取るための型
type
  TListViewEditPluginClass = class of TListViewEditPlugin;

//--------------------------------------------------------------------------//
//  プラグイン登録アイテム（1リストで管理する）                           //
//--------------------------------------------------------------------------//
type
  TListViewEditPluginItem = class
  private
    FId          : Integer;                       // プラグインID
    FPluginClass : TListViewEditPluginClass;      // クラス型（未生成）
    FInstance    : TListViewEditPlugin;           // 生成済インスタンス（必要時のみ）
  public
    constructor Create;
    destructor Destroy; override;

    procedure ClearInstance;

    property Id          : Integer read FId write FId;
    property PluginClass : TListViewEditPluginClass read FPluginClass write FPluginClass;
    property Instance    : TListViewEditPlugin read FInstance write FInstance;
  end;

//--------------------------------------------------------------------------//
//  プラグイン管理クラス                                                    //
//--------------------------------------------------------------------------//
type
  TListViewEditPluginList = class(TObjectList<TListViewEditPluginItem>)
  private
    FOnSettingInstance: TNotifyEvent;
  protected
    procedure DoSettingInstance(Instance : TObject);virtual;
  public
    constructor Create;
    destructor Destroy; override;
    function RegisterPlugin(AClass: TListViewEditPluginClass): Integer;
    function CreateInstance(const ID : Integer) : TListViewEditPluginItem;
    procedure BeginEdit(Parent: TWinControl; var Component: TWinControl;
                        EditId: Integer; r: TRect; dr: TListViewRowItem;
                        AOnEdited: TListViewEditPluginChanged;
                        AOnEditCancel: TNotifyEvent);
    procedure ClearInstances;
    procedure Clear;

    property OnSettingInstance : TNotifyEvent read FOnSettingInstance write FOnSettingInstance;
  end;

// グローバル管理
var
  ListViewEditPlugins: TListViewEditPluginList;

implementation


constructor TListViewEditPlugin.Create;
begin
   inherited Create;
end;

//--------------------------------------------------------------------------//
//  TListViewEditPlugin（基底クラス：継承側互換用）                         //
//--------------------------------------------------------------------------//

procedure TListViewEditPlugin.DoDraw(Canvas: TCanvas; r: TRect; dr: TListViewRowItem);
begin
  Canvas.TextRect(r, r.Left + 2, r.Top + 2, dr.Value);
end;

procedure TListViewEditPlugin.DoEdited(const EditStr: string);
begin
  if Assigned(FOnEdited) then
    FOnEdited(Self, EditStr);
end;

procedure TListViewEditPlugin.DoEditCancel;
begin
  if Assigned(FOnEditCancel) then
    FOnEditCancel(Self);
end;

procedure TListViewEditPlugin.Draw(Canvas: TCanvas; r: TRect; dr: TListViewRowItem);
begin
  DoDraw(Canvas, r, dr);
end;

//--------------------------------------------------------------------------//
//  TListViewEditPluginItem                                                 //
//--------------------------------------------------------------------------//

constructor TListViewEditPluginItem.Create;
begin
  inherited Create;
  FId          := -1;
  FPluginClass := nil;
  FInstance    := nil;
end;

destructor TListViewEditPluginItem.Destroy;
begin
  ClearInstance;
  inherited;
end;

procedure TListViewEditPluginItem.ClearInstance;
begin
  if FInstance <> nil then
  begin
    FInstance.Free;
    FInstance := nil;
  end;
end;

//--------------------------------------------------------------------------//
//  TListViewEditPluginList                                                 //
//--------------------------------------------------------------------------//

constructor TListViewEditPluginList.Create;
begin
  inherited Create(True); // OwnsObjects = True
end;

destructor TListViewEditPluginList.Destroy;
begin
  inherited;
end;

procedure TListViewEditPluginList.DoSettingInstance(Instance : TObject);
begin
  if Assigned(FOnSettingInstance) then FOnSettingInstance(Instance);
end;

function TListViewEditPluginList.RegisterPlugin(AClass: TListViewEditPluginClass): Integer;
var
  Item: TListViewEditPluginItem;
begin
  Item := TListViewEditPluginItem.Create;
  Item.Id := Count;
  Item.PluginClass := AClass;

  Add(Item);

  Result := Item.Id;
end;

procedure TListViewEditPluginList.ClearInstances;
var
  Item: TListViewEditPluginItem;
begin
  for Item in Self do
    Item.ClearInstance;
end;

procedure TListViewEditPluginList.Clear;
begin
  inherited; // 登録情報ごと破棄（finalization）
end;

function TListViewEditPluginList.CreateInstance(const ID: Integer) : TListViewEditPluginItem;
var
  Item: TListViewEditPluginItem;
begin
  Item := Items[ID];

  // 新しいインスタンスを生成
  Item.Instance := Item.PluginClass.Create;
  Item.Instance.FId := Item.Id;

  Result := Item;
end;

procedure TListViewEditPluginList.BeginEdit(Parent: TWinControl;
  var Component: TWinControl; EditId: Integer; r: TRect; dr: TListViewRowItem;
  AOnEdited: TListViewEditPluginChanged; AOnEditCancel: TNotifyEvent);
var
  Item: TListViewEditPluginItem;
begin
  if (EditId < 0) or (EditId >= Count) then Exit;

  // 既存インスタンスを破棄
  ClearInstances;

  Item := CreateInstance(EditId);

  Item.Instance.FParent := Parent;
  DoSettingInstance(Item.Instance);
  Item.Instance.OnEdited := AOnEdited;
  Item.Instance.OnEditCancel := AOnEditCancel;

  // 編集開始
  Item.Instance.DoEditing(Parent, Component, r, dr);
end;

initialization
  //ListViewEditPlugins := TListViewEditPluginList.Create;

finalization
  //ListViewEditPlugins.Free;

end.


