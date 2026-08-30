unit PluginFilterSerifDrawFrameEditorFrame;

interface

// 枠の種類、形状、装飾、レイヤー対象を編集する画面部品を提供する。

uses
  System.Classes,
  System.Types,
  System.UITypes,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  FormattingToolbarButtons,
  PluginFilterSerifDrawCommonFrameEditorFrame,
  PluginFilterSerifDrawSettings;

type
  // 配置プリセット番号を設定フォームへ通知するイベント。
  TSerifDrawFrameLayoutPresetEvent = procedure(Sender: TObject;
    const APreset: Integer) of object;

  // 編集対象とする枠の適用範囲。
  TSerifDrawFrameKind = (
    sdfkNone,
    sdfkCommon,
    sdfkCharacter
  );

  // 枠プレビューと保存設定で共有する形状種別。
  TSerifDrawFrameShape = (
    sdfsRectangle,
    sdfsRoundedRectangle,
    sdfsTab,
    sdfsSpeechBalloon
  );

  TFrameSerifDrawFrameEditor = class(TFrame)
    CommonSettingsHostPanel: TPanel;
    FrameAccentSourceComboBox: TComboBox;
    FrameColorPresetComboBox: TComboBox;
    FrameFillModeComboBox: TComboBox;
    FrameGradientStrengthLabel: TLabel;
    FrameGradientStrengthTrackBar: TTrackBar;
    FrameKindComboBox: TComboBox;
    FrameLayerComboBox: TComboBox;
    FrameLayeringComboBox: TComboBox;
    FrameLayoutPresetComboBox: TComboBox;
    FrameShapeComboBox: TComboBox;
    FrameOutlineStyleComboBox: TComboBox;
    FramePresetComboBox: TComboBox;
    PreviewHostPanel: TPanel;
    TypePanel: TPanel;
    procedure FrameKindComboBoxChange(Sender: TObject);
    procedure FrameAccentSourceComboBoxChange(Sender: TObject);
    procedure FrameColorPresetComboBoxChange(Sender: TObject);
    procedure FrameFillModeComboBoxChange(Sender: TObject);
    procedure FrameGradientStrengthTrackBarChange(Sender: TObject);
    procedure FrameLayerComboBoxChange(Sender: TObject);
    procedure FrameLayeringComboBoxChange(Sender: TObject);
    procedure FrameLayoutPresetComboBoxChange(Sender: TObject);
    procedure FrameShapeComboBoxChange(Sender: TObject);
    procedure FrameOutlineStyleComboBoxChange(Sender: TObject);
    procedure FramePresetComboBoxChange(Sender: TObject);
    procedure FrameKindComboBoxDrawItem(Control: TWinControl;
      Index: Integer; Rect: TRect; State: TOwnerDrawState);
  private
    FCommonEditorFrame: TFrameSerifDrawCommonFrameEditor;
    FAccentSource: Integer;
    FCommonFrameHeight: Integer;
    FCommonFrameWidth: Integer;
    FBalloonTailDirection: Integer;
    FBalloonTailLength: Integer;
    FBalloonTailPosition: Integer;
    FBalloonTailWidth: Integer;
    FCornerRadius: Integer;
    FDottedDashLength: Integer;
    FDottedGapLength: Integer;
    FControlsInitialized: Boolean;
    FFillVisible: Boolean;
    FFillMode: Integer;
    FFillVisibleButton: TFormattingToolbarButton;
    FFrameKind: TSerifDrawFrameKind;
    FFrameShape: TSerifDrawFrameShape;
    FGradientStrength: Integer;
    FLayering: Integer;
    FInnerPanelInsetX: Integer;
    FInnerPanelInsetY: Integer;
    FInnerPanelRadius: Integer;
    FOnLayoutPreset: TSerifDrawFrameLayoutPresetEvent;
    FOnResetLayerFrame: TNotifyEvent;
    FOnSettingsChange: TNotifyEvent;
    FOutlineVisibleButton: TFormattingToolbarButton;
    FOutlineStyle: Integer;
    FOutlineWidth: Integer;
    FOutlineVisible: Boolean;
    FShadowVisibleButton: TFormattingToolbarButton;
    FShadowBlur: Double;
    FShadowOffsetX: Double;
    FShadowOffsetY: Double;
    FShadowSpread: Double;
    FShadowVisible: Boolean;
    FStyleToolbar: TFormattingToolbarButtons;
    FTabHeight: Integer;
    FTabOffset: Integer;
    FTabWidth: Integer;
    procedure CommonStyleChange(Sender: TObject);
    procedure ApplyColorPreset(const APreset: Integer);
    procedure ApplyPreset(const APreset: Integer);
    function GetFillColor: Cardinal;
    function GetFillVisible: Boolean;
    function GetInnerOutlineColor: Cardinal;
    function GetInnerPanelColor: Cardinal;
    function GetFrameKind: TSerifDrawFrameKind;
    function GetSelectedLayerIndex: Integer;
    function GetOutlineColor: Cardinal;
    function GetOutlineVisible: Boolean;
    function GetShadowColor: Cardinal;
    function GetShadowVisible: Boolean;
    procedure LayoutControls;
    procedure SetCommonFrameHeight(const Value: Integer);
    procedure SetCommonFrameWidth(const Value: Integer);
    procedure SetCornerRadius(const Value: Integer);
    procedure SetOutlineWidth(const Value: Integer);
    procedure StyleToolbarExecute(Sender: TObject;
      Button: TFormattingToolbarButton);
    procedure UpdateGradientControls;
    procedure UpdateFrameKindView;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // 動的に生成した共通色編集部品を含めてダークテーマを適用する。
    procedure ApplyDarkTheme;
    // フォーム生成後に必要な動的操作部品を一度だけ作成する。
    procedure InitializeControls;
    // 影の設定値を維持したまま、影を使用する状態へ切り替える。
    procedure EnableShadow;
    // 保存済みの枠設定一式を通知イベントを発生させずに編集部品へ読み込む。
    // 色は$AARRGGBB、寸法は出力ピクセル、影の各値は実数ピクセルを表す。
    procedure LoadFrameSettings(const AKind: TSerifDrawFrameKind;
      const AShape: TSerifDrawFrameShape;
      const AAccentSource: Integer;
      const AFillMode, AGradientStrength: Integer;
      const AWidth, AHeight: Integer;
      const ACornerRadius: Integer;
      const ADottedDashLength, ADottedGapLength: Integer;
      const ATabWidth, ATabHeight, ATabOffset: Integer;
      const ABalloonTailDirection: Integer;
      const ABalloonTailPosition, ABalloonTailWidth,
      ABalloonTailLength: Integer;
      const AFillVisible, AOutlineVisible, AShadowVisible: Boolean;
      const AFillColor, AOutlineColor, AShadowColor: Cardinal;
      const AInnerOutlineColor: Cardinal;
      const ALayering: Integer; const AInnerPanelColor: Cardinal;
      const AInnerPanelInsetX, AInnerPanelInsetY, AInnerPanelRadius: Integer;
      const AOutlineWidth: Integer;
      const AOutlineStyle: Integer;
      const AShadowOffsetX, AShadowOffsetY, AShadowSpread,
      AShadowBlur: Double);
    // レイヤー枠が共通枠を継承していることを表示へ反映し、設定値自体は変更しない。
    procedure SetLayerFrameInherited(const Value: Boolean);
    // 文字編集と同じレイヤー・配役・セリフ表示を枠編集側へ複製する。
    procedure SetLayerSelectorItems(const AItems: TStrings;
      const ASelectedIndex: Integer);
    property CommonFrameHeight: Integer read FCommonFrameHeight
      write SetCommonFrameHeight;
    property CommonFrameWidth: Integer read FCommonFrameWidth
      write SetCommonFrameWidth;
    property BalloonTailLength: Integer read FBalloonTailLength
      write FBalloonTailLength;
    property BalloonTailDirection: Integer read FBalloonTailDirection
      write FBalloonTailDirection;
    property BalloonTailPosition: Integer read FBalloonTailPosition
      write FBalloonTailPosition;
    property BalloonTailWidth: Integer read FBalloonTailWidth
      write FBalloonTailWidth;
    property CornerRadius: Integer read FCornerRadius write SetCornerRadius;
    property AccentSource: Integer read FAccentSource;
    property DottedDashLength: Integer read FDottedDashLength
      write FDottedDashLength;
    property DottedGapLength: Integer read FDottedGapLength
      write FDottedGapLength;
    property FillColor: Cardinal read GetFillColor;
    property FillMode: Integer read FFillMode;
    property GradientStrength: Integer read FGradientStrength;
    property FillVisible: Boolean read GetFillVisible;
    property FrameKind: TSerifDrawFrameKind read GetFrameKind;
    property FrameShape: TSerifDrawFrameShape read FFrameShape;
    property InnerOutlineColor: Cardinal read GetInnerOutlineColor;
    property InnerPanelColor: Cardinal read GetInnerPanelColor;
    property InnerPanelInsetX: Integer read FInnerPanelInsetX write FInnerPanelInsetX;
    property InnerPanelInsetY: Integer read FInnerPanelInsetY write FInnerPanelInsetY;
    property InnerPanelRadius: Integer read FInnerPanelRadius write FInnerPanelRadius;
    property Layering: Integer read FLayering;
    property SelectedLayerIndex: Integer read GetSelectedLayerIndex;
    property OutlineColor: Cardinal read GetOutlineColor;
    property OutlineWidth: Integer read FOutlineWidth write SetOutlineWidth;
    property OutlineStyle: Integer read FOutlineStyle write FOutlineStyle;
    property OutlineVisible: Boolean read GetOutlineVisible;
    property ShadowColor: Cardinal read GetShadowColor;
    property ShadowBlur: Double read FShadowBlur write FShadowBlur;
    property ShadowOffsetX: Double read FShadowOffsetX write FShadowOffsetX;
    property ShadowOffsetY: Double read FShadowOffsetY write FShadowOffsetY;
    property ShadowSpread: Double read FShadowSpread write FShadowSpread;
    property ShadowVisible: Boolean read GetShadowVisible;
    property TabHeight: Integer read FTabHeight write FTabHeight;
    property TabOffset: Integer read FTabOffset write FTabOffset;
    property TabWidth: Integer read FTabWidth write FTabWidth;
    property OnSettingsChange: TNotifyEvent read FOnSettingsChange
      write FOnSettingsChange;
    property OnLayoutPreset: TSerifDrawFrameLayoutPresetEvent
      read FOnLayoutPreset write FOnLayoutPreset;
    property OnResetLayerFrame: TNotifyEvent read FOnResetLayerFrame
      write FOnResetLayerFrame;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  PluginFilterSerifDrawLegacyPalette,
  PluginFilterSerifDrawSettingsTheme,
  Winapi.Windows;

