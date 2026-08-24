unit PSDImageCustomKaraiKotonohaAoi;

interface

uses
  PsdImage, PSDImageElementList;

function IsKaraiKotonohaAoiPSD(PsdImage: TPSDImage): Boolean;
procedure ApplyKaraiKotonohaAoiMarkers(PsdImage: TPSDImage);
procedure ApplyKaraiKotonohaAoiExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyKaraiKotonohaAoiInitialVisibility(PsdImage: TPSDImage);
procedure ApplyKaraiKotonohaAoiElementList(PsdImage: TPSDImage;
  Elements: TPSDElementList);

implementation

uses
  SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

const
  KOTONOHA_AOI_FACE_PARTS = '顔パーツ';
  KOTONOHA_AOI_EYE = '目';
  KOTONOHA_AOI_MOUTH = '口';
  KOTONOHA_AOI_OPEN_EYES = '開き目';
  KOTONOHA_AOI_CLOSED_EYES_OTHER = '閉じ目他';
  KOTONOHA_AOI_SPECIAL = '特殊';
  KOTONOHA_AOI_CLOSED = '閉じ';
  KOTONOHA_AOI_FLAT = 'ーー';
  KOTONOHA_AOI_SMILE = '＾＾';
  KOTONOHA_AOI_TEAR = '涙';
  KOTONOHA_AOI_BEAR = 'クマ';
  KOTONOHA_AOI_LIGHT = '光';
  KOTONOHA_AOI_BODY = '体';
  KOTONOHA_AOI_UNIFORM = '制服';
  KOTONOHA_AOI_CASUAL_CLOTHES = '通常服';
  KOTONOHA_AOI_LEFT_ARM = '左腕';
  KOTONOHA_AOI_HAND = '手';
  KOTONOHA_AOI_RIGHT_HAND = '右手';
  KOTONOHA_AOI_LEFT_HAND = '左手';
  KOTONOHA_AOI_UPPER_SIDE = '上側';
  KOTONOHA_AOI_LOWER_SIDE = '下側';
  KOTONOHA_AOI_GUITAR = 'ギター';
  KOTONOHA_AOI_RUCKSACK = 'リュック';
  KOTONOHA_AOI_BACK_PARTS = '後ろパーツ';
  KOTONOHA_AOI_AKANE = '茜ちゃん';
  KOTONOHA_AOI_LAYER_SET_21 = 'レイヤーセット21';
  KOTONOHA_AOI_AOI = '葵ちゃん';
  KOTONOHA_AOI_HEAD_PARTS_ETC = '頭パーツとか';
  KOTONOHA_AOI_BACK_HAIR = '後ろ髪';
  KOTONOHA_AOI_EFFECT = '効果';
  KOTONOHA_AOI_BROW = '眉';

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

function IsKaraiKotonohaAoiPSD(PsdImage: TPSDImage): Boolean;
var
  AoiTree: TPsdFileTree;
  AoiChildren: TPsdFileTrees;
  HandTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
  BodyChildren: TPsdFileTrees;
  FacePartsTree: TPsdFileTree;
  UniformTree: TPsdFileTree;
  CasualTree: TPsdFileTree;
  HairBackTree: TPsdFileTree;
begin
  Result := False;
  if PsdImage = nil then Exit;

  AoiTree := FindTreeByName(PsdImage.Trees, KOTONOHA_AOI_AOI);
  if AoiTree = nil then Exit;

  if (FindTreeByName(PsdImage.Trees, KOTONOHA_AOI_BACK_PARTS) = nil) or
     (FindTreeByName(PsdImage.Trees, KOTONOHA_AOI_AKANE) = nil) then
    Exit;

  AoiChildren := TPsdFileTrees(AoiTree.Trees);
  if not HasChildTrees(AoiChildren,
    [KOTONOHA_AOI_HAND, KOTONOHA_AOI_HEAD_PARTS_ETC,
     KOTONOHA_AOI_BODY, KOTONOHA_AOI_BACK_HAIR]) then
    Exit;

  HandTree := FindChildTree(AoiChildren, KOTONOHA_AOI_HAND);
  BodyTree := FindChildTree(AoiChildren, KOTONOHA_AOI_BODY);
  HairBackTree := FindChildTree(AoiChildren, KOTONOHA_AOI_BACK_HAIR);
  if (HandTree = nil) or (BodyTree = nil) or (HairBackTree = nil) then
    Exit;

  if not HasChildTrees(TPsdFileTrees(HandTree.Trees),
    [KOTONOHA_AOI_LEFT_HAND, KOTONOHA_AOI_RIGHT_HAND]) then
    Exit;

  BodyChildren := TPsdFileTrees(BodyTree.Trees);
  if not HasChildTrees(BodyChildren,
    [KOTONOHA_AOI_FACE_PARTS, KOTONOHA_AOI_UNIFORM,
     KOTONOHA_AOI_CASUAL_CLOTHES]) then
    Exit;

  FacePartsTree := FindChildTree(BodyChildren, KOTONOHA_AOI_FACE_PARTS);
  UniformTree := FindChildTree(BodyChildren, KOTONOHA_AOI_UNIFORM);
  CasualTree := FindChildTree(BodyChildren, KOTONOHA_AOI_CASUAL_CLOTHES);
  if (FacePartsTree = nil) or (UniformTree = nil) or (CasualTree = nil) then
    Exit;

  Result :=
    HasChildTrees(TPsdFileTrees(FacePartsTree.Trees),
      [KOTONOHA_AOI_MOUTH, KOTONOHA_AOI_EFFECT,
       KOTONOHA_AOI_BROW, KOTONOHA_AOI_EYE]) and
    (FindTreeByName(TPsdFileTrees(UniformTree.Trees),
       KOTONOHA_AOI_LEFT_ARM) <> nil) and
    (ChildCount(HairBackTree) >= 5) and
    (FindTreeByName(PsdImage.Trees, KOTONOHA_AOI_RUCKSACK) <> nil);
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

