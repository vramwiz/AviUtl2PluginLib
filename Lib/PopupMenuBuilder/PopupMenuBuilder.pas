unit PopupMenuBuilder;

interface

uses
  System.Classes,
  Vcl.Menus;

type
  // 毎回 Clear → Add して使う前提の PopupMenu
  // 自動処理・内部イベント・継承拡張は行わない
  TPopupMenuBuilder = class(TPopupMenu)
  public
    constructor Create(AOwner: TComponent); override;

    // メニュー項目を全削除
    procedure Clear;

    // メニュー項目追加
    function AddMenuItem(
      const Caption: string;
      Tag: NativeInt = 0;
      OnClick: TNotifyEvent = nil;
      Enabled: Boolean = True
    ): TMenuItem;

    function AddCheckedMenuItem(
      const Caption: string;
      Tag: NativeInt = 0;
      OnClick: TNotifyEvent = nil;
      Checked: Boolean = False;
      Enabled: Boolean = True
    ): TMenuItem;
  end;

implementation

{ TPopupMenuBuilder }

constructor TPopupMenuBuilder.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

procedure TPopupMenuBuilder.Clear;
begin
  Items.Clear;
end;

function TPopupMenuBuilder.AddMenuItem(
  const Caption: string;
  Tag: NativeInt = 0;
  OnClick: TNotifyEvent = nil;
  Enabled: Boolean = True
): TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Caption := Caption;
  Result.Tag     := Tag;
  Result.OnClick := OnClick;
  Result.Enabled := Enabled;
  Items.Add(Result);
end;

function TPopupMenuBuilder.AddCheckedMenuItem(
  const Caption: string;
  Tag: NativeInt = 0;
  OnClick: TNotifyEvent = nil;
  Checked: Boolean = False;
  Enabled: Boolean = True
): TMenuItem;
begin
  Result := AddMenuItem(Caption, Tag, OnClick, Enabled);
  Result.AutoCheck := False;
  Result.Checked := Checked;
end;

end.

