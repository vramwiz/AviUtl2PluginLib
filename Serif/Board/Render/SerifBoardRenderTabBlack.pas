unit SerifBoardRenderTabBlack;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Graphics,
  SerifBoardDrawEngine, SerifBoardRenderThread, SerifBoardRenderColorTableNeon, Math;

type
  TSerifBoardRenderTabBlackFinishEvent = TSerifBoardRenderThreadFinishEvent;

  TSerifBoardRenderTabBlack = class
  private
    FEngine: TSerifBoardDrawEngine;  // ボード画像を描く描画エンジン
    FBoardFolder: string;            // ボード画像の保存先フォルダ
    FAsyncHandle: ISerifBoardRenderThreadHandle;
    function GetStyleFolder: string;
    function GetLastOutputFileName: string;
    procedure BeginDraw(const AWidth, AHeight: Integer);
    procedure EndDraw(const AFileName: string);
    procedure DrawTabBlackBoard(const ADarkColor, ABaseColor: TColor; const ARect: TRect);
  public
    constructor Create(const ABoardFolder: string);
    destructor Destroy; override;

    procedure Execute;
    function NeedsRender: Boolean;
    procedure ExecuteAsync(const AOnFinish: TSerifBoardRenderTabBlackFinishEvent = nil);
    procedure DetachAsync;
    function IsRunning: Boolean;
  end;

implementation

const OUTPUT_WIDTH = 1920;
const OUTPUT_HEIGHT = 1080;
const STYLE_NAME = 'タブ黒';

const
  TAB_HEIGHT = 64;
  TAB_WIDTH = 250;
  TAB_ATTACH_OVERLAP = 14;
  BODY_RADIUS = 18;
  TAB_RADIUS = 18;
  NEON_OUTER_THICKNESS = 4;
  NEON_INNER_THICKNESS = 4;

{ TSerifBoardRenderTabBlack }

constructor TSerifBoardRenderTabBlack.Create(const ABoardFolder: string);
begin
  inherited Create;
  FEngine := TSerifBoardDrawEngine.Create;
  FBoardFolder := ABoardFolder;
end;

destructor TSerifBoardRenderTabBlack.Destroy;
begin
  DetachAsync;
  FEngine.Free;
  inherited;
end;

