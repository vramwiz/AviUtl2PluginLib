unit ListViewEx;

{
  ListViewEx.pas
  ---------------------------------------------------------------------------
  拡張 ListView コンポーネント TListViewEx を定義するユニット。

  このクラスは Delphi 標準の TListView を継承し、以下のような
  表示・操作まわりの機能を追加・修正しています：

    - 行の高さを指定可能（ItemHeight）
    - ストライプ状の背景（RowColorStriped）
    - アイコン表示の有効／無効切替（EnableIcons / DisableIcons）
    - オーナードロー描画の改善（DrawBack, OnSelfDrawItem）
    - 全選択／全解除、カラム幅の自動調整などのユーティリティ追加

  また、セル単位のアクセス (`Cells[ACol, ARow]`) や、
  スクロールバーの可視状態の制御 (`SetHorzScrollBarVisible` など) にも対応しています。

  このコンポーネントは ListView の表示・操作性を向上させる目的で使用します。
}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ImgList,
  Vcl.ComCtrls,CommCtrl,System.Types,Vcl.Menus,Winapi.Dwmapi,Winapi.UxTheme;

const
  WM_FINAL_ADJUST = WM_USER + 900;

  // ヒント要求イベント
type
  TListViewGetHintEvent = procedure(Sender: TObject; Index: Integer; var AHint: string) of object;

type
  TListViewExWheelScrollEvent = procedure(               // ListViewEx がホイール操作を通知するためのイベント型
    Sender: TObject;                                     // 発生元（ListViewEx）
    WheelDelta: Integer;                                 // ホイールの回転量（±120）
    Shift: TShiftState;                                  // Shift/Ctrl/Alt の状態
    var Handled: Boolean                                 // True にすると既定スクロールを無効化
  ) of object;                                           // メソッド形式のイベント

type
  TListViewExCaptionEditBeginEvent = procedure(
    Sender: TObject;     // 発火元
    Item: TListItem;     // 編集対象
    var AllowEdit: Boolean  // 編集を許可するか
  ) of object;

type
  TListViewExCaptionEditedEvent = procedure(
    Sender: TObject;                 // 発火元の TListViewEx
    Item: TListItem;                 // 編集された対象アイテム
    const NewCaption: string;        // 編集後のキャプション文字列
    var Accept: Boolean              // 採用可否（True＝変更適用 / False＝キャンセル）
  ) of object;

type
  PLVDispInfo = ^TLVDispInfo;
  TLVDispInfo = LV_DISPINFO;

