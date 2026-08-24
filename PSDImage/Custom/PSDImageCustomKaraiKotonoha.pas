unit PSDImageCustomKaraiKotonoha;

interface

uses
  PsdImage, PSDImageElementList;

function IsKaraiKotonohaPSD(PsdImage: TPSDImage): Boolean;
procedure ApplyKaraiKotonohaMarkers(PsdImage: TPSDImage);
procedure ApplyKaraiKotonohaExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyKaraiKotonohaInitialVisibility(PsdImage: TPSDImage);
procedure ApplyKaraiKotonohaElementList(PsdImage: TPSDImage;
  Elements: TPSDElementList);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

const
  KOTONOHA_FACE_PARTS = '顔パーツ';
  KOTONOHA_EYE = '目';
  KOTONOHA_CLOSED_EYES_OTHER = '閉じ目他';
  KOTONOHA_CLOSED_EYES = '閉じ目';
  KOTONOHA_OPEN_EYES = '開き目';
  KOTONOHA_DARK_EYES = '病み';
  KOTONOHA_OTHER_EYES = '他';
  KOTONOHA_SERIOUS_TEAR = '涙（シリアスめ）';
  KOTONOHA_TEAR = '涙';
  KOTONOHA_BEAR = 'クマ';
  KOTONOHA_LIGHT = '光';
  KOTONOHA_BROW = '眉';
  KOTONOHA_MOUTH = '口';
  KOTONOHA_BODY = '本体';
  KOTONOHA_UNIFORM = '制服';
  KOTONOHA_CASUAL = '通常服';
  KOTONOHA_NORMAL = '通常';
  KOTONOHA_JERSEY = 'ジャージ';
  KOTONOHA_JERSEY_SKIRT = 'ジャージスカート';
  KOTONOHA_HAND = '手';
  KOTONOHA_LEFT_HAND = '左手';
  KOTONOHA_RIGHT_HAND = '右手';
  KOTONOHA_RIGHT_ARM = '右腕';
  KOTONOHA_RIGHT_ARM_UNIFORM = '右腕（制服）';
  KOTONOHA_RIGHT_ARM_CASUAL = '右腕（通常服）';
  KOTONOHA_KNIFE_SET = '包丁セット';
  KOTONOHA_GRIP_HAND = '持ち手';
  KOTONOHA_UP = '上';
  KOTONOHA_DOWN = '下';
  KOTONOHA_DONUT = 'ドーナツ';
  KOTONOHA_SIGNBOARD = '看板';
  KOTONOHA_BOARD = '板';
  KOTONOHA_NO_MEAL = 'ごはん抜き';
  KOTONOHA_ICON = 'アイコン';
  KOTONOHA_HEART = 'ハート';
  KOTONOHA_BACK_PARTS = '後ろパーツ';
  KOTONOHA_BACK_HAIR = '後ろ髪';
  KOTONOHA_AOI = '葵ちゃん';
  KOTONOHA_AKANE = '茜ちゃん';
  KOTONOHA_HAIR_PARTS = '髪パーツ';
  KOTONOHA_ITEM = '小物';
  KOTONOHA_EFFECT = '効果';
  KOTONOHA_PONYTAIL = 'ポニテとか';
  KOTONOHA_BAG = '鞄';

function FindTreeByName(Trees: TPsdFileTrees;
  const Name: string): TPsdFileTree;
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

    if SameText(TreeName(Tree), Name) then
      Exit(Tree);

    Result := FindTreeByName(TPsdFileTrees(Tree.Trees), Name);
    if Result <> nil then Exit;
  end;
end;

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

function IsKaraiKotonohaPSD(PsdImage: TPSDImage): Boolean;
var
  AkaneTree: TPsdFileTree;
  AkaneChildren: TPsdFileTrees;
  HandTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
  BodyChildren: TPsdFileTrees;
  FacePartsTree: TPsdFileTree;
  BodyBaseTree: TPsdFileTree;
  RightArmTree: TPsdFileTree;
  HairBackTree: TPsdFileTree;
