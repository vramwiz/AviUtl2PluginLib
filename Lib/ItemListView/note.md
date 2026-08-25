# ItemListView 作業ノート

## 目的

- Windows のネイティブ `TListView` に依存しない、一覧表示用の共通UI基盤を提供する。
- 選択、独自スクロールバー、行描画、キーボード操作、インプレース文字編集を共通化する。
- PSD、Face、キャラクター一覧などは派生クラスでデータ取得と画像描画だけを実装する。

## 設計方針

- `TCustomItemListView` 自身はデータを所有しない。
- 派生クラスが `GetItemCount`、`GetItemText`、`SetItemText`、`DrawItemImage` を実装する。
- `Layout` で横並びの行表示 (`illRow`) と、画像の下へ名称を置く1列タイル表示 (`illIcon`) を選べる。
- `CaptionVisible` で名称領域の描画とF2インプレース編集をまとめて有効・無効にできる。
- `WheelScrollRows` でホイール1ノッチあたりの移動行数を指定でき、既定値は3行。
- ネイティブListViewの `Items` と保存リストの二重管理を行わない。
- Windows標準スクロールバーは使用せず、VOICEVOX編集画面と同じ細いテーマ描画の独自部品を使う。
- 一覧の再表示後も、利用側のアダプターがUIDなどの安定した識別子で選択を復元する。
- PSD固有の保存、サムネイルキャッシュ、画像生成は共通基盤へ持ち込まない。

## 現在の適用先

- `Plugin_Extension/PSD/ListView/PSDListView.pas` のPSD設定一覧。
- PSD設定一覧は `illIcon` を使用し、サムネイルを中央、名称をその下へ表示する。
- `Plugin_Extension/PSD/Chara/PSDCharaListView.pas` の左側PSDキャラクター一覧。`illIcon` と `CaptionVisible=False` を使用する。
- `Plugin_Extension/Face/ListView` の単一・複数キャラクター用表情一覧。いずれも `illIcon` と `CaptionVisible=True` を使用する。
- 追加、コピー、削除、上下移動、名前編集、サムネイル編集、ズーム、D&Dの既存入口を維持する。

## 作業ログ

- 2026-08-21 AI修正: 動的生成した一覧が200% DPIの親フレームへ接続される際、既に拡大済みの
  `Font.Height`へ倍率が再適用され、キャプションが約2倍になる問題を修正した。親接続後に96 DPI基準の
  12px論理高さを親の`CurrentPPI`で一度だけ換算する。Extension Debug / Win64は0エラー。
- 2026-08-21 AI修正: 新一覧への移行時に、旧ネイティブ一覧で実ピクセル値だったズーム表
  `32/64/100/128`へ`CurrentPPI`を掛けていたため、200% DPIでサムネイルが2倍になる問題を修正した。
  PSDキャラクター、PSD設定、単一表情、複数表情の画像寸法は従来どおり実ピクセルとし、文字領域・余白・
  スクロールバーだけをDPI追従させる。Extension Debug / Win64はPostBuildなしで0エラー。

## 次に確認すること

- AviUtl2実機で選択、ダブルクリック、右クリック、ホイール、Ctrl+ホイールを確認する。
- 名前編集とサムネイル範囲編集の確定・キャンセルを確認する。
- 問題がなければFaceや左側PSDキャラクター一覧を個別に移行する。
