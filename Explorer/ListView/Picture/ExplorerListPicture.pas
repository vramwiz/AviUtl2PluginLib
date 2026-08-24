unit ExplorerListPicture;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  ListViewEdit,ListViewEx,Vcl.Menus,System.Generics.Collections,
  Vcl.StdCtrls, Vcl.ExtCtrls,RTTIPersistent,ExplorerFileList,ExplorerListView,
  ImageLoader,BitmapCache,DragAgent,ListViewRTTI;


procedure ExplorerConfigPictureShow(lv : TListViewRTTI;Item : TExplorerFileItem);

// 標準ファイルの情報　このクラスは拡張しない
type
  TExplorerFilePicturelItem = class(TExplorerFileItem)
  private
    FX           : Double;          // X座標
    FY           : Double;          // Y座標
    FZ           : Double;          // Z座標
    FGroup       : Integer;         // グループ番号
    FCenterX     : Double;          // 中心X座標
    FCenterY     : Double;          // 中心Y座標
    FCenterZ     : Double;          // 中心Z座標
    FRotateX     : Double;          // X軸回転
    FRotateY     : Double;          // Y軸回転
    FRotateZ     : Double;          // Z軸回転
    FScale       : Double;          // 拡大率
    FAspectRatio : Double;          // 縦横比
    FTransparent : Double;          // 透明度
    FBlendMode   : string;          // 合成モード
  protected
  public
    constructor Create;
    destructor Destroy;override;
  published
    property X           : Double  read FX           write FX;
    property Y           : Double  read FY           write FY;
    property Z           : Double  read FZ           write FZ;
    property Scale       : Double  read FScale       write FScale;
    property Transparent : Double  read FTransparent write FTransparent;
    property RotateX     : Double  read FRotateX     write FRotateX;
    property RotateY     : Double  read FRotateY     write FRotateY;
    property RotateZ     : Double  read FRotateZ     write FRotateZ;
    property BlendMode   : string  read FBlendMode   write FBlendMode;
    property AspectRatio : Double  read FAspectRatio write FAspectRatio;
    property Group       : Integer read FGroup       write FGroup;
    property CenterX     : Double  read FCenterX     write FCenterX;
    property CenterY     : Double  read FCenterY     write FCenterY;
    property CenterZ     : Double  read FCenterZ     write FCenterZ;
  end;

// ファイルリスト
type
  TExplorerFilePictureList = class(TExplorerFileList<TExplorerFilePicturelItem>)
	private
		{ Private 宣言 }
    function GetFiles(Index: Integer): TExplorerFilePicturelItem;
  protected
    function IsVisibleExtension(const FileName : string) : Boolean;override;
	public
		{ Public 宣言 }
    constructor Create;override;
    destructor Destroy; override;


    property Files[Index : Integer] : TExplorerFilePicturelItem read GetFiles;default;
	end;

  TExplorerListViewPicture = class(TExplorerListView<TExplorerFilePicturelItem>)
  private
    FImageLoader :  TImageLoader;
    FCache       : TBitmapCache;
    FDrag        : TDragShellFile;
    procedure OnDrag(Sender: TObject;FileNames : TStringList);
    function GetFiles(Index: Integer): TExplorerFilePicturelItem;
  protected
    // Ctrl＋マウスホイールによる拡大縮小用
    procedure WMMouseWheel(var Msg: TWMMouseWheel); message WM_MOUSEWHEEL;
    procedure DoGetDisplayBitmap(Index: Integer;Bitmap : TBitmap);override;
    procedure SetZoomIndex(const Value: Integer);override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ZoomIn(); override;
    procedure ZoomOut();override;

    procedure ItemPaste();override;
    function IsItemPaste() : Boolean;override;

    property Files[Index : Integer] : TExplorerFilePicturelItem read GetFiles;default;
  end;


implementation

uses  AppFolderUtils,PngImage,ClipboardWatcher,AviUtl2Picture,
      ListViewEditPluginLib,ListViewEditPluginDialog;

const
  ZOOM_TBL : array[0..5] of Integer = (32,64,100,128,192,256);
  STYLE_TBL: array[0..5] of TViewStyle = (
    vsReport,
    vsIcon,
    vsIcon,
    vsIcon,
    vsIcon,
    vsIcon
  );


{ TExplorerListViewPicture }

constructor TExplorerListViewPicture.Create(AOwner: TComponent);
var
  s : string;
  h : Integer;
