# Serif 現行仕様・設計ノート

このファイルには、`Plugin_Extension/Serif`を中心とするセリフ機能の現在の仕様、変更時に必要な情報、
継続課題だけを記録する。完了済み作業の時系列記録は [`note_history.md`](note_history.md) を参照する。

## 対象プロジェクト

- AviUtl2拡張: `Syncroh2_Extension2.dproj`
- 単体GUI: `Syncroh2_Desktop.dproj`
- セリフ送受信Module: `Syncroh2_Module.dproj`
- 新セリフ描画フィルター: `Syncroh2_Filter_SerifDraw.dproj`

## 現在のVOICEVOX入力

- 通常の入力ページは「1話者・1セリフを常時編集する簡単入力GUI」。旧複数行GUIは削除せず、
  `SerifVoicevoxInputFrame.pas`と`SerifVoicevoxInputRow.pas`を再利用資料としてビルド対象に残す。
- 入力行は話者アイコン、再生／停止ボタン、約3行分の固定高`TMemo`で構成する。長文は折り返し、
  3行を超えても入力可能。空欄時は操作案内を重ねて表示する。
- `Enter`は送信し、成功後も本文を残して全文選択する。`Shift+Enter`は本文内改行、`F5`は
  現在内容の確認再生／停止。アクセント表示と句の読み編集欄でも同じ`F5`を使う。
- 生成・再生は入力画面全体で1処理に限定し、再操作時は現在処理を停止する。
- 設定領域はアクセント、イントネーション、長さ、音声設定を切り替える。
  - アクセント: モーラの高低、アクセント核、句単位の読みを編集する。
  - イントネーション: モーラごとの`pitch`を縦型スライダーで編集する。
  - 長さ: 子音長、母音長、句読点の間を縦型スライダーで編集する。
  - 音声設定: 速度、音高、抑揚、音量、前間、後間を編集する。
- 手動アクセント、pitch、長さは編集中の`audio_query`へ内部メタデータとして保持し、VOICEVOXへ
  送る前に除去する。本文・話者・読みの変更で音素列が変わる場合は不整合な編集値を破棄する。
- 話者ショートカットは10枠を持ち、クリック、ホイール、`Ctrl+1`～`Ctrl+0`で話者・styleを適用する。
  設定はセリフプロジェクト内の`VoicevoxShortcuts.ini`へ保存する。

## VOICEVOX Engineと保存値

- Engineの場所は`Documents\Syncroh2\Serif\VoicevoxEngine.ini`へ全体共通で保存する。
- 保存値がなければVOICEVOX標準インストール先から`vv-engine\run.exe`を自動検出する。既に
  `127.0.0.1:50021`でAPIが応答する場合は既存Engineを利用する。
- 入力ページ描画後、50msの遅延を置いてAPI準備を開始する。画面が起動したEngineだけを終了時に停止する。
- キャラ＋感情別の速度、音高、抑揚、音量、前間、後間は、セリフプロジェクト内の
  `VoicevoxSettings.ini`へ`speaker_uuid + style ID`単位で保存する。規定値へ戻した項目は削除する。
- Debugログは`%TEMP%\Syncroh2\Temp\Syncroh2_Voicevox.log`へ出力する。本文は記録せず文字数だけを残す。

## VOICEVOXの生成・送信経路

1. `/speakers`から話者とtalk用styleを取得する。
2. 本文とstyle IDから`/audio_query`を取得する。
3. アクセント変更後は`/mora_data`で音素情報を再計算し、手動pitch・長さを再適用する。
4. キャラ＋感情別の音声設定を反映し、内部メタデータを除去して`/synthesis`へ送る。
5. 生成したwavとUTF-8 txtを既存Analyzerへ渡し、現在のセリフプロジェクトへ登録する。
6. 監視フォルダを経由しなくても、既存の後段処理を使って現在シーンへAviUtl2オブジェクトを送る。

## セリフプロジェクトと自動保存

- 音声、本文、配役、感情、シーン情報はセリフプロジェクト単位で管理する。
- AviUtl2プロジェクト読込直後とシーン変更時に、現在プロジェクト・シーンとの同期を行う。
- 初回保存やプロジェクトコピー時はwav/txtとVOICEVOX設定INIの参照先を新しいプロジェクトへ更新する。
- フォルダ監視経路は配置に失敗したセリフを破棄せず保持し、再試行可能な状態を維持する。
- 監視・音声合成アプリ自動操作の詳細は [`Watcher/note.md`](Watcher/note.md) を参照する。

## セリフ送受信

- Git管理するスクリプト正本は`Plugin_Module/Script/@Syncroh2_Script.obj2`。ModuleのDebug / Win64
  PostBuildで出力先へコピーし、Moduleとスクリプトの版ずれを防ぐ。
- 送信入口は`Plugin_Module/Serif/PluginModuleSerif.pas`の`set_text`。
- 現行送信形式:
  `set_text(framerate, frame, layer, message, character, emotion, direction, aiueo, totaltime, lab, obj.id, current_frame)`
