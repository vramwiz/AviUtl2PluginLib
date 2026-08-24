unit MenuSubItems;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,Vcl.ExtCtrls,Vcl.Menus;

type
  // 共通イベント用の型（MenuItem も渡す）
  TMenuSubItemClickEvent = procedure(Sender: TObject; MenuItem: TMenuItem) of object;

  TMenuSubItems = class(TPersistent)
  private
    FTarget: TMenuItem;
    FOnItemClick: TMenuSubItemClickEvent;
  protected
    procedure DoItemClick(Sender: TObject);
  public
    procedure Attach(TargetMenuItem: TMenuItem);
    procedure Clear;
    procedure Add(const Caption: string; Tag: Integer; Checked: Boolean = False);
    function IndexOfTag(Tag: Integer): Integer;
    property Target: TMenuItem read FTarget;
  published
    property OnItemClick: TMenuSubItemClickEvent read FOnItemClick write FOnItemClick;
  end;

implementation

{ TMenuSubItems }


procedure TMenuSubItems.Attach(TargetMenuItem: TMenuItem);
begin
  FTarget := TargetMenuItem;
end;

procedure TMenuSubItems.Clear;
begin
  if Assigned(FTarget) then
    FTarget.Clear;
end;

procedure TMenuSubItems.Add(const Caption: string; Tag: Integer; Checked: Boolean);
var
  Item: TMenuItem;
begin
  if not Assigned(FTarget) then
    Exit;

  Item := TMenuItem.Create(FTarget);
  Item.Caption := Caption;
  Item.Tag := Tag;
  Item.Checked := Checked;
  Item.OnClick := DoItemClick;

  FTarget.Add(Item);
end;

function TMenuSubItems.IndexOfTag(Tag: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  if not Assigned(FTarget) then
    Exit;

  for I := 0 to FTarget.Count - 1 do
  begin
    if FTarget.Items[I].Tag = Tag then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

procedure TMenuSubItems.DoItemClick(Sender: TObject);
begin
  if Assigned(FOnItemClick) and (Sender is TMenuItem) then
    FOnItemClick(Self, TMenuItem(Sender));
end;

end.
