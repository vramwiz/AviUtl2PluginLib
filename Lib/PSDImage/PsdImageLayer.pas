unit PsdImageLayer;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,PsdImageDefine,
  PsdImageFileStreamBuf,PsdImageBlend,PsdImageChannel;

type
  TPsdFileLayer = class(TPersistent)
  private
    { Private 宣言 }
    FChannelCount : Integer;
    FChannels     : TPsdFileChannels;
    FTransParent  : Integer;
    FClipping     : Integer;
    FFlag         : Integer;
    FBlends       : TPsdFileBlends;
    FBlendGlay    : TPsdFileBlend;
    FNameShifJis  : AnsiString;
    FNameUnicode  : string;
    FLayerType    : Integer;          // 0:表情 1,2:開く 3:閉じる
    FProtectFlag  : Integer;
    FOwner        : TObject;
    FBlendMode    : TPsdFileBlandType;
    FPng          : tPngimage;
    FAnmText      : string;
    FAnmGroup     : string;
    FAnmGroup2    : string;
    FTree         : TObject;
    FImageLoaded  : Boolean;
    FIndex        : Integer;
    // AviUtl出力縮小用：元チャンネルとは別に保持する縮小後チャンネル
    FScaledChannels : TPsdFileChannels;
    // FScaledChannels がどの縮小率で生成済みかを覚えて、同じ縮小率では再生成しない
    FScaledChannelMode : Integer;

    procedure LoadFromBitmapFile();
    function LoadFromStreamNorm(fs : TFileStreamBuf;mode : TPsdFileBlandType) : Integer;
    function LoadFromStreamLuni(fs : TFileStreamBuf) : Boolean;
    function LoadFromStreamLsct(fs : TFileStreamBuf) : Boolean;
    function LoadFromStreamLspf(fs : TFileStreamBuf) : Boolean;
    function LoadFromStreamEtc(fs : TFileStreamBuf) : Boolean;

    function GetName: string;
    // PSDデータ内の識別文字を描画エフェクタ型に変換
    function GetBlandMode(const str : AnsiString) : TPsdFileBlandType;
    function GetVisible: Boolean;
    function GetTreeVisible: Boolean;
    procedure SetTreeVisible(const Value: Boolean);
    procedure SetName(const Value: string);
    // 元チャンネル読み直し時などに、縮小済みチャンネルキャッシュを破棄する
    procedure InvalidateScaledChannels;
    // AviUtl出力時に描画へ使うチャンネル集合を返す。0なら元チャンネルを直接返す
    function GetDrawChannels(ScaleMode: Integer): TPsdFileChannels;
    function TryGetRGBAChannels(AChannels: TPsdFileChannels;
      const LayerWidth, LayerHeight: Integer;
      var ChR, ChG, ChB, ChA: TPsdFileChannel): Boolean;
  public
    { Public 宣言 }
    constructor Create();
    destructor Destroy;override;

    // チャンネルごとの画像データをビットマップに変換
    // toLinesが示すScanLineにaWidth aHeightの範囲内描画
    procedure Draw(const toLines : array of Pointer;const aWidth,aHeight,aLeft,aTop : Integer);

    function LoadFromStreamInfo(fs : TFileStreamBuf) : Boolean;
    function LoadFromStream(fs : TFileStreamBuf) : Boolean;

    function ImageToBitmap(aBitmap : TBitmap) : Boolean;
    procedure LoadFromBitmap(fs : TFileStreamBuf);
    // AviUtl出力専用描画。ScaleMode が 1/2/1/4 の場合だけ縮小チャンネルを使う
    procedure DrawAviUtlFilter(DestBuffer: Pointer;const aWidth,aHeight,aLeft,aTop : Integer;
      const ScaleMode: Integer = 0);
    // ANM用の親グループパスを設定し、絶対パスも更新
    procedure SetAnmGroupPath(const AGroup2: string);
    property ChannelCount : Integer read FChannelCount;
    property Channels : TPsdFileChannels read FChannels;
    property TransParent : Integer read FTransParent;
    property Clipping : Integer read FClipping;
    property Flag : Integer read FFlag;
    //property NextPos : Integer read FNextPos;
    property Blends : TPsdFileBlends read FBlends;
    property BlendGlay : TPsdFileBlend read FBlendGlay;
    // ShiftJIS UNICODE存在する名称データを返す
    property Name : string read GetName write SetName;
    property NameShifJis :AnsiString read FNameShifJis write FNameShifJis;
    property NameUnicode :string read FNameUnicode;
    property LayerType : Integer read FLayerType write FLayerType;
    property ProtectFlag : Integer read FProtectFlag;
    property Owner : TObject read FOwner write FOwner;
    property BlendMode : TPsdFileBlandType read FBlendMode;
    property AnmGroup : string read FAnmGroup write FAnmGroup;
    property AnmGroup2 : string read FAnmGroup2 write FAnmGroup2;
    property AnmText  : string read FAnmText write FAnmText;
    property Visible : Boolean read GetVisible;
    property Index : Integer read FIndex write FIndex;
    property Tree    : TObject  read FTree write FTree;
    // 表情ツリー上での表示／非表示を設定　※親ツリーまで影響が及ぶ
    property TreeVisible : Boolean read GetTreeVisible write SetTreeVisible;
  end;

