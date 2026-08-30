unit PluginFilterSerifDrawTextPreviewDrag;

// 文字プレビューのドラッグ量と中央・行位置への吸着を計算する。

interface

uses
  System.Types,
  PluginFilterSerifDrawTextPreviewLayout;

type
  TSerifDrawTextDragStart = record
    // ドラッグ開始時のマウス位置。プレビュークライアント座標で保持する。
    Mouse: TPoint;
    // 文字の縁・影の装飾量は文字サイズ比（%）、配置と文字間隔はpx。
    FontSize: Double;
    LetterSpacing: Double;
    LineSpacing: Double;
    OutlineBlur: Double;
    OutlineWidth: Double;
    PositionX: Double;
    PositionY: Double;
    ShadowBlur: Double;
    ShadowOffsetX: Double;
    ShadowOffsetY: Double;
    ShadowSpread: Double;
  end;

  TSerifDrawTextDragResult = record
    // 文字の縁・影の装飾量は文字サイズ比（%）、配置と文字間隔はpx。
    FontSize: Double;
    LetterSpacing: Double;
    LineSpacing: Double;
    OutlineBlur: Double;
    OutlineWidth: Double;
    PositionX: Double;
    PositionY: Double;
    ShadowBlur: Double;
    ShadowOffsetX: Double;
    ShadowOffsetY: Double;
    ShadowSpread: Double;
    // 中央または行位置への吸着状態。SnapYValueは吸着先の映像Y座標。
    SnapXActive: Boolean;
    SnapYActive: Boolean;
    SnapYValue: Double;
  end;

// 開始値と現在のマウス位置から対象値を返す。縁系は北東、影効果系は南東を増加方向とする。
function SerifDrawCalculateTextDrag(const AMode: TSerifPreviewDragMode;
  const AStart: TSerifDrawTextDragStart; const AMouse: TPoint;
  const AScale: Double; const AEnablePositionSnap, ASnapXActive,
  ASnapYActive: Boolean;
  const ASnapYValue: Double): TSerifDrawTextDragResult;

implementation

uses
  System.Math;

function SerifDrawCalculateTextDrag(const AMode: TSerifPreviewDragMode;
  const AStart: TSerifDrawTextDragStart; const AMouse: TPoint;
  const AScale: Double; const AEnablePositionSnap, ASnapXActive,
  ASnapYActive: Boolean;
  const ASnapYValue: Double): TSerifDrawTextDragResult;
var
  CaptureTolerance: Double;
  ReleaseTolerance: Double;
  RoundedY: Double;
