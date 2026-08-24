unit ImagePreviewFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  PNGImage, BitmapEx;

type
  TFrameImagePreview = class(TFrame)
    scrBox: TScrollBox;
    ImagePsd: TImage;
    procedure FrameResize(Sender: TObject);
    procedure ImagePsdMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ImagePsdMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure ImagePsdMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    { Private 宣言 }
    FBitmap: TBitmapEx;      // 読み込んだ画像を保持する作業用ビットマップ
    FPng: TPngImage;         // 透過付きで描画するPNG画像
    FFileName: string;       // 現在表示中の画像ファイル名
    FMouseDown: Boolean;     // True: ドラッグ移動中
    FMouseX: Integer;        // ドラッグ開始時のX座標
    FMouseY: Integer;        // ドラッグ開始時のY座標
    FScaleIndex: Integer;    // 拡大率テーブルの現在位置
    FShowed: Boolean;        // True: 画像表示を一度以上行った

    // 市松模様の背景を描画する
    procedure DrawCheckerBoard(Canvas: TCanvas; const R: TRect; CellSize: Integer = 16);
    // 現在の倍率で背景とPNGを再描画する
    procedure DrawPreview;
    // 表示領域内に収まるアスペクト比維持矩形を計算する
    procedure FitRectToAspect(var R: TRect; const AWidth, AHeight: Integer);
    // 拡大率を1段階上げる
    procedure ProcBig;
    // 拡大率を1段階下げる
    procedure ProcSmall;
    // ドラッグ量に応じてスクロール位置を移動する
    procedure ProcMove(const X, Y: Integer);
    // 現在の倍率に応じて描画領域サイズを更新する
    procedure ProcResize;
    // 現在の拡大率を取得する
    function GetScale: Double;
    // マウスホイールで拡大縮小を切り替える
    procedure WMMousewheel(var Msg: TMessage); message WM_MOUSEWHEEL;
  public
    { Public 宣言 }
    // プレビュー表示用の内部オブジェクトを初期化する
    constructor Create(AOwner: TComponent); override;
    // プレビュー表示用の内部オブジェクトを破棄する
    destructor Destroy; override;

    // 読み込み状態をクリアして空表示に戻す
    procedure Clear;
    // 指定した画像ファイルを読み込んで表示する
    procedure LoadFromFile(const AFileName: string);

    property FileName: string read FFileName;
    property Scale: Double read GetScale;
  end;

implementation

{$R *.dfm}

uses
  AviUtl2StyleColors;

const
  TBL_SCALE: array[0..4] of Double = (1, 1.5, 2, 4, 8);

constructor TFrameImagePreview.Create(AOwner: TComponent);
begin
  inherited;
  FBitmap := TBitmapEx.Create;
  FPng := TPngImage.Create;
  scrBox.VertScrollBar.Tracking := True;
  scrBox.HorzScrollBar.Tracking := True;
end;

destructor TFrameImagePreview.Destroy;
begin
  FPng.Free;
  FBitmap.Free;
  inherited;
end;

procedure TFrameImagePreview.Clear;
begin
  FFileName := '';
  FScaleIndex := 0;
  FShowed := False;
  FMouseDown := False;
  FBitmap.SetSize(0, 0);
  FPng.Free;
  FPng := TPngImage.Create;
  ProcResize;
  DrawPreview;
end;

procedure TFrameImagePreview.DrawCheckerBoard(Canvas: TCanvas; const R: TRect; CellSize: Integer);
var
  X: Integer;
  Y: Integer;
  Cell: TRect;
  Toggle: Boolean;
begin
  for Y := 0 to (R.Height div CellSize) do
  begin
    Toggle := (Y and 1) = 0;

    for X := 0 to (R.Width div CellSize) do
    begin
      if Toggle then
        Canvas.Brush.Color := A2SCPreviewChecker1
      else
        Canvas.Brush.Color := A2SCPreviewChecker2;

      Cell := Rect(
        R.Left + X * CellSize,
        R.Top + Y * CellSize,
        R.Left + (X + 1) * CellSize,
        R.Top + (Y + 1) * CellSize
      );
      Canvas.FillRect(Cell);
      Toggle := not Toggle;
    end;
  end;
end;

procedure TFrameImagePreview.DrawPreview;
var
  R: TRect;
begin
  if (ImagePsd.Width <= 0) or (ImagePsd.Height <= 0) then
    Exit;

  ImagePsd.Picture.Bitmap.SetSize(ImagePsd.Width, ImagePsd.Height);
  ImagePsd.Picture.Bitmap.PixelFormat := pf32bit;

  R := Rect(0, 0, ImagePsd.Width, ImagePsd.Height);
  DrawCheckerBoard(ImagePsd.Canvas, R, 16);

  if (FPng.Width <= 0) or (FPng.Height <= 0) then
    Exit;

  FitRectToAspect(R, FPng.Width, FPng.Height);
  ImagePsd.Canvas.StretchDraw(R, FPng);
  FShowed := True;