//--------------------------------------------------------------------------//
//  TListViewに必要最低限の機能 サイズ変更を実装                            //
//--------------------------------------------------------------------------//
type
  TListViewEx = class(TListView)
  private
    { Private 宣言 }
    FImages           : TImageList;          // リストビューで使用するイメージリスト
    FRowColorStriped  : Boolean;             // アイコン表示サイズ
    FItemHeight       : Integer;
    FHintsEnabled     : Boolean;             // 独自ヒント表示を有効にするか
    FCaptionEditing　 : Boolean;             // Caption編集中
    FLastHintText     : string;              // 最後に表示したヒント
    FLastIndex        : Integer;             // 最後に表示したヒントのインデックス値

    FOnGetHint        : TListViewGetHintEvent;
    FEditBrush        : HBRUSH;

    FPopupMenu          : TPopupMenu;          // ポップアップメニューを待避
    FPopupMenuDisabledByEdit: Boolean;         // 編集開始でPopupMenuを外したかを保持

    FOnWheelScrollRequest: TListViewExWheelScrollEvent;
    FOnCaptionEdited: TListViewExCaptionEditedEvent;
    FOnCaptionEditBegin: TListViewExCaptionEditBeginEvent;             // 行の高さ
    // 背景描画
    procedure DrawBack(cv : TCanvas;Item: TListItem;rBack: TRect; State: TOwnerDrawState);

    procedure WMFinalAdjust(var Msg: TMessage); message WM_FINAL_ADJUST;

    procedure SetRowColorStriped(const Value: Boolean);
    function GetItemHeight: Integer;
    procedure SetItemHeight(const Value: Integer);
    function GetImageSize: Integer;
    procedure SetImageSize(const Value: Integer);
    function GetCells(ACol, ARow: Integer): string;
    procedure SetCells(ACol, ARow: Integer; const Value: string);
    procedure SetHorzScrollBarVisible(const Value: Boolean);
    procedure SetVertScrollBarVisible(const Value: Boolean);
    function GetListViewRowHeight(LV: TListView): Integer;
    function GetListViewHeaderHeight(LV: TListView): Integer;

    // 指定した行が表示されるように調整
    procedure SetTopIndex(const Value : Integer);
    function GetTopIndex: Integer;
    procedure SetHintsEnabled(const Value: Boolean);
  protected
    procedure Resize; override;
    procedure DrawItem(Item: TListItem; rItem: TRect; State: TOwnerDrawState);override;
    procedure DrawTextAutoWrap(Canvas: TCanvas; var R: TRect; const Text: string);
    // マウス移動イベント
    procedure WMMouseMove(var Msg: TWMMouseMove); message WM_MOUSEMOVE;
    procedure CMHintShow(var Msg: TCMHintShow); message CM_HINTSHOW;
    // ヒント要求イベント
    procedure DoGetHint(Index: Integer; var AHint: string); virtual;
    // ホイールメッセージ受信
    procedure WMMouseWheel(var Msg: TWMMouseWheel); message WM_MOUSEWHEEL;
    // ヒント用座標指定
    procedure UpdateHintAt(X, Y: Integer); virtual;
    procedure WMControlColorEdit(var Msg: TWMCtlColorEdit); message WM_CTLCOLOREDIT;
    // スクロール要求イベント
    procedure DoWheelScrollRequest(  WheelDelta: Integer;  Shift: TShiftState;   var Handled: Boolean  ); virtual;
    procedure CNNotify(var Message: TWMNotify); message CN_NOTIFY;
    // Caption変更開始イベント
    procedure DoCaptionEditBegin(Item: TListItem; var AllowEdit: Boolean);virtual;
    // Caption変更終了イベント
    procedure DoCaptionEdited(Item: TListItem; const NewCaption: string; var Accept: Boolean); virtual;
    // 編集中に無効化したPopupMenuを復元する
    procedure RestorePopupAfterCaptionEdit;
    // フォーカスを安全に移行
    procedure FocusWhenIdle(Sender: TObject; var Done: Boolean);
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure Clear();override;
    // 要素の挿入
    function Insert(Index: Integer): TListItem;

    // アイコンを表示
    procedure EnableIcons(ViewStyle: TViewStyle; IconSize: Integer);
    // アイコンを非表示
    procedure DisableIcons();
    // 全選択
    procedure SelectAll();override;
    // 選択解除
    procedure SelectClear();
    // カラム位置を横幅に合わせる
    procedure AdjustColumnsToHeader();
    // Captionの編集開始
    procedure BeginEdit(Index: Integer);
     // サイズ変更が発生した場合に指定した列の横幅を伸ばす
    procedure ColumnAlign(const aColmun : Integer);
    // 指定した列の横幅を最大まで伸ばす
    procedure AutoAdjustColumnWidth(TargetColumn: Integer);
    // 指定した列の左端座標を取得
    function ColumnLeft(const aCol : Integer) : Integer;
    // 指定した列の右端座標を取得
    function ColumnRight(const aCol : Integer) : Integer;
    // 使用する画像のサイズを設定
    procedure SetImageSizeWH(const Width,Height : Integer);
    // リストの要素を入れ替える
    procedure Exchange(Index1,Index2 : Integer);

    // ListViewが必要としている高さを取得
    function GetViewHeight(): Integer;

    // 画像リスト
    property Images : TImageList read FImages;
    // 画像のサイズ
    property ImageSize: Integer read GetImageSize write SetImageSize;
    // 項目の高さ
    property ItemHeight : Integer read GetItemHeight write SetItemHeight;
    // 指定したインデックス値の要素が画面内に表示されるように調整
    property TopIndex : Integer read GetTopIndex write SetTopIndex;
    // TListViewのCaptionやSubItemsを二次元配列セル処理として扱う
    property Cells[ACol, ARow: Integer] : string read GetCells write SetCells;
    // True:項目毎に背景色を変える ※未使用？
    property RowColorStriped : Boolean read FRowColorStriped write SetRowColorStriped;
    // 水平スクロールバー表示設定
    property HorzScrollBarVisible: Boolean write SetHorzScrollBarVisible;
    // 垂直スクロールバー表示設定
    property VertScrollBarVisible: Boolean write SetVertScrollBarVisible;
     // ScrollBox 等へ転送するための外部イベント
    property OnWheelScrollRequest: TListViewExWheelScrollEvent read FOnWheelScrollRequest write FOnWheelScrollRequest;
    // ヒント要求イベント
    property OnGetHint: TListViewGetHintEvent read FOnGetHint write FOnGetHint;
    property OnCaptionEditBegin: TListViewExCaptionEditBeginEvent read FOnCaptionEditBegin write FOnCaptionEditBegin;
    property OnCaptionEdited: TListViewExCaptionEditedEvent  read FOnCaptionEdited write FOnCaptionEdited;
    property HintsEnabled: Boolean read FHintsEnabled write SetHintsEnabled;
    // ラベル編集用エディットが開いている間はTrue
    property CaptionEditing: Boolean read FCaptionEditing;
  end;

