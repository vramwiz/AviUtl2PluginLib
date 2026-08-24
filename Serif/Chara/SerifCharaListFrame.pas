unit SerifCharaListFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  StdCtrls,Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,ListBoxEdit,
  SerifCharaList,ListViewRTTI, Vcl.Menus,ConfirmDialogForm,ShortcutAction,
  System.ImageList, Vcl.ImgList, Vcl.ComCtrls, Vcl.ToolWin,ToolbarButtons,ConfigPanel;

//--------------------------------------------------------------------------//
//  行ごとに背景色を変えて見やすくしたリストコントロールクラス              //
//--------------------------------------------------------------------------//
type
  TListBoxCharaColor = class(TListBoxEdit)
	private
		{ Private 宣言 }
    // 背景色から適した文字色を取得
    function GetIdealFontColor(BackColor: TColor): TColor;
  protected
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
  public
		{ Public 宣言 }
  end;

type
  // 棒読みちゃん対応: 配役Name変更時に、Keywordを基準にセリフ一覧を再割り当てするための通知。
  TSerifCharaRenameEvent = procedure(Sender: TObject; const OldName, Keyword, NewName: string) of object;

type
  TFrameSerifCharaList = class(TFrame)
    PanelList: TPanel;
    PanelInfo: TPanel;
    MenuPop: TPopupMenu;
    MenuCopy: TMenuItem;
    MenuDelete: TMenuItem;
    N3: TMenuItem;
    MenuItemUp: TMenuItem;
    MenuItemDown: TMenuItem;
    MenuRefresh: TMenuItem;
    N1: TMenuItem;
    Splitter1: TSplitter;
    ImageList1: TImageList;
    procedure MenuDeleteClick(Sender: TObject);
    procedure MenuCopyClick(Sender: TObject);
    procedure MenuItemUpClick(Sender: TObject);
    procedure MenuItemDownClick(Sender: TObject);
    procedure MenuRefreshClick(Sender: TObject);
  private
    { Private 宣言 }
    FToolBar       : TToolbarButtons;            // 独自ツールバー
    FCharas    : TSerifCharaList;
    FListBox   : TListBoxCharaColor;
    FPanelConfig : TConfigPanel;
    FShortcuts     : TShortcutAction;            // ショートカット管理
    FDialog    : TFormConfirmDialog;     // 独自ダイアログ
    FOnChange: TNotifyEvent;
    FOnRenameChara: TSerifCharaRenameEvent;
    FEditingChara: TSerifCharaItem;       // 棒読みちゃん対応: 編集中の配役を保持
    FEditingCharaName: string;            // 棒読みちゃん対応: Name変更前の値を保持
    procedure ShowInfo(Chara : TSerifCharaItem);
    procedure ShowToolBar;
    // ショートカット用キー降下イベント
    procedure OnListBoxKeyDown(Sender: TObject;var Key: Word; Shift: TShiftState);

    procedure OnListBoxClick(Sender: TObject);
    procedure OnListViewChange(Sender: TObject);
    // 棒読みちゃん対応: ConfigPanelで編集したName/色を左の配役リストへ即時反映する。
    procedure RefreshSelectedListItem;
    // 棒読みちゃん対応: 配役Name変更をセリフ一覧側へ伝播するため、Keywordと新名を通知する。
    procedure CheckRenameChara;
  protected
    procedure DoChange();
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ItemUp();
    procedure ItemDown();
    procedure ItemDelete();
    procedure ItemCopy();

    procedure ShowList(Charas : TSerifCharaList);
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnRenameChara: TSerifCharaRenameEvent read FOnRenameChara write FOnRenameChara;
  end;

implementation

uses ListViewEditPluginDialog,ListViewEditPluginLib,AviUtl2StyleColors;

{$R *.dfm}

{ TFrameSerifVoiceWatcherList }

