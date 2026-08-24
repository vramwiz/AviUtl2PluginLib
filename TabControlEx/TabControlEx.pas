unit TabControlEx;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,StringListKey,StringListEx;



type
  TTabControlEx = class(TListBox)
  private
    { Private 宣言 }                         // 内部データを [行]セクションと[列]として管理
    FStrRows    : TStringListKey;            // 内部保持データ（行）
    FStrs       : TStringListEx;             // 内部保持データ（列）

    FTabs       : TStringListEx;             // 表示するタブ
    FViewX      : Integer;                   // 次に表示する列のX座標
    FRow        : Integer;                   // 表示処理中の行
    FCol        : Integer;                   // 表示処理中の列
    FIndex      : Integer;                   // 行列から取得するインデックス値
    FMouseRow   : Integer;                   // マウスカーソル上のタブの行
    FMouseCol   : Integer;                   // マウスカーソル上のタブの列
    FSelectRow  : Integer;                   // 選択中の行
    FSelectCol  : Integer;                   // 選択中の列
    FTimer      :  TTimer;                   // 再描画待ちタイマー

    procedure AddView(const Caption : string);
    // タブリストそのままで行列数を再度整列
    procedure TabClear();

    //function GetRowCount() : Integer;
    function GetColCount(const aRow : Integer) : Integer;

    function RowStrings(const aRow : Integer) : TStringListEx;
    function TextWidth(const str : string) : Integer;
    function TextCaption(const str : string) : string;
    procedure GetRowCol(const aRow,aCol : Integer;var Caption : string;var X : Integer);
    function GetRowColIndex(const aRow,aCol : Integer) : Integer;

    procedure ListBoxDrawRectRowCol(Canvas: TCanvas; Row,Col: Integer;aRect: TRect; State: TOwnerDrawState);

    procedure MouseXYToRowCol(const X,Y : Integer;var aRow,Col : Integer);
    procedure RefreshRow(const aRow : Integer);

    procedure OnSelfTimer(Sender: TObject);
    procedure OnSeldMouseDown(Sender: TObject; Button: TMouseButton;Shift: TShiftState; X, Y: Integer);
    procedure OnSelfMouseLeave(Sender: TObject);
    //procedure OnSelfClick(Sender: TObject);
    procedure OnSelfResize(Sender: TObject);
    procedure OnSelfMouseMove(Sender: TObject; Shift: TShiftState;X, Y: Integer);
    procedure OnListDrawItem(Control: TWinControl; Index: Integer; aRect: TRect;State: TOwnerDrawState);
    function GetTabIndex: Integer;
    procedure SetTabIndex(const Value: Integer);
  protected
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent);override;
    destructor Destroy;override;

    procedure Add(const Caption : string);
    procedure Clear();override;

    property Tabs : TStringListEx read FTabs;
    property TabIndex : Integer read GetTabIndex write SetTabIndex;
  end;

implementation

{ TTabControlEx }

constructor TTabControlEx.Create(AOwner: TComponent);
begin
  inherited;
  FTabs := TStringListEx.Create;
  FStrRows := TStringListKey.Create;
  FStrs := TStringListEx.Create;
  Style := lbOwnerDrawFixed;
  FMouseRow := -1;
  FSelectRow := -1;
  //OnClick := OnSelfClick;
  OnMouseMove := OnSelfMouseMove;
  OnMouseLeave := OnSelfMouseLeave;
  OnResize := OnSelfResize;
  OnDrawItem := OnListDrawItem;
  OnMouseDown := OnSeldMouseDown;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := 10;
  FTimer.OnTimer := OnSelfTimer;
end;

destructor TTabControlEx.Destroy;
begin
  FTimer.Free;
  FStrs.Free;
  FStrRows.Free;
  FTabs.Free;
  inherited;
end;

// 行と列から管理しているタブのキャプションと幅を取得
procedure TTabControlEx.GetRowCol(const aRow, aCol: Integer;
  var Caption: string; var X: Integer);
