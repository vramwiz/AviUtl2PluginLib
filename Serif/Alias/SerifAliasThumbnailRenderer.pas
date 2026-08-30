unit SerifAliasThumbnailRenderer;

interface

uses
  Winapi.Windows,System.SysUtils, Vcl.Graphics,System.UITypes;

// エイリアス解析に成功した場合だけプレビュー文字列を描画する。
function TryDrawSerifAliasPreview(const FileName: string; Bitmap: TBitmap): Boolean;
// エイリアス解析とフォールバックを含めてサムネイルを描画する。
procedure DrawSerifAliasThumbnail(const FileName, FallbackName: string; Bitmap: TBitmap);

implementation

uses
  System.Types, System.Math, System.Classes, System.Generics.Collections,
  TextEncodingUtils;

type
  TSerifAliasOutlineStyle = record
    Size: Integer;   // 縁取りの太さ
    Blur: Integer;   // 縁取りのぼかし量
    Color: TColor;   // 縁取り色
  end;

  TSerifAliasShadowStyle = record
    Enabled: Boolean; // ドロップシャドウを使うか
    OffsetX: Integer; // 影のXオフセット
    OffsetY: Integer; // 影のYオフセット
    Blur: Integer;    // 影のぼかし量
    Density: Double;  // 影の濃さ
    Color: TColor;    // 影色
  end;

  TSerifAliasPreviewStyle = record
    FontName: string;                             // 表示フォント名
    FontSize: Double;                             // 基準フォントサイズ
    FontColor: TColor;                            // 文字色
    Bold: Boolean;                                // 太字指定
    Italic: Boolean;                              // 斜体指定
    Outlines: TArray<TSerifAliasOutlineStyle>;    // 縁取り設定一覧
    Shadow: TSerifAliasShadowStyle;               // 影設定
  end;

const
  PREVIEW_TEXT = 'aA1あア漢';
  THUMBNAIL_BACKGROUND = TColor($2B2B2B);
  THUMBNAIL_BORDER = TColor($6A6A6A);
  DEFAULT_FONT_COLOR = clWhite;
  DEFAULT_FONT_NAME = 'Yu Gothic UI';

// BOM や余計な空白を除去して比較しやすい値へ整える。
function NormalizeValue(const S: string): string;
begin
  Result := Trim(StringReplace(S, #$FEFF, '', [rfReplaceAll]));
end;

// 6桁RGB文字列を Delphi の TColor に変換する。
function ParseColorText(const S: string; DefaultColor: TColor): TColor;
var
  Hex: string;
  R, G, B: Integer;
begin
  Result := DefaultColor;
  Hex := NormalizeValue(S);
  if Hex = '' then
    Exit;

  if Hex[1] = '$' then
    Delete(Hex, 1, 1);
  if SameText(Copy(Hex, 1, 2), '0X') then
    Delete(Hex, 1, 2);

  if Length(Hex) <> 6 then
    Exit;

  R := StrToIntDef('$' + Copy(Hex, 1, 2), -1);
  G := StrToIntDef('$' + Copy(Hex, 3, 2), -1);
  B := StrToIntDef('$' + Copy(Hex, 5, 2), -1);
  if (R < 0) or (G < 0) or (B < 0) then
    Exit;

  Result := RGB(R, G, B);
end;

// エイリアスの数値文字列を小数として読む。
function ParseFloatText(const S: string; DefaultValue: Double): Double;
var
  N: string;
begin
  N := NormalizeValue(S);
  if N = '' then
    Exit(DefaultValue);

  N := StringReplace(N, ',', '.', [rfReplaceAll]);
  Result := StrToFloatDef(N, DefaultValue);
end;

// エイリアスの数値文字列を整数へ丸めて読む。
function ParseIntText(const S: string; DefaultValue: Integer): Integer;
begin
  Result := Round(ParseFloatText(S, DefaultValue));
end;

// 2色を指定比率で混ぜて中間色を作る。
function BlendColor(Color1, Color2: TColor; Weight2: Double): TColor;
var
  C1: COLORREF;
  C2: COLORREF;
  W1: Double;
  R: Integer;
  G: Integer;
  B: Integer;
begin
  Weight2 := EnsureRange(Weight2, 0.0, 1.0);
  W1 := 1.0 - Weight2;

  C1 := ColorToRGB(Color1);
  C2 := ColorToRGB(Color2);

  R := Round(GetRValue(C1) * W1 + GetRValue(C2) * Weight2);
  G := Round(GetGValue(C1) * W1 + GetGValue(C2) * Weight2);
  B := Round(GetBValue(C1) * W1 + GetBValue(C2) * Weight2);

  Result := RGB(R, G, B);
end;

// 解析失敗時のフォールバックとしてファイル名サムネイルを描く。
procedure DrawFallbackThumbnail(const AName: string; Bitmap: TBitmap);
var
  R: TRect;
  S: string;
  FontHeight: Integer;
begin
  Bitmap.Canvas.Brush.Style := bsSolid;
  Bitmap.Canvas.Brush.Color := THUMBNAIL_BACKGROUND;
  Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));

  Bitmap.Canvas.Brush.Style := bsClear;
  Bitmap.Canvas.Pen.Color := THUMBNAIL_BORDER;
  Bitmap.Canvas.Rectangle(0, 0, Bitmap.Width, Bitmap.Height);

  Bitmap.Canvas.Font.Color := clWhite;
  Bitmap.Canvas.Font.Name := DEFAULT_FONT_NAME;
  FontHeight := Max(12, Min(Bitmap.Height - 12, Bitmap.Width div 8));
  Bitmap.Canvas.Font.Height := -FontHeight;

  S := AName;
  if S = '' then
    S := '(empty)';

  R := Rect(6, 6, Bitmap.Width - 6, Bitmap.Height - 6);
  DrawText(Bitmap.Canvas.Handle, PChar(S), Length(S), R,
    DT_CENTER or DT_VCENTER or DT_WORDBREAK or DT_END_ELLIPSIS);
