unit ToolbarCaptionSubs;

interface

uses
   Winapi.Windows,System.Classes,  System.SysUtils,  System.Generics.Collections, Vcl.Controls,
   Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics,Vcl.ImgList,Vcl.Menus,Winapi.Messages,ToolbarIcon,NonActiveForm;

type
  // サブアイテムがクリックされた際に通知されるイベント
  TToolbarCaptionSubClickEvent = procedure(Sender: TObject;ATag: Integer) of object;

  //======================================================================
  // サブ用：アイコン（左）＋キャプション（右）＋ Checked
  //======================================================================
  // サブメニューに表示されるキャプション付き項目
  TToolbarCaptionSubItem = class(TPanel)
  private
    FIcon: TToolbarIconItem;           // 左側に表示するアイコン
    FCaptionPanel: TPanel;             // 右側に表示するキャプションパネル

    FCaption: string;                  // 表示用キャプション文字列
    FTagValue: Integer;                // 識別用タグ値
    FChecked: Boolean;                 // チェック状態
    FIsHover: Boolean;                 // ホバー状態フラグ

    FOnItemClick: TToolbarCaptionSubClickEvent; // クリック通知イベント

    // 現在の内容から必要な横幅を計算する
    function CalcRequiredWidth: Integer;
    // アイコンがクリックされた際の処理
    procedure IconClick(Sender: TObject; ATag: Integer);
    // キャプションがクリックされた際の処理
    procedure CaptionClick(Sender: TObject);
    // キャプション文字列を設定する
    procedure SetCaption(const Value: string);
    // チェック状態を設定する
    procedure SetChecked(const Value: Boolean);
    // マウスが項目内に入ったことを検出する
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    // マウスが項目外に出たことを検出する
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    // ホバーやチェック状態に応じて見た目を更新する
    procedure UpdateVisualState;
    // チェック状態に応じてキャプション表示を更新する
    procedure UpdateVisualCaption;
    // サイズ変更時の再配置処理
    procedure Resize; override;
    procedure DoItemClick(ATag: Integer);
  public
    // サブメニュー用アイテムを生成する
    constructor Create(AOwner: TComponent); override;
    // アイコン・キャプション・サイズ情報を設定する
    procedure Setup(
      AImages: TCustomImageList;
      AImageIndex: Integer;
      const ACaption: string;
      ATag: Integer;
      AHeight: Integer
    );
    property CaptionText: string read FCaption write SetCaption; // 表示キャプション文字列
    property TagValue: Integer read FTagValue write FTagValue;   // 識別用タグ値
    property Checked: Boolean read FChecked write SetChecked;    // チェック状態
    property Icon: TToolbarIconItem read FIcon;                 // 内部アイコンオブジェクト
    property CaptionPanel: TPanel read FCaptionPanel;           // 内部キャプションパネル
    // クリック通知イベント
    property OnItemClick: TToolbarCaptionSubClickEvent  read FOnItemClick write FOnItemClick;
  end;

  //======================================================================
  // リスト管理
  //======================================================================
  // サブメニュー項目の所有リスト
  TToolbarCaptionSubItemList = class(TObjectList<TToolbarCaptionSubItem>)
  end;

  //======================================================================
  // サブツールバー本体（縦方向）
  //======================================================================
  // キャプション付きサブメニューを縦方向に表示する非アクティブフォーム
  TToolbarCaptionSubs = class(TFormNonActive)
  private
    FPanel : TPanel;                   // アイテム配置用内部パネル
    FItems: TToolbarCaptionSubItemList;// 管理しているサブアイテム一覧
    FImages: TCustomImageList;         // アイコン描画用イメージリスト

    FItemHeight: Integer;              // 各アイテムの高さ
    FOnButtonClick: TToolbarCaptionSubClickEvent; // ボタン押下通知イベント
    FOnHoverChanged: TToolbarIconHoverEvent;      // ホバー状態変化通知イベント
    FIsHover: Boolean;
    FOnMenuHide: TNotifyEvent;                 // フォーム全体のホバー状態

    // 全アイテムの配置を再計算する
    procedure UpdateLayout;
    // 内部アイテムクリックを外部イベントに中継する
    procedure InternalItemClick(Sender: TObject; ATag: Integer);
    // イメージリストを設定する
    procedure SetImages(const Value: TCustomImageList);
    // マウスがサブメニュー内に入ったことを検出する
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    // マウスがサブメニュー外に出たことを検出する
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    // 自身または配下アイテムがホバー状態かを取得する
    function GetIsHover: Boolean;
  protected
    // サイズ変更時に全体レイアウトを更新する
    procedure Resize; override;
    // ホバー状態変化を外部へ通知する
    procedure DoHoverChanged(IsHover: Boolean); virtual;
    // ポップアップメニュー非表示通知
    procedure DoMenuHide();virtual;
  public
    // サブメニュー用フォームを生成する
    constructor Create(AOwner: TComponent); override;
    // サブメニュー用フォームを破棄する
    destructor Destroy; override;
    // キャプション付きサブアイテムを追加する
    function AddCaption(AImageIndex: Integer;const ACaption: string;AChecked: Boolean = False): TToolbarCaptionSubItem;
    // 外部からレイアウト再計算を要求する
    procedure Relayout;
    property IsHover : Boolean read GetIsHover; // ホバー状態判定
     // ホバー変化通知
    property OnHoverChanged: TToolbarIconHoverEvent read FOnHoverChanged write FOnHoverChanged;
     // メインのポップアップを非表示通知
    property OnMenuHide: TNotifyEvent read FOnMenuHide write FOnMenuHide;
  published
    property SubMenus : TToolbarCaptionSubItemList read FItems;
    property Images: TCustomImageList read FImages write SetImages; // 使用するイメージリスト
    property ItemHeight: Integer read FItemHeight write FItemHeight default 24; // アイテム高さ
    // ボタン押下通知イベント
    property OnButtonClick: TToolbarCaptionSubClickEvent read FOnButtonClick write FOnButtonClick;
    property Visible;
    property Enabled;
    property Color;
  end;


