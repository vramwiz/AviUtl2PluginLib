unit PSDImageCustomMatcher;

interface

uses
  PsdImage;

function IsMatcherPSD(PsdImage: TPSDImage): Boolean;
procedure ApplyMatcherMarkers(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

function HasChildTrees(Trees: TPsdFileTrees;
  const Names: array of string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Trees = nil then Exit;

  for I := Low(Names) to High(Names) do
    if FindChildTree(Trees, Names[I]) = nil then
      Exit;

  Result := True;
end;

function CountChildTrees(Trees: TPsdFileTrees): Integer;
var
  I: Integer;
begin
  Result := 0;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
    if Trees[I] <> nil then
      Inc(Result);
end;

function HasMatcherRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  MarkTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
  HeadTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
  LeftArmTree: TPsdFileTree;
  RightArmTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    ['マーク', '腕', '頭', '目', '体']) then
    Exit;

  MarkTree := FindChildTree(RootChildren, 'マーク');
  ArmTree := FindChildTree(RootChildren, '腕');
  HeadTree := FindChildTree(RootChildren, '頭');
  EyeTree := FindChildTree(RootChildren, '目');
  BodyTree := FindChildTree(RootChildren, '体');
  LeftArmTree := FindChildTree(TPsdFileTrees(ArmTree.Trees), '左腕');
  RightArmTree := FindChildTree(TPsdFileTrees(ArmTree.Trees), '右腕');

  Result :=
    (CountChildTrees(TPsdFileTrees(MarkTree.Trees)) >= 5) and
    (CountChildTrees(TPsdFileTrees(HeadTree.Trees)) >= 1) and
    (CountChildTrees(TPsdFileTrees(EyeTree.Trees)) >= 10) and
    (BodyTree <> nil) and
    (CountChildTrees(TPsdFileTrees(LeftArmTree.Trees)) >= 5) and
    (CountChildTrees(TPsdFileTrees(RightArmTree.Trees)) >= 5);
end;

function HasMatcherRoot(Trees: TPsdFileTrees): Boolean;
var
  I: Integer;
  Tree: TPsdFileTree;
begin
  Result := False;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    if HasMatcherRootStructure(Tree) then
      Exit(True);

    if HasMatcherRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function IsMatcherPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasMatcherRoot(PsdImage.Trees);
end;

procedure ApplyMatcherArmMarkersToTrees(Trees: TPsdFileTrees);
var
  I: Integer;
  Tree: TPsdFileTree;
  Name: string;
begin
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    Name := TreeName(Tree);
    if SameText(Name, '左腕') or SameText(Name, '右腕') then
      ReplaceMarkerOnTree(Tree, '!');

    ApplyMatcherArmMarkersToTrees(TPsdFileTrees(Tree.Trees));
  end;
end;

procedure ApplyMatcherMarkers(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  ApplyMatcherArmMarkersToTrees(PsdImage.Trees);
end;

end.
