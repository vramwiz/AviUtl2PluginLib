unit ListViewRTTI;
{
  ListViewRTTI.pas
  ---------------------------------------------------------------------------
  実行時型情報 (RTTI) に基づいた編集対応 ListView コンポーネント
  TListViewRTTI を定義するユニット。

  本クラスは TListViewEdit を継承し、任意のオブジェクトから RTTI により
  プロパティ情報を取得し、それを ListView 上に自動表示・編集可能にします。

  主な機能：
    - LoadFromObject により、TObject 派生クラスのプロパティをリスト表示
    - セル編集時の値は、該当オブジェクトのプロパティに反映される
    - 任意の表示列を追加する AddCaption メソッドを提供
    - 編集完了時に通知される OnDataChange イベントを装備
    - 編集時の内部処理は DoChange をオーバーライドして制御

  また、RTTI 項目は RTTINames[プロパティ名] でアクセス可能です。

  本コンポーネントは、設定エディタやデバッグ用の可視化ツールなどにおいて、
  Delphi オブジェクトの状態をそのまま GUI 上で操作したい場面で有効です。
}
interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,ListViewEdit, Vcl.Menus,Vcl.StdCtrls,Vcl.ComCtrls,
  System.TypInfo,ListViewEx,ListViewRTTIList,RTTIPropertyList,Winapi.CommCtrl;

//--------------------------------------------------------------------------//
//  実行時型情報を持つクラスを表示編集するクラス                            //
//--------------------------------------------------------------------------//
type
   TListViewRTTI = class(TListViewEdit)
  private
    { Private 宣言 }
    FPropertys : TRTTIPropertyList;      // RTTI　実行時型情報管理クラス
    FFixedWidth   : Integer;
    FOnDataChange : TNotifyEvent;

    procedure SetColumn();

    procedure SetFixedWidth(const Value: Integer);
    function GetRTTINames(Name: string): TListViewRowItem;

    procedure SetVisibleIndex();
  protected
    // 横スクロールバー非表示
    //procedure UpdateScrollBar;
    procedure DoChanging(var EditStr : string;const aColumn,aIndex : Integer);override;
    procedure DoChange(const EditStr : string;const aColumn,aIndex : Integer);override;
    //procedure DoDataType(const aColumn,aIndex : Integer;var DataType : Integer);virtual;

    // 背景描画
    procedure DrawBackFixed(cv : TCanvas;Item: TListItem;r: TRect; State: TOwnerDrawState);
    procedure DrawBackValue(cv : TCanvas;Item: TListItem;r: TRect; State: TOwnerDrawState);
    procedure DrawItem(Item: TListItem;Rect: TRect; State: TOwnerDrawState);override;

  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;
    // 指定したオブジェクト情報を元に編集画面を作成
    procedure LoadFromObject(aObject : TObject);
    // 値のみ更新
    procedure Refresh();
    procedure Clear;override;
    // 変数名に該当する設定名ヒント編集方法を割り当てる
    function AddCaption(const PName,Caption : string;Hint : string = '';aColor : TColor = clBtnFace;aType : Integer = 2) : TListViewRowItem;


    // 非編集表示の幅を指定
    property FixedWidth : Integer write SetFixedWidth;
    property RTTINames[Name : string] : TListViewRowItem read GetRTTINames;
    //
    property OnDataChange : TNotifyEvent read FOnDataChange write FOnDataChange;
  end;


implementation

uses ListViewEditPluginLib,ListViewEditPlugin,AviUtl2StyleColors;

{ TListViewEditRtti }

//--------------------------------------------------------------------------//
//  クラス生成                                                              //
//--------------------------------------------------------------------------//
constructor TListViewRTTI.Create(AOwner: TComponent);
begin
  inherited;
  FPropertys := TRTTIPropertyList.Create;
  FixedStyle := fsVerticalFixedColumn;
  FFixedWidth := 160;
  ColumnClick := False;
  //GridLines := True;
  RowSelect := True;
  ViewStyle := vsReport;
  ReadOnly := True;
  DoubleBuffered := True;
end;

//--------------------------------------------------------------------------//
//  クラス破棄                                                              //
//--------------------------------------------------------------------------//
destructor TListViewRTTI.Destroy;
begin
  FPropertys.Free;
  inherited;
end;