implementation

uses Math;

{==============================================================================}
{ TToolbarCaptionSubs                                                           }
{==============================================================================}

// サブメニュー用フォームを初期化する
constructor TToolbarCaptionSubs.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  ParentBackground := False;

  FItemHeight := 24;
  FItems := TToolbarCaptionSubItemList.Create(True);

  FPanel := TPanel.Create(Self);
  FPanel.Parent := Self;
  FPanel.Align := alClient;
  FPanel.BevelWidth := 1;
  FPanel.BevelOuter := bvRaised;
end;

// サブメニュー用フォームを破棄する
destructor TToolbarCaptionSubs.Destroy;
begin
  FItems.Free;
  FPanel.Free;
  inherited;
end;

// ホバー状態変化を外部へ通知する
procedure TToolbarCaptionSubs.DoHoverChanged(IsHover: Boolean);
begin
  if Assigned(FOnHoverChanged) then FOnHoverChanged(Self, IsHover);
end;

procedure TToolbarCaptionSubs.DoMenuHide;
begin
  if Assigned(FOnMenuHide) then FOnMenuHide(Self);
end;

// 自身または配下アイテムがホバー状態かを判定する
function TToolbarCaptionSubs.GetIsHover: Boolean;
var
  i : Integer;
begin
  if FIsHover then Exit(True);

  for i := 0 to FItems.Count-1 do begin
    if FItems[i].FIsHover then Exit(True);
  end;
  Result := False;
end;

// 使用するイメージリストを設定する
procedure TToolbarCaptionSubs.SetImages(const Value: TCustomImageList);
begin
  FImages := Value;
end;

// キャプション付きサブアイテムを追加する
function TToolbarCaptionSubs.AddCaption(
  AImageIndex: Integer;
  const ACaption: string;
  AChecked: Boolean
): TToolbarCaptionSubItem;
var
  Item: TToolbarCaptionSubItem;
begin
  Item := TToolbarCaptionSubItem.Create(Self);
  Item.Parent := FPanel;
  Item.Checked := AChecked;
  Item.OnItemClick := InternalItemClick;

  Item.Setup(
    FImages,
    AImageIndex,
    ACaption,
    FItems.Count,
    FItemHeight
  );

  FItems.Add(Item);
  UpdateLayout;

  Result := Item;
end;

// 全サブアイテムの配置を再計算する
procedure TToolbarCaptionSubs.UpdateLayout;
var
  X, Y : Integer;
  Item : TToolbarCaptionSubItem;
begin
  X := 0;
  for Item in FItems do
    X := Max(X, Item.CalcRequiredWidth);

  Y := 2;
  for Item in FItems do
  begin
    Item.SetBounds(2, Y, X, Item.Height);
    Inc(Y, Item.Height);
  end;

  Width  := X + 8;
  Height := Y + 5;
end;

// 外部からレイアウト再計算を行う
procedure TToolbarCaptionSubs.Relayout;
begin
  UpdateLayout;
end;

// 内部アイテムクリックを外部イベントに通知する
procedure TToolbarCaptionSubs.InternalItemClick(Sender: TObject;ATag: Integer);
begin
  Hide;
  DoMenuHide();
  if Assigned(FOnButtonClick) then FOnButtonClick(Self, ATag);
end;

// サイズ変更時に全体レイアウトを更新する
procedure TToolbarCaptionSubs.Resize;
begin
  inherited;
  UpdateLayout;
end;

{==============================================================================}
{ TToolbarCaptionSubItem                                                        }
{==============================================================================}

