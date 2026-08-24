unit HintFrame;

interface

uses
  Winapi.Windows,System.Classes,System.Math,System.SysUtils,Vcl.Controls,Vcl.ExtCtrls,
  Vcl.Forms,Vcl.Graphics,Vcl.StdCtrls;

type
  TFrameHint = class(TFrame)
  private
    FPanel              : TPanel;    // 通知表示用の土台パネル
    FHintLabel          : TLabel;    // 右から左へ流す文字表示ラベル
    FScrollTimer        : TTimer;    // スクロール更新用タイマー
    FDisplayHeight      : Integer;   // 表示時の固定高さ
    FScrollInterval     : Integer;   // スクロール更新間隔
    FScrollStep         : Integer;   // 1回ごとの移動量
    FScrollStartTick    : UInt64;    // スクロール開始時刻
    FScrollStartLeft    : Integer;   // スクロール開始位置
    FHorizontalPadding  : Integer;   // 左右の余白
    FPanelColor         : TColor;    // 通知面の背景色
    FFontColor          : TColor;    // 通知文字色
    FBorderColor        : TColor;    // 外枠の色
    FAutoRegisterGlobal : Boolean;   // 生成時にグローバル登録するか
    FShowing            : Boolean;   // 表示中かどうか

    // グローバル登録の有効・無効を切り替える
    procedure SetAutoRegisterGlobal(const Value: Boolean);
    // 外枠色を更新する
    procedure SetBorderColor(const Value: TColor);
    // 表示時の高さを更新する
    procedure SetDisplayHeight(const Value: Integer);
    // 文字色を更新する
    procedure SetFontColor(const Value: TColor);
    // 左右余白を更新する
    procedure SetHorizontalPadding(const Value: Integer);
    // パネル背景色を更新する
    procedure SetPanelColor(const Value: TColor);
    // スクロール間隔を更新する
    procedure SetScrollInterval(const Value: Integer);
    // スクロール移動量を更新する
    procedure SetScrollStep(const Value: Integer);
    // タイマーでラベル位置を進める
    procedure OnScrollTimer(Sender: TObject);
    // 再表示用にスクロール状態を初期化する
    procedure ResetScrollState;
    // 表示前に見た目と配置を反映する
    procedure PrepareHintDisplay;
    // スクロール表示を開始する
    procedure StartScroll;
    // 表示状態に応じて高さと可視状態を切り替える
    procedure UpdateFrameVisibleState;
    // ラベルを縦中央へ配置する
    procedure UpdateLabelTop;
    // 色と見た目を反映する
    procedure UpdatePanelStyle;
  protected
    // リサイズ時に内部パネルを追従させる
    procedure Resize; override;
  public
    // 通知フレームを初期化する
    constructor Create(AOwner: TComponent); override;
    // 通知フレームを破棄する
    destructor Destroy; override;
    // 指定文字列の通知表示を開始する
    procedure ShowHint(const AText: string);
    // 現在の通知表示を終了する
    procedure CancelHint;
    property HintLabel: TLabel read FHintLabel;
    property HintPanel: TPanel read FPanel;
    property Showing: Boolean read FShowing;
  published
    // 配置位置
    property Align default alBottom;
    // 表示時の固定高さ
    property DisplayHeight: Integer read FDisplayHeight write SetDisplayHeight default 28;
    // スクロール更新間隔
    property ScrollInterval: Integer read FScrollInterval write SetScrollInterval default 20;
    // 1回ごとの移動量
    property ScrollStep: Integer read FScrollStep write SetScrollStep default 2;
    // 左右の余白
    property HorizontalPadding: Integer read FHorizontalPadding write SetHorizontalPadding default 8;
    // 通知面の背景色
    property PanelColor: TColor read FPanelColor write SetPanelColor default clBlack;
    // 通知文字色
    property FontColor: TColor read FFontColor write SetFontColor default clWhite;
    // 外枠の色
    property BorderColor: TColor read FBorderColor write SetBorderColor default clGray;
    // 生成時にグローバル登録するか
    property AutoRegisterGlobal: Boolean read FAutoRegisterGlobal write SetAutoRegisterGlobal default True;
  end;

