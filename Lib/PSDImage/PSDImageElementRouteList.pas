unit PSDImageElementRouteList;

// 大分類／小分類から実レイヤーツリー候補へ引くための索引リスト

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  {$IFDEF DEBUG}PSDImageDebugLog,{$ENDIF}
  PSDImage, PsdImageLayer, PSDImageElementList,PsdImageTree;

// 実レイヤーツリー候補1件と現在状態に基づく評価を持つ
type
  TPSDElementRouteCandidate = class
  private
    FTree: TPsdFileTree; // 候補として操作する実レイヤーツリー
  public
    // 候補ツリーを保持して候補オブジェクトを作成する
    constructor Create(ATree: TPsdFileTree);
    // 現在の表示状態から候補として適した度合いを返す
    function Score: Integer;
    // 候補ツリー単体の表示状態を返す
    function IsVisible: Boolean;
    // 候補ツリーを表示状態にする
    procedure SetVisible;
    // 候補ツリーと親をローカル表示にし、同階層排他を避けて表示連動だけ実行する
    procedure SetVisibleLocalWithOwnersAndRules;
    // 候補ツリーを非表示状態にする
    procedure ClearVisible;
    property Tree: TPsdFileTree read FTree;
  end;

  // 同じ大分類／小分類に対応する候補一覧
  TPSDElementRouteCandidates = class(TObjectList<TPSDElementRouteCandidate>)
  public
    // 候補一覧から最もスコアの高い候補を返す
    function BestCandidate: TPSDElementRouteCandidate;
  end;
	  TPSDElementRouteItem = class // 大分類／小分類1組とその実レイヤー候補一覧を保持する
	  private
	    FGroupName: string; // 同名 Element/Part 候補を区別するための親ルート
	    FElementName: string; // 大分類名
	    FPartName: string; // 小分類名
    FCandidates: TPSDElementRouteCandidates; // この大分類／小分類に一致する実レイヤー候補一覧
  public
    // 大分類名と小分類名を保持して索引項目を作成する
	    constructor Create(const AGroupName, AElementName, APartName: string);
    // 候補一覧を解放する
    destructor Destroy; override;
    // 候補ツリーを重複なしで追加する
    procedure AddCandidate(Tree: TPsdFileTree);
    // この索引項目の候補から最適な候補を返す
    function BestCandidate: TPSDElementRouteCandidate;
    // 最適候補が表示状態かを返す
    function IsVisible: Boolean;
    // 最適候補を表示状態にする
    function SetVisible: Boolean;
    // 最適候補を非表示状態にする
    function ClearVisible: Boolean;
	    property GroupName: string read FGroupName;
	    property ElementName: string read FElementName;
    property PartName: string read FPartName;
    property Candidates: TPSDElementRouteCandidates read FCandidates;
  end;

  // 大分類／小分類から実レイヤー候補へ引く索引リスト
  TPSDElementRouteList = class(TObjectList<TPSDElementRouteItem>)
  private
    // 大分類名と小分類名に一致する索引項目を返す
	    function FindItem(const GroupName, ElementName, PartName: string): TPSDElementRouteItem;
    // PSDレイヤーインデックスから対応するツリーを返す
    function LayerIndexToTree(PSDImage: TPSDImage; LayerIndex: Integer): TPsdFileTree;
    // Root仮想大分類の候補索引を構築する
    procedure BuildRootRoutes(PSDImage: TPSDImage; Elements: TPSDElementList);
    // Root配下として選択可能な同名候補を追加する
    procedure AddRootRouteCandidates(Trees: TPsdFileTrees; const PartName: string; Depth: Integer);
    // 大分類名に一致する各ツリー配下から小分類候補を追加する
	    procedure AddElementRouteCandidates(Trees: TPsdFileTrees; const GroupName, ElementName, PartName: string);
    // 小分類名の形式に応じて候補追加処理を振り分ける
	    procedure AddPartRouteCandidates(Trees: TPsdFileTrees; const GroupName, ElementName, PartName: string);
    // a/b/c形式の小分類ルートに一致する候補を追加する
	    procedure AddPartRouteCandidatesByRoute(Trees: TPsdFileTrees; const GroupName, ElementName, PartName: string;
	                                            const Segments: TArray<string>; Idx: Integer);
    // 単純名一致の小分類候補を再帰的に追加する
	    procedure AddPartRouteCandidatesLegacy(Trees: TPsdFileTrees; const GroupName, ElementName, PartName: string);
    // Root仮想大分類の候補にできるツリーか判定する
    function IsSelectableRootTree(Tree: TPsdFileTree): Boolean;
  public
    // PSD解析結果から大分類／小分類ごとの候補索引を構築する
    procedure BuildFromElements(PSDImage: TPSDImage; Elements: TPSDElementList);
    // 大分類／小分類の索引項目へ候補ツリーを追加する
	    procedure AddRoute(const ElementName, PartName: string; Tree: TPsdFileTree); overload;
	    procedure AddRoute(const GroupName, ElementName, PartName: string; Tree: TPsdFileTree); overload;
    // 大分類／小分類に対応する最適候補を表示状態にする
	    function SetElementPart(const ElementName, PartName: string): Boolean; overload;
	    function SetElementPart(const GroupName, ElementName, PartName: string): Boolean; overload;
    // 大分類／小分類に対応する最適候補を非表示状態にする
	    function ClearElementPart(const ElementName, PartName: string): Boolean; overload;
	    function ClearElementPart(const GroupName, ElementName, PartName: string): Boolean; overload;
    // 大分類／小分類に対応する最適候補が表示状態かを返す
	    function IsElementPartVisible(const ElementName, PartName: string): Boolean; overload;
	    function IsElementPartVisible(const GroupName, ElementName, PartName: string): Boolean; overload;
  end;
