unit PsdImageBitmap;
// VCLのビットマップに描画するための描画モードを追加

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,PSDImage,PsdImageDefine;

type TPsdImageBitmap = class(TPSDImage)
   private
    { Private 宣言 }
    // 乗算（Multiply）ブレンド：AviUtl2 用（α非対応）
    function DrawMul(const fromCol,toCol : TFourth) : TFourth;
    // リニアバーン（Linear Burn）：AviUtl2 用（α非対応）
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

{ TPsdImageBitmap }

constructor TPsdImageBitmap.Create;
begin
  inherited;
  RegisterBlendModeBMP(btMul,DrawMul);
  RegisterBlendModeBMP(btLbrn,DrawLbrn);
  RegisterBlendModeBMP(btScrn,DrawScn);
  RegisterBlendModeBMP(btPass,DrawPass);
  RegisterBlendModeBMP(btLddg,DrawLddg);
  RegisterBlendModeBMP(btOver,DrawOver);
  RegisterBlendModeBMP(btSLit,DrawSLit);
end;

destructor TPsdImageBitmap.Destroy;
begin

  inherited;
end;

// 乗算描画
function TPsdImageBitmap.DrawMul(const fromCol, toCol: TFourth): TFourth;
var
  blend : TFourth;
  alpha,invA : Integer;
begin

  // dst が無い場合
  if toCol.A = 0 then
  begin
    Result := fromCol;
    Exit;
  end;

  alpha := fromCol.A;
  invA  := 255 - alpha;

  blend.R := fromCol.R * toCol.R div 255;
  blend.G := fromCol.G * toCol.G div 255;
  blend.B := fromCol.B * toCol.B div 255;

  Result.R := (blend.R * alpha + toCol.R * invA) div 255;
  Result.G := (blend.G * alpha + toCol.G * invA) div 255;
  Result.B := (blend.B * alpha + toCol.B * invA) div 255;

  Result.A := alpha + (toCol.A * invA) div 255;

end;

// 通常描画
function TPsdImageBitmap.DrawPass(const fromCol, toCol: TFourth): TFourth;
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

function TPsdImageBitmap.DrawLbrn(const fromCol, toCol: TFourth): TFourth;
var
  r, g, b: Integer;
  invA : Integer;
begin
  invA := 255 - fromCol.A;
  // Linear Burn : src + dst - 255
  r := fromCol.R + toCol.R - 255;
  g := fromCol.G + toCol.G - 255;
  b := fromCol.B + toCol.B - 255;

  if r < 0 then r := 0 else if r > 255 then r := 255;
  if g < 0 then g := 0 else if g > 255 then g := 255;
  if b < 0 then b := 0 else if b > 255 then b := 255;

  // VCL(BGR) 用に R/B を反転
  Result.R := r;
  Result.G := g;
  Result.B := b;
  //Result.A := 0; // 完全不透明
  Result.A := fromCol.A + (toCol.A * invA) div 255;
end;

function TPsdImageBitmap.DrawScn(const fromCol, toCol: TFourth): TFourth;
var
  r, g, b: Integer;
  aSrc, invA: Integer;
begin
  aSrc := fromCol.A;
  invA := 255 - aSrc;

  // Screen : 255 - (255-src)*(255-dst)/255
  r := 255 - ((255 - fromCol.R) * (255 - toCol.R) div 255);
  g := 255 - ((255 - fromCol.G) * (255 - toCol.G) div 255);
  b := 255 - ((255 - fromCol.B) * (255 - toCol.B) div 255);

  Result.R := (r * aSrc div 255) + (toCol.R * invA div 255);
  Result.G := (g * aSrc div 255) + (toCol.G * invA div 255);
  Result.B := (b * aSrc div 255) + (toCol.B * invA div 255);
  Result.A := aSrc + (toCol.A * invA) div 255;
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

function TPsdImageBitmap.DrawSLit(const fromCol, toCol: TFourth): TFourth;
var
  r, g, b: Integer;
  aSrc, aDst, invA: Integer;
  baseR, baseG, baseB: Integer;
begin
  aSrc := fromCol.A;
  aDst := toCol.A;
  invA := 255 - aSrc;

  if toCol.A = 0 then begin
    baseR := fromCol.R;
    baseG := fromCol.G;
    baseB := fromCol.B;
  end else begin
    baseR := toCol.R;
    baseG := toCol.G;
    baseB := toCol.B;

    r := SoftLight8(baseR, fromCol.R);
    g := SoftLight8(baseG, fromCol.G);
    b := SoftLight8(baseB, fromCol.B);

    baseR := r;
    baseG := g;
    baseB := b;
  end;

  Result.R := (baseR * aSrc div 255) + (toCol.R * invA div 255);
  Result.G := (baseG * aSrc div 255) + (toCol.G * invA div 255);
  Result.B := (baseB * aSrc div 255) + (toCol.B * invA div 255);
  Result.A := aSrc + (aDst * invA) div 255;
end;

function TPsdImageBitmap.DrawLddg(const fromCol, toCol: TFourth): TFourth;
var
  r, g, b: Integer;
  aSrc, invA: Integer;
begin
  aSrc := fromCol.A;
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
  Result.A := fromCol.A + (toCol.A * invA) div 255;
end;

function TPsdImageBitmap.DrawOver(const fromCol, toCol: TFourth): TFourth;
var
  r, g, b: Integer;
  aEff, invA: Integer;

  function Overlay(src, dst: Integer): Integer;
  begin
    if dst < 128 then
      Result := (2 * src * dst) div 255
    else
      Result := 255 - (2 * (255 - src) * (255 - dst)) div 255;
  end;

  function Suppress(ovr, base: Integer): Integer;
  begin
    if base > 160 then
      Result := (ovr + base * 3) div 4
    else
      Result := (ovr + base * 2) div 3;
  end;

begin
  // ※ ここはあなたの現行仕様を尊重（toCol.A=0は“無効ピクセル”扱い）
  if toCol.A = 0 then
  begin
    Result := toCol;
    Exit;
  end;

  // Overlay（下=toCol, 上=fromCol）
  r := Overlay(fromCol.R, toCol.R);
  g := Overlay(fromCol.G, toCol.G);
  b := Overlay(fromCol.B, toCol.B);

  // 抑制（任意）
  r := Suppress(r, toCol.R);
  g := Suppress(g, toCol.G);
  b := Suppress(b, toCol.B);

  // ★ ここが肝：強度はαで決める（AviUtl2版と同じ発想）
  // まずは「半分程度」から：aEff := fromCol.A div 2;
  // さらに近づけるなら：aEff := (fromCol.A * fromCol.A) div (255 * 3);
  aEff := fromCol.A div 2;
  invA := 255 - aEff;

  // toCol を残しつつ Overlay を足す（RGBのみ）
  Result.R := (r * aEff + toCol.R * invA) div 255;
  Result.G := (g * aEff + toCol.G * invA) div 255;
  Result.B := (b * aEff + toCol.B * invA) div 255;

  // AはVCL運用の都合で固定（あなたの現行と同じ）
  Result.A := 255;
end;



end.
