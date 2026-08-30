unit PluginFilterSerifDrawReceiver;

interface

// SerifSharedの共有メモリを安定読み取りし、描画用スナップショットへ変換する。

uses
  SerifSharedIndex;

type
  TSerifDrawSnapshot = record
    // 共有データに記録された配役名。
    Chara: string;
    // このスナップショットを取得したAviUtl2上のフレーム番号。
    CurrentFrame: Integer;
    // セリフの表示方向を表す共有データ上の識別文字列。
    Direction: string;
    // 表情を表す共有データ上の識別文字列。
    Emote: string;
    // AviUtl2の対象レイヤー番号。
    Layer: Integer;
    // 描画対象のセリフ本文。
    Serif: string;
    // セリフ全体の時間に対する、おおよその現在発音位置（0～1）。
    SpeechProgress: Double;
    // Module側のLAB判定による現在発音中フラグ。
    SpeechActive: Boolean;
    // 表示後アニメーション中に終了直前の発音同期表示を保持する。
    HoldSpeechSync: Boolean;
    // セリフオブジェクト先頭からの相対フレーム。
    TimelineFrame: Integer;
    // セリフ時間とFPSからModule側で求めた総フレーム数。
    TimelineTotalFrames: Integer;
    // 履歴と現在表示を対応付ける送信元オブジェクトID。
    SourceObjectID: string;
    // セリフレコードを識別する共有データ上のUID。
    UID: string;
  end;

  TSerifDrawReceiver = class
  private
    FIndex: TObject;
    FHistory: TObject;
    FShared: TObject;
    function ReadStableIndex(const ACurrentFrame: Integer;
      const ARequireFresh: Boolean;
      out ARecords: TArray<TSerifIndexRecord>;
      out AIsFresh: Boolean): Boolean;
    function ReadStableSlot(const ALayer: Integer; out AText: string): Boolean;
    function TryParseSnapshot(const ALayer, ACurrentFrame: Integer;
      const AText: string; out ASnapshot: TSerifDrawSnapshot): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    // 指定フレームで有効な共有レコードを共有インデックス順のスナップショットとして返す。
    function ReadActive(const ACurrentFrame: Integer): TArray<TSerifDrawSnapshot>; overload;
    function ReadActive(const ACurrentFrame: Integer;
      const AValidatedLayers: TArray<Integer>): TArray<TSerifDrawSnapshot>; overload;
    // 同じフレームの索引に残る送信元レイヤーを返す。呼出側はこれらを評価して索引時刻を更新する。
    function ReadIndexedLayers(const ACurrentFrame: Integer): TArray<Integer>;
    // 共有履歴に記録されたセリフを最終送信が新しい順のスナップショットとして返す。
    function ReadHistory: TArray<TSerifDrawSnapshot>;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  Winapi.Windows,
  SharedMemoryBase
{$IFDEF DEBUG}
  , PluginFilterSerifDrawDebugLog
{$ENDIF}
  ;

const
  SHARED_MAX_LENGTH = 4000;
  SHARED_MAX_LAYERS = 100;
  SHARED_NAME = 'Local\ShareTalk';

{$IFDEF DEBUG}
var
  ReceiverLogCount: Integer;

procedure ReceiverDebugLog(const AText: string);
begin
  // 再生中のログ肥大化を防ぎつつ、初期評価と数秒分の連続フレームを残す。
  if InterlockedIncrement(ReceiverLogCount) <= 1000 then
    SerifDrawDebugLog('Receiver: ' + AText);
end;
{$ENDIF}

type
  TSerifSharedMemoryAccess = class(TSharedMemoryStringList);

function GetExactKeyValue(const AText, AKey: string): string;
var
  Item: string;
  ItemEnd: Integer;
  ItemStart: Integer;
  Prefix: string;
begin
  Result := '';
  Prefix := AKey + '=';
  ItemStart := 1;
  while ItemStart <= Length(AText) do
  begin
    ItemEnd := ItemStart;
    while (ItemEnd <= Length(AText)) and (AText[ItemEnd] <> ';') do
      Inc(ItemEnd);
    Item := Copy(AText, ItemStart, ItemEnd - ItemStart);
    if SameText(Copy(Item, 1, Length(Prefix)), Prefix) then
      Exit(Copy(Item, Length(Prefix) + 1, MaxInt));
    ItemStart := ItemEnd + 1;
  end;
end;

{ TSerifDrawReceiver }

