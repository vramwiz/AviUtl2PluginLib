unit PSDImageElementList;

// PSDImageに追加する表情の大分類小分類

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,Generics.Collections,
  Generics.Defaults,PSDImage,PsdImageLayer,PsdImageChannel,ListBoxRTTIList,PsdImageTree;

type
  // 小分類
  TPSDElementPart = class(TListBoxRTTIItem)
  private
    FName              : string;   // 小分類名（クリーン後の名称）
    //FCaption           : string;   // ユーザーが編集可能な名称
    FLayerName         : string;   // 末端レイヤーの絶対パス
    FLayerIndex        : Integer;
    FElementPartIndex  : Integer;  // TPSDElementListから見て重複しないインデックス値
  public
  published
    property Name      : string read FName write FName;
    //property Caption   : string read GetCaption write FCaption;
    property LayerName : string read FLayerName write FLayerName;
    property LayerIndex: Integer read FLayerIndex write FLayerIndex;
    property ElementPartIndex : Integer read FElementPartIndex write FElementPartIndex;
  end;


  TPSDElementParts = class(TListBoxRTTIList<TPSDElementPart>)
  public
    // 小分類名で検索し、見つかればインデックスを返す
    function IndexOfName(const AName: string): Integer;
    // 小分類名の存在チェック
    function ExistsName(const AName: string): Boolean;
  end;


type
  // 大分類
	TPSDElementItem = class(TListBoxRTTIItem)
	private
	  FParts     : TPSDElementParts; // 小分類リスト
	  FGroup     : string;           // 同名 Element/Part を区別するための大分類までの親ルート
	  FName      : string;           // 大分類名（クリーン後の名称）
    FTree      : TPsdFileTree;      // 大分類名に該当する元ツリー
    FLayer     : TPsdFileLayer;     // 大分類名に該当する元レイヤー
    FHasBounds : Boolean;           // 小分類レイヤー群から取得した矩形が有効
    FBoundsLeft: Integer;           // 小分類レイヤー群の左端座標
    FBoundsTop : Integer;           // 小分類レイヤー群の上端座標
    FBoundsWidth : Integer;         // 小分類レイヤー群の幅
    FBoundsHeight: Integer;         // 小分類レイヤー群の高さ
    //FCaption   : string;           // ユーザーが編集可能な名称
    //FLayerName : string;           // この大分類の代表レイヤーパス
    // 小分類リストをテキスト化
    function GetPartsStr: string;
    // テキストを小分類リストへ展開
    procedure SetPartsStr(const Value: string);
  public
    // 小分類リスト生成
    constructor Create;
    // 小分類リスト解放
    destructor Destroy; override;
	    // ElementPartIndexの値が全て有効
	    function IsElementPartEnable() : Boolean;
	    // 小分類レイヤーの矩形を大分類の矩形へ集約
	    procedure IncludeLayerBounds(ALayer: TPsdFileLayer);
	    // 他の大分類が持つ矩形を大分類の矩形へ集約
	    procedure IncludeElementBounds(AElement: TPSDElementItem);
    // 矩形が同一か判定
    function SameBounds(AElement: TPSDElementItem): Boolean;
    property Parts     : TPSDElementParts read FParts;
    property Tree      : TPsdFileTree read FTree write FTree;
    property Layer     : TPsdFileLayer read FLayer write FLayer;
	published
	  property Group     : string read FGroup write FGroup;
	  property Name      : string read FName write FName;
    //property Caption   : string read GetCaption write FCaption;
    //property LayerName : string read FLayerName write FLayerName;
    property PartsStr  : string read GetPartsStr write SetPartsStr;
    property HasBounds : Boolean read FHasBounds;
    property BoundsLeft: Integer read FBoundsLeft;
    property BoundsTop : Integer read FBoundsTop;
    property BoundsWidth : Integer read FBoundsWidth;
    property BoundsHeight: Integer read FBoundsHeight;
  end;