//--------------------------------------------------------------------------//
//  PSDから取り出したレイヤー情報リストを管理するクラス                     //
//--------------------------------------------------------------------------//
type
	TPsdFileLayers = class(TList)
	private
		{ Private 宣言 }
    function GetLayers(Index: Integer): TPsdFileLayer;
	public
		{ Public 宣言 }
    destructor Destroy;override;

    function Add() : TPsdFileLayer;
    procedure Delete(i : Integer);
    procedure Clear();override;

    function IndexOfAnmText(const AnmText : string) : Integer;

		property Layers[Index: Integer] : TPsdFileLayer read GetLayers ;default;

	end;


//--------------------------------------------------------------------------//
//  レイヤー情報リストのポインタだけを管理するクラス                        //
//--------------------------------------------------------------------------//
type
	TPsdFileLayerExs = class(TList)
	private
		{ Private 宣言 }
    function GetLayers(Index: Integer): TPsdFileLayer;
	public
		{ Public 宣言 }

    procedure  Add(d : TPsdFileLayer);

		property Layers[Index: Integer] : TPsdFileLayer read GetLayers ;default;

	end;



implementation

uses PSDImage,PsdImageTree;

{ TPsdFileLayers }

destructor TPsdFileLayers.Destroy;
begin
  Clear();
  inherited;
end;

function TPsdFileLayers.Add: TPsdFileLayer;
var
  d : TPsdFileLayer;
begin
  d := TPsdFileLayer.Create;
  inherited Add(d);
  result := d;
end;

procedure TPsdFileLayers.Clear;
var
  i : Integer;
begin
  for i := 0 to Count-1 do begin
    Layers[i].Free;
  end;
  inherited;
end;

procedure TPsdFileLayers.Delete(i: Integer);
begin
  Layers[i].Free;
  inherited Delete(i);
end;

function TPsdFileLayers.GetLayers(Index: Integer): TPsdFileLayer;
begin
  result := inherited Items[Index];
end;

function TPsdFileLayers.IndexOfAnmText(const AnmText: string): Integer;
var
  i: Integer;
begin
 result := -1;
 for i := 0 to Count-1 do begin
   if Layers[i].FAnmText = AnmText then begin
     result := i;
     exit;
   end;
 end;
end;

{ TPsdFileLayerExs }

procedure TPsdFileLayerExs.Add(d: TPsdFileLayer);
begin
  inherited Add(d);
end;

function TPsdFileLayerExs.GetLayers(Index: Integer): TPsdFileLayer;
begin
  result := inherited Items[Index];
end;

{ TPsdFileLayer }

constructor TPsdFileLayer.Create;
begin
  FPng := TPngImage.Create;
  FChannels := TPsdFileChannels.Create;
  FScaledChannels := TPsdFileChannels.Create;
  FScaledChannelMode := -1;
  FBlends := TPsdFileBlends.Create;
  FBlendGlay := TPsdFileBlend.Create;