- 受信入口は同ユニットの`get_text`。現行形式:
  `get_text(layer, obj.id, current_frame, "object-v2")`
- 共有データはUIDと送信元Object IDを持つ。受信済みUIDは「参照レイヤー＋受信Object ID」単位で管理し、
  同じ参照レイヤーを使う文字と枠がそれぞれ同じセリフを受け取れる。
- 受信済みUIDは再配送しない。未受信UIDはシーンを越えて保持する。旧3引数・layout付き呼び出しは
  互換経路として残すが、新規生成物は`object-v2`を使う。
- `set_text`はUID、送信元ID、現在／相対フレーム、FPS、セリフ、配役、感情、方向、総時間、LAB、
  発音進捗、発音中、総フレーム数を共有する。SerifDrawは共通索引から現在フレームの有効セリフを読む。
- Module追跡ログは`PluginModuleSerif.pas`の`SERIF_MODULE_TRACE`で切り替え、
  `%TEMP%\Syncroh2\Temp\Syncroh2_SerifModule.log`へ出力する。

## セリフ枠と新セリフ描画

- 旧セリフ枠のhold／fadeは`PluginModuleSerifCount.pas`の`get_serif_count(obj.id, obj.frame)`が管理する。
  同一フレーム再評価または逆方向移動では保持値を消し、正方向スキップは継続として扱う。
- 新しいSerifDrawの描画、配役、枠、複数配役表示、アニメーションの現行仕様は
  [`../../Plugin_Filter/SerifDraw/note.md`](../../Plugin_Filter/SerifDraw/note.md)を参照する。
- SerifDrawアニメーションは設定画面ではなくAviUtl2オブジェクトのパラメーターで設定する。

## 主なユニット

- `SerifFrame.pas`: セリフ画面全体、プロジェクト・シーン同期、監視処理の入口。
- `Voicevox/SerifVoicevoxSimpleInputView.pas`: 話者、再生、本文入力、キー操作。
- `Voicevox/SerifVoicevoxSimpleInputFrame.pas`: 入力画面統括、設定、話者、送信イベント。
- `Voicevox/SerifVoicevoxEngineSession.pas`: Engineの遅延起動、準備、終了。
- `Voicevox/SerifVoicevoxPreviewController.pas`: 非同期生成、停止、単一再生状態。
- `Voicevox/SerifVoicevoxSettingsFrame.pas`: アクセント／イントネーション／長さ／音声設定の切替。
- `Voicevox/SerifVoicevoxAccentView.pas`: アクセント表示、核・読み編集。
- `Voicevox/SerifVoicevoxIntonationFrame.pas`: モーラごとのpitch編集。
- `Voicevox/SerifVoicevoxLengthFrame.pas`: 子音長・母音長編集。
- `Alias/`: セリフ用Objectとaliasの生成・補正。
- `Analyzer/`: 音声合成ソフトの出力解析とLAB生成。
- `Watcher/`: ファイル監視と音声合成ソフトの自動操作。

## 変更時の確認

- Module変更: `Syncroh2_Module.dproj` Debug / Win64をPostBuild込みでビルドする。
- 拡張変更: `Syncroh2_Extension2.dproj`と、共通GUIに影響する場合は`Syncroh2_Desktop.dproj`の
  Debug / Win64を確認する。
- VOICEVOX変更: Engine未起動／起動済み、生成、停止、確認再生、送信、アクセント・pitch・長さ・
  音声設定の再適用、プロジェクト保存・コピーを確認する。
- 送受信変更: 文字と枠について、表示中、セリフなし、終了直後、同一フレーム再評価、逆方向移動、
  正方向スキップ、同一レイヤーの複数受信Objectを確認する。
- 問題報告にはプロジェクト、シーン、フレーム、再生方向、参照レイヤー、受信Object IDを残す。

## 継続課題

- 常時アニメーションを感情表現中心に整理し、Moduleから受信済みの`emote`を利用する。
- 同期アニメーションを、実証済みの相対フレーム・総フレーム・行ピクセル経路から拡張する。
- 表示後アニメーション用の旧セリフ一時バッファと、連続セリフ時の破棄規則を設計する。
- 複数音声合成エンジン対応は将来案。エンジンID、話者ID、style、設定保存先を分離する必要がある。
- 音声合成アプリ自動操作の実機確認待ちは [`Watcher/note.md`](Watcher/note.md) に集約する。

## 関連ノート

- 完了済み作業履歴: [`note_history.md`](note_history.md)
- SerifDraw現行仕様: [`../../Plugin_Filter/SerifDraw/note.md`](../../Plugin_Filter/SerifDraw/note.md)
- Watcher固有: [`Watcher/note.md`](Watcher/note.md)
- Face連携: [`../Face/note.md`](../Face/note.md)
- PSD描画側のセリフ同期: [`../../Plugin_Filter/PSD/note.md`](../../Plugin_Filter/PSD/note.md)
- AviUtl2連携: [`../../AviUtl/note.md`](../../AviUtl/note.md)
- ルート作業ノート: [`../../note.md`](../../note.md)
