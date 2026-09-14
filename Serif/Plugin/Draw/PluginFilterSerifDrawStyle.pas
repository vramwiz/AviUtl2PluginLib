unit PluginFilterSerifDrawStyle;

interface

uses
  AviUtl2FilterTypes;

const
  SERIF_DRAW_STYLE_MIN = 1;
  SERIF_DRAW_STYLE_MAX = 99;
  SERIF_DRAW_STYLE_META_MAGIC = $53534453; // "SDSS"
  SERIF_DRAW_STYLE_META_VERSION = 1;

type
  TSerifDrawStyleMeta = packed record
    Magic: Cardinal;
    Version: Cardinal;
    StyleNo: Cardinal;
    Generation: UInt64;
  end;

var
  SerifDrawStyleItem: TFILTER_ITEM_SELECT;
  SerifDrawStyleMetaItem: TFILTER_ITEM_DATA;

procedure AddSerifDrawStyleItems;
function CurrentSerifDrawStyleNo: Integer;
function CurrentSerifDrawStyleGeneration: UInt64;
function ResolveSerifDrawStyleText(const ALocalText: string): string;
function NewSerifDrawStyleGeneration: UInt64;
procedure PublishSerifDrawStyle(const AStyleNo: Integer;
  const AGeneration: UInt64; const ASettingsText: string);
procedure SetCurrentSerifDrawStyleMeta(const AStyleNo: Integer;
  const AGeneration: UInt64);

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  PluginFilterTable,
  PluginFilterSerifDrawDebugLog;

type
  TSerifDrawStyleCacheEntry = record
    HasValue: Boolean;
    Generation: UInt64;
    SettingsText: string;
  end;

var
  GCache: array[SERIF_DRAW_STYLE_MIN..SERIF_DRAW_STYLE_MAX] of
    TSerifDrawStyleCacheEntry;
  GDefaultMeta: TSerifDrawStyleMeta;
  GLastGeneration: UInt64;
  GLock: TRTLCriticalSection;
  GStyleList: array[0..SERIF_DRAW_STYLE_MAX - SERIF_DRAW_STYLE_MIN + 1] of
    TFILTER_ITEM_SELECT_ITEM;
  GStyleNames: array[SERIF_DRAW_STYLE_MIN..SERIF_DRAW_STYLE_MAX] of string;

function ClampStyleNo(const AStyleNo: Integer): Integer;
begin
  Result := AStyleNo;
  if Result < SERIF_DRAW_STYLE_MIN then
    Result := SERIF_DRAW_STYLE_MIN
  else if Result > SERIF_DRAW_STYLE_MAX then
    Result := SERIF_DRAW_STYLE_MAX;
end;

function TryCurrentMeta(out AMeta: TSerifDrawStyleMeta): Boolean;
begin
  Result := (SerifDrawStyleMetaItem.Value <> nil) and
    (SerifDrawStyleMetaItem.Size >= SizeOf(AMeta));
  if Result then
  begin
    Move(SerifDrawStyleMetaItem.Value^, AMeta, SizeOf(AMeta));
    Result := (AMeta.Magic = SERIF_DRAW_STYLE_META_MAGIC) and
      (AMeta.Version = SERIF_DRAW_STYLE_META_VERSION);
  end;
  if not Result then
    AMeta := Default(TSerifDrawStyleMeta);
end;

procedure AddSerifDrawStyleItems;
var
  I: Integer;
