// VOICEVOXのユーザー辞書APIと、登録用の読み・アクセント表示データを扱う。
unit SerifVoicevoxUserDictionary;

interface

type
  TSerifVoicevoxDictionaryWord = record
    UUID: string; // Engineが発行する単語ID。空は未登録を表す。
    Surface: string; // 読み替えの対象となる単語の表記。
    Pronunciation: string; // 辞書へ保存する全角カタカナの読み。
    WordType: string; // APIの品詞名。未対応の既存品詞は空にして明示選択を求める。
    AccentType: Integer; // 0は平板、1以降は音が下がる直前のモーラ位置。
    Priority: Integer; // 0～10。大きいほど辞書の読み方を優先する。
    // 新規単語の規定値。既存単語のUUIDは更新時にも引き継ぐ。
    class function NewWord: TSerifVoicevoxDictionaryWord; static;
    function SameValues(const Other: TSerifVoicevoxDictionaryWord): Boolean;
  end;

  TSerifVoicevoxUserDictionary = class
  private
    class function Request(const Method, Path: string; out Content, ErrorMessage: string): Boolean; static;
  public
    // Engineの辞書を読み取る。単語UUIDと品詞を維持し、更新・削除対象の識別に使う。
    class function Load(out Words: TArray<TSerifVoicevoxDictionaryWord>; out ErrorMessage: string): Boolean; static;
    // UUIDが空なら追加し、それ以外は同じUUIDを更新する。成功時だけUUIDを更新する。
    class function Save(var Word: TSerifVoicevoxDictionaryWord; out ErrorMessage: string): Boolean; static;
    // 指定した1単語だけを削除する。
    class function Delete(const UUID: string; out ErrorMessage: string): Boolean; static;
    // 現在の辞書で単語を解析し、カタカナの読みと推奨アクセントを返す。
    class function Analyze(const Surface: string; const StyleId: Integer;
      out Pronunciation: string; out AccentType: Integer; out ErrorMessage: string): Boolean; static;
    // ひらがな・半角カナを全角カタカナへ正規化する。保存の可否はEngineでも検証される。
    class function NormalizeReading(const Text: string): string; static;
    // Engineと同じモーラ分割規則で、アクセントの選択範囲と表示を作る。
    class function Moras(const Pronunciation: string): TArray<string>; static;
    // 辞書値の0（平板）と末尾で下がる型を、確認用の「ガ」を加えて描き分ける。
    class function AccentDisplay(const Pronunciation: string; const AccentType: Integer): string; static;
  end;

implementation

uses
  Winapi.Windows, System.Classes, System.SysUtils, System.JSON,
  System.Net.HttpClient, System.NetEncoding, System.RegularExpressions,
  SerifVoicevoxApi;

class function TSerifVoicevoxDictionaryWord.NewWord: TSerifVoicevoxDictionaryWord;
begin
  Result := Default(TSerifVoicevoxDictionaryWord);
  Result.WordType := 'PROPER_NOUN';
  Result.Priority := 5;
end;

function TSerifVoicevoxDictionaryWord.SameValues(const Other: TSerifVoicevoxDictionaryWord): Boolean;
begin
  Result := (UUID = Other.UUID) and (Surface = Other.Surface) and
    (Pronunciation = Other.Pronunciation) and (WordType = Other.WordType) and
    (AccentType = Other.AccentType) and (Priority = Other.Priority);
end;

function JsonText(Obj: TJSONObject; const Name: string): string;
var
  Value: TJSONValue;
begin
  Result := '';
  Value := Obj.GetValue(Name);
  if Value is TJSONString then Result := Value.Value;
end;

function DictionaryWordType(Obj: TJSONObject): string;
var
  Part: string;
  Detail: string;
begin
  Result := '';
  Part := JsonText(Obj, 'part_of_speech');
  Detail := JsonText(Obj, 'part_of_speech_detail_1');
  if (Part = '名詞') and (Detail = '固有名詞') then Result := 'PROPER_NOUN'
  else if (Part = '名詞') and (Detail = '一般') then Result := 'COMMON_NOUN'
  else if (Part = '名詞') and (Detail = '接尾') then Result := 'SUFFIX'
  else if Part = '動詞' then Result := 'VERB'
  else if Part = '形容詞' then Result := 'ADJECTIVE';
end;

class function TSerifVoicevoxUserDictionary.Request(const Method, Path: string;
  out Content, ErrorMessage: string): Boolean;
var
  Client: THTTPClient;
  Empty: TStringStream;
  Response: IHTTPResponse;
  Root: TJSONValue;
  Detail: TJSONValue;
  URL: string;
