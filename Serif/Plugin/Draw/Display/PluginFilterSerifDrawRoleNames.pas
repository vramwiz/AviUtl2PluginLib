unit PluginFilterSerifDrawRoleNames;

interface

uses
  System.Types;

// 表示順を変えずに同一配役名を判定するための比較キーを作る。
function SerifDrawRoleNameKey(const AValue: string): string;
// 配役名グループの相対配置を保ったまま表示領域へ収める移動量を返す。
function SerifDrawRoleNameViewportOffset(const ABounds: TRect;
  const AWidth, AHeight, AMargin: Integer): TPoint;

implementation

uses
  System.Math,
  System.SysUtils;

function SerifDrawRoleNameAxisOffset(const AStart, AFinish, AExtent,
  AMargin: Integer): Integer;
var
  Available: Integer;
  Margin: Integer;
  Size: Integer;
begin
  if AExtent <= 0 then
    Exit(0);
  Margin := EnsureRange(AMargin, 0, AExtent div 2);
  Available := AExtent - Margin * 2;
  Size := AFinish - AStart;
  if Size > Available then
    Exit((AExtent - Size) div 2 - AStart);
  if AStart < Margin then
    Exit(Margin - AStart);
  if AFinish > AExtent - Margin then
    Exit(AExtent - Margin - AFinish);
  Result := 0;
end;

function SerifDrawRoleNameViewportOffset(const ABounds: TRect;
  const AWidth, AHeight, AMargin: Integer): TPoint;
begin
  Result.X := SerifDrawRoleNameAxisOffset(ABounds.Left, ABounds.Right,
    AWidth, AMargin);
  Result.Y := SerifDrawRoleNameAxisOffset(ABounds.Top, ABounds.Bottom,
    AHeight, AMargin);
end;

function SerifDrawRoleNameKey(const AValue: string): string;
var
  C: Char;
  PendingSpace: Boolean;
begin
  Result := '';
  PendingSpace := False;
  for C in AValue do
    if (C <= ' ') or (C = #$3000) then
    begin
      if Result <> '' then
        PendingSpace := True;
    end
    else
    begin
      if PendingSpace then
        Result := Result + ' ';
      Result := Result + C;
      PendingSpace := False;
    end;
  Result := LowerCase(Result);
end;

end.
