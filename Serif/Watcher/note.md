# Serif Watcher 作業ノート

このファイルは `Plugin_Extension/Serif/Watcher` 配下の監視処理を引き継ぐためのメモです。
セリフ全体の状態は [`../note.md`](../note.md) を参照し、監視まわりの調査結果や変更方針はここへ残します。

## 最初に読むファイル

1. `SerifWindowWatcher.pas`
   - 音声合成アプリの補助ウィンドウを 100ms タイマーで監視する本体。
   - 開始時点で存在するトップレベルウィンドウは既知扱いにし、古いダイアログを誤操作しない。
   - 新規トップレベルウィンドウを検出したら、最初に `CanHandleWindow` が真になったアプリ別ターゲットへ渡す。

2. `SerifWindowWatchTarget.pas`
   - アプリ別ターゲットの基底クラス。
   - `SetTargetWindow` で音声合成アプリのメインウィンドウ HWND を受け取り、プロセス ID を保存する。
   - `IsTargetProcessWindow` は、対象メインウィンドウと同じプロセスのウィンドウか確認する。

3. `SerifWindowWatchUtils.pas`
   - Win32 / UI Automation 共通ユーティリティ。
   - ウィンドウタイトル、クラス名、プロセスファイル名、UIA 要素名などを取得する。
   - `IsTopLevelVisibleWindow` は子ウィンドウを除外し、可視トップレベルウィンドウだけを対象にする。

4. アプリ別ターゲット
   - `SerifWindowWatchAivoice.pas`
   - `SerifWindowWatchVoiceroid2.pas`
   - `SerifWindowWatchCeVIOAI.pas`

## 起動経路

- `Plugin_Extension/Serif/SerifFrame.pas` の `TFrameSerif` が `TSerifWindowWatcher` を生成する。
- ランチャー側から対象アプリのメインウィンドウ HWND が渡ると、`TFrameSerif.SetLauncherSpeechAppWindow` から `FWindowWatcher.SetWatchTargetWindow` へ渡す。
- 監視ボタンや設定復元で `ProcWatcher` が呼ばれる。
- `swsStandby` では `FWindowWatcher` とフォルダ監視を停止する。
- `swsSend` では `FWindowWatcher` とフォルダ監視を開始し、AviUtl2 への自動流し込みも有効にする。
- 旧状態名 `swsWatch` は互換用で、現在は `swsSend` と同じ扱い。

## 監視の分担

- `SerifWatcherList.pas`
  - 音声合成アプリが出力した `txt / wav / lab` などのファイル変化を監視する。
  - ファイルが落ち着くまで待ってから解析へ渡す。
  - 連番付き時系列セリフファイルがある場合、同時出力される非連番のまとめファイルを解析対象から外す。

- `SerifWindowWatcher.pas`
  - 音声合成アプリが表示する保存ダイアログや確認ダイアログを自動操作する。
  - フォルダ監視とは別系統だが、`swsSend` の開始/停止に連動する。

## アプリ別の自動操作

### A.I.VOICE

担当: `SerifWindowWatchAivoice.pas`

- 対象プロセス: `aivoiceeditor.exe`
- 主な対象ウィンドウ:
  - `音声保存`
  - `確認`
  - `ファイル保存`
  - `エラー`
  - `情報`
  - `名前を付けて保存`
- 操作フロー:
  - `音声保存` の OK を押して保存を開始する。
  - プロジェクト設定確認では本文に `プロジェクト設定` と `音声保存` があることを確認してから `はい` を押す。
  - 上書き確認では本文に `既に存在` と `上書き` があることを確認してから `上書き` ボタンを押す。
  - ビジーエラーでは本文に `前回の合成処理が完了していません` があることを確認して OK を押す。
  - 保存完了では本文に `合成音声をファイルに保存しました` があることを確認して OK を押す。
- 操作方法:
  - 基本は UI Automation の `InvokePattern`。
  - OK が押せない場合は対象ウィンドウを前面化して Enter を送る。
- 注意:
  - `確認` や `情報` はタイトルだけでは誤操作しやすいので、本文判定を外さない。

### A.I.VOICE2

担当: `SerifWindowWatchAivoice2.pas`

- 起動ショートカット:
  - `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\AI\A.I.VOICE2 Editor\A.I.VOICE2 Editor.lnk`
