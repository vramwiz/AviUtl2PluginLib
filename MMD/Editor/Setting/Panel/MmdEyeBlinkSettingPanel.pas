unit MmdEyeBlinkSettingPanel;

// 初期状態GUIで単一の目パチモーフ、閉眼段階、時間設定を編集する。

interface

uses
  System.Classes,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DarkEdit,
  DarkLabel,
  DarkPanel,
  DarkThemeDpiContext,
  HorizontalTrackBarControl,
  MmdPoseEditorTheme,
  MmdPoseEditorComboTheme,
  PmxModel,
  PmxMorph;

type
  TMmdEyeBlinkSettingPanel = class(TPanel)
  private
    FHeaderPanel: TDarkPanel;
    FIntervalEdit: TDarkEdit;
    FDpiContext: TDarkThemeDpiContext;
    FLoading: Boolean;
    FModel: TPmxModel;
    FMorphCombo: TMmdDarkComboBox;
    FOffsetEdit: TDarkEdit;
    FOnSettingChanged: TNotifyEvent;
    FSettingLabels: array[0..2] of TDarkPanel;
    FSettingLabelTexts: array[0..2] of TDarkLabel;
    FSettingRows: array[0..2] of TDarkPanel;
    FSettingsPanel: TDarkPanel;
    FSpeedEdit: TDarkEdit;
    FStageTrack: THorizontalTrackBarControl;
    procedure ApplyDpiLayout(PPI: Integer);
    function CreateSettingRow(Index: Integer; const Caption,
      InitialText: string): TDarkEdit;
    procedure EditExit(Sender: TObject);
    function GetClosedWeight: Single;
    function GetIntervalSec: Double;
    function GetOffsetSec: Double;
    function GetSelectedMorphIndex: Integer;
    function GetSelectedMorphName: string;
    function GetSpeedSec: Double;
    procedure MorphSelectionChanged(Sender: TObject);
    procedure NotifySettingChanged;
    procedure StageChanged(Sender: TObject);
    procedure UpdateStageControl;
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
  public
    // 未設定の目パチ編集コントロールを生成し、既定の時間値を表示する。
    constructor Create(AOwner: TComponent); override;
    // 選択候補を現在モデルの対応モーフで再構築し、「なし」を選択する。
    procedure SetModel(AModel: TPmxModel);
    // ホストフォームのDPI変換後に生成された各コントロールへ最終フォントを同期する。
    procedure MatchParentFont;
    // モーフ名と閉眼段階を復元し、時間値には既定値を使用する。
    procedure LoadSetting(const MorphName: string; ClosedWeight: Single);
      overload;
    // モーフ名、閉眼段階、時間値を検証して画面へ復元する。
    procedure LoadSetting(const MorphName: string; ClosedWeight: Single;
      IntervalSec, SpeedSec, OffsetSec: Double); overload;
    // 現在選択をモデル長のプレビュー用モーフウェイト配列として返す。
    procedure CopyPreviewWeights(out Weights: TPmxMorphWeights);
    property ClosedWeight: Single read GetClosedWeight;
    property HeaderPanel: TDarkPanel read FHeaderPanel;
    property IntervalEdit: TDarkEdit read FIntervalEdit;
    property IntervalSec: Double read GetIntervalSec;
    property MorphCombo: TMmdDarkComboBox read FMorphCombo;
    property OffsetEdit: TDarkEdit read FOffsetEdit;
    property OffsetSec: Double read GetOffsetSec;
    property SelectedMorphName: string read GetSelectedMorphName;
    property SpeedEdit: TDarkEdit read FSpeedEdit;
    property SpeedSec: Double read GetSpeedSec;
    property StageTrack: THorizontalTrackBarControl read FStageTrack;
    property OnSettingChanged: TNotifyEvent read FOnSettingChanged
      write FOnSettingChanged;
  end;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  MmdSettingPanelValue;

type
  TControlAccess = class(TControl);

const
  DefaultIntervalSec = 4.0;
  DefaultSpeedSec = 0.1;
  DefaultOffsetSec = 0.0;

procedure TMmdEyeBlinkSettingPanel.ApplyDpiLayout(PPI: Integer);
var
  I: Integer;
