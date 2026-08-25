unit PSDScaleFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,PSDImageAviUtl2,Vcl.StdCtrls,ThumbnailScale;

   // ユーザーが指定した任意の場所を表示領域とする表示設定フレーム
type
  TFramePsdFileImageScale = class(TFrame)
    ImageScale: TImage;
    procedure ImageScaleMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ImageScaleMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure ImageScaleMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure btnCancelClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
    procedure FrameExit(Sender: TObject);
  private
    { Private 宣言 }
    FPSDImage    : TPSDImageAviUtl2;
    FBitmap      : TBitmap;

    FMouseDown   : Boolean;
    FMouseDnX    : Integer;
    FMouseDnY    : Integer;
    FClickDnX    : Integer; // ドラックとクリック判定専用
    FClickDnY    : Integer;

    FOnChangeScale: TNotifyEvent;
    FPSDScale: ThumbnailScaleItem;
    FOnChangeCancel: TNotifyEvent;
    FOnChangeOk: TNotifyEvent;
    procedure ViewScale();

    procedure ProcMove(const X,Y: Integer);
    // 拡大
    procedure ProcBig();
    // 縮小
    procedure ProcSmall();

    procedure ProcReset();
    // ホイールスクロールイベント
    procedure WMMousewheel(var Msg: TMessage); message WM_MOUSEWHEEL;

  protected
    procedure DoChangeScale();virtual;
    procedure DoChangeOk();virtual;
    procedure DoChangeCancel();virtual;
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;
    procedure ShowScale();
    property PSDImage : TPSDImageAviUtl2 read FPSDImage write FPSDImage;
    property PSDScale : ThumbnailScaleItem read FPSDScale write FPSDScale;
    property OnChangeScale : TNotifyEvent read FOnChangeScale write FOnChangeScale;
    property OnChangeOk : TNotifyEvent read FOnChangeOk write FOnChangeOk;
    property OnChangeCancel : TNotifyEvent read FOnChangeCancel write FOnChangeCancel;
  end;

implementation

uses AviUtl2StyleColors;

{$R *.dfm}

{ TFramePsdFileImageScale }

constructor TFramePsdFileImageScale.Create(AOwner: TComponent);
begin
  inherited;
  FBitmap := TBitmap.Create;
end;

destructor TFramePsdFileImageScale.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

procedure TFramePsdFileImageScale.btnCancelClick(Sender: TObject);
begin
  DoChangeCancel;
  Hide;
end;

procedure TFramePsdFileImageScale.btnOkClick(Sender: TObject);
begin
  DoChangeOk;
  Hide;
end;

procedure TFramePsdFileImageScale.DoChangeCancel;
begin
  if Assigned(FOnChangeCancel) then FOnChangeCancel(Self);
end;

procedure TFramePsdFileImageScale.DoChangeOk;
begin
  if Assigned(FOnChangeOk) then FOnChangeOk(Self);
end;

procedure TFramePsdFileImageScale.DoChangeScale;
begin
  if Assigned(FOnChangeScale) then FOnChangeScale(Self);
end;

procedure TFramePsdFileImageScale.FrameExit(Sender: TObject);
begin
  Hide;
end;

procedure TFramePsdFileImageScale.ImageScaleMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then begin
    ProcReset();
    ViewScale();
    exit;
  end;

  if Button <> mbLeft then exit;

  FMouseDown := True;
  FMouseDnX := X;
  FMouseDnY := Y;
  FClickDnX := X;
  FClickDnY := Y;
end;

procedure TFramePsdFileImageScale.ImageScaleMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin

  if not FMouseDown then exit;

  ProcMove(X,Y);

  ViewScale();
end;

const
  CLICK_MOVE_THRESHOLD = 4;

procedure TFramePsdFileImageScale.ImageScaleMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FMouseDown := False;
  if (Abs(X - FClickDnX) <= CLICK_MOVE_THRESHOLD) and
     (Abs(Y - FClickDnY) <= CLICK_MOVE_THRESHOLD) then
  begin
    DoChangeOk();
  end;
end;

procedure TFramePsdFileImageScale.ProcBig;
var
  p : TPoint;
begin
  if FPSDScale.ThumbnailScale < 32 then exit;

  p := Mouse.CursorPos;
  p := ScreenToClient(p);

  FPSDScale.ThumbnailScale := FPSDScale.ThumbnailScale * 3 div 5;
  FPSDScale.ThumbnailX := FPSDScale.ThumbnailX - p.X*3 div 5;
  FPSDScale.ThumbnailY :=  FPSDScale.ThumbnailY - p.Y*3 div 5;
