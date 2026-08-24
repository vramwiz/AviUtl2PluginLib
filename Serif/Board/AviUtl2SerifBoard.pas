unit AviUtl2SerifBoard;

interface

// ピアノロールエリアス生成
function AviUtl2SerifBoardSend(
                              Layer : Integer;                // 生成するレイヤー 0～
                              FileName : string;              // 画像ファイル名
                              Enable : Boolean;               // True:セリフに連動して表示
                              RefLayer : Integer;             // 参照するレイヤー
                              Hold : Integer;                 // 表示維持フレーム
                              Fade : Integer;                 // フェードフレーム
                              Send : Boolean                  // True:送信 False;D&D用
                            ) : string;                       // D&Dで返すファイル名


implementation

uses AliasManager,AviUtl2TimeConvert,AliasManagerObjectPicture,SoundFileUtils;

function AviUtl2SerifBoardSend(Layer : Integer;FileName : string;Enable : Boolean;RefLayer, Hold, Fade : Integer;Send : Boolean  ) : string;
var
  len,ms : Integer;
  Convert : Double;
  Item : TAliasManagerObjectPictureFile;
begin
  Result := '';

  Convert := AviUtl2Convert();
  GAliasManager.ObjectName := '';
  GAliasManager.Clear;

  ms := 0;
  len := 3;
  Item := GAliasManager.AddPictureFile();
  Item.Layer := 0;

  Item.PictureFileName := FileName;
  Item.EnableScript    := Enable;
  Item.RefLayer := RefLayer;
  Item.Hold := Hold;
  Item.Fade := Fade;

  Item.FrameStart := Round(ms / Convert);
  Item.FrameLength := Round(len / Convert);


  GAliasManager.SaveToAlias();
  Result := GAliasManager.FileName;
end;


end.
