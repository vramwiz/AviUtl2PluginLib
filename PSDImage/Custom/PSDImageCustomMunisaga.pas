unit PSDImageCustomMunisaga;

interface

uses
  PsdImage;

function IsMunisagaPSD(PsdImage: TPSDImage): Boolean;
procedure ApplyMunisagaMarkers(PsdImage: TPSDImage);
procedure ApplyMunisagaInitialVisibility(PsdImage: TPSDImage);

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

function HasMunisagaFaceStructure(
  FaceChildren: TPsdFileTrees): Boolean;
var
  BrowTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
  ColorTree: TPsdFileTree;
begin
  Result := False;
  if not HasChildTrees(FaceChildren, ['鼻', '眉', '口', '目', '紅']) then
    Exit;

  BrowTree := FindChildTree(FaceChildren, '眉');
  EyeTree := FindChildTree(FaceChildren, '目');
  MouthTree := FindChildTree(FaceChildren, '口');
  ColorTree := FindChildTree(FaceChildren, '紅');

  Result :=
    HasChildTrees(TPsdFileTrees(BrowTree.Trees),
      ['疑問（強）', '疑問（弱）', 'しかめ', 'ツン4', '高め下向き']) and
    HasChildTrees(TPsdFileTrees(MouthTree.Trees),
      ['むにむに', 'ぞくぞく', 'あわあわ', 'にへら',
       'おっしゃー', 'うひょー', 'ドヤ口', '猫口2',
       'ニッッッッコリ', '喋る2']) and
    HasChildTrees(TPsdFileTrees(ColorTree.Trees),
      ['ちょぼ', '大', '中', '小', 'いつもの']) and
    (CountChildTreesWithText(TPsdFileTrees(EyeTree.Trees), '◆') >= 8);
end;

function HasMunisagaPoseStructure(
  PoseChildren: TPsdFileTrees): Boolean;
begin
  Result :=
    HasChildTrees(PoseChildren,
      ['箸（コラにでも）', 'ずんだ箸', 'ナイフとフォーク(コラにでも)',
       '腰に手', '頬に手', 'パー', 'グッド', 'ピース',
       'ガッツポーズ', '手組み', '照れ', '腕揚げ',
       '腕組', 'ふふん', '手を口に', '包丁以外（コラにでも）',
       '包丁（血)', '包丁', '通常']);
end;

function HasMunisagaBodyStructure(
  BodyChildren: TPsdFileTrees): Boolean;
begin
  Result :=
    HasChildTrees(BodyChildren,
      ['アホ毛', '前髪・左もみあげ', '包丁(右)', '包丁(左)',
       '左ツインテ', '服上', '服下']);
end;

function HasMunisagaRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  PoseTree: TPsdFileTree;
  FaceTree: TPsdFileTree;
  Body2Tree: TPsdFileTree;
  BodyTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;
  if not SameText(TreeName(Tree), 'v1') then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren, ['ポーズ', '顔', '素体2', '素体']) then
    Exit;

  PoseTree := FindChildTree(RootChildren, 'ポーズ');
  FaceTree := FindChildTree(RootChildren, '顔');
  Body2Tree := FindChildTree(RootChildren, '素体2');
  BodyTree := FindChildTree(RootChildren, '素体');

  Result :=
    HasMunisagaPoseStructure(TPsdFileTrees(PoseTree.Trees)) and
    HasMunisagaFaceStructure(TPsdFileTrees(FaceTree.Trees)) and
    HasMunisagaBodyStructure(TPsdFileTrees(Body2Tree.Trees)) and
    HasChildTrees(TPsdFileTrees(BodyTree.Trees),
      ['体', '右もみあげ', '右ツインテ', 'リボン',
       'リボン右', 'リボン左', 'きりたん砲（左）',
       'ランドセル', 'きりたん砲（右）']);
end;

function HasMunisagaRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasMunisagaRootStructure(Tree) then
      Exit(True);

    if HasMunisagaRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function IsMunisagaPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasMunisagaRoot(PsdImage.Trees);
