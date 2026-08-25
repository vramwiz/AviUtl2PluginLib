unit ToolbarCaptions;

interface

uses
  Winapi.Windows,  System.Classes,System.SysUtils,System.Generics.Collections,Winapi.Messages,Math,
  Vcl.Controls,Vcl.ExtCtrls,Vcl.Graphics,Vcl.ImgList,Vcl.Menus,System.Types,
  ToolbarIcon,  ToolbarCaptionSubs;

type
  // キャプションアイテムがクリックされた際に通知されるイベント
  TToolbarCaptionClickEvent = procedure(Sender: TObject; ATag: Integer) of object;

  //======================================================================
  // アイコン + キャプションの1ボタン
  //======================================================================
  // ツールバー上に配置されるキャプション付きボタン
  TToolbarCaptionItem = class(TPanel)
  private
    FIcon: TToolbarIconItem;          // アイコン表示用コンポーネント
    FCaptionPanel: TPanel;            // キャプション表示用パネル

    FCaption: string;                 // 表示用キャプション文字列
    FTagValue: Integer;               // 識別用タグ値
    FTimer : TTimer;                  // サブメニュー非表示判定用タイマー

    FOnItemClick: TToolbarCaptionClickEvent; // クリック時通知イベント
    FSubMenus: TToolbarCaptionSubs;   // ホバー時に表示するサブメニュー
    FIsHover: Boolean;                // 自身がホバー状態かどうか
    FIsSeparator: Boolean;
    FOnSubMenuHide: TToolbarCaptionClickEvent;
    FNormalColor: TColor;
    FHoverColor: TColor;
    FNormalFontColor: TColor;
    FHoverFontColor: TColor;
    FSeparatorColor: TColor;

    // ホバーやチェック状態に応じて見た目を更新する
    procedure UpdateVisualState;
    // サブメニューの表示非表示状態を切り替える
    procedure UpdateSubMenu;
    // サブメニューの非表示判定を行うタイマー処理
    procedure OnTimer(Sender: TObject);
    // キャプション部分がクリックされた際の処理
    procedure CaptionClick(Sender: TObject);
    // アイコンのホバー状態変化を受け取る
    procedure HoverChanged(Sender: TObject;IsHover: Boolean);
    // アイコンがクリックされた際の処理
    procedure IconClick(Sender: TObject; ATag: Integer);
    // キャプション文字列を設定する
    procedure SetCaption(const Value: string);
    // ホバー時ポップアップメニューを取得する
    function GetHoverPopup: TPopupMenu;
    // ホバー時ポップアップメニューを設定する
    procedure SetHoverPopup(const Value: TPopupMenu);
    // 自身またはサブメニューがホバー状態かを取得する
    function GetIsHover: Boolean;
    // マウスが項目内に入ったことを検出する
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    // マウスが項目外に出たことを検出する
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    function GetSubMenus(Index: Integer): TToolbarCaptionSubItem;
    procedure SetImages(const Value: TCustomImageList);
    function GetOnButtonClick: TToolbarCaptionClickEvent;
    procedure SetOnButtonClick(const Value: TToolbarCaptionClickEvent);
    function GetOnMenuHide: TNotifyEvent;
    procedure SetOnMenuHide(const Value: TNotifyEvent);
    procedure SetNormalColor(const Value: TColor);
    procedure SetHoverColor(const Value: TColor);
    procedure SetNormalFontColor(const Value: TColor);
    procedure SetHoverFontColor(const Value: TColor);
    procedure SetSeparatorColor(const Value: TColor);
  protected
    // サイズ変更時の再配置処理
    procedure Resize; override;
    procedure DoSubMenuHide(ATag: Integer);
  public
    // キャプション付きボタンを生成する
    constructor Create(AOwner: TComponent); override;
    // キャプション付きボタンを破棄する
    destructor Destroy; override;
    // アイコン・キャプション・サイズをまとめて設定する
    procedure Setup(AImages: TCustomImageList;AImageIndex: Integer;const ACaption: string;ATag: Integer;AIconHeight: Integer;ACaptionHeight: Integer);
    procedure ApplyColors;
    // キャプション付きサブアイテムを追加する
    function AddCaption(const ACaption: string;AImageIndex: Integer=-1; AChecked: Boolean = False): TToolbarCaptionSubItem;

    // 表示中のサブメニューを非表示にする
    procedure HideSubmenu;
    property Images: TCustomImageList  write SetImages; // 使用するイメージリスト
    property CaptionText: string read FCaption write SetCaption; // 表示キャプション文字列
    property TagValue: Integer read FTagValue write FTagValue;   // 識別用タグ値
    property Icon: TToolbarIconItem read FIcon;                  // 内部アイコンオブジェクト
    property CaptionPanel: TPanel read FCaptionPanel;            // 内部キャプションパネル
    property HoverPopup: TPopupMenu read GetHoverPopup write SetHoverPopup; // ホバー時のポップアップメニュー
    property IsHover : Boolean read GetIsHover;                  // ホバー状態判定
    property SubMenus[Index : Integer] : TToolbarCaptionSubItem read GetSubMenus;     // サブメニュー管理オブジェクト
    property OnItemClick: TToolbarCaptionClickEvent read FOnItemClick write FOnItemClick; // クリック通知イベント
    property OnSubMenuHide : TToolbarCaptionClickEvent read FOnSubMenuHide write FOnSubMenuHide; // 他のメニューのサブメニューを非表示
    property OnButtonClick: TToolbarCaptionClickEvent read GetOnButtonClick write SetOnButtonClick; // ボタン押下通知イベント
    property OnMenuHide: TNotifyEvent read GetOnMenuHide write SetOnMenuHide; // メインのポップアップを非表示通知イベント
    property NormalColor: TColor read FNormalColor write SetNormalColor;
    property HoverColor: TColor read FHoverColor write SetHoverColor;
    property NormalFontColor: TColor read FNormalFontColor write SetNormalFontColor;
    property HoverFontColor: TColor read FHoverFontColor write SetHoverFontColor;
    property SeparatorColor: TColor read FSeparatorColor write SetSeparatorColor;
  end;

  //======================================================================
  // リスト管理
  //======================================================================
  // キャプション付きボタンの所有リスト
  TToolbarCaptionItemList = class(TObjectList<TToolbarCaptionItem>)
  end;

  //======================================================================
  // ツールバー本体（キャプションあり）
  //======================================================================
  // キャプション付きボタンを横並びに管理・表示するツールバー
  TToolbarCaptions = class(TPanel)
  private
    FItems: TToolbarCaptionItemList;  // 管理しているキャプションアイテム一覧
    FImages: TCustomImageList;        // アイコン描画用イメージリスト
    FTagCount  : Integer;             // タグカウント値
    FNormalColor: TColor;             // 通常時背景色
    FHoverColor: TColor;              // ホバー時背景色
    FNormalFontColor: TColor;         // 通常時文字色
    FHoverFontColor: TColor;          // ホバー時文字色
    FSeparatorColor: TColor;          // セパレーター色
    FCaptionPadding: Integer;         // キャプション上下余白
    FOnButtonClick: TToolbarCaptionClickEvent;
    FOnMenuHide: TNotifyEvent; // ボタン押下通知イベント
    // 全アイテムの配置を再計算する
    procedure UpdateLayout;
    // イメージリストを設定する
    procedure SetImages(const Value: TCustomImageList);
    procedure SetNormalColor(const Value: TColor);
    procedure SetHoverColor(const Value: TColor);
    procedure SetNormalFontColor(const Value: TColor);
    procedure SetHoverFontColor(const Value: TColor);
    procedure SetSeparatorColor(const Value: TColor);
    // 内部アイテムクリックを外部イベントに中継する
    procedure InternalItemClick(Sender: TObject; ATag: Integer);
    // サブメニュー非表示イベント
    procedure OnSubMenuHide(Sender: TObject; ATag: Integer);
    // ツールバー全体がホバー状態かを取得する
    function GetIsHover: Boolean;
  protected
    // サイズ変更時に全体レイアウトを更新する
    procedure Resize; override;
  public
    // キャプション付きツールバーを生成する
    constructor Create(AOwner: TComponent); override;
    // キャプション付きツールバーを破棄する
    destructor Destroy; override;
    // キャプション付きアイコンボタンを追加する
    function AddCaption(const ACaption: string;AImageIndex: Integer=-1;AHint : string=''): TToolbarCaptionItem;
    // 追加（セパレーター）
    function AddSeparator: TToolbarCaptionItem;
    //
    procedure Clear();
    // 横幅計算
    function GetRequiredWidth: Integer;
    // カーソルがツールバー範囲内にあるかを取得する
    property IsHover : Boolean read GetIsHover;
    // 外部からレイアウト再計算を要求する
    procedure Relayout;
    // 全アイテムのサブメニューを非表示にする
    procedure HideSubMenu;
  published
    property Images: TCustomImageList read FImages write SetImages; // 使用するイメージリスト
    property NormalColor: TColor read FNormalColor write SetNormalColor default clBtnFace; // 通常背景色
    property HoverColor: TColor read FHoverColor write SetHoverColor default $00FFC0C0;     // ホバー背景色
    property NormalFontColor: TColor read FNormalFontColor write SetNormalFontColor default clWindowText; // 通常文字色
    property HoverFontColor: TColor read FHoverFontColor write SetHoverFontColor default clBlack; // ホバー文字色
    property SeparatorColor: TColor read FSeparatorColor write SetSeparatorColor default clBtnFace; // セパレーター色
    property CaptionPadding: Integer read FCaptionPadding write FCaptionPadding default 4; // キャプション余白
    property OnButtonClick: TToolbarCaptionClickEvent read FOnButtonClick write FOnButtonClick; // ボタン押下通知イベント
    property OnMenuHide: TNotifyEvent read FOnMenuHide write FOnMenuHide; // メインのポップアップを非表示通知イベント
  end;

