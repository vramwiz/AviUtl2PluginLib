unit PsdImageChannel;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,PsdImageDefine,
  PsdImageFileStreamBuf,PsdImageBlend;

type
  TPsdFileChannelImage = array of array of Byte;

  TPsdFileChannel = class(TPersistent)
  private
    { Private 宣言 }
    FImageLength  : Integer;       // チャンネルに該当する画像データサイズ
    FTop          : Integer;       // レイヤーマスクを囲む長方形：上、左、下、右
    FLeft         : Integer;
    FRight        : Integer;
    FBottom       : Integer;
    FDefaultColor : Integer;       // デフォルトの色。0または255
    FRectTop      : Integer;       //
    FRectLeft     : Integer;
    FFlag         : Integer;       // ビットごとに意味があるフラグ 0=相対位置
    FFlag2        : Integer;       // 上記と同じ内容が入ると思われる
    FMask         : Integer;       // マスク フラグのビット4が設定されている場合にのみ
    FMask2        : Integer;
    FRectRight    : Integer;
    FRectBottom   : Integer;
    FMode         : Integer;       // 0:R 1:G 2:B FFFF:αチャンネル FFFE:マスク？
    FImageAdr     : Integer;       // 画像格納アドレス Dataには画像データ長が入っている
    FImage        : TPsdFileChannelImage;
    FColorType: TPsdFileColorType; // y * x のサイズを持つ画像データ管理 8bit専用


    // 非圧縮データを展開
    function LoadBitmapCompressionNon(fs : TFileStreamBuf) : Boolean;
    // RLE圧縮データを展開
    function LoadBitmapCompressionRle(fs : TFileStreamBuf) : Boolean;


    function GetHeight: Integer;
    function GetWidth: Integer;
    function GetColorType: TPsdFileColorType;
  public
    { Public 宣言 }
    function LoadFromStream(fs : TFileStreamBuf) : Boolean;
    function LoadBitmap(fs : TFileStreamBuf) : Boolean;
    // AviUtl出力縮小用：元チャンネル画像を指定倍率で縮小して、このチャンネルへ複製する
    procedure AssignScaledFrom(Source: TPsdFileChannel; ScaleMode: Integer);

    property Left   : Integer read FLeft write FLeft;
    property Top    : Integer read FTop write FTop;
    property Right  : Integer read FRight write FRight;
    property Bottom : Integer read FBottom write FBottom;
    property Height : Integer read GetHeight;
    property Width  : Integer read GetWidth;

    property DefaultColor : Integer read FDefaultColor write FDefaultColor;
    property Flag         : Integer read FFlag write FFlag;
    property Flag2        : Integer read FFlag2 write FFlag2;
    property Mask         : Integer read FMask write FMask;
    property Mask2        : Integer read FMask2 write FMask2;
    property RectLeft     : Integer read FRectLeft write FRectLeft;
    property RectTop      : Integer read FRectTop write FRectTop;
    property RectRight    : Integer read FRectRight write FRectRight;
    property RectBottom   : Integer read FRectBottom write FRectBottom;

    property Image : TPsdFileChannelImage read FImage;

    property ImageAdr : Integer read FImageAdr write FImageAdr;
    property ImageLength   : Integer read FImageLength;
    property Mode : Integer read FMode;
    property ColorType : TPsdFileColorType read FColorType;
  end;


type
	TPsdFileChannels = class(TList)
	private
		{ Private 宣言 }
    function GetItems(Index: Integer): TPsdFileChannel;
    function GetHeight: Integer;
    function GetWidth: Integer;
	public
		{ Public 宣言 }
    destructor Destroy;override;
    function Add() : TPsdFileChannel;
    procedure Delete(i : Integer);
    procedure Clear();override;
    // AviUtl出力縮小用：チャンネル集合全体を縮小後データとして作り直す
    procedure AssignScaledFrom(Source: TPsdFileChannels; ScaleMode: Integer);

    function IndexOfColorType(const ct : TPsdFileColorType) : Integer;

		property Channels[Index: Integer] : TPsdFileChannel read GetItems ;default;

    property Height : Integer read GetHeight;
    property Width  : Integer read GetWidth;
	end;

implementation

{ TPsdFileChannels }

destructor TPsdFileChannels.Destroy;
begin
  Clear();
  inherited;
end;

function TPsdFileChannels.Add: TPsdFileChannel;
var
  d : TPsdFileChannel;
begin
  d := TPsdFileChannel.Create;
  inherited Add(d);
  result := d;
end;

