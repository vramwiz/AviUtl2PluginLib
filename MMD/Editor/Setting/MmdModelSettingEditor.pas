unit MmdModelSettingEditor;

// 初期状態編集とモデルフィルター設定で共用するフォーム。

interface

uses
  System.Types,
  System.UITypes,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.ImgList,
  Vcl.ToolWin,
  DarkPanel,
  MmdEyeBlinkSettingPanel,
  MmdLipSyncSettingPanel,
  MmdPoseEditor,
  MmdPoseEditorTheme,
  MmdPoseEditorButtonTheme,
  PmxMorph;

type
  TMmdModelSettingPage = (mspPose, mspExpression, mspEyeBlink, mspLipSync);
  TMmdExpressionDataChangedEvent = procedure(Sender: TObject;
    const ExpressionData: string) of object;

  TMmdModelSettingEditorForm = class(TStandardPoseEditorForm)
  private
    FCommitPanel: TDarkPanel;
    FCurrentPage: TMmdModelSettingPage;
    FEyeBlinkPanel: TMmdEyeBlinkSettingPanel;
    FExpressionWeights: TPmxMorphWeights;
    FLipSyncPanel: TMmdLipSyncSettingPanel;
    FModeButtons: TArray<TToolButton>;
    FModeImages: TImageList;
    FModeToolbar: TToolBar;
    FOnExpressionDataChanged: TMmdExpressionDataChangedEvent;
    FSaveButton: TMmdDarkButton;
    procedure ExpressionWeightsChanged(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure EyeBlinkSettingChanged(Sender: TObject);
    procedure LipSyncSettingChanged(Sender: TObject);
    procedure ModeButtonClick(Sender: TObject);
    procedure ModeToolbarCustomDraw(Sender: TToolBar; const ARect: TRect;
      var DefaultDraw: Boolean);
    procedure ModeToolbarCustomDrawButton(Sender: TToolBar;
      Button: TToolButton; State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure SaveExpressionPage;
    procedure ShowSettingPage(Page: TMmdModelSettingPage);
  public
    // 初期状態では全ページ、モデルフィルターではポーズ・表情だけ、
    // PoseOnly／FaceOnlyでは切替ツールバーなしで対象ページだけを表示する。
    procedure ConfigureSettingControls(ShowAllPages: Boolean = False;
      PoseOnly: Boolean = False; FaceOnly: Boolean = False);
    // 保存済みの名前付き表情JSONを現在モデルのモーフウェイトへ復元する。
    procedure InitializeExpression(const ExpressionData: string);
    // 保存済みの単一目パチモーフと閉眼時ウェイトを復元する。
    procedure InitializeEyeBlink(const EyeBlinkData: string);
    // 保存済みの口パクモーフ割り当てと数値設定を復元する。
    procedure InitializeLipSync(const LipSyncData: string);
    // 現在の表情ページを名前付き版付きJSONへ変換する。
    function EncodeExpression: string;
    // 現在の目パチ選択を名前付き版付きJSONへ変換する。
    function EncodeEyeBlink: string;
    // 現在の口パク割り当てと数値設定を名前付き版付きJSONへ変換する。
    function EncodeLipSync: string;
    property EyeBlinkPanel: TMmdEyeBlinkSettingPanel read FEyeBlinkPanel;
    property LipSyncPanel: TMmdLipSyncSettingPanel read FLipSyncPanel;
    property ModeToolbar: TToolBar read FModeToolbar;
    property CommitPanel: TDarkPanel read FCommitPanel;
    property SaveButton: TMmdDarkButton read FSaveButton;
    // 表情ウェイトの実編集時に最新JSONを通知する。外部からの初期化では発火しない。
    property OnExpressionDataChanged: TMmdExpressionDataChangedEvent
      read FOnExpressionDataChanged write FOnExpressionDataChanged;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Forms,
  MmdModelSettingToolbarFactory,
  MmdModelSettingToolbarRenderer,
  MmdEyeBlinkSettingCodec,
  MmdLipSyncSettingCodec,
  MmdMorphSettingCodec;

procedure TMmdModelSettingEditorForm.ModeButtonClick(Sender: TObject);
begin
  if Sender is TToolButton then
    ShowSettingPage(TMmdModelSettingPage(TToolButton(Sender).Tag));
end;

procedure TMmdModelSettingEditorForm.ExpressionWeightsChanged(Sender: TObject);
begin
  FMorphPreview.CopyWeights(FExpressionWeights);
  FViewport.SetMorphWeights(FExpressionWeights);
  if Assigned(FOnExpressionDataChanged) then
    FOnExpressionDataChanged(Self,
      EncodeMmdMorphSettingData(FModel, FExpressionWeights));
end;

procedure TMmdModelSettingEditorForm.SaveExpressionPage;
begin
  if FCurrentPage = mspExpression then
    FMorphPreview.CopyWeights(FExpressionWeights);
end;

procedure TMmdModelSettingEditorForm.EyeBlinkSettingChanged(Sender: TObject);
var
  Weights: TPmxMorphWeights;
begin
  if FEyeBlinkPanel = nil then
    Exit;
  FEyeBlinkPanel.CopyPreviewWeights(Weights);
  FViewport.SetMorphWeights(Weights);
end;

procedure TMmdModelSettingEditorForm.LipSyncSettingChanged(Sender: TObject);
var
  Weights: TPmxMorphWeights;
begin
  if FLipSyncPanel = nil then
    Exit;
  FLipSyncPanel.CopyPreviewWeights(Weights);
  FViewport.SetMorphWeights(Weights);
end;

procedure TMmdModelSettingEditorForm.ShowSettingPage(
  Page: TMmdModelSettingPage);
var
  EmptyWeights: TPmxMorphWeights;
begin
  SaveExpressionPage;
  FCurrentPage := Page;
  if (Ord(Page) <= High(FModeButtons)) and
    Assigned(FModeButtons[Ord(Page)]) then
    FModeButtons[Ord(Page)].Down := True;
  if FEyeBlinkPanel <> nil then
    FEyeBlinkPanel.Visible := False;
  if FLipSyncPanel <> nil then
    FLipSyncPanel.Visible := False;
  if Page = mspPose then
  begin
    if FModel <> nil then
      InitializeMorphWeights(FModel, EmptyWeights);
    FMorphPreview.SetWeights(EmptyWeights);
    FViewport.SetMorphWeights(EmptyWeights);
    FCommandToolbar.Visible := True;
    FBoneList.Visible := True;
    FMorphPreview.Visible := False;
    FViewport.ReadOnly := False;
    FViewport.SetDisplayVisibility(True, True);
    FViewport.ResetPreviewCamera;
    Exit;
  end;
  if Page = mspEyeBlink then
  begin
    FCommandToolbar.Visible := False;
    FBoneList.Visible := False;
    FMorphPreview.Visible := False;
    FEyeBlinkPanel.Visible := True;
    FViewport.ReadOnly := True;
    FViewport.SetDisplayVisibility(True, False);
    EyeBlinkSettingChanged(nil);
    FViewport.FocusPreviewFace(3.2);
    Exit;
  end;
  if Page = mspLipSync then
  begin
    FCommandToolbar.Visible := False;
    FBoneList.Visible := False;
    FMorphPreview.Visible := False;
    FLipSyncPanel.Visible := True;
    FViewport.ReadOnly := True;
    FViewport.SetDisplayVisibility(True, False);
    LipSyncSettingChanged(nil);
    FViewport.FocusPreviewFace(3.2);
    Exit;
  end;
  if Page = mspExpression then
  begin
    FMorphPreview.SetWeights(FExpressionWeights);
    FViewport.SetMorphWeights(FExpressionWeights);
  end
  else
  begin
    if FModel <> nil then
      InitializeMorphWeights(FModel, EmptyWeights);
    FMorphPreview.SetWeights(EmptyWeights);
    FViewport.SetMorphWeights(EmptyWeights);
  end;
  FCommandToolbar.Visible := False;
  FBoneList.Visible := False;
  FMorphPreview.Align := alClient;
  FMorphPreview.Visible := True;
  FMorphPreview.SetEditingEnabled(True);
  FMorphPreview.SetPageCaption(#$8868#$60C5#$30E2#$30FC#$30D5);
  FViewport.ReadOnly := True;
  FViewport.SetDisplayVisibility(True, False);
  FViewport.FocusPreviewFace(3.2);
end;

procedure TMmdModelSettingEditorForm.InitializeExpression(
  const ExpressionData: string);
var
  Values: TMmdNamedMorphWeights;
begin
  if FModel <> nil then
    InitializeMorphWeights(FModel, FExpressionWeights)
  else
    FExpressionWeights := nil;
  if TryDecodeMmdMorphSettingData(ExpressionData, Values) then
    ApplyMmdNamedMorphWeights(FModel, Values, FExpressionWeights);
  if FCurrentPage = mspExpression then
  begin
    FMorphPreview.SetWeights(FExpressionWeights);
    FViewport.SetMorphWeights(FExpressionWeights);
  end;
end;

procedure TMmdModelSettingEditorForm.InitializeEyeBlink(
  const EyeBlinkData: string);
var
  Setting: TMmdEyeBlinkSetting;
begin
  if FEyeBlinkPanel = nil then
    Exit;
  if not TryDecodeMmdEyeBlinkSettingData(EyeBlinkData, Setting) then
  begin
    Setting.MorphName := '';
    Setting.ClosedWeight := 0;
  end;
  FEyeBlinkPanel.LoadSetting(Setting.MorphName, Setting.ClosedWeight,
    Setting.IntervalSec, Setting.SpeedSec, Setting.OffsetSec);
end;

procedure TMmdModelSettingEditorForm.InitializeLipSync(
  const LipSyncData: string);
var
  Setting: TMmdLipSyncSetting;
begin
  if FLipSyncPanel = nil then
    Exit;
  if not TryDecodeMmdLipSyncSettingData(LipSyncData, Setting) then
    Setting := DefaultMmdLipSyncSetting;
  FLipSyncPanel.LoadSetting(Setting);
end;

function TMmdModelSettingEditorForm.EncodeExpression: string;
begin
  SaveExpressionPage;
  Result := EncodeMmdMorphSettingData(FModel, FExpressionWeights);
end;

function TMmdModelSettingEditorForm.EncodeEyeBlink: string;
begin
  if FEyeBlinkPanel = nil then
    Exit(EmptyMmdEyeBlinkSettingData);
  Result := EncodeMmdEyeBlinkSettingData(FEyeBlinkPanel.SelectedMorphName,
    FEyeBlinkPanel.ClosedWeight, FEyeBlinkPanel.IntervalSec,
    FEyeBlinkPanel.SpeedSec, FEyeBlinkPanel.OffsetSec);
end;

function TMmdModelSettingEditorForm.EncodeLipSync: string;
var
  Setting: TMmdLipSyncSetting;
begin
  if FLipSyncPanel = nil then
    Exit(EmptyMmdLipSyncSettingData);
  FLipSyncPanel.BuildSetting(Setting);
  Result := EncodeMmdLipSyncSettingData(Setting);
end;

procedure TMmdModelSettingEditorForm.ModeToolbarCustomDraw(Sender: TToolBar;
  const ARect: TRect; var DefaultDraw: Boolean);
begin
  DrawMmdModelSettingToolbar(Sender, ARect, DefaultDraw);
end;

procedure TMmdModelSettingEditorForm.ModeToolbarCustomDrawButton(
  Sender: TToolBar; Button: TToolButton; State: TCustomDrawState;
  var DefaultDraw: Boolean);
begin
  DrawMmdModelSettingToolbarButton(Sender, Button, State, FModeImages,
    DefaultDraw);
end;

procedure TMmdModelSettingEditorForm.ConfigureSettingControls(
  ShowAllPages, PoseOnly, FaceOnly: Boolean);
var
  ButtonPPI, PPI: Integer;
begin
  PPI := CurrentPPI;
  if PPI <= 0 then
    PPI := 96;
  ButtonPPI := PPI;
  if ButtonPPI > 126 then
    ButtonPPI := 126;
  if not PoseOnly and not FaceOnly then
    BuildMmdModelSettingToolbar(Self, Self, PPI, ShowAllPages,
      ModeButtonClick, ModeToolbarCustomDraw, ModeToolbarCustomDrawButton,
      FModeImages, FModeToolbar, FModeButtons);
  if ShowAllPages and not PoseOnly and not FaceOnly then
  begin
    FEyeBlinkPanel := TMmdEyeBlinkSettingPanel.Create(Self);
    FEyeBlinkPanel.Parent := FLeftPanel;
    FEyeBlinkPanel.Align := alClient;
    FEyeBlinkPanel.MatchParentFont;
    FEyeBlinkPanel.SetModel(FModel);
    FEyeBlinkPanel.OnSettingChanged := EyeBlinkSettingChanged;
    FEyeBlinkPanel.Visible := False;
    FLipSyncPanel := TMmdLipSyncSettingPanel.Create(Self);
    FLipSyncPanel.Parent := FLeftPanel;
    FLipSyncPanel.Align := alClient;
    FLipSyncPanel.MatchParentFont;
    FLipSyncPanel.SetModel(FModel);
    FLipSyncPanel.OnSettingChanged := LipSyncSettingChanged;
    FLipSyncPanel.Visible := False;
  end;
  FMorphPreview.Visible := False;
  FMorphPreview.MatchParentFont;
  FMorphPreview.OnWeightsChanged := ExpressionWeightsChanged;
  FDialogButtonPanel.Visible := False;
  FCommitPanel := TDarkPanel.Create(Self);
  FCommitPanel.Parent := Self;
  FCommitPanel.Align := alBottom;
  FCommitPanel.Height := MulDiv(55, ButtonPPI, 96);
  FCommitPanel.BevelOuter := bvNone;
  FCommitPanel.BevelKind := bkTile;
  FCommitPanel.BevelEdges := [beTop];
  FCommitPanel.ParentBackground := False;
  FCommitPanel.Color := MmdEditorPanel;
  FCommitPanel.Font.Color := MmdEditorText;
  FSaveButton := TMmdDarkButton.Create(Self);
  FSaveButton.Parent := FCommitPanel;
  FSaveButton.ParentFont := False;
  FSaveButton.Font.Assign(Font);
  FSaveButton.Caption := #$9589#$3058#$308B;
  FSaveButton.ModalResult := mrOk;
  FSaveButton.Default := True;
  FSaveButton.SetBounds(FCommitPanel.ClientWidth -
    MulDiv(127, ButtonPPI, 96), MulDiv(10, ButtonPPI, 96),
    MulDiv(111, ButtonPPI, 96), MulDiv(32, ButtonPPI, 96));
  FSaveButton.Anchors := [akTop, akRight];
  OnShow := FormShow;
  OnCloseQuery := FormCloseQuery;
  if FaceOnly then ShowSettingPage(mspExpression)
  else ShowSettingPage(mspPose);
end;

procedure TMmdModelSettingEditorForm.FormShow(Sender: TObject);
begin
  // D3D子ウィンドウ生成時の既定値を、選択中ページの表示状態で上書きする。
  ShowSettingPage(FCurrentPage);
  if FCurrentPage = mspExpression then
  begin
    // 高DPIで生成時の固定高が残らないよう、確定した左ペイン実寸へ展開する。
    FMorphPreview.Align := alNone;
    FMorphPreview.SetBounds(0, 0, FLeftPanel.ClientWidth,
      FLeftPanel.ClientHeight);
    FMorphPreview.Align := alClient;
    FLeftPanel.Realign;
  end;
end;

procedure TMmdModelSettingEditorForm.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  ModalResult := mrOk;
  CanClose := True;
end;

end.
