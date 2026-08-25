unit ToolbarIcon;

interface

uses
  System.Classes,  System.SysUtils,Winapi.Windows,Winapi.Messages,Vcl.Controls,
  Vcl.ExtCtrls,Vcl.Graphics,Vcl.ImgList,  System.Generics.Collections,System.Types;

type TToolbarIconClickEvent = procedure(Sender: TObject; ATag: Integer) of object;
type
  TToolbarIconHoverEvent = procedure(Sender: TObject;IsHover: Boolean  ) of object;

type
  //======================================================================
  // 1 アイコン（またはセパレーター）
  //======================================================================
  // ツールバーに配置される単体アイコン（またはセパレーター）
  TToolbarIconItem = class(TPanel)
  private
    FImages: TCustomImageList;          // 描画に使用するイメージリスト
    FProc   : TProc;                    // 実行する関数
    // 色
    FNormalColor: TColor;               // 通常表示時の背景色
    FHoverColor: TColor;                // ホバー時の背景色

    // 状態
    FIsHover: Boolean;                  // ホバー状態フラグ
    FIsPressed: Boolean;                // 押下状態フラグ
    FIsHoverEnabled: Boolean;           // ホバー処理を有効にするかどうか

    // 画像情報
    FImageIndex: Integer;               // 表示する画像インデックス（-1 はセパレーター）
    FWidthPPX: Integer;                 // 表示幅（PPX）
    FHeightPPX: Integer;                // 表示高さ（PPX）

    FDown: Boolean;                     // True:ボタン選択などを表す

    // 内部ビットマップ
    FBmpNormal: TBitmap;                // 通常表示用ビットマップ
    FBmpHover: TBitmap;                 // ホバー表示用ビットマップ
    FBmpDown: TBitmap;                  // 降下や選択表示用ビットマップ

    FOnClickEx: TToolbarIconClickEvent; // 拡張クリックイベント
    FOnHoverChanged: TToolbarIconHoverEvent;
    FDownColor: TColor; // ホバー状態変化イベント

    // イメージリストを設定する
    procedure SetImages(const Value: TCustomImageList);
    // 通常背景色を設定する
    procedure SetNormalColor(const Value: TColor);
    // ホバー背景色を設定する
    procedure SetHoverColor(const Value: TColor);
    // 内部描画用ビットマップを再生成する
    procedure UpdateInternalBitmaps;
    // マウスがアイコン内に入ったことを検出する
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    // マウスがアイコン外に出たことを検出する
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure SetIsHover(const Value: Boolean);
    procedure SetDown(const Value: Boolean);
    procedure SetDownColor(const Value: TColor);
  protected
    // アイコンを描画する
    procedure Paint; override;
    // サイズ変更時に内部ビットマップを更新する
    procedure Resize; override;
    // 拡張クリック処理を行う
    procedure DoClickEx(ATag: Integer); virtual;
    // ホバー状態変化を通知する
    procedure DoHoverChanged(IsHover: Boolean); virtual;
    // マウスボタン押下時の処理
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    // マウスボタン解放時の処理
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;X, Y: Integer); override;
  public
    // アイコン項目を生成する
    constructor Create(AOwner: TComponent); override;
    // アイコン項目を破棄する
    destructor Destroy; override;
    // 画像インデックスのみを割り当てる
    procedure AssignIcon(const AImageIndex: Integer);
    // アイコンまたはセパレーターとして設定する
    procedure SetIcon(AImageIndex, AWidthPPX, AHeightPPX: Integer);
    property Down : Boolean read FDown write SetDown;
    // ホバー処理有効フラグ
    property IsHoverEnabled: Boolean read FIsHoverEnabled write FIsHoverEnabled;
    // 現在の画像インデックス
    property ImageIndex: Integer read FImageIndex;
    // ホバー状態
    property IsHover: Boolean read FIsHover write SetIsHover;
    // 押下状態
    property IsPressed: Boolean read FIsPressed;
    // 実行する関数
    property Proc: TProc read FProc write FProc;
  published
    // 使用するイメージリスト
    property Images: TCustomImageList read FImages write SetImages;
    // 通常背景色
    property NormalColor: TColor read FNormalColor write SetNormalColor default clBtnFace;
    // ホバー背景色
    property HoverColor: TColor read FHoverColor write SetHoverColor default clNone;
    // 降下選択時の背景色
    property DownColor: TColor read FDownColor write SetDownColor default clNone;
    // 拡張クリックイベント
    property OnClickEx: TToolbarIconClickEvent read FOnClickEx write FOnClickEx;
    // ホバー変化イベント
    property OnHoverChanged: TToolbarIconHoverEvent read FOnHoverChanged write FOnHoverChanged;
  end;


  //======================================================================
  // 管理リスト
  //======================================================================
  // ツールバー用アイコン項目を管理するリスト
  TToolbarIconList = class(TObjectList<TToolbarIconItem>)
  private
    FImages: TCustomImageList;          // 全アイコン共通のイメージリスト
    FHoverColor: TColor;                // ホバー背景色
    FNormalColor: TColor;               // 通常背景色
    FDownColor: TColor;                 // 選択時背景色
    FOnClickEx: TToolbarIconClickEvent; // リスト全体のクリック通知イベント
    // 全アイコンの合計幅を取得する
    function GetTotalWidth: Integer;
    procedure SetNormalColor(const Value: TColor);
    procedure SetHoverColor(const Value: TColor);
    procedure SetDownColor(const Value: TColor);
    // 各アイコンからのクリックを受け取る
    procedure OnIconItemClick(Sender: TObject; ATag: Integer);
  protected
    // クリックイベントを外部へ通知する
    procedure DoClickEx(Sender: TObject; ATag: Integer); virtual;
  public
    // アイコン管理リストを生成する
    constructor Create; reintroduce;
    // 通常アイコンを追加する
    function AddIcon(AOwner: TWinControl; AImageIndex: Integer;
      AWidthPPX, AHeightPPX: Integer; ATag: Integer = 0): TToolbarIconItem;
    // セパレーターを追加する
    function AddSeparator(AOwner: TWinControl;
      AWidthPPX, AHeightPPX: Integer): TToolbarIconItem;
    property Images: TCustomImageList read FImages write FImages; // 使用するイメージリスト
    property NormalColor: TColor read FNormalColor write SetNormalColor; // 通常背景色
    property HoverColor: TColor read FHoverColor write SetHoverColor;     // ホバー背景色
    property DownColor: TColor read FDownColor write SetDownColor;        // 選択時背景色
    property TotalWidth: Integer read GetTotalWidth;                    // 全アイコンの合計幅
    property OnClickEx: TToolbarIconClickEvent read FOnClickEx write FOnClickEx; // クリック通知イベント
  end;