constructor TFrameSerifCharaList.Create(AOwner: TComponent);
begin
  inherited;
  FToolBar := TToolbarButtons.Create(Self);
  FToolBar.Parent := PanelList;
  FToolBar.Align := alTop;
  FToolBar.Height := 24;
  FToolBar.NormalColor := A2SCToolBarBackground;
  FToolBar.HoverColor := A2SCToolBarHot;
  FToolBar.DownColor := A2SCToolBarChecked;
  FToolBar.Images := ImageList1;

  FListBox := TListBoxCharaColor.Create(Self);
  FListBox.Parent := PanelList;
  FListBox.Align := alClient;
  FListBox.Font.Height := -12;
  FListBox.ItemHeight := 20;
  FListBox.BorderWidth := 0;
  FListBox.BevelOuter := bvNone;
  //FListBox.PopupMenu := MenuPop;
  FListBox.OnClick := OnListBoxClick;
  FListBox.OnKeyDown := OnListBoxKeyDown;

  FPanelConfig := TConfigPanel.Create(Self);
  FPanelConfig.Parent := PanelInfo;
  FPanelConfig.Align := alClient;
  FPanelConfig.Color := A2SCListViewBackground;
  FPanelConfig.ListViewColor := A2SCListViewBackground;
  FPanelConfig.Font.Height := -12;
  FPanelConfig.ListView.ItemHeight := 20;
  FPanelConfig.OnChange := OnListViewChange;

  FShortcuts := TShortcutAction.Create;
  FShortcuts.Add(VK_UP  ,[ssCtrl],ItemUp);
  FShortcuts.Add(VK_DOWN,[ssCtrl],ItemDown);
  FShortcuts.Add(VK_DELETE,[],ItemDelete);

  FDialog := TFormConfirmDialog.Create(Self);
end;

destructor TFrameSerifCharaList.Destroy;
begin
  FShortcuts.Free;
  FDialog.Free;
  FPanelConfig.Free;
  FListBox.Free;
  FToolBar.Free;
  inherited;
end;

procedure TFrameSerifCharaList.ShowList(Charas : TSerifCharaList);
var
  i : Integer;
  Chara : TSerifCharaItem;
begin
  FCharas := Charas;
  if FCharas.Count = 0 then
    ShowInfo(nil); // 空リスト表示時に破棄済み配役の設定参照が残らないようにする
  FListBox.Items.BeginUpdate;
  try
     FListBox.Clear;
     for i := 0 to FCharas.Count-1 do begin
       Chara := FCharas[i];
       FListBox.Items.AddObject(Chara.Name,Chara);
     end;
     if FCharas.Count > 0 then begin
       FListBox.ItemIndex := 0;
       ShowInfo(FCharas[0]);
     end;

  finally
    FListBox.Items.EndUpdate;
  end;
  ShowToolBar;
end;

procedure TFrameSerifCharaList.ShowToolBar;
begin
  if FToolBar.Tag = 0 then begin
    //FToolBar.AddIcon('服装を新規追加',0,FListView.ItemAdd);
    //FToolBar.AddIcon('服装をコピー除',1,FListView.ItemCopy);
    FToolBar.AddIcon('配役を削除',2,ItemDelete);
    FToolBar.AddIcon('上に移動',3,ItemUp);
    FToolBar.AddIcon('下に移動',4,ItemDown);
    FToolBar.Tag := 1;
  end;
end;

procedure SetLayer(ts : TStringList);
var
  i : Integer;
begin
  ts.Clear;
  for i := 0 to 99 do begin
    ts.AddObject('レイヤー ' + IntToStr(i+1),TObject(i));
  end;
end;

procedure TFrameSerifCharaList.ShowInfo(Chara : TSerifCharaItem);
var
  lv : TListViewRTTI;
begin
  lv := FPanelConfig.ListView;
  if Chara = nil then begin
    FEditingChara := nil;
    FEditingCharaName := '';
    FPanelConfig.ShowConfig(nil); // 設定パネル内部のRTTI参照も含めて空状態に戻す
    lv.Clear;
    Exit;
  end;
  FEditingChara := Chara;
  FEditingCharaName := Chara.Name; // 棒読みちゃん対応: Name変更前の値を保持してセリフ一覧更新に使う
  lv.RTTINames['Name'].AddCaption('名称','配役の名称としてわかりやすくする',clSkyBlue);
  lv.RTTINames['Keyword'].AddCaption('キーワード','受け取るときの検索ワード',clSkyBlue);
  lv.RTTINames['Emotion'].AddCaption('感情','受け取るときの感情ワード（未使用）',clSkyBlue);
  lv.RTTINames['LayerSerif'].AddCaption('セリフレイヤー','セリフテキストの送信先レイヤー',clMoneyGreen,ListViewEditPluginComboBoxObjectId);
  lv.RTTINames['LayerWave'].AddCaption('音声レイヤー','セリフ音声の送信先レイヤー',clMoneyGreen,ListViewEditPluginComboBoxObjectId);
  lv.RTTINames['Volume'].AddCaption('音量','セリフの音量',clMoneyGreen);
  lv.RTTINames['Pan'].AddCaption('位置','セリフの発生位置',clMoneyGreen);
  lv.RTTINames['ColorLight'].AddCaption('明るい色','イメージカラーのうち明るい色',clWebPink,ListViewEditPluginColorDialogId);
  lv.RTTINames['ColorBase'].AddCaption('基準色','イメージカラーの基本色',clWebPink,ListViewEditPluginColorDialogId);
  lv.RTTINames['ColorDark'].AddCaption('暗い色','イメージカラーの暗い色',clWebPink,ListViewEditPluginColorDialogId);
  lv.RTTINames['ColorFont'].AddCaption('文字色','このアプリでの表示色（未使用）',clWebPink,ListViewEditPluginColorDialogId);

  //FListView.RTTINames['LayerSerif'].EditType :=  ListViewEditPluginComboBoxObjectId;
  //FListView.RTTINames['LayerWave'].EditType :=  ListViewEditPluginComboBoxObjectId;
  SetLayer(lv.RTTINames['LayerSerif'].Strings);
  SetLayer(lv.RTTINames['LayerWave'].Strings);

  //FListView.RTTINames['ColorBack'].EditType :=  ListViewEditPluginColorDialogId;
  //FListView.RTTINames['ColorFont'].EditType :=  ListViewEditPluginColorDialogId;

  {
  clSkyBlue
  clMoneyGreen
  clWebPink
  }
  FPanelConfig.ShowConfig(Chara);
  lv.FixedWidth := 160;