function CanSafelySetFocus(Control: TWinControl): Boolean;
procedure SafeSetFocus(Control: TWinControl);

implementation

uses ShellApi,Math,AviUtl2StyleColors;
{ TListViewEx }

//--------------------------------------------------------------------------//
//  クラス生成                                                              //
//--------------------------------------------------------------------------//
constructor TListViewEx.Create(AOwner: TComponent);
begin
  inherited;
  FItemHeight := 24;
  FHintsEnabled := True;
  BevelOuter := bvNone;
  BevelInner := bvNone;
  FImages := TImageList.Create(Self);
  FEditBrush := CreateSolidBrush(A2SCEditBackground);
end;

//--------------------------------------------------------------------------//
//  クラス破棄                                                              //
//--------------------------------------------------------------------------//
destructor TListViewEx.Destroy;
begin
  RestorePopupAfterCaptionEdit; // 破棄時にPopupMenuがnilのまま残らないようにする
  FImages.Free;
  if FEditBrush <> 0 then DeleteObject(FEditBrush);
  inherited;
end;

//--------------------------------------------------------------------------//
//  Itemsクリア　※イメージリストのクリアも行っている                       //
//--------------------------------------------------------------------------//
procedure TListViewEx.Clear;
begin
  RestorePopupAfterCaptionEdit; // 一覧クリア前に編集中のPopupMenu退避状態を解除する
  inherited;
  FImages.Clear;
end;

procedure TListViewEx.CNNotify(var Message: TWMNotify);
var
  Info: PLVDispInfo;
  Item: TListItem;
  Accept: Boolean;
begin
  inherited;

  // ★ 編集開始（デバッグ判定用）
  if Message.NMHdr^.code = LVN_BEGINLABELEDIT then
  begin
    Info := PLVDispInfo(Message.NMHdr);

    if (Info^.item.iItem >= 0) then
    begin
      Item := Items[Info^.item.iItem];

      Accept := True;
      DoCaptionEditBegin(Item, Accept);

      if not Accept then
      begin
        RestorePopupAfterCaptionEdit; // 編集開始拒否時にPopupMenuの退避状態を戻す
        Message.Result := 1; // 編集を拒否
        Exit;
      end;
    end;

    OutputDebugString('LVN_BEGINLABELEDIT 発生');
    Message.Result := 0; // 編集許可
    Exit;
  end;

  // ★ 編集終了（既存処理）
  if Message.NMHdr^.code = LVN_ENDLABELEDIT then
  begin
    OutputDebugString('LVN_ENDLABELEDIT 発生');

    Info := PLVDispInfo(Message.NMHdr);

    if (Info^.item.iItem >= 0) then
    begin
      Item := Items[Info^.item.iItem];
      Accept := True;

      if Info^.item.pszText <> nil then
      begin
        OutputDebugString(PChar('New Caption = ' + Info^.item.pszText));
      end
      else
      begin
        OutputDebugString('pszText = nil → キャンセル判定');
        Accept := False;
      end;
      DoCaptionEdited(Item, Info^.item.pszText, Accept);

      if Accept then
        Message.Result := 1
      else
        Message.Result := 0;
    end;

    Exit;
  end;
end;




procedure TListViewEx.EnableIcons(ViewStyle: TViewStyle; IconSize: Integer);
begin
  Self.ViewStyle := ViewStyle;
  SetImageSize(IconSize);
