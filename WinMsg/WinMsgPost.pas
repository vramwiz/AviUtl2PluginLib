unit WinMsgPost;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.Classes, System.SysUtils, System.Threading, SharedMemoryBase;

{==============================================================================
  AviUtl2 モジュール間 通信用ユニット（送信専用）
  ---------------------------------------------------------------------------
  ・拡張プラグイン側（受信側）は別ユニット（WinMsgRecv）
  ・こちらはモジュール側で使用し、共有メモリ経由で
    メインウィンドウに PostMessage を送信する
==============================================================================}

type
  // 共有メモリ上のデータ構造
  PMainHandleData = ^TMainHandleData;
  TMainHandleData = packed record
    MainHandle: HWND; // AviUtl メインウィンドウハンドル
  end;

  // AviUtl メインウィンドウハンドル専用共有メモリクラス
  TSharedMemoryMainHandle = class(TSharedMemoryBase)
  private
    function GetData: PMainHandleData;       // データ構造ポインタ取得
    function GetMainHandle: HWND;            // ハンドル取得
    procedure SetMainHandle(Value: HWND);    // ハンドル設定
  public
    property Data: PMainHandleData read GetData;
    property MainHandle: HWND read GetMainHandle write SetMainHandle;
  end;

  // メッセージ送信クラス
  TWinMsgPost = class
  private
    FShared: TSharedMemoryMainHandle;        // 共有メモリインスタンス
    FTargetWnd: HWND;                        // 送信先ウィンドウハンドル
    FMsgID: UINT;                            // 登録メッセージID
    function GetTargetHandle: HWND;          // ハンドル取得（遅延取得）
  public
    constructor Create;                      // 初期化
    destructor Destroy; override;            // 解放
    procedure Send;                          // メッセージ送信
  end;

implementation

const
  SHARED_NAME  = 'Local\AviUtl2.MainHandle';       // 共有メモリ識別名
  WINMSG_IDENT = 'WinMsgPost.AviUtl2.Redraw';      // 固定メッセージ名

{==============================================================================}
{ TSharedMemoryMainHandle }
{==============================================================================}
function TSharedMemoryMainHandle.GetData: PMainHandleData;
begin
  Result := PMainHandleData(View); // Viewを構造体にキャスト
end;

function TSharedMemoryMainHandle.GetMainHandle: HWND;
begin
  if Assigned(View) then
    Result := Data^.MainHandle      // ハンドル値を返す
  else
    Result := 0;
end;

procedure TSharedMemoryMainHandle.SetMainHandle(Value: HWND);
begin
  if Assigned(View) then
    Data^.MainHandle := Value;      // ハンドルを書き込む
end;

{==============================================================================}
{ TWinMsgPost 送信側 }
{==============================================================================}
constructor TWinMsgPost.Create;
begin
  inherited Create;
  FMsgID := RegisterWindowMessage(WINMSG_IDENT); // メッセージ登録
  FShared := TSharedMemoryMainHandle.Create(SHARED_NAME, SizeOf(TMainHandleData));
  FTargetWnd := 0;                              // 初期値は未設定
end;

destructor TWinMsgPost.Destroy;
begin
  FShared.Free;                                 // 共有メモリ破棄
  inherited;
end;

function TWinMsgPost.GetTargetHandle: HWND;
var
  i: Integer;
begin
  // 既にキャッシュされていればそれを返す
  if FTargetWnd <> 0 then
    Exit(FTargetWnd);

  // 最大10回まで再試行（1秒待機）
  for i := 0 to 9 do
  begin
    FTargetWnd := FShared.MainHandle;
    if FTargetWnd <> 0 then Break;
    Sleep(100);
  end;
  Result := FTargetWnd;
end;

procedure TWinMsgPost.Send;
begin
  // メッセージ未登録時は無効
  if FMsgID = 0 then Exit;

  // 送信先が不明ならスキップ
  if GetTargetHandle = 0 then
  begin
    Exit;
  end;

  // PostMessageで非同期送信
  PostMessage(FTargetWnd, FMsgID, 0, 0);
end;

end.

