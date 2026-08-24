# AviUtl2PluginLib

AviUtl2向けDelphiプロジェクト間で共有するソースライブラリです。

各利用プロジェクトとこのリポジトリを、同じ親フォルダの直下へ配置します。

```text
AviUtl2Plugin/
├─ AviUtl2PluginLib/
├─ Syncroh2/
└─ OtherPlugin/
```

利用プロジェクトは、プロジェクトファイルを基準とした相対パスで必要なライブラリだけを参照します。

## ライブラリ

- `DropFile`: VCLコントロールでWindowsのファイルドロップを受け取る機能。
