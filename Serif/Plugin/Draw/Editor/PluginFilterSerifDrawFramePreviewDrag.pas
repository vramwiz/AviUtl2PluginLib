unit PluginFilterSerifDrawFramePreviewDrag;

// 枠プレビューのドラッグ操作から編集値と中央吸着状態を計算する。

interface

uses
  System.Types,
  PluginFilterSerifDrawFramePreview,
  PluginFilterSerifDrawSettings;

type
  TSerifDrawFrameDragResult = record
    // ドラッグを反映した未保存の枠スタイル。
    Style: TSerifDrawFrameStyle;
    // 中央のX/Y吸着ガイドを表示するかを呼び出し側へ返す。
    SnapXActive: Boolean;
    SnapYActive: Boolean;
  end;

// ドラッグ開始値と現在値を基に、操作対象へ反映する枠スタイルを返す。
function SerifDrawCalculateFrameDrag(const AHit: TSerifDrawFrameHit;
  const AStart, ACurrent: TSerifDrawFrameStyle;
  const AStartMouse, AMouse: TPoint; const AScale: Double;
  const ADpi: Integer; const AFrameRect: TRect;
  const ASnapXActive, ASnapYActive: Boolean): TSerifDrawFrameDragResult;

implementation

uses
  System.Math;

function SerifDrawCalculateFrameDrag(const AHit: TSerifDrawFrameHit;
  const AStart, ACurrent: TSerifDrawFrameStyle;
  const AStartMouse, AMouse: TPoint; const AScale: Double;
  const ADpi: Integer; const AFrameRect: TRect;
  const ASnapXActive, ASnapYActive: Boolean): TSerifDrawFrameDragResult;
var
  BalloonPointX: Integer;
  BalloonPointY: Integer;
  CaptureTolerance: Double;
  NewFrameHeight: Integer;
  NewFrameWidth: Integer;
  RawPositionX: Double;
  RawPositionY: Double;
  ReleaseTolerance: Double;
