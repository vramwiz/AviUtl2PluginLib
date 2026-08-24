unit PSDImageAviUtl2Filter;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,PSDImage,
  PsdImageBitmap,Math,PsdImageDefine;

type TPSDImageAviUtl2Filter = class(TPsdImageBitmap)
   private
    { Private 宣言 }
    // 乗算（Multiply）ブレンド：AviUtl2 用（α対応）
    function DrawMul(const fromCol,toCol : TFourth) : TFourth;
    // リニアバーン（Linear Burn）：AviUtl2 用（α対応）
    function DrawLbrn(const fromCol, toCol: TFourth): TFourth;
    // btMul  : Multiply（乗算・影を強くする）
    function DrawScn(const fromCol, toCol: TFourth): TFourth;
    // 本実装ではグループ合成未対応のため、通常描画（Norm）として扱う。
    function DrawPass(const fromCol, toCol: TFourth): TFourth;
    // 加算合成 通常描画との違いは微妙
    function DrawLddg(const fromCol, toCol: TFourth): TFourth;
    function DrawOver(const fromCol, toCol: TFourth): TFourth;
    function DrawSLit(const fromCol, toCol: TFourth): TFourth;
  protected
  public
    { Public 宣言 }
    constructor Create();override;
    destructor Destroy;override;
  end;


implementation

{ TPSDImageAviUtl2Filter }

constructor TPSDImageAviUtl2Filter.Create;
begin
  inherited;
  RegisterBlendModeAviUtl2Filter(btMul,DrawMul);
  RegisterBlendModeAviUtl2Filter(btLbrn,DrawLbrn);
  RegisterBlendModeAviUtl2Filter(btScrn,DrawScn);
  RegisterBlendModeAviUtl2Filter(btPass,DrawPass);
  RegisterBlendModeAviUtl2Filter(btLddg,DrawLddg);
  RegisterBlendModeAviUtl2Filter(btOver,DrawOver);
  RegisterBlendModeAviUtl2Filter(btSLit,DrawSLit);
end;

destructor TPSDImageAviUtl2Filter.Destroy;
begin

  inherited;
end;

function TPSDImageAviUtl2Filter.DrawMul(const fromCol, toCol: TFourth): TFourth;
var
  mulR, mulG, mulB : Integer;
  baseR, baseG, baseB : Integer;
  aSrc, aDst, invA : Integer;
begin
  // --- ① 下地 RGB の正規化（PSD互換の核心） ---
  // 透明下地は「白」として扱う
  if toCol.A = 0 then
  begin
    baseR := 255;
    baseG := 255;
    baseB := 255;
  end
  else
  begin
    baseR := toCol.R;
    baseG := toCol.G;
    baseB := toCol.B;
  end;

  // --- ② RGB 乗算（αは考慮しない） ---
  mulR := fromCol.R * baseR div 255;
  mulG := fromCol.G * baseG div 255;
  mulB := fromCol.B * baseB div 255;

  // --- ③ α ---
  aSrc := fromCol.A;
  aDst := toCol.A;
  invA := 255 - aSrc;

  // --- ④ 通常の α 合成 ---
  result.R := (mulR * aSrc div 255) + (toCol.R * invA div 255);
  result.G := (mulG * aSrc div 255) + (toCol.G * invA div 255);
  result.B := (mulB * aSrc div 255) + (toCol.B * invA div 255);
  result.A := aSrc + (aDst * invA) div 255;
end;


function TPSDImageAviUtl2Filter.DrawPass(const fromCol, toCol: TFourth): TFourth;
var
  alpha,invA : Integer;
begin
  invA := 255 - fromCol.A;
  alpha := 255 - fromCol.A;
  result.R := fromCol.R * fromCol.A div 255 + toCol.R * alpha div 255;
  result.G := fromCol.G * fromCol.A div 255 + toCol.G * alpha div 255;
  result.B := fromCol.B * fromCol.A div 255 + toCol.B * alpha div 255;
  result.A := fromCol.A + (toCol.A * invA) div 255;
end;

function TPSDImageAviUtl2Filter.DrawLbrn(const fromCol,toCol: TFourth): TFourth;
var
  aSrc, invA: Integer;
  r, g, b: Integer;
begin
  aSrc := fromCol.A;
  invA := 255 - aSrc;

  r := fromCol.R + toCol.R - 255;
  g := fromCol.G + toCol.G - 255;
  b := fromCol.B + toCol.B - 255;

  if r < 0 then r := 0 else if r > 255 then r := 255;
  if g < 0 then g := 0 else if g > 255 then g := 255;
  if b < 0 then b := 0 else if b > 255 then b := 255;

  Result.R := (r * aSrc div 255) + (toCol.R * invA div 255);
  Result.G := (g * aSrc div 255) + (toCol.G * invA div 255);
  Result.B := (b * aSrc div 255) + (toCol.B * invA div 255);
  Result.A := aSrc + (toCol.A * invA) div 255;
end;


