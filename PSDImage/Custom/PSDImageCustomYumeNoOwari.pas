unit PSDImageCustomYumeNoOwari;

interface

uses
  PsdImage, PSDImageElementList;

function IsYumeNoOwariFileName(const FileName: string): Boolean;
function HasYumeNoOwariStructure(PsdImage: TPSDImage): Boolean;
function HasYumeNoOwariKiritanSuwariEStructure(PsdImage: TPSDImage): Boolean;
procedure ApplyYumeNoOwariMarkers(PsdImage: TPSDImage);
procedure ApplyYumeNoOwariKiritanSuwariEExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyYumeNoOwariInitialVisibility(PsdImage: TPSDImage);
procedure ApplyYumeNoOwariKiritanSuwariEInitialVisibility(PsdImage: TPSDImage);
procedure ApplyYumeNoOwariElementCaptions(Elements: TPSDElementList);

implementation

uses
  System.SysUtils, System.Generics.Collections, PsdImageTree,
  {$IFDEF DEBUG}PSDImageDebugLog,{$ENDIF}
  PSDImageCustomMarkerUtils;

const
  YUME_NO_OWARI_POSE = 'ポーズ';

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

function HasYumeNoOwariAuthorTag(const S: string): Boolean;
begin
  Result :=
    HasText(S, '（ユメのオワリ）') or
    HasText(S, '(ユメのオワリ)');
end;

function IsYumeNoOwariFileName(const FileName: string): Boolean;
var
  Name: string;
begin
  Name := ChangeFileExt(ExtractFileName(FileName), '');
  Result := HasYumeNoOwariAuthorTag(Name);
end;

function HasYumeNoOwariEffectRoot(Trees: TPsdFileTrees): Boolean;
var
  I: Integer;
  Tree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
begin
  Result := False;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    ChildTrees := TPsdFileTrees(Tree.Trees);
    if SameText(TreeName(Tree), '効果') and
       HasChildTrees(ChildTrees, ['はぁはぁ', 'あせあせ', 'Σ']) then
      Exit(True);

    if HasYumeNoOwariEffectRoot(ChildTrees) then
      Exit(True);
  end;
end;

function HasYumeNoOwariExpressionRoot(Trees: TPsdFileTrees): Boolean;
var
  I: Integer;
  Tree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  FaceSetTree: TPsdFileTree;
  FacePartsTree: TPsdFileTree;
begin
  Result := False;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    ChildTrees := TPsdFileTrees(Tree.Trees);
    if HasText(TreeName(Tree), '表情') and
       HasChildTrees(ChildTrees, ['表情セット', '表情バラ']) then
    begin
      FaceSetTree := FindChildTree(ChildTrees, '表情セット');
      FacePartsTree := FindChildTree(ChildTrees, '表情バラ');

      if (FaceSetTree <> nil) and (FacePartsTree <> nil) and
         (CountChildTrees(TPsdFileTrees(FaceSetTree.Trees)) >= 20) and
         (CountChildTreesWithText(TPsdFileTrees(FaceSetTree.Trees), 'こっち') >= 5) and
         HasChildTrees(TPsdFileTrees(FacePartsTree.Trees), ['眉', '目', '口']) then
        Exit(True);
    end;

    if HasYumeNoOwariExpressionRoot(ChildTrees) then
      Exit(True);
  end;
end;

