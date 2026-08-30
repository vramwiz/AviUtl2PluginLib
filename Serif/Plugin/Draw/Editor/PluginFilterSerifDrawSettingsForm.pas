unit PluginFilterSerifDrawSettingsForm;

// セリフ文字と枠の設定編集、プレビュー操作、入力検証をまとめる設定フォームを提供する。

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  FormattingToolbarButtons,
  PluginFilterSerifDrawColorPicker,
  PluginFilterSerifDrawEditorModeControl,
  PluginFilterSerifDrawFrameEditorFrame,
  PluginFilterSerifDrawFramePreview,
  PluginFilterSerifDrawPlacementPopup,
  PluginFilterSerifDrawReceiver,
  PluginFilterSerifDrawSettings,
  PluginFilterSerifDrawTextPreviewDrag,
  PluginFilterSerifDrawTextPreviewLayout,
  PluginFilterSerifDrawTextEditorFrame,
  TextRenderer,
  TextRendererTypes,
  TransparencyTrackControl;

type
  // カラーピッカーで編集する文字装飾の対象。
  TSerifDrawColorTarget = (
    sctText,
    sctOutline,
    sctShadow,
    sctBlur
  );

  // 不透明度トラックで編集する文字装飾の対象。
  TSerifDrawOpacityTarget = (
    sotText,
    sotOutline,
    sotShadow,
    sotBlur
  );

  TFormSerifDrawSettings = class(TForm)
    ColorPanel: TPanel;
    FontComboBox: TComboBox;
    LayerComboBox: TComboBox;
    ModePanel: TPanel;
    PreviewPaintBox: TPaintBox;
    TopPanel: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure LayerComboBoxChange(Sender: TObject);
    procedure LayerComboBoxDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure PreviewPaintBoxDblClick(Sender: TObject);
    procedure PreviewPaintBoxMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PreviewPaintBoxMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure PreviewPaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PreviewPaintBoxPaint(Sender: TObject);
    procedure StyleEditChange(Sender: TObject);
  private
    FBackground: TBitmap;
    FBackgroundPreview: TBitmap;
    FBackBuffer: TBitmap;
    FColorPicker: TSerifDrawColorPickerControl;
    FColorTarget: TSerifDrawColorTarget;
    FColorTargetToolbar: TFormattingToolbarButtons;
    FDirect2DEnabled: Boolean;
    FDraggingPan: Boolean;
    FDraggingPreview: Boolean;
    FDragButton: TMouseButton;
    FDragMode: TSerifPreviewDragMode;
    FFrameDragHit: TSerifDrawFrameHit;
    FFrameDragStartPositionX: Double;
    FFrameDragStartPositionY: Double;
    FFrameDragStartCornerRadius: Integer;
    FFrameDragStartDottedDashLength: Integer;
    FFrameDragStartDottedGapLength: Integer;
    FFrameDragStartInnerPanelInsetX: Integer;
    FFrameDragStartInnerPanelInsetY: Integer;
    FFrameDragStartInnerPanelRadius: Integer;
    FFrameDragStartOutlineWidth: Integer;
    FFrameDragStartShadowOffsetX: Double;
    FFrameDragStartShadowOffsetY: Double;
    FFrameDragStartShadowBlur: Double;
    FFrameDragStartShadowSpread: Double;
    FFrameDragStartHeight: Integer;
    FFrameDragStartWidth: Integer;
    FFrameDragStartTabHeight: Integer;
    FFrameDragStartTabOffset: Integer;
    FFrameDragStartTabWidth: Integer;
    FFrameDragStartBalloonTailLength: Integer;
    FFrameDragStartBalloonTailPosition: Integer;
    FFrameDragStartBalloonTailWidth: Integer;
    FCommonFramePositionX: Double;
    FCommonFramePositionY: Double;
    FDragStartMouse: TPoint;
    FDragStartOffset: TPoint;
    FDragStartFontSize: Double;
    FDragStartLetterSpacing: Double;
    FDragStartLineSpacing: Double;
    FDragStartOutlineBlur: Double;
    FDragStartOutlineWidth: Double;
    FDragStartPositionX: Double;
    FDragStartPositionY: Double;
    FDragStartShadowOffsetX: Double;
    FDragStartShadowOffsetY: Double;
    FDragStartShadowBlur: Double;
    FDragStartShadowSpread: Double;
    FDragSnapXActive: Boolean;
    FDragSnapYActive: Boolean;
    FDragSnapYValue: Double;
    FFitToWindow: Boolean;
    FFormattingToolbar: TFormattingToolbarButtons;
    FEditorModeControl: TSerifDrawEditorModeControl;
    FEditingFrameDirty: Boolean;
    FEditingFrameExplicit: Boolean;
    FEditingFrameKind: TSerifDrawFrameKind;
    FEditingFrameLayer: Integer;
    FEditingFrameRoleName: string;
    FFrameEditorFrame: TFrameSerifDrawFrameEditor;
    FOffset: TPoint;
    FCompanionPreviewBitmap: TBitmap;
    FCompanionPreviewImage: TTextRenderImage;
    FCompanionPreviewRenderScale: Double;
    FPreviewBitmap: TBitmap;
    FPreviewDragScale: Double;
    FPreviewImage: TTextRenderImage;
    FPreviewRenderScale: Double;
    FPreviewRenderer: TCustomTextRenderer;
    FPreviewSelected: Boolean;
    FOpacityTrack: TTransparencyTrackControl;
    FOpacityTarget: TSerifDrawOpacityTarget;
    FOpacityTargetToolbar: TFormattingToolbarButtons;
    FPlacementPopup: TSerifDrawPlacementPopup;
    FSelectedSnapshotIndex: Integer;
    FSettings: TSerifDrawSettings;
    FSnapshots: TArray<TSerifDrawSnapshot>;
    FUpdatingControls: Boolean;
    FZoomPercent: Integer;
    FToolbarBold: TFormattingToolbarButton;
    FToolbarBlurColor: TFormattingToolbarButton;
    FToolbarFillColor: TFormattingToolbarButton;
    FToolbarItalic: TFormattingToolbarButton;
    FToolbarOutline: TFormattingToolbarButton;
    FToolbarOutlineColor: TFormattingToolbarButton;
    FToolbarOpacityBlur: TFormattingToolbarButton;
    FToolbarOpacityOutline: TFormattingToolbarButton;
    FToolbarOpacityShadow: TFormattingToolbarButton;
    FToolbarOpacityText: TFormattingToolbarButton;
    FToolbarPlacement: TFormattingToolbarButton;
    FToolbarResetSelectedColor: TFormattingToolbarButton;
    FToolbarRoleNameVisible: TFormattingToolbarButton;
    FToolbarShadow: TFormattingToolbarButton;
    FToolbarShadowColor: TFormattingToolbarButton;
    FTextEditorFrame: TFrameSerifDrawTextEditor;
    procedure ApplyDarkTheme;
    function BackgroundDestinationRect: TRect;
    procedure EnsureBackgroundPreview(const ADestination: TRect);
    procedure EnsureBackBuffer;
    procedure CreateFormattingToolbar;
    procedure CreateEditorFrames;
    procedure CreateEditorModeControl;
    procedure CreateColorPicker;
    procedure CreateColorTargetToolbar;
    procedure CreateOpacityTargetToolbar;
    procedure CreateTransparencyTracks;
    procedure LoadAvailableFonts;
    procedure LayoutDpiControls;
    procedure FitImage;
    function HitTestPreview(const APoint: TPoint): TSerifPreviewDragMode;
    function CommonFramePreviewRect: TRect;
    function FrameCornerRadiusHandleRect: TRect;
    function FrameTabRect: TRect;
    function FrameTabOffsetHandleRect: TRect;
    function FrameTabWidthHandleRect: TRect;
    function FrameTabHeightHandleRect: TRect;
    function FrameBalloonTipHandleRect: TRect;
    function FrameBalloonWidthHandleRect: TRect;
    function FrameBalloonWidthCursor: TCursor;
    function FrameDottedDashHandleRect: TRect;
    function FrameDottedGapHandleRect: TRect;
    function FrameInnerPanelInsetXHandleRect: TRect;
    function FrameInnerPanelInsetYHandleRect: TRect;
    function FrameInnerPanelRadiusHandleRect: TRect;
    function FrameOutlineWidthHandleRect: TRect;
    function FrameShadowOffsetHandleRect: TRect;
    function FrameShadowSpreadHandleRect: TRect;
    function FrameShadowBlurHandleRect: TRect;
    procedure FrameEditorSettingsChange(Sender: TObject);
    procedure FrameEditorLayoutPreset(Sender: TObject;
      const APreset: Integer);
    procedure FrameEditorResetLayerFrame(Sender: TObject);
    function FrameEditorSelectedLayer: Integer;
    function FrameEditorSelectedRoleName: string;
    function RoleNameForLayer(const ALayer: Integer): string;
    procedure LoadFrameEditorTarget(const AKind: TSerifDrawFrameKind;
      const ALayer: Integer; const ARoleName: string);
    procedure StoreFrameEditorTarget;
    function IsCommonFrameEditorActive: Boolean;
    function IsFrameEditorActive: Boolean;
    function IsRoleNameEditorActive: Boolean;
    function EditingPlacement: Byte;
    function EditingPositionX: Double;
    function EditingPositionY: Double;
    function EditingTextStyle(const ALayer: Integer;
      const ARoleName: string = ''): TSerifDrawLayerStyle;
    function HasColorOverride(const ALayer: Integer;
      const ARoleName: Boolean): Boolean;
    procedure SetEditingPosition(const AX, AY: Double);
    function TextPreviewHandleLayout: TSerifDrawTextPreviewLayout;
    function CommitSelectedStyle(out AError: string): Boolean;
    procedure ApplyColorsToSelectedLayer(const AStyle: TSerifDrawLayerStyle);
    procedure LoadSelectedStyle;
    procedure ColorPickerChange(Sender: TObject);
    procedure ColorTargetExecute(Sender: TObject;
      Button: TFormattingToolbarButton);
    procedure PlacementSelected(Sender: TObject; const APlacement: Byte);
    function CompanionPreviewDestinationRect: TRect;
    function PreviewDestinationRect: TRect;
    function PreviewLayoutRect: TRect;
    function PaintPreviewDirect2D: Boolean;
    procedure PaintPreviewGdi;
    procedure RenderSelectedPreview(const ARenderCompanion: Boolean = True);
    procedure SetPreviewCursor(const AMode: TSerifPreviewDragMode);
    procedure UpdateDraggedStyle(const AFontSize, ALineSpacing,
      ALetterSpacing: Double);
    procedure UpdateDraggedShadowOffset(const AOffsetX, AOffsetY: Double);
    procedure UpdateDraggedOutlineBlur(const ABlur: Double);
    procedure UpdateDraggedOutlineWidth(const AWidth: Double);
    procedure UpdateDraggedShadowBlur(const ABlur: Double);
    procedure UpdateDraggedShadowSpread(const ASpread: Double);
    function CreatePreviewBitmap(const AImage: TTextRenderImage):
      Vcl.Graphics.TBitmap;
    procedure UpdatePreviewBitmap(const AImage: TTextRenderImage);
    procedure UpdatePlacementButton;
    procedure UpdateColorPicker;
    procedure UpdateTransparencyTracks;
    procedure UpdateToolbarColorAccents;
    procedure UpdateResetSelectedColorButton;
    procedure TransparencyTrackChange(Sender: TObject);
    procedure FormattingToolbarExecute(Sender: TObject;
      Button: TFormattingToolbarButton);
    procedure EditorModeChange(Sender: TObject);
    procedure ShowEditorMode(const AMode: TSerifDrawEditorMode);
  protected
    procedure Resize; override;
  public
    // 設定一式を通知や保存を発生させずに画面へ読み込む。
    procedure LoadSettings(const ASettings: TSerifDrawSettings);
    // 受信済みセリフを置き換え、現在の選択とプレビュー候補を更新する。
    procedure SetSnapshots(const ASnapshots: TArray<TSerifDrawSnapshot>);
    // 幅×高さ×4バイトのRGBA画像をプレビュー背景としてコピーする。
    procedure SetBackgroundRgba(const Pixels: TBytes; Width, Height: Integer);
    // AviUtl2からの背景取得状態をデバッグログへ記録する。
    procedure SetCaptureStatus(const Value: string);
    // 画面の入力を検証して設定へ書き戻し、失敗時はFalseと理由を返す。
    function TryGetSettings(out ASettings: TSerifDrawSettings;
      out AError: string): Boolean;
  end;

implementation

uses
  System.Math,
  System.UITypes,
  PluginFilterSerifDrawDebugLog,
  PluginFilterSerifDrawFrameEditorBinding,
  PluginFilterSerifDrawFramePreviewDrag,
  PluginFilterSerifDrawPlacement,
  PluginFilterSerifDrawRoleNames,
  PluginFilterSerifDrawSettingsTheme,
  PluginFilterSerifDrawTextPreviewHandles,
  TextRendererSkia,
  Vcl.Direct2D,
  Vcl.Dialogs,
  Winapi.D2D1,
  Winapi.DwmApi,
  Winapi.Windows;

{$R *.dfm}

type
  TControlAccess = class(TControl);

const
  PREVIEW_HANDLE_SIZE = 7;

procedure TFormSerifDrawSettings.ApplyDarkTheme;
const
  DARK_BACKGROUND = SERIF_DRAW_BACKGROUND_COLOR;
  DARK_PANEL = SERIF_DRAW_PANEL_COLOR;
  DARK_TEXT = SERIF_DRAW_TEXT_COLOR;
  DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
  DWMWA_USE_IMMERSIVE_DARK_MODE_OLD = 19;
var
  Enabled: BOOL;
begin
  Color := DARK_BACKGROUND;
  Font.Color := DARK_TEXT;
  ModePanel.ParentBackground := False;
  ModePanel.Color := DARK_PANEL;
  ModePanel.Font.Color := DARK_TEXT;
  TopPanel.ParentBackground := False;
  TopPanel.Color := DARK_PANEL;
  TopPanel.Font.Color := DARK_TEXT;
  ColorPanel.ParentBackground := False;
  ColorPanel.Color := DARK_PANEL;
  FontComboBox.Color := SERIF_DRAW_CONTROL_COLOR;
  FontComboBox.Font.Color := DARK_TEXT;
  FontComboBox.StyleElements := FontComboBox.StyleElements - [seClient];
  LayerComboBox.Color := DARK_PANEL;
  LayerComboBox.Font.Color := DARK_TEXT;
  LayerComboBox.StyleElements := LayerComboBox.StyleElements - [seClient];
  FFrameEditorFrame.ApplyDarkTheme;
  Enabled := True;
  if DwmSetWindowAttribute(Handle, DWMWA_USE_IMMERSIVE_DARK_MODE,
    @Enabled, SizeOf(Enabled)) <> S_OK then
    DwmSetWindowAttribute(Handle, DWMWA_USE_IMMERSIVE_DARK_MODE_OLD,
      @Enabled, SizeOf(Enabled));
end;

procedure TFormSerifDrawSettings.CreateEditorFrames;
begin
  FTextEditorFrame := TFrameSerifDrawTextEditor.Create(Self);
  FTextEditorFrame.Parent := Self;
  FTextEditorFrame.Align := alClient;

  FFrameEditorFrame := TFrameSerifDrawFrameEditor.Create(Self);
  FFrameEditorFrame.Parent := Self;
  FFrameEditorFrame.Align := alClient;
  FFrameEditorFrame.Visible := False;
  FFrameEditorFrame.OnSettingsChange := FrameEditorSettingsChange;
  FFrameEditorFrame.OnLayoutPreset := FrameEditorLayoutPreset;
  FFrameEditorFrame.OnResetLayerFrame := FrameEditorResetLayerFrame;

  TopPanel := FTextEditorFrame.TopPanel;
  ColorPanel := FTextEditorFrame.ColorPanel;
  FontComboBox := FTextEditorFrame.FontComboBox;
  LayerComboBox := FTextEditorFrame.LayerComboBox;

  FontComboBox.OnChange := StyleEditChange;
  FontComboBox.OnDrawItem := LayerComboBoxDrawItem;
  LayerComboBox.OnChange := LayerComboBoxChange;
  LayerComboBox.OnDrawItem := LayerComboBoxDrawItem;

  PreviewPaintBox.Parent := FTextEditorFrame.PreviewHostPanel;
  PreviewPaintBox.Align := alClient;
end;

procedure TFormSerifDrawSettings.CreateEditorModeControl;
var
  Extent: Integer;
begin
  Extent := MulDiv(28, CurrentPPI, 96);
  FEditorModeControl := TSerifDrawEditorModeControl.Create(Self);
  FEditorModeControl.Parent := ModePanel;
  FEditorModeControl.Extent := Extent;
  FEditorModeControl.Hint :=
    '文字配置／配役名配置／枠の編集画面を切り替えます';
  FEditorModeControl.ShowHint := True;
  FEditorModeControl.OnChange := EditorModeChange;
end;

procedure TFormSerifDrawSettings.CreateFormattingToolbar;
var
  Extent: Integer;
begin
  if TopPanel = nil then
    Exit;
  Extent := MulDiv(28, CurrentPPI, 96);
  FFormattingToolbar := TFormattingToolbarButtons.Create(Self);
  FFormattingToolbar.Parent := TopPanel;
  ApplySerifDrawToolbarTheme(FFormattingToolbar);
  FFormattingToolbar.SetBounds(MulDiv(344, CurrentPPI, 96),
    MulDiv(38, CurrentPPI, 96), MulDiv(470, CurrentPPI, 96), Extent);
  FFormattingToolbar.ButtonExtent := Extent;
  FFormattingToolbar.SeparatorExtent := MulDiv(6, CurrentPPI, 96);
  FFormattingToolbar.Color := TopPanel.Color;
  FFormattingToolbar.OnButtonExecute := FormattingToolbarExecute;
  FToolbarRoleNameVisible := FFormattingToolbar.AddToggleButton(
    '配役名を表示', tbgVisibility, 14);
  FToolbarRoleNameVisible.Visible := False;
  FToolbarBold := FFormattingToolbar.AddToggleButton('太字', tbgBold, 2);
  FToolbarItalic := FFormattingToolbar.AddToggleButton('斜体', tbgItalic, 3);
  FFormattingToolbar.AddSeparator;
  FToolbarOutline := FFormattingToolbar.AddToggleButton('縁取り',
    tbgOutline, 5);
  FToolbarShadow := FFormattingToolbar.AddToggleButton('影', tbgShadow, 6);
  FFormattingToolbar.AddSeparator;
  FToolbarPlacement := FFormattingToolbar.AddDialogButton('文字配置：中央',
    tbgPlacementCenter, 11);
  FToolbarResetSelectedColor := FFormattingToolbar.AddCommandButton(
    '選択レイヤーの色をリセット', tbgResetSelected, 12);
  FFormattingToolbar.AddCommandButton('すべてリセット', tbgResetAll, 13);
end;

