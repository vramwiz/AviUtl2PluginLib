unit SerifSharedIndex;

interface

const
  SERIF_INDEX_SHARED_NAME = 'Local\ShareTalkIndex';
  SERIF_HISTORY_SHARED_NAME = 'Local\ShareTalkHistory';
  SERIF_INDEX_MAX_RECORDS = 100;
  SERIF_INDEX_MAX_TEXT_LENGTH = 16384;
  // 送信側と描画側は同じ評価内で連続して呼ばれる。これを超えた索引は別シーン由来の残留値として扱う。
  SERIF_INDEX_ACTIVE_MAX_AGE_MS = 500;

type
  TSerifIndexHeader = record
    Count: Integer;
    CurrentFrame: Integer;
    Generation: Integer;
    PublishedTick: UInt64;
    Ready: Boolean;
  end;

  TSerifIndexRecord = record
    Chara: string;
    Direction: string;
    Emote: string;
    Layer: Integer;
    Serif: string;
  end;

function EncodeSerifIndexHeader(const AHeader: TSerifIndexHeader): string;
function EncodeSerifIndexRecord(const ARecord: TSerifIndexRecord): string;
function TryDecodeSerifIndexHeader(const AText: string;
  out AHeader: TSerifIndexHeader): Boolean;
function TryDecodeSerifIndexRecord(const AText: string;
  out ARecord: TSerifIndexRecord): Boolean;

implementation

uses
  System.SysUtils;

const
  HEADER_PREFIX = 'SIH2|';
  LEGACY_HEADER_PREFIX = 'SIH1|';
  RECORD_PREFIX = 'SIR1|';

function AppendLengthField(const AText, AValue: string): string;
begin
  Result := AText + IntToStr(Length(AValue)) + ':' + AValue + '|';
end;

function ReadIntegerToken(const AText: string; var APosition: Integer;
  out AValue: Integer): Boolean;
var
  Separator: Integer;
begin
  Separator := Pos('|', AText, APosition);
  Result := (Separator >= APosition) and TryStrToInt(
    Copy(AText, APosition, Separator - APosition), AValue);
  if Result then
    APosition := Separator + 1;
end;

function ReadUInt64Token(const AText: string; var APosition: Integer;
  out AValue: UInt64): Boolean;
var
  Separator: Integer;
begin
  Separator := Pos('|', AText, APosition);
  Result := (Separator >= APosition) and TryStrToUInt64(
    Copy(AText, APosition, Separator - APosition), AValue);
  if Result then
    APosition := Separator + 1;
end;

function ReadLengthField(const AText: string; var APosition: Integer;
  out AValue: string): Boolean;
var
  FieldLength: Integer;
  Separator: Integer;
begin
  Result := False;
  Separator := Pos(':', AText, APosition);
  if (Separator < APosition) or not TryStrToInt(
    Copy(AText, APosition, Separator - APosition), FieldLength) or
    (FieldLength < 0) then
    Exit;
  APosition := Separator + 1;
  if NativeInt(APosition) + FieldLength > NativeInt(Length(AText)) + 1 then
    Exit;
  AValue := Copy(AText, APosition, FieldLength);
  Inc(APosition, FieldLength);
  if (APosition > Length(AText)) or (AText[APosition] <> '|') then
    Exit;
  Inc(APosition);
  Result := True;
end;

function EncodeSerifIndexHeader(const AHeader: TSerifIndexHeader): string;
begin
  Result := HEADER_PREFIX + IntToStr(AHeader.CurrentFrame) + '|' +
    IntToStr(AHeader.Count) + '|' + IntToStr(AHeader.Generation) + '|' +
    UIntToStr(AHeader.PublishedTick) + '|' +
    IntToStr(Ord(AHeader.Ready)) + '|';
end;

function EncodeSerifIndexRecord(const ARecord: TSerifIndexRecord): string;
begin
  Result := RECORD_PREFIX + IntToStr(ARecord.Layer) + '|';
  Result := AppendLengthField(Result, ARecord.Chara);
  Result := AppendLengthField(Result, ARecord.Emote);
  Result := AppendLengthField(Result, ARecord.Direction);
  Result := AppendLengthField(Result, ARecord.Serif);
end;

function TryDecodeSerifIndexHeader(const AText: string;
  out AHeader: TSerifIndexHeader): Boolean;
var
  IsLegacy: Boolean;
  Position: Integer;
  ReadyValue: Integer;
begin
  AHeader := System.Default(TSerifIndexHeader);
  IsLegacy := Copy(AText, 1, Length(LEGACY_HEADER_PREFIX)) =
    LEGACY_HEADER_PREFIX;
  Result := IsLegacy or
    (Copy(AText, 1, Length(HEADER_PREFIX)) = HEADER_PREFIX);
  if not Result then
    Exit;
  if IsLegacy then
    Position := Length(LEGACY_HEADER_PREFIX) + 1
  else
    Position := Length(HEADER_PREFIX) + 1;
  Result := ReadIntegerToken(AText, Position, AHeader.CurrentFrame) and
    ReadIntegerToken(AText, Position, AHeader.Count) and
    ReadIntegerToken(AText, Position, AHeader.Generation);
  if Result and not IsLegacy then
    Result := ReadUInt64Token(AText, Position, AHeader.PublishedTick);
  Result := Result and
    ReadIntegerToken(AText, Position, ReadyValue) and
    (AHeader.Count >= 0) and
    (AHeader.Count <= SERIF_INDEX_MAX_RECORDS) and
    (ReadyValue in [0, 1]);
  if Result then
    AHeader.Ready := ReadyValue = 1;
end;

function TryDecodeSerifIndexRecord(const AText: string;
  out ARecord: TSerifIndexRecord): Boolean;
var
  Position: Integer;
begin
  ARecord := System.Default(TSerifIndexRecord);
  Result := Copy(AText, 1, Length(RECORD_PREFIX)) = RECORD_PREFIX;
  if not Result then
    Exit;
  Position := Length(RECORD_PREFIX) + 1;
  Result := ReadIntegerToken(AText, Position, ARecord.Layer) and
    ReadLengthField(AText, Position, ARecord.Chara) and
    ReadLengthField(AText, Position, ARecord.Emote) and
    ReadLengthField(AText, Position, ARecord.Direction) and
    ReadLengthField(AText, Position, ARecord.Serif) and
    (ARecord.Layer >= 0) and
    (ARecord.Layer < SERIF_INDEX_MAX_RECORDS) and
    (Position > Length(AText));
end;

end.
