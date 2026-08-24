unit PSDImageCustomKamiyoshi;

interface

uses
  PsdImage;

// 制作者ごとの独自処理ユニットは PSDImage\Custom 直下に配置する。
// PSDImage\Custom\Lib 配下は、種別ごとの処理を呼び分ける共通ハブ用とする。

function HasKamiyoshiStructure(PsdImage: TPSDImage): Boolean;
function HasKamiyoshiShikokuMetanStructure(PsdImage: TPSDImage): Boolean;
function HasKamiyoshiNo7Structure(PsdImage: TPSDImage): Boolean;
procedure ApplyKamiyoshiExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyKamiyoshiInitialVisibility(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

function HasText(const S, Token: string): Boolean;
begin
  Result := Pos(LowerCase(Token), LowerCase(S)) > 0;
end;

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

function HasKamiyoshiArmSide(
  ArmChildren: TPsdFileTrees; const SideName, NamePrefix: string): Boolean;
var
  SideTree: TPsdFileTree;
  SideChildren: TPsdFileTrees;
begin
  Result := False;

  SideTree := FindChildTree(ArmChildren, SideName);
  if SideTree = nil then Exit;

  SideChildren := TPsdFileTrees(SideTree.Trees);
  Result :=
    (CountChildTrees(SideChildren) >= 20) and
    (CountChildTreesWithText(SideChildren, NamePrefix + 'ジャンケン') >= 3) and
    (CountChildTreesWithText(SideChildren, NamePrefix + '_小物_') >= 3) and
    (CountChildTreesWithText(SideChildren, NamePrefix + '_料理_') >= 3) and
    (CountChildTreesWithText(SideChildren, NamePrefix + '_武器_') >= 3);
end;

function HasKamiyoshiNo7ArmSide(
  ArmChildren: TPsdFileTrees; const SideName, NamePrefix: string): Boolean;
var
  SideTree: TPsdFileTree;
  SideChildren: TPsdFileTrees;
begin
  Result := False;

  SideTree := FindChildTree(ArmChildren, SideName);
  if SideTree = nil then Exit;

  SideChildren := TPsdFileTrees(SideTree.Trees);
  Result :=
    (CountChildTrees(SideChildren) >= 35) and
    (CountChildTreesWithText(SideChildren, NamePrefix + '伸ばし') >= 2) and
    (CountChildTreesWithText(SideChildren, NamePrefix + '曲げ') >= 3) and
    (CountChildTreesWithText(SideChildren, NamePrefix + '_小物_') >= 10);
end;

function HasKamiyoshiShikokuMetanArmSide(
  ArmChildren: TPsdFileTrees; const SideName, NamePrefix: string): Boolean;
var
  SideTree: TPsdFileTree;
  SideChildren: TPsdFileTrees;
begin
  Result := False;

  SideTree := FindChildTree(ArmChildren, SideName);
  if SideTree = nil then Exit;

  SideChildren := TPsdFileTrees(SideTree.Trees);
  Result :=
    (CountChildTrees(SideChildren) >= 20) and
    (CountChildTreesWithText(SideChildren, NamePrefix + 'ジャンケン') >= 3) and
    (CountChildTreesWithText(SideChildren, NamePrefix + '_小物_') >= 3) and
    (CountChildTreesWithText(SideChildren, NamePrefix + '_料理_') >= 3) and
    (CountChildTreesWithText(SideChildren, NamePrefix + '_武器_') >= 3);
end;

function HasKamiyoshiRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  ItemTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
  ArmChildren: TPsdFileTrees;
  BothArmTree: TPsdFileTree;
  FaceTree: TPsdFileTree;
  FaceChildren: TPsdFileTrees;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
  FaceColorTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    ['アイテム', '腕', '顔', '前髪', '顔色', '服', '後ろ', '背景']) then
    Exit;

  ItemTree := FindChildTree(RootChildren, 'アイテム');
  ArmTree := FindChildTree(RootChildren, '腕');
  FaceTree := FindChildTree(RootChildren, '顔');
  FaceColorTree := FindChildTree(RootChildren, '顔色');

  ArmChildren := TPsdFileTrees(ArmTree.Trees);
  BothArmTree := FindChildTree(ArmChildren, '両腕');
  if BothArmTree = nil then
    Exit;

  if not ((CountChildTrees(TPsdFileTrees(ItemTree.Trees)) >= 30) and
          (CountChildTrees(TPsdFileTrees(BothArmTree.Trees)) >= 10) and
          HasKamiyoshiArmSide(ArmChildren, '左腕', '左') and
          HasKamiyoshiArmSide(ArmChildren, '右腕', '右')) then
    Exit;

  FaceChildren := TPsdFileTrees(FaceTree.Trees);
  if not HasChildTrees(FaceChildren, ['眉', '目', '口']) then
    Exit;

  EyeTree := FindChildTree(FaceChildren, '目');
  MouthTree := FindChildTree(FaceChildren, '口');

  Result :=
    HasChildTrees(TPsdFileTrees(EyeTree.Trees),
      ['カメラ目線', 'カメラ目線半開き', 'カメラ目線閉じ',
       'そらし目線1', 'そらし目線2', '瞬きカメラ目線1']) and
    HasChildTrees(TPsdFileTrees(MouthTree.Trees),
      ['あ', 'い', 'う', 'え', 'お',
       '口パク用_笑い1', '口パク用_通常1']) and
    HasChildTrees(TPsdFileTrees(FaceColorTree.Trees),
      ['なみだ', '汗', '青ざめ', 'ほっぺ', '赤面']);