{$R *.dfm}

constructor TFrameSerifDrawFrameEditor.Create(AOwner: TComponent);
begin
  inherited;
  FCommonFrameWidth := 1280;
  FAccentSource := 0;
  FCommonFrameHeight := 180;
  FCornerRadius := 32;
  FDottedDashLength := 24;
  FDottedGapLength := 24;
  FTabWidth := 250;
  FTabHeight := 64;
  FTabOffset := 24;
  FBalloonTailPosition := 0;
  FBalloonTailWidth := 100;
  FBalloonTailLength := 60;
  FBalloonTailDirection := 0;
  FFrameKind := sdfkNone;
  FFrameShape := sdfsRectangle;
  FFillMode := SERIF_FRAME_FILL_SOLID;
  FGradientStrength := 30;
  FLayering := 0;
  FInnerPanelInsetX := 28;
  FInnerPanelInsetY := 20;
  FInnerPanelRadius := 16;
  FFillVisible := True;
  FOutlineVisible := True;
  FOutlineWidth := 2;
  FOutlineStyle := 0;
  FShadowVisible := False;
  FShadowBlur := 0;
  FShadowOffsetX := 8;
  FShadowOffsetY := 8;
  FShadowSpread := 0;
  FCommonEditorFrame := TFrameSerifDrawCommonFrameEditor.Create(Self);
  FCommonEditorFrame.Parent := CommonSettingsHostPanel;
  FCommonEditorFrame.Align := alClient;
  FCommonEditorFrame.OnStyleChange := CommonStyleChange;