type
  // 全体リスト（大分類の一覧）
  TPSDElementList = class(TListBoxRTTIList<TPSDElementItem>)
  private
	    FStrings : TStringList; // 解析用に一次元化したレイヤーパス群
	    FFilename: string;
	    // 探索の途中の小分類を削除
	    procedure NormalizeElements;
	    // Group が不要な同階層候補を従来の Element/Part 分類へ統合
	    procedure ResolveGroupUsageAndMerge;
	    // Group の階層数を返す
	    function GroupDepth(const AGroup: string): Integer;
		    // Group を使う必要がある Element/Part か判定
		    function NeedGroupForPart(AElement: TPSDElementItem; APart: TPSDElementPart): Boolean;
		    // PSD 全体で Group 方式が必要か判定
		    function HasNeedGroupUsage: Boolean;
		    // 標準方式のとき全 Part を従来分類へマージ
		    procedure MergeUngroupedParts(RemoveElements: TList<TPSDElementItem>);
		    // 空になった Group 付き Element を削除
		    procedure DeleteElementsInList(RemoveElements: TList<TPSDElementItem>);
		    // Group 空の Element を取得または作成
		    function FindOrCreateUngroupedElement(Source: TPSDElementItem): TPSDElementItem;
	    // Part を重複なしで追加
	    procedure AddPartIfMissing(Dest: TPSDElementItem; SourcePart: TPSDElementPart);
    // PSD ツリーの全レイヤーパスを再帰収集
    procedure ParseFromPSDSub(Trees: TPsdFileTrees;OwnerTree : TPsdFileTree);
    // 一次元パスから大分類/小分類を生成
    function  ParseFromStrings(): Boolean;
	    // 親ルートと大分類名で検索
	    function  FindElementByName(const Group,Name: string): TPSDElementItem;
    // Root 仮想分類に入れるルート直下パーツ名か判定
    function IsRootPartName(const AName: string): Boolean;
    // 表示用に先頭マーカーを外す
    function StripPartMarker(const AName: string): string;
    // Root 仮想分類へ小分類を追加
	    function AddRootPart(const APartName, ALayerName: string; ALayer: TPsdFileLayer): Boolean;
	    // Parts[0..LastIdx]を/で結合する
	    function BuildGroupName(const Parts: TArray<string>; LastIdx: Integer): string;
    // 小分類レイヤーから大分類レイヤーのツリーを推定
    function FindElementTreeFromPartLayer(ALayer: TPsdFileLayer; const ElemName: string; ElemIdx: Integer): TPsdFileTree;
    // 条件成立時に大分類レイヤー名の先頭へ '*' を付ける
    procedure EnsureElementStar(Element: TPSDElementItem);
    // フォルダ名変更後の子孫 ANM パスを更新
    procedure RefreshAnmPath(Tree: TPsdFileTree; const GroupPath: string);
  public
    // 初期化（FStrings 生成）
    constructor Create;
    // 終了処理（FStrings 解放）
    destructor Destroy; override;
    // PSD から大分類/小分類を解析
    function ParseFromPSD(PSDImage: TPSDImage): Boolean;
    // True : 有効なデータが存在する False : PSDデータから読み込み直した方が良い
    function IsEnableData() : Boolean;
    // ElementPartIndexの値が全て有効
    function IsElementPartEnable() : Boolean;

    // ファイル読み込み
    //procedure LoadFromFile;override;
    // ファイル保存
    //procedure SaveToFile;override;
    // インデックス値に該当する大分類小分類を返す
	    function IndexToElementPartName(const Index : Integer;var Element,Part : string) :  Boolean; overload;
	    function IndexToElementPartName(const Index : Integer;var Group,Element,Part : string) :  Boolean; overload;
    // 矩形が一致する大分類の元レイヤー名に '*' を付与する
    procedure ApplyElementStarsByMatchingBounds;

    property FileName : string read FFileName write FFileName;
  end;


implementation

uses SectionFileManager;

{ TPSDElementList }

constructor TPSDElementList.Create;
begin
  inherited;
  FStrings := TStringList.Create;
end;

destructor TPSDElementList.Destroy;
begin
  FStrings.Free;
  inherited;
end;


function TPSDElementList.ParseFromPSD(PSDImage: TPSDImage): Boolean;
begin
  Result := False;
  if PSDImage = nil then Exit;

  FStrings.Clear;

  // ツリーを再帰的に展開して絶対レイヤーパスを作る
  ParseFromPSDSub(PSDImage.Trees,nil);

  // 一次元化されたリストを解析して Element / Part を生成
  Result := ParseFromStrings();

	  // Element / Part 構造を整理
	  NormalizeElements;

	  // Group 階層差がない重複は従来の Element/Part 分類へ戻す
	  ResolveGroupUsageAndMerge;
	  NormalizeElements;
	end;

