unit PSDImageCustomPepechi;

interface

uses
  PsdImage;

procedure ApplyPepechiMarkers(PsdImage: TPSDImage);
procedure ApplyPepechiExclusiveGroups(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

function UnicodeName(const Codes: array of Word): string;
var
  i: Integer;
begin
  Result := '';
  for i := Low(Codes) to High(Codes) do
    Result := Result + Char(Codes[i]);
end;

function FindNamedTreeInChildren(Trees: TPsdFileTrees;
  const Name: string): TPsdFileTree;
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  Result := nil;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if (Tree <> nil) and SameText(TreeName(Tree), Name) then
      Exit(Tree);
  end;
end;

procedure ApplyPepechiCharacterMarkers(PsdImage: TPSDImage);
var
  KizunaTree: TPsdFileTree;
  YukariTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  KizunaTree := FindBestNamedTree(PsdImage.Trees,
    UnicodeName([$304D, $305A, $306A]));
  if KizunaTree <> nil then
    ReplaceMarkerOnTree(KizunaTree, '*');

  YukariTree := FindBestNamedTree(PsdImage.Trees,
    UnicodeName([$3086, $304B, $308A]));
  if YukariTree <> nil then
    ReplaceMarkerOnTree(YukariTree, '*');
end;

procedure ApplyPepechiFacePartMarkersToCharacter(CharacterTree: TPsdFileTree);
var
  Children: TPsdFileTrees;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
begin
  if CharacterTree = nil then
    Exit;

  Children := TPsdFileTrees(CharacterTree.Trees);
  EyeTree := FindNamedTreeInChildren(Children, UnicodeName([$3081]));
  MouthTree := FindNamedTreeInChildren(Children, UnicodeName([$304F, $3061]));

  if EyeTree <> nil then
    ReplaceMarkerOnTree(EyeTree, '!');
  if MouthTree <> nil then
    ReplaceMarkerOnTree(MouthTree, '!');
end;

procedure ApplyPepechiFacePartMarkers(PsdImage: TPSDImage);
var
  KizunaTree: TPsdFileTree;
  YukariTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  KizunaTree := FindBestNamedTree(PsdImage.Trees,
    UnicodeName([$304D, $305A, $306A]));
  YukariTree := FindBestNamedTree(PsdImage.Trees,
    UnicodeName([$3086, $304B, $308A]));

  ApplyPepechiFacePartMarkersToCharacter(KizunaTree);
  ApplyPepechiFacePartMarkersToCharacter(YukariTree);
end;

procedure AddBothArmExclusiveRule(PsdImage: TPSDImage;
  BothArmTree, RightArmTree, LeftArmTree: TPsdFileTree);
begin
  if (PsdImage = nil) or (BothArmTree = nil) or
     (RightArmTree = nil) or (LeftArmTree = nil) then
    Exit;

  // Both-arm layers overlap with the left/right arm groups.
  PsdImage.AddVisibilityRule(BothArmTree, RightArmTree, False);
  PsdImage.AddVisibilityRule(BothArmTree, LeftArmTree, False);

  // When either one-arm group is selected, restore the other arm and hide the both-arm layer.
  PsdImage.AddVisibilityRule(RightArmTree, LeftArmTree, True);
  PsdImage.AddVisibilityRule(RightArmTree, BothArmTree, False);
  PsdImage.AddVisibilityRule(LeftArmTree, RightArmTree, True);
  PsdImage.AddVisibilityRule(LeftArmTree, BothArmTree, False);
end;

procedure ApplyYukariArmExclusiveGroup(PsdImage: TPSDImage);
var
  YukariTree: TPsdFileTree;
  YukariChildren: TPsdFileTrees;
  BothArmTree32: TPsdFileTree;
  BothArmTree33: TPsdFileTree;
  RightArmTree: TPsdFileTree;
  LeftArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  YukariTree := FindBestNamedTree(PsdImage.Trees,
    UnicodeName([$3086, $304B, $308A]));
  if YukariTree = nil then Exit;

  YukariChildren := TPsdFileTrees(YukariTree.Trees);
  BothArmTree32 := FindNamedTreeInChildren(YukariChildren,
    UnicodeName([$30EC, $30A4, $30E4, $30FC, $0020, $0033, $0032]));
  BothArmTree33 := FindNamedTreeInChildren(YukariChildren,
    UnicodeName([$30EC, $30A4, $30E4, $30FC, $0020, $0033, $0033]));
  LeftArmTree := FindNamedTreeInChildren(YukariChildren,
    UnicodeName([$5DE6, $8155]));
  RightArmTree := FindNamedTreeInChildren(YukariChildren,
    UnicodeName([$53F3, $8155]));

  if (BothArmTree32 = nil) or (BothArmTree33 = nil) or
     (LeftArmTree = nil) or (RightArmTree = nil) then
    Exit;

  AddBothArmExclusiveRule(PsdImage, BothArmTree32, RightArmTree, LeftArmTree);
  AddBothArmExclusiveRule(PsdImage, BothArmTree33, RightArmTree, LeftArmTree);
end;

procedure ApplyKizunaArmExclusiveGroup(PsdImage: TPSDImage);
var
  KizunaTree: TPsdFileTree;
  KizunaChildren: TPsdFileTrees;
  BothArmTree64: TPsdFileTree;
  RightArmTree: TPsdFileTree;
  LeftArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  KizunaTree := FindBestNamedTree(PsdImage.Trees,
    UnicodeName([$304D, $305A, $306A]));
  if KizunaTree = nil then Exit;

  KizunaChildren := TPsdFileTrees(KizunaTree.Trees);
  BothArmTree64 := FindNamedTreeInChildren(KizunaChildren,
    UnicodeName([$30EC, $30A4, $30E4, $30FC, $0020, $0036, $0034]));
  LeftArmTree := FindNamedTreeInChildren(KizunaChildren,
    UnicodeName([$5DE6, $8155]));
  RightArmTree := FindNamedTreeInChildren(KizunaChildren,
    UnicodeName([$53F3, $8155]));

  AddBothArmExclusiveRule(PsdImage, BothArmTree64, RightArmTree, LeftArmTree);
end;

procedure ApplyPepechiMarkers(PsdImage: TPSDImage);
begin
  ApplyPepechiCharacterMarkers(PsdImage);
  ApplyPepechiFacePartMarkers(PsdImage);
end;

procedure ApplyPepechiExclusiveGroups(PsdImage: TPSDImage);
begin
  ApplyKizunaArmExclusiveGroup(PsdImage);
  ApplyYukariArmExclusiveGroup(PsdImage);
end;

end.
