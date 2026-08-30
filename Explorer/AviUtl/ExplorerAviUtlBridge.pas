unit ExplorerAviUtlBridge;

interface

uses
  System.Classes;

type
  TExplorerFrameDurationProvider = function: Double;
  TExplorerSelectedAliasProvider = procedure(List: TStringList);

procedure SetExplorerAviUtlBridge(
  AFrameDurationProvider: TExplorerFrameDurationProvider;
  ASelectedAliasProvider: TExplorerSelectedAliasProvider);
procedure ClearExplorerAviUtlBridge;
function ExplorerFrameDuration: Double;
procedure ExplorerGetSelectedAlias(List: TStringList);

implementation

var
  FrameDurationProvider: TExplorerFrameDurationProvider;
  SelectedAliasProvider: TExplorerSelectedAliasProvider;

procedure SetExplorerAviUtlBridge(
  AFrameDurationProvider: TExplorerFrameDurationProvider;
  ASelectedAliasProvider: TExplorerSelectedAliasProvider);
begin
  FrameDurationProvider := AFrameDurationProvider;
  SelectedAliasProvider := ASelectedAliasProvider;
end;

procedure ClearExplorerAviUtlBridge;
begin
  FrameDurationProvider := nil;
  SelectedAliasProvider := nil;
end;

function ExplorerFrameDuration: Double;
begin
  Result := 1 / 30;
  if Assigned(FrameDurationProvider) then
    Result := FrameDurationProvider;
  if Result <= 0 then
    Result := 1 / 30;
end;

procedure ExplorerGetSelectedAlias(List: TStringList);
begin
  if List = nil then
    Exit;
  List.Clear;
  if Assigned(SelectedAliasProvider) then
    SelectedAliasProvider(List);
end;

end.