var
  ts,t : TStringListEx;
begin
  Caption := '';
  X := 0;
  ts := RowStrings(aRow);
  if ts = nil then exit;
  if aCol >= ts.Count then exit;

  t := TStringListEx.Create;
  try
    t.CommaTextEx := ts[aCol];
    Caption := t.GetStrs('Caption');
    X := t.GetInts('X');
  finally
    t.Free;
  end;

end;

// 行と列から管理しているタブのインデックス値を取得
function TTabControlEx.GetRowColIndex(const aRow, aCol: Integer): Integer;
var
  ts,t : TStringListEx;
begin
  result := -1;
  ts := RowStrings(aRow);
  if ts = nil then exit;
  if aCol >= ts.Count then exit;

  t := TStringListEx.Create;
  try
    t.CommaTextEx := ts[aCol];
    result := t.GetInts('Index');
  finally
    t.Free;
  end;
end;


// 指定した行の列数を取得
function TTabControlEx.GetColCount(const aRow: Integer): Integer;
var
  ts : TStringListEx;
begin
  result := 0;
  //if aRow >= GetRowCount() then exit;
  ts := RowStrings(aRow);
  if ts = nil then exit;
  result := ts.Count;

end;


// タブをクリア
procedure TTabControlEx.Clear;
begin
  inherited;              // リストk受ラスのクリアを実行
  FTabs.Clear;            // タブデータクリア
  FStrRows.Clear;         // 管理している行列のデータをクリア
  FStrs.Clear;            // 管理している列のデータをクリア
  FViewX := 0;            // 表示開始X座標を初期化
  FRow := 0;              // 処理行を初期化
  FCol := 0;              // 処理列を初期化
  FIndex := 0;            // 処理インデックス値を初期化
end;

// タブを追加  ※拡張制は無視
procedure TTabControlEx.Add(const Caption: string);
begin
  FTabs.Add(Caption);
  AddView(Caption);
end;

// 指定されたキャプションのタブを作成
procedure TTabControlEx.AddView(const Caption: string);
var
  s,ss : string;
  xh : Integer;
  ts : TStringListEx;
begin
  ss := TextCaption(Caption);                 // 余白付きのキャプションを取得
  xh := TextWidth(ss);                        // 必要なタブ幅を計算
  if FCol = 0 then begin                      // 最初の処理の場合
    Items.Add(TextCaption(Caption));          // リストに追加
    Inc(FCol);                                // 次の列へ
  end
  else begin                                  // 2回目以降の処理
    if  FViewX + xh > Width then begin        // タブが端を超える場合
      Items.Add(TextCaption(Caption));        // 次の行にタブを追加
      FCol := 1;                              // 次に処理数列は 2番目とする
      s := FStrs.Text;                        //
      FStrRows.Add(IntToStr(FRow),FStrs);     // 処理中の列データを行データに追加
      FStrs.Clear;                            // 列データを初期化
      Inc(FRow);                              // 次の列へ処理を以降
      FViewX := 0;                            // 表示位置を左端へ
    end
    else begin                                         // 描画範囲内の場合
      Items.Strings[FRow] := Items.Strings[FRow] + s;  // 列に追加
      Inc(FCol);                                       // 次の列へ処理を以降
    end;
  end;                                        // ※描画は独自のためここで代入した値は採用されない

  ts := TStringListEx.Create;                 // 値管理用文字列リスト生成
  try
    ts.SetStrs('Caption',Caption);            // タブのキャプションを保存
    ts.SetInts('X',FViewX);                   // タブのX座標を保存
    ts.SetInts('Index',FIndex);               // タブのインデックス値を保存
    FStrs.Add(ts.CommaTextEx);                // 列データに追加
  finally
    ts.Free;
  end;
  FViewX := FViewX + xh;                      // 表示X座標を横幅分加算
  FStrRows.Add(IntToStr(FRow),FStrs);         // 列データを行データに代入

  Inc(FIndex);                                // インデックス値を次へ