begin
  Result := False;
  Content := '';
  ErrorMessage := '';
  try
    Client := THTTPClient.Create;
    try
      Client.ConnectionTimeout := 3000;
      Client.ResponseTimeout := 15000;
      URL := 'http://127.0.0.1:50021' + Path;
      Empty := TStringStream.Create('', TEncoding.UTF8);
      try
        if Method = 'GET' then Response := Client.Get(URL)
        else if Method = 'POST' then Response := Client.Post(URL, Empty)
        else if Method = 'PUT' then Response := Client.Put(URL, Empty)
        else if Method = 'DELETE' then Response := Client.Delete(URL)
        else raise Exception.Create('辞書操作の種類が不正です。');
        Content := Response.ContentAsString(TEncoding.UTF8);
        if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
        begin
          ErrorMessage := Format('VOICEVOXの辞書操作に失敗しました（HTTP %d）。', [Response.StatusCode]);
          Root := TJSONObject.ParseJSONValue(Content);
          try
            if Root is TJSONObject then
            begin
              Detail := TJSONObject(Root).GetValue('detail');
              if Detail is TJSONString then ErrorMessage := ErrorMessage + sLineBreak + Detail.Value;
            end;
          finally
            Root.Free;
          end;
          Exit;
        end;
        Result := True;
      finally
        Empty.Free;
      end;
    finally
      Client.Free;
    end;
  except
    on E: Exception do ErrorMessage := 'VOICEVOXの辞書へ接続できませんでした。' + sLineBreak + E.Message;
  end;
end;

class function TSerifVoicevoxUserDictionary.Load(out Words: TArray<TSerifVoicevoxDictionaryWord>;
  out ErrorMessage: string): Boolean;
var
  Content: string;
  I: Integer;
  Obj: TJSONObject;
  Root: TJSONValue;
begin
  Result := False;
  Words := nil;
  if not Request('GET', '/user_dict', Content, ErrorMessage) then Exit;
  Root := TJSONObject.ParseJSONValue(Content);
  try
    try
      if not (Root is TJSONObject) then raise Exception.Create('辞書一覧の応答が不正です。');
      SetLength(Words, TJSONObject(Root).Count);
      for I := 0 to High(Words) do
      begin
        if not (TJSONObject(Root).Pairs[I].JsonValue is TJSONObject) then
          raise Exception.Create('単語の応答が不正です。');
        Obj := TJSONObject(TJSONObject(Root).Pairs[I].JsonValue);
        Words[I] := TSerifVoicevoxDictionaryWord.NewWord;
        Words[I].UUID := TJSONObject(Root).Pairs[I].JsonString.Value;
        Words[I].Surface := JsonText(Obj, 'surface');
        Words[I].Pronunciation := JsonText(Obj, 'pronunciation');
        Words[I].AccentType := Obj.GetValue<Integer>('accent_type');
        Words[I].Priority := Obj.GetValue<Integer>('priority', 5);
        Words[I].WordType := DictionaryWordType(Obj);
      end;
      Result := True;
    except
      on E: Exception do
      begin
        Words := nil;
        ErrorMessage := E.Message;
      end;
    end;
  finally
    Root.Free;
  end;
end;

class function TSerifVoicevoxUserDictionary.Save(var Word: TSerifVoicevoxDictionaryWord;
  out ErrorMessage: string): Boolean;
var
  Content: string;
  Method: string;
  Path: string;
  Root: TJSONValue;
begin
  Result := False;
  ErrorMessage := '';
  if (Trim(Word.Surface) = '') or (Word.WordType = '') or (Length(Moras(Word.Pronunciation)) = 0) then
  begin
    ErrorMessage := '単語・カタカナの読み・品詞を入力してください。';
    Exit;
  end;
  Path := '/user_dict_word';
  Method := 'POST';
  if Word.UUID <> '' then
  begin
    Path := Path + '/' + TNetEncoding.URL.Encode(Word.UUID);
    Method := 'PUT';
  end;
  Path := Path + '?surface=' + TNetEncoding.URL.Encode(Trim(Word.Surface)) +
    '&pronunciation=' + TNetEncoding.URL.Encode(Word.Pronunciation) +
    '&accent_type=' + IntToStr(Word.AccentType) +
    '&priority=' + IntToStr(Word.Priority) +
    '&word_type=' + TNetEncoding.URL.Encode(Word.WordType);
  if not Request(Method, Path, Content, ErrorMessage) then Exit;
  if Word.UUID = '' then
  begin
    Root := TJSONObject.ParseJSONValue(Content);
    try
      if not (Root is TJSONString) or (Root.Value = '') then
      begin
        ErrorMessage := '登録結果の単語IDを取得できませんでした。一覧を更新して登録結果を確認してください。';
        Exit;
      end;
      Word.UUID := Root.Value;
    finally
      Root.Free;
    end;
  end;
  Result := True;
end;

class function TSerifVoicevoxUserDictionary.Delete(const UUID: string; out ErrorMessage: string): Boolean;
var
  Content: string;
