unit ListViewEdit;
{
  ListViewEdit.pas
  ---------------------------------------------------------------------------
  セル編集機能付き ListView コンポーネント TListViewEdit を定義するユニット。

  本クラスは TListViewEx を継承し、ListView の各セルに対して
  編集操作を提供する機能を追加しています。
  編集には内部的に TEdit を使用し、編集開始／終了時にはイベントを介して
  ユーザー側に文字列・行・列インデックスを通知します。

  主な機能：
    - セル単位での編集インターフェースの追加（FEditIndex / FEditColumn）
    - 編集時のスタイル制御（TListViewEditFixedStyle）
        ・fsEditOnly               : 編集対象はセルのみ
        ・fsVertical               : 行方向に固定
        ・fsHorizontal             : 列方向に固定
        ・fsVerticalFixedColumn    : 特定列を編集不可に
    - 編集確定／変更中イベントの通知（FOnChange / FOnChanging）
    - 編集対象セルの検出、編集位置の補正、オーナードロー支援

  編集処理の発火や編集領域の調整、固定列／セルの制御など、
  実用的なグリッド編集に近い操作性を ListView で実現することを目的としています。
}
interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,Vcl.ExtCtrls,
  ShellApi,ShlObj,CommCtrl,Menus, ListViewEx,ListViewRTTIList,ListViewEditPlugin;


type
  TListViewEditFixedStyle = (
    fsEditOnly,             // ① 編集のみ（リスト扱いなし）
    fsVertical,             // ② 縦リスト（ListView標準）
    fsHorizontal,           // ③ 横リスト（表計算的な横移動）
    fsVerticalFixedColumn   // ④ 縦リスト＋固定列（1列目を固定）
  );

type TListViewEditChange = procedure(Sender : TObject;const EditStr : string;const aColumn,aIndex : Integer) of object;
type TListViewEditChanging = procedure(Sender : TObject;var EditStr : string;const aColumn,aIndex : Integer) of object;

