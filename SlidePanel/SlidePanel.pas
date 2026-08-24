unit SlidePanel;

interface

uses
  System.Classes, System.Types, System.UITypes,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Forms, Winapi.Messages,
  RTTIPersistentIni,Math;

type
  // スライド方向
  TSlideSide = (ssLeft, ssRight, ssTop, ssBottom);

  // スライドパネルの状態を保存するクラス
  TSlidePanelSettings = class(TRTTIPersistentIni)
  private
    FSlideSide: TSlideSide;       // 左右上下の配置方向
    FOpenSize: Integer;           // 開いた時のサイズ
    FMinimizedSize: Integer;      // 最小化サイズ
    FMaxSize: Integer;            // 最大サイズ
    FCloseSize: Integer;          // 完全閉サイズ
    FIsOpen: Boolean;             // 開閉状態
    FAutoHideDelay: Integer;      // 自動最小化遅延
  published
    property SlideSide: TSlideSide read FSlideSide write FSlideSide;
    property OpenSize: Integer read FOpenSize write FOpenSize;
    property MinimizedSize: Integer read FMinimizedSize write FMinimizedSize;
    property MaxSize: Integer read FMaxSize write FMaxSize;
    property CloseSize: Integer read FCloseSize write FCloseSize;
    property IsOpen: Boolean read FIsOpen write FIsOpen;
    property AutoHideDelay: Integer read FAutoHideDelay write FAutoHideDelay;
  end;

  TSlidePanel = class(TCustomPanel)
  private
    FSettings: TSlidePanelSettings;     // 設定保存クラス
    FSlideSide: TSlideSide;             // 配置方向
    FOpenSize: Integer;                 // 開状態のサイズ
    FMinimizedSize: Integer;            // 最小化サイズ
    FMaxSize: Integer;                  // 最大サイズ
    FAutoHideDelay: Integer;            // 自動最小化遅延
    FIsOpen: Boolean;                   // 開閉状態
    FMouseInside: Boolean;              // パネル内にカーソル
    FCloseSize: Integer;                // 完全閉サイズ

    FHideTimer: TTimer;                 // 自動最小化用タイマー

    // スライド方向変更
    procedure SetSlideSide(const Value: TSlideSide);
    // 開状態サイズ
    procedure SetOpenSize(const Value: Integer);
    // 最小化サイズ
    procedure SetMinimizedSize(const Value: Integer);
    // 最大サイズ
    procedure SetMaxSize(const Value: Integer);
    // 開閉状態（内部統合）
    procedure SetIsOpen(const Value: Boolean);
    // 設定ファイル名
    procedure SetSettingsFileName(const Value: string);

    // 自動最小化イベント
    procedure HideTimerEvent(Sender: TObject);
    // レイアウト適用
    procedure UpdatePanelBounds;

  protected
    // CreateWnd
    procedure CreateWnd; override;

    // マウスカーソル入場
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    // マウスカーソル退出
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;

  public
    // コンストラクタ
    constructor Create(AOwner: TComponent); override;
    // デストラクタ
    destructor Destroy; override;

    // 初期化
    procedure InitializePanel;
    // 開閉切替（外部API）
    procedure TogglePanel(AOpen: Boolean);

    // 外部イベント通知（将来用）
    procedure UpdateMouseState(const MousePos: TPoint);
    // 設定適用
    procedure ApplySettings;

  published
    property SlideSide: TSlideSide read FSlideSide write SetSlideSide;
    property OpenSize: Integer read FOpenSize write SetOpenSize;
    property MinimizedSize: Integer read FMinimizedSize write SetMinimizedSize;
    property MaxSize: Integer read FMaxSize write SetMaxSize;
    property AutoHideDelay: Integer read FAutoHideDelay write FAutoHideDelay;
    property IsOpen: Boolean read FIsOpen write SetIsOpen;
    property CloseSize: Integer read FCloseSize write FCloseSize;
    property SettingsFileName: string write SetSettingsFileName;

    property Align;
    property Color;
    property ParentColor;
    property Font;
    property ParentFont;
    property Visible;
  end;

implementation

//--------------------------------------------------------------------------
// コンストラクタ
//--------------------------------------------------------------------------
constructor TSlidePanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FSettings := TSlidePanelSettings.Create;

  FSlideSide := ssLeft;
  FOpenSize := Width;
  FMinimizedSize := 64;
  FMaxSize := 0;
  FCloseSize := 64;
  FIsOpen := True;
  FAutoHideDelay := 800;

  FHideTimer := TTimer.Create(Self);
  FHideTimer.Enabled := False;
  FHideTimer.OnTimer := HideTimerEvent;
end;

//--------------------------------------------------------------------------
// デストラクタ
//--------------------------------------------------------------------------
destructor TSlidePanel.Destroy;
begin
  FSettings.Free;
  inherited Destroy;
