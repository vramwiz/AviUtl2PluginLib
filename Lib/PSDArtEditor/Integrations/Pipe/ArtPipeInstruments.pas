// 楽器用PSDの固定階層を読み取り、制作ガイドを返す。文書は変更しない。
unit ArtPipeInstruments;

interface

uses System.JSON, ArtDocument;

// JSONの所有権は呼び出し側へ渡す。画像内容や差分の完成度は判定しない。
function InstrumentDocumentJson(Document: TArtDocument): TJSONObject;

implementation

uses System.SysUtils, System.Generics.Collections, ArtLayerName;

const
  InstrumentTypes: array[0..8] of string = ('ギター', 'ベース', 'ドラム', '鍵盤', '弓奏',
    '前方構え＋キー操作', '横構え＋キー操作', '前方構え＋バルブ操作', '前方構え＋スライド操作');

function StringsJson(const Values: array of string): TJSONArray;
begin
  Result := TJSONArray.Create;
  for var Value in Values do Result.Add(Value);
end;

function TypeIndex(const Name: string): Integer;
begin
  // 提供仕様の「ストリングス」は演奏属性を共有する「弓奏」の別名。
  if Name = 'ストリングス' then Exit(4);
  for Result := Low(InstrumentTypes) to High(InstrumentTypes) do
    if Name = InstrumentTypes[Result] then Exit;
  Result := -1;
end;

