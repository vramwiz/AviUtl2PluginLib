unit PluginFilterSerifDrawLegacyPalette;

// 旧Serif Boardの配色値を、旧拡張へ依存せず現行枠から参照できる形で保持する。

interface

type
  TSerifDrawLegacyPalette = record
    // すべてAARRGGBB。Pastelは淡色・基本色・濃色、Neonは外線・内線の順。
    PastelLight: Cardinal;
    PastelBase: Cardinal;
    PastelDark: Cardinal;
    NeonDark: Cardinal;
    NeonBase: Cardinal;
  end;

const
  SERIF_DRAW_LEGACY_PALETTE_COUNT = 10;

// 0始まりの旧配色番号をARGB配色へ変換する。範囲外は先頭配色を返す。
function SerifDrawLegacyPalette(const AIndex: Integer):
  TSerifDrawLegacyPalette;

implementation

const
  LEGACY_PALETTES: array[0..SERIF_DRAW_LEGACY_PALETTE_COUNT - 1] of
    TSerifDrawLegacyPalette = (
    (PastelLight: $FFF8D6D6; PastelBase: $FFF2A7A7;
      PastelDark: $FFD97C7C; NeonDark: $FFB00000; NeonBase: $FFFF0000),
    (PastelLight: $FFF8E2D2; PastelBase: $FFF2C29B;
      PastelDark: $FFD99A6B; NeonDark: $FFD06000; NeonBase: $FFFF8000),
    (PastelLight: $FFF8F1D2; PastelBase: $FFF2E39B;
      PastelDark: $FFD9C96A; NeonDark: $FFC8C800; NeonBase: $FFFFFF00),
    (PastelLight: $FFEDF6D2; PastelBase: $FFCBE69B;
      PastelDark: $FFA9C96A; NeonDark: $FF50B000; NeonBase: $FF80FF00),
    (PastelLight: $FFDDF4E5; PastelBase: $FFAEE5C5;
      PastelDark: $FF7BC89A; NeonDark: $FF00B000; NeonBase: $FF00FF00),
    (PastelLight: $FFD9F4F6; PastelBase: $FFA9E3E8;
      PastelDark: $FF75C5CC; NeonDark: $FF00B0B0; NeonBase: $FF00FFFF),
    (PastelLight: $FFDCE7FF; PastelBase: $FFAFCBFF;
      PastelDark: $FF7FA3E6; NeonDark: $FF0060B0; NeonBase: $FF0080FF),
    (PastelLight: $FFE7DDFB; PastelBase: $FFC7B5F5;
      PastelDark: $FF9D88D9; NeonDark: $FFB000B0; NeonBase: $FFFF00FF),
    (PastelLight: $FFF9DDED; PastelBase: $FFF3B6D8;
      PastelDark: $FFD98CB8; NeonDark: $FFB00080; NeonBase: $FF8000FF),
    (PastelLight: $FFE0E0E0; PastelBase: $FFC0C0C0;
      PastelDark: $FF707070; NeonDark: $FFA0A0A0; NeonBase: $FFFFFFFF)
  );

function SerifDrawLegacyPalette(const AIndex: Integer):
  TSerifDrawLegacyPalette;
begin
  if (AIndex < Low(LEGACY_PALETTES)) or
    (AIndex > High(LEGACY_PALETTES)) then
    Exit(LEGACY_PALETTES[0]);
  Result := LEGACY_PALETTES[AIndex];
end;

end.