// サブメニュー用アイテムを初期化する
constructor TToolbarCaptionSubItem.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  BevelOuter := bvNone;
  ParentBackground := False;
  ParentColor := True;

  Height := 24;

  FIcon := TToolbarIconItem.Create(Self);
  FIcon.Parent := Self;
  FIcon.IsHoverEnabled := True;
  FIcon.OnClickEx := IconClick;

  FCaptionPanel := TPanel.Create(Self);
  FCaptionPanel.Parent := Self;
  FCaptionPanel.BevelOuter := bvNone;
  FCaptionPanel.ParentBackground := False;
  FCaptionPanel.ParentColor := True;
  FCaptionPanel.Caption := '';
  FCaptionPanel.Alignment := taLeftJustify;
  FCaptionPanel.OnClick := CaptionClick;

  FChecked := False;
end;

procedure TToolbarCaptionSubItem.DoItemClick(ATag: Integer);
begin
  if Assigned(FOnItemClick) then FOnItemClick(Self, FTagValue);
end;

// サブメニュー用アイテムの内容を設定する
procedure TToolbarCaptionSubItem.Setup(
  AImages: TCustomImageList;
  AImageIndex: Integer;
  const ACaption: string;
  ATag: Integer;
  AHeight: Integer
);
begin
  FCaption := ACaption;
  FTagValue := ATag;
  Height := AHeight;

  FIcon.Images := AImages;
  FIcon.SetIcon(AImageIndex, AHeight, AHeight);

  UpdateVisualCaption;
  UpdateVisualState;
end;

// サイズ変更時にアイコンとキャプションを再配置する
procedure TToolbarCaptionSubItem.Resize;
var
  CC    : TControlCanvas;
  TextW : Integer;
  Pad   : Integer;
begin
  inherited;

  Pad := 8;

  FIcon.SetBounds(0, 0, Height, Height);

  CC := TControlCanvas.Create;
  try
    CC.Control := FCaptionPanel;
    CC.Font.Assign(FCaptionPanel.Font);

    TextW := CC.TextWidth(FCaptionPanel.Caption);
  finally
    CC.Free;
  end;

  FCaptionPanel.SetBounds(
    Height + 4,
    0,
    TextW + Pad,
    Height
  );
end;

// チェック状態に応じてキャプション表示を更新する
procedure TToolbarCaptionSubItem.UpdateVisualCaption;
begin
  if FChecked then begin
    FCaptionPanel.Caption := '● ' + FCaption;
  end
  else begin
    FCaptionPanel.Caption := '　 ' +FCaption;
  end;
end;

// ホバー状態に応じて背景色を更新する
procedure TToolbarCaptionSubItem.UpdateVisualState;
begin
  if FIsHover then
    Color := $00FFC0C0
  else
    Color := clBtnFace;
end;

// キャプション文字列を設定する
procedure TToolbarCaptionSubItem.SetCaption(const Value: string);
begin
  FCaption := Value;
  UpdateVisualCaption();
end;

// チェック状態を設定する
procedure TToolbarCaptionSubItem.SetChecked(const Value: Boolean);
begin
  if FChecked <> Value then
  begin
    FChecked := Value;
    UpdateVisualCaption;
  end;
end;

// マウスが項目内に入った際の処理
procedure TToolbarCaptionSubItem.CMMouseEnter(var Message: TMessage);
begin
  FIsHover := True;
  FIcon.IsHover := True;
  UpdateVisualState();
end;

// マウスが項目外に出た際の処理
procedure TToolbarCaptionSubItem.CMMouseLeave(var Message: TMessage);
begin
  FIsHover := False;
  FIcon.IsHover := False;
  UpdateVisualState();
end;

// アイコンがクリックされた際に通知する
procedure TToolbarCaptionSubItem.IconClick(Sender: TObject; ATag: Integer);
begin
  DoItemClick(FTagValue)
end;

// 現在の内容から必要な横幅を算出する
function TToolbarCaptionSubItem.CalcRequiredWidth: Integer;
var
  CC: TControlCanvas;
begin
  CC := TControlCanvas.Create;
  try
    CC.Control := FCaptionPanel;
    CC.Font.Assign(FCaptionPanel.Font);
    Result := Height + 4 + CC.TextWidth(FCaptionPanel.Caption) + 8;
  finally
    CC.Free;
  end;
end;

// キャプションがクリックされた際に通知する
procedure TToolbarCaptionSubItem.CaptionClick(Sender: TObject);
begin
  DoItemClick(FTagValue);
end;

// マウスがサブメニュー内に入った際の処理
procedure TToolbarCaptionSubs.CMMouseEnter(var Message: TMessage);
begin
  FIsHover := True;
  if not FIsHover then
  begin
    FIsHover := True;
    DoHoverChanged(True);
  end;
  inherited;
end;

// マウスがサブメニュー外に出た際の処理
procedure TToolbarCaptionSubs.CMMouseLeave(var Message: TMessage);
begin
  FIsHover := False;
  if FIsHover then
  begin
    FIsHover := False;
    DoHoverChanged(False);
  end;
end;

end.

