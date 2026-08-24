unit PSDImageCustomKosukeSantaMaria;

interface

uses
  PsdImage, PSDImageElementList;

function IsKosukeSantaMariaPSD(PsdImage: TPSDImage): Boolean;

procedure ApplyKosukeSantaMariaMarkers(PsdImage: TPSDImage);
procedure ApplyKosukeSantaMariaExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyKosukeSantaMariaInitialVisibility(PsdImage: TPSDImage);
procedure ApplyKosukeSantaMariaElementList(PsdImage: TPSDImage;
  Elements: TPSDElementList);

implementation

uses
  System.SysUtils, Classes, PsdImageTree,
  {$IFDEF DEBUG}PSDImageDebugLog,{$ENDIF}
  PSDImageCustomKarai, PSDImageCustomMarkerUtils;

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

function IsKosukeSantaMariaFileName(const FileName: string): Boolean;
begin
  Result := HasText(FileName, 'こーすけさんたまりあ');
end;

function CountKosukeArmPoseNames(Trees: TPsdFileTrees): Integer;
var
  i: Integer;
  Name: string;
  Tree: TPsdFileTree;
begin
  Result := 0;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    Name := TreeName(Tree);
    if SameText(Name, '通常') or
       SameText(Name, '腰') or
       SameText(Name, 'きゅ') or
       SameText(Name, 'グー') or
       SameText(Name, 'チョキ') or
       SameText(Name, 'パー') or
       SameText(Name, 'お手上げ') or
       SameText(Name, '猫手') or
       SameText(Name, 'つんつん') or
       HasText(Name, '腕組') or
       HasText(Name, 'ばんざい') then
      Inc(Result);
  end;
end;

function CountKosukeArmVariantGroups(Tree: TPsdFileTree): Integer;
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  Result := 0;
  if Tree = nil then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[i];
    if ChildTree = nil then Continue;

    if CountKosukeArmPoseNames(TPsdFileTrees(ChildTree.Trees)) >= 6 then
      Inc(Result);
  end;
end;

function HasKosukeSantaMariaRoot(Trees: TPsdFileTrees): Boolean;
var
  i: Integer;
  Tree: TPsdFileTree;
  RootChildren: TPsdFileTrees;
  DressTree: TPsdFileTree;
  RightArmTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
begin
  Result := False;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    RootChildren := TPsdFileTrees(Tree.Trees);
    if HasChildTrees(RootChildren,
      ['眉', '飾り', '前髪', '口', '目', '服', '右腕', '後髪']) then
    begin
      DressTree := FindChildTree(RootChildren, '服');
      ArmTree := FindChildTree(RootChildren, '腕');
      RightArmTree := FindChildTree(RootChildren, '右腕');

      if (DressTree <> nil) and
         (ArmTree <> nil) and
         (RightArmTree <> nil) and
         (CountKosukeArmVariantGroups(ArmTree) >= 2) and
         (CountKosukeArmVariantGroups(RightArmTree) >= 2) then
        Exit(True);
    end;

    if HasKosukeSantaMariaRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function HasKosukeSantaMariaStructure(PsdImage: TPSDImage): Boolean;
var
  RootTree: TPsdFileTree;
  RootChildren: TPsdFileTrees;
  DressTree: TPsdFileTree;
  RightArmTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
begin
  Result := False;
  if PsdImage = nil then Exit;

  // 旧「東北きりたん 私服(小)」の厳密条件は互換のため残す。
  RootTree := FindTreeByName(PsdImage.Trees, '東北きりたん');
  if RootTree <> nil then
  begin
    RootChildren := TPsdFileTrees(RootTree.Trees);
    if HasChildTrees(RootChildren,
      ['眉', 'アンテナ', '飾り', '前髪', '口', '目', '服', '右腕', '後髪']) then
    begin
      DressTree := FindChildTree(RootChildren, '服');
      RightArmTree := FindChildTree(RootChildren, '右腕');
      ArmTree := FindChildTree(RootChildren, '腕');

      if (DressTree <> nil) and
         (RightArmTree <> nil) and
         HasChildTrees(TPsdFileTrees(DressTree.Trees),
           ['夏服', '冬服', 'サスペンダー', 'バニー', '働いたら負け']) and
         HasChildTrees(TPsdFileTrees(RightArmTree.Trees),
           ['夏服右腕', '冬服右腕', 'サスペンダー右腕']) and
         ((ArmTree = nil) or
          HasChildTrees(TPsdFileTrees(ArmTree.Trees),
            ['夏服腕', '冬服腕', 'サスペンダー腕'])) then
        Exit(True);
    end;
  end;

  Result := HasKosukeSantaMariaRoot(PsdImage.Trees);
end;

function IsKosukeSantaMariaPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and
            (IsKosukeSantaMariaFileName(PsdImage.FileName) or
             HasKosukeSantaMariaStructure(PsdImage));
end;

procedure RemoveKosukeSantaMariaGlassesMarker(PsdImage: TPSDImage);
var
  BangsTree: TPsdFileTree;
  GlassesTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  BangsTree := FindBestNamedTree(PsdImage.Trees, '前髪');
  if BangsTree = nil then Exit;

  GlassesTree := FindChildTree(TPsdFileTrees(BangsTree.Trees), '眼鏡');
  if GlassesTree = nil then Exit;

  // 眼鏡は前髪バリエーションではなく追加装飾なので、前髪候補との排他から外す。
  RemoveMarkerFromTree(GlassesTree);
