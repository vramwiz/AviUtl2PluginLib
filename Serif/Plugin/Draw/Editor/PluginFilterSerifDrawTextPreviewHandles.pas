unit PluginFilterSerifDrawTextPreviewHandles;

// 文字プレビューの選択枠と装飾編集ハンドルの描画を担当する。

interface

uses
  System.Types,
  Vcl.Graphics;

type
  // 操作中として強調描画する装飾ハンドルを識別する。
  TSerifDrawTextPreviewActiveHandle = (
    sdthNone,
    sdthOutlineBlur,
    sdthOutlineWidth,
    sdthShadowBlur,
    sdthShadowOffset,
    sdthShadowSpread
  );

  TSerifDrawTextPreviewHandleState = record
    // ActiveHandleだけを選択色で描画する。sdthNoneは強調なし。
    ActiveHandle: TSerifDrawTextPreviewActiveHandle;
    // Dpiはハンドル線幅に使用し、各矩形はプレビュー座標で受け取る。
    Dpi: Integer;
    LayoutRect: TRect;
    OutlineBlurRect: TRect;
    OutlineWidthRect: TRect;
    ShadowBlurRect: TRect;
    ShadowOffsetRect: TRect;
    ShadowSpreadRect: TRect;
  end;

// 呼び出し元が計算した各矩形と選択状態を使い、Canvasへ編集ガイドを描画する。
// A本体は白、効果は水色とし、点線は本文→親装飾→子装飾の関連を示す。
procedure DrawSerifDrawTextPreviewHandles(const Canvas: TCanvas;
  const State: TSerifDrawTextPreviewHandleState);

implementation

uses
  System.Math,
  System.UITypes,
  Winapi.Windows;

const
  HANDLE_GLYPH_TEXT_FLAGS = DT_CENTER or DT_VCENTER or DT_SINGLELINE or
    DT_NOPREFIX;
  HANDLE_BACKGROUND_COLOR = TColor($00303030);
  HANDLE_GLYPH_WHITE = TColor($00E6E6E6);
  // RGB(48, 168, 208)。影・ぼかしを無彩色の文字や枠から見分ける。
  HANDLE_SHADOW_ACCENT = TColor($00D0A830);

procedure DrawSerifDrawTextPreviewHandles(const Canvas: TCanvas;
  const State: TSerifDrawTextPreviewHandleState);
var
  GlyphRect: TRect;
  HandleSize: Integer;
  IconMidX: Integer;
  IconMidY: Integer;

  procedure DrawHandle(const AX, AY: Integer);
  begin
    Canvas.Rectangle(AX - HandleSize, AY - HandleSize,
      AX + HandleSize + 1, AY + HandleSize + 1);
  end;

  procedure BeginDecorationHandleBetween(const Anchor, ConnectorEnd: TPoint;
    const HandleRect: TRect;
    const ActiveHandle: TSerifDrawTextPreviewActiveHandle);
  begin
    Canvas.Pen.Width := 1;
    Canvas.Pen.Style := psDot;
    Canvas.Pen.Color := TColor($00909090);
    Canvas.MoveTo(Anchor.X, Anchor.Y);
    Canvas.LineTo(ConnectorEnd.X, ConnectorEnd.Y);
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := HANDLE_BACKGROUND_COLOR;
    if State.ActiveHandle = ActiveHandle then
      Canvas.Pen.Color := clAqua
    else
      Canvas.Pen.Color := TColor($00D0D0D0);
    Canvas.RoundRect(HandleRect.Left, HandleRect.Top, HandleRect.Right,
      HandleRect.Bottom, 6, 6);
  end;

  procedure BeginDecorationHandle(const Anchor: TPoint;
    const HandleRect: TRect;
    const ActiveHandle: TSerifDrawTextPreviewActiveHandle);
  begin
    BeginDecorationHandleBetween(Anchor,
      Point((HandleRect.Left + HandleRect.Right) div 2,
        (HandleRect.Top + HandleRect.Bottom) div 2),
      HandleRect, ActiveHandle);
  end;

  procedure DrawOffsetGlyph(const HandleRect: TRect);
  begin
    GlyphRect := HandleRect;
    InflateRect(GlyphRect, -3, -3);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -Max(8, HandleRect.Height div 2);
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := HANDLE_SHADOW_ACCENT;
    OffsetRect(GlyphRect, Max(4, HandleRect.Width div 6),
      Max(1, HandleRect.Height div 14));
    DrawText(Canvas.Handle, 'A', 1, GlyphRect, HANDLE_GLYPH_TEXT_FLAGS);
    OffsetRect(GlyphRect, -Max(4, HandleRect.Width div 6),
      -Max(1, HandleRect.Height div 14));
    Canvas.Font.Color := HANDLE_GLYPH_WHITE;
    DrawText(Canvas.Handle, 'A', 1, GlyphRect, HANDLE_GLYPH_TEXT_FLAGS);
    Canvas.Brush.Style := bsSolid;
  end;

  procedure DrawBlurGlyph(const HandleRect: TRect);
  var
    X: Integer;
    Y: Integer;
  begin
    GlyphRect := HandleRect;
    InflateRect(GlyphRect, -3, -3);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -Max(9, HandleRect.Height * 62 div 100);
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := HANDLE_SHADOW_ACCENT;
    // 暗い水色のAを周囲へ重ね、実際のぼかしに近い輪郭を表す。
    for Y := -2 to 2 do
      for X := -2 to 2 do
        if (Abs(X) = 2) or (Abs(Y) = 2) then
        begin
          OffsetRect(GlyphRect, X, Y);
          DrawText(Canvas.Handle, 'A', 1, GlyphRect,
            HANDLE_GLYPH_TEXT_FLAGS);
          OffsetRect(GlyphRect, -X, -Y);
        end;
    Canvas.Font.Color := HANDLE_GLYPH_WHITE;
    DrawText(Canvas.Handle, 'A', 1, GlyphRect, HANDLE_GLYPH_TEXT_FLAGS);
    Canvas.Brush.Style := bsSolid;
  end;

  procedure DrawWhiteOutlineGlyph(const HandleRect: TRect);
  var
    X: Integer;
    Y: Integer;
  begin
    GlyphRect := HandleRect;
    InflateRect(GlyphRect, -3, -3);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -Max(10, HandleRect.Height * 68 div 100);
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := HANDLE_GLYPH_WHITE;
    for Y := -1 to 1 do
      for X := -1 to 1 do
        if (X <> 0) or (Y <> 0) then
        begin
          OffsetRect(GlyphRect, X, Y);
          DrawText(Canvas.Handle, 'A', 1, GlyphRect,
            HANDLE_GLYPH_TEXT_FLAGS);
          OffsetRect(GlyphRect, -X, -Y);
        end;
    // 中央を背景色で抜き、白い輪郭だけのAにする。
    Canvas.Font.Color := HANDLE_BACKGROUND_COLOR;
    DrawText(Canvas.Handle, 'A', 1, GlyphRect, HANDLE_GLYPH_TEXT_FLAGS);
    Canvas.Brush.Style := bsSolid;
  end;

