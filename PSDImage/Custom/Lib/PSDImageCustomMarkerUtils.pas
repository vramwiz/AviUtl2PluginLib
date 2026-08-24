unit PSDImageCustomMarkerUtils;

interface

uses
  PsdImageTree;

// 仮想マーカーとして扱う文字か判定する
function IsVirtualMarkerChar(Ch: Char): Boolean;
// ツリーに紐づくレイヤー名を返す
function LayerName(Tree: TPsdFileTree): string;
// レイヤー名先頭の仮想マーカーを返す
function MarkerOfName(const AName: string): string;
// レイヤー名先頭の仮想マーカーを1文字だけ除去する
function StripMarker(const AName: string): string;
// レイヤー名先頭の仮想マーカーをすべて除去する
function CleanName(const AName: string): string;
// ツリーのレイヤー名から仮想マーカーを除いた名前を返す
function TreeName(Tree: TPsdFileTree): string;
// レイヤー名先頭に仮想マーカーがあるか判定する
function HasMarker(const AName: string): Boolean;
// ツリーのレイヤー名を変更し、子のANMパスも更新する
procedure SetTreeLayerName(Tree: TPsdFileTree; const AName: string);
// 仮想マーカーが無いツリーへ仮想マーカーを付与し、子のANMパスも更新する
function ApplyMarkerToTree(Tree: TPsdFileTree; const Marker: Char): Boolean;
// ツリーの仮想マーカーを指定マーカーへ置き換え、子のANMパスも更新する
function ReplaceMarkerOnTree(Tree: TPsdFileTree; const Marker: Char): Boolean;
// ツリーの仮想マーカーを除去する
function RemoveMarkerFromTree(Tree: TPsdFileTree): Boolean;
// 指定名の直下ツリーを探す
function FindChildTree(Trees: TPsdFileTrees; const Name: string): TPsdFileTree;
// 直下の子ツリー数を返す
function ChildCount(Tree: TPsdFileTree): Integer;
// 子ツリーを持たないツリーか判定する
function IsLeafTree(Tree: TPsdFileTree): Boolean;
// 指定名の候補から子ツリー数が最も多いツリーを探す
function FindBestNamedTree(Trees: TPsdFileTrees; const Name: string): TPsdFileTree;
// ツリーの直近の親ツリーを返す
function ParentTree(Tree: TPsdFileTree): TPsdFileTree;

implementation

uses
  System.SysUtils, PsdImageLayer;

// 仮想マーカーとして扱う文字か判定する
function IsVirtualMarkerChar(Ch: Char): Boolean;
begin
  Result := CharInSet(Ch, ['*', '!', '+', '-']);
end;

// ツリーに紐づくレイヤー名を返す
function LayerName(Tree: TPsdFileTree): string;
begin
  Result := '';
  if (Tree <> nil) and (Tree.Layer <> nil) then
    Result := Tree.Layer.Name;
end;

// レイヤー名先頭の仮想マーカーを返す
function MarkerOfName(const AName: string): string;
var
  S: string;
begin
  Result := '';
  S := Trim(AName);
  if (S <> '') and IsVirtualMarkerChar(S[1]) then
    Result := S[1];
end;

// レイヤー名先頭の仮想マーカーを1文字だけ除去する
function StripMarker(const AName: string): string;
begin
  Result := Trim(AName);
  if (Result <> '') and IsVirtualMarkerChar(Result[1]) then
    Delete(Result, 1, 1);
end;

// レイヤー名先頭の仮想マーカーをすべて除去する
function CleanName(const AName: string): string;
begin
  Result := Trim(AName);
  while (Result <> '') and IsVirtualMarkerChar(Result[1]) do
    Delete(Result, 1, 1);
end;

// ツリーのレイヤー名から仮想マーカーを除いた名前を返す
function TreeName(Tree: TPsdFileTree): string;
begin
  Result := CleanName(LayerName(Tree));
end;

// レイヤー名先頭に仮想マーカーがあるか判定する
function HasMarker(const AName: string): Boolean;
begin
  Result := MarkerOfName(AName) <> '';
end;

// 子ツリーのANMパスを親のANMパスに合わせて更新する
procedure RefreshChildAnmPaths(Tree: TPsdFileTree);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
  ChildTree: TPsdFileTree;
begin
  if (Tree = nil) or (Tree.Layer = nil) then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    ChildTree := ChildTrees[i];
    if (ChildTree = nil) or (ChildTree.Layer = nil) then Continue;

    // 親名に仮想マーカーを足した場合、子のANM絶対パスも同じ名前へ更新する。
    ChildTree.Layer.SetAnmGroupPath(Tree.Layer.AnmText + '/');
    RefreshChildAnmPaths(ChildTree);
  end;
