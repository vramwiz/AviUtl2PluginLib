unit PSDImageCustomAzuki;

interface

uses
  PsdImage;

// 制作者ごとの独自処理ユニットは PSDImage\Custom 直下に配置する。
// アズキ式はファイル名で判定し、PSD構造の差分だけここで補正する。

function IsAzukiFileName(const FileName: string): Boolean;
procedure ApplyAzukiMarkers(PsdImage: TPSDImage);
procedure ApplyAzukiExclusiveGroups(PsdImage: TPSDImage);
procedure ApplyAzukiInitialVisibility(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

function HasText(const S, Token: string): Boolean;
begin
  Result := Pos(LowerCase(Token), LowerCase(S)) > 0;
end;

function IsAzukiFileName(const FileName: string): Boolean;
var
  Name: string;
begin
  Name := ChangeFileExt(ExtractFileName(FileName), '');
  Result := HasText(Name, 'アズキ式');
end;

procedure ApplyMarkerToNamedTrees(Trees: TPsdFileTrees;
  const Names: array of string; const Marker: Char);
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
        ReplaceMarkerOnTree(Tree, Marker);
        Break;
      end;

    ApplyMarkerToNamedTrees(TPsdFileTrees(Tree.Trees), Names, Marker);
  end;
end;

function FindChildOfNamedParent(Trees: TPsdFileTrees;
  const ParentName, ChildName: string): TPsdFileTree;
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

    ChildTrees := TPsdFileTrees(Tree.Trees);
    if SameText(TreeName(Tree), ParentName) then
    begin
      Result := FindChildTree(ChildTrees, ChildName);
      if Result <> nil then Exit;
    end;

    Result := FindChildOfNamedParent(ChildTrees, ParentName, ChildName);
    if Result <> nil then Exit;
  end;
end;

procedure ApplyAzukiMarkers(PsdImage: TPSDImage);
var
  IconTree: TPsdFileTree;
  FlipQuestionTree: TPsdFileTree;
  EyeBlinkTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  // ルートに近いキャラ差分を排他選択候補にする。
  // PsdImage.Trees の直下は仮想ルート !v1 なので、再帰的に探す。
  ApplyMarkerToNamedTrees(PsdImage.Trees,
    ['みじゃがいもか', 'みやまいもか'], '*');

  // 「？反転用」は通常の「？」候補を左右反転したものとして扱う。
  IconTree := FindBestNamedTree(PsdImage.Trees, 'アイコン');
  if IconTree <> nil then
  begin
    FlipQuestionTree := FindChildTree(
      TPsdFileTrees(IconTree.Trees), '？反転用');
    if FlipQuestionTree <> nil then
      SetTreeLayerName(FlipQuestionTree, '*？:flipx');
  end;

  // 表情/目 配下の目パチ用グループを選択候補にする。
  // 「目」は複数あるため、目パチ用を直下に持つ目を再帰的に探す。
  EyeBlinkTree := FindChildOfNamedParent(PsdImage.Trees, '目', '目パチ用');
  if EyeBlinkTree <> nil then
    ReplaceMarkerOnTree(EyeBlinkTree, '*');
end;

procedure ApplyAzukiExclusiveGroups(PsdImage: TPSDImage);
begin
  // 予約: アズキ式固有の表示連動が必要になったらここに追加する。
end;

procedure ApplyAzukiInitialVisibility(PsdImage: TPSDImage);
var
  IconTree: TPsdFileTree;
  PotatoTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  // アイコン配下の「じゃがいも」はPSD側でONだが、初期状態では表示しない。
  IconTree := FindBestNamedTree(PsdImage.Trees, 'アイコン');
  if IconTree = nil then Exit;

  PotatoTree := FindChildTree(TPsdFileTrees(IconTree.Trees), 'じゃがいも');
  if PotatoTree <> nil then
    PotatoTree.SetVisibleLocal(False);
end;

end.