begin
  if PPI <= 0 then
    PPI := 96;
  FHeaderPanel.Height := MulDiv(30, PPI, 96);
  FMorphCombo.Height := MulDiv(26, PPI, 96);
  FMorphCombo.ItemHeight := Max(MulDiv(20, PPI, 96),
    Abs(FMorphCombo.Font.Height) + MulDiv(4, PPI, 96));
  FStageTrack.Height := MulDiv(36, PPI, 96);
  FHeaderPanel.Top := 0;
  FMorphCombo.Top := FHeaderPanel.Height;
  FStageTrack.Top := FHeaderPanel.Height + FMorphCombo.Height;
  FSettingsPanel.Top := FStageTrack.Top + FStageTrack.Height;
  for I := 0 to High(FSettingRows) do
  begin
    FSettingRows[I].Height := MulDiv(30, PPI, 96);
    FSettingRows[I].Top := I * FSettingRows[I].Height;
    FSettingLabels[I].Width := MulDiv(135, PPI, 96);
    FSettingLabels[I].Padding.Left := MulDiv(8, PPI, 96);
    FSettingLabels[I].Padding.Right := MulDiv(4, PPI, 96);
  end;
  FSettingsPanel.Realign;
  Realign;
end;

procedure TMmdEyeBlinkSettingPanel.ChangeScale(M, D: Integer;
  isDpiChange: Boolean);
begin
  inherited;
  if FDpiContext <> nil then
    FDpiContext.Dpi := M;
  ApplyDpiLayout(M);
end;