end;

procedure TFramePsdFileImageScale.ProcSmall;
var
  p : TPoint;
begin
  //if FPSDScale.ThumbnailScale > FPSDImage.Bitmap.Width then exit;
  if FPSDScale.ThumbnailScale > FPSDImage.RenderedBitmap.Width then exit;

  p := Mouse.CursorPos;
  p := ScreenToClient(p);

  FPSDScale.ThumbnailX := FPSDScale.ThumbnailX + p.X * 3 div 5;
  FPSDScale.ThumbnailY :=  FPSDScale.ThumbnailY + p.Y * 3 div 5;

  FPSDScale.ThumbnailScale := FPSDScale.ThumbnailScale * 5 div 3;
end;


procedure TFramePsdFileImageScale.ProcMove(const X, Y: Integer);
var
  xh,yh : Integer;
begin
  xh := X - FMouseDnX;
  yh := Y - FMouseDnY;

  FPSDScale.ThumbnailX := FPSDScale.ThumbnailX + xh*FPSDScale.ThumbnailScale div 100;
  FPSDScale.ThumbnailY := FPSDScale.ThumbnailY + yh*FPSDScale.ThumbnailScale div 100;

  FMouseDnX := X;
  FMouseDnY := Y;
end;

procedure TFramePsdFileImageScale.ProcReset;
begin
  FPSDScale.ThumbnailX := 0;
  FPSDScale.ThumbnailY := 0;
  //FPSDScale.ThumbnailScale := FPSDImage.Bitmap.Width;
  FPSDScale.ThumbnailScale := FPSDImage.RenderedBitmap.Width;
end;

procedure TFramePsdFileImageScale.ShowScale;
var
  bmp : TBitmap;
begin
  ImageScale.Left := 0;
  ImageScale.Top := 0;
  ImageScale.Width := Width;
  ImageScale.Height := Height;
  FBitmap.SetSize(FPSDScale.ThumbnailScale,FPSDScale.ThumbnailScale);
  FBitmap.PixelFormat := pf32bit;
  if FPSDScale.ThumbnailScale <= 0 then begin           // XY幅が設定されていない場合
    //bmp := FPSDImage.Bitmap;                            // 立ち絵画像を参照
    bmp := FPSDImage.RenderedBitmap;                            // 立ち絵画像を参照
    if bmp.Height > bmp.Width then begin                // 縦横を比較
      FPSDScale.ThumbnailScale := bmp.Width;            // 小さい方を採用
    end
    else begin
      FPSDScale.ThumbnailScale := bmp.Height;
    end;
  end;

  ViewScale();
  Visible := True;;
end;

procedure TFramePsdFileImageScale.ViewScale;
var
  r : TRect;
  cv : TCanvas;
begin
  FBitmap.SetSize(FPSDScale.ThumbnailScale,FPSDScale.ThumbnailScale);
  FBitmap.PixelFormat := pf32bit;
  FBitmap.AlphaFormat := afDefined;

  cv := ImageScale.Canvas;
  cv.Brush.Style := bsSolid;
  cv.Brush.Color := A2SCListViewBackground;
  cv.FillRect(ImageScale.ClientRect);  // ← これがないと残像が絶対消えない

  // FBitmap 側は必要ならクリア（任意）
  FBitmap.Canvas.Brush.Color := clWhite;
  FBitmap.Canvas.FillRect(Rect(0, 0, FBitmap.Width, FBitmap.Height));

  //FBitmap.Canvas.Draw(FPSDScale.ThumbnailX, FPSDScale.ThumbnailY, FPSDImage.Bitmap);
  FBitmap.Canvas.Draw(FPSDScale.ThumbnailX, FPSDScale.ThumbnailY, FPSDImage.RenderedBitmap);

  r := Rect(0,0,ImageScale.Width,ImageScale.Height);
  ImageScale.Canvas.StretchDraw(r,FBitmap);
end;

procedure TFramePsdFileImageScale.WMMousewheel(var Msg: TMessage);
var
  d : Integer;
begin
  d := shortint(HiWord(Msg.wParam));
  if (d > 0) then begin                // ホイールを奥
    ProcBig();
  end
  else begin                           // ホイール手前
    ProcSmall();
  end;
  ViewScale();

end;

end.
