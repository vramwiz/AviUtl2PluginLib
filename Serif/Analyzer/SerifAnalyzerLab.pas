unit SerifAnalyzerLab;


// 外部LABファイルを新旧朗2内部LAB形式へ変換するためのユニット。
//
// 外部LABは音素表記や時間単位に方言があるため、このユニットで
// 読込直後に以下の形式へ統一する。
//
//   開始時間100ns,終了時間100ns,内部音素
//
// 例:
//   0,1000000,Pause
//   1000000,2739967,O
//
// 後段のモジュール、共有メモリ、描画処理では外部LAB方言を扱わず、
// ここで正規化済みの文字列だけを扱う。

interface

uses
  System.SysUtils, System.Classes, System.Math, SerifSceneMsgList;

// セリフリスト内の各Msg.Labsを内部共通LAB形式へ変換する。
procedure NormalizeSerifMsgLabs(Msgs: TSerifSceneMsgList);

// 1件のMsg.Labsを内部共通LAB形式へ変換する。
procedure NormalizeSerifMsgLab(Msg: TSerifSceneMsgItem);
// 内部共通LABを指定秒以降で切り詰める。
procedure TrimSerifMsgLabAfterSec(Msg: TSerifSceneMsgItem; EndSec: Double);

implementation

const
  SERIF_LAB_WRITE_COMPACT_TIME = True; // Talk用LAB生成を t開始秒,長さ秒,命令 形式に圧縮する。Falseで従来形式へ戻す。

type
  TSerifLabEntry = record
    StartTime : Double;
    EndTime   : Double;
    Start100ns: Int64;
    End100ns  : Int64;
    Phoneme   : string;
  end;

  TSerifLabEntries = array of TSerifLabEntry;

function FormatCompactLabTime100ns(Value100ns: Int64): string;
var
  IntPart, FracPart: Int64;
  FracText: string;
begin
  // 100ns単位を秒表記へ変換し、小数点以下の不要な0を落として桁数を抑える。
  if Value100ns <= 0 then Exit('0');

  IntPart := Value100ns div 10000000;
  FracPart := Value100ns mod 10000000;
  if FracPart = 0 then
    Exit(IntToStr(IntPart));

  FracText := Format('%.7d', [FracPart]);
  while (FracText <> '') and (FracText[Length(FracText)] = '0') do
    Delete(FracText, Length(FracText), 1);

  if IntPart = 0 then
    Result := '.' + FracText
  else
    Result := IntToStr(IntPart) + '.' + FracText;
end;

function TryParseCompactLabTime100ns(const S: string; out Value100ns: Int64): Boolean;
var
  T, IntText, FracText: string;
  P, I: Integer;
  IntPart, FracPart: Int64;
begin
  // t付き内部LABの秒表記を100ns単位へ正確に戻す。小数は最大7桁を有効にする。
  Result := False;
  Value100ns := 0;
  T := Trim(S);
  if T = '' then Exit;

  P := Pos('.', T);
  if P = 0 then
  begin
    if not TryStrToInt64(T, IntPart) then Exit;
    if IntPart < 0 then Exit;
    if IntPart > High(Int64) div 10000000 then Exit;
    Value100ns := IntPart * 10000000;
    Exit(True);
  end;

  IntText := Copy(T, 1, P - 1);
  FracText := Copy(T, P + 1, MaxInt);
  if IntText = '' then IntText := '0';
  if FracText = '' then FracText := '0';
  if Length(FracText) > 7 then Exit;

  for I := 1 to Length(FracText) do
    if not CharInSet(FracText[I], ['0'..'9']) then Exit;
  while Length(FracText) < 7 do
    FracText := FracText + '0';

  if not TryStrToInt64(IntText, IntPart) then Exit;
  if not TryStrToInt64(FracText, FracPart) then Exit;
  if IntPart < 0 then Exit;
  if IntPart > High(Int64) div 10000000 then Exit;
  Value100ns := IntPart * 10000000 + FracPart;
  Result := True;
end;

function FormatSerifLabLine(Start100ns, End100ns: Int64; const Command: string): string;
var
  Duration100ns: Int64;
begin
  // t付き行は開始と長さを秒表記にし、1行単位のデータ量を抑える。
  if SERIF_LAB_WRITE_COMPACT_TIME then
  begin
    Duration100ns := End100ns - Start100ns;
    Result := 't' + FormatCompactLabTime100ns(Start100ns) + ',' +
              FormatCompactLabTime100ns(Duration100ns) + ',' +
              Command;
    Exit;
  end;

  // 互換性確認や問題切り分け用に、従来の start,end,command 形式へ戻せるようにする。
  Result := IntToStr(Start100ns) + ',' +
            IntToStr(End100ns) + ',' +
            Command;
end;

function TryStrToLabFloat(const S: string; out Value: Double): Boolean;
var
  FS: TFormatSettings;
  T : string;
