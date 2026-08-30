unit PluginFilterSerifDrawFramePreview;

// 枠プレビューの座標計算、操作ハンドル、外観描画をフォームから分離して提供する。

interface

uses
  System.Types,
  PluginFilterSerifDrawSettings,
  Vcl.Controls,
  Vcl.Graphics;

type
  // 枠本体の移動・サイズ変更と、形状・装飾ハンドルの操作対象を識別する。
  TSerifDrawFrameHit = (
    sdfhNone,
    sdfhNorthWest,
    sdfhNorth,
    sdfhNorthEast,
    sdfhWest,
    sdfhEast,
    sdfhMove,
    sdfhSouthWest,
    sdfhSouth,
    sdfhSouthEast,
    sdfhOutlineWidth,
    sdfhShadowOffset,
    sdfhShadowSpread,
    sdfhShadowBlur,
    sdfhCornerRadius,
    sdfhTabOffset,
    sdfhTabWidth,
    sdfhTabHeight,
    sdfhBalloonTip,
    sdfhBalloonWidth,
    sdfhDottedDashLength,
    sdfhDottedGapLength,
    sdfhInnerPanelInsetX,
    sdfhInnerPanelInsetY,
    sdfhInnerPanelRadius
  );

// 映像座標の枠寸法と中心オフセットを、プレビュー上の矩形へ変換する。
function SerifDrawCommonFrameRect(const BackgroundRect: TRect;
  const BackgroundWidth, FrameWidth, FrameHeight: Integer;
  const PositionX: Double = 0; const PositionY: Double = 0): TRect;
// 旧版互換の配置番号から、映像座標系の枠寸法と中心オフセットを返す。
procedure SerifDrawFrameLayoutPreset(const BackgroundWidth, BackgroundHeight,
  Preset: Integer; out FrameWidth, FrameHeight: Integer;
  out PositionX, PositionY: Double);
// 影・ネオン・吹き出しの外周を配置範囲内へ収めるよう寸法と位置を直接補正する。
procedure SerifDrawFitFrameAppearanceInLayout(
  const Style: TSerifDrawFrameStyle; var FrameWidth, FrameHeight: Integer;
  var PositionX, PositionY: Double);
// プレビュー上の点を、移動または8方向のサイズ変更操作へ分類する。
function SerifDrawHitTestCommonFrame(const Point: TPoint;
  const FrameRect: TRect; const HandleRadius: Integer): TSerifDrawFrameHit;
// 枠操作の種類に対応するVCLカーソルを返す。
function SerifDrawFrameHitCursor(const Hit: TSerifDrawFrameHit): TCursor;
// 表示中の効果だけに調整ハンドルとヒットテストを提供する。
function SerifDrawFrameAdjustmentVisible(const Hit: TSerifDrawFrameHit;
  const OutlineVisible, ShadowVisible: Boolean): Boolean;
// プレビュー上のドラッグ量を映像座標へ戻し、中心基準で変更した寸法を返す。
procedure SerifDrawResizeCommonFrame(const Hit: TSerifDrawFrameHit;
  const StartWidth, StartHeight: Integer; const DeltaX, DeltaY,
  Scale: Double; out FrameWidth, FrameHeight: Integer);
// 呼び出し側で配置済みの矩形を使い、枠選択点と各調整ハンドルをCanvasへ描画する。
procedure DrawSerifDrawCommonFrameGuide(Canvas: TCanvas;
  const FrameRect: TRect; const Dpi: Integer;
  const ActiveHit: TSerifDrawFrameHit;
  const CornerRadiusHandle, TabOffsetHandle, TabWidthHandle,
  TabHeightHandle, BalloonTipHandle, BalloonWidthHandle,
  InnerPanelInsetXHandle, InnerPanelInsetYHandle, InnerPanelRadiusHandle,
  DottedDashHandle, DottedGapHandle,
  OutlineWidthHandle, ShadowOffsetHandle,
  ShadowSpreadHandle, ShadowBlurHandle: TRect);
// 角丸半径を操作するハンドル矩形をプレビュー座標で返す。
function SerifDrawFrameCornerRadiusHandleRect(const FrameRect: TRect;
  const Dpi, CornerRadius: Integer; const Scale: Double): TRect;
// 映像座標のタブ寸法をScaleで変換し、プレビュー上のタブ矩形を返す。
function SerifDrawFrameTabRect(const FrameRect: TRect;
  const TabWidth, TabHeight, TabOffset: Integer; const Scale: Double): TRect;
// タブ開始位置ハンドルをタブ左上の外側へ配置する。
function SerifDrawFrameTabOffsetHandleRect(const TabRect: TRect;
  const Dpi: Integer): TRect;
// タブ幅ハンドルをタブ右上の外側へ配置する。
function SerifDrawFrameTabWidthHandleRect(const TabRect: TRect;
  const Dpi: Integer): TRect;
// タブ高さハンドルを本体との接合側へ配置する。
function SerifDrawFrameTabHeightHandleRect(const TabRect: TRect;
  const Dpi: Integer): TRect;
// 尾方向・辺上位置・長さから、吹き出し先端をプレビュー座標で返す。
function SerifDrawFrameBalloonTipPoint(const FrameRect: TRect;
  const TailDirection, TailPosition, TailLength: Integer;
  const Scale: Double): TPoint;
// 吹き出し形状と操作ハンドルが重ならないDPI対応間隔を返す。
function SerifDrawFrameBalloonHandleGap(const Dpi: Integer): Integer;
// 吹き出し先端の移動ハンドルを形状の外側へ配置する。
function SerifDrawFrameBalloonTipHandleRect(const FrameRect: TRect;
  const Dpi, TailDirection, TailPosition, TailLength: Integer;
  const Scale: Double): TRect;
// 吹き出し尾の付け根幅を操作するハンドル矩形を返す。
function SerifDrawFrameBalloonWidthHandleRect(const FrameRect: TRect;
  const Dpi, TailDirection, TailPosition, TailWidth: Integer;
  const Scale: Double): TRect;
// 枠線幅ハンドルを枠右上の外側へ配置する。
function SerifDrawFrameOutlineWidthHandleRect(const FrameRect: TRect;
  const Dpi: Integer): TRect;
// 点線の描画長ハンドルを枠線幅ハンドルの左へ配置する。
function SerifDrawFrameDottedDashHandleRect(const OutlineHandle: TRect;
  const Dpi: Integer): TRect;
// 点線の空白長ハンドルを描画長ハンドルの左へ配置する。
function SerifDrawFrameDottedGapHandleRect(const OutlineHandle: TRect;
  const Dpi: Integer): TRect;
// 内側パネルの左右余白ハンドルを現在値に対応する位置へ配置する。
function SerifDrawFrameInnerPanelInsetXHandleRect(const FrameRect: TRect;
  const Dpi, InsetX: Integer; const Scale: Double): TRect;
// 内側パネルの上下余白ハンドルを現在値に対応する位置へ配置する。
function SerifDrawFrameInnerPanelInsetYHandleRect(const FrameRect: TRect;
  const Dpi, InsetY: Integer; const Scale: Double): TRect;
// 内側パネル角丸ハンドルを余白と半径に対応する位置へ配置する。
function SerifDrawFrameInnerPanelRadiusHandleRect(const FrameRect: TRect;
  const Dpi, InsetX, InsetY, Radius: Integer; const Scale: Double): TRect;
// 影オフセットハンドルを枠右下から現在のオフセットだけ移動して返す。
function SerifDrawFrameShadowOffsetHandleRect(const FrameRect: TRect;
  const Dpi, OffsetX, OffsetY: Integer): TRect;
// 影拡散ハンドルを影位置ハンドルの右側へ配置する。
function SerifDrawFrameShadowSpreadHandleRect(const ShadowHandle: TRect;
  const Dpi, Spread: Integer): TRect;
// 影ぼかしハンドルを影位置ハンドルの左側へ配置する。
function SerifDrawFrameShadowBlurHandleRect(const ShadowHandle: TRect;
  const Dpi, Blur: Integer): TRect;
// 指定外観をCanvasへ描画する。引数の寸法は呼び出し側でプレビュー倍率を適用する。
procedure DrawSerifDrawCommonFrameAppearance(Canvas: TCanvas;
  const FrameRect: TRect; const Dpi: Integer;
  const Shape, CornerRadius, TabWidth, TabHeight, TabOffset: Integer;
  const BalloonTailDirection, BalloonTailPosition, BalloonTailWidth,
  BalloonTailLength: Integer;
  const Layering: Integer;
  const InnerPanelInsetX, InnerPanelInsetY, InnerPanelRadius: Integer;
  const OutlineWidth, OutlineStyle, DottedDashLength, DottedGapLength,
  ShadowOffsetX, ShadowOffsetY, ShadowSpread, ShadowBlur: Integer;
  const FillVisible, OutlineVisible, ShadowVisible: Boolean;
  const FillColor, OutlineColor, InnerOutlineColor, InnerPanelColor,
  ShadowColor: Cardinal; const FillMode: Integer = SERIF_FRAME_FILL_SOLID;
  const GradientStrength: Integer = 30);

