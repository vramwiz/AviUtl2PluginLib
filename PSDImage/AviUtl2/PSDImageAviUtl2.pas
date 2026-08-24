unit PSDImageAviUtl2;

// PSDImageに表情を管理する機能を追加

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,PSDImage,RTTIPersistent,
  PSDImageElementList,PSDImageElementRouteList,PSDImageFlipLayer,PSDImageAviUtl2Filter,
  PSDImageCustomKindDetector,PSDImageCustomDispatcher,
  PsdImageDefine,PsdImageFileStreamBuf,
  PsdImageLayer,PsdImageTree;

type
  TPsdVirtualMarkerMode = (pmmEnsure, pmmReplace, pmmRemove);

type TPSDImageAviUtl2 = class(TPSDImageAviUtl2Filter)
   private
    { Private 宣言 }
    //FCacheItems  : PSDImageCacheRenderItems;
    FElements           : TPSDElementList;
    FElementRoutes      : TPSDElementRouteList;
    FFlip               : TPSDImageFlipLayer;
    FPSDKind            : TPSDImageKind;     // PSD読み込み後に判定した独自処理種別

    FRenderBitmap       : TBitmap;           // AviUtl用の高速描画経路で合成した結果を、VCL表示用に保持する。
    FRenderBuffer       : Pointer;           // RenderAviUtlFilter と同じ形式で最後まで合成する作業バッファ。
    FRenderBufferSize   : Integer;
    FRenderBitmapValid  : Boolean;           // RenderedBitmap が現在のレイヤー状態を反映済みかどうか。
    FRenderFileStream   : TFileStreamBuf;

    FPreloadAllLayerBitmapsOnLoad : Boolean;

    FUseRenderDiffCache : Boolean;           // 表情プレビュー向けの実験機能。前回と今回で同じ下層描画を中間結果として再利用する。
    FLastRenderKeys     : TStringList;       // 前回描画したレイヤー列。差分キャッシュの分岐位置検出に使う。

    FDiffCacheKeys      : TStringList;       // FDiffCacheBuffer に入っている中間結果のレイヤー列。
    FDiffCacheBuffer    : Pointer;           // 共通prefixまで合成済みのRGBAバッファ。全段階は持たず、1枚だけ保持する。
    FDiffCacheSize      : Integer;
    FDiffCachePrefixCount: Integer;          // FDiffCacheBuffer が何枚目の描画レイヤーまで反映しているか。

    FAviUtlFilterScaleMode: Integer;         // AviUtlフィルター出力専用の縮小率。0=等倍、1=1/2、2=1/4。

    procedure RenderAviUtlFilterSub(tss : TPsdFileTrees;fs : TFileStreamBuf;DestBuffer: Pointer);
    // 実際の描画順にレイヤーと比較用キーを並べる。
    procedure BuildAviUtlFilterLayerList(tss: TPsdFileTrees; LayerList: TList; Keys: TStrings);
    // 差分キャッシュ使用時の描画本体。StartIndex から描き、必要なら途中結果を保存する。
    procedure RenderAviUtlFilterLayers(LayerList: TList; fs: TFileStreamBuf;
                                       DestBuffer: Pointer; StartIndex, SaveAfterIndex: Integer;
                                       const BufSize: Integer; const SaveKeys: TStrings);
    // 前回描画と今回描画で先頭から何レイヤー同じかを返す。
    function FindCommonRenderPrefix(const Keys: TStrings): Integer;
    // 現在の描画列が保存済みprefixキャッシュから再開できるかを判定する。
    function CanUseDiffCache(const Keys: TStrings; const BufSize: Integer): Boolean;
    // 共通prefixまでの合成結果を1枚だけ保存する。
    procedure SaveDiffCache(DestBuffer: Pointer; const BufSize, PrefixCount: Integer;
                            const Keys: TStrings);
    procedure ReleaseDiffCache;
    // PreloadAllLayerBitmapsOnLoad=True の比較用。描画時の遅延展開をロード時へ前倒しする。
    procedure LoadAllLayerBitmaps;
    // PSDサイズに合わせて作業バッファを確保し直す。
    procedure EnsureRenderBuffer;
    // 内包ビットマップを PSDサイズ/pf32bit に揃える。
    procedure EnsureRenderBitmap;
    // 作業バッファを VCL の TBitmap(BGRA) へ変換して反映する。
    procedure CopyRenderBufferToBitmap;
    // 未描画なら RenderBitmap を実行して内包ビットマップを返す。
    function GetRenderedBitmap: TBitmap;
    procedure SetAviUtlFilterScaleMode(const Value: Integer);
    // 縮小率指定を 0=等倍、1=1/2、2=1/4 の範囲に丸める
    function NormalizeScaleMode(Value: Integer): Integer;
    // 元PSDサイズから、AviUtl出力用の縮小後サイズを計算する
    function ScaleDimension(Value: Integer): Integer;

    // 大分類探索と動作 Trees:探索対象ツリー Element:大分類名 Parts:小分類名 Scope:探索条件 Mode:動作モード　表示制御、表示状態取得など
    function SetElement(Trees: TPsdFileTrees; const Element, Part: string;
                        Scope: TPsdElementSearchScope;Mode: TPsdElementProcessMode): Boolean;
    // 小分類探索と動作 Trees: 探索対象ツリー  Parts:小分類名  Mode:動作モード
    function SetParts(Trees: TPsdFileTrees;const Part: string;Mode: TPsdElementProcessMode): Boolean;
    // レイヤー名の先頭マーカーを指定モードで更新する
    class function ApplyMarkerToLayerName(const AName, Marker: string;
      Mode: TPsdVirtualMarkerMode): string; static;
    // レイヤー名とANM用絶対パスをまとめて更新する
    class procedure SetLayerNameAndAnmText(Layer: TPsdFileLayer;
      const AName: string); static;
    // レイヤーへ仮想マーカー処理を適用する。変更した場合 True
    class function ApplyMarkerToLayer(Layer: TPsdFileLayer; const Marker: string;
      Mode: TPsdVirtualMarkerMode): Boolean; static;
    // 名前一致判定
    function MatchLayerName(const A, B: string): Boolean;
    // ルート形式探索（a/b/c 形式）
    function SetPartsByRoute(Trees: TPsdFileTrees;const Segments: TArray<string>;Idx: Integer;Mode: TPsdElementProcessMode): Boolean;
    // 従来探索（単純名一致）
    function SetPartsLegacy(Trees: TPsdFileTrees;const Part: string;Mode: TPsdElementProcessMode): Boolean;
  protected
    // AviUtl出力中は縮小後サイズを返す。通常経路は ScaleMode=0 のため等倍になる
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
  public
    { Public 宣言 }
    constructor Create();override;
    destructor Destroy;override;
    // PSDファイル読み込み
    procedure LoadFromFile(const FileName : string);override;
    // 再描画が必要なときに明示的に呼ぶ
    procedure Invalidate;
    // フィルタプラグイン用に出力
    procedure RenderAviUtlFilter(DestBuffer: Pointer);
    // フィルタ描画経路で合成してから内包ビットマップへ反映
    procedure RenderBitmap;

    // PSDToolkit対応判定：先頭に '*' を含むレイヤーが存在するか
    function HasStarLayer: Boolean;
    // 再帰用：ツリー内に '*' を含むレイヤーがあるか
    function HasStarLayerInTrees(tss: TPsdFileTrees): Boolean;

    // ツリーを解析して指定マーカーを先頭に付加し PSDToolkitに対応させる
    class function IsVirtualMarker(const S: string): Boolean; static;
    class function GetVirtualMarker(const AName: string): string; static;
    class function StripVirtualMarker(const AName: string): string; static;
    procedure ApplyVirtualMarker(const Marker: string); overload;
    procedure ApplyVirtualMarker(const Marker: string;
      Mode: TPsdVirtualMarkerMode); overload;
    procedure ApplyVirtualMarkerToTrees(tss: TPsdFileTrees; const Marker: string); overload;
    procedure ApplyVirtualMarkerToTrees(tss: TPsdFileTrees; const Marker: string;
      Mode: TPsdVirtualMarkerMode); overload;

    // 互換ラッパー
    procedure ApplyVirtualStar;
    procedure ApplyVirtualStarToTrees(tss: TPsdFileTrees);

    procedure RebuildTreeState();override;
    procedure VisibleInit();override;
    // 大分類小分類から表情を変更
    procedure SetElementPart(const Element,Part :string); overload;
    procedure SetElementPart(const Group,Element,Part :string); overload;
    // 大分類小分類から加算パーツなどを解除
    procedure ClearElementPart(const Element,Part :string); overload;
    procedure ClearElementPart(const Group,Element,Part :string); overload;
    // 大分類小分類インデックスから表情を変更
    procedure SetElementIndexPartIndex(const Element,Part :Integer);
    //  大分類小分類インデックスから表情を変更
    procedure SetElementPartIndex(const Index : Integer);
    //  True:大分類小分類インデックスに該当するレイヤーが表示状態
    function IsElementPartIndexVisible(const Index: Integer): Boolean;
    // インデックス値に該当する大分類小分類を返す
    function IndexToElementPartName(const Index : Integer;var Element,Part : string) :  Boolean; overload;
    function IndexToElementPartName(const Index : Integer;var Group,Element,Part : string) :  Boolean; overload;
    // 反転状態を反映
    procedure ApplyFlip(Flip: Integer);


    property Elements : TPSDElementList read FElements;
    property PSDKind : TPSDImageKind read FPSDKind;
    // True: LoadFromFile時に全描画対象レイヤー画像を展開する。既定はFalse。
    property PreloadAllLayerBitmapsOnLoad: Boolean
      read FPreloadAllLayerBitmapsOnLoad write FPreloadAllLayerBitmapsOnLoad;
    // True: 共通prefixの中間描画結果を1枚だけ保持して、次回途中から描画する。既定はFalse。
    property UseRenderDiffCache: Boolean
      read FUseRenderDiffCache write FUseRenderDiffCache;
    // RenderAviUtlFilter専用。0=等倍、1=1/2、2=1/4。
    property AviUtlFilterScaleMode: Integer
      read FAviUtlFilterScaleMode write SetAviUtlFilterScaleMode;
    // RenderBitmap の結果。外部からビットマップ参照のみ取得する。
    property RenderedBitmap: TBitmap read GetRenderedBitmap;
  end;

