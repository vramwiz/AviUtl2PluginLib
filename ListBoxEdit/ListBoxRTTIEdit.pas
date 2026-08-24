unit ListBoxRTTIEdit;

{
==============================================================================
 ListBoxRTTIEdit ユニット概要
==============================================================================

■ 目的
  RTTI対応のデータクラス（TListBoxRTTIItem）と、そのリスト
  （TListBoxRTTIList<T>）を安全かつ簡潔に操作・編集するための
  汎用 ListBox コンポーネントを提供する。

  - Caption の1行編集
  - 追加 / コピー / 削除 / 並び替え
  - RTTI保存クラスとの連携
  - UI とデータの 1:1 対応保証

■ 基本構成（重要）
  Item : TListBoxRTTIItem
  List : TListBoxRTTIList<T>
  UI   : TListBoxRTTIEdit<T>

  ※ T（ジェネリック型）は最後まで同一型を貫くこと。
     キャストや override による型差し替えは行わない。

■ クラス説明
------------------------------------------------------------
● TListBoxRTTIEdit<T>
  - ListBoxEdit を基底とした汎用 RTTI ListBox
  - データの生成・保存は行わず、List に委譲する
  - UI の責務は以下に限定する
      ・表示（Items への反映）
      ・選択・編集
      ・並び替え
      ・削除制御（MinItemCount）
      ・イベント通知

● TListBoxRTTIEditColor<T>
  - TListBoxRTTIEdit<T> に OwnerDraw による描画を追加した派生クラス
  - 色分けや選択表現など、見た目のみを拡張する

■ 使い方（基本）
------------------------------------------------------------
1) Item / List を用意する
   type
     TMyItem = class(TListBoxRTTIItem)
       ...
     end;

     TMyList = class(TListBoxRTTIList<TMyItem>)
     end;

2) UI を生成する（DFM には直接置けない）
   var
     LB : TListBoxRTTIEdit<TMyItem>;
   begin
     LB := TListBoxRTTIEdit<TMyItem>.Create(Self);
     LB.Parent := SomeParent;
     LB.ShowList(MyList);
   end;

   ※ DFM に配置したい場合は
      class(TListBoxRTTIEdit<TMyItem>) の派生クラスを作成する。

■ ShowList について（重要）
------------------------------------------------------------
  ShowList(List) は以下を行う：
    - 内部の FList に List を保持
    - List の内容を Items に AddObject で反映
    - Items.Object[Index] と FList[Index] は常に同一オブジェクト

  ※ Items.Add / Delete は UI 側の責務
     データの生成・破棄は必ず List 経由で行う。

■ Item 操作メソッドの方針
------------------------------------------------------------
  ItemNew   : List.AddNew / InsertNew を使用（UI で new しない）
  ItemCopy  : RTTI Assign により複製
  ItemDelete: MinItemCount を考慮しつつ削除
  ItemUp/Down:
              List.Exchange と Items.Exchange を同期して実行

■ 削除イベントについて
------------------------------------------------------------
  OnDeleteItem は、
    - データ削除直前 / 直後の後処理
    - 関連ファイル削除など
  を外部に委ねるための通知用イベント。

■ 設計上の注意（忘れやすい点）
------------------------------------------------------------
  ・ジェネリック制約は派生クラスでも弱めない
  ・戻り値型は T を使い、TListBoxRTTIItem に戻さない
  ・UI はデータの意味を知らない
  ・RTTI保存処理は List 側の責務

■ このユニットの立ち位置
------------------------------------------------------------
  「RTTI保存クラス × 編集可能 ListBox」を使い回すための
  基盤ユニット。

  個別用途の ListBox は、本ユニットを継承して作成する。

==============================================================================
}

interface

uses
  System.Classes, System.SysUtils, Winapi.Windows,
  Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Vcl.Menus,System.Generics.Collections,
  ListBoxEdit,RTTIPersistent,ListBoxRTTIList,ConfirmDialogForm;

type TListBoxRTTIEditDeleteEvent = procedure(Sender : TObject;Item : TListBoxRTTIItem) of object;