function TemplateJson(Index: Integer): TJSONObject;
var Parts: TJSONArray;
  procedure Part(const Name: string; const Positions, Patterns, Stages: array of string;
    const Note: string);
  var Json: TJSONObject;
  begin
    Json := TJSONObject.Create; Parts.AddElement(Json);
    Json.AddPair('name', Name);
    Json.AddPair('positions', StringsJson(Positions));
    Json.AddPair('patterns', StringsJson(Patterns));
    Json.AddPair('stages', StringsJson(Stages));
    Json.AddPair('note', Note);
  end;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('type', InstrumentTypes[Index]);
    if Index = 4 then Result.AddPair('aliases', StringsJson(['ストリングス']))
    else Result.AddPair('aliases', TJSONArray.Create);
    Result.AddPair('optionalPoses', StringsJson(['開始前ポーズ', '終了後ポーズ']));
    Result.AddPair('bodyMotion', '体・頭・上半身の揺れや傾きは再生時の変形で処理する');
    Result.AddPair('recommendationOnly', TJSONBool.Create(True));
    Parts := TJSONArray.Create; Result.AddPair('parts', Parts);
    case Index of
      0, 1: begin
        Result.AddPair('performanceAttributes', StringsJson(['押弦位置', '指パターン', '右手奏法', '足動作']));
        Part('楽器本体', [], [], [], '同一基準位置・サイズ。楽器ごとの位置補正はPNG配置で行う');
        Part('左腕', ['低位置', '中位置', '高位置'], [], [], '3位置を目安にする');
        Part('左手指', ['低位置', '中位置', '高位置'],
          ['単音', '2本押さえ', '3本押さえ', '4本押さえ', 'バレー'], [],
          '位置ごとに5パターン、計15程度。難しければ前腕～手を一体化する');
        if Index = 0 then
          Part('右手', [], ['ストローク', 'ピッキング', 'アルペジオ', 'ミュート', '指弾き'],
            ['上', '中', '下'], '採用する奏法ごとに2～4段階')
        else Part('右手', [], ['指弾き', 'ピック弾き', 'スラップ'],
          ['上', '中', '下'], '採用する奏法ごとに2～4段階');
        Part('右足', [], ['通常', 'かかと上げ', 'つま先上げ', '踏み込み'], [],
          '通常＋2～3差分を目安にする');
      end;
      2: begin
        Result.AddPair('performanceAttributes', StringsJson(['左右独立打点', '腕動作段階', 'キック', 'ハイハット']));
        Part('楽器本体', [], [], [], '左右同一打点は少しずらし、腕クロスの前後関係を固定する');
        Part('右足', [], ['通常', '踏み込み', '戻し'], [], '3差分程度');
        Part('左足', [], ['閉じ', '踏み込み途中', '開き'], [], '3差分程度');
        for var Side in ['左腕', '右腕'] do
          Part(Side, ['スネア', 'ハイハット', 'タム', 'フロアタム', 'クラッシュ', 'ライド'],
            [], ['振り上げ', '中間', '打点', '戻し'], '打点→動作段階の2段階ツリー。共用可能な差分は減らせる');
      end;
      3: begin
        Result.AddPair('performanceAttributes', StringsJson(['左右手位置', '鍵盤奏法', 'ペダル']));
        Part('楽器本体', [], [], [], 'キーボードとピアノで共通の階層を使う');
        for var Side in ['左手', '右手'] do
          Part(Side, ['左', '中', '右'],
            ['通常コード演奏', '分散和音', '単音メロディ', '高速演奏A', '高速演奏B', '長音保持', '手離し待機'],
            [], '位置3程度、採用する奏法に数段階。見えない指を細分化しない');
        Part('ペダル足', [], ['通常', '踏み込み'], [], '2差分程度');
      end;
      4: begin
        Result.AddPair('performanceAttributes', StringsJson(['押弦位置', '指パターン', '弓奏法', '弓位置']));
        Part('楽器本体', [], [], [], 'バイオリン・ビオラ・チェロ・コントラバスは正式名称ごとに保持する');
        Part('左手', ['低位置', '中位置', '高位置'], [], [], '各位置で4～5指パターン、計12～15程度');
        Part('右手', [], ['通常ボウイング', 'ピチカート', 'その他特殊奏法'],
          ['弓元', '中央', '弓先'], '奏法→動作段階。弓位置は弓を使う奏法に適用し、必要なら弦別に追加する');
      end;
      5..8: begin
        Result.AddPair('performanceAttributes', StringsJson([InstrumentTypes[Index], '通常演奏', '高速演奏', 'ロングトーン']));
        Part('楽器本体', [], [], [], '構え方と演奏属性を共有する種別の配下に正式名称を置く');
        Part('腕', [], ['通常演奏', '高速演奏', 'ロングトーン'], [], '構え方に合わせ、数段階の手／腕位置を用意する');
        case Index of
          5, 6: Part('左右手キー操作', [], [], [], '左右のキー操作差分。具体枚数は未確定');
          7: Part('バルブ操作', [], [], [], 'バルブ操作差分。具体枚数は未確定');
          8: Part('スライド位置', [], [], [], '数段階のスライド位置。具体枚数は未確定');
        end;
      end;
    end;
  except Result.Free; raise; end;
end;

