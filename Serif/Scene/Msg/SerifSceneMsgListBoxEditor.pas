unit SerifSceneMsgListBoxEditor;

interface

uses
  System.Classes, System.Types, Winapi.Windows, System.UITypes, System.SysUtils,
  Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Vcl.ExtCtrls,
  SerifSceneMsgList, Vcl.Menus, Winapi.Messages, SerifSceneMsgListBox,
  SerifCharaIconRenderer;

type
  TSerifSceneMsgListBoxEditorRequestEvent = procedure(Sender: TObject; const Index: Integer; var aChara: string; var aColorLight, aColorBase, aColorDark: TColor) of object;

type
  // セリフ管理専用 ListBox に操作を追加
  TSerifSceneMsgListBoxEditor = class(TSerifSceneMsgListBox)
  private
    FLineIndex      : Integer;                                // 改行カーソル位置
    FMsgs           : TSerifSceneMsgList;                    // 表示中のセリフ一覧
    FOnRequestChara : TSerifSceneMsgListBoxEditorRequestEvent; // 配役色要求イベント
    FCharaIconRenderer : TSerifCharaIconRenderer;            // 共通キャラアイコン描画
    // 描画補助
    function DrawItemBackground(Index: Integer; const Rect: TRect; State: TOwnerDrawState) : TColor;
    procedure DrawItemChara(Index: Integer; const Rect: TRect;Item: TSerifSceneMsgItem);
    procedure DrawItemVoice(Index: Integer; const Rect: TRect;Item: TSerifSceneMsgItem;State: TOwnerDrawState;bk : TColor);
    function FindBreakPosition: Integer;
    function CountBreaks: Integer;
    function GetIdealFontColor(BackColor: TColor;Reverce : Boolean = False): TColor;
    function TryDrawCharaVectorImage(const CharaName: string; const Rect: TRect): Boolean;
    // 内部状態
    function GetItemIndex: Integer; reintroduce;
    procedure SetItemIndex(const Value: Integer); reintroduce;
  protected
    // 描画と編集イベント
    procedure DrawItem(Index: Integer; Rect: TRect;State: TOwnerDrawState); override;
    procedure Click; override;
    procedure DoEndEdit(Apply: Boolean);override;
    procedure DoRequestCharaColor(const Index: Integer; var aChara: string; var aColorLight, aColorBase, aColorDark: TColor); virtual;
  public
    // ライフサイクル
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // 表示更新
    procedure ShowList(Msgs : TSerifSceneMsgList);
    procedure AddList(Msgs : TSerifSceneMsgListEx);
    procedure AddItemMsg(Msg : TSerifSceneMsgItem);
    function ExchangeMsgItems(Index1, Index2: Integer): Boolean; // 表示とメッセージ実体を同時に入れ替える
    function SortByTimeline: Boolean;                            // フレーム位置に合わせてリスト順を整える
    // アイテム操作
    procedure ItemUp();
    procedure ItemDown();
    procedure ItemToggleExclamation;
    procedure ItemToggleQuestion;
    procedure ItemEnterPosPrev;
    procedure ItemEnterPosNext;
    procedure ItemEnterSelPrev;
    procedure ItemEnterSelNext;
    procedure ItemSelectClear();
    // 公開プロパティ
    property Msgs : TSerifSceneMsgList write FMsgs;
    property ItemIndex : Integer read GetItemIndex write SetItemIndex;
    property OnRequestChara: TSerifSceneMsgListBoxEditorRequestEvent read FOnRequestChara write FOnRequestChara;
  end;

implementation

uses AviUtl2StyleColors;

constructor TSerifSceneMsgListBoxEditor.Create(AOwner: TComponent);
begin
  inherited;
  FLineIndex := 0;
  FCharaIconRenderer := TSerifCharaIconRenderer.Create;
  Color := A2SCListBoxBackground;
end;

destructor TSerifSceneMsgListBoxEditor.Destroy;
begin
  FCharaIconRenderer.Free;
  inherited;
end;

procedure TSerifSceneMsgListBoxEditor.SetItemIndex(const Value: Integer);
begin
  inherited ItemIndex := Value;
  ItemSelectClear;
  // 現在位置を単独選択に揃える
  Selected[ItemIndex] := True;
  Invalidate;
  Update;
end;

