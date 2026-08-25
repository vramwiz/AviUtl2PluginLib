unit FormattingToolbarButtons;

// Provides the state and input layer for the character-formatting toolbar.
// Glyph rendering and form integration are intentionally kept outside this unit.

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Types,
  System.UITypes,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Graphics;

type
  TFormattingToolbarButtonKind = (
    tbkCommand,
    tbkToggle,
    tbkDialog,
    tbkSeparator
  );

  TFormattingToolbarCheckState = (
    tbcsUnchecked,
    tbcsChecked,
    tbcsMixed
  );

  // Identifies the future procedural glyph without tying the button to images.
  TFormattingToolbarGlyph = (
    tbgNone,
    tbgBold,
    tbgItalic,
    tbgUnderline,
    tbgStrikeOut,
    tbgFont,
    tbgBeforeColor,
    tbgAfterColor,
    tbgOutline,
    tbgShadow,
    tbgShadowColor,
    tbgBlurColor,
    tbgOpacityText,
    tbgOpacityOutline,
    tbgOpacityShadow,
    tbgOpacityBlur,
    tbgAlignLeft,
    tbgAlignCenter,
    tbgAlignRight,
    tbgMoveToCenter,
    tbgPlacementTopLeft,
    tbgPlacementTopCenter,
    tbgPlacementTopRight,
    tbgPlacementCenterLeft,
    tbgPlacementCenter,
    tbgPlacementCenterRight,
    tbgPlacementBottomLeft,
    tbgPlacementBottomCenter,
    tbgPlacementBottomRight,
    tbgResetSelected,
    tbgResetAll,
    tbgAlignHorizontal,
    tbgDistributeHorizontal,
    tbgFrameFill,
    tbgFrameOutline,
    tbgFrameInnerOutline,
    tbgFrameInnerPanel,
    tbgFrameShadow,
    tbgVisibility
  );

  TFormattingToolbarButton = class;

  TFormattingToolbarButtonExecuteEvent = procedure(Sender: TObject;
    Button: TFormattingToolbarButton) of object;

  // One toolbar item. Execution occurs only after a left-button MouseUp,
  // allowing a handler to open a modal dialog without leaving Pressed set.
  TFormattingToolbarButton = class(TCustomControl)
  private
    FAccentColor: TColor;
    FCheckState: TFormattingToolbarCheckState;
    FGlyph: TFormattingToolbarGlyph;
    FHasAccentColor: Boolean;
    FHotColor: TColor;
    FMixedColor: TColor;
    FCheckedColor: TColor;
    FPressedColor: TColor;
    FStateBorderColor: TColor;
    FHot: Boolean;
    FKind: TFormattingToolbarButtonKind;
    FOnExecute: TFormattingToolbarButtonExecuteEvent;
    FOnOwnerExecute: TFormattingToolbarButtonExecuteEvent;
    FPressed: Boolean;
    procedure SetAccentColor(const Value: TColor);
    procedure SetCheckState(
      const Value: TFormattingToolbarCheckState);
    procedure SetGlyph(const Value: TFormattingToolbarGlyph);
    procedure SetHasAccentColor(const Value: Boolean);
    procedure SetKind(const Value: TFormattingToolbarButtonKind);
  protected
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Paint; override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure RequestExecution; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Execute;
    property Pressed: Boolean read FPressed;
    property HotColor: TColor read FHotColor write FHotColor;
    property MixedColor: TColor read FMixedColor write FMixedColor;
    property CheckedColor: TColor read FCheckedColor write FCheckedColor;
    property PressedColor: TColor read FPressedColor write FPressedColor;
    property StateBorderColor: TColor read FStateBorderColor
      write FStateBorderColor;
  published
    property AccentColor: TColor read FAccentColor write SetAccentColor;
    property Align;
    property Anchors;
    property CheckState: TFormattingToolbarCheckState read FCheckState
      write SetCheckState default tbcsUnchecked;
    property Enabled;
    property Glyph: TFormattingToolbarGlyph read FGlyph write SetGlyph
      default tbgNone;
    property HasAccentColor: Boolean read FHasAccentColor
      write SetHasAccentColor default False;
    property Hint;
    property Kind: TFormattingToolbarButtonKind read FKind write SetKind
      default tbkCommand;
    property OnExecute: TFormattingToolbarButtonExecuteEvent read FOnExecute
      write FOnExecute;
    property ParentShowHint;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;

  TFormattingToolbarButtons = class(TCustomPanel)
  private
    FButtonExtent: Integer;
    FItems: TObjectList<TFormattingToolbarButton>;
    FHotColor: TColor;
    FMixedColor: TColor;
    FCheckedColor: TColor;
    FPressedColor: TColor;
    FStateBorderColor: TColor;
    FOnButtonExecute: TFormattingToolbarButtonExecuteEvent;
    FSeparatorExtent: Integer;
    procedure ButtonExecute(Sender: TObject;
      Button: TFormattingToolbarButton);
    function GetItem(Index: Integer): TFormattingToolbarButton;
    function GetItemCount: Integer;
    procedure SetButtonExtent(const Value: Integer);
    procedure SetSeparatorExtent(const Value: Integer);
    procedure SetHotColor(const Value: TColor);
    procedure SetMixedColor(const Value: TColor);
    procedure SetCheckedColor(const Value: TColor);
    procedure SetPressedColor(const Value: TColor);
    procedure SetStateBorderColor(const Value: TColor);
    procedure UpdateLayout;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddButton(const HintText: string;
      Glyph: TFormattingToolbarGlyph;
      Kind: TFormattingToolbarButtonKind = tbkCommand;
      TagValue: NativeInt = 0;
      ExecuteEvent: TFormattingToolbarButtonExecuteEvent = nil):
      TFormattingToolbarButton;
    function AddCommandButton(const HintText: string;
      Glyph: TFormattingToolbarGlyph; TagValue: NativeInt = 0):
      TFormattingToolbarButton;
    function AddDialogButton(const HintText: string;
      Glyph: TFormattingToolbarGlyph; TagValue: NativeInt = 0):
      TFormattingToolbarButton;
    function AddSeparator: TFormattingToolbarButton;
    function AddToggleButton(const HintText: string;
      Glyph: TFormattingToolbarGlyph; TagValue: NativeInt = 0):
      TFormattingToolbarButton;
    function FindByTag(TagValue: NativeInt): TFormattingToolbarButton;
    procedure Relayout;
    property ItemCount: Integer read GetItemCount;
    property Items[Index: Integer]: TFormattingToolbarButton read GetItem;
  published
    property Align;
    property Anchors;
    property BevelOuter;
    property ButtonExtent: Integer read FButtonExtent write SetButtonExtent
      default 28;
    property HotColor: TColor read FHotColor write SetHotColor;
    property MixedColor: TColor read FMixedColor write SetMixedColor;
    property CheckedColor: TColor read FCheckedColor write SetCheckedColor;
    property PressedColor: TColor read FPressedColor write SetPressedColor;
    property StateBorderColor: TColor read FStateBorderColor
      write SetStateBorderColor;
    property Color;
    property Enabled;
    property OnButtonExecute: TFormattingToolbarButtonExecuteEvent
      read FOnButtonExecute write FOnButtonExecute;
    property ParentBackground;
    property ParentColor;
    property SeparatorExtent: Integer read FSeparatorExtent
      write SetSeparatorExtent default 6;
    property ShowHint;
    property Visible;
  end;