end;

procedure ApplyMarkerToChildren(Trees: TPsdFileTrees; const Marker: Char);
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    ReplaceMarkerOnTree(Tree, Marker);
  end;
end;

procedure ApplyMarkerToDescendantLeaves(Tree: TPsdFileTree; const Marker: Char);
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

    if IsLeafTree(ChildTree) then
      ReplaceMarkerOnTree(ChildTree, Marker)
    else
      ApplyMarkerToDescendantLeaves(ChildTree, Marker);
  end;
end;

function FindChildTreeByPlainName(Trees: TPsdFileTrees;
  const Name: string): TPsdFileTree;
var
  i: Integer;
  Tree: TPsdFileTree;
  S: string;
begin
  Result := nil;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    S := TreeName(Tree);
    if (S <> '') and (S[1] = '◆') then
      Delete(S, 1, 1);

    if SameText(S, Name) then
      Exit(Tree);
  end;
end;

procedure SetDescendantVisibleLocal(Tree: TPsdFileTree; Visible: Boolean);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
begin
  if Tree = nil then Exit;

  Tree.SetVisibleLocal(Visible);
  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
    SetDescendantVisibleLocal(ChildTrees[i], Visible);
end;

procedure ApplyMunisagaMarkers(PsdImage: TPSDImage);
var
  FaceTree: TPsdFileTree;
  PoseTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
  BrowTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  PoseTree := FindBestNamedTree(PsdImage.Trees, 'ポーズ');
  if PoseTree <> nil then
  begin
    ReplaceMarkerOnTree(PoseTree, '!');
    ApplyMarkerToChildren(TPsdFileTrees(PoseTree.Trees), '*');
  end;

  FaceTree := FindBestNamedTree(PsdImage.Trees, '顔');
  if FaceTree = nil then Exit;

  EyeTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), '目');
  if EyeTree = nil then Exit;

  ReplaceMarkerOnTree(EyeTree, '!');
  ApplyMarkerToChildren(TPsdFileTrees(EyeTree.Trees), '*');
  ApplyMarkerToDescendantLeaves(EyeTree, '*');

  MouthTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), '口');
  if MouthTree <> nil then
  begin
    ReplaceMarkerOnTree(MouthTree, '!');
    ApplyMarkerToChildren(TPsdFileTrees(MouthTree.Trees), '*');
  end;

  BrowTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), '眉');
  if BrowTree <> nil then
  begin
    ReplaceMarkerOnTree(BrowTree, '!');
    ApplyMarkerToChildren(TPsdFileTrees(BrowTree.Trees), '*');
  end;
end;

procedure ApplyMunisagaInitialVisibility(PsdImage: TPSDImage);
var
  FaceTree: TPsdFileTree;
  SweatTree: TPsdFileTree;
  SweatLayerTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  NormalTree: TPsdFileTree;
  Normal1Tree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  FaceTree := FindBestNamedTree(PsdImage.Trees, '顔');
  if FaceTree = nil then Exit;

  SweatTree := FindChildTreeByPlainName(TPsdFileTrees(FaceTree.Trees), '汗');
  if SweatTree <> nil then
  begin
    SweatLayerTree := FindChildTree(TPsdFileTrees(SweatTree.Trees), '汗');
    if SweatLayerTree <> nil then
      SweatLayerTree.SetVisibleLocal(False);
  end;

  EyeTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), '目');
  if EyeTree = nil then Exit;

  NormalTree := FindChildTreeByPlainName(TPsdFileTrees(EyeTree.Trees), '通常');
  if NormalTree = nil then Exit;

  Normal1Tree := FindChildTree(TPsdFileTrees(NormalTree.Trees), '通常1');
  if Normal1Tree = nil then Exit;

  SetDescendantVisibleLocal(EyeTree, False);
  EyeTree.SetVisibleLocal(True);
  NormalTree.SetVisibleLocal(True);
  Normal1Tree.SetVisibleLocal(True);
end;

end.