implementation

{$IFDEF DEBUG}
uses
  PSDImageDebugLog;
{$ENDIF}

{
const
  PSD_LOAD_DEBUG = True;

procedure DebugPSDLoad(const Stage: string; PsdImage: TPSDImageAviUtl2;
  const AFileName: string);
begin
  if not PSD_LOAD_DEBUG then Exit;
  OutputDebugString(PChar(Format(
    '[PSDLoad%s] Thread=%d Psd=%s File="%s"',
    [Stage, GetCurrentThreadId, IntToHex(NativeUInt(PsdImage), SizeOf(Pointer) * 2), AFileName]
  )));
end;
}

{ TPSDImageAviUtl2 }

constructor TPSDImageAviUtl2.Create;
begin
  inherited;
  FElements := TPSDElementList.Create;
  FElementRoutes := TPSDElementRouteList.Create(True);
  FFlip := TPSDImageFlipLayer.Create;
  FPSDKind := pikNone;
  FRenderBitmap := TBitmap.Create;
  FRenderBuffer := nil;
  FRenderBufferSize := 0;
  FRenderBitmapValid := False;
  FRenderFileStream := nil;
  FPreloadAllLayerBitmapsOnLoad := False;
  FUseRenderDiffCache := False;
  FLastRenderKeys := TStringList.Create;
  FDiffCacheKeys := TStringList.Create;
  FDiffCacheBuffer := nil;
  FDiffCacheSize := 0;
  FDiffCachePrefixCount := 0;
  FAviUtlFilterScaleMode := 0;
