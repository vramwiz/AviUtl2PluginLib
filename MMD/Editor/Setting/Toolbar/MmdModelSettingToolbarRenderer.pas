unit MmdModelSettingToolbarRenderer;

// モデル設定フォームのページ切替ツールバーを共通の暗色配色で描画する。

interface

uses
  System.Types,
  Vcl.ComCtrls,
  Vcl.ImgList,
  Vcl.ToolWin;

// ツールバー背景を設定画面の共通色で塗り、標準描画を継続させる。
procedure DrawMmdModelSettingToolbar(Sender: TToolBar; const ARect: TRect;
  var DefaultDraw: Boolean);
// ボタン状態に応じた背景と指定アイコンを描き、標準ボタン描画を置き換える。
procedure DrawMmdModelSettingToolbarButton(Sender: TToolBar;
  Button: TToolButton; State: TCustomDrawState; Images: TCustomImageList;
  var DefaultDraw: Boolean);

implementation

uses
  Vcl.Graphics,
  MmdPoseEditorTheme;

const
  ModeToolbarBackground = MmdEditorPanel;
  ModeToolbarHot = TColor($00B03C3C);
  ModeToolbarPressed = TColor($001F1F1F);
  ModeToolbarChecked = TColor($00FF6666);

procedure DrawMmdModelSettingToolbar(Sender: TToolBar; const ARect: TRect;
  var DefaultDraw: Boolean);
begin
  Sender.Canvas.Brush.Color := ModeToolbarBackground;
  Sender.Canvas.FillRect(ARect);
  DefaultDraw := True;
end;

procedure DrawMmdModelSettingToolbarButton(Sender: TToolBar;
  Button: TToolButton; State: TCustomDrawState; Images: TCustomImageList;
  var DefaultDraw: Boolean);
var
  ButtonRect: TRect;
  Color: TColor;
begin
  ButtonRect := Button.BoundsRect;
  if cdsChecked in State then
    Color := ModeToolbarChecked
  else if cdsSelected in State then
    Color := ModeToolbarPressed
  else if cdsHot in State then
    Color := ModeToolbarHot
  else
    Color := ModeToolbarBackground;
  Sender.Canvas.Brush.Color := Color;
  Sender.Canvas.FillRect(ButtonRect);
  if Assigned(Images) and (Button.ImageIndex >= 0) and
    (Button.ImageIndex < Images.Count) then
    Images.Draw(Sender.Canvas,
      ButtonRect.Left + (ButtonRect.Width - Images.Width) div 2,
      ButtonRect.Top + (ButtonRect.Height - Images.Height) div 2,
      Button.ImageIndex, True);
  DefaultDraw := False;
end;

end.
