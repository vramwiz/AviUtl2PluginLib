unit MmdModelSettingEditorIcons;

// モデル設定フォームのページアイコンをDPI対応で生成する。

interface

uses
  Vcl.Controls,
  Vcl.ImgList;

// ポーズ、表情、目パチ、口パクの順でカラー線画アイコンを追加する。
// IncludeAutomationIcons=Falseならモデルフィルター用の先頭2個だけを生成する。
procedure BuildMmdModelSettingIcons(Images: TImageList; Size: Integer;
  IncludeAutomationIcons: Boolean);

implementation

uses
  Winapi.Windows,
  System.Math,
  System.Types,
  System.UITypes,
  Vcl.Graphics,
  MmdPoseEditorTheme;

const
  IconMask = TColor($00FF00FF);
  PoseColor = TColor($0078CD4C);
  ExpressionColor = TColor($0046BEF0);
  EyeColor = TColor($00FFAA50);
  MouthColor = TColor($00AA69FF);

procedure DrawIcon(Canvas: TCanvas; Index, Size: Integer; Color: TColor);
var
  S: Integer;

  function P(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, Size, 24);
  end;

begin
  S := Max(1, P(2));
  Canvas.Pen.Color := Color;
  Canvas.Pen.Width := S;
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsClear;
  case Index of
    0:
      begin
        Canvas.Ellipse(P(9), P(2), P(15), P(8));
        Canvas.MoveTo(P(12), P(8)); Canvas.LineTo(P(12), P(16));
        Canvas.MoveTo(P(12), P(10)); Canvas.LineTo(P(4), P(14));
        Canvas.MoveTo(P(12), P(10)); Canvas.LineTo(P(20), P(14));
        Canvas.MoveTo(P(12), P(16)); Canvas.LineTo(P(7), P(22));
        Canvas.MoveTo(P(12), P(16)); Canvas.LineTo(P(17), P(22));
      end;
    1:
      begin
        Canvas.Ellipse(P(3), P(3), P(21), P(21));
        Canvas.Ellipse(P(7), P(8), P(9), P(10));
        Canvas.Ellipse(P(15), P(8), P(17), P(10));
        Canvas.Arc(P(7), P(9), P(17), P(18), P(7), P(13), P(17), P(13));
      end;
    2:
      begin
        Canvas.Arc(P(2), P(6), P(22), P(19), P(2), P(12), P(22), P(12));
        Canvas.Arc(P(2), P(6), P(22), P(19), P(22), P(12), P(2), P(12));
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := Color;
        Canvas.Ellipse(P(8), P(8), P(16), P(17));
        Canvas.Brush.Color := MmdEditorPanel;
        Canvas.Ellipse(P(11), P(10), P(14), P(15));
        Canvas.Brush.Style := bsClear;
        Canvas.MoveTo(P(6), P(8)); Canvas.LineTo(P(4), P(4));
        Canvas.MoveTo(P(12), P(7)); Canvas.LineTo(P(12), P(2));
        Canvas.MoveTo(P(18), P(8)); Canvas.LineTo(P(20), P(4));
      end;
    3:
      begin
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := Color;
        Canvas.Polygon([Point(P(2), P(13)), Point(P(7), P(10)),
          Point(P(10), P(8)), Point(P(12), P(11)), Point(P(14), P(8)),
          Point(P(17), P(10)), Point(P(22), P(13)), Point(P(18), P(17)),
          Point(P(14), P(19)), Point(P(10), P(19)), Point(P(6), P(17))]);
        Canvas.Pen.Color := MmdEditorPanel;
        Canvas.Pen.Width := Max(1, P(1));
        Canvas.Polyline([Point(P(3), P(13)), Point(P(8), P(14)),
          Point(P(12), P(13)), Point(P(16), P(14)), Point(P(21), P(13))]);
        Canvas.Brush.Style := bsClear;
      end;
  end;
end;

procedure BuildMmdModelSettingIcons(Images: TImageList; Size: Integer;
  IncludeAutomationIcons: Boolean);
const
  Colors: array[0..3] of TColor = (PoseColor, ExpressionColor, EyeColor,
    MouthColor);
var
  Bitmap: TBitmap;
  IconCount: Integer;
  Index: Integer;
begin
  Images.Clear;
  Images.Width := Size;
  Images.Height := Size;
  Images.Masked := True;
  Images.BkColor := clNone;
  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf24bit;
    Bitmap.SetSize(Size, Size);
    if IncludeAutomationIcons then
      IconCount := 4
    else
      IconCount := 2;
    for Index := 0 to IconCount - 1 do
    begin
      Bitmap.Canvas.Brush.Style := bsSolid;
      Bitmap.Canvas.Brush.Color := IconMask;
      Bitmap.Canvas.FillRect(Rect(0, 0, Size, Size));
      DrawIcon(Bitmap.Canvas, Index, Size, Colors[Index]);
      Images.AddMasked(Bitmap, IconMask);
    end;
  finally
    Bitmap.Free;
  end;
end;

end.