implementation

uses
  System.Math,
  PluginFilterSerifDrawSettingsTheme,
  Winapi.Windows;

const
  MIN_FRAME_SIZE = 1;
  MAX_FRAME_SIZE = 20000;

function SerifDrawCommonFrameRect(const BackgroundRect: TRect;
  const BackgroundWidth, FrameWidth, FrameHeight: Integer;
  const PositionX, PositionY: Double): TRect;
var
  CenterX: Integer;
  CenterY: Integer;
  DrawHeight: Integer;
  DrawWidth: Integer;
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (BackgroundWidth <= 0) or (BackgroundRect.Width <= 0) then
    Exit;
  Scale := BackgroundRect.Width / BackgroundWidth;
  CenterX := (BackgroundRect.Left + BackgroundRect.Right) div 2 +
    Round(PositionX * Scale);
  CenterY := (BackgroundRect.Top + BackgroundRect.Bottom) div 2 +
    Round(PositionY * Scale);
  DrawWidth := Max(1, Round(Max(MIN_FRAME_SIZE, FrameWidth) * Scale));
  DrawHeight := Max(1, Round(Max(MIN_FRAME_SIZE, FrameHeight) * Scale));
  Result.Left := CenterX - DrawWidth div 2;
  Result.Top := CenterY - DrawHeight div 2;
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

procedure SerifDrawFrameLayoutPreset(const BackgroundWidth, BackgroundHeight,
  Preset: Integer; out FrameWidth, FrameHeight: Integer;
  out PositionX, PositionY: Double);
var
  MarginX: Integer;
begin
  FrameWidth := Max(1, BackgroundWidth);
  FrameHeight := Max(1, Round(BackgroundHeight * 230 / 1080));
  MarginX := Max(0, Round(BackgroundWidth * 270 / 1920));
  PositionX := 0;
  PositionY := (BackgroundHeight - FrameHeight) * 0.5;
  case Preset of
    2: // 右
      begin
        FrameWidth := Max(1, BackgroundWidth - MarginX);
        PositionX := MarginX * 0.5;
      end;
    3: // 左
      begin
        FrameWidth := Max(1, BackgroundWidth - MarginX);
        PositionX := -MarginX * 0.5;
      end;
    4: // 中
      FrameWidth := Max(1, BackgroundWidth - MarginX * 2);
  end;
end;

procedure SerifDrawFitFrameAppearanceInLayout(
  const Style: TSerifDrawFrameStyle; var FrameWidth, FrameHeight: Integer;
  var PositionX, PositionY: Double);
var
  BlurExtent: Integer;
  BottomExtent: Integer;
  LeftExtent: Integer;
  OutlineExtent: Integer;
  RightExtent: Integer;
  ShapeBottomExtent: Integer;
  ShapeLeftExtent: Integer;
  ShapeRightExtent: Integer;
  ShapeTopExtent: Integer;
  ShadowBottomExtent: Integer;
  ShadowLeftExtent: Integer;
  ShadowRightExtent: Integer;
  ShadowTopExtent: Integer;
  TopExtent: Integer;
begin
  ShapeLeftExtent := 0;
  ShapeTopExtent := 0;
  ShapeRightExtent := 0;
  ShapeBottomExtent := 0;
  if Style.Shape = 3 then
    if Style.BalloonTailDirection in [2, 3] then
    begin
      ShapeLeftExtent := Max(1, Style.BalloonTailLength);
      ShapeRightExtent := ShapeLeftExtent;
    end
    else
    begin
      ShapeTopExtent := Max(1, Style.BalloonTailLength);
      ShapeBottomExtent := ShapeTopExtent;
    end;

  OutlineExtent := 0;
  if Style.OutlineVisible and (Style.OutlineStyle = 2) then
    OutlineExtent := Max(0, Style.OutlineWidth);
  LeftExtent := ShapeLeftExtent + OutlineExtent;
  TopExtent := ShapeTopExtent + OutlineExtent;
  RightExtent := ShapeRightExtent + OutlineExtent;
  BottomExtent := ShapeBottomExtent + OutlineExtent;

  if Style.ShadowVisible and (Style.Layering = 0) then
  begin
    BlurExtent := Max(0, Round(Style.ShadowSpread)) +
      Max(0, Round(Style.ShadowBlur));
    ShadowLeftExtent := ShapeLeftExtent +
      Max(0, -Round(Style.ShadowOffsetX) + BlurExtent);
    ShadowTopExtent := ShapeTopExtent +
      Max(0, -Round(Style.ShadowOffsetY) + BlurExtent);
    ShadowRightExtent := ShapeRightExtent +
      Max(0, Round(Style.ShadowOffsetX) + BlurExtent);
    ShadowBottomExtent := ShapeBottomExtent +
      Max(0, Round(Style.ShadowOffsetY) + BlurExtent);
    LeftExtent := Max(LeftExtent, ShadowLeftExtent);
    TopExtent := Max(TopExtent, ShadowTopExtent);
    RightExtent := Max(RightExtent, ShadowRightExtent);
    BottomExtent := Max(BottomExtent, ShadowBottomExtent);
  end;

  FrameWidth := Max(1, FrameWidth - LeftExtent - RightExtent);
  FrameHeight := Max(1, FrameHeight - TopExtent - BottomExtent);
  PositionX := PositionX + (LeftExtent - RightExtent) * 0.5;
  PositionY := PositionY + (TopExtent - BottomExtent) * 0.5;
end;

function SerifDrawHitTestCommonFrame(const Point: TPoint;
  const FrameRect: TRect; const HandleRadius: Integer): TSerifDrawFrameHit;
var
  MidX: Integer;
  MidY: Integer;

  function Near(const X, Y: Integer): Boolean;
  begin
    Result := (Abs(Point.X - X) <= HandleRadius) and
      (Abs(Point.Y - Y) <= HandleRadius);
  end;

begin
  Result := sdfhNone;
  if (FrameRect.Width <= 0) or (FrameRect.Height <= 0) then
    Exit;
  MidX := (FrameRect.Left + FrameRect.Right) div 2;
  MidY := (FrameRect.Top + FrameRect.Bottom) div 2;
  if Near(FrameRect.Left, FrameRect.Top) then Exit(sdfhNorthWest);
  if Near(MidX, FrameRect.Top) then Exit(sdfhNorth);
  if Near(FrameRect.Right, FrameRect.Top) then Exit(sdfhNorthEast);
  if Near(FrameRect.Left, MidY) then Exit(sdfhWest);
  if Near(FrameRect.Right, MidY) then Exit(sdfhEast);
  if Near(FrameRect.Left, FrameRect.Bottom) then Exit(sdfhSouthWest);
  if Near(MidX, FrameRect.Bottom) then Exit(sdfhSouth);
  if Near(FrameRect.Right, FrameRect.Bottom) then Exit(sdfhSouthEast);
  if PtInRect(FrameRect, Point) then
    Result := sdfhMove;
end;

function SerifDrawFrameHitCursor(const Hit: TSerifDrawFrameHit): TCursor;
begin
  case Hit of
    sdfhNorthWest, sdfhSouthEast: Result := crSizeNWSE;
    sdfhNorthEast, sdfhSouthWest: Result := crSizeNESW;
    sdfhWest, sdfhEast: Result := crSizeWE;
    sdfhNorth, sdfhSouth: Result := crSizeNS;
    sdfhMove: Result := crSizeAll;
    sdfhOutlineWidth: Result := crSizeNESW;
    sdfhShadowOffset: Result := crSizeAll;
    sdfhShadowSpread: Result := crSizeNWSE;
    sdfhShadowBlur: Result := crSizeNESW;
    sdfhCornerRadius: Result := crSizeWE;
    sdfhTabOffset: Result := crSizeWE;
    sdfhTabWidth: Result := crSizeWE;
    sdfhTabHeight: Result := crSizeNS;
    sdfhBalloonTip: Result := crSizeAll;
    sdfhBalloonWidth: Result := crSizeWE;
    sdfhDottedDashLength, sdfhDottedGapLength: Result := crSizeWE;
    sdfhInnerPanelInsetX, sdfhInnerPanelRadius: Result := crSizeWE;
    sdfhInnerPanelInsetY: Result := crSizeNS;
  else
    Result := crDefault;
  end;
end;

function SerifDrawFrameAdjustmentVisible(const Hit: TSerifDrawFrameHit;
  const OutlineVisible, ShadowVisible: Boolean): Boolean;