end;

procedure TFrameSerifDrawFrameEditor.ApplyDarkTheme;
const
  DARK_PANEL = SERIF_DRAW_PANEL_COLOR;
  DARK_TEXT = SERIF_DRAW_TEXT_COLOR;
begin
  TypePanel.ParentBackground := False;
  TypePanel.Color := DARK_PANEL;
  TypePanel.Font.Color := DARK_TEXT;
  FrameKindComboBox.Color := SERIF_DRAW_CONTROL_COLOR;
  FrameKindComboBox.Font.Color := DARK_TEXT;
  FrameKindComboBox.StyleElements :=
    FrameKindComboBox.StyleElements - [seClient];
  FrameShapeComboBox.Color := SERIF_DRAW_CONTROL_COLOR;
  FrameShapeComboBox.Font.Color := DARK_TEXT;
  FrameShapeComboBox.StyleElements :=
    FrameShapeComboBox.StyleElements - [seClient];
  FrameOutlineStyleComboBox.Color := SERIF_DRAW_CONTROL_COLOR;
  FrameOutlineStyleComboBox.Font.Color := DARK_TEXT;
  FrameOutlineStyleComboBox.StyleElements :=
    FrameOutlineStyleComboBox.StyleElements - [seClient];
  FrameLayerComboBox.Color := SERIF_DRAW_CONTROL_COLOR;
  FrameLayerComboBox.Font.Color := DARK_TEXT;
  FrameLayerComboBox.StyleElements :=
    FrameLayerComboBox.StyleElements - [seClient];
  FramePresetComboBox.Color := SERIF_DRAW_CONTROL_COLOR;
  FramePresetComboBox.Font.Color := DARK_TEXT;
  FramePresetComboBox.StyleElements :=
    FramePresetComboBox.StyleElements - [seClient];
  FrameAccentSourceComboBox.Color := SERIF_DRAW_CONTROL_COLOR;
  FrameAccentSourceComboBox.Font.Color := DARK_TEXT;
  FrameAccentSourceComboBox.StyleElements :=
    FrameAccentSourceComboBox.StyleElements - [seClient];
  FrameColorPresetComboBox.Color := SERIF_DRAW_CONTROL_COLOR;
  FrameColorPresetComboBox.Font.Color := DARK_TEXT;
  FrameColorPresetComboBox.StyleElements :=
    FrameColorPresetComboBox.StyleElements - [seClient];
  FrameFillModeComboBox.Color := SERIF_DRAW_CONTROL_COLOR;
  FrameFillModeComboBox.Font.Color := DARK_TEXT;
  FrameFillModeComboBox.StyleElements :=
    FrameFillModeComboBox.StyleElements - [seClient];
  FrameGradientStrengthLabel.Font.Color := DARK_TEXT;
  FrameLayoutPresetComboBox.Color := SERIF_DRAW_CONTROL_COLOR;
  FrameLayoutPresetComboBox.Font.Color := DARK_TEXT;
  FrameLayoutPresetComboBox.StyleElements :=
    FrameLayoutPresetComboBox.StyleElements - [seClient];
  if FStyleToolbar <> nil then
    FStyleToolbar.Color := DARK_PANEL;
  CommonSettingsHostPanel.ParentBackground := False;
  CommonSettingsHostPanel.Color := DARK_PANEL;
  FCommonEditorFrame.ApplyDarkTheme;
end;

procedure TFrameSerifDrawFrameEditor.FrameKindComboBoxChange(Sender: TObject);
begin
  if (FrameKindComboBox.ItemIndex >= Ord(Low(TSerifDrawFrameKind))) and
    (FrameKindComboBox.ItemIndex <= Ord(High(TSerifDrawFrameKind))) then
    FFrameKind := TSerifDrawFrameKind(FrameKindComboBox.ItemIndex);
  UpdateFrameKindView;
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.FrameAccentSourceComboBoxChange(
  Sender: TObject);
begin
  if not FControlsInitialized then
    Exit;
  FAccentSource := EnsureRange(FrameAccentSourceComboBox.ItemIndex, 0, 1);
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.FrameColorPresetComboBoxChange(
  Sender: TObject);
var
  Preset: Integer;
begin
  if not FControlsInitialized then
    Exit;
  Preset := FrameColorPresetComboBox.ItemIndex;
  if Preset <= 0 then
    Exit;
  ApplyColorPreset(Preset - 1);
  FrameColorPresetComboBox.ItemIndex := 0;
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.FrameFillModeComboBoxChange(
  Sender: TObject);
begin
  if not FControlsInitialized then
    Exit;
  FFillMode := EnsureRange(FrameFillModeComboBox.ItemIndex,
    SERIF_FRAME_FILL_SOLID, SERIF_FRAME_FILL_VERTICAL_GRADIENT);
  UpdateGradientControls;
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.FrameGradientStrengthTrackBarChange(
  Sender: TObject);
begin
  if not FControlsInitialized then
    Exit;
  FGradientStrength := EnsureRange(FrameGradientStrengthTrackBar.Position,
    0, 100);
  UpdateGradientControls;
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.FrameLayerComboBoxChange(
  Sender: TObject);
begin
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.FrameLayeringComboBoxChange(
  Sender: TObject);
