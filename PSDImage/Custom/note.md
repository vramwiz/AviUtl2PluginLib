# PSDImage Custom 作業ノート

このファイルは `PSDImage/Custom` 配下の作者別・キャラ別 PSD 専用処理を引き継ぐためのメモです。
ルート `note.md` の肥大化を避けるため、個別立ち絵の調査状況、専用処理の方針、完了/未完了メモはできるだけこちらへ寄せます。

## このフォルダの役割

- `PSDImageCustom*.pas` は、作者別・キャラ別の PSD 専用補正ユニット。
- `PSDImage/Custom/Lib/PSDImageCustomDispatcher.pas` は、Kind ごとの専用処理呼び出し口。
- `PSDImage/Custom/Lib/PSDImageCustomKindDetector.pas` は、作者別・キャラ別の PSD 種類判定と表示名を管理する場所。
- `PSDImage/Kind/PSDImageKindDetector.pas` は互換用の薄い委譲ユニット。判定責務は持たせず、Custom 側へ処理を渡す。
- `*.txt` はデバッグ用レイヤー dump。専用処理を追加・調整するときは、該当 dump と既存ユニットを先に確認する。

## 作業時の基本方針

- 共通処理へ手を入れる前に、作者別・キャラ別ユニットで完結できるかを確認する。
- 新しい専用処理は、既存の `PSDImageCustom*.pas` に同じ作者の受け皿があればそこへ追加する。影響範囲が大きい場合だけ新ユニットや新 Kind を検討する。
- 新しい作者・キャラ判定を追加する場合は、まず `PSDImageCustomKindDetector.pas` と該当 `PSDImageCustom*.pas` を更新する。PSDImage 本体側や `PSDImage/Kind/PSDImageKindDetector.pas` に作者別知識を増やさない。
- マーカー操作はまず `PSDImageCustomMarkerUtils` の既存関数を使う。
- 排他候補として確定したい場合は、既存方針どおり `ReplaceMarkerOnTree(Tree, '*')` を使う。
- PSDToolkit 由来の元データに最初から付いている `*` はユーザー指定として扱い、明確な理由なしに消さない。
- 日本語レイヤー名を Delphi ソースへ直接書くと文字コードの影響を受けることがある。判定に使う重要文字列は、必要に応じて Unicode コードポイント定数にする。
- 作業後は、対象 dump、対象ユニット、変更理由、確認結果をこのファイルへ短く残す。完了した立ち絵はルートの `対応立ち絵一覧.md` にも日付付きで記録する。

## 既存の重要メモ

- `PSDImageAviUtl2` や `PSDImageCustomMarkerUtils` の共有処理は影響範囲が大きい。個別立ち絵の問題は、できるだけ `PSDImageCustom*.pas` 側で扱う。
- `SetTreeLayerName` は子孫の `AnmGroup2` / `AnmText` も再帰更新する。単なるマーカー付与では直接使わず、`:flipx` など名前全体を明示的に作る必要がある場合に限る。
- `[PSDMarkerRoute]` は dump 先頭付近に出る。`ApplyCustomMarkers` 後に `HasStarLayer=False` なら `*` 補完経路、`HasStarLayer=True` なら `+` 補完経路へ進んだことが分かる。

## 分類順・ツリー移動に関するメモ