//--------------------------------------------------------------------------//
//  拡張TListViewクラス ※列要素編集機能を追加                              //
//--------------------------------------------------------------------------//
type
  TListViewEdit = class(TListViewEx)
  private
    { Private 宣言 }

    FEditIndex   : Integer;                        // 編集中の行
    FEditColumn  : Integer;                        // 編集中の列
    FPendingBeginEdit: Boolean;                    // ダブルクリック後に遅延開始する
    FProc        : TWndMethod;                     // スクロールやホイール操作を受け取るハンドル
    FFixedStyle  : TListViewEditFixedStyle;        // 固定行などのレイアウト設定
    FOnChange    : TListViewEditChange;            //
    FOnChanging  : TListViewEditChanging;
    FEdited: Boolean;
    FOnSettingInstance: TNotifyEvent;          //

    // マウスカーソル上の列を取得
    function GetColumn: Integer;
    function GetColumnRect(Index: Integer; out ALeft, ARight: Integer): Boolean;
    // 表示中の先頭行位置を取得
    function TopIndex() : Integer;
    function GetMouseClientPos: TPoint;
    function IsFixedCell(aCol,aRow : Integer) : Boolean;      // 指定された列、行が固定行、固定列なのか判定
    // 行の背景色を塗る
    procedure DrawCellBackground(Canvas: TCanvas; const R: TRect; State: TOwnerDrawState);
    // 編集開始直前イベント　※TListView独自のファイル名変更イベント
    procedure OnSelfEditing(Sender: TObject; Item: TListItem; var AllowEdit: Boolean);


    // プラグインから編集完了イベントを受け取る
    procedure OnEditTypeEdited(Sender : TObject;const EditStr : string);
    // プラグインから編集キャンセルイベントを受け取る
    procedure OnEditTypeEditCancel(Sender : TObject);
    procedure SettingRequest(Sender : TObject);
    function GetSettings(Index: Integer): TListViewRowItem;
    procedure SetFixedStyle(const Value: TListViewEditFixedStyle);
  protected
    FRowSettings    : TListViewRowList;         // 行ごとの編集スタイル管理リスト
    FVisibleIndexes : TListViewRowListEx;      // 非表示行の換算クラス
    FPopMenu        : TPopupMenu;                 // ポップメニューを一時保存
    FComponentEdit  : TWinControl;                // 編集に使用中のプラグイン
    // カーソル位置の行のY座標取得
    function GetEditTop() : Integer;
    // 横スクロールバーの現在位置を取得
    function GetScrollBarLeft() : Integer;
    // 固定行　表題の高さを取得
    function GetListViewHeaderHeight(): Integer;
    // ウインドウメッセージをフック
    procedure WMProc(var Msg:TMessage);
    procedure DoChanging(var EditStr : string;const aColumn,aIndex : Integer);virtual;
    // 下位クラスにデータ変更を通知
    procedure DoChange(const EditStr : string;const aColumn,aIndex : Integer);virtual;
    // 下位クラスにプラグインインスタンスを渡す
    procedure DoSettingInstance(Instance : TObject);virtual;
    // 編集無効処理
    procedure EditChancel();
    // カーソル位置の描画範囲を取得
    function GetEditCellRect(AColumn, AIndex: Integer): TRect;
    // X座標から列を取得
    function XToColumn(const X : Integer) : Integer;
    // カーソルの列位置を取得
    function GetColumAt(const X,Y : Integer) : Integer;
    // 指定したセルに対する編集方法を取得
    function GetCellRTTI(aCol,aRow : Integer) : TListViewRowItem;
    // True : 値を編集中
    property Edited : Boolean read FEdited;
    procedure KeyPress(var Key: Char); override;
    // ダブルクリックイベント
    procedure DblClick; override;
    // マウス移動時に呼ぶ処理 ヒント表示用
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure DrawItem(Item: TListItem;Rect: TRect; State: TOwnerDrawState);override;
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    // True :編集可能で編集状態へ移行
    function EditBegin(const EditColumn : Integer = -1) : Boolean;virtual;
    // 指定した絡むが左端になるようにスクロール位置を調整
    procedure ScrollToColumn(AColumn: Integer);
    // 表示範囲に収まっているか確認してスクロール位置を調整
    procedure EnsureEditingColumnVisible(AColLeft, AColRight: Integer);
    // 何番目の列にマウスカーソルがあるのかを取得
    property Column : Integer read GetColumn;
    property Settings[Index : Integer] : TListViewRowItem read GetSettings;
    // 固定行などのレイアウト設定
    property FixedStyle: TListViewEditFixedStyle read FFixedStyle write SetFixedStyle;

    property OnChange : TListViewEditChange read FOnChange write fOnChange;
    property OnChanging : TListViewEditChanging read FOnChanging write FOnChanging;
    property OnSettingInstance : TNotifyEvent read FOnSettingInstance write FOnSettingInstance;

  end;

implementation

uses ListViewEditPluginLib,AviUtl2StyleColors;

const
  TimerIdBeginEdit = 1;


{ TListViewEx }

//--------------------------------------------------------------------------//
//  クラス生成                                                              //
//--------------------------------------------------------------------------//
constructor TListViewEdit.Create(AOwner: TComponent);
begin
  inherited;
  FRowSettings    := TListViewRowList.Create;
  FVisibleIndexes := TListViewRowListEx.Create;
  FPendingBeginEdit := False;


  OnEditing := OnSelfEditing;
  OwnerDraw := True;

  FProc := WindowProc;
  WindowProc := WMProc;
end;

//--------------------------------------------------------------------------//
//  クラス破棄                                                              //
//--------------------------------------------------------------------------//
procedure TListViewEdit.DblClick;
begin
  FPendingBeginEdit := True;
  KillTimer(Handle, TimerIdBeginEdit);
  SetTimer(Handle, TimerIdBeginEdit, GetDoubleClickTime + 10, nil);

  // ユーザーが設定した外部イベントも呼ぶ（継承元と同様の動作）
  inherited;
end;

