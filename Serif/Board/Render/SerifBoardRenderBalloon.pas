unit SerifBoardRenderBalloon;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Graphics,System.Types,
  SerifBoardDrawEngine, SerifBoardRenderThread, SerifBoardRenderColorTablePastel;

type
  TSerifBoardRenderBalloonFinishEvent = TSerifBoardRenderThreadFinishEvent;
  TSerifBoardBalloonDirection = (sbbdLeft, sbbdRight);

  TSerifBoardRenderBalloon = class
  private
    FEngine: TSerifBoardDrawEngine;  // ボード画像を描く描画エンジン
    FBoardFolder: string;            // ボード画像の保存先フォルダ
    FAsyncHandle: ISerifBoardRenderThreadHandle;
    function GetStyleFolder: string;
    function GetLastOutputFileName: string;
    function GetDirectionLabel(const ADirection: TSerifBoardBalloonDirection): string;
    procedure BeginDraw(const AWidth, AHeight: Integer);
    procedure EndDraw(const AFileName: string);
    procedure DrawBalloonBoard(const AShadowColor: TColor; const ARect: TRect;
      const ADirection: TSerifBoardBalloonDirection);
  public
    constructor Create(const ABoardFolder: string);
    destructor Destroy; override;

    procedure Execute;
    function NeedsRender: Boolean;
    procedure ExecuteAsync(const AOnFinish: TSerifBoardRenderBalloonFinishEvent = nil);
    procedure DetachAsync;
    function IsRunning: Boolean;
  end;

implementation

const OUTPUT_WIDTH = 1920;
const OUTPUT_HEIGHT = 1080;
const STYLE_NAME = '吹き出し白';
const BOARD_TOP = 850;
const BOARD_BOTTOM = 1080;
const CHARACTER_MARGIN_X = 270;
const TAIL_HALF_HEIGHT = 28;
const TAIL_WIDTH = 48;
const TAIL_INSET = 56;
const BOARD_LEFT = CHARACTER_MARGIN_X + TAIL_WIDTH;
const BOARD_RIGHT = OUTPUT_WIDTH - CHARACTER_MARGIN_X - TAIL_WIDTH;

{ TSerifBoardRenderBalloon }

constructor TSerifBoardRenderBalloon.Create(const ABoardFolder: string);
begin
  inherited Create;
  FEngine := TSerifBoardDrawEngine.Create;
  FBoardFolder := ABoardFolder;
end;

destructor TSerifBoardRenderBalloon.Destroy;
begin
  DetachAsync;
  FEngine.Free;
  inherited;
end;