implementation

function CleanRouteName(const Name: string): string;
begin
  Result := Trim(Name);
  while (Result <> '') and CharInSet(Result[1], ['*', '+', '!']) do
    Delete(Result, 1, 1);
end;

function SameRouteName(const A, B: string): Boolean;
begin
  Result := SameText(Trim(A), Trim(B)) or
            SameText(CleanRouteName(A), CleanRouteName(B));
end;

function HasRouteText(const S, Token: string): Boolean;
begin
  Result := Pos(LowerCase(Token), LowerCase(S)) > 0;
end;

function RouteTreeName(Tree: TPsdFileTree): string;
begin
  Result := '';
  if (Tree <> nil) and (Tree.Layer <> nil) then
    Result := CleanRouteName(Tree.Layer.Name);
end;

function IsKosukeRightArmLocalRoute(const ElementName, PartName: string;
  Tree: TPsdFileTree): Boolean;
begin
  Result := SameText(CleanRouteName(ElementName), '右腕') and
            (HasRouteText(PartName, '(右)') or HasRouteText(PartName, '（右）')) and
            (HasRouteText(RouteTreeName(Tree), '(右)') or
             HasRouteText(RouteTreeName(Tree), '（右）'));
end;

{$IFDEF DEBUG}
const
  ENABLE_VERBOSE_PSD_ROUTE_LOG = False;

procedure RouteDebugLog(const S: string);
begin
  if not ENABLE_VERBOSE_PSD_ROUTE_LOG then Exit;
  PSDDebugLog('PSDRoute', S);
end;

function DebugTreePath(Tree: TPsdFileTree): string;
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

procedure DebugLogRouteItem(const Prefix, GroupName, ElementName,
  PartName: string; Item: TPSDElementRouteItem);
var
  I: Integer;
  Candidate: TPSDElementRouteCandidate;
begin
  if Item = nil then
  begin
    RouteDebugLog(Format('%s Group="%s" Element="%s" Part="%s" item=<nil>',
      [Prefix, GroupName, ElementName, PartName]));
    Exit;
  end;

  RouteDebugLog(Format('%s Group="%s" Element="%s" Part="%s" candidates=%d',
    [Prefix, GroupName, ElementName, PartName, Item.Candidates.Count]));

  for I := 0 to Item.Candidates.Count - 1 do
  begin
    Candidate := Item.Candidates[I];
    if Candidate = nil then
      Continue;

    RouteDebugLog(Format('  cand[%d] score=%d visible=%s path="%s"',
      [I, Candidate.Score, BoolToStr(Candidate.IsVisible, True),
       DebugTreePath(Candidate.Tree)]));
  end;
end;
{$ENDIF}

{ TPSDElementRouteCandidate }

constructor TPSDElementRouteCandidate.Create(ATree: TPsdFileTree);
begin
  inherited Create;
  FTree := ATree;
end;

function TPSDElementRouteCandidate.IsVisible: Boolean;
begin
  Result := (FTree <> nil) and FTree.Visible;
end;

function TPSDElementRouteCandidate.Score: Integer;
var
  i: Integer;
  OwnerTree: TPsdFileTree;
  Weight: Integer;