destructor TListViewEdit.Destroy;
begin
  FPendingBeginEdit := False;
  if HandleAllocated then
    KillTimer(Handle, TimerIdBeginEdit);
  FVisibleIndexes.Free;
  FRowSettings.Free;
  WindowProc := FProc;
  inherited;
end;

procedure TListViewEdit.DoChange(const EditStr: string; const aColumn,  aIndex: Integer);
begin
  if Assigned(FOnChange) then begin
    FOnChange(Self,EditStr,aColumn,aIndex);
  end;
end;

procedure TListViewEdit.DoChanging(var EditStr: string; const aColumn, aIndex: Integer);
begin
  if Assigned(FOnChanging) then begin
    FOnChanging(Self,EditStr,aColumn,aIndex);
  end;
end;

procedure TListViewEdit.DoSettingInstance(Instance: TObject);
begin
  if Assigned(FOnSettingInstance) then FOnSettingInstance(Instance);
end;


//--------------------------------------------------------------------------//
//  プラグインからの編集キャンセルイベント                                  //
//--------------------------------------------------------------------------//
procedure TListViewEdit.OnEditTypeEditCancel(Sender: TObject);
begin
  EditChancel();
end;

//--------------------------------------------------------------------------//
//  プラグインからの編集完了イベント                                        //
//--------------------------------------------------------------------------//
procedure TListViewEdit.OnEditTypeEdited(Sender: TObject;
  const EditStr: string);
var
  f : Boolean;
begin
  if not FEdited then Exit;

  Cells[FEditColumn,FEditIndex] := EditStr;           // データとして保存
  DoChange(EditStr,FEditColumn,FEditIndex);           // 下位クラスに通知
  if FComponentEdit <> nil then begin                 // 編集中のプラグインがある場合
    FComponentEdit.Visible := False;                  // プラグインを非表示
  end;
  PopupMenu := FPopMenu;                              // ポップアップメニューを元に戻す
  //Self.SetFocus();                                    // ListViewにフォーカスを移す
  //PostMessage(Handle, WM_SETFOCUS, 0, 0);
  FocusWhenIdle(Self,f);
  Refresh();                                          // 念のため更新
  FEdited := False;                                   // 編集状態を解除
end;

//--------------------------------------------------------------------------//
//  フォーカス消失などで編集状態をキャンセル                                //
//--------------------------------------------------------------------------//
procedure TListViewEdit.EditChancel;
var
  f : Boolean;
begin
  if not FEdited then Exit;
  if FComponentEdit <> nil then begin                 // 編集中のプラグインがある場合
    FComponentEdit.Visible := False;                  // プラグインを非表示
  end;
  if FPopMenu<> nil then PopupMenu := FPopMenu;       // ポップメニューを復元

  PopupMenu := FPopMenu;                              // ポップアップメニューを元に戻す
  //Self.SetFocus();                                    // ListViewにフォーカスを移す
  //PostMessage(Handle, WM_SETFOCUS, 0, 0);
  FocusWhenIdle(Self,f);
  FEdited := False;                                   // 編集状態を解除
end;


procedure TListViewEdit.EnsureEditingColumnVisible(AColLeft,  AColRight: Integer);
var
  ScrollLeft, AWidth: Integer;
begin
  //ScrollLeft  := Perform(LVM_GETORIGIN, 0, 0);
  ScrollLeft := GetScrollPos(Handle, SB_HORZ);
  AWidth := ClientWidth;

  // ListViewのクライアント領域内に列が収まっているか確認
  if (AColLeft >= ScrollLeft) and (AColRight <= ScrollLeft + AWidth) then
    Exit; // スクロールの必要なし

  // はみ出しているのでスクロール位置を調整
  if AColLeft < ScrollLeft then
    Perform(LVM_SCROLL, -(ScrollLeft - AColLeft), 0) // 左にスクロール（dx < 0）
  else
    Perform(LVM_SCROLL, AColRight - (ScrollLeft + AWidth), 0); // 右にスクロール（dx > 0）
end;

