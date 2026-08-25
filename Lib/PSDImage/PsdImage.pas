//------------------------------------------------------------------------------
//  クラス名 : TPSDImage
//------------------------------------------------------------------------------
//  【概要】
//    Photoshop(PSD) ファイルを読み込み、内部構造（レイヤー階層・リソース情報）
//    を解析して VCL 用の TBitmap にレンダリングするクラスです。
//    各レイヤーは TPsdFileLayer/Trees/Layers クラスを通じて管理され、
//    Render() により合成画像を生成します。
//
//  【主な役割】
//    ・PSDファイルヘッダの読み込みと基本情報の保持
//    ・カラーモード、チャネル構成、レイヤー情報の解析
//    ・レイヤー階層(TPsdFileTrees)の構築
//    ・各レイヤーの描画順に基づく合成処理(Render)
//    ・VCL向けの全体画像(TBitmap)生成
//
//  【内部構成】
//    FLayerRoot   : 仮想的な最上位レイヤー（PSDTool互換構造用）
//    FLayers      : レイヤー管理クラス（全レイヤーを一元管理）
//    FTrees       : レイヤー階層ツリー構造
//    FBitmap      : 合成後の最終出力ビットマップ
//    FResource    : PSD内の追加リソース情報（ICCプロファイル等）
//
//  【主なメソッド】
//    LoadFromFile()       : PSDファイルを読み込んで内部構造を解析
//    Render()             : 各レイヤーをα合成して最終ビットマップを生成
//    Invalidate()         : 再描画を要求（Renderを再実行）
//    VisibleInit()        : レイヤーの表示・非表示を初期化
//    GetBitmap()          : 合成済みのTBitmapを取得
//    GetBitmapThumbnail() : 縮小サムネイルを取得
//
//------------------------------------------------------------------------------
unit PSDImage;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,PsdImageDefine,
  PsdImageFileStreamBuf,PsdImageBlend,PsdImageChannel,PsdImageLayer,PsdImageTree,
  PsdImageResource;

// 描画モード関数ポインタの型を定義（引数: TFourth, TFourth / 戻り値: TFourth）
type
  TBlendModeFunc = function(const fromCol, toCol: TFourth): TFourth of object;
  TBlendModeFuncs = array[TPsdFileBlandType] of TBlendModeFunc;