implementation

uses
  System.Math,
  Winapi.Windows;

{ TFormattingToolbarButton }

constructor TFormattingToolbarButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csClickEvents, csCaptureMouse,
    csDoubleClicks];
  FAccentColor := clNone;
  FCheckState := tbcsUnchecked;
  FGlyph := tbgNone;
  FHasAccentColor := False;
  FHotColor := clNone;
  FMixedColor := clNone;
  FCheckedColor := clNone;
  FPressedColor := clNone;
  FStateBorderColor := clNone;
  FHot := False;
  FKind := tbkCommand;
  FPressed := False;
  ParentShowHint := True;
  TabStop := True;
end;

procedure TFormattingToolbarButton.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  if not FHot then
  begin
    FHot := True;
    Invalidate;
  end;
end;

procedure TFormattingToolbarButton.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FHot then
  begin
    FHot := False;
    Invalidate;
  end;
end;

procedure TFormattingToolbarButton.Execute;
begin
  RequestExecution;
end;

procedure TFormattingToolbarButton.KeyDown(var Key: Word;
  Shift: TShiftState);
begin
  inherited;
  if Enabled and (FKind <> tbkSeparator) and
    (Key in [VK_SPACE, VK_RETURN]) then
  begin
    Key := 0;
    RequestExecution;
  end;
end;

procedure TFormattingToolbarButton.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button <> mbLeft) or not Enabled or
    (FKind = tbkSeparator) then
    Exit;
  SetFocus;
  FPressed := True;
  MouseCapture := True;
  Invalidate;
end;

procedure TFormattingToolbarButton.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  ExecuteRequested: Boolean;
begin
  inherited;
  if (Button <> mbLeft) or not FPressed then
    Exit;
  ExecuteRequested := Enabled and (FKind <> tbkSeparator) and
    PtInRect(ClientRect, Point(X, Y));
  FPressed := False;
  MouseCapture := False;
  Invalidate;
  if ExecuteRequested then
    RequestExecution;
end;

procedure TFormattingToolbarButton.Paint;
const
  TEXT_FLAGS = DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX;
