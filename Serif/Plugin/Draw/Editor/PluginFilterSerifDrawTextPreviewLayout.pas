unit PluginFilterSerifDrawTextPreviewLayout;

// 文字プレビューの装飾ハンドル配置、重なり回避、ヒットテストを担当する。

interface

uses
  System.Types,
  Vcl.Controls,
  PluginFilterSerifDrawSettings;

type
  // 文字本体または装飾ハンドルのドラッグ対象を識別する。
  TSerifPreviewDragMode = (
    spdmNone,
    spdmPan,
    spdmMove,
    spdmFontSizeNorthWest,
    spdmFontSizeNorthEast,
    spdmFontSizeSouthWest,
    spdmFontSizeSouthEast,
    spdmLetterSpacingWest,
    spdmLetterSpacingEast,
    spdmLineSpacingNorth,
    spdmLineSpacingSouth,
    spdmShadowOffset,
    spdmOutlineWidth,
    spdmOutlineBlur,
    spdmShadowBlur,
    spdmShadowSpread
  );

  TSerifDrawTextPreviewLayout = record
    // 文字本体の配置矩形と、影・縁を含む効果全体の矩形。プレビュー座標。
    LayoutRect: TRect;
    EffectRect: TRect;
    // 各装飾ハンドルの表示・ヒットテスト矩形。空矩形は非表示を表す。
    OutlineBlurRect: TRect;
    OutlineWidthRect: TRect;
    ShadowBlurRect: TRect;
    ShadowOffsetRect: TRect;
    ShadowSpreadRect: TRect;
  end;

// プレビューから、互いに重ならない固定ハンドル矩形を計算する。
// 操作中にハンドルが逃げないよう、AStyleの効果値は配置に使用しない。
function SerifDrawTextPreviewLayout(const AClientRect, ALayoutRect,
  AEffectRect: TRect; const ADpi: Integer; const AScale: Double;
  const AStyle: TSerifDrawLayerStyle): TSerifDrawTextPreviewLayout;
// 計算済みレイアウト上の点に対応するドラッグ操作を返す。
function SerifDrawHitTestTextPreview(const APoint: TPoint;
  const ALayout: TSerifDrawTextPreviewLayout;
  const ADpi: Integer): TSerifPreviewDragMode;
// ドラッグ操作に対応するVCLカーソルを返す。縁系はNESW、影効果系はNWSE、影位置は全方向。
function SerifDrawTextPreviewCursor(
  const AMode: TSerifPreviewDragMode): TCursor;

implementation

uses
  System.Math,
  Winapi.Windows;

const
  PREVIEW_HANDLE_SIZE = 7;

function ConstrainHandleRect(const ARect, ALayoutRect, AClientRect: TRect;
  const APreferLeft, APreferBelow: Boolean; const AGap,
  ADpi: Integer): TRect;
var
  Distance: Integer;
  Margin: Integer;
  WorkRect: TRect;
begin
  Result := ARect;
  Margin := Max(2, MulDiv(4, ADpi, 96));
  WorkRect := AClientRect;
  InflateRect(WorkRect, -Margin, -Margin);

  if APreferBelow and (Result.Bottom > WorkRect.Bottom) then
  begin
    Distance := Result.Height + AGap * 2;
    OffsetRect(Result, 0, ALayoutRect.Top - Distance - Result.Bottom);
  end
  else if not APreferBelow and (Result.Top < WorkRect.Top) then
  begin
    Distance := Result.Height + AGap * 2;
    OffsetRect(Result, 0, ALayoutRect.Bottom + Distance - Result.Top);
  end;

  if APreferLeft and (Result.Left < WorkRect.Left) then
  begin
    Distance := Max(AGap, ALayoutRect.Left - Result.Right);
    OffsetRect(Result, ALayoutRect.Right + Distance - Result.Left, 0);
  end
  else if not APreferLeft and (Result.Right > WorkRect.Right) then
  begin
    Distance := Max(AGap, Result.Left - ALayoutRect.Right);
    OffsetRect(Result, ALayoutRect.Left - Distance - Result.Right, 0);
  end;

  if Result.Left < WorkRect.Left then
    OffsetRect(Result, WorkRect.Left - Result.Left, 0);
  if Result.Right > WorkRect.Right then
    OffsetRect(Result, WorkRect.Right - Result.Right, 0);
  if Result.Top < WorkRect.Top then
    OffsetRect(Result, 0, WorkRect.Top - Result.Top);
  if Result.Bottom > WorkRect.Bottom then
    OffsetRect(Result, 0, WorkRect.Bottom - Result.Bottom);
