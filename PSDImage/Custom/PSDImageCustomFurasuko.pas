unit PSDImageCustomFurasuko;

interface

uses
  PsdImage;

function IsFurasukoPSD(PsdImage: TPSDImage): Boolean;
function IsFurasukoKiritanPSD(PsdImage: TPSDImage): Boolean;
procedure ApplyFurasukoMarkers(PsdImage: TPSDImage);
procedure ApplyFurasukoInitialVisibility(PsdImage: TPSDImage);
procedure ApplyFurasukoKiritanMarkers(PsdImage: TPSDImage);
procedure ApplyFurasukoKiritanInitialVisibility(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

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

function HasFurasukoHoodStructure(Tree: TPsdFileTree): Boolean;
var
  ChildTrees: TPsdFileTrees;
  FaceTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(ChildTrees, ['表情', '結月ゆかり']) then
    Exit;

  FaceTree := FindChildTree(ChildTrees, '表情');
  Result :=
    (FindTreeByName(TPsdFileTrees(FaceTree.Trees), 'デフォルメ') <> nil) and
    (FindTreeByName(TPsdFileTrees(FaceTree.Trees), '口') <> nil) and
    (FindTreeByName(TPsdFileTrees(FaceTree.Trees), '目') <> nil) and
    (FindTreeByName(TPsdFileTrees(FaceTree.Trees), '眉毛') <> nil) and
    (FindTreeByName(TPsdFileTrees(FaceTree.Trees), '頬') <> nil);
end;

function HasFurasukoRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  ExpressionTree: TPsdFileTree;
  DecorationTree: TPsdFileTree;
  HoodOnTree: TPsdFileTree;
  HoodOffTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    ['感情表現', '装飾', 'フードあり', 'フードなし']) then
    Exit;

  ExpressionTree := FindChildTree(RootChildren, '感情表現');
  DecorationTree := FindChildTree(RootChildren, '装飾');
  HoodOnTree := FindChildTree(RootChildren, 'フードあり');
  HoodOffTree := FindChildTree(RootChildren, 'フードなし');

  Result :=
    (CountChildTrees(TPsdFileTrees(ExpressionTree.Trees)) >= 10) and
    (CountChildTrees(TPsdFileTrees(DecorationTree.Trees)) >= 3) and
    HasFurasukoHoodStructure(HoodOnTree) and
    HasFurasukoHoodStructure(HoodOffTree);
end;

function HasFurasukoRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasFurasukoRootStructure(Tree) then
      Exit(True);

    if HasFurasukoRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function IsFurasukoPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasFurasukoRoot(PsdImage.Trees);
end;

function HasFurasukoKiritanRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  FaceTree: TPsdFileTree;
  DressTree: TPsdFileTree;
  HairStyleTree: TPsdFileTree;
  BackDecorationTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;
  if not SameText(TreeName(Tree), 'v1') then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    ['感情表現', '装飾', '表情', '出力用下地', '衣装', '髪型', '素体', '背中装飾']) then
    Exit;

  FaceTree := FindChildTree(RootChildren, '表情');
  DressTree := FindChildTree(RootChildren, '衣装');
  HairStyleTree := FindChildTree(RootChildren, '髪型');
  BackDecorationTree := FindChildTree(RootChildren, '背中装飾');

  Result :=
    HasChildTrees(TPsdFileTrees(FaceTree.Trees),
      ['デフォルメ', '涙', '口', '目', '眉', '頬', 'その他']) and
    HasChildTrees(TPsdFileTrees(DressTree.Trees),
      ['巡査', 'アイドル衣装', 'どてら', '冬服', '寝間着', '着物', '和装', 'ブラ', 'パンツ']) and
    HasChildTrees(TPsdFileTrees(HairStyleTree.Trees),
      ['おさげ', 'ポニーテール', 'お団子', '通常', 'ツインテール']) and
    HasChildTrees(TPsdFileTrees(BackDecorationTree.Trees),
      ['きりたん砲2', 'きりたん砲', 'ランドセル']);
end;

function HasFurasukoKiritanRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasFurasukoKiritanRootStructure(Tree) then
      Exit(True);

    if HasFurasukoKiritanRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

// 同じ配布PSDでも、読み込み時のグループ階層差で厳密な v1 構造を
// 取得できない場合がある。ふらすこ式きりたん固有のレイヤー名を
// 複数組み合わせ、階層に依存しない第二判定として扱う。
function HasFurasukoKiritanDistinctiveLayers(Trees: TPsdFileTrees): Boolean;
begin
  Result :=
    (Trees <> nil) and
    (FindTreeByName(Trees, 'きりたん砲2') <> nil) and
    (FindTreeByName(Trees, 'ランドセル紐和装用') <> nil) and
    (FindTreeByName(Trees, 'アイドル衣装') <> nil) and
    (FindTreeByName(Trees, 'パジャマ上') <> nil) and
    (FindTreeByName(Trees, 'ツインテール') <> nil) and
    (FindTreeByName(Trees, '感情表現') <> nil) and
    (FindTreeByName(Trees, '背中装飾') <> nil);
