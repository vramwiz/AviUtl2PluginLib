unit ImageLoader;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,RTTIPersistent;


type
	TImageLoader = class(TPersistent)
	private
		{ Private 宣言 }

    function LoadToBitmapBmp(const FileName: string;DestBitmap: TBitmap): Boolean;
    function LoadToBitmapEtc(const FileName: string;DestBitmap: TBitmap): Boolean;
    function LoadToBitmapGif(const FileName: string;DestBitmap: TBitmap): Boolean;
    function LoadToBitmapJpg(const FileName: string;DestBitmap: TBitmap): Boolean;
    function LoadToBitmapPng(const FileName: string;DestBitmap: TBitmap): Boolean;

  protected
	public
		{ Public 宣言 }
    // 指定された画像ファイルを読み込みDestBitmapのサイズに合わせて描画
    function LoadToBitmap(const FileName: string;DestBitmap: TBitmap): Boolean;
	end;


implementation


uses Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, Vcl.Imaging.gifimg,CommCtrl,
     ShellApi,ShlObj,System.IOUtils,FileInfoList, System.Math;


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


{ TImageLoader }


//-----------------------------------------------------------------------------
//  SHGetImageList関数を使用してシステムのイメージリストを取得
//  取得するアイコンのサイズを引数で指定する
//  定数名はShellAPI.pasに定義されている
//
//  Delphi XEにはSHGetImageList関数が実装されているが，32ビットのEXEを64ビット
//  Windowsで実行すると，「特権命令」違反が発生する
//  本コードのようにLoadLivraryでDLLをロードし関数のアドレスを取得して実行する
//  と例外が発生しない
//  64ビットのEXEで実行すれば「特恵命令」は発生しない
//-----------------------------------------------------------------------------
function GetSystemImageList(ASHILValue: Cardinal): HIMAGELIST;
type
  TSHGetImageList = function(iImageList: integer;
                             const riid: TGUID;
                             var ppv: Pointer): HRESULT; stdcall;
const
  IID_IImageList: TGUID= '{46EB5926-582E-4017-9FDF-E8998DAA0950}';
var
  LDllHandle      : THandle;
  LSHGetImageList : TSHGetImageList;
begin
  Result := 0;

  LDllHandle := LoadLibrary('Shell32.dll');
  if LDllHandle <> 0 then begin
    try
      LSHGetImageList := GetProcAddress(LDllHandle, 'SHGetImageList');
      if @LSHGetImageList <> nil then begin
        LSHGetImageList(ASHILValue, IID_IImageList, Pointer(Result));
      end;
    finally
      FreeLibrary(LDllHandle);
    end;
  end;
end;

// アイコンデータをビットマップに変換。
procedure IconToBmp(bmp: TBitmap; icon: TIcon;aWidth,aHeight : Integer);
var
  bmp2 : TBitmap;
  r : TRect;
  x,y : Integer;
begin
  bmp2 := TBitmap.Create;
  r :=Rect(0,0,aWidth,aHeight);
  x := icon.Width;
  y := icon.Height;
  try
    icon.AssignTo(bmp);
    if bmp.TransparentColor <> $02000000 then begin

      //bmp2.Transparent := icon.Transparent;
      bmp2.SetSize(icon.Width, icon.Height);
      bmp2.Canvas.StretchDraw(Rect(0,0,aWidth,aHeight), icon);
      //bmp.Assign(bmp2);
      bmp.SetSize(aWidth,aHeight);
      bmp.Canvas.StretchDraw(Rect(0,0,aWidth,aHeight), bmp2);
    end
    else begin
      bmp2.Assign(bmp);
      bmp.SetSize(aWidth,aHeight);
      bmp.Canvas.Brush.Color := clWhite;
      bmp.Canvas.Brush.Style := bsSolid;
      bmp.Canvas.FillRect(bmp.Canvas.ClipRect);
      //bmp.Canvas.StretchDraw(Rect(0,0,aWidth,aHeight), bmp2);
      RectToStreachRect(r,x,y);
      bmp.Canvas.StretchDraw(r, bmp2);
    end;
    bmp.TransparentColor := clBlack;
    bmp.Transparent := True;
  finally
    bmp2.Free;
  end;
end;


function TImageLoader.LoadToBitmap(const FileName: string; DestBitmap: TBitmap): Boolean;
var
  Ext: string;
  bmp : TBitmap;
  r :TRect;