begin
  inherited;
  FFiles := TExplorerFilePictureList.Create;

  FZoomIndex := 2;
  h := ZOOM_TBL[FZoomIndex];

  SetThumbnailSize(STYLE_TBL[FZoomIndex],h,h,True);

  FImageLoader := TImageLoader.Create;
  FCache := TBitmapCache.Create;
  s := GetAppFolder('Explorer\Cache');
  FCache.CacheFolder := s;
  FCache.Filename := s + 'Cache.Ini';
  FCache.LoadFromFile();

  FDrag := TDragShellFile.Create(Self);
  FDrag.Attach(Self);
  FDrag.OnDragRequest := OnDrag;

end;

destructor TExplorerListViewPicture.Destroy;
begin
  FDrag.Free;
  FCache.Free;
  FImageLoader.Free;
  FFiles.Free;
  inherited;
end;

  // 市松模様の背景を指定範囲に描画する（透過画像用の下地）
// 引数：
//   Canvas  - 描画先キャンバス
//   R       - 描画範囲（市松模様を敷き詰める領域）
//   CellSize - 1マスのサイズ（省略時は8ピクセル）
// 備考： 明るめ/暗めの2色を交互に配置し、透明領域の視認性を向上させる。
procedure FillCheckerBoard(Canvas: TCanvas; const R: TRect;
  CellSize: Integer);
var
  i, j: Integer;
  Color1, Color2: TColor;
  Cell: TRect;
begin
  Color1 := $CCCCCC;
  Color2 := $999999;
  for i := 0 to (R.Width div CellSize) do
    for j := 0 to (R.Height div CellSize) do
    begin
      Cell.Left := R.Left + i * CellSize;
      Cell.Top := R.Top + j * CellSize;
      Cell.Right := Cell.Left + CellSize;
      Cell.Bottom := Cell.Top + CellSize;

      if (i + j) mod 2 = 0 then
        Canvas.Brush.Color := Color1
      else
        Canvas.Brush.Color := Color2;
      Canvas.FillRect(Cell);
    end;
end;

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



procedure TExplorerListViewPicture.DoGetDisplayBitmap(Index: Integer;  Bitmap: TBitmap);
var
  s: string;
  DstRect: TRect;
begin
  if FFiles = nil then Exit;
  if Index = -1 then Exit;
  if Index >= FFiles.Count then Exit;

  s := FFiles[Index].FileName;
  if not FileExists(s) then Exit;

  try
    if FCache.GetCache(s,Bitmap.Width,Bitmap.Height,Bitmap) then Exit;

    DstRect := Rect(0, 0, Bitmap.Width, Bitmap.Height);
    FillCheckerBoard(Bitmap.Canvas, DstRect,8);
    if not FImageLoader.LoadToBitmap(s,Bitmap) then
      Exit;

    FCache.AddCache(s,Bitmap.Width,Bitmap.Height,Bitmap);
  except
    Exit;
  end;
end;
function TExplorerListViewPicture.GetFiles(Index: Integer): TExplorerFilePicturelItem;
begin
  Result := TExplorerFilePicturelItem(FFiles[Index]);
end;

function TExplorerListViewPicture.IsItemPaste: Boolean;
begin
  Result := True;
end;

procedure TExplorerListViewPicture.ItemPaste;
var
  FileName : string;
  Bmp : TBitmap;
  Png :TPngImage;
begin
  FileName := FFolder;
  FileName := FileName + 'Screenshot_' + FormatDateTime('yyyymmddhhnnsszzz', Now) + '.png';

  Bmp := TBitmap.Create;
  Png := TPngImage.Create;
  try
    if GetClipboardPng(Png) then begin
      Png.SaveToFile(FileName);
    end
    else if GetClipboardBitmap(Bmp) then begin
      Png.Assign(Bmp);
      Png.SaveToFile(FileName);
    end
    else begin
      exit;
    end;

  finally
    Png.Free;
    Bmp.Free;
  end;
end;

procedure TExplorerListViewPicture.OnDrag(Sender: TObject;FileNames: TStringList);
var
  i : Integer;
  s :string;
  Item : TExplorerFilePicturelItem;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  Item := Files[i];
  if Item = nil  then Exit;

  Item := Files[i];

  s := AviUtl2PictureDandD(Item);

  FileNames.Clear;
  FileNames.Add(s);
end;

procedure TExplorerListViewPicture.WMMouseWheel(var Msg: TWMMouseWheel);
var
  Delta: Integer;