end;

procedure TListViewEx.DisableIcons;
begin
  LargeImages := nil;
  SmallImages := nil;
end;

procedure TListViewEx.DoCaptionEditBegin(Item: TListItem;  var AllowEdit: Boolean);
begin
  if not FPopupMenuDisabledByEdit then begin
    FPopupMenu := PopupMenu;
    PopupMenu := nil;
    FPopupMenuDisabledByEdit := True;
  end;
  FCaptionEditing := True;

  if Assigned(FOnCaptionEditBegin) then FOnCaptionEditBegin(Self, Item, AllowEdit);
end;

procedure TListViewEx.DoCaptionEdited(Item: TListItem; const NewCaption: string;  var Accept: Boolean);
begin
  RestorePopupAfterCaptionEdit; // 編集終了時にPopupMenuの退避状態を戻す
  FCaptionEditing := False;

  if Assigned(FOnCaptionEdited) then FOnCaptionEdited(Self, Item, NewCaption, Accept);
end;

procedure TListViewEx.RestorePopupAfterCaptionEdit;
begin
  if not FPopupMenuDisabledByEdit then Exit;
  PopupMenu := FPopupMenu;
  FPopupMenu := nil;
  FPopupMenuDisabledByEdit := False;
  FCaptionEditing := False;
end;

procedure TListViewEx.DoGetHint(Index: Integer; var AHint: string);
begin
 if Assigned(FOnGetHint) then FOnGetHint(Self, Index, AHint);
end;

procedure TListViewEx.DoWheelScrollRequest(WheelDelta: Integer;  Shift: TShiftState; var Handled: Boolean);
begin
  if Assigned(FOnWheelScrollRequest) then FOnWheelScrollRequest(Self, WheelDelta, Shift, Handled);
end;

procedure TListViewEx.SelectAll;
var
  I: Integer;
begin
  if not MultiSelect then Exit;
  for I := 0 to Items.Count - 1 do
    Items[I].Selected := True;
end;

procedure TListViewEx.SelectClear;
var
  I: Integer;
begin
  for I := 0 to Items.Count - 1 do
    Items[I].Selected := False;
end;

procedure TListViewEx.AdjustColumnsToHeader;
var
  i: Integer;
begin
  i := Columns.Count ;
  if i = 0 then exit;

  ListView_SetColumnWidth(Self.Handle, i, LVSCW_AUTOSIZE_USEHEADER);


  //for i := 0 to Columns.Count - 1 do
  //  ListView_SetColumnWidth(Handle, i, LVSCW_AUTOSIZE_USEHEADER);
end;


//--------------------------------------------------------------------------//
//  指定した列幅を自動サイズ調整とする                                      //
//--------------------------------------------------------------------------//
procedure TListViewEx.ColumnAlign(const aColmun: Integer);
begin
  if aColmun >= Columns.Count then Exit;

  ListView_SetColumnWidth(Self.Handle, aColmun, LVSCW_AUTOSIZE_USEHEADER);
end;

procedure TListViewEx.AutoAdjustColumnWidth(TargetColumn: Integer);
var
  TotalWidth, UsedWidth, ActualWidth, i,w: Integer;
begin
  if not HandleAllocated then Exit;
  if (TargetColumn < 0) or (TargetColumn >= Columns.Count) then Exit;

  TotalWidth := ClientWidth;

  // 実際の表示幅を取得
  UsedWidth := 0;
  for i := 0 to Columns.Count - 1 do
    if i <> TargetColumn then
    begin
      ActualWidth := ListView_GetColumnWidth(Handle, i);
      Inc(UsedWidth, ActualWidth);
    end;

  // 残り幅で調整
  w := TotalWidth - UsedWidth;
  ListView_SetColumnWidth(Handle, TargetColumn, w);
end;

// Captionの編集開始
procedure TListViewEx.BeginEdit(Index: Integer);
var
  Item: TListItem;
begin
  // Index チェック
  if (Index < 0) or (Index >= Items.Count) then Exit;

  Item := Items[Index];

  // 編集不可条件
  if ReadOnly then Exit;
  if OwnerData then Exit;    // VirtualMode は編集不可（Windowsの仕様）

  // 編集する行を選択・フォーカス
  Item.Focused := True;
  Item.Selected := True;

  // ListView にフォーカスを移す
  SafeSetFocus(Self);

  // 編集開始（Windows メッセージ LVM_EDITLABEL）
  ListView_EditLabel(Self.Handle, Index);