type
  //===========================================================
  // RTTI対応・1行編集用の汎用 ListBox（データは TListBoxRTTIList<T> と同期）
  //===========================================================
  TListBoxRTTIEdit<T: TListBoxRTTIItem, constructor> = class(TListBoxEdit)
  private
    FDialog         : TFormConfirmDialog;          // 削除確認用ダイアログ
    FList           : TListBoxRTTIList<T>;         // 表示・操作対象となるデータリスト
    FMinItemCount   : Integer;                     // 最低限残す必要のあるアイテム数
    FDefaultCaption : string;                      // 新規追加で表示するキャプション
    FOnDeleteItem   : TListBoxRTTIEditDeleteEvent;
    FOnDataChange: TNotifyEvent; // 削除時に通知するイベント
  protected
    // 削除処理完了時にイベントを発火させる内部処理
    procedure DoDeleteItem(Item : TListBoxRTTIItem);
    procedure DoEdited(Index: Integer; var NewText: string); override;
    // データ変更イベント
    procedure DoDataChange();
  public
    // コンポーネント生成（確認ダイアログの生成を含む）
    constructor Create(AOwner: TComponent); override;
    // コンポーネント破棄（内部で生成したオブジェクトの解放）
    destructor Destroy; override;

    // 指定された RTTI リストを ListBox に表示・同期する
    procedure ShowList(List: TListBoxRTTIList<T>);

    // 新規アイテムを生成してリストに追加（または選択位置に挿入）
    function ItemNew() : T;
    // 選択中アイテムをコピーして直後に挿入
    function ItemCopy() : T;

    // 選択中のアイテムを削除（最低件数チェックあり）
    procedure ItemDelete(); virtual;
    // 選択中のアイテムを1つ上へ移動
    procedure ItemUp(); virtual;
    // 選択中のアイテムを1つ下へ移動
    procedure ItemDown();
    procedure ItemReName();
    property DefaultCaption : string write FDefaultCaption;
    // 削除時に最低限保持するアイテム数
    property MinItemCount : Integer read FMinItemCount write FMinItemCount;
    // アイテム削除時に呼び出されるイベント
    property OnDeleteItem : TListBoxRTTIEditDeleteEvent read FOnDeleteItem write FOnDeleteItem;
    property OnDataChange : TNotifyEvent read FOnDataChange write FOnDataChange;
  end;