//--------------------------------------------------------------------------//
//  編集状態に移行 True:移行完了 False:移行失敗                             //
//--------------------------------------------------------------------------//
function TListViewEdit.EditBegin(const EditColumn : Integer = -1): Boolean;
var
  i,eType : Integer;
  ColLeft, ColRight: Integer;
  s : string;
  r : Trect;
  dr : TListViewRowItem;
begin
  result := False;
  if EditColumn = -1 then begin
    FEditColumn := Column;       // マウス位置から列を取得
  end
  else begin
    FEditColumn := EditColumn;
  end;
  FEditIndex := ItemIndex;
  if FEditColumn < 0 then exit;                       // 固定行やその左の場合は範囲外とする
  if (FFixedStyle = fsVerticalFixedColumn) and
     (FEditColumn = 0) then exit;                     // 左側が固定列設定で左列の場合編集しない

  // カラムの表示位置を取得（ヘッダーのRectを利用）
  if GetColumnRect(FEditColumn, ColLeft, ColRight) then
    EnsureEditingColumnVisible(ColLeft, ColRight);

  FEdited := True;
  //if FEdited  then begin
    //if FEdit.Visible then EditOk();                 // 編集中の場合、編集結果を有効にしてから編集
  //end;

  r := GetEditCellRect(FEditColumn,FEditIndex);

  i := ItemIndex;
  if i = -1 then exit;

  //dr := GetCellRTTI(FEditColumn,i);
  s := Cells[FEditColumn,i];
  DoChanging(s,FEditColumn,FEditIndex);

  dr := GetCellRTTI(FEditColumn,i);
  dr.Value := s;
  dr.Data  := Items[i].Data;
  eType := dr.EditType;
//  if eType = ListViewEditPluginReadOnlyId then exit;


  FPopMenu  := PopupMenu;                             // ポップアップメニューを一時待避
  Popupmenu := nil;                                   // ポップアップメニューを無効に

  ListViewEditPlugins.OnSettingInstance := SettingRequest;
  //ListViewEditPlugins.CreateInstance(dr.EditType);// 該当するプラグインを生成
  ListViewEditPlugins.BeginEdit(Self,FComponentEdit,eType,r,dr,OnEditTypeEdited,OnEditTypeEditCancel);  // 編集開始
  //FEditTypes.Editing(Self,FComponentEdit,eType,r,dr);  // 編集開始
  ListViewEditPlugins.OnSettingInstance := nil;
end;

//--------------------------------------------------------------------------//
//  X座標から該当する列を取得                                               //
//--------------------------------------------------------------------------//
function TListViewEdit.XToColumn(const X: Integer): Integer;
var
  i,x1,x2: Integer;
begin
  result := -1;
  for i := 0 to Columns.Count-1 do begin
    x1 := ColumnLeft(i);
    x2 := ColumnRight(i);
    if x < x1 then continue;
    if x > x2 then continue;
    result := i;
    exit;
  end;
end;



function TListViewEdit.GetColumAt(const X, Y: Integer): Integer;
var
  i,xx : Integer;
begin
  result := -1;
  xx := -GetScrollBarLeft();                // 基準値をスクロールバーの現在位置から取得
  for i := 0 to Columns.Count-1 do begin    // 列数ループ
    xx := xx + Columns[i].Width;            // 基準値に列幅を加算
    if X < xx then begin                    // カーソルが列内にある場合
      result := i;                          // カーソルの列位置として返す
      exit;                                 // 処理終了
    end;
  end;
end;

function TListViewEdit.GetColumn: Integer;
var
  p : TPoint;
begin
  P := GetMouseClientPos;
  result := GetColumAt(p.X,p.Y);                  // マウス位置から列を取得
end;

function TListViewEdit.GetColumnRect(Index: Integer; out ALeft,  ARight: Integer): Boolean;
var
  i, X: Integer;
begin
  Result := False;
  if ViewStyle <> vsReport then Exit;
  if (Index < 0) or (Index >= Columns.Count) then Exit;

  X := -Perform(LVM_GETORIGIN, 0, 0); // スクロール分を補正
  for i := 0 to Index - 1 do
    Inc(X, Columns[i].Width);

  ALeft  := X;
  ARight := X + Columns[Index].Width;
  Result := True;