var
  Accent: TColor;
  BackColor: TColor;
  BorderColor: TColor;
  GlyphRect: TRect;
  H: Integer;
  GlyphX: Integer;
  GlyphY: Integer;
  K: Integer;
  MidX: Integer;
  MidY: Integer;
  PlacementColumn: Integer;
  PlacementIndex: Integer;
  PlacementRow: Integer;
  R: TRect;
  ResolvedBackColor: Cardinal;
  TextColor: TColor;

  function BlendColor(Base, Overlay: TColor; OverlayAmount: Byte): TColor;
  var
    BaseRgb: Cardinal;
    OverlayRgb: Cardinal;
    Red: Cardinal;
    Green: Cardinal;
    Blue: Cardinal;
    InverseAmount: Cardinal;
  begin
    BaseRgb := ColorToRGB(Base);
    OverlayRgb := ColorToRGB(Overlay);
    InverseAmount := Cardinal(255 - OverlayAmount);
    Red := ((BaseRgb and $FF) * InverseAmount +
      (OverlayRgb and $FF) * OverlayAmount) div 255;
    Green := (((BaseRgb shr 8) and $FF) * InverseAmount +
      ((OverlayRgb shr 8) and $FF) * OverlayAmount) div 255;
    Blue := (((BaseRgb shr 16) and $FF) * InverseAmount +
      ((OverlayRgb shr 16) and $FF) * OverlayAmount) div 255;
    Result := TColor(Red or (Green shl 8) or (Blue shl 16));
  end;

  procedure DrawTextGlyph(const Text: string; Style: TFontStyles;
    HeightPercent: Integer = 58);
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -Max(8, H * HeightPercent div 100);
    Canvas.Font.Style := Style;
    Canvas.Font.Color := TextColor;
    DrawText(Canvas.Handle, PChar(Text), Length(Text), GlyphRect,
      TEXT_FLAGS);
  end;

  procedure DrawColorGlyph(PointRight: Boolean);
  var
    ArrowX: Integer;
  begin
    R := GlyphRect;
    Dec(R.Bottom, Max(3, H div 6));
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -Max(8, H * 50 div 100);
    Canvas.Font.Style := [];
    Canvas.Font.Color := TextColor;
    DrawText(Canvas.Handle, 'A', 1, R, TEXT_FLAGS);
    Canvas.Pen.Width := Max(3, H div 7);
    Canvas.Pen.Color := BlendColor(BackColor, clWindowText, 150);
    Canvas.MoveTo(GlyphRect.Left + H div 5, GlyphRect.Bottom - H div 6);
    Canvas.LineTo(GlyphRect.Right - H div 5, GlyphRect.Bottom - H div 6);
    Canvas.Pen.Width := Max(2, H div 10);
    Canvas.Pen.Color := Accent;
    Canvas.MoveTo(GlyphRect.Left + H div 5, GlyphRect.Bottom - H div 6);
    Canvas.LineTo(GlyphRect.Right - H div 5, GlyphRect.Bottom - H div 6);
    Canvas.Pen.Width := 1;
    Canvas.Brush.Color := TextColor;
    if PointRight then
      ArrowX := GlyphRect.Right - 2
    else
      ArrowX := GlyphRect.Left + 2;
    if PointRight then
      Canvas.Polygon([Point(ArrowX - 4, MidY - 3),
        Point(ArrowX, MidY), Point(ArrowX - 4, MidY + 3)])
    else
      Canvas.Polygon([Point(ArrowX + 4, MidY - 3),
        Point(ArrowX, MidY), Point(ArrowX + 4, MidY + 3)]);
  end;

  procedure DrawResetGlyph(AllItems: Boolean);
  var
    ArrowInset: Integer;
    ArcRadius: Integer;
    BoxHalfHeight: Integer;
    BoxHalfWidth: Integer;
    Offset: Integer;
  begin
    Canvas.Pen.Color := TextColor;
    Canvas.Pen.Width := Max(1, H div 22);
    Canvas.Brush.Style := bsClear;
    Offset := Ord(AllItems) * Max(3, H div 9);
    BoxHalfWidth := Max(8, H * 9 div 28);
    BoxHalfHeight := Max(6, H * 6 div 28);
    ArcRadius := Max(11, H * 12 div 28);
    ArrowInset := Max(3, H * 4 div 28);
    Canvas.Rectangle(MidX - BoxHalfWidth - Offset,
      MidY - BoxHalfHeight, MidX + BoxHalfWidth - 1 - Offset,
      MidY + BoxHalfHeight);
    if AllItems then
      Canvas.Rectangle(MidX - BoxHalfWidth div 2, MidY - BoxHalfHeight - 3,
        MidX + BoxHalfWidth, MidY + BoxHalfHeight div 2);
    Canvas.Arc(MidX - ArcRadius, MidY - ArcRadius,
      MidX + ArcRadius + 1, MidY + ArcRadius + 1,
      MidX + ArcRadius - 1, MidY - BoxHalfHeight,
      MidX - ArcRadius + 2, MidY - BoxHalfHeight - 2);
    Canvas.Brush.Color := TextColor;
    Canvas.Polygon([Point(MidX - ArcRadius, MidY - BoxHalfHeight - 2),
      Point(MidX - ArcRadius + ArrowInset * 2,
        MidY - BoxHalfHeight - ArrowInset),
      Point(MidX - ArcRadius + ArrowInset div 2,
        MidY - BoxHalfHeight + ArrowInset)]);
    Canvas.Pen.Width := 1;
  end;

  procedure DrawFrameGlyph(const Kind: Integer);
  var
    AccentRgb: Cardinal;
    AccentOutline: TColor;
    FrameGlyphRect: TRect;
    ShadowRect: TRect;
  begin
    FrameGlyphRect := Rect(MidX - H div 4, MidY - H div 5,
      MidX + H div 4 + 1, MidY + H div 5 + 1);
    if Kind = 2 then
    begin
      ShadowRect := FrameGlyphRect;
      OffsetRect(ShadowRect, Max(3, H div 8), Max(2, H div 10));
      Canvas.Brush.Style := bsSolid;
      if FHasAccentColor then
        Canvas.Brush.Color := Accent
      else
        Canvas.Brush.Color := BlendColor(BackColor, TextColor, 95);
      AccentRgb := ColorToRGB(Canvas.Brush.Color);
      if GetRValue(AccentRgb) + GetGValue(AccentRgb) +
        GetBValue(AccentRgb) < 384 then
        AccentOutline := TColor($00D8D8D8)
      else
        AccentOutline := TColor($00303030);
      Canvas.Pen.Color := AccentOutline;
      Canvas.Pen.Width := 1;
      Canvas.Rectangle(ShadowRect);
    end;
    if Kind = 0 then
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := Accent;
      Canvas.Pen.Color := TextColor;
    end
    else
    begin
      Canvas.Brush.Style := bsClear;
      if Kind = 2 then
        Canvas.Pen.Color := TextColor
      else if FHasAccentColor then
        Canvas.Pen.Color := Accent
      else
        Canvas.Pen.Color := TextColor;
    end;
    Canvas.Pen.Width := Max(1, H div 20);
    Canvas.Rectangle(FrameGlyphRect);
    if Kind = 3 then
    begin
      InflateRect(FrameGlyphRect, -Max(2, H div 10), -Max(2, H div 10));
      Canvas.Pen.Color := Accent;
      Canvas.Rectangle(FrameGlyphRect);
    end;
    if Kind = 4 then
    begin
      InflateRect(FrameGlyphRect, -Max(2, H div 10), -Max(2, H div 10));
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := Accent;
      Canvas.Pen.Color := TextColor;
      Canvas.Rectangle(FrameGlyphRect);
    end;
    Canvas.Pen.Width := 1;
  end;