begin
  // Ctrlキーが押されていない場合は通常処理（スクロール）
  if GetKeyState(VK_CONTROL) >= 0 then
  begin
    inherited;
    Exit;
  end;

  // ---- ここから Ctrl＋ホイール時の独自処理 ----
  Delta := Msg.WheelDelta;

  if      Delta > 0 then ZoomIn         // 拡大方向
  else if Delta < 0 then ZoomOut;       // 縮小方向

  // Ctrl時はスクロールさせない
  Msg.Result := 1;
end;

procedure TExplorerListViewPicture.ZoomIn;
var
  h : Integer;
begin
  if FZoomIndex >= High(ZOOM_TBL) then Exit;
  Inc(FZoomIndex);
  h := ZOOM_TBL[FZoomIndex];
  SetThumbnailSize(STYLE_TBL[FZoomIndex],h,h,True);
  DoZoomChange(FZoomIndex);
end;

procedure TExplorerListViewPicture.ZoomOut;
var
  h : Integer;
begin
  if FZoomIndex <= 0 then Exit;
  Dec(FZoomIndex);
  h := ZOOM_TBL[FZoomIndex];
  SetThumbnailSize(STYLE_TBL[FZoomIndex],h,h,True);
  DoZoomChange(FZoomIndex);
end;

procedure TExplorerListViewPicture.SetZoomIndex(const Value: Integer);
var
  h : Integer;
begin
  if Value < Low(ZOOM_TBL) then Exit;
  if Value > High(ZOOM_TBL) then Exit;

  FZoomIndex := Value;
  h := ZOOM_TBL[FZoomIndex];
  SetThumbnailSize(STYLE_TBL[FZoomIndex],h,h,True);
  DoZoomChange(FZoomIndex);
end;



{ TExplorerFilePictureList }

constructor TExplorerFilePictureList.Create;
begin
  inherited;
  FExtensions.Add('.bmp');
  FExtensions.Add('.gif');
  FExtensions.Add('.png');
  FExtensions.Add('.jpg');
  FExtensions.Add('.jpeg');
end;

destructor TExplorerFilePictureList.Destroy;
begin

  inherited;
end;

function TExplorerFilePictureList.GetFiles(Index: Integer): TExplorerFilePicturelItem;
begin
  Result := inherited Items[Index];
end;

function TExplorerFilePictureList.IsVisibleExtension(
  const FileName: string): Boolean;
begin
  Result := True;
end;

{ TExplorerFilePicturelItem }

constructor TExplorerFilePicturelItem.Create;
begin
  FGroup := 1;
  FScale := 100.00;
  FBlendMode := '通常';
end;

destructor TExplorerFilePicturelItem.Destroy;
begin

  inherited;
end;

procedure ExplorerConfigPictureShow(lv : TListViewRTTI;Item : TExplorerFileItem);
begin
  if not (Item is TExplorerFileItem) then Exit;

  lv.RTTINames['FileName'].EditType := ListViewEditPluginHideId;
  lv.RTTINames['Name'].EditType := ListViewEditPluginHideId;
  lv.RTTINames['Group'].EditType := ListViewEditPluginHideId;

  lv.RTTINames['X'].AddCaption('X','',clSkyBlue);
  lv.RTTINames['Y'].AddCaption('Y','',clSkyBlue);
  lv.RTTINames['Z'].AddCaption('Z','',clSkyBlue);
  lv.RTTINames['CenterX'].AddCaption('中心X','',clMoneyGreen);
  lv.RTTINames['CenterY'].AddCaption('中心Y','',clMoneyGreen);
  lv.RTTINames['CenterZ'].AddCaption('中心Z','',clMoneyGreen);
  lv.RTTINames['RotateX'].AddCaption('X軸回転','',clWebPink);
  lv.RTTINames['RotateY'].AddCaption('Y軸回転','',clWebPink);
  lv.RTTINames['RotateZ'].AddCaption('Z軸回転','',clWebPink);
  lv.RTTINames['Scale'].AddCaption('拡大率','',clSkyBlue);
  lv.RTTINames['AspectRatio'].AddCaption('縦横比','',clSkyBlue);
  lv.RTTINames['Transparent'].AddCaption('透明度','',clSkyBlue);
  lv.RTTINames['BlendMode'].AddCaption('合成モード','');

  //lv.SetVisibleIndex();
  lv.LoadFromObject(Item);
  lv.FixedWidth := 100;
end;



end.
