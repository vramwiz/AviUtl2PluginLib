program SerifDrawFrameEditorCreationTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  PluginFilterSerifDrawCommonFrameEditorFrame in
    'Serif\Plugin\Draw\Editor\PluginFilterSerifDrawCommonFrameEditorFrame.pas'
    {FrameSerifDrawCommonFrameEditor: TFrame},
  PluginFilterSerifDrawFrameEditorBinding in
    'Serif\Plugin\Draw\Editor\PluginFilterSerifDrawFrameEditorBinding.pas',
  PluginFilterSerifDrawFrameEditorFrame in
    'Serif\Plugin\Draw\Editor\PluginFilterSerifDrawFrameEditorFrame.pas'
    {FrameSerifDrawFrameEditor: TFrame},
  PluginFilterSerifDrawTextEditorFrame in
    'Serif\Plugin\Draw\Editor\PluginFilterSerifDrawTextEditorFrame.pas'
    {FrameSerifDrawTextEditor: TFrame},
  PluginFilterSerifDrawEditorModeControl in
    'Serif\Plugin\Draw\Editor\PluginFilterSerifDrawEditorModeControl.pas',
  PluginFilterSerifDrawSettings in
    'Serif\Plugin\Draw\PluginFilterSerifDrawSettings.pas';

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

var
  CapturedStyle: TSerifDrawFrameStyle;
  CommonEditorFrame: TFrameSerifDrawCommonFrameEditor;
  EditorFrame: TFrameSerifDrawFrameEditor;
  HostForm: TForm;
  ModeControl: TSerifDrawEditorModeControl;
  TextEditorFrame: TFrameSerifDrawTextEditor;