end;

//--------------------------------------------------------------------------
// CreateWnd
//--------------------------------------------------------------------------
procedure TSlidePanel.CreateWnd;
begin
  inherited;
  InitializePanel;
end;

//--------------------------------------------------------------------------
// 初期化
//--------------------------------------------------------------------------
procedure TSlidePanel.InitializePanel;
begin
  if FMinimizedSize < 16 then
    FMinimizedSize := 16;

  UpdatePanelBounds;
end;

//--------------------------------------------------------------------------
// 設定適用
//--------------------------------------------------------------------------
procedure TSlidePanel.ApplySettings;
begin
  FSlideSide := FSettings.SlideSide;
  FOpenSize := FSettings.OpenSize;
  FMinimizedSize := Max(FSettings.MinimizedSize, 16);
  FMaxSize := FSettings.MaxSize;
  FCloseSize := FSettings.CloseSize;
  FAutoHideDelay := FSettings.AutoHideDelay;

  SetIsOpen(FSettings.IsOpen);
end;

//--------------------------------------------------------------------------
// 設定ファイル名のセット
//--------------------------------------------------------------------------
procedure TSlidePanel.SetSettingsFileName(const Value: string);
begin
  FSettings.Filename := Value;
  FSettings.LoadFromFile;
  ApplySettings;
end;

//--------------------------------------------------------------------------
// 開閉状態を統一管理
//--------------------------------------------------------------------------
procedure TSlidePanel.SetIsOpen(const Value: Boolean);
begin
  if FIsOpen = Value then Exit;

  FIsOpen := Value;
  UpdatePanelBounds;

  FSettings.IsOpen := FIsOpen;
  if FSettings.Filename <> '' then
    FSettings.SaveToFile;
end;

//--------------------------------------------------------------------------
// 外部API：開閉切り替え
//--------------------------------------------------------------------------
procedure TSlidePanel.TogglePanel(AOpen: Boolean);
begin
  SetIsOpen(AOpen);
end;

//--------------------------------------------------------------------------
// パネルの位置・サイズ更新
//--------------------------------------------------------------------------
procedure TSlidePanel.UpdatePanelBounds;
var
  TargetSize: Integer;
begin
  if FIsOpen then
    TargetSize := FOpenSize
  else
    TargetSize := FMinimizedSize;

  if (FMaxSize > 0) and (TargetSize > FMaxSize) then
    TargetSize := FMaxSize;

  if TargetSize < FMinimizedSize then
    TargetSize := FMinimizedSize;

  case FSlideSide of
    ssLeft:
      begin
        Align := alLeft;
        Width := TargetSize;
      end;

    ssRight:
      begin
        Align := alRight;
        Width := TargetSize;
      end;

    ssTop:
      begin
        Align := alTop;
        Height := TargetSize;
      end;

    ssBottom:
      begin
        Align := alBottom;
        Height := TargetSize;
      end;
  end;
end;

//--------------------------------------------------------------------------
// 自動最小化イベント
//--------------------------------------------------------------------------
procedure TSlidePanel.HideTimerEvent(Sender: TObject);
begin
  FHideTimer.Enabled := False;
  if FMouseInside then Exit;

  if FIsOpen then
    SetIsOpen(False);
end;

//--------------------------------------------------------------------------
// マウス入場
//--------------------------------------------------------------------------
procedure TSlidePanel.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FMouseInside := True;
  FHideTimer.Enabled := False;

  if not FIsOpen then
    SetIsOpen(True);
end;

//--------------------------------------------------------------------------
// マウス退出
//--------------------------------------------------------------------------
procedure TSlidePanel.CMMouseLeave(var Message: TMessage);
begin
  inherited;

  FMouseInside := False;

  if FAutoHideDelay > 0 then
  begin
    FHideTimer.Interval := FAutoHideDelay;
    FHideTimer.Enabled := True;
  end;
end;



//--------------------------------------------------------------------------
// 外部通知（今は未使用）
//--------------------------------------------------------------------------
procedure TSlidePanel.UpdateMouseState(const MousePos: TPoint);
begin
end;

//--------------------------------------------------------------------------
// プロパティセッター
//--------------------------------------------------------------------------
procedure TSlidePanel.SetSlideSide(const Value: TSlideSide);
begin
  FSlideSide := Value;
  UpdatePanelBounds;
end;

procedure TSlidePanel.SetOpenSize(const Value: Integer);
begin
  FOpenSize := Value;
  UpdatePanelBounds;
end;

procedure TSlidePanel.SetMinimizedSize(const Value: Integer);
begin
  FMinimizedSize := Max(Value, 16);
  UpdatePanelBounds;
end;

procedure TSlidePanel.SetMaxSize(const Value: Integer);
begin
  FMaxSize := Value;
  UpdatePanelBounds;
end;

end.