begin
  Result := False;
  if PsdImage = nil then Exit;

  AkaneTree := FindTreeByName(PsdImage.Trees, KOTONOHA_AKANE);
  if AkaneTree = nil then Exit;

  if (FindTreeByName(PsdImage.Trees, KOTONOHA_BACK_PARTS) = nil) or
     (FindTreeByName(PsdImage.Trees, KOTONOHA_AOI) = nil) then
    Exit;

  AkaneChildren := TPsdFileTrees(AkaneTree.Trees);
  if not HasChildTrees(AkaneChildren,
    [KOTONOHA_HAND, KOTONOHA_HAIR_PARTS,
     KOTONOHA_ITEM, KOTONOHA_BODY]) then
    Exit;

  HandTree := FindChildTree(AkaneChildren, KOTONOHA_HAND);
  BodyTree := FindChildTree(AkaneChildren, KOTONOHA_BODY);
  HairBackTree := FindTreeByName(PsdImage.Trees, KOTONOHA_BACK_HAIR);
  if (HandTree = nil) or (BodyTree = nil) or (HairBackTree = nil) then
    Exit;

  if not HasChildTrees(TPsdFileTrees(HandTree.Trees),
    [KOTONOHA_LEFT_HAND, KOTONOHA_RIGHT_HAND]) then
    Exit;

  BodyChildren := TPsdFileTrees(BodyTree.Trees);
  if not HasChildTrees(BodyChildren,
    [KOTONOHA_FACE_PARTS, KOTONOHA_BODY, KOTONOHA_RIGHT_ARM]) then
    Exit;

  FacePartsTree := FindChildTree(BodyChildren, KOTONOHA_FACE_PARTS);
  BodyBaseTree := FindChildTree(BodyChildren, KOTONOHA_BODY);
  RightArmTree := FindChildTree(BodyChildren, KOTONOHA_RIGHT_ARM);
  if (FacePartsTree = nil) or (BodyBaseTree = nil) or (RightArmTree = nil) then
    Exit;

  Result :=
    HasChildTrees(TPsdFileTrees(FacePartsTree.Trees),
      [KOTONOHA_MOUTH, KOTONOHA_EFFECT,
       KOTONOHA_BROW, KOTONOHA_EYE]) and
    HasChildTrees(TPsdFileTrees(BodyBaseTree.Trees),
      [KOTONOHA_UNIFORM, KOTONOHA_CASUAL]) and
    HasChildTrees(TPsdFileTrees(RightArmTree.Trees),
      [KOTONOHA_RIGHT_ARM_UNIFORM,
       KOTONOHA_RIGHT_ARM_CASUAL]) and
    (FindTreeByName(TPsdFileTrees(HairBackTree.Trees),
       KOTONOHA_PONYTAIL) <> nil);
end;

procedure ApplyStarMarkersToChildren(Tree: TPsdFileTree);
var
  I: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if Tree = nil then Exit;

  ReplaceMarkerOnTree(Tree, '!');

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for I := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[I];
    if ChildTree = nil then Continue;

    ReplaceMarkerOnTree(ChildTree, '*');
  end;
end;

procedure ApplyStarMarkersToDirectChildren(Tree: TPsdFileTree);
var
  I: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if Tree = nil then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for I := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[I];
    if ChildTree = nil then Continue;

    ReplaceMarkerOnTree(ChildTree, '*');
  end;
end;

function IsOpenEyeStarMarkerExcluded(Tree: TPsdFileTree): Boolean;
var
  Name: string;
begin
  Name := TreeName(Tree);
  Result :=
    SameText(Name, KOTONOHA_SERIOUS_TEAR) or
    SameText(Name, KOTONOHA_TEAR) or
    SameText(Name, KOTONOHA_BEAR) or
    SameText(Name, KOTONOHA_LIGHT);
end;

procedure ApplyOpenEyeMarkers(Tree: TPsdFileTree);
var
  I: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if Tree = nil then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for I := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[I];
    if ChildTree = nil then Continue;
    if IsOpenEyeStarMarkerExcluded(ChildTree) then Continue;

    ReplaceMarkerOnTree(ChildTree, '*');
  end;
end;

procedure ApplyEyeChildMarkers(FacePartsTree: TPsdFileTree);
var
  EyeTree: TPsdFileTree;
begin
  EyeTree := FindChildTree(TPsdFileTrees(FacePartsTree.Trees), KOTONOHA_EYE);
  if EyeTree = nil then Exit;

  ApplyStarMarkersToChildren(EyeTree);
  ApplyStarMarkersToDirectChildren(
    FindChildTree(TPsdFileTrees(EyeTree.Trees), KOTONOHA_CLOSED_EYES_OTHER));
  ApplyStarMarkersToDirectChildren(
    FindChildTree(TPsdFileTrees(EyeTree.Trees), KOTONOHA_CLOSED_EYES));
  ApplyOpenEyeMarkers(
    FindChildTree(TPsdFileTrees(EyeTree.Trees), KOTONOHA_OPEN_EYES));
  ApplyStarMarkersToDirectChildren(
    FindChildTree(TPsdFileTrees(EyeTree.Trees), KOTONOHA_DARK_EYES));
  ApplyStarMarkersToDirectChildren(
    FindChildTree(TPsdFileTrees(EyeTree.Trees), KOTONOHA_OTHER_EYES));
end;

function FindKotonohaAkaneTree(FacePartsTree: TPsdFileTree): TPsdFileTree;
var
  BodyRootTree: TPsdFileTree;