- 実ツリーを移動する機能として `TPsdImage.MoveTree(Tree, DestTrees, Index)` がある。`Index < 0` は移動先末尾、`0` 以上は指定位置へ挿入。移動後は `RebuildTreeState` が呼ばれ、Owners / Level / `Layer.Tree` / ANM パス / 平坦リストが再構築される。
- `MoveTree` は描画順や親子構造にも影響する強い処理。既存例は `PSDImageCustomMoiky` の腕を前面側から背面側へ移す処理、`PSDImageCustomNishimiya` の腕/手候補移動、`PSDImageCustomKosukeSantaMaria` のジャケット裏移動など。分類表示だけを下げたい場合の第一候補にはしない。
- 実体を持たない分類用ツリーを作る機能として `TPsdImage.AddVirtualTree(DestTrees, Name, Index)` がある。LayerType は `-1` で描画対象外。仮想分類は配下をたどれるよう初期表示 ON になる。
- 分類リストは `TPSDElementList.ParseFromPSD` で作られ、その後 `PSDImageAviUtl2.LoadFromFile` から `ApplyCustomElementList(PsdImage, FPSDKind, FElements)` が呼ばれる。作者別・キャラ別に大分類/小分類を整理するなら、このフックを使う。
- 表示用リストは `PSDImageElementDisplayList.BuildPSDDisplayElements` で `Dest.Assign(Source)` されるだけなので、通常は `ApplyCustomElementList` 後の `FElements` の順序が表示順の土台になる。
- 既存の `ApplyCustomElementList` 例では、`PSDImageCustomKarai` が腕/右腕/両腕の分類を作り直し、`PSDImageCustomKosukeSantaMaria` が腕系小分類名を末端名へ正規化し、`PSDImageCustomMoiky` が腕分類を独自分類へ整理している。
- 小分類の順序調整例として、`PSDImageCustomMoiky.AddTreePartIfMissing` は初期表示中の Part を `Parts.Exchange` で先頭へ寄せている。大分類そのものを末尾へ送る既存専用処理は、2026-06-15 調査時点では見当たらない。
- 「分類としては残すが使用優先度が低いので下へ回す」だけなら、描画順を変える `MoveTree` ではなく、専用ユニットの `Apply...ElementList` で `TPSDElementList` の該当 Element を末尾へ移す処理を追加する方が安全。実装時は `ElementPartIndex` を変えず、表示順だけを変える。

## 作者別・キャラ別状況

### ユメのオワリ

- 既存の専用処理ユニットは `PSDImageCustomYumeNoOwari.pas`。
- `小春六花立ち絵（ユメのオワリ）v01_01` は `pikYumeNoOwari` として処理済み。
- `きりたん座り絵` は `pikYumeNoOwariKiritanSuwariE` として別判定・別補正がある。
- `ユメのオワリ_琴葉葵立ち絵v01.09.txt` と `ユメのオワリ_琴葉茜立ち絵v01.09.txt` は、2026-06-15 時点でどちらも `Kind=pikYumeNoOwari` / `Caption="ユメのオワリPSD"` として認識されている。
- 琴葉葵/茜 v01.09 は、`■くっつく葵ちゃん`、`ポーズ1葵/茜`、衣装内の腕、`肌`、後ろ髪・髪飾りなどが大きい構造。追加補正が必要になった場合は、まず `PSDImageCustomYumeNoOwari.pas` 内で琴葉 v01.09 固有構造を判定して、既存 `pikYumeNoOwari` の中に限定補正を足す方針が自然。
- 琴葉葵/茜 v01.09 の `■くっつく葵ちゃん` 系は構造が非常に複雑で、分類としては有用だが通常使用の優先度は低い。分類表示で下へ回したい場合は、実ツリー移動ではなく `ApplyYumeNoOwariElementCaptions` 付近に ElementList の並べ替え処理を追加するのがよさそう。

### からい

- `立ち絵琴葉茜_差分_縮小.psd` は `pikKaraiKotonoha` として別管理。専用処理は `PSDImageCustomKaraiKotonoha.pas`。
- `立ち絵琴葉葵_差分_縮小.psd` は `pikKaraiKotonohaAoi` として別管理。専用処理は `PSDImageCustomKaraiKotonohaAoi.pas`。
- どちらもユーザー確認済みで完成扱い。

### ぺぺち

- `◆ゆるい ゆづき&きずなⅡ ver1.1‘.psd` は `pikPepechi`。
- 専用処理は `PSDImageCustomPepechi.pas`。
- `きずな` / `ゆかり` 自体への `*`、各キャラの `め` / `くち`、両腕用レイヤーの表示連動を扱う。

### moiky

- `四国めたん` は `pikMoikyShikokuMetan`。専用処理は `PSDImageCustomMoiky.pas`。
- 衣装排他は親グループへ `*` を付ける方式ではなく、表示連動ルールで扱う。
- `あんこもん立ち絵` は `pikMoikyAnkomon`。既存の `四国めたん` と構造が違うため別管理。