function HasYumeNoOwariStructure(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and
            HasYumeNoOwariEffectRoot(PsdImage.Trees) and
            HasYumeNoOwariExpressionRoot(PsdImage.Trees);
end;

function HasYumeNoOwariKiritanSuwariERootStructure(
  Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  EffectTree: TPsdFileTree;
  PoseTree: TPsdFileTree;
  PoseChildren: TPsdFileTrees;
  FaceTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;
  if not SameText(TreeName(Tree), 'きりたん') then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren, ['効果', 'ポーズ1']) then
    Exit;

  EffectTree := FindChildTree(RootChildren, '効果');
  PoseTree := FindChildTree(RootChildren, 'ポーズ1');

  if not HasChildTrees(TPsdFileTrees(EffectTree.Trees),
    ['きらーん', 'ムカッ', 'ざーこ', 'ビュフ']) then
    Exit;

  PoseChildren := TPsdFileTrees(PoseTree.Trees);
  if not HasChildTrees(PoseChildren, ['表情', 'あほ毛', '本体']) then
    Exit;

  FaceTree := FindChildTree(PoseChildren, '表情');
  BodyTree := FindChildTree(PoseChildren, '本体');

  Result :=
    HasChildTrees(TPsdFileTrees(FaceTree.Trees),
      ['簡易表情セット', '眉', '目', '口', '鼻', '頬']) and
    HasChildTrees(TPsdFileTrees(BodyTree.Trees),
      ['本体はいてない', '本体ゲームはいてない包丁下']);
end;

function HasYumeNoOwariKiritanSuwariERoot(
  Trees: TPsdFileTrees): Boolean;
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

    if HasYumeNoOwariKiritanSuwariERootStructure(Tree) then
      Exit(True);

    if HasYumeNoOwariKiritanSuwariERoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function HasYumeNoOwariKiritanSuwariEStructure(
  PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and
            HasYumeNoOwariKiritanSuwariERoot(PsdImage.Trees);
end;

function CleanElementName(const AName: string): string;
begin
  Result := Trim(AName);
  while (Result <> '') and CharInSet(Result[1], ['*', '!', '+']) do
    Delete(Result, 1, 1);
end;

function LastCleanRouteName(const AName: string): string;
var
  Parts: TArray<string>;
begin
  Result := CleanElementName(AName);
  Parts := Result.Split(['/']);
  if Length(Parts) > 0 then
    Result := CleanElementName(Parts[High(Parts)]);
end;

function IsPoseName(const AName: string): Boolean;
var
  Name: string;
begin
  Name := CleanElementName(AName);
  Result := SameText(Copy(Name, 1, Length(YUME_NO_OWARI_POSE)),
    YUME_NO_OWARI_POSE);
end;

function HasPoseRoute(const AName: string): Boolean;
var
  Part: string;
  Parts: TArray<string>;
begin
  Result := False;
  Parts := AName.Split(['/']);
  for Part in Parts do
    if IsPoseName(Part) then
      Exit(True);
end;

function IsYumeNoOwariAttachElement(Element: TPSDElementItem;
  const BodyToken: string): Boolean;
begin
  Result := (Element <> nil) and
    (HasText(Element.Caption, BodyToken) or
     HasText(Element.Name, BodyToken) or
     HasText(Element.Group, BodyToken)) and
    (HasText(Element.Caption, 'くっつく') or
     HasText(Element.Caption, 'ひっつく') or
     HasText(Element.Name, 'くっつく') or
     HasText(Element.Name, 'ひっつく') or
     HasText(Element.Group, 'くっつく') or
     HasText(Element.Group, 'ひっつく'));
end;

function HasYumeNoOwariElementText(Element: TPSDElementItem;
  const Token: string): Boolean;
begin
  Result := (Element <> nil) and
    (HasText(Element.Caption, Token) or
     HasText(Element.Name, Token) or
     HasText(Element.Group, Token));
end;

function IsYumeNoOwariTopLevelElement(Element: TPSDElementItem): Boolean;
begin
  Result := (Element <> nil) and (Trim(Element.Group) = '');
end;

function IsYumeNoOwariTopLevelAttachElement(Element: TPSDElementItem;
  const BodyToken: string): Boolean;
begin
  Result := IsYumeNoOwariTopLevelElement(Element) and
    (HasText(Element.Caption, BodyToken) or
     HasText(Element.Name, BodyToken)) and
    (HasText(Element.Caption, 'くっつく') or
     HasText(Element.Caption, 'ひっつく') or
     HasText(Element.Name, 'くっつく') or
     HasText(Element.Name, 'ひっつく'));
end;

{$IFDEF DEBUG}
procedure YumeNoOwariDebugLog(const S: string);
begin
  PSDDebugLog('YumeNoOwariElement', S);
end;

function DebugElementText(Element: TPSDElementItem): string;
begin
  if Element = nil then
    Exit('<nil>');

  Result := Format('Group="%s" Name="%s" Caption="%s" Parts=%d',
    [Element.Group, Element.Name, Element.Caption, Element.Parts.Count]);
end;

procedure DebugYumeNoOwariElementOrder(Elements: TPSDElementList;
  const Stage: string);
var
  I: Integer;
  Element: TPSDElementItem;
begin
  if Elements = nil then
  begin
    YumeNoOwariDebugLog(Stage + ' Elements=<nil>');
    Exit;
  end;

  YumeNoOwariDebugLog(Format('%s Elements=%d', [Stage, Elements.Count]));
  for I := 0 to Elements.Count - 1 do
  begin
    Element := Elements[I];
    if IsYumeNoOwariAttachElement(Element, '下半身') or
       IsYumeNoOwariAttachElement(Element, '上半身') or
       HasYumeNoOwariElementText(Element, 'アクセサリー後ろ') or
       HasYumeNoOwariElementText(Element, 'スカートをめくる時のみ') then
      YumeNoOwariDebugLog(Format('  [%d] %s', [I, DebugElementText(Element)]));
  end;
end;
{$ENDIF}

function FindYumeNoOwariLowerAttachInsertIndex(
  Elements: TPSDElementList): Integer;
var
  I: Integer;
begin
  Result := -1;
  if Elements = nil then Exit;

  for I := 0 to Elements.Count - 1 do
    if IsYumeNoOwariTopLevelAttachElement(Elements[I], '上半身') then
      Exit(I);

  for I := 0 to Elements.Count - 1 do
    if IsYumeNoOwariTopLevelElement(Elements[I]) and
       HasYumeNoOwariElementText(Elements[I], 'アクセサリー後ろ') then
      Exit(I);

  for I := 0 to Elements.Count - 1 do
    if IsYumeNoOwariTopLevelElement(Elements[I]) and
       HasYumeNoOwariElementText(Elements[I], 'スカートをめくる時のみ') then
      Exit(I + 1);

  Result := Elements.Count;
end;

procedure MoveYumeNoOwariLowerAttachElementsNearUpper(
  Elements: TPSDElementList);
var
  I: Integer;
  InsertIndex: Integer;
  Element: TPSDElementItem;
  MoveElements: TList<TPSDElementItem>;
  {$IFDEF DEBUG}
  MoveCount: Integer;
  {$ENDIF}
begin
  if Elements = nil then Exit;

  {$IFDEF DEBUG}
  MoveCount := 0;
  DebugYumeNoOwariElementOrder(Elements, 'Before lower attach move');
  {$ENDIF}

  InsertIndex := FindYumeNoOwariLowerAttachInsertIndex(Elements);
  if InsertIndex < 0 then Exit;

  MoveElements := TList<TPSDElementItem>.Create;
  try
    I := 0;
    while (I < InsertIndex) and (I < Elements.Count) do
    begin
      Element := Elements[I];
      if IsYumeNoOwariAttachElement(Element, '下半身') then
      begin
        {$IFDEF DEBUG}
        YumeNoOwariDebugLog(Format('lower attach candidate index=%d insertIndex=%d %s',
          [I, InsertIndex, DebugElementText(Element)]));
        {$ENDIF}
        MoveElements.Add(Element);
        Elements.Extract(Element);
        Dec(InsertIndex);
        Continue;
      end;

      Inc(I);
    end;

    if InsertIndex < 0 then
      InsertIndex := 0;
    if InsertIndex > Elements.Count then
      InsertIndex := Elements.Count;

    for I := 0 to MoveElements.Count - 1 do
    begin
      Elements.Insert(InsertIndex, MoveElements[I]);
      Inc(InsertIndex);
      {$IFDEF DEBUG}
      Inc(MoveCount);
      {$ENDIF}
    end;
  finally
    MoveElements.Free;
  end;

  {$IFDEF DEBUG}
  YumeNoOwariDebugLog(Format('Move result moved=%d', [MoveCount]));
  DebugYumeNoOwariElementOrder(Elements, 'After lower attach move');
  {$ENDIF}
end;

procedure ApplyMarkerToNamedTrees(Trees: TPsdFileTrees; const Name: string;
  const Marker: Char); overload;
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    if SameText(TreeName(Tree), Name) then
      ApplyMarkerToTree(Tree, Marker);

    ApplyMarkerToNamedTrees(TPsdFileTrees(Tree.Trees), Name, Marker);
  end;
end;

procedure ApplyMarkerToNamedTrees(Trees: TPsdFileTrees; const Name: string;
  const Marker: Char; StopPrefix: string); overload;
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    if SameText(TreeName(Tree), Name) then
      ApplyMarkerToTree(Tree, Marker);

    if (StopPrefix <> '') and
       SameText(Copy(TreeName(Tree), 1, Length(StopPrefix)), StopPrefix) then
      Continue;

    ApplyMarkerToNamedTrees(TPsdFileTrees(Tree.Trees), Name, Marker, StopPrefix);
  end;
end;

procedure ApplyMarkerToPrefixNamedTrees(Trees: TPsdFileTrees; const Prefix: string;
  const Marker: Char);
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
    if SameText(Copy(Name, 1, Length(Prefix)), Prefix) then
      ApplyMarkerToTree(Tree, Marker);

    ApplyMarkerToPrefixNamedTrees(TPsdFileTrees(Tree.Trees), Prefix, Marker);
  end;
end;

procedure ApplyMarkerToChildrenOfNamedTrees(Trees: TPsdFileTrees;
  const ParentName: string; const Marker: Char; StopPrefix: string = '');
var
  i: Integer;
  j: Integer;
  Tree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    ChildTrees := TPsdFileTrees(Tree.Trees);
    if SameText(TreeName(Tree), ParentName) and (ChildTrees <> nil) then
      for j := 0 to ChildTrees.Count - 1 do
        ApplyMarkerToTree(ChildTrees[j], Marker);

    if (StopPrefix <> '') and
       SameText(Copy(TreeName(Tree), 1, Length(StopPrefix)), StopPrefix) then
      Continue;

    ApplyMarkerToChildrenOfNamedTrees(ChildTrees, ParentName, Marker, StopPrefix);
  end;
end;

procedure ApplyMarkerToPoseOptionTrees(Trees: TPsdFileTrees);
var
  i: Integer;
  j: Integer;
  Tree: TPsdFileTree;
  ChildTree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  Name: string;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    ChildTrees := TPsdFileTrees(Tree.Trees);
    if SameText(Copy(TreeName(Tree), 1, Length(YUME_NO_OWARI_POSE)),
       YUME_NO_OWARI_POSE) and (ChildTrees <> nil) then
      for j := 0 to ChildTrees.Count - 1 do
      begin
        ChildTree := ChildTrees[j];
        if ChildTree = nil then Continue;

        Name := TreeName(ChildTree);
        if SameText(Name, '服') or SameText(Name, '薄着') then
          ApplyMarkerToTree(ChildTree, '*');

        if SameText(TreeName(Tree), 'ポーズ5') and SameText(Name, '右手') then
          ApplyMarkerToTree(ChildTree, '*');
      end;

    ApplyMarkerToPoseOptionTrees(ChildTrees);
  end;
end;

function ContainsChildTree(Trees: TPsdFileTrees; const Name: string): Boolean;
begin
  Result := FindChildTree(Trees, Name) <> nil;
end;

procedure SetNamedChildrenInvisible(Trees: TPsdFileTrees;
  const Names: array of string);
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
        Tree.SetVisibleLocal(False);
        Break;
      end;
  end;
end;

function HideYumeNoOwariRootOptionTrees(Trees: TPsdFileTrees): Boolean;
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  Result := False;
  if Trees = nil then Exit;

  if ContainsChildTree(Trees, YUME_NO_OWARI_POSE) then
  begin
    SetNamedChildrenInvisible(Trees, [
      '手',
      'ラキストン',
      'エレキギター',
      'ギター',
      'ストラップ'
    ]);
    Exit(True);
  end;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    if HideYumeNoOwariRootOptionTrees(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

procedure ApplyYumeNoOwariMarkers(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  ApplyMarkerToPoseOptionTrees(PsdImage.Trees);
  ApplyMarkerToNamedTrees(PsdImage.Trees, '団子', '*');
  ApplyMarkerToNamedTrees(PsdImage.Trees, '団子飛ぶ', '*');
  //ApplyMarkerToNamedTrees(PsdImage.Trees, 'エレキギター', '*');
  ApplyMarkerToNamedTrees(PsdImage.Trees, '手', '*', 'ポーズ');
  ApplyMarkerToPrefixNamedTrees(PsdImage.Trees, 'ポーズ', '*');
  ApplyMarkerToChildrenOfNamedTrees(PsdImage.Trees, '服', '*', 'ポーズ');
end;

procedure ApplyYumeNoOwariInitialVisibility(PsdImage: TPSDImage);
begin
  if PsdImage = nil then Exit;

  HideYumeNoOwariRootOptionTrees(PsdImage.Trees);
end;

function FindYumeNoOwariKiritanSuwariEFaceChildren(
  Trees: TPsdFileTrees; var FaceChildren: TPsdFileTrees): Boolean;
var
  i: Integer;
  Tree: TPsdFileTree;
  RootChildren: TPsdFileTrees;
  PoseTree: TPsdFileTree;
  FaceTree: TPsdFileTree;
begin
  Result := False;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    if SameText(TreeName(Tree), 'きりたん') then
    begin
      RootChildren := TPsdFileTrees(Tree.Trees);
      PoseTree := FindChildTree(RootChildren, 'ポーズ1');
      if PoseTree <> nil then
      begin
        FaceTree := FindChildTree(TPsdFileTrees(PoseTree.Trees), '表情');
        if FaceTree <> nil then
        begin
          FaceChildren := TPsdFileTrees(FaceTree.Trees);
          Exit(True);
        end;
      end;
    end;

    if FindYumeNoOwariKiritanSuwariEFaceChildren(TPsdFileTrees(Tree.Trees),
      FaceChildren) then
      Exit(True);
  end;
end;

procedure ApplyYumeNoOwariKiritanSuwariEExclusiveGroups(PsdImage: TPSDImage);
var
  FaceChildren: TPsdFileTrees;
  SimpleFaceTree: TPsdFileTree;
  BrowTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  FaceChildren := nil;
  if not FindYumeNoOwariKiritanSuwariEFaceChildren(PsdImage.Trees,
    FaceChildren) then
    Exit;

  SimpleFaceTree := FindChildTree(FaceChildren, '簡易表情セット');
  BrowTree := FindChildTree(FaceChildren, '眉');
  EyeTree := FindChildTree(FaceChildren, '目');
  MouthTree := FindChildTree(FaceChildren, '口');

  if (SimpleFaceTree = nil) or (BrowTree = nil) or
     (EyeTree = nil) or (MouthTree = nil) then
    Exit;

  PsdImage.AddVisibilityRule(SimpleFaceTree, BrowTree, False);
  PsdImage.AddVisibilityRule(SimpleFaceTree, EyeTree, False);
  PsdImage.AddVisibilityRule(SimpleFaceTree, MouthTree, False);

  PsdImage.AddVisibilityRule(BrowTree, SimpleFaceTree, False);
  PsdImage.AddVisibilityRule(BrowTree, EyeTree, True);
  PsdImage.AddVisibilityRule(BrowTree, MouthTree, True);

  PsdImage.AddVisibilityRule(EyeTree, SimpleFaceTree, False);
  PsdImage.AddVisibilityRule(EyeTree, BrowTree, True);
  PsdImage.AddVisibilityRule(EyeTree, MouthTree, True);

  PsdImage.AddVisibilityRule(MouthTree, SimpleFaceTree, False);
  PsdImage.AddVisibilityRule(MouthTree, BrowTree, True);
  PsdImage.AddVisibilityRule(MouthTree, EyeTree, True);
end;

procedure ApplyYumeNoOwariKiritanSuwariEInitialVisibility(PsdImage: TPSDImage);
var
  FaceChildren: TPsdFileTrees;
  SimpleFaceTree: TPsdFileTree;
  BrowTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  FaceChildren := nil;
  if not FindYumeNoOwariKiritanSuwariEFaceChildren(PsdImage.Trees,
    FaceChildren) then
    Exit;

  SimpleFaceTree := FindChildTree(FaceChildren, '簡易表情セット');
  BrowTree := FindChildTree(FaceChildren, '眉');
  EyeTree := FindChildTree(FaceChildren, '目');
  MouthTree := FindChildTree(FaceChildren, '口');

  if SimpleFaceTree <> nil then
    SimpleFaceTree.SetVisibleLocal(False);
  if BrowTree <> nil then
    BrowTree.SetVisibleLocal(True);
  if EyeTree <> nil then
    EyeTree.SetVisibleLocal(True);
  if MouthTree <> nil then
    MouthTree.SetVisibleLocal(True);
end;

procedure ApplyYumeNoOwariElementCaptions(Elements: TPSDElementList);
var
  I: Integer;
  J: Integer;
  Element: TPSDElementItem;
  IsPoseElement: Boolean;
begin
  if Elements = nil then Exit;

  {$IFDEF DEBUG}
  YumeNoOwariDebugLog(Format('ApplyYumeNoOwariElementCaptions begin Elements=%d',
    [Elements.Count]));
  {$ENDIF}

  for I := 0 to Elements.Count - 1 do
  begin
    Element := Elements[I];
    if Element = nil then Continue;

    IsPoseElement :=
      IsPoseName(Element.Name) or
      HasPoseRoute(Element.Group) or
      HasPoseRoute(Element.Caption);

    if not IsPoseElement then Continue;

    Element.Caption := LastCleanRouteName(Element.Caption);
    if Element.Caption = '' then
      Element.Caption := CleanElementName(Element.Name);

    for J := 0 to Element.Parts.Count - 1 do
      Element.Parts[J].Caption := LastCleanRouteName(Element.Parts[J].Caption);
  end;

  MoveYumeNoOwariLowerAttachElementsNearUpper(Elements);

  {$IFDEF DEBUG}
  YumeNoOwariDebugLog('ApplyYumeNoOwariElementCaptions end');
  {$ENDIF}
end;

end.