end;

destructor TPSDImageAviUtl2.Destroy;
begin
  ReleaseDiffCache;
  FDiffCacheKeys.Free;
  FLastRenderKeys.Free;
  FRenderFileStream.Free;
  if FRenderBuffer <> nil then
    FreeMem(FRenderBuffer);
  FRenderBitmap.Free;
  FFlip.Free;
  FElementRoutes.Free;
  FElements.Free;
  inherited;
end;

function TPSDImageAviUtl2.HasStarLayer: Boolean;
begin
  Result := HasStarLayerInTrees(Trees);
end;

function TPSDImageAviUtl2.HasStarLayerInTrees(tss: TPsdFileTrees): Boolean;
var
  i     : Integer;
  ts    : TPsdFileTree;
  layer : TPsdFileLayer;
begin
  Result := False;
  if tss = nil then Exit;

  for i := 0 to tss.Count - 1 do
  begin
    ts := tss[i];
    if ts = nil then Continue;

    layer := ts.Layer;
    if (layer <> nil) and (layer.Name <> '') then
    begin
      // 先頭に '*' があれば PSDToolkit対応とみなす
      if layer.Name[1] = '*' then
        Exit(True);
    end;

    // 子ツリーを再帰探索
    if (ts.Trees <> nil) and HasStarLayerInTrees(TPsdFileTrees(ts.Trees)) then
      Exit(True);
  end;
end;

procedure TPSDImageAviUtl2.Invalidate;
begin
  FRendered := False;
  FRenderBitmapValid := False;
end;

procedure TPSDImageAviUtl2.RebuildTreeState;
begin
  inherited;
  Invalidate;
end;

procedure TPSDImageAviUtl2.VisibleInit;
begin
  inherited;
  ApplyCustomInitialVisibility(Self, FPSDKind);
  FRenderBitmapValid := False;
end;

procedure TPSDImageAviUtl2.LoadAllLayerBitmaps;
var
  i: Integer;
  dl: TPsdFileLayer;
begin
  if FRenderFileStream = nil then Exit;

  for i := 0 to Layers.Count - 1 do
  begin
    dl := Layers[i];
    if dl = nil then Continue;
    if dl.LayerType <> 0 then Continue;
    if dl.Index = Layers.Count - 1 then Continue;

    dl.LoadFromBitmap(FRenderFileStream);
  end;

  FRenderFileStream.Seek(0);
end;

procedure TPSDImageAviUtl2.LoadFromFile(const FileName: string);
begin
  //DebugPSDLoad('Begin', Self, FileName);
  FPSDKind := pikNone;
  DebugMarkerRoute := '';
  FLastRenderKeys.Clear;
  ReleaseDiffCache;
  FreeAndNil(FRenderFileStream);

  inherited LoadFromFile(FileName);
  FPSDKind := DetectPSDImageKind(Self);
  {$IFDEF DEBUG}
  PSDDebugLog('PSDLoad', Format('LoadFromFile detected Kind=%d Caption="%s" File="%s"',
    [Ord(FPSDKind), PSDImageKindCaption(FPSDKind), Self.FileName]));
  {$ENDIF}

  if FileExists(Self.FileName) then
  begin
    FRenderFileStream := TFileStreamBuf.Create(Self.FileName);
    if FPreloadAllLayerBitmapsOnLoad then
      LoadAllLayerBitmaps;
  end;

  FRendered := False;
  FRenderBitmapValid := False;

  ApplyCustomMarkers(Self, FPSDKind); // 立ち絵ごとに独自の解釈を行う

  if not HasStarLayer then  begin     // PSDToolkit非対応と判定された場合のみ補正
    DebugMarkerRoute :=
      'HasStarLayer=False after custom markers -> ApplyVirtualMarker("*")';
    ApplyVirtualMarker('*');          // '*'を付ける処理
  end
  else begin
    DebugMarkerRoute :=
      'HasStarLayer=True after custom markers -> ApplyVirtualMarker("+")';
    ApplyVirtualMarker('+');          // '+'を付ける処理
    ApplyCustomFallbackVirtualMarkers(Self, FPSDKind); // 自動補完で不足した独自マーカーを補う
  end;
  ApplyCustomInitialVisibility(Self, FPSDKind); // 立ち絵ごとの初期表示を補正
  ApplyCustomExclusiveGroups(Self, FPSDKind); // 立ち絵ごとに独自の表示連動を登録
  FElements.Clear;                    // 大分類小分類を消去
  FElements.ParseFromPSD(Self);       // 大分類小分類に分類
  {$IFDEF DEBUG}
  PSDDebugLog('PSDLoad', Format('Before ApplyCustomElementList Kind=%d Elements=%d File="%s"',
    [Ord(FPSDKind), FElements.Count, Self.FileName]));
  {$ENDIF}
  ApplyCustomElementList(Self, FPSDKind, FElements); // 立ち絵ごとに独自の分類補正を行う
  {$IFDEF DEBUG}
  PSDDebugLog('PSDLoad', Format('After ApplyCustomElementList Kind=%d Elements=%d File="%s"',
    [Ord(FPSDKind), FElements.Count, Self.FileName]));
  {$ENDIF}
  //FElements.ApplyElementStarsByMatchingBounds; // 矩形が一致する大分類レイヤーへ '*' を付ける
  FElementRoutes.BuildFromElements(Self,FElements); // 大分類小分類からレイヤーツリーへの索引を作成
  FFlip.ParseFromPSD(Self);
  //DebugPSDLoad('End', Self, FileName);
