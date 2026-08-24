unit AudioPlayer;

{
  DirectShow を使用した軽量な音声再生ユニット。
  アプリ内部から wav / mp3 / wma などの音声ファイルを単発再生する。
  UI、再生位置管理、プレイリスト、終了通知は持たず、現在再生中の1件だけを管理する。
}

interface

uses
  System.SysUtils,
  Winapi.ActiveX,
  Winapi.DirectShow9;

type
  TAudioPlayer = class
  private
    FGraphBuilder: IGraphBuilder;       // DirectShow の再生グラフ
    FMediaControl: IMediaControl;       // 再生開始・停止制御
    FBasicAudio: IBasicAudio;           // DirectShow 側の音量制御
    FVolume: Integer;                   // アプリ内音量 0..100
    FComInitialized: Boolean;           // このクラスで COM を初期化したか
    // COM を初期化する
    procedure InitializeCom;
    // DirectShow 関連インターフェースを解放する
    procedure ReleaseGraph;
    // 現在の音量を DirectShow に反映する
    procedure ApplyVolume;
    // 音量を 0..100 に補正して設定する
    procedure SetVolume(const Value: Integer);
  public
    // 音声プレイヤーを生成する
    constructor Create;
    // 再生を停止して音声プレイヤーを破棄する
    destructor Destroy; override;
    // 指定ファイルを再生する
    procedure Play(const FileName: string);
    // 現在の再生を停止する
    procedure Stop;
    property Volume: Integer read FVolume write SetVolume;
  end;

implementation

uses
  System.Math,
  System.Win.ComObj;

const
  RPC_E_CHANGED_MODE = HRESULT($80010106);

{ TAudioPlayer }

constructor TAudioPlayer.Create;
begin
  inherited Create;
  FVolume := 100;
  InitializeCom;
end;

destructor TAudioPlayer.Destroy;
begin
  Stop;

  if FComInitialized then
    CoUninitialize;

  inherited;
end;

procedure TAudioPlayer.InitializeCom;
var
  Hr: HRESULT;
begin
  Hr := CoInitializeEx(nil, COINIT_APARTMENTTHREADED);

  case Hr of
    S_OK, S_FALSE:
      FComInitialized := True;
    RPC_E_CHANGED_MODE:
      // 既に別モードで初期化済みなら、既存の COM 状態を利用する
      FComInitialized := False;
  else
    OleCheck(Hr);
  end;
end;

procedure TAudioPlayer.Play(const FileName: string);
begin
  Stop;

  if not FileExists(FileName) then
    Exit;

  try
    // ファイルごとに新しい DirectShow グラフを作成する
    FGraphBuilder := CreateComObject(CLSID_FilterGraph) as IGraphBuilder;
    FMediaControl := FGraphBuilder as IMediaControl;

    OleCheck(FGraphBuilder.RenderFile(PWideChar(FileName), nil));

    if Supports(FGraphBuilder, IBasicAudio, FBasicAudio) then
      ApplyVolume;

    OleCheck(FMediaControl.Run);
  except
    // 作成途中で失敗したグラフを残さない
    ReleaseGraph;
    raise;
  end;
end;

procedure TAudioPlayer.Stop;
begin
  if FMediaControl <> nil then
    FMediaControl.Stop;

  ReleaseGraph;
end;

procedure TAudioPlayer.ReleaseGraph;
begin
  FBasicAudio := nil;
  FMediaControl := nil;
  FGraphBuilder := nil;
end;

procedure TAudioPlayer.SetVolume(const Value: Integer);
begin
  FVolume := EnsureRange(Value, 0, 100);

  if FBasicAudio <> nil then
    ApplyVolume;
end;

procedure TAudioPlayer.ApplyVolume;
var
  DirectShowVolume: Integer;
begin
  if FBasicAudio = nil then
    Exit;

  // DirectShow の音量は -10000..0 で指定する
  DirectShowVolume := Round((FVolume - 100) * 100);
  OleCheck(FBasicAudio.put_Volume(DirectShowVolume));
end;

end.
