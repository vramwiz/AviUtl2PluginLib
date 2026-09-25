unit MmdPoseEditor;

// モデル標準姿勢とポーズオブジェクトの姿勢を、共通の骨格GUIで編集する。

interface

uses
  System.Classes,
  System.UITypes,
  MmdPoseEditorLayout,
  MmdPoseEditSession,
  MmdPoseHistory,
  PmxModel,
  PmxPose;

type
  // MMDプラグインと単体アプリが共有する、編集動作まで含んだフォーム。
  // 派生側はLoadEditorModelでモデルとJSONを切り替え、PoseStateChangedで
  // アプリ固有の保存処理などを追加できる。
  TStandardPoseEditorForm = class(TMmdPoseEditorFormBase)
  private
    procedure AutoFitClick(Sender: TObject);
    procedure BoneChanged(Sender: TObject);
    procedure ResetAllClick(Sender: TObject);
    procedure ResetBranchClick(Sender: TObject);
    procedure ResetBoneClick(Sender: TObject);
    procedure RedoClick(Sender: TObject);
    procedure SymmetryChanged(Sender: TObject);
    procedure UndoClick(Sender: TObject);
    procedure ViewportBoneSelected(Sender: TObject);
    procedure ViewportPoseChanged(Sender: TObject);
    procedure ViewportPoseEditFinished(Sender: TObject);
    procedure ViewportPoseEditStarted(Sender: TObject);
    procedure InitializeEditor;
    procedure MorphWeightsChanged(Sender: TObject);
    procedure UpdateHistoryButtons;
  protected
    FEditSession: TMmdPoseEditSession;
    FHistory: TMmdPoseHistory;
    FModel: TPmxModel;
    FPoses: TPmxBonePoses;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure PoseStateChanged; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateEditor(const ModelFileName, PoseData,
      EditorCaption: string);
    destructor Destroy; override;
    // 外部生成された完全な姿勢JSONを現在モデルへ適用し、1回のUndoで戻せるようにする。
    function ApplyExternalPose(const PoseData: string): Boolean;
    function EncodeCurrentPose: string;
    procedure LoadEditorModel(AModel: TPmxModel; const PoseData: string);
  end;

// PMXと現在の姿勢JSONを読み込み、OK時だけ更新後のJSONを返す。
function EditPose(const ModelFileName, CurrentPoseData, EditorCaption: string;
  out NewPoseData: string): Boolean;

implementation

uses
  System.Math,
  System.SysUtils,
  Vcl.Dialogs,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  MmdPoseImageAutoFit,
  MmdPoseImageClipboard,
  PmxMorph,
  PmxReader;

constructor TStandardPoseEditorForm.Create(AOwner: TComponent);
begin
  inherited CreateLayout('MMD ポーズ編集');
  InitializeEditor;
end;

procedure TStandardPoseEditorForm.InitializeEditor;
begin
  FEditSession := TMmdPoseEditSession.Create;
  FHistory := FEditSession.History;
  FBoneList.OnClick := BoneChanged;
  FMorphPreview.OnWeightsChanged := MorphWeightsChanged;
  FAutoFitButton.OnClick := AutoFitClick;
  FResetBoneButton.OnClick := ResetBoneClick;
  FResetBranchButton.OnClick := ResetBranchClick;
  FResetAllButton.OnClick := ResetAllClick;
  FSymmetryButton.OnClick := SymmetryChanged;
  FUndoButton.OnClick := UndoClick;
  FRedoButton.OnClick := RedoClick;
  FViewport.OnBoneSelected := ViewportBoneSelected;
  FViewport.OnPoseChanged := ViewportPoseChanged;
  FViewport.OnPoseEditFinished := ViewportPoseEditFinished;
  FViewport.OnPoseEditStarted := ViewportPoseEditStarted;

  UpdateHistoryButtons;
end;

constructor TStandardPoseEditorForm.CreateEditor(const ModelFileName,
  PoseData, EditorCaption: string);
begin
  inherited CreateLayout(EditorCaption);
  InitializeEditor;
  LoadEditorModel(GetCachedPmxModel(ModelFileName), PoseData);
end;

procedure TStandardPoseEditorForm.LoadEditorModel(AModel: TPmxModel;
  const PoseData: string);
var
  BoneIndex: Integer;
begin
  FModel := AModel;
  FEditSession.Load(FModel, PoseData, FPoses);
  FHistory := FEditSession.History;
  FBoneList.Clear;
  FMorphPreview.SetModel(FModel);
  if FModel = nil then
  begin
    FViewport.SetScene(nil, FPoses, -1);
    UpdateHistoryButtons;
    Exit;
  end;

  for BoneIndex := 0 to High(FModel.Bones) do
    FBoneList.Items.Add(FModel.Bones[BoneIndex].Name);

  if FBoneList.Count > 0 then
  begin
    FBoneList.ItemIndex := 0;
    FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  end;
  UpdateHistoryButtons;
end;

procedure TStandardPoseEditorForm.PoseStateChanged;
begin
end;

procedure TStandardPoseEditorForm.AutoFitClick(Sender: TObject);
var
  BeforePoses: TPmxBonePoses;