end;


//--------------------------------------------------------------------------//
//  指定した列の左端座標を取得                                              //
//--------------------------------------------------------------------------//
function TListViewEx.ColumnLeft(const aCol: Integer): Integer;
var
  i,x: Integer;
begin
  result := 0;
  if aCol = 0 then exit;
  x := 0;
  for i := 0 to aCol-1 do begin
    x := x + Columns[i].Width;
  end;
  result := x;
end;

//--------------------------------------------------------------------------//
//  指定した列の右端座標を取得                                              //
//--------------------------------------------------------------------------//
function TListViewEx.ColumnRight(const aCol: Integer): Integer;
var
  i,x: Integer;
begin
  result := 0;
  if aCol > Columns.Count-1 then exit;
  x := 0;
  for i := 0 to aCol do begin
    x := x + Columns[i].Width;
  end;
  result := x;
end;

procedure ExchangeList(ds1,  ds2 : TListItem);
var
  i: Integer;
  Caption: string;
  ImageIndex: Integer;
  Data: TObject;
  SubItems1, SubItems2: TStringList;
begin
  // Caption, ImageIndex, Data を退避
  Caption := ds1.Caption;
  ImageIndex := ds1.ImageIndex;
  Data := ds1.Data;

  // SubItemsを一時リストにコピー
  SubItems1 := TStringList.Create;
  SubItems2 := TStringList.Create;
  try
    for i := 0 to ds1.SubItems.Count - 1 do
      SubItems1.AddObject(ds1.SubItems[i], ds1.SubItems.Objects[i]);
    for i := 0 to ds2.SubItems.Count - 1 do
      SubItems2.AddObject(ds2.SubItems[i], ds2.SubItems.Objects[i]);

    // 入れ替え
    ds1.Caption := ds2.Caption;
    ds1.ImageIndex := ds2.ImageIndex;
    ds1.Data := ds2.Data;
    ds1.SubItems.Assign(SubItems2);

    ds2.Caption := Caption;
    ds2.ImageIndex := ImageIndex;
    ds2.Data := Data;
    ds2.SubItems.Assign(SubItems1);

  finally
    SubItems1.Free;
    SubItems2.Free;
  end;
end;

//--------------------------------------------------------------------------//
//  要素を入れ替え ※TListViewは要素入れ替え非対応のため                    //
//--------------------------------------------------------------------------//
procedure TListViewEx.Exchange(Index1, Index2: Integer);
var
  i : Integer;
begin
  if Index1 > index2 then begin
    i := Index1;
    Index1 := Index2;
    Index2 := i;
  end;

  if Index1 < 0            then exit;
  if Index1 >= Items.Count then exit;
  if Index2 < 0            then exit;
  if Index2 >= Items.Count then exit;

  ExchangeList(Items[Index1],Items[Index2]);

end;

procedure TListViewEx.FocusWhenIdle(Sender: TObject; var Done: Boolean);
begin
  SafeSetFocus(Self);
  Application.OnIdle := nil;  // 1回だけ実行
end;

//--------------------------------------------------------------------------//
//  独自の描画処理での背景描画                                              //
//--------------------------------------------------------------------------//
procedure TListViewEx.DrawBack(cv: TCanvas; Item: TListItem; rBack: TRect;State: TOwnerDrawState);
const
  EvenColor = $F0F0F0;
  OddColor  = $FFFFFF;
begin
  cv.Brush.Style := bsSolid;
  if odSelected in State then begin
    cv.Brush.Color := clNavy;
    cv.Font.Color := clWhite;
  end
  else if odHotLight in State then begin
    cv.Brush.Color := clGradientInactiveCaption;
    cv.Font.Color := clWhite;
  end
  else begin
    if Item.Index mod 2 = 0 then begin
      cv.Brush.Color := EvenColor;
      cv.Font.Color := clBlack;
    end
    else begin
      cv.Brush.Color := OddColor;
      cv.Font.Color := clBlack;
    end;
  end;
  cv.FillRect(rBack);
end;