end;

function IsKosukeSantaMariaRoot(Tree: TPsdFileTree): Boolean;
var
  ChildTrees: TPsdFileTrees;
begin
  Result := False;
  if Tree = nil then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  Result := (FindChildTree(ChildTrees, '腕') <> nil) and
            (FindChildTree(ChildTrees, '右腕') <> nil) and
            (FindChildTree(ChildTrees, '服') <> nil) and
            (FindChildTree(ChildTrees, '目') <> nil);
end;

function FindKosukeSantaMariaRootInTrees(Trees: TPsdFileTrees): TPsdFileTree;
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

    if IsKosukeSantaMariaRoot(Tree) then
      Exit(Tree);

    Result := FindKosukeSantaMariaRootInTrees(TPsdFileTrees(Tree.Trees));
    if Result <> nil then Exit;
  end;
end;

function FindKosukeSantaMariaRoot(PsdImage: TPSDImage): TPsdFileTree;
begin
  Result := nil;
  if PsdImage = nil then Exit;

  Result := FindBestNamedTree(PsdImage.Trees, '東北きりたん');
  if IsKosukeSantaMariaRoot(Result) then Exit;

  Result := FindBestNamedTree(PsdImage.Trees, '立ち絵');
  if IsKosukeSantaMariaRoot(Result) then Exit;

  Result := FindKosukeSantaMariaRootInTrees(PsdImage.Trees);
end;

procedure ReplaceDescendantNamedMarkers(Tree: TPsdFileTree; const Name: string);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if Tree = nil then Exit;

  // こーすけさんたまりあ氏PSDは根元と配下に同名の腕レイヤーがあり、配下側だけ選択候補に戻す。
  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[i];
    if ChildTree = nil then Continue;

    if SameText(TreeName(ChildTree), Name) then
      ReplaceMarkerOnTree(ChildTree, '*');

    ReplaceDescendantNamedMarkers(ChildTree, Name);
  end;
end;

procedure FixKosukeSantaMariaArmMarker(PsdImage: TPSDImage;
  const Name: string);
var
  RootTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  // ルート直下の「腕」「右腕」は基礎表示として ! を維持する。
  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then Exit;

  ArmTree := FindChildTree(TPsdFileTrees(RootTree.Trees), Name);
  if ArmTree = nil then Exit;

  // 根元は基礎表示として残し、配下にある同名レイヤーは候補として扱う。
  ReplaceMarkerOnTree(ArmTree, '!');
  ReplaceDescendantNamedMarkers(ArmTree, Name);
end;

procedure FixKosukeSantaMariaDescendantArmMarker(PsdImage: TPSDImage;
  const RootName, DescendantName: string);
var
  RootTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then Exit;

  ArmTree := FindChildTree(TPsdFileTrees(RootTree.Trees), RootName);
  if ArmTree = nil then Exit;

  // 右腕グループ内に「腕」が出る構造では、その内側の腕も選択候補として扱う。
  ReplaceDescendantNamedMarkers(ArmTree, DescendantName);
end;

procedure FixKosukeSantaMariaArmMarkers(PsdImage: TPSDImage);
begin
  // 同名レイヤーが2階層に出るため、根元=! / 配下=* の役割に分ける。
  FixKosukeSantaMariaArmMarker(PsdImage, '腕');
  FixKosukeSantaMariaArmMarker(PsdImage, '右腕');
  FixKosukeSantaMariaDescendantArmMarker(PsdImage, '右腕', '腕');
end;

procedure FixKosukeSantaMariaMicroBikiniMarker(PsdImage: TPSDImage);
var
  MicroBikiniTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  MicroBikiniTree := FindBestNamedTree(PsdImage.Trees, 'マイクロビキニ');
  if MicroBikiniTree = nil then Exit;

  ReplaceMarkerOnTree(MicroBikiniTree, '!');
end;

procedure FixKosukeSantaMariaSwimsuitMarker(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  DressTree: TPsdFileTree;
  SwimsuitTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then Exit;

  DressTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '服');
  if DressTree = nil then Exit;

  SwimsuitTree := FindChildTree(TPsdFileTrees(DressTree.Trees), '水着');
  if SwimsuitTree = nil then Exit;

  ReplaceMarkerOnTree(SwimsuitTree, '!');
end;

procedure PrepareKosukeSantaMariaAkariJacketOnlyForVirtualMarker(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  DressTree: TPsdFileTree;
  JacketOnlyTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then Exit;

  DressTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '服');
  if DressTree = nil then Exit;

  JacketOnlyTree := FindChildTree(TPsdFileTrees(DressTree.Trees), 'ジャケットのみ');
  if JacketOnlyTree = nil then Exit;

  // 紲星あかりの「ジャケットのみ」は排他服ではなく、上着だけを足すための服装差分。
  // ここでは一度 marker を外して非表示にし、後段の ApplyVirtualMarker('+') で加算候補にする。
  RemoveMarkerFromTree(JacketOnlyTree);
  JacketOnlyTree.SetVisibleLocal(False);