begin
  case Hit of
    sdfhOutlineWidth, sdfhDottedDashLength, sdfhDottedGapLength:
      Result := OutlineVisible;
    sdfhShadowOffset, sdfhShadowSpread, sdfhShadowBlur:
      Result := ShadowVisible;
  else
    Result := True;
  end;
end;

function SerifDrawFrameTabRect(const FrameRect: TRect;
  const TabWidth, TabHeight, TabOffset: Integer; const Scale: Double): TRect;
var
  DrawHeight: Integer;
  DrawOffset: Integer;
  DrawWidth: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (FrameRect.Width <= 0) or (FrameRect.Height <= 0) or (Scale <= 0) then
    Exit;
  DrawHeight := EnsureRange(Round(TabHeight * Scale), 1,
    Max(1, FrameRect.Height - 1));
  DrawOffset := EnsureRange(Round(TabOffset * Scale), 0,
    Max(0, FrameRect.Width - 1));
  DrawWidth := EnsureRange(Round(TabWidth * Scale), 1,
    Max(1, FrameRect.Width - DrawOffset));
  Result := Rect(FrameRect.Left + DrawOffset, FrameRect.Top,
    FrameRect.Left + DrawOffset + DrawWidth, FrameRect.Top + DrawHeight);
end;

function CenteredHandle(const X, Y, Dpi: Integer): TRect;
var
  Extent: Integer;
begin
  Extent := Max(16, MulDiv(20, Dpi, 96));
  Result := Rect(X - Extent div 2, Y - Extent div 2,
    X - Extent div 2 + Extent, Y - Extent div 2 + Extent);
end;

function SerifDrawFrameTabOffsetHandleRect(const TabRect: TRect;
  const Dpi: Integer): TRect;
begin
  Result := CenteredHandle(TabRect.Left, TabRect.Top -
    Max(12, MulDiv(16, Dpi, 96)), Dpi);
end;

function SerifDrawFrameTabWidthHandleRect(const TabRect: TRect;
  const Dpi: Integer): TRect;
begin
  Result := CenteredHandle(TabRect.Right, TabRect.Top -
    Max(12, MulDiv(16, Dpi, 96)), Dpi);
end;

function SerifDrawFrameTabHeightHandleRect(const TabRect: TRect;
  const Dpi: Integer): TRect;
begin
  Result := CenteredHandle((TabRect.Left + TabRect.Right) div 2,
    TabRect.Bottom, Dpi);
end;

function SerifDrawFrameBalloonTipPoint(const FrameRect: TRect;
  const TailDirection, TailPosition, TailLength: Integer;
  const Scale: Double): TPoint;
var
  Along: Integer;
  Length: Integer;
begin
  Result := Point(0, 0);
  if (FrameRect.Width <= 0) or (FrameRect.Height <= 0) or (Scale <= 0) then
    Exit;
  Length := Max(1, Round(TailLength * Scale));
  if TailDirection in [2, 3] then
  begin
    Along := EnsureRange((FrameRect.Top + FrameRect.Bottom) div 2 +
      Round(TailPosition * Scale), FrameRect.Top, FrameRect.Bottom);
    Result.Y := Along;
    if TailDirection = 2 then Result.X := FrameRect.Left - Length
    else Result.X := FrameRect.Right + Length;
  end
  else
  begin
    Along := EnsureRange((FrameRect.Left + FrameRect.Right) div 2 +
      Round(TailPosition * Scale), FrameRect.Left, FrameRect.Right);
    Result.X := Along;
    if TailDirection = 1 then Result.Y := FrameRect.Top - Length
    else Result.Y := FrameRect.Bottom + Length;
  end;
end;

function SerifDrawFrameBalloonHandleGap(const Dpi: Integer): Integer;
begin
  Result := Max(12, MulDiv(16, Dpi, 96));
end;

function SerifDrawFrameBalloonTipHandleRect(const FrameRect: TRect;
  const Dpi, TailDirection, TailPosition, TailLength: Integer;
  const Scale: Double): TRect;
var
  Gap: Integer;
  Tip: TPoint;
begin
  Tip := SerifDrawFrameBalloonTipPoint(FrameRect, TailDirection, TailPosition,
    TailLength, Scale);
  if (Tip.X = 0) and (Tip.Y = 0) then
    Exit(Rect(0, 0, 0, 0));
  Gap := SerifDrawFrameBalloonHandleGap(Dpi);
  case TailDirection of
    1: Dec(Tip.Y, Gap);
    2: Dec(Tip.X, Gap);
    3: Inc(Tip.X, Gap);
  else
    Inc(Tip.Y, Gap);
  end;
  Result := CenteredHandle(Tip.X, Tip.Y, Dpi);
end;

function SerifDrawFrameBalloonWidthHandleRect(const FrameRect: TRect;
  const Dpi, TailDirection, TailPosition, TailWidth: Integer;
  const Scale: Double): TRect;
var
  Along: Integer;
  BaseEnd: Integer;
  Gap: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (FrameRect.Width <= 0) or (FrameRect.Height <= 0) or (Scale <= 0) then
    Exit;
  Gap := SerifDrawFrameBalloonHandleGap(Dpi);
  if TailDirection in [2, 3] then
  begin
    Along := EnsureRange((FrameRect.Top + FrameRect.Bottom) div 2 +
      Round(TailPosition * Scale), FrameRect.Top, FrameRect.Bottom);
    BaseEnd := EnsureRange(Along + Max(1, Round(TailWidth * Scale)) div 2,
      FrameRect.Top, FrameRect.Bottom);
    if TailDirection = 2 then
      Result := CenteredHandle(FrameRect.Left, BaseEnd + Gap, Dpi)
    else
      Result := CenteredHandle(FrameRect.Right, BaseEnd + Gap, Dpi);
  end
  else
  begin
    Along := EnsureRange((FrameRect.Left + FrameRect.Right) div 2 +
      Round(TailPosition * Scale), FrameRect.Left, FrameRect.Right);
    BaseEnd := EnsureRange(Along + Max(1, Round(TailWidth * Scale)) div 2,
      FrameRect.Left, FrameRect.Right);
    if TailDirection = 1 then
      Result := CenteredHandle(BaseEnd + Gap, FrameRect.Top, Dpi)
    else
      Result := CenteredHandle(BaseEnd + Gap, FrameRect.Bottom, Dpi);
  end;
end;

function SerifDrawFrameCornerRadiusHandleRect(const FrameRect: TRect;
  const Dpi, CornerRadius: Integer; const Scale: Double): TRect;
var
  CenterX: Integer;
  Extent: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (FrameRect.Width <= 0) or (FrameRect.Height <= 0) or (Scale <= 0) then
    Exit;
  Extent := Max(16, MulDiv(20, Dpi, 96));
  CenterX := FrameRect.Left + Min(FrameRect.Width div 2,
    Round(Max(0, CornerRadius) * Scale));
  Result := Rect(CenterX - Extent div 2,
    FrameRect.Top + MulDiv(10, Dpi, 96), CenterX - Extent div 2 + Extent,
    FrameRect.Top + MulDiv(10, Dpi, 96) + Extent);
end;

function SerifDrawFrameShadowBlurHandleRect(const ShadowHandle: TRect;
  const Dpi, Blur: Integer): TRect;
var
  Extent: Integer;
  Gap: Integer;
  Top: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (ShadowHandle.Width <= 0) or (ShadowHandle.Height <= 0) then
    Exit;
  Extent := Max(20, MulDiv(28, Dpi, 96));
  Gap := Max(4, MulDiv(8, Dpi, 96));
  Top := (ShadowHandle.Top + ShadowHandle.Bottom - Extent) div 2;
  Result := Rect(ShadowHandle.Left - Gap - Extent - Blur, Top,
    ShadowHandle.Left - Gap - Blur, Top + Extent);
end;

function SerifDrawFrameShadowSpreadHandleRect(const ShadowHandle: TRect;
  const Dpi, Spread: Integer): TRect;
var
  Extent: Integer;
  Gap: Integer;
  Top: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (ShadowHandle.Width <= 0) or (ShadowHandle.Height <= 0) then
    Exit;
  Extent := Max(20, MulDiv(28, Dpi, 96));
  Gap := Max(4, MulDiv(8, Dpi, 96));
  Top := (ShadowHandle.Top + ShadowHandle.Bottom - Extent) div 2;
  Result := Rect(ShadowHandle.Right + Gap + Spread, Top,
    ShadowHandle.Right + Gap + Spread + Extent, Top + Extent);
end;

function SerifDrawFrameShadowOffsetHandleRect(const FrameRect: TRect;
  const Dpi, OffsetX, OffsetY: Integer): TRect;
