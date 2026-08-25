unit WaveAnalyzer;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Math;

type
  TWaveVolumeItem = record
    Index: Integer;
    StartSec: Double;
    EndSec: Double;
    Start100ns: Int64;
    End100ns: Int64;
    RawVolume: Double;
    Volume: Integer;
  end;

  TWaveVolumeList = TList<TWaveVolumeItem>;

  TWaveAnalyzer = class
  private
    FItems: TWaveVolumeList;
    FIntervalSec: Double;
    FChannelIndex: Integer;
    FSilenceThreshold: Double;
    FNormalizeMax: Integer;
    FMaxRawVolume: Double;
    FSampleRate: Cardinal;
    FWaveLengthSec: Double;
    procedure Clear;
    procedure NormalizeItems;
    function VolumeToTalkStage(Volume: Integer): Integer;
    function ReadSample(const Buffer: TBytes; Offset: Integer; BitsPerSample: Word): Double;
  public
    constructor Create;
    destructor Destroy; override;

    function Analyze(const FileName: string): Boolean;
    procedure AddToLabLines(Lines: TStrings);

    property Items: TWaveVolumeList read FItems;
    property IntervalSec: Double read FIntervalSec write FIntervalSec;
    property ChannelIndex: Integer read FChannelIndex write FChannelIndex;
    property SilenceThreshold: Double read FSilenceThreshold write FSilenceThreshold;
    property NormalizeMax: Integer read FNormalizeMax write FNormalizeMax;
    property MaxRawVolume: Double read FMaxRawVolume;
    property SampleRate: Cardinal read FSampleRate;
    property WaveLengthSec: Double read FWaveLengthSec;
  end;

implementation

{$IFDEF DEBUG}
uses
  PSDImageDebugLog;
{$ENDIF}

type
  TWaveChunkID = array[0..3] of AnsiChar;

  TRiffHeader = packed record
    ChunkID: TWaveChunkID;
    ChunkSize: Cardinal;
    Format: TWaveChunkID;
  end;

  TChunkHeader = packed record
    ID: TWaveChunkID;
    Size: Cardinal;
  end;

  TFmtChunk = packed record
    AudioFormat: Word;
    NumChannels: Word;
    SampleRate: Cardinal;
    ByteRate: Cardinal;
    BlockAlign: Word;
    BitsPerSample: Word;
  end;

function ChunkIDToString(const Value: TWaveChunkID): AnsiString;
var
  i: Integer;
begin
  SetLength(Result, 4);
  for i := 0 to 3 do
    Result[i + 1] := Value[i];
end;

{ TWaveAnalyzer }

constructor TWaveAnalyzer.Create;
begin
  inherited Create;
  FItems := TWaveVolumeList.Create;
  FIntervalSec := 0.02;
  FChannelIndex := 0;
  FSilenceThreshold := 0.02;
  FNormalizeMax := 100;
end;

destructor TWaveAnalyzer.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TWaveAnalyzer.Clear;
begin
  FItems.Clear;
  FMaxRawVolume := 0;
  FSampleRate := 0;
  FWaveLengthSec := 0;
end;

function TWaveAnalyzer.ReadSample(const Buffer: TBytes; Offset: Integer;
  BitsPerSample: Word): Double;
var
  V: Integer;
begin
  Result := 0;

  case BitsPerSample of
    8:
      Result := (Integer(Buffer[Offset]) - 128) / 128;
    16:
      begin
        V := SmallInt(Buffer[Offset] or (Buffer[Offset + 1] shl 8));
        Result := V / 32768;
      end;
    24:
      begin
        V := Buffer[Offset] or (Buffer[Offset + 1] shl 8) or (Buffer[Offset + 2] shl 16);
        if (V and $800000) <> 0 then
          V := V - $1000000;
        Result := V / 8388608;
      end;
    32:
      begin
        V := Buffer[Offset] or (Buffer[Offset + 1] shl 8) or
             (Buffer[Offset + 2] shl 16) or (Buffer[Offset + 3] shl 24);
        Result := V / 2147483648.0;
      end;
  end;

  Result := Abs(Result);
end;

function TWaveAnalyzer.Analyze(const FileName: string): Boolean;
var
  FS: TFileStream;
  Riff: TRiffHeader;
  Ch: TChunkHeader;
  Fmt: TFmtChunk;
  FoundFmt, FoundData: Boolean;
  DataPos: Int64;
  DataSize: Cardinal;
  BytesPerChannel, BytesPerFrame, SampleCount, IntervalSamples: Integer;
  ChannelOffset, i, ItemIndex: Integer;
  Buffer: TBytes;
  SumSquares, SampleValue, RawVolume: Double;
  SamplesInItem: Integer;
  Item: TWaveVolumeItem;
