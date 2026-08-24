unit PSDImageCustomMoiky;

interface

uses
  PsdImage, PSDImageElementList;

function IsMoikyShikokuMetanPSD(PsdImage: TPSDImage): Boolean;
function IsMoikyAnkomonPSD(PsdImage: TPSDImage): Boolean;
function IsMoikyZundamonPSD(PsdImage: TPSDImage): Boolean;
procedure ApplyMoikyShikokuMetanMarkers(PsdImage: TPSDImage);
procedure ApplyMoikyAnkomonMarkers(PsdImage: TPSDImage);
procedure ApplyMoikyZundamonMarkers(PsdImage: TPSDImage);
procedure ApplyMoikyZundamonFallbackPlusMarkers(PsdImage: TPSDImage);
procedure ApplyMoikyShikokuMetanExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyMoikyAnkomonExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyMoikyShikokuMetanElementList(PsdImage: TPSDImage;
  Elements: TPSDElementList);
procedure ApplyMoikyZundamonElementList(PsdImage: TPSDImage;
  Elements: TPSDElementList);

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

function HasMoikyShikokuMetanFaceStructure(
  FaceChildren: TPsdFileTrees): Boolean;
var
  FaceColorTree: TPsdFileTree;
  BrowTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
begin
  Result := False;
  if not HasChildTrees(FaceChildren, ['顔色', '眉', '目', '口']) then
    Exit;

  FaceColorTree := FindChildTree(FaceChildren, '顔色');
  BrowTree := FindChildTree(FaceChildren, '眉');
  EyeTree := FindChildTree(FaceChildren, '目');
  MouthTree := FindChildTree(FaceChildren, '口');

  Result :=
    HasChildTrees(TPsdFileTrees(FaceColorTree.Trees),
      ['怒りマーク', '照れ', 'あせあせ', 'あせ', 'かげ', '青ざめ']) and
    HasChildTrees(TPsdFileTrees(BrowTree.Trees),
      ['不審', '困り', '怒り', '笑い', '普通']) and
    HasChildTrees(TPsdFileTrees(EyeTree.Trees),
      ['バツ', '線', '閉じ', '笑い', '驚き', '泣き', '白目',
       '半目', 'ハイライト消し', '目に♡', 'キラキラ',
       'ぐるぐる', '左', '右', '普通']) and
    HasChildTrees(TPsdFileTrees(MouthTree.Trees),
      ['わー', 'いしし', 'にへら', '歪み・閉じ', '歪み・半開き',
       '歪み・開き', '笑い・開き', '笑い・半開き', '笑い・閉じ',
       '普通・開き', '普通・半開き', '普通・閉じ']);
end;

function HasMoikyShikokuMetanRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  FaceTree: TPsdFileTree;
  NormalDressTree: TPsdFileTree;
  SchoolDressTree: TPsdFileTree;
  OtherDressTree: TPsdFileTree;
  DrillTree: TPsdFileTree;
  OtherBodyTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;
  if not SameText(TreeName(Tree), 'v1') then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    ['エフェクト・アクセサリ', '制服の腕（顔より前）',
     '腕（顔より前）', '顔', '通常服', '制服胴体',
     '他の服', '髪（胴体より後）', 'ドリル']) then
    Exit;

  FaceTree := FindChildTree(RootChildren, '顔');
  NormalDressTree := FindChildTree(RootChildren, '通常服');
  SchoolDressTree := FindChildTree(RootChildren, '制服胴体');
  OtherDressTree := FindChildTree(RootChildren, '他の服');
  DrillTree := FindChildTree(RootChildren, 'ドリル');

  if not HasMoikyShikokuMetanFaceStructure(TPsdFileTrees(FaceTree.Trees)) then
    Exit;

  OtherBodyTree := FindChildTree(TPsdFileTrees(OtherDressTree.Trees), '体');

  Result :=
    HasChildTrees(TPsdFileTrees(NormalDressTree.Trees),
      ['腕（胴体より前）', '胴体', '腕（胴体より後）']) and
    HasChildTrees(TPsdFileTrees(SchoolDressTree.Trees),
      ['腰に当てる手（左腕）', '腰に当てる手（右腕）の手首',
       '手を合わせる（両腕）', '腕組み（両腕）',
       '降ろした腕', '体']) and
    HasChildTrees(TPsdFileTrees(OtherDressTree.Trees),
      ['腕（胴体より前）', '体', '腕（胴体より後）']) and
    HasChildTrees(TPsdFileTrees(OtherBodyTree.Trees),
      ['下着', '水着', 'バニー', 'コート']) and
    HasChildTrees(TPsdFileTrees(DrillTree.Trees),
      ['ドリル（手持ち）', 'ドリル（背中）']);
end;

function HasMoikyShikokuMetanRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasMoikyShikokuMetanRootStructure(Tree) then
      Exit(True);

    if HasMoikyShikokuMetanRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function IsMoikyShikokuMetanPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and
            HasMoikyShikokuMetanRoot(PsdImage.Trees);
end;

function HasMoikyAnkomonFacePartsStructure(
  FacePartsChildren: TPsdFileTrees): Boolean;
var
  HairTree: TPsdFileTree;
  FaceColorTree: TPsdFileTree;
  BrowTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
