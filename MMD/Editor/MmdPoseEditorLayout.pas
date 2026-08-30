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
  MmdMorphPreviewPanel;

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
    FUndoButton: TToolButton;
    FViewport: TMmdD3DViewport;
    procedure CommandToolbarCustomDraw(Sender: TToolBar; const ARect: TRect;
      var DefaultDraw: Boolean);
    procedure CommandToolbarCustomDrawButton(Sender: TToolBar;
      Button: TToolButton; State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure CreateWnd; override;
    // 既に現在DPIへ調整済みのVCL標準フォントは維持し、配置寸法だけを変換する。
    procedure ScaleLayoutForPPI(TargetPPI: Integer);
  public
    // モデル非依存のボーン一覧、操作ボタン、D3D表示領域を配置する。
    constructor CreateLayout(const EditorCaption: string);
  end;

implementation

uses
  Winapi.CommCtrl,
  Winapi.Windows,
  System.Math,
  Vcl.Graphics,
  MmdPoseEditorTheme,
  MmdPoseEditorButtonTheme,
  MmdPoseEditorListTheme,
  MmdPoseEditorToolbarIcons;

type
  // TControl.Fontはprotectedのため、DPI変換前後の高さを共通に扱う。
  TControlAccess = class(TControl);

  TControlFontSnapshot = record
    Control: TControl;
    Height: Integer;
  end;

  TControlFontSnapshots = TArray<TControlFontSnapshot>;

const
  ToolbarBackground = MmdEditorPanel;
  ToolbarForeground = MmdEditorText;
  ToolbarAccent = TColor($00627DE7);
  ToolbarHot = TColor($00B03C3C);
  ToolbarPressed = TColor($001F1F1F);
  ToolbarChecked = TColor($00FF6666);
  ToolbarDisabled = TColor($00808080);

procedure TMmdPoseEditorFormBase.CommandToolbarCustomDraw(Sender: TToolBar;
  const ARect: TRect; var DefaultDraw: Boolean);
begin
  Sender.Canvas.Brush.Color := ToolbarBackground;
  Sender.Canvas.FillRect(ARect);
  // Trueを返してネイティブ描画を継続し、各ボタンのCustomDrawを呼ばせる。
  DefaultDraw := True;
end;

procedure TMmdPoseEditorFormBase.CreateWnd;
begin
  inherited;
  ApplyMmdDarkTitleBar(Self);
end;

procedure TMmdPoseEditorFormBase.CommandToolbarCustomDrawButton(
  Sender: TToolBar; Button: TToolButton; State: TCustomDrawState;
  var DefaultDraw: Boolean);
var
  ButtonRect: TRect;
  Color: TColor;
begin
  if (not Sender.HandleAllocated) or
    (Sender.Perform(TB_GETITEMRECT, Button.Index,
      LPARAM(@ButtonRect)) = 0) then
    ButtonRect := Button.BoundsRect;
  if cdsChecked in State then
    Color := ToolbarChecked
  else if cdsSelected in State then
    Color := ToolbarPressed
  else if cdsHot in State then
    Color := ToolbarHot
  else
    Color := ToolbarBackground;
  Sender.Canvas.Brush.Color := Color;
  Sender.Canvas.FillRect(ButtonRect);
  if (Button.Style <> tbsSeparator) and Assigned(Sender.Images) and
    (Button.ImageIndex >= 0) and (Button.ImageIndex < Sender.Images.Count) then
  begin
    // ImageListの標準無効描画は暗色背景ではグリフも黒くなって消えるため、
    // 無効状態専用に生成した灰色アイコンを通常描画する。
    if Button.Enabled then
      FCommandImages.Draw(Sender.Canvas,
        ButtonRect.Left + (ButtonRect.Width - FCommandImages.Width) div 2,
        ButtonRect.Top + (ButtonRect.Height - FCommandImages.Height) div 2,
        Button.ImageIndex, True)
    else
      FCommandDisabledImages.Draw(Sender.Canvas,
        ButtonRect.Left + (ButtonRect.Width - FCommandDisabledImages.Width) div 2,
        ButtonRect.Top + (ButtonRect.Height - FCommandDisabledImages.Height) div 2,
        Button.ImageIndex, True);
  end;
  DefaultDraw := False;
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
  FMorphPreview.MatchParentFont;
  BuildMmdPoseEditorToolbarIcons(FCommandImages,
    MulDiv(20, TargetPPI, 96), ToolbarForeground, ToolbarAccent);
  BuildMmdPoseEditorToolbarIcons(FCommandDisabledImages,
    MulDiv(20, TargetPPI, 96), ToolbarDisabled, ToolbarDisabled);
  FCommandToolbar.Images := FCommandImages;
end;

constructor TMmdPoseEditorFormBase.CreateLayout(const EditorCaption: string);
var
  CancelButton, OkButton: TMmdDarkButton;
  Separator: TToolButton;

  function AddCommand(const Caption, Hint: string;
    ImageIndex: Integer): TToolButton;
  begin
    Result := TToolButton.Create(Self);
    Result.Parent := FCommandToolbar;
    Result.Caption := Caption;
    Result.Hint := Hint;
    Result.ShowHint := True;
    Result.ImageIndex := ImageIndex;
  end;

  procedure AddSeparator;
  begin
    Separator := TToolButton.Create(Self);
    Separator.Parent := FCommandToolbar;
    Separator.Style := tbsSeparator;
    Separator.Width := 8;
  end;

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

  FCommandImages := TImageList.Create(Self);
  FCommandDisabledImages := TImageList.Create(Self);
  FCommandToolbar := TToolBar.Create(Self);
  FCommandToolbar.Parent := Self;
  FCommandToolbar.Align := alTop;
  FCommandToolbar.Height := 30;
  FCommandToolbar.ButtonWidth := 30;
  FCommandToolbar.ButtonHeight := 30;
  FCommandToolbar.Color := ToolbarBackground;
  FCommandToolbar.Font.Color := ToolbarForeground;
  FCommandToolbar.Flat := True;
  FCommandToolbar.ShowCaptions := False;
  FCommandToolbar.ShowHint := True;
  FCommandToolbar.Wrapable := False;
  FCommandToolbar.OnCustomDraw := CommandToolbarCustomDraw;
  FCommandToolbar.OnCustomDrawButton := CommandToolbarCustomDrawButton;

  FUndoButton := AddCommand('元に戻す', '元に戻す (Ctrl+Z)', 0);
  FRedoButton := AddCommand('やり直す', 'やり直す (Ctrl+Y)', 1);
  AddSeparator;
  FResetBoneButton := AddCommand('選択ボーンを初期化',
    '選択ボーンを初期化', 2);
  FResetBranchButton := AddCommand('選択枝を初期化',
    '選択ボーンから先を初期化', 3);
  FResetAllButton := AddCommand('全ボーンを初期化',
    '全ボーンを初期化', 4);
  AddSeparator;
  FSymmetryButton := AddCommand('左右対称編集',
    '左右対称編集のオン／オフ', 5);
  FSymmetryButton.Style := tbsCheck;
  FSymmetryButton.AllowAllUp := True;
  FAutoFitButton := AddCommand('画像へ概形合わせ',
    '貼り付けた参照画像へ概形を合わせる', 6);
  FAutoFitButton.Enabled := False;

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

  FLeftPanel := TDarkPanel.Create(Self);
  FLeftPanel.Parent := Self;
  FLeftPanel.Align := alLeft;
  FLeftPanel.Width := 245;
  FLeftPanel.BevelOuter := bvNone;
  FLeftPanel.ParentBackground := False;
  FLeftPanel.Color := MmdEditorBackground;

  FMorphPreview := TMmdMorphPreviewPanel.Create(Self);
  FMorphPreview.Parent := FLeftPanel;
  FMorphPreview.Align := alBottom;

  FBoneList := TMmdDarkListBox.Create(Self);
  FBoneList.Parent := FLeftPanel;
  FBoneList.Align := alClient;

  FViewport := TMmdD3DViewport.Create(Self);
  FViewport.Parent := Self;
  FViewport.Align := alClient;

  // CreateNewで実行時生成したControlは、Bounds設定後のDFM読込スケーリングを
  // 通らない。全配置が揃ってから96 DPI基準の寸法を現在DPIへ一度だけ変換する。
  // Form.Fontは生成時点ですでに現在DPI用なので、二重には拡大しない。
  ScaleLayoutForPPI(Screen.PixelsPerInch);
end;

end.
