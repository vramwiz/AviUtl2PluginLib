unit PSDImageCustomKarai;

interface

uses
  PsdImage, PSDImageElementList;

function IsKaraiFileName(const FileName: string): Boolean;
function HasKaraiStructure(PsdImage: TPSDImage): Boolean;

procedure ApplyKaraiMarkers(PsdImage: TPSDImage);
procedure ApplyKaraiInitialVisibility(PsdImage: TPSDImage);
procedure ApplyKaraiArmElementList(Elements: TPSDElementList);
procedure ApplyKaraiBodyElementList(PsdImage: TPSDImage; Elements: TPSDElementList);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

const
  KARAI_MANTSUKI =    '漫付';
  KARAI_OH =          'おっ';
  KARAI_BACK_PARTS =  '後ろパーツ';
  KARAI_GUITAR =      'ギター';
  KARAI_HEAD_PARTS =  '頭パーツ';
  KARAI_GRAY_RIBBON = 'グレーリボン';

function HasText(const S, Token: string): Boolean;
begin
  Result := Pos(LowerCase(Token), LowerCase(S)) > 0;
end;

function FindTreeByName(Trees: TPsdFileTrees;
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
  i: Integer;
begin
  Result := False;
  if Trees = nil then Exit;

  for i := Low(Names) to High(Names) do
    if FindChildTree(Trees, Names[i]) = nil then
      Exit;

  Result := True;
end;

function CountChildTreesWithText(Trees: TPsdFileTrees;
  const Token: string): Integer;
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  Result := 0;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    if HasText(TreeName(Tree), Token) then
      Inc(Result);
  end;
end;

function IsKaraiFileName(const FileName: string): Boolean;
var
  Name: string;
  SepPos: Integer;
  Suffix: string;
begin
  Result := False;
  Name := ChangeFileExt(ExtractFileName(FileName), '');
  SepPos := Pos(' - ', Name);
  if SepPos <= 0 then Exit;

  Suffix := Trim(Copy(Name, SepPos + 3, MaxInt));
  Result :=
    SameText(Suffix, '公式(小)') or
    SameText(Suffix, '私服');
end;

function HasKaraiRootStructure(Tree: TPsdFileTree): Boolean;
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

function HasKaraiMakiRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  BodyRootTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if FindChildTree(RootChildren, '本体') = nil then
    Exit;

  BodyRootTree := FindChildTree(RootChildren, '本体');
  if BodyRootTree = nil then Exit;

  Result :=
    (FindTreeByName(TPsdFileTrees(BodyRootTree.Trees), '前パーツ') <> nil) and
    (FindTreeByName(TPsdFileTrees(BodyRootTree.Trees), '体') <> nil) and
    (FindTreeByName(TPsdFileTrees(BodyRootTree.Trees), '口') <> nil) and
    (FindTreeByName(TPsdFileTrees(BodyRootTree.Trees), '目') <> nil) and
    (
      ((FindTreeByName(TPsdFileTrees(BodyRootTree.Trees), '赤上着') <> nil) and
       (FindTreeByName(TPsdFileTrees(BodyRootTree.Trees), 'ジャケット') <> nil)) or
      ((FindTreeByName(TPsdFileTrees(BodyRootTree.Trees), 'カーディガン') <> nil) and
       (FindTreeByName(TPsdFileTrees(BodyRootTree.Trees), 'バニー') <> nil))
    );
end;

function HasKaraiRoot(Trees: TPsdFileTrees): Boolean;
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  Result := False;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    if HasKaraiRootStructure(Tree) or HasKaraiMakiRootStructure(Tree) then
      Exit(True);

    if HasKaraiRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function HasKaraiStructure(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and
            HasKaraiRoot(PsdImage.Trees);
end;

function IsArmTreeName(const Name: string): Boolean;
begin
  Result :=
    (Pos('腕', Name) > 0) or
    (Pos('右手', Name) > 0) or
    (Pos('左手', Name) > 0) or
    (Pos('両手', Name) > 0);
end;

function IsArmElementRootName(const Name: string): Boolean;
begin
  Result :=
    SameText(Name, '腕') or
    SameText(Name, '右腕') or
    SameText(Name, '左腕') or
    SameText(Name, '両腕') or
    SameText(Name, '右手') or
    SameText(Name, '左手') or
    SameText(Name, '両手');
end;

function IsKaraiIgnoredArmPartName(const Name: string): Boolean;
begin
  Result := SameText(Name, 'ピース内');
end;

function IsArmElementRoot(Tree: TPsdFileTree): Boolean;
var
  Parent: TPsdFileTree;
begin
  Result := False;
  if not IsArmElementRootName(TreeName(Tree)) then Exit;

  Parent := ParentTree(Tree);
  Result := not IsArmElementRootName(TreeName(Parent));
end;

procedure ApplyArmChildMarkers(Tree: TPsdFileTree);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
  Name: string;
begin
  if Tree = nil then Exit;

  Name := TreeName(Tree);
  if IsKaraiIgnoredArmPartName(Name) then
  begin
    ReplaceMarkerOnTree(Tree, '!');
    Tree.SetVisibleLocal(False);
    Exit;
  end;

  // 根元の腕/手系は ApplyKaraiArmMarkers で ! にする。
  // その配下に同名の腕/手系が出る場合は、衣装や両腕用の候補なので * にする。
  if IsArmElementRootName(Name) then
    ReplaceMarkerOnTree(Tree, '*')
  else
    ApplyMarkerToTree(Tree, '*');

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
    ApplyArmChildMarkers(ChildTrees[i]);
end;

procedure ApplyKaraiArmMarkers(Tree: TPsdFileTree);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
begin
  if Tree = nil then Exit;

  // 腕/右腕を大分類にし、配下の衣装別腕やポーズを小分類ルートとして拾わせる。
  ReplaceMarkerOnTree(Tree, '!');

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
    ApplyArmChildMarkers(ChildTrees[i]);
end;

procedure ApplyKaraiMarkersToSiblingLeaves(Trees: TPsdFileTrees);
var
  i: Integer;
  Tree: TPsdFileTree;
  StarLeafCount: Integer;
begin
  if Trees = nil then Exit;

  StarLeafCount := 0;
  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    // 腕系は専用補正で大分類を分けるため、汎用のleaf補正からは外す。
    if (Tree <> nil) and IsArmTreeName(TreeName(Tree)) then
      Exit;

    if (Tree <> nil) and IsLeafTree(Tree) and
       (MarkerOfName(LayerName(Tree)) = '*') then
      Inc(StarLeafCount);
  end;

  // 既に排他候補として成立している兄弟だけを補う。
  // 服装メニュー側で切り替える階層は無理にマーカー化しない。
  if StarLeafCount >= 2 then
  begin
    for i := 0 to Trees.Count - 1 do
    begin
      Tree := Trees[i];
      if (Tree <> nil) and IsLeafTree(Tree) then
        ApplyMarkerToTree(Tree, '*');
    end;
  end;
end;

procedure ApplyKaraiDressMarkers(Trees: TPsdFileTrees);
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
    if Name = '' then Continue;

    if SameText(Name, '頭') then
    begin
      // 服配下の「頭」は衣装切替でも残す基礎パーツなので常時表示扱いにする。
      ApplyMarkerToTree(Tree, '!');
      Continue;
    end;

    // 服配下の衣装候補は排他選択にする。
    ApplyMarkerToTree(Tree, '*');
  end;
end;

procedure ApplyKaraiBodyDressMarkers(Trees: TPsdFileTrees);
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
    if (Name = '') or IsArmTreeName(Name) then Continue;

    // 体配下では左手を基礎表示にし、同階層の服装候補だけを排他選択にする。
    ApplyMarkerToTree(Tree, '*');
  end;
end;

procedure ApplyKaraiChildOptionMarkers(Trees: TPsdFileTrees);
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    ApplyMarkerToTree(Tree, '*');
  end;
end;

function IsKaraiEyeExcludedOptionName(const Name: string): Boolean;
begin
  Result :=
    SameText(Name, '効果') or
    SameText(Name, '睫毛') or
    SameText(Name, '白目');
end;

procedure ApplyKaraiEyeOptionMarkers(Trees: TPsdFileTrees);
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
    if IsKaraiEyeExcludedOptionName(Name) then Continue;

    ApplyMarkerToTree(Tree, '*');
    ApplyKaraiEyeOptionMarkers(TPsdFileTrees(Tree.Trees));
  end;
end;

procedure ApplyKaraiMouthOptionMarkers(Trees: TPsdFileTrees);
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    ApplyMarkerToTree(Tree, '*');
    if SameText(TreeName(Tree), 'あいうえお') then
      ApplyKaraiChildOptionMarkers(TPsdFileTrees(Tree.Trees));
  end;
end;

procedure ApplyKaraiFacePartsMarkers(Trees: TPsdFileTrees);
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
    if SameText(Name, '目') then
      ApplyKaraiEyeOptionMarkers(TPsdFileTrees(Tree.Trees))
    else if SameText(Name, '口') then
      ApplyKaraiMouthOptionMarkers(TPsdFileTrees(Tree.Trees))
    else if SameText(Name, '眉') then
      ApplyKaraiChildOptionMarkers(TPsdFileTrees(Tree.Trees));
  end;
end;

procedure ApplyKaraiEyeRootMarkers(Trees: TPsdFileTrees);
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
    if not (SameText(Name, '通常') or
            SameText(Name, '手前') or
            SameText(Name, '通常光オフ') or
            SameText(Name, '手前光オフ')) then
      Continue;

    // 目は「通常」などの根が排他にならないと複数の目セットが同時表示される。
    ApplyMarkerToTree(Tree, '*');
  end;
end;

procedure ApplyKaraiHairBackMarkers(Trees: TPsdFileTrees);
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

    // 後ろ髪は直下候補を排他選択にする。
    ApplyMarkerToTree(Tree, '*');

    if SameText(Name, 'ヤシ') or SameText(Name, '頭パーツ') then
      ApplyKaraiChildOptionMarkers(TPsdFileTrees(Tree.Trees));
  end;
end;

procedure NormalizeKaraiHairBackTree(PsdImage: TPSDImage);
var
  HairBackTree: TPsdFileTree;
  PartsRootTree: TPsdFileTree;
  YashiTree: TPsdFileTree;
  HeadPartsTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  HairBackTree := FindBestNamedTree(PsdImage.Trees, '後ろ髪');
  if HairBackTree = nil then
    HairBackTree := FindBestNamedTree(PsdImage.Trees, '後髪');
  if HairBackTree = nil then Exit;

  PartsRootTree := FindChildTree(TPsdFileTrees(HairBackTree.Trees), '後ろ髪パーツ');
  if PartsRootTree = nil then
    PartsRootTree := PsdImage.AddVirtualTree(TPsdFileTrees(HairBackTree.Trees), '!後ろ髪パーツ');
  if PartsRootTree = nil then Exit;

  YashiTree := FindChildTree(TPsdFileTrees(HairBackTree.Trees), 'ヤシ');
  if YashiTree <> nil then
  begin
    ReplaceMarkerOnTree(YashiTree, '!');
    PsdImage.MoveTree(YashiTree, TPsdFileTrees(PartsRootTree.Trees));
    ApplyKaraiChildOptionMarkers(TPsdFileTrees(YashiTree.Trees));
  end;

  HeadPartsTree := FindChildTree(TPsdFileTrees(HairBackTree.Trees), '頭パーツ');
  if HeadPartsTree <> nil then
  begin
    ReplaceMarkerOnTree(HeadPartsTree, '!');
    PsdImage.MoveTree(HeadPartsTree, TPsdFileTrees(PartsRootTree.Trees));
    ApplyKaraiChildOptionMarkers(TPsdFileTrees(HeadPartsTree.Trees));
  end;
end;

procedure PrepareKaraiBackPartsForVirtualMarker(PsdImage: TPSDImage);
var
  BackPartsTree: TPsdFileTree;
  GuitarTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  BackPartsTree := FindBestNamedTree(PsdImage.Trees, '後ろパーツ');
  if BackPartsTree = nil then Exit;

  GuitarTree := FindChildTree(TPsdFileTrees(BackPartsTree.Trees), 'ギター');
  if GuitarTree = nil then Exit;

  // ギターは初期OFFにしつつ、後段の ApplyVirtualMarker('+') で候補化させる。
  GuitarTree.SetVisibleLocal(False);
end;

procedure ApplyKaraiMarkersToTrees(Trees: TPsdFileTrees);
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  ApplyKaraiMarkersToSiblingLeaves(Trees);

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree <> nil then
    begin
      if IsArmElementRoot(Tree) then
        ApplyKaraiArmMarkers(Tree);

      if SameText(TreeName(Tree), '服') then
        ApplyKaraiDressMarkers(TPsdFileTrees(Tree.Trees));

      if SameText(TreeName(Tree), '体') then
        ApplyKaraiBodyDressMarkers(TPsdFileTrees(Tree.Trees));

      if SameText(TreeName(Tree), '顔パーツ') then
        ApplyKaraiFacePartsMarkers(TPsdFileTrees(Tree.Trees));

      if SameText(TreeName(Tree), '目') then
        ApplyKaraiEyeRootMarkers(TPsdFileTrees(Tree.Trees));

      if SameText(TreeName(Tree), '後髪') or
         SameText(TreeName(Tree), '後ろ髪') then
        ApplyKaraiHairBackMarkers(TPsdFileTrees(Tree.Trees));

      ApplyKaraiMarkersToTrees(TPsdFileTrees(Tree.Trees));
    end;
  end;
end;

procedure ApplyKaraiMarkers(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  NormalizeKaraiHairBackTree(PsdImage);
  PrepareKaraiBackPartsForVirtualMarker(PsdImage);
  ApplyKaraiMarkersToTrees(PsdImage.Trees);
end;

procedure SetChildInitialInvisible(PsdImage: TPSDImage; const ParentName,
  ChildName: string);
var
  ParentTree: TPsdFileTree;
  ChildTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  ParentTree := FindBestNamedTree(PsdImage.Trees, ParentName);
  if ParentTree = nil then Exit;

  ChildTree := FindChildTree(TPsdFileTrees(ParentTree.Trees), ChildName);
  if ChildTree = nil then Exit;

  ChildTree.SetVisibleLocal(False);
end;

procedure ApplyKaraiInitialVisibility(PsdImage: TPSDImage);
begin
  SetChildInitialInvisible(PsdImage, KARAI_MANTSUKI, KARAI_OH);
  SetChildInitialInvisible(PsdImage, KARAI_BACK_PARTS, KARAI_GUITAR);
  SetChildInitialInvisible(PsdImage, KARAI_HEAD_PARTS, KARAI_GRAY_RIBBON);
end;

function CleanElementName(const AName: string): string;
begin
  Result := Trim(AName);
  while (Result <> '') and CharInSet(Result[1], ['*', '!', '+']) do
    Delete(Result, 1, 1);
end;

function IsKaraiArmElement(Element: TPSDElementItem): Boolean;
begin
  Result := (Element <> nil) and SameText(CleanElementName(Element.Name), '腕');
end;

function IsBodyDressPartTree(Tree: TPsdFileTree): Boolean;
begin
  Result := (Tree <> nil) and
    (LayerName(Tree) <> '') and
    (LayerName(Tree)[1] = '*') and
    not SameText(TreeName(Tree), '左手') and
    not SameText(TreeName(Tree), '右手') and
    not SameText(TreeName(Tree), '両手') and
    not SameText(TreeName(Tree), '腕') and
    not SameText(TreeName(Tree), '右腕') and
    not SameText(TreeName(Tree), '左腕') and
    not SameText(TreeName(Tree), '両腕');
end;

function SameElementRoute(Element: TPSDElementItem; const GroupName,
  ElementName: string): Boolean;
begin
  Result := (Element <> nil) and
    SameText(Trim(Element.Group), Trim(GroupName)) and
    SameText(CleanElementName(Element.Name), CleanElementName(ElementName));
end;

function FindElement(Elements: TPSDElementList; const GroupName,
  ElementName: string): TPSDElementItem;
var
  I: Integer;
begin
  Result := nil;
  if Elements = nil then
    Exit;

  for I := 0 to Elements.Count - 1 do
    if SameElementRoute(Elements[I], GroupName, ElementName) then
      Exit(Elements[I]);
end;

function EnsureElement(Elements: TPSDElementList; Source: TPSDElementItem;
  const ElementName: string): TPSDElementItem; overload;
begin
  Result := nil;
  if (Elements = nil) or (Source = nil) then
    Exit;

  Result := FindElement(Elements, Source.Group, ElementName);
  if Result <> nil then
    Exit;

  Result := Elements.AddNew;
  Result.Group := Source.Group;
  Result.Name := ElementName;
  Result.Caption := ElementName;
  Result.Tree := Source.Tree;
  Result.Layer := Source.Layer;
end;

function EnsureElement(Elements: TPSDElementList; const GroupName,
  ElementName: string; Tree: TPsdFileTree): TPSDElementItem; overload;
begin
  Result := nil;
  if Elements = nil then Exit;

  Result := FindElement(Elements, GroupName, ElementName);
  if Result <> nil then Exit;

  Result := Elements.AddNew;
  Result.Group := GroupName;
  Result.Name := ElementName;
  Result.Caption := ElementName;
  Result.Tree := Tree;
  if (Tree <> nil) then
    Result.Layer := Tree.Layer;
end;

procedure CopyPartIfMissing(Dest: TPSDElementItem; SourcePart: TPSDElementPart);
var
  Part: TPSDElementPart;
begin
  if (Dest = nil) or (SourcePart = nil) then
    Exit;
  if Dest.Parts.ExistsName(SourcePart.Name) then
    Exit;

  Part := Dest.Parts.AddNew;
  Part.Assign(SourcePart);
end;

procedure AddTreePartIfMissing(Dest: TPSDElementItem; Tree: TPsdFileTree);
var
  Part: TPSDElementPart;
  Name: string;
begin
  if (Dest = nil) or (Tree = nil) or (Tree.Layer = nil) then Exit;

  Name := Trim(Tree.Layer.Name);
  if Name = '' then Exit;
  if Dest.Parts.ExistsName(Name) then Exit;

  Part := Dest.Parts.AddNew;
  Part.Name := Name;
  Part.Caption := Name;
  Part.LayerName := Tree.Layer.AnmText;
  Part.LayerIndex := Tree.Layer.Index;
  Part.ElementPartIndex := Tree.Layer.Index;
  Dest.IncludeLayerBounds(Tree.Layer);
end;

function IsRightArmPart(Part: TPSDElementPart): Boolean;
begin
  Result := (Part <> nil) and
    ((Pos('(右)', Part.Name) > 0) or (Pos('（右）', Part.Name) > 0));
end;

function IsBothArmPart(Part: TPSDElementPart): Boolean;
begin
  Result := (Part <> nil) and
    ((Pos('(両)', Part.Name) > 0) or (Pos('（両）', Part.Name) > 0));
end;

procedure ApplyKaraiArmElementList(Elements: TPSDElementList);
var
  I, J: Integer;
  Source: TPSDElementItem;
  Dest: TPSDElementItem;
  Part: TPSDElementPart;
begin
  if Elements = nil then
    Exit;

  for I := Elements.Count - 1 downto 0 do
  begin
    Source := Elements[I];
    if not IsKaraiArmElement(Source) then
      Continue;

    for J := Source.Parts.Count - 1 downto 0 do
    begin
      Part := Source.Parts[J];
      if IsRightArmPart(Part) then
        Dest := EnsureElement(Elements, Source, '!右腕')
      else if IsBothArmPart(Part) then
        Dest := EnsureElement(Elements, Source, '!両腕')
      else
        Dest := nil;

      if Dest = nil then
        Continue;

      CopyPartIfMissing(Dest, Part);
      Source.Parts.Delete(J);
    end;

    if Source.Parts.Count = 0 then
      Elements.Delete(I);
  end;
end;

function HasChildNamed(Trees: TPsdFileTrees; const Name: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
    if SameText(TreeName(Trees[I]), Name) then
      Exit(True);
end;

function HasBodyDressChildren(Trees: TPsdFileTrees): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
    if IsBodyDressPartTree(Trees[I]) then
      Exit(True);
end;

function FindKaraiBodyTree(Trees: TPsdFileTrees): TPsdFileTree;
var
  I: Integer;
  Tree: TPsdFileTree;
  Children: TPsdFileTrees;
begin
  Result := nil;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    Children := TPsdFileTrees(Tree.Trees);
    if SameText(TreeName(Tree), '体') and
       HasChildNamed(Children, '左手') and
       HasBodyDressChildren(Children) then
      Exit(Tree);

    Result := FindKaraiBodyTree(Children);
    if Result <> nil then Exit;
  end;
end;

procedure DeleteElementByCleanName(Elements: TPSDElementList; const Name: string);
var
  I: Integer;
begin
  if Elements = nil then Exit;

  for I := Elements.Count - 1 downto 0 do
    if SameText(CleanElementName(Elements[I].Name), Name) then
      Elements.Delete(I);
end;

procedure ApplyKaraiBodyElementList(PsdImage: TPSDImage; Elements: TPSDElementList);
var
  BodyTree: TPsdFileTree;
  BodyChildren: TPsdFileTrees;
  BodyElement: TPSDElementItem;
  RightArmElement: TPSDElementItem;
  I, J: Integer;
  DressTree: TPsdFileTree;
  RightArmTree: TPsdFileTree;
  RightArmChildren: TPsdFileTrees;
begin
  if (PsdImage = nil) or (Elements = nil) then Exit;

  BodyTree := FindKaraiBodyTree(PsdImage.Trees);
  if BodyTree = nil then Exit;

  DeleteElementByCleanName(Elements, '体');
  DeleteElementByCleanName(Elements, '右腕');

  BodyElement := EnsureElement(Elements, '', '体', BodyTree);
  RightArmElement := EnsureElement(Elements, '', '!右腕',
    FindChildTree(TPsdFileTrees(BodyTree.Trees), '右腕'));

  BodyChildren := TPsdFileTrees(BodyTree.Trees);
  if BodyChildren = nil then Exit;

  for I := 0 to BodyChildren.Count - 1 do
  begin
    DressTree := BodyChildren[I];
    if not IsBodyDressPartTree(DressTree) then Continue;

    AddTreePartIfMissing(BodyElement, DressTree);

    RightArmTree := FindChildTree(TPsdFileTrees(DressTree.Trees), '右腕');
    if RightArmTree = nil then Continue;

    if (RightArmElement.Tree = nil) then
    begin
      RightArmElement.Tree := RightArmTree;
      RightArmElement.Layer := RightArmTree.Layer;
    end;

    RightArmChildren := TPsdFileTrees(RightArmTree.Trees);
    if RightArmChildren = nil then Continue;

    for J := 0 to RightArmChildren.Count - 1 do
      if (RightArmChildren[J] <> nil) and
         (LayerName(RightArmChildren[J]) <> '') and
         (LayerName(RightArmChildren[J])[1] = '*') then
        AddTreePartIfMissing(RightArmElement, RightArmChildren[J]);
  end;
end;

end.
