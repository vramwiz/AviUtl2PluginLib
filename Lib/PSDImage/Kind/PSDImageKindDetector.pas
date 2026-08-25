unit PSDImageKindDetector;

interface

uses
  PsdImage, PSDImageCustomKindDetector;

type
  // 互換用エイリアス。作者別・キャラ別の判定責務は
  // PSDImage\Custom\Lib\PSDImageCustomKindDetector.pas 側へ移した。
  TPSDImageKind = PSDImageCustomKindDetector.TPSDImageKind;

// 判定種別に対応するメニュー表示名を返す
function PSDImageKindCaption(Kind: TPSDImageKind): string;
// PSDに適用する処理種別を判定する
function DetectPSDImageKind(PsdImage: TPSDImage): TPSDImageKind;

implementation

function PSDImageKindCaption(Kind: TPSDImageKind): string;
begin
  Result := PSDImageCustomKindDetector.PSDImageKindCaption(Kind);
end;

function DetectPSDImageKind(PsdImage: TPSDImage): TPSDImageKind;
begin
  Result := PSDImageCustomKindDetector.DetectPSDImageKind(PsdImage);
end;

end.
