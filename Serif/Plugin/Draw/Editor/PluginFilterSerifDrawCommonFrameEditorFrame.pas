unit PluginFilterSerifDrawCommonFrameEditorFrame;

interface

// 枠を構成する各色と不透明度を共通の操作系で編集するフレームを提供する。

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  FormattingToolbarButtons,
  PluginFilterSerifDrawColorPicker,
  TransparencyTrackControl;

type
  // カラーピッカーの編集対象となる枠の構成要素。
  TSerifDrawFrameColorTarget = (
    sdfctFill,
    sdfctOutline,
    sdfctInnerOutline,
    sdfctInnerPanel,
    sdfctShadow
  );

  TFrameSerifDrawCommonFrameEditor = class(TFrame)
  private
    FColorPicker: TSerifDrawColorPickerControl;
    FColorTarget: TSerifDrawFrameColorTarget;
    FColorToolbar: TFormattingToolbarButtons;
    FFillButton: TFormattingToolbarButton;
    FFillColor: Cardinal;
    FInnerOutlineButton: TFormattingToolbarButton;
    FInnerOutlineColor: Cardinal;
    FInnerOutlineEnabled: Boolean;
    FInnerPanelButton: TFormattingToolbarButton;
    FInnerPanelColor: Cardinal;
    FInnerPanelEnabled: Boolean;
    FOnStyleChange: TNotifyEvent;
    FOutlineButton: TFormattingToolbarButton;
    FOpacityTrack: TTransparencyTrackControl;
    FOutlineColor: Cardinal;
    FShadowButton: TFormattingToolbarButton;
    FShadowColor: Cardinal;
    FControlsInitialized: Boolean;
    FUpdating: Boolean;
    procedure ColorPickerChange(Sender: TObject);
    procedure ColorTargetExecute(Sender: TObject;
      Button: TFormattingToolbarButton);
    procedure NotifyStyleChange;
    procedure OpacityTrackChange(Sender: TObject);
    procedure UpdateColorControls;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // 動的に生成した操作部品を含めてダークテーマを適用する。
    procedure ApplyDarkTheme;
    // フォーム生成後に必要な動的操作部品を一度だけ作成する。
    procedure InitializeControls;
    // 各構成要素のARGB色を通知イベントを発生させずに操作部品へ読み込む。
    procedure LoadColors(const AFillColor, AOutlineColor,
      AInnerOutlineColor, AInnerPanelColor, AShadowColor: Cardinal);
    // 内線色の選択操作だけを有効化または無効化し、保持中の色は変更しない。
    procedure SetInnerOutlineEnabled(const AEnabled: Boolean);
    // 内側パネル色の選択操作だけを有効化または無効化し、保持中の色は変更しない。
    procedure SetInnerPanelEnabled(const AEnabled: Boolean);
    // 各色は$AARRGGBB形式で保持する。
    property FillColor: Cardinal read FFillColor;
    property OutlineColor: Cardinal read FOutlineColor;
    property InnerOutlineColor: Cardinal read FInnerOutlineColor;
    property InnerPanelColor: Cardinal read FInnerPanelColor;
    property ShadowColor: Cardinal read FShadowColor;
    property OnStyleChange: TNotifyEvent read FOnStyleChange
      write FOnStyleChange;
  end;

implementation

uses
  System.Math,
  PluginFilterSerifDrawSettingsTheme,
  Winapi.Windows;

{$R *.dfm}

constructor TFrameSerifDrawCommonFrameEditor.Create(AOwner: TComponent);
begin
  inherited;
  FFillColor := $70303030;
  FOutlineColor := $FFE6E6E6;
  FInnerOutlineColor := $FFE6E6E6;
  FInnerPanelColor := $FFFFFFFF;
  FInnerOutlineEnabled := False;
  FInnerPanelEnabled := False;
  FShadowColor := $6E000000;
  FColorTarget := sdfctFill;
end;

procedure TFrameSerifDrawCommonFrameEditor.ApplyDarkTheme;
const
  DARK_PANEL = SERIF_DRAW_PANEL_COLOR;