begin
  Result := 0;
  if FTree = nil then Exit;

  Weight := 1;
  for i := 0 to FTree.Owners.Count do
  begin
    if Weight < 1073741824 then
      Weight := Weight * 2;
  end;

  // Owners はルート側から直近親へ積まれるため、根に近い表示状態ほど強く評価する。
  for i := 0 to FTree.Owners.Count - 1 do
  begin
    OwnerTree := TPsdFileTree(FTree.Owners[i]);
    if (OwnerTree <> nil) and OwnerTree.Visible then
      Inc(Result, Weight)
    else
      Dec(Result, Weight);

    if Weight > 1 then
      Weight := Weight div 2;
  end;

  if FTree.Visible then
    Inc(Result, Weight)
  else
    Dec(Result, Weight);
end;

procedure TPSDElementRouteCandidate.SetVisible;
begin
  if FTree <> nil then
    FTree.Visible := True;
end;

procedure TPSDElementRouteCandidate.SetVisibleLocalWithOwnersAndRules;
var
  I: Integer;
  OwnerTree: TPsdFileTree;
begin
  if FTree = nil then Exit;

  for I := 0 to FTree.Owners.Count - 1 do
  begin
    OwnerTree := TPsdFileTree(FTree.Owners[I]);
    if OwnerTree <> nil then
      OwnerTree.SetVisibleLocal(True);
  end;

  FTree.SetVisibleLocalAndApplyRules(True);
end;

procedure TPSDElementRouteCandidate.ClearVisible;
begin
  if FTree <> nil then
    FTree.SetVisibleLocal(False);
end;

{ TPSDElementRouteCandidates }

function TPSDElementRouteCandidates.BestCandidate: TPSDElementRouteCandidate;
var
  i: Integer;
  Candidate: TPSDElementRouteCandidate;
  CandidateScore: Integer;
  BestScore: Integer;
begin
  Result := nil;
  BestScore := Low(Integer);

  for i := 0 to Count - 1 do
  begin
    Candidate := Items[i];
    if Candidate = nil then Continue;

    CandidateScore := Candidate.Score;
    if CandidateScore > BestScore then
    begin
      BestScore := CandidateScore;
      Result := Candidate;
    end;
  end;
end;

{ TPSDElementRouteItem }

constructor TPSDElementRouteItem.Create(const AGroupName, AElementName, APartName: string);
begin
  inherited Create;
  FGroupName := AGroupName;
  FElementName := AElementName;
  FPartName := APartName;
  FCandidates := TPSDElementRouteCandidates.Create(True);
end;

destructor TPSDElementRouteItem.Destroy;
begin
  FCandidates.Free;
  inherited;
end;

procedure TPSDElementRouteItem.AddCandidate(Tree: TPsdFileTree);
var
  i: Integer;
begin
  if Tree = nil then Exit;

  for i := 0 to FCandidates.Count - 1 do
    if FCandidates[i].Tree = Tree then
      Exit;

  FCandidates.Add(TPSDElementRouteCandidate.Create(Tree));
end;

function TPSDElementRouteItem.BestCandidate: TPSDElementRouteCandidate;
begin
  Result := FCandidates.BestCandidate;
end;

function TPSDElementRouteItem.IsVisible: Boolean;
var
  Candidate: TPSDElementRouteCandidate;
begin
  Candidate := BestCandidate;
  Result := (Candidate <> nil) and Candidate.IsVisible;
end;

function TPSDElementRouteItem.SetVisible: Boolean;
var
  Candidate: TPSDElementRouteCandidate;
begin
  Candidate := BestCandidate;
  Result := Candidate <> nil;
  if Result then
  begin
    if IsKosukeRightArmLocalRoute(FElementName, FPartName, Candidate.Tree) then
      Candidate.SetVisibleLocalWithOwnersAndRules
    else
      Candidate.SetVisible;
  end;
end;

function TPSDElementRouteItem.ClearVisible: Boolean;
var
  Candidate: TPSDElementRouteCandidate;
begin
  Candidate := BestCandidate;
  Result := Candidate <> nil;
  if Result then
    Candidate.ClearVisible;
end;

{ TPSDElementRouteList }

procedure TPSDElementRouteList.AddRoute(const ElementName, PartName: string; Tree: TPsdFileTree);
begin
  AddRoute('', ElementName, PartName, Tree);
end;

procedure TPSDElementRouteList.AddRoute(const GroupName, ElementName,
  PartName: string; Tree: TPsdFileTree);
var
  Item: TPSDElementRouteItem;
begin
  if (Trim(ElementName) = '') or (Trim(PartName) = '') or (Tree = nil) then Exit;

  Item := TPSDElementRouteItem.Create(GroupName, ElementName, PartName);
  Add(Item);
  Item.AddCandidate(Tree);
end;

