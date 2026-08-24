unit ListViewThumbnailEditScale;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Winapi.Windows, Winapi.Messages, Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics, Vcl.ImgList,
  ListViewEx,ListViewThumbnail,PSDScaleFrame,PSDImageAviUtl2,
  ThumbnailScale,CommCtrl;

  //===============================================================
  // ListView 拡張（サムネイル編集機能）
  //===============================================================
type
  TListViewThumbnailEditScale = class(TListViewThumbnail)
  private
    FEditIndex    : Integer;
    FEdited       : Boolean;
    FFrameScale   : TFramePsdFileImageScale;
    procedure OnScaleChangeOk(Sender: TObject);
    // カーソル位置の描画範囲を取得
    function GetEditCellRect(AColumn, AIndex: Integer): TRect;
    function GetColumn: Integer;
    function GetMouseClientPos: TPoint;
    // 横スクロールバーの現在位置を取得
    function GetScrollBarLeft() : Integer;
  protected
    FPSDImage     : TPSDImageAviUtl2;

    procedure WMLButtonDown(var Msg: TWMLButtonDown); message WM_LBUTTONDOWN;
    procedure WMVScroll(var Msg: TWMVScroll); message WM_VSCROLL;
    procedure WMHScroll(var Msg: TWMHScroll); message WM_HSCROLL;
    procedure WMMouseWheel(var Msg: TWMMouseWheel); message WM_MOUSEWHEEL;
    // サムネイル変更通知
    procedure DoEditChange();virtual;
    // 服装や表情のサムネイルアイコン表示
    procedure DrawThumbnail(Bitmap : TBitmap;Item : ThumbnailScaleItem);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // サムネイル編集開始
    procedure BeginEditThumbnail(Item : ThumbnailScaleItem);
    // サムネイル編集終了
    procedure EndEditThumbnail();

    // カーソルの列位置を取得
    function GetColumAt(const X,Y : Integer) : Integer;

    // 何番目の列にマウスカーソルがあるのかを取得
    property Column : Integer read GetColumn;
    // サムネイル編集フレームが表示されている間はTrue
    property ThumbnailEditing: Boolean read FEdited;
    //property PSDImage : TPSDImageElement write SetPSDImage;
  end;


implementation

uses AviUtl2StyleColors;

{ TListViewThumbnailEdit }

constructor TListViewThumbnailEditScale.Create(AOwner: TComponent);
begin
  inherited;
  FPSDImage := TPSDImageAviUtl2.Create;
end;

destructor TListViewThumbnailEditScale.Destroy;
begin
  if FFrameScale <> nil then FFrameScale.Free;
  FPSDImage.Free;
  inherited;
end;

procedure TListViewThumbnailEditScale.DoEditChange;
begin

end;

// アスペクトル比を合わせた範囲を取得 r : 変形先としての範囲 aWidth,aHeight:元画像ファイル
procedure RectToStreachRect(var r : TRect;const aWidth,aHeight : Integer);
var
  xh,yh,xhr,yhr : Integer;
begin
  //if aWidth = aHeight then exit;
  if aWidth = 0 then exit;
  if aHeight = 0 then exit;

  xhr := r.Width;
  yhr := r.Height;
  if aWidth > aHeight then begin
    yh := r.Width * aHeight div aWidth;
    r.Top := (yhr - yh) div 2;
    r.Height := yh;
  end
  else begin
    xh := r.Height * aWidth div aHeight;
    r.Left := (xhr - xh) div 2;
    r.Width := xh;
  end;
end;

procedure TListViewThumbnailEditScale.DrawThumbnail(Bitmap : TBitmap;Item: ThumbnailScaleItem);
var
  bmp : TBitmap;
  r : TRect;
begin
  bmp := TBitmap.Create;
  try
    if Item.ThumbnailScale > 0 then begin                 // 拡大率が指定されている場合
      bmp.SetSize(Item.ThumbnailScale,Item.ThumbnailScale);   // 指定サイズでビットマップを作成
      r := Rect(0,0,bmp.Width,bmp.Height);        // 描画先座標を指定
      bmp.Canvas.Brush.Style := bsSolid;
      bmp.Canvas.Brush.Color := A2SCListViewAltBackground;
      bmp.Canvas.FillRect(r);
      //bmp.Canvas.Draw(Item.ThumbnailX,Item.ThumbnailY,FPSDImage.Bitmap);                  // 指定座標に描画
      bmp.Canvas.Draw(Item.ThumbnailX,Item.ThumbnailY,FPSDImage.RenderedBitmap);            // 指定座標に描画
      r := Rect(0,0,Bitmap.Width,Bitmap.Height);        // 描画先座標を指定
      RectToStreachRect(r,bmp.Width,bmp.Height);      // アスペクト比を合わせる
      Bitmap.Canvas.StretchDraw(r,bmp);                // 拡大、縮小して描画
    end
    else begin                                         // 拡大率が指定されていない場合
      r := Rect(0,0,Bitmap.Width,Bitmap.Height);         // 描画先全体でアスペクト比を計算
      RectToStreachRect(r,FPSDImage.RenderedBitmap.Width,FPSDImage.RenderedBitmap.Height); // アスペクト比を合わせる
      Bitmap.Canvas.StretchDraw(r,FPSDImage.RenderedBitmap);              // 拡大、縮小して描画
    end;
  finally
    bmp.Free;
  end;