//--------------------------------------------------------------------------//
//  PSDファイルを読み込む                                                   //
//--------------------------------------------------------------------------//
type TPSDImage = class(TPersistent)
  private
    { Private 宣言 }
    FLayerRoot    : TPsdFileLayer;        // PSDtool用に使う存在しない親レイヤークラス
    FLayers       : TPsdFileLayers;       // レイヤー管理クラス
    FTrees        : TPsdFileTrees;        // PSDツリークラス
    FTreeLists    : TPsdFileTreeExs;      // ツリー構造をリストにしたもの
    FVisibilityRules: TPsdFileTreeVisibilityRules; // 独自解析で付与する表示連動ルール
    FBitmap       : TBitmap;              // 全体表示用ビットマップ
    FResource     : TPsdFileResource;
    // ------------------------------------------------------------------------
    FVersion    : Integer;             // バージョン
    FChannel    : Integer;             // アルファチャネルを含む、画像内のチャネル数
    FHeight     : Integer;             // 画像全体の高さ
    FWidth      : Integer;             // 画像全体の幅
    FDataBit    : Integer;             // チャネルあたりのビット数。値は1、8、16、および32です。
    FColorMode  : Integer;             // ファイルのカラーモード。サポートされている値は次のとおりです。ビットマップ=0; グレースケール=1; インデックス付き=2; RGB = 3; CMYK = 4; マルチチャネル=7; Duotone = 8; ラボ=9。
    // ------------------------------------------------------------------------
    FLayerMaskLength : Integer;
    FLayerLength : Integer;
    FLayerCount  : Integer;            // レイヤー数
    // ------------------------------------------------------------------------
    FBitmapLines : array of Pointer;
    FFileName    : string;             // データ読み込み時に使用するファイル名
    FFlipMode    : Integer;
    FDebugMarkerRoute: string;         // デバッグダンプ用。仮想マーカー補完の分岐メモ。
    // ------------------------------------------------------------------------
    FColor       : TColor;
    // 描画関数ポインタテーブルを定義
    FBlendModeBMPFuncs: TBlendModeFuncs;
    FBlendModeFilterFuncs: TBlendModeFuncs;

    function LoadFromFileHeader(fs : TFileStreamBuf) : Boolean;
    function LoadFromFileColorMode(fs : TFileStreamBuf) : Boolean;
    function LoadFromFileLayerInfo(fs : TFileStreamBuf) : Boolean;
    function LoadFromFileAnm() : Boolean; // ANMファイルの作成に必要な情報を各レイヤーに割り当てる
    // 指定位置のレイヤーがフォルダとして成立するかを判定する
    function LoadFromFileTreeHasFolderEnd(
      StartIndex: Integer;          // 判定対象となるフォルダ開始レイヤーの位置
      const Layers: TPsdFileLayers  // 探索対象となるレイヤー配列
    ): Boolean;
    // レイヤー配列からツリー構造を再帰的に構築するサブ処理
    procedure LoadFromFileTreeSub(
      var Index: Integer;              // FLayers 内の現在解析位置（再帰で更新）
      ParentTrees: TPsdFileTrees;      // 追加先となる親ツリーリスト
      ParentOwners: TList;             // ルートから親までの経路スタック（FOwners 用）
      Level: Integer                   // 現在の階層レベル
    );
    function LoadFromFileTree() : Boolean;
    procedure LoadFromFileTreeList();
    procedure LoadFromFileTreeListSub(tss: TPsdFileTrees);
    procedure RebuildTreeStateSub(
      Trees: TPsdFileTrees;
      ParentOwners: TList;
      Level: Integer;
      const ParentAnmPath: string
    );
    function FindTreeOwnerTrees(
      SearchTrees: TPsdFileTrees;
      TargetTree: TPsdFileTree
    ): TPsdFileTrees;
    function IsTreeOwnsTrees(
      Tree: TPsdFileTree;
      TargetTrees: TPsdFileTrees
    ): Boolean;

    procedure RenderSub(tss : TPsdFileTrees;fs : TFileStreamBuf);
    procedure BitmapClear();

    function DrawNorm(const fromCol,toCol : TFourth) : TFourth;
    function DrawNoDefine(const fromCol,toCol : TFourth) : TFourth;
    function DrawNoDefineFilter(const fromCol,toCol : TFourth) : TFourth;

    // 内部ビットマップに合成したものを描画
    procedure Render;

    function GetBitmap: TBitmap;
    function GetBitmapThumbnail: TBitmap;
    function GetLayerVisibleString: string;
    procedure SetLayerVisibleString(const Value: string);
  protected
    FRendered    : Boolean;            // True:レンダー済み
    // 派生クラスで出力専用サイズを差し替えられるよう、Width/Height はゲッター経由にする
    function GetWidth: Integer; virtual;
    function GetHeight: Integer; virtual;
    // 描画処理の登録
    procedure RegisterBlendModeBMP(Mode: TPsdFileBlandType; Func: TBlendModeFunc);
    procedure RegisterBlendModeAviUtl2Filter(Mode: TPsdFileBlandType; Func: TBlendModeFunc);
  public
    { Public 宣言 }
    constructor Create();virtual;
    destructor Destroy;override;

    // レイヤーの表示非表示情報を初期状態に
    procedure VisibleInit();virtual;
    // PSDファイル読み込み
    procedure LoadFromFile(const FileName : string);virtual;
    // TreeをDestTreesへ移動する。Index < 0 は末尾、0以上は挿入位置。
    function MoveTree(Tree: TPsdFileTree; DestTrees: TPsdFileTrees;
      Index: Integer = -1): Boolean;virtual;
    // PSD実体を持たない仮想ツリーを追加する。LayerType=-1 は描画対象外の管理用レイヤー。
    function AddVirtualTree(DestTrees: TPsdFileTrees; const Name: string;
      Index: Integer = -1): TPsdFileTree;virtual;
    // ツリー移動後に Owners/Level/Layer.Tree/ANMパス/平坦リストを作り直す
    procedure RebuildTreeState;virtual;
    // 独自解析で付与した表示連動ルールを全消去する
    procedure ClearVisibilityRules;
    // TriggerTree が ON になった時、TargetTree を TargetVisible にする
    function AddVisibilityRule(TriggerTree, TargetTree: TPsdFileTree;
      TargetVisible: Boolean): Boolean;
    // TriggerTree に紐付く表示連動ルールを取得する。存在しなければ nil
    function FindVisibilityRule(TriggerTree: TPsdFileTree): TPsdFileTreeVisibilityRule;

    property FileName : string read FFilename;
    property Layers  : TPsdFileLayers read FLayers;
    property Trees  : TPsdFileTrees read FTrees;
    property VisibilityRules: TPsdFileTreeVisibilityRules read FVisibilityRules;
    property BitmapThumbnail : TBitmap read GetBitmapThumbnail;

    property Bitmap: TBitmap read GetBitmap;
    property Height : Integer read GetHeight;
    property Width : Integer read GetWidth;
    property Color  : TColor read FColor write FColor;
    property FlipMode : Integer read FFlipMode write FFlipMode;
    property BlendModeBMPFuncs: TBlendModeFuncs read FBlendModeBMPFuncs;
    property BlendModeFilterFuncs: TBlendModeFuncs read FBlendModeFilterFuncs;
    property LayerVisibleString: string read GetLayerVisibleString write SetLayerVisibleString;
    property DebugMarkerRoute: string read FDebugMarkerRoute write FDebugMarkerRoute;
  end;