procedure ReplaceMarkerOnNamedChild(Trees: TPsdFileTrees; const Name: string;
  const Marker: Char);
var
  Tree: TPsdFileTree;
begin
  Tree := FindChildTree(Trees, Name);
  if Tree <> nil then
    ReplaceMarkerOnTree(Tree, Marker);
end;

procedure RemoveMarkerFromNamedChild(Trees: TPsdFileTrees; const Name: string);
var
  Tree: TPsdFileTree;
begin
  Tree := FindChildTree(Trees, Name);
  if Tree <> nil then
    RemoveMarkerFromTree(Tree);
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

procedure HideTreeSubtree(Tree: TPsdFileTree);
var
  I: Integer;
  ChildTrees: TPsdFileTrees;
begin
  if Tree = nil then Exit;

  Tree.SetVisibleLocal(False);

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for I := 0 to ChildTrees.Count - 1 do
    HideTreeSubtree(ChildTrees[I]);
end;

procedure HideNamedTreeSubtrees(Trees: TPsdFileTrees; const Name: string);
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
      HideTreeSubtree(Tree)
    else
      HideNamedTreeSubtrees(TPsdFileTrees(Tree.Trees), Name);
  end;
end;

procedure ApplyAoiClosedEyesOtherMarkers(EyeTree: TPsdFileTree);
var
  ClosedEyesOtherTree: TPsdFileTree;
  ClosedEyesOtherChildren: TPsdFileTrees;
begin
  ClosedEyesOtherTree := FindChildTree(TPsdFileTrees(EyeTree.Trees),
    KOTONOHA_AOI_CLOSED_EYES_OTHER);
  if ClosedEyesOtherTree = nil then Exit;

  ClosedEyesOtherChildren := TPsdFileTrees(ClosedEyesOtherTree.Trees);
  ReplaceMarkerOnNamedChild(ClosedEyesOtherChildren, KOTONOHA_AOI_SPECIAL, '*');
  ReplaceMarkerOnNamedChild(ClosedEyesOtherChildren, KOTONOHA_AOI_CLOSED, '*');
  ReplaceMarkerOnNamedChild(ClosedEyesOtherChildren, KOTONOHA_AOI_FLAT, '*');
  ReplaceMarkerOnNamedChild(ClosedEyesOtherChildren, KOTONOHA_AOI_SMILE, '*');
end;

procedure ApplyAoiOpenEyeMarkers(EyeTree: TPsdFileTree);
var
  OpenEyeTree: TPsdFileTree;
  OpenEyeChildren: TPsdFileTrees;
begin
  OpenEyeTree := FindChildTree(TPsdFileTrees(EyeTree.Trees),
    KOTONOHA_AOI_OPEN_EYES);
  if OpenEyeTree = nil then Exit;

  ApplyStarMarkersToDirectChildren(OpenEyeTree);

  OpenEyeChildren := TPsdFileTrees(OpenEyeTree.Trees);
  RemoveMarkerFromNamedChild(OpenEyeChildren, KOTONOHA_AOI_TEAR);
  RemoveMarkerFromNamedChild(OpenEyeChildren, KOTONOHA_AOI_BEAR);
  RemoveMarkerFromNamedChild(OpenEyeChildren, KOTONOHA_AOI_LIGHT);
end;

procedure ApplyAoiEyeMarkers(PsdImage: TPSDImage);
var
  FacePartsTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  FacePartsTree := FindBestNamedTree(PsdImage.Trees, KOTONOHA_AOI_FACE_PARTS);
  if FacePartsTree = nil then Exit;

  EyeTree := FindChildTree(TPsdFileTrees(FacePartsTree.Trees),
    KOTONOHA_AOI_EYE);
  if EyeTree <> nil then
  begin
    ReplaceMarkerOnTree(EyeTree, '!');
    ApplyStarMarkersToDirectChildren(EyeTree);
    ApplyAoiClosedEyesOtherMarkers(EyeTree);
    ApplyAoiOpenEyeMarkers(EyeTree);
  end;

  MouthTree := FindChildTree(TPsdFileTrees(FacePartsTree.Trees),
    KOTONOHA_AOI_MOUTH);
  if MouthTree = nil then Exit;

  ReplaceMarkerOnTree(MouthTree, '!');
  ApplyStarMarkersToDirectChildren(MouthTree);
