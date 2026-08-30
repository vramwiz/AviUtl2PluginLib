program SerifDrawReceiverIndexTest;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  Winapi.Windows,
  SharedMemoryBase in 'Lib\SharedMemory\SharedMemoryBase.pas',
  SerifSharedIndex in 'Lib\SharedMemory\SerifSharedIndex.pas',
  PluginFilterSerifDrawReceiver in
    'Serif\Plugin\Draw\PluginFilterSerifDrawReceiver.pas';

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function MakeIndexRecord(const ALayer: Integer; const AChara,
  ASerif: string): TSerifIndexRecord;
begin
  Result := System.Default(TSerifIndexRecord);
  Result.Layer := ALayer;
  Result.Chara := AChara;
  Result.Serif := ASerif;
end;

var
  Header: TSerifIndexHeader;
  History: TSharedMemoryStringList;
  Index: TSharedMemoryStringList;
  Receiver: TSerifDrawReceiver;
  Snapshots: TArray<TSerifDrawSnapshot>;
  Talk: TSharedMemoryStringList;
begin
  Talk := TSharedMemoryStringList.Create('Local\ShareTalk', 100, 4000);
  Index := TSharedMemoryStringList.Create(SERIF_INDEX_SHARED_NAME,
    SERIF_INDEX_MAX_RECORDS + 1, SERIF_INDEX_MAX_TEXT_LENGTH);
  History := TSharedMemoryStringList.Create(SERIF_HISTORY_SHARED_NAME,
    SERIF_INDEX_MAX_RECORDS + 1, SERIF_INDEX_MAX_TEXT_LENGTH);
  Receiver := TSerifDrawReceiver.Create;
  try
    Talk.Strings[7] :=
      'uid=u7;source_object=o7;current_frame=100;serif=layer seven;' +
      'chara=role7;emote=happy;direction=left;speech_progress=0.25;' +
      'speech_active=1;frame=4;total_frames=20;';
    Talk.Strings[12] :=
      'uid=u12;source_object=o12;current_frame=100;serif=layer twelve;' +
      'chara=role12;emote=sad;direction=right;';
    Talk.Strings[99] :=
      'uid=u99;source_object=o99;current_frame=100;serif=must not appear;';

    Header.CurrentFrame := 100;
    Header.Count := 2;
    Header.Generation := 1;
    Header.PublishedTick := GetTickCount64;
    Header.Ready := False;
    Index.Strings[0] := EncodeSerifIndexHeader(Header);
    Index.Strings[1] := EncodeSerifIndexRecord(
      MakeIndexRecord(7, 'role7', 'layer seven'));
    Index.Strings[2] := EncodeSerifIndexRecord(
      MakeIndexRecord(12, 'role12', 'layer twelve'));
    Header.Ready := True;
    Index.Strings[0] := EncodeSerifIndexHeader(Header);

    Snapshots := Receiver.ReadActive(100);
    Require(Length(Snapshots) = 2, 'Indexed snapshot count mismatch.');
    Require((Snapshots[0].Layer = 7) and
      (Snapshots[0].Chara = 'role7') and
      (Snapshots[0].Emote = 'happy') and
      (Snapshots[0].Direction = 'left') and
      (Abs(Snapshots[0].SpeechProgress - 0.25) < 0.000001) and
      Snapshots[0].SpeechActive and (Snapshots[0].TimelineFrame = 4) and
      (Snapshots[0].TimelineTotalFrames = 20),
      'Layer 7 metadata mismatch.');
    Require((Snapshots[1].Layer = 12) and
      (Snapshots[1].Chara = 'role12'), 'Layer 12 metadata mismatch.');
    Require(Snapshots[High(Snapshots)].Layer = 12,
      'The latest active serif must be the last snapshot.');

    Snapshots := Receiver.ReadActive(101);
    Require(Length(Snapshots) = 0,
      'A stale index frame was accepted.');

    Header.CurrentFrame := 100;
    Header.PublishedTick := GetTickCount64 -
      (SERIF_INDEX_ACTIVE_MAX_AGE_MS + 1);
    Index.Strings[0] := EncodeSerifIndexHeader(Header);
    Snapshots := Receiver.ReadActive(100);
    Require(Length(Snapshots) = 0,
      'An expired index from another scene was accepted.');

    Header.CurrentFrame := 101;
    Header.Count := 2;
    Header.Generation := 2;
    Header.PublishedTick := GetTickCount64;
    Header.Ready := False;
    History.Strings[0] := EncodeSerifIndexHeader(Header);
    History.Strings[1] := EncodeSerifIndexRecord(
      MakeIndexRecord(12, 'role12', 'old layer twelve'));
    History.Strings[2] := EncodeSerifIndexRecord(
      MakeIndexRecord(7, 'updated role7', 'latest layer seven'));
    Header.Ready := True;
    History.Strings[0] := EncodeSerifIndexHeader(Header);
    Snapshots := Receiver.ReadHistory;
    Require(Length(Snapshots) = 2, 'History snapshot count mismatch.');
    Require((Snapshots[0].Layer = 7) and
      (Snapshots[0].Chara = 'updated role7') and
      (Snapshots[0].Serif = 'latest layer seven'),
      'The most recently sent history layer was not first.');
    Require(Snapshots[1].Layer = 12,
      'Previously seen history layer was not retained.');
    Writeln('SerifDraw indexed receiver tests passed.');
  finally
    Receiver.Free;
    History.Free;
    Index.Free;
    Talk.Free;
  end;
end.