procedure TSerifSceneMsgListBoxEditor.ShowList(Msgs: TSerifSceneMsgList);
var
  i,j : Integer;
  Msg : TSerifSceneMsgItem;
begin
  FMsgs := Msgs;
  j := ItemIndex;
  Items.BeginUpdate();
  try
    Clear;
    for i := 0 to Msgs.Count-1 do begin
      Msg := Msgs[i];
      Items.AddObject(Msg.Voice,Msg);
      RefreshItemHeight(i,Msg.Voice);
    end;
    if j < Items.Count then begin
      ItemIndex := j;
      TopIndex := j;
    end;
  finally
    Items.EndUpdate();
  end;
  Invalidate;
end;

procedure TSerifSceneMsgListBoxEditor.AddItemMsg(Msg: TSerifSceneMsgItem);
var
  i : Integer;
begin
  Items.BeginUpdate();
  try
    Items.AddObject(Msg.Voice,Msg);
    i := Items.Count-1;
    RefreshItemHeight(i,Msg.Voice);
  finally
    Items.EndUpdate();
  end;
end;

procedure TSerifSceneMsgListBoxEditor.AddList(Msgs: TSerifSceneMsgListEx);
var
  i,j : Integer;
  Msg : TSerifSceneMsgItem;
begin
  j := ItemIndex;
  Items.BeginUpdate();
  try
    for i := 0 to Msgs.Count-1 do begin
      Msg := Msgs[i];
      Items.AddObject(Msg.Voice,Msg);
      RefreshItemHeight(i,Msg.Voice);
    end;
    if j < Items.Count then begin
      ItemIndex := j;
      TopIndex := j;
    end;
  finally
    Items.EndUpdate();
  end;
  Invalidate;
end;

procedure TSerifSceneMsgListBoxEditor.Click;
begin
  inherited;
  FLineIndex := 0;
end;

procedure TSerifSceneMsgListBoxEditor.DoEndEdit(Apply: Boolean);
begin
  inherited;
  FLineIndex := 0;
end;

procedure TSerifSceneMsgListBoxEditor.DoRequestCharaColor(const Index: Integer;
  var aChara: string; var aColorLight, aColorBase, aColorDark: TColor);
begin
  if Assigned(FOnRequestChara) then
    FOnRequestChara(Self, Index, aChara, aColorLight, aColorBase, aColorDark);
end;

function StateToStr(State: TOwnerDrawState): string;
begin
  Result := '';
  if odSelected     in State then Result := Result + 'Selected ';
  if odFocused      in State then Result := Result + 'Focused ';
  if odDisabled     in State then Result := Result + 'Disabled ';
  if odGrayed       in State then Result := Result + 'Grayed ';
  if odChecked      in State then Result := Result + 'Checked ';
  if odHotLight     in State then Result := Result + 'Hot ';
  if odDefault      in State then Result := Result + 'Default ';
  if odComboBoxEdit in State then Result := Result + 'ComboEdit ';
end;

// 描画本体
procedure TSerifSceneMsgListBoxEditor.DrawItem(Index: Integer; Rect: TRect;State: TOwnerDrawState);
var
  Item: TSerifSceneMsgItem;
  bk : TColor;
begin
  Item := GetMsgItem(Index);
  if Item = nil then Exit;
  bk := DrawItemBackground(Index, Rect, State);
  DrawItemVoice(Index, Rect, Item,State,bk);
  DrawItemChara(Index, Rect, Item);
end;

// 背景描画
function TSerifSceneMsgListBoxEditor.DrawItemBackground(Index: Integer;const Rect: TRect; State: TOwnerDrawState) : TColor;
var
  cv: TCanvas;
  R: TRect;
begin
  cv := Canvas;
  cv.Brush.Style := bsSolid;
  cv.Brush.Color := A2SCListBoxBackground;
  cv.FillRect(Rect);
  // 配役高さは描画計算と揃える
  FCharaHeight := FLineHeight + 2;
  R := Rect;
  Inc(R.Top, FCharaHeight);
  if (odSelected in State) or (odFocused in State) then
  begin
    // Voice 部分だけ選択色にする
    cv.Brush.Color := clNavy;
    cv.FillRect(R);
  end
  else
  begin
    cv.Brush.Color := A2SCListBoxBackground;
    cv.FillRect(R);
  end;
  // 配役部分は通常背景で統一する
  R := Rect;
  R.Bottom := Rect.Top + FCharaHeight;
  Result := cv.Brush.Color;
  cv.Brush.Color := A2SCListBoxBackground;
  cv.FillRect(R);
