// キャラクターのベクターアイコンをキャッシュ描画し、未登録時は共通グリフで補完する。
unit SerifCharaIconRenderer;

interface

uses
  System.SysUtils, System.Classes, System.Types, Vcl.Graphics, BitmapCache;

type
  TSerifCharaIconRenderer = class
  private
    FCache: TBitmapCache;
    FVectorFolder: string;
    FVectorFileList: TStringList;
    FVectorFileListLoaded: Boolean;
    FVectorFolderWriteTime: TDateTime;
    function EnsureCache: Boolean;
    function FindVectorFileNameByPartialMatch(
      const CharaName: string): string;
    function FindVectorFolder: string;
    function GetCacheUID(const FileName: string): string;
    function GetVectorFileName(const CharaName: string): string;
    function NormalizeLookupName(const Value: string): string;
    procedure RefreshVectorFileList;
    function SanitizeFileBase(const CharaName: string): string;
  public
    // ベクター画像の描画結果を再利用するキャッシュを生成する。
    constructor Create;
    // この描画器が所有するビットマップキャッシュを解放する。
    destructor Destroy; override;
    // ベクターデータがないキャラクターを表す共通の人物グリフを描画する。
    procedure DrawFallback(ACanvas: TCanvas; const DrawRect: TRect);
    // ベクターアイコンを優先し、見つからない場合は共通の人物グリフを描画する。
    procedure DrawOrFallback(ACanvas: TCanvas; const CharaName: string;
      const DrawRect: TRect);
    // 指定名のベクターアイコンを描画し、データが存在して描画できた場合だけTrueを返す。
    function Draw(ACanvas: TCanvas; const CharaName: string;
      const DrawRect: TRect): Boolean;
  end;

implementation

uses
  Winapi.Windows, System.IOUtils, System.Math, VectorRenderer, AppFolderUtils;

// アルファ付きビットマップを描画先の背景へ合成する。
procedure DrawAlphaBitmap(ACanvas: TCanvas; const DrawRect: TRect;
  ABitmap: Vcl.Graphics.TBitmap);
var
  Blend: BLENDFUNCTION;
begin
  Blend.BlendOp := AC_SRC_OVER;
  Blend.BlendFlags := 0;
  Blend.SourceConstantAlpha := 255;
  Blend.AlphaFormat := AC_SRC_ALPHA;
  if not Winapi.Windows.AlphaBlend(ACanvas.Handle, DrawRect.Left,
    DrawRect.Top, DrawRect.Width, DrawRect.Height, ABitmap.Canvas.Handle,
    0, 0, ABitmap.Width, ABitmap.Height, Blend) then
    ACanvas.StretchDraw(DrawRect, ABitmap);
end;

constructor TSerifCharaIconRenderer.Create;
begin
  inherited Create;
  FCache := TBitmapCache.Create;
  FVectorFileList := TStringList.Create;
  FVectorFileList.CaseSensitive := False;
end;

destructor TSerifCharaIconRenderer.Destroy;
begin
  FVectorFileList.Free;
  FCache.Free;
  inherited;
end;

procedure TSerifCharaIconRenderer.DrawFallback(ACanvas: TCanvas;
  const DrawRect: TRect);
var
  BodyRect: TRect;
  CenterX: Integer;
  HeadCenterY: Integer;
  HeadRadius: Integer;
  IconSize: Integer;
  OldBrushColor: TColor;
  OldBrushStyle: TBrushStyle;
  OldPenColor: TColor;
  OldPenStyle: TPenStyle;
  OldPenWidth: Integer;
begin
  if not Assigned(ACanvas) or (DrawRect.Width <= 0) or
    (DrawRect.Height <= 0) then Exit;
  OldBrushColor := ACanvas.Brush.Color;
  OldBrushStyle := ACanvas.Brush.Style;
  OldPenColor := ACanvas.Pen.Color;
  OldPenStyle := ACanvas.Pen.Style;
  OldPenWidth := ACanvas.Pen.Width;
  try
    IconSize := Min(DrawRect.Width, DrawRect.Height);
    CenterX := DrawRect.Left + DrawRect.Width div 2;
    HeadRadius := Max(2, IconSize div 7);
    HeadCenterY := DrawRect.Top + IconSize * 3 div 10;
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Brush.Color := TColor($007EDC98);
    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Width := 1;
    ACanvas.Pen.Color := TColor($00C2FFD2);
    ACanvas.Ellipse(CenterX - HeadRadius, HeadCenterY - HeadRadius,
      CenterX + HeadRadius + 1, HeadCenterY + HeadRadius + 1);
    BodyRect := Rect(CenterX - IconSize * 27 div 100,
      DrawRect.Top + IconSize * 52 div 100,
      CenterX + IconSize * 27 div 100 + 1,
      DrawRect.Top + IconSize * 91 div 100);
    ACanvas.RoundRect(BodyRect.Left, BodyRect.Top, BodyRect.Right,
      BodyRect.Bottom, Max(3, IconSize div 6), Max(3, IconSize div 6));
  finally
    ACanvas.Brush.Color := OldBrushColor;
    ACanvas.Brush.Style := OldBrushStyle;
    ACanvas.Pen.Color := OldPenColor;
    ACanvas.Pen.Style := OldPenStyle;
    ACanvas.Pen.Width := OldPenWidth;
  end;
end;

procedure TSerifCharaIconRenderer.DrawOrFallback(ACanvas: TCanvas;
  const CharaName: string; const DrawRect: TRect);