implementation

{ TToolbarIconItem }

// アイコン項目を初期化する
constructor TToolbarIconItem.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FImages := nil;
  FImageIndex := -1;

  FNormalColor := clBtnFace;
  FHoverColor  := clSilver;
  FDownColor   := clHighlight;

  FIsHover := False;
  FIsPressed := False;
  FIsHoverEnabled := True;

  FBmpNormal := TBitmap.Create;
  FBmpHover := TBitmap.Create;
  FBmpDown  := TBitmap.Create;

  BevelOuter := bvNone;
  ParentBackground := False;
  ParentColor := True;
end;

// アイコン項目を破棄する
destructor TToolbarIconItem.Destroy;
begin
  FBmpDown.Free;
  FBmpNormal.Free;
  FBmpHover.Free;
  inherited;
end;

// 使用するイメージリストを設定する
procedure TToolbarIconItem.SetImages(const Value: TCustomImageList);
begin
  FImages := Value;
  UpdateInternalBitmaps;
end;

procedure TToolbarIconItem.SetIsHover(const Value: Boolean);
begin
  FIsHover := Value;
  Invalidate;
end;

// 通常背景色を設定する
procedure TToolbarIconItem.SetNormalColor(const Value: TColor);
begin
  if FNormalColor <> Value then
  begin
    FNormalColor := Value;
    UpdateInternalBitmaps;
  end;
end;

procedure TToolbarIconItem.SetDown(const Value: Boolean);
begin
  if FDown <> Value then
  begin
    FDown := Value;
    UpdateInternalBitmaps;
    Invalidate;
  end;
end;

// 降下選択時の色を設定する
procedure TToolbarIconItem.SetDownColor(const Value: TColor);
begin
  if FDownColor <> Value then
  begin
    FDownColor := Value;
    UpdateInternalBitmaps;
  end;
end;

// ホバー背景色を設定する
procedure TToolbarIconItem.SetHoverColor(const Value: TColor);
begin
  if FHoverColor <> Value then
  begin
    FHoverColor := Value;
    UpdateInternalBitmaps;
  end;
end;

// 画像インデックスを割り当てる
procedure TToolbarIconItem.AssignIcon(const AImageIndex: Integer);
begin
  FImageIndex := AImageIndex;
  UpdateInternalBitmaps;
  Invalidate;
end;

