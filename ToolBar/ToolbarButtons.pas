unit ToolbarButtons;

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.ImgList,
  Vcl.Graphics,
  ToolbarIcon;  // TToolbarIconItem / TToolbarIconList

type
  // ボタンクリックイベント（Tag を返す）
  TToolbarButtonClickEvent = procedure(Sender: TObject; ATag: Integer) of object;

  //======================================================================
  // ツールバー（キャプションなし）
  //======================================================================
  TToolbarButtons = class(TCustomPanel)
  private
    // 内部アイコン管理
    FItems: TToolbarIconList;

    // 共有設定
    FImages: TCustomImageList;
    FNormalColor: TColor;
    FHoverColor: TColor;
    FDownColor: TColor;

    // 外部イベント
    FOnButtonClick: TToolbarButtonClickEvent;

    // 内部 → 外部 のイベント変換
    procedure IconClickInternal(Sender: TObject; ATag: Integer);

    // レイアウト更新
    procedure UpdateLayout;

    // セッター
    procedure SetImages(const Value: TCustomImageList);
    procedure SetNormalColor(const Value: TColor);
    procedure SetHoverColor(const Value: TColor);
    procedure SetDownColor(const Value: TColor);

  protected
    procedure Resize; override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // 要素追加（サイズ指定なし）
    function AddIcon(const HintText: string; AImageIndex: Integer; AProc: TProc; ATag: Integer = 0): TToolbarIconItem;
    function AddSeparator: TToolbarIconItem;

    // レイアウト強制更新
    procedure Relayout;

    property Items: TToolbarIconList read FItems;

  published
    property Images: TCustomImageList read FImages write SetImages;
    property NormalColor: TColor read FNormalColor write SetNormalColor ;
    property HoverColor: TColor read FHoverColor write SetHoverColor;
    property DownColor: TColor read FDownColor write SetDownColor;

    property OnButtonClick: TToolbarButtonClickEvent read FOnButtonClick write FOnButtonClick;

    // パネルの公開プロパティ
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
    property Color;
    property ShowHint;
    property ParentColor;
    property ParentBackground;
    property PopupMenu;
  end;

implementation

{==============================================================================}
{  TToolbarButtons                                                              }
{==============================================================================}
constructor TToolbarButtons.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  BevelOuter := bvNone;
  ParentBackground := False;

  Color := clBtnFace;
  FNormalColor := clBtnFace;
  FHoverColor  := clSilver;
  FDownColor := clHighlight;

  FItems := TToolbarIconList.Create;
  FItems.Images      := nil;
  FItems.NormalColor := FNormalColor;
  FItems.HoverColor  := FHoverColor;
  FItems.DownColor   := FDownColor;

  FItems.OnClickEx := IconClickInternal;
end;

destructor TToolbarButtons.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TToolbarButtons.SetImages(const Value: TCustomImageList);
begin
  FImages := Value;
  FItems.Images := FImages;
end;

procedure TToolbarButtons.SetNormalColor(const Value: TColor);
begin
  FNormalColor := Value;
  Color := Value;
  FItems.NormalColor := Value;
end;

procedure TToolbarButtons.SetHoverColor(const Value: TColor);
begin
  FHoverColor := Value;
  FItems.HoverColor := Value;
end;

procedure TToolbarButtons.SetDownColor(const Value: TColor);
begin
  FDownColor := Value;
  FItems.DownColor := Value;
end;

{------------------------------------------------------------------------------}
{ アイコン追加：サイズの指定は行わない }
{------------------------------------------------------------------------------}
function TToolbarButtons.AddIcon(const HintText: string; AImageIndex: Integer; AProc: TProc; ATag: Integer): TToolbarIconItem;
var
  H: Integer;
begin
  H := Height;

  Result := FItems.AddIcon(Self, AImageIndex, H, H, ATag);
  Result.Proc := AProc;
  Result.Hint := HintText;
  Result.ShowHint := HintText <> '';

  UpdateLayout;
end;

{------------------------------------------------------------------------------}
{ セパレーター追加：サイズ指定なし → 高さの 1/8 幅 }
{------------------------------------------------------------------------------}
function TToolbarButtons.AddSeparator: TToolbarIconItem;
var
  H: Integer;
  W: Integer;
begin
  H := Height;
  W := H div 8;

  Result := FItems.AddSeparator(Self, W, H);

  UpdateLayout;
end;

{------------------------------------------------------------------------------}
{ 内部クリックイベント → 外部へ転送 }
{------------------------------------------------------------------------------}
procedure TToolbarButtons.IconClickInternal(Sender: TObject; ATag: Integer);
begin
  if (Sender is TToolbarIconItem) and Assigned(TToolbarIconItem(Sender).Proc) then TToolbarIconItem(Sender).Proc();

  if Assigned(FOnButtonClick) then FOnButtonClick(Self, ATag);
end;

{------------------------------------------------------------------------------}
{ レイアウト再計算 }
{------------------------------------------------------------------------------}
procedure TToolbarButtons.UpdateLayout;
var
  X: Integer;
  Item: TToolbarIconItem;
begin
  X := 0;

  for Item in FItems do
  begin
    Item.Left := X;
    Item.Top  := 0;
    Item.Anchors := [akLeft, akTop];

    Inc(X, Item.Width);
  end;

  Invalidate;
end;

procedure TToolbarButtons.Relayout;
begin
  UpdateLayout;
end;

{------------------------------------------------------------------------------}
{ Resize → レイアウト維持（高さ変更時にも対応） }
{------------------------------------------------------------------------------}
procedure TToolbarButtons.Resize;
begin
  inherited;
  UpdateLayout;
end;

end.