end;

procedure TPSDImageAviUtl2.EnsureRenderBuffer;
var
  BufSize: Integer;
begin
  BufSize := Width * Height * SizeOf(TFourth);

  // PSD未読み込みなどでサイズが無い場合は、古い作業バッファを破棄する。
  if BufSize <= 0 then
  begin
    if FRenderBuffer <> nil then
    begin
      FreeMem(FRenderBuffer);
      FRenderBuffer := nil;
    end;
    FRenderBufferSize := 0;
    Exit;
  end;

  if FRenderBufferSize = BufSize then Exit;

  // サイズが変わった場合だけ再確保する。
  if FRenderBuffer <> nil then
  begin
    FreeMem(FRenderBuffer);
    FRenderBuffer := nil;
  end;

  GetMem(FRenderBuffer, BufSize);
  FRenderBufferSize := BufSize;
end;

procedure TPSDImageAviUtl2.EnsureRenderBitmap;
begin
  // TBitmapは表示用として保持し続け、PSDサイズが変わったときだけサイズ変更する。
  if (FRenderBitmap.Width <> Width) or (FRenderBitmap.Height <> Height) then
    FRenderBitmap.SetSize(Width, Height);

  FRenderBitmap.PixelFormat := pf32bit;
  FRenderBitmap.AlphaFormat := afIgnored;
end;

procedure TPSDImageAviUtl2.CopyRenderBufferToBitmap;
var
  y, x: Integer;
  SrcLine: PFourthArray;
  DstLine: PFourthArray;
begin
  if (FRenderBuffer = nil) or (FRenderBufferSize <= 0) then Exit;

  EnsureRenderBitmap;

  for y := 0 to Height - 1 do
  begin
    SrcLine := Pointer(NativeUInt(FRenderBuffer) + NativeUInt(y) * Width * SizeOf(TFourth));
    DstLine := FRenderBitmap.ScanLine[y];

    // RenderAviUtlFilter側のバッファは、VCL TBitmapのBGRAとはR/Bが逆になる。
    for x := 0 to Width - 1 do
    begin
      DstLine^[x].B := SrcLine^[x].R;
      DstLine^[x].G := SrcLine^[x].G;
      DstLine^[x].R := SrcLine^[x].B;
      DstLine^[x].A := SrcLine^[x].A;
    end;
  end;

  FRenderBitmap.AlphaFormat := afDefined;
  FRenderBitmapValid := True;
end;

function TPSDImageAviUtl2.GetRenderedBitmap: TBitmap;
begin
  if not FRenderBitmapValid then
    RenderBitmap;

  Result := FRenderBitmap;
end;

function TPSDImageAviUtl2.NormalizeScaleMode(Value: Integer): Integer;
begin
  if Value < 0 then
    Result := 0
  else if Value > 2 then
    Result := 2
  else
    Result := Value;
end;

function TPSDImageAviUtl2.ScaleDimension(Value: Integer): Integer;
var
  Divisor: Integer;
begin
  if Value <= 0 then
    Exit(0);

  Divisor := 1 shl NormalizeScaleMode(FAviUtlFilterScaleMode);
  // 奇数サイズのPSDでも端を落とさないよう、縮小後サイズは切り上げる
  Result := (Value + Divisor - 1) div Divisor;
end;

function TPSDImageAviUtl2.GetHeight: Integer;
begin
  Result := ScaleDimension(inherited GetHeight);
end;

function TPSDImageAviUtl2.GetWidth: Integer;
begin
  Result := ScaleDimension(inherited GetWidth);
end;

