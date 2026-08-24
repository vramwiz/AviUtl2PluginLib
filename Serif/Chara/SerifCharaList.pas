unit SerifCharaList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,RTTIPersistentIni;

//--------------------------------------------------------------------------//
//  セリフとキャラを関連付けデータ管理するクラス                            //
//--------------------------------------------------------------------------//
type
  TSerifCharaItem = class(TRTTIPersistentIni)
  private
    { Private 宣言 }
    FKeyword    : string;            // セリフに含まれるキャラ名
    FColorFont  : TColor;            // テキスト表示色
    FColorLight : TColor;            // イメージカラー（明るい色）
    FColorBase  : TColor;            // イメージカラー（基本色）
    FColorDark  : TColor;            // イメージカラー（暗い色）
    FLayerSerif : Integer;           // セリフのレイヤー
    FLayerWave  : Integer;           // 音声のレイヤー
    FName       : string;            // セリフ指定用のキャラ名
    FEmotion:    string;             // 感情
    FVolume    : Double;             // 音量
    FPan       : Double;             // 位置
    procedure SetColorBack(const Value: TColor);
    procedure SetColorBase(const Value: TColor);
  public
    { Public 宣言 }
    constructor Create();
    destructor Destroy;override;
    function IsMatch(const S: string): Boolean;
    procedure SetImageColors(const LightColor, BaseColor, DarkColor: TColor);

 published
    property Name       : string read FName    write FName;
    property Keyword    : string read FKeyword write FKeyword;
    property Emotion    : string read FEmotion write FEmotion;

    property LayerSerif : Integer read FLayerSerif write FLayerSerif;
    property LayerWave  : Integer read FLayerWave write FLayerWave;

    property ColorFont  : TColor read FColorFont write FColorFont;
    property ColorBack  : TColor read FColorBase write SetColorBack;  // 既存互換: 背景色は Base として扱う
    property ColorLight : TColor read FColorLight write FColorLight;
    property ColorBase  : TColor read FColorBase write SetColorBase;
    property ColorDark  : TColor read FColorDark write FColorDark;

    property Volume     : Double read FVolume   write FVolume;
    property Pan        : Double read FPan      write FPan;
  end;

  TSerifCharaList = class(TRTTIPersistentIniList<TSerifCharaItem>)
  private
    function GetCharas(Index: Integer): TSerifCharaItem;
  public
    function indexOfKeyword(const aKeywrod : string) : Integer;
    // 音声合成ソフトからのキャラ名を登録
    procedure AddChara(const aChara : string);
    property Charas[Index : Integer] : TSerifCharaItem read GetCharas;
  end;

implementation

{ TSerifCharaList }

procedure TSerifCharaList.AddChara(const aChara: string);
var
  Item : TSerifCharaItem;
begin
  Item := AddNew();
  Item.Name := aChara;
  Item.Keyword := aChara;
end;

function TSerifCharaList.GetCharas(Index: Integer): TSerifCharaItem;
begin
  Result := TSerifCharaItem(inherited Items[Index]);
end;

function TSerifCharaList.indexOfKeyword(const aKeywrod: string): Integer;
var
  i : Integer;
  NameText, KeywordText, SearchText: string;

  function NormalizeCharaKey(const S: string): string;
  begin
    Result := Trim(S);
    Result := Result.Replace(' ', '', [rfReplaceAll]);
    Result := Result.Replace('　', '', [rfReplaceAll]);
  end;
begin
  Result := -1;
  SearchText := NormalizeCharaKey(aKeywrod);
  if SearchText = '' then Exit;

  for i := 0 to Count-1 do begin
    // 棒読みちゃん対応: Keywordを受信キー、Nameを表示名としてどちらでも配役を引けるようにする。
    KeywordText := NormalizeCharaKey(Items[i].Keyword);
    NameText    := NormalizeCharaKey(Items[i].Name);
    if (not SameText(KeywordText, SearchText)) and
       (not SameText(NameText, SearchText)) then Continue;
    Result := i;
    Exit;
  end;

end;

{ TSerifCharaItem }

constructor TSerifCharaItem.Create;
begin
  FLayerWave := 1;
  FColorLight := clWhite;
  FColorBase  := clWhite;
  FColorDark  := clWhite;
  FVolume    := 100.00;
end;

destructor TSerifCharaItem.Destroy;
begin

  inherited;
end;

procedure TSerifCharaItem.SetColorBack(const Value: TColor);
begin
  // 3色化フェーズ2: 既存の ColorBack は Base 色へ接続する。
  SetColorBase(Value);
end;

procedure TSerifCharaItem.SetColorBase(const Value: TColor);
begin
  FColorBase := Value;
end;

procedure TSerifCharaItem.SetImageColors(const LightColor, BaseColor,
  DarkColor: TColor);
begin
  FColorLight := LightColor;
  FColorBase  := BaseColor;
  FColorDark  := DarkColor;
end;

function TSerifCharaItem.IsMatch(const S: string): Boolean;
var
  A, B: string;
begin
  // 元文字列をコピー
  A := FName;
  B := S;

  // 半角空白と全角空白を除去
  A := A.Replace(' ', '', [rfReplaceAll]);
  A := A.Replace('　', '', [rfReplaceAll]); // 全角スペース

  B := B.Replace(' ', '', [rfReplaceAll]);
  B := B.Replace('　', '', [rfReplaceAll]); // 全角スペース

  // 比較（大文字小文字はそのままでも SameText が安全）
  Result := SameText(A, B);
end;

end.
