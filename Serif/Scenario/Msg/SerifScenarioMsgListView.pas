unit SerifScenarioMsgListView;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Winapi.Windows, Winapi.Messages,
  Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics,
  ListViewEx, SerifScenarioCharaList,SerifScenarioMsgList,ShortcutAction,ClipboardWatcher;

type
  TSerifScenarioMsgListView = class(TListViewEx)
  private
    FMsgs          : TSerifScenarioMsgList;       // セリフのリスト
    FCharas        : TSerifScenarioCharaList;     // 配役リスト（キー判定に使用）
    FKeyColWidth   : Integer;
    FShortcuts     : TShortcutAction;            // ショートカット管理

    function AssignCharaByKey(Key: Word): Boolean;
    function ExtractSerifText(const S: string): string;
    procedure SetupColumns;
    function GetTextColorForBackground(BG: TColor): TColor;
  protected
    procedure DrawItem(Item: TListItem; Rect: TRect; State: TOwnerDrawState); override;
    // ショートカット用キー降下イベント
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ItemUp();
    procedure ItemDown();
    procedure ItemDelete();
    procedure ItemPaste();
    procedure ItemCopy();
    procedure ItemClear();

    procedure ShowMsg(Charas: TSerifScenarioCharaList;Msgs: TSerifScenarioMsgList);
  end;

implementation

uses AviUtl2PluginCore,Math,AviUtl2StyleColors;


{ TSerifScenarioMsgListView }

constructor TSerifScenarioMsgListView.Create(AOwner: TComponent);
begin
  inherited;

  OwnerDraw := True;
  ViewStyle := vsReport;

  FKeyColWidth := 140;
  Font.Height := -13;
  ItemHeight := 20;
  Color := A2SCListBoxBackground;

  SetupColumns();

  FShortcuts   := TShortcutAction.Create;
  FShortcuts.Add(VK_UP  ,[ssCtrl],ItemUp);
  FShortcuts.Add(VK_DOWN,[ssCtrl],ItemDown);
  FShortcuts.Add(Ord('V'),[ssCtrl],ItemPaste);
  FShortcuts.Add(Ord('C'),[ssCtrl],ItemCopy);
  FShortcuts.Add(VK_DELETE,[],ItemDelete);

end;

destructor TSerifScenarioMsgListView.Destroy;
begin
  FShortcuts.Free;

  inherited;
end;



function TSerifScenarioMsgListView.AssignCharaByKey(Key: Word): Boolean;
var
  C: Char;
  MsgIndex: Integer;
  MsgItem: TSerifScenarioMsgItem;
  CharaItem: TSerifScenarioCharaItem;
  i: Integer;
begin
  Result := False;

  // --- (1) 英数字でなければ即脱出 ---
  if not (((Key >= Ord('0')) and (Key <= Ord('9'))) or
          ((Key >= Ord('A')) and (Key <= Ord('Z')))) then
    Exit;

  C := Char(Key);

  // --- (2) 選択行が存在しなければ脱出 ---
  MsgIndex := ItemIndex;
  if (MsgIndex < 0) or (MsgIndex >= FMsgs.Count) then Exit;

  MsgItem := FMsgs[MsgIndex];
  if MsgItem = nil then Exit;

  // --- (3) CharaList からキー一致を探す ---
  CharaItem := nil;
  for i := 0 to FCharas.Count - 1 do
    if SameText(FCharas[i].Key, C) then
    begin
      CharaItem := FCharas[i];
      Break;
    end;

  // 見つからなければ脱出
  if CharaItem = nil then Exit;

  // --- (4) 値を代入 ---
  MsgItem.Chara := CharaItem.Name;
  MsgItem.Color := CharaItem.Color;
  Items[MsgIndex].Caption := MsgItem.Chara;
  // --- (5) 再描画 ---
  Invalidate;

  // --- (6) 次行へ移動 ---
  if MsgIndex < Items.Count - 1 then ItemIndex := MsgIndex + 1;

  // --- (7) 保存 ---
  FMsgs.SaveToFile();

  Result := True;
