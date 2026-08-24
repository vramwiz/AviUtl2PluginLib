unit PSDImageCustomKindDetector;

interface

uses
  System.SysUtils, PsdImage;

type                                      // 立ち絵制作者
  TPSDImageKind = (pikNone,               // 判定不能：標準
                   pikKarai,              // からい氏PSD
                   pikShimaDonpachiMei,   // 島でドンパチするメイ氏PSD
                   pikKosukeSantaMaria,   // こーすけさんたまりあ氏PSD
                   pikMatcher,            // マッチャー氏PSD
                   pikYumeNoOwari,        // ユメのオワリ氏PSD
                   pikNishimiya,          // にしみや式PSD
                   pikKamiyoshiGeneric,   // カミヨシ氏 汎用PSD
                   pikKamiyoshiShikokuMetan, // カミヨシ氏 四国めたんPSD
                   pikKamiyoshiNo7,       // カミヨシ氏 No.7(ナンバー7) PSD
                   pikAzuki,              // アズキ式PSD
                   pikBlueberry,          // blueberry氏PSD
                   pikPetenshi,           // ペテン師氏PSD
                   pikNanroku,            // 七六氏PSD
                   pikYumeNoOwariKiritanSuwariE, // ユメのオワリ氏 きりたん座り絵PSD
                   pikMunisaga,           // むにさが氏PSD
                   pikAjishio,            // アジシオ氏PSD
                   pikFurasuko,           // ふらすこ氏PSD
                   pikKaraiKotonoha,      // からい氏 琴葉茜PSD
                   pikKaraiKotonohaAoi,   // からい氏 琴葉葵PSD
                   pikMoikyShikokuMetan,  // moiky氏 四国めたんPSD
                   pikMoikyAnkomon,       // moiky氏 あんこもんPSD
                   pikMoikyZundamon,      // moiky氏 ずんだもんPSD
                   pikPepechi,            // ぺぺち氏PSD
                   pikMikoDamon,          // みこ氏 damon PSD
                   pikTaotaoShikokuMetan, // たおたお氏 四国めたんPSD
                   pikSaiyouWagashiTsukuyomi, // 西妖和菓子氏 つくよみちゃんPSD
                   pikFurasukoKiritan     // ふらすこ氏 東北きりたんPSD
                   );

// 判定種別に対応するメニュー表示名を返す
function PSDImageKindCaption(Kind: TPSDImageKind): string;
// PSDに適用する処理種別を判定する
function DetectPSDImageKind(PsdImage: TPSDImage): TPSDImageKind;

implementation

uses
  PSDImageCustomBlueberry, PSDImageCustomKaraiKotonoha,
  PSDImageCustomKaraiKotonohaAoi, PSDImageCustomMoiky,
  PSDImageCustomFurasuko, PSDImageCustomMatcher, PSDImageCustomMunisaga,
  PSDImageCustomAjishio, PSDImageCustomNishimiya, PSDImageCustomAzuki,
  PSDImageCustomPetenshi, PSDImageCustomNanroku, PSDImageCustomYumeNoOwari,
  PSDImageCustomKamiyoshi, PSDImageCustomKarai, PSDImageCustomShimaDonpachiMei,
  PSDImageCustomKosukeSantaMaria, PSDImageCustomMiko, PSDImageCustomTaotao,
  PSDImageCustomSaiyouWagashi;

const
  PSD_IMAGE_KIND_CAPTIONS: array[pikKarai..pikFurasukoKiritan] of string = (
    'からいPSD',
    '島でドンパチするメイPSD',
    'こーすけさんたまりあPSD',
    'マッチャーPSD',
    'ユメのオワリPSD',
    'にしみや式PSD',
    'カミヨシ_汎用PSD',
    'カミヨシ_四国めたんPSD',
    'カミヨシ_No.7(ナンバー7) PSD',
    'アズキ式PSD',
    'blueberryPSD',
    'ペテン師PSD',
    '七六PSD',
    'ユメのオワリ_きりたん座り絵PSD',
    'むにさがPSD',
    'アジシオPSD',
    'ふらすこPSD',
    'からい_琴葉茜PSD',
    'からい_琴葉葵PSD',
    'moiky_四国めたんPSD',
    'moiky_あんこもんPSD',
    'moiky_ずんだもんPSD',
    'ぺぺちPSD',
    'みこ_damonPSD',
    'たおたお_四国めたんPSD',
    '西妖和菓子_つくよみちゃんPSD',
    'ふらすこ_東北きりたんPSD'
  );