begin
  HandleSize := Max(3, MulDiv(4, State.Dpi, 96));
  Canvas.Pen.Color := clYellow;
  Canvas.Pen.Width := 2;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(State.LayoutRect);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clBlack;
  DrawHandle(State.LayoutRect.Left, State.LayoutRect.Top);
  DrawHandle(State.LayoutRect.Right, State.LayoutRect.Top);
  DrawHandle(State.LayoutRect.Left, State.LayoutRect.Bottom);
  DrawHandle(State.LayoutRect.Right, State.LayoutRect.Bottom);
  DrawHandle((State.LayoutRect.Left + State.LayoutRect.Right) div 2,
    State.LayoutRect.Top);
  DrawHandle((State.LayoutRect.Left + State.LayoutRect.Right) div 2,
    State.LayoutRect.Bottom);
  DrawHandle(State.LayoutRect.Left,
    (State.LayoutRect.Top + State.LayoutRect.Bottom) div 2);
  DrawHandle(State.LayoutRect.Right,
    (State.LayoutRect.Top + State.LayoutRect.Bottom) div 2);

  BeginDecorationHandle(Point(State.LayoutRect.Right, State.LayoutRect.Top),
    State.OutlineWidthRect, sdthOutlineWidth);
  DrawWhiteOutlineGlyph(State.OutlineWidthRect);

  BeginDecorationHandleBetween(Point(State.OutlineWidthRect.Right,
    (State.OutlineWidthRect.Top + State.OutlineWidthRect.Bottom) div 2),
    Point(State.OutlineBlurRect.Left,
      (State.OutlineBlurRect.Top + State.OutlineBlurRect.Bottom) div 2),
    State.OutlineBlurRect, sdthOutlineBlur);
  DrawBlurGlyph(State.OutlineBlurRect);

  BeginDecorationHandle(Point(State.LayoutRect.Right,
    State.LayoutRect.Bottom), State.ShadowOffsetRect, sdthShadowOffset);
  DrawOffsetGlyph(State.ShadowOffsetRect);

  BeginDecorationHandleBetween(Point(
    (State.ShadowOffsetRect.Left + State.ShadowOffsetRect.Right) div 2,
    State.ShadowOffsetRect.Bottom), Point(
      (State.ShadowBlurRect.Left + State.ShadowBlurRect.Right) div 2,
      State.ShadowBlurRect.Top), State.ShadowBlurRect, sdthShadowBlur);
  DrawBlurGlyph(State.ShadowBlurRect);

  BeginDecorationHandleBetween(Point(State.ShadowOffsetRect.Right,
    (State.ShadowOffsetRect.Top + State.ShadowOffsetRect.Bottom) div 2),
    Point(State.ShadowSpreadRect.Left,
      (State.ShadowSpreadRect.Top + State.ShadowSpreadRect.Bottom) div 2),
    State.ShadowSpreadRect, sdthShadowSpread);
  GlyphRect := State.ShadowSpreadRect;
  InflateRect(GlyphRect, -3, -3);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Height := -Max(8, State.ShadowSpreadRect.Height * 48 div 100);
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := HANDLE_GLYPH_WHITE;
  DrawText(Canvas.Handle, 'A', 1, GlyphRect, HANDLE_GLYPH_TEXT_FLAGS);
  IconMidX := (State.ShadowSpreadRect.Left +
    State.ShadowSpreadRect.Right) div 2;
  IconMidY := State.ShadowSpreadRect.Bottom - Max(5,
    State.ShadowSpreadRect.Height div 5);
  Canvas.Pen.Color := HANDLE_SHADOW_ACCENT;
  Canvas.Pen.Width := 1;
  Canvas.MoveTo(IconMidX - 2, IconMidY);
  Canvas.LineTo(IconMidX - 8, IconMidY);
  Canvas.MoveTo(IconMidX + 2, IconMidY);
  Canvas.LineTo(IconMidX + 8, IconMidY);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := HANDLE_SHADOW_ACCENT;
  Canvas.Polygon([Point(IconMidX - 10, IconMidY),
    Point(IconMidX - 7, IconMidY - 2),
    Point(IconMidX - 7, IconMidY + 2)]);
  Canvas.Polygon([Point(IconMidX + 10, IconMidY),
    Point(IconMidX + 7, IconMidY - 2),
    Point(IconMidX + 7, IconMidY + 2)]);
  Canvas.Brush.Style := bsSolid;
end;

end.