implementation

uses DebugTimer, PSDImageAnmPath;

function StrLeft(const str,key : string) : string;
var
  i : Integer;
begin
  result := '';
  i := Pos(key,str);
  if i = 0 then exit;
  result := Copy(str,i+Length(key),Length(str));
end;

// 指定した文字列に囲まれた部分を返す
function StrMid(const str,keyLeft,keyRight : string) : string;
var
  i,j : Integer;
  s : string;
begin
  result := '';
  i := Pos(keyLeft,str);
  if i = 0 then exit;

  s := Copy(str,i+Length(keyLeft),Length(str));

  j := Pos(keyRight,s);
  if j = 0 then exit;
  result := Copy(s,1,j-1);

end;

function StrMidCut(var str : string;const keyLeft,keyRight : string) : string;
var
  i,j : Integer;
  s : string;
begin
  result := '';
  i := Pos(keyLeft,str);
  if i = 0 then exit;

  s := Copy(str,i+Length(keyLeft),Length(str));

  j := Pos(keyRight,s);
  if j = 0 then exit;
  result := Copy(s,1,j-1);

  j := Pos(keyRight,str);
  str := Copy(str,j + Length(keyRight),Length(str));
end;

// 指定した右側の文字列を探し、左はその最短位置を探して囲まれた部分を返す
function StrMidRight(const str,keyLeft,keyRight : string) : string;
var
  i,j : Integer;
  s,ss : string;
begin
  result := str;

  s := str;
  j := Pos(keyRight,s);
  if j = 0 then exit;

  repeat
    ss := StrMid(s,keyLeft,keyRight);
    if ss = '' then break;

    i := Pos(keyLeft,s);
    if i = 0 then break;

    s := Copy(s,(i+Length(keyLeft)),Length(s));
    result := ss;
  until (False);


end;

function StrCutLeft(var str : string;const key : string) : Boolean;
var
  i : Integer;
begin
  result := False;
  i := Pos(key,str);
  if i = 0 then exit;
  str := Copy(str,i+Length(key),Length(str));
  result := True;
end;



{ TPsdImage }

procedure TPsdImage.BitmapClear;
var
  y: Integer;
  p: PByte;
begin
  FBitmap.AlphaFormat := afIgnored; // ← 重要

  for y := 0 to FBitmap.Height-1 do
  begin
    p := FBitmap.ScanLine[y];
    FillChar(p^, FBitmap.Width * 4, 0); // BGRA全部0
  end;
end;

constructor TPsdImage.Create;
var
  i : Integer;
begin
  FLayerRoot   := TPsdFileLayer.Create;
  FLayers := TPsdFileLayers.Create;
  FTrees := TPsdFileTrees.Create;
  FTreeLists := TPsdFileTreeExs.Create;
  FVisibilityRules := TPsdFileTreeVisibilityRules.Create;
  FBitmap := TBitmap.Create;
  FResource := TPsdFileResource.Create;

  // 描画モードごとに未定義を設定　ブレークポイント用に分岐
 for i := Integer(Low(TPsdFileBlandType)) to Integer(High(TPsdFileBlandType)) do begin
   RegisterBlendModeBMP(TPsdFileBlandType(i),DrawNoDefine);
   RegisterBlendModeAviUtl2Filter(TPsdFileBlandType(i),DrawNoDefineFilter);
 end;
 // 定義されている標準描画を定義
 RegisterBlendModeBMP(btNorm,DrawNorm);
 RegisterBlendModeAviUtl2Filter(btNorm,DrawNorm);

