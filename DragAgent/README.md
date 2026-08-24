# DragAgent.pas

Delphi 向けのドラッグ送信支援ユニットです。  
任意の `TWinControl` 派生コントロールに対してドラッグ操作（仮想ファイル、テキストなど）を付与し、COMベースの `DoDragDrop` を通じて外部アプリへのデータ送信が可能になります。

---

## ✨ 主な機能

- `TWinControl` にドラッグ操作を付与（Attach / Detach）
- ドラッグ中のマウス操作を自動で検出・制御
- COM標準の `IDropSource` を実装
- ドラッグキャンセル、ターゲット到達イベントをフック
- 継承により、ファイル・テキスト・HTMLなど多形式に対応可能

---

## 🧱 クラス構成

### 🔹 `TDragAgent`
- 抽象基底クラス（`IDropSource` 実装）
- ドラッグ検出、COM転送、イベント通知などを一括管理
- 継承して `DoDragDataMake`, `DoDragRequest` を実装することで使用可能

### 🔹 `TDragShellFile`
- ファイルドラッグ用の実装例
- `OnDragRequest` イベントでファイル名を通知
- `CF_HDROP` に基づく `IDataObject` を自動生成

---

## 🚀 使用例

```pascal
type
  TMyDrag = class(TDragShellFile)
  protected
    procedure DoDragRequestFiles(FileNames: TStringList); override;
  end;

procedure TMyDrag.DoDragRequestFiles(FileNames: TStringList);
begin
  FileNames.Add('sample.txt');
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  MyDrag := TMyDrag.Create(Self);
  MyDrag.Attach(Button1);  // Button1 にドラッグ機能を付与
end;
```

---

## 🛠 実装のしくみ

- `MouseDown / Move / Up` を差し替えてドラッグ開始を検出
- `DoDragDrop(IDataObject, Self, ...)` を呼び出してドラッグを送信
- `QueryContinueDrag`, `GiveFeedback` によって ESCキャンセルやカーソル変化に対応
- `DoDragRequest` により動的にデータ生成が可能

---

## 📌 注意点

- VCL標準の DragMode とは独立して動作します
- コントロールに複数のイベントを上書きするため、既存の OnMouse 系イベントとの競合に注意
- `DoDragDataMake` は abstract のため、継承クラスでの実装が必須です

---

## 📄 ライセンス

MIT License またはプロジェクトに合わせて自由に変更してください。

---

## 🧑‍💻 作者

Created by **vramwiz**  
Created: 2025-07-10  
Updated: 2025-07-10
