unit PsdImageTree;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,PsdImageDefine,
  PsdImageFileStreamBuf,PsdImageBlend,PsdImageChannel,PsdImageLayer;

type
  TPsdFileTreeVisibilityRule = class;

  TPsdFileTree = class(TPersistent)
  private
    { Private 宣言 }
    FLevel: Integer;                      // 階層レベル　※まだ未対応
    FLayer: TPsdFileLayer;                // 対応するレイヤー
    FTrees: TObject;                      // その下にあるツリー
    //FOwner: TObject;                      // その上にあるツリー
    FNode : TObject;
    FVisible: Boolean;
    FImageIndex: Integer;
    FOwners: TList;
    FVisibilityRuleRefs: TList;
    function GetIsChildren: Boolean;
    function GetIsMultiSelect: Boolean;
    procedure SetVisible(const Value: Boolean);
    function GetIsAlways: Boolean;
    procedure AddVisibilityRuleRef(Rule: TPsdFileTreeVisibilityRule);
    procedure ApplyVisibilityRules;
    procedure HideInitialDressSiblingsForFaceSelection;
  public
    { Public 宣言 }
    constructor Create();
    destructor Destroy;override;
    // 親まで遡って非表示か判定
    function IsTreeEffectivelyVisible(Tree: TPsdFileTree): Boolean;
    // AlwayCtrl=True !が付いていても非表示にする
    procedure SetLayerVisible(const AlwayCtrl,Value: Boolean);
    // 親子や兄弟へ影響を与えず、このノードだけを切り替える
    procedure SetVisibleLocal(const Value: Boolean);
    // 親子や兄弟へ影響を与えずに切り替え、ON時の表示連動ルールだけ実行する
    procedure SetVisibleLocalAndApplyRules(const Value: Boolean);
    // ON時に発火する表示連動ルールの参照を消去する
    procedure ClearVisibilityRuleRefs;

    property IsChildren : Boolean read  GetIsChildren;

    property Trees : TObject read FTrees;
    //property Owner : TObject read FOwner;
    property Owners : TList read FOwners;
    property Layer : TPsdFileLayer read FLayer write FLayer;
    property Level : Integer read FLevel write FLevel;
    property Node  : TObject read FNode write FNode;
    property Visible : Boolean read FVisible write SetVisible;
    property ImageIndex : Integer read FImageIndex write FImageIndex;
     // True : 複数選択可能な要素
    property IsMultiSelect : Boolean read GetIsMultiSelect;
    //  True : 常にVisibleでなければならない
    property IsAlways      : Boolean read GetIsAlways;
  end;

//--------------------------------------------------------------------------//
//  レイヤー情報をツリー形式で管理するクラス                                //
//--------------------------------------------------------------------------//
	TPsdFileTrees = class(TList)
	private
		{ Private 宣言 }
    function GetTrees(Index: Integer): TPsdFileTree;
	public
		{ Public 宣言 }
    destructor Destroy;override;
    function Add() : TPsdFileTree;
    procedure Delete(i : Integer);
    procedure Clear();override;

    function IndexOfLayer(dl : TPsdFileLayer) : Integer;
		property Trees[Index: Integer] : TPsdFileTree read GetTrees ;default;
	end;

  TPsdFileTreeVisibilityAction = class(TPersistent)
  private
    FTree: TPsdFileTree;
    FVisible: Boolean;
  public
    constructor Create(ATree: TPsdFileTree; AVisible: Boolean);
    property Tree: TPsdFileTree read FTree;
    property Visible: Boolean read FVisible;
  end;

  TPsdFileTreeVisibilityRule = class(TPersistent)
  private
    FTriggerTree: TPsdFileTree;
    FActions: TList;
    function GetCount: Integer;
    function GetActions(Index: Integer): TPsdFileTreeVisibilityAction;
  public
    constructor Create(ATriggerTree: TPsdFileTree);
    destructor Destroy; override;
    function AddAction(TargetTree: TPsdFileTree; TargetVisible: Boolean): Boolean;
    function ContainsAction(TargetTree: TPsdFileTree; TargetVisible: Boolean): Boolean;
    procedure Clear;
    procedure Execute;
    property TriggerTree: TPsdFileTree read FTriggerTree;
    property Count: Integer read GetCount;
    property Actions[Index: Integer]: TPsdFileTreeVisibilityAction read GetActions; default;
  end;

  TPsdFileTreeVisibilityRules = class(TList)
  private
    function GetRules(Index: Integer): TPsdFileTreeVisibilityRule;
  public
    destructor Destroy; override;
    function AddRule(TriggerTree: TPsdFileTree): TPsdFileTreeVisibilityRule;
    function AddAction(TriggerTree, TargetTree: TPsdFileTree; TargetVisible: Boolean): Boolean;
    procedure Clear; override;
    function FindRule(TriggerTree: TPsdFileTree): TPsdFileTreeVisibilityRule;
    function GetOrAddRule(TriggerTree: TPsdFileTree): TPsdFileTreeVisibilityRule;
    property Rules[Index: Integer]: TPsdFileTreeVisibilityRule read GetRules; default;
  end;

	TPsdFileTreeExs = class(TList)
	private
		{ Private 宣言 }
    FFlipMode : Integer;
    function GetTrees(Index: Integer): TPsdFileTree;
    function GetVisibleString: string;
    procedure SetVisibleString(const Value: string);
	public
		{ Public 宣言 }
		property Trees[Index: Integer] : TPsdFileTree read GetTrees ;default;
    property VisibleString: string read GetVisibleString write SetVisibleString;
    property FlipMode : Integer read FFlipMode write FFlipMode;
	end;