begin
  H := Min(ClientWidth, ClientHeight);
  MidX := ClientWidth div 2;
  MidY := ClientHeight div 2;
  if Parent <> nil then
    BackColor := Parent.Brush.Color
  else
    BackColor := clBtnFace;
  BorderColor := BlendColor(BackColor, clBtnShadow, 100);
  if FPressed and (FPressedColor <> clNone) then
    BackColor := FPressedColor
  else if FPressed then
    BackColor := BlendColor(BackColor, clHighlight, 90)
  else if (FCheckState = tbcsChecked) and (FCheckedColor <> clNone) then
    BackColor := FCheckedColor
  else if FCheckState = tbcsChecked then
    BackColor := BlendColor(BackColor, clHighlight, 65)
  else if (FCheckState = tbcsMixed) and (FMixedColor <> clNone) then
    BackColor := FMixedColor
  else if FCheckState = tbcsMixed then
    BackColor := BlendColor(BackColor, clHighlight, 38)
  else if FHot and (FHotColor <> clNone) then
    BackColor := FHotColor
  else if FHot then
    BackColor := BlendColor(BackColor, clHighlight, 28);

  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := BackColor;
  Canvas.Pen.Color := BackColor;
  Canvas.Rectangle(ClientRect);
  if FPressed or FHot or (FCheckState <> tbcsUnchecked) then
  begin
    Canvas.Brush.Style := bsClear;
    if FStateBorderColor <> clNone then
      Canvas.Pen.Color := FStateBorderColor
    else
      Canvas.Pen.Color := BorderColor;
    Canvas.Rectangle(0, 0, ClientWidth, ClientHeight);
  end;
  if FKind = tbkSeparator then
  begin
    Canvas.Pen.Color := BorderColor;
    Canvas.MoveTo(MidX, H div 4);
    Canvas.LineTo(MidX, H - H div 4);
    Exit;
  end;

  ResolvedBackColor := ColorToRGB(BackColor);
  if Enabled and
    (GetRValue(ResolvedBackColor) + GetGValue(ResolvedBackColor) +
     GetBValue(ResolvedBackColor) < 384) then
    TextColor := TColor($00E6E6E6)
  else if Enabled then
    TextColor := clWindowText
  else
    TextColor := clGrayText;
  if FHasAccentColor then
    Accent := FAccentColor
  else
    Accent := TextColor;
  GlyphRect := Rect(2, 2, ClientWidth - 2, ClientHeight - 2);
  Canvas.Pen.Color := TextColor;
  Canvas.Brush.Color := TextColor;
  Canvas.Pen.Width := 1;
  case FGlyph of
    tbgBold:
      DrawTextGlyph('B', [fsBold]);
    tbgItalic:
      DrawTextGlyph('I', [fsItalic]);
    tbgUnderline:
      DrawTextGlyph('U', [fsUnderline]);
    tbgStrikeOut:
      DrawTextGlyph('S', [fsStrikeOut]);
    tbgFont:
      DrawTextGlyph('Aa', []);
    tbgBeforeColor:
      DrawColorGlyph(False);
    tbgAfterColor:
      DrawColorGlyph(True);
    tbgOutline:
      begin
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Name := 'Segoe UI';
        Canvas.Font.Height := -Max(8, H * 58 div 100);
        Canvas.Font.Style := [fsBold];
        Canvas.Font.Color := TextColor;
        for GlyphY := -2 to 2 do
          for GlyphX := -2 to 2 do
            if (Abs(GlyphX) = 2) or (Abs(GlyphY) = 2) then
            begin
              OffsetRect(GlyphRect, GlyphX, GlyphY);
              DrawText(Canvas.Handle, 'A', 1, GlyphRect, TEXT_FLAGS);
              OffsetRect(GlyphRect, -GlyphX, -GlyphY);
            end;
        Canvas.Font.Color := BackColor;
        DrawText(Canvas.Handle, 'A', 1, GlyphRect, TEXT_FLAGS);
      end;
    tbgShadow:
      begin
        R := GlyphRect;
        OffsetRect(R, Max(4, H div 6), Max(1, H div 14));
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Name := 'Segoe UI';
        Canvas.Font.Height := -Max(8, H * 50 div 100);
        Canvas.Font.Style := [fsBold];
        Canvas.Font.Color := BlendColor(BackColor, TextColor, 100);
        DrawText(Canvas.Handle, 'A', 1, R, TEXT_FLAGS);
        OffsetRect(R, -Max(4, H div 6), -Max(1, H div 14));
        Canvas.Font.Color := TextColor;
        DrawText(Canvas.Handle, 'A', 1, R, TEXT_FLAGS);
      end;
    tbgShadowColor:
      DrawColorGlyph(True);
    tbgBlurColor:
      begin
        R := GlyphRect;
        Dec(R.Bottom, Max(3, H div 6));
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Name := 'Segoe UI';
        Canvas.Font.Height := -Max(8, H * 46 div 100);
        Canvas.Font.Style := [fsBold];
        Canvas.Font.Color := TextColor;
        DrawText(Canvas.Handle, 'A', 1, R, TEXT_FLAGS);
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := BlendColor(BackColor, TextColor, 120);
        Canvas.Pen.Color := Canvas.Brush.Color;
        Canvas.Ellipse(MidX + H div 6, MidY - H div 5,
          MidX + H div 6 + Max(2, H div 10),
          MidY - H div 5 + Max(2, H div 10));
        Canvas.Ellipse(MidX + H div 5, MidY,
          MidX + H div 5 + Max(2, H div 12),
          MidY + Max(2, H div 12));
        Canvas.Pen.Width := Max(2, H div 10);
        Canvas.Pen.Color := Accent;
        Canvas.MoveTo(GlyphRect.Left + H div 5,
          GlyphRect.Bottom - H div 6);
        Canvas.LineTo(GlyphRect.Right - H div 5,
          GlyphRect.Bottom - H div 6);
        Canvas.Pen.Width := 1;
      end;
    tbgOpacityText:
      DrawTextGlyph('A', [fsBold], 58);
    tbgOpacityOutline:
      begin
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Name := 'Segoe UI';
        Canvas.Font.Height := -Max(8, H * 52 div 100);
        Canvas.Font.Style := [fsBold];
        Canvas.Font.Color := clAqua;
        for GlyphY := -1 to 1 do
          for GlyphX := -1 to 1 do
            if (GlyphX <> 0) or (GlyphY <> 0) then
            begin
              OffsetRect(GlyphRect, GlyphX, GlyphY);
              DrawText(Canvas.Handle, 'A', 1, GlyphRect, TEXT_FLAGS);
              OffsetRect(GlyphRect, -GlyphX, -GlyphY);
            end;
        Canvas.Font.Color := TextColor;
        DrawText(Canvas.Handle, 'A', 1, GlyphRect, TEXT_FLAGS);
      end;
    tbgOpacityShadow:
      begin
        R := GlyphRect;
        OffsetRect(R, Max(3, H div 7), Max(2, H div 12));
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Name := 'Segoe UI';
        Canvas.Font.Height := -Max(8, H * 50 div 100);
        Canvas.Font.Style := [fsBold];
        Canvas.Font.Color := BlendColor(BackColor, TextColor, 95);
        DrawText(Canvas.Handle, 'A', 1, R, TEXT_FLAGS);
        Canvas.Font.Color := TextColor;
        DrawText(Canvas.Handle, 'A', 1, GlyphRect, TEXT_FLAGS);
      end;
    tbgOpacityBlur:
      begin
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := BlendColor(BackColor, TextColor, 125);
        Canvas.Pen.Color := Canvas.Brush.Color;
        Canvas.Ellipse(MidX - H div 3, MidY - H div 4,
          MidX - H div 3 + Max(2, H div 11),
          MidY - H div 4 + Max(2, H div 11));
        Canvas.Ellipse(MidX + H div 4, MidY - H div 5,
          MidX + H div 4 + Max(2, H div 10),
          MidY - H div 5 + Max(2, H div 10));
        Canvas.Ellipse(MidX + H div 4, MidY + H div 7,
          MidX + H div 4 + Max(2, H div 12),
          MidY + H div 7 + Max(2, H div 12));
        Canvas.Ellipse(MidX - H div 4, MidY + H div 5,
          MidX - H div 4 + Max(2, H div 12),
          MidY + H div 5 + Max(2, H div 12));
        DrawTextGlyph('A', [fsBold], 52);
      end;
    tbgAlignLeft, tbgAlignCenter, tbgAlignRight:
      begin
        Canvas.Pen.Color := TextColor;
        Canvas.Pen.Width := Max(1, H div 14);
        for K := 0 to 3 do
        begin
          R.Top := MidY - 7 + K * 5;
          if Odd(K) then
            R.Right := 7
          else
            R.Right := 10;
          case FGlyph of
            tbgAlignLeft:
              begin
                R.Left := MidX - 10;
                Canvas.MoveTo(R.Left, R.Top);
                Canvas.LineTo(R.Left + R.Right, R.Top);
              end;
            tbgAlignCenter:
              begin
                R.Left := MidX - R.Right div 2;
                Canvas.MoveTo(R.Left, R.Top);
                Canvas.LineTo(R.Left + R.Right, R.Top);
              end;
            tbgAlignRight:
              begin
                R.Left := MidX + 10;
                Canvas.MoveTo(R.Left - R.Right, R.Top);
                Canvas.LineTo(R.Left, R.Top);
              end;
          end;
        end;
        Canvas.Pen.Width := 1;
      end;
    tbgMoveToCenter:
      begin
        Canvas.Brush.Style := bsClear;
        Canvas.Rectangle(MidX - 6, MidY - 5, MidX + 7, MidY + 6);
        Canvas.MoveTo(MidX - 10, MidY);
        Canvas.LineTo(MidX + 11, MidY);
        Canvas.MoveTo(MidX, MidY - 10);
        Canvas.LineTo(MidX, MidY + 11);
      end;
    tbgPlacementTopLeft..tbgPlacementBottomRight:
      begin
        PlacementIndex := Ord(FGlyph) - Ord(tbgPlacementTopLeft);
        PlacementColumn := PlacementIndex mod 3;
        PlacementRow := PlacementIndex div 3;
        Canvas.Pen.Color := BlendColor(BackColor, TextColor, 190);
        Canvas.Pen.Width := Max(1, MulDiv(1, H, 28));
        for K := 0 to 2 do
        begin
          R.Top := MidY - MulDiv(5, H, 28) +
            K * MulDiv(5, H, 28);
          if K = PlacementRow then
          begin
            R.Left := MidX - MulDiv(9, H, 28);
            R.Right := MidX + MulDiv(10, H, 28);
          end
          else
          begin
            case PlacementColumn of
              0: R.Left := MidX - MulDiv(9, H, 28);
              1: R.Left := MidX - MulDiv(4, H, 28);
            else
              R.Left := MidX + MulDiv(1, H, 28);
            end;
            R.Right := R.Left + MulDiv(9, H, 28);
          end;
          Canvas.MoveTo(R.Left, R.Top);
          Canvas.LineTo(R.Right, R.Top);
        end;
        Canvas.Pen.Width := 1;
      end;
    tbgResetSelected:
      DrawResetGlyph(False);
    tbgResetAll:
      DrawResetGlyph(True);
    tbgAlignHorizontal:
      begin
        Canvas.Pen.Style := psDot;
        Canvas.MoveTo(MidX - 10, MidY + 5);
        Canvas.LineTo(MidX + 11, MidY + 5);
        Canvas.Pen.Style := psSolid;
        Canvas.Brush.Color := TextColor;
        Canvas.Rectangle(MidX - 10, MidY - 4, MidX - 5, MidY + 5);
        Canvas.Rectangle(MidX - 2, MidY - 8, MidX + 3, MidY + 5);
        Canvas.Rectangle(MidX + 6, MidY - 2, MidX + 11, MidY + 5);
      end;
    tbgDistributeHorizontal:
      begin
        Canvas.MoveTo(MidX - 10, MidY - 8);
        Canvas.LineTo(MidX - 10, MidY + 9);
        Canvas.MoveTo(MidX + 10, MidY - 8);
        Canvas.LineTo(MidX + 10, MidY + 9);
        Canvas.Brush.Color := TextColor;
        Canvas.Rectangle(MidX - 7, MidY - 4, MidX - 3, MidY + 5);
        Canvas.Rectangle(MidX - 1, MidY - 4, MidX + 2, MidY + 5);
        Canvas.Rectangle(MidX + 4, MidY - 4, MidX + 8, MidY + 5);
      end;
    tbgFrameFill:
      DrawFrameGlyph(0);
    tbgFrameOutline:
      DrawFrameGlyph(1);
    tbgFrameInnerOutline:
      DrawFrameGlyph(3);
    tbgFrameInnerPanel:
      DrawFrameGlyph(4);
    tbgFrameShadow:
      DrawFrameGlyph(2);
    tbgVisibility:
      begin
        R := Rect(MidX - H * 3 div 10, MidY - H div 5,
          MidX + H * 3 div 10 + 1, MidY + H div 5 + 1);
        Canvas.Brush.Style := bsClear;
        Canvas.Pen.Color := TextColor;
        Canvas.Pen.Width := Max(1, H div 14);
        Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom,
          H div 2, H div 2);
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := TextColor;
        Canvas.Ellipse(MidX - Max(2, H div 10),
          MidY - Max(2, H div 10), MidX + Max(2, H div 10) + 1,
          MidY + Max(2, H div 10) + 1);
        Canvas.Pen.Width := 1;
      end;
  end;
  if FCheckState = tbcsMixed then
  begin
    Canvas.Pen.Color := TextColor;
    Canvas.MoveTo(ClientWidth div 4, ClientHeight - 3);
    Canvas.LineTo(ClientWidth - ClientWidth div 4, ClientHeight - 3);
  end;
  if Focused then
  begin
    R := ClientRect;
    InflateRect(R, -3, -3);
    DrawFocusRect(Canvas.Handle, R);
  end;