procedure TSerifBoardRenderTabBlack.Execute;
const
  FrameSizes: array[0..1] of record
    Left, Top, Right, Bottom: Integer;
    SizeLabel: string;
  end = (
    (Left: 0; Top: 850; Right: 1920; Bottom: 1080; SizeLabel: 'フル'),
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
      BeginDraw(OUTPUT_WIDTH, OUTPUT_HEIGHT);
      DrawTabBlackBoard(
        SerifBoardNeonColors[J].DarkColor,
        SerifBoardNeonColors[J].BaseColor,
        Rect(FrameSizes[I].Left, FrameSizes[I].Top, FrameSizes[I].Right, FrameSizes[I].Bottom));
      FileName := STYLE_NAME + '_' + SerifBoardNeonColors[J].Name + '_' + FrameSizes[I].SizeLabel + '.png';
      EndDraw(FileName);
    end;
  end;
end;

function TSerifBoardRenderTabBlack.GetStyleFolder: string;
begin
  Result := TPath.Combine(FBoardFolder, Format('%dx%d_%s', [OUTPUT_WIDTH, OUTPUT_HEIGHT, STYLE_NAME]));
end;

function TSerifBoardRenderTabBlack.GetLastOutputFileName: string;
begin
  Result := TPath.Combine(GetStyleFolder, STYLE_NAME + '_' +
    SerifBoardNeonColors[High(SerifBoardNeonColors)].Name + '_中.png');
end;

function TSerifBoardRenderTabBlack.NeedsRender: Boolean;
begin
  Result := not TFile.Exists(GetLastOutputFileName);
end;

procedure TSerifBoardRenderTabBlack.ExecuteAsync(const AOnFinish: TSerifBoardRenderTabBlackFinishEvent);
var
  Render: TSerifBoardRenderTabBlack;
begin
  if IsRunning then
    Exit;

  Render := TSerifBoardRenderTabBlack.Create(FBoardFolder);
  FAsyncHandle := TSerifBoardRenderThread.Run(Render.Execute, Render, True, AOnFinish);
end;

procedure TSerifBoardRenderTabBlack.DetachAsync;
begin
  if Assigned(FAsyncHandle) then
  begin
    FAsyncHandle.Detach;
    FAsyncHandle := nil;
  end;
end;

function TSerifBoardRenderTabBlack.IsRunning: Boolean;
begin
  Result := Assigned(FAsyncHandle) and FAsyncHandle.IsRunning;
end;

procedure TSerifBoardRenderTabBlack.BeginDraw(const AWidth, AHeight: Integer);
begin
  FEngine.BeginDraw(AWidth, AHeight);
end;

procedure TSerifBoardRenderTabBlack.EndDraw(const AFileName: string);
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

procedure TSerifBoardRenderTabBlack.DrawTabBlackBoard(const ADarkColor, ABaseColor: TColor; const ARect: TRect);
var
  MainRect: TRect;
  TabRect: TRect;
begin
  if (FEngine.Bitmap.Width <= 0) or (FEngine.Bitmap.Height <= 0) then
    Exit;

  MainRect := Rect(ARect.Left, ARect.Top + TAB_HEIGHT, ARect.Right, ARect.Bottom);
  TabRect := Rect(ARect.Left + 24, ARect.Top, Min(ARect.Left + 24 + TAB_WIDTH, ARect.Right - 120),
    MainRect.Top + TAB_ATTACH_OVERLAP);

  // 外暗色 -> 内明色 -> 中黒 の3段で、角丸を保ったまま太いネオン枠を作る
  FEngine.FillRoundRect(MainRect, BODY_RADIUS, ADarkColor, $FF);
  FEngine.FillRoundRect(
    Rect(
      MainRect.Left + NEON_OUTER_THICKNESS,
      MainRect.Top + NEON_OUTER_THICKNESS,
      MainRect.Right - NEON_OUTER_THICKNESS,
      MainRect.Bottom - NEON_OUTER_THICKNESS),
    Max(0, BODY_RADIUS - NEON_OUTER_THICKNESS), ABaseColor, $FF);
  FEngine.FillRoundRect(
    Rect(
      MainRect.Left + NEON_OUTER_THICKNESS + NEON_INNER_THICKNESS,
      MainRect.Top + NEON_OUTER_THICKNESS + NEON_INNER_THICKNESS,
      MainRect.Right - NEON_OUTER_THICKNESS - NEON_INNER_THICKNESS,
      MainRect.Bottom - NEON_OUTER_THICKNESS - NEON_INNER_THICKNESS),
    Max(0, BODY_RADIUS - NEON_OUTER_THICKNESS - NEON_INNER_THICKNESS), clBlack, $FF);

  FEngine.FillRoundRect(TabRect, TAB_RADIUS, ADarkColor, $FF);
  FEngine.FillRoundRect(
    Rect(
      TabRect.Left + NEON_OUTER_THICKNESS,
      TabRect.Top + NEON_OUTER_THICKNESS,
      TabRect.Right - NEON_OUTER_THICKNESS,
      TabRect.Bottom - NEON_OUTER_THICKNESS),
    Max(0, TAB_RADIUS - NEON_OUTER_THICKNESS), ABaseColor, $FF);
  FEngine.FillRoundRect(
    Rect(
      TabRect.Left + NEON_OUTER_THICKNESS + NEON_INNER_THICKNESS,
      TabRect.Top + NEON_OUTER_THICKNESS + NEON_INNER_THICKNESS,
      TabRect.Right - NEON_OUTER_THICKNESS - NEON_INNER_THICKNESS,
      TabRect.Bottom - NEON_OUTER_THICKNESS - NEON_INNER_THICKNESS),
    Max(0, TAB_RADIUS - NEON_OUTER_THICKNESS - NEON_INNER_THICKNESS), clBlack, $FF);
end;

end.
