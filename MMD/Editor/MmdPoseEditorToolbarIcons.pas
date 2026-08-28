unit MmdPoseEditorToolbarIcons;

// 共通ポーズ編集ツールバー用のDPI対応線画アイコンを生成する。

interface

uses
  Vcl.Graphics,
  Vcl.ImgList;

const
  MMD_POSE_TOOLBAR_ICON_COUNT = 7;

procedure BuildMmdPoseEditorToolbarIcons(Images: TCustomImageList;
  IconSize: Integer; NormalColor, AccentColor: TColor);

implementation

uses
  System.Math,
  System.Types,
  Winapi.Windows;

const
  BaseSize = 24;
  MaskColor = TColor($00FF00FF);

function Scale(Value, Size: Integer): Integer;
begin
  Result := MulDiv(Value, Size, BaseSize);
end;

procedure SetupPen(Canvas: TCanvas; Size: Integer; Color: TColor);
begin
  Canvas.Pen.Color := Color;
  Canvas.Pen.Width := Max(1, Scale(2, Size));
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsClear;
end;

procedure DrawUndoRedo(Canvas: TCanvas; Size: Integer; Color: TColor;
  Redo: Boolean);
var
  Direction: Integer;
  Left, Right: Integer;
begin
  SetupPen(Canvas, Size, Color);
  if Redo then
  begin
    Direction := -1;
    Left := 5;
    Right := 19;
  end
  else
  begin
    Direction := 1;
    Left := 19;
    Right := 5;
  end;
  Canvas.Arc(Scale(4, Size), Scale(6, Size), Scale(20, Size),
    Scale(21, Size), Scale(Left, Size), Scale(8, Size),
    Scale(Right, Size), Scale(8, Size));
  Canvas.Polyline([Point(Scale(Right + Direction * 5, Size), Scale(3, Size)),
    Point(Scale(Right, Size), Scale(8, Size)),
    Point(Scale(Right + Direction * 5, Size), Scale(12, Size))]);
end;

procedure DrawResetBone(Canvas: TCanvas; Size: Integer; Color: TColor);
begin
  SetupPen(Canvas, Size, Color);
  Canvas.Ellipse(Scale(8, Size), Scale(8, Size), Scale(16, Size),
    Scale(16, Size));
  Canvas.Arc(Scale(3, Size), Scale(3, Size), Scale(21, Size), Scale(21, Size),
    Scale(19, Size), Scale(8, Size), Scale(8, Size), Scale(3, Size));
  Canvas.Polyline([Point(Scale(18, Size), Scale(3, Size)),
    Point(Scale(20, Size), Scale(8, Size)),
    Point(Scale(15, Size), Scale(8, Size))]);
end;

procedure DrawResetBranch(Canvas: TCanvas; Size: Integer; Color: TColor);
begin
  SetupPen(Canvas, Size, Color);
  Canvas.MoveTo(Scale(6, Size), Scale(6, Size));
  Canvas.LineTo(Scale(12, Size), Scale(12, Size));
  Canvas.LineTo(Scale(18, Size), Scale(6, Size));
  Canvas.MoveTo(Scale(12, Size), Scale(12, Size));
  Canvas.LineTo(Scale(18, Size), Scale(18, Size));
  Canvas.Ellipse(Scale(3, Size), Scale(3, Size), Scale(8, Size), Scale(8, Size));
  Canvas.Ellipse(Scale(16, Size), Scale(3, Size), Scale(21, Size), Scale(8, Size));
  Canvas.Ellipse(Scale(16, Size), Scale(16, Size), Scale(21, Size), Scale(21, Size));
end;

procedure DrawResetAll(Canvas: TCanvas; Size: Integer; Color: TColor);
begin
  SetupPen(Canvas, Size, Color);
  Canvas.Ellipse(Scale(3, Size), Scale(9, Size), Scale(8, Size), Scale(14, Size));
  Canvas.Ellipse(Scale(10, Size), Scale(9, Size), Scale(15, Size), Scale(14, Size));
  Canvas.Ellipse(Scale(17, Size), Scale(9, Size), Scale(22, Size), Scale(14, Size));
  Canvas.Arc(Scale(3, Size), Scale(3, Size), Scale(21, Size), Scale(21, Size),
    Scale(19, Size), Scale(7, Size), Scale(7, Size), Scale(3, Size));
  Canvas.Polyline([Point(Scale(18, Size), Scale(2, Size)),
    Point(Scale(20, Size), Scale(7, Size)),
    Point(Scale(15, Size), Scale(7, Size))]);