begin
  Result := nil;
  if FacePartsTree = nil then Exit;

  BodyRootTree := ParentTree(FacePartsTree);
  if BodyRootTree = nil then Exit;

  Result := ParentTree(BodyRootTree);
end;

function FindKotonohaBodyBaseTree(FacePartsTree: TPsdFileTree): TPsdFileTree;
var
  BodyRootTree: TPsdFileTree;
begin
  Result := nil;
  if FacePartsTree = nil then Exit;

  BodyRootTree := ParentTree(FacePartsTree);
  if BodyRootTree = nil then Exit;

  Result := FindChildTree(TPsdFileTrees(BodyRootTree.Trees), KOTONOHA_BODY);
end;

procedure RenameFirstJerseyToSkirt(UniformTree: TPsdFileTree);
var
  I: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if UniformTree = nil then Exit;

  ChildTrees := TPsdFileTrees(UniformTree.Trees);
  if ChildTrees = nil then Exit;

  for I := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[I];
    if ChildTree = nil then Continue;

    if SameText(TreeName(ChildTree), KOTONOHA_JERSEY) then
    begin
      SetTreeLayerName(ChildTree, string('*') + KOTONOHA_JERSEY_SKIRT);
      Exit;
    end;
  end;
end;

procedure ApplyKotonohaDressMarkers(FacePartsTree: TPsdFileTree);
var
  BodyBaseTree: TPsdFileTree;
  UniformTree: TPsdFileTree;
begin
  BodyBaseTree := FindKotonohaBodyBaseTree(FacePartsTree);
  if BodyBaseTree = nil then Exit;

  ReplaceMarkerOnTree(
    FindChildTree(TPsdFileTrees(BodyBaseTree.Trees), KOTONOHA_UNIFORM), '*');
  ReplaceMarkerOnTree(
    FindChildTree(TPsdFileTrees(BodyBaseTree.Trees), KOTONOHA_CASUAL), '*');

  UniformTree := FindChildTree(TPsdFileTrees(BodyBaseTree.Trees),
    KOTONOHA_UNIFORM);
  if UniformTree = nil then Exit;

  ReplaceMarkerOnTree(
    FindChildTree(TPsdFileTrees(UniformTree.Trees), KOTONOHA_NORMAL), '*');
  RenameFirstJerseyToSkirt(UniformTree);
  ReplaceMarkerOnTree(
    FindChildTree(TPsdFileTrees(UniformTree.Trees), KOTONOHA_JERSEY), '*');
end;

procedure ApplyKotonohaRightArmMarkers(FacePartsTree: TPsdFileTree);
var
  BodyRootTree: TPsdFileTree;
  RightArmTree: TPsdFileTree;
begin
  BodyRootTree := ParentTree(FacePartsTree);
  if BodyRootTree = nil then Exit;

  RightArmTree := FindChildTree(TPsdFileTrees(BodyRootTree.Trees),
    KOTONOHA_RIGHT_ARM);
  if RightArmTree = nil then Exit;

  ApplyStarMarkersToChildren(RightArmTree);
  ApplyStarMarkersToDirectChildren(
    FindChildTree(TPsdFileTrees(RightArmTree.Trees),
      KOTONOHA_RIGHT_ARM_UNIFORM));
  ApplyStarMarkersToDirectChildren(
    FindChildTree(TPsdFileTrees(RightArmTree.Trees),
      KOTONOHA_RIGHT_ARM_CASUAL));
end;

procedure ApplyGripHandMarkerToKnifeSets(Trees: TPsdFileTrees);
var
  I: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    if SameText(TreeName(Tree), KOTONOHA_KNIFE_SET) then
      ReplaceMarkerOnTree(
        FindChildTree(TPsdFileTrees(Tree.Trees), KOTONOHA_GRIP_HAND), '!');

    ApplyGripHandMarkerToKnifeSets(TPsdFileTrees(Tree.Trees));
  end;
end;

procedure ApplyHandSideMarkers(Tree: TPsdFileTree);
var
  I: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if Tree = nil then Exit;

  ReplaceMarkerOnTree(Tree, '!');

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for I := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[I];
    if ChildTree = nil then Continue;

    ReplaceMarkerOnTree(ChildTree, '*');
    if SameText(TreeName(ChildTree), KOTONOHA_UP) or
       SameText(TreeName(ChildTree), KOTONOHA_DOWN) then
      ApplyStarMarkersToDirectChildren(ChildTree);
  end;

  ApplyGripHandMarkerToKnifeSets(ChildTrees);
end;

procedure ApplyKotonohaHandMarkers(FacePartsTree: TPsdFileTree);
var
  AkaneTree: TPsdFileTree;
  HandTree: TPsdFileTree;