procedure TPSDElementList.ParseFromPSDSub(Trees: TPsdFileTrees;OwnerTree : TPsdFileTree);
var
  i    : Integer;
  Tree : TPsdFileTree;
  Layer: TPsdFileLayer;
begin
  if Trees = nil then Exit;

  for i := Trees.Count - 1 downto 0 do
  begin
    Tree  := Trees[i];
    if Tree = nil then Continue;

    Layer := Tree.Layer;
    if Layer <> nil then
      FStrings.AddObject(Layer.AnmText,Layer);

    // 再帰
    ParseFromPSDSub(TPsdFileTrees(Tree.Trees),Tree);
  end;
end;

{----------------------------------------}
{  名前で Element（大分類）を検索        }
{----------------------------------------}
function TPSDElementList.FindElementByName(const Group,Name: string): TPSDElementItem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if SameText(Items[i].Group, Group) and SameText(Items[i].Name, Name) then
      Exit(Items[i]);
end;

function TPSDElementList.IndexToElementPartName(const Index: Integer;  var Element, Part: string): Boolean;
var
  Group: string;
begin
  Result := IndexToElementPartName(Index,Group,Element,Part);
end;

function TPSDElementList.IndexToElementPartName(const Index: Integer;
  var Group, Element, Part: string): Boolean;
var
  i,j : Integer;
  es : TPSDElementItem;
  ps : TPSDElementPart;
begin
  Result := False;
  for j := 0 to Count-1 do begin
    es := Items[j];
    for i := 0 to es.FParts.Count-1 do begin
      ps := es.FParts[i];
      if ps.FElementPartIndex <> Index then Continue;
      Group   := es.Group;
      Element := es.Name;
      Part    := ps.Name;
      Exit(True);
    end;

  end;

end;

procedure TPSDElementList.NormalizeElements;
var
  i, j, k : Integer;
  Elem : TPSDElementItem;
  PartA, PartB : TPSDElementPart;
  RemoveList : TList<Integer>;
begin
  RemoveList := TList<Integer>.Create;
  try
    for i := 0 to Count - 1 do
    begin
      Elem := Items[i];
      RemoveList.Clear;

      for j := 0 to Elem.Parts.Count - 1 do
      begin
        PartA := Elem.Parts[j];

        for k := 0 to Elem.Parts.Count - 1 do
        begin
          if j = k then Continue;

          PartB := Elem.Parts[k];

          // PartA が PartB の親なら削除
          if StartsText(PartA.Name + '/', PartB.Name) then
          begin
            RemoveList.Add(j);
            Break;
          end;
        end;
      end;

      for j := RemoveList.Count - 1 downto 0 do
        Elem.Parts.Delete(RemoveList[j]);
    end;
  finally
    RemoveList.Free;
  end;
end;

function TPSDElementList.GroupDepth(const AGroup: string): Integer;
var
  i: Integer;
  S: string;
begin
  S := Trim(AGroup);
  if S = '' then Exit(0);

  Result := 1;
  for i := 1 to Length(S) do
    if S[i] = '/' then Inc(Result);
end;

function TPSDElementList.NeedGroupForPart(AElement: TPSDElementItem;
  APart: TPSDElementPart): Boolean;
var
  i, j: Integer;
  Elem: TPSDElementItem;
  Part: TPSDElementPart;
  BaseDepth: Integer;
begin
  Result := False;
  if (AElement = nil) or (APart = nil) then Exit;
  if SameText(AElement.Name, 'Root') then Exit;

  BaseDepth := GroupDepth(AElement.Group);
  for i := 0 to Count - 1 do
  begin
    Elem := Items[i];
    if (Elem = nil) or (Elem = AElement) then Continue;
    if not SameText(Elem.Name, AElement.Name) then Continue;

    for j := 0 to Elem.Parts.Count - 1 do
    begin
      Part := Elem.Parts[j];
      if (Part = nil) or (not SameText(Part.Name, APart.Name)) then Continue;

      // 同じ Element/Part で Group 階層数が異なる場合だけ Group 指定が必要
      if GroupDepth(Elem.Group) <> BaseDepth then
        Exit(True);
    end;
	  end;
	end;

function TPSDElementList.FindOrCreateUngroupedElement(
  Source: TPSDElementItem): TPSDElementItem;