begin
  Result := False;
  Clear;

  if (FileName = '') or not FileExists(FileName) then
    Exit;

  if FIntervalSec <= 0 then
    FIntervalSec := 0.02;
  if FNormalizeMax <= 0 then
    FNormalizeMax := 100;

  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    if FS.Read(Riff, SizeOf(Riff)) <> SizeOf(Riff) then Exit;
    if (ChunkIDToString(Riff.ChunkID) <> 'RIFF') or (ChunkIDToString(Riff.Format) <> 'WAVE') then
      Exit;

    FillChar(Fmt, SizeOf(Fmt), 0);
    FoundFmt := False;
    FoundData := False;
    DataPos := 0;
    DataSize := 0;

    while FS.Position + SizeOf(TChunkHeader) <= FS.Size do
    begin
      if FS.Read(Ch, SizeOf(Ch)) <> SizeOf(Ch) then Break;

      if ChunkIDToString(Ch.ID) = 'fmt ' then
      begin
        if Ch.Size < SizeOf(TFmtChunk) then Exit;
        if FS.Read(Fmt, SizeOf(TFmtChunk)) <> SizeOf(TFmtChunk) then Exit;
        FoundFmt := True;
        if Ch.Size > SizeOf(TFmtChunk) then
          FS.Seek(Ch.Size - SizeOf(TFmtChunk), soFromCurrent);
      end
      else if ChunkIDToString(Ch.ID) = 'data' then
      begin
        DataPos := FS.Position;
        DataSize := Ch.Size;
        FoundData := True;
        FS.Seek(Ch.Size, soFromCurrent);
      end
      else
        FS.Seek(Ch.Size, soFromCurrent);

      if Odd(Ch.Size) then
        FS.Seek(1, soFromCurrent);
      if FoundFmt and FoundData then Break;
    end;

    if not (FoundFmt and FoundData) then Exit;
    if Fmt.AudioFormat <> 1 then Exit;
    if (Fmt.NumChannels = 0) or (Fmt.SampleRate = 0) or (Fmt.BitsPerSample = 0) then Exit;
    if not (Fmt.BitsPerSample in [8, 16, 24, 32]) then Exit;

    BytesPerChannel := Fmt.BitsPerSample div 8;
    BytesPerFrame := BytesPerChannel * Fmt.NumChannels;
    if BytesPerFrame <= 0 then Exit;

    if FChannelIndex < 0 then
      FChannelIndex := 0;
    if FChannelIndex >= Fmt.NumChannels then
      FChannelIndex := 0;
    ChannelOffset := FChannelIndex * BytesPerChannel;

    SetLength(Buffer, DataSize);
    FS.Position := DataPos;
    if DataSize > 0 then
      if FS.Read(Buffer[0], DataSize) <> Integer(DataSize) then Exit;

    FSampleRate := Fmt.SampleRate;
    SampleCount := Integer(DataSize) div BytesPerFrame;
    if SampleCount <= 0 then Exit;
    FWaveLengthSec := SampleCount / Fmt.SampleRate;

    IntervalSamples := Max(1, Round(Fmt.SampleRate * FIntervalSec));
    ItemIndex := 0;
    i := 0;
    while i < SampleCount do
    begin
      SumSquares := 0;
      SamplesInItem := 0;

      while (i < SampleCount) and (SamplesInItem < IntervalSamples) do
      begin
        SampleValue := ReadSample(Buffer, (i * BytesPerFrame) + ChannelOffset, Fmt.BitsPerSample);
        SumSquares := SumSquares + Sqr(SampleValue);
        Inc(SamplesInItem);
        Inc(i);
      end;

      if SamplesInItem > 0 then
        RawVolume := Sqrt(SumSquares / SamplesInItem)
      else
        RawVolume := 0;

      Item.Index := ItemIndex;
      Item.StartSec := (ItemIndex * IntervalSamples) / Fmt.SampleRate;
      Item.EndSec := Min(i / Fmt.SampleRate, FWaveLengthSec);
      Item.Start100ns := Round(Item.StartSec * 10000000);
      Item.End100ns := Round(Item.EndSec * 10000000);
      Item.RawVolume := RawVolume;
      Item.Volume := 0;

      FItems.Add(Item);
      if RawVolume > FMaxRawVolume then
        FMaxRawVolume := RawVolume;
      Inc(ItemIndex);
    end;

    NormalizeItems;
    {$IFDEF DEBUG}
    PSDDebugLog('SerifWaveLab', Format(
      'analyze finish file="%s" sample_rate=%d length=%.4f interval=%.4f items=%d max_raw=%.8f silence_threshold=%.4f normalize_max=%d',
      [FileName, FSampleRate, FWaveLengthSec, FIntervalSec, FItems.Count,
       FMaxRawVolume, FSilenceThreshold, FNormalizeMax]));
    {$ENDIF}
    Result := FItems.Count > 0;
  finally
    FS.Free;
  end;