- 対象プロセス:
  - `C:\Program Files\AI\AIVoice2\AIVoice2Editor\aivoice.exe`
- 主な対象ウィンドウ:
  - `書き出し（命名規則）`
  - `確認` / `ファイル保存`
  - `情報` / `完了`
- 操作フロー:
  - `書き出し（命名規則）` で、本文に `保存先フォルダ`、`命名規則`、`書き出しを実行` があることを確認してから `書き出しを実行` を押す。
  - 上書き確認では本文に `既に存在` と `上書き` があることを確認してから `上書き` ボタンを押す。
  - 書き出し完了らしい `情報` / `完了` ダイアログでは、本文に `書き出し` または `保存` と `完了` があることを確認して OK を押す。
- 操作方法:
  - 基本は UI Automation の `InvokePattern`。
  - `書き出しを実行` が UIA で押せない場合は、対象ウィンドウを前面化して Enter を送る。
- 注意:
  - 画像確認時点では、最初に表示される対象は `書き出し（命名規則）` ダイアログ。
  - 完了ダイアログの実タイトルや本文は未実機確認なので、動作確認後に必要なら判定語句を調整する。

### VOICEROID2

担当: `SerifWindowWatchVoiceroid2.pas`

- 対象プロセス: `voiceroideditor.exe`
- 主な対象ウィンドウ:
  - `音声保存`
  - `名前を付けて保存`
  - `ファイル保存`
  - `情報`
- 操作フロー:
  - `音声保存` の OK を押し、ファイル保存ダイアログ待ちへ進む。
  - `名前を付けて保存` は前面化して Enter を送る。
  - 上書き確認では UIA で `新しいファイルで上書き` を探して押す。失敗時は Enter。
  - 保存完了の `情報` は OK を押してフローを終了する。
- 操作方法:
  - OK は UI Automation の `InvokePattern`。
  - 標準ダイアログでは `WM_COMMAND / IDOK` と Enter をフォールバックに使う。
- 注意:
  - `FVoiceroidFlowState`、`FFileSaveActionDone`、各スキャンカウンタで Enter 連打や待ち続けを防いでいる。
  - 直接 `名前を付けて保存` が出た場合も、そこから保存フローを開始できる。

### CeVIO AI

担当: `SerifWindowWatchCeVIOAI.pas`

- 対象プロセス: `cevio ai.exe`
- 主な対象ウィンドウ:
  - 連続 WAV 書き出し確認ウィンドウ
- 操作フロー:
  - 対象ウィンドウを見つけたら OK を押す。
  - 開始時点ですでに開いている場合も `Tick` 側で再探索する。
- 操作方法:
  - 基本は UI Automation の OK `InvokePattern`。
  - UIA で押せない場合は子ウィンドウの `OK` ボタンへ `BM_CLICK`。
  - 最後のフォールバックとして対象ウィンドウを前面化して Enter。

## 変更時の注意点

- `CanHandleWindow` の判定は広げすぎない。
  - 保存や確認のタイトルだけでは危ないので、可能なら UIA 本文も見る。
  - 終了確認や別用途の `確認` / `情報` を押さないことを優先する。

- `SerifWindowWatcher.Start` は開始時点のウィンドウを既知化する。
  - 監視開始前から開いていたダイアログを自動操作しないための仕様。
  - 例外的に既存ウィンドウも処理したい場合は、アプリ別 `Tick` 側で明示的に再探索する。

- 操作は UI Automation を第一候補にする。
  - UIA で対象ボタンを特定できない場合だけ、`SendMessage` や Enter 送信へ落とす。
  - Enter 送信を追加する場合は、対象ウィンドウ判定を必ず狭くする。

- フォルダ監視の仕様変更は `SerifWatcherList.pas` を見る。
  - ウィンドウ自動操作の仕様変更は `SerifWindowWatch*.pas` を見る。
  - 両者は `swsSend` に連動して同時に動くが、責務は分けて考える。

- DEBUG ログのタグは `SerifWindowWatcher`。
  - `PSDImageDebug.log` に追記される。
  - 通常の保存先は `C:\Users\<ユーザー名>\Documents\Syncroh2\Temp\PSDImageDebug.log`。
  - ウィンドウ検出、UIA 要素、ボタン押下結果、フロー終了理由を追う時に使う。