procedure TPSDElementRouteList.BuildFromElements(PSDImage: TPSDImage; Elements: TPSDElementList);
var
  i, j: Integer;
  Element: TPSDElementItem;
  Part: TPSDElementPart;
  Tree: TPsdFileTree;
begin
  Clear;
  if (PSDImage = nil) or (Elements = nil) then Exit;

  for i := 0 to Elements.Count - 1 do
  begin
    Element := Elements[i];
    if Element = nil then Continue;

    for j := 0 to Element.Parts.Count - 1 do
    begin
      Part := Element.Parts[j];
      if Part = nil then Continue;

      if SameText(Element.Name, 'Root') then Continue;
      Tree := LayerIndexToTree(PSDImage, Part.LayerIndex);
	      AddRoute(Element.Group, Element.Name, Part.Name, Tree); // Group 付きで実レイヤー候補を索引化
	      if Element.Group = '' then
	      begin
	        AddElementRouteCandidates(PSDImage.Trees, Element.Group, Element.Name, Part.Name); // Group 不要時は従来通り全候補から優先順位計算する
	        if Element.Tree <> nil then
	          AddPartRouteCandidates(TPsdFileTrees(Element.Tree.Trees),
	            Element.Group, Element.Name, Part.Name);
	      end
	      else if Element.Tree <> nil then
	        AddPartRouteCandidates(TPsdFileTrees(Element.Tree.Trees), Element.Group, Element.Name, Part.Name);
    end;
  end;

  BuildRootRoutes(PSDImage, Elements);
end;

procedure TPSDElementRouteList.BuildRootRoutes(PSDImage: TPSDImage; Elements: TPSDElementList);
var
  i: Integer;
  RootElement: TPSDElementItem;
  Part: TPSDElementPart;
begin
  if (PSDImage = nil) or (Elements = nil) then Exit;

  RootElement := nil;
  for i := 0 to Elements.Count - 1 do
  begin
    if SameText(Elements[i].Name, 'Root') then
    begin
      RootElement := Elements[i];
      Break;
    end;
  end;

  if RootElement = nil then Exit;

  for i := 0 to RootElement.Parts.Count - 1 do
  begin
    Part := RootElement.Parts[i];
    if Part = nil then Continue;

    AddRootRouteCandidates(PSDImage.Trees, Part.Name, 0);
  end;
end;

procedure TPSDElementRouteList.AddRootRouteCandidates(Trees: TPsdFileTrees; const PartName: string; Depth: Integer);
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    if IsSelectableRootTree(Tree) and SameRouteName(Tree.Layer.Name, PartName) then
      AddRoute('', 'Root', PartName, Tree);

    if Depth < 1 then
      AddRootRouteCandidates(TPsdFileTrees(Tree.Trees), PartName, Depth + 1);
  end;
end;

procedure TPSDElementRouteList.AddElementRouteCandidates(Trees: TPsdFileTrees; const GroupName, ElementName, PartName: string);
var
  i: Integer;
  Tree: TPsdFileTree;
  Layer: TPsdFileLayer;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    Layer := Tree.Layer;
    if (Layer <> nil) and SameRouteName(Layer.Name, ElementName) then
      AddPartRouteCandidates(TPsdFileTrees(Tree.Trees), GroupName, ElementName, PartName);

    AddElementRouteCandidates(TPsdFileTrees(Tree.Trees), GroupName, ElementName, PartName);
  end;
end;

procedure TPSDElementRouteList.AddPartRouteCandidates(Trees: TPsdFileTrees; const GroupName, ElementName, PartName: string);
var
  Segments: TArray<string>;
begin
  if (Trees = nil) or (Trim(PartName) = '') then Exit;

  if Pos('/', PartName) > 0 then
  begin
    Segments := PartName.Split(['/']);
    if Length(Segments) > 0 then
      AddPartRouteCandidatesByRoute(Trees, GroupName, ElementName, PartName, Segments, 0);
  end
  else
    AddPartRouteCandidatesLegacy(Trees, GroupName, ElementName, PartName);
end;

procedure TPSDElementRouteList.AddPartRouteCandidatesByRoute(Trees: TPsdFileTrees;
  const GroupName, ElementName, PartName: string; const Segments: TArray<string>; Idx: Integer);
var
  i: Integer;
  Tree: TPsdFileTree;
  Layer: TPsdFileLayer;
