unit PSDImageCustomAjishio;

interface

uses
  PsdImage;

function IsAjishioPSD(PsdImage: TPSDImage): Boolean;
procedure ApplyAjishioMarkers(PsdImage: TPSDImage);
procedure ApplyAjishioExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyAjishioInitialVisibility(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

function HasText(const S, Token: string): Boolean;
begin
  Result := Pos(LowerCase(Token), LowerCase(S)) > 0;
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

function CountChildTreesWithText(Trees: TPsdFileTrees;
  const Token: string): Integer;
var
  I: Integer;
  Tree: TPsdFileTree;
begin
  Result := 0;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    if HasText(TreeName(Tree), Token) then
      Inc(Result);
  end;
end;

function HasAjishioRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  BrowTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
  LeftParkerArmTree: TPsdFileTree;
  RightParkerArmTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    ['漫符', '特殊', '眉毛', '口', '目',
     '服腕重なり部分', '左腕パーカー', '右腕パーカー',
     'パーカー', '左腕', '右腕', '衣装', '裸']) then
    Exit;

  BrowTree := FindChildTree(RootChildren, '眉毛');
  EyeTree := FindChildTree(RootChildren, '目');
  MouthTree := FindChildTree(RootChildren, '口');
  LeftParkerArmTree := FindChildTree(RootChildren, '左腕パーカー');
  RightParkerArmTree := FindChildTree(RootChildren, '右腕パーカー');

  Result :=
    HasChildTrees(TPsdFileTrees(BrowTree.Trees),
      ['まゆ通常', '上がりまゆ', 'ちょいつり']) and
    HasChildTrees(TPsdFileTrees(EyeTree.Trees),
      ['基本目目線１', '目綺麗系', '閉じ目']) and
    HasChildTrees(TPsdFileTrees(MouthTree.Trees),
      ['喜び', '基本口開く', 'あ口閉じる(3)']) and
    (CountChildTreesWithText(TPsdFileTrees(LeftParkerArmTree.Trees), '腕') >= 10) and
    (CountChildTreesWithText(TPsdFileTrees(RightParkerArmTree.Trees), '腕') >= 10);
end;

function HasAjishioRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasAjishioRootStructure(Tree) then
      Exit(True);

    if HasAjishioRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function IsAjishioPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasAjishioRoot(PsdImage.Trees);
end;

procedure MarkAjishioCostumeBaseAsInitialDress(Trees: TPsdFileTrees);
var
  i: Integer;
  Tree: TPsdFileTree;
  CostumeTree: TPsdFileTree;
  CostumeChildren: TPsdFileTrees;
  BaseTree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;
    if SameText(TreeName(Tree), '衣装') then
      CostumeTree := Tree
    else
      CostumeTree := FindChildTree(TPsdFileTrees(Tree.Trees), '衣装');

    if CostumeTree <> nil then
    begin
      CostumeChildren := TPsdFileTrees(CostumeTree.Trees);
      BaseTree := FindChildTree(CostumeChildren, '基本服');
      if BaseTree = nil then
        BaseTree := FindChildTree(CostumeChildren, '服基本');
      if (BaseTree <> nil) and BaseTree.Visible then
      begin
        // PSD 初期状態の基本服は表示を維持し、Face で同層の服を
        // 選んだ時だけ退避する初期服として記録する。
        ReplaceMarkerOnTree(BaseTree, '-');
      end;
    end;

    MarkAjishioCostumeBaseAsInitialDress(TPsdFileTrees(Tree.Trees));
  end;
end;
procedure MoveAjishioTreeToSpecial(PsdImage: TPSDImage; const Name: string);
var
  TreeToMove: TPsdFileTree;
  SpecialTree: TPsdFileTree;
  SpecialChildren: TPsdFileTrees;
begin
  if PsdImage = nil then Exit;

  TreeToMove := FindBestNamedTree(PsdImage.Trees, Name);
  if TreeToMove = nil then Exit;

  SpecialTree := FindBestNamedTree(PsdImage.Trees, '特殊');
  if SpecialTree = nil then Exit;

  SpecialChildren := TPsdFileTrees(SpecialTree.Trees);
  if SpecialChildren = nil then Exit;

  PsdImage.MoveTree(TreeToMove, SpecialChildren);