end;

procedure MoveKosukeSantaMariaAkariJacketBackLayer(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  DressTree: TPsdFileTree;
  JacketOnlyTree: TPsdFileTree;
  JacketBackTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then Exit;

  DressTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '服');
  if DressTree = nil then Exit;

  JacketOnlyTree := FindChildTree(TPsdFileTrees(DressTree.Trees), 'ジャケットのみ');
  JacketBackTree := FindChildTree(TPsdFileTrees(DressTree.Trees), 'ジャケット裏');
  if (JacketOnlyTree = nil) or (JacketBackTree = nil) then Exit;

  // 「ジャケット裏」は単独服ではなく、「ジャケットのみ」を選んだ時だけ一緒に出す裏地。
  // + 付与後に移動しないと「ジャケットのみ」が子持ちになり、加算候補化されない。
  RemoveMarkerFromTree(JacketBackTree);
  JacketBackTree.SetVisibleLocal(True);
  PsdImage.MoveTree(JacketBackTree, TPsdFileTrees(JacketOnlyTree.Trees));
end;

procedure HideKosukeSantaMariaAccessoryTree(Tree: TPsdFileTree);
var
  ChildTrees: TPsdFileTrees;
  I: Integer;
begin
  if Tree = nil then Exit;

  Tree.SetVisibleLocal(False);

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for I := 0 to ChildTrees.Count - 1 do
    HideKosukeSantaMariaAccessoryTree(ChildTrees[I]);
end;

procedure PrepareKosukeSantaMariaAccessoriesForVirtualMarker(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  AccessoryTree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  I: Integer;
begin
  if PsdImage = nil then Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then Exit;

  AccessoryTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '飾り');
  if AccessoryTree = nil then Exit;

  ChildTrees := TPsdFileTrees(AccessoryTree.Trees);
  if ChildTrees = nil then Exit;

  // 紲星あかりの飾り配下は元PSDで表示になっている装飾もあるが、初期表示では出さず
  // ApplyVirtualMarker('+') に非表示加算候補として拾わせる。VisibleInit 後にも同じ補正をかける。
  for I := 0 to ChildTrees.Count - 1 do
    HideKosukeSantaMariaAccessoryTree(ChildTrees[I]);
end;

procedure FixKosukeSantaMariaAkariFlipMarker(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  DressTree: TPsdFileTree;
  FlipTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then Exit;

  DressTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '服');
  if DressTree = nil then Exit;

  FlipTree := FindChildTree(TPsdFileTrees(DressTree.Trees), 'あかり反転');
  if FlipTree = nil then Exit;

  SetTreeLayerName(FlipTree, '*あかり:flipx');
end;