constructor TSerifDrawReceiver.Create;
begin
  inherited Create;
  FShared := TSerifSharedMemoryAccess.Create(SHARED_NAME,
    SHARED_MAX_LAYERS, SHARED_MAX_LENGTH);
  FIndex := TSerifSharedMemoryAccess.Create(SERIF_INDEX_SHARED_NAME,
    SERIF_INDEX_MAX_RECORDS + 1, SERIF_INDEX_MAX_TEXT_LENGTH);
  FHistory := TSerifSharedMemoryAccess.Create(SERIF_HISTORY_SHARED_NAME,
    SERIF_INDEX_MAX_RECORDS + 1, SERIF_INDEX_MAX_TEXT_LENGTH);
end;

destructor TSerifDrawReceiver.Destroy;
begin
  FHistory.Free;
  FIndex.Free;
  FShared.Free;
  inherited;
end;

function TSerifDrawReceiver.ReadHistory: TArray<TSerifDrawSnapshot>;
const
  MAX_READ_ATTEMPTS = 3;
var
  Attempt: Integer;
  FirstHeaderText: string;
  Header: TSerifIndexHeader;
  History: TSerifSharedMemoryAccess;
  I: Integer;
  Item: TSerifIndexRecord;
  LastHeaderText: string;
  RecordText: string;
  SecondRecordText: string;
begin
  Result := nil;
  History := TSerifSharedMemoryAccess(FHistory);
  for Attempt := 1 to MAX_READ_ATTEMPTS do
  begin
    FirstHeaderText := History.Strings[0];
    if not TryDecodeSerifIndexHeader(FirstHeaderText, Header) then
      Exit;
    if not Header.Ready then
      Continue;
    SetLength(Result, Header.Count);
    for I := 0 to Header.Count - 1 do
    begin
      RecordText := History.Strings[I + 1];
      SecondRecordText := History.Strings[I + 1];
      if (RecordText <> SecondRecordText) or
        not TryDecodeSerifIndexRecord(RecordText, Item) then
      begin
        Result := nil;
        Break;
      end;
      Result[Header.Count - I - 1] := System.Default(TSerifDrawSnapshot);
      Result[Header.Count - I - 1].Layer := Item.Layer;
      Result[Header.Count - I - 1].Chara := Item.Chara;
      Result[Header.Count - I - 1].Emote := Item.Emote;
      Result[Header.Count - I - 1].Direction := Item.Direction;
      Result[Header.Count - I - 1].Serif := Item.Serif;
      Result[Header.Count - I - 1].CurrentFrame := Header.CurrentFrame;
    end;
    LastHeaderText := History.Strings[0];
    if (Length(Result) = Header.Count) and
      (FirstHeaderText = LastHeaderText) then
      Exit;
    Result := nil;
  end;
end;

function TSerifDrawReceiver.ReadActive(
  const ACurrentFrame: Integer): TArray<TSerifDrawSnapshot>;
var
  NoValidatedLayers: TArray<Integer>;
begin
  Result := ReadActive(ACurrentFrame, NoValidatedLayers);
end;

function TSerifDrawReceiver.ReadActive(
  const ACurrentFrame: Integer;
  const AValidatedLayers: TArray<Integer>): TArray<TSerifDrawSnapshot>;
var
  I: Integer;
  IndexIsFresh: Boolean;
  IndexRecord: TSerifIndexRecord;
  IndexRecords: TArray<TSerifIndexRecord>;
  LayerValidated: Boolean;
  Snapshot: TSerifDrawSnapshot;
  Text: string;
begin
  Result := nil;
  if not ReadStableIndex(ACurrentFrame, False, IndexRecords,
    IndexIsFresh) then
  begin
{$IFDEF DEBUG}
    ReceiverDebugLog(Format('active rejected frame=%d reason=index',
      [ACurrentFrame]));
{$ENDIF}
    Exit;
  end;
  for IndexRecord in IndexRecords do
  begin
    LayerValidated := IndexIsFresh;
    if not LayerValidated then
      for I := 0 to High(AValidatedLayers) do
        if AValidatedLayers[I] = IndexRecord.Layer then
        begin
          LayerValidated := True;
          Break;
        end;
    if not LayerValidated then
    begin
{$IFDEF DEBUG}
      ReceiverDebugLog(Format(
        'active record rejected frame=%d layer=%d reason=stale-unvalidated',
        [ACurrentFrame, IndexRecord.Layer]));
{$ENDIF}
      Continue;
    end;
    if ReadStableSlot(IndexRecord.Layer, Text) and
      TryParseSnapshot(IndexRecord.Layer, ACurrentFrame, Text, Snapshot) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Snapshot;
    end;
  end;
{$IFDEF DEBUG}
  ReceiverDebugLog(Format('active accepted frame=%d index=%d snapshots=%d',
    [ACurrentFrame, Length(IndexRecords), Length(Result)]));
{$ENDIF}
end;