begin
  // LAB時刻は小数点表記の可能性があるため、現在ロケールと'.'小数点の両方を試す。
  T := Trim(S);
  Result := TryStrToFloat(T, Value);
  if Result then Exit;

  FS := FormatSettings;
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := ',';
  Result := TryStrToFloat(T, Value, FS);
end;

function NormalizeLabPhoneme(const S: string): string;
var
  P: string;
  N: Integer;
begin
  // 外部LABの音素方言を、後段が扱う内部共通音素へ寄せる。
  P := Trim(S);
  if P = '' then Exit('Pause');

  // WAV音量解析由来の内部命令。音素ではないためそのまま保持する。
  if Copy(LowerCase(P), 1, 4) = 'vol:' then
  begin
    if TryStrToInt(Copy(P, 5, MaxInt), N) then
      Exit('vol:' + IntToStr(EnsureRange(N, 0, 100)));
    Exit('vol:0');
  end;

  if SameText(P, 'a') or (P = 'あ') then Exit('A');
  if SameText(P, 'i') or (P = 'い') then Exit('I');
  if SameText(P, 'u') or (P = 'う') then Exit('U');
  if SameText(P, 'e') or (P = 'え') then Exit('E');
  if SameText(P, 'o') or (P = 'お') then Exit('O');
  if SameText(P, 'n') or (P = 'ん') then Exit('N');

  if SameText(P, 'Pause') or
     SameText(P, 'pau') or SameText(P, 'sil') or
     SameText(P, 'sp')  or SameText(P, 'R')   or
     SameText(P, 'silB') or SameText(P, 'silE') then
    Exit('Pause');

  if SameText(P, 'Consonant') then Exit('Consonant');

  Result := 'Consonant';
end;

function TryParseLabLine(const Line: string; out Entry: TSerifLabEntry): Boolean;
var
  S: string;
  Tokens: TStringList;
  Start100ns, Duration100ns: Int64;
