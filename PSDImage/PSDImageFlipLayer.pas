unit PSDImageFlipLayer;

interface

uses
  System.SysUtils,System.Classes,System.Generics.Collections,Winapi.Windows,
  PsdImage,PsdImageLayer,PSDImageFlipTree,PsdImageTree;

type
  {------------------------------------------------------------
    反転レイヤー1グループ
      BaseName をキーとして管理
      0:通常 1:X 2:Y 3:XY
  ------------------------------------------------------------}
  TPSDImageFlipLayerItem = class
  private
    FBaseName  : string;
    FTrees     : array[0..3] of TPsdFileTree;
    FFlipTree  : TPSDFlipTree; // ★ 解析ツリー（親参照あり）を参照する（所有しない）

    procedure SetFlipTree(AFlipTree: TPSDFlipTree);

    // ★ 親参照付きの「実効可視（現時点）」判定
    function IsTreeEffectivelyVisibleNow(Tree: TPsdFileTree): Boolean;
  public
    constructor Create(const ABaseName: string);

    procedure SetTree(Flip: Integer; Tree: TPsdFileTree);
    function  GetTree(Flip: Integer): TPsdFileTree;

    function  Count: Integer;
    function  HasAnyVisible: Boolean;

    procedure Normalize;
    procedure ApplyFlip(Flip: Integer);

    property BaseName: string read FBaseName;
    property Trees[Flip: Integer]: TPsdFileTree read GetTree write SetTree;
  end;

  {------------------------------------------------------------
    反転レイヤー管理クラス
  ------------------------------------------------------------}
  TPSDImageFlipLayer = class
  private
    FItems    : TObjectList<TPSDImageFlipLayerItem>;
    FFlipTree : TPSDFlipTree; // ★ 追加：親参照つき解析ツリー

    // 再帰探索
    procedure ParseTrees(Trees: TPsdFileTrees);

    // アイテム取得
    function  FindItem(const BaseName: string): TPSDImageFlipLayerItem;
    function  GetOrCreateItem(const BaseName: string): TPSDImageFlipLayerItem;

    // レイヤー名解析
    procedure ParseLayerName(
      const LayerName: string;
      out BaseName: string;
      out Flip: Integer
    );
  public
    constructor Create;
    destructor  Destroy; override;

    procedure Clear;

    // 読み込み・解析
    procedure ParseFromPSD(PSDImage: TPSDImage);

    // 反転指示（0:通常 1:X 2:Y 3:XY）
    procedure ApplyFlip(Flip: Integer);
  end;

implementation

{ TPSDImageFlipLayerItem }

constructor TPSDImageFlipLayerItem.Create(const ABaseName: string);
begin
  inherited Create;
  FBaseName := ABaseName;
  FFlipTree := nil;
end;

procedure TPSDImageFlipLayerItem.SetFlipTree(AFlipTree: TPSDFlipTree);
begin
  FFlipTree := AFlipTree;
end;

procedure TPSDImageFlipLayerItem.SetTree(Flip: Integer; Tree: TPsdFileTree);
begin
  if (Flip < 0) or (Flip > 3) then Exit;
  FTrees[Flip] := Tree;
end;

function TPSDImageFlipLayerItem.GetTree(Flip: Integer): TPsdFileTree;
begin
  if (Flip < 0) or (Flip > 3) then
    Result := nil
  else
    Result := FTrees[Flip];
end;

function TPSDImageFlipLayerItem.Count: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if FTrees[i] <> nil then
      Inc(Result);
end;

function TPSDImageFlipLayerItem.HasAnyVisible: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to 3 do
    if (FTrees[i] <> nil) and FTrees[i].Visible then
      Exit(True);
end;

procedure TPSDImageFlipLayerItem.Normalize;
begin
  // X / Y が無い場合は通常で補完
  if FTrees[1] = nil then FTrees[1] := FTrees[0];
  if FTrees[2] = nil then FTrees[2] := FTrees[0];

  // XY が無い場合は X → Y → 通常 の順で補完
  if FTrees[3] = nil then
  begin
    if FTrees[1] <> nil then
      FTrees[3] := FTrees[1]
    else if FTrees[2] <> nil then
      FTrees[3] := FTrees[2]
    else
      FTrees[3] := FTrees[0];
  end;
end;

function TPSDImageFlipLayerItem.IsTreeEffectivelyVisibleNow(Tree: TPsdFileTree): Boolean;
var
  Node: TPSDFlipTreeNode;
begin
  Result := False;
  if Tree = nil then Exit;
  if FFlipTree = nil then Exit;

  Node := FFlipTree.FindNode(Tree);
  if Node = nil then Exit;

  // ★ 親参照で「現時点の Visible」を遡って判定する
  while Node <> nil do
  begin
    if (Node.SourceTree = nil) or (not Node.SourceTree.Visible) then
      Exit(False);
    Node := Node.Parent;
  end;

  Result := True;