procedure TFormSerifDrawSettings.LayoutDpiControls;
var
  ComboTop: Integer;
  Extent: Integer;
  FontLeft: Integer;
  FontWidth: Integer;
  Gap: Integer;
  I: Integer;
  LayerWidth: Integer;
  Margin: Integer;
  MinLayerWidth: Integer;
  OpacityTop: Integer;
  PickerHeight: Integer;
  SelectorTop: Integer;
  ToolbarLeft: Integer;
  ToolbarWidth: Integer;
begin
  Extent := MulDiv(28, CurrentPPI, 96);
  Gap := MulDiv(6, CurrentPPI, 96);
  Margin := MulDiv(8, CurrentPPI, 96);
  PickerHeight := Max(Extent, ColorPanel.ClientWidth - Margin * 2 -
    MulDiv(24, CurrentPPI, 96));
  ModePanel.Height := MulDiv(38, CurrentPPI, 96);
  TopPanel.Height := MulDiv(38, CurrentPPI, 96);

  if FEditorModeControl <> nil then
  begin
    FEditorModeControl.Extent := Extent;
    FEditorModeControl.SetBounds(Margin,
      (ModePanel.ClientHeight - Extent) div 2,
      FEditorModeControl.Width, Extent);
  end;

  if FFormattingToolbar <> nil then
  begin
    FFormattingToolbar.ButtonExtent := Extent;
    FFormattingToolbar.SeparatorExtent := MulDiv(6, CurrentPPI, 96);
    ToolbarWidth := 0;
    for I := 0 to FFormattingToolbar.ItemCount - 1 do
      if FFormattingToolbar.Items[I].Kind = tbkSeparator then
        Inc(ToolbarWidth, FFormattingToolbar.SeparatorExtent)
      else
        Inc(ToolbarWidth, Extent);
    ToolbarLeft := Max(Margin, TopPanel.ClientWidth - Margin - ToolbarWidth);
    FFormattingToolbar.SetBounds(ToolbarLeft,
      (TopPanel.ClientHeight - Extent) div 2, ToolbarWidth, Extent);

    MinLayerWidth := MulDiv(160, CurrentPPI, 96);
    FontWidth := Min(MulDiv(180, CurrentPPI, 96),
      Max(MulDiv(100, CurrentPPI, 96), ToolbarLeft - Margin - Gap * 2 -
        MinLayerWidth));
    FontLeft := ToolbarLeft - Gap - FontWidth;
    ComboTop := (TopPanel.ClientHeight - FontComboBox.Height) div 2;
    FontComboBox.SetBounds(FontLeft, ComboTop, FontWidth,
      FontComboBox.Height);
    LayerWidth := Max(Extent, FontLeft - Gap - Margin);
    LayerComboBox.SetBounds(Margin,
      (TopPanel.ClientHeight - LayerComboBox.Height) div 2,
      LayerWidth, LayerComboBox.Height);
  end;
  if FColorPicker <> nil then
  begin
    FColorPicker.Margins.Left := Margin;
    FColorPicker.Margins.Top := Margin;
    FColorPicker.Margins.Right := Margin;
    FColorPicker.Margins.Bottom := Margin;
    FColorPicker.Height := PickerHeight;
  end;
  if FColorTargetToolbar <> nil then
  begin
    OpacityTop := ColorPanel.ClientHeight - Margin -
      PickerHeight - Gap - Extent;
    FOpacityTrack.SetBounds(Margin, OpacityTop,
      Max(Extent, ColorPanel.ClientWidth - Margin * 2), Extent);
    SelectorTop := OpacityTop - Gap - Extent;
    FColorTargetToolbar.ButtonExtent := Extent;
    FColorTargetToolbar.SetBounds(Margin, SelectorTop,
      Max(Extent, ColorPanel.ClientWidth - Margin * 2), Extent);
  end;
end;

procedure TFormSerifDrawSettings.CreateColorPicker;
begin
  FColorPicker := TSerifDrawColorPickerControl.Create(Self);
  FColorPicker.Parent := ColorPanel;
  FColorPicker.AlignWithMargins := True;
  FColorPicker.Margins.Left := MulDiv(8, CurrentPPI, 96);
  FColorPicker.Margins.Top := MulDiv(8, CurrentPPI, 96);
  FColorPicker.Margins.Right := MulDiv(8, CurrentPPI, 96);
  FColorPicker.Margins.Bottom := MulDiv(8, CurrentPPI, 96);
  FColorPicker.Align := alBottom;
  FColorPicker.Height := Max(MulDiv(28, CurrentPPI, 96),
    ColorPanel.ClientWidth - MulDiv(16 + 24, CurrentPPI, 96));
  FColorPicker.OnChange := ColorPickerChange;
end;

procedure TFormSerifDrawSettings.CreateColorTargetToolbar;
var
  Extent: Integer;
begin
  Extent := MulDiv(28, CurrentPPI, 96);
  FColorTargetToolbar := TFormattingToolbarButtons.Create(Self);
  FColorTargetToolbar.Parent := ColorPanel;
  ApplySerifDrawToolbarTheme(FColorTargetToolbar);
  FColorTargetToolbar.ButtonExtent := Extent;
  FColorTargetToolbar.SeparatorExtent := 0;
  FColorTargetToolbar.Color := ColorPanel.Color;
  FColorTargetToolbar.OnButtonExecute := ColorTargetExecute;
  FToolbarFillColor := FColorTargetToolbar.AddToggleButton(
    '文字色の透明度と色', tbgBeforeColor, Ord(sotText));
  FToolbarOpacityText := FToolbarFillColor;
  FToolbarFillColor.HasAccentColor := True;
  FToolbarOutlineColor := FColorTargetToolbar.AddToggleButton(
    '縁取り色の透明度と色', tbgAfterColor, Ord(sotOutline));
  FToolbarOpacityOutline := FToolbarOutlineColor;
  FToolbarOutlineColor.HasAccentColor := True;
  FToolbarShadowColor := FColorTargetToolbar.AddToggleButton(
    '影色の透明度と色', tbgShadowColor, Ord(sotShadow));
  FToolbarOpacityShadow := FToolbarShadowColor;
  FToolbarShadowColor.HasAccentColor := True;
  FToolbarBlurColor := FColorTargetToolbar.AddToggleButton(
    'ぼかし色の透明度と色', tbgBlurColor, Ord(sotBlur));
  FToolbarOpacityBlur := FToolbarBlurColor;
  FToolbarBlurColor.HasAccentColor := True;
end;

procedure TFormSerifDrawSettings.CreateOpacityTargetToolbar;
begin
  // 透明度と色の対象はFColorTargetToolbarへ統合する。
  FOpacityTargetToolbar := nil;
end;

procedure TFormSerifDrawSettings.CreateTransparencyTracks;
begin
  FOpacityTrack := TTransparencyTrackControl.Create(Self);
  FOpacityTrack.Parent := ColorPanel;
  FOpacityTrack.SetBounds(MulDiv(8, CurrentPPI, 96), 0,
    Max(MulDiv(28, CurrentPPI, 96),
      ColorPanel.ClientWidth - MulDiv(16, CurrentPPI, 96)),
    MulDiv(28, CurrentPPI, 96));
  FOpacityTrack.BackgroundColor := ColorPanel.Color;
  FOpacityTrack.GlyphColor := SERIF_DRAW_ICON_GLYPH_COLOR;
  FOpacityTrack.Font.Assign(Font);
  FOpacityTrack.Caption := '';
  FOpacityTrack.OnChange := TransparencyTrackChange;
end;

procedure TFormSerifDrawSettings.LoadAvailableFonts;
var
  FontName: string;
  I: Integer;
begin
  FontComboBox.Items.BeginUpdate;
  try
    FontComboBox.Items.Clear;
    for I := 0 to Screen.Fonts.Count - 1 do
    begin
      FontName := Screen.Fonts[I];
      if (FontName <> '') and (FontName[1] <> '@') then
        FontComboBox.Items.Add(FontName);
    end;
  finally
    FontComboBox.Items.EndUpdate;
  end;
  SerifDrawDebugLog(Format('Available fonts loaded: vcl=%d listed=%d',
    [Screen.Fonts.Count, FontComboBox.Items.Count]));
end;

function TFormSerifDrawSettings.BackgroundDestinationRect: TRect;
var
  DrawHeight: Integer;
  DrawWidth: Integer;
  Scale: Double;
begin
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit(Rect(0, 0, 0, 0));
  Scale := Min(PreviewPaintBox.ClientWidth / FBackground.Width,
    PreviewPaintBox.ClientHeight / FBackground.Height) * FZoomPercent / 100;
  DrawWidth := Max(1, Round(FBackground.Width * Scale));
  DrawHeight := Max(1, Round(FBackground.Height * Scale));
  Result.Left := (PreviewPaintBox.ClientWidth - DrawWidth) div 2 + FOffset.X;
  Result.Top := (PreviewPaintBox.ClientHeight - DrawHeight) div 2 + FOffset.Y;
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

procedure TFormSerifDrawSettings.EnsureBackBuffer;
begin
  if (FBackBuffer.Width <> PreviewPaintBox.ClientWidth) or
    (FBackBuffer.Height <> PreviewPaintBox.ClientHeight) then
    FBackBuffer.SetSize(Max(1, PreviewPaintBox.ClientWidth),
      Max(1, PreviewPaintBox.ClientHeight));
end;

procedure TFormSerifDrawSettings.EnsureBackgroundPreview(
  const ADestination: TRect);
begin
  if (ADestination.Width <= 0) or (ADestination.Height <= 0) or
    (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  if (FBackgroundPreview.Width = ADestination.Width) and
    (FBackgroundPreview.Height = ADestination.Height) then
    Exit;
  FBackgroundPreview.SetSize(ADestination.Width, ADestination.Height);
  SetStretchBltMode(FBackgroundPreview.Canvas.Handle, HALFTONE);
  FBackgroundPreview.Canvas.StretchDraw(
    Rect(0, 0, ADestination.Width, ADestination.Height), FBackground);
end;

procedure TFormSerifDrawSettings.FitImage;
begin
  FFitToWindow := True;
  FZoomPercent := 100;
  FOffset := Point(0, 0);
  FDraggingPan := False;
  FDraggingPreview := False;
  FDragMode := spdmNone;
  TControlAccess(PreviewPaintBox).MouseCapture := False;
  PreviewPaintBox.Cursor := crDefault;
  PreviewPaintBox.Invalidate;
end;

procedure TFormSerifDrawSettings.FormCreate(Sender: TObject);
begin
  CreateEditorFrames;
  ApplyDarkTheme;
  FBackground := Vcl.Graphics.TBitmap.Create;
  FBackgroundPreview := Vcl.Graphics.TBitmap.Create;
  FBackgroundPreview.PixelFormat := pf32bit;
  FBackBuffer := Vcl.Graphics.TBitmap.Create;
  FBackBuffer.PixelFormat := pf32bit;
  FCompanionPreviewBitmap := Vcl.Graphics.TBitmap.Create;
  FCompanionPreviewBitmap.PixelFormat := pf32bit;
  FCompanionPreviewRenderScale := 1.0;
  FPreviewBitmap := Vcl.Graphics.TBitmap.Create;
  FPreviewBitmap.PixelFormat := pf32bit;
  FPreviewRenderer := TSkiaTextRenderer.Create;
  FPreviewRenderScale := 1.0;
  FPreviewDragScale := 1.0;
  FDirect2DEnabled := TDirect2DCanvas.Supported;
  FPreviewSelected := False;
  FDraggingPan := False;
  FDraggingPreview := False;
  FDragMode := spdmNone;
  DoubleBuffered := True;
  TControlAccess(PreviewPaintBox).ControlStyle :=
    TControlAccess(PreviewPaintBox).ControlStyle + [csOpaque];
  FZoomPercent := 100;
  FSelectedSnapshotIndex := -1;
  FColorTarget := sctText;
  FOpacityTarget := sotText;
  CreateEditorModeControl;
  LoadAvailableFonts;
  CreateColorPicker;
  CreateColorTargetToolbar;
  CreateOpacityTargetToolbar;
  CreateFormattingToolbar;
  CreateTransparencyTracks;
  LayoutDpiControls;
  FPlacementPopup := TSerifDrawPlacementPopup.Create(Self);
  FPlacementPopup.OnSelected := PlacementSelected;
  FitImage;
  SerifDrawDebugLog(Format(
    'Settings form created: ppi=%d client=%dx%d toolbar=%dx%d d2d=%s.',
    [CurrentPPI, ClientWidth, ClientHeight,
     FFormattingToolbar.Width, FFormattingToolbar.Height,
     BoolToStr(FDirect2DEnabled, True)]));
end;

procedure TFormSerifDrawSettings.EditorModeChange(Sender: TObject);
begin
  if FEditorModeControl = nil then
    Exit;
  ShowEditorMode(FEditorModeControl.Mode);
end;

function TFormSerifDrawSettings.CommonFramePreviewRect: TRect;
begin
  Result := Rect(0, 0, 0, 0);
  if not IsCommonFrameEditorActive or (FBackground.Width <= 0) then
    Exit;
  Result := SerifDrawCommonFrameRect(BackgroundDestinationRect,
    FBackground.Width, FFrameEditorFrame.CommonFrameWidth,
    FFrameEditorFrame.CommonFrameHeight, FCommonFramePositionX,
    FCommonFramePositionY);
end;

function TFormSerifDrawSettings.FrameCornerRadiusHandleRect: TRect;
var
  BackgroundRect: TRect;
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FFrameEditorFrame = nil) or
    (FFrameEditorFrame.FrameShape <> sdfsRoundedRectangle) or
    (FBackground.Width <= 0) then
    Exit;
  BackgroundRect := BackgroundDestinationRect;
  Scale := BackgroundRect.Width / FBackground.Width;
  Result := SerifDrawFrameCornerRadiusHandleRect(CommonFramePreviewRect,
    CurrentPPI, FFrameEditorFrame.CornerRadius, Scale);
end;

function TFormSerifDrawSettings.FrameInnerPanelInsetXHandleRect: TRect;
var
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FFrameEditorFrame = nil) or (FFrameEditorFrame.Layering <> 1) or
    (FBackground.Width <= 0) then
    Exit;
  Scale := BackgroundDestinationRect.Width / FBackground.Width;
  Result := SerifDrawFrameInnerPanelInsetXHandleRect(CommonFramePreviewRect,
    CurrentPPI, FFrameEditorFrame.InnerPanelInsetX, Scale);
end;

function TFormSerifDrawSettings.FrameInnerPanelInsetYHandleRect: TRect;
var
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FFrameEditorFrame = nil) or (FFrameEditorFrame.Layering <> 1) or
    (FBackground.Width <= 0) then
    Exit;
  Scale := BackgroundDestinationRect.Width / FBackground.Width;
  Result := SerifDrawFrameInnerPanelInsetYHandleRect(CommonFramePreviewRect,
    CurrentPPI, FFrameEditorFrame.InnerPanelInsetY, Scale);
end;

function TFormSerifDrawSettings.FrameInnerPanelRadiusHandleRect: TRect;
var
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FFrameEditorFrame = nil) or (FFrameEditorFrame.Layering <> 1) or
    (FBackground.Width <= 0) then
    Exit;
  Scale := BackgroundDestinationRect.Width / FBackground.Width;
  Result := SerifDrawFrameInnerPanelRadiusHandleRect(CommonFramePreviewRect,
    CurrentPPI, FFrameEditorFrame.InnerPanelInsetX,
    FFrameEditorFrame.InnerPanelInsetY, FFrameEditorFrame.InnerPanelRadius,
    Scale);
end;

function TFormSerifDrawSettings.FrameTabRect: TRect;
var
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FFrameEditorFrame = nil) or
    (FFrameEditorFrame.FrameShape <> sdfsTab) or
    (FBackground.Width <= 0) then
    Exit;
  Scale := BackgroundDestinationRect.Width / FBackground.Width;
  Result := SerifDrawFrameTabRect(CommonFramePreviewRect,
    FFrameEditorFrame.TabWidth, FFrameEditorFrame.TabHeight,
    FFrameEditorFrame.TabOffset, Scale);
end;

function TFormSerifDrawSettings.FrameTabOffsetHandleRect: TRect;
begin
  Result := SerifDrawFrameTabOffsetHandleRect(FrameTabRect, CurrentPPI);
end;

function TFormSerifDrawSettings.FrameTabWidthHandleRect: TRect;
begin
  Result := SerifDrawFrameTabWidthHandleRect(FrameTabRect, CurrentPPI);
end;

function TFormSerifDrawSettings.FrameTabHeightHandleRect: TRect;
begin
  Result := SerifDrawFrameTabHeightHandleRect(FrameTabRect, CurrentPPI);
end;

function TFormSerifDrawSettings.FrameBalloonTipHandleRect: TRect;
var
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FFrameEditorFrame = nil) or
    (FFrameEditorFrame.FrameShape <> sdfsSpeechBalloon) or
    (FBackground.Width <= 0) then
    Exit;
  Scale := BackgroundDestinationRect.Width / FBackground.Width;
  Result := SerifDrawFrameBalloonTipHandleRect(CommonFramePreviewRect,
    CurrentPPI, FFrameEditorFrame.BalloonTailDirection,
    FFrameEditorFrame.BalloonTailPosition,
    FFrameEditorFrame.BalloonTailLength, Scale);
end;

function TFormSerifDrawSettings.FrameBalloonWidthHandleRect: TRect;
var
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FFrameEditorFrame = nil) or
    (FFrameEditorFrame.FrameShape <> sdfsSpeechBalloon) or
    (FBackground.Width <= 0) then
    Exit;
  Scale := BackgroundDestinationRect.Width / FBackground.Width;
  Result := SerifDrawFrameBalloonWidthHandleRect(CommonFramePreviewRect,
    CurrentPPI, FFrameEditorFrame.BalloonTailDirection,
    FFrameEditorFrame.BalloonTailPosition,
    FFrameEditorFrame.BalloonTailWidth, Scale);
end;

function TFormSerifDrawSettings.FrameBalloonWidthCursor: TCursor;
begin
  if (FFrameEditorFrame <> nil) and
    (FFrameEditorFrame.BalloonTailDirection in [2, 3]) then
    Result := crSizeNS
  else
    Result := crSizeWE;
end;

function TFormSerifDrawSettings.FrameDottedDashHandleRect: TRect;
begin
  Result := Rect(0, 0, 0, 0);
  if (FFrameEditorFrame = nil) or
    (FFrameEditorFrame.OutlineStyle <> 3) or
    not FFrameEditorFrame.OutlineVisible then
    Exit;
  Result := SerifDrawFrameDottedDashHandleRect(
    FrameOutlineWidthHandleRect, CurrentPPI);
end;

function TFormSerifDrawSettings.FrameDottedGapHandleRect: TRect;
begin
  Result := Rect(0, 0, 0, 0);
  if (FFrameEditorFrame = nil) or
    (FFrameEditorFrame.OutlineStyle <> 3) or
    not FFrameEditorFrame.OutlineVisible then
    Exit;
  Result := SerifDrawFrameDottedGapHandleRect(
    FrameOutlineWidthHandleRect, CurrentPPI);
end;