end;

function AvoidHandleOverlap(const ARect, ALayoutRect,
  AClientRect: TRect; const AOtherRects: array of TRect;
  const ADpi: Integer): TRect;
var
  BestScore: Integer;
  Candidate: TRect;
  DeltaX: Integer;
  DeltaY: Integer;
  Padding: Integer;
  Score: Integer;
  StepX: Integer;
  StepY: Integer;
  WorkRect: TRect;

  function IsAvailable(const ATestRect: TRect): Boolean;
  var
    TestIndex: Integer;
    TestObstacle: TRect;
  begin
    Result := (ATestRect.Left >= WorkRect.Left) and
      (ATestRect.Top >= WorkRect.Top) and
      (ATestRect.Right <= WorkRect.Right) and
      (ATestRect.Bottom <= WorkRect.Bottom);
    if not Result then
      Exit;
    TestObstacle := ALayoutRect;
    InflateRect(TestObstacle, Padding, Padding);
    if ATestRect.IntersectsWith(TestObstacle) then
      Exit(False);
    for TestIndex := 0 to High(AOtherRects) do
    begin
      TestObstacle := AOtherRects[TestIndex];
      if (TestObstacle.Width <= 0) or (TestObstacle.Height <= 0) then
        Continue;
      InflateRect(TestObstacle, Padding, Padding);
      if ATestRect.IntersectsWith(TestObstacle) then
        Exit(False);
    end;
  end;

begin
  Result := ARect;
  Padding := Max(2, MulDiv(4, ADpi, 96));
  WorkRect := AClientRect;
  InflateRect(WorkRect, -Padding, -Padding);
  if IsAvailable(Result) then
    Exit;

  StepX := Max(1, ARect.Width + Padding);
  StepY := Max(1, ARect.Height + Padding);
  BestScore := MaxInt;
  for DeltaY := -8 to 8 do
    for DeltaX := -8 to 8 do
    begin
      if (DeltaX = 0) and (DeltaY = 0) then
        Continue;
      Candidate := ARect;
      OffsetRect(Candidate, DeltaX * StepX, DeltaY * StepY);
      if not IsAvailable(Candidate) then
        Continue;
      // 横方向を優先し、元の位置から最も近い空き枠を選ぶ。
      Score := Abs(DeltaX) + Abs(DeltaY) * 16;
      if Score < BestScore then
      begin
        BestScore := Score;
        Result := Candidate;
      end;
    end;
end;

function HandleRect(const ACenterX, ACenterY, AExtent: Integer): TRect;
begin
  Result := Rect(ACenterX - AExtent div 2, ACenterY - AExtent div 2,
    ACenterX - AExtent div 2 + AExtent,
    ACenterY - AExtent div 2 + AExtent);
end;

function SerifDrawTextPreviewLayout(const AClientRect, ALayoutRect,
  AEffectRect: TRect; const ADpi: Integer; const AScale: Double;
  const AStyle: TSerifDrawLayerStyle): TSerifDrawTextPreviewLayout;
var
  CenterX: Integer;
  CenterY: Integer;
  Extent: Integer;
  Gap: Integer;