procedure TSerifBoardRenderBalloon.Execute;
const
  FrameSizes: array[0..1] of record
    Direction: TSerifBoardBalloonDirection;
  end = (
    (Direction: sbbdLeft),
    (Direction: sbbdRight)
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
      DrawBalloonBoard(SerifBoardPastelColors[J].LightColor,
        Rect(BOARD_LEFT, BOARD_TOP, BOARD_RIGHT, BOARD_BOTTOM),
        FrameSizes[I].Direction);
      FileName := STYLE_NAME + '_' + SerifBoardPastelColors[J].Name + '_' +
        GetDirectionLabel(FrameSizes[I].Direction) + '.png';
      EndDraw(FileName);
    end;
  end;
end;

function TSerifBoardRenderBalloon.GetStyleFolder: string;
begin
  Result := TPath.Combine(FBoardFolder, Format('%dx%d_%s', [OUTPUT_WIDTH, OUTPUT_HEIGHT, STYLE_NAME]));
end;

function TSerifBoardRenderBalloon.GetLastOutputFileName: string;
begin
  Result := TPath.Combine(GetStyleFolder, STYLE_NAME + '_' +
    SerifBoardPastelColors[High(SerifBoardPastelColors)].Name + '_右.png');
end;

function TSerifBoardRenderBalloon.NeedsRender: Boolean;
begin
  Result := not TFile.Exists(GetLastOutputFileName);
end;

function TSerifBoardRenderBalloon.GetDirectionLabel(const ADirection: TSerifBoardBalloonDirection): string;
begin
  case ADirection of
    sbbdLeft: Result := '左';
    sbbdRight: Result := '右';
  else
    Result := '';
  end;
end;

procedure TSerifBoardRenderBalloon.ExecuteAsync(const AOnFinish: TSerifBoardRenderBalloonFinishEvent);
var
  Render: TSerifBoardRenderBalloon;
begin
  if IsRunning then
    Exit;

  Render := TSerifBoardRenderBalloon.Create(FBoardFolder);
  FAsyncHandle := TSerifBoardRenderThread.Run(Render.Execute, Render, True, AOnFinish);
end;

procedure TSerifBoardRenderBalloon.DetachAsync;
begin
  if Assigned(FAsyncHandle) then
  begin
    FAsyncHandle.Detach;
    FAsyncHandle := nil;
  end;
end;

function TSerifBoardRenderBalloon.IsRunning: Boolean;
begin
  Result := Assigned(FAsyncHandle) and FAsyncHandle.IsRunning;
end;

procedure TSerifBoardRenderBalloon.BeginDraw(const AWidth, AHeight: Integer);
begin
  FEngine.BeginDraw(AWidth, AHeight);
end;

procedure TSerifBoardRenderBalloon.EndDraw(const AFileName: string);
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

procedure TSerifBoardRenderBalloon.DrawBalloonBoard(const AShadowColor: TColor; const ARect: TRect;
  const ADirection: TSerifBoardBalloonDirection);
const
  SHADOW_OFFSET_X = 10;
  SHADOW_OFFSET_Y = 10;
  SHADOW_ALPHA = $A8;
  CORNER_RADIUS = 16;
var
  WhiteRect: TRect;
  ShadowRect: TRect;
  TailCenterY: Integer;
  WhiteBaseX: Integer;
  ShadowBaseX: Integer;
  WhiteTipX: Integer;
  ShadowTipX: Integer;
  WhiteTail1, WhiteTail2, WhiteTail3: TPoint;
  ShadowTail1, ShadowTail2, ShadowTail3: TPoint;
begin
  if (FEngine.Bitmap.Width <= 0) or (FEngine.Bitmap.Height <= 0) then
    Exit;

  ShadowRect := Rect(
    ARect.Left + SHADOW_OFFSET_X,
    ARect.Top + SHADOW_OFFSET_Y,
    ARect.Right,
    ARect.Bottom);
  WhiteRect := Rect(
    ARect.Left,
    ARect.Top,
    ARect.Right - SHADOW_OFFSET_X,
    ARect.Bottom - SHADOW_OFFSET_Y);

  TailCenterY := WhiteRect.Top + MulDiv(WhiteRect.Bottom - WhiteRect.Top, 3, 4);

  case ADirection of
    sbbdLeft:
      begin
        WhiteBaseX := WhiteRect.Left;
        ShadowBaseX := ShadowRect.Left;
        WhiteTipX := WhiteBaseX - TAIL_WIDTH;
        ShadowTipX := ShadowBaseX - TAIL_WIDTH;
      end;
    sbbdRight:
      begin
        WhiteBaseX := WhiteRect.Right - 1;
        ShadowBaseX := ShadowRect.Right - 1;
        WhiteTipX := WhiteBaseX + TAIL_WIDTH;
        ShadowTipX := ShadowBaseX + TAIL_WIDTH;
      end;
  else
    Exit;
  end;

  WhiteTail1 := Point(WhiteBaseX, TailCenterY - TAIL_HALF_HEIGHT);
  WhiteTail2 := Point(WhiteBaseX, TailCenterY + TAIL_HALF_HEIGHT);
  WhiteTail3 := Point(WhiteTipX, TailCenterY - TAIL_INSET div 2);
  ShadowTail1 := Point(ShadowBaseX, TailCenterY - TAIL_HALF_HEIGHT + SHADOW_OFFSET_Y);
  ShadowTail2 := Point(ShadowBaseX, TailCenterY + TAIL_HALF_HEIGHT + SHADOW_OFFSET_Y);
  ShadowTail3 := Point(ShadowTipX, TailCenterY - TAIL_INSET div 2 + SHADOW_OFFSET_Y);

  FEngine.FillRoundRect(ShadowRect, CORNER_RADIUS, AShadowColor, SHADOW_ALPHA);
  FEngine.FillTriangle(ShadowTail1, ShadowTail2, ShadowTail3, AShadowColor, SHADOW_ALPHA);

  FEngine.FillRoundRect(WhiteRect, CORNER_RADIUS, clWhite, $FF);
  FEngine.FillTriangle(WhiteTail1, WhiteTail2, WhiteTail3, clWhite, $FF);
end;

end.