end;

procedure TPSDImageFlipLayerItem.ApplyFlip(Flip: Integer);
var
  i: Integer;
  HasVisible: Boolean;
  Tree: TPsdFileTree;
begin
  if (Flip < 0) or (Flip > 3) then Exit;
  if FFlipTree = nil then Exit;

  // ① 4つすべて「実効可視（現時点）」でないなら何もしない
  //   ※「Tree.Visible 単体」ではなく、親方向を含めた実効可視で判断する
  HasVisible := False;
  for i := 0 to 3 do
  begin
    Tree := FTrees[i];
    if Tree = nil then Continue;

    if IsTreeEffectivelyVisibleNow(Tree) then
    begin
      HasVisible := True;
      Break;
    end;
  end;

  if not HasVisible then Exit;

  // ② いったん全方向を消す
  for i := 0 to 3 do
    if FTrees[i] <> nil then
      FTrees[i].SetLayerVisible(True,False); // 強制的にレイヤーを非表示

  // ③ 選択方向だけ True（親が不可視なら結果的に描画されないので安全）
  Tree := FTrees[Flip];
  if Tree <> nil then
    Tree.Visible := True;
end;

{ TPSDImageFlipLayer }

constructor TPSDImageFlipLayer.Create;
begin
  inherited Create;
  FItems := TObjectList<TPSDImageFlipLayerItem>.Create(True);
  FFlipTree := TPSDFlipTree.Create;
end;

destructor TPSDImageFlipLayer.Destroy;
begin
  FFlipTree.Free;
  FItems.Free;
  inherited;
end;

procedure TPSDImageFlipLayer.Clear;
begin
  FItems.Clear;
  FFlipTree.Clear;
end;

procedure TPSDImageFlipLayer.ParseFromPSD(PSDImage: TPSDImage);
var
  i: Integer;
  Item: TPSDImageFlipLayerItem;
begin
  Clear;
  if PSDImage = nil then Exit;

  // ★ 親参照つき解析ツリーをここで構築（以後 ApplyFlip で利用）
  FFlipTree.BuildFromPSD(PSDImage);

  // 反転グループ抽出（従来通りの再帰探索）
  ParseTrees(PSDImage.Trees);

  // 不要要素削除（逆順）
  for i := FItems.Count - 1 downto 0 do
    if FItems[i].Count <= 1 then
      FItems.Delete(i);

  // 正規化 + FlipTree参照を注入
  for i := 0 to FItems.Count - 1 do
  begin
    Item := FItems[i];
    Item.Normalize;
    Item.SetFlipTree(FFlipTree);
  end;
end;

procedure TPSDImageFlipLayer.ApplyFlip(Flip: Integer);
var
  Item: TPSDImageFlipLayerItem;
begin
  for Item in FItems do
    Item.ApplyFlip(Flip);
end;

procedure TPSDImageFlipLayer.ParseTrees(Trees: TPsdFileTrees);
var
  i: Integer;
  ts: TPsdFileTree;
  layer: TPsdFileLayer;
  BaseName: string;
  Flip: Integer;
  Item: TPSDImageFlipLayerItem;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    ts := Trees[i];
    if ts = nil then Continue;

    layer := ts.Layer;
    if layer <> nil then
    begin
      ParseLayerName(layer.AnmText, BaseName, Flip);
      Item := GetOrCreateItem(BaseName);
      Item.SetTree(Flip, ts);
    end;

    ParseTrees(TPsdFileTrees(ts.Trees));
  end;
end;

function TPSDImageFlipLayer.FindItem(const BaseName: string): TPSDImageFlipLayerItem;
var
  Item: TPSDImageFlipLayerItem;
begin
  for Item in FItems do
    if SameText(Item.BaseName, BaseName) then
      Exit(Item);
  Result := nil;
end;

function TPSDImageFlipLayer.GetOrCreateItem(const BaseName: string): TPSDImageFlipLayerItem;
begin
  Result := FindItem(BaseName);
  if Result <> nil then Exit;

  Result := TPSDImageFlipLayerItem.Create(BaseName);
  FItems.Add(Result);
end;

procedure TPSDImageFlipLayer.ParseLayerName(
  const LayerName: string;
  out BaseName: string;
  out Flip: Integer
);
begin
  BaseName := LayerName;
  Flip := 0;

  if LayerName.EndsWith(':flipxy') then
  begin
    Flip := 3;
    BaseName := Copy(LayerName, 1, Length(LayerName) - 7);
  end
  else if LayerName.EndsWith(':flipy') then
  begin
    Flip := 2;
    BaseName := Copy(LayerName, 1, Length(LayerName) - 6);
  end
  else if LayerName.EndsWith(':flipx') then
  begin
    Flip := 1;
    BaseName := Copy(LayerName, 1, Length(LayerName) - 6);
  end;
end;

end.