begin
  Result := System.Default(TSerifDrawTextPreviewLayout);
  Result.LayoutRect := ALayoutRect;
  Result.EffectRect := AEffectRect;
  if (ALayoutRect.Width <= 0) or (ALayoutRect.Height <= 0) or
    (AScale <= 0) then
    Exit;

  Extent := Max(24, MulDiv(28, ADpi, 96));
  Gap := Max(10, MulDiv(12, ADpi, 96));
  // 縁取りを親とし、縁ぼかしをその右隣へまとめる。
  CenterX := ALayoutRect.Right + Gap + Extent div 2;
  CenterY := ALayoutRect.Top - Gap - Extent div 2;
  Result.OutlineWidthRect := HandleRect(CenterX, CenterY, Extent);
  Result.OutlineWidthRect := ConstrainHandleRect(Result.OutlineWidthRect,
    ALayoutRect, AClientRect, False, False, Gap, ADpi);

  CenterX := Result.OutlineWidthRect.Right + Gap + Extent div 2;
  CenterY := (Result.OutlineWidthRect.Top +
    Result.OutlineWidthRect.Bottom) div 2;
  Result.OutlineBlurRect := HandleRect(CenterX, CenterY, Extent);
  Result.OutlineBlurRect := ConstrainHandleRect(Result.OutlineBlurRect,
    ALayoutRect, AClientRect, False, False, Gap, ADpi);
  Result.OutlineBlurRect := AvoidHandleOverlap(Result.OutlineBlurRect,
    ALayoutRect, AClientRect, [Result.OutlineWidthRect], ADpi);

  // 影位置を親とし、ぼかしを下、広がりを右へまとめる。
  // 操作中にアイコンが逃げないよう、影位置値自体は配置に使わない。
  CenterX := ALayoutRect.Right + Gap + Extent div 2;
  CenterY := ALayoutRect.Bottom + Gap + Extent div 2;
  Result.ShadowOffsetRect := HandleRect(CenterX, CenterY, Extent);
  Result.ShadowOffsetRect := ConstrainHandleRect(Result.ShadowOffsetRect,
    ALayoutRect, AClientRect, False, True, Gap, ADpi);
  Result.ShadowOffsetRect := AvoidHandleOverlap(Result.ShadowOffsetRect,
    ALayoutRect, AClientRect,
    [Result.OutlineWidthRect, Result.OutlineBlurRect], ADpi);

  CenterX := (Result.ShadowOffsetRect.Left +
    Result.ShadowOffsetRect.Right) div 2;
  CenterY := Result.ShadowOffsetRect.Bottom + Gap + Extent div 2;
  Result.ShadowBlurRect := HandleRect(CenterX, CenterY, Extent);
  Result.ShadowBlurRect := ConstrainHandleRect(Result.ShadowBlurRect,
    ALayoutRect, AClientRect, False, True, Gap, ADpi);
  Result.ShadowBlurRect := AvoidHandleOverlap(Result.ShadowBlurRect,
    ALayoutRect, AClientRect, [Result.OutlineWidthRect,
    Result.OutlineBlurRect, Result.ShadowOffsetRect], ADpi);

  CenterX := Result.ShadowOffsetRect.Right + Gap + Extent div 2;
  CenterY := (Result.ShadowOffsetRect.Top +
    Result.ShadowOffsetRect.Bottom) div 2;
  Result.ShadowSpreadRect := HandleRect(CenterX, CenterY, Extent);
  Result.ShadowSpreadRect := ConstrainHandleRect(Result.ShadowSpreadRect,
    ALayoutRect, AClientRect, False, True, Gap, ADpi);
  Result.ShadowSpreadRect := AvoidHandleOverlap(Result.ShadowSpreadRect,
    ALayoutRect, AClientRect, [Result.OutlineWidthRect,
    Result.OutlineBlurRect, Result.ShadowBlurRect,
    Result.ShadowOffsetRect], ADpi);
end;

function SerifDrawHitTestTextPreview(const APoint: TPoint;
  const ALayout: TSerifDrawTextPreviewLayout;
  const ADpi: Integer): TSerifPreviewDragMode;