procedure RegisterHintPanel(AHintPanel: TFrameHint);
procedure UnregisterHintPanel(AHintPanel: TFrameHint);
procedure ShowHintFrame(const AText: string);
procedure CancelHintPanel;
function GetHintPanel: TFrameHint;

implementation

{$R *.dfm}

var
  GHintPanel: TFrameHint;

procedure RegisterHintPanel(AHintPanel: TFrameHint);
begin
  GHintPanel := AHintPanel;
end;

procedure UnregisterHintPanel(AHintPanel: TFrameHint);
begin
  if GHintPanel = AHintPanel then GHintPanel := nil;
end;

procedure ShowHintFrame(const AText: string);
begin
  if GHintPanel = nil then Exit;
  GHintPanel.ShowHint(AText);
end;

procedure CancelHintPanel;
begin
  if GHintPanel = nil then Exit;
  GHintPanel.CancelHint;
end;

function GetHintPanel: TFrameHint;
begin
  Result := GHintPanel;
end;

{ TFrameHint }

constructor TFrameHint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Align := alBottom;

  FDisplayHeight := 28;
  FScrollInterval := 20;
  FScrollStep := 2;
  FScrollStartTick := 0;
  FScrollStartLeft := 0;
  FHorizontalPadding := 8;
  FPanelColor := clBlack;
  FFontColor := clWhite;
  FBorderColor := clGray;
  FAutoRegisterGlobal := True;
  FShowing := False;

  Height := 0;
  Visible := False;

  FPanel := TPanel.Create(Self);
  FPanel.Parent := Self;
  FPanel.Align := alNone;
  FPanel.BevelOuter := bvNone;
  FPanel.Caption := '';
  FPanel.ParentBackground := False;

  FHintLabel := TLabel.Create(Self);
  FHintLabel.Parent := FPanel;
  FHintLabel.AutoSize := True;
  FHintLabel.Transparent := True;
  FHintLabel.Caption := '';
  FHintLabel.Left := FHorizontalPadding;

  FScrollTimer := TTimer.Create(Self);
  FScrollTimer.Enabled := False;
  FScrollTimer.Interval := FScrollInterval;
  FScrollTimer.OnTimer := OnScrollTimer;

  if FAutoRegisterGlobal then RegisterHintPanel(Self);
end;

destructor TFrameHint.Destroy;
begin
  if FAutoRegisterGlobal then UnregisterHintPanel(Self);

  inherited Destroy;
end;

procedure TFrameHint.CancelHint;
begin
  ResetScrollState;
  FShowing := False;
  UpdateFrameVisibleState;
end;

procedure TFrameHint.OnScrollTimer(Sender: TObject);
var
  ElapsedMs : UInt64;
  Distance  : Integer;
begin
  ElapsedMs := GetTickCount64 - FScrollStartTick;
  Distance := Integer(Round(ElapsedMs * (FScrollStep / Max(1, FScrollInterval))));

  FHintLabel.Left := FScrollStartLeft - Distance;

  if FHintLabel.Left + FHintLabel.Width < -FHorizontalPadding then CancelHint;
end;

procedure TFrameHint.Resize;
begin
  inherited Resize;
  if FPanel <> nil then FPanel.SetBounds(1, 1, Max(0, ClientWidth - 2), Max(0, ClientHeight - 2));
  UpdateLabelTop;
end;

procedure TFrameHint.SetAutoRegisterGlobal(const Value: Boolean);
begin
  if FAutoRegisterGlobal = Value then Exit;

  FAutoRegisterGlobal := Value;

  if FAutoRegisterGlobal then
    RegisterHintPanel(Self)
  else
    UnregisterHintPanel(Self);
end;

