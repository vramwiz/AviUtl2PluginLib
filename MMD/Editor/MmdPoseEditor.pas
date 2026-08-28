unit MmdPoseEditor;

// モデル標準姿勢とポーズオブジェクトの姿勢を、共通の骨格GUIで編集する。

interface

uses
  System.Classes,
  System.UITypes,
  MmdPoseEditorLayout,
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
  MmdPoseEditOperations,
  MmdPoseImageAutoFit,
  MmdPoseImageClipboard,
  MmdPoseSymmetry,
  PmxMorph,
  PmxPoseCodec,
  PmxReader;

function IsIdentity(const Pose: TPmxBonePose): Boolean;
begin
  Result := (Abs(Pose.Translation.X) < 0.000001) and
    (Abs(Pose.Translation.Y) < 0.000001) and
    (Abs(Pose.Translation.Z) < 0.000001) and
    (Abs(Pose.Rotation.X) < 0.000001) and
    (Abs(Pose.Rotation.Y) < 0.000001) and
    (Abs(Pose.Rotation.Z) < 0.000001) and
    (Abs(Abs(Pose.Rotation.W) - 1.0) < 0.000001);
end;

constructor TStandardPoseEditorForm.Create(AOwner: TComponent);
begin
  inherited CreateLayout('MMD ポーズ編集');
  InitializeEditor;
end;

procedure TStandardPoseEditorForm.InitializeEditor;
begin
  FHistory := TMmdPoseHistory.Create;
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
  NamedPoses: TPmxNamedBonePoses;
begin
  FModel := AModel;
  FHistory.Free;
  FHistory := TMmdPoseHistory.Create;
  FBoneList.Clear;
  SetLength(FPoses, 0);
  FMorphPreview.SetModel(FModel);
  if FModel = nil then
  begin
    FViewport.SetScene(nil, FPoses, -1);
    UpdateHistoryButtons;
    Exit;
  end;

  InitializeBonePoses(FModel, FPoses);
  if TryDecodePoseData(PoseData, NamedPoses) then
    ApplyNamedBonePoses(FModel, NamedPoses, FPoses);
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
  FHistory.Free;
  inherited Destroy;
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
var
  Restored: TPmxBonePoses;
begin
  if not FHistory.Undo(FPoses, Restored) then
    Exit;
  FPoses := Restored;
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  UpdateHistoryButtons;
  PoseStateChanged;
end;

procedure TStandardPoseEditorForm.RedoClick(Sender: TObject);
var
  Restored: TPmxBonePoses;
begin
  if not FHistory.Redo(FPoses, Restored) then
    Exit;
  FPoses := Restored;
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
var
  BeforePoses: TPmxBonePoses;
  MirrorIndex: Integer;
begin
  if FBoneList.ItemIndex < 0 then
    Exit;
  BeforePoses := Copy(FPoses);
  FPoses[FBoneList.ItemIndex] := Default(TPmxBonePose);
  FPoses[FBoneList.ItemIndex].Rotation := IdentityQuaternion;
  if FSymmetryButton.Down then
  begin
    MirrorIndex := FindSymmetricBone(FModel, FBoneList.ItemIndex);
    if MirrorIndex >= 0 then
      FPoses[MirrorIndex] := MirrorBonePose(FPoses[FBoneList.ItemIndex]);
  end;
  FHistory.RecordBeforeEdit(BeforePoses);
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  UpdateHistoryButtons;
  PoseStateChanged;
end;

procedure TStandardPoseEditorForm.ResetBranchClick(Sender: TObject);
var
  BeforePoses: TPmxBonePoses;
  MirrorIndex: Integer;
begin
  if FBoneList.ItemIndex < 0 then
    Exit;
  BeforePoses := Copy(FPoses);
  ResetBoneBranch(FModel, FBoneList.ItemIndex, FPoses);
  if FSymmetryButton.Down then
  begin
    MirrorIndex := FindSymmetricBone(FModel, FBoneList.ItemIndex);
    if MirrorIndex >= 0 then
      ResetBoneBranch(FModel, MirrorIndex, FPoses);
  end;
  FHistory.RecordBeforeEdit(BeforePoses);
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  UpdateHistoryButtons;
  PoseStateChanged;
end;

procedure TStandardPoseEditorForm.ResetAllClick(Sender: TObject);
var
  BeforePoses: TPmxBonePoses;
begin
  BeforePoses := Copy(FPoses);
  InitializeBonePoses(FModel, FPoses);
  FHistory.RecordBeforeEdit(BeforePoses);
  FViewport.SetScene(FModel, FPoses, FBoneList.ItemIndex);
  UpdateHistoryButtons;
  PoseStateChanged;
end;

function TStandardPoseEditorForm.EncodeCurrentPose: string;
var
  BoneIndex: Integer;
  Count: Integer;
  NamedPoses: TPmxNamedBonePoses;
begin
  Count := 0;
  SetLength(NamedPoses, Length(FPoses));
  for BoneIndex := 0 to High(FPoses) do
    if not IsIdentity(FPoses[BoneIndex]) then
    begin
      NamedPoses[Count].BoneName := FModel.Bones[BoneIndex].Name;
      NamedPoses[Count].Pose := FPoses[BoneIndex];
      Inc(Count);
    end;
  SetLength(NamedPoses, Count);
  Result := EncodePoseData(NamedPoses);
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