procedure FixKosukeSantaMariaHataraitaraMakeMarkers(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
  i: Integer;
  Name: string;
begin
  if PsdImage = nil then Exit;

  RootTree := FindBestNamedTree(PsdImage.Trees, '働いたら負け');
  if RootTree = nil then Exit;

  ChildTrees := TPsdFileTrees(RootTree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[i];
    if ChildTree = nil then Continue;

    Name := TreeName(ChildTree);
    if SameText(Name, '働いたら負け') then
      ReplaceMarkerOnTree(ChildTree, '!')
    else if SameText(Name, 'フォルダー 24') then
      SetTreeLayerName(ChildTree, '*フォルダー 24:flipx')
    else
      ReplaceMarkerOnTree(ChildTree, '*');
  end;
end;

procedure FixKosukeSantaMariaSchoolSwimsuitMarkers(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
  i: Integer;
  Name: string;
begin
  if PsdImage = nil then Exit;

  RootTree := FindBestNamedTree(PsdImage.Trees, 'スク水');
  if RootTree = nil then Exit;

  ChildTrees := TPsdFileTrees(RootTree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[i];
    if ChildTree = nil then Continue;

    Name := TreeName(ChildTree);
    if (not ChildTree.Visible) and SameText(Name, 'レイヤー 168') then
      SetTreeLayerName(ChildTree, '*レイヤー 168:flipx')
    else if SameText(Name, 'スク水') then
      ReplaceMarkerOnTree(ChildTree, '!')
    else
      ReplaceMarkerOnTree(ChildTree, '*');
  end;
end;

procedure FixKosukeSantaMariaEyeMarker(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  BrowTree: TPsdFileTree;
  AntennaTree: TPsdFileTree;
  CheekTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  GrandChildTrees: TPsdFileTrees;
  I: Integer;
  J: Integer;
  ChildTree: TPsdFileTree;
  GrandChildTree: TPsdFileTree;
begin
  if PsdImage = nil then
    Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then
    Exit;

  BrowTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '眉');
  if BrowTree <> nil then
  begin
    ReplaceMarkerOnTree(BrowTree, '!');
    ChildTrees := TPsdFileTrees(BrowTree.Trees);
    if ChildTrees <> nil then
      for I := 0 to ChildTrees.Count - 1 do
      begin
        ChildTree := ChildTrees[I];
        if ChildTree = nil then
          Continue;

        ReplaceMarkerOnTree(ChildTree, '*');
      end;
  end;

  AntennaTree := FindChildTree(TPsdFileTrees(RootTree.Trees), 'アンテナ');
  if AntennaTree <> nil then
  begin
    ReplaceMarkerOnTree(AntennaTree, '!');
    ChildTrees := TPsdFileTrees(AntennaTree.Trees);
    if ChildTrees <> nil then
      for I := 0 to ChildTrees.Count - 1 do
      begin
        ChildTree := ChildTrees[I];
        if ChildTree = nil then
          Continue;

        ReplaceMarkerOnTree(ChildTree, '*');

        GrandChildTrees := TPsdFileTrees(ChildTree.Trees);
        if GrandChildTrees = nil then
          Continue;

        for J := 0 to GrandChildTrees.Count - 1 do
        begin
          GrandChildTree := GrandChildTrees[J];
          if GrandChildTree = nil then
            Continue;

          ReplaceMarkerOnTree(GrandChildTree, '*');
        end;
      end;
  end;

  CheekTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '頬');
  if CheekTree <> nil then
    ReplaceMarkerOnTree(CheekTree, '!');

  MouthTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '口');
  if MouthTree <> nil then
  begin
    ReplaceMarkerOnTree(MouthTree, '!');
    ChildTrees := TPsdFileTrees(MouthTree.Trees);
    if ChildTrees <> nil then
      for I := 0 to ChildTrees.Count - 1 do
      begin
        ChildTree := ChildTrees[I];
        if ChildTree = nil then
          Continue;

        ReplaceMarkerOnTree(ChildTree, '*');
      end;
  end;

  EyeTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '目');
  if EyeTree = nil then
    Exit;

  ReplaceMarkerOnTree(EyeTree, '!');

  ChildTrees := TPsdFileTrees(EyeTree.Trees);
  if ChildTrees = nil then
    Exit;

  for I := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[I];
    if ChildTree = nil then
      Continue;

    ReplaceMarkerOnTree(ChildTree, '*');

    GrandChildTrees := TPsdFileTrees(ChildTree.Trees);
    if GrandChildTrees = nil then
      Continue;

    for J := 0 to GrandChildTrees.Count - 1 do
    begin
      GrandChildTree := GrandChildTrees[J];
      if GrandChildTree = nil then
        Continue;

      ReplaceMarkerOnTree(GrandChildTree, '*');
    end;
  end;
end;

function RuleName(Tree: TPsdFileTree): string;
begin
  Result := '';
  if (Tree = nil) or (Tree.Layer = nil) then
    Exit;

  Result := Trim(Tree.Layer.Name);
  // !右腕を探したいので、仮想補正で付く * / + だけ外し、! は名前の一部として残す。
  while (Result <> '') and CharInSet(Result[1], ['*', '+']) do
    Delete(Result, 1, 1);
end;

function TreeHasText(Tree: TPsdFileTree; const Text: string): Boolean;
begin
  Result := Pos(Text, TreeName(Tree)) > 0;
end;

function FindTreeByRuleName(Trees: TPsdFileTrees;
  const Name: string): TPsdFileTree;
var
  I: Integer;
  Tree: TPsdFileTree;
begin
  Result := nil;
  if Trees = nil then
    Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then
      Continue;

    if SameText(RuleName(Tree), Name) then
      Exit(Tree);

    Result := FindTreeByRuleName(TPsdFileTrees(Tree.Trees), Name);
    if Result <> nil then
      Exit;
  end;
end;

procedure CollectTreeAndChildren(Tree: TPsdFileTree; List: TList);
var
  I: Integer;
  ChildTrees: TPsdFileTrees;
begin
  if (Tree = nil) or (List = nil) then
    Exit;

  if List.IndexOf(Tree) < 0 then
    List.Add(Tree);

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then
    Exit;

  for I := 0 to ChildTrees.Count - 1 do
    CollectTreeAndChildren(ChildTrees[I], List);
end;

procedure CollectBothArmTrees(Trees: TPsdFileTrees; List: TList);
var
  I: Integer;
  Tree: TPsdFileTree;
  InBothArmScope: Boolean;
begin
  if (Trees = nil) or (List = nil) then
    Exit;

  // こーすけさんたまりあ氏PSDでは「両腕」分類の実体が腕配下にあるため、(両)名の実ツリーを拾う。
  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then
      Continue;

    InBothArmScope := TreeHasText(Tree, '(両)') or TreeHasText(Tree, '（両）');
    if InBothArmScope then
      CollectTreeAndChildren(Tree, List)
    else
      CollectBothArmTrees(TPsdFileTrees(Tree.Trees), List);
  end;
end;

function FindChildTreeByRuleName(Trees: TPsdFileTrees;
  const Name: string): TPsdFileTree;
var
  I: Integer;
  Tree: TPsdFileTree;
begin
  Result := nil;
  if Trees = nil then
    Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then
      Continue;

    if SameText(RuleName(Tree), Name) then
      Exit(Tree);
  end;
end;

{$IFDEF DEBUG}
procedure KosukeDressArmDebugLog(const S: string);
begin
  PSDDebugLog('KosukeDressArm', S);
end;

function KosukeDebugTreePath(Tree: TPsdFileTree): string;
var
  I: Integer;
  OwnerTree: TPsdFileTree;
  Name: string;
begin
  Result := '';
  if Tree = nil then
    Exit('<nil>');

  for I := 0 to Tree.Owners.Count - 1 do
  begin
    OwnerTree := TPsdFileTree(Tree.Owners[I]);
    if (OwnerTree = nil) or (OwnerTree.Layer = nil) then
      Continue;

    Name := OwnerTree.Layer.Name;
    if Name = '' then
      Continue;

    if Result <> '' then
      Result := Result + '/';
    Result := Result + Name;
  end;

  if (Tree.Layer <> nil) and (Tree.Layer.Name <> '') then
  begin
    if Result <> '' then
      Result := Result + '/';
    Result := Result + Tree.Layer.Name;
  end;
end;
{$ENDIF}

function KosukeArmGroupNameForDress(const DressName: string): string;
var
  P: Integer;
begin
  Result := Trim(DressName);
  while (Result <> '') and CharInSet(Result[1], ['*', '!', '+']) do
    Delete(Result, 1, 1);
  P := Pos(':', Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1);
  if Result = '' then
    Exit;

  Result := Result + '腕';
end;

function KosukeRightArmGroupNameForDress(const DressName: string): string;
var
  P: Integer;
begin
  Result := Trim(DressName);
  while (Result <> '') and CharInSet(Result[1], ['*', '!', '+']) do
    Delete(Result, 1, 1);
  P := Pos(':', Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1);
  if Result = '' then
    Exit;

  Result := Result + '右腕';
end;

function IsKosukeKiritanRoot(Tree: TPsdFileTree): Boolean;
begin
  Result := (Tree <> nil) and SameText(TreeName(Tree), '東北きりたん');
end;

function UseKosukeBaseArmForDress(const DressName: string): Boolean;
var
  Name: string;
  P: Integer;
begin
  Name := Trim(DressName);
  while (Name <> '') and CharInSet(Name[1], ['*', '!', '+']) do
    Delete(Name, 1, 1);
  P := Pos(':', Name);
  if P > 0 then
    Name := Copy(Name, 1, P - 1);

  Result := SameText(Name, 'スポーツウェア') or
            SameText(Name, 'スポーツウエア') or
            SameText(Name, 'ヨガウェア') or
            SameText(Name, 'ヨガウエア') or
            SameText(Name, 'バスタオル') or
            SameText(Name, '下着') or
            SameText(Name, '夏服') or
            SameText(Name, '競泳水着');
end;

function FindKosukeBaseArmTree(ArmRootTree: TPsdFileTree): TPsdFileTree;
var
  ChildTrees: TPsdFileTrees;
begin
  Result := nil;
  if ArmRootTree = nil then
    Exit;

  ChildTrees := TPsdFileTrees(ArmRootTree.Trees);
  if ChildTrees = nil then
    Exit;

  Result := FindChildTreeByRuleName(ChildTrees, TreeName(ArmRootTree));
  if (Result = nil) and SameText(TreeName(ArmRootTree), '右腕') then
    Result := FindChildTreeByRuleName(ChildTrees, '腕');
  if (Result = nil) and SameText(TreeName(ArmRootTree), '腕') then
    Result := FindChildTreeByRuleName(ChildTrees, '右腕');
end;

function IsKosukeRightArmHelperTree(Tree: TPsdFileTree): Boolean;
var
  Name: string;
begin
  Name := TreeName(Tree);
  Result := HasText(Name, '(右)') or HasText(Name, '（右）');
end;

procedure CollectKosukeRightArmHelperTrees(Tree: TPsdFileTree; List: TList);
var
  I: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if (Tree = nil) or (List = nil) then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for I := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[I];
    if (ChildTree <> nil) and IsKosukeRightArmHelperTree(ChildTree) then
      List.Add(ChildTree);
  end;
end;

procedure ApplyKosukeKiritanRightArmHelperRules(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  RootChildren: TPsdFileTrees;
  ArmRootTree: TPsdFileTree;
  RightArmRootTree: TPsdFileTree;
  ArmBaseTree: TPsdFileTree;
  RightArmBaseTree: TPsdFileTree;
  RightArmBaseChildren: TPsdFileTrees;
  HelperTrees: TList;
  I: Integer;
  J: Integer;
  HelperTree: TPsdFileTree;
  OtherHelperTree: TPsdFileTree;
  RightArmChildTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if not IsKosukeKiritanRoot(RootTree) then Exit;

  RootChildren := TPsdFileTrees(RootTree.Trees);
  ArmRootTree := FindChildTree(RootChildren, '腕');
  RightArmRootTree := FindChildTree(RootChildren, '右腕');
  if (ArmRootTree = nil) or (RightArmRootTree = nil) then Exit;

  ArmBaseTree := FindKosukeBaseArmTree(ArmRootTree);
  RightArmBaseTree := FindKosukeBaseArmTree(RightArmRootTree);
  if (ArmBaseTree = nil) or (RightArmBaseTree = nil) then Exit;

  RightArmBaseChildren := TPsdFileTrees(RightArmBaseTree.Trees);
  if RightArmBaseChildren = nil then Exit;

  HelperTrees := TList.Create;
  try
    CollectKosukeRightArmHelperTrees(ArmBaseTree, HelperTrees);

    for I := 0 to HelperTrees.Count - 1 do
    begin
      HelperTree := TPsdFileTree(HelperTrees[I]);
      PsdImage.AddVisibilityRule(HelperTree, RightArmBaseTree, False);

      for J := 0 to HelperTrees.Count - 1 do
      begin
        OtherHelperTree := TPsdFileTree(HelperTrees[J]);
        if OtherHelperTree <> HelperTree then
          PsdImage.AddVisibilityRule(HelperTree, OtherHelperTree, False);
      end;

      for J := 0 to RightArmBaseChildren.Count - 1 do
      begin
        RightArmChildTree := RightArmBaseChildren[J];
        if RightArmChildTree = nil then Continue;

        PsdImage.AddVisibilityRule(HelperTree, RightArmChildTree, False);
        PsdImage.AddVisibilityRule(RightArmChildTree, HelperTree, False);
      end;
    end;
  finally
    HelperTrees.Free;
  end;
end;

procedure AddKosukeDressArmRule(PsdImage: TPSDImage; TriggerTree,
  ArmRootTree: TPsdFileTree; const DressName: string;
  FallbackToBaseArm: Boolean);
var
  I: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
  TargetTree: TPsdFileTree;
begin
  if (PsdImage = nil) or (TriggerTree = nil) or (ArmRootTree = nil) then
    Exit;

  ChildTrees := TPsdFileTrees(ArmRootTree.Trees);
  TargetTree := FindChildTreeByRuleName(ChildTrees, KosukeArmGroupNameForDress(DressName));
  if (TargetTree = nil) and SameText(TreeName(ArmRootTree), '右腕') then
    TargetTree := FindChildTreeByRuleName(ChildTrees, KosukeRightArmGroupNameForDress(DressName));
  if (TargetTree = nil) and UseKosukeBaseArmForDress(DressName) then
    TargetTree := FindKosukeBaseArmTree(ArmRootTree);
  if (TargetTree = nil) and FallbackToBaseArm then
    TargetTree := FindChildTreeByRuleName(ChildTrees, TreeName(ArmRootTree));
  if (ChildTrees = nil) or (TargetTree = nil) then
  begin
    {$IFDEF DEBUG}
    KosukeDressArmDebugLog(Format(
      'rule skip trigger="%s" armRoot="%s" dress="%s" target="%s"',
      [KosukeDebugTreePath(TriggerTree), KosukeDebugTreePath(ArmRootTree),
       DressName, KosukeArmGroupNameForDress(DressName)]));
    {$ENDIF}
    Exit;
  end;

  // 表示連動は SetVisibleLocal なので、同階層の排他は明示的に落とす。
  for I := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[I];
    if ChildTree = nil then
      Continue;

    PsdImage.AddVisibilityRule(TriggerTree, ChildTree, ChildTree = TargetTree);
  end;

  {$IFDEF DEBUG}
  KosukeDressArmDebugLog(Format(
    'rule add trigger="%s" armRoot="%s" dress="%s" target="%s" siblings=%d',
    [KosukeDebugTreePath(TriggerTree), KosukeDebugTreePath(ArmRootTree),
     DressName, KosukeDebugTreePath(TargetTree), ChildTrees.Count]));
  {$ENDIF}
end;

procedure AddKosukeDressArmRuleToTreeAndChildren(PsdImage: TPSDImage;
  TriggerTree, ArmTree, RightArmTree: TPsdFileTree; const DressName: string;
  FallbackToBaseArm: Boolean);
var
  I: Integer;
  ChildTrees: TPsdFileTrees;
begin
  if TriggerTree = nil then
    Exit;

  AddKosukeDressArmRule(PsdImage, TriggerTree, ArmTree, DressName,
    FallbackToBaseArm);
  AddKosukeDressArmRule(PsdImage, TriggerTree, RightArmTree, DressName,
    FallbackToBaseArm);

  ChildTrees := TPsdFileTrees(TriggerTree.Trees);
  if ChildTrees = nil then
    Exit;

  for I := 0 to ChildTrees.Count - 1 do
    AddKosukeDressArmRuleToTreeAndChildren(PsdImage, ChildTrees[I],
      ArmTree, RightArmTree, DressName, FallbackToBaseArm);
end;

procedure ApplyKosukeSantaMariaDressArmRules(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  RootChildren: TPsdFileTrees;
  DressTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
  RightArmTree: TPsdFileTree;
  DressChildren: TPsdFileTrees;
  I: Integer;
  DressPartTree: TPsdFileTree;
  DressName: string;
  FallbackToBaseArm: Boolean;
begin
  if PsdImage = nil then
    Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then
    Exit;

  RootChildren := TPsdFileTrees(RootTree.Trees);
  DressTree := FindChildTree(RootChildren, '服');
  ArmTree := FindChildTree(RootChildren, '腕');
  if DressTree = nil then
    Exit;

  // このPSDの右腕分類は「服」の子ではなく、服と同じ階層にある。
  RightArmTree := FindChildTree(RootChildren, '右腕');
  DressChildren := TPsdFileTrees(DressTree.Trees);
  if DressChildren = nil then
    Exit;

  FallbackToBaseArm := IsKosukeKiritanRoot(RootTree);

  for I := 0 to DressChildren.Count - 1 do
  begin
    DressPartTree := DressChildren[I];
    if DressPartTree = nil then
      Continue;

    DressName := TreeName(DressPartTree);
    if SameText(DressName, '頭') or SameText(DressName, '右腕') then
      Continue;

    AddKosukeDressArmRuleToTreeAndChildren(PsdImage, DressPartTree,
      ArmTree, RightArmTree, DressName, FallbackToBaseArm);
  end;
end;

procedure ApplyKosukeSantaMariaMarkers(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  ApplyKaraiMarkers(PsdImage);
  RemoveKosukeSantaMariaGlassesMarker(PsdImage);
  FixKosukeSantaMariaArmMarkers(PsdImage);
  FixKosukeSantaMariaMicroBikiniMarker(PsdImage);
  FixKosukeSantaMariaSwimsuitMarker(PsdImage);
  PrepareKosukeSantaMariaAkariJacketOnlyForVirtualMarker(PsdImage);
  PrepareKosukeSantaMariaAccessoriesForVirtualMarker(PsdImage);
  FixKosukeSantaMariaAkariFlipMarker(PsdImage);
  FixKosukeSantaMariaHataraitaraMakeMarkers(PsdImage);
  FixKosukeSantaMariaSchoolSwimsuitMarkers(PsdImage);
  FixKosukeSantaMariaEyeMarker(PsdImage);
end;

procedure ApplyKosukeSantaMariaExclusiveGroups(PsdImage: TPSDImage);
var
  RightArmHideTree: TPsdFileTree;
  BothArmTrees: TList;
  I: Integer;
  BothArmTree: TPsdFileTree;
begin
  if PsdImage = nil then
    Exit;

  ApplyKosukeSantaMariaDressArmRules(PsdImage);
  ApplyKosukeKiritanRightArmHelperRules(PsdImage);

  // (両)付き腕をONにした時だけ、基礎表示の !右腕 を強制OFFにする。
  RightArmHideTree := FindTreeByRuleName(PsdImage.Trees, '!右腕');
  if RightArmHideTree = nil then
    Exit;

  BothArmTrees := TList.Create;
  try
    CollectBothArmTrees(PsdImage.Trees, BothArmTrees);

    for I := 0 to BothArmTrees.Count - 1 do
    begin
      BothArmTree := TPsdFileTree(BothArmTrees[I]);
      PsdImage.AddVisibilityRule(BothArmTree, RightArmHideTree, False);
    end;
  finally
    BothArmTrees.Free;
  end;
end;

function CleanKosukeElementListName(const Name: string): string;
begin
  Result := Trim(Name);
  while (Result <> '') and CharInSet(Result[1], ['*', '!', '+']) do
    Delete(Result, 1, 1);
end;

function KosukeElementListLeafName(const RouteName: string): string;
var
  P: Integer;
begin
  Result := Trim(RouteName);
  P := LastDelimiter('/', Result);
  if P > 0 then
    Result := Copy(Result, P + 1, MaxInt);
end;

function IsKosukeRightArmBothArmHelperPart(const PartName: string): Boolean;
var
  Name: string;
begin
  Name := CleanKosukeElementListName(PartName);
  // 紲星あかりの !右腕 側には「※腕組(両)」のような両腕用の補助レイヤーがある。
  // これは !両腕 の選択肢として見せる本体ではなく、服別の両腕レイヤー側から制御させる。
  Result := (Name <> '') and
            (Name[1] = '※') and
            ((Pos('(両)', Name) > 0) or (Pos('（両）', Name) > 0));
end;

function IsKosukeArmElement(Element: TPSDElementItem): Boolean;
var
  Name: string;
begin
  Result := False;
  if Element = nil then
    Exit;

  Name := CleanKosukeElementListName(Element.Name);
  Result := SameText(Name, '腕') or
            SameText(Name, '右腕') or
            SameText(Name, '両腕');
end;

procedure NormalizeKosukeArmElementParts(Element: TPSDElementItem);
var
  I: Integer;
  Part: TPSDElementPart;
  LeafName: string;
  IsBothArmElement: Boolean;
  SeenNames: TStringList;
begin
  if (Element = nil) or (Element.Parts = nil) then
    Exit;

  IsBothArmElement := SameText(CleanKosukeElementListName(Element.Name), '両腕');

  SeenNames := TStringList.Create;
  try
    SeenNames.Sorted := True;
    SeenNames.Duplicates := dupIgnore;
    SeenNames.CaseSensitive := False;

    for I := Element.Parts.Count - 1 downto 0 do
    begin
      Part := Element.Parts[I];
      if Part = nil then
        Continue;

      LeafName := KosukeElementListLeafName(Part.Name);
      if LeafName = '' then
        Continue;

      if IsBothArmElement and IsKosukeRightArmBothArmHelperPart(LeafName) then
      begin
        Element.Parts.Delete(I);
        Continue;
      end;

      if SeenNames.IndexOf(LeafName) >= 0 then
        Element.Parts.Delete(I)
      else
      begin
        SeenNames.Add(LeafName);
        Part.Name := LeafName;
        Part.Caption := LeafName;
      end;
    end;
  finally
    SeenNames.Free;
  end;
end;

{$IFDEF DEBUG}
procedure DebugKosukeArmElement(Element: TPSDElementItem);
var
  I: Integer;
  Part: TPSDElementPart;
begin
  if (Element = nil) or (Element.Parts = nil) then Exit;

  KosukeDressArmDebugLog(Format(
    'element group="%s" name="%s" caption="%s" tree="%s" parts=%d',
    [Element.Group, Element.Name, Element.Caption,
     KosukeDebugTreePath(Element.Tree), Element.Parts.Count]));

  for I := 0 to Element.Parts.Count - 1 do
  begin
    Part := Element.Parts[I];
    if Part = nil then Continue;

    KosukeDressArmDebugLog(Format(
      '  part[%d] name="%s" caption="%s" layerIndex=%d',
      [I, Part.Name, Part.Caption, Part.LayerIndex]));
  end;
end;
{$ENDIF}

procedure ApplyKosukeSantaMariaElementList(PsdImage: TPSDImage;
  Elements: TPSDElementList);
var
  I: Integer;
  Element: TPSDElementItem;
begin
  if (PsdImage = nil) or (Elements = nil) then
    Exit;

  // 腕系の小分類は服装腕グループを含めず末端ポーズ名だけにする。
  // 同名候補は ElementRoute 側の候補スコアで現在服装に近い実レイヤーが選ばれる。
  for I := 0 to Elements.Count - 1 do
  begin
    Element := Elements[I];
    if IsKosukeArmElement(Element) then
    begin
      NormalizeKosukeArmElementParts(Element);
      {$IFDEF DEBUG}
      DebugKosukeArmElement(Element);
      {$ENDIF}
    end;
  end;
end;

procedure HideKosukeSantaMariaTwinCoordinateChildren(RootTree: TPsdFileTree;
  const GroupName: string);
var
  GroupTree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  I: Integer;
  ChildTree: TPsdFileTree;
begin
  if RootTree = nil then
    Exit;

  GroupTree := FindChildTree(TPsdFileTrees(RootTree.Trees), GroupName);
  if GroupTree = nil then
    Exit;

  ChildTrees := TPsdFileTrees(GroupTree.Trees);
  if ChildTrees = nil then
    Exit;

  for I := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[I];
    if ChildTree = nil then
      Continue;

    if Pos('双子コーデ', TreeName(ChildTree)) = 1 then
      ChildTree.SetVisibleLocal(False);
  end;
end;

procedure ApplyKosukeSantaMariaTwinCoordinateInitialVisibility(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
begin
  if PsdImage = nil then
    Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then
    Exit;

  HideKosukeSantaMariaTwinCoordinateChildren(RootTree, '服');
  HideKosukeSantaMariaTwinCoordinateChildren(RootTree, '腕');
  HideKosukeSantaMariaTwinCoordinateChildren(RootTree, '右腕');
end;

procedure ShowKosukeSantaMariaSameNamedArmChild(RootTree: TPsdFileTree;
  const GroupName: string);
var
  GroupTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
begin
  if RootTree = nil then
    Exit;

  GroupTree := FindChildTree(TPsdFileTrees(RootTree.Trees), GroupName);
  if GroupTree = nil then
    Exit;

  ArmTree := FindChildTree(TPsdFileTrees(GroupTree.Trees), GroupName);
  if ArmTree = nil then
    Exit;

  ArmTree.SetVisibleLocal(True);
end;

procedure ApplyKosukeSantaMariaArmInitialVisibility(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
begin
  if PsdImage = nil then
    Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then
    Exit;

  ShowKosukeSantaMariaSameNamedArmChild(RootTree, '腕');
  ShowKosukeSantaMariaSameNamedArmChild(RootTree, '右腕');
end;

procedure ApplyKosukeSantaMariaInitialVisibility(PsdImage: TPSDImage);
var
  RootTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  I: Integer;
  ChildTree: TPsdFileTree;
begin
  if PsdImage = nil then
    Exit;

  RootTree := FindKosukeSantaMariaRoot(PsdImage);
  if RootTree = nil then
    Exit;

  PrepareKosukeSantaMariaAccessoriesForVirtualMarker(PsdImage);
  MoveKosukeSantaMariaAkariJacketBackLayer(PsdImage);
  ApplyKosukeSantaMariaTwinCoordinateInitialVisibility(PsdImage);
  ApplyKosukeSantaMariaArmInitialVisibility(PsdImage);

  EyeTree := FindChildTree(TPsdFileTrees(RootTree.Trees), '目');
  if EyeTree = nil then
    Exit;

  ChildTrees := TPsdFileTrees(EyeTree.Trees);
  if ChildTrees = nil then
    Exit;

  // 目配下は「通常」を初期表示の基準にし、それ以外の派生差分は閉じた状態で始める。
  for I := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[I];
    if ChildTree = nil then
      Continue;

    ChildTree.SetVisibleLocal(
      SameText(TreeName(ChildTree), '通常') or
      SameText(TreeName(ChildTree), '目茜'));
  end;
end;

end.