## 現在の未対応メモ

- VOICEPEAK は `出力設定` ダイアログの `出力` ボタン押下まで実装済み。ソース文字コードの影響を避けるため、VOICEPEAK 用ターゲット内の日本語判定文字列は Unicode コードポイントで書く。次に上書き確認、保存先選択、完了ダイアログなどが出る場合は、実画面を見て `SerifWindowWatchVoicepeak.pas` に追加する。

## 作業ログ

- 2026-07-05 AI: `ずんだもんなのだ` の1秒弱音声で、AviUtl2オブジェクトへ出力された音素LABが `ずんだもんな` 相当の0.600秒付近で終わり、後半の `のだ` が欠ける件を調査した。入口は `Watcher` だが、原因箇所はファイル監視ではなく取り込み後の `Plugin_Extension/Serif/Analyzer/SerifAnalyzer.pas`。`Scene.ini` では対象セリフが `WaveLength=0.992`、`LabStr` 最終行が `t.5893753,.0106247,A` で保存済みだったため、AviUtl2送信前にLABが切られていた。2026-06-27 に追加した `MsgsToTrimQuietLabTailFromWave` が、WAV音量の `ActiveEndSec` を基準に音素LAB末尾を切り詰めるが、今回のように `0.992 - 0.600 = 約0.392秒` も削るとセリフ本体が欠落する。対策として、静音末尾の切り詰めは `QUIET_TAIL_MAX_TRIM_SEC=0.25` 秒以内の場合だけ実行し、それより長い場合は DEBUG ログを出してスキップするようにした。`Syncroh2_Extension2.dproj` と `Syncroh2_Desktop.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。

- 2026-07-03 AI: VOICEPEAK 用の `SerifWindowWatchVoicepeak.pas` を追加した。`出力設定` ダイアログを、タイトルに加えて UIA 本文の `ファイル名` / `フォーマット` / `セリフをファイルに保存` / `ブロックごとに分割して保存` / `命名規則` / `出力` で判定し、UI Automation で右下の `出力` ボタンを押す。UIA で押せない場合は Enter にフォールバックする。`SerifWindowWatcher` の `FTargets` へ登録し、`Syncroh2_Desktop.dpr/.dproj` と `Syncroh2_Extension2.dpr/.dproj` に参照を追加した。`Syncroh2_Extension2.dproj` と `Syncroh2_Desktop.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。
- 2026-07-03 AI: VOICEPEAK 初回実装が動かない件を修正。原因は `SerifWindowWatchVoicepeak.pas` の日本語リテラルがソース文字コードと噛み合わず文字化けしていたこと。`出力設定` / `出力` を Unicode コードポイント表記へ変更し、UIA 本文判定に依存せず `voicepeak.exe` プロセスの `出力設定` タイトルで拾うようにした。UIA では `Button` 以外でも InvokePattern を持つ `出力` 要素を押し、失敗時は右下の出力ボタン位置をクリックする。監視開始前から開いていた `出力設定` も拾えるよう Tick で再探索する。ランチャー側の VOICEPEAK 実行ファイル名も `DummyVoicepeak` から `voicepeak` へ変更した。
- 2026-07-03 AI: VOICEPEAK の `出力設定` が独自フォームでキー入力を受け付けない可能性があるため、`SerifWindowWatchVoicepeak.pas` を追加修正した。`TargetMainWindow`、フォアグラウンド、`voicepeak.exe` の可視トップレベルを順に探し、メインウィンドウ内モーダルとして `ファイル名` / `フォーマット` / `ブロックごとに分割して保存` / `出力` が UIA で見える場合も処理対象にする。`出力` 要素が Invoke できない場合は、その UIA 矩形中央を直接クリックし、それも取れない場合に右下相対座標クリックへ落とす。`Syncroh2_Extension2.dproj` と `Syncroh2_Desktop.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。
- 2026-07-03 AI: VOICEPEAK の `出力設定` が `voicepeak.exe` の通常ダイアログとして検出できない場合に備え、タイトルが完全一致する可視トップレベルウィンドウはプロセスに依存せず処理対象にするよう変更した。独自描画で UIA/キー操作が効かない前提で、`出力設定` タイトル一致時は UIA より先に右下の `出力` ボタン相対位置をマウスクリックする。これによりランチャーから VOICEPEAK を起動し、手動で出力画面を開いた後の独自フォームでも進められる可能性を上げた。`Syncroh2_Extension2.dproj` と `Syncroh2_Desktop.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。
- 2026-07-03 AI: VOICEPEAK の `出力設定` ハンドル取得状況を実機デバッグできるよう、`SerifWindowWatchVoicepeak.pas` に詳細ログを追加した。`PSDImageDebug.log` の `[SerifWindowWatcher]` タグへ、Tick 走査開始、`TargetMainWindow`、フォアグラウンド HWND、EnumWindows の可視トップレベル候補、`CanHandle` 結果、PID、プロセスパス、タイトル、クラス名、矩形、クリック座標、UIA text scan 失敗を出す。全ウィンドウ列挙ログは `VOICEPEAK_DEBUG_SCAN_INTERVAL = 10` ごとに抑制し、対象ヒット時は即時ログする。`Syncroh2_Extension2.dproj` と `Syncroh2_Desktop.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。
- 2026-07-03 AI: VOICEPEAK の `出力設定` で `出力` を押した後に出る `保存先のフォルダーを指定してください...` フォルダー選択ダイアログを自動で進める処理を追加した。タイトル前方一致で検出し、`フォルダーの選択` ボタンを UIA で押す。UIA で取れない場合は標準ダイアログ向けに `WM_COMMAND / IDOK`、さらに Enter をフォールバックにする。`FOutputActionDone` / `FFolderActionDone` は対象 HWND が閉じたら解除し、同じ監視セッション内の次回出力でも再処理できるようにした。`Syncroh2_Extension2.dproj` と `Syncroh2_Desktop.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。
- 2026-06-28 AI: VOICEROID2 のダイアログ自動操作が動かない件を確認。`SerifWindowWatchVoiceroid2.pas` だけ `CanHandleWindow` と保存/上書き/完了 OK の Tick 再探索が `IsTargetProcessWindow` 必須になっており、ランチャーから VOICEROID2 のメイン HWND が未登録または古い場合に `voiceroideditor.exe` のダイアログを処理入口で落としていた。A.I.VOICE 系と同じく `IsTargetProcessWindow` または `IsVoiceroidProcessWindow` で受けるよう修正。`Syncroh2_Extension2.dproj` Debug/Win64 は `/p:PostBuildEvent=` 指定で 0 エラー成功を確認した。
- 2026-06-15 AI: A.I.VOICE2 の出力形式に「改行付きセリフ」が追加されたため、監視取り込み後の解析経路でデータ改行が消えないようにした。`SerifAnalyzer.FileNameToSerifMsg` で txt 本文の CR / LF / CRLF を CRLF に正規化してから末尾改行だけ除去し、`MsgsToMagsEnterPos` では `Msg.Voice` に既存改行が含まれる場合、自動改行処理をスキップする。これにより A.I.VOICE2 の本文改行は `Msg.Voice`、AviUtl2 alias の `\n` 変換、共有メモリへそのまま届く。改行なしセリフでは従来どおり `Config.EnterPos` による自動改行を行う。
- 2026-06-14 AI: A.I.VOICE2 Editor 用の `SerifWindowWatchAivoice2.pas` を追加した。起動ショートカット `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\AI\A.I.VOICE2 Editor\A.I.VOICE2 Editor.lnk` の実体が `C:\Program Files\AI\AIVoice2\AIVoice2Editor\aivoice.exe` であることを確認し、プロセス名 `aivoice.exe` を判定に使う。添付画像の `書き出し（命名規則）` ダイアログで、`保存先フォルダ`、`命名規則`、`書き出しを実行` を UIA で確認してから `書き出しを実行` ボタンを押す処理を実装。上書き確認と完了 OK らしいダイアログの処理も仮実装した。`SerifWindowWatcher` の `FTargets` へ登録し、`Syncroh2_Desktop.dpr/.dproj` と `Syncroh2_Extension2.dpr/.dproj` に参照を追加。`Syncroh2_Extension2.dproj` と `Syncroh2_Desktop.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。完了ダイアログの実タイトル/本文は未実機確認のため、動作確認後に必要なら判定語句を調整する。
- 2026-06-14 AI: A.I.VOICE2 の自動操作がうまく動かないため、`SerifWindowWatchAivoice2.pas` の `AIVOICE2_DEBUG_DETAIL` を `True` にして詳細ログを有効化した。A.I.VOICE2 プロセスの新規トップレベルウィンドウに対して、`CanHandleWindow` の結果、タイトル、クラス名、子ウィンドウ、UI Automation の Actionable / AllElements、候補ボタン名を `OutputDebugString` へ出す。ログタグは `[SerifWindowWatcher]`。DebugView や IDE のデバッグ出力で、`A.I.VOICE2 CanHandle`、`A.I.VOICE2 window detected`、`A.I.VOICE2 export execute candidate button` を確認する。`Syncroh2_Extension2.dproj` と `Syncroh2_Desktop.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。
- 2026-06-14 AI: 実行後のログ確認で、`C:\Users\zan12\Documents\Syncroh2\Temp\PSDImageDebug.log` には `SerifAnalyzer` の解析ログだけが残り、`SerifWindowWatcher` の A.I.VOICE2 詳細は残っていなかった。A.I.VOICE2 の出力 `txt / lab / wav` は 2026-06-14 11:18 頃に解析されていたため、少なくともファイル出力と解析側は動作している。監視側の詳細を後から確認できるよう、A.I.VOICE2 監視ユニットの詳細ログを `OutputDebugString` 直書きから `PSDImageDebug.log` への `PSDDebugLog('SerifWindowWatcher', ...)` に変更した。
- 2026-06-14 AI: 11:23 実行ログを確認。`SerifWindowWatcher` は `aivoice.exe` の `A.I.VOICE2 Editor` メインウィンドウと ATOK パレット/候補ウィンドウだけを検出した。`書き出し（命名規則）`、`書き出しを実行`、上書き、完了 OK のいずれも UIA 要素として出ていない。A.I.VOICE2 は Flutter メインウィンドウ内に書き出しモーダルを描画しており、別トップレベルウィンドウとして検出できない可能性が高い。一方で `SerifAnalyzer` は 11:23:37 に `txt / lab / wav` を解析完了しているため、出力後のファイル監視/解析は動作している。
- 2026-06-14 AI: A.I.VOICE2 のメインウィンドウ内モーダルに対応するため、`SerifWindowWatchAivoice2.pas` の `Tick` で `A.I.VOICE2 Editor` メインウィンドウを定期走査する処理を追加した。まず UIA で `保存先フォルダ` と `書き出しを実行` を探し、見つからない場合は添付画像のレイアウトを基準に、メインウィンドウ相対位置 `(0.684, 0.662)` のピクセルが青緑の実行ボタン色に見える時だけ座標クリックする。座標クリック時は `A.I.VOICE2 export execute position click sent` を `PSDImageDebug.log` に出す。`SerifWindowWatchTarget.pas` には、アプリ別ターゲットが登録済みメインウィンドウを参照できるよう `TargetMainWindow` / `TargetProcessID` を protected に追加した。`Syncroh2_Extension2.dproj` Debug/Win64 はビルド成功。`Syncroh2_Desktop.dproj` は `D:\DelphiProg\Syncroh2\Win64\Debug\Syncroh2_Desktop.exe` が実行中で、出力 exe を作成できずビルド失敗した。
- 2026-06-14 AI: A.I.VOICE2 自動操作は 1 回目は成功するが 2 回目が反応しない問題を修正。原因は 1 回目の実行後に `a2efsWaitFinalOK` へ入り、A.I.VOICE2 が完了 OK ダイアログを出さない環境では `AIVOICE2_FINAL_OK_SCAN_COUNT = 600` の約 60 秒間、次のメインウィンドウ内モーダル走査が止まること。`AIVOICE2_FINAL_OK_SCAN_COUNT` を `30` に短縮し、完了 OK が出ない場合も数秒で `A.I.VOICE2 final OK scan timeout` により `Reset` され、2 回目以降の書き出しモーダルを再検出できるようにした。`Syncroh2_Extension2.dproj` Debug/Win64 はビルド成功。`Syncroh2_Desktop.exe` は実行中のため Desktop ビルドは未再実行。