end;

// ツリーのレイヤー名を変更し、子のANMパスも更新する
procedure SetTreeLayerName(Tree: TPsdFileTree; const AName: string);
begin
  if (Tree = nil) or (Tree.Layer = nil) then Exit;

  Tree.Layer.Name := AName;
  Tree.Layer.AnmText := Tree.Layer.AnmGroup2 + Tree.Layer.Name;
  RefreshChildAnmPaths(Tree);
end;

// 仮想マーカーが無いツリーへ仮想マーカーを付与し、子のANMパスも更新する
function ApplyMarkerToTree(Tree: TPsdFileTree; const Marker: Char): Boolean;
var
  Layer: TPsdFileLayer;
  NewName: string;
begin
  Result := False;
  if Tree = nil then Exit;
  Layer := Tree.Layer;
  if Layer = nil then Exit;
  if HasMarker(Layer.Name) then Exit;

  NewName := string(Marker) + Trim(Layer.Name);
  if NewName = Layer.Name then Exit;

  SetTreeLayerName(Tree, NewName);
  Result := True;
end;

// ツリーの仮想マーカーを指定マーカーへ置き換え、子のANMパスも更新する
function ReplaceMarkerOnTree(Tree: TPsdFileTree; const Marker: Char): Boolean;
var
  Layer: TPsdFileLayer;
  NewName: string;
begin
  Result := False;
  if Tree = nil then Exit;
  Layer := Tree.Layer;
  if Layer = nil then Exit;

  NewName := string(Marker) + StripMarker(Layer.Name);
  if NewName = Layer.Name then Exit;

  SetTreeLayerName(Tree, NewName);
  Result := True;
end;

// ツリーの仮想マーカーを除去する
function RemoveMarkerFromTree(Tree: TPsdFileTree): Boolean;
var
  Layer: TPsdFileLayer;
  NewName: string;
begin
  Result := False;
  if Tree = nil then Exit;
  Layer := Tree.Layer;
  if Layer = nil then Exit;
  if not HasMarker(Layer.Name) then Exit;

  NewName := StripMarker(Layer.Name);
  if NewName = Layer.Name then Exit;

  SetTreeLayerName(Tree, NewName);
  Result := True;
end;

// 指定名の直下ツリーを探す
function FindChildTree(Trees: TPsdFileTrees; const Name: string): TPsdFileTree;
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  Result := nil;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if SameText(TreeName(Tree), Name) then
      Exit(Tree);
  end;
end;

// 直下の子ツリー数を返す
function ChildCount(Tree: TPsdFileTree): Integer;
var
  ChildTrees: TPsdFileTrees;
begin
  Result := 0;
  if Tree = nil then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees <> nil then
    Result := ChildTrees.Count;
end;

// 子ツリーを持たないツリーか判定する
function IsLeafTree(Tree: TPsdFileTree): Boolean;
begin
  Result := ChildCount(Tree) = 0;
end;

// 指定名の候補から子ツリー数が最も多いツリーを再帰的に探す
procedure FindBestNamedTreeSub(Trees: TPsdFileTrees; const Name: string;
  var BestTree: TPsdFileTree; var BestChildCount: Integer);
var
  i: Integer;
  Tree: TPsdFileTree;
  Count: Integer;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    if SameText(TreeName(Tree), Name) then
    begin
      Count := ChildCount(Tree);
      if Count > BestChildCount then
      begin
        BestTree := Tree;
        BestChildCount := Count;
      end;
    end;

    FindBestNamedTreeSub(TPsdFileTrees(Tree.Trees), Name, BestTree, BestChildCount);
  end;
end;

// 指定名の候補から子ツリー数が最も多いツリーを探す
function FindBestNamedTree(Trees: TPsdFileTrees; const Name: string): TPsdFileTree;
var
  BestChildCount: Integer;
begin
  Result := nil;
  BestChildCount := -1;
  FindBestNamedTreeSub(Trees, Name, Result, BestChildCount);
end;

// ツリーの直近の親ツリーを返す
function ParentTree(Tree: TPsdFileTree): TPsdFileTree;
begin
  Result := nil;
  if (Tree = nil) or (Tree.Owners = nil) or (Tree.Owners.Count = 0) then Exit;

  Result := TPsdFileTree(Tree.Owners[Tree.Owners.Count - 1]);
end;

end.
