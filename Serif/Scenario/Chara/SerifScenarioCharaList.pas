unit SerifScenarioCharaList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,RTTIPersistentIni;

type
  TSerifScenarioCharaItem = class(TRTTIPersistentIni)
  private
    { Private 宣言 }
    FName    : string;   // このシナリオで使用する配役（キャラ）の名前
    FKey     : string;   // 配役に割り当てる 1 文字キー（操作用ショートカット）
    FEnabled : Boolean;  // この配役がシナリオ上で有効かどうか
    FColor   : TColor;   // 配役の背景色（Name列に使用）
  public
    { Public 宣言 }
    constructor Create();
  published
    property Name    : string  read FName    write FName;
    property Key     : string  read FKey     write FKey;
    property Enabled : Boolean read FEnabled write FEnabled;
    property Color   : TColor read FColor   write FColor;
 end;

  TSerifScenarioCharaList = class(TRTTIPersistentIniList<TSerifScenarioCharaItem>)
  private
    function GetCharas(Index: Integer): TSerifScenarioCharaItem;
  public
    // リストから指定したキーに一致するを設定なしにする
    procedure DeleteValueKey(const AKey : string);
    property Charas[Index : Integer] : TSerifScenarioCharaItem read GetCharas;
  end;

implementation

{ TSerifScenarioCharaList }

procedure TSerifScenarioCharaList.DeleteValueKey(const AKey: string);
var
  i : Integer;
begin
  for i := 0 to Count-1 do begin
    if Items[i].FKey = AKey then Items[i].FKey := '';
  end;
end;

function TSerifScenarioCharaList.GetCharas(  Index: Integer): TSerifScenarioCharaItem;
begin
  Result := TSerifScenarioCharaItem(inherited Items[Index]);
end;

{ TSerifScenarioCharaItem }

constructor TSerifScenarioCharaItem.Create;
begin
  FColor := clWhite;
end;

end.