implementation

// マウスがアイテム領域に入ったことを検出する
procedure TToolbarCaptionItem.CMMouseEnter(var Message: TMessage);
begin
  FIsHover := True;
  UpdateVisualState;
  UpdateSubMenu;
end;

// マウスがアイテム領域から出たことを検出する
procedure TToolbarCaptionItem.CMMouseLeave(var Message: TMessage);
begin
  FIsHover := False;
  UpdateVisualState;
  UpdateSubMenu;
end;

{==============================================================================}
{ TToolbarCaptionItem                                                           }
{==============================================================================}

// キャプション付きボタンを初期化する
constructor TToolbarCaptionItem.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  BevelOuter := bvNone;
  ParentBackground := False;
  ParentColor := True;

  FSubMenus := TToolbarCaptionSubs.Create(Self);

  // アイコン表示用コンポーネントを生成する
  FIcon := TToolbarIconItem.Create(Self);
  FIcon.Parent := Self;
  FIcon.IsHoverEnabled := True;
  FIcon.OnClickEx := IconClick;
  FIcon.OnHoverChanged := HoverChanged;

  // キャプション表示用パネルを生成する
  FCaptionPanel := TPanel.Create(Self);
  FCaptionPanel.Parent := Self;
  FCaptionPanel.BevelOuter := bvNone;
  FCaptionPanel.ParentBackground := False;
  FCaptionPanel.ParentColor := True;
  FCaptionPanel.Caption := '';
  FCaptionPanel.OnClick := CaptionClick;

  // サブメニュー監視用タイマーを生成する
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 1000;
  FTimer.OnTimer := OnTimer;

  FNormalColor := clBtnFace;
  FHoverColor := $00FFC0C0;
  FNormalFontColor := clWindowText;
  FHoverFontColor := clBlack;
  FSeparatorColor := clBtnFace;
