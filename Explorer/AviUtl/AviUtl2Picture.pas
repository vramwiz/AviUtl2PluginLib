unit AviUtl2Picture;

interface

uses
  ExplorerListPicture;

function AviUtl2PictureDandD(Picture : TExplorerFilePicturelItem): string;


implementation

uses AliasManager,AviUtl2TimeConvert,AliasManagerObjectPicture,SoundFileUtils;


function AviUtl2PictureDandD(Picture : TExplorerFilePicturelItem): string;
var
  len,ms : Integer;
  Convert : Double;
  Item : TAliasManagerObjectPicture;
begin
  Result := '';

  Convert := AviUtl2Convert();
  GAliasManager.ObjectName := '';
  GAliasManager.Clear;

  ms := 0;
  len := 3;
  Item := GAliasManager.AddPicture(); //TAliasManagerObjectPicture(GAliasManager.Add('Picture'));
  Item.Picture := Picture;
  Item.Layer := 0;
  Item.FrameStart := Round(ms / Convert);
  Item.FrameLength := Round(len / Convert);

  GAliasManager.SaveToAlias();
  Result := GAliasManager.FileName;
end;

end.