var
  HandleSize: Integer;

  function NearPoint(const AX, AY: Integer): Boolean;
  begin
    Result := (Abs(APoint.X - AX) <= HandleSize) and
      (Abs(APoint.Y - AY) <= HandleSize);
  end;

begin
  Result := spdmNone;
  if (ALayout.LayoutRect.Width <= 0) or
    (ALayout.LayoutRect.Height <= 0) then
    Exit;
  if PtInRect(ALayout.OutlineBlurRect, APoint) then
    Exit(spdmOutlineBlur);
  if PtInRect(ALayout.OutlineWidthRect, APoint) then
    Exit(spdmOutlineWidth);
  if PtInRect(ALayout.ShadowBlurRect, APoint) then
    Exit(spdmShadowBlur);
  if PtInRect(ALayout.ShadowSpreadRect, APoint) then
    Exit(spdmShadowSpread);
  if PtInRect(ALayout.ShadowOffsetRect, APoint) then
    Exit(spdmShadowOffset);
  HandleSize := Max(5, MulDiv(PREVIEW_HANDLE_SIZE, ADpi, 96));
  if NearPoint(ALayout.LayoutRect.Left, ALayout.LayoutRect.Top) then
    Exit(spdmFontSizeNorthWest);
  if NearPoint(ALayout.LayoutRect.Right, ALayout.LayoutRect.Top) then
    Exit(spdmFontSizeNorthEast);
  if NearPoint(ALayout.LayoutRect.Left, ALayout.LayoutRect.Bottom) then
    Exit(spdmFontSizeSouthWest);
  if NearPoint(ALayout.LayoutRect.Right, ALayout.LayoutRect.Bottom) then
    Exit(spdmFontSizeSouthEast);
  if (Abs(APoint.X - ALayout.LayoutRect.Left) <= HandleSize) and
    (APoint.Y >= ALayout.LayoutRect.Top) and
    (APoint.Y <= ALayout.LayoutRect.Bottom) then
    Exit(spdmLetterSpacingWest);
  if (Abs(APoint.X - ALayout.LayoutRect.Right) <= HandleSize) and
    (APoint.Y >= ALayout.LayoutRect.Top) and
    (APoint.Y <= ALayout.LayoutRect.Bottom) then
    Exit(spdmLetterSpacingEast);
  if (Abs(APoint.Y - ALayout.LayoutRect.Top) <= HandleSize) and
    (APoint.X >= ALayout.LayoutRect.Left) and
    (APoint.X <= ALayout.LayoutRect.Right) then
    Exit(spdmLineSpacingNorth);
  if (Abs(APoint.Y - ALayout.LayoutRect.Bottom) <= HandleSize) and
    (APoint.X >= ALayout.LayoutRect.Left) and
    (APoint.X <= ALayout.LayoutRect.Right) then
    Exit(spdmLineSpacingSouth);
  if PtInRect(ALayout.EffectRect, APoint) or
    PtInRect(ALayout.LayoutRect, APoint) then
    Result := spdmMove;
end;

function SerifDrawTextPreviewCursor(
  const AMode: TSerifPreviewDragMode): TCursor;
begin
  case AMode of
    spdmMove, spdmPan, spdmShadowOffset:
      Result := crSizeAll;
    spdmFontSizeNorthWest, spdmFontSizeSouthEast, spdmShadowSpread,
    spdmShadowBlur:
      Result := crSizeNWSE;
    spdmFontSizeNorthEast, spdmFontSizeSouthWest, spdmOutlineWidth,
    spdmOutlineBlur:
      Result := crSizeNESW;
    spdmLetterSpacingWest, spdmLetterSpacingEast:
      Result := crSizeWE;
    spdmLineSpacingNorth, spdmLineSpacingSouth:
      Result := crSizeNS;
  else
    Result := crDefault;
  end;
end;

end.
