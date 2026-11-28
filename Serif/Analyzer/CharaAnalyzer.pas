unit CharaAnalyzer;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,StrUtils,FolderWatch,RTTIPersistentIni,
  SerifCharaList,System.IOUtils,SerifSceneMsgList;

type
  TSerifAnalyzerCharaItem = class(TRTTIPersistentIni)
  private
    { Private 宣言 }
    FName       : string;
    FColorLight : TColor;
    FColorBase  : TColor;
    FColorDark  : TColor;
  protected
  public
    function IsMatch(const S: string): Boolean;
  published
    property Name       : string read FName       write FName;
    property Color      : TColor read FColorBase  write FColorBase;  // 既存互換: 代表色は Base を返す
    property ColorLight : TColor read FColorLight write FColorLight;
    property ColorBase  : TColor read FColorBase  write FColorBase;
    property ColorDark  : TColor read FColorDark  write FColorDark;
  end;

{$I ..\Chara\SerifCharaColors.inc}

type

//--------------------------------------------------------------------------//
//   リストクラス                                                             //
//--------------------------------------------------------------------------//
  TSerifAnalyzerCharaList = class(TRTTIPersistentIniList<TSerifAnalyzerCharaItem>)
  private
    procedure AppendCharaTable(const A: array of TCharaDef);
    function GetCharas(Index: Integer): TSerifAnalyzerCharaItem;
  protected
  public
    constructor Create();
    function IndexOfChara(const Chara :string) : Integer;
    function TryGetCharaColor(const Name: string; out Color: TColor): Boolean;
    function TryGetCharaColors(const Name: string; out ColorLight, ColorBase, ColorDark: TColor): Boolean;
    function GetCharaColor(const Name: string): TColor;
    property Charas[Index : Integer] : TSerifAnalyzerCharaItem read GetCharas;
  end;


implementation


function HexToColor(const S: string): TColor;var R, G, B: Byte;
begin
  R := StrToInt('$' + Copy(S, 2, 2));
  G := StrToInt('$' + Copy(S, 4, 2));
  B := StrToInt('$' + Copy(S, 6, 2));
  Result := RGB(R, G, B);
end;

function MixByte(Value, Target: Byte; Amount: Double): Byte;
begin
  Result := Round(Value + ((Target - Value) * Amount));
end;

{
function MakeLightColor(Color: TColor): TColor;
var
  RGBColor: TColor;
begin
  RGBColor := ColorToRGB(Color);
  Result := RGB(
    MixByte(GetRValue(RGBColor), 255, 0.35),
    MixByte(GetGValue(RGBColor), 255, 0.35),
    MixByte(GetBValue(RGBColor), 255, 0.35)
  );
end;

function MakeDarkColor(Color: TColor): TColor;
var
  RGBColor: TColor;
begin
  RGBColor := ColorToRGB(Color);
  Result := RGB(
    MixByte(GetRValue(RGBColor), 0, 0.35),
    MixByte(GetGValue(RGBColor), 0, 0.35),
    MixByte(GetBValue(RGBColor), 0, 0.35)
  );
end;
}

function DefColorOrDefault(const HexColor: string; DefaultColor: TColor): TColor;
begin
  if Trim(HexColor) <> '' then
    Result := HexToColor(HexColor)
  else
    Result := DefaultColor;
end;


{ TSerifAnalyzerCharaList }

constructor TSerifAnalyzerCharaList.Create;
begin
  inherited;

  AppendCharaTable(SERIF_CHARA_COLOR_DEFS);
end;

procedure TSerifAnalyzerCharaList.AppendCharaTable(const A: array of TCharaDef);
var
  i: Integer;
  Chara: TSerifAnalyzerCharaItem;
begin
  for i := 0 to High(A) do
  begin
    Chara := AddNew();
    Chara.FName       := A[i].Name;
    Chara.FColorBase  := HexToColor(A[i].HexRGB);
    Chara.FColorLight  := HexToColor(A[i].HexLight);
    Chara.FColorDark  := HexToColor(A[i].HexDark);
    // 3色化フェーズ1: 未指定キャラは既存の代表色から Light/Dark を自動生成する。
    //Chara.FColorLight := DefColorOrDefault(A[i].HexLight, MakeLightColor(Chara.FColorBase));
    //Chara.FColorDark  := DefColorOrDefault(A[i].HexDark, MakeDarkColor(Chara.FColorBase));
  end;
end;




function TSerifAnalyzerCharaList.GetCharaColor(const Name: string): TColor;
begin
  if not TryGetCharaColor(Name, Result) then
    Result := clWhite;
end;

function TSerifAnalyzerCharaList.GetCharas(  Index: Integer): TSerifAnalyzerCharaItem;
begin
  Result := TSerifAnalyzerCharaItem(inherited Items[Index]);
end;

function TSerifAnalyzerCharaList.IndexOfChara(const Chara: string): Integer;
var
  i: Integer;
  Item: TSerifAnalyzerCharaItem;
begin
  Result := -1;
  for i := 0 to Count - 1 do
  begin
    Item := Charas[i];
    if Item.IsMatch(Chara) then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

function TSerifAnalyzerCharaList.TryGetCharaColor(const Name: string;
  out Color: TColor): Boolean;
var
  idx: Integer;
begin
  Result := False;
  idx := IndexOfChara(Name);
  if idx < 0 then Exit;

  // 定義が見つかった時だけ True を返す。clWhite も有効な定義色なので戻り値で判定する。
  Color := Charas[idx].Color;
  Result := True;
end;

function TSerifAnalyzerCharaList.TryGetCharaColors(const Name: string; out
  ColorLight, ColorBase, ColorDark: TColor): Boolean;
var
  idx: Integer;
  Chara: TSerifAnalyzerCharaItem;
begin
  Result := False;
  idx := IndexOfChara(Name);
  if idx < 0 then Exit;

  // 3色取得用。表示側の3色対応フェーズではこの API を使う。
  Chara := Charas[idx];
  ColorLight := Chara.ColorLight;
  ColorBase  := Chara.ColorBase;
  ColorDark  := Chara.ColorDark;
  Result := True;
end;

{ TSerifAnalyzerCharaItem }

function TSerifAnalyzerCharaItem.IsMatch(const S: string): Boolean;
var
  A, B: string;
begin
  // 固定キャラ名
  A := FName;
  // 入力文字列
  B := S;

  // 半角空白・全角空白を除去
  A := A.Replace(' ', '', [rfReplaceAll]).Replace('　', '', [rfReplaceAll]);
  B := B.Replace(' ', '', [rfReplaceAll]).Replace('　', '', [rfReplaceAll]);

  // 部分一致（ケース無視）
  Result := (Pos(LowerCase(A), LowerCase(B)) > 0);
end;


end.