begin
  // 外部LABの1行を「開始 終了 音素」として読み取る。
  // 区切りは空白、タブ、カンマを許容する。
  Result := False;
  S := Trim(Line);
  if S = '' then Exit;
  if (S[1] = '#') or (S[1] = ';') then Exit;

  S := StringReplace(S, ',', ' ', [rfReplaceAll]);
  Tokens := TStringList.Create;
  try
    ExtractStrings([' ', #9], [], PChar(S), Tokens);
    if Tokens.Count < 3 then Exit;

    // t付き内部LABは 開始秒,長さ秒 形式として読み、既存データ再正規化時も壊さない。
    if (Length(Tokens[0]) >= 2) and SameText(Copy(Tokens[0], 1, 1), 't') then
    begin
      if not TryParseCompactLabTime100ns(Copy(Tokens[0], 2, MaxInt), Start100ns) then Exit;
      if not TryParseCompactLabTime100ns(Tokens[1], Duration100ns) then Exit;
      if Start100ns < 0 then Start100ns := 0;
      if Duration100ns <= 0 then Exit;
      Entry.StartTime := Start100ns;
      Entry.EndTime := Start100ns + Duration100ns;
      Entry.Phoneme := NormalizeLabPhoneme(Tokens[2]);
      Exit(True);
    end;

    if not TryStrToLabFloat(Tokens[0], Entry.StartTime) then Exit;
    if not TryStrToLabFloat(Tokens[1], Entry.EndTime) then Exit;
    if Entry.StartTime < 0 then Entry.StartTime := 0;
    if Entry.EndTime <= Entry.StartTime then Exit;
    Entry.Phoneme := NormalizeLabPhoneme(Tokens[2]);
    Result := True;
  finally
    Tokens.Free;
  end;
end;

function InferLabTimeFactor(const LastEndTime, WaveLength: Double): Double;
const
  FACTOR_COUNT = 4;
  FACTORS: array[0..FACTOR_COUNT - 1] of Double = (1, 10, 10000, 10000000);
var
  i, BestIndex: Integer;
  Target100ns, Value100ns, Diff, BestDiff: Double;

  function HeuristicScore(const Factor: Double): Double;
  var
    Sec: Double;
  begin
    Sec := LastEndTime * Factor / 10000000;
    if (Sec >= 1.0) and (Sec <= 10.0) then
      Result := 0
    else if Sec < 1.0 then
      Result := 1.0 - Sec
    else
      Result := Sec - 10.0;
  end;

begin
  // LABには時間単位情報がないため、WAV長に最も近くなる単位を選ぶ。
  // 候補は 100ns、us、ms、sec。WAV長がない場合は一般的なセリフ長を基準にする。
  BestIndex := 0;
  BestDiff := 1.0E308;

  if WaveLength > 0 then
  begin
    Target100ns := WaveLength * 10000000;
    for i := Low(FACTORS) to High(FACTORS) do
    begin
      Value100ns := LastEndTime * FACTORS[i];
      Diff := Abs(Value100ns - Target100ns);
      if Diff < BestDiff then
      begin
        BestDiff := Diff;
        BestIndex := i;
      end;
    end;
  end
  else
  begin
    for i := Low(FACTORS) to High(FACTORS) do
    begin
      Diff := HeuristicScore(FACTORS[i]);
      if Diff < BestDiff then
      begin
        BestDiff := Diff;
        BestIndex := i;
      end;
    end;
  end;

  Result := FACTORS[BestIndex];
end;

procedure SortLabEntries(var Entries: TSerifLabEntries);
var
  i, j: Integer;
  T: TSerifLabEntry;
begin
  // 後段で時系列前提にできるよう、開始時刻で昇順に並べる。
  for i := Low(Entries) to High(Entries) - 1 do
    for j := i + 1 to High(Entries) do
      if Entries[i].StartTime > Entries[j].StartTime then
      begin
        T := Entries[i];
        Entries[i] := Entries[j];
        Entries[j] := T;
      end;
end;

procedure NormalizeSerifMsgLab(Msg: TSerifSceneMsgItem);
var
  i, Count: Integer;
  Entry: TSerifLabEntry;
  Entries: TSerifLabEntries;
  Factor, LastEnd: Double;
  PrevEnd: Int64;
begin
  // Msg.Labsに読み込まれた外部LAB文字列を、内部共通LAB文字列へ置き換える。
  if Msg.Labs.Count = 0 then Exit;

  Count := 0;
  for i := 0 to Msg.Labs.Count - 1 do
  begin
    if not TryParseLabLine(Msg.Labs[i], Entry) then Continue;
    SetLength(Entries, Count + 1);
    Entries[Count] := Entry;
    Inc(Count);
  end;

  if Count = 0 then
  begin
    Msg.Labs.Clear;
    Exit;
  end;

  SortLabEntries(Entries);
  LastEnd := 0;
  for i := Low(Entries) to High(Entries) do
    if Entries[i].EndTime > LastEnd then
      LastEnd := Entries[i].EndTime;

  Factor := InferLabTimeFactor(LastEnd, Msg.WaveLength);

  Msg.Labs.BeginUpdate;
  try
    Msg.Labs.Clear;
    PrevEnd := 0;
    for i := Low(Entries) to High(Entries) do
    begin
      // すべての時刻を内部標準の100ns単位へ変換する。
      Entries[i].Start100ns := Round(Entries[i].StartTime * Factor);
      Entries[i].End100ns   := Round(Entries[i].EndTime   * Factor);
      // 重なりがある場合は前Endに寄せ、時系列の破綻を後段へ持ち込まない。
      if Entries[i].Start100ns < PrevEnd then
        Entries[i].Start100ns := PrevEnd;
      if Entries[i].End100ns <= Entries[i].Start100ns then
        Continue;
      Msg.Labs.Add(FormatSerifLabLine(Entries[i].Start100ns, Entries[i].End100ns, Entries[i].Phoneme));
      PrevEnd := Entries[i].End100ns;
    end;
  finally
    Msg.Labs.EndUpdate;
  end;
end;

procedure TrimSerifMsgLabAfterSec(Msg: TSerifSceneMsgItem; EndSec: Double);
var
  i: Integer;
  Entry: TSerifLabEntry;
  Entries: TSerifLabEntries;
  Count: Integer;
  End100ns: Int64;
begin
  if Msg = nil then Exit;
  if Msg.Labs.Count = 0 then Exit;
  if EndSec <= 0 then
  begin
    Msg.Labs.Clear;
    Exit;
  end;

  End100ns := Round(EndSec * 10000000);
  Count := 0;
  for i := 0 to Msg.Labs.Count - 1 do
  begin
    if not TryParseLabLine(Msg.Labs[i], Entry) then Continue;
    Entry.Start100ns := Round(Entry.StartTime);
    Entry.End100ns := Round(Entry.EndTime);

    if Entry.Start100ns >= End100ns then
      Continue;
    if Entry.End100ns > End100ns then
      Entry.End100ns := End100ns;
    if Entry.End100ns <= Entry.Start100ns then
      Continue;

    SetLength(Entries, Count + 1);
    Entries[Count] := Entry;
    Inc(Count);
  end;

  Msg.Labs.BeginUpdate;
  try
    Msg.Labs.Clear;
    for i := 0 to Count - 1 do
      Msg.Labs.Add(FormatSerifLabLine(Entries[i].Start100ns, Entries[i].End100ns, Entries[i].Phoneme));
  finally
    Msg.Labs.EndUpdate;
  end;
end;

procedure NormalizeSerifMsgLabs(Msgs: TSerifSceneMsgList);
var
  i: Integer;
begin
  // 解析済みセリフ全体にLAB正規化を適用する。
  for i := 0 to Msgs.Count - 1 do
    NormalizeSerifMsgLab(Msgs[i]);
end;

end.