end;

// 背景色に応じた文字色を返す
function TSerifSceneMsgListBoxEditor.GetIdealFontColor(BackColor: TColor;Reverce : Boolean = False): TColor;
var
  R, G, B: Byte;
  Y: Double;
begin
  BackColor := ColorToRGB(BackColor);
  R := GetRValue(BackColor);
  G := GetGValue(BackColor);
  B := GetBValue(BackColor);
  // 輝度から視認しやすい前景色を選ぶ
  Y := R * 0.299 + G * 0.587 + B * 0.114;
  if Reverce then begin
    if Y >= 186 then Result := clWhite else Result := clBlack;
  end
  else begin
    if Y < 186 then Result := clWhite else Result := clBlack;
  end;
end;

function TSerifSceneMsgListBoxEditor.GetItemIndex: Integer;
begin
  Result := inherited ItemIndex;
end;

// キャラ名に対応するベクター画像を共通レンダラーで描画する
function TSerifSceneMsgListBoxEditor.TryDrawCharaVectorImage(
  const CharaName: string; const Rect: TRect): Boolean;
begin
  Result := FCharaIconRenderer.Draw(Canvas, CharaName, Rect);
end;

// 配役表示
procedure TSerifSceneMsgListBoxEditor.DrawItemChara(Index: Integer; const Rect: TRect; Item: TSerifSceneMsgItem);
var
  cv: TCanvas;
  x0, x1, x2: Integer;
  ImageSize: Integer;
  ImageRect: TRect;
  p: array[0..3] of TPoint;
  cLight, cBase, cDark : TColor;
  s, sInfo : string;
  TextW, TextRight, BandLeft, BandRight, BandW: Integer;
  RBase, RLight, RDark: TRect;
begin
  cv := Canvas;
  FLineHeight := cv.TextHeight('あ');
  FCharaHeight := FLineHeight + 2;
  x0 := Rect.Left + 0;
  x2 := Rect.Right - FMargin;
  p[0] := Point(x0,           Rect.Top + FCharaHeight);
  p[1] := Point(x0 + 8,       Rect.Top);
  p[2] := Point(x2,           Rect.Top);
  p[3] := Point(x2 + 8,       Rect.Top + FCharaHeight);
  cLight := $FFFFFF;
  cBase := $EEEEEE;
  cDark := $C8C8C8;
  s := Item.Chara;
  DoRequestCharaColor(Index, s, cLight, cBase, cDark);
  cv.Brush.Style := bsSolid;
  cv.Brush.Color := cBase;
  cv.Polygon(p);

  cv.Brush.Style := bsClear;
  SetTextColor(Canvas.Handle, GetIdealFontColor(cBase,False));
  ImageSize := FCharaHeight - 2;
  if ImageSize < 0 then
    ImageSize := 0;
  ImageRect := Rect;
  ImageRect.Left := x0 + 10;
  ImageRect.Top := Rect.Top + 1;
  ImageRect.Right := ImageRect.Left + ImageSize;
  ImageRect.Bottom := ImageRect.Top + ImageSize;
  TryDrawCharaVectorImage(s, ImageRect);
  x1 := ImageRect.Right + 6;
  cv.TextOut(x1, Rect.Top + 1, s);

  // キャラ名の後ろへ感情と演出の補足情報を続けて表示する
  sInfo := '';
  if Trim(Item.Emotion) <> '' then
    sInfo := '[' + Item.Emotion + ']';
  if Trim(Item.Direction) <> '' then
  begin
    if sInfo <> '' then
      sInfo := sInfo + ' ';
    sInfo := sInfo + '(' + Item.Direction + ')';
  end;

  if sInfo <> '' then
  begin
    // 補足情報は背景色に関係なく黒で固定表示する
    SetTextColor(Canvas.Handle, clBlack);
    cv.TextOut(x1 + cv.TextWidth(s) + 8, Rect.Top + 1, sInfo);
  end;

  TextW := cv.TextWidth(s);
  if sInfo <> '' then
    TextW := TextW + 8 + cv.TextWidth(sInfo);
  TextRight := x1 + TextW + 12;

  BandLeft := x0 + ((x2 - x0) * 58 div 100);
  if BandLeft < TextRight then
    BandLeft := TextRight;
  BandRight := x2 + 8;
  BandW := BandRight - BandLeft;

  if BandW > 24 then
  begin
    // 3色化フェーズ4: 配役帯の右側へ、全体幅比率でイメージカラーを並べる。
    RBase := Rect;
    RBase.Left := BandLeft;
    RBase.Top := Rect.Top + 1;
    RBase.Right := BandLeft + (BandW * 56 div 100);
    RBase.Bottom := Rect.Top + FCharaHeight - 1;

    RLight := RBase;
    RLight.Left := RBase.Right;
    RLight.Right := RLight.Left + (BandW * 28 div 100);

    RDark := RLight;
    RDark.Left := RLight.Right;
    RDark.Right := BandRight - 1;

    cv.Brush.Style := bsSolid;
    cv.Brush.Color := cBase;
    cv.FillRect(RBase);
    cv.Brush.Color := cLight;
    cv.FillRect(RLight);
    cv.Brush.Color := cDark;
    cv.FillRect(RDark);

    cv.Pen.Style := psSolid;
    cv.Pen.Color := A2SCListBoxBackground;
    cv.MoveTo(RLight.Left, RLight.Top);
    cv.LineTo(RLight.Left, RLight.Bottom);
    cv.MoveTo(RDark.Left, RDark.Top);
    cv.LineTo(RDark.Left, RDark.Bottom);
  end;
