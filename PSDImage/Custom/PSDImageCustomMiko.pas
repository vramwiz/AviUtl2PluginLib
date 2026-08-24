unit PSDImageCustomMiko;

interface

uses
  PsdImage;

function IsMikoDamonPSD(PsdImage: TPSDImage): Boolean;
procedure ApplyMikoDamonInitialVisibility(PsdImage: TPSDImage);

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

function HasMikoDamonRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  TearTree: TPsdFileTree;
  BrowTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;
  if not SameText(TreeName(Tree), 'v1') then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    ['涙とか', '眉', '目', '口', '体', '背景']) then
    Exit;

  TearTree := FindChildTree(RootChildren, '涙とか');
  BrowTree := FindChildTree(RootChildren, '眉');
  EyeTree := FindChildTree(RootChildren, '目');
  MouthTree := FindChildTree(RootChildren, '口');

  Result :=
    HasChildTrees(TPsdFileTrees(TearTree.Trees),
      ['照れ', '蒼白', '涙(閉じ)', '涙', '汗']) and
    HasChildTrees(TPsdFileTrees(BrowTree.Trees),
      ['おこ', '困った', 'ノーマル']) and
    HasChildTrees(TPsdFileTrees(EyeTree.Trees),
      ['＞＜', '白目', 'まばたき', 'にこにこ', 'ぐるぐる', 'ノーマル']) and
    HasChildTrees(TPsdFileTrees(MouthTree.Trees),
      ['あわわ', 'よだれ', 'ω', 'にこ', 'むっ', 'ぷんぷん',
       'すん', 'あっ', 'お', 'え', 'う', 'い', 'あ']);
end;

function HasMikoDamonRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasMikoDamonRootStructure(Tree) then
      Exit(True);

    if HasMikoDamonRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function IsMikoDamonPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasMikoDamonRoot(PsdImage.Trees);
end;

function FindMikoDamonRoot(Trees: TPsdFileTrees): TPsdFileTree;
var
  I: Integer;
  Tree: TPsdFileTree;
begin
  Result := nil;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    if HasMikoDamonRootStructure(Tree) then
      Exit(Tree);

    Result := FindMikoDamonRoot(TPsdFileTrees(Tree.Trees));
    if Result <> nil then Exit;
  end;
end;

procedure ApplyMikoDamonInitialVisibility(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  BackgroundTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMikoDamonRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  BackgroundTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '背景');
  if BackgroundTree <> nil then
    BackgroundTree.SetVisibleLocal(False);
end;

end.