function TSerifDrawReceiver.ReadIndexedLayers(
  const ACurrentFrame: Integer): TArray<Integer>;
var
  I: Integer;
  IndexIsFresh: Boolean;
  IndexRecords: TArray<TSerifIndexRecord>;
begin
  Result := nil;
  // 再描画時はScriptがキャッシュされて壁時計上の期限だけが切れることがある。
  // フレーム一致は維持し、入力を再評価するためのレイヤー列挙だけは期限切れを許可する。
  if not ReadStableIndex(ACurrentFrame, False, IndexRecords,
    IndexIsFresh) then
    Exit;
  SetLength(Result, Length(IndexRecords));
  for I := 0 to High(IndexRecords) do
    Result[I] := IndexRecords[I].Layer;
end;

function TSerifDrawReceiver.ReadStableIndex(const ACurrentFrame: Integer;
  const ARequireFresh: Boolean;
  out ARecords: TArray<TSerifIndexRecord>;
  out AIsFresh: Boolean): Boolean;
const
  MAX_READ_ATTEMPTS = 3;
var
  Attempt: Integer;
  FirstHeaderText: string;
  Header: TSerifIndexHeader;
  I: Integer;
  Index: TSerifSharedMemoryAccess;
  LastHeaderText: string;
  CurrentTick: UInt64;
  PublishedAge: UInt64;
  RecordText: string;
  SecondRecordText: string;
begin
  Result := False;
  ARecords := nil;
  AIsFresh := False;
  Index := TSerifSharedMemoryAccess(FIndex);
  for Attempt := 1 to MAX_READ_ATTEMPTS do
  begin
    FirstHeaderText := Index.Strings[0];
    if not TryDecodeSerifIndexHeader(FirstHeaderText, Header) then
    begin
{$IFDEF DEBUG}
      ReceiverDebugLog('index rejected reason=decode header=' +
        Copy(FirstHeaderText, 1, 160));
{$ENDIF}
      Exit;
    end;
    CurrentTick := GetTickCount64;
    if (Header.PublishedTick = 0) or (CurrentTick < Header.PublishedTick) then
      PublishedAge := High(UInt64)
    else
      PublishedAge := CurrentTick - Header.PublishedTick;
    if not Header.Ready then
    begin
{$IFDEF DEBUG}
      ReceiverDebugLog(Format('index rejected reason=not-ready frame=%d count=%d',
        [Header.CurrentFrame, Header.Count]));
{$ENDIF}
      Exit;
    end;
    if Header.CurrentFrame <> ACurrentFrame then
    begin
{$IFDEF DEBUG}
      ReceiverDebugLog(Format(
        'index rejected reason=frame requested=%d published=%d count=%d',
        [ACurrentFrame, Header.CurrentFrame, Header.Count]));
{$ENDIF}
      Exit;
    end;
    if ARequireFresh and
      (PublishedAge > SERIF_INDEX_ACTIVE_MAX_AGE_MS) then
    begin
{$IFDEF DEBUG}
      ReceiverDebugLog(Format(
        'index rejected reason=age frame=%d age=%d max=%d count=%d',
        [ACurrentFrame, PublishedAge,
         SERIF_INDEX_ACTIVE_MAX_AGE_MS, Header.Count]));
{$ENDIF}
      Exit;
    end;
    AIsFresh := PublishedAge <= SERIF_INDEX_ACTIVE_MAX_AGE_MS;
    SetLength(ARecords, Header.Count);
    Result := True;
    for I := 0 to Header.Count - 1 do
    begin
      RecordText := Index.Strings[I + 1];
      SecondRecordText := Index.Strings[I + 1];
      if (RecordText <> SecondRecordText) or
        not TryDecodeSerifIndexRecord(RecordText, ARecords[I]) then
      begin
{$IFDEF DEBUG}
        ReceiverDebugLog(Format(
          'index record rejected attempt=%d slot=%d stable=%d text=%s',
          [Attempt, I + 1, Ord(RecordText = SecondRecordText),
           Copy(RecordText, 1, 160)]));
{$ENDIF}
        Result := False;
        Break;
      end;
    end;
    LastHeaderText := Index.Strings[0];
    if Result and (FirstHeaderText = LastHeaderText) then
    begin
{$IFDEF DEBUG}
      ReceiverDebugLog(Format(
        'index accepted frame=%d count=%d generation=%d age=%d fresh=%d',
        [Header.CurrentFrame, Header.Count, Header.Generation,
         PublishedAge, Ord(ARequireFresh)]));
{$ENDIF}
      Exit(True);
    end;
{$IFDEF DEBUG}
    ReceiverDebugLog(Format('index changed attempt=%d frame=%d count=%d',
      [Attempt, Header.CurrentFrame, Header.Count]));
{$ENDIF}
    Result := False;
    ARecords := nil;
  end;