end;

procedure TFrameSerifCharaList.DoChange;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TFrameSerifCharaList.ItemCopy;
var
  i : Integer;
  s : string;
  CharaFrom,CharaTo : TSerifCharaItem;
begin
  i := FListBox.ItemIndex;
  if i = -1 then Exit;
  CharaFrom := TSerifCharaItem(FListBox.Items.Objects[i]);
  if CharaFrom = nil then Exit;
  s := CharaFrom.Name;
  CharaTo := FCharas.InsertNew(i+1);
  CharaTo.Assign(CharaFrom);
  CharaTo.Name := CharaTo.Name + 'コピー';
  FListBox.Items.InsertObject(i+1,CharaTo.Name,CharaTo);

  DoChange();
  Inc(i);
  FListBox.ItemIndex := i;

  i := FListBox.ItemIndex;
  if i = -1 then Exit;

  ShowInfo(CharaTo);
  DoChange();
end;

procedure TFrameSerifCharaList.ItemDelete;
var
  i : Integer;
  Chara : TSerifCharaItem;
begin
  if FDialog.Execute('削除しますか？') <> mrOk then Exit;

  i := FListBox.ItemIndex;
  if i = -1 then Exit;
  Chara := TSerifCharaItem(FListBox.Items.Objects[i]);
  if Chara = nil then Exit;

  ShowInfo(nil); // 削除直前に設定パネルから削除対象への参照を外す
  FListBox.Items.Delete(i);
  FCharas.Delete(i);
  DoChange();
  Dec(i);
  FListBox.ItemIndex := i;

  i := FListBox.ItemIndex;
  if i = -1 then begin
    ShowInfo(nil);
    Exit;
  end;
  Chara := TSerifCharaItem(FListBox.Items.Objects[i]);
  if Chara = nil then Exit;

  ShowInfo(Chara);
  DoChange();
end;

procedure TFrameSerifCharaList.ItemDown;
var
  i : Integer;
begin
  i := FListBox.ItemIndex;
  if i = -1 then exit;
  if i+1 >= FListBox.Items.Count then exit;
  FCharas.Exchange(i,i+1);
  FListBox.Items.Exchange(i,i+1);
  FListBox.ItemIndex := i + 1;
  FListBox.TopIndex := FListBox.ItemIndex;        // カーソルが表示されるようにスクロール
  FCharas.SaveToFile();
end;

procedure TFrameSerifCharaList.ItemUp;
var
  i : Integer;
begin
  i := FListBox.ItemIndex;
  if i = -1 then exit;
  if i-1 < 0 then exit;
  FCharas.Exchange(i,i-1);
  FListBox.Items.Exchange(i,i-1);
  FListBox.ItemIndex := i - 1;
  FListBox.TopIndex := FListBox.ItemIndex;        // カーソルが表示されるようにスクロール
  FCharas.SaveToFile();
end;

procedure TFrameSerifCharaList.MenuCopyClick(Sender: TObject);
begin
  ItemCopy();
end;

procedure TFrameSerifCharaList.MenuDeleteClick(Sender: TObject);
begin
  ItemDelete();
end;

procedure TFrameSerifCharaList.MenuItemUpClick(Sender: TObject);
begin
  ItemUp;
end;

procedure TFrameSerifCharaList.MenuItemDownClick(Sender: TObject);
begin
  ItemDown;