var
  Extent: Integer;
  Gap: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (FrameRect.Width <= 0) or (FrameRect.Height <= 0) then
    Exit;
  Extent := Max(20, MulDiv(28, Dpi, 96));
  Gap := Max(4, MulDiv(8, Dpi, 96));
  Result := Rect(FrameRect.Right + Gap + OffsetX,
    FrameRect.Bottom + Gap + OffsetY,
    FrameRect.Right + Gap + OffsetX + Extent,
    FrameRect.Bottom + Gap + OffsetY + Extent);
end;

function SerifDrawFrameOutlineWidthHandleRect(const FrameRect: TRect;
  const Dpi: Integer): TRect;
var
  Extent: Integer;
  Gap: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (FrameRect.Width <= 0) or (FrameRect.Height <= 0) then
    Exit;
  Extent := Max(20, MulDiv(28, Dpi, 96));
  Gap := Max(4, MulDiv(8, Dpi, 96));
  Result := Rect(FrameRect.Right + Gap, FrameRect.Top - Extent - Gap,
    FrameRect.Right + Gap + Extent, FrameRect.Top - Gap);
end;

function SerifDrawFrameDottedDashHandleRect(const OutlineHandle: TRect;
  const Dpi: Integer): TRect;
begin
  Result := OutlineHandle;
  if Result.Width <= 0 then
    Exit;
  OffsetRect(Result, -(Result.Width + Max(4, MulDiv(6, Dpi, 96))), 0);
end;

function SerifDrawFrameDottedGapHandleRect(const OutlineHandle: TRect;
  const Dpi: Integer): TRect;
begin
  Result := SerifDrawFrameDottedDashHandleRect(OutlineHandle, Dpi);
  if Result.Width <= 0 then
    Exit;
  OffsetRect(Result, -(Result.Width + Max(4, MulDiv(6, Dpi, 96))), 0);
end;

function SerifDrawFrameInnerPanelInsetXHandleRect(const FrameRect: TRect;
  const Dpi, InsetX: Integer; const Scale: Double): TRect;
begin
  if Scale <= 0 then
    Exit(Rect(0, 0, 0, 0));
  Result := CenteredHandle(FrameRect.Left + Max(MulDiv(10, Dpi, 96),
    Round(Max(0, InsetX) * Scale)),
    (FrameRect.Top + FrameRect.Bottom) div 2, Dpi);
end;

function SerifDrawFrameInnerPanelInsetYHandleRect(const FrameRect: TRect;
  const Dpi, InsetY: Integer; const Scale: Double): TRect;
begin
  if Scale <= 0 then
    Exit(Rect(0, 0, 0, 0));
  Result := CenteredHandle((FrameRect.Left + FrameRect.Right) div 2,
    FrameRect.Top + Max(MulDiv(10, Dpi, 96),
    Round(Max(0, InsetY) * Scale)), Dpi);
end;

function SerifDrawFrameInnerPanelRadiusHandleRect(const FrameRect: TRect;
  const Dpi, InsetX, InsetY, Radius: Integer; const Scale: Double): TRect;
begin
  if Scale <= 0 then
    Exit(Rect(0, 0, 0, 0));
  Result := CenteredHandle(FrameRect.Left + Round(Max(0, InsetX) * Scale) +
    Max(MulDiv(10, Dpi, 96), Round(Max(0, Radius) * Scale)),
    FrameRect.Top + Max(MulDiv(10, Dpi, 96),
    Round(Max(0, InsetY) * Scale)), Dpi);
end;

procedure SerifDrawResizeCommonFrame(const Hit: TSerifDrawFrameHit;
  const StartWidth, StartHeight: Integer; const DeltaX, DeltaY,
  Scale: Double; out FrameWidth, FrameHeight: Integer);
var
  WidthDelta: Double;
  HeightDelta: Double;
begin
  FrameWidth := StartWidth;
  FrameHeight := StartHeight;
  if Scale <= 0 then
    Exit;
  WidthDelta := 0;
  HeightDelta := 0;
  case Hit of
    sdfhNorthWest, sdfhWest, sdfhSouthWest:
      WidthDelta := -2 * DeltaX / Scale;
    sdfhNorthEast, sdfhEast, sdfhSouthEast:
      WidthDelta := 2 * DeltaX / Scale;
  end;
  case Hit of
    sdfhNorthWest, sdfhNorth, sdfhNorthEast:
      HeightDelta := -2 * DeltaY / Scale;
    sdfhSouthWest, sdfhSouth, sdfhSouthEast:
      HeightDelta := 2 * DeltaY / Scale;
  end;
  FrameWidth := EnsureRange(Round(StartWidth + WidthDelta),
    MIN_FRAME_SIZE, MAX_FRAME_SIZE);
  FrameHeight := EnsureRange(Round(StartHeight + HeightDelta),
    MIN_FRAME_SIZE, MAX_FRAME_SIZE);
end;

procedure DrawSerifDrawCommonFrameGuide(Canvas: TCanvas;
  const FrameRect: TRect; const Dpi: Integer;
  const ActiveHit: TSerifDrawFrameHit;
  const CornerRadiusHandle, TabOffsetHandle, TabWidthHandle,
  TabHeightHandle, BalloonTipHandle, BalloonWidthHandle,
  InnerPanelInsetXHandle, InnerPanelInsetYHandle, InnerPanelRadiusHandle,
  DottedDashHandle, DottedGapHandle,
  OutlineWidthHandle, ShadowOffsetHandle,
  ShadowSpreadHandle, ShadowBlurHandle: TRect);
var
  HandleRadius: Integer;
  InnerRect: TRect;
  MidX: Integer;
  MidY: Integer;

  procedure DrawHandle(const X, Y: Integer; const Hit: TSerifDrawFrameHit);
  begin
    if Hit = ActiveHit then
      Canvas.Brush.Color := clAqua
    else
      Canvas.Brush.Color := clBlack;
    Canvas.Rectangle(X - HandleRadius, Y - HandleRadius,
      X + HandleRadius + 1, Y + HandleRadius + 1);
  end;