// アイコンまたはセパレーターとして設定する
procedure TToolbarIconItem.SetIcon(AImageIndex, AWidthPPX, AHeightPPX: Integer);
begin
  FImageIndex := AImageIndex;
  FWidthPPX := AWidthPPX;
  FHeightPPX := AHeightPPX;

  Width := FWidthPPX;
  Height := FHeightPPX;

  UpdateInternalBitmaps;
  Invalidate;
end;

// 内部描画用ビットマップを再生成する
procedure TToolbarIconItem.UpdateInternalBitmaps;
var
  BmpBase: TBitmap;
begin
  if (Width <= 0) or (Height <= 0) then Exit;

  FBmpNormal.SetSize(Width, Height);
  FBmpHover.SetSize(Width, Height);
  FBmpDown.SetSize(Width, Height);

  FBmpNormal.PixelFormat := pf32bit;
  FBmpHover.PixelFormat  := pf32bit;
  FBmpDown.PixelFormat   := pf32bit;

  // セパレーター描画
  if FImageIndex < 0 then
  begin
    FBmpNormal.Canvas.Brush.Color := FNormalColor;
    FBmpNormal.Canvas.FillRect(Rect(0, 0, Width, Height));

    FBmpHover.Canvas.Brush.Color := FHoverColor;
    FBmpHover.Canvas.FillRect(Rect(0, 0, Width, Height));

    FBmpDown.Canvas.Brush.Color := FDownColor;
    FBmpDown.Canvas.FillRect(Rect(0, 0, Width, Height));
    Exit;
  end;

  if (FImages = nil) or (FImageIndex >= FImages.Count) then Exit;

  BmpBase := TBitmap.Create;
  try
    BmpBase.SetSize(FImages.Width, FImages.Height);
    BmpBase.PixelFormat := pf32bit;

    // --- Normal ---
    BmpBase.Canvas.Brush.Color := FNormalColor;
    BmpBase.Canvas.FillRect(Rect(0, 0, BmpBase.Width, BmpBase.Height));
    FImages.Draw(BmpBase.Canvas, 0, 0, FImageIndex, True);

    SetStretchBltMode(FBmpNormal.Canvas.Handle, HALFTONE);
    StretchBlt(FBmpNormal.Canvas.Handle,
      0, 0, Width, Height,
      BmpBase.Canvas.Handle,
      0, 0, BmpBase.Width, BmpBase.Height,
      SRCCOPY);

    // --- Hover ---
    BmpBase.Canvas.Brush.Color := FHoverColor;
    BmpBase.Canvas.FillRect(Rect(0, 0, BmpBase.Width, BmpBase.Height));
    FImages.Draw(BmpBase.Canvas, 0, 0, FImageIndex, True);

    SetStretchBltMode(FBmpHover.Canvas.Handle, HALFTONE);
    StretchBlt(FBmpHover.Canvas.Handle,
      0, 0, Width, Height,
      BmpBase.Canvas.Handle,
      0, 0, BmpBase.Width, BmpBase.Height,
      SRCCOPY);

    // --- Down ---
    BmpBase.Canvas.Brush.Color := FDownColor;
    BmpBase.Canvas.FillRect(Rect(0, 0, BmpBase.Width, BmpBase.Height));
    FImages.Draw(BmpBase.Canvas, 0, 0, FImageIndex, True);

    SetStretchBltMode(FBmpDown.Canvas.Handle, HALFTONE);
    StretchBlt(FBmpDown.Canvas.Handle,
      0, 0, Width, Height,
      BmpBase.Canvas.Handle,
      0, 0, BmpBase.Width, BmpBase.Height,
      SRCCOPY);
  finally
    BmpBase.Free;
  end;
end;

// アイコンを描画する
procedure TToolbarIconItem.Paint;
var
  OffX, OffY: Integer;
begin
  inherited;

  if FIsPressed then begin
    OffX := 1; OffY := 1;
  end else begin
    OffX := 0; OffY := 0;
  end;

  if FImageIndex < 0 then
  begin
    Canvas.Brush.Color := FNormalColor;
    Canvas.FillRect(ClientRect);
    Exit;
  end;

  if FDown then
    Canvas.Draw(OffX, OffY, FBmpDown)
  else if FIsHover then
    Canvas.Draw(OffX, OffY, FBmpHover)
  else
    Canvas.Draw(OffX, OffY, FBmpNormal);
end;

// サイズ変更時に内部ビットマップを更新する
procedure TToolbarIconItem.Resize;
begin
  inherited;
  UpdateInternalBitmaps;
end;

// マウスがアイコン内に入った際の処理
procedure TToolbarIconItem.CMMouseEnter(var Message: TMessage);
var
  P: TPoint;