end;

procedure TFormattingToolbarButton.RequestExecution;
begin
  if not Enabled or (FKind = tbkSeparator) then
    Exit;
  if FKind = tbkToggle then
    case FCheckState of
      tbcsChecked:
        CheckState := tbcsUnchecked;
      tbcsUnchecked, tbcsMixed:
        CheckState := tbcsChecked;
    end;
  if Assigned(FOnExecute) then
    FOnExecute(Self, Self);
  if Assigned(FOnOwnerExecute) then
    FOnOwnerExecute(Self, Self);
end;

procedure TFormattingToolbarButton.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TFormattingToolbarButton.SetCheckState(
  const Value: TFormattingToolbarCheckState);
begin
  if FCheckState = Value then
    Exit;
  FCheckState := Value;
  Invalidate;
end;

procedure TFormattingToolbarButton.SetGlyph(
  const Value: TFormattingToolbarGlyph);
begin
  if FGlyph = Value then
    Exit;
  FGlyph := Value;
  Invalidate;
end;

procedure TFormattingToolbarButton.SetHasAccentColor(
  const Value: Boolean);
begin
  if FHasAccentColor = Value then
    Exit;
  FHasAccentColor := Value;
  Invalidate;
end;

procedure TFormattingToolbarButton.SetKind(
  const Value: TFormattingToolbarButtonKind);
