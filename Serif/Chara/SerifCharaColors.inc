// セリフのキャラ制作と表示設定が共用する名前・配色。既存の検索優先順を維持する。
type
  TCharaDef = record
    Name     : string;
    HexRGB   : string; // 基本色の #RRGGBB
    HexLight : string; // 明るい色の #RRGGBB
    HexDark  : string; // 暗い色の #RRGGBB
  end;

const
  SERIF_CHARA_COLOR_DEFS: array[0..112] of TCharaDef = (
    // VOICEROID
    (Name: '東北きりたん' ; HexRGB: '#FFFFFF'; HexLight: '#FFFFFF'; HexDark: '#A6A6A6'),
    (Name: '東北ずん子'   ; HexRGB: '#A8E6A8'; HexLight: '#C6EFC6'; HexDark: '#6D966D'),  // 淡いグリーン
    (Name: '結月ゆかり'   ; HexRGB: '#D6C8FF'; HexLight: '#E4DBFF'; HexDark: '#8B82A6'),  // 淡いラベンダー
    (Name: '弦巻マキ'     ; HexRGB: '#FFB7D1'; HexLight: '#FFD0E1'; HexDark: '#A67788'),  // 淡いピンク
    (Name: '琴葉茜'       ; HexRGB: '#FFB5C0'; HexLight: '#FFDDE4'; HexDark: '#E26D7D'),  // 3色サンプル: 茜
    (Name: '琴葉葵'       ; HexRGB: '#A8D4FF'; HexLight: '#D8ECFF'; HexDark: '#5FA6EA'),  // 3色サンプル: 葵
    (Name: '紲星あかり'   ; HexRGB: '#FFD8A0'; HexLight: '#FFE6C1'; HexDark: '#A68C68'),  // 淡いオレンジ
    (Name: '月読アイ'     ; HexRGB: '#FFDDEE'; HexLight: '#FFE9F4'; HexDark: '#A6909B'),  // さらに淡いピンク
    (Name: '月読ショウタ' ; HexRGB: '#CDEBFF'; HexLight: '#DEF2FF'; HexDark: '#8599A6'),  // 淡い水色（葵より白寄り）
    (Name: '京町セイカ'   ; HexRGB: '#A9F0E0'; HexLight: '#C7F5EB'; HexDark: '#6E9C92'),  // 淡い青緑
    (Name: '東北イタコ'   ; HexRGB: '#C9B4E6'; HexLight: '#DCCEEF'; HexDark: '#837596'),  // 淡い紫
    (Name: '音街ウナ'     ; HexRGB: '#AFCBFF'; HexLight: '#CBDDFF'; HexDark: '#7284A6'),  // 淡い青（ややパステル）
    // VOICEVOX
    (Name: '四国めたん'      ; HexRGB: '#FF99CC'; HexLight: '#FFBDDE'; HexDark: '#A66385'),  // はっきりした淡いピンク
    (Name: 'ずんだもん'      ; HexRGB: '#C6F5C6'; HexLight: '#E3FFE3'; HexDark: '#78C978'),  // 3色サンプル: ずんだグリーン
    (Name: '春日部つむぎ'    ; HexRGB: '#FFD6A8'; HexLight: '#FFE4C6'; HexDark: '#A68B6D'),  // 淡いオレンジ
    (Name: '雨晴はう'        ; HexRGB: '#C6E2FF'; HexLight: '#DAECFF'; HexDark: '#8193A6'),  // 淡い水色
    (Name: '波音リツ'        ; HexRGB: '#FFC6C6'; HexLight: '#FFDADA'; HexDark: '#A68181'),  // 淡い赤（ピンク寄り）
    (Name: '玄野武宏'        ; HexRGB: '#C8D0D8'; HexLight: '#DBE0E6'; HexDark: '#82878C'),  // 淡い青灰色
    (Name: '白上虎太郎'      ; HexRGB: '#E6E6E6'; HexLight: '#EFEFEF'; HexDark: '#969696'),  // 淡いグレー（白系）
    (Name: '青山龍星'        ; HexRGB: '#B8D4FF'; HexLight: '#D1E3FF'; HexDark: '#788AA6'),  // 淡いブルー
    (Name: '冥鳴ひまり'      ; HexRGB: '#C8C0B0'; HexLight: '#DBD6CC'; HexDark: '#827D72'),  // 髪色に近い灰ベージュ系
    (Name: '九州そら'        ; HexRGB: '#CFA7FF'; HexLight: '#E0C6FF'; HexDark: '#876DA6'),  // 一目で分かる薄い紫
    (Name: 'もち子さん'      ; HexRGB: '#F7F7F7'; HexLight: '#FAFAFA'; HexDark: '#A1A1A1'),  // ほぼ白の薄いグレー
    (Name: '†聖騎士紅桜†'    ; HexRGB: '#F8C6D8'; HexLight: '#FADAE6'; HexDark: '#A1818C'),  // 淡い紅色
    // VOICEVOX
    (Name: '剣崎雌雄'        ; HexRGB: '#D8E8E0'; HexLight: '#E6F0EB'; HexDark: '#8C9792'),  // 白灰＋薄緑寄り
    (Name: 'WhiteCUL'        ; HexRGB: '#E6F0FF'; HexLight: '#EFF5FF'; HexDark: '#969CA6'),  // 氷色の薄いブルー
    (Name: '後鬼'            ; HexRGB: '#BBD6FF'; HexLight: '#D3E4FF'; HexDark: '#7A8BA6'),  // 髪色ベースの淡い青
    (Name: 'No.7'            ; HexRGB: '#E2F0F5'; HexLight: '#ECF5F8'; HexDark: '#939C9F'),  // 白系シアン
    (Name: 'ちび式じい'      ; HexRGB: '#F5D9FF'; HexLight: '#F8E6FF'; HexDark: '#9F8DA6'),  // 淡い紫ピンク
    (Name: '櫻歌ミコ'        ; HexRGB: '#FFD6E6'; HexLight: '#FFE4EF'; HexDark: '#A68B96'),  // 桜色の淡ピンク
    (Name: '小夜/SAYO'       ; HexRGB: '#EBD6D6'; HexLight: '#F2E4E4'; HexDark: '#998B8B'),  // 白×赤系の淡いローズ
    (Name: 'ナースロボ_タイプT'; HexRGB: '#FFF0D6'; HexLight: '#FFF5E4'; HexDark: '#A69C8B'),  // 看護系イメージの淡クリーム
    (Name: '雀松朱司'        ; HexRGB: '#FFCCB8'; HexLight: '#FFDED1'; HexDark: '#A68578'),  // 髪色ベースの薄橙ピンク
    (Name: '魁ヶ島宗麟'      ; HexRGB: '#D6E2C0'; HexLight: '#E4ECD6'; HexDark: '#8B937D'),  // 和風の淡い緑黄
    // VOICEVOX
    (Name: '春歌ナナ'       ; HexRGB: '#FFE6F5'; HexLight: '#FFEFF8'; HexDark: '#A6969F'),  // ピンク＋黄の淡色
    (Name: '猫使アル'       ; HexRGB: '#FFD6D6'; HexLight: '#FFE4E4'; HexDark: '#A68B8B'),  // 赤髪の淡ピンク
    (Name: '猫使ビィ'       ; HexRGB: '#C6E8FF'; HexLight: '#DAF0FF'; HexDark: '#8197A6'),  // 明るい水色
    (Name: '中国うさぎ'     ; HexRGB: '#E8E8E8'; HexLight: '#F0F0F0'; HexDark: '#979797'),  // 白＋黒の淡グレー
    (Name: '栗田まろん'     ; HexRGB: '#F2E0D0'; HexLight: '#F7EBE0'; HexDark: '#9D9287'),  // 茶髪の淡いベージュ
    (Name: 'あいえるたん'   ; HexRGB: '#FFD8FF'; HexLight: '#FFE6FF'; HexDark: '#A68CA6'),  // 紫ピンクの淡色
    (Name: '満別花丸'       ; HexRGB: '#E8EFC6'; HexLight: '#F0F5DA'; HexDark: '#979B81'),  // 黄緑系の淡い色
    (Name: '琴詠ニア'       ; HexRGB: '#D6D6E8'; HexLight: '#E4E4F0'; HexDark: '#8B8B97'),  // 暗色髪 → 淡紫グレー
    (Name: 'Voidoll'        ; HexRGB: '#D6F5FF'; HexLight: '#E4F8FF'; HexDark: '#8B9FA6'),  // シアン寄りロボイメージ
    (Name: 'ぞん子'         ; HexRGB: '#FFD6CC'; HexLight: '#FFE4DE'; HexDark: '#A68B85'),  // サーモン系の薄橙ピンク
    (Name: '中部つるぎ'     ; HexRGB: '#E0F0C6'; HexLight: '#EBF5DA'; HexDark: '#929C81'),  // 若草色を薄く
    (Name: '離途'           ; HexRGB: '#D6DCEB'; HexLight: '#E4E8F2'; HexDark: '#8B8F99'),  // 青紫の淡グレー
    (Name: '黒沢冥白'       ; HexRGB: '#E0D8D0'; HexLight: '#EBE6E0'; HexDark: '#928C87'),  // 暗め髪 →淡いベージュグレー
    (Name: 'ユーレイちゃん' ; HexRGB: '#C6F0FF'; HexLight: '#DAF5FF'; HexDark: '#819CA6'),  // 氷色の淡いブルー
    // VOICEVOX
    (Name: 'あんこもん'     ; HexRGB: '#F0E0C8'; HexLight: '#F5EBDB'; HexDark: '#9C9282'),  // あんこ系の淡いベージュ
    (Name: '夜語トバリ'     ; HexRGB: '#D8D0E8'; HexLight: '#E6E0F0'; HexDark: '#8C8797'),  // 夜色イメージの淡い紫
    (Name: '暁記ミタマ'     ; HexRGB: '#FFE0D0'; HexLight: '#FFEBE0'; HexDark: '#A69287'),  // 暁色の淡いサーモン
    (Name: '里石ユカ'       ; HexRGB: '#D8F0E0'; HexLight: '#E6F5EB'; HexDark: '#8C9C92'),  // 石と草色の淡いミント
    // AIVOICE
    (Name: '伊織弓鶴'          ; HexRGB: '#D6E0FF'; HexLight: '#E4EBFF'; HexDark: '#8B92A6'),  // 青髪の淡いブルー
    (Name: 'つくよみちゃん'    ; HexRGB: '#FFE0F5'; HexLight: '#FFEBF8'; HexDark: '#A6929F'),  // ピンク寄りの薄桜色
    (Name: 'つくよみちゃん（幼）'; HexRGB: '#FFEAF7'; HexLight: '#FFF1FA'; HexDark: '#A698A1'),  // 幼児版 → さらに柔らかい桜色
    (Name: '小春音アミ'        ; HexRGB: '#F6EBD6'; HexLight: '#F9F2E4'; HexDark: '#A0998B'),  // 茶系の淡ベージュ
    (Name: '小春音アミ2'       ; HexRGB: '#F7F2E0'; HexLight: '#FAF7EB'; HexDark: '#A19D92'),  // 新版 → より白寄りの淡ベージュ
    (Name: '犬鳴めい'          ; HexRGB: '#E0F7FF'; HexLight: '#EBFAFF'; HexDark: '#92A1A6'),  // 水色の柔らかパステル
    // AIVOICE
    (Name: '彩澄りりせ'      ; HexRGB: '#FFE6F0'; HexLight: '#FFEFF5'; HexDark: '#A6969C'),  // ピンク寄り、りりせの柔らか本色
    (Name: '彩澄しゅお'      ; HexRGB: '#FFF0E0'; HexLight: '#FFF5EB'; HexDark: '#A69C92'),  // しゅお → 黄色寄りの淡クリーム
    (Name: 'たみ'            ; HexRGB: '#E6F5D6'; HexLight: '#EFF8E4'; HexDark: '#969F8B'),  // 緑髪 → 淡い若草色
    (Name: '白咲めあ'        ; HexRGB: '#E8F5FF'; HexLight: '#F0F8FF'; HexDark: '#979FA6'),  // 白青系 → 氷青
    (Name: '白咲ゆず'        ; HexRGB: '#FFF7E0'; HexLight: '#FFFAEB'; HexDark: '#A6A192'),  // 柔らかレモン色
    (Name: '花隈千冬'        ; HexRGB: '#E8D6F5'; HexLight: '#F0E4F8'; HexDark: '#978B9F'),  // 紫髪 → 淡いラベンダー
    // AIVOICE
    (Name: '満月るな'         ; HexRGB: '#FFE6D6'; HexLight: '#FFEFE4'; HexDark: '#A6968B'),  // 橙髪 → 淡サーモン
    (Name: '星界使者ルーナ'   ; HexRGB: '#D6F0FF'; HexLight: '#E4F5FF'; HexDark: '#8B9CA6'),  // 宇宙系 → 淡青
    (Name: '星界使者ルウナ'   ; HexRGB: '#F0D6FF'; HexLight: '#F5E4FF'; HexDark: '#9C8BA6'),  // 紫寄り → 薄ライラック
    (Name: '海声 夏凪'        ; HexRGB: '#D6F7F2'; HexLight: '#E4FAF7'; HexDark: '#8BA19D'),  // 海色 → 淡ターコイズ
    (Name: 'つくよみちゃん2'  ; HexRGB: '#FFE0F0'; HexLight: '#FFEBF5'; HexDark: '#A6929C'),  // 第二版 → ほんのり濃い桜色
    (Name: '雪菜ゆき'         ; HexRGB: '#F0F8FF'; HexLight: '#F5FAFF'; HexDark: '#9CA1A6'),  // 雪色 → 白に近い淡水色
    // VOICEPEAK
    (Name: '麒一くん'          ; HexRGB: '#D6E8FF'; HexLight: '#E4F0FF'; HexDark: '#8B97A6'),  // 青髪 → 淡ブルー
    (Name: '桜乃そら'          ; HexRGB: '#FFE6F5'; HexLight: '#FFEFF8'; HexDark: '#A6969F'),  // ピンク髪 → 桜色パステル
    (Name: '桜乃そら（青年）'   ; HexRGB: '#E0D6F5'; HexLight: '#EBE4F8'; HexDark: '#928B9F'),  // 紫系の髪 → 淡ライラック
    (Name: '桜乃そら（子ども）'; HexRGB: '#FFF0FA'; HexLight: '#FFF5FC'; HexDark: '#A69CA2'),  // 子ども版 → さらに明るい桜色
    (Name: 'ちび桜乃そら'      ; HexRGB: '#FFEAF7'; HexLight: '#FFF1FA'; HexDark: '#A698A1'),  // 超淡いピンク
    (Name: '城澤京'            ; HexRGB: '#E0F0E8'; HexLight: '#EBF5F0'; HexDark: '#929C97'),  // 緑系髪 → 明るいミント
    (Name: '榊原睦月'          ; HexRGB: '#F2E6D6'; HexLight: '#F7EFE4'; HexDark: '#9D968B'),  // 茶髪 → 淡ベージュ
    (Name: '宮舞モカ'          ; HexRGB: '#F5D6C8'; HexLight: '#F8E4DB'; HexDark: '#9F8B82'),  // やわらかいモカ色
    // VOICEPEAK
    (Name: '坂本アヒル'        ; HexRGB: '#FFF2C6'; HexLight: '#FFF7DA'; HexDark: '#A69D81'),  // 黄色 → 明るいクリーム
    (Name: '猫山トラオ'        ; HexRGB: '#F5D6A8'; HexLight: '#F8E4C6'; HexDark: '#9F8B6D'),  // オレンジ寄り → 淡サーモン
    (Name: '女性1（やさしい）' ; HexRGB: '#E8F5FF'; HexLight: '#F0F8FF'; HexDark: '#979FA6'),  // 透明感のある淡青
    (Name: '女性2（元気）'     ; HexRGB: '#FFE8D6'; HexLight: '#FFF0E4'; HexDark: '#A6978B'),  // 明るい橙 → 淡ピーチ
    (Name: '女性3（おしとやか）'; HexRGB: '#E8D6F5'; HexLight: '#F0E4F8'; HexDark: '#978B9F'),  // 紫寄り → 淡ラベンダー
    (Name: '男性1（落ち着いた）'; HexRGB: '#E0E0E0'; HexLight: '#EBEBEB'; HexDark: '#929292'),  // 落ち着き → 淡グレー
    (Name: '男性2（自然）'     ; HexRGB: '#E0F0D6'; HexLight: '#EBF5E4'; HexDark: '#929C8B'),  // 自然 → 淡い若草色
    // CEVIO
    (Name: 'さとうささら'    ; HexRGB: '#FFE6F5'; HexLight: '#FFEFF8'; HexDark: '#A6969F'),  // ピンク系の淡色
    (Name: 'すずきつづみ'    ; HexRGB: '#E6F0FF'; HexLight: '#EFF5FF'; HexDark: '#969CA6'),  // 水色の淡色
    (Name: 'タカハシ'        ; HexRGB: '#E0E0E0'; HexLight: '#EBEBEB'; HexDark: '#929292'),  // 無個性ベース → 明るい灰色
    (Name: 'IA（CeVIO AI）'  ; HexRGB: '#FFF0FA'; HexLight: '#FFF5FC'; HexDark: '#A69CA2'),  // 白ピンクの淡色
    (Name: 'ONE（CeVIO AI）' ; HexRGB: '#D6E8FF'; HexLight: '#E4F0FF'; HexDark: '#8B97A6'),  // 青髪 → 淡いブルー
    (Name: '#kzn'            ; HexRGB: '#D6F7F2'; HexLight: '#E4FAF7'; HexDark: '#8BA19D'),  // キズナ → 透明感の淡ミント
    (Name: '裏命 RIME'       ; HexRGB: '#E8D6F5'; HexLight: '#F0E4F8'; HexDark: '#978B9F'),  // 紫黒系 → パステルラベンダー
    (Name: '小春六花（CeVIO AI）' ; HexRGB: '#FFE8D6'; HexLight: '#FFF0E4'; HexDark: '#A6978B'),  // オレンジ系 → 淡サーモン
    // CEVIO
    (Name: '可不（KAFU）'    ; HexRGB: '#D6F5FF'; HexLight: '#E4F8FF'; HexDark: '#8B9FA6'),  // KAFU → 氷青色
    (Name: '星界 SEKAI'      ; HexRGB: '#F0D6FF'; HexLight: '#F5E4FF'; HexDark: '#9C8BA6'),  // 紫白 → 淡ライラック
    (Name: '心華 SHINKA'     ; HexRGB: '#FFD6E6'; HexLight: '#FFE4EF'; HexDark: '#A68B96'),  // ピンク → 淡ローズ
    (Name: 'IA TALK'         ; HexRGB: '#FFEAF7'; HexLight: '#FFF1FA'; HexDark: '#A698A1'),  // 白ピンクのより薄い色
    (Name: 'ONE TALK'        ; HexRGB: '#E0F0FF'; HexLight: '#EBF5FF'; HexDark: '#929CA6'),  // 青白系 → パウダーブルー
    (Name: 'ささら（CS）'    ; HexRGB: '#FFE6F0'; HexLight: '#FFEFF5'; HexDark: '#A6969C'),  // ささら旧版 → くっきり桜色
    (Name: 'つづみ（CS）'    ; HexRGB: '#E6F8FF'; HexLight: '#EFFAFF'; HexDark: '#96A1A6'),  // 水色のより淡い色
    (Name: 'タカハシ（CS）'  ; HexRGB: '#E8E8E8'; HexLight: '#F0F0F0'; HexDark: '#979797'),  // グレー → 淡灰色
    // COEIROINK
    (Name: 'つくよみちゃん（COEIROINK）' ; HexRGB: '#FFE8F5'; HexLight: '#FFF0F8'; HexDark: '#A6979F'),  // ピンク寄りの桜色
    (Name: 'ヨル'                         ; HexRGB: '#D6E0F5'; HexLight: '#E4EBF8'; HexDark: '#8B929F'),  // 青髪ベースの淡ブルー
    (Name: 'スズキ'                       ; HexRGB: '#E8F0E0'; HexLight: '#F0F5EB'; HexDark: '#979C92'),  // 緑髪 → 淡ミント
    (Name: 'カエデ'                       ; HexRGB: '#FFE6CC'; HexLight: '#FFEFDE'; HexDark: '#A69685'),  // オレンジ髪 → 淡サーモン
    (Name: '橘リエ'                       ; HexRGB: '#FFE0E8'; HexLight: '#FFEBF0'; HexDark: '#A69297'),  // ピンク系 → 明るいローズ
    (Name: 'みるひ'                       ; HexRGB: '#E6F7FF'; HexLight: '#EFFAFF'; HexDark: '#96A1A6'),  // 淡いシアン
    // COEIROINK
    (Name: 'ひづき夜宵'         ; HexRGB: '#E8D6F5'; HexLight: '#F0E4F8'; HexDark: '#978B9F'),  // 紫髪 → 淡ラベンダー
    (Name: 'ひまり（COEIROINK）'; HexRGB: '#F5E6D6'; HexLight: '#F8EFE4'; HexDark: '#9F968B'),  // 茶髪 → 柔らかい淡ベージュ
    (Name: '叫びオノマトペ'     ; HexRGB: '#FFD6D6'; HexLight: '#FFE4E4'; HexDark: '#A68B8B'),  // 赤系のオノマトペ → 淡ピンク
    (Name: '罵りオノマトペ'     ; HexRGB: '#FFE6E6'; HexLight: '#FFEFEF'; HexDark: '#A69696'),  // 少し強い赤 → 薄ベビーピンク
    (Name: '読み上げおれんじ'   ; HexRGB: '#FFF0D6'; HexLight: '#FFF5E4'; HexDark: '#A69C8B'),  // 名前通りの淡オレンジ
    (Name: '浮遊感ボイス（ふゆ）'; HexRGB: '#D6F0FF'; HexLight: '#E4F5FF'; HexDark: '#8B9CA6')  // 浮遊感 → 淡ブルー
  );
