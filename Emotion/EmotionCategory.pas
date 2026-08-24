unit EmotionCategory;

interface

// 音声アプリ等から届く感情プリセット名を共通の喜怒哀楽へ正規化する。
// UIやPSDに依存しないため、SerifDrawとPSDDrawの両方から利用できる。

type
  TEmotionCategory = (
    ecUnknown,
    ecNormal,
    ecJoy,
    ecAnger,
    ecSorrow,
    ecFun
  );

function ResolveEmotionCategory(const APresetName: string):
  TEmotionCategory;
function EmotionCategoryName(const ACategory: TEmotionCategory): string;

implementation

uses
  System.StrUtils,
  System.SysUtils;

const
  NORMAL_KEYWORDS =
    #$30CE#$30FC#$30DE#$30EB','#$6A19#$6E96','#$3075#$3064#$3046;
  JOY_KEYWORDS =
    #$559C','#$559C#$3073','#$3042#$307E#$3042#$307E',' +
    #$308F#$30FC#$3044','#$5143#$6C17;
  ANGER_KEYWORDS =
    #$6012','#$6012#$308A','#$304A#$3053',' +
    #$30C4#$30F3#$30C4#$30F3','#$30C4#$30F3#$30AE#$30EC',' +
    #$71B1#$8840','#$4E0D#$6A5F#$5ACC','#$3064#$3088#$3064#$3088;
  SORROW_KEYWORDS =
    #$54C0','#$60B2#$3057#$307F','#$304B#$306A#$3057#$307F',' +
    #$304B#$306A#$3057#$3044','#$54C0#$3057#$307F','#$6CE3#$304D',' +
    #$3073#$3048#$30FC#$3093','#$306A#$307F#$3060#$3081',' +
    #$3073#$304F#$3073#$304F','#$3053#$308F#$304C#$308A',' +
    #$6050#$6016','#$304A#$3069#$308D#$304D;
  FUN_KEYWORDS =
    #$3046#$304D#$3046#$304D','#$305F#$306E#$3057#$3044',' +
    #$697D','#$697D#$3005;

function MatchesKeyword(const AValue, AKeywords: string): Boolean;
var
  ItemEnd: Integer;
  ItemStart: Integer;
  Token: string;
begin
  Result := False;
  if Trim(AValue) = '' then
    Exit;
  ItemStart := 1;
  while ItemStart <= Length(AKeywords) do
  begin
    ItemEnd := ItemStart;
    while (ItemEnd <= Length(AKeywords)) and
      (AKeywords[ItemEnd] <> ',') do
      Inc(ItemEnd);
    Token := Trim(Copy(AKeywords, ItemStart, ItemEnd - ItemStart));
    if (Token <> '') and ContainsText(AValue, Token) then
      Exit(True);
    ItemStart := ItemEnd + 1;
  end;
end;

function ResolveEmotionCategory(const APresetName: string):
  TEmotionCategory;
var
  PresetName: string;
begin
  PresetName := Trim(APresetName);
  if MatchesKeyword(PresetName, NORMAL_KEYWORDS) then
    Exit(ecNormal);
  if MatchesKeyword(PresetName, ANGER_KEYWORDS) then
    Exit(ecAnger);
  if MatchesKeyword(PresetName, SORROW_KEYWORDS) then
    Exit(ecSorrow);
  if MatchesKeyword(PresetName, FUN_KEYWORDS) then
    Exit(ecFun);
  if MatchesKeyword(PresetName, JOY_KEYWORDS) then
    Exit(ecJoy);
  Result := ecUnknown;
end;

function EmotionCategoryName(const ACategory: TEmotionCategory): string;
begin
  case ACategory of
    ecNormal:
      Result := #$901A#$5E38;
    ecJoy:
      Result := #$559C;
    ecAnger:
      Result := #$6012;
    ecSorrow:
      Result := #$54C0;
    ecFun:
      Result := #$697D;
  else
    Result := '';
  end;
end;

end.
