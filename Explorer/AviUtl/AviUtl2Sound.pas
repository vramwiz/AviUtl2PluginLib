unit AviUtl2Sound;

interface

uses
  ExplorerListSound,AliasManagerPositionList;

function AviUtl2SoundDandD(Sound : TExplorerFileSoundItem): string;

implementation

uses AliasManager,AviUtl2TimeConvert,AliasManagerObjectSound,SoundFileUtils,Math;


function AviUtl2SoundDandD(Sound : TExplorerFileSoundItem): string;
var
  Convert         : Double;   // 1フレームの秒数
  len, sec        : Double;   // 秒
  FadeInSec       : Double;   // 秒へ変換したフェード時間
  FadeOutSec      : Double;   // 秒へ変換したフェード時間
  Item            : TAliasManagerObjectSound;
  P               : TAliasManagerPositionItem;
begin
  Result := '';

  Convert := AviUtl2Convert();               // frame → sec
  GAliasManager.ObjectName := '';
  GAliasManager.Clear;

  sec := 0.0;
  len := GetSoundFileLengthSec(Sound.FileName);   // ★ 秒で取得されている前提

  // フェード値はミリ秒 → 秒へ変換（重要）
  FadeInSec  := Sound.FadeIn  / 1;
  FadeOutSec := Sound.FadeOut / 1;

  {--------------------------------------
    Sound オブジェクト作成
  --------------------------------------}
  Item := GAliasManager.AddSound(); // TAliasManagerObjectSound(GAliasManager.Add('Sound'));
  Item.Sound       := Sound;
  Item.Layer       := 0;
  Item.FrameStart  := Round(sec / Convert);
  Item.FrameLength := Ceil(len / Convert);     // 切り上げが自然

  {--------------------------------------
    フェードイン
  --------------------------------------}
  if (Sound.FadeMode = 1) or (Sound.FadeMode = 3) then
  begin
    P := Item.Positions.AddNew();
    P.Frame := Round(FadeInSec / Convert);
    if P.Frame > Item.FrameEnd then
      P.Frame := Item.FrameEnd;
  end;

  {--------------------------------------
    フェードアウト
  --------------------------------------}
  if (Sound.FadeMode = 2) or (Sound.FadeMode = 3) then
  begin
    P := Item.Positions.AddNew();
    P.Frame := Round((len - FadeOutSec) / Convert);
    if P.Frame < Item.FrameStart then
      P.Frame := Item.FrameStart;
  end;

  GAliasManager.SaveToAlias();
  Result := GAliasManager.FileName;
end;


end.