begin
  Result := nil;
  if Source = nil then Exit;

  Result := FindElementByName('', Source.Name);
  if Result <> nil then Exit;

  Result := AddNew;
  Result.Group := '';
  Result.Name := Source.Name;
  Result.Caption := Source.Name;
  Result.Tree := Source.Tree;
  Result.Layer := Source.Layer;
end;

procedure TPSDElementList.AddPartIfMissing(Dest: TPSDElementItem;
  SourcePart: TPSDElementPart);
var
  Part: TPSDElementPart;
begin
  if (Dest = nil) or (SourcePart = nil) then Exit;
  if Dest.Parts.ExistsName(SourcePart.Name) then Exit;

  Part := Dest.Parts.AddNew;
  Part.Name := SourcePart.Name;
  Part.Caption := SourcePart.Caption;
  Part.LayerName := SourcePart.LayerName;
  Part.LayerIndex := SourcePart.LayerIndex;
	Part.ElementPartIndex := SourcePart.ElementPartIndex;
end;

function TPSDElementList.HasNeedGroupUsage: Boolean;
var
  i, j: Integer;
  Elem: TPSDElementItem;
  Part: TPSDElementPart;
begin
  Result := False;

  for i := 0 to Count - 1 do
  begin
    Elem := Items[i];
    if (Elem = nil) or SameText(Elem.Name, 'Root') then Continue;

    for j := 0 to Elem.Parts.Count - 1 do
    begin
      Part := Elem.Parts[j];
      if NeedGroupForPart(Elem, Part) then
        Exit(True); // 1件でも条件成立したら PSD 全体を Group 方式として扱う
    end;
  end;
end;

procedure TPSDElementList.MergeUngroupedParts(
  RemoveElements: TList<TPSDElementItem>);
var
  i, j: Integer;
  Elem, Target: TPSDElementItem;
  Part: TPSDElementPart;
begin
  if RemoveElements = nil then Exit;

  for i := 0 to Count - 1 do
  begin
    Elem := Items[i];
    if (Elem = nil) or SameText(Elem.Name, 'Root') then Continue;

    for j := Elem.Parts.Count - 1 downto 0 do
    begin
      Part := Elem.Parts[j];

      // Group 不要な同階層候補は Group を消して Element/Part の従来分類へマージする
      Target := FindOrCreateUngroupedElement(Elem);
      AddPartIfMissing(Target, Part);
      Target.IncludeElementBounds(Elem);

      if Target <> Elem then
        Elem.Parts.Delete(j);
    end;

    if (Elem.Group <> '') and (Elem.Parts.Count = 0) then
      RemoveElements.Add(Elem);
  end;
end;

procedure TPSDElementList.DeleteElementsInList(
  RemoveElements: TList<TPSDElementItem>);
var
  i: Integer;
begin
  if RemoveElements = nil then Exit;

  for i := Count - 1 downto 0 do
    if RemoveElements.Contains(Items[i]) then
      Delete(i);
end;

procedure TPSDElementList.ResolveGroupUsageAndMerge;
var
  RemoveElements: TList<TPSDElementItem>;
begin
  if HasNeedGroupUsage then Exit; // 特殊構造がある PSD は全体を Group 方式のまま保持する

  RemoveElements := TList<TPSDElementItem>.Create;
  try
    MergeUngroupedParts(RemoveElements);
    DeleteElementsInList(RemoveElements);
  finally
    RemoveElements.Free;
  end;
end;

function TPSDElementList.IsElementPartEnable: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Count-1 do begin
    if not Items[i].IsElementPartEnable then Exit;
  end;
  Result := True;
end;

function TPSDElementList.IsEnableData: Boolean;
begin
  Result := False;
  if Count = 0 then Exit;                      // 表情データが無い無効とする
  Result := True;
end;

function TPSDElementList.AddRootPart(const APartName, ALayerName: string; ALayer: TPsdFileLayer): Boolean;
var
  RootElement: TPSDElementItem;
  RootPart: TPSDElementPart;
begin
  Result := False;
  if (ALayer = nil) or (not IsRootPartName(APartName)) then Exit;

  RootElement := FindElementByName('', 'Root');
  if RootElement = nil then
  begin
    RootElement := AddNew;
    RootElement.Group := '';
    RootElement.Name := 'Root';
    RootElement.Caption := 'Root';
  end;

  if RootElement.Parts.ExistsName(APartName) then Exit;

  RootPart := RootElement.Parts.AddNew;
  RootPart.Name := APartName;
  RootPart.Caption := StripPartMarker(APartName);
  RootPart.LayerName := ALayerName;
  RootPart.LayerIndex := ALayer.Index;
  RootPart.ElementPartIndex := -(RootElement.Parts.Count);
  Result := True;