end;

function HasKamiyoshiRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasKamiyoshiRootStructure(Tree) then
      Exit(True);

    if HasKamiyoshiRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function HasKamiyoshiStructure(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasKamiyoshiRoot(PsdImage.Trees);
end;

function HasKamiyoshiShikokuMetanStructure(
  PsdImage: TPSDImage): Boolean;
var
  RootTree: TPsdFileTree;
  RootChildren: TPsdFileTrees;
  ItemTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
  ArmChildren: TPsdFileTrees;
  BothArmTree: TPsdFileTree;
  FaceTree: TPsdFileTree;
  FaceChildren: TPsdFileTrees;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
  FaceColorTree: TPsdFileTree;
begin
  Result := False;
  if PsdImage = nil then Exit;

  RootTree := FindTreeByName(PsdImage.Trees, '四国めたん');
  if RootTree = nil then Exit;

  RootChildren := TPsdFileTrees(RootTree.Trees);
  if not HasChildTrees(RootChildren,
    ['アイテム', '腕', '顔', '前髪', '顔色', '服', '後ろ', '背景']) then
    Exit;

  ItemTree := FindChildTree(RootChildren, 'アイテム');
  ArmTree := FindChildTree(RootChildren, '腕');
  FaceTree := FindChildTree(RootChildren, '顔');
  FaceColorTree := FindChildTree(RootChildren, '顔色');

  ArmChildren := TPsdFileTrees(ArmTree.Trees);
  BothArmTree := FindChildTree(ArmChildren, '両腕');
  if BothArmTree = nil then Exit;

  if not ((CountChildTrees(TPsdFileTrees(ItemTree.Trees)) >= 30) and
          (CountChildTrees(TPsdFileTrees(BothArmTree.Trees)) >= 10) and
          HasKamiyoshiShikokuMetanArmSide(ArmChildren, '左腕', '左') and
          HasKamiyoshiShikokuMetanArmSide(ArmChildren, '右腕', '右')) then
    Exit;

  FaceChildren := TPsdFileTrees(FaceTree.Trees);
  if not HasChildTrees(FaceChildren, ['眉', '目', '口']) then
    Exit;

  EyeTree := FindChildTree(FaceChildren, '目');
  MouthTree := FindChildTree(FaceChildren, '口');

  Result :=
    HasChildTrees(TPsdFileTrees(EyeTree.Trees),
      ['カメラ目線', 'カメラ目線半開き', 'カメラ目線閉じ',
       'そらし目線1', 'そらし目線2', '瞬きカメラ目線1']) and
    HasChildTrees(TPsdFileTrees(MouthTree.Trees),
      ['あ', 'い', 'う', 'え', 'お',
       '口パク用_笑い1', '口パク用_通常1']) and
    HasChildTrees(TPsdFileTrees(FaceColorTree.Trees),
      ['なみだ', '汗', '青ざめ', 'ほっぺ', '赤面']);
end;

function HasKamiyoshiNo7RootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  ItemTree: TPsdFileTree;
  FaceTree: TPsdFileTree;
  FaceChildren: TPsdFileTrees;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
  FaceColorTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    ['アイテム', '左腕', '右腕', '髪', '顔', '体', '後_しっぽ_傘']) then
    Exit;

  ItemTree := FindChildTree(RootChildren, 'アイテム');
  FaceTree := FindChildTree(RootChildren, '顔');

  if not ((CountChildTrees(TPsdFileTrees(ItemTree.Trees)) >= 15) and
          HasKamiyoshiNo7ArmSide(RootChildren, '左腕', '左') and
          HasKamiyoshiNo7ArmSide(RootChildren, '右腕', '右')) then
    Exit;

  FaceChildren := TPsdFileTrees(FaceTree.Trees);
  if not HasChildTrees(FaceChildren, ['目', '眉', '口', '顔色']) then
    Exit;

  EyeTree := FindChildTree(FaceChildren, '目');
  MouthTree := FindChildTree(FaceChildren, '口');
  FaceColorTree := FindChildTree(FaceChildren, '顔色');

  Result :=
    HasChildTrees(TPsdFileTrees(EyeTree.Trees),
      ['カメラ目線', 'カメラ目線半開き', 'そらし目線1',
       'そらし目線2', '瞬きカメラ目線1']) and
    HasChildTrees(TPsdFileTrees(MouthTree.Trees),
      ['口開き1', '口開き2', '結び1', '口ニコッ1', '口パク用1']) and
    HasChildTrees(TPsdFileTrees(FaceColorTree.Trees),
      ['なみだ', '青ざめ', 'ほっぺ', 'ほっぺ赤め', '斜線ほっぺ']);