begin
  Result := False;
  ErrorMessage := '';
  if UUID = '' then Exit;
  Result := Request('DELETE', '/user_dict_word/' + TNetEncoding.URL.Encode(UUID), Content, ErrorMessage);
end;

class function TSerifVoicevoxUserDictionary.Analyze(const Surface: string; const StyleId: Integer;
  out Pronunciation: string; out AccentType: Integer; out ErrorMessage: string): Boolean;
var
  Content: string;
  I: Integer;
  J: Integer;
  Phrases: TJSONArray;
  Phrase: TJSONObject;
  Items: TJSONArray;
  Root: TJSONValue;
begin
  Result := False;
  Pronunciation := '';
  AccentType := 0;
  if not TSerifVoicevoxApi.CreateAudioQuery(Surface, StyleId, Content, ErrorMessage) then Exit;
  Root := TJSONObject.ParseJSONValue(Content);
  try
    try
      if not (Root is TJSONObject) then raise Exception.Create('読みの応答が不正です。');
      Phrases := TJSONObject(Root).GetValue<TJSONArray>('accent_phrases');
      if not Assigned(Phrases) then raise Exception.Create('読みを取得できませんでした。');
      for I := 0 to Phrases.Count - 1 do
      begin
        Phrase := Phrases.Items[I] as TJSONObject;
        Items := Phrase.GetValue<TJSONArray>('moras');
        if not Assigned(Items) then Continue;
        for J := 0 to Items.Count - 1 do
          Pronunciation := Pronunciation + TJSONObject(Items.Items[J]).GetValue<string>('text');
        if (Phrases.Count = 1) and (Phrase.GetValue<Integer>('accent') < Items.Count) then
          AccentType := Phrase.GetValue<Integer>('accent');
      end;
      Pronunciation := NormalizeReading(Pronunciation);
      if Length(Moras(Pronunciation)) = 0 then raise Exception.Create('単語のカタカナ読みを取得できませんでした。');
      Result := True;
    except
      on E: Exception do ErrorMessage := E.Message;
    end;
  finally
    Root.Free;
  end;
end;

class function TSerifVoicevoxUserDictionary.NormalizeReading(const Text: string): string;
var
  Count: Integer;
  Source: string;
begin
  Source := Trim(Text);
  Result := Source;
  if Source = '' then Exit;
  Count := LCMapString($0411, LCMAP_FULLWIDTH or LCMAP_KATAKANA, PChar(Source), Length(Source), nil, 0);
  if Count <= 0 then Exit;
  SetLength(Result, Count);
  if LCMapString($0411, LCMAP_FULLWIDTH or LCMAP_KATAKANA,
    PChar(Source), Length(Source), PChar(Result), Count) = 0 then Result := Source;
end;

class function TSerifVoicevoxUserDictionary.Moras(const Pronunciation: string): TArray<string>;
const
  Pattern = '[イ][ェ]|[ヴ][ャュョ]|[ウクグトド][ゥ]|[テデ][ィェャュョ]|[クグ][ヮ]|' +
    '[キシチニヒミリギジヂビピ][ェャュョ]|[キニヒミリギビピ][ィ]|' +
    '[クツフヴグ][ァ]|[ウクスツフヴグズ][ィ]|[ウクツフヴグ][ェォ]|[ァ-ヴー]';
var
  I: Integer;
  Matches: TMatchCollection;
begin
  Result := nil;
  if not TRegEx.IsMatch(Pronunciation, '^[ァ-ヴー]+$') then Exit;
  Matches := TRegEx.Matches(Pronunciation, Pattern);
  SetLength(Result, Matches.Count);
  for I := 0 to High(Result) do Result[I] := Matches.Item[I].Value;
end;

class function TSerifVoicevoxUserDictionary.AccentDisplay(const Pronunciation: string;
  const AccentType: Integer): string;
var
  DisplayAccent: Integer;
  Mora: string;
  Parts: TArray<string>;
  Root: TJSONObject;
  Phrases: TJSONArray;
  Phrase: TJSONObject;
  Items: TJSONArray;
begin
  Parts := Moras(Pronunciation);
  DisplayAccent := AccentType;
  if DisplayAccent = 0 then DisplayAccent := Length(Parts) + 1;
  Root := TJSONObject.Create;
  try
    Phrases := TJSONArray.Create;
    Root.AddPair('accent_phrases', Phrases);
    Phrase := TJSONObject.Create;
    Phrases.AddElement(Phrase);
    Phrase.AddPair('accent', TJSONNumber.Create(DisplayAccent));
    Items := TJSONArray.Create;
    Phrase.AddPair('moras', Items);
    for Mora in Parts do Items.AddElement(TJSONObject.Create.AddPair('text', Mora));
    Items.AddElement(TJSONObject.Create.AddPair('text', 'ガ'));
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

end.
