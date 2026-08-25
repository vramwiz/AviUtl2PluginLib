unit PSDImageCustomTaotao;

interface

uses
  PsdImage;

function IsTaotaoShikokuMetanPSD(PsdImage: TPSDImage): Boolean;
procedure ApplyTaotaoShikokuMetanMarkers(PsdImage: TPSDImage);

implementation

uses
  System.SysUtils, PsdImageTree, PSDImageCustomMarkerUtils;

const
  LAYER_SHIKOKU_METAN = #$56DB#$56FD#$3081#$305F#$3093;
  LAYER_CHEER_POMPON = #$30C1#$30A2'_'#$30DD#$30F3#$30DD#$30F3;
  LAYER_EMANATA = #$6F2B#$7B26;
  LAYER_FACE_AREA = #$9854#$56DE#$308A;
  LAYER_COSTUME_DIFF = #$8863#$88C5#$5DEE#$5206;
  LAYER_HAIR_ACCESSORY = #$9AEA#$98FE#$308A;
  LAYER_EYEBROW = #$7709;
  LAYER_EYE = #$76EE;
  LAYER_CHEEK = #$982C;
  LAYER_MOUTH = #$53E3;
  LAYER_NORMAL_COSTUME = #$901A#$5E38#$8863#$88C5;
  LAYER_UNIFORM = #$5236#$670D;

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

function HasTaotaoMetanTreeStructure(Tree: TPsdFileTree): Boolean;
var
  MetanChildren: TPsdFileTrees;
  FaceTree: TPsdFileTree;
  DressTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;
  if not SameText(TreeName(Tree), LAYER_SHIKOKU_METAN) then Exit;

  MetanChildren := TPsdFileTrees(Tree.Trees);
  if not HasChildTrees(MetanChildren,
    [LAYER_CHEER_POMPON, LAYER_EMANATA, LAYER_FACE_AREA,
     LAYER_COSTUME_DIFF]) then
    Exit;

  FaceTree := FindChildTree(MetanChildren, LAYER_FACE_AREA);
  DressTree := FindChildTree(MetanChildren, LAYER_COSTUME_DIFF);
  if (FaceTree = nil) or (DressTree = nil) then Exit;

  Result :=
    HasChildTrees(TPsdFileTrees(FaceTree.Trees),
      [LAYER_EYEBROW, LAYER_EYE, LAYER_MOUTH]) and
    HasChildTrees(TPsdFileTrees(DressTree.Trees),
      [LAYER_NORMAL_COSTUME, LAYER_UNIFORM]);
end;

function HasTaotaoShikokuMetanRootStructure(Tree: TPsdFileTree): Boolean;
var
  RootChildren: TPsdFileTrees;
  MetanTree: TPsdFileTree;
begin
  Result := False;
  if Tree = nil then Exit;

  if HasTaotaoMetanTreeStructure(Tree) then
    Exit(True);

  if not SameText(TreeName(Tree), 'v1') then Exit;

  RootChildren := TPsdFileTrees(Tree.Trees);
  MetanTree := FindChildTree(RootChildren, LAYER_SHIKOKU_METAN);
  Result := HasTaotaoMetanTreeStructure(MetanTree);
end;

function HasTaotaoShikokuMetanRoot(Trees: TPsdFileTrees): Boolean;
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

    if HasTaotaoShikokuMetanRootStructure(Tree) then
      Exit(True);

    if HasTaotaoShikokuMetanRoot(TPsdFileTrees(Tree.Trees)) then
      Exit(True);
  end;
end;

function FindTaotaoMetanTree(Trees: TPsdFileTrees): TPsdFileTree;
var
  I: Integer;
  Tree: TPsdFileTree;
begin
  Result := nil;
  if Trees = nil then Exit;

  for I := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[I];
    if Tree = nil then Continue;

    if HasTaotaoMetanTreeStructure(Tree) then
      Exit(Tree);

    Result := FindTaotaoMetanTree(TPsdFileTrees(Tree.Trees));
    if Result <> nil then Exit;
  end;
end;

procedure MarkTaotaoFaceAreaParts(FaceTree: TPsdFileTree);
var
  FaceChildren: TPsdFileTrees;
  PartTree: TPsdFileTree;
  I: Integer;
const
  PART_NAMES: array[0..4] of string = (
    LAYER_HAIR_ACCESSORY,
    LAYER_EYEBROW,
    LAYER_EYE,
    LAYER_CHEEK,
    LAYER_MOUTH
  );
begin
  if FaceTree = nil then Exit;

  FaceChildren := TPsdFileTrees(FaceTree.Trees);
  if FaceChildren = nil then Exit;

  for I := Low(PART_NAMES) to High(PART_NAMES) do
  begin
    PartTree := FindChildTree(FaceChildren, PART_NAMES[I]);
    if PartTree <> nil then
      ReplaceMarkerOnTree(PartTree, '!');
  end;
end;

function IsTaotaoShikokuMetanPSD(PsdImage: TPSDImage): Boolean;
begin
  Result := (PsdImage <> nil) and HasTaotaoShikokuMetanRoot(PsdImage.Trees);
end;

procedure ApplyTaotaoShikokuMetanMarkers(PsdImage: TPSDImage);
var
  MetanTree: TPsdFileTree;
  FaceTree: TPsdFileTree;
begin
  if PsdImage = nil then Exit;

  MetanTree := FindTaotaoMetanTree(PsdImage.Trees);
  if MetanTree = nil then Exit;

  FaceTree := FindChildTree(TPsdFileTrees(MetanTree.Trees), LAYER_FACE_AREA);
  MarkTaotaoFaceAreaParts(FaceTree);
end;

end.