//--------------------------------------------------------------------------//
//  1行毎に色を変える場合の描画処理                                         //
//--------------------------------------------------------------------------//
procedure TListViewEx.DrawItem(Item: TListItem; rItem: TRect;
  State: TOwnerDrawState);
var
  cv : TCanvas;
  i,x : Integer;
  s : string;
begin
  inherited;
  cv := TLIstView(Self).Canvas;

  DrawBack(cv,Item,rItem,State);
  x := 5;
  cv.Brush.Style := bsClear;
  for i := 0 to Columns.Count-1 do begin
    cv.Brush.Style := bsClear;
    if i = 0 then begin
      s := Item.Caption;
      cv.TextRect(rItem,rItem.Left+ x,rItem.Top + 2,s);
    end
    else begin
      s  := '';
      if i < item.SubItems.Count then begin
        s := Item.SubItems[i-1];
      end;
      cv.TextRect(rItem,rItem.Left+ x,rItem.Top + 2,s);
    end;
    x := x + Columns[i].Width;
  end;
end;

procedure TListViewEx.DrawTextAutoWrap(Canvas: TCanvas; var R: TRect;
  const Text: string);
var
  Flags: Integer;
begin
  Canvas.Brush.Style := bsClear;
  Flags :=
    DT_LEFT or        // 横 左寄せ
    DT_SINGLELINE or  // 縦中央寄せには必須
    DT_VCENTER or     // 縦 中央
    DT_END_ELLIPSIS or
    DT_NOPREFIX;
     {
  Flags :=
    DT_LEFT or        // 横位置 左寄せ
    DT_VCENTER or     // 縦位置 中央寄せ
    DT_WORDBREAK or   // 折り返し
    DT_END_ELLIPSIS or// 枠から溢れたら「…」
    DT_NOPREFIX or
    DT_EDITCONTROL;   // 行間・改行制御を標準に合わせる
    }

  DrawTextEx(
    Canvas.Handle,
    PChar(Text),
    Length(Text),
    R,
    Flags,
    nil
  );
end;

procedure TListViewEx.Resize;
begin
  inherited;
//  AdjustColumnsToHeader();
  PostMessage(Handle, WM_FINAL_ADJUST, 0, 0);
  HorzScrollBarVisible := False;                         // 横スクロールバー非表示
end;

//--------------------------------------------------------------------------//
//  使用する画像サイズ設定                                                  //
//--------------------------------------------------------------------------//
procedure TListViewEx.SetImageSizeWH(const Width, Height: Integer);
begin

  LargeImages := nil;
  SmallImages := nil;
  LargeImages := Images;
  SmallImages := Images;
  IconOptions.WrapText := False;

 // SendMessage(Handle, LVM_SETICONSPACING, 0, MakeLParam(spacing, spacing));

  FImages.Width  := Width;
  FImages.Height := Height;
end;
procedure TListViewEx.SetImageSize(const Value: Integer);
begin
  SetImageSizeWH(Value,Value);
end;


//--------------------------------------------------------------------------//
//  行の高さ設定                                                            //
//--------------------------------------------------------------------------//
procedure TListViewEx.SetItemHeight(const Value: Integer);
begin
  FItemHeight := Value;
  SetImageSizeWH(1,Value);
end;

//--------------------------------------------------------------------------//
//  行の高さ取得                                                            //
//--------------------------------------------------------------------------//
function TListViewEx.GetItemHeight: Integer;
var
  R: TRect;
begin
  if Items.Count > 0 then
  begin
    if ListView_GetItemRect(Handle, 0, R, LVIR_BOUNDS) then
      Result := R.Bottom - R.Top
    else
      Result := Font.Height + 8; // フォールバック値
  end
  else
    Result := Font.Height + 8; // 項目がない場合の仮高さ
end;

function TListViewEx.GetTopIndex: Integer;
begin
  Result := ListView_GetTopIndex(Self.Handle);
end;

function TListViewEx.GetViewHeight: Integer;
var
  RowH     : Integer;
  HeaderH  : Integer;
  Count    : Integer;
begin
  RowH    := GetListViewRowHeight(Self);
  HeaderH := GetListViewHeaderHeight(Self);
  Count   := Self.Items.Count + 1;

  Result :=  HeaderH + (RowH * Count) + 4;  // 枠の調整値
end;