end;

procedure DrawSymmetry(Canvas: TCanvas; Size: Integer; Color: TColor);
begin
  SetupPen(Canvas, Size, Color);
  Canvas.Pen.Style := psDot;
  Canvas.MoveTo(Scale(12, Size), Scale(2, Size));
  Canvas.LineTo(Scale(12, Size), Scale(22, Size));
  Canvas.Pen.Style := psSolid;
  Canvas.Polyline([Point(Scale(10, Size), Scale(5, Size)),
    Point(Scale(5, Size), Scale(8, Size)), Point(Scale(4, Size), Scale(16, Size)),
    Point(Scale(9, Size), Scale(20, Size))]);
  Canvas.Polyline([Point(Scale(14, Size), Scale(5, Size)),
    Point(Scale(19, Size), Scale(8, Size)), Point(Scale(20, Size), Scale(16, Size)),
    Point(Scale(15, Size), Scale(20, Size))]);
end;

procedure DrawAutoFit(Canvas: TCanvas; Size: Integer; Color: TColor);
begin
  SetupPen(Canvas, Size, Color);
  Canvas.Rectangle(Scale(5, Size), Scale(6, Size), Scale(19, Size),
    Scale(18, Size));
  Canvas.Polyline([Point(Scale(2, Size), Scale(8, Size)),
    Point(Scale(2, Size), Scale(2, Size)), Point(Scale(8, Size), Scale(2, Size))]);
  Canvas.Polyline([Point(Scale(16, Size), Scale(2, Size)),
    Point(Scale(22, Size), Scale(2, Size)), Point(Scale(22, Size), Scale(8, Size))]);
  Canvas.Polyline([Point(Scale(2, Size), Scale(16, Size)),
    Point(Scale(2, Size), Scale(22, Size)), Point(Scale(8, Size), Scale(22, Size))]);
  Canvas.Polyline([Point(Scale(16, Size), Scale(22, Size)),
    Point(Scale(22, Size), Scale(22, Size)), Point(Scale(22, Size), Scale(16, Size))]);
end;

procedure DrawIcon(Canvas: TCanvas; Index, Size: Integer;
  NormalColor, AccentColor: TColor);
begin
  case Index of
    0: DrawUndoRedo(Canvas, Size, NormalColor, False);
    1: DrawUndoRedo(Canvas, Size, NormalColor, True);
    2: DrawResetBone(Canvas, Size, NormalColor);
    3: DrawResetBranch(Canvas, Size, NormalColor);
    4: DrawResetAll(Canvas, Size, NormalColor);
    5: DrawSymmetry(Canvas, Size, AccentColor);
    6: DrawAutoFit(Canvas, Size, NormalColor);
  end;
end;

procedure BuildMmdPoseEditorToolbarIcons(Images: TCustomImageList;
  IconSize: Integer; NormalColor, AccentColor: TColor);
var
  Bitmap: Vcl.Graphics.TBitmap;
  Index: Integer;
begin
  if not Assigned(Images) or (IconSize <= 0) then
    Exit;
  Images.Clear;
  Images.Width := IconSize;
  Images.Height := IconSize;
  Images.Masked := True;
  Images.BkColor := clNone;
  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    Bitmap.PixelFormat := pf24bit;
    Bitmap.SetSize(IconSize, IconSize);
    for Index := 0 to MMD_POSE_TOOLBAR_ICON_COUNT - 1 do
    begin
      Bitmap.Canvas.Brush.Style := bsSolid;
      Bitmap.Canvas.Brush.Color := MaskColor;
      Bitmap.Canvas.FillRect(System.Types.Rect(0, 0, IconSize, IconSize));
      DrawIcon(Bitmap.Canvas, Index, IconSize, NormalColor, AccentColor);
      Images.AddMasked(Bitmap, MaskColor);
    end;
  finally
    Bitmap.Free;
  end;
end;

end.
