unit SerifScenarioCharaListView;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Winapi.Windows, Winapi.Messages,
  Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics,
  ListViewEx, SerifScenarioCharaList,ShortcutAction,ClipboardWatcher,CharaAnalyzer;

type
  TSerifScenarioCharaListView = class(TListViewEx)
  private
    FCharas        : TSerifScenarioCharaList;
    FColorCharas   : TSerifAnalyzerCharaList;  // 配役のイメージカラー

    FKeyColWidth: Integer;
    FShortcuts     : TShortcutAction;            // ショートカット管理

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

    procedure ShowCharas(Charas: TSerifScenarioCharaList);
  end;

implementation

uses AviUtl2PluginCore,Math,AviUtl2StyleColors;

{ TSerifScenarioCharaListView }

constructor TSerifScenarioCharaListView.Create(AOwner: TComponent);
begin
  inherited;

  OwnerDraw := True;
  ViewStyle := vsReport;

  // Key列の固定幅
  FKeyColWidth := 40;
  Font.Height := -13;
  ItemHeight := 20;
  ColumnClick := False;

  SetupColumns();

  FColorCharas := TSerifAnalyzerCharaList.Create;

  FShortcuts   := TShortcutAction.Create;
  FShortcuts.Add(VK_UP  ,[ssCtrl],ItemUp);
  FShortcuts.Add(VK_DOWN,[ssCtrl],ItemDown);
  FShortcuts.Add(Ord('V'),[ssCtrl],ItemPaste);
  FShortcuts.Add(VK_DELETE,[],ItemDelete);

end;

destructor TSerifScenarioCharaListView.Destroy;
begin
  FShortcuts.Free;
  FColorCharas.Free;
  inherited;
end;

procedure TSerifScenarioCharaListView.ItemDelete;
var
  Sel: TListItem;
  Index: Integer;
begin
  Sel := Selected;
  if Sel = nil then
    Exit;

  Index := Sel.Index;

  // データ削除（Charas が存在し範囲内の場合）
  if (FCharas <> nil) and (Index >= 0) and (Index < FCharas.Count) then
    FCharas.Delete(Index);

  // ListView から削除
  Items.Delete(Index);

  // 削除後のカーソル位置を調整
  if Items.Count > 0 then
  begin
    if Index >= Items.Count then
      Index := Items.Count - 1;  // 最後を消したらひとつ前へ

    ItemIndex := Index;
    Items[Index].Focused  := True;
    Items[Index].Selected := True;
  end;
end;


procedure TSerifScenarioCharaListView.ItemDown;
var
  Index: Integer;
begin
  Index := ItemIndex;
  if (FCharas = nil) or (Index < 0) or (Index >= Items.Count - 1) then
    Exit;

  FCharas.Exchange(Index, Index + 1);
  Exchange(Index, Index + 1);

  ItemIndex := Index + 1;
  Items[ItemIndex].Focused := True;
  Items[ItemIndex].Selected := True;

  FCharas.SaveToFile;
  Invalidate;

end;


function FindDelimiterPos(const S: string): Integer;
const
  DELIM1 = '>';   // 半角
  DELIM2 = '＞';  // 全角
var
  P1, P2: Integer;
begin
  P1 := Pos(DELIM1, S);
  P2 := Pos(DELIM2, S);

  if (P1 = 0) then Result := P2
  else if (P2 = 0) then Result := P1
  else Result := Min(P1, P2); // 両方あった場合は先にあるほう
end;

// クリップボードから貼り付け
procedure TSerifScenarioCharaListView.ItemPaste;
var
  S: string;
  SL: TStringList;
  Line: string;
  Work: string;
  CharaName: string;
  P: Integer;
  i: Integer;
  Exists: Boolean;
  Item: TSerifScenarioCharaItem;
begin
  if FCharas = nil then Exit;

  // クリップボード取得
  if not GetClipboardText(S) then Exit;
  if S = '' then Exit;

  SL := TStringList.Create;
  try
    SL.Text := S;

    for Line in SL do
    begin
      Work := Trim(Line);
      if Work = '' then
        Continue;

      // 「配役名 ＞ セリフ」形式から左側だけ取り出す
      P := FindDelimiterPos(Work);
      if P > 0 then
        CharaName := Trim(Copy(Work, 1, P - 1))
      else
        CharaName := Work;

      if CharaName = '' then
        Continue;

      // 重複チェック
      Exists := False;
      for i := 0 to FCharas.Count - 1 do
      begin
        if SameText(FCharas[i].Name, CharaName) then
        begin
          Exists := True;
          Break;
        end;
      end;

      if Exists then
        Continue;

      // ---- 新規追加 ----
      Item := FCharas.AddNew;
      Item.Name := CharaName;
      Item.Enabled := True;
      // 色などの追加
      Item.Color := FColorCharas.GetCharaColor(CharaName);
    end;

    FCharas.SaveToFile();
  finally
    SL.Free;
  end;

  // 再表示
  ShowCharas(FCharas);
end;




procedure TSerifScenarioCharaListView.ItemUp;
var
  Index: Integer;