begin
  if (FrameRect.Width <= 0) or (FrameRect.Height <= 0) then
    Exit;
  HandleRadius := Max(3, MulDiv(4, Dpi, 96));
  MidX := (FrameRect.Left + FrameRect.Right) div 2;
  MidY := (FrameRect.Top + FrameRect.Bottom) div 2;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := clAqua;
  Canvas.Pen.Width := Max(1, MulDiv(2, Dpi, 96));
  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Color := clAqua;
  Canvas.Pen.Width := 1;
  DrawHandle(FrameRect.Left, FrameRect.Top, sdfhNorthWest);
  DrawHandle(MidX, FrameRect.Top, sdfhNorth);
  DrawHandle(FrameRect.Right, FrameRect.Top, sdfhNorthEast);
  DrawHandle(FrameRect.Left, MidY, sdfhWest);
  DrawHandle(FrameRect.Right, MidY, sdfhEast);
  DrawHandle(FrameRect.Left, FrameRect.Bottom, sdfhSouthWest);
  DrawHandle(MidX, FrameRect.Bottom, sdfhSouth);
  DrawHandle(FrameRect.Right, FrameRect.Bottom, sdfhSouthEast);
  if InnerPanelInsetXHandle.Width > 0 then
    DrawHandle((InnerPanelInsetXHandle.Left + InnerPanelInsetXHandle.Right) div 2,
      (InnerPanelInsetXHandle.Top + InnerPanelInsetXHandle.Bottom) div 2,
      sdfhInnerPanelInsetX);
  if InnerPanelInsetYHandle.Width > 0 then
    DrawHandle((InnerPanelInsetYHandle.Left + InnerPanelInsetYHandle.Right) div 2,
      (InnerPanelInsetYHandle.Top + InnerPanelInsetYHandle.Bottom) div 2,
      sdfhInnerPanelInsetY);
  if InnerPanelRadiusHandle.Width > 0 then
  begin
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhInnerPanelRadius then Canvas.Pen.Color := clAqua
    else Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.Ellipse(InnerPanelRadiusHandle);
  end;
  if (CornerRadiusHandle.Width > 0) and
    (CornerRadiusHandle.Height > 0) then
  begin
    Canvas.Pen.Style := psDot;
    Canvas.Pen.Color := TColor($00909090);
    Canvas.MoveTo(FrameRect.Left, FrameRect.Top);
    Canvas.LineTo((CornerRadiusHandle.Left + CornerRadiusHandle.Right) div 2,
      (CornerRadiusHandle.Top + CornerRadiusHandle.Bottom) div 2);
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhCornerRadius then
      Canvas.Pen.Color := clAqua
    else
      Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.Ellipse(CornerRadiusHandle);
    InnerRect := CornerRadiusHandle;
    InflateRect(InnerRect, -MulDiv(5, Dpi, 96), -MulDiv(5, Dpi, 96));
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := SERIF_DRAW_FRAME_HANDLE_GLYPH_COLOR;
    Canvas.Arc(InnerRect.Left, InnerRect.Top, InnerRect.Right,
      InnerRect.Bottom, InnerRect.Left, InnerRect.Bottom,
      InnerRect.Right, InnerRect.Top);
    Canvas.Brush.Style := bsSolid;
  end;
  if (TabOffsetHandle.Width > 0) then
  begin
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhTabOffset then Canvas.Pen.Color := clAqua
    else Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.Rectangle(TabOffsetHandle);
    Canvas.MoveTo(TabOffsetHandle.Left + 4,
      (TabOffsetHandle.Top + TabOffsetHandle.Bottom) div 2);
    Canvas.LineTo(TabOffsetHandle.Right - 4,
      (TabOffsetHandle.Top + TabOffsetHandle.Bottom) div 2);
  end;
  if (TabWidthHandle.Width > 0) then
  begin
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhTabWidth then Canvas.Pen.Color := clAqua
    else Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.Rectangle(TabWidthHandle);
    Canvas.MoveTo(TabWidthHandle.Left + 4,
      (TabWidthHandle.Top + TabWidthHandle.Bottom) div 2);
    Canvas.LineTo(TabWidthHandle.Right - 4,
      (TabWidthHandle.Top + TabWidthHandle.Bottom) div 2);
  end;
  if (TabHeightHandle.Height > 0) then
  begin
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhTabHeight then Canvas.Pen.Color := clAqua
    else Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.Rectangle(TabHeightHandle);
    Canvas.MoveTo((TabHeightHandle.Left + TabHeightHandle.Right) div 2,
      TabHeightHandle.Top + 4);
    Canvas.LineTo((TabHeightHandle.Left + TabHeightHandle.Right) div 2,
      TabHeightHandle.Bottom - 4);
  end;
  if BalloonTipHandle.Height > 0 then
  begin
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhBalloonTip then Canvas.Pen.Color := clAqua
    else Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.Rectangle(BalloonTipHandle);
    Canvas.MoveTo(BalloonTipHandle.Left + 4,
      (BalloonTipHandle.Top + BalloonTipHandle.Bottom) div 2);
    Canvas.LineTo(BalloonTipHandle.Right - 4,
      (BalloonTipHandle.Top + BalloonTipHandle.Bottom) div 2);
    Canvas.MoveTo((BalloonTipHandle.Left + BalloonTipHandle.Right) div 2,
      BalloonTipHandle.Top + 4);
    Canvas.LineTo((BalloonTipHandle.Left + BalloonTipHandle.Right) div 2,
      BalloonTipHandle.Bottom - 4);
  end;
  if BalloonWidthHandle.Width > 0 then
  begin
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhBalloonWidth then Canvas.Pen.Color := clAqua
    else Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.Rectangle(BalloonWidthHandle);
    Canvas.MoveTo(BalloonWidthHandle.Left + 4,
      (BalloonWidthHandle.Top + BalloonWidthHandle.Bottom) div 2);
    Canvas.LineTo(BalloonWidthHandle.Right - 4,
      (BalloonWidthHandle.Top + BalloonWidthHandle.Bottom) div 2);
  end;
  if DottedDashHandle.Width > 0 then
  begin
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhDottedDashLength then Canvas.Pen.Color := clAqua
    else Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.Rectangle(DottedDashHandle);
    Canvas.Pen.Width := Max(2, MulDiv(3, Dpi, 96));
    Canvas.MoveTo(DottedDashHandle.Left + 5,
      (DottedDashHandle.Top + DottedDashHandle.Bottom) div 2);
    Canvas.LineTo(DottedDashHandle.Right - 5,
      (DottedDashHandle.Top + DottedDashHandle.Bottom) div 2);
    Canvas.Pen.Width := 1;
  end;
  if DottedGapHandle.Width > 0 then
  begin
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhDottedGapLength then Canvas.Pen.Color := clAqua
    else Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.Rectangle(DottedGapHandle);
    Canvas.MoveTo(DottedGapHandle.Left + 4,
      (DottedGapHandle.Top + DottedGapHandle.Bottom) div 2);
    Canvas.LineTo(DottedGapHandle.Left + 8,
      (DottedGapHandle.Top + DottedGapHandle.Bottom) div 2);
    Canvas.MoveTo(DottedGapHandle.Right - 8,
      (DottedGapHandle.Top + DottedGapHandle.Bottom) div 2);
    Canvas.LineTo(DottedGapHandle.Right - 4,
      (DottedGapHandle.Top + DottedGapHandle.Bottom) div 2);
  end;
  if (OutlineWidthHandle.Width > 0) and
    (OutlineWidthHandle.Height > 0) then
  begin
    Canvas.Pen.Style := psDot;
    Canvas.Pen.Color := TColor($00909090);
    Canvas.MoveTo(FrameRect.Right, FrameRect.Top);
    Canvas.LineTo((OutlineWidthHandle.Left + OutlineWidthHandle.Right) div 2,
      (OutlineWidthHandle.Top + OutlineWidthHandle.Bottom) div 2);
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhOutlineWidth then
      Canvas.Pen.Color := clAqua
    else
      Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.RoundRect(OutlineWidthHandle.Left, OutlineWidthHandle.Top,
      OutlineWidthHandle.Right, OutlineWidthHandle.Bottom,
      MulDiv(6, Dpi, 96), MulDiv(6, Dpi, 96));
    InnerRect := OutlineWidthHandle;
    InflateRect(InnerRect, -MulDiv(6, Dpi, 96), -MulDiv(6, Dpi, 96));
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := SERIF_DRAW_FRAME_HANDLE_GLYPH_COLOR;
    Canvas.Pen.Width := Max(2, MulDiv(2, Dpi, 96));
    Canvas.Rectangle(InnerRect);
    Canvas.Brush.Style := bsSolid;
    Canvas.Pen.Width := 1;
  end;
  if (ShadowOffsetHandle.Width > 0) and
    (ShadowOffsetHandle.Height > 0) then
  begin
    Canvas.Pen.Style := psDot;
    Canvas.Pen.Color := TColor($00909090);
    Canvas.MoveTo(FrameRect.Right, FrameRect.Bottom);
    Canvas.LineTo((ShadowOffsetHandle.Left + ShadowOffsetHandle.Right) div 2,
      (ShadowOffsetHandle.Top + ShadowOffsetHandle.Bottom) div 2);
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhShadowOffset then
      Canvas.Pen.Color := clAqua
    else
      Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.RoundRect(ShadowOffsetHandle.Left, ShadowOffsetHandle.Top,
      ShadowOffsetHandle.Right, ShadowOffsetHandle.Bottom,
      MulDiv(6, Dpi, 96), MulDiv(6, Dpi, 96));
    InnerRect := ShadowOffsetHandle;
    InflateRect(InnerRect, -MulDiv(7, Dpi, 96), -MulDiv(7, Dpi, 96));
    OffsetRect(InnerRect, MulDiv(3, Dpi, 96), MulDiv(3, Dpi, 96));
    Canvas.Brush.Color := SERIF_DRAW_FRAME_SHADOW_GLYPH_COLOR;
    Canvas.Pen.Color := SERIF_DRAW_FRAME_SHADOW_GLYPH_BORDER_COLOR;
    Canvas.Rectangle(InnerRect);
    OffsetRect(InnerRect, -MulDiv(5, Dpi, 96), -MulDiv(5, Dpi, 96));
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := SERIF_DRAW_FRAME_HANDLE_GLYPH_COLOR;
    Canvas.Pen.Width := Max(2, MulDiv(2, Dpi, 96));
    Canvas.Rectangle(InnerRect);
    Canvas.Brush.Style := bsSolid;
    Canvas.Pen.Width := 1;
  end;
  if (ShadowSpreadHandle.Width > 0) and
    (ShadowSpreadHandle.Height > 0) then
  begin
    Canvas.Pen.Style := psDot;
    Canvas.Pen.Color := TColor($00909090);
    Canvas.MoveTo(ShadowOffsetHandle.Right,
      (ShadowOffsetHandle.Top + ShadowOffsetHandle.Bottom) div 2);
    Canvas.LineTo((ShadowSpreadHandle.Left + ShadowSpreadHandle.Right) div 2,
      (ShadowSpreadHandle.Top + ShadowSpreadHandle.Bottom) div 2);
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhShadowSpread then
      Canvas.Pen.Color := clAqua
    else
      Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.RoundRect(ShadowSpreadHandle.Left, ShadowSpreadHandle.Top,
      ShadowSpreadHandle.Right, ShadowSpreadHandle.Bottom,
      MulDiv(6, Dpi, 96), MulDiv(6, Dpi, 96));
    InnerRect := ShadowSpreadHandle;
    InflateRect(InnerRect, -MulDiv(8, Dpi, 96), -MulDiv(8, Dpi, 96));
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := SERIF_DRAW_FRAME_HANDLE_GLYPH_COLOR;
    Canvas.Pen.Width := Max(2, MulDiv(2, Dpi, 96));
    Canvas.Rectangle(InnerRect);
    InflateRect(InnerRect, MulDiv(4, Dpi, 96), MulDiv(4, Dpi, 96));
    Canvas.Pen.Width := 1;
    Canvas.Rectangle(InnerRect);
    Canvas.Brush.Style := bsSolid;
  end;
  if (ShadowBlurHandle.Width > 0) and (ShadowBlurHandle.Height > 0) then
  begin
    Canvas.Pen.Style := psDot;
    Canvas.Pen.Color := TColor($00909090);
    Canvas.MoveTo(ShadowOffsetHandle.Left,
      (ShadowOffsetHandle.Top + ShadowOffsetHandle.Bottom) div 2);
    Canvas.LineTo((ShadowBlurHandle.Left + ShadowBlurHandle.Right) div 2,
      (ShadowBlurHandle.Top + ShadowBlurHandle.Bottom) div 2);
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Color := TColor($00303030);
    if ActiveHit = sdfhShadowBlur then
      Canvas.Pen.Color := clAqua
    else
      Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.RoundRect(ShadowBlurHandle.Left, ShadowBlurHandle.Top,
      ShadowBlurHandle.Right, ShadowBlurHandle.Bottom,
      MulDiv(6, Dpi, 96), MulDiv(6, Dpi, 96));
    InnerRect := ShadowBlurHandle;
    InflateRect(InnerRect, -MulDiv(9, Dpi, 96), -MulDiv(9, Dpi, 96));
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := SERIF_DRAW_FRAME_HANDLE_GLYPH_COLOR;
    Canvas.Pen.Width := 1;
    Canvas.Rectangle(InnerRect);
    InflateRect(InnerRect, MulDiv(4, Dpi, 96), MulDiv(4, Dpi, 96));
    Canvas.Pen.Color := TColor($00708080);
    Canvas.Rectangle(InnerRect);
    InflateRect(InnerRect, MulDiv(3, Dpi, 96), MulDiv(3, Dpi, 96));
    Canvas.Pen.Color := TColor($00405050);
    Canvas.Rectangle(InnerRect);
    Canvas.Brush.Style := bsSolid;
  end;