end;

function TListViewEdit.GetEditCellRect(AColumn, AIndex: Integer): TRect;
var
  RowRect: TRect;
  ScrollX: Integer;
  ColLeft: Integer;
  Col: TListColumn;
begin
  Result := Rect(0, 0, 0, 0);

  if (AColumn < 0) or (AColumn >= Columns.Count) then Exit;
  if (AIndex < 0) or (AIndex >= Items.Count) then Exit;

  // 各行の矩形を取得
  if not ListView_GetItemRect(Handle, AIndex, RowRect, LVIR_BOUNDS) then Exit;

  // スクロール位置の補正
  ScrollX := GetScrollPos(Handle, SB_HORZ);
  ColLeft := ColumnLeft(AColumn);

  Col := Columns[AColumn];

  Result.Left := ColLeft - ScrollX;
  Result.Top := RowRect.Top;
  Result.Right := Result.Left + Col.Width;
  Result.Bottom := RowRect.Bottom;
end;

function TListViewEdit.GetEditTop: Integer;
begin
  // 表題の高さ分を別途調整
  result := (ItemIndex -  TopIndex) * (ItemHeight+1);
end;


//--------------------------------------------------------------------------//
//  固定行　表題の高さを取得                                                //
//--------------------------------------------------------------------------//
function TListViewEdit.GetListViewHeaderHeight(): Integer;
var
  Header_Handle: HWND;
  WindowPlacement: TWindowPlacement;
begin
  Header_Handle := ListView_GetHeader(Handle);
  FillChar(WindowPlacement, SizeOf(WindowPlacement), 0);
  WindowPlacement.Length := SizeOf(WindowPlacement);
  GetWindowPlacement(Header_Handle, @WindowPlacement);
  Result  := WindowPlacement.rcNormalPosition.Bottom -
    WindowPlacement.rcNormalPosition.Top;
end;


function TListViewEdit.GetMouseClientPos: TPoint;
begin
  GetCursorPos(Result);
  Result := ScreenToClient(Result);
end;

function TListViewEdit.GetSettings(Index: Integer): TListViewRowItem;
begin
  while Index >= FRowSettings.Count do FRowSettings.AddNew();
  result := FRowSettings[Index];
end;

//--------------------------------------------------------------------------//
//  横スクロールバーの現在位置を取得                                        //
//--------------------------------------------------------------------------//
function TListViewEdit.GetScrollBarLeft: Integer;
var
  SInfo: TScrollInfo;
begin
  SInfo.cbSize := SizeOf(SInfo);
  SInfo.fMask := SIF_ALL;
  GetScrollInfo(Handle, SB_HORZ, SInfo);
  result := SInfo.nPos;
end;


function TListViewEdit.IsFixedCell(aCol, aRow: Integer): Boolean;
begin
  result := False;
  if (FFixedStyle = fsVerticalFixedColumn) and
     (aCol = 0) then result := True;                      // 左端の表題の場合
 // if (FFixedStyle = fsHorizontalFixedRow) and
 //    (aRow = 0) then result := True;                      // 左端の表題の場合

end;

//--------------------------------------------------------------------------//
//  キー降下イベント                                                        //
//--------------------------------------------------------------------------//
procedure TListViewEdit.KeyPress(var Key: Char);
var
  i : Integer;
begin
  inherited;

  i := ItemIndex;                                     // 行カーソル位置取得
  if i = -1 then exit;                                // 未選択時未処理

  if Key <> #$0d then exit;                           // エンター意外は未処理
  Key := #$0;                                         // キーを処理しない

  EditBegin();                                        // 編集状態へ移行
end;


procedure TListViewEdit.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  dl : TListItem;
  dr : TListViewRowItem;
  col : Integer;