begin
  Index := ItemIndex;
  if (FCharas = nil) or (Index <= 0) or (Index >= Items.Count) then
    Exit;

  FCharas.Exchange(Index, Index - 1);
  Exchange(Index, Index - 1);

  ItemIndex := Index - 1;
  Items[ItemIndex].Focused := True;
  Items[ItemIndex].Selected := True;

  FCharas.SaveToFile;
  Invalidate;

end;

procedure TSerifScenarioCharaListView.KeyDown(var Key: Word;Shift: TShiftState);
var
  C: Char;
var
  i,j: Integer;
  Chara : TSerifScenarioCharaItem;
begin
  inherited;

    // Key が英数字か判定
  if ((Key >= Ord('0')) and (Key <= Ord('9'))) or
     ((Key >= Ord('A')) and (Key <= Ord('Z'))) then
  begin
    // Key を 1文字に変換
    C := Char(Key);

    i := ItemIndex;
    if i <> -1 then begin
      Chara := TSerifScenarioCharaItem(Items[i].Data);
      // ほかに割り当てられている場合削除
      //FCharas.DeleteValueKey(C);
      for j := 0 to FCharas.Count-1 do begin
        if FCharas[j].Key = C then begin
          FCharas[j].Key := '';
          Items[j].Caption := '';
        end;
      end;

      // ショートカットを処理
      Chara.Key := C;
      Items[i].Caption := C;
    end;

    // --- (6) 次行へ移動 ---
    if i < Items.Count - 1 then
      ItemIndex := i + 1;

    FCharas.SaveToFile();
    Invalidate;
  end;

  if GAviUtl2Plugin then begin                      // ショートカット設定が有効の場合
    FShortcuts.KeyDown(Key,Shift);
  end;
end;

procedure TSerifScenarioCharaListView.SetupColumns;
var
  Col: TListColumn;
begin
  Columns.BeginUpdate;
  try
    Columns.Clear;

    // Key 列（1文字固定）
    Col := Columns.Add;
    Col.Caption := 'キー';
    Col.Width   := FKeyColWidth;

    // 配役列（自動拡張）
    Col := Columns.Add;
    Col.Caption := '配役';
    Col.Width   := -2;  // 残り幅を自動
  finally
    Columns.EndUpdate;
  end;
end;


procedure TSerifScenarioCharaListView.ShowCharas(Charas: TSerifScenarioCharaList);
var
  i : Integer;
  Item : TListItem;
  Chara : TSerifScenarioCharaItem;
begin
  FCharas := Charas;
  Items.BeginUpdate;
    try
    Clear;
    for i := 0 to FCharas.Count-1 do begin
      Chara := FCharas[i];
      Item := Items.Add();
      Item.Caption := Chara.Key;
      Item.SubItems.Clear;
      Item.SubItems.Add(Chara.Name);
      Item.Data := Chara;
    end;
  finally
    Items.EndUpdate;
  end;
end;

function TSerifScenarioCharaListView.GetTextColorForBackground(BG: TColor): TColor;
var
  R, G, B: Byte;
  Y: Integer;
begin
  BG := ColorToRGB(BG);
  R := GetRValue(BG);
  G := GetGValue(BG);
  B := GetBValue(BG);

  // 輝度から白黒を選択（一般的な YIQ 判定）
  Y := (R * 299 + G * 587 + B * 114) div 1000;
  if Y >= 128 then
    Result := clBlack   // 明るい背景 → 黒文字
  else
    Result := clWhite;  // 暗い背景 → 白文字
end;

procedure TSerifScenarioCharaListView.DrawItem(
  Item: TListItem; Rect: TRect; State: TOwnerDrawState);
var
  Chara: TSerifScenarioCharaItem;
  BG, FG: TColor;
  cv: TCanvas;
  R: TRect;
  X: Integer;
  i: Integer;
  S: string;
begin
  if Item = nil then Exit;

  cv := Canvas;
  Chara := TSerifScenarioCharaItem(Item.Data);

  // --- 背景色 ---
  if odSelected in State then
    BG := clHighlight
  else if Chara <> nil then
    BG := Chara.Color
  else
    BG := clWhite;

  // --- 文字色 ---
  if odSelected in State then
    FG := clHighlightText
  else if Chara <> nil then
    FG := GetTextColorForBackground(BG)
  else
    FG := clWindowText;

  if (Chara <> nil) and (not Chara.Enabled) then
    FG := clGrayText;

  // 背景描画
  cv.Brush.Color := BG;
  cv.FillRect(Rect);

  cv.Font.Color := FG;

  // --- 列描画（左寄せ） ---
  X := Rect.Left;

  for i := 0 to Columns.Count - 1 do
  begin
    // 列矩形を確定
    R := Rect;
    R.Left  := X;
    R.Right := X + Columns[i].Width;

    // 列内マージン（左のみ）
    Inc(R.Left, 4);

    // 描画文字列
    if i = 0 then
      S := Item.Caption
    else
      S := Item.SubItems[i - 1];

    // 左寄せ描画
    DrawText(
      cv.Handle,
      PChar(S),
      Length(S),
      R,
      DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX
    );

    // 次の列へ
    X := X + Columns[i].Width;
  end;
end;



end.