end;


procedure TSerifScenarioMsgListView.ShowMsg(
  Charas: TSerifScenarioCharaList;
  Msgs: TSerifScenarioMsgList);
var
  i: Integer;
  LItem: TListItem;
begin
  FCharas := Charas;
  FMsgs   := Msgs;

  Items.BeginUpdate;
  try
    Items.Clear;
    SetupColumns;

    if FMsgs <> nil then
    begin
      for i := 0 to FMsgs.Count - 1 do
      begin
        LItem := Items.Add;
        LItem.Data := FMsgs[i];              // ← ここが重要（DrawItem がこれを見る）

        LItem.Caption := FMsgs[i].Chara;     // Chara 列
        LItem.SubItems.Add(FMsgs[i].Serif);  // Serif 列
      end;
    end;

  finally
    Items.EndUpdate;
  end;
end;



procedure TSerifScenarioMsgListView.DrawItem(
  Item: TListItem; Rect: TRect; State: TOwnerDrawState);
var
  Msg: TSerifScenarioMsgItem;
  BG, FG: TColor;
  cv: TCanvas;
  R: TRect;
  i: Integer;
  S: string;
begin
  cv := Canvas;
  Msg := TSerifScenarioMsgItem(Item.Data);

  // ★ 背景色（配役カラー）、未設定なら白
  if Msg <> nil then
    BG := Msg.Color
  else
    BG := A2SCListBoxBackground;

  // フォーカスまたは選択状態のときはシステム色を優先
  if odSelected in State then BG := clHighlight;

  // ★ 文字色を背景から自動判定（白/黒）
  if odSelected in State then
    FG := clHighlightText
  else
    FG := GetTextColorForBackground(BG);

  // 背景塗り
  cv.Brush.Color := BG;
  cv.FillRect(Rect);

  // 文字色設定
  cv.Font.Color := FG;

  // ---- 各カラムの描画 ----
  R := Rect;
  R.Left := R.Left + 4;

  for i := 0 to Columns.Count - 1 do
  begin
    if i = 0 then
      S := Item.Caption
    else
      S := Item.SubItems[i - 1];

    DrawText(cv.Handle, PChar(S), Length(S), R,
             DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);

    // 次のカラムへ
    R.Left  := R.Left + Columns[i].Width;
    R.Right := R.Left + Columns[Math.Min(i+1, Columns.Count-1)].Width;
  end;
end;


function TSerifScenarioMsgListView.ExtractSerifText(const S: string): string;
var
  p: Integer;
  Work: string;
begin
  Work := Trim(S);

  // 「＞」があれば右側だけ使う
  p := Work.IndexOf('＞');
  if p >= 0 then
    Work := Work.Substring(p + 1).Trim;

  // ★禁止文字除去（あなたが後でここに処理を追加）
  // Work := RemoveForbiddenChars(Work);

  Result := Work;
end;


function TSerifScenarioMsgListView.GetTextColorForBackground(
  BG: TColor): TColor;
var
  R, G, B: Integer;
  Y: Double;
begin
  // Delphi の TColor は BGR
  R := BG and $FF;
  G := (BG shr 8) and $FF;
  B := (BG shr 16) and $FF;

  // 輝度計算（相対的な明るさ）
  Y := R*0.299 + G*0.587 + B*0.114;

  if Y < 128 then
    Result := clWhite   // 暗い背景 → 白文字
  else
    Result := clBlack;  // 明るい背景 → 黒文字
end;

procedure TSerifScenarioMsgListView.ItemClear;
begin
  FMsgs.Clear;
  Clear();
end;

procedure TSerifScenarioMsgListView.ItemCopy;
var
  SL: TStringList;
  i: Integer;
  Msg: TSerifScenarioMsgItem;
  Line: string;