end;

function TListViewThumbnailEditScale.GetColumAt(const X, Y: Integer): Integer;
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

function TListViewThumbnailEditScale.GetColumn: Integer;
var
  p : TPoint;
  r : TRect;
begin
  P := GetMouseClientPos;
  r := GetEditCellRect(0,0);
  if p.X < r.Right then begin
    Result := 0;
  end
  else begin
    Result := 1;
  end;
  //result := GetColumAt(p.X,p.Y);                  // マウス位置から列を取得
end;

function TListViewThumbnailEditScale.GetEditCellRect(AColumn,
  AIndex: Integer): TRect;
var
  RowRect: TRect;
  ScrollX: Integer;
  ColLeft: Integer;
begin
  Result := Rect(0, 0, 0, 0);

  if (AColumn < 0) or (AColumn >= Columns.Count) then Exit;
  if (AIndex < 0) or (AIndex >= Items.Count) then Exit;

  // 各行の矩形を取得
  if not ListView_GetItemRect(Handle, AIndex, RowRect, LVIR_BOUNDS) then Exit;

  // スクロール位置の補正
  ScrollX := GetScrollPos(Handle, SB_HORZ);
  ColLeft := ColumnLeft(AColumn);

  Result.Left := ColLeft - ScrollX;
  Result.Top := RowRect.Top;
  //Result.Right := Result.Left + Col.Width div Round(CurrentPPI / 96.0);
  Result.Bottom := RowRect.Bottom;
  Result.Right := Result.Left + Result.Height;

end;

function TListViewThumbnailEditScale.GetMouseClientPos: TPoint;
begin
  GetCursorPos(Result);
  Result := ScreenToClient(Result);
end;

function TListViewThumbnailEditScale.GetScrollBarLeft: Integer;
var
  SInfo: TScrollInfo;
begin
  SInfo.cbSize := SizeOf(SInfo);
  SInfo.fMask := SIF_ALL;
  GetScrollInfo(Handle, SB_HORZ, SInfo);
  result := SInfo.nPos;
end;

procedure TListViewThumbnailEditScale.BeginEditThumbnail(Item : ThumbnailScaleItem);
var
  i : Integer;
  r : TRect;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  FEditIndex := i;
  if Item = nil then Exit;

  if FFrameScale = nil then begin
    FFrameScale := TFramePsdFileImageScale.Create(Self);
    FFrameScale.Parent := Self;
    FFrameScale.PSDImage := FPSDImage;
    FFrameScale.OnChangeOk := OnScaleChangeOk;
  end;


  FEdited := True;
  r := GetEditCellRect(0,i);
  // 下位クラスで初期値を設定
  //Item.DoEditStart(FFrameScale.PSDImage);
  FFrameScale.PSDScale := Item;
  FFrameScale.Top := r.Top;
  FFrameScale.Left := r.Left;
  FFrameScale.Width := r.Width;
  FFrameScale.Height := r.Height;
  FFrameScale.ShowScale;
  FFrameScale.Visible := True;

end;

procedure TListViewThumbnailEditScale.EndEditThumbnail;
begin
  if not FEdited then Exit;                 // 編集状態でなければ処理しない
  FFrameScale.Visible := False;

  FEdited := False;                         // 編集状態解除
  if Assigned(FFrameScale) then FFrameScale.Hide;
  DoEditChange();
  ShowItemRefresh(ItemIndex);
end;



procedure TListViewThumbnailEditScale.OnScaleChangeOk(Sender: TObject);
begin
  DoEditChange();
  FFrameScale.Visible := False;
end;

procedure TListViewThumbnailEditScale.WMHScroll(var Msg: TWMHScroll);
begin
  EndEditThumbnail();
  inherited;
end;

procedure TListViewThumbnailEditScale.WMLButtonDown(var Msg: TWMLButtonDown);
begin
  EndEditThumbnail();
  inherited;
end;

procedure TListViewThumbnailEditScale.WMMouseWheel(var Msg: TWMMouseWheel);
begin
  EndEditThumbnail();
  inherited;
end;

procedure TListViewThumbnailEditScale.WMVScroll(var Msg: TWMVScroll);
begin
  EndEditThumbnail();
  inherited;
end;

end.