begin
  Ext := LowerCase(ExtractFileExt(FileName));

  bmp := TBitmap.Create;
  try
    try
      if Ext = '.png' then       Result := LoadToBitmapPng(FileName,bmp)
      else if Ext = '.jpeg' then Result := LoadToBitmapJpg(FileName,bmp)
      else if Ext = '.jpg' then  Result := LoadToBitmapJpg(FileName,bmp)
      else if Ext = '.gif' then  Result := LoadToBitmapGif(FileName,bmp)
      else if Ext = '.bmp' then  Result := LoadToBitmapBmp(FileName,bmp)
      else                       Result := LoadToBitmapEtc(FileName,bmp);
    except
      Result := False;
    end;

    if not Result then
      Exit;

    r := Rect(0,0,DestBitmap.Width,DestBitmap.Height);
    RectToStreachRect(r,bmp.Width,bmp.Height);
    DestBitmap.Canvas.StretchDraw(r, bmp);
  finally
    bmp.Free;
  end;
end;

function TImageLoader.LoadToBitmapBmp(const FileName: string;DestBitmap: TBitmap): Boolean;
var
  Bmp: TBitmap;
  Stream: TFileStream;
begin
  Bmp := TBitmap.Create;
  Stream := nil;
  try
    try
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      Bmp.LoadFromStream(Stream);
      DestBitmap.Assign(Bmp);
      Result := True;
    except
      Result := False;
    end;
  finally
    Stream.Free;
    Bmp.Free;
  end;
end;

function TImageLoader.LoadToBitmapEtc(const FileName: string;DestBitmap: TBitmap): Boolean;
var
  LSHFileInfo : TSHFileInfo;
  LIcon       : TIcon;
  i : Integer;
  list    : HIMAGELIST;
begin
  LIcon := TIcon.Create;
  try
    try
      if ExtractFileName(FileName) = '..' then begin
        SHGetFileInfo(PChar(FileName),
          FILE_ATTRIBUTE_DIRECTORY,
          LSHFileInfo,
          SizeOf(LSHFileInfo),
          SHGFI_ICON or SHGFI_SMALLICON or SHGFI_USEFILEATTRIBUTES
        );
      end
      else begin
        SHGetFileInfo(PChar(FileName),
          0,
          LSHFileInfo,
          SizeOf(LSHFileInfo),
          SHGFI_ICON or SHGFI_SMALLICON or SHGFI_SHELLICONSIZE);
      end;
      i := LSHFileInfo.iIcon;
      if i = -1 then i := 0;
      list := GetSystemImageList(SHIL_JUMBO);
      LIcon.Handle := ImageList_GetIcon(list, i, ILD_NORMAL);
      IconToBmp(DestBitmap,LIcon,DestBitmap.Width,DestBitmap.Height);
      Result := True;
    except
      Result := False;
    end;
  finally
    FreeAndNil(LIcon);
  end;
end;

function TImageLoader.LoadToBitmapGif(const FileName: string;DestBitmap: TBitmap): Boolean;
var
  Gif: TGIFImage;
  Stream: TFileStream;
begin
  Gif := TGIFImage.Create;
  Stream := nil;
  try
    try
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      Gif.LoadFromStream(Stream);
      DestBitmap.Assign(Gif);
      Result := True;
    except
      Result := False;
    end;
  finally
    Stream.Free;
    Gif.Free;
  end;
end;

function TImageLoader.LoadToBitmapJpg(const FileName: string; DestBitmap: TBitmap): Boolean;
var
  Jpeg: TJPEGImage;
  Stream: TFileStream;
begin
  Jpeg := TJPEGImage.Create;
  Stream := nil;
  try
    try
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      Jpeg.LoadFromStream(Stream);
      DestBitmap.Assign(Jpeg);
      Result := True;
    except
      Result := False;
    end;
  finally
    Stream.Free;
    Jpeg.Free;
  end;
end;

function TImageLoader.LoadToBitmapPng(const FileName: string;
  DestBitmap: TBitmap): Boolean;
var
  Png: TPngImage;
  Stream: TFileStream;
begin
  Result := False;
  if not FileExists(FileName) then Exit;

  Png := TPngImage.Create;
  Stream := nil;
  try
    try
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      Png.LoadFromStream(Stream);
      DestBitmap.Assign(Png);
      Result := True;
    except
      Result := False;
    end;
  finally
    Stream.Free;
    Png.Free;
  end;
end;

end.