end;

procedure DrawSerifDrawCommonFrameAppearance(Canvas: TCanvas;
  const FrameRect: TRect; const Dpi: Integer;
  const Shape, CornerRadius, TabWidth, TabHeight, TabOffset: Integer;
  const BalloonTailDirection, BalloonTailPosition, BalloonTailWidth,
  BalloonTailLength: Integer;
  const Layering: Integer;
  const InnerPanelInsetX, InnerPanelInsetY, InnerPanelRadius: Integer;
  const OutlineWidth, OutlineStyle, DottedDashLength, DottedGapLength,
  ShadowOffsetX, ShadowOffsetY, ShadowSpread, ShadowBlur: Integer;
  const FillVisible, OutlineVisible, ShadowVisible: Boolean;
  const FillColor, OutlineColor, InnerOutlineColor, InnerPanelColor,
  ShadowColor: Cardinal; const FillMode: Integer;
  const GradientStrength: Integer);
var
  Blend: BLENDFUNCTION;
  ColorBitmap: Vcl.Graphics.TBitmap;
  DrawRect: TRect;
  DrawOutlineWidth: Integer;
  DrawLineWidth: Integer;
  GlowDistance: Integer;
  BlurDistance: Integer;
  BlurInnerDistance: Integer;
  BlurStep: Integer;
  InnerRect: TRect;
  InnerPanelRect: TRect;
  InnerPanelDrawRadius: Integer;
  OuterRect: TRect;

  function CreateAppearanceRegion(const Rect: TRect;
    const Radius: Integer): HRGN;
  var
    BodyRect: TRect;
    BodyRegion: HRGN;
    EffectiveTabWidth: Integer;
    ShapeInset: Integer;
    TabRect: TRect;
    TabRegion: HRGN;
    TailPoints: array[0..2] of TPoint;
    TailRegion: HRGN;
    TailCenter: Integer;
  begin
    if Shape = 2 then
    begin
      // 内周でもタブ右端を同じ距離だけ内側へ寄せ、接合部の輪郭を連続させる。
      ShapeInset := (FrameRect.Width - Rect.Width) div 2;
      EffectiveTabWidth := Max(1, TabWidth - ShapeInset * 2);
      BodyRect := Rect;
      BodyRect.Top := Min(BodyRect.Bottom - 1,
        BodyRect.Top + Max(1, TabHeight));
      TabRect := System.Types.Rect(Rect.Left + Max(0, TabOffset), Rect.Top,
        Min(Rect.Right, Rect.Left + Max(0, TabOffset) + EffectiveTabWidth),
        Min(Rect.Bottom, BodyRect.Top + Max(Max(1, Radius),
          Max(1, MulDiv(14, Dpi, 96)))));
      BodyRegion := CreateRoundRectRgn(BodyRect.Left, BodyRect.Top,
        BodyRect.Right + 1, BodyRect.Bottom + 1, Radius * 2, Radius * 2);
      TabRegion := CreateRoundRectRgn(TabRect.Left, TabRect.Top,
        TabRect.Right + 1, TabRect.Bottom + 1, Radius * 2, Radius * 2);
      CombineRgn(BodyRegion, BodyRegion, TabRegion, RGN_OR);
      DeleteObject(TabRegion);
      Exit(BodyRegion);
    end;
    if Shape = 3 then
    begin
      BodyRegion := CreateRoundRectRgn(Rect.Left, Rect.Top, Rect.Right + 1,
        Rect.Bottom + 1, Radius * 2, Radius * 2);
      if BalloonTailDirection in [2, 3] then
      begin
        TailCenter := EnsureRange((Rect.Top + Rect.Bottom) div 2 +
          BalloonTailPosition, Rect.Top, Rect.Bottom);
        if BalloonTailDirection = 2 then BodyRect.Left := Rect.Left
        else BodyRect.Left := Rect.Right - 1;
        TailPoints[0] := Point(BodyRect.Left, EnsureRange(TailCenter -
          Max(1, BalloonTailWidth) div 2, Rect.Top, Rect.Bottom));
        TailPoints[1] := Point(BodyRect.Left, EnsureRange(TailCenter +
          Max(1, BalloonTailWidth) div 2, Rect.Top, Rect.Bottom));
        if BalloonTailDirection = 2 then
          TailPoints[2] := Point(Rect.Left - Max(1, BalloonTailLength), TailCenter)
        else
          TailPoints[2] := Point(Rect.Right + Max(1, BalloonTailLength), TailCenter);
      end
      else
      begin
        TailCenter := EnsureRange((Rect.Left + Rect.Right) div 2 +
          BalloonTailPosition, Rect.Left, Rect.Right);
        if BalloonTailDirection = 1 then BodyRect.Top := Rect.Top
        else BodyRect.Top := Rect.Bottom - 1;
        TailPoints[0] := Point(EnsureRange(TailCenter -
          Max(1, BalloonTailWidth) div 2, Rect.Left, Rect.Right), BodyRect.Top);
        TailPoints[1] := Point(EnsureRange(TailCenter +
          Max(1, BalloonTailWidth) div 2, Rect.Left, Rect.Right), BodyRect.Top);
        if BalloonTailDirection = 1 then
          TailPoints[2] := Point(TailCenter, Rect.Top - Max(1, BalloonTailLength))
        else
          TailPoints[2] := Point(TailCenter, Rect.Bottom + Max(1, BalloonTailLength));
      end;
      TailRegion := CreatePolygonRgn(TailPoints, Length(TailPoints), WINDING);
      CombineRgn(BodyRegion, BodyRegion, TailRegion, RGN_OR);
      DeleteObject(TailRegion);
      Exit(BodyRegion);
    end;
    if Shape in [1, 3] then
      Result := CreateRoundRectRgn(Rect.Left, Rect.Top, Rect.Right + 1,
        Rect.Bottom + 1, Radius * 2, Radius * 2)
    else
      Result := CreateRectRgn(Rect.Left, Rect.Top, Rect.Right, Rect.Bottom);
  end;

  function AppearanceBounds(const Rect: TRect): TRect;
  begin
    Result := Rect;
    if Shape = 3 then
      case BalloonTailDirection of
        1: Result.Top := Result.Top - Max(1, BalloonTailLength);
        2: Result.Left := Result.Left - Max(1, BalloonTailLength);
        3: Result.Right := Result.Right + Max(1, BalloonTailLength);
      else
        Result.Bottom := Result.Bottom + Max(1, BalloonTailLength);
      end;
  end;

  procedure FillAlpha(const Rect: TRect; const Color: Cardinal);
  var
    Alpha: Byte;
    VclColor: TColor;
  begin
    Alpha := Color shr 24;
    VclColor := RGB((Color shr 16) and $FF, (Color shr 8) and $FF,
      Color and $FF);
    ColorBitmap.Canvas.Brush.Color := VclColor;
    ColorBitmap.Canvas.FillRect(System.Types.Rect(0, 0, 1, 1));
    Blend.BlendOp := AC_SRC_OVER;
    Blend.BlendFlags := 0;
    Blend.SourceConstantAlpha := Alpha;
    Blend.AlphaFormat := 0;
    Winapi.Windows.AlphaBlend(Canvas.Handle, Rect.Left, Rect.Top,
      Rect.Width, Rect.Height, ColorBitmap.Canvas.Handle, 0, 0, 1, 1, Blend);
  end;

  procedure FillAlphaRing(const OuterRect, InnerRect: TRect;
    const Color: Cardinal);
  begin
    FillAlpha(Rect(OuterRect.Left, OuterRect.Top, OuterRect.Right,
      InnerRect.Top), Color);
    FillAlpha(Rect(OuterRect.Left, InnerRect.Bottom, OuterRect.Right,
      OuterRect.Bottom), Color);
    FillAlpha(Rect(OuterRect.Left, InnerRect.Top, InnerRect.Left,
      InnerRect.Bottom), Color);
    FillAlpha(Rect(InnerRect.Right, InnerRect.Top, OuterRect.Right,
      InnerRect.Bottom), Color);
  end;

  procedure FillAlphaGradient(const Bounds, GradientRect: TRect;
    const Color: Cardinal; const Mode, Strength: Integer);
  var
    Y: Integer;
  begin
    if (Mode <> SERIF_FRAME_FILL_VERTICAL_GRADIENT) or (Strength <= 0) then
    begin
      FillAlpha(Bounds, Color);
      Exit;
    end;
    for Y := Bounds.Top to Bounds.Bottom - 1 do
      FillAlpha(System.Types.Rect(Bounds.Left, Y, Bounds.Right, Y + 1),
        SerifDrawFrameGradientColor(Color, Mode, Strength, Y,
          GradientRect.Top, GradientRect.Bottom));
  end;

  procedure FillAlphaRounded(const Rect: TRect; const Radius: Integer;
    const Color: Cardinal; const Mode: Integer = SERIF_FRAME_FILL_SOLID;
    const Strength: Integer = 0);
  var
    Region: HRGN;
    SavedDc: Integer;
  begin
    if (Shape = 0) or ((Shape = 1) and (Radius <= 0)) then
    begin
      FillAlphaGradient(Rect, Rect, Color, Mode, Strength);
      Exit;
    end;
    SavedDc := SaveDC(Canvas.Handle);
    try
      Region := CreateAppearanceRegion(Rect, Max(0, Radius));
      try
        SelectClipRgn(Canvas.Handle, Region);
        FillAlphaGradient(AppearanceBounds(Rect), Rect, Color, Mode,
          Strength);
      finally
        DeleteObject(Region);
      end;
    finally
      RestoreDC(Canvas.Handle, SavedDc);
    end;
  end;

  procedure FillAlphaInnerPanel(const Rect: TRect; const Radius: Integer;
    const Color: Cardinal; const Mode: Integer = SERIF_FRAME_FILL_SOLID;
    const Strength: Integer = 0);
  var
    Region: HRGN;
    SavedDc: Integer;
  begin
    SavedDc := SaveDC(Canvas.Handle);
    try
      Region := CreateRoundRectRgn(Rect.Left, Rect.Top, Rect.Right + 1,
        Rect.Bottom + 1, Radius * 2, Radius * 2);
      try
        SelectClipRgn(Canvas.Handle, Region);
        FillAlphaGradient(Rect, Rect, Color, Mode, Strength);
      finally
        DeleteObject(Region);
      end;
    finally
      RestoreDC(Canvas.Handle, SavedDc);
    end;
  end;

  procedure FillAlphaRoundedRing(const OuterRect, InnerRect: TRect;
    const OuterRadius, InnerRadius: Integer; const Color: Cardinal);
  var
    InnerRegion: HRGN;
    OuterRegion: HRGN;
    SavedDc: Integer;
  begin
    if (Shape = 0) or ((Shape = 1) and (OuterRadius <= 0)) then
    begin
      FillAlphaRing(OuterRect, InnerRect, Color);
      Exit;
    end;
    SavedDc := SaveDC(Canvas.Handle);
    try
      OuterRegion := CreateAppearanceRegion(OuterRect, Max(0, OuterRadius));
      try
        InnerRegion := CreateAppearanceRegion(InnerRect,
          Max(0, InnerRadius));
        try
          CombineRgn(OuterRegion, OuterRegion, InnerRegion, RGN_DIFF);
          SelectClipRgn(Canvas.Handle, OuterRegion);
          FillAlpha(AppearanceBounds(OuterRect), Color);
        finally
          DeleteObject(InnerRegion);
        end;
      finally
        DeleteObject(OuterRegion);
      end;
    finally
      RestoreDC(Canvas.Handle, SavedDc);
    end;
  end;

  procedure FillAlphaInnerPanelRing(const OuterRect, InnerRect: TRect;
    const OuterRadius, InnerRadius: Integer; const Color: Cardinal);
  var
    InnerRegion: HRGN;
    OuterRegion: HRGN;
    SavedDc: Integer;
  begin
    SavedDc := SaveDC(Canvas.Handle);
    try
      OuterRegion := CreateRoundRectRgn(OuterRect.Left, OuterRect.Top,
        OuterRect.Right + 1, OuterRect.Bottom + 1,
        Max(0, OuterRadius) * 2, Max(0, OuterRadius) * 2);
      try
        InnerRegion := CreateRoundRectRgn(InnerRect.Left, InnerRect.Top,
          InnerRect.Right + 1, InnerRect.Bottom + 1,
          Max(0, InnerRadius) * 2, Max(0, InnerRadius) * 2);
        try
          CombineRgn(OuterRegion, OuterRegion, InnerRegion, RGN_DIFF);
          SelectClipRgn(Canvas.Handle, OuterRegion);
          FillAlpha(OuterRect, Color);
        finally
          DeleteObject(InnerRegion);
        end;
      finally
        DeleteObject(OuterRegion);
      end;
    finally
      RestoreDC(Canvas.Handle, SavedDc);
    end;
  end;

  procedure FillAlphaRoundedDottedRing(const OuterRect, InnerRect: TRect;
    const OuterRadius, InnerRadius, DashLength, GapLength: Integer;
    const Color: Cardinal);
  var
    Bounds: TRect;
    CellRect: TRect;
    HorizontalRegion: HRGN;
    InnerBodyTop: Integer;
    InnerRegion: HRGN;
    OuterBodyTop: Integer;
    OuterRegion: HRGN;
    SavedDc: Integer;
    SectorRegion: HRGN;
    VerticalRegion: HRGN;
    X: Integer;
    Y: Integer;
  begin
    SavedDc := SaveDC(Canvas.Handle);
    try
      OuterRegion := CreateAppearanceRegion(OuterRect, Max(0, OuterRadius));
      try
        InnerRegion := CreateAppearanceRegion(InnerRect,
          Max(0, InnerRadius));
        try
          CombineRgn(OuterRegion, OuterRegion, InnerRegion, RGN_DIFF);
          Bounds := AppearanceBounds(OuterRect);
          HorizontalRegion := CreateRectRgn(Bounds.Left, Bounds.Top,
            Bounds.Right, Min(Bounds.Bottom, InnerRect.Top));
          try
            SectorRegion := CreateRectRgn(Bounds.Left,
              Max(Bounds.Top, InnerRect.Bottom), Bounds.Right, Bounds.Bottom);
            try
              CombineRgn(HorizontalRegion, HorizontalRegion,
                SectorRegion, RGN_OR);
            finally
              DeleteObject(SectorRegion);
            end;
            if Shape = 2 then
            begin
              // タブより一段下の本体上辺も、縦線ではなく横方向の点線として刻む。
              OuterBodyTop := Min(OuterRect.Bottom,
                OuterRect.Top + Max(1, TabHeight));
              InnerBodyTop := Min(InnerRect.Bottom,
                InnerRect.Top + Max(1, TabHeight));
              SectorRegion := CreateRectRgn(Bounds.Left, OuterBodyTop,
                Bounds.Right, InnerBodyTop);
              try
                CombineRgn(HorizontalRegion, HorizontalRegion,
                  SectorRegion, RGN_OR);
              finally
                DeleteObject(SectorRegion);
              end;
            end;
            CombineRgn(HorizontalRegion, HorizontalRegion,
              OuterRegion, RGN_AND);
            VerticalRegion := CreateRectRgn(0, 0, 0, 0);
            try
              CombineRgn(VerticalRegion, OuterRegion,
                HorizontalRegion, RGN_DIFF);
              SelectClipRgn(Canvas.Handle, HorizontalRegion);
              X := Bounds.Left;
              while X < Bounds.Right do
              begin
                CellRect := System.Types.Rect(X, Bounds.Top,
                  Min(Bounds.Right, X + DashLength), Bounds.Bottom);
                FillAlpha(CellRect, Color);
                Inc(X, DashLength + GapLength);
              end;
              SelectClipRgn(Canvas.Handle, VerticalRegion);
              Y := Bounds.Top;
              while Y < Bounds.Bottom do
              begin
                CellRect := System.Types.Rect(Bounds.Left, Y,
                  Bounds.Right, Min(Bounds.Bottom, Y + DashLength));
                FillAlpha(CellRect, Color);
                Inc(Y, DashLength + GapLength);
              end;
            finally
              DeleteObject(VerticalRegion);
            end;
          finally
            DeleteObject(HorizontalRegion);
          end;
        finally
          DeleteObject(InnerRegion);
        end;
      finally
        DeleteObject(OuterRegion);
      end;
    finally
      RestoreDC(Canvas.Handle, SavedDc);
    end;
  end;

  function ScaledAlphaColor(const Color: Cardinal;
    const Numerator, Denominator: Integer): Cardinal;
  var
    Alpha: Cardinal;
  begin
    Alpha := ((Color shr 24) * Cardinal(Max(0, Numerator)) +
      Cardinal(Denominator div 2)) div Cardinal(Max(1, Denominator));
    Result := (Color and $00FFFFFF) or (Alpha shl 24);
  end;