type
  //===========================================================
  // 色付き描画対応の RTTI ListBox（OwnerDraw 拡張）
  //===========================================================
  TListBoxRTTIEditColor<T: TListBoxRTTIItem, constructor> =class(TListBoxRTTIEdit<T>)
  protected
    // ListBox の1行分を描画する（OwnerDraw）
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    // 行背景の描画（選択状態・交互色など）
    procedure DrawItemBackground(Canvas: TCanvas; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    // テキスト描画処理
    procedure DrawTextOut(Canvas: TCanvas; Rect: TRect; State: TOwnerDrawState; const str: string);
  public
    { Public 宣言 }
  end;

const
  COLOR_CURSOL = clNavy;

implementation

uses AviUtl2StyleColors;

{ TListBoxRTTIEdit }

constructor TListBoxRTTIEdit<T>.Create(AOwner: TComponent);
begin
  inherited;
  FDialog := TFormConfirmDialog.Create(Self);

end;

destructor TListBoxRTTIEdit<T>.Destroy;
begin
  FDialog.Free;

  inherited;
end;

procedure TListBoxRTTIEdit<T>.ItemDelete;
var
  SelIdx  : TList<Integer>;
  i, idx  : Integer;
  BaseIdx : Integer;
  Item    : TListBoxRTTIItem;
begin
  if FDialog.Execute(string('削除しますか？')) <> mrOk then Exit;

  SelIdx := TList<Integer>.Create;
  try
    // 選択インデックス収集
    for i := 0 to Items.Count - 1 do
      if Selected[i] then SelIdx.Add(i);

    if SelIdx.Count = 0 then Exit;

    // 最低件数を下回る場合は削除不可
    if Items.Count - SelIdx.Count < MinItemCount then Exit;

    // 再表示基準（最初の選択）
    BaseIdx := SelIdx[0];

    // 後ろから削除（ソート不要）
    for i := SelIdx.Count - 1 downto 0 do begin
      idx := SelIdx[i];

      Item := FList[idx];

      Item.DeleteItem();
      DoDeleteItem(Item);
      FList.Delete(idx);
      Items.Delete(idx);
    end;
    FList.SaveToFile;

    // 再表示インデックス補正
    if BaseIdx >= Items.Count then
      BaseIdx := Items.Count - 1;

    if BaseIdx < 0 then  Exit;

    ItemIndex := BaseIdx;
    TopIndex  := BaseIdx;

  finally
    SelIdx.Free;
  end;
end;

procedure TListBoxRTTIEdit<T>.ItemDown;
var
  i : Integer;
begin
  i := ItemIndex;
  if i = -1 then exit;
  if i+1 >= Items.Count then exit;
  FList.Exchange(i,i+1);
  Items.Exchange(i,i+1);
  ItemIndex := i + 1;
  TopIndex := ItemIndex;        // カーソルが表示されるようにスクロール
  //FList.SaveToFile();
  DoDataChange;
end;

function TListBoxRTTIEdit<T>.ItemNew: T;
var
  i : Integer;
  Item : T;
begin
  i := ItemIndex;
  if i = -1 then begin
    Item := FList.AddNew();
    Item.Caption := FDefaultCaption;
    Items.AddObject(Item.Caption,Item);
  end
  else begin
    Item := FList.InsertNew(i);
    Item.Caption := FDefaultCaption;
    Items.InsertObject(i,Item.Caption,Item);
  end;
  //FList.SaveToFile;
  DoDataChange;
  Result := Item;
end;

procedure TListBoxRTTIEdit<T>.ItemReName;
begin
  BeginEdit(ItemIndex);
end;

function TListBoxRTTIEdit<T>.ItemCopy: T;
var
  i : Integer;
  Item : TListBoxRTTIItem;
begin
  Result := nil;
  i := ItemIndex;
  if i = -1 then Exit;
  Item := FList[i];
  Result := FList.InsertNew(i+1);

  Result.Assign(Item);
  Result.Caption := Result.Caption + '（コピー）';

  Items.InsertObject(i+1,Result.Caption,Result);
  FList.SaveToFile;
  DoDataChange;
end;


procedure TListBoxRTTIEdit<T>.ItemUp;
var
  i : Integer;
begin
  i := ItemIndex;
  if i = -1 then exit;
  if i-1 < 0 then exit;
  FList.Exchange(i,i-1);
  Items.Exchange(i,i-1);
  ItemIndex := i - 1;
  TopIndex := ItemIndex;        // カーソルが表示されるようにスクロール
  //FList.SaveToFile();
  DoDataChange;
end;

procedure TListBoxRTTIEdit<T>.ShowList(List: TListBoxRTTIList<T>);
var
  i : Integer;
  Item : TListBoxRTTIItem;
begin
  FList := List;
  Items.BeginUpdate;
  Clear;
  for i := 0 to FList.Count-1 do begin
    Item := FList[i];
    Items.AddObject(Item.Caption,Item);
  end;
  Items.EndUpdate;
end;

procedure TListBoxRTTIEdit<T>.DoDataChange;
begin
  if Assigned(FOnDataChange) then FOnDataChange(Self);
end;

procedure TListBoxRTTIEdit<T>.DoDeleteItem(Item: TListBoxRTTIItem);
begin
  if Assigned(FOnDeleteItem) then FOnDeleteItem(Self,Item);
end;


procedure TListBoxRTTIEdit<T>.DoEdited(Index: Integer; var NewText: string);
var
  i : Integer;
  Item : TListBoxRTTIItem;
begin
  i := Index;
  if i = -1 then Exit;
  Item := FList[i];
  if Item = nil then Exit;
  Item.Caption := NewText;
  Items.Strings[i] :=  NewText;
  //FList.SaveToFile();
  DoDataChange;
  inherited;
end;

{ TListBoxRTTIEditColor }
procedure TListBoxRTTIEditColor<T>.DrawItem(Index: Integer; Rect: TRect;State: TOwnerDrawState);
var
  cv : TCanvas;
  s :string;
begin
  cv := Canvas;
  DrawItemBackground(cv,Index,Rect,State);
  s := Items.Strings[Index];
  DrawTextOut(cv,Rect,State,s);
end;


procedure TListBoxRTTIEditColor<T>.DrawItemBackground(Canvas: TCanvas;Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  cv : TCanvas;
  cF,cB : TColor;
  m : Integer;
begin
  cv := Canvas;

  // 3行周期の背景
  m := Index mod 3;

  if m = 0 then
    cB := A2SCListBoxBackground
  else if m = 1 then
    cB := A2SCListBoxAltBackground
  else
    cB := A2SCListBoxAltBackground2;

  cF := Font.Color;

  // 選択状態
  if (odSelected in State) then
  begin
    cB := A2SCListBoxSelection;
    cF := A2SCListBoxSelectionText;
  end;

  cv.Brush.Color := cB;
  cv.Font.Color  := cF;
  cv.Pen.Color   := A2SCListBoxBorder;

  cv.FillRect(Rect);
end;

procedure TListBoxRTTIEditColor<T>.DrawTextOut(Canvas: TCanvas; Rect: TRect;State: TOwnerDrawState; const str: string);
var
  cv : TCanvas;
  PrevStyle: TBrushStyle;
begin
  cv := Canvas;
  cv.Font.Color  := Font.Color;
  if (odFocused in State) or (odSelected in State)  then begin
    Canvas.Brush.Color := COLOR_CURSOL ;
    Canvas.Font.Color  := clWhite;
  end;
  PrevStyle := cv.Brush.Style;
  cv.Brush.Style := bsClear;
  try
    cv.TextRect(Rect,Rect.Left+5,Rect.Top+3,str);
  finally
    cv.Brush.Style := PrevStyle;
  end;
end;

end.