begin
  ParentBackground := False;
  Color := DARK_PANEL;
  Font.Color := SERIF_DRAW_TEXT_COLOR;
  if FColorToolbar <> nil then
    FColorToolbar.Color := DARK_PANEL;
  if FColorPicker <> nil then
    FColorPicker.Color := RGB((FFillColor shr 16) and $FF,
      (FFillColor shr 8) and $FF, FFillColor and $FF);
  if FOpacityTrack <> nil then
    FOpacityTrack.BackgroundColor := DARK_PANEL;
end;

procedure TFrameSerifDrawCommonFrameEditor.InitializeControls;
var
  Extent: Integer;
begin
  if FControlsInitialized then
    Exit;
  if (Parent = nil) or not Parent.HandleAllocated then
    Exit;
  Extent := MulDiv(28, CurrentPPI, 96);
  FColorPicker := TSerifDrawColorPickerControl.Create(Self);
  FColorPicker.Parent := Self;
  FColorPicker.OnChange := ColorPickerChange;
  FOpacityTrack := TTransparencyTrackControl.Create(Self);
  FOpacityTrack.Parent := Self;
  FOpacityTrack.BackgroundColor := Color;
  FOpacityTrack.GlyphColor := SERIF_DRAW_ICON_GLYPH_COLOR;
  FOpacityTrack.Caption := '';
  FOpacityTrack.GlyphKind := ttgFrame;
  FOpacityTrack.OnChange := OpacityTrackChange;
  FColorToolbar := TFormattingToolbarButtons.Create(Self);
  FColorToolbar.Parent := Self;
  ApplySerifDrawToolbarTheme(FColorToolbar);
  FColorToolbar.ButtonExtent := Extent;
  FColorToolbar.SeparatorExtent := 0;
  FColorToolbar.OnButtonExecute := ColorTargetExecute;
  FFillButton := FColorToolbar.AddToggleButton(
    '枠本体の透明度と色を編集',
    tbgFrameFill, Ord(sdfctFill));
  FOutlineButton := FColorToolbar.AddToggleButton(
    '枠の縁の透明度と色を編集',
    tbgFrameOutline, Ord(sdfctOutline));
  FInnerOutlineButton := FColorToolbar.AddToggleButton(
    '二重線の内側線の透明度と色を編集',
    tbgFrameInnerOutline, Ord(sdfctInnerOutline));
  FInnerPanelButton := FColorToolbar.AddToggleButton(
    '内側パネルの透明度と色を編集',
    tbgFrameInnerPanel, Ord(sdfctInnerPanel));
  FShadowButton := FColorToolbar.AddToggleButton(
    '枠の影の透明度と色を編集',
    tbgFrameShadow, Ord(sdfctShadow));
  FInnerOutlineButton.Enabled := FInnerOutlineEnabled;
  FInnerPanelButton.Enabled := FInnerPanelEnabled;
  FFillButton.HasAccentColor := True;
  FOutlineButton.HasAccentColor := True;
  FInnerOutlineButton.HasAccentColor := True;
  FInnerPanelButton.HasAccentColor := True;
  FShadowButton.HasAccentColor := True;
  FControlsInitialized := True;
  ApplyDarkTheme;
  UpdateColorControls;
  Resize;
end;

procedure TFrameSerifDrawCommonFrameEditor.LoadColors(
  const AFillColor, AOutlineColor, AInnerOutlineColor,
  AInnerPanelColor, AShadowColor: Cardinal);
begin
  FFillColor := AFillColor;
  FOutlineColor := AOutlineColor;
  FInnerOutlineColor := AInnerOutlineColor;
  FInnerPanelColor := AInnerPanelColor;
  FShadowColor := AShadowColor;
  if FControlsInitialized then
    UpdateColorControls;
end;

procedure TFrameSerifDrawCommonFrameEditor.SetInnerPanelEnabled(
  const AEnabled: Boolean);
