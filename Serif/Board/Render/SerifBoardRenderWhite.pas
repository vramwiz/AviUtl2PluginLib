unit SerifBoardRenderWhite;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Graphics,
  SerifBoardDrawEngine, SerifBoardRenderThread, SerifBoardRenderColorTablePastel;

type
  TSerifBoardRenderWhiteFinishEvent = TSerifBoardRenderThreadFinishEvent;

  TSerifBoardRenderWhite = class
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
    // 白い角丸ボードと色付きの影を描画する
    procedure DrawShadowBoard(const AShadowColor: TColor; const ARect: TRect);
  public
    // 保存先フォルダを受け取ってレンダラーを初期化する
    constructor Create(const ABoardFolder: string);
    // 内部で保持している描画エンジンを破棄する
    destructor Destroy; override;

    // 白スタイルの角丸ボードPNGを色違いとサイズ違いでまとめて生成する
    procedure Execute;
    // まだ生成が必要か
    function NeedsRender: Boolean;
    // バックグラウンドスレッドでまとめて生成する
    procedure ExecuteAsync(const AOnFinish: TSerifBoardRenderWhiteFinishEvent = nil);
    // 破棄時に通知だけ外したい場合に使う
    procedure DetachAsync;
    // 現在バックグラウンド生成中か
    function IsRunning: Boolean;
  end;

implementation

  const OUTPUT_WIDTH = 1920;
  const OUTPUT_HEIGHT = 1080;
  const STYLE_NAME = '白';


{ TSerifBoardRenderWhite }

constructor TSerifBoardRenderWhite.Create(const ABoardFolder: string);
begin
  inherited Create;
  FEngine := TSerifBoardDrawEngine.Create;
  FBoardFolder := ABoardFolder;
end;

destructor TSerifBoardRenderWhite.Destroy;
begin
  DetachAsync;
  FEngine.Free;
  inherited;
end;

procedure TSerifBoardRenderWhite.Execute;
const
  FrameSizes: array[0..3] of record
    Left, Top, Right, Bottom: Integer;
    SizeLabel: string;
  end = (
    (Left: 0; Top: 850; Right: 1920; Bottom: 1080; SizeLabel: 'フル'),
    (Left: 270; Top: 850; Right: 1920; Bottom: 1080; SizeLabel: '右'),
    (Left: 0; Top: 850; Right: 1650; Bottom: 1080; SizeLabel: '左'),
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
      DrawShadowBoard(SerifBoardPastelColors[J].LightColor,
        Rect(FrameSizes[I].Left, FrameSizes[I].Top, FrameSizes[I].Right, FrameSizes[I].Bottom));
      FileName := '影_' + SerifBoardPastelColors[J].Name + '_' + FrameSizes[I].SizeLabel + '.png';
      EndDraw(FileName);
    end;
  end;
end;

function TSerifBoardRenderWhite.GetStyleFolder: string;
begin
  Result := TPath.Combine(FBoardFolder, Format('%dx%d_%s', [OUTPUT_WIDTH, OUTPUT_HEIGHT, STYLE_NAME]));
end;

function TSerifBoardRenderWhite.GetLastOutputFileName: string;
begin
  Result := TPath.Combine(GetStyleFolder, '影_' +
    SerifBoardPastelColors[High(SerifBoardPastelColors)].Name + '_中.png');
end;

function TSerifBoardRenderWhite.NeedsRender: Boolean;
begin
  Result := not TFile.Exists(GetLastOutputFileName);
end;

procedure TSerifBoardRenderWhite.ExecuteAsync(const AOnFinish: TSerifBoardRenderWhiteFinishEvent);
var
  Render: TSerifBoardRenderWhite;
begin
  if IsRunning then
    Exit;

  Render := TSerifBoardRenderWhite.Create(FBoardFolder);
  FAsyncHandle := TSerifBoardRenderThread.Run(Render.Execute, Render, True, AOnFinish);
end;

procedure TSerifBoardRenderWhite.DetachAsync;
begin
  if Assigned(FAsyncHandle) then
  begin
    FAsyncHandle.Detach;
    FAsyncHandle := nil;
  end;
end;

function TSerifBoardRenderWhite.IsRunning: Boolean;
begin
  Result := Assigned(FAsyncHandle) and FAsyncHandle.IsRunning;
end;

procedure TSerifBoardRenderWhite.BeginDraw(const AWidth, AHeight: Integer);
begin
  FEngine.BeginDraw(AWidth, AHeight);
end;

procedure TSerifBoardRenderWhite.EndDraw(const AFileName: string);
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

procedure TSerifBoardRenderWhite.DrawShadowBoard(const AShadowColor: TColor; const ARect: TRect);
const
  SHADOW_OFFSET_X = 10;
  SHADOW_OFFSET_Y = 10;
  SHADOW_ALPHA = $A8;
  CORNER_RADIUS = 16;
var
  WhiteRect: TRect;
  ShadowRect: TRect;
begin
  if (FEngine.Bitmap.Width <= 0) or (FEngine.Bitmap.Height <= 0) then
    Exit;

  ShadowRect := Rect(
    ARect.Left + SHADOW_OFFSET_X,
    ARect.Top + SHADOW_OFFSET_Y,
    ARect.Right,
    ARect.Bottom);
  FEngine.FillRoundRect(ShadowRect, CORNER_RADIUS, AShadowColor, SHADOW_ALPHA);

  WhiteRect := Rect(
    ARect.Left,
    ARect.Top,
    ARect.Right - SHADOW_OFFSET_X,
    ARect.Bottom - SHADOW_OFFSET_Y);
  FEngine.FillRoundRect(WhiteRect, CORNER_RADIUS, clWhite, $FF);
end;

end.