end;

destructor TPsdFileLayer.Destroy;
begin
  FBlendGlay.Free;
  FBlends.Free;
  FScaledChannels.Free;
  FChannels.Free;
  FPng.Free;
  inherited;
end;


procedure TPsdFileLayer.InvalidateScaledChannels;
begin
  FScaledChannels.Clear;
  FScaledChannelMode := -1;
end;

function TPsdFileLayer.GetDrawChannels(ScaleMode: Integer): TPsdFileChannels;
begin
  // 等倍ではメモリを増やさず、元チャンネルをそのまま描画に使う
  if ScaleMode <= 0 then
    Exit(FChannels);

  if FScaledChannelMode <> ScaleMode then
  begin
    // 縮小率が変わったときだけ縮小チャンネルを作り直す
    FScaledChannels.AssignScaledFrom(FChannels, ScaleMode);
    FScaledChannelMode := ScaleMode;
  end;

  Result := FScaledChannels;
end;

function TPsdFileLayer.TryGetRGBAChannels(AChannels: TPsdFileChannels;
  const LayerWidth, LayerHeight: Integer;
  var ChR, ChG, ChB, ChA: TPsdFileChannel): Boolean;
var
  ch: Integer;
  dc: TPsdFileChannel;
begin
  ChR := nil;
  ChG := nil;
  ChB := nil;
  ChA := nil;

  if AChannels = nil then Exit(False);

  for ch := 0 to AChannels.Count - 1 do
  begin
    dc := AChannels[ch];
    case dc.ColorType of
      ctR:     ChR := dc;
      ctG:     ChG := dc;
      ctB:     ChB := dc;
      ctAlpha: ChA := dc;
    end;
  end;

  Result := Assigned(ChR) and Assigned(ChG) and Assigned(ChB) and Assigned(ChA);
  if not Result then Exit;

  Result :=
    (ChR.Width >= LayerWidth) and (ChR.Height >= LayerHeight) and
    (ChG.Width >= LayerWidth) and (ChG.Height >= LayerHeight) and
    (ChB.Width >= LayerWidth) and (ChB.Height >= LayerHeight) and
    (ChA.Width >= LayerWidth) and (ChA.Height >= LayerHeight);
end;



procedure TPsdFileLayer.Draw(const toLines : array of Pointer;const aWidth,aHeight,aLeft,aTop : Integer);
var
  ch,y,x,d : Integer;
  dstX: Integer;
  alpha, invA: Integer;
  LayerWidth, LayerHeight: Integer;
  xStart, xEnd, yStart, yEnd: Integer;
  dc : TPsdFileChannel;
  chR, chG, chB, chA: TPsdFileChannel;
  //fromLines : array of Pointer;
  fromCol,toCol,resCol : TFourth;
  dstLine: PFourthArray;
  PSD : TPSDImage;
