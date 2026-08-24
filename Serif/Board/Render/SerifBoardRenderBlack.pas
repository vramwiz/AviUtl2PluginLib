unit SerifBoardRenderBlack;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Graphics,
  SerifBoardDrawEngine, SerifBoardRenderColorTableNeon, SerifBoardRenderThread;

type
  TSerifBoardRenderBlackFinishEvent = TSerifBoardRenderThreadFinishEvent;

  TSerifBoardRenderBlack = class
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
    // 黒ベースの帯と2段のネオン枠を描画する
    procedure DrawNeonFrame(const ADarkColor, ABaseColor: TColor; const ARect: TRect);
  public
    // 保存先フォルダを受け取ってレンダラーを初期化する
    constructor Create(const ABoardFolder: string);
    // 内部で保持している描画エンジンを破棄する
    destructor Destroy; override;

    // 黒スタイルのネオン枠PNGを色違いとサイズ違いでまとめて生成する
    procedure Execute;
    // まだ生成が必要か
    function NeedsRender: Boolean;
    // バックグラウンドスレッドでまとめて生成する
    procedure ExecuteAsync(const AOnFinish: TSerifBoardRenderBlackFinishEvent = nil);
    // 破棄時に通知だけ外したい場合に使う
    procedure DetachAsync;
    // 現在バックグラウンド生成中か
    function IsRunning: Boolean;

    //property StyleName: string read FStyleName;
  end;

implementation

const OUTPUT_WIDTH = 1920;
const OUTPUT_HEIGHT = 1080;
const STYLE_NAME = '黒';



{ TSerifBoardRenderBlack }

constructor TSerifBoardRenderBlack.Create(const ABoardFolder: string);
begin
  inherited Create;
  FEngine := TSerifBoardDrawEngine.Create;
  FBoardFolder := ABoardFolder;
end;

destructor TSerifBoardRenderBlack.Destroy;
begin
  DetachAsync;
  FEngine.Free;
  inherited;
end;

procedure TSerifBoardRenderBlack.Execute;
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
    for J := Low(SerifBoardNeonColors) to High(SerifBoardNeonColors) do
    begin
      BeginDraw(1920, 1080);
      DrawNeonFrame(
        SerifBoardNeonColors[J].DarkColor,
        SerifBoardNeonColors[J].BaseColor,
        Rect(FrameSizes[I].Left, FrameSizes[I].Top, FrameSizes[I].Right, FrameSizes[I].Bottom));
      FileName := 'ネオン_' + SerifBoardNeonColors[J].Name + '_' + FrameSizes[I].SizeLabel + '.png';
      EndDraw(FileName);
    end;
  end;
end;

function TSerifBoardRenderBlack.GetStyleFolder: string;
begin
  Result := TPath.Combine(FBoardFolder, Format('%dx%d_%s', [OUTPUT_WIDTH, OUTPUT_HEIGHT, STYLE_NAME]));
end;

function TSerifBoardRenderBlack.GetLastOutputFileName: string;
begin
  Result := TPath.Combine(GetStyleFolder, 'ネオン_' +
    SerifBoardNeonColors[High(SerifBoardNeonColors)].Name + '_中.png');
end;

function TSerifBoardRenderBlack.NeedsRender: Boolean;
begin
  Result := not TFile.Exists(GetLastOutputFileName);
end;

procedure TSerifBoardRenderBlack.ExecuteAsync(const AOnFinish: TSerifBoardRenderBlackFinishEvent);
var
  Render: TSerifBoardRenderBlack;
begin
  if IsRunning then
    Exit;

  Render := TSerifBoardRenderBlack.Create(FBoardFolder);
  FAsyncHandle := TSerifBoardRenderThread.Run(Render.Execute, Render, True, AOnFinish);
end;

procedure TSerifBoardRenderBlack.DetachAsync;
begin
  if Assigned(FAsyncHandle) then
  begin
    FAsyncHandle.Detach;
    FAsyncHandle := nil;
  end;
end;

function TSerifBoardRenderBlack.IsRunning: Boolean;
begin
  Result := Assigned(FAsyncHandle) and FAsyncHandle.IsRunning;
end;

procedure TSerifBoardRenderBlack.BeginDraw(const AWidth, AHeight: Integer);
begin
  FEngine.BeginDraw(AWidth, AHeight);
end;

procedure TSerifBoardRenderBlack.EndDraw(const AFileName: string);
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

procedure TSerifBoardRenderBlack.DrawNeonFrame(const ADarkColor, ABaseColor: TColor; const ARect: TRect);
const
  NEON_OUTER_THICKNESS = 4;
  NEON_INNER_THICKNESS = 4;
var
  InnerRect: TRect;
begin
  if (FEngine.Bitmap.Width <= 0) or (FEngine.Bitmap.Height <= 0) then
    Exit;

  FEngine.FillRect(ARect, clBlack, $FF);

  FEngine.DrawFrameRect(ARect, ADarkColor, NEON_OUTER_THICKNESS);
  InnerRect := Rect(
    ARect.Left + NEON_OUTER_THICKNESS,
    ARect.Top + NEON_OUTER_THICKNESS,
    ARect.Right - NEON_OUTER_THICKNESS,
    ARect.Bottom - NEON_OUTER_THICKNESS);
  FEngine.DrawFrameRect(InnerRect, ABaseColor, NEON_INNER_THICKNESS);
end;

end.