begin
  if FKind = Value then
    Exit;
  FKind := Value;
  if FKind <> tbkToggle then
    FCheckState := tbcsUnchecked;
  TabStop := FKind <> tbkSeparator;
  Invalidate;
end;

{ TFormattingToolbarButtons }

constructor TFormattingToolbarButtons.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FButtonExtent := 28;
  FSeparatorExtent := 6;
  FHotColor := clNone;
  FMixedColor := clNone;
  FCheckedColor := clNone;
  FPressedColor := clNone;
  FStateBorderColor := clNone;
  FItems := TObjectList<TFormattingToolbarButton>.Create(True);
  Height := FButtonExtent;
end;

destructor TFormattingToolbarButtons.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TFormattingToolbarButtons.AddButton(const HintText: string;
  Glyph: TFormattingToolbarGlyph; Kind: TFormattingToolbarButtonKind;
  TagValue: NativeInt;
  ExecuteEvent: TFormattingToolbarButtonExecuteEvent):
  TFormattingToolbarButton;
begin
  Result := TFormattingToolbarButton.Create(Self);
  Result.Parent := Self;
  Result.Hint := HintText;
  Result.ShowHint := HintText <> '';
  Result.Glyph := Glyph;
  Result.Kind := Kind;
  Result.Tag := TagValue;
  Result.OnExecute := ExecuteEvent;
  Result.FOnOwnerExecute := ButtonExecute;
  Result.HotColor := FHotColor;
  Result.MixedColor := FMixedColor;
  Result.CheckedColor := FCheckedColor;
  Result.PressedColor := FPressedColor;
  Result.StateBorderColor := FStateBorderColor;
  FItems.Add(Result);
  UpdateLayout;