function TListViewEx.GetListViewHeaderHeight(LV: TListView): Integer;
var
  Header: HWND;
  R: TRect;
begin
  Header := ListView_GetHeader(LV.Handle);
  if (Header <> 0) and GetWindowRect(Header, R) then
    Result := R.Bottom - R.Top
  else
    Result := 20;
end;

function TListViewEx.GetListViewRowHeight(LV: TListView): Integer;
var
  R: TRect;
begin
  if LV.Items.Count = 0 then
  begin
    // アイテムが無いと取得できないので仮の値
    Result := LV.Font.Height * -1 + 6;
    Exit;
  end;

  // アイテム0の矩形を取得
  if ListView_GetItemRect(LV.Handle, 0, R, LVIR_BOUNDS) then
    Result := R.Bottom - R.Top
  else
    Result := LV.Font.Height * -1 + 6;
end;



function TListViewEx.Insert(Index: Integer): TListItem;
var
  i: Integer;
begin
  // 末尾に追加して、それを指定位置まで押し上げる
  Items.Add;
  for i := Items.Count - 1 downto Index + 1 do
    Exchange(i, i - 1);
  Result := Items[Index]; // 挿入された位置にある項目を返す
end;

function TListViewEx.GetImageSize: Integer;
begin
  result :=FImages.Width;
end;

//--------------------------------------------------------------------------//
//  True:独自の描画処理を行う                                               //
//--------------------------------------------------------------------------//
procedure TListViewEx.SetRowColorStriped(const Value: Boolean);
begin
  OwnerDraw := Value;
end;

procedure TListViewEx.SetHintsEnabled(const Value: Boolean);
begin
  FHintsEnabled := Value;
  if FHintsEnabled then
  begin
    ParentShowHint := True;
  end
  else
  begin
    ParentShowHint := False;
    FLastIndex := -1;
    FLastHintText := '';
    Hint := '';
    ShowHint := False;
  end;
end;

//--------------------------------------------------------------------------//
//  指定した行が表示されるように調整                                        //
//--------------------------------------------------------------------------//
procedure TListViewEx.SetTopIndex(const Value: Integer);
begin
  if Value = -1 then exit;

  ItemFocused := Items[Value];                       // 指定行のフォーカスを有効に
  Items[Value].MakeVisible(True);                    // 指定した行が表示されるようスクロール
end;

//--------------------------------------------------------------------------//
//  指定した行と列の値を取得                                                //
//--------------------------------------------------------------------------//
function TListViewEx.GetCells(ACol, ARow: Integer): string;
var
  t : TStrings;
begin
  result := '';
  if ACol < 0 then exit;
  if ACol > Columns.Count-1 then exit;
  if ARow < 0 then exit;
  if ARow > Items.Count-1 then exit;
  if ACol = 0 then begin
    result := Items[ARow].Caption;
  end
  else begin
    t := Items[ARow].SubItems;
    while ACol-1 >=t.Count do t.Add('');
    result := t[ACol-1];
  end;
end;

//--------------------------------------------------------------------------//
//  指定した行と列の値を設定                                                //
//--------------------------------------------------------------------------//
procedure TListViewEx.SetCells(ACol, ARow: Integer; const Value: string);
var
  t : TStrings;
begin
  if ACol < 0 then exit;
  if ACol > Columns.Count-1 then exit;
  if ARow < 0 then exit;
  if ARow > Items.Count-1 then exit;
  if ACol = 0 then begin
    Items[ARow].Caption := Value;
  end
  else begin
    t := Items[ARow].SubItems;
    while ACol-1 >=t.Count do t.Add('');
    t[ACol-1] := Value;;
  end;
end;

procedure TListViewEx.SetHorzScrollBarVisible(const Value: Boolean);
var
  si: TScrollInfo;
begin
  si.cbSize := SizeOf(si);
  si.fMask := SIF_RANGE or SIF_PAGE;
  if Value then begin
    si.nMin := 0;
    si.nMax := 100;
    si.nPage := 50;
  end
  else begin
    si.nMin := 0;
    si.nMax := 0;
    si.nPage := 0;
  end;
  SetScrollInfo(Handle, SB_HORZ, si, True);
end;

procedure TListViewEx.SetVertScrollBarVisible(const Value: Boolean);
var
  si: TScrollInfo;