begin
  if (FrameRect.Width <= 0) or (FrameRect.Height <= 0) then
    Exit;
  ColorBitmap := Vcl.Graphics.TBitmap.Create;
  try
    ColorBitmap.PixelFormat := pf32bit;
    ColorBitmap.SetSize(1, 1);
    InnerPanelRect := FrameRect;
    InflateRect(InnerPanelRect, -InnerPanelInsetX, -InnerPanelInsetY);
    InnerPanelDrawRadius := Max(0, Min(InnerPanelRadius,
      Min(InnerPanelRect.Width, InnerPanelRect.Height) div 2));
    if ShadowVisible and ((Layering <> 1) or
      (InnerPanelRect.Width <= 0) or (InnerPanelRect.Height <= 0)) then
    begin
      DrawRect := FrameRect;
      InflateRect(DrawRect, ShadowSpread, ShadowSpread);
      OffsetRect(DrawRect, ShadowOffsetX, ShadowOffsetY);
      BlurDistance := Max(0, ShadowBlur);
      if BlurDistance > 0 then
      begin
        BlurStep := Max(1, (BlurDistance + 31) div 32);
        while BlurDistance > 0 do
        begin
          BlurInnerDistance := Max(0, BlurDistance - BlurStep);
          OuterRect := DrawRect;
          InflateRect(OuterRect, BlurDistance, BlurDistance);
          InnerRect := DrawRect;
          InflateRect(InnerRect, BlurInnerDistance, BlurInnerDistance);
          FillAlphaRoundedRing(OuterRect, InnerRect,
            CornerRadius + ShadowSpread + BlurDistance,
            CornerRadius + ShadowSpread + BlurInnerDistance,
            ScaledAlphaColor(ShadowColor,
              Max(1, ShadowBlur - BlurDistance + BlurStep),
              Max(1, ShadowBlur + BlurStep)));
          BlurDistance := BlurInnerDistance;
        end;
      end;
      FillAlphaRounded(DrawRect, CornerRadius + ShadowSpread, ShadowColor);
    end;
    if FillVisible then
      FillAlphaRounded(FrameRect, CornerRadius, FillColor, FillMode,
        GradientStrength);
    if Layering = 1 then
    begin
      if (InnerPanelRect.Width > 0) and (InnerPanelRect.Height > 0) then
      begin
        if ShadowVisible then
        begin
          DrawRect := InnerPanelRect;
          InflateRect(DrawRect, ShadowSpread, ShadowSpread);
          OffsetRect(DrawRect, ShadowOffsetX, ShadowOffsetY);
          BlurDistance := Max(0, ShadowBlur);
          if BlurDistance > 0 then
          begin
            BlurStep := Max(1, (BlurDistance + 31) div 32);
            while BlurDistance > 0 do
            begin
              BlurInnerDistance := Max(0, BlurDistance - BlurStep);
              OuterRect := DrawRect;
              InflateRect(OuterRect, BlurDistance, BlurDistance);
              InnerRect := DrawRect;
              InflateRect(InnerRect, BlurInnerDistance, BlurInnerDistance);
              FillAlphaInnerPanelRing(OuterRect, InnerRect,
                InnerPanelDrawRadius + ShadowSpread + BlurDistance,
                InnerPanelDrawRadius + ShadowSpread + BlurInnerDistance,
                ScaledAlphaColor(ShadowColor,
                  Max(1, ShadowBlur - BlurDistance + BlurStep),
                  Max(1, ShadowBlur + BlurStep)));
              BlurDistance := BlurInnerDistance;
            end;
          end;
          FillAlphaInnerPanel(DrawRect,
            InnerPanelDrawRadius + ShadowSpread, ShadowColor);
        end;
        FillAlphaInnerPanel(InnerPanelRect, InnerPanelDrawRadius,
          InnerPanelColor, FillMode, GradientStrength);
      end;
    end;
    if OutlineVisible then
    begin
      DrawOutlineWidth := Min(Max(0, OutlineWidth),
        Min(FrameRect.Width, FrameRect.Height) div 2);
      if DrawOutlineWidth <= 0 then
        Exit;
      if OutlineStyle = 3 then
      begin
        InnerRect := FrameRect;
        InflateRect(InnerRect, -DrawOutlineWidth, -DrawOutlineWidth);
        FillAlphaRoundedDottedRing(FrameRect, InnerRect, CornerRadius,
          Max(0, CornerRadius - DrawOutlineWidth),
          Max(1, DottedDashLength), Max(1, DottedGapLength), OutlineColor);
      end
      else if OutlineStyle = 2 then
      begin
        for GlowDistance := DrawOutlineWidth downto 1 do
        begin
          OuterRect := FrameRect;
          InflateRect(OuterRect, GlowDistance, GlowDistance);
          InnerRect := FrameRect;
          InflateRect(InnerRect, GlowDistance - 1, GlowDistance - 1);
          FillAlphaRoundedRing(OuterRect, InnerRect,
            CornerRadius + GlowDistance,
            CornerRadius + GlowDistance - 1,
            ScaledAlphaColor(OutlineColor,
              DrawOutlineWidth - GlowDistance + 1,
              DrawOutlineWidth + 1));
        end;
        DrawLineWidth := Max(1, DrawOutlineWidth div 3);
        InnerRect := FrameRect;
        InflateRect(InnerRect, -DrawLineWidth, -DrawLineWidth);
        FillAlphaRoundedRing(FrameRect, InnerRect, CornerRadius,
          Max(0, CornerRadius - DrawLineWidth), InnerOutlineColor);
      end
      else if (OutlineStyle = 1) and (DrawOutlineWidth >= 3) then
      begin
        DrawLineWidth := Max(1, DrawOutlineWidth div 3);
        InnerRect := FrameRect;
        InflateRect(InnerRect, -DrawLineWidth, -DrawLineWidth);
        FillAlphaRoundedRing(FrameRect, InnerRect, CornerRadius,
          Max(0, CornerRadius - DrawLineWidth), OutlineColor);
        OuterRect := FrameRect;
        InflateRect(OuterRect, -(DrawOutlineWidth - DrawLineWidth),
          -(DrawOutlineWidth - DrawLineWidth));
        InnerRect := FrameRect;
        InflateRect(InnerRect, -DrawOutlineWidth, -DrawOutlineWidth);
        FillAlphaRoundedRing(OuterRect, InnerRect,
          Max(0, CornerRadius - DrawOutlineWidth + DrawLineWidth),
          Max(0, CornerRadius - DrawOutlineWidth), InnerOutlineColor);
      end
      else
      begin
        InnerRect := FrameRect;
        InflateRect(InnerRect, -DrawOutlineWidth, -DrawOutlineWidth);
        FillAlphaRoundedRing(FrameRect, InnerRect, CornerRadius,
          Max(0, CornerRadius - DrawOutlineWidth), OutlineColor);
      end;
    end;
  finally
    ColorBitmap.Free;
  end;
end;

end.