end;

procedure TPSDElementList.ApplyElementStarsByMatchingBounds;
var
  i, j: Integer;
  ElementA, ElementB: TPSDElementItem;
begin
  for i := 0 to Count - 1 do
  begin
    ElementA := Items[i];
    if (ElementA = nil) or SameText(ElementA.Name, 'Root') or
       (not ElementA.HasBounds) or (ElementA.Layer = nil) then
      Continue;

    for j := i + 1 to Count - 1 do
    begin
      ElementB := Items[j];
      if (ElementB = nil) or SameText(ElementB.Name, 'Root') or
         (not ElementB.HasBounds) or (ElementB.Layer = nil) then
        Continue;

      if ElementA.SameBounds(ElementB) then
      begin
        EnsureElementStar(ElementA);
        EnsureElementStar(ElementB);
      end;
    end;
  end;
end;

procedure TPSDElementList.EnsureElementStar(Element: TPSDElementItem);
var
  Layer: TPsdFileLayer;
  S: string;
  GroupPath: string;
begin
  if Element = nil then Exit;

  Layer := Element.Layer;
  if Layer = nil then Exit;

  S := Layer.Name;
  if (S <> '') and (S[1] = '*') then Exit;

  GroupPath := Layer.AnmGroup2;
  Layer.Name := '*' + S;
  RefreshAnmPath(Element.Tree, GroupPath);
end;

function TPSDElementList.FindElementTreeFromPartLayer(ALayer: TPsdFileLayer;
  const ElemName: string; ElemIdx: Integer): TPsdFileTree;
var
  PartTree: TPsdFileTree;
  OwnerIndex, i: Integer;
  OwnerTree: TPsdFileTree;
begin
  Result := nil;
  if ALayer = nil then Exit;

  PartTree := TPsdFileTree(ALayer.Tree);
  if PartTree = nil then Exit;

  // Owners はダミールートを含むため、パス上の index とは +1 ずれる。
  OwnerIndex := ElemIdx + 1;
  if (OwnerIndex >= 0) and (OwnerIndex < PartTree.Owners.Count) then
  begin
    OwnerTree := TPsdFileTree(PartTree.Owners[OwnerIndex]);
    if (OwnerTree <> nil) and (OwnerTree.Layer <> nil) and
       SameText(Trim(OwnerTree.Layer.Name), Trim(ElemName)) then
      Exit(OwnerTree);
  end;

  for i := PartTree.Owners.Count - 1 downto 0 do
  begin
    OwnerTree := TPsdFileTree(PartTree.Owners[i]);
    if (OwnerTree <> nil) and (OwnerTree.Layer <> nil) and
       SameText(Trim(OwnerTree.Layer.Name), Trim(ElemName)) then
      Exit(OwnerTree);
  end;
end;

procedure TPSDElementList.RefreshAnmPath(Tree: TPsdFileTree; const GroupPath: string);
var
  i: Integer;
  Layer: TPsdFileLayer;
  ChildGroupPath: string;
begin
  if Tree = nil then Exit;

  Layer := Tree.Layer;
  if Layer = nil then Exit;

  Layer.SetAnmGroupPath(GroupPath);
  ChildGroupPath := Layer.AnmText + '/';

  for i := 0 to TPsdFileTrees(Tree.Trees).Count - 1 do
    RefreshAnmPath(TPsdFileTrees(Tree.Trees)[i], ChildGroupPath);
end;

function TPSDElementList.IsRootPartName(const AName: string): Boolean;
begin
  Result := (AName <> '') and (AName[1] = '*');
end;

function TPSDElementList.StripPartMarker(const AName: string): string;
begin
  if (AName <> '') and ((AName[1] = '*') or (AName[1] = '+')) then
    Result := Copy(AName, 2, MaxInt)
  else
    Result := AName;
end;

function TPSDElementList.BuildGroupName(const Parts: TArray<string>;
  LastIdx: Integer): string;
var
  i: Integer;