end;

// セリフ表示
procedure TSerifSceneMsgListBoxEditor.DrawItemVoice(
  Index: Integer; const Rect: TRect; Item: TSerifSceneMsgItem;State: TOwnerDrawState;bk : TColor);
var
  cv: TCanvas;
  Lines: TStringList;
  i: Integer;
  StartY: Integer;
  yh: Integer;
  LineY: Integer;
  MarkX: Integer;
  LeftTextX: Integer;
begin
  // 編集中は Memo を優先する
  if IsEditingItem(Index) then Exit;
  cv := Canvas;
  cv.Brush.Style := bsClear;
  cv.Font.Color := GetIdealFontColor(bk);
  FLineHeight := cv.TextHeight('あ');
  yh := FLineHeight + 2;
  StartY := Rect.Top + yh + 4;
  Lines := TStringList.Create;
  try
    Lines.Text := Item.Voice;
    LeftTextX := Rect.Left + FMargin;
    for i := 0 to Lines.Count - 1 do
    begin
      LineY := StartY + (i * FLineHeight);
      cv.TextOut(LeftTextX, LineY, Lines[i]);
      if i < Lines.Count - 1 then
      begin
        MarkX := LeftTextX + cv.TextWidth(Lines[i]) + 4;
        // 選択中の改行位置だけ強調表示する
        if i = FLineIndex then begin
          cv.TextOut(MarkX, LineY, '▼')
        end
        else begin
          cv.TextOut(MarkX, LineY, '↓');
        end;
      end;
      if i = Lines.Count - 1 then
      begin
        MarkX := LeftTextX + cv.TextWidth(Lines[i]) + 4;
        cv.TextOut(MarkX, LineY, '←');
      end;
    end;
  finally
    Lines.Free;
  end;
end;

// 文末の感嘆符を切り替える
procedure TSerifSceneMsgListBoxEditor.ItemToggleExclamation;
var
  Item: TSerifSceneMsgItem;
  S: string;
  LastChar: Char;
begin
  Item := GetMsgItem(ItemIndex);
  if Item = nil then Exit;
  S := Item.Voice.TrimRight;
  if S = '' then Exit;
  LastChar := S[Length(S)];
  // 同種の記号が末尾にあれば削除し、なければ全角を追加する
  if (LastChar = '！') or (LastChar = '!') then
  begin
    Delete(S, Length(S), 1);
  end
  else
  begin
    S := S + '！';
  end;
  Item.Voice := S;
  Invalidate;
end;

// 文末の疑問符を切り替える
procedure TSerifSceneMsgListBoxEditor.ItemToggleQuestion;
var
  Item: TSerifSceneMsgItem;
  S: string;
  LastChar: Char;