end;

function TFormattingToolbarButtons.AddCommandButton(
  const HintText: string; Glyph: TFormattingToolbarGlyph;
  TagValue: NativeInt): TFormattingToolbarButton;
begin
  Result := AddButton(HintText, Glyph, tbkCommand, TagValue);
end;

function TFormattingToolbarButtons.AddDialogButton(
  const HintText: string; Glyph: TFormattingToolbarGlyph;
  TagValue: NativeInt): TFormattingToolbarButton;
begin
  Result := AddButton(HintText, Glyph, tbkDialog, TagValue);
end;

function TFormattingToolbarButtons.AddSeparator:
  TFormattingToolbarButton;
begin
  Result := AddButton('', tbgNone, tbkSeparator, -1);
end;

function TFormattingToolbarButtons.AddToggleButton(
  const HintText: string; Glyph: TFormattingToolbarGlyph;
  TagValue: NativeInt): TFormattingToolbarButton;
begin
  Result := AddButton(HintText, Glyph, tbkToggle, TagValue);
end;

procedure TFormattingToolbarButtons.ButtonExecute(Sender: TObject;
  Button: TFormattingToolbarButton);
begin
  if Assigned(FOnButtonExecute) then
    FOnButtonExecute(Self, Button);
end;

function TFormattingToolbarButtons.FindByTag(
  TagValue: NativeInt): TFormattingToolbarButton;
