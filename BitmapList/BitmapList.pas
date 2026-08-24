unit BitmapList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  ListViewEdit,ListViewEx,System.Generics.Collections,
  Vcl.StdCtrls,System.SyncObjs,PsdImageAviUtl2,PNGImage;

type
  TBitmapList = class
  private
    FBitmaps: TList<TBitmap>;
    FPNGs: TList<TPngImage>;
    FPSDs: TList<TPSDImageAviUtl2>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Add(ABitmap: TBitmap);
    function Count: Integer;
    function Bitmaps(Index: Integer): TBitmap;
    function PNGs(Index: Integer): TPngImage;
    function PSDg(Index : Integer) :TPSDImageAviUtl2;


    procedure Clear;
  end;


implementation

constructor TBitmapList.Create;
begin
  FBitmaps := TList<TBitmap>.Create;
  FPNGs := TList<TPngImage>.Create;
  FPSDs := TList<TPSDImageAviUtl2>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TBitmapList.Destroy;
begin
  Clear;
  FLock.Free;
  FPSDs.Free;
  FPNGs.Free;
  FBitmaps.Free;
  inherited;
end;

procedure TBitmapList.Add(ABitmap: TBitmap);
var
  APng : TPngImage;
  APsd : TPSDImageAviUtl2;
begin
  FLock.Acquire;
  try
    FBitmaps.Add(ABitmap);
    APng := TPngImage.Create;
    FPNGs.Add(APng);
    APsd := TPSDImageAviUtl2.Create;
    FPSDs.Add(APsd);
  finally
    FLock.Release;
  end;
end;

function TBitmapList.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FBitmaps.Count;
  finally
    FLock.Release;
  end;
end;

function TBitmapList.Bitmaps(Index: Integer): TBitmap;
begin
  FLock.Acquire;
  try
    Result := FBitmaps[Index];
  finally
    FLock.Release;
  end;
end;

function TBitmapList.PNGs(Index: Integer): TPngImage;
begin
  //FLock.Acquire;
  try
    Result := FPNGs[Index];
  finally
    //FLock.Release;
  end;
end;

function TBitmapList.PSDg(Index: Integer): TPSDImageAviUtl2;
begin
  FLock.Acquire;
  try
    Result := FPSDs[Index];
  finally
    FLock.Release;
  end;
end;

procedure TBitmapList.Clear;
var
  bmp: TBitmap;
  png: TPngImage;
  psd: TPSDImageAviUtl2;
begin
  FLock.Acquire;
  try
    for bmp in FBitmaps do  bmp.Free;
    FBitmaps.Clear;
    for png in FPNGs do  png.Free;
    FPNGs.Clear;
    for psd in FPSDs do  psd.Free;
    FPSDs.Clear;
  finally
    FLock.Release;
  end;
end;


end.