end;

destructor TPsdImage.Destroy;
begin
  FVisibilityRules.Free;
  FLayerRoot   := TPsdFileLayer.Create;
  FLayers := TPsdFileLayers.Create;
  FTreeLists.Free;
  FTrees := TPsdFileTrees.Create;
  FBitmap := TBitmap.Create;
  FResource := TPsdFileResource.Create;

  inherited;
end;

function TPsdImage.AddVisibilityRule(TriggerTree, TargetTree: TPsdFileTree;
  TargetVisible: Boolean): Boolean;
begin
  Result := False;
  if FVisibilityRules = nil then Exit;

  Result := FVisibilityRules.AddAction(TriggerTree, TargetTree, TargetVisible);
end;

procedure TPsdImage.ClearVisibilityRules;
begin
  if FVisibilityRules <> nil then
    FVisibilityRules.Clear;
end;

function TPsdImage.FindVisibilityRule(
  TriggerTree: TPsdFileTree): TPsdFileTreeVisibilityRule;
begin
  Result := nil;
  if FVisibilityRules = nil then Exit;

  Result := FVisibilityRules.FindRule(TriggerTree);
end;

function TPSDImage.DrawNorm(const fromCol, toCol: TFourth): TFourth;
var
  alpha,invA : Integer;
begin
  alpha := fromCol.A;
  invA  := 255 - alpha;

  result.R := (fromCol.R * alpha + toCol.R * invA) div 255;
  result.G := (fromCol.G * alpha + toCol.G * invA) div 255;
  result.B := (fromCol.B * alpha + toCol.B * invA) div 255;
  result.A := alpha + (toCol.A * invA) div 255;
end;

// 定義されていない描画はここに飛ぶ
function TPSDImage.DrawNoDefine(const fromCol, toCol: TFourth): TFourth;
begin
  DrawNorm(fromCol, toCol);
end;

function TPSDImage.DrawNoDefineFilter(const fromCol, toCol: TFourth): TFourth;
begin
  DrawNorm(fromCol, toCol);
end;

procedure TPsdImage.RenderSub(tss: TPsdFileTrees;fs : TFileStreamBuf);
var
  i : Integer;
  ts : TPsdFileTree;
  dl : TPsdFileLayer;
begin
  for i := tss.Count-1 downto 0 do begin
    ts := tss[i];
    if not ts.Visible then continue;
    RenderSub(TPsdFileTrees(ts.Trees),fs);

    dl := ts.Layer;
    if dl.LayerType<>0 then continue;
    if dl.Index = Layers.Count-1 then Continue;

    dl.LoadFromBitmap(fs);
    dl.Draw(FBitmapLines,FWidth,FHeight,dl.Channels[0].Left,dl.Channels[0].Top);
  end;
end;


procedure TPsdImage.LoadFromFile(const FileName: string);
var
  i,j,pos : Integer;
  dl : TPsdFileLayer;
  dc : TPsdFileChannel;
  fs : TFileStreamBuf;
  se : string;
begin
  if not FileExists(FileName) then Exit;

  FRendered := False;
  FLayers.Clear;
  FTreeLists.Clear;
  ClearVisibilityRules;
  FTrees.Clear;
  se := ExtractFileExt(FileName);
  if CompareText(se,'.psd') <> 0 then exit;
  fs := TFileStreamBuf.Create(FileName);
  try
    FFileName := FileName;                        // ファイル名を保存　※要改良？
    LoadFromFileHeader(fs);                       // ヘッダを処理
    LoadFromFileColorMode(fs);                    // カラーモードを処理
    FResource.LoadFromFile(fs);
    LoadFromFileLayerInfo(fs);                    // レイヤー情報を処理

    pos := fs.Position;                           // 現在のファイル位置を画像データの先頭とする
    for j := 0 to FLayers.Count-1 do begin        // レイヤー数ループ
      dl := FLayers[j];                           // レイヤーのデータを参照
      for i := 0 to dl.Channels.Count-1 do begin  // チャンネル数分ループ
        dc := dl.Channels[i];                     // チャンネルのデータを参照
        dc.ImageAdr := pos;                      // 画像データのアドレスとする

        //dc.LoadBitmap(fs,pos);

        pos := pos + dc.ImageLength;             // 画像サイズ分アドレスを増やす
      end;
    end;
    LoadFromFileAnm();                            // ANMファイルに必要な情報を作成
    LoadFromFileTree();                           // レイヤーツリー情報を作成
    LoadFromFileTreeList();                       // レイヤーツリーをリストに
  finally
    fs.Free;
  end;
