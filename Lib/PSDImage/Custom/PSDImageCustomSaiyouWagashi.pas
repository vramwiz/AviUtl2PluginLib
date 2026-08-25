unit PSDImageCustomSaiyouWagashi;

interface

uses
  PsdImage;

function IsSaiyouWagashiTsukuyomiPSD(PsdImage: TPSDImage): Boolean;
procedure ApplySaiyouWagashiTsukuyomiMarkers(PsdImage: TPSDImage);
procedure ApplySaiyouWagashiTsukuyomiInitialVisibility(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

const
  LAYER_TSUKUYOMI = #$3064#$304F#$3088#$307F#$3061#$3083#$3093;
  LAYER_HAIR_ACCESSORY = #$9AEA#$98FE#$308A;
  LAYER_HAIR_1 = #$9AEA#$FF11;
  LAYER_HAIR_2 = #$9AEA#$FF12;
  LAYER_HAIR_3 = #$9AEA#$FF13;
  LAYER_ARM = #$8155;
  LAYER_FRONT_HAIR = #$524D#$9AEA;
  LAYER_FACE = #$8868#$60C5;
  LAYER_BODY = #$8EAB#$4F53;
  LAYER_CHEEK = #$982C;
  LAYER_BROW = #$307E#$3086;
  LAYER_EYE = #$76EE;
  LAYER_MOUTH = #$304F#$3061;
  LAYER_WHITE = #$767D;
  LAYER_BLACK = #$9ED2;
  LAYER_EYELASH = #$307E#$3064#$3052;
  LAYER_EYEBALL = #$773C#$7403;
  LAYER_SCLERA = #$767D#$76EE;

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

function HasSaiyouWagashiTsukuyomiStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  FaceTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;
  if not SameText(TreeName(Tree), LAYER_TSUKUYOMI) then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    [LAYER_HAIR_ACCESSORY, LAYER_HAIR_1, LAYER_ARM, LAYER_FRONT_HAIR,
     LAYER_FACE, LAYER_BODY, LAYER_HAIR_2, LAYER_HAIR_3]) then
    Exit;

  FaceTree := FindChildTree(RootChildren, LAYER_FACE);
  ArmTree := FindChildTree(RootChildren, LAYER_ARM);
  BodyTree := FindChildTree(RootChildren, LAYER_BODY);
  if (FaceTree = nil) or (ArmTree = nil) or (BodyTree = nil) then Exit;

  EyeTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), LAYER_EYE);
  if EyeTree = nil then Exit;

  Result :=
    HasChildTrees(TPsdFileTrees(FaceTree.Trees),
      [LAYER_CHEEK, LAYER_BROW, LAYER_EYE, LAYER_MOUTH]) and
    HasChildTrees(TPsdFileTrees(ArmTree.Trees), [LAYER_WHITE, LAYER_BLACK]) and
    HasChildTrees(TPsdFileTrees(BodyTree.Trees), [LAYER_WHITE, LAYER_BLACK]) and
    HasChildTrees(TPsdFileTrees(EyeTree.Trees),
      ['00', '01', '02', '03', '04', '05', '06', '07', '08',
       '09', '10', '11', '12', '13', '14']);
end;

function HasSaiyouWagashiTsukuyomiRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasSaiyouWagashiTsukuyomiStructure(Tree) then
      Exit(True);

    if HasSaiyouWagashiTsukuyomiRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function FindSaiyouWagashiTsukuyomiRoot(Trees: TPsdFileTrees): TPsdFileTree;
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

    if HasSaiyouWagashiTsukuyomiStructure(Tree) then
      Exit(Tree);

    Result := FindSaiyouWagashiTsukuyomiRoot(TPsdFileTrees(Tree.Trees));
    if Result <> nil then
      Exit;
  end;
end;

function IsSaiyouWagashiTsukuyomiPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasSaiyouWagashiTsukuyomiRoot(PsdImage.Trees);
end;

procedure MarkDirectChildren(Tree: TPsdFileTree; const Marker: Char);
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

    ReplaceMarkerOnTree(ChildTree, Marker);
  end;
end;

procedure MarkTreeAndDirectChildren(Tree: TPsdFileTree; const TreeMarker,
  ChildMarker: Char);
begin
  if Tree = nil then Exit;

  ReplaceMarkerOnTree(Tree, TreeMarker);
  MarkDirectChildren(Tree, ChildMarker);
end;

procedure MarkSaiyouWagashiTsukuyomiEye00Children(EyePartTree: TPsdFileTree);
var
  EyePartChildren: TPsdFileTrees;
  EyelashTree: TPsdFileTree;
  EyeballTree: TPsdFileTree;
  ScleraTree: TPsdFileTree;
begin
  if EyePartTree = nil then Exit;
  if not SameText(TreeName(EyePartTree), '00') then Exit;

  EyePartChildren := TPsdFileTrees(EyePartTree.Trees);
  if EyePartChildren = nil then Exit;

  EyelashTree := FindChildTree(EyePartChildren, LAYER_EYELASH);
  if EyelashTree <> nil then
    ReplaceMarkerOnTree(EyelashTree, '!');

  EyeballTree := FindChildTree(EyePartChildren, LAYER_EYEBALL);
  if EyeballTree <> nil then
  begin
    ReplaceMarkerOnTree(EyeballTree, '!');
    MarkDirectChildren(EyeballTree, '*');
  end;

  ScleraTree := FindChildTree(EyePartChildren, LAYER_SCLERA);
  if ScleraTree <> nil then
  begin
    ReplaceMarkerOnTree(ScleraTree, '!');
    MarkDirectChildren(ScleraTree, '*');
  end;