procedure TFrameHint.SetBorderColor(const Value: TColor);
begin
  if FBorderColor = Value then Exit;

  FBorderColor := Value;
  UpdatePanelStyle;
end;

procedure TFrameHint.SetDisplayHeight(const Value: Integer);
begin
  if FDisplayHeight = Value then Exit;

  FDisplayHeight := Value;
  UpdateFrameVisibleState;
  UpdateLabelTop;
end;

procedure TFrameHint.SetFontColor(const Value: TColor);
begin
  if FFontColor = Value then Exit;

  FFontColor := Value;
  UpdatePanelStyle;
end;

procedure TFrameHint.SetHorizontalPadding(const Value: Integer);
begin
  if FHorizontalPadding = Value then Exit;

  FHorizontalPadding := Value;
  UpdateLabelTop;
end;

procedure TFrameHint.SetPanelColor(const Value: TColor);
begin
  if FPanelColor = Value then Exit;

  FPanelColor := Value;
  UpdatePanelStyle;
end;

procedure TFrameHint.SetScrollInterval(const Value: Integer);
begin
  if FScrollInterval = Value then Exit;

  FScrollInterval := Value;
  FScrollTimer.Interval := FScrollInterval;
end;

procedure TFrameHint.SetScrollStep(const Value: Integer);
begin
  if FScrollStep = Value then Exit;

  FScrollStep := Value;
end;

procedure TFrameHint.ShowHint(const AText: string);
begin
  ResetScrollState;

  if AText = '' then
  begin
    FShowing := False;
    UpdateFrameVisibleState;
    Exit;
  end;

  PrepareHintDisplay;
  FHintLabel.Caption := AText;
  UpdateLabelTop;
  StartScroll;
end;

procedure TFrameHint.ResetScrollState;
begin
  FScrollTimer.Enabled := False;
  FHintLabel.Caption := '';
  FHintLabel.Left := FHorizontalPadding;
  FScrollStartTick := 0;
  FScrollStartLeft := FHorizontalPadding;
end;

procedure TFrameHint.PrepareHintDisplay;
begin
  UpdatePanelStyle;
  UpdateFrameVisibleState;
  UpdateLabelTop;
end;

procedure TFrameHint.StartScroll;
begin
  FShowing := True;
  UpdateFrameVisibleState;

  FHintLabel.Left := ClientWidth + FHorizontalPadding;
  FScrollStartLeft := FHintLabel.Left;
  FScrollStartTick := GetTickCount64;
  UpdateLabelTop;
  FScrollTimer.Enabled := True;
end;

procedure TFrameHint.UpdateFrameVisibleState;
begin
  if FShowing then
  begin
    Height := FDisplayHeight;
    Visible := True;
  end
  else
  begin
    Visible := False;
    Height := 0;
  end;

  if FPanel = nil then
    Exit;

  if Visible then
    FPanel.SetBounds(1, 1, Max(0, ClientWidth - 2), Max(0, ClientHeight - 2))
  else
    FPanel.SetBounds(0, 0, 0, 0);
end;

procedure TFrameHint.UpdateLabelTop;
begin
  if (FPanel = nil) or (FHintLabel = nil) then Exit;

  FHintLabel.Top := (FPanel.ClientHeight - FHintLabel.Height) div 2;
  if FHintLabel.Top < 0 then FHintLabel.Top := 0;
end;

procedure TFrameHint.UpdatePanelStyle;
begin
  ParentColor := False;
  Color := FBorderColor;
  FPanel.Color := FPanelColor;
  FPanel.Font.Color := FFontColor;
  FHintLabel.Font.Color := FFontColor;

  FPanel.BevelOuter := bvNone;
  FPanel.BevelInner := bvNone;
  FPanel.BorderStyle := bsNone;
  FPanel.ParentBackground := False;
  FPanel.ParentColor := False;
  FPanel.ParentFont := False;
  FHintLabel.ParentFont := True;
end;

end.