implementation

{$IFDEF DEBUG}
uses
  PSDImageDebugLog;
{$ENDIF}

{$IFDEF DEBUG}
const
  ENABLE_VERBOSE_PSD_VISIBILITY_RULE_LOG = False;

procedure VisibilityRuleDebugLog(const S: string);
begin
  if not ENABLE_VERBOSE_PSD_VISIBILITY_RULE_LOG then Exit;
  PSDDebugLog('PSDVisibilityRule', S);
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

function DebugTreeName(Tree: TPsdFileTree): string;
begin
  Result := '';
  if (Tree <> nil) and (Tree.Layer <> nil) then
    Result := Tree.Layer.Name;
end;

function IsDebugArmTree(Tree: TPsdFileTree): Boolean;
var
  S: string;
begin
  S := DebugTreePath(Tree);
  Result := (Pos('腕', S) > 0) or
            (Pos('右腕', S) > 0) or
            (Pos('(右)', S) > 0) or
            (Pos('（右）', S) > 0);
end;
{$ENDIF}


{ TPsdFileTreeFrameTrees }

destructor TPsdFileTrees.Destroy;
begin
  Clear();
  inherited;
end;

function TPsdFileTrees.Add: TPsdFileTree;
var
  d : TPsdFileTree;
begin
  d := TPsdFileTree.Create;
  //d.FOwner := Self;
  inherited Add(d);
  result := d;
end;

procedure TPsdFileTrees.Clear;
var
  i : Integer;
begin
  for i := 0 to Count-1 do begin
    Trees[i].Free;
  end;
  inherited;
end;

procedure TPsdFileTrees.Delete(i: Integer);
begin
  Trees[i].Free;
  inherited Delete(i);
end;

function TPsdFileTrees.GetTrees(Index: Integer): TPsdFileTree;
begin
  result := inherited Items[Index];
end;

{
function TPsdFileTrees.GetLayerTree( dl: TPsdFileLayer): TPsdFileTree;
var
  i : Integer;
  ts : TPsdFileTree;
begin
  i := IndexOfLayer(dl);
  ts := Items[i];
  result := TPsdFileTree(ts.FTrees);
end;
}

function TPsdFileTrees.IndexOfLayer(dl: TPsdFileLayer): Integer;
var
  i : Integer;
begin
  result := -1;
  for i := 0 to Count-1 do begin
    if Trees[i].FLayer = dl then begin
      result := i;
      exit;
    end;
  end;

end;

{ TPsdFileTreeFrameTree }

constructor TPsdFileTree.Create;
begin
  FTrees := TPsdFileTrees.Create;
  FOwners := TList.Create;
  FVisibilityRuleRefs := TList.Create;
end;

destructor TPsdFileTree.Destroy;
begin
  FVisibilityRuleRefs.Free;
  FOwners.Free;
   FTrees.Free;
  inherited;
end;