begin

  PSD := TPSDImage(FOwner);

  if (aWidth <= 0) or (aHeight <= 0) then Exit;

  LayerWidth := FChannels.Width;
  LayerHeight := FChannels.Height;
  if (LayerWidth <= 0) or (LayerHeight <= 0) then Exit;

  xStart := 0;
  if aLeft < 0 then xStart := -aLeft;

  yStart := 0;
  if aTop < 0 then yStart := -aTop;

  xEnd := LayerWidth - 1;
  if aLeft + xEnd >= aWidth then xEnd := aWidth - 1 - aLeft;

  yEnd := LayerHeight - 1;
  if aTop + yEnd >= aHeight then yEnd := aHeight - 1 - aTop;

  if (xStart > xEnd) or (yStart > yEnd) then Exit;

  if (FBlendMode = btNorm) and TryGetRGBAChannels(FChannels, LayerWidth, LayerHeight, chR, chG, chB, chA) then
  begin
    for y := yStart to yEnd do
    begin
      dstLine := PFourthArray(toLines[aTop + y]);
      for x := xStart to xEnd do
      begin
        dstX := aLeft + x;
        alpha := chA.Image[y, x];
        invA := 255 - alpha;

        dstLine^[dstX].R := (chR.Image[y, x] * alpha + dstLine^[dstX].R * invA) div 255;
        dstLine^[dstX].G := (chG.Image[y, x] * alpha + dstLine^[dstX].G * invA) div 255;
        dstLine^[dstX].B := (chB.Image[y, x] * alpha + dstLine^[dstX].B * invA) div 255;
        dstLine^[dstX].A := alpha + (dstLine^[dstX].A * invA) div 255;
      end;
    end;
    Exit;
  end;

  //SetLength(fromLines,FChannels.Height);                   // 高さ分の配列を作成
  for y := yStart to yEnd do begin                         // 高さ分ループ
    dstLine := PFourthArray(toLines[aTop+y]);
    for x := xStart to xEnd do begin                       // 横幅分ループ
      FillChar(fromCol, SizeOf(TFourth), 0);

      for ch := 0 to FChannels.Count-1 do begin            // チャンネル数分ループ
        dc := FChannels[ch];                               // チャンネルクラス参照
        if y > dc.Height-1 then continue;
        if x > dc.Width-1 then continue;

        d := dc.Image[y,x];                               // 画像データを取得
        case dc.ColorType of                              // チャンネルが持つ色指定で分岐
          ctR     : fromCol.R := d;   // R                 // 元のRGB画素データとする
          ctG     : fromCol.G := d;   // G
          ctB     : fromCol.B := d;   // B
          ctAlpha : fromCol.A := d;   // α
        end;
      end;

      toCol.R := dstLine^[aLeft+x].R; // 描画先RGB画素データを取得
      toCol.G := dstLine^[aLeft+x].G;
      toCol.B := dstLine^[aLeft+x].B;
      toCol.A := dstLine^[aLeft+x].A; // αチャンネルは手動処理のためないものとする

      // 関数テーブルから描画処理を呼出実行
      resCol := PSD.BlendModeBMPFuncs[FBlendMode](fromCol, toCol);

      dstLine^[aLeft+x].R := resCol.R;  // 描画先の画素データとして反映
      dstLine^[aLeft+x].G := resCol.G;
      dstLine^[aLeft+x].B := resCol.B;
      dstLine^[aLeft+x].A := resCol.A;

    end;
  end;

end;


procedure TPsdFileLayer.DrawAviUtlFilter(DestBuffer: Pointer; const aWidth,
  aHeight, aLeft, aTop: Integer; const ScaleMode: Integer);
var
  ch, y, x, d,Pitch: Integer;
  dstX: Integer;
  alpha, invA: Integer;
  LayerWidth, LayerHeight: Integer;
  xStart, xEnd, yStart, yEnd: Integer;
  dc: TPsdFileChannel;
  chR, chG, chB, chA: TPsdFileChannel;
  fromCol, toCol, resCol: TFourth;
  dstLine: PFourthArray;
  Offset: NativeUInt;
  PSD : TPSDImage;
  DrawChannels: TPsdFileChannels;
  DrawLeft, DrawTop: Integer;
