unit AviUtl2Picture;

interface

uses
  ExplorerListPicture;

function AviUtl2PictureDandD(Picture: TExplorerFilePicturelItem): string;

implementation

uses
  AppFolderUtils,
  ExplorerAliasBuilder,
  ExplorerAviUtlBridge;

const
  TextPictureFile = #$753B#$50CF#$30D5#$30A1#$30A4#$30EB;
  TextFile = #$30D5#$30A1#$30A4#$30EB;
  TextDisplayNumber = #$8868#$793A#$756A#$53F7;
  TextSequenceFile = #$9023#$756A#$30D5#$30A1#$30A4#$30EB;
  TextVideoPlayback = #$6620#$50CF#$518D#$751F;
  TextCenter = #$4E2D#$5FC3;
  TextAxisRotation = #$8EF8#$56DE#$8EE2;
  TextScale = #$62E1#$5927#$7387;
  TextAspectRatio = #$7E26#$6A2A#$6BD4;
  TextOpacity = #$900F#$660E#$5EA6;
  TextBlendMode = #$5408#$6210#$30E2#$30FC#$30C9;

function AviUtl2PictureDandD(Picture: TExplorerFilePicturelItem): string;
var
  AliasBuilder: TExplorerAliasBuilder;
  FrameEnd: Integer;
begin
  Result := '';
  if Picture = nil then
    Exit;

  FrameEnd := Round(3 / ExplorerFrameDuration);
  Result := GetAppFolder('Temp') + 'Temp.object';
  AliasBuilder := TExplorerAliasBuilder.Create;
  try
    AliasBuilder.AddObject(0, 0, FrameEnd, []);
    AliasBuilder.AddFilter(TextPictureFile);
    AliasBuilder.AddValue(TextFile, Picture.FileName);
    AliasBuilder.AddValue(TextDisplayNumber, 0);
    AliasBuilder.AddValue(TextSequenceFile, 0);
    AliasBuilder.AddFilter(TextVideoPlayback);
    AliasBuilder.AddFloat('X', Picture.X, 2);
    AliasBuilder.AddFloat('Y', Picture.Y, 2);
    AliasBuilder.AddFloat('Z', Picture.Z, 2);
    AliasBuilder.AddValue('Group', Picture.Group);
    AliasBuilder.AddFloat(TextCenter + 'X', Picture.CenterX, 2);
    AliasBuilder.AddFloat(TextCenter + 'Y', Picture.CenterY, 2);
    AliasBuilder.AddFloat(TextCenter + 'Z', Picture.CenterZ, 2);
    AliasBuilder.AddFloat('X' + TextAxisRotation, Picture.RotateX, 2);
    AliasBuilder.AddFloat('Y' + TextAxisRotation, Picture.RotateY, 2);
    AliasBuilder.AddFloat('Z' + TextAxisRotation, Picture.RotateZ, 2);
    AliasBuilder.AddFloat(TextScale, Picture.Scale, 3);
    AliasBuilder.AddFloat(TextAspectRatio, Picture.AspectRatio, 3);
    AliasBuilder.AddFloat(TextOpacity, Picture.Transparent, 2);
    AliasBuilder.AddValue(TextBlendMode, Picture.BlendMode);
    AliasBuilder.SaveToFile(Result);
  finally
    AliasBuilder.Free;
  end;
end;

end.