end;

function TPsdImage.LoadFromFileAnm: Boolean;
begin
  Result := AssignPSDImageAnmPaths(FLayers);
end;

function TPsdImage.LoadFromFileColorMode(fs: TFileStreamBuf): Boolean;
var
  size,i : Integer;
begin
  size :=  fs.ReadBin(4);
  for i := 0 to size-1 do begin
    fs.ReadDumy(1);
  end;
  result := True;
end;

function TPsdImage.LoadFromFileHeader(fs: TFileStreamBuf): Boolean;
var
  sa: AnsiString;
begin
  result := False;
  sa := fs.ReadStr(4);
  if sa <> '8BPS' then exit;
  FVersion := fs.ReadBin(2);
  fs.ReadDumy(6);
  FChannel   := fs.ReadBin(2);
  FHeight    := fs.ReadBin(4);
  FWidth     := fs.ReadBin(4);
  FDataBit   := fs.ReadBin(2);
  FColorMode := fs.ReadBin(2);
  result := True;
end;

function TPsdImage.LoadFromFileLayerInfo(fs: TFileStreamBuf): Boolean;
var
  i : Integer;
  d : TPsdFileLayer;
begin
  FLayers.Clear;
  FLayerMaskLength := fs.ReadBin(4);
  FLayerLength     := fs.ReadBin(4);
  FLayerCount      := fs.ReadBin(2);
  if (FLayerCount and $8000)<>0 then begin
    FLayerCount := (FLayerCount xor $FFFF) + 1;
  end;

  for i := 0 to FLayerCount-1 do begin
    d := FLayers.Add();
    d.Owner := Self;
    d.LoadFromStreamInfo(fs);
    d.LoadFromStream(fs);
    d.Index := i;
  end;

  result := True;
end;

procedure TPsdImage.LoadFromFileTreeSub(
  var Index: Integer;
  ParentTrees: TPsdFileTrees;
  ParentOwners: TList;
  Level: Integer
);
var
  dl        : TPsdFileLayer;
  ts        : TPsdFileTree;
  ChildOwners: TList;
begin
  // レイヤー配列を逆順に走査
  while Index >= 0 do
  begin
    dl := FLayers[Index];
    Dec(Index);

    case dl.LayerType of
      0:  // 通常のデータレイヤー
        begin
          ts := ParentTrees.Add;
          ts.Layer   := dl;
          ts.Level   := Level;
          ts.SetVisibleLocal(dl.Visible);
          dl.Tree    := ts;

          // ★ 経路スタックをコピー
          ts.Owners.Clear;
          if Assigned(ParentOwners) then
            ts.Owners.Assign(ParentOwners);
        end;

      1, 2: // フォルダ開始候補
        begin
          // 閉じが存在しない場合は通常レイヤー扱い
          if not LoadFromFileTreeHasFolderEnd(Index + 1, FLayers) then
          begin
            ts := ParentTrees.Add;
            ts.Layer   := dl;
            ts.Level   := Level;
            ts.SetVisibleLocal(dl.Visible);
            dl.Tree     := ts;

            ts.Owners.Clear;
            if Assigned(ParentOwners) then
              ts.Owners.Assign(ParentOwners);

            Continue;
          end;

          // フォルダとして成立
          ts := ParentTrees.Add;
          ts.Layer   := dl;
          ts.Level   := Level;
          ts.SetVisibleLocal(dl.Visible);
          dl.Tree     := ts;

          // ★ このノードの FOwners を構築
          ts.Owners.Clear;
          if Assigned(ParentOwners) then
            ts.Owners.Assign(ParentOwners);

          // ★ 子に渡す経路スタックを生成
          ChildOwners := TList.Create;
          try
            // 親までの経路をコピー
            ChildOwners.Assign(ts.Owners);
            // 親（＝この ts）を push
            ChildOwners.Add(ts);

            // 子階層を再帰的に構築
            LoadFromFileTreeSub(
              Index,
              TPsdFileTrees(ts.Trees),
              ChildOwners,
              Level + 1
            );
          finally
            ChildOwners.Free;
          end;
        end;

      3:  // フォルダ終了
        begin
          // 現在の階層はここで終了
          Exit;
        end;
    else
      // 想定外の LayerType は無視
    end;
  end;
