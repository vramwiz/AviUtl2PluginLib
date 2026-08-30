program SerifDrawRoleNamesTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  PluginFilterSerifDrawRoleNames in
    'Serif\Plugin\Draw\Display\PluginFilterSerifDrawRoleNames.pas';

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

const
  METAN: UnicodeString = #$3081#$305F#$3093;
  SHIKOKU: UnicodeString = #$56DB#$56FD;
  ZUNDAMON: UnicodeString = #$305A#$3093#$3060#$3082#$3093;

begin
  Require(SerifDrawRoleNameKey('  Alice  ') = 'alice',
    'Outer spaces and case must not distinguish role names.');
  Require(SerifDrawRoleNameKey('Alice' + #9 + #13#10 + 'Smith') =
    'alice smith', 'Consecutive whitespace must collapse.');
  Require(SerifDrawRoleNameKey(SHIKOKU + #$3000 + METAN) =
    SerifDrawRoleNameKey(SHIKOKU + ' ' + METAN),
    'Full-width and regular spaces must compare equally.');
  Require(SerifDrawRoleNameKey('  ' + #$3000) = '',
    'Whitespace-only role names must be empty.');
  Require(SerifDrawRoleNameKey(SHIKOKU + METAN) <>
    SerifDrawRoleNameKey(ZUNDAMON),
    'Different role names must remain distinct.');
  Require(SerifDrawRoleNameViewportOffset(Rect(-10, 20, 80, 50),
    100, 100, 4) = Point(14, 0),
    'A left overflow must move inside the margin.');
  Require(SerifDrawRoleNameViewportOffset(Rect(20, 20, 110, 50),
    100, 100, 4) = Point(-14, 0),
    'A right overflow must move inside the margin.');
  Require(SerifDrawRoleNameViewportOffset(Rect(10, 80, 40, 110),
    100, 100, 4) = Point(0, -14),
    'A bottom overflow must move inside the margin.');
  Require(SerifDrawRoleNameViewportOffset(Rect(-50, 10, 150, 30),
    100, 100, 4) = Point(0, 0),
    'An oversized group must be centered without changing its layout.');
  Writeln('SerifDraw role name tests passed.');
end.
