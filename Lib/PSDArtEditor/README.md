# PSDArtEditor

Syncroh2 と他の Delphi VCL ホストから利用できる PSD 編集部品です。
画像描画の既存 PSDImage 部品とは独立し、ホストにはファイルパスと保存結果を返します。
取り込み元 AIArtToPSD の単独 EXE、Application.Initialize/Run、全体スタイルは使用しません。

## ホスト API

- unit `PsdArtEditorForm` / class `TPsdArtEditorForm`
- `CreateForHost(Owner, ManagedRoot, ExchangeRoot, HistoryRoot)` で各保存先を明示
- `OpenPsdFile(FileName)` → `Show` で既存 PSD 編集
- `NewBlank(FileName, Width, Height)` で透明な画像レイヤー1枚を作成・保存
- `ReorderLayer(Layer, Parent, Index)` / `SwapLayers(Layer, Other)` で画像・グループの構成を変更。管理PSD限定、Undo/Redo対応
- `DeleteLayer(Layer)` で画像／グループと全ての子を削除。管理PSD限定、最後の最上位項目は保持し、Undo/Redo対応
- `OnSaved(Sender, Info)` で `OldFileName` / `NewFileName`、変更種別を通知
- `OriginalDocument` / `EditedDocument` は通知中だけ有効な Clone。
  保存後再読込で失われる内部 ID を保った編集前後文書を渡します。
- `NamesChanged` / `VisibilityChanged` / `StructureChanged` / `VisualChanged`。
  名前と補助記号のみの変更では `VisualChanged=False`。
- 同じ PSD を複数の画面で編集しないよう、ホストは正規化フルパスで所有を管理してください。
- フォーム終了は確定操作です。最終値が開始値と同一なら PSD を書き込みません。
  保存失敗時は閉じず、編集内容を保持します。

新規作成時だけPSDのImage Resourcesへ専用の作成情報を付与します。
識別情報（形式1・文書UUID）とファイル全体に結び付いたHMAC-SHA-256を検証できたPSDだけに、
AI・PNG・画像・構造・ファイル名変更を許可します。保存・AI再開用snapshotの出力では認証値を更新します。
外部PSDは名前本文を保持し、*・!・:flipx・:flipy・:flipxyの修飾子、表示非表示、排他パーツ切替だけを許可します。
この制約はUI、公開編集API、パイプ入口、外部PSD保存経路で検証します。
ManagedRootは新規作成の保存先であり、編集権限の判定には使いません。
作成情報なし・重複・改変・認証失敗のPSDは、保存場所に関係なく外部PSDとして扱います。
従来の無印PSDへ作成情報を自動付与する互換処理はありません。
外部PSDは元ファイルに保存し、管理フォルダへコピーしません。

認証鍵は %LOCALAPPDATA%\Syncroh2\PSDArtEditor\origin.key にWindowsのユーザー保護（DPAPI）で保存します。
鍵の消失、別PC・別Windowsユーザー、他の編集ソフトによる内容・メタデータ変更では認証できなくなり、
外部PSDの制限が適用されます。PSD内に認証鍵を含めません。

ファイル名変更は元PSDと同じディレクトリの未使用の名前へ保存し、成功通知を行います。
元ファイルの削除は、ホストで登録参照の変更に成功した後に実行してください。
AviUtl2 に既に配置済みの PSD パスはホストが自動更新する対象ではありません。

## PSD 保存

元の PSD bytes を保持し、外部 PSD の補助記号だけ変更したときは元の合成画像を維持します。
外部 PSD の可視状態変更では、対応している合成のみを再生成します。
未対応の描画機能では可視状態変更を拒否し、補助記号の変更のみ許可します。
PSB、ZIP 圧縮、RGB 以外、16/32 bit は未対応として明示的に拒否します。
GUI から元 bytes の保全なしに外部 PSD を新規書き出しすることはありません。

RAW/RLEの読み書きは連続データをまとめて処理し、RLE行と合成画像の中間コピーを減らします。
`ReadPsdBytes(Data)`は既に保持しているアーカイブを直接解析します。返された文書の
`SourceBytes`は入力配列を共有するため、呼び出し後も入力の内容を変更しないでください。
画像・構造保存時の合成は1回とし、元アーカイブを一時ファイルへ書き戻さずに検査します。
作成情報のSHA-256はWindows CNGで計算し、従来と同じHMAC・認証形式を維持します。
保存後のPSD再解析、画像・マスク・元情報の検証、原子的なファイル置換は引き続き行います。

## 依存

Core / Persistence / Editor / Integrations / Shell / Support の Pascal units を参照してください。
Support は既存共通部品との DPI・配色・transport 差を隔離するため ArtEditor 接頭辞を付けています。
既存 DropFile は組み込まず、対象 PSD の選択はホストへ委ねます。

パイプと PNG/JSON の操作手順は [通信仕様](通信仕様.md) を参照してください。

パイプはPNG初期化・追加・置換・座標移動・階層と順序変更・レイヤー入れ替え・削除・グループ作成・排他パーツ選択にも対応します。
statusのsupportedCommandsで接続先の対応を確認できます。AIジョブは元PSDのパスとSHA-256を記録し、
同じ保存内容のPSDを開き直した後でもrecoverで復元できます。