begin
  if Trees = nil then Exit;
  if (Idx < 0) or (Idx > High(Segments)) then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    Layer := Tree.Layer;
    if (Layer = nil) or (not SameRouteName(Layer.Name, Segments[Idx])) then
      Continue;

    if Idx = High(Segments) then
      AddRoute(GroupName, ElementName, PartName, Tree)
    else
      AddPartRouteCandidatesByRoute(TPsdFileTrees(Tree.Trees), GroupName, ElementName, PartName, Segments, Idx + 1);
  end;
end;

procedure TPSDElementRouteList.AddPartRouteCandidatesLegacy(Trees: TPsdFileTrees;
  const GroupName, ElementName, PartName: string);
var
  i: Integer;
  Tree: TPsdFileTree;
  Layer: TPsdFileLayer;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    Layer := Tree.Layer;
    if (Layer <> nil) and SameRouteName(Layer.Name, PartName) then
      AddRoute(GroupName, ElementName, PartName, Tree);

    AddPartRouteCandidatesLegacy(TPsdFileTrees(Tree.Trees), GroupName, ElementName, PartName);
  end;
end;

function TPSDElementRouteList.FindItem(const GroupName, ElementName, PartName: string): TPSDElementRouteItem;
var
  i: Integer;
  Item: TPSDElementRouteItem;
  Candidate: TPSDElementRouteCandidate;
  CandidateScore: Integer;
  BestScore: Integer;
begin
  Result := nil;
  BestScore := Low(Integer);

  for i := 0 to Count - 1 do
  begin
    Item := Items[i];
    if Item = nil then Continue;

    if SameText(Trim(Item.GroupName), Trim(GroupName)) and // Group も一致条件に含めて重複候補を分離
       SameText(Trim(Item.ElementName), Trim(ElementName)) and
       SameText(Trim(Item.PartName), Trim(PartName)) then
    begin
      Candidate := Item.BestCandidate;
      if Candidate = nil then Continue;

      CandidateScore := Candidate.Score;
      if CandidateScore > BestScore then
      begin
        BestScore := CandidateScore;
        Result := Item;
      end;
    end;
  end;
end;

function TPSDElementRouteList.IsElementPartVisible(const ElementName, PartName: string): Boolean;
begin
  Result := IsElementPartVisible('', ElementName, PartName);
end;

function TPSDElementRouteList.IsElementPartVisible(const GroupName, ElementName,
  PartName: string): Boolean;
var
  Item: TPSDElementRouteItem;
begin
  Item := FindItem(GroupName, ElementName, PartName);
  Result := (Item <> nil) and Item.IsVisible;
end;

function TPSDElementRouteList.LayerIndexToTree(PSDImage: TPSDImage; LayerIndex: Integer): TPsdFileTree;
var
  Layer: TPsdFileLayer;
begin
  Result := nil;
  if PSDImage = nil then Exit;
  if (LayerIndex < 0) or (LayerIndex >= PSDImage.Layers.Count) then Exit;

  Layer := PSDImage.Layers[LayerIndex];
  if Layer = nil then Exit;

  Result := TPsdFileTree(Layer.Tree);
end;

function TPSDElementRouteList.IsSelectableRootTree(Tree: TPsdFileTree): Boolean;
var
  Layer: TPsdFileLayer;
begin
  Result := False;
  if Tree = nil then Exit;

  Layer := Tree.Layer;
  if (Layer = nil) or (Layer.Name = '') then Exit;

  Result := Layer.Name[1] = '*';
end;

function TPSDElementRouteList.SetElementPart(const ElementName, PartName: string): Boolean;
begin
  Result := SetElementPart('', ElementName, PartName);
end;

function TPSDElementRouteList.SetElementPart(const GroupName, ElementName,
  PartName: string): Boolean;
var
  Item: TPSDElementRouteItem;
begin
  Item := FindItem(GroupName, ElementName, PartName);
  {$IFDEF DEBUG}
  DebugLogRouteItem('SetElementPart', GroupName, ElementName, PartName, Item);
  {$ENDIF}
  Result := (Item <> nil) and Item.SetVisible;
  {$IFDEF DEBUG}
  RouteDebugLog(Format('SetElementPart result=%s Group="%s" Element="%s" Part="%s"',
    [BoolToStr(Result, True), GroupName, ElementName, PartName]));
  {$ENDIF}
end;

function TPSDElementRouteList.ClearElementPart(const ElementName,
  PartName: string): Boolean;
begin
  Result := ClearElementPart('', ElementName, PartName);
end;

function TPSDElementRouteList.ClearElementPart(const GroupName, ElementName,
  PartName: string): Boolean;
var
  Item: TPSDElementRouteItem;
begin
  Item := FindItem(GroupName, ElementName, PartName);
  Result := (Item <> nil) and Item.ClearVisible;
end;

end.