begin
  FInnerPanelEnabled := AEnabled;
  if FInnerPanelButton <> nil then
    FInnerPanelButton.Enabled := AEnabled;
  if not AEnabled and (FColorTarget = sdfctInnerPanel) then
  begin
    FColorTarget := sdfctFill;
    UpdateColorControls;
  end;
end;

procedure TFrameSerifDrawCommonFrameEditor.SetInnerOutlineEnabled(
  const AEnabled: Boolean);
begin
  FInnerOutlineEnabled := AEnabled;
  if FInnerOutlineButton <> nil then
    FInnerOutlineButton.Enabled := AEnabled;
  if not AEnabled and (FColorTarget = sdfctInnerOutline) then
  begin
    FColorTarget := sdfctOutline;
    UpdateColorControls;
  end;
end;

procedure TFrameSerifDrawCommonFrameEditor.ColorPickerChange(Sender: TObject);
var
  Argb: Cardinal;
  Color: TColor;
begin
  if FUpdating then
    Exit;
  case FColorTarget of
    sdfctFill: Argb := FFillColor;
    sdfctOutline: Argb := FOutlineColor;
    sdfctInnerOutline: Argb := FInnerOutlineColor;
    sdfctInnerPanel: Argb := FInnerPanelColor;
  else
    Argb := FShadowColor;
  end;
  Color := ColorToRGB(FColorPicker.Color);
  Argb := (Argb and $FF000000) or
    (Cardinal(GetRValue(Color)) shl 16) or
    (Cardinal(GetGValue(Color)) shl 8) or Cardinal(GetBValue(Color));
  case FColorTarget of
    sdfctFill: FFillColor := Argb;
    sdfctOutline: FOutlineColor := Argb;
    sdfctInnerOutline: FInnerOutlineColor := Argb;
    sdfctInnerPanel: FInnerPanelColor := Argb;
    sdfctShadow: FShadowColor := Argb;
  end;
  UpdateColorControls;
  NotifyStyleChange;
end;

procedure TFrameSerifDrawCommonFrameEditor.ColorTargetExecute(
  Sender: TObject; Button: TFormattingToolbarButton);
begin
  if (Button.Tag < Ord(Low(TSerifDrawFrameColorTarget))) or
    (Button.Tag > Ord(High(TSerifDrawFrameColorTarget))) then
    Exit;
  FColorTarget := TSerifDrawFrameColorTarget(Button.Tag);
  UpdateColorControls;
end;

procedure TFrameSerifDrawCommonFrameEditor.NotifyStyleChange;
begin
  if Assigned(FOnStyleChange) then
    FOnStyleChange(Self);
end;

procedure TFrameSerifDrawCommonFrameEditor.OpacityTrackChange(Sender: TObject);
var
  Alpha: Cardinal;
begin
  if FUpdating then
    Exit;
  Alpha := Cardinal(FOpacityTrack.Alpha) shl 24;
  case FColorTarget of
    sdfctFill: FFillColor := (FFillColor and $00FFFFFF) or Alpha;
    sdfctOutline: FOutlineColor := (FOutlineColor and $00FFFFFF) or Alpha;
    sdfctInnerOutline:
      FInnerOutlineColor := (FInnerOutlineColor and $00FFFFFF) or Alpha;
    sdfctInnerPanel:
      FInnerPanelColor := (FInnerPanelColor and $00FFFFFF) or Alpha;
    sdfctShadow: FShadowColor := (FShadowColor and $00FFFFFF) or Alpha;
  end;
  UpdateColorControls;
  NotifyStyleChange;
end;

procedure TFrameSerifDrawCommonFrameEditor.Resize;
var
  Extent: Integer;
  Gap: Integer;
  Margin: Integer;
  PickerHeight: Integer;
