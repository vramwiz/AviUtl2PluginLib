unit SerifBoardList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Winapi.CommCtrl, Vcl.Graphics, Vcl.Controls, Vcl.ComCtrls,
  ExplorerFileList, ExplorerListView, BitmapCache;

type
  TSerifBoardFileItem = class(TExplorerFileItem)
  end;

type
  TSerifBoardFileList = class(TExplorerFileList<TSerifBoardFileItem>)
  private
    function GetFiles(Index: Integer): TSerifBoardFileItem;
  protected
    function IsVisibleExtension(const FileName: string): Boolean; override;
  public
    constructor Create; override;
    procedure AddFiles(FileNames: TStringList); override;
    property Files[Index: Integer]: TSerifBoardFileItem read GetFiles; default;
  end;

type
  TSerifBoardListView = class(TExplorerListView<TSerifBoardFileItem>)
  private
    FCache: TBitmapCache;
    function GetCacheUID(Item: TSerifBoardFileItem): string;
    function GetFiles(Index: Integer): TSerifBoardFileItem;
  protected
    procedure CreateWnd; override;
    procedure WMMouseWheel(var Msg: TWMMouseWheel); message WM_MOUSEWHEEL;
    procedure DoGetDisplayBitmap(Index: Integer; Bitmap: TBitmap); override;
    procedure SetZoomIndex(const Value: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ItemPaste; override;
    procedure ZoomIn; override;
    procedure ZoomOut; override;

    property Files[Index: Integer]: TSerifBoardFileItem read GetFiles; default;
    property ZoomIndex: Integer read FZoomIndex write SetZoomIndex;
  end;

implementation

uses
  System.Types, System.IOUtils, PngImage, AppFolderUtils;

const
  CHECKER_CELL_SIZE = 8;
  THUMBNAIL_ASPECT_RATIO = 16 / 9;
  ZOOM_TBL: array[0..5] of Integer = (36, 54, 72, 96, 128, 160);
  STYLE_TBL: array[0..5] of TViewStyle = (
    vsReport,
    vsReport,
    vsIcon,
    vsIcon,
    vsIcon,
    vsIcon
  );

function GetThumbnailWidth(AHeight: Integer): Integer;
begin
  Result := Round(AHeight * THUMBNAIL_ASPECT_RATIO);
end;

procedure FillCheckerBoard(Canvas: TCanvas; const R: TRect; CellSize: Integer);
var
  X: Integer;
  Y: Integer;
  Cell: TRect;
begin
  for X := 0 to (R.Width div CellSize) do
    for Y := 0 to (R.Height div CellSize) do
    begin
      Cell.Left := R.Left + (X * CellSize);
      Cell.Top := R.Top + (Y * CellSize);
      Cell.Right := Cell.Left + CellSize;
      Cell.Bottom := Cell.Top + CellSize;

      if Odd(X + Y) then
        Canvas.Brush.Color := $00B8B8B8
      else
        Canvas.Brush.Color := $00E0E0E0;
      Canvas.FillRect(Cell);
    end;
end;

function GetFitRect(const Bounds: TRect; const AWidth, AHeight: Integer): TRect;
var
  DrawWidth: Integer;
  DrawHeight: Integer;
begin
  Result := Bounds;
  if (AWidth <= 0) or (AHeight <= 0) then
    Exit;

  DrawWidth := Bounds.Width;
  DrawHeight := MulDiv(DrawWidth, AHeight, AWidth);
  if DrawHeight > Bounds.Height then
  begin
    DrawHeight := Bounds.Height;
    DrawWidth := MulDiv(DrawHeight, AWidth, AHeight);
  end;

  Result.Left := Bounds.Left + ((Bounds.Width - DrawWidth) div 2);
  Result.Top := Bounds.Top + ((Bounds.Height - DrawHeight) div 2);
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

{ TSerifBoardFileList }

constructor TSerifBoardFileList.Create;
begin
  inherited;
  FExtensions.Add('.png');
end;

function TSerifBoardFileList.GetFiles(Index: Integer): TSerifBoardFileItem;
begin
  Result := inherited Items[Index];
end;

function TSerifBoardFileList.IsVisibleExtension(const FileName: string): Boolean;
begin
  Result := SameText(ExtractFileExt(FileName), '.png');
end;

procedure TSerifBoardFileList.AddFiles(FileNames: TStringList);
begin
  inherited AddFiles(FileNames);
  Sort(
    function(const Left, Right: TSerifBoardFileItem): Integer
    begin
      Result := CompareText(Left.Name, Right.Name);
      if Result = 0 then
        Result := CompareText(Left.FileName, Right.FileName);
    end
  );
end;

{ TSerifBoardListView }

constructor TSerifBoardListView.Create(AOwner: TComponent);
var
  H: Integer;
  W: Integer;
begin
  inherited;
  FFiles := TSerifBoardFileList.Create;
  FCache := TBitmapCache.Create;
  FCache.CacheFolder := GetAppFolder('Serif\Board\Cache');
  SortType := stData;
  IconOptions.Arrangement := iaTop;
  IconOptions.AutoArrange := True;

  FZoomIndex := 3;
  H := ZOOM_TBL[FZoomIndex];
  W := GetThumbnailWidth(H);
  SetThumbnailSize(STYLE_TBL[FZoomIndex], H, W, True);
end;

procedure TSerifBoardListView.CreateWnd;
var
  Style: NativeInt;
begin
  inherited;
  Style := GetWindowLongPtr(Handle, GWL_STYLE);
  Style := (Style or LVS_ALIGNTOP) and not LVS_ALIGNLEFT;
  SetWindowLongPtr(Handle, GWL_STYLE, Style);
  Perform(LVM_ARRANGE, LVA_DEFAULT, 0);
end;

destructor TSerifBoardListView.Destroy;
begin
  FCache.Free;
  FFiles.Free;
  inherited;
end;

procedure TSerifBoardListView.DoGetDisplayBitmap(Index: Integer; Bitmap: TBitmap);
var
  Item: TSerifBoardFileItem;
  FileName: string;
  CacheUID: string;
  Png: TPngImage;
  Stream: TFileStream;
  DrawRect: TRect;
begin
  if (FFiles = nil) or (Index < 0) or (Index >= FFiles.Count) then
    Exit;

  Item := Files[Index];
  if Item = nil then
    Exit;

  CacheUID := GetCacheUID(Item);
  if (FCache <> nil) and FCache.GetCache(CacheUID, Bitmap.Width, Bitmap.Height, Bitmap) then
    Exit;

  Bitmap.PixelFormat := pf32bit;
  Bitmap.Canvas.Brush.Color := clBlack;
  Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
  FillCheckerBoard(Bitmap.Canvas, Rect(0, 0, Bitmap.Width, Bitmap.Height), CHECKER_CELL_SIZE);

  FileName := Item.FileName;
  if not FileExists(FileName) then
    Exit;

  Png := TPngImage.Create;
  Stream := nil;
  try
    try
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      Png.LoadFromStream(Stream);
    except
      Exit;
    end;

    DrawRect := GetFitRect(Rect(0, 0, Bitmap.Width, Bitmap.Height), Png.Width, Png.Height);
    Png.Draw(Bitmap.Canvas, DrawRect);
    if FCache <> nil then
      FCache.AddCache(CacheUID, Bitmap.Width, Bitmap.Height, Bitmap);
  finally
    Stream.Free;
    Png.Free;
  end;
end;

function TSerifBoardListView.GetCacheUID(Item: TSerifBoardFileItem): string;
var
  LastWriteTime: TDateTime;
begin
  Result := '';
  if Item = nil then
    Exit;

  Result := Item.FileName;
  if TFile.Exists(Item.FileName) then
  begin
    LastWriteTime := TFile.GetLastWriteTime(Item.FileName);
    Result := Result + '|' + DateTimeToStr(LastWriteTime);
  end;
end;

function TSerifBoardListView.GetFiles(Index: Integer): TSerifBoardFileItem;
begin
  Result := TSerifBoardFileItem(FFiles[Index]);
end;

procedure TSerifBoardListView.ItemPaste;
begin
end;

procedure TSerifBoardListView.SetZoomIndex(const Value: Integer);
var
  H: Integer;
  W: Integer;
  NewValue: Integer;
begin
  NewValue := Value;
  if NewValue < Low(ZOOM_TBL) then
    NewValue := Low(ZOOM_TBL);
  if NewValue > High(ZOOM_TBL) then
    Exit;

  FZoomIndex := NewValue;
  H := ZOOM_TBL[FZoomIndex];
  W := GetThumbnailWidth(H);
  SetThumbnailSize(STYLE_TBL[FZoomIndex], H, W, True);
  DoZoomChange(FZoomIndex);
end;

procedure TSerifBoardListView.WMMouseWheel(var Msg: TWMMouseWheel);
begin
  if GetKeyState(VK_CONTROL) >= 0 then
  begin
    inherited;
    Exit;
  end;

  if Msg.WheelDelta > 0 then
    ZoomIn
  else if Msg.WheelDelta < 0 then
    ZoomOut;

  Msg.Result := 1;
end;

procedure TSerifBoardListView.ZoomIn;
begin
  if FZoomIndex >= High(ZOOM_TBL) then
    Exit;
  SetZoomIndex(FZoomIndex + 1);
end;

procedure TSerifBoardListView.ZoomOut;
begin
  if FZoomIndex <= Low(ZOOM_TBL) then
    Exit;
  SetZoomIndex(FZoomIndex - 1);
end;

end.