begin
  inherited;

  if not FIsHoverEnabled then Exit;

  if not FIsHover then
  begin
    FIsHover := True;
    Invalidate;

    DoHoverChanged(True);

    if Assigned(PopupMenu) then
    begin
      P := ClientToScreen(Point(0, Height));
      PopupMenu.Popup(P.X, P.Y);
    end;
  end;
end;

// マウスがアイコン外に出た際の処理
procedure TToolbarIconItem.CMMouseLeave(var Message: TMessage);
begin
  inherited;

  if not FIsHoverEnabled then Exit;

  if FIsHover then
  begin
    DoHoverChanged(False);
    FIsHover := False;
    Invalidate;
  end;
end;

// マウスボタン押下時の処理
procedure TToolbarIconItem.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FImageIndex >= 0 then
  begin
    FIsPressed := True;
    Invalidate;
    if FImageIndex >= 0 then  DoClickEx(Tag);
  end;
end;

// マウスボタン解放時の処理
procedure TToolbarIconItem.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FImageIndex >= 0 then
  begin
    FIsPressed := False;
    Invalidate;
    Click;
  end;
end;

// 拡張クリックイベントを発火させる
procedure TToolbarIconItem.DoClickEx(ATag: Integer);
begin
  if Assigned(FOnClickEx) then FOnClickEx(Self, ATag);
end;

// ホバー状態変化イベントを発火させる
procedure TToolbarIconItem.DoHoverChanged(IsHover: Boolean);
begin
  if Assigned(FOnHoverChanged) then FOnHoverChanged(Self, IsHover);
end;

{ TToolbarIconList }

// アイコン管理リストを初期化する
constructor TToolbarIconList.Create;
begin
  inherited Create(True);
  FNormalColor := clBtnFace;
  FHoverColor := clSilver;
  FDownColor := clHighlight;
end;

procedure TToolbarIconList.SetNormalColor(const Value: TColor);
var
  Item: TToolbarIconItem;
begin
  if FNormalColor = Value then Exit;

  FNormalColor := Value;
  for Item in Self do
    Item.NormalColor := Value;
end;

procedure TToolbarIconList.SetHoverColor(const Value: TColor);
var
  Item: TToolbarIconItem;
begin
  if FHoverColor = Value then Exit;

  FHoverColor := Value;
  for Item in Self do
    Item.HoverColor := Value;
end;

procedure TToolbarIconList.SetDownColor(const Value: TColor);
var
  Item: TToolbarIconItem;
begin
  if FDownColor = Value then Exit;

  FDownColor := Value;
  for Item in Self do
    Item.DownColor := Value;
end;

// クリックイベントを外部へ通知する
procedure TToolbarIconList.DoClickEx(Sender: TObject; ATag: Integer);
begin
  if Assigned(FOnClickEx) then  FOnClickEx(Sender, ATag);
end;

// 通常アイコンを追加する
function TToolbarIconList.AddIcon(AOwner: TWinControl; AImageIndex: Integer;
  AWidthPPX, AHeightPPX: Integer; ATag: Integer): TToolbarIconItem;
begin
  if FImages = nil then
    raise Exception.Create(string('TToolbarIconList.Images が設定されていません。'));

  Result := TToolbarIconItem.Create(AOwner);
  Result.Parent := AOwner;

  Result.Tag := ATag;
  Result.NormalColor := FNormalColor;
  Result.HoverColor := FHoverColor;
  Result.DownColor := FDownColor;
  Result.Images := FImages;

  Result.Width  := AWidthPPX;
  Result.Height := AHeightPPX;
  Result.OnClickEx := OnIconItemClick;

  Result.AssignIcon(AImageIndex);

  Add(Result);
end;

// セパレーターを追加する
function TToolbarIconList.AddSeparator(AOwner: TWinControl;
  AWidthPPX, AHeightPPX: Integer): TToolbarIconItem;
begin
  Result := TToolbarIconItem.Create(AOwner);
  Result.Parent := AOwner;

  Result.Tag := -1;
  Result.IsHoverEnabled := False;
  Result.NormalColor := FNormalColor;
  Result.HoverColor := FHoverColor;
  Result.DownColor := FDownColor;

  Result.SetIcon(-1, AWidthPPX, AHeightPPX);

  Add(Result);
end;

// 全アイコンの合計幅を取得する
function TToolbarIconList.GetTotalWidth: Integer;
var
  Item: TToolbarIconItem;
begin
  Result := 0;
  for Item in Self do
    Inc(Result, Item.Width);
end;

// 各アイコンからのクリックを受け取る
procedure TToolbarIconList.OnIconItemClick(Sender: TObject; ATag: Integer);
begin
  DoClickEx(Sender,ATag);
end;

end.