end;

// キャプション付きボタンを破棄する
destructor TToolbarCaptionItem.Destroy;
begin
  FTimer.Free;
  FSubMenus.Free;
  inherited;
end;

procedure TToolbarCaptionItem.DoSubMenuHide(ATag: Integer);
begin
  if Assigned(FOnSubMenuHide) then FOnSubMenuHide(Self,ATag);
end;

procedure TToolbarCaptionItem.ApplyColors;
begin
  if FIsSeparator then
  begin
    ParentColor := False;
    Color := FSeparatorColor;
    Exit;
  end;

  ParentColor := False;
  FCaptionPanel.ParentColor := False;
  FIcon.NormalColor := FNormalColor;
  FIcon.HoverColor := FHoverColor;
  FIcon.DownColor := FHoverColor;
  UpdateVisualState;
end;

// アイコン・キャプション・サイズ情報をまとめて設定する
procedure TToolbarCaptionItem.Setup(
  AImages: TCustomImageList;
  AImageIndex: Integer;
  const ACaption: string;
  ATag: Integer;
  AIconHeight: Integer;
  ACaptionHeight: Integer);
var
  SepW: Integer;
begin
  FCaption := ACaption;
  FTagValue := ATag;

  // セパレーター判定
  FIsSeparator := (AImageIndex = -1);

  if FIsSeparator then
  begin
    // セパレーター（縦線 or 単なる空白）
    FIcon.Visible := False;
    FCaptionPanel.Visible := False;

    SepW := Max(4, AIconHeight div 8); // パネル高さの 1/8
    Width := SepW;
    Height := AIconHeight + ACaptionHeight;
    ApplyColors;

    Exit;
  end;

  // 通常アイテム
  FIcon.Images := AImages;
  FIcon.SetIcon(AImageIndex, AIconHeight, AIconHeight);
  FIcon.Visible := True;

  FCaptionPanel.Caption := ACaption;
  FCaptionPanel.Visible := True;

  // サイズ
  FIcon.SetBounds(0, 0, AIconHeight, AIconHeight);
  FCaptionPanel.SetBounds(0, AIconHeight, AIconHeight, ACaptionHeight);

  Width := AIconHeight;
  Height := AIconHeight + ACaptionHeight;
  Font.Height := -13;
  ApplyColors;

