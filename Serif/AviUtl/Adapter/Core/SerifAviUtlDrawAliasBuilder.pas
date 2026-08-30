unit SerifAviUtlDrawAliasBuilder;

// 製品別の表示エフェクト名を使い、共通SerifDrawの新規オブジェクトを生成する。

interface

function BuildDefaultSerifDrawAlias(const FilterObjectName,
  SerifDrawEffectName: string): string;
// SDK取得形式の数値オブジェクト番号をシェルD&D用の[Object]系へ変換する。
function NormalizeSerifDrawDragAlias(const AliasText: string): string;

implementation

uses
  System.Classes,
  System.StrUtils,
  System.SysUtils;

const
  ITEM_SETTINGS = #$8A2D#$5B9A;
  ITEM_TEXT_PARAMETER = #$30C6#$30AD#$30B9#$30C8#$30D1#$30E9#$30E1#$30FC#$30BF + '1';
  DEFAULT_TEXT_PARAMETER =
    'SD2;fs=160;ow=16;ob=0;fc=FFFFFFFF;oc=FF247EFF;bc=FF247EFF;' +
    'fn=597520476F74686963205549;st=1;se=0;sx=10;sy=10;sb=4;ss=0;' +
    'sc=A0000000;ls=0;cs=0;al=1;op=255;pl=4;x=-5.236;y=384;' +
    'layers=7,77.091,16,FFFFFFFF,FF247EFF,597520476F74686963205549,' +
    '1,1,32.691,36.182,4,0,A0000000,0,0,1,0,255,FF247EFF/' +
    '9,160,16,FFFFFFFF,FF56A70A,597520476F74686963205549,1,0,10,' +
    '10,4,0,A0000000,0,0,1,0,255,FF7FF213';

function BuildDefaultSerifDrawAlias(const FilterObjectName,
  SerifDrawEffectName: string): string;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    // シェルD&DでAviUtl2へ渡す.object形式はObjectセクションを使う。
    // [0]形式はSDKの直接生成では受理されるが、ファイルD&Dでは生成されない。
    Lines.Add('[Object]');
    Lines.Add('frame=136,163');
    Lines.Add('[Object.0]');
    Lines.Add('effect.name=' + FilterObjectName);
    Lines.Add('[Object.1]');
    Lines.Add('effect.name=' + SerifDrawEffectName);
    Lines.Add(ITEM_SETTINGS + '=');
    Lines.Add(ITEM_TEXT_PARAMETER + '=' + DEFAULT_TEXT_PARAMETER);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function NormalizeSerifDrawDragAlias(const AliasText: string): string;
var
  Index: Integer;
  Lines: TStringList;
  ObjectIndex: Integer;
  ObjectPrefix: string;
  SectionName: string;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AliasText;
    ObjectPrefix := '';
    for Index := 0 to Lines.Count - 1 do
    begin
      SectionName := Trim(Lines[Index]);
      if (Length(SectionName) < 3) or (SectionName[1] <> '[') or
         (SectionName[Length(SectionName)] <> ']') then
        Continue;
      SectionName := Copy(SectionName, 2, Length(SectionName) - 2);
      if (Pos('.', SectionName) = 0) and
         TryStrToInt(SectionName, ObjectIndex) and (ObjectIndex >= 0) then
      begin
        ObjectPrefix := SectionName;
        Break;
      end;
    end;

    if ObjectPrefix <> '' then
      for Index := 0 to Lines.Count - 1 do
        if SameText(Trim(Lines[Index]), '[' + ObjectPrefix + ']') then
          Lines[Index] := '[Object]'
        else if StartsText('[' + ObjectPrefix + '.', Trim(Lines[Index])) then
          Lines[Index] := '[Object.' + Copy(Trim(Lines[Index]),
            Length(ObjectPrefix) + 3, MaxInt);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
