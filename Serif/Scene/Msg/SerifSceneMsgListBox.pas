unit SerifSceneMsgListBox;

interface

uses
  System.Classes, System.Types,Winapi.Windows, System.UITypes, System.SysUtils,
  Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Vcl.ExtCtrls,
  SerifSceneMsgList,Vcl.Menus,Winapi.Messages;

type  TSerifSceneMsgListBoxRequestMeasureEvent = procedure(Sender: TObject;const Index : Integer;var str : string) of object;

type
  //===========================================================
  //  セリフ管理専用 ListBox
  //===========================================================
  TSerifSceneMsgListBox = class(TListBox)
  private
    //--- 編集用コントロール（Memoを重ねる） -----------------
    FMemo: TMemo;       // セリフ編集用
    FEditingIndex: Integer; // 現在編集中のアイテム
    FIsEditing: Boolean;    // 編集モード中フラグ
    FIsEdited : Boolean;    // 編集終了処理中フラグ
    FBaseFontHeight: Integer; // 標準状態のフォントサイズ
    FFontZoomIndex: Integer;  // Ctrl+ホイール用の表示倍率

    //--- PopupMenu 退避（Memoが影響を受けないようにする） ---
    FSavedPopup: TPopupMenu;

    FMemoOrgWndProc: TWndMethod;
    //--- 描画用 ------------------------------------------------
    FOnRequestMeasure: TSerifSceneMsgListBoxRequestMeasureEvent;
    FOnEdited: TNotifyEvent; // アイテム高さキャッシュ

    // キャッシュが有効かどうか
    //function IsHeightCached(Index: Integer): Boolean;
    // キャッシュへ保存する
    procedure SetHeightCache(Index: Integer; AHeight: Integer);
    procedure SetFontZoomIndex(Value: Integer);
    procedure ApplyFontZoom;
    procedure RefreshAllItemHeights;
    function GetZoomFontHeight: Integer;

    // Voice の行数をカウントする（最適化対象）
    function CalcVoiceLinesFast(const S: string): Integer;

    // Item 全体の高さを計算する（キャッシュ無効時）
    function CalcItemHeightInternal(const Voice: string): Integer;


    //--- メモの操作イベント -------------------------------------
    procedure MemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MemoExit(Sender: TObject);

    procedure EndEditProc(Apply: Boolean);

    procedure MemoWndProc(var Msg: TMessage);
    // 編集キャンセル用のイベントを受け取る
    //procedure CMExit(var Msg: TCMExit);   message CM_EXIT;

  protected
    FLineHeight: Integer;   // 1行の高さ
    FMargin: Integer;       // 余白
    FItemHeightCache: array of Integer;
    FCharaHeight: Integer;  // 配役1行分の高さ

    // 行数を正しく計算
    function LineCountForDisplay(const S: string): Integer;
    //--- ListBox 描画 -----------------------------------------
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;

    // 編集中アイテムかどうかの判定
    function IsEditingItem(Index: Integer): Boolean;
    //--- 内部使用ヘルパー -------------------------------------
    function GetMsgItem(Index: Integer): TSerifSceneMsgItem;

    procedure MeasureItem(Index: Integer; var Height: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;

    procedure DoRequestMeasure(const Index : Integer;var str : string);
    //--- 編集処理 ---------------------------------------------
    procedure DoBeginEdit(Index: Integer);virtual;
    procedure DoEndEdit(Apply: Boolean);virtual;

    //--- 内部ユーティリティ ----------------------------------
    procedure InitMemo;
    procedure UpdateMemoBounds;

    procedure OnMemoChange(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    //--- 外部公開API（必要最小限） ---------------------------
    procedure BeginEdit();  // 外部指示で編集開始
    procedure EndEdit(ApplyChanges: Boolean); // 強制終了含む

    // アイテムの高さキャッシュを再計算し、再描画
    procedure RefreshItemHeight(const Index: Integer;const aText : string);

    function IsEditing: Boolean;

    property OnRequestMeasure :  TSerifSceneMsgListBoxRequestMeasureEvent  read FOnRequestMeasure write FOnRequestMeasure;
    property OnEdited: TNotifyEvent read FOnEdited write FOnEdited;
  end;

implementation

uses AviUtl2StyleColors;

const
  // Ctrl+ホイールの表示倍率。標準を 2 にして、縮小側は控えめ、拡大側は多めにする。
  SERIF_MSG_FONT_ZOOM_MIN = 0;
  SERIF_MSG_FONT_ZOOM_DEFAULT = 2;
  SERIF_MSG_FONT_ZOOM_MAX = 8;
  // Font.Height は負値なので、ZoomIndex が増えるほど文字は大きくなる。
  SERIF_MSG_FONT_ZOOM_STEP = 2;

{---------------------------------------------------------------}
{  Constructor / Destructor                                     }
{---------------------------------------------------------------}

constructor TSerifSceneMsgListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Style := lbOwnerDrawVariable;

  FEditingIndex := -1;
  FIsEditing := False;
  FBaseFontHeight := 0;
  FFontZoomIndex := SERIF_MSG_FONT_ZOOM_DEFAULT;

  FMargin := 6;

  InitMemo;
end;

destructor TSerifSceneMsgListBox.Destroy;
begin
  FMemo.Free;
  inherited Destroy;
end;

{---------------------------------------------------------------}
{  Window / Params                                              }
{---------------------------------------------------------------}
procedure TSerifSceneMsgListBox.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
end;

procedure TSerifSceneMsgListBox.CreateWnd;
begin
  inherited CreateWnd;
end;

{---------------------------------------------------------------}
{  編集用 Memo の初期化                                         }
{---------------------------------------------------------------}

procedure TSerifSceneMsgListBox.InitMemo;
begin
  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Visible := False;
  FMemo.WantTabs := False;
  FMemo.ScrollBars := ssNone;
  FMemo.Color :=  A2SCMemoBackground;
  FMemo.Font.Color := A2SCMemoText;
  FMemo.Font.Height := -12;
  FMemo.PopupMenu := nil;   // 親のPopupMenuを拾わないようにする
  FMemo.OnChange := OnMemoChange;
  // ★スクロール禁止のため WindowProc 差し替え
  FMemoOrgWndProc := FMemo.WindowProc;
  FMemo.WindowProc := MemoWndProc;
end;

procedure TSerifSceneMsgListBox.UpdateMemoBounds;
var
  R: TRect;
begin
  if not FIsEditing then Exit;
  if FEditingIndex < 0 then Exit;
  if FEditingIndex >= Items.Count then Exit;
  if FEditingIndex >= Length(FItemHeightCache) then Exit;

  R := ItemRect(FEditingIndex);
  Inc(R.Top, FCharaHeight + 1);
  R.Bottom := R.Top + (FItemHeightCache[FEditingIndex] - FCharaHeight) + 6;
  FMemo.SetBounds(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
end;

{---------------------------------------------------------------}
{  アイテム取得（nil安全）                                      }
{---------------------------------------------------------------}

function TSerifSceneMsgListBox.GetMsgItem(Index: Integer): TSerifSceneMsgItem;
begin
  Result := nil;
  if (Index < 0) or (Index >= Items.Count) then Exit;
  Result := TSerifSceneMsgItem(Items.Objects[Index]);
end;

{---------------------------------------------------------------}
{  編集中アイテム判定                                           }
{---------------------------------------------------------------}
function TSerifSceneMsgListBox.IsEditingItem(Index: Integer): Boolean;
begin
  Result := FIsEditing and (Index = FEditingIndex);
end;


{ キャッシュが存在するか }
{
function TSerifSceneMsgListBox.IsHeightCached(Index: Integer): Boolean;
begin
  Result := (Index >= 0) and
            (Index < Length(FItemHeightCache)) and
            (FItemHeightCache[Index] > 0);
end;
}

function TSerifSceneMsgListBox.LineCountForDisplay(const S: string): Integer;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := S;

    Result := SL.Count;
    // ★ 末尾が改行で終わる場合は SL が空行を作らないので補正する
    if (S <> '') and (S[Length(S)] = #10) then
      Inc(Result);

  finally
    SL.Free;
  end;
end;

{ キャッシュ保存 }
procedure TSerifSceneMsgListBox.SetHeightCache(Index: Integer; AHeight: Integer);
begin
  if Index < 0 then Exit;

  if Index >= Length(FItemHeightCache) then
    SetLength(FItemHeightCache, Items.Count);

  FItemHeightCache[Index] := AHeight;
end;

procedure TSerifSceneMsgListBox.SetFontZoomIndex(Value: Integer);
begin
  if Value < SERIF_MSG_FONT_ZOOM_MIN then
    Value := SERIF_MSG_FONT_ZOOM_MIN;
  if Value > SERIF_MSG_FONT_ZOOM_MAX then
    Value := SERIF_MSG_FONT_ZOOM_MAX;
  if FFontZoomIndex = Value then Exit;

  FFontZoomIndex := Value;
  ApplyFontZoom;
end;

function TSerifSceneMsgListBox.GetZoomFontHeight: Integer;
begin
  if FBaseFontHeight = 0 then
    FBaseFontHeight := Font.Height;

  Result := FBaseFontHeight +
    ((SERIF_MSG_FONT_ZOOM_DEFAULT - FFontZoomIndex) * SERIF_MSG_FONT_ZOOM_STEP);
end;

procedure TSerifSceneMsgListBox.ApplyFontZoom;
var
  OldItemIndex, OldTopIndex: Integer;
begin
  if FBaseFontHeight = 0 then
    FBaseFontHeight := Font.Height;

  OldItemIndex := ItemIndex;
  OldTopIndex := TopIndex;

  Font.Height := GetZoomFontHeight;
  FMemo.Font.Height := Font.Height;

  Items.BeginUpdate;
  try
    RefreshAllItemHeights;
  finally
    Items.EndUpdate;
  end;

  if OldItemIndex >= Items.Count then
    OldItemIndex := Items.Count - 1;
  if OldTopIndex >= Items.Count then
    OldTopIndex := Items.Count - 1;

  if OldTopIndex >= 0 then
    TopIndex := OldTopIndex;
  if OldItemIndex >= 0 then
    ItemIndex := OldItemIndex;

  if FIsEditing then
  begin
    UpdateMemoBounds;
    OnMemoChange(FMemo);
  end;

  Invalidate;
end;

procedure TSerifSceneMsgListBox.RefreshAllItemHeights;
var
  I: Integer;
begin
  for I := 0 to Items.Count - 1 do
    RefreshItemHeight(I, '');
end;

{ Voice の行数を高速計算 }
function TSerifSceneMsgListBox.CalcVoiceLinesFast(const S: string): Integer;
var
  i: Integer;
begin
  Result := 1;  // 1 行目は必ず存在

  for i := 1 to Length(S) do
    if S[i] = #10 then
      Inc(Result);  // LF を行区切りとみなす
end;

{ キャッシュ無し時の高さ計算 }
function TSerifSceneMsgListBox.CalcItemHeightInternal(const Voice: string): Integer;
var
  VoiceLines: Integer;
begin
  Canvas.Font := Self.Font;
  FLineHeight := Canvas.TextHeight('あ');
  FCharaHeight := FLineHeight + 2;   // ★ここも同じ高さ

  VoiceLines := CalcVoiceLinesFast(Voice);

  Result :=
    FCharaHeight +              // 配役（Chara）部分の高さ
    (VoiceLines * FLineHeight) +  // セリフ部分
    FMargin * 2;                 // 余白
end;



{---------------------------------------------------------------}
{  MeasureItem  (高さ決定)                                      }
{---------------------------------------------------------------}
procedure TSerifSceneMsgListBox.MeasureItem(Index: Integer; var Height: Integer);
var
  Voice: string;
begin
  // キャッシュあれば即返す
  {
  if IsHeightCached(Index) then
  begin
    Height := FItemHeightCache[Index];
    Exit;
  end;
  }

  DoRequestMeasure(Index,Voice);

  // 高さ計算
  Height := CalcItemHeightInternal(Voice);

  // キャッシュ保存
  SetHeightCache(Index, Height);
end;

function TSerifSceneMsgListBox.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  if ssCtrl in Shift then
  begin
    Result := True;
    if WheelDelta > 0 then
      SetFontZoomIndex(FFontZoomIndex + 1)
    else if WheelDelta < 0 then
      SetFontZoomIndex(FFontZoomIndex - 1);
    Exit;
  end;

  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

procedure TSerifSceneMsgListBox.RefreshItemHeight(const Index: Integer;const aText : string);
var
  Voice: string;
  H: Integer;
begin
  if Index <> -1 then begin

    DoRequestMeasure(Index,Voice);
    // 高さを自前で再計算
    H := CalcItemHeightInternal(Voice);

    // キャッシュ更新
    SetHeightCache(Index, H);
    SendMessage(Handle, LB_SETITEMHEIGHT, Index, H);
  end;
  Invalidate;

end;


{---------------------------------------------------------------}
{  編集開始 / 終了                                              }
{---------------------------------------------------------------}
procedure TSerifSceneMsgListBox.BeginEdit();
var
  Item: TSerifSceneMsgItem;
  R: TRect;
  Index : Integer;
begin
  Index := ItemIndex;
  if (Index < 0) or (Index >= Items.Count) then Exit;
  Item := GetMsgItem(Index);
  if Item = nil then Exit;

  R := ItemRect(Index);
  Inc(R.Top, FCharaHeight+1);
  R.Bottom := R.Top + (FItemHeightCache[Index] - FCharaHeight) + 6;

  // --------------------
  // ★ ここでイベント登録
  // --------------------
  FMemo.OnKeyDown := MemoKeyDown;
  FMemo.OnExit    := MemoExit;


  FMemo.SetBounds(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
  FMemo.WordWrap := False;
  FMemo.Font.Height := Font.Height;
  FMemo.Visible := True;
  FMemo.Lines.Text := Item.Voice;
  FMemo.SelStart := Length(FMemo.Text);
  FMemo.SelLength := 0;
  FMemo.SetFocus;

  // PopupMenu 退避
  FSavedPopup := PopupMenu;

  FIsEditing := True;
  FEditingIndex := Index;

  // PopupMenu を無効化
  PopupMenu := nil;
end;



procedure TSerifSceneMsgListBox.EndEdit(ApplyChanges: Boolean);
begin
  EndEditProc(ApplyChanges);
end;

procedure TSerifSceneMsgListBox.EndEditProc(Apply: Boolean);
var
  Item: TSerifSceneMsgItem;
  S : string;
  i : Integer;
begin
  if FIsEdited then Exit;
  FIsEdited := True;

  if Apply then
  begin
    Item := TSerifSceneMsgItem(Items.Objects[FEditingIndex]);

    // ① CR 除去
    S := StringReplace(FMemo.Text, #13, '', [rfReplaceAll]);

    // ② LF → CRLF
    S := StringReplace(S, #10, sLineBreak, [rfReplaceAll]);

    // ③ 反映
    Item.Voice := S;

    // ④ 高さキャッシュクリア（★★重要）
    //ClearHeightCache(FEditingIndex);
  end;

  // 編集終了イベント
  DoEndEdit(Apply);
  SetFocus;

  // 後処理
  FMemo.Visible := False;
  FIsEditing := False;
  PopupMenu := FSavedPopup;

  RefreshItemHeight(FEditingIndex,s);

  i := ItemIndex;
  ItemIndex := -1;
  ItemIndex := i;

  FIsEdited := False;

end;

function TSerifSceneMsgListBox.IsEditing: Boolean;
begin
  Result := FIsEditing;
end;

procedure TSerifSceneMsgListBox.DoBeginEdit(Index: Integer);
begin
  // 後で実装
end;


procedure TSerifSceneMsgListBox.DoEndEdit(Apply: Boolean);
begin
  if Assigned(FOnEdited) then    FOnEdited(Self);
end;

procedure TSerifSceneMsgListBox.MemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  // Shift + Enter → 改行（何もしない）
  if (Key = VK_RETURN) and (ssShift in Shift) then
  begin
    Exit;   // TMemo がそのまま改行処理する
  end;

  // Enter（単独）→ 確定
  if (Key = VK_RETURN) then
  begin
    Key := 0;            // 改行を抑止
    EndEditProc(True);     // 確定
    Exit;
  end;

  // Esc → キャンセル
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    EndEditProc(False);
    Exit;
  end;
end;



procedure TSerifSceneMsgListBox.MemoWndProc(var Msg: TMessage);
begin
  case Msg.Msg of
    WM_VSCROLL, WM_HSCROLL,
    EM_SCROLLCARET:
      Exit; // ★スクロール禁止
  end;

  FMemoOrgWndProc(Msg);
end;

procedure TSerifSceneMsgListBox.OnMemoChange(Sender: TObject);
var
  L: Integer;
  LH: Integer;
  NewH: Integer;
begin
  // 行数（最低1）
  L := LineCountForDisplay(FMemo.Text);
  if L < 1 then
    L := 1;

  // 行の高さ（ListBox のフォントで統一）
  Canvas.Font := Self.Font;
  LH := Canvas.TextHeight('あ');

  // 高さ計算（行数 × 行高 + 少し余白）
  NewH := L * LH + 4;

  // 違う場合のみ更新
  if FMemo.Height <> NewH then
    FMemo.Height := NewH;
  // ---- 先頭行へスクロールさせる ----
  FMemo.Perform(EM_LINESCROLL, 0, -FMemo.Lines.Count);
end;

procedure TSerifSceneMsgListBox.MemoExit(Sender: TObject);
begin
  // 編集中にフォーカスが外れたら確定
  if FIsEditing then
    EndEditProc(True);
end;

procedure TSerifSceneMsgListBox.DoRequestMeasure(const Index: Integer; var str: string);
begin
  if Assigned(FOnRequestMeasure) then  FOnRequestMeasure(Self,Index,str);
end;

end.

