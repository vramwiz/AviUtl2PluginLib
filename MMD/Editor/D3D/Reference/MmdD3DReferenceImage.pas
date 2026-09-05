unit MmdD3DReferenceImage;

// D3D Viewportへ重ねる参照画像の所有、寸法変換、半透明GDI描画を担当する。

interface

uses
  Vcl.Graphics;

type
  TMmdD3DReferenceImage = class
  private
    FBitmap: Vcl.Graphics.TBitmap;
  public
    // 空の参照画像コンテナーを生成する。
    constructor Create;
    // 保持中の画像を解放する。
    destructor Destroy; override;
    // 入力画像を独立コピーとして保持する。nilなら保持中の画像を消去する。
    procedure SetImage(Bitmap: Vcl.Graphics.TBitmap);
    // 現在描画可能な参照画像を保持しているか返す。
    function HasImage: Boolean;
    // Viewportと同寸法の暗色背景へ、縦横比を保った参照画像を中央配置して返す。
    procedure CopyForViewport(Destination: Vcl.Graphics.TBitmap; Width, Height: Integer);
    // Canvasへ高さ基準で拡縮した参照画像を半透明合成する。
    procedure Draw(Canvas: TCanvas; Width, Height: Integer);
  end;

implementation

uses
  Winapi.Windows,
  System.Types;

constructor TMmdD3DReferenceImage.Create;
begin
  inherited;
  FBitmap := Vcl.Graphics.TBitmap.Create;
end;

destructor TMmdD3DReferenceImage.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

procedure TMmdD3DReferenceImage.SetImage(Bitmap: Vcl.Graphics.TBitmap);
begin
  if Bitmap = nil then
    FBitmap.SetSize(0, 0)
  else
    FBitmap.Assign(Bitmap);
end;

function TMmdD3DReferenceImage.HasImage: Boolean;
begin
  Result := (FBitmap.Width > 0) and (FBitmap.Height > 0);
end;

procedure TMmdD3DReferenceImage.CopyForViewport(Destination: Vcl.Graphics.TBitmap; Width, Height: Integer);
var
  DestLeft, DestWidth: Integer;
begin
  Destination.PixelFormat := pf32bit;
  Destination.SetSize(Width, Height);
  Destination.Canvas.Brush.Color := RGB(14, 15, 19);
  Destination.Canvas.FillRect(Rect(0, 0, Width, Height));
  if not HasImage or (Height <= 0) then
    Exit;
  DestWidth := MulDiv(FBitmap.Width, Height, FBitmap.Height);
  DestLeft := (Width - DestWidth) div 2;
  Destination.Canvas.StretchDraw(Rect(DestLeft, 0, DestLeft + DestWidth,
    Height), FBitmap);
end;

procedure TMmdD3DReferenceImage.Draw(Canvas: TCanvas; Width, Height: Integer);
const
  REFERENCE_ALPHA = 112;
var
  Blend: TBlendFunction;
  DestLeft, DestWidth: Integer;
  OldBitmap: HGDIOBJ;
  SourceDC: HDC;
begin
  if not HasImage or (Height <= 0) then
    Exit;
  DestWidth := MulDiv(FBitmap.Width, Height, FBitmap.Height);
  DestLeft := (Width - DestWidth) div 2;
  SourceDC := CreateCompatibleDC(Canvas.Handle);
  if SourceDC = 0 then
    Exit;
  OldBitmap := SelectObject(SourceDC, FBitmap.Handle);
  try
    Blend.BlendOp := AC_SRC_OVER;
    Blend.BlendFlags := 0;
    Blend.SourceConstantAlpha := REFERENCE_ALPHA;
    Blend.AlphaFormat := 0;
    AlphaBlend(Canvas.Handle, DestLeft, 0, DestWidth, Height, SourceDC, 0, 0,
      FBitmap.Width, FBitmap.Height, Blend);
  finally
    SelectObject(SourceDC, OldBitmap);
    DeleteDC(SourceDC);
  end;
end;

end.
