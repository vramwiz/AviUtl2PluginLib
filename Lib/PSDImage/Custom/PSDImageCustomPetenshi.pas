unit PSDImageCustomPetenshi;

interface

uses
  PsdImage;

function IsPetenshiFileName(const FileName: string): Boolean;
procedure ApplyPetenshiMarkers(PsdImage: TPSDImage);
procedure ApplyPetenshiExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyPetenshiInitialVisibility(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, System.StrUtils, PsdImageTree,
  PSDImageCustomMarkerUtils;

const
  PETENSHI_POSE_1 = 'ポーズ１';
  PETENSHI_POSE_2 = 'ポーズ２';
  PETENSHI_POSE_3 = 'ポーズ３';
  PETENSHI_POSE_4 = 'ポーズ４';
  PETENSHI_POSE_5 = 'ポーズ５';

  PETENSHI_TOKEN_MOMIAGE = 'もみあげ';
  PETENSHI_NAME_FUTSUU_SHITAGI = '普通下着';
  PETENSHI_TOKEN_KIHON = '基本';
  PETENSHI_NAME_PARKER_WITH_RING = 'パーカー（腰リングつき）';
  PETENSHI_NAME_PARKER_WITH_RING_SHORT = 'パーカー（リングつき）';
  PETENSHI_NAME_EXPRESSION = '表情';
  PETENSHI_NAME_SPECIAL_PARTS = '特殊パーツ';
  PETENSHI_NAME_SHADOW_1 = '影１';
  PETENSHI_NAME_CHILL = '悪寒';

procedure DebugOut(const S: string);
begin
end;

function IsPetenshiFileName(const FileName: string): Boolean;
var
  Name: string;
begin
  Name := ChangeFileExt(ExtractFileName(FileName), '');
  Result := SameText(Copy(Name, 1, Length('petenshi_')), 'petenshi_');
end;

procedure PreparePetenshiExpressionTree(PsdImage: TPSDImage);
var
  ExpressionTree: TPsdFileTree;
  SpecialPartsTree: TPsdFileTree;
  ExpressionChildren: TPsdFileTrees;
  SpecialChildren: TPsdFileTrees;
  ChildTree: TPsdFileTree;
  i: Integer;
  Name: string;
begin
  if PsdImage = nil then Exit;

  ExpressionTree := FindBestNamedTree(PsdImage.Trees, PETENSHI_NAME_EXPRESSION);
  SpecialPartsTree := FindBestNamedTree(PsdImage.Trees, PETENSHI_NAME_SPECIAL_PARTS);
  if (ExpressionTree = nil) or (SpecialPartsTree = nil) then Exit;

  ExpressionChildren := TPsdFileTrees(ExpressionTree.Trees);
  SpecialChildren := TPsdFileTrees(SpecialPartsTree.Trees);
  if (ExpressionChildren = nil) or (SpecialChildren = nil) then Exit;

  for i := ExpressionChildren.Count - 1 downto 0 do
  begin
    ChildTree := ExpressionChildren[i];
    if ChildTree = nil then Continue;

    Name := TreeName(ChildTree);
    if SameText(Name, PETENSHI_NAME_SHADOW_1) or
      SameText(Name, PETENSHI_NAME_CHILL) then
    begin
      if PsdImage.MoveTree(ChildTree, SpecialChildren) then
        DebugOut(Format('Move -> %s / %s', [PETENSHI_NAME_SPECIAL_PARTS, Name]));
      Continue;
    end;

    ReplaceMarkerOnTree(ChildTree, '*');
    DebugOut(Format('Marker * -> %s / %s', [PETENSHI_NAME_EXPRESSION, Name]));
  end;
end;

procedure ApplyMarkerToNamedTrees(Trees: TPsdFileTrees;
  const Names: array of string; const Marker: Char);
var
  i: Integer;
  j: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    for j := Low(Names) to High(Names) do
      if SameText(TreeName(Tree), Names[j]) then
      begin
        ReplaceMarkerOnTree(Tree, Marker);
        Break;
      end;

    ApplyMarkerToNamedTrees(TPsdFileTrees(Tree.Trees), Names, Marker);
  end;
end;

function FindPetenshiPoseTree(Trees: TPsdFileTrees;
  const PoseName: string): TPsdFileTree;
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  Result := nil;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    if SameText(TreeName(Tree), PoseName) then
      Exit(Tree);

    Result := FindPetenshiPoseTree(TPsdFileTrees(Tree.Trees), PoseName);
    if Result <> nil then Exit;
  end;
end;

procedure ApplyPetenshiPoseChildMarkers(PoseTree: TPsdFileTree);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
  Name: string;
begin
  if PoseTree = nil then Exit;

  ChildTrees := TPsdFileTrees(PoseTree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[i];
    if ChildTree = nil then Continue;

    Name := TreeName(ChildTree);
    if Pos(PETENSHI_TOKEN_MOMIAGE, Name) > 0 then
    begin
      ReplaceMarkerOnTree(ChildTree, '!');
      DebugOut(Format('Marker ! -> %s / %s', [TreeName(PoseTree), Name]));
    end
    else if SameText(Name, PETENSHI_NAME_FUTSUU_SHITAGI) then
    begin
      ReplaceMarkerOnTree(ChildTree, '!');
      DebugOut(Format('Marker ! -> %s / %s', [TreeName(PoseTree), Name]));
    end;
  end;
end;

procedure ApplyPetenshiPoseInitialVisibility(PoseTree: TPsdFileTree);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
  Name: string;
begin
  if PoseTree = nil then Exit;

  ChildTrees := TPsdFileTrees(PoseTree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[i];
    if ChildTree = nil then Continue;

    Name := TreeName(ChildTree);
    if StartsText(PETENSHI_TOKEN_KIHON, Name) then
    begin
      ChildTree.SetVisibleLocal(False);
      DebugOut(Format('Hide -> %s / %s', [TreeName(PoseTree), Name]));
    end
    else if SameText(Name, PETENSHI_NAME_PARKER_WITH_RING) or
      SameText(Name, PETENSHI_NAME_PARKER_WITH_RING_SHORT) then
    begin
      ChildTree.SetVisibleLocal(False);
      DebugOut(Format('Hide -> %s / %s', [TreeName(PoseTree), Name]));
    end
    else if SameText(Name, PETENSHI_NAME_FUTSUU_SHITAGI) then
    begin
      ChildTree.SetVisibleLocal(True);
      DebugOut(Format('Show -> %s / %s', [TreeName(PoseTree), Name]));
    end;
  end;
end;

procedure ApplyPetenshiPoseRules(PsdImage: TPSDImage);
const
  POSE_NAMES: array[0..4] of string = (
    PETENSHI_POSE_1, PETENSHI_POSE_2, PETENSHI_POSE_3,
    PETENSHI_POSE_4, PETENSHI_POSE_5
  );
var
  i: Integer;
  PoseTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  for i := Low(POSE_NAMES) to High(POSE_NAMES) do
  begin
    PoseTree := FindPetenshiPoseTree(PsdImage.Trees, POSE_NAMES[i]);
    if PoseTree = nil then Continue;

    ApplyPetenshiPoseChildMarkers(PoseTree);
    ApplyPetenshiPoseInitialVisibility(PoseTree);
  end;
end;

procedure ApplyPetenshiMarkers(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  DebugOut('ApplyPetenshiMarkers');
  PreparePetenshiExpressionTree(PsdImage);
  ApplyPetenshiPoseRules(PsdImage);
  ApplyMarkerToNamedTrees(PsdImage.Trees,
    [PETENSHI_POSE_1, PETENSHI_POSE_2, PETENSHI_POSE_3,
     PETENSHI_POSE_4, PETENSHI_POSE_5], '*');
end;

procedure ApplyPetenshiExclusiveGroups(PsdImage: TPSDImage);
begin
end;

procedure ApplyPetenshiInitialVisibility(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  DebugOut('ApplyPetenshiInitialVisibility');
  ApplyPetenshiPoseRules(PsdImage);
end;

end.
