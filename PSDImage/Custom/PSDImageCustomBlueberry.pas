unit PSDImageCustomBlueberry;

interface

uses
  PsdImage;

// 制作者ごとの独自処理ユニットは PSDImage\Custom 直下に配置する。
// blueberry氏PSDはファイル名ではなく、PSD内部構造で判定する。

function IsBlueberryPSD(PsdImage: TPSDImage): Boolean;
procedure ApplyBlueberryMarkers(PsdImage: TPSDImage);
procedure ApplyBlueberryExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyBlueberryInitialVisibility(PsdImage: TPSDImage);

implementation

uses
  PsdImageTree, PSDImageCustomMarkerUtils;

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

function CountChildTrees(Trees: TPsdFileTrees): Integer;
var
  i: Integer;
begin
  Result := 0;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
    if Trees[i] <> nil then
      Inc(Result);
end;

function HasBlueberryRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  MarkTree: TPsdFileTree;
  EyeTree: TPsdFileTree;
  MouthTree: TPsdFileTree;
  ArmTree: TPsdFileTree;
  BodyTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(RootChildren,
    ['マーク', 'アクセサリ', '眉', '目', '口', '腕', '顔効果', '本体']) then
    Exit;

  MarkTree := FindChildTree(RootChildren, 'マーク');
  EyeTree := FindChildTree(RootChildren, '目');
  MouthTree := FindChildTree(RootChildren, '口');
  ArmTree := FindChildTree(RootChildren, '腕');
  BodyTree := FindChildTree(RootChildren, '本体');

  Result :=
    HasChildTrees(TPsdFileTrees(MarkTree.Trees),
      ['ため息', 'ばってん', 'おこ', 'ひらめいた', '？反転', '？']) and
    (CountChildTrees(TPsdFileTrees(EyeTree.Trees)) >= 20) and
    HasChildTrees(TPsdFileTrees(EyeTree.Trees),
      ['普通', 'ちょっと閉じ', '半目', '閉じ', 'ウインク']) and
    (CountChildTrees(TPsdFileTrees(MouthTree.Trees)) >= 20) and
    HasChildTrees(TPsdFileTrees(MouthTree.Trees),
      ['閉じ', '開き', 'アニメ1', 'アニメ2', '笑い']) and
    HasChildTrees(TPsdFileTrees(ArmTree.Trees), ['かしこま', '普通']) and
    HasChildTrees(TPsdFileTrees(BodyTree.Trees),
      ['服', '服破れ', 'パジャマ', '水着']);
end;

function HasBlueberryRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasBlueberryRootStructure(Tree) then
      Exit(True);

    if HasBlueberryRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function IsBlueberryPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasBlueberryRoot(PsdImage.Trees);
end;

procedure ApplyBlueberryMarkers(PsdImage: TPSDImage);
begin
  // 予約: blueberry氏PSD固有のマーカー補正が必要になったらここに追加する。
end;

procedure ApplyBlueberryExclusiveGroups(PsdImage: TPSDImage);
begin
  // 予約: blueberry氏PSD固有の表示連動が必要になったらここに追加する。
end;

procedure ApplyBlueberryInitialVisibility(PsdImage: TPSDImage);
begin
  // 予約: blueberry氏PSD固有の初期表示補正が必要になったらここに追加する。
end;

end.