begin
  if not FControlsInitialized then
    Exit;
  FLayering := EnsureRange(FrameLayeringComboBox.ItemIndex, 0, 1);
  FCommonEditorFrame.SetInnerPanelEnabled(FLayering = 1);
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.FrameLayoutPresetComboBoxChange(
  Sender: TObject);
var
  Preset: Integer;
begin
  if not FControlsInitialized then
    Exit;
  Preset := FrameLayoutPresetComboBox.ItemIndex;
  if Preset <= 0 then
    Exit;
  FrameLayoutPresetComboBox.ItemIndex := 0;
  if Assigned(FOnLayoutPreset) then
    FOnLayoutPreset(Self, Preset);
end;

procedure TFrameSerifDrawFrameEditor.FrameShapeComboBoxChange(
  Sender: TObject);
begin
  if (FrameShapeComboBox.ItemIndex >= Ord(Low(TSerifDrawFrameShape))) and
    (FrameShapeComboBox.ItemIndex <= Ord(High(TSerifDrawFrameShape))) then
    FFrameShape := TSerifDrawFrameShape(FrameShapeComboBox.ItemIndex);
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.FrameOutlineStyleComboBoxChange(
  Sender: TObject);
begin
  if FrameOutlineStyleComboBox.ItemIndex in [0, 1, 2, 3] then
    FOutlineStyle := FrameOutlineStyleComboBox.ItemIndex;
  FCommonEditorFrame.SetInnerOutlineEnabled(FOutlineStyle in [1, 2]);
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.FramePresetComboBoxChange(
  Sender: TObject);
var
  Preset: Integer;
begin
  if not FControlsInitialized then
    Exit;
  Preset := FramePresetComboBox.ItemIndex;
  if Preset <= 0 then
    Exit;
  if Preset = 7 then
  begin
    FramePresetComboBox.ItemIndex := 0;
    if (FrameKind = sdfkCharacter) and Assigned(FOnResetLayerFrame) then
      FOnResetLayerFrame(Self);
    Exit;
  end;
  ApplyPreset(Preset);
  FramePresetComboBox.ItemIndex := 0;
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.ApplyPreset(const APreset: Integer);
var
  AccentColor: Cardinal;
  InnerAccentColor: Cardinal;
  ShadowColor: Cardinal;
begin
  AccentColor := FCommonEditorFrame.OutlineColor;
  InnerAccentColor := FCommonEditorFrame.InnerOutlineColor;
  ShadowColor := (FCommonEditorFrame.ShadowColor and $00FFFFFF) or $A8000000;
  FCornerRadius := 16;
  FLayering := 0;
  FInnerPanelInsetX := 28;
  FInnerPanelInsetY := 20;
  FInnerPanelRadius := 16;
  FTabWidth := 250;
  FTabHeight := 64;
  FTabOffset := 24;
  FFillVisible := True;
  FOutlineVisible := False;
  FOutlineWidth := 2;
  FOutlineStyle := 0;
  FShadowVisible := True;
  FShadowOffsetX := 10;
  FShadowOffsetY := 10;
  FShadowSpread := 0;
  FShadowBlur := 0;
  case APreset of
    1: // 白
      begin
        FFrameShape := sdfsRoundedRectangle;
        FCommonEditorFrame.LoadColors($FFFFFFFF, AccentColor,
          InnerAccentColor, $FFFFFFFF, ShadowColor);
      end;
    2: // カラー
      begin
        FFrameShape := sdfsRectangle;
        FLayering := 1;
        FShadowOffsetX := 6;
        FShadowOffsetY := 6;
        FCommonEditorFrame.LoadColors((AccentColor and $00FFFFFF) or
          $FF000000, AccentColor, InnerAccentColor, $FFFFFFFF, ShadowColor);
      end;
    3: // 黒
      begin
        FFrameShape := sdfsRectangle;
        FOutlineVisible := True;
        FOutlineStyle := 2;
        FOutlineWidth := 8;
        FShadowVisible := False;
        FCommonEditorFrame.LoadColors($FF101010, AccentColor,
          InnerAccentColor, $FFFFFFFF, ShadowColor);
      end;
    4: // 吹き出し白
      begin
        FFrameShape := sdfsSpeechBalloon;
        FBalloonTailDirection := 2;
        FBalloonTailPosition := FCommonFrameHeight div 4;
        FBalloonTailWidth := 56;
        FBalloonTailLength := 48;
        FCommonEditorFrame.LoadColors($FFFFFFFF, AccentColor,
          InnerAccentColor, $FFFFFFFF, ShadowColor);
      end;
    5: // タブ白
      begin
        FFrameShape := sdfsTab;
        FCornerRadius := 18;
        FOutlineVisible := True;
        FOutlineWidth := 8;
        FCommonEditorFrame.LoadColors($FFFFFFFF, AccentColor,
          InnerAccentColor, $FFFFFFFF, ShadowColor);
      end;
    6: // タブ黒
      begin
        FFrameShape := sdfsTab;
        FCornerRadius := 18;
        FOutlineVisible := True;
        FOutlineStyle := 2;
        FOutlineWidth := 8;
        FShadowVisible := False;
        FCommonEditorFrame.LoadColors($FF101010, AccentColor,
          InnerAccentColor, $FFFFFFFF, ShadowColor);
      end;
  else
    Exit;
  end;
  FrameShapeComboBox.ItemIndex := Ord(FFrameShape);
  FrameLayeringComboBox.ItemIndex := FLayering;
  FrameOutlineStyleComboBox.ItemIndex := FOutlineStyle;
  if FFillVisible then
    FFillVisibleButton.CheckState := tbcsChecked
  else
    FFillVisibleButton.CheckState := tbcsUnchecked;
  if FOutlineVisible then
    FOutlineVisibleButton.CheckState := tbcsChecked
  else
    FOutlineVisibleButton.CheckState := tbcsUnchecked;
  if FShadowVisible then
    FShadowVisibleButton.CheckState := tbcsChecked
  else
    FShadowVisibleButton.CheckState := tbcsUnchecked;
  FCommonEditorFrame.SetInnerOutlineEnabled(FOutlineStyle in [1, 2]);
  FCommonEditorFrame.SetInnerPanelEnabled(FLayering = 1);
  UpdateFrameKindView;
