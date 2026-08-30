unit PluginFilterSerifDrawRender;

interface

uses
  Winapi.Windows,System.SysUtils,System.Classes,Vcl.Graphics,
  AviUtl2Render,Math;

type
  //========================================================
  // セリフ描画クラス
  //========================================================
  TSerifRender = class(TAviUtl2Render)
  private
    FSerif        : string;
    FBaseColor    : TColor;
    FFrameColor   : TColor;
    FBevelColor   : TColor;

    procedure GetTable;
  public
    constructor Create; override;
    destructor Destroy; override;


    // 指定秒数のフレームを描画
    procedure Render(const Sec : Double); override;
    // 座標系を構築
    procedure BuildLayout();

    property Serif : string read FSerif write FSerif;

  end;


implementation

uses PluginFilterSerifDrawTable,PluginFilterTable;

{ TSerifRender }

constructor TSerifRender.Create;
begin
  inherited;

end;

destructor TSerifRender.Destroy;
begin

  inherited;
end;

procedure TSerifRender.GetTable;
begin
  FBaseColor     := GetColor(BaseColorItem);
  FFrameColor     := GetColor(FrameColorItem);
  FBevelColor     := GetColor(BevelColorItem);

end;

procedure TSerifRender.BuildLayout;
begin

end;

procedure TSerifRender.Render(const Sec: Double);
begin
  // フレーム初期化
  Clear;
  GetTable;
  BuildLayout;
  Bitmap.Canvas.Font.Size := -50;
  Bitmap.Canvas.Font.Color := clWhite;
  FBitmap.Canvas.TextOut(0,0,FSerif);
end;

end.