var
  Item: TFormattingToolbarButton;
begin
  Result := nil;
  for Item in FItems do
    if Item.Tag = TagValue then
      Exit(Item);
end;

function TFormattingToolbarButtons.GetItem(
  Index: Integer): TFormattingToolbarButton;
begin
  Result := FItems[Index];
end;

function TFormattingToolbarButtons.GetItemCount: Integer;
begin
  Result := FItems.Count;
end;

procedure TFormattingToolbarButtons.Relayout;
begin
  UpdateLayout;
end;

procedure TFormattingToolbarButtons.Resize;
begin
  inherited;
  UpdateLayout;
end;

procedure TFormattingToolbarButtons.SetButtonExtent(
  const Value: Integer);
begin
  if FButtonExtent = EnsureRange(Value, 16, 128) then
    Exit;
  FButtonExtent := EnsureRange(Value, 16, 128);
  UpdateLayout;
end;

procedure TFormattingToolbarButtons.SetHotColor(const Value: TColor);
var
  Item: TFormattingToolbarButton;
begin
  if FHotColor = Value then
    Exit;
  FHotColor := Value;
  for Item in FItems do
  begin
    Item.HotColor := Value;
    Item.Invalidate;
  end;
end;

procedure TFormattingToolbarButtons.SetMixedColor(const Value: TColor);
var
  Item: TFormattingToolbarButton;
begin
  if FMixedColor = Value then
    Exit;
  FMixedColor := Value;
  for Item in FItems do
  begin
    Item.MixedColor := Value;
    Item.Invalidate;
  end;
end;

procedure TFormattingToolbarButtons.SetCheckedColor(const Value: TColor);
var
  Item: TFormattingToolbarButton;
begin
  if FCheckedColor = Value then
    Exit;
  FCheckedColor := Value;
  for Item in FItems do
  begin
    Item.CheckedColor := Value;
    Item.Invalidate;
  end;
end;

procedure TFormattingToolbarButtons.SetPressedColor(const Value: TColor);
var
  Item: TFormattingToolbarButton;
begin
  if FPressedColor = Value then
    Exit;
  FPressedColor := Value;
  for Item in FItems do
  begin
    Item.PressedColor := Value;
    Item.Invalidate;
  end;
end;

procedure TFormattingToolbarButtons.SetStateBorderColor(
  const Value: TColor);
var
  Item: TFormattingToolbarButton;
begin
  if FStateBorderColor = Value then
    Exit;
  FStateBorderColor := Value;
  for Item in FItems do
  begin
    Item.StateBorderColor := Value;
    Item.Invalidate;
  end;
end;

procedure TFormattingToolbarButtons.SetSeparatorExtent(
  const Value: Integer);
begin
  if FSeparatorExtent = EnsureRange(Value, 1, 32) then
    Exit;
  FSeparatorExtent := EnsureRange(Value, 1, 32);
  UpdateLayout;
end;

procedure TFormattingToolbarButtons.UpdateLayout;
var
  Item: TFormattingToolbarButton;
  ItemWidth: Integer;
  X: Integer;
begin
  X := 0;
  for Item in FItems do
  begin
    if Item.Kind = tbkSeparator then
      ItemWidth := FSeparatorExtent
    else
      ItemWidth := FButtonExtent;
    Item.SetBounds(X, 0, ItemWidth, FButtonExtent);
    Inc(X, ItemWidth);
  end;
end;

end.
