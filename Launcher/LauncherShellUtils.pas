unit LauncherShellUtils;
// ランチャーで使う Windows Shell 操作。

interface

uses
  Winapi.Windows, Winapi.Messages,
  Vcl.Controls, Vcl.ImgList;

function IsSupportedLauncherFile(const FileName: string): Boolean;
function ResolveLauncherShortcut(const FileName: string): string;
function AddLauncherFileIcon(Images: TImageList; const FileName: string;
  ImageSize: Integer): Integer;
function ActivateLauncherWindow(Wnd: HWND): Boolean;
function OpenLauncherFile(OwnerWnd: HWND; const FileName: string;
  out ProcessHandle: THandle): Boolean;

implementation

uses
  Winapi.ActiveX, Winapi.ShellAPI, Winapi.ShlObj,
  System.SysUtils, System.Win.ComObj,
  Vcl.Graphics;

function IsSupportedLauncherFile(const FileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := FileExists(FileName) and
    (SameText(Ext, '.exe') or SameText(Ext, '.lnk'));
end;

function ResolveLauncherShortcut(const FileName: string): string;
var
  ShellLink: IShellLink;
  PersistFile: IPersistFile;
  FindData: TWin32FindData;
  Buffer: array[0..MAX_PATH - 1] of Char;
  CoInit: HRESULT;
  NeedUninitialize: Boolean;
begin
  Result := '';
  if not SameText(ExtractFileExt(FileName), '.lnk') then
    Exit(FileName);

  CoInit := CoInitialize(nil);
  NeedUninitialize := Succeeded(CoInit);
  try
    ShellLink := CreateComObject(CLSID_ShellLink) as IShellLink;
    PersistFile := ShellLink as IPersistFile;
    if Failed(PersistFile.Load(PChar(FileName), STGM_READ)) then
      Exit;

    ZeroMemory(@FindData, SizeOf(FindData));
    if Succeeded(ShellLink.GetPath(Buffer, Length(Buffer), FindData,
      SLGP_UNCPRIORITY)) then
      Result := Buffer;
  finally
    if NeedUninitialize then
      CoUninitialize;
  end;
end;

function AddLauncherFileIcon(Images: TImageList; const FileName: string;
  ImageSize: Integer): Integer;
var
  FileInfo: TSHFileInfo;
  Icon: TIcon;
  ImageFactory: IShellItemImageFactory;
  Bitmap: TBitmap;
  BitmapHandle: HBITMAP;
  Size: TSize;
  Flags: UINT;
  CoInit: HRESULT;
  NeedUninitialize: Boolean;
begin
  Result := -1;
  if Images = nil then
    Exit;

  CoInit := CoInitialize(nil);
  NeedUninitialize := Succeeded(CoInit);
  try
    ImageFactory := nil;
    BitmapHandle := 0;

    if Succeeded(SHCreateItemFromParsingName(PChar(FileName), nil,
      IID_IShellItemImageFactory, ImageFactory)) then
    begin
      Size.cx := ImageSize;
      Size.cy := ImageSize;

      if Succeeded(ImageFactory.GetImage(Size,
        SIIGBF_ICONONLY or SIIGBF_BIGGERSIZEOK, BitmapHandle)) and
        (BitmapHandle <> 0) then
      begin
        Bitmap := TBitmap.Create;
        try
          Bitmap.Handle := BitmapHandle;
          BitmapHandle := 0;
          Bitmap.PixelFormat := pf32bit;
          Result := Images.Add(Bitmap, nil);
          Exit;
        finally
          Bitmap.Free;
          if BitmapHandle <> 0 then
            DeleteObject(BitmapHandle);
        end;
      end;
    end;
  finally
    if NeedUninitialize then
      CoUninitialize;
  end;

  FillChar(FileInfo, SizeOf(FileInfo), 0);
  Flags := SHGFI_ICON;
  if ImageSize <= 16 then
    Flags := Flags or SHGFI_SMALLICON
  else
    Flags := Flags or SHGFI_LARGEICON;

  if SHGetFileInfo(PChar(FileName), FILE_ATTRIBUTE_NORMAL, FileInfo,
    SizeOf(FileInfo), Flags) = 0 then
    Exit;

  Icon := TIcon.Create;
  try
    Icon.Handle := FileInfo.hIcon;
    Result := Images.AddIcon(Icon);
  finally
    Icon.Handle := 0;
    Icon.Free;
    if FileInfo.hIcon <> 0 then
      DestroyIcon(FileInfo.hIcon);
  end;
end;

function ActivateLauncherWindow(Wnd: HWND): Boolean;
var
  ForegroundWnd: HWND;
  CurrentThreadID: DWORD;
  TargetThreadID: DWORD;
  ForegroundThreadID: DWORD;
  ProcessID: DWORD;
  AttachedTarget: Boolean;
  AttachedForeground: Boolean;
begin
  Result := (Wnd <> 0) and IsWindow(Wnd);
  if not Result then
  begin
    OutputDebugString(PChar(Format('[Launcher] ActivateWindow skipped HWND=%p IsWindow=%s',
      [Pointer(Wnd), BoolToStr((Wnd <> 0) and IsWindow(Wnd), True)])));
    Exit;
  end;

  if IsIconic(Wnd) then
    ShowWindow(Wnd, SW_RESTORE);

  // Foreground activation from a global hotkey can fail across UI threads.
  // Attach input queues temporarily before calling SetForegroundWindow.
  ForegroundWnd := GetForegroundWindow;
  CurrentThreadID := GetCurrentThreadId;
  TargetThreadID := GetWindowThreadProcessId(Wnd, @ProcessID);
  ForegroundThreadID := 0;
  if ForegroundWnd <> 0 then
    ForegroundThreadID := GetWindowThreadProcessId(ForegroundWnd, @ProcessID);

  AttachedTarget := (TargetThreadID <> 0) and (TargetThreadID <> CurrentThreadID) and
    (AttachThreadInput(CurrentThreadID, TargetThreadID, True) <> False);
  AttachedForeground := (ForegroundThreadID <> 0) and
    (ForegroundThreadID <> CurrentThreadID) and
    (ForegroundThreadID <> TargetThreadID) and
    (AttachThreadInput(CurrentThreadID, ForegroundThreadID, True) <> False);
  try
    BringWindowToTop(Wnd);
    Result := SetForegroundWindow(Wnd) <> False;
  finally
    // AttachThreadInput は接続したままだと入力状態に影響するため、必ず戻す。
    if AttachedForeground then
      AttachThreadInput(CurrentThreadID, ForegroundThreadID, False);
    if AttachedTarget then
      AttachThreadInput(CurrentThreadID, TargetThreadID, False);
  end;

  PostMessage(Wnd, WM_SETFOCUS, 0, 0);
  // SetForegroundWindow の戻りが False でも、実際に前面化できていれば成功扱いにする。
  Result := Result or (GetForegroundWindow = Wnd);
end;

function OpenLauncherFile(OwnerWnd: HWND; const FileName: string;
  out ProcessHandle: THandle): Boolean;
var
  ExecuteInfo: TShellExecuteInfo;
begin
  ProcessHandle := 0;
  ZeroMemory(@ExecuteInfo, SizeOf(ExecuteInfo));
  ExecuteInfo.cbSize := SizeOf(ExecuteInfo);
  ExecuteInfo.Wnd := OwnerWnd;
  ExecuteInfo.fMask := SEE_MASK_NOCLOSEPROCESS;
  ExecuteInfo.lpVerb := 'open';
  ExecuteInfo.lpFile := PChar(FileName);
  ExecuteInfo.nShow := SW_SHOWNORMAL;

  Result := ShellExecuteEx(@ExecuteInfo);
  if Result then
    ProcessHandle := ExecuteInfo.hProcess;
end;

end.