function TFormSerifDrawSettings.FrameOutlineWidthHandleRect: TRect;
var
  Margin: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (FFrameEditorFrame = nil) or
    not SerifDrawFrameAdjustmentVisible(sdfhOutlineWidth,
      FFrameEditorFrame.OutlineVisible,
      FFrameEditorFrame.ShadowVisible) then
    Exit;
  Result := SerifDrawFrameOutlineWidthHandleRect(CommonFramePreviewRect,
    CurrentPPI);
  Margin := MulDiv(4, CurrentPPI, 96);
  if Result.Right > PreviewPaintBox.ClientWidth - Margin then
    OffsetRect(Result, PreviewPaintBox.ClientWidth - Margin - Result.Right, 0);
  if Result.Left < Margin then
    OffsetRect(Result, Margin - Result.Left, 0);
  if Result.Top < Margin then
    OffsetRect(Result, 0, Margin - Result.Top);
  if Result.Bottom > PreviewPaintBox.ClientHeight - Margin then
    OffsetRect(Result, 0, PreviewPaintBox.ClientHeight - Margin -
      Result.Bottom);
end;

function TFormSerifDrawSettings.FrameShadowOffsetHandleRect: TRect;
var
  BackgroundRect: TRect;
  Margin: Integer;
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FBackground.Width <= 0) or (FFrameEditorFrame = nil) or
    not SerifDrawFrameAdjustmentVisible(sdfhShadowOffset,
      FFrameEditorFrame.OutlineVisible,
      FFrameEditorFrame.ShadowVisible) then
    Exit;
  BackgroundRect := BackgroundDestinationRect;
  Scale := BackgroundRect.Width / FBackground.Width;
  Result := SerifDrawFrameShadowOffsetHandleRect(CommonFramePreviewRect,
    CurrentPPI, Round(FFrameEditorFrame.ShadowOffsetX * Scale),
    Round(FFrameEditorFrame.ShadowOffsetY * Scale));
  Margin := MulDiv(4, CurrentPPI, 96);
  if Result.Right > PreviewPaintBox.ClientWidth - Margin then
    OffsetRect(Result, PreviewPaintBox.ClientWidth - Margin - Result.Right, 0);
  if Result.Left < Margin then
    OffsetRect(Result, Margin - Result.Left, 0);
  if Result.Top < Margin then
    OffsetRect(Result, 0, Margin - Result.Top);
  if Result.Bottom > PreviewPaintBox.ClientHeight - Margin then
    OffsetRect(Result, 0, PreviewPaintBox.ClientHeight - Margin -
      Result.Bottom);
end;

function TFormSerifDrawSettings.FrameShadowSpreadHandleRect: TRect;
var
  BackgroundRect: TRect;
  Gap: Integer;
  Margin: Integer;
  Overlap: TRect;
  Scale: Double;
  ShadowHandle: TRect;
begin
  Result := Rect(0, 0, 0, 0);
  if (FBackground.Width <= 0) or (FFrameEditorFrame = nil) or
    not SerifDrawFrameAdjustmentVisible(sdfhShadowSpread,
      FFrameEditorFrame.OutlineVisible,
      FFrameEditorFrame.ShadowVisible) then
    Exit;
  BackgroundRect := BackgroundDestinationRect;
  Scale := BackgroundRect.Width / FBackground.Width;
  ShadowHandle := FrameShadowOffsetHandleRect;
  Result := SerifDrawFrameShadowSpreadHandleRect(ShadowHandle, CurrentPPI,
    Round(FFrameEditorFrame.ShadowSpread * Scale));
  Margin := MulDiv(4, CurrentPPI, 96);
  if Result.Right > PreviewPaintBox.ClientWidth - Margin then
    OffsetRect(Result, PreviewPaintBox.ClientWidth - Margin - Result.Right, 0);
  if Result.Left < Margin then
    OffsetRect(Result, Margin - Result.Left, 0);
  if Result.Bottom > PreviewPaintBox.ClientHeight - Margin then
    OffsetRect(Result, 0, PreviewPaintBox.ClientHeight - Margin -
      Result.Bottom);
  if Result.Top < Margin then
    OffsetRect(Result, 0, Margin - Result.Top);
  if IntersectRect(Overlap, Result, ShadowHandle) then
  begin
    Gap := MulDiv(6, CurrentPPI, 96);
    OffsetRect(Result, 0, ShadowHandle.Top - Gap - Result.Bottom);
    if Result.Top < Margin then
      OffsetRect(Result, 0, Margin - Result.Top);
  end;
end;

function TFormSerifDrawSettings.FrameShadowBlurHandleRect: TRect;
var
  BackgroundRect: TRect;
  Gap: Integer;
  Margin: Integer;
  Overlap: TRect;
  Scale: Double;
  ShadowHandle: TRect;
begin
  Result := Rect(0, 0, 0, 0);
  if (FBackground.Width <= 0) or (FFrameEditorFrame = nil) or
    not SerifDrawFrameAdjustmentVisible(sdfhShadowBlur,
      FFrameEditorFrame.OutlineVisible,
      FFrameEditorFrame.ShadowVisible) then
    Exit;
  BackgroundRect := BackgroundDestinationRect;
  Scale := BackgroundRect.Width / FBackground.Width;
  ShadowHandle := FrameShadowOffsetHandleRect;
  Result := SerifDrawFrameShadowBlurHandleRect(ShadowHandle, CurrentPPI,
    Round(FFrameEditorFrame.ShadowBlur * Scale));
  Margin := MulDiv(4, CurrentPPI, 96);
  if Result.Left < Margin then
    OffsetRect(Result, Margin - Result.Left, 0);
  if Result.Right > PreviewPaintBox.ClientWidth - Margin then
    OffsetRect(Result, PreviewPaintBox.ClientWidth - Margin - Result.Right, 0);
  if Result.Bottom > PreviewPaintBox.ClientHeight - Margin then
    OffsetRect(Result, 0, PreviewPaintBox.ClientHeight - Margin -
      Result.Bottom);
  if Result.Top < Margin then
    OffsetRect(Result, 0, Margin - Result.Top);
  if IntersectRect(Overlap, Result, ShadowHandle) then
  begin
    Gap := MulDiv(6, CurrentPPI, 96);
    OffsetRect(Result, 0, ShadowHandle.Top - Gap - Result.Bottom);
    if Result.Top < Margin then
      OffsetRect(Result, 0, Margin - Result.Top);
  end;
end;

procedure TFormSerifDrawSettings.FrameEditorSettingsChange(Sender: TObject);
var
  NewKind: TSerifDrawFrameKind;
  NewLayer: Integer;
  NewRoleName: string;
begin
  if FUpdatingControls then
    Exit;
  NewKind := FFrameEditorFrame.FrameKind;
  NewLayer := FrameEditorSelectedLayer;
  NewRoleName := FrameEditorSelectedRoleName;
  if (NewKind <> FEditingFrameKind) or
    ((NewKind = sdfkCharacter) and
      ((NewLayer <> FEditingFrameLayer) or
       (NewRoleName <> FEditingFrameRoleName))) then
  begin
    StoreFrameEditorTarget;
    FSettings.FrameKind := Ord(NewKind);
    LoadFrameEditorTarget(NewKind, NewLayer, NewRoleName);
  end
  else
  begin
    FEditingFrameDirty := True;
    StoreFrameEditorTarget;
  end;
  FFrameDragHit := sdfhNone;
  PreviewPaintBox.Cursor := crDefault;
  PreviewPaintBox.Invalidate;
end;

procedure TFormSerifDrawSettings.FrameEditorLayoutPreset(Sender: TObject;
  const APreset: Integer);
var
  FrameHeight: Integer;
  FrameStyle: TSerifDrawFrameStyle;
  FrameWidth: Integer;
  PositionX: Double;
  PositionY: Double;
begin
  if (FFrameEditorFrame = nil) or (FBackground.Width <= 0) or
    (FBackground.Height <= 0) then
    Exit;
  SerifDrawFrameLayoutPreset(FBackground.Width, FBackground.Height, APreset,
    FrameWidth, FrameHeight, PositionX, PositionY);
  FrameStyle := CaptureSerifDrawFrameEditorStyle(FFrameEditorFrame,
    FrameEditorSelectedLayer, 0, 0);
  SerifDrawFitFrameAppearanceInLayout(FrameStyle, FrameWidth, FrameHeight,
    PositionX, PositionY);
  FFrameEditorFrame.CommonFrameWidth := FrameWidth;
  FFrameEditorFrame.CommonFrameHeight := FrameHeight;
  FCommonFramePositionX := PositionX;
  FCommonFramePositionY := PositionY;
  FEditingFrameDirty := True;
  StoreFrameEditorTarget;
  FFrameDragHit := sdfhNone;
  PreviewPaintBox.Cursor := crDefault;
  PreviewPaintBox.Invalidate;
end;

procedure TFormSerifDrawSettings.FrameEditorResetLayerFrame(Sender: TObject);
begin
  if (FEditingFrameKind <> sdfkCharacter) or
    (FEditingFrameLayer < 0) then
    Exit;
  FSettings.RemoveLayerFrameStyle(FEditingFrameRoleName);
  LoadFrameEditorTarget(sdfkCharacter, FEditingFrameLayer,
    FEditingFrameRoleName);
  FFrameDragHit := sdfhNone;
  PreviewPaintBox.Cursor := crDefault;
  PreviewPaintBox.Invalidate;
end;

function TFormSerifDrawSettings.FrameEditorSelectedLayer: Integer;
var
  Index: Integer;
begin
  Result := -1;
  if FFrameEditorFrame = nil then
    Exit;
  Index := FFrameEditorFrame.SelectedLayerIndex;
  if (Index >= 0) and (Index < Length(FSnapshots)) then
    Result := FSnapshots[Index].Layer;
end;

function TFormSerifDrawSettings.FrameEditorSelectedRoleName: string;
var
  Index: Integer;
begin
  Result := '';
  if FFrameEditorFrame = nil then
    Exit;
  Index := FFrameEditorFrame.SelectedLayerIndex;
  if (Index >= 0) and (Index < Length(FSnapshots)) then
    Result := SerifDrawRoleNameKey(FSnapshots[Index].Chara);
end;

function TFormSerifDrawSettings.RoleNameForLayer(
  const ALayer: Integer): string;
var
  Snapshot: TSerifDrawSnapshot;
begin
  Result := '';
  if (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) and
    (FSnapshots[FSelectedSnapshotIndex].Layer = ALayer) then
    Exit(FSnapshots[FSelectedSnapshotIndex].Chara);
  for Snapshot in FSnapshots do
    if Snapshot.Layer = ALayer then
      Exit(Snapshot.Chara);
end;

procedure TFormSerifDrawSettings.LoadFrameEditorTarget(
  const AKind: TSerifDrawFrameKind; const ALayer: Integer;
  const ARoleName: string);
var
  RoleName: string;
  Style: TSerifDrawFrameStyle;
begin
  RoleName := SerifDrawRoleNameKey(ARoleName);
  if AKind = sdfkCharacter then
    Style := FSettings.ResolveFrameStyle(ALayer, RoleName)
  else
    Style := FSettings.CommonFrameStyle;
  FEditingFrameKind := AKind;
  FEditingFrameLayer := ALayer;
  FEditingFrameRoleName := RoleName;
  FEditingFrameExplicit := (AKind <> sdfkCharacter) or
    FSettings.HasLayerFrameStyle(RoleName);
  FEditingFrameDirty := False;
  FCommonFramePositionX := Style.PositionX;
  FCommonFramePositionY := Style.PositionY;
  FUpdatingControls := True;
  try
    LoadSerifDrawFrameEditorStyle(FFrameEditorFrame, AKind, Style);
    FFrameEditorFrame.SetLayerFrameInherited(
      (AKind = sdfkCharacter) and not FEditingFrameExplicit);
  finally
    FUpdatingControls := False;
  end;
end;

procedure TFormSerifDrawSettings.StoreFrameEditorTarget;
var
  Style: TSerifDrawFrameStyle;
begin
  if (FFrameEditorFrame = nil) or (FEditingFrameKind = sdfkNone) then
    Exit;
  if (FEditingFrameKind = sdfkCharacter) and
    not FEditingFrameExplicit and not FEditingFrameDirty then
    Exit;
  Style := CaptureSerifDrawFrameEditorStyle(FFrameEditorFrame,
    FEditingFrameLayer, FCommonFramePositionX, FCommonFramePositionY);
  Style.RoleName := FEditingFrameRoleName;
  if FEditingFrameKind = sdfkCommon then
    FSettings.SetCommonFrameStyle(Style)
  else if (FEditingFrameKind = sdfkCharacter) and (Style.Layer >= 0) then
  begin
    FSettings.SetLayerFrameStyle(Style);
    FEditingFrameExplicit := True;
    FFrameEditorFrame.SetLayerFrameInherited(False);
  end;
  FEditingFrameDirty := False;
end;

function TFormSerifDrawSettings.IsCommonFrameEditorActive: Boolean;
begin
  Result := IsFrameEditorActive and (FFrameEditorFrame <> nil) and
    (FFrameEditorFrame.FrameKind <> sdfkNone);
end;

function TFormSerifDrawSettings.IsFrameEditorActive: Boolean;
begin
  Result := (FEditorModeControl <> nil) and
    (FEditorModeControl.Mode = sdemFrame);
end;

function TFormSerifDrawSettings.IsRoleNameEditorActive: Boolean;
begin
  Result := (FEditorModeControl <> nil) and
    (FEditorModeControl.Mode = sdemRoleName);
end;

function TFormSerifDrawSettings.EditingPlacement: Byte;
begin
  if IsRoleNameEditorActive then
    Result := FSettings.RoleNamePlacement
  else
    Result := FSettings.Placement;
end;

function TFormSerifDrawSettings.EditingPositionX: Double;
begin
  if IsRoleNameEditorActive then
    Result := FSettings.RoleNamePositionX
  else
    Result := FSettings.PositionX;
end;

function TFormSerifDrawSettings.EditingPositionY: Double;
begin
  if IsRoleNameEditorActive then
    Result := FSettings.RoleNamePositionY
  else
    Result := FSettings.PositionY;
end;

function TFormSerifDrawSettings.EditingTextStyle(
  const ALayer: Integer; const ARoleName: string): TSerifDrawLayerStyle;
var
  RoleName: string;
begin
  RoleName := ARoleName;
  if (RoleName = '') and (ALayer >= 0) then
    RoleName := RoleNameForLayer(ALayer);
  if IsRoleNameEditorActive then
    Result := FSettings.ResolveRoleNameStyle(ALayer, RoleName)
  else
    Result := FSettings.ResolveStyle(ALayer, RoleName);
end;

function TFormSerifDrawSettings.HasColorOverride(const ALayer: Integer;
  const ARoleName: Boolean): Boolean;
var
  Colors: TSerifDrawLayerColors;
  Key: string;
begin
  Result := False;
  Key := SerifDrawRoleNameKey(RoleNameForLayer(ALayer));
  if Key = '' then
    Exit;
  if ARoleName then
  begin
    for Colors in FSettings.RoleNameLayerColors do
      if Colors.RoleName = Key then
        Exit(True);
    Exit;
  end;
  for Colors in FSettings.LayerColors do
    if Colors.RoleName = Key then
      Exit(True);
end;

procedure TFormSerifDrawSettings.SetEditingPosition(const AX, AY: Double);
begin
  if IsRoleNameEditorActive then
  begin
    FSettings.RoleNamePositionX := AX;
    FSettings.RoleNamePositionY := AY;
  end
  else
  begin
    FSettings.PositionX := AX;
    FSettings.PositionY := AY;
  end;
end;

procedure TFormSerifDrawSettings.ShowEditorMode(
  const AMode: TSerifDrawEditorMode);
begin
  if (FTextEditorFrame = nil) or (FFrameEditorFrame = nil) then
    Exit;
  if (AMode <> sdemFrame) and FFrameEditorFrame.Visible then
    StoreFrameEditorTarget;
  case AMode of
    sdemText, sdemRoleName:
      begin
        FFrameEditorFrame.Visible := False;
        FTextEditorFrame.Visible := True;
        PreviewPaintBox.Parent := FTextEditorFrame.PreviewHostPanel;
        PreviewPaintBox.Enabled := True;
        FPreviewSelected := FSelectedSnapshotIndex >= 0;
        FToolbarRoleNameVisible.Visible := AMode = sdemRoleName;
        FTextEditorFrame.BringToFront;
      end;
    sdemFrame:
      begin
        FToolbarRoleNameVisible.Visible := False;
        FFrameEditorFrame.InitializeControls;
        FFrameEditorFrame.SetLayerSelectorItems(LayerComboBox.Items,
          LayerComboBox.ItemIndex);
        FTextEditorFrame.Visible := False;
        FFrameEditorFrame.Visible := True;
        PreviewPaintBox.Parent := FFrameEditorFrame.PreviewHostPanel;
        PreviewPaintBox.Enabled := True;
        FPreviewSelected := False;
        FFrameEditorFrame.BringToFront;
      end;
  end;
  PreviewPaintBox.Align := alClient;
  FDraggingPan := False;
  FDraggingPreview := False;
  FDragMode := spdmNone;
  FFrameDragHit := sdfhNone;
  TControlAccess(PreviewPaintBox).MouseCapture := False;
  PreviewPaintBox.Cursor := crDefault;
  if AMode = sdemFrame then
  begin
    UpdatePlacementButton;
    RenderSelectedPreview;
  end
  else
    LoadSelectedStyle;
  ModePanel.BringToFront;
  PreviewPaintBox.Invalidate;
end;

procedure TFormSerifDrawSettings.Resize;
begin
  inherited;
  LayoutDpiControls;
end;

procedure TFormSerifDrawSettings.FormDestroy(Sender: TObject);
begin
  FPreviewRenderer.Free;
  FCompanionPreviewImage.Free;
  FCompanionPreviewBitmap.Free;
  FPreviewImage.Free;
  FPreviewBitmap.Free;
  FBackBuffer.Free;
  FBackgroundPreview.Free;
  FBackground.Free;
  SerifDrawDebugLog('Settings form destroyed.');
end;

procedure TFormSerifDrawSettings.FormMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
var
  ClientPoint: TPoint;
  ImageX: Double;
  ImageY: Double;
  NewDestination: TRect;
  NewScale: Double;
  NewZoomPercent: Integer;
  OldDestination: TRect;
  OldScale: Double;
begin
  Handled := False;
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  ClientPoint := PreviewPaintBox.ScreenToClient(MousePos);
  if not PtInRect(PreviewPaintBox.ClientRect, ClientPoint) then
    Exit;
  OldDestination := BackgroundDestinationRect;
  OldScale := OldDestination.Width / FBackground.Width;
  if OldScale <= 0 then
    Exit;
  ImageX := (ClientPoint.X - OldDestination.Left) / OldScale;
  ImageY := (ClientPoint.Y - OldDestination.Top) / OldScale;
  NewZoomPercent := FZoomPercent;
  if WheelDelta > 0 then
    Inc(NewZoomPercent, 25)
  else
    Dec(NewZoomPercent, 25);
  NewZoomPercent := EnsureRange(NewZoomPercent, 25, 400);
  if NewZoomPercent = FZoomPercent then
  begin
    Handled := True;
    Exit;
  end;
  FZoomPercent := NewZoomPercent;
  FFitToWindow := False;
  FOffset := Point(0, 0);
  NewDestination := BackgroundDestinationRect;
  NewScale := NewDestination.Width / FBackground.Width;
  FOffset.X := Round(ClientPoint.X - ImageX * NewScale -
    NewDestination.Left);
  FOffset.Y := Round(ClientPoint.Y - ImageY * NewScale -
    NewDestination.Top);
  PreviewPaintBox.Invalidate;
  Handled := True;