end;

function TPsdImage.LoadFromFileTree: Boolean;
var
  Index        : Integer;
  ts           : TPsdFileTree;
  RootOwners   : TList;
begin
  // 既存ツリーをクリア
  FTrees.Clear;

  // ダミールートレイヤーを設定
  FLayerRoot.NameShifJis := '!v1';
  FLayerRoot.LayerType  := 1;

  // ルートツリーを生成
  ts := FTrees.Add;
  ts.Layer   := FLayerRoot;
  ts.Level   := -1;
  ts.SetVisibleLocal(True);
  FLayerRoot.Tree := ts;

  // ★ ダミールートは経路の起点なので Owners は空
  ts.Owners.Clear;

  // ★ ルート用の経路スタックを生成（空）
  RootOwners := TList.Create;
  try
    RootOwners.Add(ts); // ルート直下の * レイヤーでも同層排他を効かせるため、ダミールートを親に含める
    // レイヤー配列の末尾から解析開始
    Index := FLayers.Count - 1;

    // 再帰サブ関数でツリー構築
    LoadFromFileTreeSub(
      Index,
      TPsdFileTrees(ts.Trees),
      RootOwners,   // ★ ルートからの経路スタック
      0
    );
  finally
    RootOwners.Free;
  end;

  // 本関数は成功前提
  Result := True;
end;

function TPsdImage.LoadFromFileTreeHasFolderEnd(
  StartIndex: Integer;          // 判定対象となるフォルダ開始レイヤーの位置
  const Layers: TPsdFileLayers  // 探索対象となるレイヤー配列
): Boolean;
var
  i     : Integer;
  Depth : Integer;
  lt    : Integer;
begin
  Result := False;
  Depth  := 0;

  // StartIndex より前（逆順）を走査
  for i := StartIndex - 1 downto 0 do
  begin
    lt := Layers[i].LayerType;

    case lt of
      3:
        begin
          // フォルダ終了を検出
          if Depth = 0 then
          begin
            // 対応する閉じを発見
            Result := True;
            Exit;
          end
          else
            Dec(Depth);
        end;

      1, 2:
        begin
          // 内側のフォルダ開始に入った
          Inc(Depth);
        end;
    end;
  end;
end;

procedure TPSDImage.LoadFromFileTreeList;
begin
  FTreeLists.Clear;
  LoadFromFileTreeListSub(FTrees);
end;

procedure TPSDImage.LoadFromFileTreeListSub(tss: TPsdFileTrees);
var
  i : Integer;
  ts : TPsdFileTree;
begin
  for i := tss.Count-1 downto 0 do begin
    ts := tss[i];
    LoadFromFileTreeListSub(TPsdFileTrees(ts.Trees));
    FTreeLists.Add(ts);
  end;
end;

procedure TPsdImage.RebuildTreeState;
var
  RootOwners: TList;
  RootTree: TPsdFileTree;
  RootTrees: TPsdFileTrees;
  RootAnmPath: string;
begin
  RootOwners := TList.Create;
  try
    RootTrees := FTrees;
    if (RootTrees <> nil) and (RootTrees.Count > 0) then
    begin
      RootTree := RootTrees[0];
      if RootTree <> nil then
      begin
        RootTree.Owners.Clear;
        RootTree.Level := -1;
        // ダミールート(!v1)はツリー制御用で、既存のANM絶対パスには含めない。
        RootAnmPath := '';
        if RootTree.Layer <> nil then
          RootTree.Layer.Tree := RootTree;

        RootOwners.Add(RootTree);
        RebuildTreeStateSub(
          TPsdFileTrees(RootTree.Trees),
          RootOwners,
          0,
          RootAnmPath
        );
      end;
    end;

    LoadFromFileTreeList;
    FRendered := False;
  finally
    RootOwners.Free;
  end;