begin
  Result := False;
  if not HasChildTrees(FacePartsChildren, ['髪', '顔色', '眉', '目', '口']) then
    Exit;

  HairTree := FindChildTree(FacePartsChildren, '髪');
  FaceColorTree := FindChildTree(FacePartsChildren, '顔色');
  BrowTree := FindChildTree(FacePartsChildren, '眉');
  EyeTree := FindChildTree(FacePartsChildren, '目');
  MouthTree := FindChildTree(FacePartsChildren, '口');

  Result :=
    HasChildTrees(TPsdFileTrees(HairTree.Trees),
      ['通常の耳', 'バニー耳']) and
    HasChildTrees(TPsdFileTrees(FaceColorTree.Trees),
      ['怒りマーク', '赤面あせあせ', '赤面涙', '涙',
       '赤面', 'あせあせ', 'かげ', '青ざめ', '汗']) and
    HasChildTrees(TPsdFileTrees(BrowTree.Trees),
      ['困惑', '激怒', '怒り', '泣き', '笑い', '普通']) and
    HasChildTrees(TPsdFileTrees(EyeTree.Trees),
      ['バツ', '閉じた目', '笑顔目', '疲労', 'ジト目',
       'ぐるぐる', 'キラキラ', 'ハート', 'ハイライト消し',
       'ウインク', '驚き', '上', '左', '右', '半目', '普通目']) and
    HasChildTrees(TPsdFileTrees(MouthTree.Trees),
      ['悪い笑い', 'わー', 'いーっ', 'よだれ', 'いしし',
       'ぺろり', '口パク歪み.0', '口パク笑い.0',
       '口パク煽り.0', '口パク普通.0']);
end;

function HasMoikyAnkomonBodyStructure(BodyChildren: TPsdFileTrees): Boolean;
var
  ArmBodyTree: TPsdFileTree;
  VariationDressTree: TPsdFileTree;
  BackHairTree: TPsdFileTree;
begin
  Result := False;
  if not HasChildTrees(BodyChildren,
    ['腕差分あり胴体', 'バリエーション衣装', '後ろ髪２']) then
    Exit;

  ArmBodyTree := FindChildTree(BodyChildren, '腕差分あり胴体');
  VariationDressTree := FindChildTree(BodyChildren, 'バリエーション衣装');
  BackHairTree := FindChildTree(BodyChildren, '後ろ髪２');

  Result :=
    HasChildTrees(TPsdFileTrees(ArmBodyTree.Trees),
      ['腕（胴体より前）', '胴体(通常)', '腕（胴体より後）']) and
    HasChildTrees(TPsdFileTrees(VariationDressTree.Trees),
      ['カフェ店員', '胴体（ゆるシャツ）', 'つなぎ', 'パーカー']) and
    HasChildTrees(TPsdFileTrees(BackHairTree.Trees),
      ['後ろ髪', 'しっぽ']);
end;

function HasMoikyAnkomonRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  FacePartsTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;
  if not SameText(TreeName(Tree), 'v1') then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    ['顔の前の手', 'アクセサリ', '体の前の手',
     '顔パーツ', '顔', '体']) then
    Exit;

  FacePartsTree := FindChildTree(RootChildren, '顔パーツ');
  BodyTree := FindChildTree(RootChildren, '体');

  Result :=
    HasMoikyAnkomonFacePartsStructure(TPsdFileTrees(FacePartsTree.Trees)) and
    HasMoikyAnkomonBodyStructure(TPsdFileTrees(BodyTree.Trees));
end;

function HasMoikyAnkomonRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasMoikyAnkomonRootStructure(Tree) then
      Exit(True);

    if HasMoikyAnkomonRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function IsMoikyAnkomonPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasMoikyAnkomonRoot(PsdImage.Trees);
end;

function HasMoikyZundamonFacePartsStructure(
  FacePartsChildren: TPsdFileTrees): Boolean;
var
  EarTree: TPsdFileTree;
  BrowTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
begin
  Result := False;
  if not HasChildTrees(FacePartsChildren, ['耳', '眉', '目', '口']) then
    Exit;

  EarTree := FindChildTree(FacePartsChildren, '耳');
  BrowTree := FindChildTree(FacePartsChildren, '眉');
  EyeTree := FindChildTree(FacePartsChildren, '目');
  MouthTree := FindChildTree(FacePartsChildren, '口');

  Result :=
    HasChildTrees(TPsdFileTrees(EarTree.Trees), ['普通', 'たれ']) and
    HasChildTrees(TPsdFileTrees(BrowTree.Trees),
      ['激怒', '無', '怒り', '泣き', '笑い', '普通']) and
    HasChildTrees(TPsdFileTrees(EyeTree.Trees),
      ['白目・泣き', '白目', '笑い', '線', '半目', '驚き',
       '左', '右', '泣き', '♡', 'キラキラ', 'ハイライト消し',
       '過労', '普通']) and
    HasChildTrees(TPsdFileTrees(MouthTree.Trees),
      ['歪み', 'にへら', '笑い・開き', '笑い・閉じ',
       '小口', 'わー', 'むー', 'いー', '無', 'ギャー']);
end;

function HasMoikyZundamonBodyStructure(BodyChildren: TPsdFileTrees): Boolean;
begin
  Result := HasChildTrees(BodyChildren,
    ['作業着', 'コート', '着ぐるみ', '着ぐるみ2', 'ばんざい2',
     'ばんざい', '腕おろし', '一番', '説明', 'B', 'つなぎ',
     'パーカー', '普通', '後髪']);
end;

function HasMoikyZundamonRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  FacePartsTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;
  if not SameText(TreeName(Tree), 'v1') then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren, ['顔パーツ', '顔', '体']) then
    Exit;
  if (FindChildTree(RootChildren, '表情') = nil) and
    not HasChildTrees(RootChildren, ['くろずみ', '青ざめ',
      '怒りマーク', '汗', '照れ']) then
    Exit;

  FacePartsTree := FindChildTree(RootChildren, '顔パーツ');
  BodyTree := FindChildTree(RootChildren, '体');

  Result :=
    HasMoikyZundamonFacePartsStructure(TPsdFileTrees(FacePartsTree.Trees)) and
    HasMoikyZundamonBodyStructure(TPsdFileTrees(BodyTree.Trees));
end;

function HasMoikyZundamonRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasMoikyZundamonRootStructure(Tree) then
      Exit(True);

    if HasMoikyZundamonRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function IsMoikyZundamonPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasMoikyZundamonRoot(PsdImage.Trees);
end;

function FindMoikyZundamonRoot(Trees: TPsdFileTrees): TPsdFileTree;
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

    if HasMoikyZundamonRootStructure(Tree) then
      Exit(Tree);

    Result := FindMoikyZundamonRoot(TPsdFileTrees(Tree.Trees));
    if Result <> nil then Exit;
  end;
end;