end;

function TSerifDrawReceiver.ReadStableSlot(const ALayer: Integer;
  out AText: string): Boolean;
var
  FirstRead: string;
  Shared: TSerifSharedMemoryAccess;
begin
  Shared := TSerifSharedMemoryAccess(FShared);
  FirstRead := Shared.Strings[ALayer];
  AText := Shared.Strings[ALayer];
  Result := (FirstRead = AText) and (AText <> '');
{$IFDEF DEBUG}
  if not Result then
    ReceiverDebugLog(Format('slot rejected layer=%d stable=%d length=%d',
      [ALayer, Ord(FirstRead = AText), Length(AText)]));
{$ENDIF}
end;

function TSerifDrawReceiver.TryParseSnapshot(const ALayer,
  ACurrentFrame: Integer; const AText: string;
  out ASnapshot: TSerifDrawSnapshot): Boolean;
var
  FrameText: string;
  SpeechActiveText: string;
  SpeechProgressText: string;
  TimelineFrameText: string;
  TimelineTotalFramesText: string;
begin
  ASnapshot := System.Default(TSerifDrawSnapshot);
  ASnapshot.Layer := ALayer;
  ASnapshot.Chara := GetExactKeyValue(AText, 'chara');
  ASnapshot.Emote := GetExactKeyValue(AText, 'emote');
  ASnapshot.Direction := GetExactKeyValue(AText, 'direction');
  ASnapshot.SourceObjectID := GetExactKeyValue(AText, 'source_object');
  ASnapshot.UID := GetExactKeyValue(AText, 'uid');
  ASnapshot.Serif := GetExactKeyValue(AText, 'serif');
  SpeechProgressText := GetExactKeyValue(AText, 'speech_progress');
  if not TryStrToFloat(SpeechProgressText, ASnapshot.SpeechProgress) then
    ASnapshot.SpeechProgress := 0.0;
  ASnapshot.SpeechProgress := EnsureRange(ASnapshot.SpeechProgress, 0.0, 1.0);
  SpeechActiveText := GetExactKeyValue(AText, 'speech_active');
  ASnapshot.SpeechActive := (SpeechActiveText = '1') or
    SameText(SpeechActiveText, 'true');
  TimelineFrameText := GetExactKeyValue(AText, 'frame');
  if not TryStrToInt(TimelineFrameText, ASnapshot.TimelineFrame) then
    ASnapshot.TimelineFrame := 0;
  TimelineTotalFramesText := GetExactKeyValue(AText, 'total_frames');
  if not TryStrToInt(TimelineTotalFramesText,
    ASnapshot.TimelineTotalFrames) or (ASnapshot.TimelineTotalFrames < 1) then
    ASnapshot.TimelineTotalFrames := 1;
  FrameText := GetExactKeyValue(AText, 'current_frame');
  Result := (ASnapshot.SourceObjectID <> '') and (ASnapshot.UID <> '') and
    (ASnapshot.Serif <> '') and
    TryStrToInt(FrameText, ASnapshot.CurrentFrame) and
    (ASnapshot.CurrentFrame = ACurrentFrame);
{$IFDEF DEBUG}
  ReceiverDebugLog(Format(
    'snapshot layer=%d accepted=%d requested=%d published=%s source=%s uid=%d serif=%d speech=%d progress=%.4f',
    [ALayer, Ord(Result), ACurrentFrame, FrameText,
     ASnapshot.SourceObjectID, Length(ASnapshot.UID), Length(ASnapshot.Serif),
     Ord(ASnapshot.SpeechActive), ASnapshot.SpeechProgress]));
{$ENDIF}
end;

end.
