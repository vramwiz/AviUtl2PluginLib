unit PSDImageFlipTree;

interface

uses
  System.SysUtils,System.Classes,System.Generics.Collections,Winapi.Windows,
  PsdImage,PsdImageTree;

type
  {------------------------------------------------------------
    解析ツリーノード（親参照あり）
    ・BaseVisible は Parse 時点の ts.Visible を保持（flipで書き換わっても不変）
    ・実効可視は Parent を遡って BaseVisible をANDする
  ------------------------------------------------------------}
  TPSDFlipTreeNode = class
  private
    FSourceTree  : TPsdFileTree;
    FParent      : TPSDFlipTreeNode;
    FChildren    : TObjectList<TPSDFlipTreeNode>;
    FBaseVisible : Boolean;
  public
    constructor Create(ASource: TPsdFileTree; AParent: TPSDFlipTreeNode);
    destructor Destroy; override;

    property SourceTree  : TPsdFileTree read FSourceTree;
    property Parent      : TPSDFlipTreeNode read FParent;
    property Children    : TObjectList<TPSDFlipTreeNode> read FChildren;
    property BaseVisible : Boolean read FBaseVisible;

    function IsEffectivelyVisibleBase: Boolean;
  end;

  {------------------------------------------------------------
    解析ツリー
    ・ノードの所有権は FRoots / Children 側のみ
    ・辞書は参照用途（非所有）
  ------------------------------------------------------------}
  TPSDFlipTree = class
  private
    FRoots   : TObjectList<TPSDFlipTreeNode>;
    FNodeMap : TObjectDictionary<TPsdFileTree, TPSDFlipTreeNode>;

    procedure ParseTrees(Trees: TPsdFileTrees; ParentNode: TPSDFlipTreeNode);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure BuildFromPSD(PSDImage: TPSDImage);

    function FindNode(Tree: TPsdFileTree): TPSDFlipTreeNode;
  end;

implementation

{ TPSDFlipTreeNode }

constructor TPSDFlipTreeNode.Create(ASource: TPsdFileTree; AParent: TPSDFlipTreeNode);
begin
  inherited Create;
  FSourceTree  := ASource;
  FParent      := AParent;
  FChildren    := TObjectList<TPSDFlipTreeNode>.Create(True);
  FBaseVisible := (ASource <> nil) and ASource.Visible;
end;

destructor TPSDFlipTreeNode.Destroy;
begin
  FChildren.Free;
  inherited;
end;

function TPSDFlipTreeNode.IsEffectivelyVisibleBase: Boolean;
var
  N: TPSDFlipTreeNode;
begin
  Result := True;
  N := Self;
  while N <> nil do
  begin
    if not N.BaseVisible then
      Exit(False);
    N := N.Parent;
  end;
end;

{ TPSDFlipTree }

constructor TPSDFlipTree.Create;
begin
  inherited Create;
  FRoots   := TObjectList<TPSDFlipTreeNode>.Create(True);
  // ★ 辞書は非所有（Nodeはツリー側のみが所有）
  FNodeMap := TObjectDictionary<TPsdFileTree, TPSDFlipTreeNode>.Create;
end;

destructor TPSDFlipTree.Destroy;
begin
  FNodeMap.Free;
  FRoots.Free;
  inherited;
end;

procedure TPSDFlipTree.Clear;
begin
  FRoots.Clear;    // ノードはここで一括解放
  FNodeMap.Clear; // 参照のみクリア
end;

procedure TPSDFlipTree.BuildFromPSD(PSDImage: TPSDImage);
begin
  Clear;
  if PSDImage = nil then Exit;
  ParseTrees(PSDImage.Trees, nil);
end;

procedure TPSDFlipTree.ParseTrees(Trees: TPsdFileTrees; ParentNode: TPSDFlipTreeNode);
var
  i   : Integer;
  ts  : TPsdFileTree;
  Node: TPSDFlipTreeNode;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    ts := Trees[i];
    if ts = nil then Continue;

    Node := TPSDFlipTreeNode.Create(ts, ParentNode);

    if ParentNode = nil then
      FRoots.Add(Node)
    else
      ParentNode.Children.Add(Node);

    if not FNodeMap.ContainsKey(ts) then
      FNodeMap.Add(ts, Node);

    ParseTrees(TPsdFileTrees(ts.Trees), Node);
  end;
end;

function TPSDFlipTree.FindNode(Tree: TPsdFileTree): TPSDFlipTreeNode;
begin
  if (Tree <> nil) and FNodeMap.TryGetValue(Tree, Result) then
    Exit;
  Result := nil;
end;

end.

