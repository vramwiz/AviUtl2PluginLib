unit PSDImageCustomNanroku;

interface

uses
  PsdImage;

// 制作者ごとの独自処理ユニットは PSDImage\Custom 直下に配置する。
// 七六氏PSDは「プロゲーマー☆ゆかり.psd」をファイル名で判定する。

function IsNanrokuFileName(const FileName: string): Boolean;
procedure ApplyNanrokuMarkers(PsdImage: TPSDImage);
procedure ApplyNanrokuExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyNanrokuInitialVisibility(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

function IsNanrokuFileName(const FileName: string): Boolean;
var
  Name: string;
begin
  Name := ChangeFileExt(ExtractFileName(FileName), '');
  Result := SameText(Name, 'プロゲーマー☆ゆかり');
end;

function FindExpressionTree(Trees: TPsdFileTrees): TPsdFileTree;
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

    if SameText(TreeName(Tree), '表情') then
      Exit(Tree);

    Result := FindExpressionTree(TPsdFileTrees(Tree.Trees));
    if Result <> nil then Exit;
  end;
end;

procedure ApplyChoiceGroupMarker(ParentTree: TPsdFileTree; const Name: string);
var
  GroupTree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  i: Integer;
begin
  if ParentTree = nil then Exit;

  GroupTree := FindBestNamedTree(TPsdFileTrees(ParentTree.Trees), Name);
  if GroupTree = nil then Exit;

  // 表情配下の各差分グループは排他グループとして扱うため、親に ! を付ける。
  ReplaceMarkerOnTree(GroupTree, '!');

  // その1階層下にある各表情差分を選択肢として扱うため、直下の子だけに * を付ける。
  ChildTrees := TPsdFileTrees(GroupTree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
    ReplaceMarkerOnTree(ChildTrees[i], '*');
end;

procedure ApplyRootGroupMarker(Trees: TPsdFileTrees; const Name: string);
var
  RootTree: TPsdFileTree;
  ChildTrees: TPsdFileTrees;
  i: Integer;
begin
  RootTree := FindBestNamedTree(Trees, Name);
  if RootTree = nil then Exit;

  // 七六氏PSDのルート分類は大分類として扱うため、親に ! を付ける。
  ReplaceMarkerOnTree(RootTree, '!');

  // ルート分類の1階層下も、表情差分と同じく選択肢として扱う。
  ChildTrees := TPsdFileTrees(RootTree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
    ReplaceMarkerOnTree(ChildTrees[i], '*');
end;

procedure ApplyNanrokuMarkers(PsdImage: TPSDImage);
var
  ExpressionTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  ApplyRootGroupMarker(PsdImage.Trees, 'エフェクト');
  ApplyRootGroupMarker(PsdImage.Trees, '腕');
  ApplyRootGroupMarker(PsdImage.Trees, '胴体差分');
  ApplyRootGroupMarker(PsdImage.Trees, '足');
  ApplyRootGroupMarker(PsdImage.Trees, 'メイン体');
  ApplyRootGroupMarker(PsdImage.Trees, '背景小道具');

  ExpressionTree := FindExpressionTree(PsdImage.Trees);
  if ExpressionTree = nil then Exit;

  ApplyChoiceGroupMarker(ExpressionTree, 'まゆげ');
  ApplyChoiceGroupMarker(ExpressionTree, '口');
  ApplyChoiceGroupMarker(ExpressionTree, '目');
  ApplyChoiceGroupMarker(ExpressionTree, '顔エフェクト');
  ApplyChoiceGroupMarker(ExpressionTree, 'ほっぺた');
end;

procedure ApplyNanrokuExclusiveGroups(PsdImage: TPSDImage);
begin
  // 予約: 七六氏PSD固有の表示連動が必要になったらここに追加する。
end;

procedure ApplyNanrokuInitialVisibility(PsdImage: TPSDImage);
begin
  // 予約: 七六氏PSD固有の初期表示補正が必要になったらここに追加する。
end;

end.