begin
  if not Draw(ACanvas, CharaName, DrawRect) then
    DrawFallback(ACanvas, DrawRect);
end;

function TSerifCharaIconRenderer.Draw(ACanvas: TCanvas;
  const CharaName: string; const DrawRect: TRect): Boolean;
var
  Bitmap: Vcl.Graphics.TBitmap;
  FileName: string;
  RenderedBitmap: Vcl.Graphics.TBitmap;
  UID: string;
begin
  Result := False;
  if not Assigned(ACanvas) or (DrawRect.Width <= 0) or
    (DrawRect.Height <= 0) then Exit;
  if not EnsureCache then Exit;

  FileName := GetVectorFileName(CharaName);
  if FileName = '' then Exit;
  UID := GetCacheUID(FileName);

  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(DrawRect.Width, DrawRect.Height);
    if not FCache.GetCache(UID, Bitmap.Width, Bitmap.Height, Bitmap) then
    begin
      RenderedBitmap := TVectorRenderer.RenderFileToBitmap(FileName,
        DrawRect.Width, DrawRect.Height, vrbTransparent);
      try
        if not Assigned(RenderedBitmap) then Exit;
        Bitmap.Assign(RenderedBitmap);
        FCache.AddCache(UID, Bitmap.Width, Bitmap.Height, Bitmap);
      finally
        RenderedBitmap.Free;
      end;
    end;
    Bitmap.AlphaFormat := afPremultiplied;
    DrawAlphaBitmap(ACanvas, DrawRect, Bitmap);
    Result := True;
  finally
    Bitmap.Free;
  end;
end;

function TSerifCharaIconRenderer.EnsureCache: Boolean;
var
  CacheFolder: string;
begin
  Result := False;
  if FVectorFolder = '' then
    FVectorFolder := FindVectorFolder;
  if FVectorFolder = '' then Exit;

  CacheFolder := TPath.Combine(FVectorFolder, 'Cache');
  ForceDirectories(CacheFolder);
  FCache.CacheFolder := IncludeTrailingPathDelimiter(CacheFolder);
  Result := True;
end;

function TSerifCharaIconRenderer.FindVectorFolder: string;
begin
  Result := GetAppFolder('Vector');
end;

function TSerifCharaIconRenderer.GetCacheUID(const FileName: string): string;
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Invariant;
  Result := FileName + '|transparent-v2|' +
    FloatToStr(TFile.GetLastWriteTime(FileName), FS);
end;

function TSerifCharaIconRenderer.GetVectorFileName(
  const CharaName: string): string;
var
  FileBase: string;
begin
  Result := '';
  if FVectorFolder = '' then
    FVectorFolder := FindVectorFolder;
  if FVectorFolder = '' then Exit;

  FileBase := SanitizeFileBase(CharaName);
  if FileBase = '' then Exit;
  Result := TPath.Combine(FVectorFolder, FileBase + '.ini');
  if not TFile.Exists(Result) then
    Result := FindVectorFileNameByPartialMatch(CharaName);
end;

function TSerifCharaIconRenderer.FindVectorFileNameByPartialMatch(
  const CharaName: string): string;
var
  CandidateBase: string;
  CandidateFileName: string;
  CandidateName: string;
  I: Integer;
  SearchName: string;
begin
  Result := '';
  SearchName := NormalizeLookupName(CharaName);
  if SearchName = '' then Exit;
  RefreshVectorFileList;
  for I := 0 to FVectorFileList.Count - 1 do
  begin
    CandidateFileName := FVectorFileList[I];
    CandidateBase := TPath.GetFileNameWithoutExtension(CandidateFileName);
    CandidateName := NormalizeLookupName(CandidateBase);
    if (CandidateName = '') or
      (Pos(CandidateName, SearchName) = 0) then
      Continue;
    if (Result = '') or
      (Length(CandidateName) > Length(NormalizeLookupName(
        TPath.GetFileNameWithoutExtension(Result)))) then
      Result := CandidateFileName;
  end;
end;

function TSerifCharaIconRenderer.NormalizeLookupName(
  const Value: string): string;
begin
  Result := LowerCase(SanitizeFileBase(Value));
end;

procedure TSerifCharaIconRenderer.RefreshVectorFileList;
var
  FileName: string;
  Files: TArray<string>;
  FolderWriteTime: TDateTime;
begin
  if (FVectorFolder = '') or not TDirectory.Exists(FVectorFolder) then
  begin
    FVectorFileList.Clear;
    FVectorFileListLoaded := False;
    Exit;
  end;

  try
    FolderWriteTime := TDirectory.GetLastWriteTime(FVectorFolder);
  except
    FolderWriteTime := 0;
  end;
  if FVectorFileListLoaded and
    (FVectorFolderWriteTime = FolderWriteTime) then
    Exit;

  FVectorFileList.Clear;
  Files := TDirectory.GetFiles(FVectorFolder, '*.ini',
    TSearchOption.soTopDirectoryOnly);
  for FileName in Files do
    if not SameText(TPath.GetFileName(FileName), 'Characters.ini') then
      FVectorFileList.Add(FileName);
  FVectorFileList.Sort;
  FVectorFolderWriteTime := FolderWriteTime;
  FVectorFileListLoaded := True;
end;

function TSerifCharaIconRenderer.SanitizeFileBase(
  const CharaName: string): string;
var
  C: Char;
begin
  Result := Trim(CharaName);
  for C in TPath.GetInvalidFileNameChars do
    Result := StringReplace(Result, C, '', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
  Result := StringReplace(Result, #$3000, '', [rfReplaceAll]);
end;

end.