constructor TMmdEyeBlinkSettingPanel.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited;
  BevelOuter := bvNone;
  ParentBackground := False;
  Color := MmdEditorBackground;
  Font.Color := MmdEditorText;
  FDpiContext := TDarkThemeDpiContext.Create(Self);
  FDpiContext.UpdateFromControl(Self);

  FHeaderPanel := TDarkPanel.Create(Self);
  FHeaderPanel.Parent := Self;
  FHeaderPanel.Align := alTop;
  FHeaderPanel.BevelOuter := bvNone;
  FHeaderPanel.ParentBackground := False;
  FHeaderPanel.Color := MmdEditorPanel;
  FHeaderPanel.Caption := #$76EE#$30D1#$30C1;
  FHeaderPanel.Font.Color := MmdEditorText;

  FMorphCombo := TMmdDarkComboBox.Create(Self);
  FMorphCombo.Parent := Self;
  FMorphCombo.Align := alTop;
  FMorphCombo.DropDownCount := 16;
  FMorphCombo.OnChange := MorphSelectionChanged;

  FStageTrack := THorizontalTrackBarControl.Create(Self);
  FStageTrack.Parent := Self;
  FStageTrack.Align := alTop;
  FStageTrack.Minimum := 0;
  FStageTrack.Maximum := 100;
  FStageTrack.Frequency := 10;
  FStageTrack.SmallChange := 1;
  FStageTrack.LargeChange := 10;
  FStageTrack.BackgroundColor := MmdEditorPanel;
  FStageTrack.ChannelColor := MmdEditorBorder;
  FStageTrack.DisabledColor := MmdEditorDisabledText;
  FStageTrack.FillColor := MmdEditorSelection;
  FStageTrack.ThumbBorderColor := MmdEditorText;
  FStageTrack.ThumbColor := MmdEditorControl;
  FStageTrack.TickColor := MmdEditorDisabledText;
  FStageTrack.Position := 0;
  FStageTrack.OnChange := StageChanged;

  FSettingsPanel := TDarkPanel.Create(Self);
  FSettingsPanel.Parent := Self;
  FSettingsPanel.Align := alClient;
  FSettingsPanel.BevelOuter := bvNone;
  FSettingsPanel.ParentBackground := False;
  FSettingsPanel.Color := MmdEditorBackground;
  FIntervalEdit := CreateSettingRow(0, #$9593#$9694 + #$FF08#$79D2#$FF09,
    FloatToStr(DefaultIntervalSec));
  FSpeedEdit := CreateSettingRow(1, #$901F#$5EA6 + #$FF08#$79D2#$FF09,
    FloatToStr(DefaultSpeedSec));
  FOffsetEdit := CreateSettingRow(2, #$30AA#$30D5#$30BB#$30C3#$30C8 +
    #$FF08#$79D2#$FF09, FloatToStr(DefaultOffsetSec));

  FHeaderPanel.Height := 30;
  FMorphCombo.Height := 26;
  FStageTrack.Height := 36;
  FHeaderPanel.Top := 0;
  FMorphCombo.Top := 30;
  FStageTrack.Top := 56;
  FSettingsPanel.Top := 92;
  for I := 0 to High(FSettingRows) do
  begin
    FSettingRows[I].Height := 30;
    FSettingRows[I].Top := I * 30;
    FSettingLabels[I].Width := 135;
  end;
  FSettingsPanel.Realign;
  Realign;
  FStageTrack.Enabled := False;
end;

function TMmdEyeBlinkSettingPanel.CreateSettingRow(Index: Integer;
  const Caption, InitialText: string): TDarkEdit;
begin
  FSettingRows[Index] := TDarkPanel.Create(Self);
  FSettingRows[Index].Parent := FSettingsPanel;
  FSettingRows[Index].Align := alTop;
  FSettingRows[Index].BevelOuter := bvNone;
  FSettingRows[Index].ParentBackground := False;
  FSettingRows[Index].Color := MmdEditorBackground;

  FSettingLabels[Index] := TDarkPanel.Create(Self);
  FSettingLabels[Index].Parent := FSettingRows[Index];
  FSettingLabels[Index].Align := alLeft;
  FSettingLabels[Index].BevelOuter := bvNone;
  FSettingLabels[Index].ParentBackground := False;
  FSettingLabels[Index].Color := MmdEditorPanel;
  FSettingLabels[Index].Padding.SetBounds(8, 0, 4, 0);
  FSettingLabelTexts[Index] := TDarkLabel.Create(Self);
  FSettingLabelTexts[Index].Parent := FSettingLabels[Index];
  FSettingLabelTexts[Index].Align := alClient;
  FSettingLabelTexts[Index].AutoSize := False;
  FSettingLabelTexts[Index].Caption := Caption;
  FSettingLabelTexts[Index].Alignment := taLeftJustify;
  FSettingLabelTexts[Index].Layout := tlCenter;
  FSettingLabelTexts[Index].Transparent := True;
  FSettingLabelTexts[Index].UseThemeFont := False;
  FSettingLabelTexts[Index].TextColor := MmdEditorText;

  Result := TDarkEdit.Create(Self);
  Result.Parent := FSettingRows[Index];
  Result.DpiContext := FDpiContext;
  Result.Align := alClient;
  Result.Text := InitialText;
  Result.OnExit := EditExit;
end;

procedure TMmdEyeBlinkSettingPanel.EditExit(Sender: TObject);
begin
  if Sender = FIntervalEdit then
    FIntervalEdit.Text := FloatToStr(IntervalSec)
  else if Sender = FSpeedEdit then
    FSpeedEdit.Text := FloatToStr(SpeedSec)
  else if Sender = FOffsetEdit then
    FOffsetEdit.Text := FloatToStr(OffsetSec);
  NotifySettingChanged;
end;

procedure TMmdEyeBlinkSettingPanel.CopyPreviewWeights(
  out Weights: TPmxMorphWeights);
var
  MorphIndex: Integer;
begin
  Weights := nil;
  if FModel = nil then
    Exit;
  InitializeMorphWeights(FModel, Weights);
  MorphIndex := GetSelectedMorphIndex;
  if MorphIndex >= 0 then
    Weights[MorphIndex] := ClosedWeight;
end;

function TMmdEyeBlinkSettingPanel.GetClosedWeight: Single;
begin
  if GetSelectedMorphIndex < 0 then
    Exit(0);
  Result := FStageTrack.Position / 100;
end;

function TMmdEyeBlinkSettingPanel.GetIntervalSec: Double;
begin
  Result := ReadMmdSettingEditValue(FIntervalEdit, DefaultIntervalSec,
    1.0, 20.0);
end;

function TMmdEyeBlinkSettingPanel.GetOffsetSec: Double;
begin
  Result := ReadMmdSettingEditValue(FOffsetEdit, DefaultOffsetSec,
    -20.0, 20.0);
end;

function TMmdEyeBlinkSettingPanel.GetSelectedMorphIndex: Integer;
begin
  Result := ResolveMmdMorphComboIndex(FMorphCombo, FModel);
end;

function TMmdEyeBlinkSettingPanel.GetSelectedMorphName: string;
var
  MorphIndex: Integer;
begin
  MorphIndex := GetSelectedMorphIndex;
  if MorphIndex < 0 then
    Exit('');
  Result := FModel.Morphs[MorphIndex].Name;
end;

function TMmdEyeBlinkSettingPanel.GetSpeedSec: Double;
begin
  Result := ReadMmdSettingEditValue(FSpeedEdit, DefaultSpeedSec,
    0.01, 100.0);
end;

procedure TMmdEyeBlinkSettingPanel.LoadSetting(const MorphName: string;
  ClosedWeight: Single);
begin
  LoadSetting(MorphName, ClosedWeight, DefaultIntervalSec, DefaultSpeedSec,
    DefaultOffsetSec);
end;

procedure TMmdEyeBlinkSettingPanel.LoadSetting(const MorphName: string;
  ClosedWeight: Single; IntervalSec, SpeedSec, OffsetSec: Double);
var
  Index: Integer;
begin
  FLoading := True;
  try
    FMorphCombo.ItemIndex := 0;
    if MorphName <> '' then
      for Index := 1 to FMorphCombo.Items.Count - 1 do
        if SameText(FMorphCombo.Items[Index], MorphName) then
        begin
          FMorphCombo.ItemIndex := Index;
          Break;
        end;
    if FMorphCombo.ItemIndex = 0 then
      FStageTrack.Position := 0
    else
      FStageTrack.Position := EnsureRange(Round(ClosedWeight * 100), 0, 100);
    FIntervalEdit.Text := FloatToStr(EnsureRange(IntervalSec, 1.0, 20.0));
    FSpeedEdit.Text := FloatToStr(EnsureRange(SpeedSec, 0.01, 100.0));
    FOffsetEdit.Text := FloatToStr(EnsureRange(OffsetSec, -20.0, 20.0));
    UpdateStageControl;
  finally
    FLoading := False;
  end;
  NotifySettingChanged;
end;

procedure TMmdEyeBlinkSettingPanel.MatchParentFont;
var
  I: Integer;
begin
  if Parent = nil then
    Exit;
  Font.Assign(TControlAccess(Parent).Font);
  Font.Color := MmdEditorText;
  FHeaderPanel.Font.Assign(Font);
  FMorphCombo.Font.Assign(Font);
  FIntervalEdit.Font.Assign(Font);
  FSpeedEdit.Font.Assign(Font);
  FOffsetEdit.Font.Assign(Font);
  for I := 0 to High(FSettingLabels) do
    FSettingLabelTexts[I].Font.Assign(Font);
  ApplyDpiLayout(CurrentPPI);
end;

procedure TMmdEyeBlinkSettingPanel.MorphSelectionChanged(Sender: TObject);
begin
  if FLoading then
    Exit;
  if GetSelectedMorphIndex < 0 then
    FStageTrack.Position := 0
  else
    FStageTrack.Position := 100;
  UpdateStageControl;
  NotifySettingChanged;
end;

procedure TMmdEyeBlinkSettingPanel.NotifySettingChanged;
begin
  if not FLoading and Assigned(FOnSettingChanged) then
    FOnSettingChanged(Self);
end;

procedure TMmdEyeBlinkSettingPanel.SetModel(AModel: TPmxModel);
begin
  FLoading := True;
  try
    FModel := AModel;
    PopulateMmdMorphCombo(FMorphCombo, FModel);
    FStageTrack.Position := 0;
    UpdateStageControl;
  finally
    FLoading := False;
  end;
end;

procedure TMmdEyeBlinkSettingPanel.StageChanged(Sender: TObject);
begin
  NotifySettingChanged;
end;

procedure TMmdEyeBlinkSettingPanel.UpdateStageControl;
begin
  FStageTrack.Enabled := GetSelectedMorphIndex >= 0;
  if not FStageTrack.Enabled then
    FStageTrack.Position := 0;
end;

end.