end;

procedure RelinkAjishioSpecialTrees(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  MoveAjishioTreeToSpecial(PsdImage, '真っ赤');
  MoveAjishioTreeToSpecial(PsdImage, '青ざめ');
end;
procedure PrepareAjishioParkerRoot(PsdImage: TPSDImage);
var
  ParkerTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  ParkerTree := FindBestNamedTree(PsdImage.Trees, 'パーカー');
  if ParkerTree <> nil then
    ReplaceMarkerOnTree(ParkerTree, '!');
end;

procedure NormalizeAjishioParkerChildren(PsdImage: TPSDImage);
var
  ParkerTree: TPsdFileTree;
  ParkerChildren: TPsdFileTrees;
  ParkerChildTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  ParkerTree := FindBestNamedTree(PsdImage.Trees, 'パーカー');
  if ParkerTree = nil then Exit;

  ParkerChildren := TPsdFileTrees(ParkerTree.Trees);
  ParkerChildTree := FindChildTree(ParkerChildren, 'パーカー');

  if ParkerChildTree <> nil then
    ParkerChildTree.SetVisibleLocal(False);
end;

procedure AddAjishioHideTreeActions(PsdImage: TPSDImage;
  TriggerTree, TargetTree: TPsdFileTree);
var
  i: Integer;
  TargetChildren: TPsdFileTrees;
begin
  if (PsdImage = nil) or (TriggerTree = nil) or (TargetTree = nil) then Exit;

  PsdImage.AddVisibilityRule(TriggerTree, TargetTree, False);
  TargetChildren := TPsdFileTrees(TargetTree.Trees);
  for i := 0 to TargetChildren.Count - 1 do
    AddAjishioHideTreeActions(PsdImage, TriggerTree, TargetChildren[i]);
end;

procedure AddAjishioArmParkerRuleBranch(PsdImage: TPSDImage;
  TriggerTree, TargetTree: TPsdFileTree);
var
  i: Integer;
  TriggerChildren: TPsdFileTrees;
begin
  if (PsdImage = nil) or (TriggerTree = nil) or (TargetTree = nil) then Exit;

  AddAjishioHideTreeActions(PsdImage, TriggerTree, TargetTree);
  TriggerChildren := TPsdFileTrees(TriggerTree.Trees);
  for i := 0 to TriggerChildren.Count - 1 do
    AddAjishioArmParkerRuleBranch(PsdImage, TriggerChildren[i], TargetTree);
end;

procedure AddAjishioArmParkerRule(PsdImage: TPSDImage; const ArmName,
  ParkerName: string);
var
  ArmTree: TPsdFileTree;
  ParkerTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  ArmTree := FindBestNamedTree(PsdImage.Trees, ArmName);
  ParkerTree := FindBestNamedTree(PsdImage.Trees, ParkerName);
  if (ArmTree = nil) or (ParkerTree = nil) then Exit;

  AddAjishioArmParkerRuleBranch(PsdImage, ArmTree, ParkerTree);
  AddAjishioArmParkerRuleBranch(PsdImage, ParkerTree, ArmTree);
end;

procedure ApplyAjishioMarkers(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  RelinkAjishioSpecialTrees(PsdImage);
  PrepareAjishioParkerRoot(PsdImage);
  MarkAjishioCostumeBaseAsInitialDress(PsdImage.Trees);
end;

procedure ApplyAjishioExclusiveGroups(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  AddAjishioArmParkerRule(PsdImage, '左腕', '左腕パーカー');
  AddAjishioArmParkerRule(PsdImage, '右腕', '右腕パーカー');
end;

procedure ApplyAjishioInitialVisibility(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  MarkAjishioCostumeBaseAsInitialDress(PsdImage.Trees);
  NormalizeAjishioParkerChildren(PsdImage);
end;

end.