begin
  if DestBuffer = nil then Exit;
  if (aWidth <= 0) or (aHeight <= 0) then Exit;

  PSD := TPSDImage(FOwner);
  // 通常のDrawではなく、AviUtl出力だけ縮小チャンネルへ差し替える
  DrawChannels := GetDrawChannels(ScaleMode);
  if (DrawChannels = nil) or (DrawChannels.Count = 0) then Exit;

  // 描画座標も縮小後チャンネル側の矩形を使い、出力サイズと揃える
  DrawLeft := DrawChannels[0].Left;
  DrawTop := DrawChannels[0].Top;
  LayerWidth := DrawChannels.Width;
  LayerHeight := DrawChannels.Height;
  if (LayerWidth <= 0) or (LayerHeight <= 0) then Exit;

  xStart := 0;
  if DrawLeft < 0 then
    xStart := -DrawLeft;

  yStart := 0;
  if DrawTop < 0 then
    yStart := -DrawTop;

  xEnd := LayerWidth - 1;
  if DrawLeft + xEnd >= aWidth then
    xEnd := aWidth - 1 - DrawLeft;

  yEnd := LayerHeight - 1;
  if DrawTop + yEnd >= aHeight then
    yEnd := aHeight - 1 - DrawTop;

  if (xStart > xEnd) or (yStart > yEnd) then Exit;

  Pitch := ((aWidth * 32 + 31) div 32) * 4;

  if (FBlendMode = btNorm) and TryGetRGBAChannels(DrawChannels, LayerWidth, LayerHeight, chR, chG, chB, chA) then
  begin
    for y := yStart to yEnd do
    begin
      Offset := NativeUInt(Int64(DrawTop + y) * Pitch);
      dstLine := Pointer(NativeUInt(DestBuffer) + Offset);

      for x := xStart to xEnd do
      begin
        dstX := DrawLeft + x;
        alpha := chA.Image[y, x];
        invA := 255 - alpha;

        dstLine^[dstX].B := (chR.Image[y, x] * alpha + dstLine^[dstX].B * invA) div 255;
        dstLine^[dstX].G := (chG.Image[y, x] * alpha + dstLine^[dstX].G * invA) div 255;
        dstLine^[dstX].R := (chB.Image[y, x] * alpha + dstLine^[dstX].R * invA) div 255;
        dstLine^[dstX].A := alpha + (dstLine^[dstX].A * invA) div 255;
      end;
    end;
    Exit;
  end;

  for y := yStart to yEnd do
  begin
    // AviUtlのフィルターは上下そのまま
    Offset := NativeUInt(Int64(DrawTop + y) * Pitch);
    dstLine := Pointer(NativeUInt(DestBuffer) + Offset);

    for x := xStart to xEnd do
    begin
      // 各チャンネルからfromCol作成
      FillChar(fromCol, SizeOf(TFourth), 0);
      for ch := 0 to DrawChannels.Count - 1 do
      begin
        dc := DrawChannels[ch];
        if (y > dc.Height - 1) or (x > dc.Width - 1) then Break;

        d := dc.Image[y, x];
        case dc.ColorType of
          ctR:     fromCol.R := d;
          ctG:     fromCol.G := d;
          ctB:     fromCol.B := d;
          ctAlpha: fromCol.A := d;
        end;
      end;

      toCol.B := dstLine^[DrawLeft + x].R;
      toCol.G := dstLine^[DrawLeft + x].G;
      toCol.R := dstLine^[DrawLeft + x].B;
      toCol.A := dstLine^[DrawLeft + x].A;

      // 関数テーブルから描画処理を呼出実行
      resCol := PSD.BlendModeFilterFuncs[FBlendMode](fromCol, toCol);

      dstLine^[DrawLeft + x].B := resCol.R;
      dstLine^[DrawLeft + x].G := resCol.G;
      dstLine^[DrawLeft + x].R := resCol.B;
      dstLine^[DrawLeft + x].A := resCol.A;

    end;
  end;
end;



// PSDデータ内の識別文字を描画エフェクタ型に変換
function TPsdFileLayer.GetBlandMode(const str: AnsiString): TPsdFileBlandType;
var
  i : Integer;
begin
  result := btNil;
  for i := 0 to High(BLEND_KEY) do begin
    if BLEND_KEY[i] = str then begin
      result := TPsdFileBlandType(i+1);
      exit;
    end;
  end;
end;

function TPsdFileLayer.GetName: string;
begin
  if FNameUnicode<>'' then begin
    result := FNameUnicode;
  end
  else begin
    result := string(FNameShifJis);
  end;
end;

procedure TPsdFileLayer.SetName(const Value: string);
begin
  FNameUnicode := Value;
end;

procedure TPsdFileLayer.SetAnmGroupPath(const AGroup2: string);
begin
  FAnmGroup2 := AGroup2;
  FAnmText := FAnmGroup2 + Name;
end;


function TPsdFileLayer.GetTreeVisible: Boolean;
var
  ts : TPsdFileTree;
begin
  result := False;
  ts := TPsdFileTree(FTree);
  if ts = nil then exit;

  result := ts.Visible;
end;

procedure TPsdFileLayer.LoadFromBitmap(fs : TFileStreamBuf);
var
  dc : TPsdFileChannel;
  i : Integer;