procedure TPsdFileTree.AddVisibilityRuleRef(Rule: TPsdFileTreeVisibilityRule);
begin
  if Rule = nil then Exit;
  if FVisibilityRuleRefs.IndexOf(Rule) >= 0 then Exit;

  FVisibilityRuleRefs.Add(Rule);
end;

procedure TPsdFileTree.ApplyVisibilityRules;
var
  i: Integer;
  Rule: TPsdFileTreeVisibilityRule;
begin
  for i := 0 to FVisibilityRuleRefs.Count - 1 do
  begin
    Rule := TPsdFileTreeVisibilityRule(FVisibilityRuleRefs[i]);
    if Rule <> nil then
      Rule.Execute;
  end;
end;

procedure TPsdFileTree.ClearVisibilityRuleRefs;
begin
  FVisibilityRuleRefs.Clear;
end;

function TPsdFileTree.GetIsAlways: Boolean;
var
  dl : TPsdFileLayer;
begin
  result := False;
  dl := FLayer;
  if dl = nil then exit;
  result := Copy(dl.Name,1,1) = '!';
end;

function TPsdFileTree.GetIsChildren: Boolean;
var
  tss : TPsdFileTrees;
begin
  tss := TPsdFileTrees(FTrees);             // 子供が居るかどうかで判断
  result := tss.Count > 0;
end;


function TPsdFileTree.GetIsMultiSelect: Boolean;
var
  dl : TPsdFileLayer;
  s : string;
begin
  result := False;
  dl := FLayer;
  if dl = nil then exit;
  s := Copy(dl.Name,1,1);
  result := (s <> '*');
end;

procedure TPsdFileTree.HideInitialDressSiblingsForFaceSelection;
var
  I: Integer;
  ParentTree: TPsdFileTree;
  SiblingTrees: TPsdFileTrees;
  SiblingTree: TPsdFileTree;
  Marker: string;
begin
  if FLayer = nil then Exit;

  Marker := Copy(FLayer.Name, 1, 1);
  if (Marker <> '*') and (Marker <> '+') then Exit;
  if FOwners.Count = 0 then Exit;

  ParentTree := TPsdFileTree(FOwners[FOwners.Count - 1]);
  if ParentTree = nil then Exit;

  SiblingTrees := TPsdFileTrees(ParentTree.FTrees);
  if SiblingTrees = nil then Exit;

  for I := 0 to SiblingTrees.Count - 1 do
  begin
    SiblingTree := SiblingTrees[I];
    if (SiblingTree = nil) or (SiblingTree = Self) or
       (SiblingTree.FLayer = nil) then
      Continue;

    if Copy(SiblingTree.FLayer.Name, 1, 1) = '-' then
      SiblingTree.FVisible := False;
  end;
end;

function TPsdFileTree.IsTreeEffectivelyVisible(Tree: TPsdFileTree): Boolean;
begin
  while Tree <> nil do
  begin
    if not Tree.Visible then Exit(False);
    if Tree.FOwners.Count = 0 then break;
    Tree := TPsdFileTree(Tree.FOwners[0]); // 親ツリー
  end;
  Result := True;
end;

procedure TPsdFileTree.SetLayerVisible(const AlwayCtrl,Value: Boolean);
var
  i,cnt: Integer;
  ts : TPsdFileTree;
  tss : TPsdFileTrees;
  s : string;
  {$IFDEF DEBUG}
  DebugThis: Boolean;
  {$ENDIF}