end;

procedure TFrameSerifCharaList.MenuRefreshClick(Sender: TObject);
begin
  FListBox.Refresh;
end;

procedure TFrameSerifCharaList.OnListBoxClick(Sender: TObject);
var
  i : Integer;
  Chara : TSerifCharaItem;
begin
  i := FListBox.ItemIndex;
  if i = -1 then Exit;
  Chara := TSerifCharaItem(FListBox.Items.Objects[i]);
  if Chara = nil then Exit;

  ShowInfo(Chara);
end;


procedure TFrameSerifCharaList.OnListBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  FShortcuts.KeyDown(Key,Shift);
end;

procedure TFrameSerifCharaList.OnListViewChange(Sender: TObject);
begin
  CheckRenameChara;      // 棒読みちゃん対応: 配役Name変更を既存セリフへ反映する
  RefreshSelectedListItem; // 棒読みちゃん対応: Keyword/Name編集後に配役一覧の表示も更新する
  FCharas.SaveToFile;
  DoChange();
end;

procedure TFrameSerifCharaList.CheckRenameChara;
var
  OldName, NewName: string;
begin
  if FEditingChara = nil then Exit;

  OldName := Trim(FEditingCharaName);
  NewName := Trim(FEditingChara.Name);
  if SameText(OldName, NewName) then Exit;

  // 棒読みちゃん対応: Keywordに紐づく表示名(Name)が変わった時、親へKeywordと新名を通知する。
  if Assigned(FOnRenameChara) and (OldName <> '') and (NewName <> '') then
    FOnRenameChara(Self, OldName, FEditingChara.Keyword, NewName);

  FEditingCharaName := FEditingChara.Name;
end;

procedure TFrameSerifCharaList.RefreshSelectedListItem;
var
  i: Integer;
  Chara: TSerifCharaItem;
begin
  i := FListBox.ItemIndex;
  if i = -1 then Exit;
  if i >= FListBox.Items.Count then Exit;

  Chara := TSerifCharaItem(FListBox.Items.Objects[i]);
  if Chara = nil then Exit;

  // 棒読みちゃん対応: Nameを編集した時、取り込み表示名に使う配役名を一覧にも反映する。
  FListBox.Items[i] := Chara.Name;
  FListBox.Refresh; // 色や名称の変更をOwnerDrawへ即時反映する
end;

{ TListBoxCharaColor }
procedure TListBoxCharaColor.DrawItem(Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  S: string;
  Item: TSerifCharaItem;
  cv: TCanvas;
  bg: TColor;
begin
  if Index < 0 then Exit;

  Item := TSerifCharaItem(Items.Objects[Index]);
  cv   := Canvas;
  S    := Item.Name;

  bg := Item.ColorBack;

  // マウスオーバー
  if odHotLight in State then
    bg := A2SCListBoxHot;

  // 選択時の背景
  if odSelected in State then
    bg :=  A2SCListBoxSelection;

  // 背景描画
  cv.Brush.Color := bg;
  cv.FillRect(Rect);

  // 文字色
  if odSelected in State then
    cv.Font.Color := clHighlightText
  else
    cv.Font.Color := GetIdealFontColor(bg);

  // テキスト
  cv.TextOut(Rect.Left + 24, Rect.Top + 2, S);

  // ---- ここから枠描画 ----
  if odSelected in State then
  begin
    cv.Brush.Style := bsClear;

    // 左に “●” を描く
    cv.Font.Color := clWhite;
    cv.TextOut(Rect.Left + 2, Rect.Top + 2, '●');

    // 外枠
    cv.Pen.Color := clWhite;
    cv.Pen.Width := 2;
    cv.Rectangle(Rect);

    // 内枠
    InflateRect(Rect, -2, -2);
    cv.Pen.Color := clBlack;
    cv.Pen.Width := 1;
    cv.Rectangle(Rect);
  end;

  // フォーカス枠の標準処理
  if odFocused in State then
  begin
    cv.Brush.Style := bsClear;
    cv.DrawFocusRect(Rect);
  end;
end;



function TListBoxCharaColor.GetIdealFontColor(BackColor: TColor): TColor;
var
  R, G, B: Byte;
  Y: Double;
begin
  BackColor := ColorToRGB(BackColor);
  R := GetRValue(BackColor);
  G := GetGValue(BackColor);
  B := GetBValue(BackColor);

  // 輝度計算（W3C 推奨式）
  Y := R * 0.299 + G * 0.587 + B * 0.114;
  if Y < 186 then  Result := clWhite else Result := clBlack;
end;

end.