begin
  Application.Initialize;
  HostForm := TForm.Create(nil);
  try
    EditorFrame := TFrameSerifDrawFrameEditor.Create(HostForm);
    Require(EditorFrame.Parent = nil,
      'The regression condition requires a frame without a parent window.');

    TextEditorFrame := TFrameSerifDrawTextEditor.Create(HostForm);
    Require(TextEditorFrame.Parent = nil,
      'The text editor frame must support creation without a parent window.');
    TextEditorFrame.Parent := HostForm;
    Require((TextEditorFrame.ColorPanel <> nil) and
      (TextEditorFrame.ColorPanel.ControlCount = 0),
      'The obsolete multiple-serif direction controls are still present.');

    ModeControl := TSerifDrawEditorModeControl.Create(HostForm);
    ModeControl.Parent := HostForm;
    Require(ModeControl.Width > ModeControl.Extent * 3,
      'The editor mode control must reserve three icon slots.');
    ModeControl.Mode := sdemRoleName;
    Require(ModeControl.Mode = sdemRoleName,
      'The role name placement mode could not be selected.');
    EditorFrame.Parent := HostForm;
    Require(HostForm.Handle <> 0, 'The host form handle was not created.');
    EditorFrame.InitializeControls;
    Require(EditorFrame.FrameKindComboBox.Items.Count = 3,
      'Frame kind items were not initialized after parenting.');
    Require(EditorFrame.FrameKind = sdfkNone,
      'The initial frame kind must be none.');
    EditorFrame.CommonFrameWidth := 1440;
    EditorFrame.CommonFrameHeight := 240;
    Require((EditorFrame.CommonFrameWidth = 1440) and
      (EditorFrame.CommonFrameHeight = 240),
      'Common frame dimensions did not update.');
    Require((EditorFrame.FrameKindComboBox.Items[0] = 'なし') and
      (EditorFrame.FrameKindComboBox.Items[1] = '共通') and
      (EditorFrame.FrameKindComboBox.Items[2] = 'キャラ別'),
      'Frame kind labels mismatch.');
    Require((EditorFrame.FrameShapeComboBox.Items.Count = 4) and
      (EditorFrame.FrameShapeComboBox.Items[0] = '四角') and
      (EditorFrame.FrameShapeComboBox.Items[1] = '角丸') and
      (EditorFrame.FrameShapeComboBox.Items[2] = 'タブ') and
      (EditorFrame.FrameShapeComboBox.Items[3] = '吹き出し'),
      'Frame shape labels mismatch.');
    Require(not EditorFrame.FrameShapeComboBox.Enabled and
      not EditorFrame.FrameLayeringComboBox.Enabled and
      not EditorFrame.FramePresetComboBox.Enabled and
      not EditorFrame.FrameAccentSourceComboBox.Enabled and
      not EditorFrame.FrameColorPresetComboBox.Enabled and
      not EditorFrame.FrameLayoutPresetComboBox.Enabled and
      not EditorFrame.FrameFillModeComboBox.Enabled and
      not EditorFrame.FrameGradientStrengthTrackBar.Enabled and
      not EditorFrame.FrameOutlineStyleComboBox.Enabled and
      not EditorFrame.FrameLayerComboBox.Enabled,
      'None must disable the shape and layer selectors.');
    Require(EditorFrame.CommonSettingsHostPanel.Visible and
      not EditorFrame.CommonSettingsHostPanel.Enabled,
      'None must leave the color panel visible but disabled.');
    Require((EditorFrame.CommonSettingsHostPanel.ControlCount = 1) and
      (EditorFrame.CommonSettingsHostPanel.Controls[0] is TWinControl) and
      (TWinControl(EditorFrame.CommonSettingsHostPanel.Controls[0]).ControlCount
        >= 3),
      'Frame color controls were not initialized while disabled.');
    EditorFrame.FrameKindComboBox.ItemIndex := Ord(sdfkCommon);
    EditorFrame.FrameKindComboBoxChange(EditorFrame.FrameKindComboBox);
    Require(EditorFrame.FrameShapeComboBox.Enabled and
      EditorFrame.FrameLayeringComboBox.Enabled and
      EditorFrame.FramePresetComboBox.Enabled and
      EditorFrame.FrameAccentSourceComboBox.Enabled and
      EditorFrame.FrameColorPresetComboBox.Enabled and
      EditorFrame.FrameLayoutPresetComboBox.Enabled and
      EditorFrame.FrameOutlineStyleComboBox.Enabled and
      not EditorFrame.FrameLayerComboBox.Enabled,
      'Common must enable only the shape selector.');
    Require(EditorFrame.CommonSettingsHostPanel.Visible and
      EditorFrame.CommonSettingsHostPanel.Enabled,
      'Common must enable the visible color panel.');
    EditorFrame.FrameKindComboBox.ItemIndex := 2;
    EditorFrame.FrameKindComboBoxChange(EditorFrame.FrameKindComboBox);
    Require(EditorFrame.FrameShapeComboBox.Enabled and
      EditorFrame.FrameLayeringComboBox.Enabled and
      EditorFrame.FrameOutlineStyleComboBox.Enabled and
      EditorFrame.FrameLayerComboBox.Enabled,
      'Character frames must enable both dependent selectors.');
    Require(EditorFrame.CommonSettingsHostPanel.Visible and
      EditorFrame.CommonSettingsHostPanel.Enabled,
      'Character frames must enable the visible color panel.');
    Require(EditorFrame.FrameKind = sdfkCharacter,
      'The character selector did not update the editing target.');
    EditorFrame.FrameShapeComboBox.ItemIndex := Ord(sdfsSpeechBalloon);
    EditorFrame.FrameShapeComboBoxChange(EditorFrame.FrameShapeComboBox);
    Require(EditorFrame.FrameShape = sdfsSpeechBalloon,
      'The frame shape selector did not update the editing shape.');
    Require((EditorFrame.FrameOutlineStyleComboBox.Items.Count = 4) and
      (EditorFrame.FrameOutlineStyleComboBox.Items[0] = '単線') and
      (EditorFrame.FrameOutlineStyleComboBox.Items[1] = '二重線') and
      (EditorFrame.FrameOutlineStyleComboBox.Items[2] = 'ネオン') and
      (EditorFrame.FrameOutlineStyleComboBox.Items[3] = '点線'),
      'Frame outline style labels mismatch.');
    Require((EditorFrame.FrameLayeringComboBox.Items.Count = 2) and
      (EditorFrame.FrameLayeringComboBox.Items[0] = '単層') and
      (EditorFrame.FrameLayeringComboBox.Items[1] = '内側パネル') and
      (EditorFrame.FrameLayeringComboBox.ItemIndex = 0),
      'Frame layering labels mismatch.');
    Require((EditorFrame.FramePresetComboBox.Items.Count = 8) and
      (EditorFrame.FramePresetComboBox.Items[0] = '構成プリセット') and
      (EditorFrame.FramePresetComboBox.Items[2] = 'カラー') and
      (EditorFrame.FramePresetComboBox.Items[6] = 'タブ黒') and
      (EditorFrame.FramePresetComboBox.Items[7] = '共通設定を継承'),
      'Frame preset labels mismatch.');
    EditorFrame.SetLayerFrameInherited(True);
    Require((EditorFrame.FramePresetComboBox.Items[0] = '共通枠を継承中') and
      (EditorFrame.FramePresetComboBox.ItemIndex = 0),
      'Inherited character frame status was not shown.');
    EditorFrame.SetLayerFrameInherited(False);
    Require(EditorFrame.FramePresetComboBox.Items[0] = '構成プリセット',
      'Explicit character frame status did not restore the preset label.');
    Require((EditorFrame.FrameAccentSourceComboBox.Items.Count = 2) and
      (EditorFrame.FrameAccentSourceComboBox.Items[0] = '固定色') and
      (EditorFrame.FrameAccentSourceComboBox.Items[1] = '配役色'),
      'Frame accent source labels mismatch.');
    EditorFrame.FrameAccentSourceComboBox.ItemIndex := 1;
    EditorFrame.FrameAccentSourceComboBoxChange(
      EditorFrame.FrameAccentSourceComboBox);
    CommonEditorFrame := TFrameSerifDrawCommonFrameEditor(
      EditorFrame.CommonSettingsHostPanel.Controls[0]);
    CommonEditorFrame.OnStyleChange(CommonEditorFrame);
    Require((EditorFrame.AccentSource = 0) and
      (EditorFrame.FrameAccentSourceComboBox.ItemIndex = 0),
      'Manual frame color editing did not switch to fixed colors.');
    Require((EditorFrame.FrameColorPresetComboBox.Items.Count = 11) and
      (EditorFrame.FrameColorPresetComboBox.Items[0] = '配色プリセット') and
      (EditorFrame.FrameColorPresetComboBox.Items[1] = '赤') and
      (EditorFrame.FrameColorPresetComboBox.Items[4] = '黄緑') and
      (EditorFrame.FrameColorPresetComboBox.Items[9] = '桃') and
      (EditorFrame.FrameColorPresetComboBox.Items[10] = '反転／白'),
      'Legacy frame color preset labels mismatch.');
    Require((EditorFrame.FrameLayoutPresetComboBox.Items.Count = 5) and
      (EditorFrame.FrameLayoutPresetComboBox.Items[0] = '配置プリセット') and
      (EditorFrame.FrameLayoutPresetComboBox.Items[1] = 'フル') and
      (EditorFrame.FrameLayoutPresetComboBox.Items[4] = '中'),
      'Frame layout preset labels mismatch.');
    Require((EditorFrame.FrameFillModeComboBox.Items.Count = 2) and
      (EditorFrame.FrameFillModeComboBox.Items[0] = '単色') and
      (EditorFrame.FrameFillModeComboBox.Items[1] = 'グラデーション'),
      'Frame fill mode labels mismatch.');
    EditorFrame.LoadFrameSettings(sdfkCommon, sdfsRectangle, 1, 1, 42,
      1280, 180, 32,
      18, 30,
      250, 64, 24,
      2,
      -40, 120, 70,
      True, True, True,
      $70112233, $FF445566, $6E778899, $FFABCDEF,
      1, $FFFAFAFA, 34, 22, 18, 12, 3,
      -14.5, 18.25, 9.5, 7.25);
    Require((EditorFrame.FillColor = $70112233) and
      (EditorFrame.OutlineColor = $FF445566) and
      (EditorFrame.InnerOutlineColor = $FFABCDEF) and
      (EditorFrame.Layering = 1) and
      (EditorFrame.InnerPanelColor = $FFFAFAFA) and
      (EditorFrame.InnerPanelInsetX = 34) and
      (EditorFrame.InnerPanelInsetY = 22) and
      (EditorFrame.InnerPanelRadius = 18) and
      (EditorFrame.AccentSource = 1) and
      (EditorFrame.FillMode = SERIF_FRAME_FILL_VERTICAL_GRADIENT) and
      (EditorFrame.GradientStrength = 42) and
      EditorFrame.FrameGradientStrengthTrackBar.Enabled and
      (EditorFrame.ShadowColor = $6E778899) and
      (EditorFrame.OutlineWidth = 12) and
      (EditorFrame.OutlineStyle = 3) and
      (EditorFrame.ShadowOffsetX = -14.5) and
      (EditorFrame.ShadowOffsetY = 18.25) and
      (EditorFrame.ShadowSpread = 9.5) and
      (EditorFrame.ShadowBlur = 7.25) and
      (EditorFrame.CornerRadius = 32) and
      (EditorFrame.DottedDashLength = 18) and
      (EditorFrame.DottedGapLength = 30) and
      (EditorFrame.BalloonTailPosition = -40) and
      (EditorFrame.BalloonTailDirection = 2) and
      (EditorFrame.BalloonTailWidth = 120) and
      (EditorFrame.BalloonTailLength = 70),
      'Common frame ARGB colors did not retain their alpha values.');
    CapturedStyle := CaptureSerifDrawFrameEditorStyle(EditorFrame, 7,
      -120.5, 80.25);
    Require((CapturedStyle.Layer = 7) and
      (CapturedStyle.PositionX = -120.5) and
      (CapturedStyle.PositionY = 80.25) and
      (TSerifDrawFrameShape(CapturedStyle.Shape) = sdfsRectangle) and
      (CapturedStyle.Width = 1280) and (CapturedStyle.Height = 180) and
      (CapturedStyle.TabWidth = 250) and
      (CapturedStyle.BalloonTailDirection = 2) and
      (CapturedStyle.FillColor = $70112233) and
      (CapturedStyle.FillMode = SERIF_FRAME_FILL_VERTICAL_GRADIENT) and
      (CapturedStyle.GradientStrength = 42) and
      (CapturedStyle.InnerPanelInsetX = 34) and
      (CapturedStyle.ShadowBlur = 7.25),
      'Frame editor binding did not capture the loaded style.');
    EditorFrame.FramePresetComboBox.ItemIndex := 1;
    EditorFrame.FramePresetComboBoxChange(EditorFrame.FramePresetComboBox);
    Require((EditorFrame.FrameShape = sdfsRoundedRectangle) and
      (EditorFrame.CornerRadius = 16) and (EditorFrame.Layering = 0) and
      EditorFrame.FillVisible and not EditorFrame.OutlineVisible and
      EditorFrame.FrameOutlineStyleComboBox.Enabled and
      EditorFrame.ShadowVisible and (EditorFrame.FillColor = $FFFFFFFF) and
      (EditorFrame.ShadowColor shr 24 = $A8) and
      (EditorFrame.ShadowOffsetX = 10) and
      (EditorFrame.ShadowOffsetY = 10) and
      (EditorFrame.ShadowSpread = 0) and (EditorFrame.ShadowBlur = 0),
      'White legacy frame preset mismatch.');
    EditorFrame.FrameOutlineStyleComboBox.ItemIndex := 1;
    EditorFrame.FrameOutlineStyleComboBoxChange(
      EditorFrame.FrameOutlineStyleComboBox);
    Require((EditorFrame.OutlineStyle = 1) and
      not EditorFrame.OutlineVisible and
      EditorFrame.FrameOutlineStyleComboBox.Enabled,
      'Outline style must remain editable while outline display is disabled.');
    EditorFrame.FramePresetComboBox.ItemIndex := 2;
    EditorFrame.FramePresetComboBoxChange(EditorFrame.FramePresetComboBox);
    Require((EditorFrame.FrameShape = sdfsRectangle) and
      (EditorFrame.Layering = 1) and EditorFrame.FillVisible and
      not EditorFrame.OutlineVisible and EditorFrame.ShadowVisible and
      (EditorFrame.FillColor = $FF445566) and
      (EditorFrame.InnerPanelColor = $FFFFFFFF) and
      (EditorFrame.InnerPanelInsetX = 28) and
      (EditorFrame.InnerPanelInsetY = 20) and
      (EditorFrame.InnerPanelRadius = 16) and
      (EditorFrame.ShadowColor shr 24 = $A8) and
      (EditorFrame.ShadowOffsetX = 6) and
      (EditorFrame.ShadowOffsetY = 6) and
      (EditorFrame.FramePresetComboBox.ItemIndex = 0),
      'Color legacy frame preset mismatch.');
    EditorFrame.FrameColorPresetComboBox.ItemIndex := 1;
    EditorFrame.FrameColorPresetComboBoxChange(
      EditorFrame.FrameColorPresetComboBox);
    Require((EditorFrame.FillColor = $FFF8D6D6) and
      (EditorFrame.OutlineColor = $FFF2A7A7) and
      (EditorFrame.InnerOutlineColor = $FFF2A7A7) and
      (EditorFrame.InnerPanelColor = $FFFFFFFF) and
      (EditorFrame.ShadowColor = $A8D97C7C) and
      (EditorFrame.AccentSource = 0) and
      (EditorFrame.FrameAccentSourceComboBox.ItemIndex = 0) and
      (EditorFrame.FrameColorPresetComboBox.ItemIndex = 0),
      'Pastel color preset did not reproduce the legacy color frame.');
    EditorFrame.FramePresetComboBox.ItemIndex := 3;
    EditorFrame.FramePresetComboBoxChange(EditorFrame.FramePresetComboBox);
    Require((EditorFrame.FrameShape = sdfsRectangle) and
      (EditorFrame.Layering = 0) and EditorFrame.OutlineVisible and
      (EditorFrame.OutlineStyle = 2) and (EditorFrame.OutlineWidth = 8) and
      not EditorFrame.ShadowVisible and
      (EditorFrame.FillColor = $FF101010),
      'Black legacy frame preset mismatch.');
    EditorFrame.FrameColorPresetComboBox.ItemIndex := 7;
    EditorFrame.FrameColorPresetComboBoxChange(
      EditorFrame.FrameColorPresetComboBox);
    Require((EditorFrame.FillColor = $FF101010) and
      (EditorFrame.OutlineColor = $FF0060B0) and
      (EditorFrame.InnerOutlineColor = $FF0080FF) and
      (EditorFrame.AccentSource = 0),
      'Neon color preset did not reproduce the legacy black frame.');
    EditorFrame.FramePresetComboBox.ItemIndex := 4;
    EditorFrame.FramePresetComboBoxChange(EditorFrame.FramePresetComboBox);
    Require((EditorFrame.FrameShape = sdfsSpeechBalloon) and
      (EditorFrame.CornerRadius = 16) and
      (EditorFrame.BalloonTailDirection = 2) and
      (EditorFrame.BalloonTailPosition = EditorFrame.CommonFrameHeight div 4) and
      (EditorFrame.BalloonTailWidth = 56) and
      (EditorFrame.BalloonTailLength = 48) and
      EditorFrame.ShadowVisible and (EditorFrame.ShadowColor shr 24 = $A8) and
      (EditorFrame.ShadowOffsetX = 10) and
      (EditorFrame.ShadowOffsetY = 10),
      'Speech-balloon legacy frame preset mismatch.');
    EditorFrame.FramePresetComboBox.ItemIndex := 5;
    EditorFrame.FramePresetComboBoxChange(EditorFrame.FramePresetComboBox);
    Require((EditorFrame.FrameShape = sdfsTab) and
      (EditorFrame.CornerRadius = 18) and
      (EditorFrame.TabWidth = 250) and (EditorFrame.TabHeight = 64) and
      (EditorFrame.TabOffset = 24) and EditorFrame.OutlineVisible and
      (EditorFrame.OutlineStyle = 0) and (EditorFrame.OutlineWidth = 8) and
      EditorFrame.ShadowVisible and (EditorFrame.ShadowColor shr 24 = $A8),
      'White-tab legacy frame preset mismatch.');
    EditorFrame.FramePresetComboBox.ItemIndex := 6;
    EditorFrame.FramePresetComboBoxChange(EditorFrame.FramePresetComboBox);
    Require((EditorFrame.FrameShape = sdfsTab) and
      (EditorFrame.CornerRadius = 18) and
      (EditorFrame.TabWidth = 250) and (EditorFrame.TabHeight = 64) and
      (EditorFrame.TabOffset = 24) and EditorFrame.OutlineVisible and
      (EditorFrame.OutlineStyle = 2) and (EditorFrame.OutlineWidth = 8) and
      not EditorFrame.ShadowVisible and
      (EditorFrame.FillColor = $FF101010),
      'Black-tab legacy frame preset mismatch.');
  finally
    HostForm.Free;
  end;
  Writeln('SerifDraw frame editor creation test passed.');
end.
