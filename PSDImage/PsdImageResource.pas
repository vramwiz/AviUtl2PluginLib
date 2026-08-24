unit PsdImageResource;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,
  PsdImageFileStreamBuf,PsdImageThumbnail;

// リソースデータ管理クラス
type
  TPsdFileResource = class(TPersistent)
  private
    { Private 宣言 }
    FThumbnail: TPsdFileResourceThumbnail;
    FSize: Integer;
  public
    { Public 宣言 }
    constructor Create();
    destructor Destroy;override;
    function LoadFromFile(fs : TFileStreamBuf) : Boolean;

    property Thumbnail : TPsdFileResourceThumbnail read FThumbnail;
    property Size : Integer read FSize;
  end;

implementation

{ TPsdFileResource }

constructor TPsdFileResource.Create;
begin
  FThumbnail := TPsdFileResourceThumbnail.Create;
end;

destructor TPsdFileResource.Destroy;
begin
  FThumbnail.Free;
  inherited;
end;

function TPsdFileResource.LoadFromFile(fs: TFileStreamBuf): Boolean;
var
  size,size2 : Integer;
  s: string;
  sa : AnsiString;
  mode,len : Integer;
begin
  FSize :=  fs.ReadBin(4);                // リソース全体のサイズを取得
  size := fs.Position + FSize;
  while fs.Position < size do begin       // キャッシュサイズまで読み込み処理を行う
    sa := fs.ReadStr(4);                  // シグネチャ 8BIMを取得
    if sa <> '8BIM' then break;           // 解析エラーとして処理終了
    mode := fs.ReadBin(2);                // リソースの種類を取得
    s := IntToHex(mode,4);                // デバッグ用
    len := fs.ReadBin(1);                 // リソースを識別する文字列の長さを取得
    sa := fs.ReadStrPascal2(len);         // リソースを識別する文字列を取得
    case mode of
      $040C : FThumbnail.LoadFromFile(fs); // サムネイルデータの場合サムネイル情報として読み込む
    else
      begin
        size2 := fs.ReadBin(4);           // リソースのデータサイズを取得
        size2 := (size2+1) div 2 * 2;     // リソースデータは2の倍数サイズなので丸める
        fs.ReadDumy(size2);               // リソースサイズ分データを読み飛ばす
      end;
    end;
  end;

  result := True;
end;

end.