begin
  if not FViewport.HasReferenceImage then
    Exit;
  BeforePoses := Copy(FPoses);
  FAutoFitButton.Enabled := False;
  Screen.Cursor := crHourGlass;
  try
    if AutoFitPoseToReference(FModel, FViewport, FBoneList.ItemIndex,
      FPoses) then
    begin
      FHistory.RecordBeforeEdit(BeforePoses);
      UpdateHistoryButtons;
      PoseStateChanged;
    end
    else
      MessageDlg('参照画像との差を改善できませんでした。'#13#10 +
        '現在姿勢が近い場合、または画像差が大きい場合は手動で調整してください。',
        mtInformation, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
    FAutoFitButton.Enabled := FViewport.HasReferenceImage;
  end;
end;

procedure TStandardPoseEditorForm.MorphWeightsChanged(Sender: TObject);
var
  Weights: TPmxMorphWeights;
begin
  FMorphPreview.CopyWeights(Weights);
  FViewport.SetMorphWeights(Weights);
end;

destructor TStandardPoseEditorForm.Destroy;
begin
  FEditSession.Free;
  inherited Destroy;
end;

function TStandardPoseEditorForm.ApplyExternalPose(
  const PoseData: string): Boolean;
begin
  Result := FEditSession.ApplyExternal(FModel, PoseData, FPoses);
  if not Result then Exit;
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  UpdateHistoryButtons;
  PoseStateChanged;
end;

procedure TStandardPoseEditorForm.SymmetryChanged(Sender: TObject);
begin
  FViewport.SymmetricEditing := FSymmetryButton.Down;
end;

procedure TStandardPoseEditorForm.UpdateHistoryButtons;
begin
  FUndoButton.Enabled := FHistory.CanUndo;
  FRedoButton.Enabled := FHistory.CanRedo;
end;

procedure TStandardPoseEditorForm.ViewportPoseEditStarted(Sender: TObject);
begin
  FHistory.RecordBeforeEdit(FPoses);
  UpdateHistoryButtons;
end;

procedure TStandardPoseEditorForm.ViewportPoseEditFinished(Sender: TObject);
begin
  UpdateHistoryButtons;
  PoseStateChanged;
end;

procedure TStandardPoseEditorForm.UndoClick(Sender: TObject);
begin
  if not FEditSession.Undo(FPoses) then Exit;
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  UpdateHistoryButtons;
  PoseStateChanged;
end;

procedure TStandardPoseEditorForm.RedoClick(Sender: TObject);
begin
  if not FEditSession.Redo(FPoses) then Exit;
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  UpdateHistoryButtons;
  PoseStateChanged;
end;

procedure TStandardPoseEditorForm.KeyDown(var Key: Word; Shift: TShiftState);
var
  Bitmap: TBitmap;
begin
  if ssCtrl in Shift then
    case Key of
      Ord('Z'):
        begin
          UndoClick(Self);
          Key := 0;
          Exit;
        end;
      Ord('Y'):
        begin
          RedoClick(Self);
          Key := 0;
          Exit;
        end;
      Ord('C'):
        if not (ActiveControl is TCustomEdit) then
        begin
          if not CopyModelImageToClipboard(FViewport) then
            MessageDlg('モデル画像をクリップボードへコピーできませんでした。',
              mtError, [mbOK], 0);
          Key := 0;
          Exit;
        end;
      Ord('V'):
        if not (ActiveControl is TCustomEdit) then
        begin
          Bitmap := TBitmap.Create;
          try
            if PasteImageFromClipboard(Bitmap) then
            begin
              FViewport.SetReferenceImage(Bitmap);
              FAutoFitButton.Enabled := True;
            end
            else
              MessageDlg('クリップボードに貼り付け可能な画像がありません。',
                mtInformation, [mbOK], 0);
          finally
            Bitmap.Free;
          end;
          Key := 0;
          Exit;
        end;
    end;
  inherited KeyDown(Key, Shift);
end;

procedure TStandardPoseEditorForm.ViewportBoneSelected(Sender: TObject);
begin
  FBoneList.ItemIndex := FViewport.SelectedBone;
  FBoneList.TopIndex := Max(FBoneList.ItemIndex - 5, 0);
end;

procedure TStandardPoseEditorForm.ViewportPoseChanged(Sender: TObject);
begin
  FViewport.CopyPoses(FPoses);
end;

procedure TStandardPoseEditorForm.BoneChanged(Sender: TObject);
begin
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
end;

procedure TStandardPoseEditorForm.ResetBoneClick(Sender: TObject);
begin
  if FBoneList.ItemIndex < 0 then Exit;
  FEditSession.ResetBone(FModel, FBoneList.ItemIndex,
    FSymmetryButton.Down, FPoses);
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  UpdateHistoryButtons;
  PoseStateChanged;
end;

procedure TStandardPoseEditorForm.ResetBranchClick(Sender: TObject);
begin
  if FBoneList.ItemIndex < 0 then Exit;
  FEditSession.ResetBranch(FModel, FBoneList.ItemIndex,
    FSymmetryButton.Down, FPoses);
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  UpdateHistoryButtons;
  PoseStateChanged;
end;

procedure TStandardPoseEditorForm.ResetAllClick(Sender: TObject);
begin
  FEditSession.ResetAll(FModel, FPoses);
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  UpdateHistoryButtons;
  PoseStateChanged;
end;

function TStandardPoseEditorForm.EncodeCurrentPose: string;
begin
  Result := FEditSession.Encode(FModel, FPoses);
end;

function EditPose(const ModelFileName, CurrentPoseData, EditorCaption: string;
  out NewPoseData: string): Boolean;
var
  Form: TStandardPoseEditorForm;
begin
  Result := False;
  NewPoseData := CurrentPoseData;
  Form := TStandardPoseEditorForm.CreateEditor(ModelFileName, CurrentPoseData,
    EditorCaption);
  try
    if Form.ShowModal <> mrOk then
      Exit;
    NewPoseData := Form.EncodeCurrentPose;
    Result := True;
  finally
    Form.Free;
  end;
end;

end.
