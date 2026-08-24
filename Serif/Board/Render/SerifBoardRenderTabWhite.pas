unit SerifBoardRenderTabWhite;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Graphics,
  SerifBoardDrawEngine, SerifBoardRenderThread, SerifBoardRenderColorTablePastel, Math;

type
  TSerifBoardRenderTabWhiteFinishEvent = TSerifBoardRenderThreadFinishEvent;

  TSerifBoardRenderTabWhite = class
  private
    FEngine: TSerifBoardDrawEngine;  // ボード画像を描く描画エンジン
    FBoardFolder: string;            // ボード画像の保存先フォルダ
    FAsyncHandle: ISerifBoardRenderThreadHandle;
    function GetStyleFolder: string;
    function GetLastOutputFileName: string;
    procedure BeginDraw(const AWidth, AHeight: Integer);
    procedure EndDraw(const AFileName: string);
    procedure DrawTabWhiteBoard(const AShadowColor, AFrameColor: TColor; const ARect: TRect);
  public
    constructor Create(const ABoardFolder: string);
    destructor Destroy; override;

    procedure Execute;
    function NeedsRender: Boolean;
    procedure ExecuteAsync(const AOnFinish: TSerifBoardRenderTabWhiteFinishEvent = nil);
    procedure DetachAsync;
    function IsRunning: Boolean;
  end;

implementation

const OUTPUT_WIDTH = 1920;
const OUTPUT_HEIGHT = 1080;
const STYLE_NAME = 'タブ白';

const
  TAB_HEIGHT = 64;
  TAB_WIDTH = 250;
  TAB_ATTACH_OVERLAP = 14;
  SHADOW_OFFSET_X = 10;
  SHADOW_OFFSET_Y = 10;
  SHADOW_ALPHA = $A8;
  BODY_RADIUS = 18;
  TAB_RADIUS = 18;
  FRAME_THICKNESS = 8;

{ TSerifBoardRenderTabWhite }

constructor TSerifBoardRenderTabWhite.Create(const ABoardFolder: string);
begin
  inherited Create;
  FEngine := TSerifBoardDrawEngine.Create;
  FBoardFolder := ABoardFolder;
end;

destructor TSerifBoardRenderTabWhite.Destroy;
begin
  DetachAsync;
  FEngine.Free;
  inherited;
end;

procedure TSerifBoardRenderTabWhite.Execute;
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
    for J := Low(SerifBoardPastelColors) to High(SerifBoardPastelColors) do
    begin
      BeginDraw(OUTPUT_WIDTH, OUTPUT_HEIGHT);
      DrawTabWhiteBoard(
        SerifBoardPastelColors[J].LightColor,
        SerifBoardPastelColors[J].BaseColor,
        Rect(FrameSizes[I].Left, FrameSizes[I].Top, FrameSizes[I].Right, FrameSizes[I].Bottom));
      FileName := STYLE_NAME + '_' + SerifBoardPastelColors[J].Name + '_' + FrameSizes[I].SizeLabel + '.png';
      EndDraw(FileName);
    end;
  end;
end;

function TSerifBoardRenderTabWhite.GetStyleFolder: string;
begin
  Result := TPath.Combine(FBoardFolder, Format('%dx%d_%s', [OUTPUT_WIDTH, OUTPUT_HEIGHT, STYLE_NAME]));
end;

function TSerifBoardRenderTabWhite.GetLastOutputFileName: string;
begin
  Result := TPath.Combine(GetStyleFolder, STYLE_NAME + '_' +
    SerifBoardPastelColors[High(SerifBoardPastelColors)].Name + '_中.png');
end;

function TSerifBoardRenderTabWhite.NeedsRender: Boolean;
begin
  Result := not TFile.Exists(GetLastOutputFileName);
end;

procedure TSerifBoardRenderTabWhite.ExecuteAsync(const AOnFinish: TSerifBoardRenderTabWhiteFinishEvent);
var
  Render: TSerifBoardRenderTabWhite;
begin
  if IsRunning then
    Exit;

  Render := TSerifBoardRenderTabWhite.Create(FBoardFolder);
  FAsyncHandle := TSerifBoardRenderThread.Run(Render.Execute, Render, True, AOnFinish);
end;

procedure TSerifBoardRenderTabWhite.DetachAsync;
begin
  if Assigned(FAsyncHandle) then
  begin
    FAsyncHandle.Detach;
    FAsyncHandle := nil;
  end;
end;

function TSerifBoardRenderTabWhite.IsRunning: Boolean;
begin
  Result := Assigned(FAsyncHandle) and FAsyncHandle.IsRunning;
end;

procedure TSerifBoardRenderTabWhite.BeginDraw(const AWidth, AHeight: Integer);
begin
  FEngine.BeginDraw(AWidth, AHeight);
end;

procedure TSerifBoardRenderTabWhite.EndDraw(const AFileName: string);
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

procedure TSerifBoardRenderTabWhite.DrawTabWhiteBoard(const AShadowColor, AFrameColor: TColor; const ARect: TRect);
var
  MainRect: TRect;
  ShadowMainRect: TRect;
  TabRect: TRect;
  ShadowTabRect: TRect;
begin
  if (FEngine.Bitmap.Width <= 0) or (FEngine.Bitmap.Height <= 0) then
    Exit;

  MainRect := Rect(ARect.Left, ARect.Top + TAB_HEIGHT, ARect.Right, ARect.Bottom);
  ShadowMainRect := Rect(
    MainRect.Left + SHADOW_OFFSET_X,
    MainRect.Top + SHADOW_OFFSET_Y,
    MainRect.Right,
    MainRect.Bottom);
  TabRect := Rect(ARect.Left + 24, ARect.Top, Min(ARect.Left + 24 + TAB_WIDTH, ARect.Right - 120),
    MainRect.Top + TAB_ATTACH_OVERLAP);
  ShadowTabRect := Rect(
    TabRect.Left + SHADOW_OFFSET_X,
    TabRect.Top + SHADOW_OFFSET_Y,
    TabRect.Right + SHADOW_OFFSET_X,
    TabRect.Bottom + SHADOW_OFFSET_Y);

  FEngine.FillRoundRect(ShadowMainRect, BODY_RADIUS, AShadowColor, SHADOW_ALPHA);
  FEngine.FillRoundRect(ShadowTabRect, TAB_RADIUS, AShadowColor, SHADOW_ALPHA);

  FEngine.FillRoundRectFrame(MainRect, BODY_RADIUS, AFrameColor, clWhite, FRAME_THICKNESS, $FF);
  FEngine.FillRoundRectFrame(TabRect, TAB_RADIUS, AFrameColor, clWhite, FRAME_THICKNESS, $FF);
end;

end.
