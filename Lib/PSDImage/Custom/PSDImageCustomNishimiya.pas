unit PSDImageCustomNishimiya;

interface

uses
  PsdImage;

function IsNishimiyaFileName(const FileName: string): Boolean;
procedure ApplyNishimiyaMarkers(PsdImage: TPSDImage);
procedure ApplyNishimiyaInitialVisibility(PsdImage: TPSDImage);
procedure ApplyNishimiyaTreeRelinks(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, Classes, PsdImageTree, PSDImageCustomMarkerUtils;

function HasText(const S, Token: string): Boolean;
begin
  Result := Pos(LowerCase(Token), LowerCase(S)) > 0;
end;

function IsNishimiyaFileName(const FileName: string): Boolean;
var
  Name: string;
begin
  Name := ChangeFileExt(ExtractFileName(FileName), '');
  Result := (Pos('_', Name) > 0) and HasText(Name, 'にしみや式');
end;

procedure ApplyMarkerToDescendantTrees(Tree: TPsdFileTree; const Marker: Char);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if Tree = nil then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[i];
    if ChildTree = nil then Continue;

    ApplyMarkerToTree(ChildTree, Marker);
    ApplyMarkerToDescendantTrees(ChildTree, Marker);
  end;
end;

procedure ApplyMarkerToChildTrees(Tree: TPsdFileTree; const Marker: Char);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if Tree = nil then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[i];
    if ChildTree = nil then Continue;

    ApplyMarkerToTree(ChildTree, Marker);
  end;
end;

procedure ApplyNishimiyaMarkersToTrees(Trees: TPsdFileTrees);
var
  i: Integer;
  Tree: TPsdFileTree;
  Name: string;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    Name := TreeName(Tree);

    if SameText(Name, '右腕') or
       SameText(Name, '左腕') then
      ApplyMarkerToDescendantTrees(Tree, '*');

    if HasText(Name, '二重まぶた') then
      ApplyMarkerToChildTrees(Tree, '*');

    if HasText(Name, 'YMM目') then
    begin
      ApplyMarkerToTree(Tree, '*');
      ApplyMarkerToChildTrees(Tree, '*');
    end;

    if HasText(Name, 'YMM口') then
    begin
      ApplyMarkerToTree(Tree, '*');
      ApplyMarkerToChildTrees(Tree, '*');
    end;

    ApplyNishimiyaMarkersToTrees(TPsdFileTrees(Tree.Trees));
  end;
end;

procedure HideNameContainingTrees(Trees: TPsdFileTrees; const Token: string);
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    if HasText(TreeName(Tree), Token) then
      Tree.SetVisibleLocal(False);

    HideNameContainingTrees(TPsdFileTrees(Tree.Trees), Token);
  end;
end;

procedure ApplyNishimiyaMarkers(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  ApplyNishimiyaMarkersToTrees(PsdImage.Trees);
end;

procedure ApplyNishimiyaInitialVisibility(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  HideNameContainingTrees(PsdImage.Trees, 'オーバーレイ');
end;

procedure RelinkNamedTreeToNamedParent(PsdImage: TPSDImage;
  const TreeNameToMove, ParentName: string);
var
  TreeToMove: TPsdFileTree;
  ParentTree: TPsdFileTree;
  ParentChildren: TPsdFileTrees;
begin
  if PsdImage = nil then Exit;

  TreeToMove := FindBestNamedTree(PsdImage.Trees, TreeNameToMove);
  if TreeToMove = nil then Exit;

  ParentTree := FindBestNamedTree(PsdImage.Trees, ParentName);
  if ParentTree = nil then Exit;

  ParentChildren := TPsdFileTrees(ParentTree.Trees);
  if ParentChildren = nil then Exit;

  ReplaceMarkerOnTree(TreeToMove, '*');
  PsdImage.MoveTree(TreeToMove, ParentChildren);
end;

procedure CollectDescendantTreesByNameToken(Tree: TPsdFileTree;
  const Token: string; List: TList);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if (Tree = nil) or (List = nil) then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[i];
    if ChildTree = nil then Continue;

    if HasText(TreeName(ChildTree), Token) then
      List.Add(ChildTree)
    else
      CollectDescendantTreesByNameToken(ChildTree, Token, List);
  end;
end;

procedure MoveDescendantTreesByNameToken(PsdImage: TPSDImage;
  const RootName, Token, DestParentName: string);
var
  RootTree: TPsdFileTree;
  DestParentTree: TPsdFileTree;
  DestChildren: TPsdFileTrees;
  TreesToMove: TList;
  i: Integer;
  TreeToMove: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindBestNamedTree(PsdImage.Trees, RootName);
  if RootTree = nil then Exit;

  DestParentTree := FindBestNamedTree(PsdImage.Trees, DestParentName);
  if DestParentTree = nil then Exit;

  DestChildren := TPsdFileTrees(DestParentTree.Trees);
  if DestChildren = nil then Exit;

  TreesToMove := TList.Create;
  try
    CollectDescendantTreesByNameToken(RootTree, Token, TreesToMove);

    for i := 0 to TreesToMove.Count - 1 do
    begin
      TreeToMove := TPsdFileTree(TreesToMove[i]);
      if TreeToMove = nil then Continue;

      ReplaceMarkerOnTree(TreeToMove, '*');
      PsdImage.MoveTree(TreeToMove, DestChildren);
    end;
  finally
    TreesToMove.Free;
  end;
end;

procedure ApplyNishimiyaTreeRelinks(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  RelinkNamedTreeToNamedParent(PsdImage, '右腕（肩ひも有）', '右腕');
  RelinkNamedTreeToNamedParent(PsdImage, '左腕（肩ひも有）', '左腕');

  MoveDescendantTreesByNameToken(PsdImage, '右腕', '（左手）', '左腕');
  MoveDescendantTreesByNameToken(PsdImage, '右腕', '(左手)', '左腕');
  MoveDescendantTreesByNameToken(PsdImage, '左腕', '（右手）', '右手');
  MoveDescendantTreesByNameToken(PsdImage, '左腕', '(右手)', '右手');
end;

end.