function IsPepechiFileName(const FileName: string): Boolean;
var
  Name: string;
begin
  Name := ChangeFileExt(ExtractFileName(FileName), '');
  Result := SameText(Copy(Name, 1, Length('◆ゆるい')), '◆ゆるい');
end;

function PSDImageKindCaption(Kind: TPSDImageKind): string;
begin
  Result := '不明';
  if (Kind >= Low(PSD_IMAGE_KIND_CAPTIONS)) and
     (Kind <= High(PSD_IMAGE_KIND_CAPTIONS)) then
    Result := PSD_IMAGE_KIND_CAPTIONS[Kind];
end;

function DetectPSDImageKind(PsdImage: TPSDImage): TPSDImageKind;
begin
  Result := pikNone;
  if PsdImage = nil then Exit;

  if IsPepechiFileName(PsdImage.FileName) then
    Result := pikPepechi
  else if IsMatcherPSD(PsdImage) then
    Result := pikMatcher
  else if IsNanrokuFileName(PsdImage.FileName) then
    Result := pikNanroku
  else if IsPetenshiFileName(PsdImage.FileName) then
    Result := pikPetenshi
  else if IsAzukiFileName(PsdImage.FileName) then
    Result := pikAzuki
  else if IsBlueberryPSD(PsdImage) then
    Result := pikBlueberry
  else if IsMoikyShikokuMetanPSD(PsdImage) then
    Result := pikMoikyShikokuMetan
  else if IsMoikyAnkomonPSD(PsdImage) then
    Result := pikMoikyAnkomon
  else if IsMoikyZundamonPSD(PsdImage) then
    Result := pikMoikyZundamon
  else if IsMikoDamonPSD(PsdImage) then
    Result := pikMikoDamon
  else if IsTaotaoShikokuMetanPSD(PsdImage) then
    Result := pikTaotaoShikokuMetan
  else if IsSaiyouWagashiTsukuyomiPSD(PsdImage) then
    Result := pikSaiyouWagashiTsukuyomi
  else if HasKamiyoshiShikokuMetanStructure(PsdImage) then
    Result := pikKamiyoshiShikokuMetan
  else if HasKamiyoshiNo7Structure(PsdImage) then
    Result := pikKamiyoshiNo7
  else if HasKamiyoshiStructure(PsdImage) then
    Result := pikKamiyoshiGeneric
  else if IsAjishioPSD(PsdImage) then
    Result := pikAjishio
  else if IsFurasukoPSD(PsdImage) then
    Result := pikFurasuko
  else if IsFurasukoKiritanPSD(PsdImage) then
    Result := pikFurasukoKiritan
  else if IsMunisagaPSD(PsdImage) then
    Result := pikMunisaga
  else if HasYumeNoOwariKiritanSuwariEStructure(PsdImage) then
    Result := pikYumeNoOwariKiritanSuwariE
  else if IsYumeNoOwariFileName(PsdImage.FileName) or
     HasYumeNoOwariStructure(PsdImage) then
    Result := pikYumeNoOwari
  else if IsNishimiyaFileName(PsdImage.FileName) then
    Result := pikNishimiya
  else if IsShimaDonpachiMeiPSD(PsdImage) then
    Result := pikShimaDonpachiMei
  else if IsKosukeSantaMariaPSD(PsdImage) then
    Result := pikKosukeSantaMaria
  else if IsKaraiKotonohaPSD(PsdImage) then
    Result := pikKaraiKotonoha
  else if IsKaraiKotonohaAoiPSD(PsdImage) then
    Result := pikKaraiKotonohaAoi
  else if IsKaraiFileName(PsdImage.FileName) or
     HasKaraiStructure(PsdImage) then
    Result := pikKarai;
end;

end.
