unit SerifBoardRender;

interface

uses
  System.SysUtils, System.Classes, Vcl.Graphics, SerifBoardDrawEngine;

type
  TSerifBoardRender = class
  private
    FEngine: TSerifBoardDrawEngine;  // 実際の描画を担当する描画エンジン
  public
    // 描画エンジンを生成してレンダラーを初期化する
    constructor Create;
    // 内部で保持している描画エンジンを破棄する
    destructor Destroy; override;

    // 指定サイズで描画を開始する
    procedure BeginDraw(const AWidth, AHeight: Integer);
    // 描画結果をファイルへ保存する
    procedure EndDraw(const AFileName: string);

    // 動作確認用の図形を描画する
    procedure DrawTestShapes;
    // セリフボード用の表示領域を描画する
    procedure DrawCoordArea;

    property Engine: TSerifBoardDrawEngine read FEngine;
  end;

implementation

{ TSerifBoardRender }

constructor TSerifBoardRender.Create;
begin
  inherited Create;
  FEngine := TSerifBoardDrawEngine.Create;
end;

destructor TSerifBoardRender.Destroy;
begin
  FEngine.Free;
  inherited;
end;

procedure TSerifBoardRender.BeginDraw(const AWidth, AHeight: Integer);
begin
  FEngine.BeginDraw(AWidth, AHeight);
end;

procedure TSerifBoardRender.EndDraw(const AFileName: string);
begin
  FEngine.EndDraw(AFileName);
end;

procedure TSerifBoardRender.DrawTestShapes;
begin
  if (FEngine.Bitmap.Width <= 0) or (FEngine.Bitmap.Height <= 0) then
    Exit;

  FEngine.FillRect(Rect(120, 120, 620, 420), clRed, $FF);
  FEngine.FillEllipse(Rect(760, 140, 1160, 540), clLime, $FF);
  FEngine.FillRect(Rect(1000, 700, 1500, 900), clBlue, $FF);
  FEngine.FillEllipse(Rect(300, 680, 620, 980), clYellow, $FF);
end;

procedure TSerifBoardRender.DrawCoordArea;
begin
  if (FEngine.Bitmap.Width <= 0) or (FEngine.Bitmap.Height <= 0) then
    Exit;

  FEngine.FillRect(Rect(0, 850, 1920, 1080), clBlack, $FF);
  FEngine.DrawFrameRect(Rect(0, 850, 1920, 1080), clWhite, 2);
end;

end.