end;


// タブを表示
procedure TabControlDrawRectPolygon(Canvas: TCanvas;Rect: TRect);
var
  p : array[0..4] of TPoint;
begin
  p[0].X := Rect.Left;
  p[0].Y := Rect.Bottom;
  p[1].X := Rect.Left + 2;
  p[1].Y := Rect.Top;
  p[2].X := Rect.Right - 2;
  p[2].Y := Rect.Top;
  p[3].X := Rect.Right;
  p[3].Y := Rect.Bottom;
  p[4].X := Rect.Left;
  p[4].Y := Rect.Bottom;
  Canvas.Polygon(p);
end;

procedure TTabControlEx.ListBoxDrawRectRowCol(Canvas: TCanvas; Row,
  Col: Integer; aRect: TRect; State: TOwnerDrawState);
var
  cv : TCanvas;
  cF,cB : TColor;     // 通常時の文字色と背景色
begin
  cv := Canvas;
  if Row mod 2 = Col mod 2 then begin
    //cB := clWhite;
    cb := $00FFF0F0;
    cF := clBlack;
  end
  else begin
    //cB := clWebLightSkyBlue;
    cb := $00FFE0E0;
    cF := clBlack;
  end;
  //if (odFocused in State) or (odSelected in State)  then begin
    if (Col = FMouseCol) and (Row = FMouseRow) then begin    // マウスカーソル上のタブの場合
      cb := $00FFC0C0;
      cF := clBlack;
    end;
    if (Col = FSelectCol) and (Row = FSelectRow) then begin  // 選択中のタブの場合
      //CB := clActiveCaption  ;
      CB := clBlue ;
      CF := clWhite;
    end;

  //end;
  cv.Brush.Color:= cB;
  cv.Font.Color := cF;
  TabControlDrawRectPolygon(cv,aRect);
  //cv.FillRect(Rect);
end;


// 行描画イベント
procedure TTabControlEx.OnListDrawItem(Control: TWinControl; Index: Integer;
  aRect: TRect; State: TOwnerDrawState);
var
  cv : TCanvas;
  s :string;
  i,X: Integer;
  r : TRect;
begin
  cv := Canvas;
  cv.Pen.Width := 1;
  cv.Pen.Color := clBlack;
  for i := 0 to GetColCount(Index)-1 do begin    // 列数ループ
    GetRowCol(Index,i,s,x);                      // 表示する文字と幅を取得
    r := aRect;                                  // 描画範囲を取得
    r.Left := x;                                 // 左座標を計算
    r.Width := TextWidth(TextCaption(s));        // 文字幅を取得し計算
    cv.Brush.Style := bsSolid;                   // タブはべた塗り
    ListBoxDrawRectRowCol(cv,Index,i,r,State);   // タブ描画
    cv.Brush.Style := bsClear;                   // 文字背景を透明に
    cv.TextRect(r,r.Left+8,r.Top+3,s);           // 文字を描画
  end;
end;

// マウスボタン降下イベント
procedure TTabControlEx.OnSeldMouseDown(Sender: TObject; Button: TMouseButton;  Shift: TShiftState; X, Y: Integer);
begin
  MouseXYToRowCol(X,Y,FSelectRow,FSelectCol);
  RefreshRow(FSelectRow);                        // 指定した行を再描画
  //if FSelectRow >= Items.Count then exit;
  //Items[FSelectRow] := '';
end;

// マウス範囲外イベント
procedure TTabControlEx.OnSelfMouseLeave(Sender: TObject);
var
  aRow,aCol : Integer;
begin
  aRow := FMouseRow;                             // 現在値を一時保存
  aCol := FMouseCol;
  FMouseRow := -1;                               // マウス行を範囲外とする
  FMouseCol := -1;                               // マウス列を範囲外とする
  if (FMouseRow <> aRow) or                      // 以前の座標と異なる場合
     (FMouseCol <> aCol) then Refresh();         // 描画処理へ
