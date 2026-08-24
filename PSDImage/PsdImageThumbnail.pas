unit PsdImageThumbnail;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,PsdImageDefine,PsdImageFileStreamBuf;

//--------------------------------------------------------------------------//
//  リソースデータのサムネイル管理クラス                                    //
//--------------------------------------------------------------------------//
type
  TPsdFileResourceThumbnail = class(TPersistent)
  private
    { Private 宣言 }
    FImageFormat : Integer;   // フォーマット。1=kJpegRGB。kRawRGB（0）もサポートします。
    FWidth       : Integer;
    FHeight      : Integer;
    FWidthbytes  : Integer;   // パディングされた行のバイト=（幅*ピクセルあたりのビット数+ 31）/ 32*4。
    FWidthHeight : Integer;   //合計サイズ=widthbytes*高さ*平面
    FDataLength  : Integer;   // データ長（圧縮後）
    FPixcelBit   : Integer;
    FPlaneCount  : Integer;
    FBitmap      : TBitmap;
    // 画像データを読み込み
    function LoadFromFileData(fs : TFileStreamBuf) : Boolean;
    // Jpegデータを読み込み
    function LoadFromFileDataJpeg(fs : TFileStreamBuf) : Boolean;
  public
    { Public 宣言 }
    constructor Create();
    destructor Destroy;override;
    function LoadFromFile(fs : TFileStreamBuf) : Boolean;

    property Bitmap : TBitmap read FBitmap;
    property ImageFormat : Integer read FImageFormat;
    property Height : Integer read FHeight;
    property Width  : Integer read FWidth;
    property Widthbytes : Integer read FWidthbytes;
    property WidthHeight : Integer read FWidthHeight;
    property DataLength : Integer read FDataLength;
    property PixcelBit : Integer read FPixcelBit;
    property PlaneCount : Integer read FPlaneCount;
  end;



implementation

{ TPsdFileResourceThumbnail }

constructor TPsdFileResourceThumbnail.Create;
begin
  FBitmap := TBitmap.Create;
end;

destructor TPsdFileResourceThumbnail.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

function TPsdFileResourceThumbnail.LoadFromFile(fs: TFileStreamBuf): Boolean;
var
  size,bufpos,phase : Integer;
begin
  size :=  fs.ReadBin(4);                     // リソース全体のサイズを取得
  size := (size+1) div 2 * 2;                 // もしかしたら必要／不要かも
  bufpos := fs.Position + size;                 // 最終データ位置を取得
  phase := 0;                                 // 処理経過状態を初期化
  while fs.Position < bufpos do begin           // 最終データまで読み込み処理を行う
    case phase of                             // 処理経過順序で分岐
      0 : FImageFormat := fs.ReadBin(4);
      1 : FWidth       := fs.ReadBin(4);
      2 : FHeight      := fs.ReadBin(4);
      3 : FWidthbytes  := fs.ReadBin(4);
      4 : FWidthHeight := fs.ReadBin(4);
      5 : FDataLength  := fs.ReadBin(4);
      6 : FPixcelBit   := fs.ReadBin(2);
      7 : FPlaneCount  := fs.ReadBin(2);
      8 : LoadFromFileData(fs);               // 画像データを読み込み
      else fs.ReadDumy(1);                    // あまりデータを処理
    end;
    inc(phase);
  end;
  result := True;
end;

function TPsdFileResourceThumbnail.LoadFromFileData(fs: TFileStreamBuf): Boolean;
begin
  FBitmap.SetSize(FWidth,FHeight);         // ビットマップサイズを設定
  FBitmap.PixelFormat := pf32bit;
  case FImageFormat of                     // データの種類で分岐
    1 : LoadFromFileDataJpeg(fs);          // Jpegデータの場合
  end;
  result := True;
end;

function TPsdFileResourceThumbnail.LoadFromFileDataJpeg(fs: TFileStreamBuf): Boolean;
var
  jpeg : TJPEGImage;
  ms : TMemoryStream;
  i: Integer;
  d : Byte;
begin
  jpeg := TJPEGImage.Create;
  ms := TMemoryStream.Create;
  try
    ms.Position := 0;                      // ストリームの先頭へ
    for i := 0 to DataLength-1 do begin    // データ長分ループ
      d := fs.ReadBin(1);                  // キャッシュから読み込み
      ms.WriteData(d);                     // ストリームへ書きだし
    end;
    ms.Position := 0;                      // ストリームの先頭へ
    jpeg.LoadFromStream(ms);               // Jpegデータとして読み込む
    FBitmap.Assign(jpeg);                  // ビットマップ変換
  finally
    ms.Free;
    jpeg.Free;
  end;
  result := True;
end;



end.