begin
  Result := '';
  if LastIdx < 0 then Exit;
  if LastIdx > High(Parts) then LastIdx := High(Parts);

  for i := 0 to LastIdx do
  begin
    if Parts[i] = '' then Continue;
    if Result <> '' then Result := Result + '/';
    Result := Result + Parts[i];
  end;
end;

{----------------------------------------}
{  FStrings を解析し、大分類/小分類を生成 }
{----------------------------------------}
function TPSDElementList.ParseFromStrings(): Boolean;
var
  i, j: Integer;
  S: string;
  Parts: TArray<string>;
  PartIdx, ElemIdx: Integer;
  GroupName, ElemName, PartName, RouteName: string;
  Element: TPSDElementItem;
  Part: TPSDElementPart;
  Layer: TPsdFileLayer;
begin
  Result := False;

  for i := FStrings.Count - 1 downto 0 do
  begin
    S := FStrings[i].Trim;
    if S = '' then Continue;

    Layer := TPsdFileLayer(FStrings.Objects[i]);
    if Layer = nil then Continue;

    Parts := S.Split(['/']);

    // ルート直下、または !v1 直下のキャラ選択レイヤーを Root 大分類として扱う。
    if High(Parts) > 0 then begin
      if Copy(Parts[0],1,1) = '*' then begin
        if AddRootPart(Parts[0], S, Layer) then Result := True;
      end;
    end;

    if Length(Parts) < 2 then Continue;

    // -----------------------------
    // 1) 小分類（* または +）の位置を探す
    // -----------------------------
    PartIdx := -1;
    for j := High(Parts) downto 0 do
    begin
      if (Parts[j] <> '') and ((Parts[j][1] = '*') or (Parts[j][1] = '+')) then
      begin
        PartIdx := j;
        Break;
      end;
    end;

    if PartIdx < 0 then Continue;

    // -----------------------------
    // 2) 大分類（!）の位置を探す
    // -----------------------------
    ElemIdx := -1;
    for j := PartIdx - 1 downto 0 do
    begin
      if Parts[j].Contains('!') then
      begin
        ElemIdx := j;
        Break;
      end;
    end;

    if (ElemIdx < 0) and (PartIdx - 1 >= 0) then
      ElemIdx := PartIdx - 1;

    if ElemIdx < 0 then Continue;

    ElemName := Parts[ElemIdx];
    if ElemName = '' then Continue;

    GroupName := BuildGroupName(Parts, ElemIdx - 1); // 同名 Element を親ルート別に分ける

    // -----------------------------
    // 3) 小分類名（相対ルート）を構築
    //    ElemIdx は含めない
    // -----------------------------
    RouteName := '';
    for j := ElemIdx + 1 to PartIdx do
    begin
      if RouteName <> '' then RouteName := RouteName + '/';
      RouteName := RouteName + Parts[j];
    end;

    if RouteName = '' then Continue;

    // 表示用 Caption は末端のみ
    PartName := Parts[PartIdx];

    // -----------------------------
    // 4) 大分類の取得 / 作成
    // -----------------------------
    Element := FindElementByName(GroupName, ElemName);
    if Element = nil then
    begin
      Element := AddNew;
      Element.Group   := GroupName; // Group + Element が分類上の一意キー
      Element.Name    := ElemName;
      if GroupName <> '' then
        Element.Caption := GroupName + '/' + ElemName
      else
        Element.Caption := ElemName;
    end;

    if Element.Tree = nil then
    begin
      Element.Tree := FindElementTreeFromPartLayer(Layer, ElemName, ElemIdx);
      if Element.Tree <> nil then
        Element.Layer := Element.Tree.Layer;
    end;

    // -----------------------------
    // 5) 小分類を追加
    // -----------------------------
    {
    // 同じ内部小分類名(RouteName)のパーツは重複追加しない
    if Element.Parts.ExistsName(RouteName) then
      Continue;
    }

    Part := Element.Parts.AddNew;
    Part.Name := RouteName;              // 内部用：相対ルート
    Part.Caption := RouteName;            // 表示用
    //Part.Caption := PartName;            // 表示用
    Part.LayerName := S;
    Part.LayerIndex := Layer.Index;
    Part.ElementPartIndex := i;

    Element.IncludeLayerBounds(Layer);

    Result := True;
  end;
end;


{ TPSDElementParts }

