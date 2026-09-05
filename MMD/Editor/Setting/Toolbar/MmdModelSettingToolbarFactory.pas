unit MmdModelSettingToolbarFactory;

// モデル設定フォームのページ切替ツールバー、アイコン、ボタンを一括生成する。

interface

uses
  System.Classes,
  System.Types,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ImgList,
  Vcl.ToolWin;

type
  TMmdSettingToolbarDrawEvent = procedure(Sender: TToolBar;
    const ARect: TRect; var DefaultDraw: Boolean) of object;
  TMmdSettingToolbarDrawButtonEvent = procedure(Sender: TToolBar;
    Button: TToolButton; State: TCustomDrawState;
    var DefaultDraw: Boolean) of object;

// Parentへページ切替ツールバーを作り、ページ番号をTagに持つボタン配列を返す。生成物はAOwnerが所有する。
procedure BuildMmdModelSettingToolbar(AOwner: TComponent;
  Parent: TWinControl; PPI: Integer; ShowAllPages: Boolean;
  OnModeClick: TNotifyEvent; OnCustomDraw: TMmdSettingToolbarDrawEvent;
  OnCustomDrawButton: TMmdSettingToolbarDrawButtonEvent;
  out Images: TImageList; out Toolbar: TToolBar;
  out Buttons: TArray<TToolButton>);

implementation

uses
  Winapi.Windows,
  MmdModelSettingEditorIcons,
  MmdModelSettingToolbarRenderer,
  MmdPoseEditorTheme;

function AddModeButton(AOwner: TComponent; Toolbar: TToolBar;
  Page: Integer; const Caption: string; Down: Boolean;
  OnModeClick: TNotifyEvent): TToolButton;
begin
  Result := TToolButton.Create(AOwner);
  Result.Parent := Toolbar;
  Result.Caption := Caption;
  Result.Hint := Caption;
  Result.ShowHint := True;
  Result.ImageIndex := Page;
  Result.Tag := Page;
  Result.Style := tbsCheck;
  Result.Grouped := True;
  Result.Down := Down;
  Result.OnClick := OnModeClick;
end;

procedure BuildMmdModelSettingToolbar(AOwner: TComponent;
  Parent: TWinControl; PPI: Integer; ShowAllPages: Boolean;
  OnModeClick: TNotifyEvent; OnCustomDraw: TMmdSettingToolbarDrawEvent;
  OnCustomDrawButton: TMmdSettingToolbarDrawButtonEvent;
  out Images: TImageList; out Toolbar: TToolBar;
  out Buttons: TArray<TToolButton>);
var
  IconSize, ToolbarSize: Integer;
begin
  if PPI <= 0 then
    PPI := 96;
  ToolbarSize := MulDiv(30, PPI, 96);
  IconSize := MulDiv(20, PPI, 96);
  Images := TImageList.Create(AOwner);
  BuildMmdModelSettingIcons(Images, IconSize, ShowAllPages);
  Toolbar := TToolBar.Create(AOwner);
  Toolbar.Parent := Parent;
  Toolbar.Align := alTop;
  Toolbar.Height := ToolbarSize;
  Toolbar.ButtonWidth := ToolbarSize;
  Toolbar.ButtonHeight := ToolbarSize;
  Toolbar.Color := MmdEditorPanel;
  Toolbar.Flat := True;
  Toolbar.ShowCaptions := False;
  Toolbar.ShowHint := True;
  Toolbar.Wrapable := False;
  Toolbar.Images := Images;
  Toolbar.OnCustomDraw := OnCustomDraw;
  Toolbar.OnCustomDrawButton := OnCustomDrawButton;
  SetLength(Buttons, 4);
  if ShowAllPages then
  begin
    Buttons[3] := AddModeButton(AOwner, Toolbar, 3, #$53E3#$30D1#$30AF,
      False, OnModeClick);
    Buttons[2] := AddModeButton(AOwner, Toolbar, 2, #$76EE#$30D1#$30C1,
      False, OnModeClick);
  end;
  Buttons[1] := AddModeButton(AOwner, Toolbar, 1, #$8868#$60C5, False,
    OnModeClick);
  Buttons[0] := AddModeButton(AOwner, Toolbar, 0, #$30DD#$30FC#$30BA, True,
    OnModeClick);
  Buttons[0].AllowAllUp := False;
  Toolbar.BringToFront;
end;

end.