begin
  if FMsgs = nil then Exit;

  SL := TStringList.Create;
  try
    for i := 0 to FMsgs.Count - 1 do
    begin
      Msg := FMsgs[i];

      // 配役（空なら何もつけない）
      if Msg.Chara <> '' then
        Line := Msg.Chara + '＞' + Msg.Serif
      else
        Line := '＞' + Msg.Serif;     // 配役なし

      SL.Add(Line);
    end;

    // クリップボードへ送る
    SetClipboardText(SL.Text);

  finally
    SL.Free;
  end;
end;


procedure TSerifScenarioMsgListView.ItemDelete;
var
  idx: Integer;
begin
  idx := ItemIndex;
  if (idx < 0) or (idx >= Items.Count) then  Exit;

  // --- データ削除 ---
  if (FMsgs <> nil) and (idx < FMsgs.Count) then
    FMsgs.Delete(idx);

  // --- ListView から削除 ---
  Items.Delete(idx);

  // --- カーソル位置調整 ---
  if idx >= Items.Count then
    idx := Items.Count - 1;

  if idx >= 0 then
    ItemIndex := idx;

  // --- 保存 ---
  if FMsgs <> nil then
    FMsgs.SaveToFile;

  // --- 再描画 ---
  Invalidate;
end;


procedure TSerifScenarioMsgListView.ItemDown;
var
  idx: Integer;
begin
  idx := ItemIndex;
  if (FMsgs = nil) or (idx < 0) or (idx >= Items.Count - 1) then
    Exit;

  FMsgs.Exchange(idx, idx + 1);
  Exchange(idx, idx + 1);

  ItemIndex := idx + 1;
  Items[ItemIndex].Focused := True;
  Items[ItemIndex].Selected := True;

  FMsgs.SaveToFile;
  Invalidate;

end;

procedure TSerifScenarioMsgListView.ItemPaste();
var
  s: string;
  Lines: TStringList;
  i: Integer;
  Serif: string;
  MsgItem: TSerifScenarioMsgItem;
begin
  // クリップボード取得
  if not GetClipboardText(S) then Exit;
  if S = '' then Exit;

  ItemClear();

  Lines := TStringList.Create;
  try
    Lines.Text := s;

    for i := 0 to Lines.Count - 1 do
    begin
      Serif := ExtractSerifText(Lines[i]);
      if Serif = '' then
        Continue;

      MsgItem := FMsgs.AddNew;
      MsgItem.Color := clWhite;
      MsgItem.Serif := Serif;
      MsgItem.Chara := '';          // まだ配役なし
    end;

    // 保存
    FMsgs.SaveToFile;

    // 再表示
    ShowMsg(FCharas, FMsgs);

    // カーソルを先頭に
    if Items.Count > 0 then
      ItemIndex := 0;

  finally
    Lines.Free;
  end;
end;


procedure TSerifScenarioMsgListView.ItemUp;
var
  idx: Integer;
begin
  idx := ItemIndex;
  if (FMsgs = nil) or (idx <= 0) or (idx >= Items.Count) then
    Exit;

  FMsgs.Exchange(idx, idx - 1);
  Exchange(idx, idx - 1);

  ItemIndex := idx - 1;
  Items[ItemIndex].Focused := True;
  Items[ItemIndex].Selected := True;

  FMsgs.SaveToFile;
  Invalidate;

end;

procedure TSerifScenarioMsgListView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;

  // Ctrl+C / Ctrl+V と単体 C / V の衝突を避けるため、Ctrl 系を先に処理する
  if FShortcuts.KeyDown(Key, Shift) then Exit;

  // 配役キー割り当ては修飾キーなしの単体入力だけを対象にする
  if Shift = [] then
    if AssignCharaByKey(Key) then Exit;
end;

procedure TSerifScenarioMsgListView.SetupColumns;
var
  Col: TListColumn;
begin
  Columns.Clear;

  // 1列目：配役（Chara）
  Col := Columns.Add;
  Col.Caption := '配役';
  Col.Width   := FKeyColWidth;   // 固定幅

  // 2列目：セリフ（Serif）
  Col := Columns.Add;
  Col.Caption := 'セリフ';
  Col.Width   := -2;             // 自動で残り幅
end;


end.