function TPSDImageAviUtl2Filter.DrawScn(const fromCol, toCol: TFourth): TFourth;
var
  r, g, b: Integer;
  aSrc, aDst, invA: Integer;
begin
  aSrc := fromCol.A;
  aDst := toCol.A;
  invA := 255 - aSrc;

  // Screen
  r := 255 - ((255 - fromCol.R) * (255 - toCol.R) div 255);
  g := 255 - ((255 - fromCol.G) * (255 - toCol.G) div 255);
  b := 255 - ((255 - fromCol.B) * (255 - toCol.B) div 255);

  Result.R := (r * aSrc div 255) + (toCol.R * invA div 255);
  Result.G := (g * aSrc div 255) + (toCol.G * invA div 255);
  Result.B := (b * aSrc div 255) + (toCol.B * invA div 255);
  Result.A := aSrc + (aDst * invA) div 255;
end;

function SoftLight8(const Base, Blend: Integer): Integer;
var
  b: Double;
begin
  if Blend < 128 then
    Result := Base - ((255 - 2 * Blend) * Base * (255 - Base) div 65025)
  else begin
    b := Sqrt(Base / 255);
    Result := Base + Round((2 * Blend - 255) * (b * 255 - Base) / 255);
  end;

  if Result < 0 then Result := 0
  else if Result > 255 then Result := 255;
end;

function TPSDImageAviUtl2Filter.DrawSLit(const fromCol, toCol: TFourth): TFourth;
var
  r, g, b: Integer;
  aSrc, aDst, invA: Integer;
begin
  aSrc := fromCol.A;
  aDst := toCol.A;
  invA := 255 - aSrc;

  r := SoftLight8(toCol.R, fromCol.R);
  g := SoftLight8(toCol.G, fromCol.G);
  b := SoftLight8(toCol.B, fromCol.B);

  Result.R := (r * aSrc div 255) + (toCol.R * invA div 255);
  Result.G := (g * aSrc div 255) + (toCol.G * invA div 255);
  Result.B := (b * aSrc div 255) + (toCol.B * invA div 255);
  Result.A := aSrc + (aDst * invA) div 255;
end;

function TPSDImageAviUtl2Filter.DrawLddg(const fromCol,
  toCol: TFourth): TFourth;
var
  r, g, b: Integer;
  aSrc, aDst, invA: Integer;
begin
  aSrc := fromCol.A;
  aDst := toCol.A;
  invA := 255 - aSrc;

  // Linear Dodge (Add)
  r := fromCol.R + toCol.R;
  g := fromCol.G + toCol.G;
  b := fromCol.B + toCol.B;

  if r > 255 then r := 255;
  if g > 255 then g := 255;
  if b > 255 then b := 255;

  Result.R := (r * aSrc div 255) + (toCol.R * invA div 255);
  Result.G := (g * aSrc div 255) + (toCol.G * invA div 255);
  Result.B := (b * aSrc div 255) + (toCol.B * invA div 255);
  Result.A := aSrc + (aDst * invA) div 255;
end;

function Overlay8(const Base, Blend: Integer): Integer;
begin
  if Base < 128 then
    Result := (2 * Base * Blend + 127) div 255
  else
    Result := 255 - (2 * (255 - Base) * (255 - Blend) + 127) div 255;

  if Result < 0 then Result := 0
  else if Result > 255 then Result := 255;
end;

function TPSDImageAviUtl2Filter.DrawOver(const fromCol,toCol: TFourth): TFourth;
var
  a: Integer;      // 0..255
  k: Integer;      // 抑制係数（0..255）
  ovR, ovG, ovB: Integer;
begin
  // 段階0.5を維持
  //if fromCol.A = 0 then
  if toCol.A = 0 then
  begin
    Result := fromCol;
    Exit;
  end;

  Result := toCol;

  // αをそのまま使う
  //a := fromCol.A;
  // 半分に抑制（?50%）
  //a := fromCol.A div 2;
  //a := (fromCol.A * fromCol.A + 255) div (255 * 2);
  a := (fromCol.A * fromCol.A) div (255 * 3);
  // 抑制係数（まずは 128 = 0.5）
  k := 128;

  // Overlay 色（下=toCol, 上=fromCol）
  ovR := Overlay8(toCol.R, fromCol.R);
  ovG := Overlay8(toCol.G, fromCol.G);
  ovB := Overlay8(toCol.B, fromCol.B);

  // 差分 × α × 抑制
  Result.R := toCol.R + ((ovR - toCol.R) * a * k + 32768) div (255 * 255);
  Result.G := toCol.G + ((ovG - toCol.G) * a * k + 32768) div (255 * 255);
  Result.B := toCol.B + ((ovB - toCol.B) * a * k + 32768) div (255 * 255);

  // clamp
  Result.R := Byte(EnsureRange(Result.R, 0, 255));
  Result.G := Byte(EnsureRange(Result.G, 0, 255));
  Result.B := Byte(EnsureRange(Result.B, 0, 255));

  Result.A := toCol.A;
end;

end.