### こーすけさんたまりあ

- 専用処理は `PSDImageCustomKosukeSantaMaria.pas`。
- 服装・腕・右腕・両腕の連動が複雑なため、共有処理へ広げずこのユニット側で閉じる方針。
- 腕系小分類は末端名だけへ正規化し、候補探索と表示連動で現在衣装に近い実レイヤーを選ばせる。
- DEBUG ログは `[KosukeDressArm]`、`[PSDVisibilityRule]`、`[PSDRoute]` を確認する。

### その他

- `PSDImageCustomFurasuko.pas`: ふらすこ式東北きりたんで、`衣装` 直下のPSD初期表示中レイヤーへ `-` を付け、初期服として表示を維持する動作をユーザー確認済み。処理はふらすこ共通へ広げ、`pikFurasuko` / `pikFurasukoKiritan` の `衣装` / `服装` 階層を対象にする。初期非表示衣装は後段の `+` 候補のまま扱う。
- `PSDImageCustomAjishio.pas`: `衣装 > 基本服` / `服基本` は、PSD初期表示中の場合に限り `-` 付き初期服として表示を維持する。従来の強制非表示は廃止し、同層の `*` / `+` 選択時だけ退避させる。実機確認待ち。
- `PSDImageCustomMunisaga.pas`: むにさが氏 `東北きりたん_立ち絵素材`。
- `PSDImageCustomTaotao.pas`: たおたお氏 `四国めたん_立ち絵`。
- `PSDImageCustomMiko.pas`: みこ氏 `damon`。
- `PSDImageCustomSaiyouWagashi.pas`: 西妖和菓子氏 `【フリー素材】つくよみちゃん2`。