end;

procedure TPsdImage.RebuildTreeStateSub(
  Trees: TPsdFileTrees;
  ParentOwners: TList;
  Level: Integer;
  const ParentAnmPath: string
);
var
  i: Integer;
  Tree: TPsdFileTree;
  ChildOwners: TList;
  Layer: TPsdFileLayer;
  ChildAnmPath: string;
begin
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    Tree := Trees[i];
    if Tree = nil then Continue;

    Tree.Owners.Clear;
    if ParentOwners <> nil then
      Tree.Owners.Assign(ParentOwners);
    Tree.Level := Level;

    Layer := Tree.Layer;
    if Layer <> nil then
    begin
      Layer.Tree := Tree;
      Layer.SetAnmGroupPath(ParentAnmPath);
      ChildAnmPath := Layer.AnmText + '/';
    end
    else begin
      ChildAnmPath := ParentAnmPath;
    end;

    ChildOwners := TList.Create;
    try
      if ParentOwners <> nil then
        ChildOwners.Assign(ParentOwners);
      ChildOwners.Add(Tree);

      RebuildTreeStateSub(
        TPsdFileTrees(Tree.Trees),
        ChildOwners,
        Level + 1,
        ChildAnmPath
      );
    finally
      ChildOwners.Free;
    end;
  end;
end;

function TPsdImage.FindTreeOwnerTrees(
  SearchTrees: TPsdFileTrees;
  TargetTree: TPsdFileTree
): TPsdFileTrees;
var
  i: Integer;
  Tree: TPsdFileTree;
begin
  Result := nil;
  if (SearchTrees = nil) or (TargetTree = nil) then Exit;

  if SearchTrees.IndexOf(TargetTree) >= 0 then
    Exit(SearchTrees);

  for i := 0 to SearchTrees.Count - 1 do
  begin
    Tree := SearchTrees[i];
    if Tree = nil then Continue;

    Result := FindTreeOwnerTrees(TPsdFileTrees(Tree.Trees), TargetTree);
    if Result <> nil then Exit;
  end;
end;

function TPsdImage.IsTreeOwnsTrees(
  Tree: TPsdFileTree;
  TargetTrees: TPsdFileTrees
): Boolean;
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
begin
  Result := False;
  if (Tree = nil) or (TargetTrees = nil) then Exit;

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = TargetTrees then
    Exit(True);

  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
  begin
    if IsTreeOwnsTrees(ChildTrees[i], TargetTrees) then
      Exit(True);
  end;
end;

function TPsdImage.MoveTree(Tree: TPsdFileTree; DestTrees: TPsdFileTrees;
  Index: Integer): Boolean;
var
  SrcTrees: TPsdFileTrees;
  SrcIndex: Integer;
  RestoreIndex: Integer;
  InsertIndex: Integer;
begin
  Result := False;
  if (Tree = nil) or (DestTrees = nil) then Exit;
  if Tree = TPsdFileTree(FLayerRoot.Tree) then Exit;
  if DestTrees = FTrees then Exit;
  if IsTreeOwnsTrees(Tree, DestTrees) then Exit;

  SrcTrees := FindTreeOwnerTrees(FTrees, Tree);
  if SrcTrees = nil then Exit;

  SrcIndex := SrcTrees.IndexOf(Tree);
  TList(SrcTrees).Remove(Tree);
  try
    if Index < 0 then
    begin
      TList(DestTrees).Add(Tree);
    end
    else begin
      InsertIndex := Index;
      if InsertIndex > DestTrees.Count then
        InsertIndex := DestTrees.Count;
      TList(DestTrees).Insert(InsertIndex, Tree);
    end;

    RebuildTreeState;
    Result := True;
  except
    if SrcTrees.IndexOf(Tree) < 0 then
    begin
      RestoreIndex := SrcIndex;
      if RestoreIndex < 0 then
        RestoreIndex := SrcTrees.Count
      else if RestoreIndex > SrcTrees.Count then
        RestoreIndex := SrcTrees.Count;
      TList(SrcTrees).Insert(RestoreIndex, Tree);
    end;
    RebuildTreeState;
    raise;
  end;
end;

function TPsdImage.AddVirtualTree(DestTrees: TPsdFileTrees; const Name: string;
  Index: Integer): TPsdFileTree;
