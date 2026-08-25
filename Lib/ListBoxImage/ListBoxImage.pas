unit ListBoxImage;

interface

uses
  System.Classes, System.SysUtils, Winapi.Windows,
  Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Vcl.Forms,Winapi.Messages;

const
  WM_USER_THUMB_READY = WM_USER + $800;

type
  // サムネイル状態
  TThumbState = (tsNone, tsLoading, tsReady);

  //===========================================================
  // ダミー処理用スレッド
  //===========================================================
  TThumbLoadThread = class(TThread)
  private
    FOwner  : HWND;
    FIndex  : Integer;
    FFileName : string;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: HWND; AIndex: Integer; const AFileName: string);
  end;

  //===========================================================
  // 基礎クラス：TListBoxImage
  //===========================================================
  TListBoxImage = class(TListBox)
  private
    FStates: array of TThumbState;
    procedure WMThumbReady(var Msg: TMessage); message WM_USER_THUMB_READY;
  protected
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ShowList(Files: TStrings);
    procedure InvalidateItem(Index: Integer);
  end;

implementation

//===========================================================
// TThumbLoadThread
//===========================================================

constructor TThumbLoadThread.Create(AOwner: HWND; AIndex: Integer; const AFileName: string);
begin
  inherited Create(False);
  FreeOnTerminate := True;

  FOwner    := AOwner;
  FIndex    := AIndex;
  FFileName := AFileName;
end;

procedure TThumbLoadThread.Execute;
begin
  // 擬似的に処理が重いフリ（200ms ? 600ms）
  Sleep(200 + Random(400));

  // 完了通知（UI スレッドへ）
  PostMessage(FOwner, WM_USER_THUMB_READY, FIndex, 0);
end;


//===========================================================
// TListBoxImage
//===========================================================

constructor TListBoxImage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Style := lbOwnerDrawFixed;
  ItemHeight := 80;     // 行の高さ（仮）
end;

procedure TListBoxImage.CreateWnd;
begin
  inherited;
  // 再作成時の安全対策
end;

//-----------------------------------------------------------
// ファイルリストを表示
//-----------------------------------------------------------
procedure TListBoxImage.ShowList(Files: TStrings);
var
  i: Integer;
begin
  Items.Assign(Files);

  SetLength(FStates, Items.Count);
  for i := 0 to Items.Count - 1 do
    FStates[i] := tsNone;
end;

//-----------------------------------------------------------
// 行だけ再描画
//-----------------------------------------------------------
procedure TListBoxImage.InvalidateItem(Index: Integer);
var
  R: TRect;
begin
  if (Index < 0) or (Index >= Items.Count) then Exit;
  R := ItemRect(Index);
  InvalidateRect(Handle, @R, True);
end;


//-----------------------------------------------------------
// DrawItem：状態に応じてダミーを描画
//-----------------------------------------------------------
procedure TListBoxImage.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  S: TThumbState;
  C: TCanvas;
  RThumb, RText: TRect;
  str : string;
begin
  C := Canvas;
  S := FStates[Index];

  // 背景
  if odSelected in State then
    C.Brush.Color := $CCE0FF
  else
    C.Brush.Color := clWhite;
  C.FillRect(Rect);

  // サムネイル矩形（左側）
  RThumb := Rect;
  RThumb.Right := RThumb.Left + ItemHeight;

  // 状態に応じて描画色変更
  case S of
    tsNone:
      begin
        // スレッド開始
        FStates[Index] := tsLoading;
        TThumbLoadThread.Create(Handle, Index, Items[Index]);

        C.Brush.Color := clGray;  // 未処理ダミー
      end;

    tsLoading:
      C.Brush.Color := clSilver; // ローディング中

    tsReady:
      C.Brush.Color := clSkyBlue; // 完了ダミー
  end;

  C.FillRect(RThumb);

  // 文字部分
  RText := Rect;
  RText.Left := RThumb.Right + 8;

  C.Font.Color := clBlack;
  str := Items[Index];
  C.TextRect(RText, str, [tfSingleLine, tfVerticalCenter]);
end;


//-----------------------------------------------------------
// スレッド完了通知
//-----------------------------------------------------------
procedure TListBoxImage.WMThumbReady(var Msg: TMessage);
var
  idx: Integer;
begin
  idx := Msg.WParam;
  if (idx >= 0) and (idx < Length(FStates)) then
  begin
    FStates[idx] := tsReady;
    InvalidateItem(idx);
  end;
end;

end.

