program SerifDrawOverlapTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  SharedMemoryBase in 'Lib\SharedMemory\SharedMemoryBase.pas',
  SerifSharedIndex in 'Lib\SharedMemory\SerifSharedIndex.pas',
  KeyValueText in 'Lib\KeyValue\KeyValueText.pas',
  PluginFilterSerifDrawRoleNames in
    'Serif\Plugin\Draw\Display\PluginFilterSerifDrawRoleNames.pas',
  PluginFilterSerifDrawOverlap in
    'Serif\Plugin\Draw\Display\PluginFilterSerifDrawOverlap.pas',
  PluginFilterSerifDrawReceiver in
    'Serif\Plugin\Draw\PluginFilterSerifDrawReceiver.pas';

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function Snapshot(const ASerif, ARoleName: string): TSerifDrawSnapshot;
begin
  Result := System.Default(TSerifDrawSnapshot);
  Result.Serif := ASerif;
  Result.Chara := ARoleName;
end;

var
  BandBottom: Integer;
  BandTop: Integer;
  Indices: TArray<Integer>;
  Snapshots: TArray<TSerifDrawSnapshot>;
begin
  Snapshots := [Snapshot('same', 'Role A'), Snapshot('same', 'Role B'),
    Snapshot('same', 'Role C')];
  Indices := SelectSerifDrawVisibleSnapshotIndices(Snapshots);
  Require((Length(Indices) = 3) and (Indices[0] = 0) and
    (Indices[1] = 1) and (Indices[2] = 2),
    'Identical serif text did not select every role in send order.');

  Snapshots := [Snapshot('same', 'Role A'), Snapshot('same', 'Role B'),
    Snapshot('same', 'Role A')];
  Indices := SelectSerifDrawVisibleSnapshotIndices(Snapshots);
  Require((Length(Indices) = 2) and (Indices[0] = 1) and
    (Indices[1] = 2),
    'A duplicate role did not retain only its latest snapshot.');

  Snapshots := [Snapshot('old', 'Role A'), Snapshot('new', 'Role B')];
  Indices := SelectSerifDrawVisibleSnapshotIndices(Snapshots);
  Require((Length(Indices) = 1) and (Indices[0] = 1),
    'Different serif text did not select only the latest snapshot.');

  Snapshots := [Snapshot('same', 'Role A'), Snapshot('same ', 'Role B')];
  Indices := SelectSerifDrawVisibleSnapshotIndices(Snapshots);
  Require((Length(Indices) = 1) and (Indices[0] = 1),
    'Whitespace differences must not be treated as identical serif text.');

  Require(SerifDrawRoleNameDisplayText(1, 'Role A') = 'Role A',
    'A single role must retain its role name.');
  Require(SerifDrawRoleNameDisplayText(2, 'Role B') = '2' + #$4EBA,
    'Two visible roles must be displayed as a person count.');
  Require(SerifDrawRoleNameDisplayText(3, 'Role C') = '3' + #$4EBA,
    'Three visible roles must be displayed as a person count.');

  SerifDrawSplitBand(10, 0, 3, BandTop, BandBottom);
  Require((BandTop = 0) and (BandBottom = 3),
    'First split band mismatch.');
  SerifDrawSplitBand(10, 1, 3, BandTop, BandBottom);
  Require((BandTop = 3) and (BandBottom = 6),
    'Middle split band mismatch.');
  SerifDrawSplitBand(10, 2, 3, BandTop, BandBottom);
  Require((BandTop = 6) and (BandBottom = 10),
    'Last split band mismatch.');

  Writeln('SerifDraw overlap tests passed.');
end.
