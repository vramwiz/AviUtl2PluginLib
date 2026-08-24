unit SerifBoardRenderBatch;

interface

uses
  System.SysUtils,
  SerifBoardRenderThread;

type
  TSerifBoardRenderBatchFinishEvent = TSerifBoardRenderThreadFinishEvent;

  TSerifBoardRenderBatch = class
  private
    FBoardFolder: string;            // ボード画像の保存先フォルダ
    FAsyncHandle: ISerifBoardRenderThreadHandle;
  public
    // 保存先フォルダを受け取って一括レンダラーを初期化する
    constructor Create(const ABoardFolder: string);
    // 非同期通知だけ外してから破棄する
    destructor Destroy; override;

    // カラー・黒・白の各スタイルを順番にまとめて生成する
    procedure Execute;
    // まだどれかのスタイルに生成が必要か
    function NeedsRender: Boolean;
    // バックグラウンドスレッドで順番にまとめて生成する
    procedure ExecuteAsync(const AOnFinish: TSerifBoardRenderBatchFinishEvent = nil);
    // 破棄時に通知だけ外したい場合に使う
    procedure DetachAsync;
    // 現在バックグラウンド生成中か
    function IsRunning: Boolean;
  end;

implementation

uses
  SerifBoardRenderColor,
  SerifBoardRenderBlack,
  SerifBoardRenderWhite,
  SerifBoardRenderBalloon,
  SerifBoardRenderTabBlack,
  SerifBoardRenderTabWhite;

{ TSerifBoardRenderBatch }

constructor TSerifBoardRenderBatch.Create(const ABoardFolder: string);
begin
  inherited Create;
  FBoardFolder := ABoardFolder;
end;

destructor TSerifBoardRenderBatch.Destroy;
begin
  DetachAsync;
  inherited;
end;

procedure TSerifBoardRenderBatch.Execute;
var
  ColorRender: TSerifBoardRenderColor;
  BlackRender: TSerifBoardRenderBlack;
  WhiteRender: TSerifBoardRenderWhite;
  BalloonRender: TSerifBoardRenderBalloon;
  TabBlackRender: TSerifBoardRenderTabBlack;
  TabWhiteRender: TSerifBoardRenderTabWhite;
begin
  ColorRender := TSerifBoardRenderColor.Create(FBoardFolder);
  try
    ColorRender.Execute;
  finally
    ColorRender.Free;
  end;

  BlackRender := TSerifBoardRenderBlack.Create(FBoardFolder);
  try
    BlackRender.Execute;
  finally
    BlackRender.Free;
  end;

  WhiteRender := TSerifBoardRenderWhite.Create(FBoardFolder);
  try
    WhiteRender.Execute;
  finally
    WhiteRender.Free;
  end;

  BalloonRender := TSerifBoardRenderBalloon.Create(FBoardFolder);
  try
    BalloonRender.Execute;
  finally
    BalloonRender.Free;
  end;

  TabBlackRender := TSerifBoardRenderTabBlack.Create(FBoardFolder);
  try
    TabBlackRender.Execute;
  finally
    TabBlackRender.Free;
  end;

  TabWhiteRender := TSerifBoardRenderTabWhite.Create(FBoardFolder);
  try
    TabWhiteRender.Execute;
  finally
    TabWhiteRender.Free;
  end;
end;

function TSerifBoardRenderBatch.NeedsRender: Boolean;
var
  ColorRender: TSerifBoardRenderColor;
  BlackRender: TSerifBoardRenderBlack;
  WhiteRender: TSerifBoardRenderWhite;
  BalloonRender: TSerifBoardRenderBalloon;
  TabBlackRender: TSerifBoardRenderTabBlack;
  TabWhiteRender: TSerifBoardRenderTabWhite;
begin
  Result := False;

  ColorRender := TSerifBoardRenderColor.Create(FBoardFolder);
  try
    if ColorRender.NeedsRender then
      Exit(True);
  finally
    ColorRender.Free;
  end;

  BlackRender := TSerifBoardRenderBlack.Create(FBoardFolder);
  try
    if BlackRender.NeedsRender then
      Exit(True);
  finally
    BlackRender.Free;
  end;

  WhiteRender := TSerifBoardRenderWhite.Create(FBoardFolder);
  try
    if WhiteRender.NeedsRender then
      Exit(True);
  finally
    WhiteRender.Free;
  end;

  BalloonRender := TSerifBoardRenderBalloon.Create(FBoardFolder);
  try
    if BalloonRender.NeedsRender then
      Exit(True);
  finally
    BalloonRender.Free;
  end;

  TabBlackRender := TSerifBoardRenderTabBlack.Create(FBoardFolder);
  try
    if TabBlackRender.NeedsRender then
      Exit(True);
  finally
    TabBlackRender.Free;
  end;

  TabWhiteRender := TSerifBoardRenderTabWhite.Create(FBoardFolder);
  try
    if TabWhiteRender.NeedsRender then
      Exit(True);
  finally
    TabWhiteRender.Free;
  end;
end;

procedure TSerifBoardRenderBatch.ExecuteAsync(const AOnFinish: TSerifBoardRenderBatchFinishEvent);
var
  Render: TSerifBoardRenderBatch;
begin
  if IsRunning then
    Exit;

  Render := TSerifBoardRenderBatch.Create(FBoardFolder);
  FAsyncHandle := TSerifBoardRenderThread.Run(Render.Execute, Render, True, AOnFinish);
end;

procedure TSerifBoardRenderBatch.DetachAsync;
begin
  if Assigned(FAsyncHandle) then
  begin
    FAsyncHandle.Detach;
    FAsyncHandle := nil;
  end;
end;

function TSerifBoardRenderBatch.IsRunning: Boolean;
begin
  Result := Assigned(FAsyncHandle) and FAsyncHandle.IsRunning;
end;

end.