function InstrumentDocumentJson(Document: TArtDocument): TJSONObject;
var Roots, Instruments, Templates, Warnings: TJSONArray;
  procedure Warn(const Code: string; Layer: TArtLayer; const MessageText: string);
  var Json: TJSONObject;
  begin
    Json := TJSONObject.Create; Warnings.AddElement(Json);
    Json.AddPair('code', Code);
    if Layer = nil then Json.AddPair('layerId', '') else Json.AddPair('layerId', Layer.Id);
    Json.AddPair('message', MessageText);
  end;
  procedure ReadRoot(Root: TArtLayer; EffectiveVisible: Boolean);
  var Category, Instrument: TArtLayer; Json: TJSONObject; Index, Count: Integer;
      Names: TDictionary<string, Boolean>; Name, TypeName: string;
  begin
    Json := TJSONObject.Create; Roots.AddElement(Json);
    Json.AddPair('layerId', Root.Id);
    Json.AddPair('effectiveVisible', TJSONBool.Create(EffectiveVisible));
    if Root.Children.Count = 0 then Warn('empty-root', Root, '楽器名の配下に楽器種別グループがありません');
    for Category in Root.Children do begin
      if Category.Kind = alkDivider then Continue;
      if Category.Kind <> alkGroup then begin
        Warn('type-not-group', Category, '楽器種別はグループで作成してください'); Continue;
      end;
      TypeName := ParseLayerName(Category.Name).DisplayName; Index := TypeIndex(TypeName);
      if Index < 0 then Warn('unknown-type', Category, '未対応の楽器種別です: ' + TypeName);
      Names := TDictionary<string, Boolean>.Create;
      try
        Count := 0;
        for Instrument in Category.Children do begin
          if Instrument.Kind = alkDivider then Continue;
          if Instrument.Kind <> alkGroup then begin
            Warn('instrument-not-group', Instrument, '楽器正式名称はグループで作成してください'); Continue;
          end;
          Name := ParseLayerName(Instrument.Name).DisplayName;
          if Trim(Name) = '' then begin
            Warn('empty-instrument-name', Instrument, '楽器正式名称を入力してください'); Continue;
          end;
          if Names.ContainsKey(Name) then Warn('duplicate-instrument-name', Instrument,
            '同じ種別内に同じ楽器正式名称があります。layerIdで区別してください')
          else Names.Add(Name, True);
          Inc(Count);
          Json := TJSONObject.Create; Instruments.AddElement(Json);
          Json.AddPair('rootLayerId', Root.Id); Json.AddPair('typeLayerId', Category.Id);
          Json.AddPair('layerId', Instrument.Id); Json.AddPair('type', TypeName);
          Json.AddPair('name', Name); Json.AddPair('layerName', Instrument.Name);
          Json.AddPair('recognized', TJSONBool.Create(Index >= 0));
          if Index >= 0 then Json.AddPair('templateType', InstrumentTypes[Index])
          else Json.AddPair('templateType', '');
          Json.AddPair('visible', TJSONBool.Create(Instrument.Visible));
          Json.AddPair('effectiveVisible', TJSONBool.Create(EffectiveVisible and Category.Visible and Instrument.Visible));
          if Instrument.Children.Count = 0 then Warn('empty-instrument', Instrument,
            '楽器の画像・演奏差分はまだありません');
        end;
        if Count = 0 then Warn('empty-type', Category, '楽器種別の配下に楽器正式名称グループがありません');
      finally Names.Free; end;
    end;
  end;
  procedure FindRoots(List: TList<TArtLayer>; ParentVisible: Boolean; Depth: Integer);
  var Layer: TArtLayer; EffectiveVisible: Boolean;
  begin
    if Depth > 128 then raise EArtFormat.Create('Instrument hierarchy is too deep');
    for Layer in List do begin
      EffectiveVisible := ParentVisible and Layer.Visible;
      if ParseLayerName(Layer.Name).DisplayName = '楽器名' then begin
        if Layer.Kind = alkGroup then ReadRoot(Layer, EffectiveVisible)
        else if Layer.Kind <> alkDivider then Warn('root-not-group', Layer, '楽器名はグループで作成してください');
      end;
      FindRoots(Layer.Children, EffectiveVisible, Depth + 1);
    end;
  end;
begin
  if Document = nil then raise EArtFormat.Create('No PSD is open');
  Result := TJSONObject.Create;
  try
    Result.AddPair('documentId', Document.SessionId);
    Result.AddPair('revision', UIntToStr(Document.Revision));
    Result.AddPair('fixedRootName', '楽器名');
    Roots := TJSONArray.Create; Result.AddPair('roots', Roots);
    Instruments := TJSONArray.Create; Result.AddPair('instruments', Instruments);
    Templates := TJSONArray.Create; Result.AddPair('templates', Templates);
    Warnings := TJSONArray.Create; Result.AddPair('warnings', Warnings);
    for var Index := Low(InstrumentTypes) to High(InstrumentTypes) do
      Templates.AddElement(TemplateJson(Index));
    FindRoots(Document.Roots, True, 0);
    Result.AddPair('found', TJSONBool.Create(Roots.Count > 0));
    if Roots.Count = 0 then Warn('missing-root', nil, '楽器名グループがありません。新規制作では固定階層を作成してください');
  except Result.Free; raise; end;
end;

end.