begin
  Item := GetMsgItem(ItemIndex);
  if Item = nil then Exit;
  S := Item.Voice.TrimRight;
  if S = '' then Exit;
  LastChar := S[Length(S)];
  // 同種の記号が末尾にあれば削除し、なければ全角を追加する
  if (LastChar = '？') or (LastChar = '?') then
  begin
    Delete(S, Length(S), 1);
  end
  else
  begin
    S := S + '？';
  end;
  Item.Voice := S;
  Invalidate;
end;

procedure TSerifSceneMsgListBoxEditor.ItemUp;
var
  i : Integer;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if i = 0 then Exit;
  ItemSelectClear;
  ExchangeMsgItems(i,i-1);              // MsgsとItemsを同じ順番で入れ替える
  ItemIndex := i - 1;
  Selected[ItemIndex] := True;
  Invalidate;
  Update;
end;

procedure TSerifSceneMsgListBoxEditor.ItemDown;
var
  i : Integer;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if i >= FMsgs.Count-1 then Exit;
  ItemSelectClear;
  ExchangeMsgItems(i,i+1);              // MsgsとItemsを同じ順番で入れ替える
  ItemIndex := i + 1;
  Selected[ItemIndex] := True;
  Invalidate;
  Update;
end;

function TSerifSceneMsgListBoxEditor.ExchangeMsgItems(Index1,
  Index2: Integer): Boolean;
begin
  Result := False;
  if FMsgs = nil then Exit;                                     // メッセージリストが無い場合未処理
  if Index1 = Index2 then Exit;                                 // 同じ位置は入れ替え不要
  if Index1 < 0 then Exit;                                      // 範囲外は未処理
  if Index2 < 0 then Exit;                                      // 範囲外は未処理
  if Index1 >= FMsgs.Count then Exit;                           // Msgs範囲外は未処理
  if Index2 >= FMsgs.Count then Exit;                           // Msgs範囲外は未処理
  if Index1 >= Items.Count then Exit;                           // Items範囲外は未処理
  if Index2 >= Items.Count then Exit;                           // Items範囲外は未処理

  Items.BeginUpdate;                                            // 連続更新中の再描画を抑える
  try
    FMsgs.Exchange(Index1, Index2);                             // 高さ要求が参照するMsgsを先に入れ替える
    Items.Exchange(Index1, Index2);                             // ListBox表示も同じ位置で入れ替える
    RefreshItemHeight(Index1, FMsgs[Index1].Voice);             // 入れ替え後の内容で行高を再計算
    RefreshItemHeight(Index2, FMsgs[Index2].Voice);             // 入れ替え後の内容で行高を再計算
  finally
    Items.EndUpdate;                                            // まとめて再描画を許可する
  end;

  Result := True;                                               // 入れ替え完了
end;

function TSerifSceneMsgListBoxEditor.SortByTimeline: Boolean;
var
  i, j: Integer;
  Msg1, Msg2: TSerifSceneMsgItem;

  function ShouldSwap(A, B: TSerifSceneMsgItem): Boolean;
  begin
    Result := False;
    if (A = nil) or (B = nil) then Exit;                        // 比較対象が無い場合は現状維持
    if A.FrameStart > B.FrameStart then
    begin
      Result := True;                                           // 開始フレームが後ろなら入れ替える
      Exit;
    end;
    if A.FrameStart < B.FrameStart then Exit;                   // 開始フレームが前なら現状維持
    if A.SerifLayer > B.SerifLayer then
      Result := True;                                           // 同一フレームでは若いレイヤーを上にする
  end;

begin
  Result := False;
  if FMsgs = nil then Exit;                                     // メッセージリストが無い場合未処理
  if IsEditing then Exit;                                       // 編集中は対象Indexがずれるため未処理
  if FMsgs.Count <> Items.Count then Exit;                      // MsgsとItemsの数が違う場合は未処理

  Items.BeginUpdate;                                            // ソート中のちらつきを抑える
  try
    for i := 1 to FMsgs.Count - 1 do                            // 安定ソート用に先頭から順に見る
    begin
      j := i;                                                   // 現在位置を前方向へ差し込む
      while j > 0 do
      begin
        Msg1 := FMsgs[j - 1];                                   // 1つ前のセリフ参照
        Msg2 := FMsgs[j];                                       // 現在のセリフ参照
        if not ShouldSwap(Msg1, Msg2) then Break;               // 順番が正しければ次へ
        if ExchangeMsgItems(j - 1, j) then
          Result := True;                                       // 入れ替えが発生したことを返す
        Dec(j);                                                 // さらに前の位置と比較する
      end;
    end;
  finally
    Items.EndUpdate;                                            // まとめて再描画を許可する
  end;
