unit WinMsgRecv;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.Classes, System.SysUtils, System.Threading, AviUtl2PluginTypes,SharedMemoryBase,
  AviUtl2ObjectList,AviUtl2ObjectItem;

{==============================================================================
  AviUtl2 モジュール間 通信用ユニット
  ---------------------------------------------------------------------------
  ・拡張プラグイン側（受信側）
      AviUtl メインウィンドウのハンドルを共有メモリへ書き込み
      そのウィンドウを Subclass して RegisterWindowMessage を受信

  ・モジュール側（送信側）
      共有メモリから HWND を読み取り PostMessage 送信

  ※スレッド分離環境でも確実にメッセージを届ける構成
==============================================================================}

type
  // AviUtl メインウィンドウハンドルを共有するデータ構造
  PMainHandleData = ^TMainHandleData;
  TMainHandleData = packed record
    MainHandle: HWND; // AviUtlのメインウィンドウハンドル
  end;


  // AviUtl メインウィンドウハンドル専用共有メモリ
  TSharedMemoryMainHandle = class(TSharedMemoryBase)
  private
    function GetData: PMainHandleData;
    function GetMainHandle: HWND;
    procedure SetMainHandle(Value: HWND);
  public
    property Data: PMainHandleData read GetData;
    property MainHandle: HWND read GetMainHandle write SetMainHandle;
  end;


  // メッセージ受信クラス（拡張プラグイン側）
  TWinMsgRecv = class
  private
    FMainWnd: HWND;                 // AviUtlメインウィンドウ
    FOrigProc: Pointer;             // 元のWndProc
    FMsgID: UINT;                   // 登録メッセージID
    FShared: TSharedMemoryMainHandle; // 共有メモリ
    FOnReceive: TProc;              // メッセージ受信イベント
    FEditHandle: PEditHandle;       // 編集ハンドル

    class function HookProc(Wnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; static;
  protected
    procedure DoReceive; virtual;   // 受信処理本体
  public
    constructor Create;
    destructor Destroy; override;
    procedure WriteHandleToShared;  // AviUtlのHWNDを共有メモリに書き込み
    property EditHandle: PEditHandle read FEditHandle write FEditHandle;
    property OnReceive: TProc read FOnReceive write FOnReceive;
  end;

implementation

const
  SHARED_NAME = 'Local\AviUtl2.MainHandle'; // 共有メモリ識別名
  WINMSG_IDENT = 'WinMsgPost.AviUtl2.Redraw'; // 登録メッセージ識別子

var
  GInstance: TWinMsgRecv = nil; // 静的インスタンス参照
  GIsEditing: Boolean = False;  // 編集中フラグ
  GFrame: Integer;              // 現在フレーム
  GFrame2: Integer;             // 前回フレーム
  GObjItems1 : TAviUtl2ObjectList;
  GObjItems2 : TAviUtl2ObjectList;
  GTempList:  TAviUtl2ObjectList;

  GFocusItem1: TAviUtl2ObjectItem;
  GFocusItem2: TAviUtl2ObjectItem;
  GFocusChanged: Boolean = False;

{==============================================================================}
{ TSharedMemoryMainHandle }
{==============================================================================}
function TSharedMemoryMainHandle.GetData: PMainHandleData;
begin
  Result := PMainHandleData(View); // ポインタをキャスト
end;

function TSharedMemoryMainHandle.GetMainHandle: HWND;
begin
  if Assigned(View) then
    Result := Data^.MainHandle     // ハンドル取得
  else
    Result := 0;
end;

procedure TSharedMemoryMainHandle.SetMainHandle(Value: HWND);
begin
  if Assigned(View) then
    Data^.MainHandle := Value;     // ハンドル書き込み
end;
{==============================================================================}
{ TWinMsgRecv 受信側(Subclass) }
{==============================================================================}
constructor TWinMsgRecv.Create;
begin
  inherited Create;
  GInstance := Self; // グローバル参照設定
  GObjItems1 := TAviUtl2ObjectList.Create;
  GObjItems2 := TAviUtl2ObjectList.Create;
  GFocusItem1 := TAviUtl2ObjectItem.Create;
  GFocusItem2 := TAviUtl2ObjectItem.Create;
  FMsgID := RegisterWindowMessage(WINMSG_IDENT); // 固定メッセージ登録
  FShared := TSharedMemoryMainHandle.Create(SHARED_NAME, SizeOf(TMainHandleData)); // 共有メモリ確保
  FMainWnd := GetAncestor(GetForegroundWindow, GA_ROOT); // AviUtlメインウィンドウ取得
  WriteHandleToShared; // ハンドルを共有メモリに書き込み

  if FMainWnd <> 0 then
  begin
    FOrigProc := Pointer(SetWindowLongPtr(FMainWnd, GWLP_WNDPROC, LONG_PTR(@HookProc))); // Subclass設定
  end
end;

destructor TWinMsgRecv.Destroy;
begin
  if (FMainWnd <> 0) and (FOrigProc <> nil) then
    SetWindowLongPtr(FMainWnd, GWLP_WNDPROC, LONG_PTR(FOrigProc)); // Subclass解除
  FShared.Free;
  GFocusItem1.Free;
  GFocusItem2.Free;
  GObjItems2.Free;
  GObjItems1.Free;
  GInstance := nil;
  inherited;
end;

procedure TWinMsgRecv.WriteHandleToShared;
begin
  if FMainWnd <> 0 then
  begin
    FShared.MainHandle := FMainWnd; // HWNDを共有メモリに書き込み
  end;
end;

class function TWinMsgRecv.HookProc(Wnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
begin
  // 固定メッセージ受信チェック
  if (GInstance <> nil) and (Msg = GInstance.FMsgID) then
  begin
    GInstance.DoReceive; // 再描画処理呼び出し
    Result := 0;
    Exit;
  end;

  // 他のメッセージは既存WndProcに委譲
  if (GInstance <> nil) and (GInstance.FOrigProc <> nil) then
    Result := CallWindowProc(GInstance.FOrigProc, Wnd, Msg, wParam, lParam)
  else
    Result := DefWindowProc(Wnd, Msg, wParam, lParam);
end;

procedure CheckFrame(Edit: PEditSection); cdecl;
var
  Obj: TObjectHandle;
begin
  if (Edit = nil) or (Edit^.Info = nil) then Exit; // 無効チェック

  Obj := Edit^.GetFocusObject(); // 選択オブジェクト取得

  if (Obj <> nil) and (Edit^.Info^.Frame = GFrame) then // 編集停止中と判断
  begin
    GIsEditing := True;
  end
  else
  begin
    GIsEditing := False;
  end;
  GFrame := Edit^.Info^.Frame; // 現在フレームを記録
end;

// ※ボツ
procedure CaptureObjectsProc(Edit: PEditSection); cdecl;
begin
  if (Edit = nil) or (GTempList = nil) then Exit;
  GTempList.Capture(Edit);
end;

// ※ボツ
function CompareAndUpdateObjects: Boolean;
var
  i: Integer;
  NewItem: TAviUtl2ObjectItem;
begin
  Result := False;
  if (GObjItems1 = nil) or (GObjItems2 = nil) then Exit;

  // 差分があるか？
  if not GObjItems2.EqualsTo(GObjItems1) then
  begin
    Result := True; // 変更検出

    // GObjItems1 を更新（中身を複製）
    GObjItems1.Clear;
    GObjItems1.Capacity := GObjItems2.Count;

    for i := 0 to GObjItems2.Count - 1 do
    begin
      NewItem := GObjItems1.AddNew();
      NewItem.Assign(GObjItems2[i]);
    end;
  end;
end;




procedure TWinMsgRecv.DoReceive;
begin
  if FEditHandle = nil then Exit; // 編集ハンドル未設定

  GIsEditing := False;
  if not FEditHandle^.CallEditSection(@CheckFrame) then Exit; // 現在状態を確認
  if not GIsEditing then Exit;  // 再生中ならスキップ
  if GFrame = GFrame2 then Exit; // 同一フレームなら再描画不要
   {
  // === 最新オブジェクト構成の取得 ===
  GTempList := GObjItems2;
  try
    if not FEditHandle^.CallEditSection(@CaptureObjectsProc) then
      Exit;
  finally
    GTempList := nil;
  end;
  }
  // === 比較と更新 ===
  //if CompareAndUpdateObjects then
  //begin
    // 差分あり → 再描画要求
    PostMessage(FMainWnd, WM_KEYDOWN, VK_F5, 0);
    PostMessage(FMainWnd, WM_KEYUP, VK_F5, 0);
  //end;

  GFrame2 := GFrame; // フレーム更新
end;

end.