begin
  if FImageLoaded then exit;                    // データ読み込み済みの場合処理しない

  for i := 0 to Channels.Count-1 do begin       // チャンネル数分ループ　αRGB
    dc := Channels[i];                          // チャンネルデータを参照
    fs.Seek(dc.ImageAdr);
    dc.LoadBitmap(fs);                          // ファイルからチャンネルごとの画像データを作成
  end;
  FImageLoaded := True;
end;

procedure TPsdFileLayer.LoadFromBitmapFile;
var
  dc : TPsdFileChannel;
  i : Integer;
  Filename : string;
  fs : TFileStreamBuf;
  psd : TPSDImage;
begin
  if FImageLoaded then exit;                    // データ読み込み済みの場合処理しない

  psd := TPSDImage(FOwner);
  Filename := psd.FileName;
  if not FileExists(Filename) then Exit;
  fs := TFileStreamBuf.Create(FileName);
  try
    for i := 0 to Channels.Count-1 do begin       // チャンネル数分ループ　αRGB
      dc := Channels[i];                          // チャンネルデータを参照
      fs.Seek(dc.ImageAdr);
      dc.LoadBitmap(fs);                          // ファイルからチャンネルごとの画像データを作成
    end;
  FImageLoaded := True;
  finally
    fs.Free;
  end;
end;

function TPsdFileLayer.LoadFromStream(fs: TFileStreamBuf): Boolean;
var
  sa : AnsiString;
  m : TPsdFileBlandType;
  PosNext : Integer;
begin
  result := False;
  PosNext := fs.Position + 1;             // Nomalタグを読みに行くまで不明のためダミー
  //while fs.Position< FNextPos do begin
  while fs.Position < PosNext do begin
    sa := fs.ReadStr(4);
    if sa <> '8BIM' then begin
      sa := sa;
      exit;
    end;
    sa := fs.ReadStr(4);
    m := GetBlandMode(sa);
    if m <> btNil then begin
      PosNext := LoadFromStreamNorm(fs,m);
    end
    else begin
      if sa= 'luni' then begin
        LoadFromStreamLuni(fs);
      end
      else if sa= 'lsct' then begin
        LoadFromStreamLsct(fs);
      end
      else if sa= 'lspf' then begin
        LoadFromStreamLspf(fs);
      end
      else if sa= 'tsly' then begin
        LoadFromStreamEtc(fs);
      end
      else begin
        LoadFromStreamEtc(fs);
      end;
    end;
  end;
  result := True;
end;

function TPsdFileLayer.LoadFromStreamEtc(fs: TFileStreamBuf): Boolean;
var
  len : Integer;
begin
  len := fs.ReadBin(4);
  fs.ReadDumy(len);
  result := True;
end;

function TPsdFileLayer.LoadFromStreamInfo(fs: TFileStreamBuf): Boolean;
var
  i,aTop,aLeft,ABottom,aRight : Integer;
  dc : TPsdFileChannel;
begin
  aTop   := fs.ReadBin(4);
  aLeft   := fs.ReadBin(4);
  aBottom := fs.ReadBin(4);
  aRight  := fs.ReadBin(4);
  FChannelCount := fs.ReadBin(2);
  FChannels.Clear;
  // レイヤー情報を読み直したら、以前の縮小キャッシュは元データと一致しなくなる
  InvalidateScaledChannels;
  for i := 0 to FChannelCount-1 do begin
    dc := FChannels.Add();
    dc.LoadFromStream(fs);
    dc.Top := aTop;
    dc.Left := aLeft;
    dc.Bottom := ABottom;
    dc.Right := aRight;
  end;
  result := True;
end;

function TPsdFileLayer.LoadFromStreamLsct(fs: TFileStreamBuf): Boolean;
var
  len,i : Integer;
begin
  len := fs.ReadBin(4);
//  fs.ReadDumy(len);

  FLayerType := fs.ReadBin(4);
  for i := 4 to len-1 do begin
    fs.ReadDumy(1);
  end;

  result := True;
end;