procedure TListViewRTTI.Clear;
begin
  inherited;
  Items.BeginUpdate();
  try
    SetColumn();
    Items.Clear;
    FRowSettings.Clear;
    FVisibleIndexes.Clear;
  finally
    Items.EndUpdate();
  end;

end;


procedure TListViewRTTI.DrawBackFixed(cv: TCanvas; Item: TListItem; r: TRect;  State: TOwnerDrawState);
var
  i : Integer;
begin
  // ---- 背景塗りつぶし（全面クリア）----
  cv.Brush.Style := bsSolid;
  cv.Brush.Color := Self.Color;

  if Columns.Count = 0 then Exit;

  r.Right := Columns[0].Width;
  r.Bottom := r.Bottom - 1;

  i := FVisibleIndexes[Item.Index];
  if i = -1 then Exit;

  cv.Brush.Style := bsSolid;
  cv.Brush.Color := Settings[i].ColorBack;
  cv.FillRect(r);

  cv.Pen.Width := 1;

  cv.Pen.Color := clWhite;
  cv.MoveTo(r.Left, r.Bottom);
  cv.LineTo(r.Left, r.Top);
  cv.LineTo(r.Right, r.Top);

  cv.Pen.Color := clDkGray;
  cv.LineTo(r.Right, r.Bottom);
  cv.LineTo(r.Left, r.Bottom);
end;

procedure TListViewRTTI.DrawBackValue(cv: TCanvas; Item: TListItem; r: TRect;
  State: TOwnerDrawState);
begin
  if Columns.Count = 0 then Exit;
  r.Left := Columns[0].Width;
  cv.Brush.Color := Self.Color;
  cv.Brush.Style := bsSolid;
  if (odFocused in State) or (odSelected in State)  then begin
    cv.Brush.Color := A2SCListViewSelection;
  end;
  cv.FillRect(r);

end;

procedure TListViewRTTI.DrawItem(Item: TListItem; Rect: TRect;State: TOwnerDrawState);
var
  cv : TCanvas;
  i,j,x,xh,ScrollX : Integer;
  s : string;
  dt : TListViewRowItem;
  r : TRect;
begin
  if not(Canvas.HandleAllocated) or not(Self.HandleAllocated) then exit;

  ScrollX := GetScrollPos(Self.Handle, SB_HORZ);
  cv := TLIstView(Self).Canvas;                   // 描画キャンバス参照

  x := 5;                                           // マージンを指定
  cv.Brush.Style := bsClear;

  xh := 0;

  i := Item.Index;

  for j := 0 to Columns.Count-1 do begin            // 列数ループ
    dt := GetCellRTTI(j,i);                         // 実効値型情報の行を参照
    dt.Value := Cells[j,i];
    ListViewEditPlugins.CreateInstance(dt.EditType);// 該当するプラグインを生成
    r := Rect;                                      // 描画範囲を参照
    r.Left := ColumnLeft(j) - ScrollX;
    if j = 0 then r.Left := r.Left + xh;
    r.Right := ColumnRight(j) - ScrollX - 8;        // 左端マージンを設定

    if j = 0 then begin                             // 左端の表題の場合
      DrawBackFixed(cv,Item,Rect,State);            // カーソルに合わせて背景描画
      cv.Font.Color  := dt.ColorFont;               // 色設定を反映
      //cv.Brush.Color := dt.ColorBack;
      cv.Brush.Style := bsClear;
      s := Item.Caption;

      if dt.Caption<>'' then s := dt.Caption;       // 表題が設定されていれば取得

      cv.TextRect(r,r.Left+x,r.Top+2,s);            // 表題を描画
    end
    else begin                                      // 表題では無い場合
      DrawBackValue(cv,Item,Rect,State);            // カーソルに合わせて背景描画
      cv.Font.Color  := Font.Color;
      cv.Brush.Style := bsClear;

      s := Cells[j, Item.Index];

      // Xオフセットが必要な場合は r.Left := r.Left + x など
      r.Left := r.Left + x;

      // 自動折り返し付き描画
      //DrawTextAutoWrap(cv, r, s);
      dt.Value := FPropertys.Values[dt.PName];         // 値を代入
      ListViewEditPlugins[dt.EditType].Instance.Draw(cv,r,dt);
  end;
    //x := x + Columns[j].Width;                      // 描画位置を次へ
  end;
end;