end;

procedure MarkSaiyouWagashiTsukuyomiBody(PsdImage: TPSDImage;
  RootTree: TPsdFileTree);
var
  BodyTree: TPsdFileTree;
  BodyChildren: TPsdFileTrees;
  I: Integer;
  BodyPartTree: TPsdFileTree;
begin
  if (PsdImage = nil) or (RootTree = nil) then Exit;

  BodyTree := FindChildTree(TPsdFileTrees(RootTree.Trees), LAYER_BODY);
  if BodyTree = nil then Exit;

  BodyChildren := TPsdFileTrees(BodyTree.Trees);
  if BodyChildren = nil then Exit;

  for I := 0 to BodyChildren.Count - 1 do
  begin
    BodyPartTree := BodyChildren[I];
    if BodyPartTree = nil then Continue;

    if SameText(TreeName(BodyPartTree), LAYER_WHITE) or
       SameText(TreeName(BodyPartTree), LAYER_BLACK) then
    begin
      ReplaceMarkerOnTree(BodyPartTree, '*');
      MarkDirectChildren(BodyPartTree, '*');
    end;
  end;
end;

procedure HideSaiyouWagashiTsukuyomiHairAccessoryWhite(RootTree: TPsdFileTree);
var
  HairAccessoryTree: TPsdFileTree;
  WhiteTree: TPsdFileTree;
begin
  if RootTree = nil then Exit;

  HairAccessoryTree := FindChildTree(TPsdFileTrees(RootTree.Trees),
    LAYER_HAIR_ACCESSORY);
  if HairAccessoryTree = nil then Exit;

  WhiteTree := FindChildTree(TPsdFileTrees(HairAccessoryTree.Trees),
    LAYER_WHITE);
  if WhiteTree <> nil then
    WhiteTree.SetVisibleLocal(False);
end;

procedure ApplySaiyouWagashiTsukuyomiInitialVisibility(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindSaiyouWagashiTsukuyomiRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  HideSaiyouWagashiTsukuyomiHairAccessoryWhite(RootTree);
end;

procedure ApplySaiyouWagashiTsukuyomiMarkers(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  FaceTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  BrowTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
  EyeChildren: TPsdFileTrees;
  EyePartChildren: TPsdFileTrees;
  I: Integer;
  J: Integer;
  EyePartTree: TPsdFileTree;
  EyePartChildTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindSaiyouWagashiTsukuyomiRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  HideSaiyouWagashiTsukuyomiHairAccessoryWhite(RootTree);

  FaceTree := FindChildTree(TPsdFileTrees(RootTree.Trees), LAYER_FACE);
  if FaceTree = nil then Exit;

  BrowTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), LAYER_BROW);
  MarkTreeAndDirectChildren(BrowTree, '!', '*');

  MouthTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), LAYER_MOUTH);
  MarkTreeAndDirectChildren(MouthTree, '!', '*');

  MarkTreeAndDirectChildren(
    FindChildTree(TPsdFileTrees(RootTree.Trees), LAYER_FRONT_HAIR), '!', '*');
  MarkTreeAndDirectChildren(
    FindChildTree(TPsdFileTrees(RootTree.Trees), LAYER_HAIR_1), '!', '*');
  MarkTreeAndDirectChildren(
    FindChildTree(TPsdFileTrees(RootTree.Trees), LAYER_HAIR_2), '!', '*');
  MarkTreeAndDirectChildren(
    FindChildTree(TPsdFileTrees(RootTree.Trees), LAYER_HAIR_3), '!', '*');

  EyeTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), LAYER_EYE);
  if EyeTree = nil then Exit;

  ReplaceMarkerOnTree(EyeTree, '!');

  EyeChildren := TPsdFileTrees(EyeTree.Trees);
  if EyeChildren = nil then Exit;

  for I := 0 to EyeChildren.Count - 1 do
  begin
    EyePartTree := EyeChildren[I];
    if EyePartTree = nil then Continue;

    ReplaceMarkerOnTree(EyePartTree, '*');
    MarkSaiyouWagashiTsukuyomiEye00Children(EyePartTree);

    EyePartChildren := TPsdFileTrees(EyePartTree.Trees);
    if EyePartChildren = nil then Continue;

    for J := 0 to EyePartChildren.Count - 1 do
    begin
      EyePartChildTree := EyePartChildren[J];
      if EyePartChildTree = nil then Continue;

      if SameText(TreeName(EyePartChildTree), LAYER_WHITE) or
         SameText(TreeName(EyePartChildTree), LAYER_BLACK) then
        ReplaceMarkerOnTree(EyePartChildTree, '*');
    end;
  end;

  MarkSaiyouWagashiTsukuyomiBody(PsdImage, RootTree);
end;

end.