begin
  inherited MouseMove(Shift, X, Y);    //

  if not HintsEnabled then
  begin
    ShowHint := False;
    Hint := '';
    Exit;
  end;

  ShowHint := False;                   // ヒント表示を消す
  dl := GetItemAt(X,Y);                // カーソル上のデータを参照
  if dl= nil then exit;                // カーソル上にデータが無い場合
  //dr := FRowSettings[dl.Index];        // インデックス値に該当するデータを参照
  col := Column;
  if col = -1 then exit;

  dr := GetCellRTTI(col,dl.Index);
  Hint := dr.Hint;                    // ヒントを割り当て
  if Hint <> '' then begin             // ヒントが無い場合は処理しない
    ShowHint := True;                  // ヒントを表示させる
  end;
end;


procedure TListViewEdit.DrawCellBackground(Canvas: TCanvas; const R: TRect;State: TOwnerDrawState);
begin
  Canvas.Brush.Style := bsSolid;

  if odSelected in State then
    Canvas.Brush.Color := A2SCListViewBackground
  else if odHotLight in State then
    Canvas.Brush.Color := A2SCListViewAltBackground
  else
    Canvas.Brush.Color := A2SCListViewSelection;

  Canvas.FillRect(R);
end;

//--------------------------------------------------------------------------//
//  描画処理                                                                //
//--------------------------------------------------------------------------//
procedure TListViewEdit.DrawItem(Item: TListItem; Rect: TRect;
  State: TOwnerDrawState);
var
  cv : TCanvas;
  i,j,x,xh,ScrollX : Integer;
  s : string;
  dt : TListViewRowItem;
  r : TRect;
  bmp: TBitmap;
begin
  if not(Canvas.HandleAllocated) or not(Self.HandleAllocated) then exit;

  ScrollX := GetScrollPos(Self.Handle, SB_HORZ);
  cv := TLIstView(Self).Canvas;                   // 描画キャンバス参照

  //DrawBack(cv,Item,Rect,State);                     // カーソルに合わせて背景描画
  x := 5;                                           // マージンを指定
  cv.Brush.Style := bsClear;
  i := Item.Index;

  xh := 0;
  if (SmallImages <> nil) and (Items[i].ImageIndex < SmallImages.Count) then
  begin
    bmp := TBitmap.Create;
    try
      SmallImages.GetBitmap(Items[i].ImageIndex, bmp);
      r := Item.DisplayRect(drIcon);
      InflateRect(r, -6, -6);   // ← 2px 内側に縮める（重要！）

      // アイコンを取得
      SmallImages.GetBitmap(Items[i].ImageIndex, bmp);

      // r の範囲へストレッチ描画
      Self.Canvas.StretchDraw(r, bmp);

      xh := r.Width + 4;
      //------------------------------------------
      // 選択状態のときアイコン枠を強調表示する
      //------------------------------------------
      if odSelected in State then
      begin
        cv.Pen.Color := clRed;        // 強調色（お好みで変更可）
        cv.Pen.Width := 4;
        cv.Brush.Style := bsClear;
        cv.Rectangle(r);
      end
      else if odHotLight in State then
      begin
        cv.Pen.Color := clSkyBlue;    // ホバー時の色
        cv.Pen.Width := 2;
        cv.Brush.Style := bsClear;
        cv.Rectangle(r);
      end;
    finally
      bmp.Free;
    end;
  end;

  i := Item.Index;

  for j := 0 to Columns.Count-1 do begin            // 列数ループ
    dt := GetCellRTTI(j,i);                         // 実効値型情報の行を参照
    dt.Value := Cells[j,i];
    r := Rect;                                      // 描画範囲を参照
    r.Left := ColumnLeft(j) - ScrollX;
    if j = 0 then r.Left := r.Left + xh;
    r.Right := ColumnRight(j) - ScrollX - 8;        // 左端マージンを設定

    if IsFixedCell(j,i) then begin                  // 左端の表題の場合
      cv.Font.Color  := dt.ColorFont;               // 色設定を反映
      //cv.Brush.Color := dt.ColorBack;
      cv.Brush.Style := bsClear;
      s := Item.Caption;

      if dt.Caption<>'' then s := dt.Caption;       // 表題が設定されていれば取得

      cv.TextRect(r,r.Left+x,r.Top+2,s);            // 表題を描画
    end
    else begin                                      // 表題では無い場合
      DrawCellBackground(cv,r,State);               // 背景を塗る

      cv.Font.Color  := clBlack;
      cv.Brush.Style := bsClear;

      s := Cells[j, Item.Index];

      // Xオフセットが必要な場合は r.Left := r.Left + x など
      r.Left := r.Left + x;

      // 自動折り返し付き描画
      DrawTextAutoWrap(cv, r, s);
  end;
    //x := x + Columns[j].Width;                      // 描画位置を次へ
  end;
