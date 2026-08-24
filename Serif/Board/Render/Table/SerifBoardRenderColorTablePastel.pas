unit SerifBoardRenderColorTablePastel;

interface

uses
  Vcl.Graphics;

type
  TSerifBoardPastelColor = record
    Name: string;
    LightColor: TColor;
    BaseColor: TColor;
    DarkColor: TColor;
    IsBackgroundDependent: Boolean;
  end;

const
  SerifBoardPastelColors: array[0..9] of TSerifBoardPastelColor = (
    (Name: '赤';   LightColor: $00D6D6F8; BaseColor: $00A7A7F2; DarkColor: $007C7CD9; IsBackgroundDependent: False),
    (Name: '橙';   LightColor: $00D2E2F8; BaseColor: $009BC2F2; DarkColor: $006B9AD9; IsBackgroundDependent: False),
    (Name: '黄';   LightColor: $00D2F1F8; BaseColor: $009BE3F2; DarkColor: $006AC9D9; IsBackgroundDependent: False),
    (Name: '黄緑'; LightColor: $00D2F6ED; BaseColor: $009BE6CB; DarkColor: $006AC9A9; IsBackgroundDependent: False),
    (Name: '緑';   LightColor: $00E5F4DD; BaseColor: $00C5E5AE; DarkColor: $009AC87B; IsBackgroundDependent: False),
    (Name: '水';   LightColor: $00F6F4D9; BaseColor: $00E8E3A9; DarkColor: $00CCC575; IsBackgroundDependent: False),
    (Name: '青';   LightColor: $00FFE7DC; BaseColor: $00FFCBAF; DarkColor: $00E6A37F; IsBackgroundDependent: False),
    (Name: '紫';   LightColor: $00FBDDE7; BaseColor: $00F5B5C7; DarkColor: $00D9889D; IsBackgroundDependent: False),
    (Name: '桃';   LightColor: $00EDDDF9; BaseColor: $00D8B6F3; DarkColor: $00B88CD9; IsBackgroundDependent: False),
    // この描画では白カードの縁と影に相当するため、反転はモノトーンで扱う
    (Name: '反転'; LightColor: $00E0E0E0; BaseColor: $00C0C0C0; DarkColor: $00707070; IsBackgroundDependent: True)
  );

implementation

end.