begin
  {$IFDEF DEBUG}
  DebugThis := IsDebugArmTree(Self);
  if DebugThis then
    VisibilityRuleDebugLog(Format('SetLayerVisible enter alwaysCtrl=%s value=%s self="%s" multi=%s always=%s visible=%s',
      [BoolToStr(AlwayCtrl, True), BoolToStr(Value, True),
       DebugTreePath(Self), BoolToStr(IsMultiSelect, True),
       BoolToStr(IsAlways, True), BoolToStr(FVisible, True)]));
  {$ENDIF}

  if IsMultiSelect then begin                    // 複数選択可能な場合
    if not Value then begin                      // 非表示の指定の場合で
      if (not AlwayCtrl) and IsAlways then exit; // 常に表示のレイヤーの場合は処理終了
    end;

    FVisible := Value;                           // 反映させる
    cnt := FOwners.Count;
    // Visible=True のときは * の有無に関係なく直上の親も表示にする
    if cnt >= 1 then
    begin
      ts := TPsdFileTree(FOwners[cnt-1]);
      {$IFDEF DEBUG}
      if DebugThis then
        VisibilityRuleDebugLog(Format('  parent on self="%s" parent="%s"',
          [DebugTreePath(Self), DebugTreePath(ts)]));
      {$ENDIF}
      ts.Visible := True;
    end;
    if Value then ApplyVisibilityRules;          // 親表示後にON時の表示連動ルールを実行する
  end
  else begin
    //if FVisible = Value then exit;

    cnt := FOwners.Count;
    if cnt = 0 then begin
      FVisible := Value;
      if Value then ApplyVisibilityRules;
      exit;
    end;
    ts := TPsdFileTree(FOwners[cnt-1]);
    tss := TPsdFileTrees(ts.FTrees);
    for i := 0 to tss.Count-1 do begin   // 自分の親ツリーのデータ数ループ
      ts := tss[i];                      // ツリーデータ参照
      if ts = Self then continue;        // 自分自身の場合は処理しない
      if not ts.FVisible then continue;  // 非表示中なら処理しない
      if ts.Level=-1 then continue;
      s := ts.FLayer.Name;
      if ts.IsAlways then continue;      // 常に表示のレイヤーは消さない
      if ts.IsMultiSelect then continue;      // 常に表示のレイヤーは消さない

      {$IFDEF DEBUG}
      if DebugThis or IsDebugArmTree(ts) then
        VisibilityRuleDebugLog(Format('  exclusive off self="%s" sibling="%s" siblingName="%s"',
          [DebugTreePath(Self), DebugTreePath(ts), DebugTreeName(ts)]));
      {$ENDIF}
      ts.FVisible := False;              // 排他的処理とする
    end;
    if Value then begin                  // 複数選択不可能な場合　非表示指定は処理しない
      FVisible := Value;                 // 指定通り表示状態とする
    end;
    // Visible=True のときは * の有無に関係なく直上の親も表示にする
    if cnt >= 1 then
    begin
      ts := TPsdFileTree(FOwners[cnt-1]);
      {$IFDEF DEBUG}
      if DebugThis then
        VisibilityRuleDebugLog(Format('  parent on self="%s" parent="%s"',
          [DebugTreePath(Self), DebugTreePath(ts)]));
      {$ENDIF}
      ts.Visible := True;
    end;
    if Value then ApplyVisibilityRules;  // 親表示後にON時の表示連動ルールを実行する
  end;

  if Value then
    HideInitialDressSiblingsForFaceSelection;
end;

procedure TPsdFileTree.SetVisibleLocal(const Value: Boolean);
begin
  FVisible := Value;
end;

procedure TPsdFileTree.SetVisibleLocalAndApplyRules(const Value: Boolean);
var
  i: Integer;
  OwnerTree: TPsdFileTree;
begin
  // UI側で単体切替を保ちつつ、ON時だけ独自表示連動を発火させるための入口。
  FVisible := Value;
  if Value then
  begin
    ApplyVisibilityRules;
    // メニュー操作では親を SetVisibleLocal で開くため、親側に登録されたルールもここで実行する。
    for i := 0 to FOwners.Count - 1 do
    begin
      OwnerTree := TPsdFileTree(FOwners[i]);
      if OwnerTree <> nil then
        OwnerTree.ApplyVisibilityRules;
    end;
    HideInitialDressSiblingsForFaceSelection;
  end;
end;

procedure TPsdFileTree.SetVisible(const Value: Boolean);
begin
  SetLayerVisible(False,Value);
end;

{ TPsdFileTreeVisibilityAction }

constructor TPsdFileTreeVisibilityAction.Create(ATree: TPsdFileTree;
  AVisible: Boolean);
begin
  inherited Create;
  FTree := ATree;
  FVisible := AVisible;
end;

{ TPsdFileTreeVisibilityRule }

constructor TPsdFileTreeVisibilityRule.Create(ATriggerTree: TPsdFileTree);
begin
  inherited Create;
  FTriggerTree := ATriggerTree;
  FActions := TList.Create;
end;

destructor TPsdFileTreeVisibilityRule.Destroy;
begin
  Clear;
  FActions.Free;
  inherited;
end;

function TPsdFileTreeVisibilityRule.AddAction(TargetTree: TPsdFileTree;
  TargetVisible: Boolean): Boolean;