end;

procedure TToolbarCaptionItem.UpdateSubMenu;
var
  P: TPoint;
begin
  if FSubMenus = nil then Exit;
  if FSubMenus.SubMenus.Count=0 then Exit;

  if IsHover then
  begin
    // 自分以外のサブメニューを閉じる
    DoSubMenuHide(FTagValue);
    // サブメニュー表示位置を算出する
    P := Point(0, FIcon.Height+FCaptionPanel.Height);
    P := FIcon.ClientToScreen(P);

    // サブメニューはフォームに直接ぶら下げない
    FSubMenus.Parent := nil;

    // スクリーン座標で表示位置を設定する
    FSubMenus.Left := P.X - 0;
    FSubMenus.Top  := P.Y + 0;

    FTimer.Enabled := False;

    FSubMenus.BringToFront;
    // サブメニューを表示する
    FSubMenus.Show;
  end
  else
  begin
    FTimer.Enabled := True;
  end;
end;

procedure TToolbarCaptionItem.UpdateVisualState;
begin
  if (FIsHover) and (not FIsSeparator) then begin
    Color := FHoverColor;
    FCaptionPanel.Color := FHoverColor;
    Font.Color := FHoverFontColor;
    FCaptionPanel.Font.Color := FHoverFontColor;
    FIcon.IsHover := True;
  end
  else begin
    Color := FNormalColor;
    FCaptionPanel.Color := FNormalColor;
    Font.Color := FNormalFontColor;
    FCaptionPanel.Font.Color := FNormalFontColor;
    FIcon.IsHover := False;
  end;

end;

// サイズ変更時の処理を行う
procedure TToolbarCaptionItem.Resize;
begin
  inherited;
  // 高さ変化時は親（ツールバー）が再配置するのでここは固定
end;

function TToolbarCaptionItem.AddCaption(const ACaption: string;AImageIndex: Integer=-1; AChecked: Boolean=False): TToolbarCaptionSubItem;
begin
  Result := FSubMenus.AddCaption(AImageIndex,ACaption,AChecked);
end;

// キャプション部分がクリックされた際に通知する
procedure TToolbarCaptionItem.CaptionClick(Sender: TObject);
begin
  if Assigned(FOnItemClick) then
    FOnItemClick(Self, FTagValue);
end;

// アイコン部分がクリックされた際に通知する
procedure TToolbarCaptionItem.IconClick(Sender: TObject; ATag: Integer);
begin
  if Assigned(FOnItemClick) then
    FOnItemClick(Self, FTagValue);
end;

// サブメニューの非表示判定を行うタイマー処理
procedure TToolbarCaptionItem.OnTimer(Sender: TObject);
begin
  FTimer.Enabled := False;
  if FIsHover  then begin
    Exit;
  end;
  if FSubMenus = nil then begin
    Exit;
  end;

  if not FSubMenus.IsHover then begin
   FSubMenus.Hide;
   Exit;
  end;

  FTimer.Enabled := True;
end;

// キャプション文字列を設定する
procedure TToolbarCaptionItem.SetCaption(const Value: string);
begin
  FCaption := Value;
  FCaptionPanel.Caption := Value;
end;

// ホバー時に表示するポップアップメニューを取得する
function TToolbarCaptionItem.GetHoverPopup: TPopupMenu;
begin
  Result := FIcon.PopupMenu;
end;

// 自身またはサブメニューがホバー状態かを判定する
function TToolbarCaptionItem.GetIsHover: Boolean;
begin
  Result := false;
  if FIsHover then Exit(True);
  if FSubMenus = nil then Exit;
  Result := FSubMenus.IsHover;
end;