begin
  Result := System.Default(TSerifDrawFrameDragResult);
  Result.Style := ACurrent;
  Result.SnapXActive := ASnapXActive;
  Result.SnapYActive := ASnapYActive;
  if AScale <= 0 then
    Exit;

  case AHit of
    sdfhInnerPanelInsetX:
      begin
        Result.Style.InnerPanelInsetX := EnsureRange(
          Round(AStart.InnerPanelInsetX +
            (AMouse.X - AStartMouse.X) / AScale), 0,
          Max(0, ACurrent.Width div 2 - 1));
        Result.Style.InnerPanelRadius := Min(ACurrent.InnerPanelRadius,
          Min(ACurrent.Width - 2 * Result.Style.InnerPanelInsetX,
            ACurrent.Height - 2 * ACurrent.InnerPanelInsetY) div 2);
        Exit;
      end;
    sdfhInnerPanelInsetY:
      begin
        Result.Style.InnerPanelInsetY := EnsureRange(
          Round(AStart.InnerPanelInsetY +
            (AMouse.Y - AStartMouse.Y) / AScale), 0,
          Max(0, ACurrent.Height div 2 - 1));
        Result.Style.InnerPanelRadius := Min(ACurrent.InnerPanelRadius,
          Min(ACurrent.Width - 2 * ACurrent.InnerPanelInsetX,
            ACurrent.Height - 2 * Result.Style.InnerPanelInsetY) div 2);
        Exit;
      end;
    sdfhInnerPanelRadius:
      begin
        Result.Style.InnerPanelRadius := EnsureRange(
          Round(AStart.InnerPanelRadius +
            (AMouse.X - AStartMouse.X) / AScale), 0,
          Min(500, Min(ACurrent.Width - 2 * ACurrent.InnerPanelInsetX,
            ACurrent.Height - 2 * ACurrent.InnerPanelInsetY) div 2));
        Exit;
      end;
    sdfhDottedDashLength:
      begin
        Result.Style.DottedDashLength := EnsureRange(
          Round(AStart.DottedDashLength +
            (AMouse.X - AStartMouse.X) / AScale), 1, 20000);
        Exit;
      end;
    sdfhDottedGapLength:
      begin
        Result.Style.DottedGapLength := EnsureRange(
          Round(AStart.DottedGapLength +
            (AMouse.X - AStartMouse.X) / AScale), 1, 20000);
        Exit;
      end;
    sdfhBalloonTip:
      begin
        if Max(AFrameRect.Top - AMouse.Y,
          AMouse.Y - AFrameRect.Bottom) >
          Max(AFrameRect.Left - AMouse.X,
          AMouse.X - AFrameRect.Right) then
        begin
          if AMouse.Y < (AFrameRect.Top + AFrameRect.Bottom) div 2 then
            Result.Style.BalloonTailDirection := 1
          else
            Result.Style.BalloonTailDirection := 0;
        end
        else if AMouse.X < (AFrameRect.Left + AFrameRect.Right) div 2 then
          Result.Style.BalloonTailDirection := 2
        else
          Result.Style.BalloonTailDirection := 3;
        BalloonPointX := AMouse.X;
        BalloonPointY := AMouse.Y;
        case Result.Style.BalloonTailDirection of
          1: Inc(BalloonPointY, SerifDrawFrameBalloonHandleGap(ADpi));
          2: Inc(BalloonPointX, SerifDrawFrameBalloonHandleGap(ADpi));
          3: Dec(BalloonPointX, SerifDrawFrameBalloonHandleGap(ADpi));
        else
          Dec(BalloonPointY, SerifDrawFrameBalloonHandleGap(ADpi));
        end;
        if Result.Style.BalloonTailDirection in [2, 3] then
        begin
          Result.Style.BalloonTailPosition := EnsureRange(Round(
            (BalloonPointY - (AFrameRect.Top + AFrameRect.Bottom) div 2) /
            AScale), -ACurrent.Height div 2, ACurrent.Height div 2);
          if Result.Style.BalloonTailDirection = 2 then
            Result.Style.BalloonTailLength := EnsureRange(Round(
              (AFrameRect.Left - BalloonPointX) / AScale), 1, 20000)
          else
            Result.Style.BalloonTailLength := EnsureRange(Round(
              (BalloonPointX - AFrameRect.Right) / AScale), 1, 20000);
        end
        else
        begin
          Result.Style.BalloonTailPosition := EnsureRange(Round(
            (BalloonPointX - (AFrameRect.Left + AFrameRect.Right) div 2) /
            AScale), -ACurrent.Width div 2, ACurrent.Width div 2);
          if Result.Style.BalloonTailDirection = 1 then
            Result.Style.BalloonTailLength := EnsureRange(Round(
              (AFrameRect.Top - BalloonPointY) / AScale), 1, 20000)
          else
            Result.Style.BalloonTailLength := EnsureRange(Round(
              (BalloonPointY - AFrameRect.Bottom) / AScale), 1, 20000);
        end;
        Exit;
      end;
    sdfhBalloonWidth:
      begin
        Result.Style.BalloonTailWidth := EnsureRange(
          Round(AStart.BalloonTailWidth + 2 * IfThen(
            ACurrent.BalloonTailDirection in [2, 3],
            AMouse.Y - AStartMouse.Y, AMouse.X - AStartMouse.X) / AScale),
          1, IfThen(ACurrent.BalloonTailDirection in [2, 3],
            ACurrent.Height, ACurrent.Width));
        Exit;
      end;
    sdfhTabOffset:
      begin
        Result.Style.TabOffset := EnsureRange(Round(AStart.TabOffset +
          (AMouse.X - AStartMouse.X) / AScale), 0,
          Max(0, ACurrent.Width - 1));
        Result.Style.TabWidth := Min(ACurrent.TabWidth,
          ACurrent.Width - Result.Style.TabOffset);
        Exit;
      end;
    sdfhTabWidth:
      begin
        Result.Style.TabWidth := EnsureRange(Round(AStart.TabWidth +
          (AMouse.X - AStartMouse.X) / AScale), 1,
          Max(1, ACurrent.Width - ACurrent.TabOffset));
        Exit;
      end;
    sdfhTabHeight:
      begin
        Result.Style.TabHeight := EnsureRange(Round(AStart.TabHeight +
          (AMouse.Y - AStartMouse.Y) / AScale), 1,
          Max(1, ACurrent.Height - 1));
        Exit;
      end;
    sdfhCornerRadius:
      begin
        Result.Style.CornerRadius := EnsureRange(Round(AStart.CornerRadius +
          (AMouse.X - AStartMouse.X) / AScale), 0,
          Min(500, Min(ACurrent.Width, ACurrent.Height) div 2));
        Exit;
      end;
    sdfhShadowBlur:
      begin
        Result.Style.ShadowBlur := EnsureRange(AStart.ShadowBlur -
          (AMouse.X - AStartMouse.X) / AScale, 0.0, 500.0);
        Exit;
      end;
    sdfhShadowSpread:
      begin
        Result.Style.ShadowSpread := EnsureRange(AStart.ShadowSpread +
          (AMouse.X - AStartMouse.X) / AScale, 0.0, 500.0);
        Exit;
      end;
    sdfhShadowOffset:
      begin
        Result.Style.ShadowOffsetX := EnsureRange(AStart.ShadowOffsetX +
          (AMouse.X - AStartMouse.X) / AScale, -2000.0, 2000.0);
        Result.Style.ShadowOffsetY := EnsureRange(AStart.ShadowOffsetY +
          (AMouse.Y - AStartMouse.Y) / AScale, -2000.0, 2000.0);
        Exit;
      end;
    sdfhOutlineWidth:
      begin
        Result.Style.OutlineWidth := EnsureRange(Round(AStart.OutlineWidth +
          (AMouse.X - AStartMouse.X) / AScale), 0, 500);
        Exit;
      end;
    sdfhMove:
      begin
        RawPositionX := EnsureRange(AStart.PositionX +
          (AMouse.X - AStartMouse.X) / AScale, -20000.0, 20000.0);
        RawPositionY := EnsureRange(AStart.PositionY +
          (AMouse.Y - AStartMouse.Y) / AScale, -20000.0, 20000.0);
        Result.Style.PositionX := RawPositionX;
        Result.Style.PositionY := RawPositionY;
        CaptureTolerance := Max(2.0, 6.0 / AScale);
        ReleaseTolerance := CaptureTolerance * 1.5;
        if Result.SnapXActive then
        begin
          if Abs(RawPositionX) <= ReleaseTolerance then
            Result.Style.PositionX := 0
          else
            Result.SnapXActive := False;
        end;
        if not Result.SnapXActive and
          (Abs(RawPositionX) <= CaptureTolerance) then
        begin
          Result.SnapXActive := True;
          Result.Style.PositionX := 0;
        end;
        if Result.SnapYActive then
        begin
          if Abs(RawPositionY) <= ReleaseTolerance then
            Result.Style.PositionY := 0
          else
            Result.SnapYActive := False;
        end;
        if not Result.SnapYActive and
          (Abs(RawPositionY) <= CaptureTolerance) then
        begin
          Result.SnapYActive := True;
          Result.Style.PositionY := 0;
        end;
        Exit;
      end;
  end;

  SerifDrawResizeCommonFrame(AHit, AStart.Width, AStart.Height,
    AMouse.X - AStartMouse.X, AMouse.Y - AStartMouse.Y, AScale,
    NewFrameWidth, NewFrameHeight);
  Result.Style.Width := NewFrameWidth;
  Result.Style.Height := NewFrameHeight;
  Result.Style.InnerPanelInsetX := Min(ACurrent.InnerPanelInsetX,
    Max(0, NewFrameWidth div 2 - 1));
  Result.Style.InnerPanelInsetY := Min(ACurrent.InnerPanelInsetY,
    Max(0, NewFrameHeight div 2 - 1));
  Result.Style.InnerPanelRadius := Min(ACurrent.InnerPanelRadius,
    Min(NewFrameWidth - 2 * Result.Style.InnerPanelInsetX,
      NewFrameHeight - 2 * Result.Style.InnerPanelInsetY) div 2);
end;

end.
