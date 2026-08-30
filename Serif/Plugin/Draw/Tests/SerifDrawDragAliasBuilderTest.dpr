program SerifDrawDragAliasBuilderTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  SerifAviUtlDrawAliasBuilder in '..\..\..\AviUtl\Adapter\Core\SerifAviUtlDrawAliasBuilder.pas';

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  AliasText: string;
  LegacyRegisteredAlias: string;
  RegisteredAlias: string;
begin
  try
    AliasText := BuildDefaultSerifDrawAlias(
      #$30D5#$30A3#$30EB#$30BF#$30AA#$30D6#$30B8#$30A7#$30AF#$30C8,
      #$65B0#$65E7#$6717 + '2 ' + #$30BB#$30EA#$30D5#$8868#$793A);
    Check(Pos('[Object]', AliasText) > 0, 'Object section is missing');
    Check(Pos('[Object.0]', AliasText) > 0,
      'first effect section is missing');
    Check(Pos('[Object.1]', AliasText) > 0,
      'second effect section is missing');
    Check(Pos('[0]', AliasText) = 0, 'SDK section leaked into drag alias');
    Check(Pos('effect.name=' + #$65B0#$65E7#$6717 + '2 ' +
      #$30BB#$30EA#$30D5#$8868#$793A, AliasText) > 0,
      'Syncroh2 SerifDraw effect is missing');
    RegisteredAlias := NormalizeSerifDrawDragAlias(
      '[0]' + sLineBreak + '[0.0]' + sLineBreak +
      'effect.name=filter' + sLineBreak + '[0.1]' + sLineBreak +
      'effect.name=draw');
    Check(Pos('[Object]', RegisteredAlias) > 0,
      'registered root section was not normalized');
    Check(Pos('[Object.0]', RegisteredAlias) > 0,
      'registered first effect section was not normalized');
    Check(Pos('[Object.1]', RegisteredAlias) > 0,
      'registered second effect section was not normalized');
    Check(Pos('[0]', RegisteredAlias) = 0,
      'registered SDK root section remains');
    LegacyRegisteredAlias := NormalizeSerifDrawDragAlias(
      '[7]' + sLineBreak + 'layer=7' + sLineBreak +
      'frame=0,228' + sLineBreak + '[7.0]' + sLineBreak +
      'effect.name=filter' + sLineBreak + '[7.1]' + sLineBreak +
      'effect.name=draw');
    Check(Pos('[Object]', LegacyRegisteredAlias) > 0,
      'legacy root section was not normalized');
    Check(Pos('[Object.0]', LegacyRegisteredAlias) > 0,
      'legacy first effect section was not normalized');
    Check(Pos('[Object.1]', LegacyRegisteredAlias) > 0,
      'legacy second effect section was not normalized');
    Check(Pos('[7]', LegacyRegisteredAlias) = 0,
      'legacy numeric root section remains');
    Writeln('SerifDrawDragAliasBuilderTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('SerifDrawDragAliasBuilderTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