end;

// 改行位置を1文字前へ移動する
procedure TSerifSceneMsgListBoxEditor.ItemEnterPosPrev;
var
  Item: TSerifSceneMsgItem;
  S: string;
  P: Integer;
begin
  Item := GetMsgItem(ItemIndex);
  if Item = nil then Exit;
  S := Item.Voice;
  P := FindBreakPosition;
  // 改行が無い場合は末尾1文字前に新規作成する
  if P = -1 then
  begin
    if Length(S) >= 2 then begin
      Insert(#13#10, S, Length(S));
      Item.Voice := S;
      RefreshItemHeight(ItemIndex,S);
      Exit;
    end;
  end;
  P := FindBreakPosition;
  // 先頭位置より前へは動かせない
  if P <= 1 then Exit;
  S := Item.Voice;
  // 連続改行は作らない
  if (P > 2) and (Copy(S,P-2,2) = #$0d#$0a) then Exit;
  Delete(S, P, 2);
  Insert(#13#10, S, P-1);
  Item.Voice := S;
  RefreshItemHeight(ItemIndex,S);
end;

// 改行位置を1文字後へ移動する
procedure TSerifSceneMsgListBoxEditor.ItemEnterPosNext;
var
  Item: TSerifSceneMsgItem;
  S: string;
  P: Integer;
begin
  Item := GetMsgItem(ItemIndex);
  if Item = nil then Exit;
  P := FindBreakPosition;
  if P <= 0 then Exit;
  S := Item.Voice;
  Delete(S, P, 2);
  // 連続改行は作らない
  if Copy(S,P,2) = #$0d#$0a then Exit;
  // 末尾以外なら1文字後へ挿入する
  if Length(S) <> P then begin
    Insert(#13#10, S, P+1);
  end;
  Item.Voice := S;
  RefreshItemHeight(ItemIndex,S);
end;

// 現在参照中の改行位置を返す
function TSerifSceneMsgListBoxEditor.FindBreakPosition: Integer;
var
  Voice: string;
  i, Count: Integer;
begin
  Result := -1;
  Voice := GetMsgItem(ItemIndex).Voice;
  if Voice = '' then Exit;
  Count := 0;
  for i := 1 to Length(Voice) do
  begin
    if Voice[i] = #13 then
    begin
      // CRLF の組だけを改行として扱う
      if (i < Length(Voice)) and (Voice[i+1] = #10) then
      begin
        if Count = FLineIndex then
        begin
          Result := i;
          Exit;
        end;
        Inc(Count);
      end;
    end;
  end;
end;

// 改行参照位置を1つ前へ移動する
procedure TSerifSceneMsgListBoxEditor.ItemEnterSelPrev;
begin
  if FLineIndex = 0 then Exit;
  Dec(FLineIndex);
  Invalidate;
end;

// 選択状態を全解除する
procedure TSerifSceneMsgListBoxEditor.ItemSelectClear;
var
  i : Integer;
begin
  for i := 0 to Count-1 do begin
    Selected[i] := False;
  end;
end;

// 改行参照位置を1つ後ろへ移動する
procedure TSerifSceneMsgListBoxEditor.ItemEnterSelNext;
var
  cnt : Integer;
begin
  cnt := CountBreaks();
  if FLineIndex >= cnt-1 then Exit;
  Inc(FLineIndex);
  Invalidate;
end;

// Voice 内の改行数を返す
function TSerifSceneMsgListBoxEditor.CountBreaks: Integer;
var
  Voice: string;
  i: Integer;
begin
  Result := 0;
  Voice := GetMsgItem(ItemIndex).Voice;
  if Voice = '' then Exit;
  i := 1;
  while i < Length(Voice) do
  begin
    if (Voice[i] = #13) and (Voice[i+1] = #10) then
    begin
      Inc(Result);
      Inc(i, 2);
    end
    else
      Inc(i);
  end;
end;

end.
