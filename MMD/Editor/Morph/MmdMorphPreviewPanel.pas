unit MmdMorphPreviewPanel;

// 再利用可能なモーフ設定一覧へ、見出し、全消去、プレビュー通知を追加する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DarkLabel,
  DarkThemeDpiContext,
  MmdMorphSettingList,
  MmdPoseEditorTheme,
  MmdPoseEditorButtonTheme,
  PmxModel,
  PmxMorph;

type
  // モーフ一覧へ見出しと全解除を加え、プレビュー更新を最大約30fpsへ集約する。
  TMmdMorphPreviewPanel = class(TPanel)
  private
    FCaptionLabel: TDarkLabel;
    FClearButton: TMmdDarkButton;
    FDpiContext: TDarkThemeDpiContext;
    FList: TMmdMorphSettingList;
    FOnWeightsChanged: TNotifyEvent;
    FPendingPreview: Boolean;
    FUpdateTimer: TTimer;
    procedure ClearClick(Sender: TObject);
    procedure FlushPendingPreview;
    procedure ListEditFinished(Sender: TObject);
    procedure ListWeightsChanged(Sender: TObject);
    procedure UpdateTimerTick(Sender: TObject);
  public
    // 見出し、仮想モーフ一覧、全解除ボタン、遅延通知タイマーを生成する。
    constructor Create(AOwner: TComponent); override;
    // フォーム側でDPI調整が完了したフォントを見出し、一覧、操作ボタンへ同期する。
    procedure MatchParentFont;
    // 一覧が保持する現在のモーフウェイトを、モーフ番号順の配列として複製する。
    procedure CopyWeights(out AWeights: TPmxMorphWeights);
    // 一覧編集と全解除操作の有効状態を同時に切り替える。
    procedure SetEditingEnabled(Value: Boolean);
    // 読取専用PMXモデルを一覧へ接続し、保留中のプレビュー通知を破棄する。
    procedure SetModel(AModel: TPmxModel);
    // 保存済み設定など外部のウェイトを一覧とプレビューへ反映する。
    procedure SetWeights(const AWeights: TPmxMorphWeights);
    // ページ用途に合わせて一覧上部の見出しを変更する。
    procedure SetPageCaption(const Value: string);
    // 集約済みウェイトをD3Dプレビューへ反映できるタイミングで通知する。
    property OnWeightsChanged: TNotifyEvent read FOnWeightsChanged
      write FOnWeightsChanged;
    property CaptionLabel: TDarkLabel read FCaptionLabel;
    property ClearButton: TMmdDarkButton read FClearButton;
    property ListControl: TMmdMorphSettingList read FList;
  end;

// 現在のプレビュー計算が適用できるモーフ種別かを返す。
function IsPreviewMorphSupported(MorphType: TPmxMorphType): Boolean;

implementation

uses
  Winapi.Windows;

type
  TControlAccess = class(TControl);

function IsPreviewMorphSupported(MorphType: TPmxMorphType): Boolean;
begin
  Result := MorphType in [pmtGroup, pmtVertex, pmtBone, pmtMaterial, pmtFlip];
end;

constructor TMmdMorphPreviewPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Height := 245;
  ParentBackground := False;
  Color := MmdEditorBackground;
  Font.Color := MmdEditorText;

  FDpiContext := TDarkThemeDpiContext.Create(Self);
  FDpiContext.UpdateFromControl(Self);

  FCaptionLabel := TDarkLabel.Create(Self);
  FCaptionLabel.Parent := Self;
  FCaptionLabel.DpiContext := FDpiContext;
  FCaptionLabel.UseThemeFont := False;
  FCaptionLabel.Align := alTop;
  FCaptionLabel.DesignHeight := 27;
  FCaptionLabel.AutoSize := False;
  FCaptionLabel.Layout := tlCenter;
  FCaptionLabel.Margins.Left := MulDiv(8, CurrentPPI, 96);
  FCaptionLabel.Caption := #$30E2#$30FC#$30D5#$8A2D#$5B9A;

  FClearButton := TMmdDarkButton.Create(Self);
  FClearButton.Parent := Self;
  FClearButton.ParentFont := True;
  FClearButton.Align := alBottom;
  FClearButton.Height := MulDiv(34, CurrentPPI, 96);
  FClearButton.Caption := #$3059#$3079#$3066#$89E3#$9664;
  FClearButton.OnClick := ClearClick;

  FList := TMmdMorphSettingList.Create(Self);
  FList.Parent := Self;
  TControlAccess(FList).ParentFont := True;
  FList.Align := alClient;
  FList.OnChange := ListWeightsChanged;
  FList.OnEditFinished := ListEditFinished;

  FUpdateTimer := TTimer.Create(Self);
  FUpdateTimer.Enabled := False;
  FUpdateTimer.Interval := 33;
  FUpdateTimer.OnTimer := UpdateTimerTick;
end;

procedure TMmdMorphPreviewPanel.MatchParentFont;
begin
  if Parent <> nil then
    Font.Assign(TControlAccess(Parent).Font);
  Font.Color := MmdEditorText;
  FCaptionLabel.UseThemeFont := False;
  FCaptionLabel.Font.Assign(Font);
  TControlAccess(FList).ParentFont := False;
  TControlAccess(FList).Font.Assign(Font);
  FClearButton.ParentFont := False;
  FClearButton.Font.Assign(Font);
  FList.Invalidate;
  FClearButton.Invalidate;
end;

procedure TMmdMorphPreviewPanel.ClearClick(Sender: TObject);
begin
  FUpdateTimer.Enabled := False;
  FPendingPreview := False;
  FList.ClearWeights;
end;

procedure TMmdMorphPreviewPanel.CopyWeights(out AWeights: TPmxMorphWeights);
begin
  FList.CopyWeights(AWeights);
end;

procedure TMmdMorphPreviewPanel.FlushPendingPreview;
begin
  FUpdateTimer.Enabled := False;
  if not FPendingPreview then
    Exit;
  FPendingPreview := False;
  if Assigned(FOnWeightsChanged) then
    FOnWeightsChanged(Self);
end;

procedure TMmdMorphPreviewPanel.ListEditFinished(Sender: TObject);
begin
  FlushPendingPreview;
end;

procedure TMmdMorphPreviewPanel.ListWeightsChanged(Sender: TObject);
begin
  FPendingPreview := True;
  if not FUpdateTimer.Enabled then
    FUpdateTimer.Enabled := True;
end;

procedure TMmdMorphPreviewPanel.SetEditingEnabled(Value: Boolean);
begin
  FList.EditingEnabled := Value;
  FClearButton.Enabled := Value;
end;

procedure TMmdMorphPreviewPanel.SetModel(AModel: TPmxModel);
begin
  FUpdateTimer.Enabled := False;
  FPendingPreview := False;
  FList.SetModel(AModel);
  FClearButton.Enabled := Assigned(AModel);
end;

procedure TMmdMorphPreviewPanel.SetWeights(const AWeights: TPmxMorphWeights);
begin
  FUpdateTimer.Enabled := False;
  FPendingPreview := False;
  FList.SetWeights(AWeights);
end;

procedure TMmdMorphPreviewPanel.SetPageCaption(const Value: string);
begin
  FCaptionLabel.Caption := Value;
end;

procedure TMmdMorphPreviewPanel.UpdateTimerTick(Sender: TObject);
begin
  FlushPendingPreview;
end;

end.