## 作業ログ
- 2026-07-22 AI: 別作者へのFace初期服置換として、アジシオ氏の `HideAjishioCostumeBase` を `MarkAjishioCostumeBaseAsInitialDress` へ変更した。`衣装 > 基本服` / `服基本` がPSD初期表示中なら、非表示にせず `-` を付ける。元から非表示のレイヤーは従来の候補化を維持する。パーカーや他作者の装飾・ポーズ別初期表示補正は意味が異なるため変更対象外。両対象プロジェクトのDebug/Win64は0エラー。
- 2026-07-22 AI/ユーザー確認: ふらすこ式東北きりたんの `-` 初期服処理が正常動作した。`ApplyFurasukoInitialVisibility` をふらすこ共通処理として追加し、`pikFurasuko` と `pikFurasukoKiritan` の双方で、`衣装` / `服装` 直下のPSD初期表示中レイヤーへ `-` を付けるようにした。dispatcher の初期表示再適用にも `pikFurasuko` を接続。両対象プロジェクトのDebug/Win64は0エラー。
- 2026-07-22 AI: ふらすこ式東北きりたんの初期服置換を実験実装した。`ApplyFurasukoKiritanInitialVisibility` で `衣装` 直下を一律非表示にせず、PSD初期状態で表示中の子へ `-` を付けて表示を維持する。共有の `TPsdFileTree` 表示処理は `*` / `+` を表示した時だけ同じ親の `-` 兄弟を非表示にする。`PSDImageCustomMarkerUtils` のマーカー認識にも `-` を追加。両対象プロジェクトの Debug/Win64 は0エラー、実機確認待ち。
- 2026-07-05 AI: moiky `ずんだもん` 専用処理で、`体 > 作業着` は排他服ではなく追加差分として扱うため、`ApplyMoikyZundamonMarkers` 内で明示的に `+作業着` へ置き換え、非表示候補へ戻すようにした。自動補完は既存マーカーを上書きしないため、後段の `ApplyVirtualMarker('*' / '+')` で `*作業着` に戻らない。対象は `PSDImageCustomMoiky.pas`。
- 2026-07-05 AI: moiky `ずんだもん` の `!表情` ツリーは正しいが分類に出ない件を調査。原因は `TPSDElementList.ParseFromStrings` が小分類として `*` / `+` 付きレイヤーだけを拾うため、`!表情` 配下へ「`*` を付けない」子レイヤーとして移した `くろずみ` / `青ざめ` / `怒りマーク` / `汗` / `照れ` が汎用解析対象外になることだった。対処として `ApplyMoikyZundamonElementList` を追加し、`ApplyCustomElementList` から `!表情` Element と配下のプレーンな子レイヤーPartを分類へ明示追加するようにした。Part は実レイヤーの `AnmText` / `Index` を持つため `TPSDElementRouteList.BuildFromElements` で直接候補化できる。`Syncroh2_Extension2.dproj` と `Syncroh2_Filter_PSDDraw.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。
- 2026-07-05 AI: moiky `ずんだもん` 専用処理で、`顔パーツ` と同層にある `顔` 手前までの表情系レイヤーを仮想ノード `!表情` 配下へ移動する処理を追加した。移動対象は `顔パーツ` の直後から `顔` の直前までを参照で先に集め、`TPsdImage.AddVirtualTree` で `!表情` を作成してから `TPsdImage.MoveTree` で移す。分類反映前に確実に構造変更が終わるよう、処理は `ApplyCustomMarkers` 内で `ApplyVirtualMarker('*' / '+')` より前に実行する。さらに `PSDImageAviUtl2.ApplyVirtualMarkerToTrees` で LayerType=-1 かつ `!` の仮想分類ノード配下へ自動 `*` / `+` 補完を再帰しないようにし、`!表情` 配下の子レイヤーへ `*` が付かないようにした。`Syncroh2_Extension2.dproj` と `Syncroh2_Filter_PSDDraw.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。
- 2026-07-05 AI: moiky `ずんだもん` 専用処理を追加し、`pikMoikyZundamon` の `体 > 後髪` に `!` を付けるようにした。対象は `PSDImageCustomMoiky.pas` と `PSDImageCustomDispatcher.pas`。`FindMoikyZundamonRoot` と `ApplyMoikyZundamonMarkers` を追加し、`ApplyCustomMarkers` から呼び出す。`Syncroh2_Extension2.dproj` と `Syncroh2_Filter_PSDDraw.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。
- 2026-07-05 AI: `Lib/PSDImage/Custom/ZUNDAMON.txt` を確認し、`D:\VoiceroidProj\PSD\moiky\zundamon\ZUNDAMON.psd` は moiky氏制作だが、既存の `pikMoikyShikokuMetan` / `pikMoikyAnkomon` とは構造が大きく異なるため、作者名＋キャラ名の別種別 `pikMoikyZundamon` として扱うようにした。対象は `PSDImageCustomMoiky.pas`、`PSDImageCustomKindDetector.pas`、`PSDImageCustomDispatcher.pas`。構造判定は `v1` 直下の `顔パーツ` / `体` と、`顔パーツ` 配下の `耳` / `眉` / `目` / `口`、`体` 配下の `作業着` / `コート` / `着ぐるみ` / `普通` / `後髪` などを見る。Caption は `moiky_ずんだもんPSD`、dump 用 Kind 表示は `pikMoikyZundamon`。現時点では認識追加のみで、マーカー補正や表示連動は追加していない。`Syncroh2_Extension2.dproj` と `Syncroh2_Filter_PSDDraw.dproj` の `Debug / Win64` は `/p:PostBuildEvent=` 指定でビルド成功。`Syncroh2_Desktop.dproj` はコンパイル後、既存 `Win64\Debug\Syncroh2_Desktop.exe` を作成できず失敗したため、実行中プロセスなどによるロックの可能性が高い。

- 2026-06-15 AI: PSD 種類判定の責務を `Lib/PSDImage/Kind/PSDImageKindDetector.pas` から `Lib/PSDImage/Custom/Lib/PSDImageCustomKindDetector.pas` へ移した。旧 `PSDImageKindDetector` は互換用の薄い委譲ユニットとして残し、`PSDImageAviUtl2`、`PSDImageCustomDispatcher`、PSD UI、DressEditMenu は Custom 側の判定ユニットを直接使うよう変更した。`Syncroh2_Filter_PSDDraw.dproj`、`Syncroh2_Extension2.dproj`、`Syncroh2_Desktop.dproj` の `Debug / Win64` ビルドは `/p:PostBuildEvent=` 指定で成功した。

- 2026-06-15 AI: 「くっつく/ひっつく」系の分類を下へ回すための既存処理を調査。実ツリー移動は `TPsdImage.MoveTree` として存在し、Moiky / Nishimiya / KosukeSantaMaria などで使われているが、描画順や親子構造にも影響する強い処理だった。分類表示だけなら `ApplyCustomElementList` 後の `TPSDElementList` 並べ替えが適切そう。大分類末尾移動の既存専用例は見つからず、小分類順序調整例として `PSDImageCustomMoiky.AddTreePartIfMissing` の `Parts.Exchange` を確認した。

- 2026-06-15 AI: このメモを追加。`Lib/PSDImage/Custom` が作者別・キャラ別 PSD 専用処理ユニットと debug dump の置き場であること、ルート `note.md` から詳細を分離する運用、ユメのオワリ琴葉葵/茜 v01.09 の現状調査結果を記録した。

- 2026-06-16 AI: ユメのオワリ琴葉葵/茜 v01.09 で、`くっつく` / `ひっつく` かつ `下半身` を含む大分類が上部に出る場合、`ApplyYumeNoOwariElementCaptions` の末尾で `TPSDElementList` だけを並べ替え、同系統の `上半身` 分類の直前へ移動するようにした。実PSDツリーや描画順は変更しない。

- 2026-06-16 AI: 保存済み要素リストで `上半身` 側の移動先分類が見つからない場合でも、`アクセサリー後ろ`、`スカートをめくる時のみ`、最終的にはリスト末尾を移動先にして、`下半身` の `くっつく/ひっつく` 分類が上部に残らないようにした。

- 2026-06-16 AI: 専用分類の責務は PSD 読み込み時の `PSDImageAviUtl2.LoadFromFile` -> `ApplyCustomElementList` -> `PSDImageCustomYumeNoOwari.pas` に閉じる方針。UI やキャラ設定ロード側では分類補正を呼ばない。`下半身` 分類の移動は `TPSDElementList.Exchange` で行い、リスト所有権や挿入削除に依存しない形にした。

- 2026-06-16 AI: うまく分類移動されない原因確認用に、Debug ビルド時だけ `PSDImageDebugLog` へログを出すようにした。`PSDImageAviUtl2.LoadFromFile` は `PSDLoad` タグで Kind / Caption / Element 数を出し、`PSDImageCustomYumeNoOwari.pas` は `YumeNoOwariElement` タグで対象候補、移動先 index、移動前後の関連分類位置を出す。ログファイルは既存仕様の `PSDImageDebug.log`。

- 2026-06-16 AI: DEBUG実行時のPSDImageログは `PSDImageDebug.log` に出る。今回の実行環境では `D:\Users\take6\Syncroh2\Temp\PSDImageDebug.log` が更新されていた。環境や起動方法によっては `C:\Users\vramw\AppData\Local\Temp\Syncroh2\Temp\PSDImageDebug.log` 側を確認する必要がある。

- 2026-06-16 AI: ユメのオワリ琴葉葵/茜v01.09の「くっつく/ひっつく 下半身」分類移動ログでは、移動先検出が下半身分類配下の子要素 `茜葵上半身` を拾っていた。移動先は `Group=''` の親分類だけを対象にし、表示用 `TPSDElementList` の並び替えは次候補を飛ばさないよう同じ index を再評価する方針にした。

- 2026-06-16 AI: PSDImageログは起動が重くなるため、Debugビルドでも通常は出さない opt-in 方式に変更した。ログを出したい場合はログフォルダに空ファイル `PSDImageDebug.enabled` を作るか、環境変数 `SYNCROH2_PSD_DEBUG_LOG` に任意の値を入れて起動する。例: `D:\Users\take6\Syncroh2\Temp\PSDImageDebug.enabled` を置くと `D:\Users\take6\Syncroh2\Temp\PSDImageDebug.log` が出る。