begin
  inherited;
  if (FColorPicker = nil) or (FColorToolbar = nil) then
    Exit;
  Extent := MulDiv(28, CurrentPPI, 96);
  Gap := MulDiv(6, CurrentPPI, 96);
  Margin := MulDiv(8, CurrentPPI, 96);
  PickerHeight := Max(Extent, ClientWidth - Margin * 2 -
    MulDiv(24, CurrentPPI, 96));
  FColorPicker.SetBounds(Margin, ClientHeight - Margin - PickerHeight,
    Max(Extent, ClientWidth - Margin * 2), PickerHeight);
  FColorToolbar.ButtonExtent := Extent;
  FOpacityTrack.SetBounds(Margin, FColorPicker.Top - Gap - Extent,
    Max(Extent, ClientWidth - Margin * 2), Extent);
  FColorToolbar.SetBounds(Margin, FOpacityTrack.Top - Gap - Extent,
    Max(Extent, ClientWidth - Margin * 2), Extent);
end;

procedure TFrameSerifDrawCommonFrameEditor.UpdateColorControls;
begin
  FUpdating := True;
  try
    FFillButton.CheckState := tbcsUnchecked;
    FOutlineButton.CheckState := tbcsUnchecked;
    FInnerOutlineButton.CheckState := tbcsUnchecked;
    FInnerPanelButton.CheckState := tbcsUnchecked;
    FShadowButton.CheckState := tbcsUnchecked;
    case FColorTarget of
      sdfctFill:
        begin
          FFillButton.CheckState := tbcsChecked;
          FColorPicker.Color := RGB((FFillColor shr 16) and $FF,
            (FFillColor shr 8) and $FF, FFillColor and $FF);
          FOpacityTrack.Alpha := FFillColor shr 24;
        end;
      sdfctOutline:
        begin
          FOutlineButton.CheckState := tbcsChecked;
          FColorPicker.Color := RGB((FOutlineColor shr 16) and $FF,
            (FOutlineColor shr 8) and $FF, FOutlineColor and $FF);
          FOpacityTrack.Alpha := FOutlineColor shr 24;
        end;
      sdfctInnerOutline:
        begin
          FInnerOutlineButton.CheckState := tbcsChecked;
          FColorPicker.Color := RGB((FInnerOutlineColor shr 16) and $FF,
            (FInnerOutlineColor shr 8) and $FF, FInnerOutlineColor and $FF);
          FOpacityTrack.Alpha := FInnerOutlineColor shr 24;
        end;
      sdfctInnerPanel:
        begin
          FInnerPanelButton.CheckState := tbcsChecked;
          FColorPicker.Color := RGB((FInnerPanelColor shr 16) and $FF,
            (FInnerPanelColor shr 8) and $FF, FInnerPanelColor and $FF);
          FOpacityTrack.Alpha := FInnerPanelColor shr 24;
        end;
      sdfctShadow:
        begin
          FShadowButton.CheckState := tbcsChecked;
          FColorPicker.Color := RGB((FShadowColor shr 16) and $FF,
            (FShadowColor shr 8) and $FF, FShadowColor and $FF);
          FOpacityTrack.Alpha := FShadowColor shr 24;
        end;
    end;
    FFillButton.AccentColor := RGB((FFillColor shr 16) and $FF,
      (FFillColor shr 8) and $FF, FFillColor and $FF);
    FOutlineButton.AccentColor := RGB((FOutlineColor shr 16) and $FF,
      (FOutlineColor shr 8) and $FF, FOutlineColor and $FF);
    FInnerOutlineButton.AccentColor := RGB(
      (FInnerOutlineColor shr 16) and $FF,
      (FInnerOutlineColor shr 8) and $FF, FInnerOutlineColor and $FF);
    FInnerPanelButton.AccentColor := RGB((FInnerPanelColor shr 16) and $FF,
      (FInnerPanelColor shr 8) and $FF, FInnerPanelColor and $FF);
    FShadowButton.AccentColor := RGB((FShadowColor shr 16) and $FF,
      (FShadowColor shr 8) and $FF, FShadowColor and $FF);
    FInnerOutlineButton.Enabled := FInnerOutlineEnabled;
  finally
    FUpdating := False;
  end;
end;

end.