function TPSDElementParts.IndexOfName(const AName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if SameText(Items[i].Name, AName) then Exit(i);
  Result := -1;
end;

function TPSDElementParts.ExistsName(const AName: string): Boolean;
begin
  Result := IndexOfName(AName) <> -1;
end;

{ TPSDElementItem }

constructor TPSDElementItem.Create;
begin
  FParts := TPSDElementParts.Create;
  FGroup := '';
  FTree := nil;
  FLayer := nil;
  FHasBounds := False;
  FBoundsLeft := 0;
  FBoundsTop := 0;
  FBoundsWidth := 0;
  FBoundsHeight := 0;
end;

destructor TPSDElementItem.Destroy;
begin
  FParts.Free;
  inherited;
end;

function TPSDElementItem.GetPartsStr: string;
begin
  Result := FParts.SerializeToText();
end;

function TPSDElementItem.IsElementPartEnable: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to FParts.Count-1 do begin
    if FParts[i].FElementPartIndex = 0 then Exit;
  end;
  Result := True;
end;

procedure TPSDElementItem.IncludeLayerBounds(ALayer: TPsdFileLayer);
var
  Channel: TPsdFileChannel;
  LeftValue, TopValue, RightValue, BottomValue: Integer;
  CurRight, CurBottom: Integer;
begin
  if (ALayer = nil) or (ALayer.Channels = nil) or (ALayer.Channels.Count = 0) then
    Exit;

  Channel := ALayer.Channels[0];
  if (Channel = nil) or (Channel.Width <= 0) or (Channel.Height <= 0) then
    Exit;

  LeftValue := Channel.Left;
  TopValue := Channel.Top;
  RightValue := Channel.Left + Channel.Width;
  BottomValue := Channel.Top + Channel.Height;

  if not FHasBounds then
  begin
    FBoundsLeft := LeftValue;
    FBoundsTop := TopValue;
    FBoundsWidth := Channel.Width;
    FBoundsHeight := Channel.Height;
    FHasBounds := True;
    Exit;
  end;

  CurRight := FBoundsLeft + FBoundsWidth;
  CurBottom := FBoundsTop + FBoundsHeight;

  if LeftValue < FBoundsLeft then
    FBoundsLeft := LeftValue;
  if TopValue < FBoundsTop then
    FBoundsTop := TopValue;
  if RightValue > CurRight then
    CurRight := RightValue;
  if BottomValue > CurBottom then
    CurBottom := BottomValue;

  FBoundsWidth := CurRight - FBoundsLeft;
  FBoundsHeight := CurBottom - FBoundsTop;
end;

procedure TPSDElementItem.IncludeElementBounds(AElement: TPSDElementItem);
var
  LeftValue, TopValue, RightValue, BottomValue: Integer;
  CurRight, CurBottom: Integer;
begin
  if (AElement = nil) or (not AElement.HasBounds) then Exit;

  LeftValue := AElement.BoundsLeft;
  TopValue := AElement.BoundsTop;
  RightValue := AElement.BoundsLeft + AElement.BoundsWidth;
  BottomValue := AElement.BoundsTop + AElement.BoundsHeight;

  if not FHasBounds then
  begin
    FBoundsLeft := LeftValue;
    FBoundsTop := TopValue;
    FBoundsWidth := AElement.BoundsWidth;
    FBoundsHeight := AElement.BoundsHeight;
    FHasBounds := True;
    Exit;
  end;

  CurRight := FBoundsLeft + FBoundsWidth;
  CurBottom := FBoundsTop + FBoundsHeight;

  if LeftValue < FBoundsLeft then
    FBoundsLeft := LeftValue;
  if TopValue < FBoundsTop then
    FBoundsTop := TopValue;
  if RightValue > CurRight then
    CurRight := RightValue;
  if BottomValue > CurBottom then
    CurBottom := BottomValue;

  FBoundsWidth := CurRight - FBoundsLeft;
  FBoundsHeight := CurBottom - FBoundsTop;
end;

function TPSDElementItem.SameBounds(AElement: TPSDElementItem): Boolean;
begin
  Result := (AElement <> nil) and
            FHasBounds and AElement.FHasBounds and
            (FBoundsLeft = AElement.FBoundsLeft) and
            (FBoundsTop = AElement.FBoundsTop) and
            (FBoundsWidth = AElement.FBoundsWidth) and
            (FBoundsHeight = AElement.FBoundsHeight);
end;

procedure TPSDElementItem.SetPartsStr(const Value: string);
begin
  FParts.DeserializeFromText(Value);
end;



end.