end;

function IsFurasukoKiritanPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and
    (HasFurasukoKiritanRoot(PsdImage.Trees) or
     HasFurasukoKiritanDistinctiveLayers(PsdImage.Trees));
end;

function FindFurasukoKiritanRoot(Trees: TPsdFileTrees): TPsdFileTree;
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

    if HasFurasukoKiritanRootStructure(Tree) then
      Exit(Tree);

    Result := FindFurasukoKiritanRoot(TPsdFileTrees(Tree.Trees));
    if Result <> nil then Exit;
  end;
end;

procedure ApplyMarkerToDescendants(Tree: TPsdFileTree; const Marker: Char);
var
  ChildTrees: TPsdFileTrees;
  I: Integer;
begin
  if Tree = nil then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for I := 0 to ChildTrees.Count - 1 do
    if ChildTrees[I] <> nil then
    begin
      ReplaceMarkerOnTree(ChildTrees[I], Marker);
      ApplyMarkerToDescendants(ChildTrees[I], Marker);
    end;
end;

procedure ApplyFurasukoKiritanMarkers(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  FaceTree: TPsdFileTree;
  FacePartTrees: TPsdFileTrees;
  MouthTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  BrowTree: TPsdFileTree;
  UnderlayTree: TPsdFileTree;
  DressTree: TPsdFileTree;
  FlipTree: TPsdFileTree;
  BackDecorationTree: TPsdFileTree;
  BackDecorationParts: TPsdFileTrees;
  I: Integer;
begin
  if PsdImage = nil then Exit;

  RootTree := FindFurasukoKiritanRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  FaceTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '表情');
  if FaceTree = nil then Exit;

  FacePartTrees := TPsdFileTrees(FaceTree.Trees);
  if FacePartTrees = nil then Exit;

  for I := 0 to FacePartTrees.Count - 1 do
    if FacePartTrees[I] <> nil then
      ReplaceMarkerOnTree(FacePartTrees[I], '!');

  // 「口」自体は ! のグループとし、その配下は階層の深さにかかわらず
  // すべて排他候補として扱う。
  MouthTree := FindChildTree(FacePartTrees, '口');
  ApplyMarkerToDescendants(MouthTree, '*');

  EyeTree := FindChildTree(FacePartTrees, '目');
  ApplyMarkerToDescendants(EyeTree, '*');

  BrowTree := FindChildTree(FacePartTrees, '眉');
  ApplyMarkerToDescendants(BrowTree, '*');

  // このPSDが '*' 対応であることを後段へ伝える基準レイヤー。
  // 衣装はここでは無印のまま非表示にし、ApplyVirtualMarker('+') に任せる。
  UnderlayTree := FindChildTree(
    TPsdFileTrees(RootTree.Trees), '出力用下地');
  if UnderlayTree <> nil then
    ReplaceMarkerOnTree(UnderlayTree, '*');

  DressTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '衣装');
  if DressTree <> nil then
  begin
    FlipTree := FindChildTree(
      TPsdFileTrees(DressTree.Trees), '寝間着反転');
    if FlipTree <> nil then
      SetTreeLayerName(FlipTree, '寝間着:flipx');

    FlipTree := FindChildTree(
      TPsdFileTrees(DressTree.Trees), '着物反転');
    if FlipTree <> nil then
      SetTreeLayerName(FlipTree, '着物:flipx');

    FlipTree := FindChildTree(
      TPsdFileTrees(DressTree.Trees), '和装反転');
    if FlipTree <> nil then
      SetTreeLayerName(FlipTree, '和装:flipx');
  end;

  // 背中装飾は同時表示される追加パーツなので、排他候補にしない。
  BackDecorationTree := FindChildTree(
    TPsdFileTrees(RootTree.Trees), '背中装飾');
  if BackDecorationTree <> nil then
  begin
    BackDecorationParts := TPsdFileTrees(BackDecorationTree.Trees);
    if BackDecorationParts <> nil then
      for I := 0 to BackDecorationParts.Count - 1 do
        if BackDecorationParts[I] <> nil then
          ReplaceMarkerOnTree(BackDecorationParts[I], '+');
  end;

  // 汎用の '*' / '+' 補完より前に、PSD固有の初期表示を確定する。
  ApplyFurasukoKiritanInitialVisibility(PsdImage);