end;

// マウス移動イベント
procedure TTabControlEx.OnSelfMouseMove(Sender: TObject; Shift: TShiftState; X,  Y: Integer);
var
  aRow,aCol : Integer;
begin
  aRow := FMouseRow;                                  // 現在値を一時保存
  aCol := FMouseCol;
  MouseXYToRowCol(X,Y,FMouseRow,FMouseCol);           // カーソル位置からタブの行列を取得
  if (FMouseRow <> aRow) or                           // 以前と異なる場合
     (FMouseCol <> aCol) then RefreshRow(FMouseRow);  // 行を再描画
end;

// マウス座標からタブの行列を取得
procedure TTabControlEx.MouseXYToRowCol(const X, Y: Integer; var aRow, Col: Integer);
var
  i,j,xx,xxx : Integer;
  s : string;
  ts : TStringListEx;
begin
  j := ItemAtPos(Point(x,y),False);                   // マウス座標から列を取得
  ts := RowStrings(j);                                // 該当する列データを取得
  if ts = nil then exit;                              // 範囲外の場合処理しない
  aRow := j;                                          // 行データを返す
  xxx := 0;                                           // 列データの初期値
  for i := 0 to GetColCount(j)-1 do begin             // 行にあるタブ列数ループ
    GetRowCol(j,i,s,xx);                              // キャプションと表示X座標を取得
    if xx < X then xxx := i;                          // 表示座標範囲内であれば列として採用
  end;
  Col := xxx;                                         // 列データを返す
end;


// サイズ変更イベント
procedure TTabControlEx.OnSelfResize(Sender: TObject);
begin
  FTimer.Enabled :=False;                      //
  FTimer.Enabled := true;                      // 再描画タイマー開始
end;

// 再描画タイマー
procedure TTabControlEx.OnSelfTimer(Sender: TObject);
var
  i: Integer;
begin
  FTimer.Enabled := False;
  Items.BeginUpdate();
  TabClear();                                  // タブ表示をクリア
  for i := 0 to FTabs.Count-1 do begin         // タブ数ループ
    AddView(FTabs[i]);                         // タブに追加
  end;
  Items.EndUpdate();
  FTimer.Enabled := False;
end;

// 指定された行の描画イベントを強制的に発生させる
procedure TTabControlEx.RefreshRow(const aRow: Integer);
begin
  if aRow < 0 then exit;
  if aRow >= Items.Count then exit;
  //Items.BeginUpdate();
  //Items[aRow] := '';
  Refresh();
  //Items.EndUpdate();
end;

function TTabControlEx.RowStrings(const aRow: Integer): TStringListEx;
begin
  result := FStrRows.Values[IntToStr(aRow)];
end;


function TTabControlEx.GetTabIndex: Integer;
var
  ts : TStringListEx;
begin
  result := -1;
  ts := RowStrings(FSelectRow);
  if ts = nil then exit;
  if FSelectCol >= ts.Count then exit;
  result := GetRowColIndex(FSelectRow,FSelectCol);
end;


procedure TTabControlEx.SetTabIndex(const Value: Integer);
begin
  FSelectRow := 0;
  FSelectCol := 0;
  if Items.Count>0 then begin
    ItemIndex := 0;
    //Items[0] := '';
  end;
end;

// タブリストそのままで行列数を再度整列
procedure TTabControlEx.TabClear;
begin
  Items.Clear;                    // 表示中のリストクリア
  FStrRows.Clear;                 // 内部保持データを初期化
  FStrs.Clear;                    // 内部保持データ（列）
  FViewX := 0;
  FRow := 0;
  FCol := 0;
  FIndex := 0;
end;

function TTabControlEx.TextCaption(const str: string): string;
begin
  result := '<' + str+ '>';
end;

function TTabControlEx.TextWidth(const str: string): Integer;
begin
  result := Canvas.TextWidth(str);
end;


end.