function TToolbarCaptionItem.GetOnButtonClick: TToolbarCaptionClickEvent;
begin
  Result := FSubMenus.OnButtonClick;
end;

function TToolbarCaptionItem.GetOnMenuHide: TNotifyEvent;
begin
  Result := FSubMenus.OnMenuHide;
end;

function TToolbarCaptionItem.GetSubMenus( Index: Integer): TToolbarCaptionSubItem;
begin
  Result := FSubMenus.SubMenus[Index];
end;

// サブメニューを非表示にする
procedure TToolbarCaptionItem.HideSubmenu;
begin
  if FSubMenus<>nil then FSubMenus.Hide;
end;

// アイコンのホバー状態変化に応じてサブメニューを制御する
procedure TToolbarCaptionItem.HoverChanged(Sender: TObject; IsHover: Boolean);
begin
  FIsHover := IsHover;
  UpdateVisualState;
  UpdateSubMenu;
end;

// ホバー時ポップアップメニューを設定する
procedure TToolbarCaptionItem.SetHoverPopup(const Value: TPopupMenu);
begin
  FIcon.PopupMenu := Value;
end;

procedure TToolbarCaptionItem.SetImages(const Value: TCustomImageList);
begin
  FSubMenus.Images := Value;
end;

procedure TToolbarCaptionItem.SetOnButtonClick(const Value: TToolbarCaptionClickEvent);
begin
  FSubMenus.OnButtonClick := Value;
end;

procedure TToolbarCaptionItem.SetOnMenuHide(const Value: TNotifyEvent);
begin
  FSubMenus.OnMenuHide := Value;
end;

procedure TToolbarCaptionItem.SetNormalColor(const Value: TColor);
begin
  FNormalColor := Value;
  ApplyColors;
end;

procedure TToolbarCaptionItem.SetHoverColor(const Value: TColor);
begin
  FHoverColor := Value;
  ApplyColors;
end;

procedure TToolbarCaptionItem.SetNormalFontColor(const Value: TColor);
begin
  FNormalFontColor := Value;
  ApplyColors;
end;

procedure TToolbarCaptionItem.SetHoverFontColor(const Value: TColor);
begin
  FHoverFontColor := Value;
  ApplyColors;
end;

procedure TToolbarCaptionItem.SetSeparatorColor(const Value: TColor);
begin
  FSeparatorColor := Value;
  ApplyColors;
end;

{==============================================================================}
{ TToolbarCaptions                                                              }
{==============================================================================}

// キャプション付きツールバーを初期化する
constructor TToolbarCaptions.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  BevelOuter := bvNone;
  ParentBackground := False;

  FNormalColor := clBtnFace;
  FHoverColor  := $00FFC0C0;
  FNormalFontColor := clWindowText;
  FHoverFontColor := clBlack;
  FSeparatorColor := clBtnFace;
  FCaptionPadding := 4;
  FTagCount := 0;
  Color := FNormalColor;
  Font.Color := FNormalFontColor;

  FItems := TToolbarCaptionItemList.Create(True);
end;

// キャプション付きツールバーを破棄する
destructor TToolbarCaptions.Destroy;
begin
  FItems.Free;
  inherited;
end;

// ツールバー全体がホバー状態かを判定する
function TToolbarCaptions.GetIsHover: Boolean;
var
  i : Integer;
begin
  for i := 0 to FItems.Count-1 do begin
    if FItems[i].IsHover then Exit(True);
  end;
  Result := False;
end;

function TToolbarCaptions.GetRequiredWidth: Integer;
var
  Item: TToolbarCaptionItem;
begin
  Result := 0;
  for Item in FItems do
    Inc(Result, Item.Width);
end;

// 全アイテムのサブメニューを非表示にする
procedure TToolbarCaptions.HideSubMenu;
var
  i : Integer;
  Item :TToolbarCaptionItem;
begin
  for i := 0 to FItems.Count-1 do begin
    Item := FItems[i];
    Item.HideSubmenu;
  end;
end;

// 使用するイメージリストを設定する
procedure TToolbarCaptions.SetImages(const Value: TCustomImageList);
begin
  FImages := Value;
end;

procedure TToolbarCaptions.SetNormalColor(const Value: TColor);
var
  Item: TToolbarCaptionItem;
begin
  FNormalColor := Value;
  Color := Value;
  for Item in FItems do
    Item.NormalColor := Value;
end;

procedure TToolbarCaptions.SetHoverColor(const Value: TColor);
var
  Item: TToolbarCaptionItem;
