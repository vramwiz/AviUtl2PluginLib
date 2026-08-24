unit SerifBoardRenderColor;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Graphics,
  SerifBoardDrawEngine, SerifBoardRenderThread, SerifBoardRenderColorTablePastel;

type
  TSerifBoardRenderColorFinishEvent = TSerifBoardRenderThreadFinishEvent;

  TSerifBoardRenderColor = class
  private
    FEngine: TSerifBoardDrawEngine;  // ボード画像を描く描画エンジン
    FBoardFolder: string;            // ボード画像の保存先フォルダ
    FAsyncHandle: ISerifBoardRenderThreadHandle;
    function GetStyleFolder: string;
    function GetLastOutputFileName: string;
    // 指定サイズの描画バッファを初期化する
    procedure BeginDraw(const AWidth, AHeight: Integer);
    // スタイル別フォルダにPNGを書き出す
    procedure EndDraw(const AFileName: string);
    // 色付きの土台と影付きの白カードを描画する
    procedure DrawColorBoard(const ABaseColor, AShadowColor: TColor; const ARect: TRect);
  public
    // 保存先フォルダを受け取ってレンダラーを初期化する
    constructor Create(const ABoardFolder: string);
    // 内部で保持している描画エンジンを破棄する
    destructor Destroy; override;

    // カラースタイルのボードPNGを色違いとサイズ違いでまとめて生成する
    procedure Execute;
    // まだ生成が必要か
    function NeedsRender: Boolean;
    // バックグラウンドスレッドでまとめて生成する
    procedure ExecuteAsync(const AOnFinish: TSerifBoardRenderColorFinishEvent = nil);
    // 破棄時に通知だけ外したい場合に使う
    procedure DetachAsync;
    // 現在バックグラウンド生成中か
    function IsRunning: Boolean;
  end;

implementation

const OUTPUT_WIDTH = 1920;
const OUTPUT_HEIGHT = 1080;
const STYLE_NAME = 'カラー';


{ TSerifBoardRenderColor }

constructor TSerifBoardRenderColor.Create(const ABoardFolder: string);
begin
  inherited Create;
  FEngine := TSerifBoardDrawEngine.Create;
  FBoardFolder := ABoardFolder;
end;

destructor TSerifBoardRenderColor.Destroy;
begin
  DetachAsync;
  FEngine.Free;
  inherited;
end;

procedure TSerifBoardRenderColor.Execute;
const
  FrameSizes: array[0..3] of record
    Left, Top, Right, Bottom: Integer;
    SizeLabel: string;
  end = (
    (Left:   0; Top: 850; Right: 1920; Bottom: 1080; SizeLabel: 'フル'),
    (Left: 270; Top: 850; Right: 1920; Bottom: 1080; SizeLabel: '右'),
    (Left:   0; Top: 850; Right: 1650; Bottom: 1080; SizeLabel: '左'),
    (Left: 270; Top: 850; Right: 1650; Bottom: 1080; SizeLabel: '中')
  );

var
  I, J: Integer;
  FileName: string;
begin
  if not NeedsRender then
    Exit;

  for I := Low(FrameSizes) to High(FrameSizes) do
  begin
    for J := Low(SerifBoardPastelColors) to High(SerifBoardPastelColors) do
    begin
      BeginDraw(1920, 1080);
      DrawColorBoard(
        SerifBoardPastelColors[J].LightColor,
        SerifBoardPastelColors[J].DarkColor,
        Rect(FrameSizes[I].Left, FrameSizes[I].Top, FrameSizes[I].Right, FrameSizes[I].Bottom));
      FileName := 'カラー_' + SerifBoardPastelColors[J].Name + '_' + FrameSizes[I].SizeLabel + '.png';
      EndDraw(FileName);
    end;
  end;
end;

function TSerifBoardRenderColor.GetStyleFolder: string;
begin
  Result := TPath.Combine(FBoardFolder, Format('%dx%d_%s', [OUTPUT_WIDTH, OUTPUT_HEIGHT, STYLE_NAME]));
end;

function TSerifBoardRenderColor.GetLastOutputFileName: string;
begin
  Result := TPath.Combine(GetStyleFolder, 'カラー_' +
    SerifBoardPastelColors[High(SerifBoardPastelColors)].Name + '_中.png');
end;

function TSerifBoardRenderColor.NeedsRender: Boolean;
begin
  Result := not TFile.Exists(GetLastOutputFileName);
end;

procedure TSerifBoardRenderColor.ExecuteAsync(const AOnFinish: TSerifBoardRenderColorFinishEvent);
var
  Render: TSerifBoardRenderColor;
begin
  if IsRunning then
    Exit;

  Render := TSerifBoardRenderColor.Create(FBoardFolder);
  FAsyncHandle := TSerifBoardRenderThread.Run(Render.Execute, Render, True, AOnFinish);
end;

procedure TSerifBoardRenderColor.DetachAsync;
begin
  if Assigned(FAsyncHandle) then
  begin
    FAsyncHandle.Detach;
    FAsyncHandle := nil;
  end;
end;

function TSerifBoardRenderColor.IsRunning: Boolean;
begin
  Result := Assigned(FAsyncHandle) and FAsyncHandle.IsRunning;
end;

procedure TSerifBoardRenderColor.BeginDraw(const AWidth, AHeight: Integer);
begin
  FEngine.BeginDraw(AWidth, AHeight);
end;

procedure TSerifBoardRenderColor.EndDraw(const AFileName: string);
var
  StyleFolder: string;
  FullFileName: string;
begin
  StyleFolder := GetStyleFolder;
  if not TDirectory.Exists(StyleFolder) then
    TDirectory.CreateDirectory(StyleFolder);

  FullFileName := TPath.Combine(StyleFolder, AFileName);
  FEngine.EndDraw(FullFileName);
end;

procedure TSerifBoardRenderColor.DrawColorBoard(const ABaseColor, AShadowColor: TColor; const ARect: TRect);
const
  SHADOW_OFFSET_X = 6;
  SHADOW_OFFSET_Y = 6;
  SHADOW_ALPHA    = $A8;
  CARD_MARGIN_X   = 28;
  CARD_MARGIN_Y   = 20;
  CORNER_RADIUS   = 16;
var
  CardRect: TRect;
  ShadowRect: TRect;
begin
  if (FEngine.Bitmap.Width <= 0) or (FEngine.Bitmap.Height <= 0) then
    Exit;

  FEngine.FillRect(ARect, ABaseColor, $FF);

  CardRect := Rect(
    ARect.Left + CARD_MARGIN_X,
    ARect.Top + CARD_MARGIN_Y,
    ARect.Right - CARD_MARGIN_X,
    ARect.Bottom - CARD_MARGIN_Y);

  ShadowRect := Rect(
    CardRect.Left + SHADOW_OFFSET_X,
    CardRect.Top + SHADOW_OFFSET_Y,
    CardRect.Right + SHADOW_OFFSET_X,
    CardRect.Bottom + SHADOW_OFFSET_Y);
  FEngine.FillRoundRect(ShadowRect, CORNER_RADIUS, AShadowColor, SHADOW_ALPHA);
  FEngine.FillRoundRect(CardRect, CORNER_RADIUS, clWhite, $FF);
end;

end.