end;

// .object から文字装飾に必要な最小限の情報を取り出す。
function ExtractPreviewStyle(const FileName: string; out Style: TSerifAliasPreviewStyle): Boolean;
var
  Lines: TStringList;
  Values: TStringList;
  Line: string;
  Key: string;
  Value: string;
  SeparatorPos: Integer;
  LineIndex: Integer;
  EffectName: string;
  OutlineList: TList<TSerifAliasOutlineStyle>;
  Outline: TSerifAliasOutlineStyle;

  procedure ApplySection;
  begin
    EffectName := NormalizeValue(Values.Values['effect.name']);
    if SameText(EffectName, 'テキスト') then
    begin
      Style.FontName := NormalizeValue(Values.Values['フォント']);
      if Style.FontName = '' then
        Style.FontName := DEFAULT_FONT_NAME;
      Style.FontSize := ParseFloatText(Values.Values['サイズ'],
        Style.FontSize);
      Style.FontColor := ParseColorText(Values.Values['文字色'],
        Style.FontColor);
      Style.Bold := ParseIntText(Values.Values['B'], 0) <> 0;
      Style.Italic := ParseIntText(Values.Values['I'], 0) <> 0;
      Result := True;
    end
    else if SameText(EffectName, '縁取り') then
    begin
      Outline.Size := Max(1, ParseIntText(Values.Values['サイズ'], 1));
      Outline.Blur := Max(0, ParseIntText(Values.Values['ぼかし'], 0));
      Outline.Color := ParseColorText(Values.Values['縁色'], clBlack);
      OutlineList.Add(Outline);
    end
    else if SameText(EffectName, 'ドロップシャドウ') then
    begin
      Style.Shadow.Enabled := True;
      Style.Shadow.OffsetX := ParseIntText(Values.Values['X'], 0);
      Style.Shadow.OffsetY := ParseIntText(Values.Values['Y'], 0);
      Style.Shadow.Blur := Max(0, ParseIntText(Values.Values['拡散'], 0));
      Style.Shadow.Density := EnsureRange(ParseFloatText(
        Values.Values['濃さ'], 40.0), 0.0, 100.0);
      Style.Shadow.Color := ParseColorText(Values.Values['影色'], clBlack);
    end;
  end;