end;

procedure TWaveAnalyzer.NormalizeItems;
var
  i: Integer;
  Item: TWaveVolumeItem;
begin
  for i := 0 to FItems.Count - 1 do
  begin
    Item := FItems[i];
    if (FMaxRawVolume <= 0) or (Item.RawVolume < FMaxRawVolume * FSilenceThreshold) then
      Item.Volume := 0
    else
      Item.Volume := EnsureRange(Round((Item.RawVolume / FMaxRawVolume) * FNormalizeMax), 0, FNormalizeMax);
    FItems[i] := Item;
  end;
end;

function TWaveAnalyzer.VolumeToTalkStage(Volume: Integer): Integer;
begin
  if Volume <= 0 then Exit(0);
  // Keep the generated LAB grouping aligned with PluginFilterPSDDrawLipSyncTalk.
  // Otherwise quiet Mouth1 values and Mouth2 values are merged and the max volume
  // is stretched over the whole merged range.
  if Volume <= 20 then Exit(1);
  if Volume <= 40 then Exit(2);
  if Volume <= 60 then Exit(3);
  if Volume <= 80 then Exit(4);
  Result := 5;
end;

{$IFDEF DEBUG}
procedure DebugLogWaveItem(const Item: TWaveVolumeItem; Stage: Integer);
begin
  PSDDebugLog('SerifWaveLab', Format(
    'item index=%d start=%.4f end=%.4f raw=%.8f volume=%d stage=%d',
    [Item.Index, Item.StartSec, Item.EndSec, Item.RawVolume, Item.Volume, Stage]));
end;

procedure DebugLogWaveLabLine(const Prefix: string; Start100ns, End100ns: Int64;
  Volume, Stage: Integer);
begin
  PSDDebugLog('SerifWaveLab', Format(
    '%s start100ns=%d end100ns=%d start=%.4f end=%.4f volume=%d stage=%d line=%s',
    [Prefix, Start100ns, End100ns, Start100ns / 10000000,
     End100ns / 10000000, Volume, Stage,
     IntToStr(Start100ns) + ',' + IntToStr(End100ns) + ',vol:' + IntToStr(Volume)]));
end;
{$ENDIF}

procedure TWaveAnalyzer.AddToLabLines(Lines: TStrings);
var
  i, Stage, CurrentStage, CurrentVolume: Integer;
  CurrentStart, CurrentEnd: Int64;
  Item: TWaveVolumeItem;

  procedure FlushCurrent;
  begin
    if (CurrentEnd <= CurrentStart) then Exit;
    {$IFDEF DEBUG}
    DebugLogWaveLabLine('flush', CurrentStart, CurrentEnd, CurrentVolume, CurrentStage);
    {$ENDIF}
    Lines.Add(
      IntToStr(CurrentStart) + ',' +
      IntToStr(CurrentEnd) + ',vol:' +
      IntToStr(CurrentVolume));
  end;

begin
  if Lines = nil then Exit;

  CurrentStage := -1;
  CurrentVolume := 0;
  CurrentStart := 0;
  CurrentEnd := 0;

  for i := 0 to FItems.Count - 1 do
  begin
    Item := FItems[i];
    if Item.End100ns <= Item.Start100ns then
      Continue;

    Stage := VolumeToTalkStage(Item.Volume);
    {$IFDEF DEBUG}
    DebugLogWaveItem(Item, Stage);
    {$ENDIF}
    if CurrentStage < 0 then
    begin
      CurrentStage := Stage;
      CurrentStart := Item.Start100ns;
      CurrentEnd := Item.End100ns;
      CurrentVolume := Item.Volume;
      Continue;
    end;

    if (Stage = CurrentStage) and (Item.Start100ns <= CurrentEnd) then
    begin
      CurrentEnd := Item.End100ns;
      if Item.Volume > CurrentVolume then
        CurrentVolume := Item.Volume;
      Continue;
    end;

    FlushCurrent;
    CurrentStage := Stage;
    CurrentStart := Item.Start100ns;
    CurrentEnd := Item.End100ns;
    CurrentVolume := Item.Volume;
  end;

  FlushCurrent;
end;

end.
