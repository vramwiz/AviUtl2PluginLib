program SerifDrawFontResolutionTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Vcl.Forms,
  TextRendererTypes in 'Lib\TextRenderer\TextRendererTypes.pas',
  TextRenderer in 'Lib\TextRenderer\TextRenderer.pas',
  TextRendererSkiaRuntime in 'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  TextRendererSkia in 'Lib\TextRenderer\TextRendererSkia.pas';

var
  FamilyName: string;
  I: Integer;
  SupportedCount: Integer;
begin
  TTextRendererSkiaRuntime.Acquire(
    'Serif\Plugin\Draw\Tests\sk4d.dll');
  try
    SupportedCount := 0;
    for I := 0 to Screen.Fonts.Count - 1 do
    begin
      FamilyName := Screen.Fonts[I];
      if (FamilyName <> '') and (FamilyName[1] <> '@') and
        TSkiaTextRenderer.IsFontFamilyAvailable(FamilyName) then
        Inc(SupportedCount);
    end;
    if TSkiaTextRenderer.IsFontFamilyAvailable(
      '__Syncroh2_missing_font__') then
      raise Exception.Create('Missing font was reported as available.');
    if not TSkiaTextRenderer.IsFontFamilyAvailable('Yu Gothic UI') then
      raise Exception.Create('Yu Gothic UI was not resolved.');
    if SupportedCount <= 0 then
      raise Exception.Create('No supported fonts were found.');
    Writeln(Format('SerifDraw font resolution test passed: fonts=%d supported=%d',
      [Screen.Fonts.Count, SupportedCount]));
  finally
    TTextRendererSkiaRuntime.Release;
  end;
end.