end;

procedure TFrameSerifDrawFrameEditor.ApplyColorPreset(
  const APreset: Integer);
var
  Palette: TSerifDrawLegacyPalette;
begin
  Palette := SerifDrawLegacyPalette(APreset);
  FAccentSource := 0;
  FrameAccentSourceComboBox.ItemIndex := FAccentSource;
  if (FOutlineStyle = 2) and not FShadowVisible then
    FCommonEditorFrame.LoadColors($FF101010, Palette.NeonDark,
      Palette.NeonBase, $FFFFFFFF,
      (Palette.PastelDark and $00FFFFFF) or $A8000000)
  else if FLayering = 1 then
    FCommonEditorFrame.LoadColors(Palette.PastelLight,
      Palette.PastelBase, Palette.PastelBase, $FFFFFFFF,
      (Palette.PastelDark and $00FFFFFF) or $A8000000)
  else
    FCommonEditorFrame.LoadColors($FFFFFFFF, Palette.PastelBase,
      Palette.PastelBase, $FFFFFFFF,
      (Palette.PastelLight and $00FFFFFF) or $A8000000);
end;

procedure TFrameSerifDrawFrameEditor.CommonStyleChange(Sender: TObject);
begin
  // 手動で色を編集した場合は、描画時に配役色で上書きしない。
  FAccentSource := 0;
  if FControlsInitialized then
    FrameAccentSourceComboBox.ItemIndex := FAccentSource;
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

function TFrameSerifDrawFrameEditor.GetFillColor: Cardinal;
begin
  Result := FCommonEditorFrame.FillColor;
end;

function TFrameSerifDrawFrameEditor.GetFillVisible: Boolean;
begin
  Result := FFillVisible;
end;

function TFrameSerifDrawFrameEditor.GetInnerOutlineColor: Cardinal;
begin
  Result := FCommonEditorFrame.InnerOutlineColor;
end;

function TFrameSerifDrawFrameEditor.GetInnerPanelColor: Cardinal;
begin
  Result := FCommonEditorFrame.InnerPanelColor;
end;

