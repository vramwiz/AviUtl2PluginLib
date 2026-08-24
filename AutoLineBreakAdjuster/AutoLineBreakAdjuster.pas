unit AutoLineBreakAdjuster;

interface

uses
  System.SysUtils;

type
  TAutoLineBreakAdjuster = class
  private
    // 改行処理前の文字列を整形する
    function PrepareText(const S: string): string;
    // 指定位置で改行可能かを判定する
    function CanBreak(const S: string; BasePos: Integer): Boolean;
    // 文字列中の既存改行を除去する
    function RemoveCrLf(const S: string): string;
    // 指定位置ごとに仮の改行を挿入する
    function ApplyInitialBreakPhase(const S: string; BasePos: Integer): string;
    // 行頭禁則文字かどうかを判定する
    function IsLeadingProhibitedChar(const Ch: Char): Boolean;
    // 行末禁則文字かどうかを判定する
    function IsTrailingProhibitedChar(const Ch: Char): Boolean;
    // 漢字かどうかを判定する
    function IsKanji(const Ch: Char): Boolean;
    // カタカナかどうかを判定する
    function IsKatakana(const Ch: Char): Boolean;
    // 英字かどうかを判定する
    function IsAlphabet(const Ch: Char): Boolean;
    // 分割を避ける保護対象文字かどうかを判定する
    function IsProtectedChar(const Ch: Char): Boolean;
    // 改行直前の文字を次行へ送って改行位置を左へずらす
    procedure MoveBreakLeft(var S: string; BreakPos: Integer);
    // 連続する保護対象文字の途中を避ける
    function ApplyProtectedRunPhase(const S: string): string;
    // 行頭禁則文字が先頭に来ないよう改行位置を調整する
    function ApplyLeadingProhibitedCharPhase(const S: string): string;
    // 行末禁則文字が末尾に来ないよう改行位置を調整する
    function ApplyTrailingProhibitedCharPhase(const S: string): string;
  public
    // 指定位置を基準に文字列へ改行を挿入する
    function Adjust(const S: string; BasePos: Integer): string;
  end;

implementation

const
  LEADING_PROHIBITED_CHARS = '、。，．・：；？！)]）｝〕］】〉》」』〙〗ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮゕゖヵヶ';
  TRAILING_PROHIBITED_CHARS = '（「『【〈《〔';

function TAutoLineBreakAdjuster.Adjust(const S: string;
  BasePos: Integer): string;
var
  WorkText: string;
begin
  WorkText := PrepareText(S);

  if not CanBreak(WorkText, BasePos) then Exit(WorkText);

  WorkText := ApplyInitialBreakPhase(WorkText, BasePos);
  WorkText := ApplyProtectedRunPhase(WorkText);
  WorkText := ApplyLeadingProhibitedCharPhase(WorkText);
  WorkText := ApplyTrailingProhibitedCharPhase(WorkText);

  Result := WorkText;
end;

function TAutoLineBreakAdjuster.PrepareText(const S: string): string;
begin
  Result := RemoveCrLf(S);
end;

function TAutoLineBreakAdjuster.CanBreak(const S: string;
  BasePos: Integer): Boolean;
begin
  Result := False;

  if S = '' then Exit;

  if BasePos <= 0 then Exit;

  // Skip analysis when the text is shorter than the requested break position.
  if BasePos >= Length(S) then Exit;

  Result := True;
end;

function TAutoLineBreakAdjuster.ApplyInitialBreakPhase(const S: string;
  BasePos: Integer): string;
var
  SourcePos: Integer;
  Chunk: string;
begin
  Result := '';
  SourcePos := 1;

  while (Length(S) - SourcePos + 1) > BasePos do
  begin
    Chunk := Copy(S, SourcePos, BasePos);
    Result := Result + Chunk + #13#10;
    Inc(SourcePos, BasePos);
  end;

  Result := Result + Copy(S, SourcePos, MaxInt);
end;

procedure TAutoLineBreakAdjuster.MoveBreakLeft(var S: string; BreakPos: Integer);
var
  MoveChar: Char;
begin
  if BreakPos <= 1 then Exit;

  if BreakPos + 2 > Length(S) then Exit;

  MoveChar := S[BreakPos - 1];
  Delete(S, BreakPos - 1, 1);
  Insert(MoveChar, S, BreakPos + 1);
end;

function TAutoLineBreakAdjuster.ApplyProtectedRunPhase(const S: string): string;
var
  WorkText: string;
  BreakPos: Integer;
  MoveCount: Integer;
  MaxMoveCount: Integer;
