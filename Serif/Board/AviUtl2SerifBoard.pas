unit AviUtl2SerifBoard;

interface

// セリフボード画像のD&D用エイリアスを生成する。
// LayerとSendは従来API互換のため保持し、既存どおり生成値には使用しない。
function AviUtl2SerifBoardSend(Layer: Integer; FileName: string;
  Enable: Boolean; RefLayer, Hold, Fade: Integer; Send: Boolean): string;

implementation

uses
  AviUtl2TimeConvert,
  SerifAviUtlAliasProvider;

function AviUtl2SerifBoardSend(Layer: Integer; FileName: string;
  Enable: Boolean; RefLayer, Hold, Fade: Integer; Send: Boolean): string;
var
  AliasData: TSerifAviUtlBoardAliasData;
  Convert: Double;
begin
  Convert := AviUtl2Convert;
  AliasData := Default(TSerifAviUtlBoardAliasData);
  AliasData.FileName := FileName;
  AliasData.EnableScript := Enable;
  AliasData.RefLayer := RefLayer;
  AliasData.Hold := Hold;
  AliasData.Fade := Fade;
  AliasData.Layer := 0;
  AliasData.FrameStart := 0;
  AliasData.FrameLength := Round(3 / Convert);
  Result := CreateSerifAviUtlBoardAlias(AliasData);
end;

end.
