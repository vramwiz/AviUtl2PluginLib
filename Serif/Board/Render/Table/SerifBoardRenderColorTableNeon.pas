unit SerifBoardRenderColorTableNeon;

interface

uses
  Vcl.Graphics;

type
  TSerifBoardNeonColor = record
    Name: string;
    DarkColor: TColor;
    BaseColor: TColor;
  end;

const
  SerifBoardNeonColors: array[0..9] of TSerifBoardNeonColor = (
    (Name: '赤';   DarkColor: $000000B0; BaseColor: $000000FF),
    (Name: '橙';   DarkColor: $000060D0; BaseColor: $000080FF),
    (Name: '黄';   DarkColor: $0000C8C8; BaseColor: $0000FFFF),
    (Name: '黄緑'; DarkColor: $0000B050; BaseColor: $0000FF80),
    (Name: '緑';   DarkColor: $0000B000; BaseColor: $0000FF00),
    (Name: '水';   DarkColor: $00B0B000; BaseColor: $00FFFF00),
    (Name: '青';   DarkColor: $00B06000; BaseColor: $00FF8000),
    (Name: '紫';   DarkColor: $00B000B0; BaseColor: $00FF00FF),
    (Name: '桃';   DarkColor: $008000B0; BaseColor: $00FF0080),
    (Name: '白';   DarkColor: $00A0A0A0; BaseColor: $00FFFFFF)
  );

implementation

end.