begin
  si.cbSize := SizeOf(si);
  si.fMask := SIF_RANGE or SIF_PAGE;
  if Visible then begin
    si.nMin := 0;
    si.nMax := 100; // 任意
    si.nPage := 50;
  end
  else begin
    si.nMin := 0;
    si.nMax := 0;
    si.nPage := 0;
  end;
  SetScrollInfo(Handle,SB_VERT, si, True);end;

procedure TListViewEx.UpdateHintAt(X, Y: Integer);
var
  Item: TListItem;
  NewHint: string;
  i : Integer;
begin
  if not FHintsEnabled then
  begin
    Hint := '';
    ShowHint := False;
    Exit;
  end;

  // アイテム取得
  Item := GetItemAt(X, Y);
  if Item = nil then Exit;

  i := Item.Index;
  if i = -1 then Exit;

  NewHint := '';
  // 新しいヒント内容を生成（必要ならサブアイテムも含めて拡張可）
  DoGetHint(i,NewHint);

  // 前回と同じなら何もしない（ちらつき防止）
  if (Item.Index = FLastIndex) and (NewHint = FLastHintText) then
    Exit;

  // ヒント更新
  FLastIndex     := Item.Index;
  FLastHintText  := NewHint;
  //Self.Hint      := NewHint;
  //Self.ShowHint  := False;
  //Self.ShowHint  := True;

  // ヒント再表示
  //P := ClientToScreen(Point(X, Y));
  //Application.ActivateHint(P);
end;

procedure TListViewEx.CMHintShow(var Msg: TCMHintShow);
begin
  if not FHintsEnabled then
  begin
    Msg.Result := 1;
    Exit;
  end;
  inherited;
end;

procedure TListViewEx.WMControlColorEdit(var Msg: TWMCtlColorEdit);
begin
  Winapi.Windows.SetTextColor(Msg.ChildDC, A2SCEditText);
  Winapi.Windows.SetBkColor(Msg.ChildDC, A2SCEditBackground);
  Msg.Result := LRESULT(FEditBrush);
end;

procedure TListViewEx.WMFinalAdjust(var Msg: TMessage);
begin
  AutoAdjustColumnWidth(1);
end;

// マウス移動イベントでヒントを設定
procedure TListViewEx.WMMouseMove(var Msg: TWMMouseMove);
var
  X, Y: Integer;
begin
  inherited;

  if not FHintsEnabled then Exit;

  X := Msg.XPos;
  Y := Msg.YPos;

  UpdateHintAt(X,Y);

end;

procedure TListViewEx.WMMouseWheel(var Msg: TWMMouseWheel);
var
  Handled: Boolean;
  Shift  : TShiftState;
  pt: TPoint;
begin
  Handled := False;

  // Shift/Ctrl/Alt 情報を変換
  Shift := KeyDataToShiftState(Msg.Keys);

  // 外部へ通知（ScrollBox などに渡すかどうかはユーザー側が判断）
  DoWheelScrollRequest(Msg.WheelDelta, Shift, Handled);

  // ユーザーが Handled = True にした場合は既定のスクロールをキャンセル
  if Handled then
    Exit;

  // 既定処理を実行（ListView 内部スクロール）
  inherited;

  if not FHintsEnabled then Exit;

  GetCursorPos(pt);
  pt := ScreenToClient(pt);

  UpdateHintAt(pt.X, pt.Y);

end;

function CanSafelySetFocus(Control: TWinControl): Boolean;
var
  Form: TCustomForm;
begin
  Result := Assigned(Control);
  if not Result then
    Exit;

  if (csDestroying in Control.ComponentState) or
     (not Control.HandleAllocated) or
     (not Control.Visible) or
     (not Control.Enabled) then
    Exit(False);

  Form := GetParentForm(Control);
  if not Assigned(Form) then
    Exit(False);

  if (csDestroying in Form.ComponentState) or
     (not Form.HandleAllocated) or
     (not Form.Visible) or
     (not Form.Enabled) then
    Exit(False);

  Result := Control.CanFocus;
end;

procedure SafeSetFocus(Control: TWinControl);
begin
  if not CanSafelySetFocus(Control) then
    Exit;
  try
    Control.SetFocus;
  except
    // Never propagate focus exceptions to plugin host.
  end;
end;



end.