begin
  AkaneTree := FindKotonohaAkaneTree(FacePartsTree);
  if AkaneTree = nil then Exit;

  HandTree := FindChildTree(TPsdFileTrees(AkaneTree.Trees), KOTONOHA_HAND);
  if HandTree = nil then Exit;

  ApplyHandSideMarkers(
    FindChildTree(TPsdFileTrees(HandTree.Trees), KOTONOHA_LEFT_HAND));
  ApplyHandSideMarkers(
    FindChildTree(TPsdFileTrees(HandTree.Trees), KOTONOHA_RIGHT_HAND));
end;

procedure ApplyKotonohaSignboardMarkers(FacePartsTree: TPsdFileTree);
var
  AkaneTree: TPsdFileTree;
  SignboardTree: TPsdFileTree;
begin
  AkaneTree := FindKotonohaAkaneTree(FacePartsTree);
  if AkaneTree = nil then Exit;

  SignboardTree := FindBestNamedTree(TPsdFileTrees(AkaneTree.Trees),
    KOTONOHA_SIGNBOARD);
  if SignboardTree = nil then Exit;

  ApplyStarMarkersToChildren(SignboardTree);
  ReplaceMarkerOnTree(
    FindChildTree(TPsdFileTrees(SignboardTree.Trees), KOTONOHA_BOARD), '!');
end;

procedure ApplyKotonohaBackPartsMarkers(PsdImage: TPSDImage);
var
  BackPartsTree: TPsdFileTree;
  AoiTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  BackPartsTree := FindBestNamedTree(PsdImage.Trees, KOTONOHA_BACK_PARTS);
  if BackPartsTree = nil then Exit;

  AoiTree := FindChildTree(TPsdFileTrees(BackPartsTree.Trees), KOTONOHA_AOI);
  if AoiTree = nil then Exit;

  ApplyStarMarkersToDirectChildren(AoiTree);
end;

procedure HideNamedTrees(Trees: TPsdFileTrees; const Name: string);
var
  I: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    if SameText(TreeName(Tree), Name) then
      Tree.SetVisibleLocal(False);

    HideNamedTrees(TPsdFileTrees(Tree.Trees), Name);
  end;
end;

procedure HideBagUnderUniformTrees(Trees: TPsdFileTrees);
var
  I: Integer;
  Tree: TPsdFileTree;
  BagTree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    if SameText(TreeName(Tree), KOTONOHA_UNIFORM) then
    begin
      BagTree := FindChildTree(TPsdFileTrees(Tree.Trees), KOTONOHA_BAG);
      if BagTree <> nil then
        BagTree.SetVisibleLocal(False);
    end;

    HideBagUnderUniformTrees(TPsdFileTrees(Tree.Trees));
  end;
end;

procedure HideIconHeart(PsdImage: TPSDImage);
var
  IconTree: TPsdFileTree;
  HeartTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  IconTree := FindBestNamedTree(PsdImage.Trees, KOTONOHA_ICON);
  if IconTree = nil then Exit;

  HeartTree := FindChildTree(TPsdFileTrees(IconTree.Trees), KOTONOHA_HEART);
  if HeartTree <> nil then
    HeartTree.SetVisibleLocal(False);
end;

procedure ApplyKaraiKotonohaMarkers(PsdImage: TPSDImage);
var
  FacePartsTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  FacePartsTree := FindBestNamedTree(PsdImage.Trees, KOTONOHA_FACE_PARTS);
  if FacePartsTree = nil then Exit;

  ApplyEyeChildMarkers(FacePartsTree);
  ApplyStarMarkersToChildren(
    FindChildTree(TPsdFileTrees(FacePartsTree.Trees), KOTONOHA_BROW));
  ApplyStarMarkersToChildren(
    FindChildTree(TPsdFileTrees(FacePartsTree.Trees), KOTONOHA_MOUTH));
  ApplyKotonohaDressMarkers(FacePartsTree);
  ApplyKotonohaRightArmMarkers(FacePartsTree);
  ApplyKotonohaHandMarkers(FacePartsTree);
  ApplyKotonohaSignboardMarkers(FacePartsTree);
  ApplyKotonohaBackPartsMarkers(PsdImage);
end;

procedure ApplyKaraiKotonohaExclusiveGroups(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;
  // TODO: Add exclusive groups after checking the Kotonoha layer structure.
end;

procedure ApplyKaraiKotonohaInitialVisibility(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  HideNamedTrees(PsdImage.Trees, KOTONOHA_DONUT);
  HideNamedTrees(PsdImage.Trees, KOTONOHA_NO_MEAL);
  HideBagUnderUniformTrees(PsdImage.Trees);
  HideIconHeart(PsdImage);
end;

procedure ApplyKaraiKotonohaElementList(PsdImage: TPSDImage;
  Elements: TPSDElementList);
begin
  if (PsdImage = nil) or (Elements = nil) then Exit;
  // TODO: Add element list fixes after checking the Kotonoha layer structure.
end;

end.