procedure TPsdFileChannels.AssignScaledFrom(Source: TPsdFileChannels;
  ScaleMode: Integer);
var
  i: Integer;
  d: TPsdFileChannel;
begin
  // 縮小チャンネルはキャッシュ用途なので、必要になるたび現在の元チャンネルから再生成する
  Clear;
  if Source = nil then Exit;

  for i := 0 to Source.Count - 1 do
  begin
    d := Add;
    d.AssignScaledFrom(Source[i], ScaleMode);
  end;
end;

procedure TPsdFileChannels.Clear;
var
  i : Integer;
begin
  for i := 0 to Count-1 do begin
    Channels[i].Free;
  end;
  inherited;
end;

procedure TPsdFileChannels.Delete(i: Integer);
begin
  Channels[i].Free;
  inherited Delete(i);
end;

function TPsdFileChannels.GetItems(Index: Integer): TPsdFileChannel;
begin
  result := inherited Items[Index];
end;

function TPsdFileChannels.GetHeight: Integer;
var
  i,d : Integer;
  dc : TPsdFileChannel;
begin
  d := 0;
  for i := 0 to Count-1 do begin
    dc := Items[i];
    if dc.FMode >= 3 then continue;
    if dc.Height > d then d := dc.Height;
  end;
  result := d;
end;

function TPsdFileChannels.GetWidth: Integer;
var
  i,d : Integer;
  dc : TPsdFileChannel;
begin
  d := 0;
  for i := 0 to Count-1 do begin
    dc := Items[i];
    if dc = nil then continue;
    if dc.FMode >= 3 then continue;
    if dc.Width > d then d := dc.Width;
  end;
  result := d;
end;

function TPsdFileChannels.IndexOfColorType(const ct: TPsdFileColorType): Integer;
var
  i : Integer;
begin
  result := -1;
  for i := 0 to Count-1 do begin
    if Channels[i].FColorType = ct then begin
      result := i;
      exit;
    end;
  end;
end;

{ TPsdFileChannel }

function PsdScaleDivisor(ScaleMode: Integer): Integer;
begin
  // ScaleMode は 0=等倍、1=1/2、2=1/4 に丸める
  if ScaleMode < 0 then
    ScaleMode := 0
  else if ScaleMode > 2 then
    ScaleMode := 2;

  Result := 1 shl ScaleMode;
end;

function PsdScaleCeil(Value, Divisor: Integer): Integer;
begin
  // 端の1ピクセルを落とさないよう、縮小後サイズは切り上げで計算する
  if Value <= 0 then
    Result := 0
  else
    Result := (Value + Divisor - 1) div Divisor;
end;

procedure TPsdFileChannel.AssignScaledFrom(Source: TPsdFileChannel;
  ScaleMode: Integer);
var
  Divisor: Integer;
  SrcX, SrcY, EndX, EndY: Integer;
  DstX, DstY: Integer;
  X, Y: Integer;
  Sum, Count: Integer;
  DstWidth, DstHeight: Integer;
begin
  if Source = nil then Exit;

  Divisor := PsdScaleDivisor(ScaleMode);

  // チャンネルIDやマスク属性は元データを引き継ぎ、画像本体と矩形だけ縮小する
  FImageLength  := 0;
  FDefaultColor := Source.FDefaultColor;
  FFlag         := Source.FFlag;
  FFlag2        := Source.FFlag2;
  FMask         := Source.FMask;
  FMask2        := Source.FMask2;
  FMode         := Source.FMode;
  FImageAdr     := Source.FImageAdr;
  FColorType    := Source.FColorType;

  DstWidth  := PsdScaleCeil(Source.Width, Divisor);
  DstHeight := PsdScaleCeil(Source.Height, Divisor);

  FLeft   := Source.FLeft div Divisor;
  FTop    := Source.FTop div Divisor;
  FRight  := FLeft + DstWidth;
  FBottom := FTop + DstHeight;

  FRectLeft   := Source.FRectLeft div Divisor;
  FRectTop    := Source.FRectTop div Divisor;
  FRectRight  := PsdScaleCeil(Source.FRectRight, Divisor);
  FRectBottom := PsdScaleCeil(Source.FRectBottom, Divisor);

  SetLength(FImage, DstHeight, DstWidth);
  if (DstWidth <= 0) or (DstHeight <= 0) then Exit;

  if Divisor = 1 then
  begin
    // 等倍指定では同じ画像をコピーする。通常描画経路ではこの処理を通らず元チャンネルを直接参照する
    for DstY := 0 to DstHeight - 1 do
      for DstX := 0 to DstWidth - 1 do
        FImage[DstY, DstX] := Source.FImage[DstY, DstX];
    Exit;
  end;

  for DstY := 0 to DstHeight - 1 do
  begin
    // 1/2・1/4 は単純平均で縮小する。透明境界の高品質化が必要ならここを差し替える
    SrcY := DstY * Divisor;
    EndY := SrcY + Divisor - 1;
    if EndY >= Source.Height then
      EndY := Source.Height - 1;

    for DstX := 0 to DstWidth - 1 do
    begin
      SrcX := DstX * Divisor;
      EndX := SrcX + Divisor - 1;
      if EndX >= Source.Width then
        EndX := Source.Width - 1;

      Sum := 0;
      Count := 0;
      for Y := SrcY to EndY do
        for X := SrcX to EndX do
        begin
          Inc(Sum, Source.FImage[Y, X]);
          Inc(Count);
        end;

      if Count > 0 then
        FImage[DstY, DstX] := (Sum + (Count div 2)) div Count;
    end;
  end;