function IndexOfChildTreeByName(Trees: TPsdFileTrees; const Name: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
    if SameText(TreeName(Trees[I]), Name) then
      Exit(I);
end;

procedure MoveMoikyZundamonExpressionLayers(PsdImage: TPSDImage;
  RootTree: TPsdFileTree);
var
  RootChildren: TPsdFileTrees;
  FacePartsIndex: Integer;
  FaceIndex: Integer;
  I: Integer;
  TargetCount: Integer;
  ExpressionTree: TPsdFileTree;
  TargetTree: TPsdFileTree;
  TargetTrees: array of TPsdFileTree;
begin
  if (PsdImage = nil) or (RootTree = nil) then Exit;

  RootChildren := TPsdFileTrees(RootTree.Trees);
  if RootChildren = nil then Exit;

  FacePartsIndex := IndexOfChildTreeByName(RootChildren, '顔パーツ');
  FaceIndex := IndexOfChildTreeByName(RootChildren, '顔');
  if (FacePartsIndex < 0) or (FaceIndex < 0) then Exit;
  if FaceIndex <= FacePartsIndex + 1 then Exit;

  TargetCount := 0;
  for I := FacePartsIndex + 1 to FaceIndex - 1 do
  begin
    TargetTree := RootChildren[I];
    if TargetTree = nil then Continue;
    if SameText(TreeName(TargetTree), '表情') then Continue;

    SetLength(TargetTrees, TargetCount + 1);
    TargetTrees[TargetCount] := TargetTree;
    Inc(TargetCount);
  end;
  if TargetCount = 0 then Exit;

  ExpressionTree := FindChildTree(RootChildren, '表情');
  if ExpressionTree = nil then
    ExpressionTree := PsdImage.AddVirtualTree(
      RootChildren, '!表情', FacePartsIndex + 1)
  else
    ReplaceMarkerOnTree(ExpressionTree, '!');
  if ExpressionTree = nil then Exit;

  for I := 0 to TargetCount - 1 do
  begin
    TargetTree := TargetTrees[I];
    RemoveMarkerFromTree(TargetTree);
    PsdImage.MoveTree(TargetTree, TPsdFileTrees(ExpressionTree.Trees));
  end;
end;

function FindMoikyAnkomonRoot(Trees: TPsdFileTrees): TPsdFileTree;
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

    if HasMoikyAnkomonRootStructure(Tree) then
      Exit(Tree);

    Result := FindMoikyAnkomonRoot(TPsdFileTrees(Tree.Trees));
    if Result <> nil then Exit;
  end;
end;

function FindMoikyShikokuMetanRoot(Trees: TPsdFileTrees): TPsdFileTree;
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

    if SameText(TreeName(Tree), 'v1') then
    begin
      ChildTrees := TPsdFileTrees(Tree.Trees);
      if (FindChildTree(ChildTrees, '顔') <> nil) and
         (FindChildTree(ChildTrees, '通常服') <> nil) and
         (FindChildTree(ChildTrees, '制服胴体') <> nil) and
         (FindChildTree(ChildTrees, '他の服') <> nil) and
         (FindChildTree(ChildTrees, 'ドリル') <> nil) then
        Exit(Tree);
    end;

    Result := FindMoikyShikokuMetanRoot(TPsdFileTrees(Tree.Trees));
    if Result <> nil then Exit;
  end;
end;

function FindRootChild(RootTree: TPsdFileTree; const Name: string): TPsdFileTree;
begin
  Result := nil;
  if RootTree = nil then Exit;

  Result := FindChildTree(TPsdFileTrees(RootTree.Trees), Name);
end;

procedure AddExclusivePair(PsdImage: TPSDImage; TriggerTree, TargetTree: TPsdFileTree);
begin
  if (PsdImage = nil) or (TriggerTree = nil) or (TargetTree = nil) then Exit;

  PsdImage.AddVisibilityRule(TriggerTree, TargetTree, False);
end;

procedure AddExclusiveGroup(PsdImage: TPSDImage; const Trees: array of TPsdFileTree);
var
  i: Integer;
  j: Integer;
begin
  if PsdImage = nil then Exit;

  for i := Low(Trees) to High(Trees) do
    for j := Low(Trees) to High(Trees) do
      if i <> j then
        AddExclusivePair(PsdImage, Trees[i], Trees[j]);
end;

procedure HideExclusiveTargets(VisibleTree: TPsdFileTree;
  const Trees: array of TPsdFileTree);
var
  i: Integer;
begin
  if VisibleTree = nil then Exit;

  for i := Low(Trees) to High(Trees) do
    if (Trees[i] <> nil) and (Trees[i] <> VisibleTree) then
      Trees[i].SetVisibleLocal(False);
end;

procedure ApplyCurrentExclusiveState(const Trees: array of TPsdFileTree);
var
  i: Integer;
begin
  // ロード時点で衣装グループが複数表示されている場合も、先頭で見つかった表示グループだけを残す。
  for i := Low(Trees) to High(Trees) do
    if (Trees[i] <> nil) and Trees[i].Visible then
    begin
      HideExclusiveTargets(Trees[i], Trees);
      Exit;
    end;
end;

function FindUniformBodyTree(PsdImage: TPSDImage): TPsdFileTree;
var
  RootTree: TPsdFileTree;
begin
  Result := nil;
  if PsdImage = nil then Exit;

  RootTree := FindMoikyShikokuMetanRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  Result := FindRootChild(RootTree, '制服胴体');
end;

procedure MoveNormalBanzaiArmToBack(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  NormalClothesTree: TPsdFileTree;
  FrontArmTree: TPsdFileTree;
  BackArmTree: TPsdFileTree;
  BanzaiArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyShikokuMetanRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  NormalClothesTree := FindRootChild(RootTree, '通常服');
  if NormalClothesTree = nil then Exit;

  FrontArmTree := FindChildTree(TPsdFileTrees(NormalClothesTree.Trees),
    '腕（胴体より前）');
  BackArmTree := FindChildTree(TPsdFileTrees(NormalClothesTree.Trees),
    '腕（胴体より後）');
  if (FrontArmTree = nil) or (BackArmTree = nil) then Exit;

  BanzaiArmTree := FindChildTree(TPsdFileTrees(FrontArmTree.Trees), '万歳腕');
  if BanzaiArmTree = nil then Exit;

  // 通常服の万歳腕は前腕側にあると胴体より前に描画されるため、後腕側へ移して重なり順を合わせる。
  PsdImage.MoveTree(BanzaiArmTree, TPsdFileTrees(BackArmTree.Trees), 0);
end;

function FindNthChildTree(Trees: TPsdFileTrees; const Name: string;
  Nth: Integer): TPsdFileTree;
var
  I: Integer;
  MatchCount: Integer;
begin
  Result := nil;
  if (Trees = nil) or (Nth <= 0) then Exit;

  MatchCount := 0;
  for I := 0 to Trees.Count - 1 do
    if SameText(TreeName(Trees[I]), Name) then
    begin
      Inc(MatchCount);
      if MatchCount = Nth then
        Exit(Trees[I]);
    end;
end;

procedure MoveSecondMouthArmToNormalBack(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  FaceFrontArmTree: TPsdFileTree;
  NormalClothesTree: TPsdFileTree;
  BackArmTree: TPsdFileTree;
  MouthArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyShikokuMetanRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  FaceFrontArmTree := FindRootChild(RootTree, '腕（顔より前）');
  NormalClothesTree := FindRootChild(RootTree, '通常服');
  if (FaceFrontArmTree = nil) or (NormalClothesTree = nil) then Exit;

  BackArmTree := FindChildTree(TPsdFileTrees(NormalClothesTree.Trees),
    '腕（胴体より後）');
  if BackArmTree = nil then Exit;

  MouthArmTree := FindNthChildTree(TPsdFileTrees(FaceFrontArmTree.Trees),
    '口元腕', 2);
  if MouthArmTree = nil then Exit;

  // 2つ目の口元腕は通常服の後腕として使うため、通常服側の背面腕グループへ移す。
  PsdImage.MoveTree(MouthArmTree, TPsdFileTrees(BackArmTree.Trees), 0);
end;

procedure ApplyMoikyShikokuMetanMarkers(PsdImage: TPSDImage);
var
  UniformBodyTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
begin
  MoveNormalBanzaiArmToBack(PsdImage);
  MoveSecondMouthArmToNormalBack(PsdImage);

  // 衣装グループには '*' を付けない。ここでは制服胴体内の基礎表示「体」だけを ! にして保護する。
  UniformBodyTree := FindUniformBodyTree(PsdImage);
  if UniformBodyTree = nil then Exit;

  BodyTree := FindChildTree(TPsdFileTrees(UniformBodyTree.Trees), '体');
  if BodyTree <> nil then
    ReplaceMarkerOnTree(BodyTree, '!');
end;

procedure ApplyMoikyAnkomonBodyDressMarkers(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
  ArmBodyTree: TPsdFileTree;
  VariationDressTree: TPsdFileTree;
  VariationChildren: TPsdFileTrees;
  I: Integer;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyAnkomonRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  BodyTree := FindRootChild(RootTree, '体');
  if BodyTree = nil then Exit;

  ArmBodyTree := FindChildTree(TPsdFileTrees(BodyTree.Trees), '腕差分あり胴体');
  VariationDressTree := FindChildTree(TPsdFileTrees(BodyTree.Trees), 'バリエーション衣装');

  if ArmBodyTree <> nil then
    ReplaceMarkerOnTree(ArmBodyTree, '*');
  if VariationDressTree = nil then Exit;

  ReplaceMarkerOnTree(VariationDressTree, '*');

  VariationChildren := TPsdFileTrees(VariationDressTree.Trees);
  if VariationChildren = nil then Exit;

  for I := 0 to VariationChildren.Count - 1 do
    if VariationChildren[I] <> nil then
      ReplaceMarkerOnTree(VariationChildren[I], '*');
end;

procedure ApplyMoikyAnkomonFacePartsMarkers(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  FacePartsTree: TPsdFileTree;
  FacePartTrees: TPsdFileTrees;
  CandidateTrees: TPsdFileTrees;
  I: Integer;
  J: Integer;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyAnkomonRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  FacePartsTree := FindRootChild(RootTree, '顔パーツ');
  if FacePartsTree = nil then Exit;

  FacePartTrees := TPsdFileTrees(FacePartsTree.Trees);
  if FacePartTrees = nil then Exit;

  for I := 0 to FacePartTrees.Count - 1 do
  begin
    if FacePartTrees[I] = nil then Continue;

    ReplaceMarkerOnTree(FacePartTrees[I], '!');

    CandidateTrees := TPsdFileTrees(FacePartTrees[I].Trees);
    if CandidateTrees = nil then Continue;

    for J := 0 to CandidateTrees.Count - 1 do
      if CandidateTrees[J] <> nil then
        ReplaceMarkerOnTree(CandidateTrees[J], '*');
  end;
end;

procedure ApplyMoikyAnkomonCafeDressMarkers(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
  VariationDressTree: TPsdFileTree;
  CafeTree: TPsdFileTree;
  CafeChildren: TPsdFileTrees;
  LeftArmTree: TPsdFileTree;
  SecondLeftArmTree: TPsdFileTree;
  BodyPartTree: TPsdFileTree;
  RightArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyAnkomonRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  BodyTree := FindRootChild(RootTree, '体');
  if BodyTree = nil then Exit;

  VariationDressTree := FindChildTree(TPsdFileTrees(BodyTree.Trees), 'バリエーション衣装');
  if VariationDressTree = nil then Exit;

  CafeTree := FindChildTree(TPsdFileTrees(VariationDressTree.Trees), 'カフェ店員');
  if CafeTree = nil then Exit;

  ReplaceMarkerOnTree(CafeTree, '*');

  CafeChildren := TPsdFileTrees(CafeTree.Trees);
  if CafeChildren = nil then Exit;

  LeftArmTree := FindNthChildTree(CafeChildren, '左腕', 1);
  BodyPartTree := FindChildTree(CafeChildren, '体');
  SecondLeftArmTree := FindNthChildTree(CafeChildren, '左腕', 2);
  RightArmTree := FindChildTree(CafeChildren, '右腕');

  if LeftArmTree <> nil then
    ReplaceMarkerOnTree(LeftArmTree, '!');
  if BodyPartTree <> nil then
    ReplaceMarkerOnTree(BodyPartTree, '!');
  if SecondLeftArmTree <> nil then
    SetTreeLayerName(SecondLeftArmTree, '!右腕');
  if RightArmTree <> nil then
    SetTreeLayerName(RightArmTree, '!右腕（コーヒー）');
end;

procedure ApplyMoikyAnkomonMarkers(PsdImage: TPSDImage);
begin
  ApplyMoikyAnkomonFacePartsMarkers(PsdImage);
  ApplyMoikyAnkomonBodyDressMarkers(PsdImage);
  ApplyMoikyAnkomonCafeDressMarkers(PsdImage);
end;

procedure ApplyMoikyZundamonMarkers(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
  BackHairTree: TPsdFileTree;
  WorkWearTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyZundamonRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  MoveMoikyZundamonExpressionLayers(PsdImage, RootTree);

  BodyTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '体');
  if BodyTree = nil then Exit;

  BackHairTree := FindChildTree(TPsdFileTrees(BodyTree.Trees), '後髪');
  if BackHairTree <> nil then
    ReplaceMarkerOnTree(BackHairTree, '!');

  // 作業着は排他服ではなく追加差分として扱うため、明示的に加算候補へ置き換える。
  // 自動補完は既存マーカーを上書きしないので、後段で '*' に戻らない。
  WorkWearTree := FindChildTree(TPsdFileTrees(BodyTree.Trees), '作業着');
  if WorkWearTree <> nil then begin
    ReplaceMarkerOnTree(WorkWearTree, '+');
    WorkWearTree.SetVisibleLocal(False);
  end;
end;

procedure ApplyMoikyZundamonFallbackPlusMarkers(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
  WorkWearTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyZundamonRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  BodyTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '体');
  if BodyTree = nil then Exit;

  WorkWearTree := FindChildTree(TPsdFileTrees(BodyTree.Trees), '作業着');
  if (WorkWearTree <> nil) and (MarkerOfName(LayerName(WorkWearTree)) = '') then
    ApplyMarkerToTree(WorkWearTree, '+');
end;

procedure ApplyMoikyShikokuMetanUniformArmRules(PsdImage: TPSDImage); forward;

procedure ApplyMoikyAnkomonVariationDressRules(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
  ArmBodyTree: TPsdFileTree;
  VariationDressTree: TPsdFileTree;
  VariationChildren: TPsdFileTrees;
  I: Integer;
  TriggerTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyAnkomonRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  BodyTree := FindRootChild(RootTree, '体');
  if BodyTree = nil then Exit;

  ArmBodyTree := FindChildTree(TPsdFileTrees(BodyTree.Trees), '腕差分あり胴体');
  VariationDressTree := FindChildTree(TPsdFileTrees(BodyTree.Trees), 'バリエーション衣装');
  if (ArmBodyTree = nil) or (VariationDressTree = nil) then Exit;

  VariationChildren := TPsdFileTrees(VariationDressTree.Trees);
  if VariationChildren = nil then Exit;

  for I := 0 to VariationChildren.Count - 1 do
  begin
    TriggerTree := VariationChildren[I];
    if TriggerTree <> nil then
      PsdImage.AddVisibilityRule(TriggerTree, ArmBodyTree, False);
  end;
end;

procedure ApplyMoikyShikokuMetanCoatArmRules(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  OtherClothesTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
  CoatTree: TPsdFileTree;
  FrontArmTree: TPsdFileTree;
  BackArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyShikokuMetanRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  OtherClothesTree := FindRootChild(RootTree, '他の服');
  if OtherClothesTree = nil then Exit;

  BodyTree := FindChildTree(TPsdFileTrees(OtherClothesTree.Trees), '体');
  FrontArmTree := FindChildTree(TPsdFileTrees(OtherClothesTree.Trees),
    '腕（胴体より前）');
  BackArmTree := FindChildTree(TPsdFileTrees(OtherClothesTree.Trees),
    '腕（胴体より後）');
  if BodyTree = nil then Exit;

  CoatTree := FindChildTree(TPsdFileTrees(BodyTree.Trees), 'コート');
  if CoatTree = nil then Exit;

  if FrontArmTree <> nil then
    PsdImage.AddVisibilityRule(CoatTree, FrontArmTree, False);
  if BackArmTree <> nil then
    PsdImage.AddVisibilityRule(CoatTree, BackArmTree, False);
end;

procedure ApplyMoikyShikokuMetanFaceFrontArmRules(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  FaceFrontArmTree: TPsdFileTree;
  NormalClothesTree: TPsdFileTree;
  NormalFrontArmTree: TPsdFileTree;
  MouthArmTree: TPsdFileTree;
  BanzaiArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyShikokuMetanRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  FaceFrontArmTree := FindRootChild(RootTree, '腕（顔より前）');
  NormalClothesTree := FindRootChild(RootTree, '通常服');
  if (FaceFrontArmTree = nil) or (NormalClothesTree = nil) then Exit;

  NormalFrontArmTree := FindChildTree(TPsdFileTrees(NormalClothesTree.Trees),
    '腕（胴体より前）');
  if NormalFrontArmTree = nil then Exit;

  MouthArmTree := FindChildTree(TPsdFileTrees(FaceFrontArmTree.Trees),
    '口元腕');
  BanzaiArmTree := FindChildTree(TPsdFileTrees(FaceFrontArmTree.Trees),
    '万歳腕');

  if MouthArmTree <> nil then
    PsdImage.AddVisibilityRule(MouthArmTree, NormalFrontArmTree, False);
  if BanzaiArmTree <> nil then
    PsdImage.AddVisibilityRule(BanzaiArmTree, NormalFrontArmTree, False);
end;

procedure ApplyMoikyShikokuMetanExclusiveGroups(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  NormalClothesTree: TPsdFileTree;
  UniformBodyTree: TPsdFileTree;
  OtherClothesTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindMoikyShikokuMetanRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  NormalClothesTree := FindRootChild(RootTree, '通常服');
  UniformBodyTree := FindRootChild(RootTree, '制服胴体');
  OtherClothesTree := FindRootChild(RootTree, '他の服');

  AddExclusiveGroup(PsdImage,
    [NormalClothesTree, UniformBodyTree, OtherClothesTree]);
  ApplyCurrentExclusiveState(
    [NormalClothesTree, UniformBodyTree, OtherClothesTree]);
  ApplyMoikyShikokuMetanUniformArmRules(PsdImage);
  ApplyMoikyShikokuMetanCoatArmRules(PsdImage);
  ApplyMoikyShikokuMetanFaceFrontArmRules(PsdImage);
end;

procedure ApplyMoikyAnkomonExclusiveGroups(PsdImage: TPSDImage);
begin
  ApplyMoikyAnkomonVariationDressRules(PsdImage);
end;

function CleanElementName(const AName: string): string;
begin
  Result := Trim(AName);
  while (Result <> '') and CharInSet(Result[1], ['*', '!', '+']) do
    Delete(Result, 1, 1);
end;

function SameElementName(Element: TPSDElementItem; const ElementName: string): Boolean;
begin
  Result := (Element <> nil) and
    SameText(CleanElementName(Element.Name), CleanElementName(ElementName));
end;

function EnsureElement(Elements: TPSDElementList; const ElementName: string;
  Tree: TPsdFileTree): TPSDElementItem;
var
  I: Integer;
begin
  Result := nil;
  if Elements = nil then Exit;

  for I := 0 to Elements.Count - 1 do
    if SameElementName(Elements[I], ElementName) then
      Exit(Elements[I]);

  Result := Elements.AddNew;
  Result.Group := '';
  Result.Name := ElementName;
  Result.Caption := ElementName;
  Result.Tree := Tree;
  if Tree <> nil then
    Result.Layer := Tree.Layer;
end;

procedure DeleteElementByCleanName(Elements: TPSDElementList; const ElementName: string);
var
  I: Integer;
begin
  if Elements = nil then Exit;

  for I := Elements.Count - 1 downto 0 do
    if SameElementName(Elements[I], ElementName) then
      Elements.Delete(I);
end;

function IsUniformBodyLayerName(const LayerName: string): Boolean;
begin
  Result := LayerName.Contains('/制服胴体/');
end;

procedure RemoveUniformBodyPartsFromElements(Elements: TPSDElementList);
var
  I: Integer;
  J: Integer;
  Element: TPSDElementItem;
  Part: TPSDElementPart;
begin
  if Elements = nil then Exit;

  for I := Elements.Count - 1 downto 0 do
  begin
    Element := Elements[I];
    if Element = nil then Continue;

    for J := Element.Parts.Count - 1 downto 0 do
    begin
      Part := Element.Parts[J];
      if (Part <> nil) and IsUniformBodyLayerName(Part.LayerName) then
        Element.Parts.Delete(J);
    end;

    if (Element.Parts.Count = 0) and
       (not SameElementName(Element, '制服（右腕）')) and
       (not SameElementName(Element, '制服（左腕）')) and
       (not SameElementName(Element, '制服（両腕）')) then
      Elements.Delete(I);
  end;
end;

procedure AddTreePartIfMissing(Dest: TPSDElementItem; Tree: TPsdFileTree);
var
  Part: TPSDElementPart;
  Name: string;
  I: Integer;
begin
  if (Dest = nil) or (Tree = nil) or (Tree.Layer = nil) then Exit;

  Name := Trim(Tree.Layer.Name);
  if Name = '' then Exit;
  if Dest.Parts.ExistsName(Name) then Exit;

  Part := Dest.Parts.AddNew;
  Part.Name := Name;
  Part.Caption := CleanElementName(Name);
  Part.LayerName := Tree.Layer.AnmText;
  Part.LayerIndex := Tree.Layer.Index;
  Part.ElementPartIndex := Tree.Layer.Index;
  Dest.IncludeLayerBounds(Tree.Layer);

  if Tree.Visible then
    for I := Dest.Parts.Count - 1 downto 1 do
      Dest.Parts.Exchange(I, I - 1);
end;

function IsMoikyUniformRightArmTree(Tree: TPsdFileTree): Boolean;
var
  Name: string;
begin
  Name := TreeName(Tree);
  Result := Name.Contains('右腕');
end;

function IsMoikyUniformBothArmTree(Tree: TPsdFileTree): Boolean;
var
  Name: string;
begin
  Name := TreeName(Tree);
  Result := Name.Contains('両腕');
end;

function IsMoikyUniformLeftArmTree(Tree: TPsdFileTree): Boolean;
var
  Name: string;
begin
  Name := TreeName(Tree);
  // 制服胴体では、左右指定のない「降ろした腕」が左腕側の候補になる。
  Result := Name.Contains('左腕') or
    ((not Name.Contains('右腕')) and (not Name.Contains('両腕')) and
     (not SameText(Name, '体')));
end;

type
  TPsdFileTreeArray = array of TPsdFileTree;

procedure AddTreeToArray(var Trees: TPsdFileTreeArray; Tree: TPsdFileTree);
var
  Count: Integer;
begin
  if Tree = nil then Exit;

  Count := Length(Trees);
  SetLength(Trees, Count + 1);
  Trees[Count] := Tree;
end;

function FindMoikyUniformDefaultLeftArm(const Trees: TPsdFileTreeArray): TPsdFileTree;
var
  I: Integer;
begin
  Result := nil;
  for I := Low(Trees) to High(Trees) do
    if SameText(TreeName(Trees[I]), '降ろした腕') then
      Exit(Trees[I]);
end;

function FindMoikyUniformDefaultRightArm(const Trees: TPsdFileTreeArray): TPsdFileTree;
var
  I: Integer;
begin
  Result := nil;
  for I := Low(Trees) to High(Trees) do
    if SameText(TreeName(Trees[I]), '降ろした腕（右腕）') then
      Exit(Trees[I]);
end;

procedure AddHideRules(PsdImage: TPSDImage; TriggerTree: TPsdFileTree;
  const TargetTrees: TPsdFileTreeArray);
var
  I: Integer;
begin
  if (PsdImage = nil) or (TriggerTree = nil) then Exit;

  for I := Low(TargetTrees) to High(TargetTrees) do
    if TargetTrees[I] <> nil then
      PsdImage.AddVisibilityRule(TriggerTree, TargetTrees[I], False);
end;

procedure ApplyMoikyShikokuMetanUniformArmRules(PsdImage: TPSDImage);
var
  UniformBodyTree: TPsdFileTree;
  UniformChildren: TPsdFileTrees;
  RightArmTrees: TPsdFileTreeArray;
  LeftArmTrees: TPsdFileTreeArray;
  BothArmTrees: TPsdFileTreeArray;
  DefaultRightArmTree: TPsdFileTree;
  DefaultLeftArmTree: TPsdFileTree;
  I: Integer;
  ChildTree: TPsdFileTree;
begin
  UniformBodyTree := FindUniformBodyTree(PsdImage);
  if UniformBodyTree = nil then Exit;

  UniformChildren := TPsdFileTrees(UniformBodyTree.Trees);
  if UniformChildren = nil then Exit;

  for I := 0 to UniformChildren.Count - 1 do
  begin
    ChildTree := UniformChildren[I];
    if (ChildTree = nil) or SameText(TreeName(ChildTree), '体') then Continue;

    if IsMoikyUniformBothArmTree(ChildTree) then
      AddTreeToArray(BothArmTrees, ChildTree)
    else if IsMoikyUniformRightArmTree(ChildTree) then
      AddTreeToArray(RightArmTrees, ChildTree)
    else if IsMoikyUniformLeftArmTree(ChildTree) then
      AddTreeToArray(LeftArmTrees, ChildTree);
  end;

  DefaultRightArmTree := FindMoikyUniformDefaultRightArm(RightArmTrees);
  DefaultLeftArmTree := FindMoikyUniformDefaultLeftArm(LeftArmTrees);

  for I := Low(BothArmTrees) to High(BothArmTrees) do
  begin
    AddHideRules(PsdImage, BothArmTrees[I], RightArmTrees);
    AddHideRules(PsdImage, BothArmTrees[I], LeftArmTrees);
  end;

  for I := Low(RightArmTrees) to High(RightArmTrees) do
  begin
    AddHideRules(PsdImage, RightArmTrees[I], BothArmTrees);
    if DefaultLeftArmTree <> nil then
      PsdImage.AddVisibilityRule(RightArmTrees[I], DefaultLeftArmTree, True);
  end;

  for I := Low(LeftArmTrees) to High(LeftArmTrees) do
  begin
    AddHideRules(PsdImage, LeftArmTrees[I], BothArmTrees);
    if DefaultRightArmTree <> nil then
      PsdImage.AddVisibilityRule(LeftArmTrees[I], DefaultRightArmTree, True);
  end;
end;

procedure ApplyMoikyShikokuMetanElementList(PsdImage: TPSDImage;
  Elements: TPSDElementList);
var
  UniformBodyTree: TPsdFileTree;
  UniformChildren: TPsdFileTrees;
  RightArmElement: TPSDElementItem;
  LeftArmElement: TPSDElementItem;
  BothArmElement: TPSDElementItem;
  I: Integer;
  ChildTree: TPsdFileTree;
begin
  if (PsdImage = nil) or (Elements = nil) then Exit;

  UniformBodyTree := FindUniformBodyTree(PsdImage);
  if UniformBodyTree = nil then Exit;

  DeleteElementByCleanName(Elements, '制服（右腕）');
  DeleteElementByCleanName(Elements, '制服（左腕）');
  DeleteElementByCleanName(Elements, '制服（両腕）');
  RemoveUniformBodyPartsFromElements(Elements);

  RightArmElement := EnsureElement(Elements, '制服（右腕）', UniformBodyTree);
  LeftArmElement := EnsureElement(Elements, '制服（左腕）', UniformBodyTree);
  BothArmElement := EnsureElement(Elements, '制服（両腕）', UniformBodyTree);

  UniformChildren := TPsdFileTrees(UniformBodyTree.Trees);
  if UniformChildren = nil then Exit;

  for I := 0 to UniformChildren.Count - 1 do
  begin
    ChildTree := UniformChildren[I];
    if (ChildTree = nil) or SameText(TreeName(ChildTree), '体') then Continue;

    if IsMoikyUniformBothArmTree(ChildTree) then
      AddTreePartIfMissing(BothArmElement, ChildTree)
    else if IsMoikyUniformRightArmTree(ChildTree) then
      AddTreePartIfMissing(RightArmElement, ChildTree)
    else if IsMoikyUniformLeftArmTree(ChildTree) then
    AddTreePartIfMissing(LeftArmElement, ChildTree);
  end;
end;

procedure AddMoikyZundamonExpressionPartIfMissing(Dest: TPSDElementItem;
  Tree: TPsdFileTree);
var
  Part: TPSDElementPart;
  Name: string;
begin
  if (Dest = nil) or (Tree = nil) or (Tree.Layer = nil) then Exit;
  if Tree.Layer.LayerType = -1 then Exit;

  Name := TreeName(Tree);
  if Name = '' then Exit;
  if Dest.Parts.ExistsName(Name) then Exit;

  Part := Dest.Parts.AddNew;
  Part.Name := Name;
  Part.Caption := Name;
  Part.LayerName := Tree.Layer.AnmText;
  Part.LayerIndex := Tree.Layer.Index;
  if Tree.Layer.Index <> 0 then
    Part.ElementPartIndex := Tree.Layer.Index
  else
    Part.ElementPartIndex := -(Dest.Parts.Count);

  Dest.IncludeLayerBounds(Tree.Layer);
end;

procedure ApplyMoikyZundamonElementList(PsdImage: TPSDImage;
  Elements: TPSDElementList);
var
  RootTree: TPsdFileTree;
  ExpressionTree: TPsdFileTree;
  ExpressionChildren: TPsdFileTrees;
  ExpressionElement: TPSDElementItem;
  I: Integer;
begin
  if (PsdImage = nil) or (Elements = nil) then Exit;

  RootTree := FindMoikyZundamonRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  ExpressionTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '表情');
  if ExpressionTree = nil then Exit;

  ExpressionElement := EnsureElement(Elements, '!表情', ExpressionTree);
  if ExpressionElement = nil then Exit;
  ExpressionElement.Caption := '表情';

  ExpressionChildren := TPsdFileTrees(ExpressionTree.Trees);
  if ExpressionChildren = nil then Exit;

  for I := 0 to ExpressionChildren.Count - 1 do
    AddMoikyZundamonExpressionPartIfMissing(
      ExpressionElement, ExpressionChildren[I]);
end;

end.
