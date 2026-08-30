unit MmdPoseEditorListTheme;

// 旧MMD名を共通ダーク一覧へ接続し、フォーム側の調整済みフォントを維持する。

interface

uses
  System.Classes,
  DarkCheckListBox, DarkListBox;

type
  TMmdDarkListBox = class(TDarkListBox)
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TMmdDarkCheckListBox = class(TDarkCheckListBox)
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

constructor TMmdDarkListBox.Create(AOwner: TComponent);
begin
  inherited;
  UseThemeFont := False;
  ParentFont := True;
end;

constructor TMmdDarkCheckListBox.Create(AOwner: TComponent);
begin
  inherited;
  UseThemeFont := False;
  ParentFont := True;
end;

end.
