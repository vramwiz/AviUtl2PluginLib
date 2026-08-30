unit MmdModelSettingDialogs;

// モデル設定フォームの生成、初期化、モーダル確定、結果回収を呼出側へ提供する。

interface

// ポーズと表情を同じフォームで編集し、確定時だけ両データを返す。
function EditMmdModelSettings(const ModelFileName, CurrentPoseData,
  CurrentExpressionData, EditorCaption: string; out NewPoseData,
  NewExpressionData: string; ShowAllPages: Boolean = False): Boolean;
// 初期状態の全ページを編集し、確定時だけポーズ、表情、目パチ、口パクを返す。
function EditMmdInitialStateSettings(const ModelFileName, CurrentPoseData,
  CurrentExpressionData, CurrentEyeBlinkData, CurrentLipSyncData,
  EditorCaption: string; out NewPoseData, NewExpressionData, NewEyeBlinkData,
  NewLipSyncData: string): Boolean;
// PMX管理と同じ設定フォームをページ切替なしのポーズ専用構成で開き、
// 閉じた時点の姿勢だけを返す。
function EditMmdPoseOnlySettings(const ModelFileName, CurrentPoseData,
  EditorCaption: string; out NewPoseData: string): Boolean;
// 共通フォームをページ切替なしの表情専用構成で開き、閉じた時点の
// モーフ設定だけを返す。
function EditMmdFaceOnlySettings(const ModelFileName, CurrentFaceData,
  EditorCaption: string; out NewFaceData: string): Boolean;

implementation

uses
  Vcl.Controls,
  MmdModelSettingEditor,
  MmdMorphSettingCodec;

function EditMmdModelSettings(const ModelFileName, CurrentPoseData,
  CurrentExpressionData, EditorCaption: string; out NewPoseData,
  NewExpressionData: string; ShowAllPages: Boolean): Boolean;
var
  ExpressionData: string;
  Form: TMmdModelSettingEditorForm;
  PoseData: string;
begin
  Result := False;
  NewPoseData := CurrentPoseData;
  NewExpressionData := CurrentExpressionData;
  PoseData := CurrentPoseData;
  if PoseData = '' then
    PoseData := '{"version":1,"bones":[]}';
  ExpressionData := CurrentExpressionData;
  if ExpressionData = '' then
    ExpressionData := EmptyMmdMorphSettingData;
  Form := TMmdModelSettingEditorForm.CreateEditor(ModelFileName, PoseData,
    EditorCaption);
  try
    Form.ConfigureSettingControls(ShowAllPages);
    Form.InitializeExpression(ExpressionData);
    if Form.ShowModal <> mrOk then
      Exit;
    NewPoseData := Form.EncodeCurrentPose;
    NewExpressionData := Form.EncodeExpression;
    Result := True;
  finally
    Form.Free;
  end;
end;

function EditMmdInitialStateSettings(const ModelFileName, CurrentPoseData,
  CurrentExpressionData, CurrentEyeBlinkData, CurrentLipSyncData,
  EditorCaption: string; out NewPoseData, NewExpressionData, NewEyeBlinkData,
  NewLipSyncData: string): Boolean;
var
  Form: TMmdModelSettingEditorForm;
  PoseData: string;
begin
  Result := False;
  NewPoseData := CurrentPoseData;
  NewExpressionData := CurrentExpressionData;
  NewEyeBlinkData := CurrentEyeBlinkData;
  NewLipSyncData := CurrentLipSyncData;
  PoseData := CurrentPoseData;
  if PoseData = '' then
    PoseData := '{"version":1,"bones":[]}';
  Form := TMmdModelSettingEditorForm.CreateEditor(ModelFileName, PoseData,
    EditorCaption);
  try
    Form.ConfigureSettingControls(True);
    Form.InitializeExpression(CurrentExpressionData);
    Form.InitializeEyeBlink(CurrentEyeBlinkData);
    Form.InitializeLipSync(CurrentLipSyncData);
    if Form.ShowModal <> mrOk then
      Exit;
    NewPoseData := Form.EncodeCurrentPose;
    NewExpressionData := Form.EncodeExpression;
    NewEyeBlinkData := Form.EncodeEyeBlink;
    NewLipSyncData := Form.EncodeLipSync;
    Result := True;
  finally
    Form.Free;
  end;
end;

function EditMmdPoseOnlySettings(const ModelFileName, CurrentPoseData,
  EditorCaption: string; out NewPoseData: string): Boolean;
var
  Form: TMmdModelSettingEditorForm;
  PoseData: string;
begin
  Result := False;
  NewPoseData := CurrentPoseData;
  PoseData := CurrentPoseData;
  if PoseData = '' then PoseData := '{"version":1,"bones":[]}';
  Form := TMmdModelSettingEditorForm.CreateEditor(ModelFileName, PoseData,
    EditorCaption);
  try
    Form.ConfigureSettingControls(False, True);
    if Form.ShowModal <> mrOk then Exit;
    NewPoseData := Form.EncodeCurrentPose;
    Result := True;
  finally
    Form.Free;
  end;
end;

function EditMmdFaceOnlySettings(const ModelFileName, CurrentFaceData,
  EditorCaption: string; out NewFaceData: string): Boolean;
var
  FaceData: string;
  Form: TMmdModelSettingEditorForm;
begin
  Result := False;
  NewFaceData := CurrentFaceData;
  FaceData := CurrentFaceData;
  if FaceData = '' then FaceData := EmptyMmdMorphSettingData;
  Form := TMmdModelSettingEditorForm.CreateEditor(ModelFileName,
    '{"version":1,"bones":[]}', EditorCaption);
  try
    Form.ConfigureSettingControls(False, False, True);
    Form.InitializeExpression(FaceData);
    if Form.ShowModal <> mrOk then Exit;
    NewFaceData := Form.EncodeExpression;
    Result := True;
  finally
    Form.Free;
  end;
end;

end.