procedure TPSDImageAviUtl2.SetAviUtlFilterScaleMode(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := NormalizeScaleMode(Value);
  if FAviUtlFilterScaleMode = NewValue then Exit;

  // 縮小率が変わると出力サイズと中間キャッシュが変わるため、描画キャッシュを破棄する
  FAviUtlFilterScaleMode := NewValue;
  ReleaseDiffCache;
  FLastRenderKeys.Clear;
  FRendered := False;
  FRenderBitmapValid := False;
end;


function TPSDImageAviUtl2.MatchLayerName(const A, B: string): Boolean;
begin
  Result := SameText(Trim(A), Trim(B));
end;

class function TPSDImageAviUtl2.IsVirtualMarker(const S: string): Boolean;
begin
  Result := (S <> '') and CharInSet(S[1], ['*', '!', '+']);
end;

class function TPSDImageAviUtl2.GetVirtualMarker(const AName: string): string;
var
  S: string;
begin
  Result := '';
  S := Trim(AName);
  if IsVirtualMarker(S) then
    Result := S[1];
end;

class function TPSDImageAviUtl2.StripVirtualMarker(
  const AName: string): string;
begin
  Result := Trim(AName);
  if IsVirtualMarker(Result) then
    Delete(Result, 1, 1);
end;

class function TPSDImageAviUtl2.ApplyMarkerToLayerName(
  const AName, Marker: string; Mode: TPsdVirtualMarkerMode): string;
var
  CurrentMarker: string;
  NewMarker: string;
  Body: string;
begin
  Result := AName;
  NewMarker := Trim(Marker);
  if NewMarker <> '' then
    NewMarker := NewMarker[1];

  if (Mode <> pmmRemove) and not IsVirtualMarker(NewMarker) then
    Exit;

  CurrentMarker := GetVirtualMarker(AName);
  Body := StripVirtualMarker(AName);

  case Mode of
    pmmEnsure:
      begin
        // 自動補正では既存のユーザー指定を壊さない。別マーカーも二重付与しない。
        if CurrentMarker <> '' then Exit;
        Result := NewMarker + Body;
      end;
    pmmReplace:
      Result := NewMarker + Body;
    pmmRemove:
      Result := Body;
  end;
end;

class procedure TPSDImageAviUtl2.SetLayerNameAndAnmText(
  Layer: TPsdFileLayer; const AName: string);
begin
  if Layer = nil then Exit;

  Layer.Name := AName;
  Layer.AnmText := Layer.AnmGroup2 + Layer.Name;
end;

class function TPSDImageAviUtl2.ApplyMarkerToLayer(Layer: TPsdFileLayer;
  const Marker: string; Mode: TPsdVirtualMarkerMode): Boolean;
var
  NewName: string;
begin
  Result := False;
  if Layer = nil then Exit;

  NewName := ApplyMarkerToLayerName(Layer.Name, Marker, Mode);
  if NewName = Layer.Name then Exit;

  SetLayerNameAndAnmText(Layer, NewName);
  Result := True;
end;

procedure TPSDImageAviUtl2.ApplyFlip(Flip: Integer);
begin
  FlipMode := Flip;
  FFlip.ApplyFlip(Flip);
  FRenderBitmapValid := False;
end;

procedure TPSDImageAviUtl2.ApplyVirtualMarker(const Marker: string);
begin
  ApplyVirtualMarker(Marker, pmmEnsure);
end;

procedure TPSDImageAviUtl2.ApplyVirtualMarker(const Marker: string;
  Mode: TPsdVirtualMarkerMode);
begin
  ApplyVirtualMarkerToTrees(Trees, Marker, Mode);
end;

procedure TPSDImageAviUtl2.ApplyVirtualStar;
begin
  ApplyVirtualMarker('*');
end;

procedure TPSDImageAviUtl2.ApplyVirtualMarkerToTrees(tss: TPsdFileTrees; const Marker: string);
begin
  ApplyVirtualMarkerToTrees(tss, Marker, pmmEnsure);
end;

procedure TPSDImageAviUtl2.ApplyVirtualMarkerToTrees(tss: TPsdFileTrees;
  const Marker: string; Mode: TPsdVirtualMarkerMode);
var
  i         : Integer;
  ts        : TPsdFileTree;
  layer     : TPsdFileLayer;
  LeafCount : Integer;
  Trees     : TPsdFileTrees;
begin
  if (Mode <> pmmRemove) and not IsVirtualMarker(Marker) then Exit;
  if tss = nil then Exit;

  // -----------------------------
  // 調査フェーズ：最下層数を数える
  // -----------------------------
  LeafCount := 0;
  for i := 0 to tss.Count - 1 do
  begin
    ts := tss[i];
    if ts = nil then Continue;

    Trees := TPsdFileTrees(ts.Trees);
    if (Trees = nil) or (Trees.Count = 0) then
      Inc(LeafCount);
  end;

  // --------------------------------
  // 付与フェーズ：条件成立時のみ指定マーカー（先頭）
  // --------------------------------
  if LeafCount >= 2 then
  begin
    for i := 0 to tss.Count - 1 do begin
      ts := tss[i];
      if ts = nil then Continue;

      Trees := TPsdFileTrees(ts.Trees);
      if (Trees = nil) or (Trees.Count = 0) then begin
        if (Marker = '+') and ts.Visible then Continue;

        layer := ts.Layer;
        ApplyMarkerToLayer(layer, Marker, Mode);
      end;
    end;
  end;

  // -----------------------------
  // 再帰：子ツリーへ
  // -----------------------------
  for i := 0 to tss.Count - 1 do
  begin
    ts := tss[i];
    if ts = nil then Continue;

    layer := ts.Layer;
    if (Mode <> pmmRemove) and (layer <> nil) and
      (layer.LayerType = -1) and (GetVirtualMarker(layer.Name) = '!') then
      Continue;

    if ts.Trees <> nil then
      ApplyVirtualMarkerToTrees(TPsdFileTrees(ts.Trees), Marker, Mode);
  end;
end;

procedure TPSDImageAviUtl2.ApplyVirtualStarToTrees(tss: TPsdFileTrees);
begin
  ApplyVirtualMarkerToTrees(tss, '*');
end;

procedure TPSDImageAviUtl2.RenderBitmap;
var
  WasRendered: Boolean;
begin
  FRenderBitmapValid := False;

  if not FileExists(FileName) then Exit;

  EnsureRenderBuffer;
  if FRenderBuffer = nil then Exit;

  WasRendered := FRendered;
  try
    // 既存の高速なAviUtl用合成処理を流用して、まず生バッファへ描画する。
    RenderAviUtlFilter(FRenderBuffer);
  finally
    // 親クラスのBitmap用レンダー済み状態とは別物なので、元の状態に戻す。
    FRendered := WasRendered;
  end;
  // 最後に表示用TBitmapへまとめて変換する。
  CopyRenderBufferToBitmap;
end;

procedure TPSDImageAviUtl2.RenderAviUtlFilter(DestBuffer: Pointer);
var
  BufSize: Integer;
  LayerList: TList;
  Keys: TStringList;
  StartIndex: Integer;
  SaveAfterIndex: Integer;
  CommonPrefix: Integer;
begin
  if (DestBuffer = nil) or (not FileExists(FileName)) then
    Exit;
  // ---- 通常描画 ----
  BufSize := Width * Height * SizeOf(TFourth);

  if FRenderFileStream = nil then
    FRenderFileStream := TFileStreamBuf.Create(FileName);

  FRenderFileStream.Seek(0);

  if not FUseRenderDiffCache then
  begin
    // 差分キャッシュOFF時は従来経路をそのまま使う。
    FillChar(DestBuffer^, BufSize, 0);
    RenderAviUtlFilterSub(Trees, FRenderFileStream, DestBuffer);
    FRendered := True;
    Exit;
  end;

  LayerList := TList.Create;
  Keys := TStringList.Create;
  try
    BuildAviUtlFilterLayerList(Trees, LayerList, Keys);

    StartIndex := 0;
    SaveAfterIndex := -1;

    if CanUseDiffCache(Keys, BufSize) then
    begin
      // 保存済みprefixが一致したので、中間結果から続きを描く。
      Move(FDiffCacheBuffer^, DestBuffer^, BufSize);
      StartIndex := FDiffCachePrefixCount;
    end
    else
    begin
      FillChar(DestBuffer^, BufSize, 0);

      CommonPrefix := FindCommonRenderPrefix(Keys);
      if (CommonPrefix > 0) and (CommonPrefix < Keys.Count) then
        // 今回は通常描画しつつ、次回に使う分岐直前の中間結果を1回だけ保存する。
        SaveAfterIndex := CommonPrefix - 1;
    end;

    RenderAviUtlFilterLayers(LayerList, FRenderFileStream, DestBuffer,
                             StartIndex, SaveAfterIndex, BufSize, Keys);

    FLastRenderKeys.Assign(Keys);
  finally
    Keys.Free;
    LayerList.Free;
  end;
  FRendered := True;
end;

procedure TPSDImageAviUtl2.BuildAviUtlFilterLayerList(tss: TPsdFileTrees;
  LayerList: TList; Keys: TStrings);
var
  i: Integer;
  ts: TPsdFileTree;
  dl: TPsdFileLayer;
begin
  if tss = nil then Exit;

  for i := tss.Count - 1 downto 0 do
  begin
    ts := tss[i];
    if (ts = nil) or (not ts.Visible) then Continue;

    BuildAviUtlFilterLayerList(TPsdFileTrees(ts.Trees), LayerList, Keys);

    dl := ts.Layer;
    if dl = nil then Continue;
    if dl.LayerType <> 0 then Continue;
    if dl.Index = Layers.Count - 1 then Continue;

    LayerList.Add(dl);
    // レイヤー名ではなくPSD内のIndexと描画モードで、描画順の同一性だけを見る。
    Keys.Add(IntToStr(dl.Index) + ':' + IntToStr(Integer(dl.BlendMode)));
  end;
end;

procedure TPSDImageAviUtl2.RenderAviUtlFilterLayers(LayerList: TList;
  fs: TFileStreamBuf; DestBuffer: Pointer; StartIndex, SaveAfterIndex: Integer;
  const BufSize: Integer; const SaveKeys: TStrings);
var
  i: Integer;
  dl: TPsdFileLayer;
begin
  if StartIndex < 0 then
    StartIndex := 0;

  for i := StartIndex to LayerList.Count - 1 do
  begin
    dl := TPsdFileLayer(LayerList[i]);
    dl.LoadFromBitmap(fs);
    // AviUtl出力専用の縮小率をレイヤーへ渡し、縮小チャンネルで合成する
    dl.DrawAviUtlFilter(DestBuffer, Width, Height,
                         dl.Channels[0].Left, dl.Channels[0].Top,
                         FAviUtlFilterScaleMode);

    if i = SaveAfterIndex then
      // 分岐直前まで描き終えた瞬間のバッファを次回用に保存する。
      SaveDiffCache(DestBuffer, BufSize, SaveAfterIndex + 1, SaveKeys);
  end;
end;

function TPSDImageAviUtl2.FindCommonRenderPrefix(const Keys: TStrings): Integer;
var
  MaxCount: Integer;
begin
  Result := 0;
  MaxCount := Keys.Count;
  if FLastRenderKeys.Count < MaxCount then
    MaxCount := FLastRenderKeys.Count;

  while (Result < MaxCount) and (Keys[Result] = FLastRenderKeys[Result]) do
    Inc(Result);
end;

function TPSDImageAviUtl2.CanUseDiffCache(const Keys: TStrings;
  const BufSize: Integer): Boolean;
var
  i: Integer;
begin
  Result := False;

  if (FDiffCacheBuffer = nil) or (FDiffCacheSize <> BufSize) then Exit;
  if (FDiffCachePrefixCount <= 0) or (FDiffCachePrefixCount > Keys.Count) then Exit;
  if FDiffCacheKeys.Count <> FDiffCachePrefixCount then Exit;

  for i := 0 to FDiffCachePrefixCount - 1 do
    if Keys[i] <> FDiffCacheKeys[i] then
      Exit;

  Result := True;
end;

procedure TPSDImageAviUtl2.SaveDiffCache(DestBuffer: Pointer;
  const BufSize, PrefixCount: Integer; const Keys: TStrings);
var
  i: Integer;
begin
  if (DestBuffer = nil) or (BufSize <= 0) or (PrefixCount <= 0) then Exit;
  if PrefixCount > Keys.Count then Exit;

  if FDiffCacheSize <> BufSize then
  begin
    ReleaseDiffCache;
    GetMem(FDiffCacheBuffer, BufSize);
    FDiffCacheSize := BufSize;
  end
  else if FDiffCacheBuffer = nil then
    GetMem(FDiffCacheBuffer, BufSize);

  Move(DestBuffer^, FDiffCacheBuffer^, BufSize);

  FDiffCacheKeys.Clear;
  for i := 0 to PrefixCount - 1 do
    FDiffCacheKeys.Add(Keys[i]);

  FDiffCachePrefixCount := PrefixCount;
end;

procedure TPSDImageAviUtl2.ReleaseDiffCache;
begin
  if FDiffCacheBuffer <> nil then
  begin
    FreeMem(FDiffCacheBuffer);
    FDiffCacheBuffer := nil;
  end;

  FDiffCacheSize := 0;
  FDiffCachePrefixCount := 0;
  if FDiffCacheKeys <> nil then
    FDiffCacheKeys.Clear;
end;

procedure TPSDImageAviUtl2.RenderAviUtlFilterSub(tss: TPsdFileTrees;
  fs: TFileStreamBuf; DestBuffer: Pointer);
var
  i : Integer;
  ts : TPsdFileTree;
  dl : TPsdFileLayer;
begin
  for i := tss.Count-1 downto 0 do begin
    ts := tss[i];
    if not ts.Visible then continue;
    RenderAviUtlFilterSub(TPsdFileTrees(ts.Trees),fs,DestBuffer);

    dl := ts.Layer;
    if dl.LayerType<>0 then continue;
    if dl.Index = Layers.Count-1 then Continue;
    dl.LoadFromBitmap(fs);
    // 差分キャッシュ未使用経路でも、同じ縮小チャンネル描画を使う
    dl.DrawAviUtlFilter(DestBuffer,Width,Height,dl.Channels[0].Left,dl.Channels[0].Top,
                         FAviUtlFilterScaleMode);
  end;
end;

procedure TPSDImageAviUtl2.SetElementPart(const Element, Part: string);
begin
  if FElementRoutes.SetElementPart(Element,Part) then begin
    Invalidate;
    Exit;
  end;
end;

procedure TPSDImageAviUtl2.SetElementPart(const Group, Element, Part: string);
begin
  if FElementRoutes.SetElementPart(Group,Element,Part) then begin
    Invalidate;
    Exit;
  end;
end;

procedure TPSDImageAviUtl2.ClearElementPart(const Element, Part: string);
begin
  if FElementRoutes.ClearElementPart(Element,Part) then begin
    Invalidate;
    Exit;
  end;
end;

procedure TPSDImageAviUtl2.ClearElementPart(const Group, Element, Part: string);
begin
  if FElementRoutes.ClearElementPart(Group,Element,Part) then begin
    Invalidate;
    Exit;
  end;
end;

procedure TPSDImageAviUtl2.SetElementIndexPartIndex(const Element, Part: Integer);
var
  sGroup, sElement, sPart: string;
begin
  // Part = 0 は操作しない仕様
  if Part <= 0 then Exit;

  // Element 範囲チェック
  if (Element < 0) or (Element >= Elements.Count) then Exit;

  // Part は 1 始まりなので -1 した後で範囲チェック
  if (Part - 1 < 0) or (Part - 1 >= Elements[Element].Parts.Count) then Exit;

  sGroup   := Elements[Element].Group; // 表示位置指定でも同名 Element/Part の親ルートを保持する
  sElement := Elements[Element].Name;
  sPart    := Elements[Element].Parts[Part - 1].Name;

  if FElementRoutes.SetElementPart(sGroup,sElement,sPart) then begin
    Invalidate;
    Exit;
  end;
end;

procedure TPSDImageAviUtl2.SetElementPartIndex(const Index: Integer);
var
  Group,Element,Part : string;
begin
  if not FElements.IndexToElementPartName(Index,Group,Element,Part) then Exit; // 保存済み ElementPartIndex から Group も復元する
  if FElementRoutes.SetElementPart(Group,Element,Part) then begin
    Invalidate;
    Exit;
  end;
end;


function TPSDImageAviUtl2.IndexToElementPartName(const Index: Integer;
  var Element, Part: string): Boolean;
begin
  Result := FElements.IndexToElementPartName(Index,Element,Part);
end;

function TPSDImageAviUtl2.IndexToElementPartName(const Index: Integer;
  var Group, Element, Part: string): Boolean;
begin
  Result := FElements.IndexToElementPartName(Index,Group,Element,Part);
end;

function TPSDImageAviUtl2.IsElementPartIndexVisible(const Index: Integer): Boolean;
var
  Group,Element,Part : string;
begin
  Result := False;
  if not FElements.IndexToElementPartName(Index,Group,Element,Part) then Exit;
  Result := FElementRoutes.IsElementPartVisible(Group,Element,Part);
end;



function TPSDImageAviUtl2.SetElement(Trees: TPsdFileTrees;const Element, Part: string;
                                     Scope: TPsdElementSearchScope;Mode: TPsdElementProcessMode): Boolean;
var
  i     : Integer;
  ts    : TPsdFileTree;
  layer : TPsdFileLayer;
begin
  Result := False;

  if (Element = '') or (Part = '') then
    Exit;

  // PSD ツリー上には存在しない仮想大分類。
  // ルート近くのキャラ選択（*ずんだもん等）はツリー先頭から小分類だけで探す。
  if SameText(Trim(Element), 'Root') then
  begin
    Result := SetParts(Trees, Part, Mode);
    Exit;
  end;

  for i := 0 to Trees.Count - 1 do
  begin
    ts := Trees[i];
    if ts = nil then
      Continue;

    layer := ts.Layer;
    if layer = nil then
      Continue;

    // ★ 大分類探索時の可視条件切り替え
    case Scope of
      pssVisibleOnly: if not ts.Visible then Continue;
      pssUnmarkedOrVisible: begin
        if (not ts.IsMultiSelect) and (not ts.Visible) then Continue;
      end;
      //pssAll: ;
    end;

    // 大分類名が一致した場合
    if Trim(layer.Name) = Trim(Element) then
    begin
      // この大分類配下で小分類探索
      if SetParts(TPsdFileTrees(ts.Trees), Part,Mode) then
        Exit(True);   // ★ 最初に見つかった時点で完全終了
    end;

    // 子階層に対して大分類探索を継続
    if SetElement(TPsdFileTrees(ts.Trees), Element, Part, Scope,Mode) then
      Exit(True);
  end;
end;

function TPSDImageAviUtl2.SetParts(
  Trees: TPsdFileTrees;
  const Part: string;
  Mode: TPsdElementProcessMode
): Boolean;
var
  Segments: TArray<string>;
begin
  Result := False;

  if (Trees = nil) or (Trim(Part) = '') then Exit;

  // ルート形式（a/b/c）
  if Part.Contains('/') then
  begin
    Segments := Part.Split(['/']);
    if Length(Segments) = 0 then Exit;

    Result := SetPartsByRoute(Trees, Segments, 0, Mode);
  end
  else
  begin
    // 従来形式（単純一致）
    Result := SetPartsLegacy(Trees, Part, Mode);
  end;
end;

function TPSDImageAviUtl2.SetPartsByRoute(Trees: TPsdFileTrees;const Segments: TArray<string>;
                                          Idx: Integer;Mode: TPsdElementProcessMode): Boolean;
var
  i: Integer;
  ts: TPsdFileTree;
  lyr: TPsdFileLayer;
begin
  Result := False;
  if Trees = nil then Exit;
  if (Idx < 0) or (Idx > High(Segments)) then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    ts := Trees[i];
    if ts = nil then Continue;

    lyr := ts.Layer;
    if lyr = nil then Continue;

    if not MatchLayerName(lyr.Name, Segments[Idx]) then Continue;

    if Idx = High(Segments) then
    begin
      case Mode of
        pepmSetVisible:
        begin
          ts.Visible := True;
          Exit(True)
        end;
        pepmCheckVisible: Exit(ts.Visible);
      end;
      Exit;
    end;

    if SetPartsByRoute(TPsdFileTrees(ts.Trees), Segments, Idx + 1, Mode) then
    begin
      if Mode = pepmSetVisible then
        ts.Visible := True;

      Result := True;
    end;
  end;
end;

function TPSDImageAviUtl2.SetPartsLegacy(Trees: TPsdFileTrees;const Part: string;Mode: TPsdElementProcessMode): Boolean;
var
  i: Integer;
  ts: TPsdFileTree;
  layer: TPsdFileLayer;
begin
  Result := False;
  if Trees = nil then Exit;

  for i := 0 to Trees.Count - 1 do
  begin
    ts := Trees[i];
    if ts = nil then Continue;

    layer := ts.Layer;
    if layer = nil then Continue;

    if MatchLayerName(layer.Name, Part) then
    begin
      case Mode of
        pepmSetVisible:
        begin
          ts.Visible := True;
          Exit(True)
        end;
        pepmCheckVisible: Exit(ts.Visible);
      end;
      Exit;
    end;

    if SetPartsLegacy(TPsdFileTrees(ts.Trees), Part, Mode) then
    begin
      if Mode = pepmSetVisible then
        ts.Visible := True;

      Result := True;
    end;
  end;
end;

end.
