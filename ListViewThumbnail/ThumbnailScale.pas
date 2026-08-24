// サムネイル付きデータを管理するクラス
// サムネイルを表示させたいデータはこのクラスから継承させる

unit ThumbnailScale;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  Vcl.Menus,System.Generics.Collections,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ImgList,RTTIPersistentIni,PSDImageAviUtl2;

type
  ThumbnailScaleItem = class(TRTTIPersistentIni)
  private
    FFileName    : string;          // PSDファイル名
    FName           : string;       // 表示する名称
    FThumbnailScale : Integer;      // サムネイル表示拡大率
    FThumbnailX     : Integer;      // サムネイル表示X座標
    FThumbnailY     : Integer;      // サムネイル表示Y座標
    FIsCustomName   : Boolean;      // True:手動で名称を設定
  protected
  public
  published
    property FileName :string read FFileName write FFileName;
    property Name :string read FName write FName;
    property IsCustomName : Boolean read FIsCustomName write FIsCustomName;
    // 表情表示の座標と範囲
    property ThumbnailX : Integer read FThumbnailX write FThumbnailX;
    property ThumbnailY : Integer read FThumbnailY write FThumbnailY;
    property ThumbnailScale : Integer read FThumbnailScale write FThumbnailScale;
  end;

implementation

uses SectionFileManager;

{ ThumbnailScaleItem }

// アスペクトル比を合わせた範囲を取得 r : 変形先としての範囲 aWidth,aHeight:元画像ファイル
procedure RectToStreachRect(var r : TRect;const aWidth,aHeight : Integer);
var
  xh,yh,xhr,yhr : Integer;
begin
  //if aWidth = aHeight then exit;
  if aWidth = 0 then exit;
  if aHeight = 0 then exit;

  xhr := r.Width;
  yhr := r.Height;
  if aWidth > aHeight then begin
    yh := r.Width * aHeight div aWidth;
    r.Top := (yhr - yh) div 2;
    r.Height := yh;
  end
  else begin
    xh := r.Height * aWidth div aHeight;
    r.Left := (xhr - xh) div 2;
    r.Width := xh;
  end;
end;


end.