procedure TFrameSerifDrawFrameEditor.FrameKindComboBoxDrawItem(
  Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
const
  DARK_ITEM = SERIF_DRAW_PANEL_COLOR;
  DARK_TEXT = SERIF_DRAW_TEXT_COLOR;
var
  ComboBox: TComboBox;
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
  TextRect := Rect;
  Inc(TextRect.Left, MulDiv(4, CurrentPPI, 96));
  ComboBox.Canvas.TextRect(TextRect, TextRect.Left,
    TextRect.Top + (TextRect.Height - ComboBox.Canvas.TextHeight('Ag')) div 2,
    ComboBox.Items[Index]);
end;

procedure TFrameSerifDrawFrameEditor.InitializeControls;
var
  Extent: Integer;
begin
  if FControlsInitialized then
    Exit;
  if (Parent = nil) or not Parent.HandleAllocated then
    Exit;
  Extent := MulDiv(28, CurrentPPI, 96);
  FStyleToolbar := TFormattingToolbarButtons.Create(Self);
  FStyleToolbar.Parent := TypePanel;
  ApplySerifDrawToolbarTheme(FStyleToolbar);
  FStyleToolbar.ButtonExtent := Extent;
  FStyleToolbar.SeparatorExtent := 0;
  FStyleToolbar.Color := TypePanel.Color;
  FStyleToolbar.OnButtonExecute := StyleToolbarExecute;
  FFillVisibleButton := FStyleToolbar.AddToggleButton('枠本体の表示',
    tbgFrameFill, 0);
  FOutlineVisibleButton := FStyleToolbar.AddToggleButton('枠の縁の表示',
    tbgFrameOutline, 1);
  FShadowVisibleButton := FStyleToolbar.AddToggleButton('枠の影の表示',
    tbgFrameShadow, 2);
  if FFillVisible then
    FFillVisibleButton.CheckState := tbcsChecked;
  if FOutlineVisible then
    FOutlineVisibleButton.CheckState := tbcsChecked;
  if FShadowVisible then
    FShadowVisibleButton.CheckState := tbcsChecked;
  FrameKindComboBox.Items.Add('なし');
  FrameKindComboBox.Items.Add('共通');
  FrameKindComboBox.Items.Add('キャラ別');
  FrameKindComboBox.ItemIndex := Ord(FFrameKind);
  FrameShapeComboBox.Items.Add('四角');
  FrameShapeComboBox.Items.Add('角丸');
  FrameShapeComboBox.Items.Add('タブ');
  FrameShapeComboBox.Items.Add('吹き出し');
  FrameShapeComboBox.ItemIndex := Ord(FFrameShape);
  FrameLayeringComboBox.Items.Add('単層');
  FrameLayeringComboBox.Items.Add('内側パネル');
  FrameLayeringComboBox.ItemIndex := 0;
  FramePresetComboBox.Items.Add('構成プリセット');
  FramePresetComboBox.Items.Add('白');
  FramePresetComboBox.Items.Add('カラー');
  FramePresetComboBox.Items.Add('黒');
  FramePresetComboBox.Items.Add('吹き出し白');
  FramePresetComboBox.Items.Add('タブ白');
  FramePresetComboBox.Items.Add('タブ黒');
  FramePresetComboBox.Items.Add('共通設定を継承');
  FramePresetComboBox.ItemIndex := 0;
  FrameAccentSourceComboBox.Items.Add('固定色');
  FrameAccentSourceComboBox.Items.Add('配役色');
  FrameAccentSourceComboBox.ItemIndex := FAccentSource;
  FrameColorPresetComboBox.Items.Add('配色プリセット');
  FrameColorPresetComboBox.Items.Add('赤');
  FrameColorPresetComboBox.Items.Add('橙');
  FrameColorPresetComboBox.Items.Add('黄');
  FrameColorPresetComboBox.Items.Add('黄緑');
  FrameColorPresetComboBox.Items.Add('緑');
  FrameColorPresetComboBox.Items.Add('水');
  FrameColorPresetComboBox.Items.Add('青');
  FrameColorPresetComboBox.Items.Add('紫');
  FrameColorPresetComboBox.Items.Add('桃');
  FrameColorPresetComboBox.Items.Add('反転／白');
  FrameColorPresetComboBox.ItemIndex := 0;
  FrameFillModeComboBox.Items.Add('単色');
  FrameFillModeComboBox.Items.Add('グラデーション');
  FrameFillModeComboBox.ItemIndex := FFillMode;
  FrameGradientStrengthTrackBar.Min := 0;
  FrameGradientStrengthTrackBar.Max := 100;
  FrameGradientStrengthTrackBar.Position := FGradientStrength;
  FrameLayoutPresetComboBox.Items.Add('配置プリセット');
  FrameLayoutPresetComboBox.Items.Add('フル');
  FrameLayoutPresetComboBox.Items.Add('右');
  FrameLayoutPresetComboBox.Items.Add('左');
  FrameLayoutPresetComboBox.Items.Add('中');
  FrameLayoutPresetComboBox.ItemIndex := 0;
  FrameOutlineStyleComboBox.Items.Add('単線');
  FrameOutlineStyleComboBox.Items.Add('二重線');
  FrameOutlineStyleComboBox.Items.Add('ネオン');
  FrameOutlineStyleComboBox.Items.Add('点線');
  FrameOutlineStyleComboBox.ItemIndex := FOutlineStyle;
  FControlsInitialized := True;
  LayoutControls;
  UpdateGradientControls;
  UpdateFrameKindView;
end;

procedure TFrameSerifDrawFrameEditor.LoadFrameSettings(
  const AKind: TSerifDrawFrameKind; const AShape: TSerifDrawFrameShape;
  const AAccentSource: Integer;
  const AFillMode, AGradientStrength: Integer;
  const AWidth, AHeight: Integer;
  const ACornerRadius: Integer;
  const ADottedDashLength, ADottedGapLength: Integer;
  const ATabWidth, ATabHeight, ATabOffset: Integer;
  const ABalloonTailDirection: Integer;
  const ABalloonTailPosition, ABalloonTailWidth,
  ABalloonTailLength: Integer;
  const AFillVisible, AOutlineVisible, AShadowVisible: Boolean;
  const AFillColor, AOutlineColor, AShadowColor: Cardinal;
  const AInnerOutlineColor: Cardinal;
  const ALayering: Integer; const AInnerPanelColor: Cardinal;
  const AInnerPanelInsetX, AInnerPanelInsetY, AInnerPanelRadius: Integer;
  const AOutlineWidth: Integer;
  const AOutlineStyle: Integer;
  const AShadowOffsetX, AShadowOffsetY, AShadowSpread,
  AShadowBlur: Double);
begin
  FFrameKind := AKind;
  FFrameShape := AShape;
  FAccentSource := EnsureRange(AAccentSource, 0, 1);
  FFillMode := EnsureRange(AFillMode, SERIF_FRAME_FILL_SOLID,
    SERIF_FRAME_FILL_VERTICAL_GRADIENT);
  FGradientStrength := EnsureRange(AGradientStrength, 0, 100);
  FCommonFrameWidth := EnsureRange(AWidth, 1, 20000);
  FCommonFrameHeight := EnsureRange(AHeight, 1, 20000);
  FCornerRadius := EnsureRange(ACornerRadius, 0, 500);
  FDottedDashLength := EnsureRange(ADottedDashLength, 1, 20000);
  FDottedGapLength := EnsureRange(ADottedGapLength, 1, 20000);
  FTabWidth := EnsureRange(ATabWidth, 1, 20000);
  FTabHeight := EnsureRange(ATabHeight, 1, 20000);
  FTabOffset := EnsureRange(ATabOffset, 0, 20000);
  FBalloonTailDirection := EnsureRange(ABalloonTailDirection, 0, 3);
  FBalloonTailPosition := EnsureRange(ABalloonTailPosition, -20000, 20000);
  FBalloonTailWidth := EnsureRange(ABalloonTailWidth, 1, 20000);
  FBalloonTailLength := EnsureRange(ABalloonTailLength, 1, 20000);
  FFillVisible := AFillVisible;
  FOutlineVisible := AOutlineVisible;
  FOutlineWidth := EnsureRange(AOutlineWidth, 0, 500);
  FOutlineStyle := EnsureRange(AOutlineStyle, 0, 3);
  FLayering := EnsureRange(ALayering, 0, 1);
  FInnerPanelInsetX := EnsureRange(AInnerPanelInsetX, 0, 10000);
  FInnerPanelInsetY := EnsureRange(AInnerPanelInsetY, 0, 10000);
  FInnerPanelRadius := EnsureRange(AInnerPanelRadius, 0, 500);
  FShadowVisible := AShadowVisible;
  FShadowOffsetX := EnsureRange(AShadowOffsetX, -2000.0, 2000.0);
  FShadowOffsetY := EnsureRange(AShadowOffsetY, -2000.0, 2000.0);
  FShadowSpread := EnsureRange(AShadowSpread, 0.0, 500.0);
  FShadowBlur := EnsureRange(AShadowBlur, 0.0, 500.0);
  FCommonEditorFrame.LoadColors(AFillColor, AOutlineColor,
    AInnerOutlineColor, AInnerPanelColor, AShadowColor);
  FCommonEditorFrame.SetInnerOutlineEnabled(FOutlineStyle in [1, 2]);
  FCommonEditorFrame.SetInnerPanelEnabled(FLayering = 1);
  if FControlsInitialized then
  begin
    FrameKindComboBox.ItemIndex := Ord(FFrameKind);
    FrameShapeComboBox.ItemIndex := Ord(FFrameShape);
    FrameAccentSourceComboBox.ItemIndex := FAccentSource;
    FrameFillModeComboBox.ItemIndex := FFillMode;
    FrameGradientStrengthTrackBar.Position := FGradientStrength;
    FrameOutlineStyleComboBox.ItemIndex := FOutlineStyle;
    FrameLayeringComboBox.ItemIndex := FLayering;
    if FFillVisible then
      FFillVisibleButton.CheckState := tbcsChecked
    else
      FFillVisibleButton.CheckState := tbcsUnchecked;
    if FOutlineVisible then
      FOutlineVisibleButton.CheckState := tbcsChecked
    else
      FOutlineVisibleButton.CheckState := tbcsUnchecked;
    if FShadowVisible then
      FShadowVisibleButton.CheckState := tbcsChecked
    else
      FShadowVisibleButton.CheckState := tbcsUnchecked;
    UpdateGradientControls;
    UpdateFrameKindView;
  end;
end;

procedure TFrameSerifDrawFrameEditor.SetLayerFrameInherited(
  const Value: Boolean);
begin
  if not FControlsInitialized or (FramePresetComboBox.Items.Count = 0) then
    Exit;
  if Value then
    FramePresetComboBox.Items[0] := '共通枠を継承中'
  else
    FramePresetComboBox.Items[0] := '構成プリセット';
  FramePresetComboBox.ItemIndex := 0;
end;

procedure TFrameSerifDrawFrameEditor.EnableShadow;
begin
  FShadowVisible := True;
  if FShadowVisibleButton <> nil then
    FShadowVisibleButton.CheckState := tbcsChecked;
end;

function TFrameSerifDrawFrameEditor.GetFrameKind: TSerifDrawFrameKind;
begin
  Result := FFrameKind;
end;

function TFrameSerifDrawFrameEditor.GetSelectedLayerIndex: Integer;
begin
  Result := FrameLayerComboBox.ItemIndex;
end;

function TFrameSerifDrawFrameEditor.GetOutlineColor: Cardinal;
begin
  Result := FCommonEditorFrame.OutlineColor;
end;

function TFrameSerifDrawFrameEditor.GetOutlineVisible: Boolean;
begin
  Result := FOutlineVisible;
end;

function TFrameSerifDrawFrameEditor.GetShadowColor: Cardinal;
begin
  Result := FCommonEditorFrame.ShadowColor;
end;

function TFrameSerifDrawFrameEditor.GetShadowVisible: Boolean;
begin
  Result := FShadowVisible;
end;

procedure TFrameSerifDrawFrameEditor.LayoutControls;
var
  Extent: Integer;
  FillModeWidth: Integer;
  Gap: Integer;
  LayerLeft: Integer;
  LayerWidth: Integer;
  LayeringWidth: Integer;
  Margin: Integer;
  PresetWidth: Integer;
  ShapeWidth: Integer;
  OutlineStyleWidth: Integer;
  KindWidth: Integer;
  StrengthLabelWidth: Integer;
  ToolbarLeft: Integer;
  ToolbarWidth: Integer;
begin
  Extent := MulDiv(28, CurrentPPI, 96);
  Gap := MulDiv(6, CurrentPPI, 96);
  Margin := MulDiv(8, CurrentPPI, 96);
  KindWidth := MulDiv(112, CurrentPPI, 96);
  FillModeWidth := MulDiv(104, CurrentPPI, 96);
  StrengthLabelWidth := MulDiv(70, CurrentPPI, 96);
  ShapeWidth := MulDiv(104, CurrentPPI, 96);
  OutlineStyleWidth := MulDiv(88, CurrentPPI, 96);
  LayeringWidth := MulDiv(96, CurrentPPI, 96);
  PresetWidth := MulDiv(112, CurrentPPI, 96);
  ToolbarWidth := Extent * 3;
  ToolbarLeft := Max(Margin, TypePanel.ClientWidth - Margin - ToolbarWidth);

  FrameKindComboBox.SetBounds(Margin, Margin,
    KindWidth, FrameKindComboBox.Height);
  FrameShapeComboBox.SetBounds(FrameKindComboBox.Left +
    FrameKindComboBox.Width + Gap,
    Margin,
    ShapeWidth, FrameShapeComboBox.Height);
  FrameLayeringComboBox.SetBounds(FrameShapeComboBox.Left +
    FrameShapeComboBox.Width + Gap,
    Margin,
    LayeringWidth, FrameLayeringComboBox.Height);
  FrameOutlineStyleComboBox.SetBounds(FrameLayeringComboBox.Left +
    FrameLayeringComboBox.Width + Gap,
    Margin,
    OutlineStyleWidth, FrameOutlineStyleComboBox.Height);
  LayerLeft := FrameOutlineStyleComboBox.Left +
    FrameOutlineStyleComboBox.Width + Gap;
  LayerWidth := Max(Extent, ToolbarLeft - Gap - LayerLeft);
  FrameLayerComboBox.SetBounds(LayerLeft,
    Margin,
    LayerWidth, FrameLayerComboBox.Height);

  FramePresetComboBox.SetBounds(Margin,
    Margin + FrameKindComboBox.Height + Gap,
    PresetWidth, FramePresetComboBox.Height);
  FrameAccentSourceComboBox.SetBounds(FramePresetComboBox.Left +
    FramePresetComboBox.Width + Gap, FramePresetComboBox.Top,
    MulDiv(96, CurrentPPI, 96), FrameAccentSourceComboBox.Height);
  FrameColorPresetComboBox.SetBounds(FrameAccentSourceComboBox.Left +
    FrameAccentSourceComboBox.Width + Gap, FramePresetComboBox.Top,
    MulDiv(112, CurrentPPI, 96), FrameColorPresetComboBox.Height);
  FrameLayoutPresetComboBox.SetBounds(FrameColorPresetComboBox.Left +
    FrameColorPresetComboBox.Width + Gap, FramePresetComboBox.Top,
    MulDiv(112, CurrentPPI, 96), FrameLayoutPresetComboBox.Height);
  FrameFillModeComboBox.SetBounds(FrameLayoutPresetComboBox.Left +
    FrameLayoutPresetComboBox.Width + Gap, FramePresetComboBox.Top,
    FillModeWidth, FrameFillModeComboBox.Height);
  FrameGradientStrengthLabel.SetBounds(FrameFillModeComboBox.Left +
    FrameFillModeComboBox.Width + Gap, FramePresetComboBox.Top +
    MulDiv(4, CurrentPPI, 96), StrengthLabelWidth,
    FrameGradientStrengthLabel.Height);
  FrameGradientStrengthTrackBar.SetBounds(
    FrameGradientStrengthLabel.Left + FrameGradientStrengthLabel.Width,
    FramePresetComboBox.Top - MulDiv(2, CurrentPPI, 96),
    Max(Extent, TypePanel.ClientWidth - Margin -
      (FrameGradientStrengthLabel.Left + FrameGradientStrengthLabel.Width)),
    Extent);

  if FStyleToolbar <> nil then
  begin
    FStyleToolbar.ButtonExtent := Extent;
    FStyleToolbar.SetBounds(ToolbarLeft,
      Margin, ToolbarWidth, Extent);
  end;
end;

procedure TFrameSerifDrawFrameEditor.Resize;
begin
  inherited;
  LayoutControls;
end;

procedure TFrameSerifDrawFrameEditor.SetCommonFrameHeight(
  const Value: Integer);
begin
  FCommonFrameHeight := EnsureRange(Value, 1, 20000);
end;

procedure TFrameSerifDrawFrameEditor.SetCommonFrameWidth(
  const Value: Integer);
begin
  FCommonFrameWidth := EnsureRange(Value, 1, 20000);
end;

procedure TFrameSerifDrawFrameEditor.SetCornerRadius(const Value: Integer);
begin
  FCornerRadius := EnsureRange(Value, 0, 500);
end;

procedure TFrameSerifDrawFrameEditor.SetOutlineWidth(const Value: Integer);
begin
  FOutlineWidth := EnsureRange(Value, 0, 500);
end;

procedure TFrameSerifDrawFrameEditor.SetLayerSelectorItems(
  const AItems: TStrings; const ASelectedIndex: Integer);
begin
  FrameLayerComboBox.Items.Assign(AItems);
  if (ASelectedIndex >= 0) and
    (ASelectedIndex < FrameLayerComboBox.Items.Count) then
    FrameLayerComboBox.ItemIndex := ASelectedIndex
  else
    FrameLayerComboBox.ItemIndex := -1;
end;

procedure TFrameSerifDrawFrameEditor.StyleToolbarExecute(Sender: TObject;
  Button: TFormattingToolbarButton);
begin
  FFillVisible := FFillVisibleButton.CheckState = tbcsChecked;
  FOutlineVisible := FOutlineVisibleButton.CheckState = tbcsChecked;
  FShadowVisible := FShadowVisibleButton.CheckState = tbcsChecked;
  UpdateFrameKindView;
  if Assigned(FOnSettingsChange) then
    FOnSettingsChange(Self);
end;

procedure TFrameSerifDrawFrameEditor.UpdateFrameKindView;
var
  FrameEnabled: Boolean;
  CommonVisible: Boolean;
  SelectorIndex: Integer;
begin
  SelectorIndex := FrameKindComboBox.ItemIndex;
  FrameEnabled := SelectorIndex <> Ord(sdfkNone);
  FramePresetComboBox.Enabled := FrameEnabled;
  FrameAccentSourceComboBox.Enabled := FrameEnabled;
  FrameColorPresetComboBox.Enabled := FrameEnabled;
  FrameLayoutPresetComboBox.Enabled := FrameEnabled;
  FrameFillModeComboBox.Enabled := FrameEnabled;
  FrameShapeComboBox.Enabled := FrameEnabled;
  FrameLayeringComboBox.Enabled := FrameEnabled;
  FrameOutlineStyleComboBox.Enabled := FrameEnabled;
  FrameLayerComboBox.Enabled := SelectorIndex = 2;
  CommonVisible := SelectorIndex <> Ord(sdfkNone);
  // 種類を切り替えても色UIの位置を動かさず、枠なしでは無効表示にする。
  CommonSettingsHostPanel.Visible := True;
  CommonSettingsHostPanel.Enabled := FrameEnabled;
  if FStyleToolbar <> nil then
    FStyleToolbar.Visible := CommonVisible;
  // 右パネルは常時表示するため、初期表示時点で色編集UIを生成する。
  CommonSettingsHostPanel.HandleNeeded;
  FCommonEditorFrame.InitializeControls;
  UpdateGradientControls;
end;

procedure TFrameSerifDrawFrameEditor.UpdateGradientControls;
var
  GradientEnabled: Boolean;
begin
  FrameGradientStrengthLabel.Caption := Format('明暗差 %d%%',
    [FGradientStrength]);
  GradientEnabled := (FFrameKind <> sdfkNone) and
    (FFillMode = SERIF_FRAME_FILL_VERTICAL_GRADIENT);
  FrameGradientStrengthLabel.Enabled := GradientEnabled;
  FrameGradientStrengthTrackBar.Enabled := GradientEnabled;
  FrameGradientStrengthTrackBar.Hint := Format('明暗差: %d%%',
    [FGradientStrength]);
end;

end.