end;

procedure TFrameImagePreview.FitRectToAspect(var R: TRect; const AWidth, AHeight: Integer);
var
  DrawWidth: Integer;
  DrawHeight: Integer;
  TargetWidth: Integer;
  TargetHeight: Integer;
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    Exit;

  TargetWidth := R.Width;
  TargetHeight := R.Height;
  DrawWidth := TargetWidth;
  DrawHeight := MulDiv(TargetWidth, AHeight, AWidth);

  if DrawHeight > TargetHeight then
  begin
    DrawHeight := TargetHeight;
    DrawWidth := MulDiv(TargetHeight, AWidth, AHeight);
  end;

  R.Left := R.Left + (TargetWidth - DrawWidth) div 2;
  R.Top := R.Top + (TargetHeight - DrawHeight) div 2;
  R.Right := R.Left + DrawWidth;
  R.Bottom := R.Top + DrawHeight;
end;

procedure TFrameImagePreview.FrameResize(Sender: TObject);
begin
  ProcResize;
  if FShowed or (FFileName <> '') then
    DrawPreview;
end;

function TFrameImagePreview.GetScale: Double;
begin
  Result := TBL_SCALE[FScaleIndex];
end;

procedure TFrameImagePreview.ImagePsdMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then
    Exit;

  FMouseDown := True;
  FMouseX := X;
  FMouseY := Y;
end;

procedure TFrameImagePreview.ImagePsdMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if not FMouseDown then
    Exit;

  ProcMove(X, Y);
end;

procedure TFrameImagePreview.ImagePsdMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FMouseDown := False;
end;

procedure TFrameImagePreview.LoadFromFile(const AFileName: string);
begin
  Clear;
  if (AFileName = '') or (not FileExists(AFileName)) then
    Exit;

  FFileName := AFileName;
  FBitmap.LoadFromFile(AFileName);
  FPng.LoadFromFile(AFileName);
  ProcResize;
  DrawPreview;
end;

procedure TFrameImagePreview.ProcBig;
var
  XH: Double;
  YH: Double;
  Z1: Double;
  Z2: Double;
  X: Integer;
  Y: Integer;
begin
  Z1 := TBL_SCALE[FScaleIndex];
  if FScaleIndex + 1 > High(TBL_SCALE) then
    Exit;

  Inc(FScaleIndex);
  Z2 := TBL_SCALE[FScaleIndex];
  XH := scrBox.ClientWidth * Z2;
  YH := scrBox.ClientHeight * Z2;

  ImagePsd.Width := Round(XH);
  ImagePsd.Height := Round(YH);

  X := scrBox.HorzScrollBar.Position;
  Y := scrBox.VertScrollBar.Position;

  X := Round(X * Z2 / Z1);
  Y := Round(Y * Z2 / Z1);

  scrBox.HorzScrollBar.Position := X;
  scrBox.VertScrollBar.Position := Y;

  DrawPreview;
end;

procedure TFrameImagePreview.ProcMove(const X, Y: Integer);
var
  SX: Integer;
  SY: Integer;
  XH: Integer;
  YH: Integer;
begin
  XH := X - FMouseX;
  YH := Y - FMouseY;

  SX := scrBox.HorzScrollBar.Position - XH;
  SY := scrBox.VertScrollBar.Position - YH;

  scrBox.HorzScrollBar.Position := SX;
  scrBox.VertScrollBar.Position := SY;
end;

procedure TFrameImagePreview.ProcResize;
begin
  if FScaleIndex = 0 then
  begin
    ImagePsd.Width := scrBox.ClientWidth;
    ImagePsd.Height := scrBox.ClientHeight;
  end
  else
  begin
    ImagePsd.Width := Round(scrBox.ClientWidth * TBL_SCALE[FScaleIndex]);
    ImagePsd.Height := Round(scrBox.ClientHeight * TBL_SCALE[FScaleIndex]);
  end;
end;

procedure TFrameImagePreview.ProcSmall;
var
  XH: Double;
  YH: Double;
begin
  if FScaleIndex <= 0 then
    Exit;

  Dec(FScaleIndex);
  XH := scrBox.ClientWidth * TBL_SCALE[FScaleIndex];
  YH := scrBox.ClientHeight * TBL_SCALE[FScaleIndex];

  ImagePsd.Width := Round(XH);
  ImagePsd.Height := Round(YH);
  DrawPreview;

  scrBox.VertScrollBar.Position := ImagePsd.Height div 4;
  scrBox.HorzScrollBar.Position := ImagePsd.Width div 4;
end;

procedure TFrameImagePreview.WMMousewheel(var Msg: TMessage);
var
  D: Integer;
begin
  D := SmallInt(HiWord(Msg.wParam));
  if D > 0 then
    ProcBig
  else
    ProcSmall;
end;

end.