end;

procedure TFormSerifDrawSettings.LoadSettings(
  const ASettings: TSerifDrawSettings);
var
  Kind: TSerifDrawFrameKind;
  Layer: Integer;
  RoleName: string;
begin
  FSettings := ASettings;
  Kind := TSerifDrawFrameKind(FSettings.FrameKind);
  if Length(FSnapshots) > 0 then
  begin
    LayerComboBox.ItemIndex := 0;
    FSelectedSnapshotIndex := 0;
  end
  else
    FSelectedSnapshotIndex := -1;
  Layer := -1;
  RoleName := '';
  if (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
  begin
    Layer := FSnapshots[FSelectedSnapshotIndex].Layer;
    RoleName := FSnapshots[FSelectedSnapshotIndex].Chara;
  end;
  LoadFrameEditorTarget(Kind, Layer, RoleName);
  FPreviewSelected := FSelectedSnapshotIndex >= 0;
  LoadSelectedStyle;
  SerifDrawDebugLog(Format('Settings form loaded: layer_colors=%d selected=%d',
    [Length(FSettings.LayerColors), FSelectedSnapshotIndex]));
end;

function TFormSerifDrawSettings.CommitSelectedStyle(
  out AError: string): Boolean;
begin
  AError := '';
  if (Trim(FontComboBox.Text) = '') or
    (Length(Trim(FontComboBox.Text)) > 128) then
  begin
    AError := 'Font name must contain 1 to 128 characters.';
    Exit(False);
  end;
  if IsRoleNameEditorActive then
  begin
    FSettings.RoleNameFontName := Trim(FontComboBox.Text);
    FSettings.RoleNameFontStyles := 0;
    if (FToolbarBold <> nil) and (FToolbarBold.CheckState = tbcsChecked) then
      FSettings.RoleNameFontStyles := FSettings.RoleNameFontStyles or
        SERIF_FONT_BOLD;
    if (FToolbarItalic <> nil) and (FToolbarItalic.CheckState = tbcsChecked) then
      FSettings.RoleNameFontStyles := FSettings.RoleNameFontStyles or
        SERIF_FONT_ITALIC;
    FSettings.RoleNameOutlineEnabled := (FToolbarOutline <> nil) and
      (FToolbarOutline.CheckState = tbcsChecked);
    FSettings.RoleNameShadowEnabled := (FToolbarShadow <> nil) and
      (FToolbarShadow.CheckState = tbcsChecked);
    FSettings.RoleNameVisible := (FToolbarRoleNameVisible <> nil) and
      (FToolbarRoleNameVisible.CheckState = tbcsChecked);
  end
  else
  begin
    FSettings.FontName := Trim(FontComboBox.Text);
    FSettings.FontStyles := 0;
    if (FToolbarBold <> nil) and (FToolbarBold.CheckState = tbcsChecked) then
      FSettings.FontStyles := FSettings.FontStyles or SERIF_FONT_BOLD;
    if (FToolbarItalic <> nil) and (FToolbarItalic.CheckState = tbcsChecked) then
      FSettings.FontStyles := FSettings.FontStyles or SERIF_FONT_ITALIC;
    FSettings.Alignment := FSettings.Placement mod 3;
    FSettings.OutlineEnabled := (FToolbarOutline <> nil) and
      (FToolbarOutline.CheckState = tbcsChecked);
    FSettings.ShadowEnabled := (FToolbarShadow <> nil) and
      (FToolbarShadow.CheckState = tbcsChecked);
  end;
  Result := True;
end;

procedure TFormSerifDrawSettings.ApplyColorsToSelectedLayer(
  const AStyle: TSerifDrawLayerStyle);
var
  Colors: TSerifDrawLayerColors;
begin
  if IsRoleNameEditorActive then
  begin
    if (FSelectedSnapshotIndex >= 0) and
      (FSelectedSnapshotIndex < Length(FSnapshots)) then
    begin
      Colors.Layer := FSnapshots[FSelectedSnapshotIndex].Layer;
      Colors.RoleName := FSnapshots[FSelectedSnapshotIndex].Chara;
      Colors.FillColor := AStyle.FillColor;
      Colors.OutlineColor := AStyle.OutlineColor;
      Colors.ShadowColor := AStyle.ShadowColor;
      Colors.BlurColor := AStyle.BlurColor;
      FSettings.SetRoleNameLayerColors(Colors);
    end
    else
    begin
      FSettings.RoleNameFillColor := AStyle.FillColor;
      FSettings.RoleNameOutlineColor := AStyle.OutlineColor;
      FSettings.RoleNameShadowColor := AStyle.ShadowColor;
      FSettings.RoleNameBlurColor := AStyle.BlurColor;
    end;
    Exit;
  end;
  if (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
  begin
    Colors.Layer := FSnapshots[FSelectedSnapshotIndex].Layer;
    Colors.RoleName := FSnapshots[FSelectedSnapshotIndex].Chara;
    Colors.FillColor := AStyle.FillColor;
    Colors.OutlineColor := AStyle.OutlineColor;
    Colors.ShadowColor := AStyle.ShadowColor;
    Colors.BlurColor := AStyle.BlurColor;
    FSettings.SetLayerColors(Colors);
  end
  else
  begin
    FSettings.FillColor := AStyle.FillColor;
    FSettings.OutlineColor := AStyle.OutlineColor;
    FSettings.ShadowColor := AStyle.ShadowColor;
    FSettings.BlurColor := AStyle.BlurColor;
  end;
end;

procedure TFormSerifDrawSettings.LayerComboBoxChange(Sender: TObject);
var
  ErrorText: string;
  NewIndex: Integer;
  PreviousIndex: Integer;
begin
  if FUpdatingControls then
    Exit;
  PreviousIndex := FSelectedSnapshotIndex;
  NewIndex := LayerComboBox.ItemIndex;
  if not CommitSelectedStyle(ErrorText) then
  begin
    FUpdatingControls := True;
    try
      LayerComboBox.ItemIndex := PreviousIndex;
    finally
      FUpdatingControls := False;
    end;
    MessageDlg('現在の配役設定を切り替えられません。' + sLineBreak +
      ErrorText, mtError, [mbOK], 0);
    SerifDrawDebugLog(Format(
      'Settings layer switch rejected: from=%d to=%d error=%s',
      [PreviousIndex, NewIndex, ErrorText]));
    Exit;
  end;
  FSelectedSnapshotIndex := NewIndex;
  FPreviewSelected := FSelectedSnapshotIndex >= 0;
  LoadSelectedStyle;
  if (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
    SerifDrawDebugLog(Format('Settings layer selected: index=%d layer=%d',
      [FSelectedSnapshotIndex, FSnapshots[FSelectedSnapshotIndex].Layer]));
end;

procedure TFormSerifDrawSettings.LayerComboBoxDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
const
  DARK_ITEM = TColor($00262626);
  DARK_TEXT = TColor($00E6E6E6);
var
  ComboBox: TComboBox;
  ItemText: string;
  TextRect: TRect;
begin
  if not (Control is TComboBox) then
    Exit;
  ComboBox := TComboBox(Control);
  if odSelected in State then
  begin
    ComboBox.Canvas.Brush.Color := clHighlight;
    ComboBox.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    ComboBox.Canvas.Brush.Color := DARK_ITEM;
    ComboBox.Canvas.Font.Color := DARK_TEXT;
  end;
  ComboBox.Canvas.FillRect(Rect);
  if (Index < 0) or (Index >= ComboBox.Items.Count) then
    Exit;
  ItemText := ComboBox.Items[Index];
  if (ComboBox = LayerComboBox) and IsRoleNameEditorActive and
    (Index < Length(FSnapshots)) and
    HasColorOverride(FSnapshots[Index].Layer, True) then
    ItemText := ItemText + ' [個別色]';
  TextRect := Rect;
  Inc(TextRect.Left, MulDiv(4, CurrentPPI, 96));
  ComboBox.Canvas.TextRect(TextRect, TextRect.Left,
    TextRect.Top + (TextRect.Height - ComboBox.Canvas.TextHeight('Ag')) div 2,
    ItemText);
end;

procedure TFormSerifDrawSettings.ColorPickerChange(Sender: TObject);
var
  Argb: Cardinal;
  Color: TColor;
  Style: TSerifDrawLayerStyle;
begin
  if FUpdatingControls or (FColorPicker = nil) then
    Exit;
  if (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
    Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer)
  else
    Style := EditingTextStyle(-1);
  Argb := Style.FillColor;
  case FColorTarget of
    sctText: Argb := Style.FillColor;
    sctOutline: Argb := Style.OutlineColor;
    sctShadow: Argb := Style.ShadowColor;
    sctBlur: Argb := Style.BlurColor;
  end;
  Color := ColorToRGB(FColorPicker.Color);
  Argb := (Argb and $FF000000) or
    (Cardinal(GetRValue(Color)) shl 16) or
    (Cardinal(GetGValue(Color)) shl 8) or Cardinal(GetBValue(Color));
  case FColorTarget of
    sctText: Style.FillColor := Argb;
    sctOutline: Style.OutlineColor := Argb;
    sctShadow: Style.ShadowColor := Argb;
    sctBlur: Style.BlurColor := Argb;
  end;
  ApplyColorsToSelectedLayer(Style);
  UpdateToolbarColorAccents;
  RenderSelectedPreview(False);
end;

procedure TFormSerifDrawSettings.ColorTargetExecute(Sender: TObject;
  Button: TFormattingToolbarButton);
begin
  if (Button = nil) or (Button.Tag < Ord(Low(TSerifDrawOpacityTarget))) or
    (Button.Tag > Ord(High(TSerifDrawOpacityTarget))) then
    Exit;
  FOpacityTarget := TSerifDrawOpacityTarget(Button.Tag);
  case FOpacityTarget of
    sotText: FColorTarget := sctText;
    sotOutline: FColorTarget := sctOutline;
    sotShadow: FColorTarget := sctShadow;
    sotBlur: FColorTarget := sctBlur;
  end;
  UpdateTransparencyTracks;
  UpdateColorPicker;
end;

procedure TFormSerifDrawSettings.LoadSelectedStyle;
const
  FALLBACK_FONT_NAMES: array[0..2] of string =
    ('Yu Gothic UI', 'Meiryo UI', 'Segoe UI');
var
  FontIndex: Integer;
  FontName: string;
  Snapshot: TSerifDrawSnapshot;
  Style: TSerifDrawLayerStyle;
begin
  FUpdatingControls := True;
  try
    if (FSelectedSnapshotIndex >= 0) and
      (FSelectedSnapshotIndex < Length(FSnapshots)) then
    begin
      Snapshot := FSnapshots[FSelectedSnapshotIndex];
      Style := EditingTextStyle(Snapshot.Layer);
    end
    else
    begin
      Style := EditingTextStyle(-1);
    end;
    FontIndex := FontComboBox.Items.IndexOf(Style.FontName);
    if (FontIndex < 0) and
      TSkiaTextRenderer.IsFontFamilyAvailable(Style.FontName) then
    begin
      FontComboBox.Items.Add(Style.FontName);
      FontIndex := FontComboBox.Items.IndexOf(Style.FontName);
    end;
    if FontIndex < 0 then
      for FontName in FALLBACK_FONT_NAMES do
      begin
        FontIndex := FontComboBox.Items.IndexOf(FontName);
        if FontIndex >= 0 then
          Break;
      end;
    if (FontIndex < 0) and (FontComboBox.Items.Count > 0) then
      FontIndex := 0;
    FontComboBox.ItemIndex := FontIndex;
    if FToolbarBold <> nil then
      FToolbarBold.CheckState := TFormattingToolbarCheckState(
        Ord((Style.FontStyles and SERIF_FONT_BOLD) <> 0));
    if FToolbarItalic <> nil then
      FToolbarItalic.CheckState := TFormattingToolbarCheckState(
        Ord((Style.FontStyles and SERIF_FONT_ITALIC) <> 0));
    if FToolbarOutline <> nil then
      FToolbarOutline.CheckState := TFormattingToolbarCheckState(
        Ord(Style.OutlineEnabled));
    if FToolbarShadow <> nil then
      FToolbarShadow.CheckState := TFormattingToolbarCheckState(
        Ord(Style.ShadowEnabled));
    if FToolbarRoleNameVisible <> nil then
      FToolbarRoleNameVisible.CheckState := TFormattingToolbarCheckState(
        Ord(FSettings.RoleNameVisible));
  finally
    FUpdatingControls := False;
  end;
  UpdateTransparencyTracks;
  UpdateToolbarColorAccents;
  UpdatePlacementButton;
  RenderSelectedPreview;
end;

procedure TFormSerifDrawSettings.PlacementSelected(Sender: TObject;
  const APlacement: Byte);
begin
  if IsRoleNameEditorActive then
    FSettings.RoleNamePlacement := APlacement
  else
    FSettings.Placement := APlacement;
  UpdatePlacementButton;
  StyleEditChange(Sender);
end;

procedure TFormSerifDrawSettings.PreviewPaintBoxDblClick(Sender: TObject);
begin
  FitImage;
end;

function TFormSerifDrawSettings.HitTestPreview(
  const APoint: TPoint): TSerifPreviewDragMode;
begin
  if IsRoleNameEditorActive and not FSettings.RoleNameVisible then
    Exit(spdmNone);
  Result := SerifDrawHitTestTextPreview(APoint, TextPreviewHandleLayout,
    CurrentPPI);
end;

procedure TFormSerifDrawSettings.SetPreviewCursor(
  const AMode: TSerifPreviewDragMode);
begin
  PreviewPaintBox.Cursor := SerifDrawTextPreviewCursor(AMode);
end;

function TFormSerifDrawSettings.TextPreviewHandleLayout:
  TSerifDrawTextPreviewLayout;
var
  BackgroundRect: TRect;
  LayoutRect: TRect;
  Scale: Double;
  Style: TSerifDrawLayerStyle;
begin
  Result := System.Default(TSerifDrawTextPreviewLayout);
  if (FSelectedSnapshotIndex < 0) or
    (FSelectedSnapshotIndex >= Length(FSnapshots)) or
    (FBackground.Width <= 0) then
    Exit;
  LayoutRect := PreviewLayoutRect;
  if (LayoutRect.Width <= 0) or (LayoutRect.Height <= 0) then
    Exit;
  BackgroundRect := BackgroundDestinationRect;
  Scale := BackgroundRect.Width / FBackground.Width;
  if Scale <= 0 then
    Exit;
  Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer);
  Result := SerifDrawTextPreviewLayout(PreviewPaintBox.ClientRect,
    LayoutRect, PreviewDestinationRect, CurrentPPI, Scale, Style);
end;

procedure TFormSerifDrawSettings.UpdateDraggedStyle(const AFontSize,
  ALineSpacing, ALetterSpacing: Double);
var
  FontSize: Double;
begin
  if (FSelectedSnapshotIndex < 0) or
    (FSelectedSnapshotIndex >= Length(FSnapshots)) then
    Exit;
  FontSize := EnsureRange(AFontSize, 1.0, 2000.0);
  if IsRoleNameEditorActive then
  begin
    FSettings.RoleNameFontSize := FontSize;
    FSettings.RoleNameLineSpacing := EnsureRange(ALineSpacing, -500.0, 500.0);
    FSettings.RoleNameLetterSpacing := EnsureRange(ALetterSpacing, -500.0, 500.0);
  end
  else
  begin
    FSettings.FontSize := FontSize;
    FSettings.LineSpacing := EnsureRange(ALineSpacing, -500.0, 500.0);
    FSettings.LetterSpacing := EnsureRange(ALetterSpacing, -500.0, 500.0);
  end;
  if (FDragMode in [spdmFontSizeNorthWest, spdmFontSizeNorthEast,
    spdmFontSizeSouthWest, spdmFontSizeSouthEast]) and
    (FDragStartFontSize > 0) then
  begin
    // ドラッグ中は既存画像をD2D/GDIで拡大し、重い文字生成は確定時に1回だけ行う。
    FPreviewDragScale := FontSize / FDragStartFontSize;
    PreviewPaintBox.Invalidate;
    Exit;
  end;
  RenderSelectedPreview(False);
end;

// 文字装飾のドラッグ値は比率で受け、保存前に装飾別の上限へ制限する。
// 本文と配役名は独立したスタイルなので、変更対象だけを更新して他方の画像を再利用する。
procedure TFormSerifDrawSettings.UpdateDraggedShadowOffset(const AOffsetX,
  AOffsetY: Double);
begin
  if (FSelectedSnapshotIndex < 0) or
    (FSelectedSnapshotIndex >= Length(FSnapshots)) then
    Exit;
  if IsRoleNameEditorActive then
  begin
    FSettings.RoleNameShadowEnabled := True;
    FSettings.RoleNameShadowOffsetX := EnsureRange(AOffsetX,
      -SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT,
      SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT);
    FSettings.RoleNameShadowOffsetY := EnsureRange(AOffsetY,
      -SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT,
      SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT);
  end
  else
  begin
    FSettings.ShadowEnabled := True;
    FSettings.ShadowOffsetX := EnsureRange(AOffsetX,
      -SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT,
      SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT);
    FSettings.ShadowOffsetY := EnsureRange(AOffsetY,
      -SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT,
      SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT);
  end;
  FUpdatingControls := True;
  try
    if FToolbarShadow <> nil then
      FToolbarShadow.CheckState := tbcsChecked;
  finally
    FUpdatingControls := False;
  end;
  RenderSelectedPreview(False);
end;

procedure TFormSerifDrawSettings.UpdateDraggedOutlineBlur(
  const ABlur: Double);
begin
  if (FSelectedSnapshotIndex < 0) or
    (FSelectedSnapshotIndex >= Length(FSnapshots)) then
    Exit;
  if IsRoleNameEditorActive then
    FSettings.RoleNameOutlineBlur := EnsureRange(ABlur, 0.0,
      SERIF_TEXT_OUTLINE_BLUR_MAX_PERCENT)
  else
    FSettings.OutlineBlur := EnsureRange(ABlur, 0.0,
      SERIF_TEXT_OUTLINE_BLUR_MAX_PERCENT);
  RenderSelectedPreview(False);
end;

procedure TFormSerifDrawSettings.UpdateDraggedOutlineWidth(
  const AWidth: Double);
begin
  if (FSelectedSnapshotIndex < 0) or
    (FSelectedSnapshotIndex >= Length(FSnapshots)) then
    Exit;
  if IsRoleNameEditorActive then
    FSettings.RoleNameOutlineWidth := EnsureRange(AWidth, 0.0,
      SERIF_TEXT_OUTLINE_WIDTH_MAX_PERCENT)
  else
    FSettings.OutlineWidth := EnsureRange(AWidth, 0.0,
      SERIF_TEXT_OUTLINE_WIDTH_MAX_PERCENT);
  RenderSelectedPreview(False);
end;

procedure TFormSerifDrawSettings.UpdateDraggedShadowBlur(
  const ABlur: Double);
begin
  if (FSelectedSnapshotIndex < 0) or
    (FSelectedSnapshotIndex >= Length(FSnapshots)) then
    Exit;
  if IsRoleNameEditorActive then
  begin
    FSettings.RoleNameShadowEnabled := True;
    FSettings.RoleNameShadowBlur := EnsureRange(ABlur, 0.0,
      SERIF_TEXT_SHADOW_BLUR_MAX_PERCENT);
  end
  else
  begin
    FSettings.ShadowEnabled := True;
    FSettings.ShadowBlur := EnsureRange(ABlur, 0.0,
      SERIF_TEXT_SHADOW_BLUR_MAX_PERCENT);
  end;
  FUpdatingControls := True;
  try
    if FToolbarShadow <> nil then
      FToolbarShadow.CheckState := tbcsChecked;
  finally
    FUpdatingControls := False;
  end;
  RenderSelectedPreview(False);
end;

procedure TFormSerifDrawSettings.UpdateDraggedShadowSpread(
  const ASpread: Double);
begin
  if (FSelectedSnapshotIndex < 0) or
    (FSelectedSnapshotIndex >= Length(FSnapshots)) then
    Exit;
  if IsRoleNameEditorActive then
  begin
    FSettings.RoleNameShadowEnabled := True;
    FSettings.RoleNameShadowSpread := EnsureRange(ASpread, 0.0,
      SERIF_TEXT_SHADOW_SPREAD_MAX_PERCENT);
  end
  else
  begin
    FSettings.ShadowEnabled := True;
    FSettings.ShadowSpread := EnsureRange(ASpread, 0.0,
      SERIF_TEXT_SHADOW_SPREAD_MAX_PERCENT);
  end;
  FUpdatingControls := True;
  try
    if FToolbarShadow <> nil then
      FToolbarShadow.CheckState := tbcsChecked;
  finally
    FUpdatingControls := False;
  end;
  RenderSelectedPreview(False);
end;

procedure TFormSerifDrawSettings.PreviewPaintBoxMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Style: TSerifDrawLayerStyle;
begin
  if IsFrameEditorActive then
  begin
    FFrameDragHit := sdfhNone;
    if (Button = mbLeft) and IsCommonFrameEditorActive then
    begin
      if PtInRect(FrameInnerPanelRadiusHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhInnerPanelRadius
      else if PtInRect(FrameInnerPanelInsetXHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhInnerPanelInsetX
      else if PtInRect(FrameInnerPanelInsetYHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhInnerPanelInsetY
      else if PtInRect(FrameDottedDashHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhDottedDashLength
      else if PtInRect(FrameDottedGapHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhDottedGapLength
      else if PtInRect(FrameBalloonTipHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhBalloonTip
      else if PtInRect(FrameBalloonWidthHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhBalloonWidth
      else if PtInRect(FrameTabOffsetHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhTabOffset
      else if PtInRect(FrameTabWidthHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhTabWidth
      else if PtInRect(FrameTabHeightHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhTabHeight
      else if PtInRect(FrameCornerRadiusHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhCornerRadius
      else if PtInRect(FrameShadowBlurHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhShadowBlur
      else if PtInRect(FrameShadowSpreadHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhShadowSpread
      else if PtInRect(FrameShadowOffsetHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhShadowOffset
      else if PtInRect(FrameOutlineWidthHandleRect, Point(X, Y)) then
        FFrameDragHit := sdfhOutlineWidth
      else
        FFrameDragHit := SerifDrawHitTestCommonFrame(Point(X, Y),
          CommonFramePreviewRect,
          Max(5, MulDiv(PREVIEW_HANDLE_SIZE, CurrentPPI, 96)));
    end;
    if FFrameDragHit = sdfhNone then
    begin
      PreviewPaintBox.Cursor := crDefault;
      Exit;
    end;
    FDragButton := Button;
    FDragStartMouse := Point(X, Y);
    FFrameDragStartWidth := FFrameEditorFrame.CommonFrameWidth;
    FFrameDragStartHeight := FFrameEditorFrame.CommonFrameHeight;
    FFrameDragStartCornerRadius := FFrameEditorFrame.CornerRadius;
    FFrameDragStartDottedDashLength := FFrameEditorFrame.DottedDashLength;
    FFrameDragStartDottedGapLength := FFrameEditorFrame.DottedGapLength;
    FFrameDragStartInnerPanelInsetX := FFrameEditorFrame.InnerPanelInsetX;
    FFrameDragStartInnerPanelInsetY := FFrameEditorFrame.InnerPanelInsetY;
    FFrameDragStartInnerPanelRadius := FFrameEditorFrame.InnerPanelRadius;
    FFrameDragStartTabWidth := FFrameEditorFrame.TabWidth;
    FFrameDragStartTabHeight := FFrameEditorFrame.TabHeight;
    FFrameDragStartTabOffset := FFrameEditorFrame.TabOffset;
    FFrameDragStartBalloonTailPosition :=
      FFrameEditorFrame.BalloonTailPosition;
    FFrameDragStartBalloonTailWidth := FFrameEditorFrame.BalloonTailWidth;
    FFrameDragStartBalloonTailLength := FFrameEditorFrame.BalloonTailLength;
    FFrameDragStartPositionX := FCommonFramePositionX;
    FFrameDragStartPositionY := FCommonFramePositionY;
    FFrameDragStartOutlineWidth := FFrameEditorFrame.OutlineWidth;
    FFrameDragStartShadowOffsetX := FFrameEditorFrame.ShadowOffsetX;
    FFrameDragStartShadowOffsetY := FFrameEditorFrame.ShadowOffsetY;
    FFrameDragStartShadowBlur := FFrameEditorFrame.ShadowBlur;
    FFrameDragStartShadowSpread := FFrameEditorFrame.ShadowSpread;
    if FFrameDragHit in [sdfhShadowOffset, sdfhShadowSpread,
      sdfhShadowBlur] then
      FFrameEditorFrame.EnableShadow;
    FDragSnapXActive := False;
    FDragSnapYActive := False;
    FDraggingPreview := True;
    FDraggingPan := False;
    TControlAccess(PreviewPaintBox).MouseCapture := True;
    PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(FFrameDragHit);
    if FFrameDragHit = sdfhBalloonWidth then
      PreviewPaintBox.Cursor := FrameBalloonWidthCursor;
    PreviewPaintBox.Invalidate;
    Exit;
  end;
  if not (Button in [mbLeft, mbRight]) then
    Exit;
  FDragButton := Button;
  FDragSnapXActive := False;
  FDragSnapYActive := False;
  FDragMode := HitTestPreview(Point(X, Y));
  FPreviewDragScale := 1.0;
  FPreviewSelected := FDragMode <> spdmNone;
  if FDragMode = spdmNone then
    FDragMode := spdmPan;
  FDraggingPreview := FDragMode <> spdmPan;
  FDraggingPan := FDragMode = spdmPan;
  FDragStartMouse := Point(X, Y);
  if FDraggingPreview then
  begin
    FDragStartPositionX := EditingPositionX;
    FDragStartPositionY := EditingPositionY;
    if (FSelectedSnapshotIndex >= 0) and
      (FSelectedSnapshotIndex < Length(FSnapshots)) then
    begin
      Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer);
      FDragStartFontSize := Style.FontSize;
      FDragStartLineSpacing := Style.LineSpacing;
      FDragStartLetterSpacing := Style.LetterSpacing;
      FDragStartOutlineBlur := Style.OutlineBlur;
      FDragStartOutlineWidth := Style.OutlineWidth;
      FDragStartShadowOffsetX := Style.ShadowOffsetX;
      FDragStartShadowOffsetY := Style.ShadowOffsetY;
      FDragStartShadowBlur := Style.ShadowBlur;
      FDragStartShadowSpread := Style.ShadowSpread;
    end;
  end;
  if FDraggingPan then
    FDragStartOffset := FOffset;
  TControlAccess(PreviewPaintBox).MouseCapture := True;
  SetPreviewCursor(FDragMode);
  if FDragMode = spdmShadowOffset then
    UpdateDraggedShadowOffset(FDragStartShadowOffsetX,
      FDragStartShadowOffsetY);
  if FDragMode = spdmShadowBlur then
    UpdateDraggedShadowBlur(FDragStartShadowBlur);
  if FDragMode = spdmShadowSpread then
    UpdateDraggedShadowSpread(FDragStartShadowSpread);
  PreviewPaintBox.Invalidate;
  if FPreviewSelected and (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
    SerifDrawDebugLog(Format('Settings preview selected: layer=%d',
      [FSnapshots[FSelectedSnapshotIndex].Layer]));
end;

procedure TFormSerifDrawSettings.PreviewPaintBoxMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  BackgroundRect: TRect;
  FrameCurrent: TSerifDrawFrameStyle;
  FrameDragResult: TSerifDrawFrameDragResult;
  FrameStart: TSerifDrawFrameStyle;
  Scale: Double;
  TextDragResult: TSerifDrawTextDragResult;
  TextDragStart: TSerifDrawTextDragStart;
begin
  if IsFrameEditorActive then
  begin
    if not FDraggingPreview or (FFrameDragHit = sdfhNone) then
    begin
      if IsCommonFrameEditorActive then
      begin
        if PtInRect(FrameInnerPanelRadiusHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := crSizeWE
        else if PtInRect(FrameInnerPanelInsetXHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := crSizeWE
        else if PtInRect(FrameInnerPanelInsetYHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := crSizeNS
        else if PtInRect(FrameDottedDashHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := crSizeWE
        else if PtInRect(FrameDottedGapHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := crSizeWE
        else if PtInRect(FrameBalloonTipHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhBalloonTip)
        else if PtInRect(FrameBalloonWidthHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := FrameBalloonWidthCursor
        else if PtInRect(FrameTabOffsetHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhTabOffset)
        else if PtInRect(FrameTabWidthHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhTabWidth)
        else if PtInRect(FrameTabHeightHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhTabHeight)
        else if PtInRect(FrameCornerRadiusHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhCornerRadius)
        else if PtInRect(FrameShadowBlurHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhShadowBlur)
        else if PtInRect(FrameShadowSpreadHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhShadowSpread)
        else if PtInRect(FrameShadowOffsetHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhShadowOffset)
        else if PtInRect(FrameOutlineWidthHandleRect, Point(X, Y)) then
          PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhOutlineWidth)
        else
          PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(
            SerifDrawHitTestCommonFrame(Point(X, Y), CommonFramePreviewRect,
              Max(5, MulDiv(PREVIEW_HANDLE_SIZE, CurrentPPI, 96))));
      end
      else
        PreviewPaintBox.Cursor := crDefault;
      Exit;
    end;
    if not (ssLeft in Shift) then
    begin
      FDraggingPreview := False;
      FFrameDragHit := sdfhNone;
      FDragSnapXActive := False;
      FDragSnapYActive := False;
      TControlAccess(PreviewPaintBox).MouseCapture := False;
      PreviewPaintBox.Cursor := crDefault;
      Exit;
    end;
    if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
      Exit;
    BackgroundRect := BackgroundDestinationRect;
    Scale := BackgroundRect.Width / FBackground.Width;
    FEditingFrameDirty := True;
    FrameCurrent := CaptureSerifDrawFrameEditorStyle(FFrameEditorFrame,
      FrameEditorSelectedLayer, FCommonFramePositionX,
      FCommonFramePositionY);
    FrameStart := FrameCurrent;
    FrameStart.Width := FFrameDragStartWidth;
    FrameStart.Height := FFrameDragStartHeight;
    FrameStart.PositionX := FFrameDragStartPositionX;
    FrameStart.PositionY := FFrameDragStartPositionY;
    FrameStart.CornerRadius := FFrameDragStartCornerRadius;
    FrameStart.DottedDashLength := FFrameDragStartDottedDashLength;
    FrameStart.DottedGapLength := FFrameDragStartDottedGapLength;
    FrameStart.InnerPanelInsetX := FFrameDragStartInnerPanelInsetX;
    FrameStart.InnerPanelInsetY := FFrameDragStartInnerPanelInsetY;
    FrameStart.InnerPanelRadius := FFrameDragStartInnerPanelRadius;
    FrameStart.OutlineWidth := FFrameDragStartOutlineWidth;
    FrameStart.ShadowOffsetX := FFrameDragStartShadowOffsetX;
    FrameStart.ShadowOffsetY := FFrameDragStartShadowOffsetY;
    FrameStart.ShadowBlur := FFrameDragStartShadowBlur;
    FrameStart.ShadowSpread := FFrameDragStartShadowSpread;
    FrameStart.TabHeight := FFrameDragStartTabHeight;
    FrameStart.TabOffset := FFrameDragStartTabOffset;
    FrameStart.TabWidth := FFrameDragStartTabWidth;
    FrameStart.BalloonTailLength := FFrameDragStartBalloonTailLength;
    FrameStart.BalloonTailPosition := FFrameDragStartBalloonTailPosition;
    FrameStart.BalloonTailWidth := FFrameDragStartBalloonTailWidth;
    FrameDragResult := SerifDrawCalculateFrameDrag(FFrameDragHit,
      FrameStart, FrameCurrent, FDragStartMouse, Point(X, Y), Scale,
      CurrentPPI, CommonFramePreviewRect, FDragSnapXActive,
      FDragSnapYActive);
    case FFrameDragHit of
      sdfhInnerPanelInsetX:
        begin
          FFrameEditorFrame.InnerPanelInsetX :=
            FrameDragResult.Style.InnerPanelInsetX;
          FFrameEditorFrame.InnerPanelRadius :=
            FrameDragResult.Style.InnerPanelRadius;
        end;
      sdfhInnerPanelInsetY:
        begin
          FFrameEditorFrame.InnerPanelInsetY :=
            FrameDragResult.Style.InnerPanelInsetY;
          FFrameEditorFrame.InnerPanelRadius :=
            FrameDragResult.Style.InnerPanelRadius;
        end;
      sdfhInnerPanelRadius:
        FFrameEditorFrame.InnerPanelRadius :=
          FrameDragResult.Style.InnerPanelRadius;
      sdfhDottedDashLength:
        FFrameEditorFrame.DottedDashLength :=
          FrameDragResult.Style.DottedDashLength;
      sdfhDottedGapLength:
        FFrameEditorFrame.DottedGapLength :=
          FrameDragResult.Style.DottedGapLength;
      sdfhBalloonTip:
        begin
          FFrameEditorFrame.BalloonTailDirection :=
            FrameDragResult.Style.BalloonTailDirection;
          FFrameEditorFrame.BalloonTailPosition :=
            FrameDragResult.Style.BalloonTailPosition;
          FFrameEditorFrame.BalloonTailLength :=
            FrameDragResult.Style.BalloonTailLength;
        end;
      sdfhBalloonWidth:
        FFrameEditorFrame.BalloonTailWidth :=
          FrameDragResult.Style.BalloonTailWidth;
      sdfhTabOffset:
        begin
          FFrameEditorFrame.TabOffset := FrameDragResult.Style.TabOffset;
          FFrameEditorFrame.TabWidth := FrameDragResult.Style.TabWidth;
        end;
      sdfhTabWidth:
        FFrameEditorFrame.TabWidth := FrameDragResult.Style.TabWidth;
      sdfhTabHeight:
        FFrameEditorFrame.TabHeight := FrameDragResult.Style.TabHeight;
      sdfhCornerRadius:
        FFrameEditorFrame.CornerRadius :=
          FrameDragResult.Style.CornerRadius;
      sdfhShadowBlur:
        FFrameEditorFrame.ShadowBlur := FrameDragResult.Style.ShadowBlur;
      sdfhShadowSpread:
        FFrameEditorFrame.ShadowSpread :=
          FrameDragResult.Style.ShadowSpread;
      sdfhShadowOffset:
        begin
          FFrameEditorFrame.ShadowOffsetX :=
            FrameDragResult.Style.ShadowOffsetX;
          FFrameEditorFrame.ShadowOffsetY :=
            FrameDragResult.Style.ShadowOffsetY;
        end;
      sdfhOutlineWidth:
        FFrameEditorFrame.OutlineWidth :=
          FrameDragResult.Style.OutlineWidth;
      sdfhMove:
        begin
          FCommonFramePositionX := FrameDragResult.Style.PositionX;
          FCommonFramePositionY := FrameDragResult.Style.PositionY;
        end;
    else
      begin
        FFrameEditorFrame.CommonFrameWidth := FrameDragResult.Style.Width;
        FFrameEditorFrame.CommonFrameHeight := FrameDragResult.Style.Height;
        FFrameEditorFrame.InnerPanelInsetX :=
          FrameDragResult.Style.InnerPanelInsetX;
        FFrameEditorFrame.InnerPanelInsetY :=
          FrameDragResult.Style.InnerPanelInsetY;
        FFrameEditorFrame.InnerPanelRadius :=
          FrameDragResult.Style.InnerPanelRadius;
      end;
    end;
    FDragSnapXActive := FrameDragResult.SnapXActive;
    FDragSnapYActive := FrameDragResult.SnapYActive;
    PreviewPaintBox.Invalidate;
    Exit;
  end;
  if not FDraggingPreview and not FDraggingPan then
  begin
    SetPreviewCursor(HitTestPreview(Point(X, Y)));
    Exit;
  end;
  if ((FDragButton = mbLeft) and not (ssLeft in Shift)) or
    ((FDragButton = mbRight) and not (ssRight in Shift)) then
  begin
    if Abs(FPreviewDragScale - 1.0) > 0.000001 then
    begin
      FPreviewDragScale := 1.0;
      RenderSelectedPreview;
    end;
    FDraggingPan := False;
    FDraggingPreview := False;
    FDragMode := spdmNone;
    FDragSnapXActive := False;
    FDragSnapYActive := False;
    TControlAccess(PreviewPaintBox).MouseCapture := False;
    PreviewPaintBox.Cursor := crDefault;
    Exit;
  end;
  if FDraggingPan then
  begin
    FOffset.X := FDragStartOffset.X + X - FDragStartMouse.X;
    FOffset.Y := FDragStartOffset.Y + Y - FDragStartMouse.Y;
    FFitToWindow := False;
    PreviewPaintBox.Invalidate;
    Exit;
  end;
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  BackgroundRect := BackgroundDestinationRect;
  Scale := BackgroundRect.Width / FBackground.Width;
  if Scale <= 0 then
    Exit;
  TextDragStart := System.Default(TSerifDrawTextDragStart);
  TextDragStart.Mouse := FDragStartMouse;
  TextDragStart.FontSize := FDragStartFontSize;
  TextDragStart.LetterSpacing := FDragStartLetterSpacing;
  TextDragStart.LineSpacing := FDragStartLineSpacing;
  TextDragStart.OutlineBlur := FDragStartOutlineBlur;
  TextDragStart.OutlineWidth := FDragStartOutlineWidth;
  TextDragStart.PositionX := FDragStartPositionX;
  TextDragStart.PositionY := FDragStartPositionY;
  TextDragStart.ShadowBlur := FDragStartShadowBlur;
  TextDragStart.ShadowOffsetX := FDragStartShadowOffsetX;
  TextDragStart.ShadowOffsetY := FDragStartShadowOffsetY;
  TextDragStart.ShadowSpread := FDragStartShadowSpread;
  TextDragResult := SerifDrawCalculateTextDrag(FDragMode, TextDragStart,
    Point(X, Y), Scale, FDragButton = mbLeft,
    FDragSnapXActive, FDragSnapYActive, FDragSnapYValue);
  case FDragMode of
    spdmFontSizeNorthWest, spdmFontSizeNorthEast,
    spdmFontSizeSouthWest, spdmFontSizeSouthEast,
    spdmLetterSpacingWest, spdmLetterSpacingEast,
    spdmLineSpacingNorth, spdmLineSpacingSouth:
      UpdateDraggedStyle(TextDragResult.FontSize,
        TextDragResult.LineSpacing, TextDragResult.LetterSpacing);
    spdmShadowOffset:
      UpdateDraggedShadowOffset(TextDragResult.ShadowOffsetX,
        TextDragResult.ShadowOffsetY);
    spdmOutlineWidth:
      UpdateDraggedOutlineWidth(TextDragResult.OutlineWidth);
    spdmOutlineBlur:
      UpdateDraggedOutlineBlur(TextDragResult.OutlineBlur);
    spdmShadowBlur:
      UpdateDraggedShadowBlur(TextDragResult.ShadowBlur);
    spdmShadowSpread:
      UpdateDraggedShadowSpread(TextDragResult.ShadowSpread);
  else
    begin
      SetEditingPosition(TextDragResult.PositionX, TextDragResult.PositionY);
      FDragSnapXActive := TextDragResult.SnapXActive;
      FDragSnapYActive := TextDragResult.SnapYActive;
      FDragSnapYValue := TextDragResult.SnapYValue;
      PreviewPaintBox.Invalidate;
    end;
  end;
end;

procedure TFormSerifDrawSettings.PreviewPaintBoxMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  FS: TFormatSettings;
  NeedsFinalRender: Boolean;
  Style: TSerifDrawLayerStyle;
begin
  if IsFrameEditorActive then
  begin
    if (Button <> FDragButton) or not FDraggingPreview then
      Exit;
    FDraggingPreview := False;
    FFrameDragHit := sdfhNone;
    FDragSnapXActive := False;
    FDragSnapYActive := False;
    TControlAccess(PreviewPaintBox).MouseCapture := False;
    if IsCommonFrameEditorActive then
    begin
      if PtInRect(FrameInnerPanelRadiusHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := crSizeWE
      else if PtInRect(FrameInnerPanelInsetXHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := crSizeWE
      else if PtInRect(FrameInnerPanelInsetYHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := crSizeNS
      else if PtInRect(FrameDottedDashHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := crSizeWE
      else if PtInRect(FrameDottedGapHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := crSizeWE
      else if PtInRect(FrameBalloonTipHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhBalloonTip)
      else if PtInRect(FrameBalloonWidthHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := FrameBalloonWidthCursor
      else if PtInRect(FrameTabOffsetHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhTabOffset)
      else if PtInRect(FrameTabWidthHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhTabWidth)
      else if PtInRect(FrameTabHeightHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhTabHeight)
      else if PtInRect(FrameCornerRadiusHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhCornerRadius)
      else if PtInRect(FrameShadowBlurHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhShadowBlur)
      else if PtInRect(FrameShadowSpreadHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhShadowSpread)
      else if PtInRect(FrameShadowOffsetHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhShadowOffset)
      else if PtInRect(FrameOutlineWidthHandleRect, Point(X, Y)) then
        PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(sdfhOutlineWidth)
      else
        PreviewPaintBox.Cursor := SerifDrawFrameHitCursor(
          SerifDrawHitTestCommonFrame(Point(X, Y), CommonFramePreviewRect,
            Max(5, MulDiv(PREVIEW_HANDLE_SIZE, CurrentPPI, 96))));
    end
    else
      PreviewPaintBox.Cursor := crDefault;
    PreviewPaintBox.Invalidate;
    Exit;
  end;
  if (Button <> FDragButton) or
    (not FDraggingPreview and not FDraggingPan) then
    Exit;
  FS := TFormatSettings.Create('en-US');
  if FDragMode = spdmMove then
  begin
    SerifDrawDebugLog(Format('Settings preview moved: x=%s y=%s',
      [FormatFloat('0.###', EditingPositionX, FS),
       FormatFloat('0.###', EditingPositionY, FS)]));
  end;
  if (FDragMode in [spdmFontSizeNorthWest, spdmFontSizeNorthEast,
    spdmFontSizeSouthWest, spdmFontSizeSouthEast, spdmLetterSpacingWest,
    spdmLetterSpacingEast, spdmLineSpacingNorth, spdmLineSpacingSouth]) and
    (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
  begin
    Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer);
    SerifDrawDebugLog(Format(
      'Settings preview resized: font=%s line_spacing=%s letter_spacing=%s',
      [FormatFloat('0.###', Style.FontSize, FS),
       FormatFloat('0.###', Style.LineSpacing, FS),
       FormatFloat('0.###', Style.LetterSpacing, FS)]));
  end;
  if (FDragMode = spdmShadowOffset) and
    (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
  begin
    Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer);
    SerifDrawDebugLog(Format(
      'Settings shadow handle moved: x=%s y=%s',
      [FormatFloat('0.###', Style.ShadowOffsetX, FS),
       FormatFloat('0.###', Style.ShadowOffsetY, FS)]));
  end;
  if (FDragMode = spdmOutlineWidth) and
    (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
  begin
    Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer);
    SerifDrawDebugLog(Format('Settings outline handle moved: width=%s',
      [FormatFloat('0.###', Style.OutlineWidth, FS)]));
  end;
  if (FDragMode = spdmOutlineBlur) and
    (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
  begin
    Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer);
    SerifDrawDebugLog(Format('Settings outline blur handle moved: blur=%s',
      [FormatFloat('0.###', Style.OutlineBlur, FS)]));
  end;
  if (FDragMode = spdmShadowBlur) and
    (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
  begin
    Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer);
    SerifDrawDebugLog(Format('Settings shadow blur handle moved: blur=%s',
      [FormatFloat('0.###', Style.ShadowBlur, FS)]));
  end;
  if (FDragMode = spdmShadowSpread) and
    (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
  begin
    Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer);
    SerifDrawDebugLog(Format('Settings shadow spread handle moved: spread=%s',
      [FormatFloat('0.###', Style.ShadowSpread, FS)]));
  end;
  NeedsFinalRender := FDragMode in [spdmFontSizeNorthWest,
    spdmFontSizeNorthEast, spdmFontSizeSouthWest,
    spdmFontSizeSouthEast, spdmLetterSpacingWest, spdmLetterSpacingEast,
    spdmLineSpacingNorth, spdmLineSpacingSouth, spdmOutlineBlur,
    spdmOutlineWidth, spdmShadowBlur, spdmShadowOffset,
    spdmShadowSpread];
  if Abs(FPreviewDragScale - 1.0) > 0.000001 then
  begin
    FPreviewDragScale := 1.0;
    NeedsFinalRender := True;
  end;
  FDraggingPan := False;
  FDraggingPreview := False;
  FDragSnapXActive := False;
  FDragSnapYActive := False;
  FDragMode := spdmNone;
  TControlAccess(PreviewPaintBox).MouseCapture := False;
  SetPreviewCursor(HitTestPreview(Point(X, Y)));
  if NeedsFinalRender then
    RenderSelectedPreview(False)
  else
    PreviewPaintBox.Invalidate;
end;

function TFormSerifDrawSettings.PaintPreviewDirect2D: Boolean;
var
  CompanionRect: TRect;
  Destination: TRect;
  Direct2DBitmap: ID2D1Bitmap;
  Direct2DCanvas: TDirect2DCanvas;
  Direct2DRect: TD2D1RectF;
  FrameAccentLayer: Integer;
  FrameAppearance: TSerifDrawFrameStyle;
  FrameRect: TRect;
  PreviewRect: TRect;
  SnapGuideX: Boolean;
  SnapGuideY: Boolean;
  TargetCanvas: TCanvas;
  TextHandleState: TSerifDrawTextPreviewHandleState;
  TextLayout: TSerifDrawTextPreviewLayout;

  procedure DrawBitmap(const ABitmap: Vcl.Graphics.TBitmap;
    const ARect: TRect);
  begin
    if (ABitmap = nil) or (ABitmap.Width <= 0) or
      (ABitmap.Height <= 0) or (ARect.Width <= 0) or
      (ARect.Height <= 0) then
      Exit;
    Direct2DBitmap := Direct2DCanvas.CreateBitmap(ABitmap);
    if Direct2DBitmap = nil then
      raise EInvalidOp.Create('Direct2D preview bitmap creation failed');
    Direct2DRect := D2D1RectF(ARect.Left, ARect.Top,
      ARect.Right, ARect.Bottom);
    Direct2DCanvas.RenderTarget.DrawBitmap(Direct2DBitmap, @Direct2DRect);
    Direct2DBitmap := nil;
  end;

  procedure DrawFrame(const ARect: TRect;
    const AStyle: TSerifDrawFrameStyle);
  var
    FrameScale: Double;
  begin
    if (FBackground.Width <= 0) or (Destination.Width <= 0) then
      Exit;
    FrameScale := Destination.Width / FBackground.Width;
    DrawSerifDrawCommonFrameAppearance(TargetCanvas,
      ARect, CurrentPPI, AStyle.Shape,
      Round(AStyle.CornerRadius * FrameScale),
      Round(AStyle.TabWidth * FrameScale),
      Round(AStyle.TabHeight * FrameScale),
      Round(AStyle.TabOffset * FrameScale),
      AStyle.BalloonTailDirection,
      Round(AStyle.BalloonTailPosition * FrameScale),
      Round(AStyle.BalloonTailWidth * FrameScale),
      Round(AStyle.BalloonTailLength * FrameScale),
      AStyle.Layering,
      Round(AStyle.InnerPanelInsetX * FrameScale),
      Round(AStyle.InnerPanelInsetY * FrameScale),
      Round(AStyle.InnerPanelRadius * FrameScale),
      Round(AStyle.OutlineWidth * FrameScale),
      AStyle.OutlineStyle,
      Round(AStyle.DottedDashLength * FrameScale),
      Round(AStyle.DottedGapLength * FrameScale),
      Round(AStyle.ShadowOffsetX * FrameScale),
      Round(AStyle.ShadowOffsetY * FrameScale),
      Round(AStyle.ShadowSpread * FrameScale),
      Round(AStyle.ShadowBlur * FrameScale),
      AStyle.FillVisible, AStyle.OutlineVisible, AStyle.ShadowVisible,
      AStyle.FillColor, AStyle.OutlineColor, AStyle.InnerOutlineColor,
      AStyle.InnerPanelColor, AStyle.ShadowColor, AStyle.FillMode,
      AStyle.GradientStrength);
  end;

begin
  Result := False;
  if not FDirect2DEnabled or not TDirect2DCanvas.Supported then
    Exit;
  TargetCanvas := PreviewPaintBox.Canvas;
  Destination := Rect(0, 0, 0, 0);
  try
    Direct2DCanvas := TDirect2DCanvas.Create(TargetCanvas,
      PreviewPaintBox.ClientRect);
    try
      Direct2DCanvas.BeginDraw;
      try
        Direct2DCanvas.Brush.Color := clBlack;
        Direct2DCanvas.FillRect(PreviewPaintBox.ClientRect);
        if (FBackground.Width > 0) and (FBackground.Height > 0) then
        begin
          Destination := BackgroundDestinationRect;
          DrawBitmap(FBackground, Destination);
        end;
      finally
        Direct2DCanvas.EndDraw;
      end;
    finally
      Direct2DCanvas.Free;
    end;

    if (FBackground.Width > 0) and (FBackground.Height > 0) then
    begin
      TargetCanvas.Brush.Style := bsClear;
      SnapGuideX := FDraggingPreview and FDragSnapXActive and
        (((not IsFrameEditorActive) and (FDragMode = spdmMove) and
          (FDragButton = mbLeft)) or
         (IsFrameEditorActive and (FFrameDragHit = sdfhMove)));
      if SnapGuideX then
      begin
        TargetCanvas.Pen.Color := clAqua;
        TargetCanvas.Pen.Style := psSolid;
        TargetCanvas.Pen.Width := Max(1, MulDiv(2, CurrentPPI, 96));
      end
      else
      begin
        TargetCanvas.Pen.Color := TColor($00808080);
        TargetCanvas.Pen.Style := psDot;
        TargetCanvas.Pen.Width := 1;
      end;
      TargetCanvas.MoveTo((Destination.Left + Destination.Right) div 2,
        Destination.Top);
      TargetCanvas.LineTo((Destination.Left + Destination.Right) div 2,
        Destination.Bottom);
      if IsCommonFrameEditorActive then
      begin
        SnapGuideY := FDraggingPreview and FDragSnapYActive and
          (FFrameDragHit = sdfhMove);
        if SnapGuideY then
        begin
          TargetCanvas.Pen.Color := clAqua;
          TargetCanvas.Pen.Style := psSolid;
          TargetCanvas.Pen.Width := Max(1, MulDiv(2, CurrentPPI, 96));
        end
        else
        begin
          TargetCanvas.Pen.Color := TColor($00808080);
          TargetCanvas.Pen.Style := psDot;
          TargetCanvas.Pen.Width := 1;
        end;
        TargetCanvas.MoveTo(Destination.Left,
          (Destination.Top + Destination.Bottom) div 2);
        TargetCanvas.LineTo(Destination.Right,
          (Destination.Top + Destination.Bottom) div 2);
      end;
      TargetCanvas.Pen.Style := psSolid;
      TargetCanvas.Pen.Width := 1;
      TargetCanvas.Brush.Style := bsSolid;
    end;

    if IsCommonFrameEditorActive then
    begin
      FrameAccentLayer := FrameEditorSelectedLayer;
      FrameAppearance := ResolveSerifDrawFrameEditorAppearance(FSettings,
        FFrameEditorFrame, FrameAccentLayer,
        RoleNameForLayer(FrameAccentLayer));
      DrawFrame(CommonFramePreviewRect, FrameAppearance);
    end
    else if not IsFrameEditorActive and (FSettings.FrameKind in [1, 2]) and
      (FBackground.Width > 0) and (FBackground.Height > 0) then
    begin
      FrameAccentLayer := -1;
      if (FSelectedSnapshotIndex >= 0) and
        (FSelectedSnapshotIndex < Length(FSnapshots)) then
        FrameAccentLayer := FSnapshots[FSelectedSnapshotIndex].Layer;
      if FSettings.FrameKind = 1 then
        FrameAppearance := FSettings.ResolveCommonFrameAppearance(
          RoleNameForLayer(FrameAccentLayer))
      else
        FrameAppearance := FSettings.ResolveFrameAppearance(FrameAccentLayer,
          RoleNameForLayer(FrameAccentLayer));
      FrameRect := SerifDrawCommonFrameRect(Destination, FBackground.Width,
        FrameAppearance.Width, FrameAppearance.Height,
        FrameAppearance.PositionX, FrameAppearance.PositionY);
      DrawFrame(FrameRect, FrameAppearance);
    end;

    Direct2DCanvas := TDirect2DCanvas.Create(TargetCanvas,
      PreviewPaintBox.ClientRect);
    try
      Direct2DCanvas.BeginDraw;
      try
        CompanionRect := CompanionPreviewDestinationRect;
        DrawBitmap(FCompanionPreviewBitmap, CompanionRect);
        PreviewRect := PreviewDestinationRect;
        if not IsRoleNameEditorActive or FSettings.RoleNameVisible then
          DrawBitmap(FPreviewBitmap, PreviewRect);
      finally
        Direct2DCanvas.EndDraw;
      end;
    finally
      Direct2DCanvas.Free;
    end;

    if (not IsRoleNameEditorActive or FSettings.RoleNameVisible) and
      (FPreviewBitmap.Width > 0) and (FPreviewBitmap.Height > 0) and
      (PreviewRect.Width > 0) and (PreviewRect.Height > 0) and
      FPreviewSelected and not IsFrameEditorActive then
    begin
      TextLayout := TextPreviewHandleLayout;
      TextHandleState := System.Default(TSerifDrawTextPreviewHandleState);
      TextHandleState.Dpi := CurrentPPI;
      TextHandleState.LayoutRect := TextLayout.LayoutRect;
      TextHandleState.OutlineBlurRect := TextLayout.OutlineBlurRect;
      TextHandleState.OutlineWidthRect := TextLayout.OutlineWidthRect;
      TextHandleState.ShadowBlurRect := TextLayout.ShadowBlurRect;
      TextHandleState.ShadowOffsetRect := TextLayout.ShadowOffsetRect;
      TextHandleState.ShadowSpreadRect := TextLayout.ShadowSpreadRect;
      case FDragMode of
        spdmOutlineBlur:
          TextHandleState.ActiveHandle := sdthOutlineBlur;
        spdmOutlineWidth:
          TextHandleState.ActiveHandle := sdthOutlineWidth;
        spdmShadowBlur:
          TextHandleState.ActiveHandle := sdthShadowBlur;
        spdmShadowOffset:
          TextHandleState.ActiveHandle := sdthShadowOffset;
        spdmShadowSpread:
          TextHandleState.ActiveHandle := sdthShadowSpread;
      else
        TextHandleState.ActiveHandle := sdthNone;
      end;
      DrawSerifDrawTextPreviewHandles(TargetCanvas, TextHandleState);
    end;
    if IsCommonFrameEditorActive then
      DrawSerifDrawCommonFrameGuide(TargetCanvas,
        CommonFramePreviewRect, CurrentPPI, FFrameDragHit,
        FrameCornerRadiusHandleRect, FrameTabOffsetHandleRect,
        FrameTabWidthHandleRect, FrameTabHeightHandleRect,
        FrameBalloonTipHandleRect, FrameBalloonWidthHandleRect,
        FrameInnerPanelInsetXHandleRect, FrameInnerPanelInsetYHandleRect,
        FrameInnerPanelRadiusHandleRect,
        FrameDottedDashHandleRect, FrameDottedGapHandleRect,
        FrameOutlineWidthHandleRect,
        FrameShadowOffsetHandleRect,
        FrameShadowSpreadHandleRect, FrameShadowBlurHandleRect);
    Result := True;
  except
    on E: Exception do
    begin
      FDirect2DEnabled := False;
      SerifDrawDebugLog('Settings Direct2D preview disabled: ' +
        E.ClassName + ': ' + E.Message);
    end;
  end;
end;

procedure TFormSerifDrawSettings.PreviewPaintBoxPaint(Sender: TObject);
begin
  if not PaintPreviewDirect2D then
    PaintPreviewGdi;
end;

procedure TFormSerifDrawSettings.PaintPreviewGdi;
var
  Blend: BLENDFUNCTION;
  CompanionRect: TRect;
  Destination: TRect;
  FrameAccentLayer: Integer;
  FrameAppearance: TSerifDrawFrameStyle;
  FrameRect: TRect;
  PreviewRect: TRect;
  SnapGuideX: Boolean;
  SnapGuideY: Boolean;
  TextHandleState: TSerifDrawTextPreviewHandleState;
  TextLayout: TSerifDrawTextPreviewLayout;

  procedure DrawFrame(const ARect: TRect;
    const AStyle: TSerifDrawFrameStyle);
  var
    FrameScale: Double;
  begin
    FrameScale := Destination.Width / FBackground.Width;
    DrawSerifDrawCommonFrameAppearance(FBackBuffer.Canvas,
      ARect, CurrentPPI, AStyle.Shape,
      Round(AStyle.CornerRadius * FrameScale),
      Round(AStyle.TabWidth * FrameScale),
      Round(AStyle.TabHeight * FrameScale),
      Round(AStyle.TabOffset * FrameScale),
      AStyle.BalloonTailDirection,
      Round(AStyle.BalloonTailPosition * FrameScale),
      Round(AStyle.BalloonTailWidth * FrameScale),
      Round(AStyle.BalloonTailLength * FrameScale),
      AStyle.Layering,
      Round(AStyle.InnerPanelInsetX * FrameScale),
      Round(AStyle.InnerPanelInsetY * FrameScale),
      Round(AStyle.InnerPanelRadius * FrameScale),
      Round(AStyle.OutlineWidth * FrameScale),
      AStyle.OutlineStyle,
      Round(AStyle.DottedDashLength * FrameScale),
      Round(AStyle.DottedGapLength * FrameScale),
      Round(AStyle.ShadowOffsetX * FrameScale),
      Round(AStyle.ShadowOffsetY * FrameScale),
      Round(AStyle.ShadowSpread * FrameScale),
      Round(AStyle.ShadowBlur * FrameScale),
      AStyle.FillVisible, AStyle.OutlineVisible, AStyle.ShadowVisible,
      AStyle.FillColor, AStyle.OutlineColor, AStyle.InnerOutlineColor,
      AStyle.InnerPanelColor, AStyle.ShadowColor, AStyle.FillMode,
      AStyle.GradientStrength);
  end;

begin
  EnsureBackBuffer;
  FBackBuffer.Canvas.Brush.Color := clBlack;
  FBackBuffer.Canvas.FillRect(Rect(0, 0, FBackBuffer.Width,
    FBackBuffer.Height));
  if (FBackground.Width > 0) and (FBackground.Height > 0) then
  begin
    Destination := BackgroundDestinationRect;
    EnsureBackgroundPreview(Destination);
    FBackBuffer.Canvas.Draw(Destination.Left, Destination.Top,
      FBackgroundPreview);
    FBackBuffer.Canvas.Brush.Style := bsClear;
    SnapGuideX := FDraggingPreview and FDragSnapXActive and
      (((not IsFrameEditorActive) and (FDragMode = spdmMove) and
        (FDragButton = mbLeft)) or
       (IsFrameEditorActive and (FFrameDragHit = sdfhMove)));
    if SnapGuideX then
    begin
      FBackBuffer.Canvas.Pen.Color := clAqua;
      FBackBuffer.Canvas.Pen.Style := psSolid;
      FBackBuffer.Canvas.Pen.Width := Max(1, MulDiv(2, CurrentPPI, 96));
    end
    else
    begin
      FBackBuffer.Canvas.Pen.Color := TColor($00808080);
      FBackBuffer.Canvas.Pen.Style := psDot;
      FBackBuffer.Canvas.Pen.Width := 1;
    end;
    FBackBuffer.Canvas.MoveTo(
      (Destination.Left + Destination.Right) div 2, Destination.Top);
    FBackBuffer.Canvas.LineTo(
      (Destination.Left + Destination.Right) div 2, Destination.Bottom);
    if IsCommonFrameEditorActive then
    begin
      SnapGuideY := FDraggingPreview and FDragSnapYActive and
        (FFrameDragHit = sdfhMove);
      if SnapGuideY then
      begin
        FBackBuffer.Canvas.Pen.Color := clAqua;
        FBackBuffer.Canvas.Pen.Style := psSolid;
        FBackBuffer.Canvas.Pen.Width := Max(1,
          MulDiv(2, CurrentPPI, 96));
      end
      else
      begin
        FBackBuffer.Canvas.Pen.Color := TColor($00808080);
        FBackBuffer.Canvas.Pen.Style := psDot;
        FBackBuffer.Canvas.Pen.Width := 1;
      end;
      FBackBuffer.Canvas.MoveTo(Destination.Left,
        (Destination.Top + Destination.Bottom) div 2);
      FBackBuffer.Canvas.LineTo(Destination.Right,
        (Destination.Top + Destination.Bottom) div 2);
    end;
    FBackBuffer.Canvas.Pen.Style := psSolid;
    FBackBuffer.Canvas.Pen.Width := 1;
  end;
  if IsCommonFrameEditorActive then
  begin
    FrameAccentLayer := FrameEditorSelectedLayer;
    FrameAppearance := ResolveSerifDrawFrameEditorAppearance(FSettings,
      FFrameEditorFrame, FrameAccentLayer,
      RoleNameForLayer(FrameAccentLayer));
    DrawFrame(CommonFramePreviewRect, FrameAppearance);
  end
  else if not IsFrameEditorActive and (FSettings.FrameKind in [1, 2]) and
    (FBackground.Width > 0) and (FBackground.Height > 0) then
  begin
    FrameAccentLayer := -1;
    if (FSelectedSnapshotIndex >= 0) and
      (FSelectedSnapshotIndex < Length(FSnapshots)) then
      FrameAccentLayer := FSnapshots[FSelectedSnapshotIndex].Layer;
    if FSettings.FrameKind = 1 then
      FrameAppearance := FSettings.ResolveCommonFrameAppearance(
        RoleNameForLayer(FrameAccentLayer))
    else
      FrameAppearance := FSettings.ResolveFrameAppearance(FrameAccentLayer,
        RoleNameForLayer(FrameAccentLayer));
    FrameRect := SerifDrawCommonFrameRect(Destination, FBackground.Width,
      FrameAppearance.Width, FrameAppearance.Height,
      FrameAppearance.PositionX, FrameAppearance.PositionY);
    DrawFrame(FrameRect, FrameAppearance);
  end;
  CompanionRect := CompanionPreviewDestinationRect;
  if (FCompanionPreviewBitmap.Width > 0) and
    (FCompanionPreviewBitmap.Height > 0) and
    (CompanionRect.Width > 0) and (CompanionRect.Height > 0) then
  begin
    Blend.BlendOp := AC_SRC_OVER;
    Blend.BlendFlags := 0;
    Blend.SourceConstantAlpha := 255;
    Blend.AlphaFormat := AC_SRC_ALPHA;
    Winapi.Windows.AlphaBlend(FBackBuffer.Canvas.Handle,
      CompanionRect.Left, CompanionRect.Top, CompanionRect.Width,
      CompanionRect.Height, FCompanionPreviewBitmap.Canvas.Handle,
      0, 0, FCompanionPreviewBitmap.Width, FCompanionPreviewBitmap.Height,
      Blend);
  end;
  PreviewRect := PreviewDestinationRect;
  if (not IsRoleNameEditorActive or FSettings.RoleNameVisible) and
    (FPreviewBitmap.Width > 0) and (FPreviewBitmap.Height > 0) and
    (PreviewRect.Width > 0) and (PreviewRect.Height > 0) then
  begin
    Blend.BlendOp := AC_SRC_OVER;
    Blend.BlendFlags := 0;
    Blend.SourceConstantAlpha := 255;
    Blend.AlphaFormat := AC_SRC_ALPHA;
    Winapi.Windows.AlphaBlend(FBackBuffer.Canvas.Handle,
      PreviewRect.Left, PreviewRect.Top, PreviewRect.Width, PreviewRect.Height,
      FPreviewBitmap.Canvas.Handle, 0, 0, FPreviewBitmap.Width,
      FPreviewBitmap.Height, Blend);
    if FPreviewSelected and not IsFrameEditorActive then
    begin
      TextLayout := TextPreviewHandleLayout;
      TextHandleState := System.Default(TSerifDrawTextPreviewHandleState);
      TextHandleState.Dpi := CurrentPPI;
      TextHandleState.LayoutRect := TextLayout.LayoutRect;
      TextHandleState.OutlineBlurRect := TextLayout.OutlineBlurRect;
      TextHandleState.OutlineWidthRect := TextLayout.OutlineWidthRect;
      TextHandleState.ShadowBlurRect := TextLayout.ShadowBlurRect;
      TextHandleState.ShadowOffsetRect := TextLayout.ShadowOffsetRect;
      TextHandleState.ShadowSpreadRect := TextLayout.ShadowSpreadRect;
      case FDragMode of
        spdmOutlineBlur:
          TextHandleState.ActiveHandle := sdthOutlineBlur;
        spdmOutlineWidth:
          TextHandleState.ActiveHandle := sdthOutlineWidth;
        spdmShadowBlur:
          TextHandleState.ActiveHandle := sdthShadowBlur;
        spdmShadowOffset:
          TextHandleState.ActiveHandle := sdthShadowOffset;
        spdmShadowSpread:
          TextHandleState.ActiveHandle := sdthShadowSpread;
      else
        TextHandleState.ActiveHandle := sdthNone;
      end;
      DrawSerifDrawTextPreviewHandles(FBackBuffer.Canvas, TextHandleState);
    end;
  end;
  if IsCommonFrameEditorActive then
    DrawSerifDrawCommonFrameGuide(FBackBuffer.Canvas,
      CommonFramePreviewRect, CurrentPPI, FFrameDragHit,
      FrameCornerRadiusHandleRect, FrameTabOffsetHandleRect,
      FrameTabWidthHandleRect, FrameTabHeightHandleRect,
      FrameBalloonTipHandleRect, FrameBalloonWidthHandleRect,
      FrameInnerPanelInsetXHandleRect, FrameInnerPanelInsetYHandleRect,
      FrameInnerPanelRadiusHandleRect,
      FrameDottedDashHandleRect, FrameDottedGapHandleRect,
      FrameOutlineWidthHandleRect,
      FrameShadowOffsetHandleRect,
      FrameShadowSpreadHandleRect, FrameShadowBlurHandleRect);
  PreviewPaintBox.Canvas.Draw(0, 0, FBackBuffer);
end;

function TFormSerifDrawSettings.CompanionPreviewDestinationRect: TRect;
var
  Anchor: TPointF;
  BackgroundRect: TRect;
  ImageLeft: Double;
  ImageTop: Double;
  Placement: Byte;
  PositionX: Double;
  PositionY: Double;
  RenderScale: Double;
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) or
    (FCompanionPreviewImage = nil) or
    (FCompanionPreviewBitmap.Width <= 0) or
    (FCompanionPreviewBitmap.Height <= 0) then
    Exit;
  if IsRoleNameEditorActive then
  begin
    Placement := FSettings.Placement;
    PositionX := FSettings.PositionX;
    PositionY := FSettings.PositionY;
  end
  else
  begin
    Placement := FSettings.RoleNamePlacement;
    PositionX := FSettings.RoleNamePositionX;
    PositionY := FSettings.RoleNamePositionY;
  end;
  BackgroundRect := BackgroundDestinationRect;
  Scale := BackgroundRect.Width / FBackground.Width;
  if Scale <= 0 then
    Exit;
  RenderScale := FCompanionPreviewRenderScale;
  if RenderScale <= 0 then
    RenderScale := 1.0;
  Anchor := SerifDrawPlacementAnchor(Placement,
    FCompanionPreviewImage.Bounds, FCompanionPreviewImage.LayoutBounds);
  ImageLeft := FBackground.Width * 0.5 + PositionX -
    Anchor.X / RenderScale;
  ImageTop := FBackground.Height * 0.5 + PositionY -
    Anchor.Y / RenderScale;
  Result.Left := BackgroundRect.Left + Round(ImageLeft * Scale);
  Result.Top := BackgroundRect.Top + Round(ImageTop * Scale);
  Result.Right := Result.Left + Max(1,
    Round(FCompanionPreviewBitmap.Width * Scale / RenderScale));
  Result.Bottom := Result.Top + Max(1,
    Round(FCompanionPreviewBitmap.Height * Scale / RenderScale));
end;

function TFormSerifDrawSettings.PreviewDestinationRect: TRect;
var
  Anchor: TPointF;
  BackgroundRect: TRect;
  ImageLeft: Double;
  ImageTop: Double;
  RenderScale: Double;
  PreviewScale: Double;
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) or
    (FPreviewImage = nil) or
    (FPreviewBitmap.Width <= 0) or (FPreviewBitmap.Height <= 0) then
    Exit;
  BackgroundRect := BackgroundDestinationRect;
  Scale := BackgroundRect.Width / FBackground.Width;
  if Scale <= 0 then
    Exit;
  RenderScale := FPreviewRenderScale;
  if RenderScale <= 0 then
    RenderScale := 1.0;
  Anchor := SerifDrawPlacementAnchor(EditingPlacement,
    FPreviewImage.Bounds, FPreviewImage.LayoutBounds);
  PreviewScale := Max(0.0001, FPreviewDragScale);
  ImageLeft := FBackground.Width * 0.5 + EditingPositionX -
    Anchor.X * PreviewScale / RenderScale;
  ImageTop := FBackground.Height * 0.5 + EditingPositionY -
    Anchor.Y * PreviewScale / RenderScale;
  Result.Left := BackgroundRect.Left + Round(ImageLeft * Scale);
  Result.Top := BackgroundRect.Top + Round(ImageTop * Scale);
  Result.Right := Result.Left + Max(1,
    Round(FPreviewBitmap.Width * Scale * PreviewScale / RenderScale));
  Result.Bottom := Result.Top + Max(1,
    Round(FPreviewBitmap.Height * Scale * PreviewScale / RenderScale));
end;

function TFormSerifDrawSettings.PreviewLayoutRect: TRect;
var
  BackgroundRect: TRect;
  EffectRect: TRect;
  RenderScale: Double;
  PreviewScale: Double;
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (FPreviewImage = nil) or (FBackground.Width <= 0) or
    (FBackground.Height <= 0) then
    Exit;
  BackgroundRect := BackgroundDestinationRect;
  Scale := BackgroundRect.Width / FBackground.Width;
  if Scale <= 0 then
    Exit;
  RenderScale := FPreviewRenderScale;
  if RenderScale <= 0 then
    RenderScale := 1.0;
  PreviewScale := Max(0.0001, FPreviewDragScale);
  EffectRect := PreviewDestinationRect;
  Result.Left := EffectRect.Left + Round(
    (FPreviewImage.LayoutBounds.Left - FPreviewImage.Bounds.Left) * Scale /
    RenderScale * PreviewScale);
  Result.Top := EffectRect.Top + Round(
    (FPreviewImage.LayoutBounds.Top - FPreviewImage.Bounds.Top) * Scale /
    RenderScale * PreviewScale);
  Result.Right := EffectRect.Left + Round(
    (FPreviewImage.LayoutBounds.Right - FPreviewImage.Bounds.Left) * Scale /
    RenderScale * PreviewScale);
  Result.Bottom := EffectRect.Top + Round(
    (FPreviewImage.LayoutBounds.Bottom - FPreviewImage.Bounds.Top) * Scale /
    RenderScale * PreviewScale);
  if Result.Right <= Result.Left then
    Result.Right := Result.Left + 1;
  if Result.Bottom <= Result.Top then
    Result.Bottom := Result.Top + 1;
end;

procedure TFormSerifDrawSettings.RenderSelectedPreview(
  const ARenderCompanion: Boolean);
var
  CompanionBitmap: Vcl.Graphics.TBitmap;
  CompanionImage: TTextRenderImage;
  Destination: TRect;
  Metrics: TTextRenderMetrics;
  NewImage: TTextRenderImage;
  RenderScale: Double;
  Request: TTextRenderRequest;
  Shadow: TTextRenderShadow;
  Snapshot: TSerifDrawSnapshot;
  Style: TSerifDrawLayerStyle;

  procedure ApplyStyleToRequest(const AStyle: TSerifDrawLayerStyle);
  var
    OutlineBlurPixels: Double;
    OutlineWidthPixels: Double;
  begin
    Request.FontFamilies := [AStyle.FontName, 'Yu Gothic UI', 'Meiryo UI',
      'Segoe UI'];
    Request.FontSize := Max(1.0, AStyle.FontSize * RenderScale);
    Request.LetterSpacing := AStyle.LetterSpacing * RenderScale;
    Request.LineSpacing := AStyle.LineSpacing * RenderScale;
    Request.FontStyle := [];
    if (AStyle.FontStyles and SERIF_FONT_BOLD) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.Bold);
    if (AStyle.FontStyles and SERIF_FONT_ITALIC) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.Italic);
    Request.FillColor := AStyle.FillColor;
    // 設定とキャッシュキーには比率を保持し、Skiaへ渡す直前だけ実画素へ変換する。
    OutlineWidthPixels := SerifDrawOutlineWidthPixels(AStyle.OutlineWidth,
      AStyle.FontSize) * RenderScale;
    OutlineBlurPixels := SerifDrawOutlineBlurPixels(AStyle.OutlineBlur,
      AStyle.FontSize) * RenderScale;
    if not AStyle.OutlineEnabled then
      Request.Outlines := nil
    else if OutlineBlurPixels <= 0 then
      Request.Outlines := [TTextRenderOutline.Create(OutlineWidthPixels,
        AStyle.OutlineColor)]
    else if AStyle.BlurColor = AStyle.OutlineColor then
      Request.Outlines := [TTextRenderOutline.Create(OutlineWidthPixels,
        OutlineBlurPixels,
        AStyle.BlurColor)]
    else
      Request.Outlines := [
        TTextRenderOutline.Create(OutlineWidthPixels, OutlineBlurPixels,
          AStyle.BlurColor),
        TTextRenderOutline.Create(OutlineWidthPixels,
          AStyle.OutlineColor)];
    Request.Shadows := [];
    if AStyle.ShadowEnabled then
    begin
      Shadow := System.Default(TTextRenderShadow);
      Shadow.Offset := PointF(
        SerifDrawShadowOffsetPixels(AStyle.ShadowOffsetX, AStyle.FontSize) *
          RenderScale,
        SerifDrawShadowOffsetPixels(AStyle.ShadowOffsetY, AStyle.FontSize) *
          RenderScale);
      Shadow.BlurRadius := SerifDrawShadowBlurPixels(AStyle.ShadowBlur,
        AStyle.FontSize) * RenderScale;
      Shadow.SpreadRadius := SerifDrawShadowSpreadPixels(
        AStyle.ShadowSpread, AStyle.FontSize) * RenderScale;
      Shadow.Color := AStyle.ShadowColor;
      Request.Shadows := [Shadow];
    end;
  end;
begin
  if (FPreviewRenderer = nil) or (FSelectedSnapshotIndex < 0) or
    (FSelectedSnapshotIndex >= Length(FSnapshots)) then
  begin
    FreeAndNil(FCompanionPreviewImage);
    FCompanionPreviewBitmap.SetSize(0, 0);
    FreeAndNil(FPreviewImage);
    PreviewPaintBox.Invalidate;
    Exit;
  end;
  RenderScale := 1.0;
  if FBackground.Width > 0 then
  begin
    Destination := BackgroundDestinationRect;
    if Destination.Width > 0 then
      RenderScale := EnsureRange(Destination.Width / FBackground.Width,
        0.05, 1.0);
  end;
  // 表示中の背景倍率で描画し、ドラッグ開始・終了時に解像度を
  // 切り替えない。倍率変更による見かけ上の拡大を防ぐ。
  Snapshot := FSnapshots[FSelectedSnapshotIndex];
  Style := EditingTextStyle(Snapshot.Layer);
  Request := TTextRenderRequest.Default;
  if IsRoleNameEditorActive then
  begin
    Request.Text := Trim(Snapshot.Chara);
    if Request.Text = '' then
      Request.Text := '未取得';
    Request.Alignment := TTextRenderAlignment(EditingPlacement mod 3);
  end
  else
  begin
    Request.Text := Snapshot.Serif;
    Request.Alignment := TTextRenderAlignment(Style.Alignment);
  end;
  ApplyStyleToRequest(Style);
  NewImage := nil;
  CompanionImage := nil;
  CompanionBitmap := nil;
  try
    NewImage := FPreviewRenderer.Render(Request, Metrics);
    UpdatePreviewBitmap(NewImage);
    FreeAndNil(FPreviewImage);
    FPreviewImage := NewImage;
    FPreviewRenderScale := RenderScale;
    NewImage := nil;
    SerifDrawDebugLog(Format(
      'Settings preview rendered: layer=%d image=%dx%d scale=%.3f elapsed=%.3fms',
      [Snapshot.Layer, FPreviewImage.Width, FPreviewImage.Height,
       RenderScale, Metrics.TotalMilliseconds]));
    if ARenderCompanion and
      (IsRoleNameEditorActive or FSettings.RoleNameVisible) then
    begin
      if IsRoleNameEditorActive then
      begin
        Style := FSettings.ResolveStyle(Snapshot.Layer, Snapshot.Chara);
        Request.Text := Snapshot.Serif;
        Request.Alignment := TTextRenderAlignment(FSettings.Alignment);
      end
      else
      begin
        Style := FSettings.ResolveRoleNameStyle(Snapshot.Layer,
          Snapshot.Chara);
        Request.Text := Trim(Snapshot.Chara);
        if Request.Text = '' then
          Request.Text := '未取得';
        Request.Alignment := TTextRenderAlignment(
          FSettings.RoleNamePlacement mod 3);
      end;
      ApplyStyleToRequest(Style);
      CompanionImage := FPreviewRenderer.Render(Request, Metrics);
      CompanionBitmap := CreatePreviewBitmap(CompanionImage);
      FreeAndNil(FCompanionPreviewImage);
      FCompanionPreviewImage := CompanionImage;
      FCompanionPreviewRenderScale := RenderScale;
      CompanionImage := nil;
      FCompanionPreviewBitmap.Free;
      FCompanionPreviewBitmap := CompanionBitmap;
      CompanionBitmap := nil;
    end
    else if ARenderCompanion then
    begin
      FreeAndNil(FCompanionPreviewImage);
      FCompanionPreviewBitmap.SetSize(0, 0);
    end;
  except
    on E: Exception do
    begin
      SerifDrawDebugLog('Settings preview render failed: ' + E.Message);
    end;
  end;
  CompanionBitmap.Free;
  CompanionImage.Free;
  NewImage.Free;
  PreviewPaintBox.Invalidate;
end;

procedure TFormSerifDrawSettings.TransparencyTrackChange(Sender: TObject);
var
  Alpha: Cardinal;
  Style: TSerifDrawLayerStyle;
begin
  if FUpdatingControls or (Sender <> FOpacityTrack) then
    Exit;
  if (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
    Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer)
  else
    Style := EditingTextStyle(-1);
  Alpha := Cardinal(FOpacityTrack.Alpha) shl 24;
  case FOpacityTarget of
    sotText:
      Style.FillColor := (Style.FillColor and $00FFFFFF) or Alpha;
    sotOutline:
      Style.OutlineColor := (Style.OutlineColor and $00FFFFFF) or Alpha;
    sotShadow:
      Style.ShadowColor := (Style.ShadowColor and $00FFFFFF) or Alpha;
    sotBlur:
      Style.BlurColor := (Style.BlurColor and $00FFFFFF) or Alpha;
  end;
  ApplyColorsToSelectedLayer(Style);
  RenderSelectedPreview(False);
end;

procedure TFormSerifDrawSettings.UpdateTransparencyTracks;
var
  Alpha: Byte;
  Style: TSerifDrawLayerStyle;
  WasUpdating: Boolean;
begin
  if FOpacityTrack = nil then
    Exit;
  WasUpdating := FUpdatingControls;
  FUpdatingControls := True;
  try
    if (FSelectedSnapshotIndex >= 0) and
      (FSelectedSnapshotIndex < Length(FSnapshots)) then
      Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer)
    else
      Style := EditingTextStyle(-1);
    Alpha := 255;
    case FOpacityTarget of
      sotText: Alpha := Byte(Style.FillColor shr 24);
      sotOutline: Alpha := Byte(Style.OutlineColor shr 24);
      sotShadow: Alpha := Byte(Style.ShadowColor shr 24);
      sotBlur: Alpha := Byte(Style.BlurColor shr 24);
    end;
    FOpacityTrack.Alpha := Alpha;
    if FToolbarOpacityText <> nil then
      FToolbarOpacityText.CheckState := TFormattingToolbarCheckState(
        Ord(FOpacityTarget = sotText));
    if FToolbarOpacityOutline <> nil then
      FToolbarOpacityOutline.CheckState := TFormattingToolbarCheckState(
        Ord(FOpacityTarget = sotOutline));
    if FToolbarOpacityShadow <> nil then
      FToolbarOpacityShadow.CheckState := TFormattingToolbarCheckState(
        Ord(FOpacityTarget = sotShadow));
    if FToolbarOpacityBlur <> nil then
      FToolbarOpacityBlur.CheckState := TFormattingToolbarCheckState(
        Ord(FOpacityTarget = sotBlur));
  finally
    FUpdatingControls := WasUpdating;
  end;
end;

procedure TFormSerifDrawSettings.StyleEditChange(Sender: TObject);
var
  ErrorText: string;
begin
  if FUpdatingControls then
    Exit;
  if CommitSelectedStyle(ErrorText) then
  begin
    UpdateTransparencyTracks;
    UpdateToolbarColorAccents;
    RenderSelectedPreview(False);
  end;
end;

procedure TFormSerifDrawSettings.FormattingToolbarExecute(Sender: TObject;
  Button: TFormattingToolbarButton);
var
  DefaultSettings: TSerifDrawSettings;
  PopupPoint: TPoint;
  Style: TSerifDrawLayerStyle;
begin
  if Button.Tag = 11 then
  begin
    PopupPoint := FFormattingToolbar.ClientToScreen(
      Point(FToolbarPlacement.Left,
        FToolbarPlacement.Top + FToolbarPlacement.Height));
    FPlacementPopup.Popup(PopupPoint, EditingPlacement);
    Exit;
  end;
  if Button.Tag = 12 then
  begin
    if IsRoleNameEditorActive then
    begin
      if (FSelectedSnapshotIndex >= 0) and
        (FSelectedSnapshotIndex < Length(FSnapshots)) then
        FSettings.RemoveRoleNameLayerColors(
          FSnapshots[FSelectedSnapshotIndex].Chara)
      else
      begin
        DefaultSettings := TSerifDrawSettings.Default;
        Style := DefaultSettings.ResolveRoleNameStyle(-1, '');
        ApplyColorsToSelectedLayer(Style);
      end;
    end
    else if (FSelectedSnapshotIndex >= 0) and
      (FSelectedSnapshotIndex < Length(FSnapshots)) then
      FSettings.RemoveLayerColors(FSnapshots[FSelectedSnapshotIndex].Chara)
    else
    begin
      DefaultSettings := TSerifDrawSettings.Default;
      Style := DefaultSettings.ResolveStyle(-1, '');
      ApplyColorsToSelectedLayer(Style);
    end;
    LoadSelectedStyle;
    Exit;
  end;
  if Button.Tag = 13 then
  begin
    FSettings := TSerifDrawSettings.Default;
    LoadSelectedStyle;
    Exit;
  end;
  if not FUpdatingControls then
    StyleEditChange(Button);
end;

procedure TFormSerifDrawSettings.UpdateColorPicker;
var
  Argb: Cardinal;
  Style: TSerifDrawLayerStyle;
begin
  if (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
    Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer)
  else
    Style := EditingTextStyle(-1);
  Argb := Style.FillColor;
  case FColorTarget of
    sctText: Argb := Style.FillColor;
    sctOutline: Argb := Style.OutlineColor;
    sctShadow: Argb := Style.ShadowColor;
    sctBlur: Argb := Style.BlurColor;
  end;
  FUpdatingControls := True;
  try
    if FColorPicker <> nil then
      FColorPicker.Enabled := True;
    if FToolbarFillColor <> nil then
      FToolbarFillColor.CheckState := TFormattingToolbarCheckState(
        Ord(FOpacityTarget = sotText));
    if FToolbarOutlineColor <> nil then
      FToolbarOutlineColor.CheckState := TFormattingToolbarCheckState(
        Ord(FOpacityTarget = sotOutline));
    if FToolbarShadowColor <> nil then
      FToolbarShadowColor.CheckState := TFormattingToolbarCheckState(
        Ord(FOpacityTarget = sotShadow));
    if FToolbarBlurColor <> nil then
      FToolbarBlurColor.CheckState := TFormattingToolbarCheckState(
        Ord(FOpacityTarget = sotBlur));
    if FColorPicker <> nil then
      FColorPicker.Color := RGB((Argb shr 16) and $FF,
        (Argb shr 8) and $FF, Argb and $FF);
  finally
    FUpdatingControls := False;
  end;
end;

procedure TFormSerifDrawSettings.UpdatePlacementButton;
begin
  if FToolbarPlacement = nil then
    Exit;
  FToolbarPlacement.Glyph := TFormattingToolbarGlyph(
    Ord(tbgPlacementTopLeft) + EditingPlacement);
  FToolbarPlacement.CheckState := tbcsChecked;
  if IsRoleNameEditorActive then
    FToolbarPlacement.Hint := '配役名配置：' +
      SerifDrawPlacementName(EditingPlacement)
  else
    FToolbarPlacement.Hint := '文字配置：' +
      SerifDrawPlacementName(EditingPlacement);
end;

procedure TFormSerifDrawSettings.UpdateToolbarColorAccents;
var
  Color: TColor;
  Style: TSerifDrawLayerStyle;
begin
  if (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
    Style := EditingTextStyle(FSnapshots[FSelectedSnapshotIndex].Layer)
  else
    Style := EditingTextStyle(-1);
  Color := RGB((Style.FillColor shr 16) and $FF,
    (Style.FillColor shr 8) and $FF, Style.FillColor and $FF);
  if FToolbarFillColor <> nil then
    FToolbarFillColor.AccentColor := Color;
  Color := RGB((Style.OutlineColor shr 16) and $FF,
    (Style.OutlineColor shr 8) and $FF, Style.OutlineColor and $FF);
  if FToolbarOutlineColor <> nil then
    FToolbarOutlineColor.AccentColor := Color;
  Color := RGB((Style.BlurColor shr 16) and $FF,
    (Style.BlurColor shr 8) and $FF, Style.BlurColor and $FF);
  if FToolbarBlurColor <> nil then
    FToolbarBlurColor.AccentColor := Color;
  Color := RGB((Style.ShadowColor shr 16) and $FF,
    (Style.ShadowColor shr 8) and $FF, Style.ShadowColor and $FF);
  if FToolbarShadowColor <> nil then
    FToolbarShadowColor.AccentColor := Color;
  UpdateColorPicker;
  UpdateResetSelectedColorButton;
end;

procedure TFormSerifDrawSettings.UpdateResetSelectedColorButton;
var
  HasOverride: Boolean;
  Layer: Integer;
begin
  if FToolbarResetSelectedColor = nil then
    Exit;
  Layer := -1;
  if (FSelectedSnapshotIndex >= 0) and
    (FSelectedSnapshotIndex < Length(FSnapshots)) then
    Layer := FSnapshots[FSelectedSnapshotIndex].Layer;
  HasOverride := HasColorOverride(Layer, IsRoleNameEditorActive);
  FToolbarResetSelectedColor.Enabled := HasOverride;
  if IsRoleNameEditorActive then
  begin
    if HasOverride then
      FToolbarResetSelectedColor.Hint :=
        'この配役名の個別色を解除して共通色を使用'
    else
      FToolbarResetSelectedColor.Hint := 'この配役名は共通色を使用中';
  end
  else
  begin
    if HasOverride then
      FToolbarResetSelectedColor.Hint :=
        'このセリフの個別色を解除して共通色を使用'
    else
      FToolbarResetSelectedColor.Hint := 'このセリフは共通色を使用中';
  end;
  LayerComboBox.Invalidate;
end;

function TFormSerifDrawSettings.CreatePreviewBitmap(
  const AImage: TTextRenderImage): Vcl.Graphics.TBitmap;
var
  Destination: PByte;
  Source: PTextRenderPixel;
  X: Integer;
  Y: Integer;
begin
  Result := nil;
  if (AImage = nil) or AImage.IsEmpty then
    Exit;
  Result := Vcl.Graphics.TBitmap.Create;
  try
    Result.PixelFormat := pf32bit;
    Result.SetSize(AImage.Width, AImage.Height);
    for Y := 0 to AImage.Height - 1 do
    begin
      Source := PTextRenderPixel(PByte(AImage.Data) +
        NativeInt(Y) * AImage.Stride);
      Destination := Result.ScanLine[Y];
      for X := 0 to AImage.Width - 1 do
      begin
        Destination[0] := (Cardinal(Source^.B) * Source^.A + 127) div 255;
        Destination[1] := (Cardinal(Source^.G) * Source^.A + 127) div 255;
        Destination[2] := (Cardinal(Source^.R) * Source^.A + 127) div 255;
        Destination[3] := Source^.A;
        Inc(Destination, 4);
        Inc(Source);
      end;
    end;
    Result.AlphaFormat := afPremultiplied;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

procedure TFormSerifDrawSettings.UpdatePreviewBitmap(
  const AImage: TTextRenderImage);
var
  NewBitmap: Vcl.Graphics.TBitmap;
begin
  NewBitmap := CreatePreviewBitmap(AImage);
  if NewBitmap = nil then
    Exit;
  FPreviewBitmap.Free;
  FPreviewBitmap := NewBitmap;
end;

procedure TFormSerifDrawSettings.SetBackgroundRgba(const Pixels: TBytes;
  Width, Height: Integer);
var
  Destination: PByte;
  Source: PByte;
  X: Integer;
  Y: Integer;
begin
  if (Width <= 0) or (Height <= 0) or
    (Length(Pixels) <> NativeInt(Width) * Height * 4) then
    Exit;
  FBackground.PixelFormat := pf32bit;
  FBackground.SetSize(Width, Height);
  FBackgroundPreview.SetSize(0, 0);
  Source := @Pixels[0];
  for Y := 0 to Height - 1 do
  begin
    Destination := FBackground.ScanLine[Y];
    for X := 0 to Width - 1 do
    begin
      Destination[0] := Source[2];
      Destination[1] := Source[1];
      Destination[2] := Source[0];
      Destination[3] := Source[3];
      Inc(Destination, 4);
      Inc(Source, 4);
    end;
  end;
  FitImage;
end;

procedure TFormSerifDrawSettings.SetCaptureStatus(const Value: string);
begin
  SerifDrawDebugLog('Settings capture status: ' + Value);
end;

procedure TFormSerifDrawSettings.SetSnapshots(
  const ASnapshots: TArray<TSerifDrawSnapshot>);
var
  CurrentFrame: Integer;
  DuplicateRole: Boolean;
  I: Integer;
  J: Integer;
  RoleKey: string;
  RoleList: string;
  RoleName: string;
begin
  StoreFrameEditorTarget;
  SetLength(FSnapshots, 0);
  for I := 0 to High(ASnapshots) do
  begin
    RoleKey := SerifDrawRoleNameKey(ASnapshots[I].Chara);
    DuplicateRole := False;
    for J := 0 to High(FSnapshots) do
      if SerifDrawRoleNameKey(FSnapshots[J].Chara) = RoleKey then
      begin
        DuplicateRole := True;
        Break;
      end;
    if DuplicateRole then
      Continue;
    SetLength(FSnapshots, Length(FSnapshots) + 1);
    FSnapshots[High(FSnapshots)] := ASnapshots[I];
  end;
  CurrentFrame := -1;
  if Length(FSnapshots) > 0 then
    CurrentFrame := FSnapshots[0].CurrentFrame;
  RoleList := '';
  LayerComboBox.Items.BeginUpdate;
  try
    LayerComboBox.Items.Clear;
    for I := 0 to High(FSnapshots) do
    begin
      RoleName := Trim(FSnapshots[I].Chara);
      if RoleName = '' then
        RoleName := '未取得';
      LayerComboBox.Items.Add(RoleName);
      if RoleList <> '' then
        RoleList := RoleList + ',';
      RoleList := RoleList + RoleName;
    end;
  finally
    LayerComboBox.Items.EndUpdate;
  end;
  if LayerComboBox.Items.Count > 0 then
  begin
    LayerComboBox.ItemIndex := 0;
    FSelectedSnapshotIndex := 0;
    FPreviewSelected := True;
  end
  else
  begin
    LayerComboBox.ItemIndex := -1;
    FSelectedSnapshotIndex := -1;
    FPreviewSelected := False;
  end;
  FFrameEditorFrame.SetLayerSelectorItems(LayerComboBox.Items,
    LayerComboBox.ItemIndex);
  LoadFrameEditorTarget(FFrameEditorFrame.FrameKind,
    FrameEditorSelectedLayer, FrameEditorSelectedRoleName);
  LoadSelectedStyle;
  SerifDrawDebugLog(Format(
    'Settings snapshots fixed: frame=%d count=%d roles=[%s]',
    [CurrentFrame, Length(FSnapshots), RoleList]));
end;

function TFormSerifDrawSettings.TryGetSettings(
  out ASettings: TSerifDrawSettings; out AError: string): Boolean;
begin
  Result := CommitSelectedStyle(AError);
  if Result then
  begin
    StoreFrameEditorTarget;
    FSettings.FrameKind := Ord(FFrameEditorFrame.FrameKind);
    ASettings := FSettings;
    SerifDrawDebugLog(Format('Settings form accepted: layer_colors=%d data=%s',
      [Length(ASettings.LayerColors), ASettings.Encode]));
  end
  else
    SerifDrawDebugLog('Settings form validation failed: ' + AError);
end;

end.