begin
  Result := False;

  Style.FontName := DEFAULT_FONT_NAME;
  Style.FontSize := 50.0;
  Style.FontColor := DEFAULT_FONT_COLOR;
  Style.Bold := False;
  Style.Italic := False;
  Style.Outlines := nil;
  Style.Shadow.Enabled := False;
  Style.Shadow.OffsetX := 0;
  Style.Shadow.OffsetY := 0;
  Style.Shadow.Blur := 0;
  Style.Shadow.Density := 40.0;
  Style.Shadow.Color := clBlack;

  if not FileExists(FileName) then
    Exit;

  Lines := TStringList.Create;
  Values := TStringList.Create;
  OutlineList := TList<TSerifAliasOutlineStyle>.Create;
  try
    Values.NameValueSeparator := '=';
    Lines.Text := LoadTextAutoEncoding(FileName);
    for LineIndex := 0 to Lines.Count do
    begin
      if LineIndex < Lines.Count then
        Line := Trim(Lines[LineIndex])
      else
        Line := '[end]';
      if (Line <> '') and (Line[1] = '[') and
        (Line[Length(Line)] = ']') then
      begin
        if Values.Count > 0 then ApplySection;
        Values.Clear;
        Continue;
      end;
      SeparatorPos := Pos('=', Line);
      if SeparatorPos <= 0 then Continue;
      Key := Trim(Copy(Line, 1, SeparatorPos - 1));
      Value := Copy(Line, SeparatorPos + 1, MaxInt);
      Values.Values[Key] := Value;
    end;
    Style.Outlines := OutlineList.ToArray;
  finally
    OutlineList.Free;
    Values.Free;
    Lines.Free;
  end;
end;

// サムネイル共通の背景と枠線を描画する。
procedure SetupPreviewCanvas(Bitmap: TBitmap);
begin
  Bitmap.Canvas.Brush.Style := bsSolid;
  Bitmap.Canvas.Brush.Color := THUMBNAIL_BACKGROUND;
  Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));

  Bitmap.Canvas.Brush.Style := bsClear;
  Bitmap.Canvas.Pen.Color := THUMBNAIL_BORDER;
  Bitmap.Canvas.Rectangle(0, 0, Bitmap.Width, Bitmap.Height);
end;

// 文字列をサムネイル中央へ寄せる描画開始位置を返す。
function GetTextOrigin(const Bitmap: TBitmap; const TextSize: TSize; ExtraMargin: Integer): TPoint;
begin
  Result.X := (Bitmap.Width - TextSize.cx) div 2;
  Result.Y := (Bitmap.Height - TextSize.cy) div 2;

  Result.X := EnsureRange(Result.X, 4 + ExtraMargin,
    Max(4 + ExtraMargin, Bitmap.Width - TextSize.cx - 4 - ExtraMargin));
  Result.Y := EnsureRange(Result.Y, 4 + ExtraMargin,
    Max(4 + ExtraMargin, Bitmap.Height - TextSize.cy - 4 - ExtraMargin));
end;

// エイリアスの縁取り設定をサムネイル用の描画半径へ控えめに変換する。
function CalcOutlineRadius(const Outline: TSerifAliasOutlineStyle): Integer;
begin
  // サムネイルでは原寸より細く見えやすいので、縁取り半径は少し強めに寄せる。
  Result := Max(2, (Outline.Size + 1) div 2 + 1);
  Result := Result + (Outline.Blur div 6);
end;

// 半径分だけずらし描きして簡易的な縁取りを表現する。
procedure DrawTextStroke(Canvas: TCanvas; const Text: string; X, Y, Radius: Integer; AColor: TColor);
var
  DX: Integer;
  DY: Integer;
begin
  if Radius <= 0 then
    Exit;

  Canvas.Font.Color := AColor;
  for DY := -Radius to Radius do
    for DX := -Radius to Radius do
    begin
      if (DX = 0) and (DY = 0) then
        Continue;
      if (DX * DX) + (DY * DY) > Radius * Radius then
        Continue;
      Canvas.TextOut(X + DX, Y + DY, Text);
    end;
end;

// オフセット付きの影を簡易的なぼかし付きで描画する。
procedure DrawTextShadow(Canvas: TCanvas; const Text: string; X, Y: Integer; const Shadow: TSerifAliasShadowStyle);
var
  Radius: Integer;
  ShadowColor: TColor;