end;


function TPsdFileChannel.GetColorType: TPsdFileColorType;
begin
  result := ctNil;
  case FMode of                   // チャンネルが持つ色指定で分岐
    0     : result := ctR;        // 赤
    1     : result := ctG;        // 緑
    2     : result := ctB;        // 青
    $FFFF : result := ctAlpha;    // 透明度
    $FFFE : result := ctMask;     // マスク
  end;
end;

function TPsdFileChannel.GetHeight: Integer;
begin
  result := FBottom - FTop;
end;

function TPsdFileChannel.GetWidth: Integer;
begin
  result := FRight - FLeft;
end;

function TPsdFileChannel.LoadBitmap(fs: TFileStreamBuf): Boolean;
var
  mode : Integer;

begin

  SetLength(FImage,Height,Width);
  mode := fs.ReadBin(2);
  case mode of
    0: LoadBitmapCompressionNon(fs);
    1: LoadBitmapCompressionRle(fs);
  end;

  result := True;
end;

function TPsdFileChannel.LoadBitmapCompressionNon(fs: TFileStreamBuf): Boolean;
var
  y,x,d : Integer;
begin
  for y := 0 to Height-1 do begin        // 高さ分ループ
    for x := 0 to Width-1 do begin       // 幅分ループ
      d := fs.ReadBin(1);
      FImage[y,x] := d;
    end;
  end;
  result := True;
end;

function TPsdFileChannel.LoadBitmapCompressionRle(fs: TFileStreamBuf): Boolean;
var
  rLen :  array of Integer;
  y,x,len,i,NextPos : Integer;
  d : Byte;
begin
  SetLength(rLen,Height);                       // 高さ×チャンネル数の配列を準備
  for y := 0 to Height-1 do begin               // 各Ｙ座標ごとに読み込むバイト数を取得
    rLen[y] :=  fs.ReadBin(2);
  end;

  for y := 0 to Height-1 do begin              // 高さ分ループ
    NextPos := fs.Position + rLen[y];         // 読み込み完了位置を取得
    x := 0;
    while fs.Position <  NextPos do begin     // 横幅分データが揃うまでループ
      len := fs.ReadBin(1);                   // データを取得

      if len < 128 then begin                  // 最上位ビットが0の場合
        Inc(len);                              // 1増やす
        for i := 0 to len-1 do begin           // 取得した値をデータ長としてループ
          d := fs.ReadBin(1);                 // データを取得
          if x >= Width then continue;         // X座標が範囲を超える場合は未処理
          FImage[y,x] := d;                    // 値を書き込む
          x := x +1;                           // 次の座標へ
        end;
      end
      else if len >128 then begin              // 最上位ビットが1の場合
        len := len xor $ff;                    // 2の補数とする
        len := len +2;
        d := fs.ReadBin(1);                   // データを取得
        for i := 0 to len-1 do begin           // 2の補数にした長さデータ分ループ
          if x >= Width then continue;         // X座標が範囲を超える場合は未処理
          FImage[y,x] := d;                    // 値を書き込む
          x := x +1;                           // 次の座標へ
        end;
      end;
    end;
  end;
  result := True;
end;

function TPsdFileChannel.LoadFromStream(fs: TFileStreamBuf): Boolean;
begin
  FMode        := fs.ReadBin(2);
  FImageLength := fs.ReadBin(4);
  FColorType   := GetColorType();
  result := True;
end;


end.
