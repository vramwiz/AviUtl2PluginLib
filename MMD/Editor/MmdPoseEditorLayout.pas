unit MmdPoseEditorLayout;

// ポーズ編集フォームの静的なVCLコントロール構成と配置だけを生成する。

interface

uses
  System.Types,
  System.UITypes,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.ImgList,
  Vcl.StdCtrls,
  Vcl.ToolWin,
  DarkPanel,
  MmdD3DViewport,
  MmdMorphPreviewPanel,
  MmdPoseEditorTools;

type
  TMmdPoseEditorFormBase = class(TForm)
  protected
    FAutoFitButton: TToolButton;
    FBoneList: TListBox;
    FCommandDisabledImages: TImageList;
    FCommandImages: TImageList;
    FCommandToolbar: TToolBar;
    FDialogButtonPanel: TDarkPanel;
    FLeftPanel: TDarkPanel;
    FMorphPreview: TMmdMorphPreviewPanel;
    FRedoButton: TToolButton;
    FResetAllButton: TToolButton;
    FResetBoneButton: TToolButton;
    FResetBranchButton: TToolButton;
    FSymmetryButton: TToolButton;
    FTools: TMmdPoseEditorTools;
    FUndoButton: TToolButton;
    FViewport: TMmdD3DViewport;
    procedure CreateWnd; override;
    // 既に現在DPIへ調整済みのVCL標準フォントは維持し、配置寸法だけを変換する。
    procedure ScaleLayoutForPPI(TargetPPI: Integer);
  public
    // モデル非依存のボーン一覧、操作ボタン、D3D表示領域を配置する。
    constructor CreateLayout(const EditorCaption: string);
  end;

implementation

uses
  Winapi.Windows,
  System.Math,
  Vcl.Graphics,
  MmdPoseEditorTheme,
  MmdPoseEditorButtonTheme;

type
  // TControl.Fontはprotectedのため、DPI変換前後の高さを共通に扱う。
  TControlAccess = class(TControl);

  TControlFontSnapshot = record
    Control: TControl;
    Height: Integer;
  end;

  TControlFontSnapshots = TArray<TControlFontSnapshot>;

procedure TMmdPoseEditorFormBase.CreateWnd;
begin
  inherited;
  ApplyMmdDarkTitleBar(Self);
end;

procedure TMmdPoseEditorFormBase.ScaleLayoutForPPI(TargetPPI: Integer);
var
  FontSnapshots: TControlFontSnapshots;
  I: Integer;

  procedure CaptureFonts(Control: TControl);
  var
    ChildIndex, SnapshotIndex: Integer;
    ParentControl: TWinControl;
  begin
    SnapshotIndex := Length(FontSnapshots);
    SetLength(FontSnapshots, SnapshotIndex + 1);
    FontSnapshots[SnapshotIndex].Control := Control;
    FontSnapshots[SnapshotIndex].Height := TControlAccess(Control).Font.Height;
    if Control is TWinControl then
    begin
      ParentControl := TWinControl(Control);
      for ChildIndex := 0 to ParentControl.ControlCount - 1 do
        CaptureFonts(ParentControl.Controls[ChildIndex]);
    end;
  end;
begin
  if TargetPPI <= 0 then
    TargetPPI := 96;
  CaptureFonts(Self);

  // CreateNew直後の各Control.Fontは既にWindowsの現在DPI向けである。
  // そのままScaleForPPIすると子コントロールの文字まで再度拡大されるため、
  // 一旦96 DPI相当へ戻してから配置と一緒に変換する。
  for I := 0 to High(FontSnapshots) do
    TControlAccess(FontSnapshots[I].Control).Font.Height := MulDiv(
      FontSnapshots[I].Height, 96, TargetPPI);
  ScaleForPPI(TargetPPI);
  // 丸め誤差を含め、作成時にWindowsが選んだ正しいフォント高へ揃える。
  for I := 0 to High(FontSnapshots) do
    TControlAccess(FontSnapshots[I].Control).Font.Height :=
      FontSnapshots[I].Height;
  FTools.UpdateDpi(TargetPPI);
end;

constructor TMmdPoseEditorFormBase.CreateLayout(const EditorCaption: string);
var
  CancelButton, OkButton: TMmdDarkButton;
begin
  inherited CreateNew(nil);
  Caption := EditorCaption;
  Position := poScreenCenter;
  Width := 980;
  Height := 680;
  Constraints.MinWidth := 800;
  Constraints.MinHeight := 630;
  BorderStyle := bsSizeable;
  KeyPreview := True;
  Color := MmdEditorBackground;
  Font.Color := MmdEditorText;

  FTools := TMmdPoseEditorTools.CreateForParents(Self, Self, Self);
  FCommandImages := FTools.CommandImages;
  FCommandDisabledImages := FTools.CommandDisabledImages;
  FCommandToolbar := FTools.CommandToolbar;
  FUndoButton := FTools.UndoButton;
  FRedoButton := FTools.RedoButton;
  FResetBoneButton := FTools.ResetBoneButton;
  FResetBranchButton := FTools.ResetBranchButton;
  FResetAllButton := FTools.ResetAllButton;
  FSymmetryButton := FTools.SymmetryButton;
  FAutoFitButton := FTools.AutoFitButton;
  FLeftPanel := FTools.LeftPanel;
  FMorphPreview := FTools.MorphPreview;
  FBoneList := FTools.BoneList;

  // 数値ボーン編集パネルは持たない。確定操作だけを独立した下端バーに置く。
  FDialogButtonPanel := TDarkPanel.Create(Self);
  FDialogButtonPanel.Parent := Self;
  FDialogButtonPanel.Align := alBottom;
  FDialogButtonPanel.Height := 55;
  FDialogButtonPanel.BevelOuter := bvNone;
  FDialogButtonPanel.ParentBackground := False;
  FDialogButtonPanel.Color := MmdEditorPanel;
  OkButton := TMmdDarkButton.Create(Self);
  OkButton.Parent := FDialogButtonPanel;
  OkButton.Caption := 'OK';
  OkButton.ModalResult := mrOk;
  OkButton.Default := True;
  OkButton.SetBounds(FDialogButtonPanel.ClientWidth - 215, 10, 95, 32);
  OkButton.Anchors := [akTop, akRight];
  CancelButton := TMmdDarkButton.Create(Self);
  CancelButton.Parent := FDialogButtonPanel;
  CancelButton.Caption := 'キャンセル';
  CancelButton.ModalResult := mrCancel;
  CancelButton.Cancel := True;
  CancelButton.SetBounds(FDialogButtonPanel.ClientWidth - 111, 10, 95, 32);
  CancelButton.Anchors := [akTop, akRight];

  FViewport := TMmdD3DViewport.Create(Self);
  FViewport.Parent := Self;
  FViewport.Align := alClient;

  // CreateNewで実行時生成したControlは、Bounds設定後のDFM読込スケーリングを
  // 通らない。全配置が揃ってから96 DPI基準の寸法を現在DPIへ一度だけ変換する。
  // Form.Fontは生成時点ですでに現在DPI用なので、二重には拡大しない。
  ScaleLayoutForPPI(Screen.PixelsPerInch);
end;

end.