end;

procedure ApplyAoiBodyMarkers(PsdImage: TPSDImage);
var
  BodyTree: TPsdFileTree;
  BodyChildren: TPsdFileTrees;
  UniformTree: TPsdFileTree;
  UniformChildren: TPsdFileTrees;
  LeftArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  BodyTree := FindBestNamedTree(PsdImage.Trees, KOTONOHA_AOI_BODY);
  if BodyTree = nil then Exit;

  BodyChildren := TPsdFileTrees(BodyTree.Trees);
  ReplaceMarkerOnNamedChild(BodyChildren, KOTONOHA_AOI_UNIFORM, '*');
  ReplaceMarkerOnNamedChild(BodyChildren, KOTONOHA_AOI_CASUAL_CLOTHES, '*');

  UniformTree := FindChildTree(BodyChildren, KOTONOHA_AOI_UNIFORM);
  if UniformTree = nil then Exit;

  UniformChildren := TPsdFileTrees(UniformTree.Trees);
  LeftArmTree := FindChildTree(UniformChildren, KOTONOHA_AOI_LEFT_ARM);
  if LeftArmTree = nil then Exit;

  ReplaceMarkerOnTree(LeftArmTree, '!');
  ApplyStarMarkersToDirectChildren(LeftArmTree);
end;

procedure ApplyAoiHandMarkers(PsdImage: TPSDImage);
var
  HandTree: TPsdFileTree;
  LeftHandTree: TPsdFileTree;
  LeftHandChildren: TPsdFileTrees;
  RightHandTree: TPsdFileTree;
  SideTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  HandTree := FindBestNamedTree(PsdImage.Trees, KOTONOHA_AOI_HAND);
  if HandTree = nil then Exit;

  LeftHandTree := FindChildTree(TPsdFileTrees(HandTree.Trees),
    KOTONOHA_AOI_LEFT_HAND);
  if LeftHandTree <> nil then
  begin
    LeftHandChildren := TPsdFileTrees(LeftHandTree.Trees);

    SideTree := FindChildTree(LeftHandChildren, KOTONOHA_AOI_UPPER_SIDE);
    if SideTree <> nil then
    begin
      ReplaceMarkerOnTree(SideTree, '*');
      ApplyStarMarkersToDirectChildren(SideTree);
    end;

    SideTree := FindChildTree(LeftHandChildren, KOTONOHA_AOI_LOWER_SIDE);
    if SideTree <> nil then
    begin
      ReplaceMarkerOnTree(SideTree, '*');
      ApplyStarMarkersToDirectChildren(SideTree);
    end;
  end;

  RightHandTree := FindChildTree(TPsdFileTrees(HandTree.Trees),
    KOTONOHA_AOI_RIGHT_HAND);
  if RightHandTree = nil then Exit;

  ReplaceMarkerOnTree(RightHandTree, '!');
  ApplyStarMarkersToDirectChildren(RightHandTree);
end;

procedure ApplyAoiPreVirtualMarkerVisibility(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  HideNamedTreeSubtrees(PsdImage.Trees, KOTONOHA_AOI_RUCKSACK);
end;

procedure ApplyAoiBackPartsMarkers(PsdImage: TPSDImage);
var
  BackPartsTree: TPsdFileTree;
  AkaneTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  BackPartsTree := FindBestNamedTree(PsdImage.Trees, KOTONOHA_AOI_BACK_PARTS);
  if BackPartsTree = nil then Exit;

  AkaneTree := FindChildTree(TPsdFileTrees(BackPartsTree.Trees),
    KOTONOHA_AOI_AKANE);
  if AkaneTree = nil then Exit;

  ApplyStarMarkersToDirectChildren(AkaneTree);
end;

procedure ApplyAoiLayerSet21Markers(PsdImage: TPSDImage);
var
  LayerSetTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  LayerSetTree := FindBestNamedTree(PsdImage.Trees, KOTONOHA_AOI_LAYER_SET_21);
  if LayerSetTree = nil then Exit;

  ApplyStarMarkersToDirectChildren(LayerSetTree);
end;

procedure ApplyKaraiKotonohaAoiMarkers(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  ApplyAoiPreVirtualMarkerVisibility(PsdImage);
  ApplyAoiEyeMarkers(PsdImage);
  ApplyAoiBodyMarkers(PsdImage);
  ApplyAoiHandMarkers(PsdImage);
  ApplyAoiBackPartsMarkers(PsdImage);
  ApplyAoiLayerSet21Markers(PsdImage);
end;

procedure ApplyKaraiKotonohaAoiExclusiveGroups(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;
end;

procedure ApplyKaraiKotonohaAoiInitialVisibility(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  HideNamedTrees(PsdImage.Trees, KOTONOHA_AOI_GUITAR);
  HideNamedTreeSubtrees(PsdImage.Trees, KOTONOHA_AOI_RUCKSACK);
end;

procedure ApplyKaraiKotonohaAoiElementList(PsdImage: TPSDImage;
  Elements: TPSDElementList);
begin
  if (PsdImage = nil) or (Elements = nil) then Exit;
end;

end.