begin
  WorkText := S;
  BreakPos := 2;
  MaxMoveCount := Length(WorkText);

  while BreakPos <= Length(WorkText) - 2 do
  begin
    if (WorkText[BreakPos] = #13) and (WorkText[BreakPos + 1] = #10) then
    begin
      // Never split inside Kanji, Katakana, or alphabet runs.
      // If the target lands inside a run, move the break to the left.
      MoveCount := 0;
      while (BreakPos > 1) and
            (BreakPos + 2 <= Length(WorkText)) and
            IsProtectedChar(WorkText[BreakPos - 1]) and
            IsProtectedChar(WorkText[BreakPos + 2]) and
            (MoveCount < MaxMoveCount) do
      begin
        MoveBreakLeft(WorkText, BreakPos);
        Dec(BreakPos);
        Inc(MoveCount);
      end;

      Inc(BreakPos, 2);
      Continue;
    end;

    Inc(BreakPos);
  end;

  Result := WorkText;
end;

function TAutoLineBreakAdjuster.ApplyLeadingProhibitedCharPhase(const S: string): string;
var
  WorkText: string;
  BreakPos: Integer;
  MoveCount: Integer;
  MaxMoveCount: Integer;
begin
  WorkText := S;
  BreakPos := 2;
  MaxMoveCount := Length(WorkText);

  while BreakPos <= Length(WorkText) - 2 do
  begin
    if (WorkText[BreakPos] = #13) and (WorkText[BreakPos + 1] = #10) then
    begin
      // Prevent prohibited punctuation from appearing at the start of the next line.
      MoveCount := 0;
      while (BreakPos > 1) and
            (BreakPos + 2 <= Length(WorkText)) and
            IsLeadingProhibitedChar(WorkText[BreakPos + 2]) and
            (MoveCount < MaxMoveCount) do
      begin
        MoveBreakLeft(WorkText, BreakPos);
        Dec(BreakPos);
        Inc(MoveCount);
      end;

      Inc(BreakPos, 2);
      Continue;
    end;

    Inc(BreakPos);
  end;

  Result := WorkText;
end;

function TAutoLineBreakAdjuster.ApplyTrailingProhibitedCharPhase(const S: string): string;
var
  WorkText: string;
  BreakPos: Integer;
  MoveCount: Integer;
  MaxMoveCount: Integer;
begin
  WorkText := S;
  BreakPos := 2;
  MaxMoveCount := Length(WorkText);

  while BreakPos <= Length(WorkText) - 2 do
  begin
    if (WorkText[BreakPos] = #13) and (WorkText[BreakPos + 1] = #10) then
    begin
      // Prevent opening punctuation from appearing at the end of the previous line.
      MoveCount := 0;
      while (BreakPos > 1) and
            IsTrailingProhibitedChar(WorkText[BreakPos - 1]) and
            (MoveCount < MaxMoveCount) do
      begin
        MoveBreakLeft(WorkText, BreakPos);
        Dec(BreakPos);
        Inc(MoveCount);
      end;

      Inc(BreakPos, 2);
      Continue;
    end;

    Inc(BreakPos);
  end;

  Result := WorkText;
end;

function TAutoLineBreakAdjuster.IsLeadingProhibitedChar(const Ch: Char): Boolean;
begin
  Result := Pos(Ch, LEADING_PROHIBITED_CHARS) > 0;
end;

function TAutoLineBreakAdjuster.IsTrailingProhibitedChar(const Ch: Char): Boolean;
begin
  Result := Pos(Ch, TRAILING_PROHIBITED_CHARS) > 0;
end;

function TAutoLineBreakAdjuster.IsKanji(const Ch: Char): Boolean;
begin
  Result :=
    ((Ch >= #$3400) and (Ch <= #$4DBF)) or
    ((Ch >= #$4E00) and (Ch <= #$9FFF)) or
    ((Ch >= #$F900) and (Ch <= #$FAFF));
end;

function TAutoLineBreakAdjuster.IsKatakana(const Ch: Char): Boolean;
begin
  Result :=
    ((Ch >= #$30A1) and (Ch <= #$30FA)) or
    ((Ch >= #$31F0) and (Ch <= #$31FF)) or
    (Ch = #$30FC);
end;

function TAutoLineBreakAdjuster.IsAlphabet(const Ch: Char): Boolean;
begin
  Result := ((Ch >= 'A') and (Ch <= 'Z')) or
            ((Ch >= 'a') and (Ch <= 'z'));
end;

function TAutoLineBreakAdjuster.IsProtectedChar(const Ch: Char): Boolean;
begin
  Result := IsKanji(Ch) or IsKatakana(Ch) or IsAlphabet(Ch);
end;

function TAutoLineBreakAdjuster.RemoveCrLf(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  I := 1;
  while I <= Length(Result) - 1 do
  begin
    if (Result[I] = #13) and (Result[I + 1] = #10) then
      Delete(Result, I, 2)
    else
      Inc(I);
  end;
end;

end.