//--------------------------------------------------------------------------//
//  クラスの値編集表示                                                      //
//--------------------------------------------------------------------------//
procedure TListViewRTTI.LoadFromObject(aObject: TObject);
begin
  FPropertys.LoadFromObject(aObject);
  Items.BeginUpdate();
  try
    Items.Clear;
    //FRowSettings.Clear;
    //FVisibleIndexes.Clear;
    SetVisibleIndex();
    SetColumn();
  finally
    Items.EndUpdate();
  end;
  Refresh();
  Resize();
end;

//--------------------------------------------------------------------------//
//  クラスの値表示更新                                                      //
//--------------------------------------------------------------------------//
procedure TListViewRTTI.Refresh;
var
  i,ii : Integer;
  dl : TListItem;
begin
  Items.BeginUpdate();
  for i := 0 to FVisibleIndexes.Count-1 do begin
    if i >= Items.Count then begin
      dl := Items.Add();
    end
    else begin
      dl := Items[i];
    end;
    ii := FVisibleIndexes[i];
    dl.Caption := '';
    if ii >= FRowSettings.Count then Continue;
    
    if FRowSettings[ii].Caption <> '' then
      dl.Caption := FRowSettings[ii].Caption
    else
      dl.Caption := FRowSettings[ii].PName;
    dl.SubItems.Clear;
    dl.SubItems.Add(FRowSettings[ii].Value);
  end;
  Items.EndUpdate();
  inherited;
end;


function TListViewRTTI.AddCaption(const PName, Caption: string; Hint: string='';aColor : TColor = clBtnFace; aType: Integer= 2) : TListViewRowItem;
var
  dr : TListViewRowItem;
begin
  dr := RTTINames[PName];
  dr.AddCaption(Caption,Hint,aColor,aType);
  result := dr;
end;


function TListViewRTTI.GetRTTINames(Name: string): TListViewRowItem;
var
  i : Integer;
  d : TListViewRowItem;
begin
  i := FRowSettings.IndexOfPName(Name);
  if i <> -1 then begin
    result := FRowSettings[i];
    exit;
  end;
  d := FRowSettings.AddNew();
  d.PName := Name;
  result := d;
end;


//--------------------------------------------------------------------------//
//  固定行の設定                                                            //
//--------------------------------------------------------------------------//
procedure TListViewRTTI.SetColumn;
var
  dc : TListColumn;
begin
  Columns.Clear;                     // カラムを初期化

  dc := Columns.Add;                 // ファイル名の表題を追加
  dc.Caption := '名称';              // 表題の名称を設定
  dc.Width := FFixedWidth;           // 表題の幅を設定

  dc := Columns.Add;                 // ファイル名の表題を追加
  dc.Caption := '値';                // 表題の名称を設定
  AdjustColumnsToHeader();
  ColumnAlign(1);
end;

procedure TListViewRTTI.SetFixedWidth(const Value: Integer);
begin
  FFixedWidth := Value;
  Columns[0].Width := Value;
end;

procedure TListViewRTTI.SetVisibleIndex;
var
  i : Integer;
  Item : TListViewRowItem;
begin
  FVisibleIndexes.Clear;
  for i := 0 to FRowSettings.Count-1 do begin
    Item :=  FRowSettings[i];
    if  Item.EditType = 0 then continue;
    FVisibleIndexes.Add(i);                   // 非表示分を換算
  end;

end;

//--------------------------------------------------------------------------//
//  編集完了イベント                                                        //
//--------------------------------------------------------------------------//
procedure TListViewRTTI.DoChange(const EditStr: string;const aColumn,aIndex : Integer);
var
  dr : TListViewRowItem;
  s : string;
begin
  dr := FRowSettings[FVisibleIndexes[aIndex]];    // 型情報クラス参照
  s := EditStr;                                   // 編集後の値を取得
  FPropertys.Values[dr.PName] := s;
  //FRowSettings.RttiWrite(dr.PName,s);             // 実行時型情報に値を書き込み
  dr.Value := s;                                 // 実行時型情報クラスに書き込み
  Refresh();
  //dr.DoRequestEdited();
  inherited;
  if Assigned(FOnDataChange) then FOnDataChange(Self);

end;



procedure TListViewRTTI.DoChanging(var EditStr: string; const aColumn,
  aIndex: Integer);
var
  dr : TListViewRowItem;
begin
  dr := FRowSettings[FVisibleIndexes[aIndex]];    // 型情報クラス参照
  EditStr := FPropertys.Values[dr.PName];

end;

end.