var
  Layer: TPsdFileLayer;
  Tree: TPsdFileTree;
  InsertIndex: Integer;
  Inserted: Boolean;
begin
  Result := nil;
  if (DestTrees = nil) or (Trim(Name) = '') then Exit;
  if DestTrees = FTrees then Exit;

  Layer := FLayers.Add;
  Layer.Owner := Self;
  Layer.Name := Name;
  Layer.LayerType := -1; // 仮想分類用。PSD実体も描画データも持たない。
  Layer.Index := -1;    // PSD内レイヤー番号ではないことを示す。

  Tree := TPsdFileTree.Create;
  Inserted := False;
  Tree.Layer := Layer;
  Tree.SetVisibleLocal(True); // 仮想分類は配下をたどれるよう初期表示にする。
  Layer.Tree := Tree;

  try
    if Index < 0 then
    begin
      TList(DestTrees).Add(Tree);
      Inserted := True;
    end
    else begin
      InsertIndex := Index;
      if InsertIndex > DestTrees.Count then
        InsertIndex := DestTrees.Count;
      TList(DestTrees).Insert(InsertIndex, Tree);
      Inserted := True;
    end;

    RebuildTreeState;
    Result := Tree;
  except
    if Inserted then
      TList(DestTrees).Remove(Tree); // 追加途中で失敗した場合はツリーリストから参照を外す。
    Tree.Free;
    FLayers.Delete(FLayers.Count - 1);
    RebuildTreeState;
    raise;
  end;
end;

procedure TPSDImage.RegisterBlendModeBMP(Mode: TPsdFileBlandType; Func: TBlendModeFunc);
begin
  FBlendModeBMPFuncs[Mode] := Func;
end;

procedure TPSDImage.RegisterBlendModeAviUtl2Filter(Mode: TPsdFileBlandType;Func: TBlendModeFunc);
begin
  FBlendModeFilterFuncs[Mode] := Func;
end;

procedure TPSDImage.Render;
var
  y : Integer;
  fs : TFileStreamBuf;
begin
  DebugTimerBegin('Render');
  FBitmap.SetSize(FWidth,FHeight);
  FBitmap.PixelFormat := pf32bit;
  BitmapClear();
  SetLength(FBitmapLines,FHeight);

  if not FileExists(FFileName) then Exit;

  fs := TFileStreamBuf.Create(FFileName);
  try
    for y := 0 to FHeight-1 do begin
      FBitmapLines[y] := FBitmap.ScanLine[y];
    end;

    RenderSub(FTrees,fs);
    FBitmap.AlphaFormat := afDefined;
    FRendered := True;
  finally
    DebugTimerEnd;
    fs.Free;
  end;
end;
procedure TPsdImage.VisibleInit;
var
 i  : Integer;
 dl : TPsdFileLayer;
 ts : TPsdFileTree;
begin
  ts := TPsdFileTree(FLayerRoot.Tree);
  if ts <> nil then
    ts.SetVisibleLocal(True);

  for i := 0 to FLayers.Count-1 do begin
    dl := FLayers[i];
    ts := TPsdFileTree(dl.Tree);
    if ts = nil then continue;
    ts.SetVisibleLocal(dl.Visible);
  end;
  FRendered := False;
end;


function TPsdImage.GetBitmap: TBitmap;
begin
  if not FRendered then Render;
  Result := FBitmap;
end;

function TPsdImage.GetBitmapThumbnail: TBitmap;
begin
  result := FResource.Thumbnail.Bitmap;
end;

function TPSDImage.GetHeight: Integer;
begin
  Result := FHeight;
end;

function TPSDImage.GetLayerVisibleString: string;
begin
  Result :=  FTreeLists.VisibleString;
  FFlipMode := FTreeLists.FlipMode;
end;

function TPSDImage.GetWidth: Integer;
begin
  Result := FWidth;
end;

procedure TPSDImage.SetLayerVisibleString(const Value: string);
begin
  if Value = '' then begin            // レイヤー指定文字が無い場合
    VisibleInit();                    // 所期状態とする
    Exit;                             // レイヤーへの反映は不要
  end;

  // 以前の可視状態を引きずらないよう、復元前に必ず初期状態へ戻す
  VisibleInit();
  FTreeLists.FlipMode := FFlipMode;
  FTreeLists.VisibleString := Value;
end;

end.