begin
  FHoverColor := Value;
  for Item in FItems do
    Item.HoverColor := Value;
end;

procedure TToolbarCaptions.SetNormalFontColor(const Value: TColor);
var
  Item: TToolbarCaptionItem;
begin
  FNormalFontColor := Value;
  Font.Color := Value;
  for Item in FItems do
    Item.NormalFontColor := Value;
end;

procedure TToolbarCaptions.SetHoverFontColor(const Value: TColor);
var
  Item: TToolbarCaptionItem;
begin
  FHoverFontColor := Value;
  for Item in FItems do
    Item.HoverFontColor := Value;
end;

procedure TToolbarCaptions.SetSeparatorColor(const Value: TColor);
var
  Item: TToolbarCaptionItem;
begin
  FSeparatorColor := Value;
  for Item in FItems do
    Item.SeparatorColor := Value;
end;

{------------------------------------------------------------------------------}
{ アイテム追加 }
{------------------------------------------------------------------------------}

// キャプション付きアイコンボタンを追加する
function TToolbarCaptions.AddCaption(const ACaption: string;AImageIndex: Integer=-1;AHint : string=''): TToolbarCaptionItem;
var
  TextH: Integer;
  IconH: Integer;
  Item: TToolbarCaptionItem;
  Bmp : TBitmap;
begin
  // キャプション高さを計測する
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(10, 10);
    Bmp.Canvas.Font.Assign(Self.Font);
    TextH := Bmp.Canvas.TextHeight(ACaption) + FCaptionPadding;
  finally
    Bmp.Free;
  end;

  // アイコン高さを算出する
  IconH := Self.Height - TextH - 2;
  if IconH < 8 then IconH := 8;

  // キャプションアイテムを生成する
  Item := TToolbarCaptionItem.Create(Self);
  Item.Parent := Self;
  Item.OnItemClick := InternalItemClick;
  Item.OnSubMenuHide := OnSubMenuHide;
  Item.OnMenuHide := OnMenuHide;
  Item.NormalColor := FNormalColor;
  Item.HoverColor := FHoverColor;
  Item.NormalFontColor := FNormalFontColor;
  Item.HoverFontColor := FHoverFontColor;
  Item.SeparatorColor := FSeparatorColor;
  Item.Hint := AHint;
  if AHint <> '' then Item.ShowHint := True;

  Item.Setup(
    FImages,
    AImageIndex,
    ACaption,
    FTagCount,
    IconH,
    TextH
  );

  Inc(FTagCount);
  FItems.Add(Item);

  UpdateLayout;

  Result := Item;
end;


{------------------------------------------------------------------------------}
{ セパレーター追加                                                              }
{------------------------------------------------------------------------------}
function TToolbarCaptions.AddSeparator: TToolbarCaptionItem;
begin
  Result := AddCaption('');
  Dec(FTagCount);
end;

procedure TToolbarCaptions.Clear;
begin
  FTagCount := 0;
  FItems.Clear;
  //FImages.Clear;
end;



{------------------------------------------------------------------------------}
{ レイアウト更新 }
{------------------------------------------------------------------------------}

// 全アイテムの配置を再計算する
procedure TToolbarCaptions.UpdateLayout;
var
  X: Integer;
  Item: TToolbarCaptionItem;
begin
  X := 0;

  for Item in FItems do
  begin
    Item.Left := X;
    Item.Top  := 0;

    Inc(X, Item.Width);
  end;
  Self.Width := x + 4;

  Invalidate;
end;

// 外部からレイアウト再計算を行う
procedure TToolbarCaptions.Relayout;
begin
  UpdateLayout;
end;

// 内部アイテムクリックを外部イベントに通知する
procedure TToolbarCaptions.InternalItemClick(Sender: TObject; ATag: Integer);
begin
  if Assigned(FOnButtonClick) then
    FOnButtonClick(Self, ATag);
end;

procedure TToolbarCaptions.OnSubMenuHide(Sender: TObject; ATag: Integer);
var
  Item: TToolbarCaptionItem;
begin
  for Item in FItems do begin
    if Item.FTagValue <> ATag then Item.HideSubmenu;
  end;
end;

{------------------------------------------------------------------------------}
{ Resize → 全体再配置 }
{------------------------------------------------------------------------------}

// サイズ変更時に全体レイアウトを再計算する
procedure TToolbarCaptions.Resize;
begin
  inherited;
  UpdateLayout;
end;

end.
