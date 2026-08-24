unit PSDImageCustomShimaDonpachiMei;

interface

uses
  PsdImage;

function IsShimaDonpachiMeiPSD(PsdImage: TPSDImage): Boolean;

procedure ApplyShimaDonpachiMeiMarkers(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

function HasText(const S, Token: string): Boolean;
begin
  Result := Pos(LowerCase(Token), LowerCase(S)) > 0;
end;

function IsShimaDonpachiMeiFileName(const FileName: string): Boolean;
var
  Name: string;
begin
  Name := ChangeFileExt(ExtractFileName(FileName), '');
  Result :=
    HasText(Name, 'メイ式') or
    HasText(Name, 'ちょこんと') or
    HasText(Name, '島でドンパチするメイ');
end;

function HasShimaDonpachiMeiLayer(Trees: TPsdFileTrees): Boolean;
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

    if SameText(TreeName(Tree), 'ちょこんと立ち絵') then
      Exit(True);

    if HasShimaDonpachiMeiLayer(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function IsShimaDonpachiMeiPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and
            (HasShimaDonpachiMeiLayer(PsdImage.Trees) or
             IsShimaDonpachiMeiFileName(PsdImage.FileName));
end;

function FindShimaDonpachiMeiRootTrees(Trees: TPsdFileTrees): TPsdFileTrees;
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

    // 「ちょこんと立ち絵」は候補の親ではなく、同じ階層を示す目印として扱う。
    if SameText(TreeName(Tree), 'ちょこんと立ち絵') then
      Exit(Trees);

    Result := FindShimaDonpachiMeiRootTrees(TPsdFileTrees(Tree.Trees));
    if Result <> nil then Exit;
  end;
end;

procedure ApplyShimaDonpachiMeiMarkers(PsdImage: TPSDImage);
var
  RootTrees: TPsdFileTrees;
  BodyTree: TPsdFileTree;
  BodyChildren: TPsdFileTrees;
  i: Integer;
  Tree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  RootTrees := FindShimaDonpachiMeiRootTrees(PsdImage.Trees);
  BodyTree := FindChildTree(RootTrees, '素体');
  if BodyTree = nil then
    BodyTree := FindBestNamedTree(PsdImage.Trees, '素体');
  if BodyTree = nil then Exit;

  BodyChildren := TPsdFileTrees(BodyTree.Trees);
  if BodyChildren = nil then Exit;

  for i := 0 to BodyChildren.Count - 1 do
  begin
    Tree := BodyChildren[i];
    if Tree = nil then Continue;
    // 島でドンパチするメイ氏PSDは「素体」直下のキャラ一覧を排他選択候補にする。
    ReplaceMarkerOnTree(Tree, '*');
  end;
end;

end.
