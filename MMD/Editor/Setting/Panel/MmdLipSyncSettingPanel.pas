unit MmdLipSyncSettingPanel;

// 初期状態GUIで開閉と日本語音素のモーフ割り当て、口パク設定値を編集する。

interface

uses
  System.Classes,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DarkEdit,
  DarkLabel,
  DarkPanel,
  DarkThemeDpiContext,
  MmdLipSyncSettingCodec,
  MmdPoseEditorTheme,
  MmdPoseEditorComboTheme,
  PmxModel,
  PmxMorph;

type
  TMmdLipSyncSettingPanel = class(TPanel)
  private
    FHeaderPanel: TDarkPanel;
    FDpiContext: TDarkThemeDpiContext;
    FLabels: array[0..8] of TDarkPanel;
    FLabelTexts: array[0..8] of TDarkLabel;
    FLoading: Boolean;
    FModel: TPmxModel;
    FMorphCombos: array[0..6] of TMmdDarkComboBox;
    FOnSettingChanged: TNotifyEvent;
    FPreviewMorphIndex: Integer;
    FRows: array[0..8] of TDarkPanel;
    FSettingsPanel: TDarkPanel;
    FSpeedEdit: TDarkEdit;
    FStrengthEdit: TDarkEdit;
    procedure ApplyDpiLayout(PPI: Integer);
    function ComboMorphIndex(Combo: TMmdDarkComboBox): Integer;
    function ComboMorphName(Combo: TMmdDarkComboBox): string;
    function CreateMorphRow(Index: Integer; const Caption: string):
      TMmdDarkComboBox;
    function CreateValueRow(Index: Integer; const Caption,
      InitialText: string): TDarkEdit;
    procedure EditExit(Sender: TObject);
    function GetOpenCloseCombo: TMmdDarkComboBox;
    function GetSpeedSec: Double;
    function GetStrength: Single;
    procedure MorphSelectionChanged(Sender: TObject);
    procedure NotifySettingChanged;
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
  public
    // 未設定の口パク割り当てと既定の速度・強さを持つ編集コントロールを生成する。
    constructor Create(AOwner: TComponent); override;
    // 現在の全コンボと数値入力を永続化用設定へ変換する。
    procedure BuildSetting(out Setting: TMmdLipSyncSetting);
    // 最後に選択したモーフだけを100%にしたプレビュー配列を返す。
    procedure CopyPreviewWeights(out Weights: TPmxMorphWeights);
    // 保存済み設定を復元し、未初期化時だけ一般的なモーフ名を自動割り当てする。
    procedure LoadSetting(const Setting: TMmdLipSyncSetting);
    // ホストフォームのDPI変換後に生成された各コントロールへ最終フォントを同期する。
    procedure MatchParentFont;
    // 指定音素に対応する選択コンボを返す。戻り値はパネルが所有する。
    function PhonemeCombo(Phoneme: TMmdLipSyncPhoneme): TMmdDarkComboBox;
    // 全コンボの候補を現在モデルの対応モーフで再構築する。
    procedure SetModel(AModel: TPmxModel);
    property HeaderPanel: TDarkPanel read FHeaderPanel;
    property OpenCloseCombo: TMmdDarkComboBox read GetOpenCloseCombo;
    property SpeedEdit: TDarkEdit read FSpeedEdit;
    property SpeedSec: Double read GetSpeedSec;
    property Strength: Single read GetStrength;
    property StrengthEdit: TDarkEdit read FStrengthEdit;
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
  MorphCaptions: array[0..6] of string =
    (#$958B#$9589, #$3042, #$3044, #$3046, #$3048, #$304A, #$3093);

procedure TMmdLipSyncSettingPanel.ApplyDpiLayout(PPI: Integer);
var
  I, RowHeight: Integer;
begin
  if PPI <= 0 then
    PPI := 96;
  FHeaderPanel.Height := MulDiv(30, PPI, 96);
  FHeaderPanel.Top := 0;
  FSettingsPanel.Top := FHeaderPanel.Height;
  RowHeight := MulDiv(30, PPI, 96);
  for I := 0 to High(FRows) do
  begin
    FRows[I].Height := RowHeight;
    FRows[I].Top := I * RowHeight;
    FLabels[I].Width := MulDiv(100, PPI, 96);
    FLabels[I].Padding.Left := MulDiv(8, PPI, 96);
    FLabels[I].Padding.Right := MulDiv(4, PPI, 96);
  end;
  for I := 0 to High(FMorphCombos) do
  begin
    FMorphCombos[I].ItemHeight := Max(MulDiv(20, PPI, 96),
      Abs(FMorphCombos[I].Font.Height) + MulDiv(4, PPI, 96));
    FMorphCombos[I].Height := RowHeight;
  end;
  FSettingsPanel.Realign;
  Realign;
end;

procedure TMmdLipSyncSettingPanel.ChangeScale(M, D: Integer;
  isDpiChange: Boolean);
begin
  inherited;
  if FDpiContext <> nil then
    FDpiContext.Dpi := M;
  ApplyDpiLayout(M);
end;

constructor TMmdLipSyncSettingPanel.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited;
  BevelOuter := bvNone;
  ParentBackground := False;
  Color := MmdEditorBackground;
  Font.Color := MmdEditorText;
  FPreviewMorphIndex := -1;
  FDpiContext := TDarkThemeDpiContext.Create(Self);
  FDpiContext.UpdateFromControl(Self);

  FHeaderPanel := TDarkPanel.Create(Self);
  FHeaderPanel.Parent := Self;
  FHeaderPanel.Align := alTop;
  FHeaderPanel.BevelOuter := bvNone;
  FHeaderPanel.ParentBackground := False;
  FHeaderPanel.Color := MmdEditorPanel;
  FHeaderPanel.Caption := #$53E3#$30D1#$30AF;
  FHeaderPanel.Font.Color := MmdEditorText;

  FSettingsPanel := TDarkPanel.Create(Self);
  FSettingsPanel.Parent := Self;
  FSettingsPanel.Align := alClient;
  FSettingsPanel.BevelOuter := bvNone;
  FSettingsPanel.ParentBackground := False;
  FSettingsPanel.Color := MmdEditorBackground;

  for I := 0 to High(FMorphCombos) do
    FMorphCombos[I] := CreateMorphRow(I, MorphCaptions[I]);
  FSpeedEdit := CreateValueRow(7, #$901F#$5EA6 + #$FF08#$79D2#$FF09,
    FloatToStr(DefaultMmdLipSyncSpeedSec));
  FStrengthEdit := CreateValueRow(8, #$5F37#$3055 + #$FF08'%'#$FF09,
    FloatToStr(DefaultMmdLipSyncStrength * 100));

  FHeaderPanel.Height := 30;
  FHeaderPanel.Top := 0;
  FSettingsPanel.Top := 30;
  for I := 0 to High(FRows) do
  begin
    FRows[I].Height := 30;
    FRows[I].Top := I * 30;
    FLabels[I].Width := 100;
  end;
  FSettingsPanel.Realign;
  Realign;
end;

function TMmdLipSyncSettingPanel.ComboMorphIndex(
  Combo: TMmdDarkComboBox): Integer;
begin
  Result := ResolveMmdMorphComboIndex(Combo, FModel);
end;

function TMmdLipSyncSettingPanel.ComboMorphName(
  Combo: TMmdDarkComboBox): string;
begin
  Result := ResolveMmdMorphComboName(Combo, FModel);
end;

function TMmdLipSyncSettingPanel.CreateMorphRow(Index: Integer;
  const Caption: string): TMmdDarkComboBox;
begin
  FRows[Index] := TDarkPanel.Create(Self);
  FRows[Index].Parent := FSettingsPanel;
  FRows[Index].Align := alTop;
  FRows[Index].BevelOuter := bvNone;
  FRows[Index].ParentBackground := False;
  FRows[Index].Color := MmdEditorBackground;
  FLabels[Index] := TDarkPanel.Create(Self);
  FLabels[Index].Parent := FRows[Index];
  FLabels[Index].Align := alLeft;
  FLabels[Index].BevelOuter := bvNone;
  FLabels[Index].ParentBackground := False;
  FLabels[Index].Color := MmdEditorPanel;
  FLabels[Index].Padding.SetBounds(8, 0, 4, 0);
  FLabelTexts[Index] := TDarkLabel.Create(Self);
  FLabelTexts[Index].Parent := FLabels[Index];
  FLabelTexts[Index].Align := alClient;
  FLabelTexts[Index].AutoSize := False;
  FLabelTexts[Index].Caption := Caption;
  FLabelTexts[Index].Alignment := taLeftJustify;
  FLabelTexts[Index].Layout := tlCenter;
  FLabelTexts[Index].Transparent := True;
  FLabelTexts[Index].UseThemeFont := False;
  FLabelTexts[Index].TextColor := MmdEditorText;
  Result := TMmdDarkComboBox.Create(Self);
  Result.Parent := FRows[Index];
  Result.Align := alClient;
  Result.DropDownCount := 16;
  Result.OnChange := MorphSelectionChanged;
end;

function TMmdLipSyncSettingPanel.CreateValueRow(Index: Integer;
  const Caption, InitialText: string): TDarkEdit;
begin
  FRows[Index] := TDarkPanel.Create(Self);
  FRows[Index].Parent := FSettingsPanel;
  FRows[Index].Align := alTop;
  FRows[Index].BevelOuter := bvNone;
  FRows[Index].ParentBackground := False;
  FRows[Index].Color := MmdEditorBackground;
  FLabels[Index] := TDarkPanel.Create(Self);
  FLabels[Index].Parent := FRows[Index];
  FLabels[Index].Align := alLeft;
  FLabels[Index].BevelOuter := bvNone;
  FLabels[Index].ParentBackground := False;
  FLabels[Index].Color := MmdEditorPanel;
  FLabels[Index].Padding.SetBounds(8, 0, 4, 0);
  FLabelTexts[Index] := TDarkLabel.Create(Self);
  FLabelTexts[Index].Parent := FLabels[Index];
  FLabelTexts[Index].Align := alClient;
  FLabelTexts[Index].AutoSize := False;
  FLabelTexts[Index].Caption := Caption;
  FLabelTexts[Index].Alignment := taLeftJustify;
  FLabelTexts[Index].Layout := tlCenter;
  FLabelTexts[Index].Transparent := True;
  FLabelTexts[Index].UseThemeFont := False;
  FLabelTexts[Index].TextColor := MmdEditorText;
  Result := TDarkEdit.Create(Self);
  Result.Parent := FRows[Index];
  Result.DpiContext := FDpiContext;
  Result.Align := alClient;
  Result.Text := InitialText;
  Result.OnExit := EditExit;
end;

procedure TMmdLipSyncSettingPanel.BuildSetting(
  out Setting: TMmdLipSyncSetting);
var
  Phoneme: TMmdLipSyncPhoneme;
begin
  Setting := DefaultMmdLipSyncSetting;
  // 一度確定した後は全項目が「なし」でも明示選択として保存し、次回の自動割り当てを抑止する。
  Setting.Initialized := True;
  Setting.OpenClose.MorphName := ComboMorphName(FMorphCombos[0]);
  if Setting.OpenClose.MorphName <> '' then
    Setting.OpenClose.Weight := 1.0;
  for Phoneme := Low(TMmdLipSyncPhoneme) to High(TMmdLipSyncPhoneme) do
  begin
    Setting.Phonemes[Phoneme].MorphName :=
      ComboMorphName(PhonemeCombo(Phoneme));
    if Setting.Phonemes[Phoneme].MorphName <> '' then
      Setting.Phonemes[Phoneme].Weight := 1.0;
  end;
  Setting.SpeedSec := SpeedSec;
  Setting.Strength := Strength;
end;

procedure TMmdLipSyncSettingPanel.CopyPreviewWeights(
  out Weights: TPmxMorphWeights);
begin
  Weights := nil;
  if FModel = nil then
    Exit;
  InitializeMorphWeights(FModel, Weights);
  if (FPreviewMorphIndex >= 0) and
    (FPreviewMorphIndex < Length(Weights)) then
    Weights[FPreviewMorphIndex] := 1.0;
end;

procedure TMmdLipSyncSettingPanel.EditExit(Sender: TObject);
begin
  if Sender = FSpeedEdit then
    FSpeedEdit.Text := FloatToStr(SpeedSec)
  else if Sender = FStrengthEdit then
    FStrengthEdit.Text := FloatToStr(Strength * 100);
  NotifySettingChanged;
end;

function TMmdLipSyncSettingPanel.GetSpeedSec: Double;
begin
  Result := ReadMmdSettingEditValue(FSpeedEdit, DefaultMmdLipSyncSpeedSec,
    0.01, 100.0);
end;

function TMmdLipSyncSettingPanel.GetOpenCloseCombo: TMmdDarkComboBox;
begin
  Result := FMorphCombos[0];
end;

function TMmdLipSyncSettingPanel.GetStrength: Single;
begin
  Result := ReadMmdSettingEditValue(FStrengthEdit,
    DefaultMmdLipSyncStrength * 100, 0.0, 100.0) / 100;
end;

procedure TMmdLipSyncSettingPanel.LoadSetting(
  const Setting: TMmdLipSyncSetting);
const
  InitialMorphNames: array[0..6] of string =
    (#$3042, #$3042, #$3044, #$3046, #$3048, #$304A, #$3093);
var
  I: Integer;
  Phoneme: TMmdLipSyncPhoneme;
begin
  FLoading := True;
  try
    if not Setting.Initialized then
      // 初回だけPMXで一般的な完全一致名を割り当て、存在しない名前は「なし」のままにする。
      for I := 0 to High(FMorphCombos) do
        SelectMmdMorphCombo(FMorphCombos[I], InitialMorphNames[I])
    else
    begin
      SelectMmdMorphCombo(FMorphCombos[0], Setting.OpenClose.MorphName);
      for Phoneme := Low(TMmdLipSyncPhoneme) to High(TMmdLipSyncPhoneme) do
        SelectMmdMorphCombo(PhonemeCombo(Phoneme),
          Setting.Phonemes[Phoneme].MorphName);
    end;
    FSpeedEdit.Text := FloatToStr(EnsureRange(Setting.SpeedSec, 0.01, 100.0));
    FStrengthEdit.Text := FloatToStr(
      EnsureRange(Setting.Strength, 0.0, 1.0) * 100);
    FPreviewMorphIndex := -1;
  finally
    FLoading := False;
  end;
  NotifySettingChanged;
end;

procedure TMmdLipSyncSettingPanel.MatchParentFont;
var
  I: Integer;
begin
  if Parent = nil then
    Exit;
  Font.Assign(TControlAccess(Parent).Font);
  Font.Color := MmdEditorText;
  FHeaderPanel.Font.Assign(Font);
  FSpeedEdit.Font.Assign(Font);
  FStrengthEdit.Font.Assign(Font);
  for I := 0 to High(FLabels) do
    FLabelTexts[I].Font.Assign(Font);
  for I := 0 to High(FMorphCombos) do
    FMorphCombos[I].Font.Assign(Font);
  ApplyDpiLayout(CurrentPPI);
end;

procedure TMmdLipSyncSettingPanel.MorphSelectionChanged(Sender: TObject);
begin
  if FLoading or not (Sender is TMmdDarkComboBox) then
    Exit;
  FPreviewMorphIndex := ComboMorphIndex(TMmdDarkComboBox(Sender));
  NotifySettingChanged;
end;

procedure TMmdLipSyncSettingPanel.NotifySettingChanged;
begin
  if not FLoading and Assigned(FOnSettingChanged) then
    FOnSettingChanged(Self);
end;

function TMmdLipSyncSettingPanel.PhonemeCombo(
  Phoneme: TMmdLipSyncPhoneme): TMmdDarkComboBox;
begin
  Result := FMorphCombos[Ord(Phoneme) + 1];
end;

procedure TMmdLipSyncSettingPanel.SetModel(AModel: TPmxModel);
var
  ComboIndex: Integer;
begin
  FLoading := True;
  try
    FModel := AModel;
    for ComboIndex := 0 to High(FMorphCombos) do
    begin
      PopulateMmdMorphCombo(FMorphCombos[ComboIndex], FModel);
    end;
    FPreviewMorphIndex := -1;
  finally
    FLoading := False;
  end;
end;

end.
