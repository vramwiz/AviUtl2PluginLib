unit MmdPoseEditorTools;

// ボーン一覧と編集コマンドを、プレビューに依存しない再利用可能な部品として生成する。

interface

uses
  System.Classes,
  System.Types,
  System.UITypes,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.ImgList,
  Vcl.StdCtrls,
  Vcl.ToolWin,
  DarkPanel,
  MmdMorphPreviewPanel;

type
  TMmdPoseEditorTools = class(TComponent)
  private
    FAutoFitButton: TToolButton;
    FBoneList: TListBox;
    FCommandDisabledImages: TImageList;
    FCommandImages: TImageList;
    FCommandToolbar: TToolBar;
    FLeftPanel: TDarkPanel;
    FMorphPreview: TMmdMorphPreviewPanel;
    FRedoButton: TToolButton;
    FResetAllButton: TToolButton;
    FResetBoneButton: TToolButton;
    FResetBranchButton: TToolButton;
    FSymmetryButton: TToolButton;
    FUndoButton: TToolButton;
    function AddCommand(const Caption, Hint: string;
      ImageIndex: Integer): TToolButton;
    procedure AddSeparator;
    procedure CommandToolbarCustomDraw(Sender: TToolBar; const ARect: TRect;
      var DefaultDraw: Boolean);
    procedure CommandToolbarCustomDrawButton(Sender: TToolBar;
      Button: TToolButton; State: TCustomDrawState; var DefaultDraw: Boolean);
  public
    // ツールバーと左側ペインを指定した親へ設置する。D3Dプレビューは生成しない。
    constructor CreateForParents(AOwner: TComponent;
      ToolbarParent, ListParent: TWinControl;
      ListAlign: TAlign = alLeft; WithPreviewCommands: Boolean = True);
    // 親画面のDPI変換後に文字とアイコンの寸法を揃える。
    procedure UpdateDpi(TargetPPI: Integer);
    property AutoFitButton: TToolButton read FAutoFitButton;
    property BoneList: TListBox read FBoneList;
    property CommandDisabledImages: TImageList read FCommandDisabledImages;
    property CommandImages: TImageList read FCommandImages;
    property CommandToolbar: TToolBar read FCommandToolbar;
    property LeftPanel: TDarkPanel read FLeftPanel;
    property MorphPreview: TMmdMorphPreviewPanel read FMorphPreview;
    property RedoButton: TToolButton read FRedoButton;
    property ResetAllButton: TToolButton read FResetAllButton;
    property ResetBoneButton: TToolButton read FResetBoneButton;
    property ResetBranchButton: TToolButton read FResetBranchButton;
    property SymmetryButton: TToolButton read FSymmetryButton;
    property UndoButton: TToolButton read FUndoButton;
  end;

implementation

uses
  Winapi.CommCtrl,
  Winapi.Windows,
  Vcl.Graphics,
  MmdPoseEditorTheme,
  MmdPoseEditorButtonTheme,
  MmdPoseEditorListTheme,
  MmdPoseEditorToolbarIcons;

const
  ToolbarBackground = MmdEditorPanel;
  ToolbarForeground = MmdEditorText;
  ToolbarAccent = TColor($00627DE7);
  ToolbarHot = TColor($00B03C3C);
  ToolbarPressed = TColor($001F1F1F);
  ToolbarChecked = TColor($00FF6666);
  ToolbarDisabled = TColor($00808080);

constructor TMmdPoseEditorTools.CreateForParents(AOwner: TComponent;
  ToolbarParent, ListParent: TWinControl; ListAlign: TAlign;
  WithPreviewCommands: Boolean);
begin
  inherited Create(AOwner);
  FCommandImages := TImageList.Create(Self);
  FCommandDisabledImages := TImageList.Create(Self);
  FCommandToolbar := TToolBar.Create(Self);
  FCommandToolbar.Parent := ToolbarParent;
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
  FAutoFitButton.Visible := WithPreviewCommands;

  FLeftPanel := TDarkPanel.Create(Self);
  FLeftPanel.Parent := ListParent;
  FLeftPanel.Align := ListAlign;
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
end;

function TMmdPoseEditorTools.AddCommand(const Caption, Hint: string;
  ImageIndex: Integer): TToolButton;
begin
  Result := TToolButton.Create(Self);
  Result.Parent := FCommandToolbar;
  Result.Caption := Caption;
  Result.Hint := Hint;
  Result.ShowHint := True;
  Result.ImageIndex := ImageIndex;
end;

procedure TMmdPoseEditorTools.AddSeparator;
var
  Separator: TToolButton;
begin
  Separator := TToolButton.Create(Self);
  Separator.Parent := FCommandToolbar;
  Separator.Style := tbsSeparator;
  Separator.Width := 8;
end;

procedure TMmdPoseEditorTools.UpdateDpi(TargetPPI: Integer);
begin
  if TargetPPI <= 0 then TargetPPI := 96;
  FMorphPreview.MatchParentFont;
  BuildMmdPoseEditorToolbarIcons(FCommandImages,
    MulDiv(20, TargetPPI, 96), ToolbarForeground, ToolbarAccent);
  BuildMmdPoseEditorToolbarIcons(FCommandDisabledImages,
    MulDiv(20, TargetPPI, 96), ToolbarDisabled, ToolbarDisabled);
  FCommandToolbar.Images := FCommandImages;
end;

procedure TMmdPoseEditorTools.CommandToolbarCustomDraw(Sender: TToolBar;
  const ARect: TRect; var DefaultDraw: Boolean);
begin
  Sender.Canvas.Brush.Color := ToolbarBackground;
  Sender.Canvas.FillRect(ARect);
  DefaultDraw := True;
end;

procedure TMmdPoseEditorTools.CommandToolbarCustomDrawButton(
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

end.