begin
  Result := False;
  if TargetTree = nil then Exit;
  if ContainsAction(TargetTree, TargetVisible) then Exit;

  FActions.Add(TPsdFileTreeVisibilityAction.Create(TargetTree, TargetVisible));
  Result := True;
end;

procedure TPsdFileTreeVisibilityRule.Clear;
var
  i: Integer;
begin
  for i := 0 to FActions.Count - 1 do
    TPsdFileTreeVisibilityAction(FActions[i]).Free;
  FActions.Clear;
end;

function TPsdFileTreeVisibilityRule.ContainsAction(TargetTree: TPsdFileTree;
  TargetVisible: Boolean): Boolean;
var
  i: Integer;
  Action: TPsdFileTreeVisibilityAction;
begin
  Result := False;
  for i := 0 to FActions.Count - 1 do
  begin
    Action := TPsdFileTreeVisibilityAction(FActions[i]);
    if (Action.Tree = TargetTree) and (Action.Visible = TargetVisible) then
      Exit(True);
  end;
end;

procedure TPsdFileTreeVisibilityRule.Execute;
var
  i, j: Integer;
  Action: TPsdFileTreeVisibilityAction;
  OwnerTree: TPsdFileTree;
begin
  {$IFDEF DEBUG}
  VisibilityRuleDebugLog(Format('execute trigger="%s" actions=%d',
    [DebugTreePath(FTriggerTree), FActions.Count]));
  {$ENDIF}

  for i := 0 to FActions.Count - 1 do
  begin
    Action := TPsdFileTreeVisibilityAction(FActions[i]);
    if (Action = nil) or (Action.Tree = nil) then Continue;

    {$IFDEF DEBUG}
    VisibilityRuleDebugLog(Format('  action[%d] visible=%s target="%s"',
      [i, BoolToStr(Action.Visible, True), DebugTreePath(Action.Tree)]));
    {$ENDIF}

    // 連動先は ! 付きでも落としたいので、通常の Visible setter を通さず直接反映する。
    Action.Tree.SetVisibleLocal(Action.Visible);
    if Action.Visible then
    begin
      // ONにする時だけ親も開き、実効表示になるようにする。親側の連動は発火させない。
      for j := 0 to Action.Tree.Owners.Count - 1 do
      begin
        OwnerTree := TPsdFileTree(Action.Tree.Owners[j]);
        if OwnerTree <> nil then
          OwnerTree.SetVisibleLocal(True);
      end;
    end;
  end;
end;

function TPsdFileTreeVisibilityRule.GetActions(
  Index: Integer): TPsdFileTreeVisibilityAction;
begin
  Result := TPsdFileTreeVisibilityAction(FActions[Index]);
end;

function TPsdFileTreeVisibilityRule.GetCount: Integer;
begin
  Result := FActions.Count;
end;

{ TPsdFileTreeVisibilityRules }

destructor TPsdFileTreeVisibilityRules.Destroy;
begin
  Clear;
  inherited;
end;

function TPsdFileTreeVisibilityRules.AddRule(
  TriggerTree: TPsdFileTree): TPsdFileTreeVisibilityRule;
begin
  Result := TPsdFileTreeVisibilityRule.Create(TriggerTree);
  inherited Add(Result);
  TriggerTree.AddVisibilityRuleRef(Result);
end;

function TPsdFileTreeVisibilityRules.AddAction(TriggerTree,
  TargetTree: TPsdFileTree; TargetVisible: Boolean): Boolean;
var
  Rule: TPsdFileTreeVisibilityRule;
begin
  Result := False;
  if (TriggerTree = nil) or (TargetTree = nil) then Exit;

  Rule := GetOrAddRule(TriggerTree);
  Result := Rule.AddAction(TargetTree, TargetVisible);
end;

procedure TPsdFileTreeVisibilityRules.Clear;
var
  i: Integer;
  Rule: TPsdFileTreeVisibilityRule;
begin
  for i := 0 to Count - 1 do
  begin
    Rule := Rules[i];
    if Rule.TriggerTree <> nil then
      Rule.TriggerTree.ClearVisibilityRuleRefs;
    Rule.Free;
  end;
  inherited;
end;

function TPsdFileTreeVisibilityRules.FindRule(
  TriggerTree: TPsdFileTree): TPsdFileTreeVisibilityRule;
var
  i: Integer;
