# PSDArtEditor

Syncroh2 と他の Delphi VCL ホストから利用できる PSD 編集部品です。
画像描画の既存 PSDImage 部品とは独立し、ホストにはファイルパスと保存結果を返します。
取り込み元 AIArtToPSD の単独 EXE、Application.Initialize/Run、全体スタイルは使用しません。

## ホスト API

- unit `PsdArtEditorForm` / class `TPsdArtEditorForm`
- `CreateForHost(Owner, ManagedRoot, ExchangeRoot, HistoryRoot)` で各保存先を明示
- `OpenPsdFile(FileName)` → `Show` で既存 PSD 編集
- `NewBlank(FileName, Width, Height)` で透明な画像レイヤー1枚を作成・保存
- `OnSaved(Sender, Info)` で `OldFileName` / `NewFileName`、変更種別を通知
- `OriginalDocument` / `EditedDocument` は通知中だけ有効な Clone。
  保存後再読込で失われる内部 ID を保った編集前後文書を渡します。
- `NamesChanged` / `VisibilityChanged` / `StructureChanged` / `VisualChanged`。
  名前と補助記号のみの変更では `VisualChanged=False`。
- 同じ PSD を複数の画面で編集しないよう、ホストは正規化フルパスで所有を管理してください。
- フォーム終了は確定操作です。最終値が開始値と同一なら PSD を書き込みません。
  保存失敗時は閉じず、編集内容を保持します。

ManagedRoot 内の PSD に AI・PNG・画像・構造・ファイル名変更を許可します。
外部 PSD に許可するのはレイヤー名・補助記号・表示状態だけです。
この制約は UI、公開編集 API、パイプ入口、外部 PSD 保存経路で検証します。
パス判定は正規化フルパスと ManagedRoot + ディレクトリ区切りを比較します。
外部 PSD は元ファイルに保存し、管理フォルダへコピーしません。

ファイル名変更は同じ管理ディレクトリの未使用の名前へ保存し、成功通知を行います。
元ファイルの削除は、ホストで登録参照の変更に成功した後に実行してください。
AviUtl2 に既に配置済みの PSD パスはホストが自動更新する対象ではありません。

## PSD 保存

元の PSD bytes を保持し、外部 PSD の名前だけ変更したときは元の合成画像を維持します。
外部 PSD の可視状態変更では、対応している合成のみを再生成します。
未対応の描画機能では可視状態変更を拒否し、名前編集のみ許可します。
PSB、ZIP 圧縮、RGB 以外、16/32 bit は未対応として明示的に拒否します。
GUI から元 bytes の保全なしに外部 PSD を新規書き出しすることはありません。

## 依存

Core / Persistence / Editor / Integrations / Shell / Support の Pascal units を参照してください。
Support は既存共通部品との DPI・配色・transport 差を隔離するため ArtEditor 接頭辞を付けています。
既存 DropFile は組み込まず、対象 PSD の選択はホストへ委ねます。

パイプと PNG/JSON の操作手順は [通信仕様](通信仕様.md) を参照してください。

パイプはPNG初期化・追加・置換・座標移動・グループ作成・排他パーツ選択にも対応します。
statusのsupportedCommandsで接続先の対応を確認できます。AIジョブは元PSDのパスとSHA-256を記録し、
同じ保存内容のPSDを開き直した後でもrecoverで復元できます。