begin
  for I := SERIF_DRAW_STYLE_MIN to SERIF_DRAW_STYLE_MAX do
  begin
    GStyleNames[I] := Format(#$30B9#$30BF#$30A4#$30EB' %d', [I]);
    GStyleList[I - SERIF_DRAW_STYLE_MIN].Name := PWideChar(GStyleNames[I]);
    GStyleList[I - SERIF_DRAW_STYLE_MIN].Value := I;
  end;
  GStyleList[High(GStyleList)].Name := nil;
  GStyleList[High(GStyleList)].Value := 0;

  GDefaultMeta.Magic := SERIF_DRAW_STYLE_META_MAGIC;
  GDefaultMeta.Version := SERIF_DRAW_STYLE_META_VERSION;
  GDefaultMeta.StyleNo := SERIF_DRAW_STYLE_MIN;
  GDefaultMeta.Generation := 0;
  AddSelect(SerifDrawStyleItem, #$30B9#$30BF#$30A4#$30EB,
    SERIF_DRAW_STYLE_MIN,
    @GStyleList[0]);
  AddData(SerifDrawStyleMetaItem,
    #$30B9#$30BF#$30A4#$30EB#$7BA1#$7406,
    PWideChar(@GDefaultMeta), SizeOf(GDefaultMeta));
end;

function CurrentSerifDrawStyleNo: Integer;
begin
  Result := ClampStyleNo(SerifDrawStyleItem.Value);
end;

function CurrentSerifDrawStyleGeneration: UInt64;
var
  Meta: TSerifDrawStyleMeta;
begin
  if TryCurrentMeta(Meta) and
    (Meta.StyleNo = Cardinal(CurrentSerifDrawStyleNo)) then
    Result := Meta.Generation
  else
    Result := 0;
end;

procedure SetCurrentSerifDrawStyleMeta(const AStyleNo: Integer;
  const AGeneration: UInt64);
var
  Meta: TSerifDrawStyleMeta;
begin
  Meta.Magic := SERIF_DRAW_STYLE_META_MAGIC;
  Meta.Version := SERIF_DRAW_STYLE_META_VERSION;
  Meta.StyleNo := ClampStyleNo(AStyleNo);
  Meta.Generation := AGeneration;
  if (SerifDrawStyleMetaItem.Value <> nil) and
    (SerifDrawStyleMetaItem.Size >= SizeOf(Meta)) then
    Move(Meta, SerifDrawStyleMetaItem.Value^, SizeOf(Meta));
end;

function NewSerifDrawStyleGeneration: UInt64;
var
  FileTime: TFileTime;
  Candidate: UInt64;
begin
  GetSystemTimeAsFileTime(FileTime);
  Candidate := UInt64(FileTime.dwLowDateTime) or
    (UInt64(FileTime.dwHighDateTime) shl 32);
  EnterCriticalSection(GLock);
  try
    if Candidate <= GLastGeneration then
      Candidate := GLastGeneration + 1;
    GLastGeneration := Candidate;
    Result := Candidate;
  finally
    LeaveCriticalSection(GLock);
  end;
end;

procedure PublishSerifDrawStyle(const AStyleNo: Integer;
  const AGeneration: UInt64; const ASettingsText: string);
var
  StyleNo: Integer;
begin
  StyleNo := ClampStyleNo(AStyleNo);
  EnterCriticalSection(GLock);
  try
    if (not GCache[StyleNo].HasValue) or
      (AGeneration > GCache[StyleNo].Generation) then
    begin
      GCache[StyleNo].HasValue := True;
      GCache[StyleNo].Generation := AGeneration;
      GCache[StyleNo].SettingsText := ASettingsText;
    end;
  finally
    LeaveCriticalSection(GLock);
  end;
end;

function ResolveSerifDrawStyleText(const ALocalText: string): string;
var
  Generation: UInt64;
  StyleNo: Integer;
begin
  StyleNo := CurrentSerifDrawStyleNo;
  Generation := CurrentSerifDrawStyleGeneration;
  EnterCriticalSection(GLock);
  try
    if not GCache[StyleNo].HasValue then
    begin
      GCache[StyleNo].HasValue := True;
      GCache[StyleNo].Generation := Generation;
      GCache[StyleNo].SettingsText := ALocalText;
    end
    else if Generation > GCache[StyleNo].Generation then
    begin
      GCache[StyleNo].Generation := Generation;
      GCache[StyleNo].SettingsText := ALocalText;
    end;
    Result := GCache[StyleNo].SettingsText;
{$IFDEF DEBUG}
    if (Generation < GCache[StyleNo].Generation) and
      (ALocalText <> Result) then
      SerifDrawDebugLog(Format(
        'Style cache applied: style=%d local_generation=%d cache_generation=%d',
        [StyleNo, Generation, GCache[StyleNo].Generation]));
{$ENDIF}
  finally
    LeaveCriticalSection(GLock);
  end;
end;

initialization
  InitializeCriticalSection(GLock);

finalization
  DeleteCriticalSection(GLock);

end.