function TPsdFileLayer.LoadFromStreamLspf(fs: TFileStreamBuf): Boolean;
var
  len : Integer;
begin
  len := fs.ReadBin(4);
  fs.ReadDumy(len);
  result := True;
end;

function TPsdFileLayer.LoadFromStreamLuni(fs: TFileStreamBuf): Boolean;
begin
  FNameUnicode := fs.ReadStrUnicodeSizeLenData();
  result := True;
end;

function TPsdFileLayer.LoadFromStreamNorm(fs: TFileStreamBuf;mode : TPsdFileBlandType): Integer;
var
  size : Integer;
  i: Integer;
  db : TPsdFileBlend;
  dc : TPsdFileChannel;
begin
  FBlendMode   := mode;
  FTransParent := fs.ReadBin(1);
  FClipping    := fs.ReadBin(1);
  FFlag        := fs.ReadBin(1);
  fs.ReadDumy(1);
  size         := fs.ReadBin(4);
  Result       := fs.Position + size;
  //FNextPos := fs.Position + size;
  size := fs.ReadBin(4);
  if size >0 then begin                    // レイヤーマスクデータが存在する場合
    dc := FChannels[4];                    // マスク？ RGBの次のチャンネルに割り当てる
    dc.Top          := fs.ReadBin(4);     // Modeが-2 または -3であることを確かめた方が良い
    dc.Left         := fs.ReadBin(4);
    dc.Bottom       := fs.ReadBin(4);
    dc.Right        := fs.ReadBin(4);
    dc.DefaultColor := fs.ReadBin(1);
    dc.Flag         := fs.ReadBin(1);
    dc.Mask         := fs.ReadBin(1);
    if size=20 then begin                  // 長さ20バイトのデータの場合
      fs.ReadDumy(1);                      // 2の倍数にするための予備データを読み飛ばす
    end
    else begin                             // 20以上の場合はさらにデータが存在する
      dc.Flag2      := fs.ReadBin(1);
      dc.Mask2      := fs.ReadBin(1);
      dc.RectTop    := fs.ReadBin(4);
      dc.RectLeft   := fs.ReadBin(4);
      dc.RectTop    := fs.ReadBin(4);
      dc.RectBottom := fs.ReadBin(4);
    end;

  end;
  size := fs.ReadBin(4);
  FBlends.Clear;
  for i := 0 to size div 8-1 do begin
    if i = 0 then begin
      FBlendGlay.LoadFromStream(fs);
    end
    else begin
      db := FBlends.Add();
      db.LoadFromStream(fs);
    end;
  end;
  size := fs.ReadBin(1);
  FNameShifJis := fs.ReadStrPascal(size);
end;

procedure TPsdFileLayer.SetTreeVisible(const Value: Boolean);
var
  ts : TPsdFileTree;
begin
  ts := TPsdFileTree(FTree);
  ts.SetLayerVisible(True,Value);
  //ts.Visible := Value;
end;

function TPsdFileLayer.GetVisible: Boolean;
begin
  result := (FFlag and $02) <> $02;
end;

function TPsdFileLayer.ImageToBitmap(aBitmap: TBitmap): Boolean;
var
  y,aWidth,aHeight : Integer;
  sLines : array of Pointer;
  cv : TCanvas;
begin
  result := False;
  if ChannelCount=0 then exit;

  if FChannels.Count=5 then begin
    exit;
  end;
  LoadFromBitmapFile();
  aWidth := FChannels.Width;
  aHeight := FChannels.Height;

  aBitmap.SetSize(aWidth,aHeight);
  aBitmap.PixelFormat := pf32bit;
  cv := aBitmap.Canvas;
  cv.Brush.Color := TPSDImage(FOwner).Color;
  cv.Brush.Style := bsSolid;
  cv.FillRect(Rect(0,0,aBitmap.Width,aBitmap.Height));

  SetLength(sLines,aHeight);
  for y := 0 to FChannels.Height-1 do begin
    sLines[y] := aBitmap.ScanLine[y];
  end;

  if FChannels.Height=0 then exit;

  Draw(sLines,aWidth,aHeight,0,0);

  Result := True;
end;


end.