end;

function HasKamiyoshiNo7Root(Trees: TPsdFileTrees): Boolean;
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

    if (SameText(TreeName(Tree), '№7') or
        SameText(TreeName(Tree), 'No.7') or
        SameText(TreeName(Tree), 'ナンバー7')) and
       HasKamiyoshiNo7RootStructure(Tree) then
      Exit(True);

    if HasKamiyoshiNo7Root(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function HasKamiyoshiNo7Structure(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasKamiyoshiNo7Root(PsdImage.Trees);
end;

function FindKamiyoshiArmTree(Trees: TPsdFileTrees): TPsdFileTree;
var
  i: Integer;
  Tree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
begin
  Result := nil;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    // カミヨシPSDは「腕」直下に「両腕」「右腕」「左腕」が並ぶ。
    // キャラ名ではなく、この腕構造を起点に独自処理の対象を絞る。
    if SameText(TreeName(Tree), '腕') then
    begin
      ChildTrees := TPsdFileTrees(Tree.Trees);
      if (FindChildTree(ChildTrees, '両腕') <> nil) and
         (FindChildTree(ChildTrees, '右腕') <> nil) and
         (FindChildTree(ChildTrees, '左腕') <> nil) then
        Exit(Tree);
    end;

    Result := FindKamiyoshiArmTree(TPsdFileTrees(Tree.Trees));
    if Result <> nil then Exit;
  end;
end;

function FindChildTreeByNameContaining(Trees: TPsdFileTrees;
  const Token: string): TPsdFileTree;
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

    if Pos(Token, TreeName(Tree)) > 0 then
      Exit(Tree);
  end;
end;

procedure ApplyKamiyoshiExclusiveGroups(PsdImage: TPSDImage);
var
  ArmTree: TPsdFileTree;
  ArmChildren: TPsdFileTrees;
  BothArmTree: TPsdFileTree;
  RightArmTree: TPsdFileTree;
  LeftArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  ArmTree := FindKamiyoshiArmTree(PsdImage.Trees);
  if ArmTree = nil then Exit;

  ArmChildren := TPsdFileTrees(ArmTree.Trees);
  BothArmTree := FindChildTree(ArmChildren, '両腕');
  RightArmTree := FindChildTree(ArmChildren, '右腕');
  LeftArmTree := FindChildTree(ArmChildren, '左腕');

  if (BothArmTree = nil) or (RightArmTree = nil) or (LeftArmTree = nil) then
    Exit;

  // カミヨシPSDの腕は「両腕」と「片腕左右」を同時に使うと絵が重なる。
  // 両腕選択時は左右腕をOFF、片腕選択時は反対側をONにして両腕をOFFにする。
  // 両腕ポーズを使う時は、片腕ポーズの左右を落とす。
  PsdImage.AddVisibilityRule(BothArmTree, RightArmTree, False);
  PsdImage.AddVisibilityRule(BothArmTree, LeftArmTree, False);

  // 片腕ポーズを使う時は、反対側の腕を基礎表示として戻し、両腕ポーズを落とす。
  PsdImage.AddVisibilityRule(RightArmTree, LeftArmTree, True);
  PsdImage.AddVisibilityRule(RightArmTree, BothArmTree, False);
  PsdImage.AddVisibilityRule(LeftArmTree, RightArmTree, True);
  PsdImage.AddVisibilityRule(LeftArmTree, BothArmTree, False);
end;

procedure ApplyKamiyoshiInitialVisibility(PsdImage: TPSDImage);
var
  ArmTree: TPsdFileTree;
  ArmChildren: TPsdFileTrees;
  RightArmTree: TPsdFileTree;
  LeftArmTree: TPsdFileTree;
  BackgroundTree: TPsdFileTree;
  LayerCopyTree: TPsdFileTree;
  LeftJankenTree: TPsdFileTree;
  RightJankenTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  // 背景は素材確認用のため、読み込み直後は表示しない。
  BackgroundTree := FindBestNamedTree(PsdImage.Trees, '背景');
  if BackgroundTree <> nil then
    BackgroundTree.SetVisibleLocal(False);

  // No.7 では残骸レイヤー「レイヤー 1 のコピー」が混ざるため初期非表示にする。
  LayerCopyTree := FindBestNamedTree(PsdImage.Trees, 'レイヤー 1 のコピー');
  if LayerCopyTree <> nil then
    LayerCopyTree.SetVisibleLocal(False);

  ArmTree := FindKamiyoshiArmTree(PsdImage.Trees);
  if ArmTree = nil then Exit;

  ArmChildren := TPsdFileTrees(ArmTree.Trees);
  RightArmTree := FindChildTree(ArmChildren, '右腕');
  LeftArmTree := FindChildTree(ArmChildren, '左腕');

  if RightArmTree <> nil then
  begin
    // 右腕/左腕グループ自体は初期状態では閉じる。
    // 子のジャンケングーだけONにしておき、後で片腕を表示した時の初期候補にする。
    RightArmTree.SetVisibleLocal(False);
    RightJankenTree := FindChildTreeByNameContaining(
      TPsdFileTrees(RightArmTree.Trees), '右ジャンケングー');
    if RightJankenTree <> nil then
      RightJankenTree.SetVisibleLocal(True);
  end;

  if LeftArmTree <> nil then
  begin
    // 左腕側も右腕と同じく、グループOFF + グー候補ONを初期状態にする。
    LeftArmTree.SetVisibleLocal(False);
    LeftJankenTree := FindChildTreeByNameContaining(
      TPsdFileTrees(LeftArmTree.Trees), '左ジャンケングー');
    if LeftJankenTree <> nil then
      LeftJankenTree.SetVisibleLocal(True);
  end;
end;

end.