end;

procedure TListViewEdit.OnSelfEditing(Sender: TObject; Item: TListItem;
  var AllowEdit: Boolean);
begin
  AllowEdit := False;          // 左端のセルがクリックだけで編集になるのを抑止
  //FEdited := True;
end;


function TListViewEdit.GetCellRTTI(aCol, aRow: Integer): TListViewRowItem;
begin
  if FFixedStyle = fsHorizontal then begin
    if FVisibleIndexes.Count = 0 then begin
      result := Settings[aCol];          // 編集方法を取得
    end
    else begin
      while aCol >= FRowSettings.Count do FRowSettings.AddNew();
      result := Settings[FVisibleIndexes[aCol]];          // 編集方法を取得
    end;
  end
  else begin
    if FVisibleIndexes.Count = 0 then begin
      while aRow >= FRowSettings.Count do FRowSettings.AddNew();
      result := Settings[aRow];          // 編集方法を取得
    end
    else begin
      result := Settings[FVisibleIndexes[aRow]];          // 編集方法を取得
    end;
  end;
end;


procedure TListViewEdit.ScrollToColumn(AColumn: Integer);
var
  HeaderHandle: HWND;
  i, TargetX: Integer;
begin
  if not HandleAllocated then Exit;

  HeaderHandle := FindWindowEx(Handle, 0, 'SysHeader32', nil);
  if HeaderHandle = 0 then Exit;

  TargetX := 0;
  for i := 0 to AColumn - 1 do
  begin
    if ListView_GetColumnWidth(Handle, i) > 0 then
      Inc(TargetX, ListView_GetColumnWidth(Handle, i));
  end;

  ListView_Scroll(Handle, TargetX - GetScrollPos(Handle, SB_HORZ), 0);
end;

procedure TListViewEdit.SetFixedStyle(const Value: TListViewEditFixedStyle);
begin
  FFixedStyle := Value;
end;

procedure TListViewEdit.SettingRequest(Sender: TObject);
begin
  DoSettingInstance(Sender);
end;

//--------------------------------------------------------------------------//
//  表示中の先頭行位置を取得                                                //
//--------------------------------------------------------------------------//
function TListViewEdit.TopIndex: Integer;
var
  SInfo: TScrollInfo;
begin
  SInfo.cbSize := SizeOf(SInfo);
  SInfo.fMask := SIF_ALL;
  GetScrollInfo(Handle, SB_VERT, SInfo);
  //result := SInfo.nPos - 1;
  result := SInfo.nPos;             // 2022/4/30
end;


//--------------------------------------------------------------------------//
//  ウインドウメッセージをフック                                            //
//--------------------------------------------------------------------------//
procedure TListViewEdit.WMProc(var Msg: TMessage);
begin
  FProc(Msg);                             // 元のプロセスにも送る
  //FormSyncroh2.MsgDebug(IntToHex(Msg.Msg,4));             // ※デバッグ用

  case Msg.Msg of                         // 編集キャンセル操作か判断
    WM_HSCROLL    : EditChancel;          // スクロール
    WM_VSCROLL    : EditChancel;          // スクロール
    WM_TIMER      : if Msg.WParam = TimerIdBeginEdit then begin
                      KillTimer(Handle, TimerIdBeginEdit);
                      if FPendingBeginEdit then begin
                        FPendingBeginEdit := False;
                        EditBegin();
                      end;
                    end;
    //WM_SIZE       : EditChancel;          // サイズ変更
    WM_MOUSEWHEEL : EditChancel;          // マウスホイール
    //else FormMain.MsgDebug(Msg.Msg);
  end;
end;


end.