begin
  Result := System.Default(TSerifDrawTextDragResult);
  Result.FontSize := AStart.FontSize;
  Result.LetterSpacing := AStart.LetterSpacing;
  Result.LineSpacing := AStart.LineSpacing;
  Result.OutlineBlur := AStart.OutlineBlur;
  Result.OutlineWidth := AStart.OutlineWidth;
  Result.PositionX := AStart.PositionX;
  Result.PositionY := AStart.PositionY;
  Result.ShadowBlur := AStart.ShadowBlur;
  Result.ShadowOffsetX := AStart.ShadowOffsetX;
  Result.ShadowOffsetY := AStart.ShadowOffsetY;
  Result.ShadowSpread := AStart.ShadowSpread;
  Result.SnapXActive := ASnapXActive;
  Result.SnapYActive := ASnapYActive;
  Result.SnapYValue := ASnapYValue;
  if AScale <= 0 then
    Exit;

  case AMode of
    spdmFontSizeNorthWest:
      Result.FontSize := AStart.FontSize +
        (AStart.Mouse.X - AMouse.X + AStart.Mouse.Y - AMouse.Y) /
        (2 * AScale);
    spdmFontSizeNorthEast:
      Result.FontSize := AStart.FontSize +
        (AMouse.X - AStart.Mouse.X + AStart.Mouse.Y - AMouse.Y) /
        (2 * AScale);
    spdmFontSizeSouthWest:
      Result.FontSize := AStart.FontSize +
        (AStart.Mouse.X - AMouse.X + AMouse.Y - AStart.Mouse.Y) /
        (2 * AScale);
    spdmFontSizeSouthEast:
      Result.FontSize := AStart.FontSize +
        (AMouse.X - AStart.Mouse.X + AMouse.Y - AStart.Mouse.Y) /
        (2 * AScale);
    spdmLetterSpacingWest:
      Result.LetterSpacing := AStart.LetterSpacing +
        (AStart.Mouse.X - AMouse.X) / AScale;
    spdmLetterSpacingEast:
      Result.LetterSpacing := AStart.LetterSpacing +
        (AMouse.X - AStart.Mouse.X) / AScale;
    spdmLineSpacingNorth:
      Result.LineSpacing := AStart.LineSpacing +
        (AStart.Mouse.Y - AMouse.Y) / AScale;
    spdmLineSpacingSouth:
      Result.LineSpacing := AStart.LineSpacing +
        (AMouse.Y - AStart.Mouse.Y) / AScale;
    spdmShadowOffset:
      begin
        Result.ShadowOffsetX := AStart.ShadowOffsetX +
          (AMouse.X - AStart.Mouse.X) / AScale * 100.0 /
          Max(1.0, AStart.FontSize);
        Result.ShadowOffsetY := AStart.ShadowOffsetY +
          (AMouse.Y - AStart.Mouse.Y) / AScale * 100.0 /
          Max(1.0, AStart.FontSize);
      end;
    spdmOutlineWidth:
      // 右上ハンドルは北東へ離すと増え、南西へ近づけると減る。
      Result.OutlineWidth := AStart.OutlineWidth +
        (AMouse.X - AStart.Mouse.X - AMouse.Y + AStart.Mouse.Y) /
        (2 * AScale) * 100.0 / Max(1.0, AStart.FontSize);
    spdmOutlineBlur:
      Result.OutlineBlur := AStart.OutlineBlur +
        (AMouse.X - AStart.Mouse.X - AMouse.Y + AStart.Mouse.Y) /
        (2 * AScale) * 100.0 / Max(1.0, AStart.FontSize);
    spdmShadowBlur:
      // 右下ハンドルは南東へ離すと増え、北西へ近づけると減る。
      Result.ShadowBlur := AStart.ShadowBlur +
        (AMouse.X - AStart.Mouse.X + AMouse.Y - AStart.Mouse.Y) /
        (2 * AScale) * 100.0 / Max(1.0, AStart.FontSize);
    spdmShadowSpread:
      Result.ShadowSpread := AStart.ShadowSpread +
        (AMouse.X - AStart.Mouse.X + AMouse.Y - AStart.Mouse.Y) /
        (2 * AScale) * 100.0 / Max(1.0, AStart.FontSize);
  else
    begin
      Result.PositionX := EnsureRange(AStart.PositionX +
        (AMouse.X - AStart.Mouse.X) / AScale, -20000.0, 20000.0);
      Result.PositionY := EnsureRange(AStart.PositionY +
        (AMouse.Y - AStart.Mouse.Y) / AScale, -20000.0, 20000.0);
      if not AEnablePositionSnap then
        Exit;

      CaptureTolerance := Max(2.0, 6.0 / AScale);
      ReleaseTolerance := CaptureTolerance * 1.5;
      if Result.SnapXActive then
      begin
        if Abs(Result.PositionX) <= ReleaseTolerance then
          Result.PositionX := 0.0
        else
          Result.SnapXActive := False;
      end;
      if not Result.SnapXActive and
        (Abs(Result.PositionX) <= CaptureTolerance) then
      begin
        Result.SnapXActive := True;
        Result.PositionX := 0.0;
      end;

      CaptureTolerance := Min(4.5, Max(2.0, 2.0 / AScale));
      ReleaseTolerance := Min(4.9, CaptureTolerance * 1.5);
      if Result.SnapYActive then
      begin
        if Abs(Result.PositionY - Result.SnapYValue) <= ReleaseTolerance then
          Result.PositionY := Result.SnapYValue
        else
          Result.SnapYActive := False;
      end;
      if not Result.SnapYActive then
      begin
        RoundedY := Round(Result.PositionY / 10.0) * 10.0;
        if Abs(Result.PositionY - RoundedY) <= CaptureTolerance then
        begin
          Result.SnapYActive := True;
          Result.SnapYValue := RoundedY;
          Result.PositionY := RoundedY;
        end;
      end;
    end;
  end;
end;

end.