begin
  Result := nil;
  if TriggerTree = nil then Exit;

  for i := 0 to Count - 1 do
    if Rules[i].TriggerTree = TriggerTree then
      Exit(Rules[i]);
end;

function TPsdFileTreeVisibilityRules.GetRules(
  Index: Integer): TPsdFileTreeVisibilityRule;
begin
  Result := TPsdFileTreeVisibilityRule(inherited Items[Index]);
end;

function TPsdFileTreeVisibilityRules.GetOrAddRule(
  TriggerTree: TPsdFileTree): TPsdFileTreeVisibilityRule;
begin
  Result := FindRule(TriggerTree);
  if Result = nil then
    Result := AddRule(TriggerTree);
end;

{ TPsdFileTreeExs }

function TPsdFileTreeExs.GetTrees(Index: Integer): TPsdFileTree;
begin
  result := inherited Items[Index];
end;

const
  // Base64URLテーブル（共有用）
  BASE64URL_TABLE: string =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

function TPsdFileTreeExs.GetVisibleString: string;
var
  i, bitIndex, charIndex, count: Integer;
  bits: TBytes;
  val: Byte;
  sb: TStringBuilder;
begin
  count := Self.Count;
  if count = 0 then
    Exit('');

  //FFlipMode := 0; // 反転情報を持たせる場合は外部で設定してから代入

  // 可視データ部のバイト数（6bit単位で圧縮）
  SetLength(bits, (count + 5) div 6);

  // 6bitごとに詰め込み
  for i := 0 to count - 1 do
  begin
    charIndex := i div 6;
    bitIndex  := i mod 6;
    if Trees[i].FVisible then
      bits[charIndex] := bits[charIndex] or ($20 shr bitIndex);
  end;

  sb := TStringBuilder.Create;
  try
    // ヘッダ：反転 + レイヤー数(下位→上位)
    sb.Append(BASE64URL_TABLE[FFlipMode + 1]);
    sb.Append(BASE64URL_TABLE[(count and $3F) + 1]);
    sb.Append(BASE64URL_TABLE[((count shr 6) and $3F) + 1]);
    sb.Append(BASE64URL_TABLE[((count shr 12) and $3F) + 1]);

    // 本体：可視ビット列
    for val in bits do
      sb.Append(BASE64URL_TABLE[val + 1]);

    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;


procedure TPsdFileTreeExs.SetVisibleString(const Value: string);
var
  DecodeTable: array[Char] of Byte;
  i, cnt, bitIndex, charIndex, valIndex: Integer;
  val: Byte;
  bits: TBytes;
  ch: Char;
begin
  // 空文字は無視
  if (Value = '') then
    Exit;

  // BASE64URL_TABLE 検証
  if Length(BASE64URL_TABLE) = 0 then
    Exit;

  // デコードテーブルを初期化
  FillChar(DecodeTable, SizeOf(DecodeTable), $FF);
  for i := 1 to Length(BASE64URL_TABLE) do
    DecodeTable[BASE64URL_TABLE[i]] := i - 1;

  // 最低限の長さチェック（反転1文字 + カウント3文字 + 1データ以上）
  if Length(Value) < 5 then
    Exit;

  // 不正文字を含む場合は中断
  for ch in Value do
    if DecodeTable[ch] = $FF then
      Exit;

  // ヘッダ解析（反転＋レイヤー数）
  FFlipMode := DecodeTable[Value[1]];

  cnt :=
    (DecodeTable[Value[2]]) or
    (DecodeTable[Value[3]] shl 6) or
    (DecodeTable[Value[4]] shl 12);

  // カウントの妥当性チェック
  if (cnt <= 0) or (cnt > Self.Count * 2) then
    Exit;

  // データ部
  valIndex := 5;
  SetLength(bits, Length(Value) - 4);
  for i := 0 to High(bits) do
    bits[i] := DecodeTable[Value[valIndex + i]];

  // 6bit展開して反映（安全範囲のみ）
  for i := 0 to cnt - 1 do
  begin
    if i >= Self.Count then
      Break;

    charIndex := i div 6;
    bitIndex  := i mod 6;

    // ビット抽出 (左詰め: bit5→bit0)
    val := bits[charIndex] and (1 shl (5 - bitIndex));
    Trees[i].FVisible := (val <> 0);
  end;

  // flipMode は外部処理（未使用）
end;



end.