end;

procedure HideFurasukoKiritanNamedTrees(Trees: TPsdFileTrees;
  const Name: string);
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

    HideFurasukoKiritanNamedTrees(TPsdFileTrees(Tree.Trees), Name);
  end;
end;

procedure HideFurasukoKiritanChildren(Trees: TPsdFileTrees;
  const ParentName: string; const ChildName: string = '');
var
  I: Integer;
  J: Integer;
  Tree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
begin
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    if SameText(TreeName(Tree), ParentName) then
    begin
      ChildTrees := TPsdFileTrees(Tree.Trees);
      if ChildTrees <> nil then
        for J := 0 to ChildTrees.Count - 1 do
          if (ChildTrees[J] <> nil) and
             ((ChildName = '') or
              SameText(TreeName(ChildTrees[J]), ChildName)) then
            ChildTrees[J].SetVisibleLocal(False);
    end;

    HideFurasukoKiritanChildren(
      TPsdFileTrees(Tree.Trees), ParentName, ChildName);
  end;
end;

procedure MarkFurasukoVisibleChildrenAsInitialDress(
  Trees: TPsdFileTrees; const ParentName: string);
var
  I: Integer;
  J: Integer;
  Tree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    if SameText(TreeName(Tree), ParentName) then
    begin
      ChildTrees := TPsdFileTrees(Tree.Trees);
      if ChildTrees <> nil then
        for J := 0 to ChildTrees.Count - 1 do
        begin
          ChildTree := ChildTrees[J];
          if (ChildTree = nil) or (not ChildTree.Visible) then Continue;

          // PSD 初期状態で表示されている衣装だけを、Face 選択時に
          // 同層から退避する初期服として記録する。表示状態は維持する。
          ReplaceMarkerOnTree(ChildTree, '-');
        end;
    end;

    MarkFurasukoVisibleChildrenAsInitialDress(
      TPsdFileTrees(Tree.Trees), ParentName);
  end;
end;

procedure ApplyFurasukoInitialVisibility(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  // ふらすこ式の別データでも使えるよう、衣装系の代表的な親名を
  // 共通処理し、PSD 初期状態で表示中の直下レイヤーだけを初期服にする。
  MarkFurasukoVisibleChildrenAsInitialDress(PsdImage.Trees, '衣装');
  MarkFurasukoVisibleChildrenAsInitialDress(PsdImage.Trees, '服装');
end;

procedure ApplyFurasukoKiritanInitialVisibility(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  FaceTree: TPsdFileTree;
  PartTree: TPsdFileTree;
  TargetTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  ApplyFurasukoInitialVisibility(PsdImage);
  HideFurasukoKiritanChildren(PsdImage.Trees, '感情表現', '！');
  HideFurasukoKiritanNamedTrees(PsdImage.Trees, 'きりたん砲');
  HideFurasukoKiritanNamedTrees(PsdImage.Trees, 'ランドセル');

  RootTree := FindFurasukoKiritanRoot(PsdImage.Trees);
  if RootTree = nil then Exit;

  FaceTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '表情');
  if FaceTree = nil then Exit;

  PartTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), 'その他');
  if PartTree <> nil then
  begin
    TargetTree := FindChildTree(TPsdFileTrees(PartTree.Trees), '影');
    if TargetTree <> nil then
      TargetTree.SetVisibleLocal(False);
  end;

  PartTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), '涙');
  if PartTree <> nil then
  begin
    TargetTree := FindChildTree(TPsdFileTrees(PartTree.Trees), '涙');
    if TargetTree <> nil then
      TargetTree.SetVisibleLocal(False);
  end;

  PartTree := FindChildTree(TPsdFileTrees(FaceTree.Trees), '頬');
  if PartTree <> nil then
  begin
    TargetTree := FindChildTree(TPsdFileTrees(PartTree.Trees), '通常');
    if TargetTree <> nil then
      TargetTree.SetVisibleLocal(False);
  end;
end;

procedure ApplyFurasukoHoodMarkersToTrees(Trees: TPsdFileTrees);
var
  I: Integer;
  Tree: TPsdFileTree;
  Name: string;
begin
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    Name := TreeName(Tree);
    if SameText(Name, 'フードあり') or SameText(Name, 'フードなし') then
      ReplaceMarkerOnTree(Tree, '*');

    ApplyFurasukoHoodMarkersToTrees(TPsdFileTrees(Tree.Trees));
  end;
end;

procedure ApplyFurasukoMarkers(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  ApplyFurasukoHoodMarkersToTrees(PsdImage.Trees);
  ApplyFurasukoInitialVisibility(PsdImage);
end;

end.