begin
  if not Shadow.Enabled then
    Exit;

  Radius := Max(1, Shadow.Blur div 5);
  ShadowColor := BlendColor(THUMBNAIL_BACKGROUND, Shadow.Color, Shadow.Density / 100.0);
  DrawTextStroke(Canvas, Text, X + Shadow.OffsetX, Y + Shadow.OffsetY, Radius, ShadowColor);
  Canvas.Font.Color := ShadowColor;
  Canvas.TextOut(X + Shadow.OffsetX, Y + Shadow.OffsetY, Text);
end;

// 解析済みスタイルを使って固定プレビュー文字列を描画する。
procedure DrawPreviewText(Bitmap: TBitmap; const Style: TSerifAliasPreviewStyle);
var
  TextSize: TSize;
  I: Integer;
  FontHeight: Integer;
  Origin: TPoint;
  ExtraMargin: Integer;
  OutlineRadii: TArray<Integer>;
  Radius: Integer;
begin
  Bitmap.Canvas.Font.Name := Style.FontName;
  Bitmap.Canvas.Font.Style := [];
  Bitmap.Canvas.Font.Quality := fqAntialiased;
  if Style.Bold then
    Bitmap.Canvas.Font.Style := Bitmap.Canvas.Font.Style + [fsBold];
  if Style.Italic then
    Bitmap.Canvas.Font.Style := Bitmap.Canvas.Font.Style + [fsItalic];

  ExtraMargin := 8;
  for I := 0 to High(Style.Outlines) do
    ExtraMargin := Max(ExtraMargin, CalcOutlineRadius(Style.Outlines[I]) + 4);

  FontHeight := Max(10, Bitmap.Height - (ExtraMargin * 2));
  repeat
    Bitmap.Canvas.Font.Height := -FontHeight;
    TextSize := Bitmap.Canvas.TextExtent(PREVIEW_TEXT);
    if (TextSize.cx <= Bitmap.Width - ExtraMargin * 2) and
       (TextSize.cy <= Bitmap.Height - ExtraMargin * 2) then
      Break;
    Dec(FontHeight);
  until FontHeight <= 10;

  Bitmap.Canvas.Font.Height := -Max(FontHeight, 10);
  TextSize := Bitmap.Canvas.TextExtent(PREVIEW_TEXT);
  Origin := GetTextOrigin(Bitmap, TextSize, ExtraMargin);

  DrawTextShadow(Bitmap.Canvas, PREVIEW_TEXT, Origin.X, Origin.Y, Style.Shadow);

  SetLength(OutlineRadii, Length(Style.Outlines));
  for I := 0 to High(Style.Outlines) do
  begin
    // 縁取りサイズは内側から外側へ累積させて、外枠の半径として使う。
    Radius := CalcOutlineRadius(Style.Outlines[I]);
    if I > 0 then
      Inc(Radius, OutlineRadii[I - 1]);
    OutlineRadii[I] := Radius;
  end;

  // 外側を先に描いてから内側を重ねると、二重縁取りでも内側色が消えにくい。
  for I := High(Style.Outlines) downto 0 do
  begin
    Radius := OutlineRadii[I];
    DrawTextStroke(Bitmap.Canvas, PREVIEW_TEXT, Origin.X, Origin.Y, Radius,
      Style.Outlines[I].Color);
  end;

  Bitmap.Canvas.Font.Color := Style.FontColor;
  Bitmap.Canvas.TextOut(Origin.X, Origin.Y, PREVIEW_TEXT);
end;

// エイリアス解析に成功した場合だけプレビュー文字列を描画する。
function TryDrawSerifAliasPreview(const FileName: string; Bitmap: TBitmap): Boolean;
var
  Style: TSerifAliasPreviewStyle;
begin
  Result := False;
  if Bitmap = nil then
    Exit;

  if not ExtractPreviewStyle(FileName, Style) then
    Exit;

  SetupPreviewCanvas(Bitmap);
  DrawPreviewText(Bitmap, Style);
  Result := True;
end;

// エイリアス解析とフォールバックを含めたサムネイル描画入口。
procedure DrawSerifAliasThumbnail(const FileName, FallbackName: string; Bitmap: TBitmap);
begin
  if not TryDrawSerifAliasPreview(FileName, Bitmap) then
    DrawFallbackThumbnail(FallbackName, Bitmap);
end;

end.
