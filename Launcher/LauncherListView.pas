unit LauncherListView;
// ランチャー項目をアイコン付き一覧表示する ListView コンポーネント。

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.CommCtrl,
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics, Vcl.ImgList, Vcl.ExtCtrls,
  ListViewEx,
  LauncherListTypes, LauncherListItems, LauncherRunningState;

const
  WM_LAUNCH_PROCESS_EXITED = WM_USER + 1201;
  WM_LAUNCH_PROCESS_REFRESH = WM_USER + 1202;

type
  TLauncherRunningState = LauncherListTypes.TLauncherRunningState;
  TLauncherListViewItem = LauncherListItems.TLauncherListViewItem;
  TLauncherListViewList = LauncherListItems.TLauncherListViewList;

type
  TLauncherListViewItemEvent = procedure(Sender: TObject;
    Item: TLauncherListViewItem) of object;
  TLauncherListViewZoomChangeEvent = procedure(Sender: TObject;
    ZoomIndex: Integer) of object;
  TLauncherListViewSpeechAppEvent = procedure(Sender: TObject;
    AppKind: Integer; Wnd: HWND; RunningState: TLauncherRunningState) of object;

type
  TLauncherListView = class(TListViewEx)
  private
    FFiles: TLauncherListViewList; // 表示・保存するランチャー項目リスト。
    FZoomIndex: Integer; // アイコン表示サイズの段階。
    FOnItemDblClick: TLauncherListViewItemEvent; // ダブルクリック時の外部処理。
    FOnZoomChange: TLauncherListViewZoomChangeEvent; // ズーム変更通知。
    FOnSpeechAppRunningChange: TLauncherListViewSpeechAppEvent; // 音声合成ソフト起動状態通知。
    FRunningTextColor: TColor; // このランチャーから起動した管理中項目の文字色。
    FSpeechAppManagedTextColor: TColor; // ランチャーから起動した音声合成ソフトの文字色。
    FSpeechAppAdoptedTextColor: TColor; // 外部起動から取り込んだ音声合成ソフトの文字色。
    FRunningRefreshTimer: TTimer; // 起動中状態を軽く再判定するタイマー。
    FRunningStateDetector: TLauncherRunningStateDetector; // 起動中判定を担当する補助クラス。
    function AddFileIcon(const FileName: string): Integer;
    function GetFiles(Index: Integer): TLauncherListViewItem;
    function DetectRunningState(Item: TLauncherListViewItem;
      out Wnd: HWND): TLauncherRunningState;
    function GetRunningStateTextColor(Item: TLauncherListViewItem;
      IsSpeechApp: Boolean): TColor;
    procedure AdjustNameColumnWidth;
    procedure SetFiles(const Value: TLauncherListViewList);
    procedure SetZoomIndex(const Value: Integer);
    function GetScaledZoomIconSize: Integer;
    procedure UpdateIconSize;
    procedure ListViewCustomDrawItem(Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure WatchProcessExit(ProcessHandle: THandle; Item: TLauncherListViewItem);
    procedure WatchRunningStateRefresh(Item: TLauncherListViewItem;
      DelayMS: Cardinal);
    procedure RefreshLauncherItem(Item: TLauncherListViewItem);
    procedure RedrawLauncherItem(Item: TLauncherListViewItem);
    function ContainsLauncherItem(Item: TLauncherListViewItem): Boolean;
    procedure DoSpeechAppRunningChange(Item: TLauncherListViewItem;
      Wnd: HWND);
    procedure StartRunningRefreshTimer;
    procedure RunningRefreshTimerTimer(Sender: TObject);
  protected
    procedure CreateWnd; override;
    procedure DblClick; override;
    procedure DoCaptionEdited(Item: TListItem; const NewCaption: string;
      var Accept: Boolean); override;
    procedure Resize; override;
    procedure WMMouseWheel(var Msg: TWMMouseWheel); message WM_MOUSEWHEEL;
    procedure WMLaunchProcessExited(var Msg: TMessage); message WM_LAUNCH_PROCESS_EXITED;
    procedure WMLaunchProcessRefresh(var Msg: TMessage); message WM_LAUNCH_PROCESS_REFRESH;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RebuildItems;
    procedure RefreshRunningStates;
    function AddFile(const FileName: string): Boolean;
    function AddFiles(const Files: TArray<string>): Integer;
    function GetSelectedItem: TLauncherListViewItem;
    function IsApplicationRunning(const FileName: string): Boolean;
    function ActivateSelected: Boolean;
    function ActivateItem(Item: TLauncherListViewItem): Boolean;
    function LaunchSelected: Boolean;
    function LaunchItem(Item: TLauncherListViewItem): Boolean;
    function RemoveSelected: Boolean;
    procedure BeginRenameSelected;
    procedure ItemUp;
    procedure ItemDown;
    procedure LoadFromFile;
    procedure SaveToFile;
    property FileList: TLauncherListViewList read FFiles write SetFiles;
    property Files[Index: Integer]: TLauncherListViewItem read GetFiles; default;
    property OnItemDblClick: TLauncherListViewItemEvent read FOnItemDblClick write FOnItemDblClick;
    property OnZoomChange: TLauncherListViewZoomChangeEvent read FOnZoomChange write FOnZoomChange;
    property OnSpeechAppRunningChange: TLauncherListViewSpeechAppEvent read FOnSpeechAppRunningChange write FOnSpeechAppRunningChange;
    property RunningTextColor: TColor read FRunningTextColor write FRunningTextColor;
    property SpeechAppManagedTextColor: TColor read FSpeechAppManagedTextColor write FSpeechAppManagedTextColor;
    property SpeechAppAdoptedTextColor: TColor read FSpeechAppAdoptedTextColor write FSpeechAppAdoptedTextColor;
    property ZoomIndex: Integer read FZoomIndex write SetZoomIndex;
  end;

implementation

uses
  Vcl.Forms,
  AviUtl2StyleColors,
  LauncherShellUtils;

const
  ZOOM_TBL: array[0..5] of Integer = (16, 24, 32, 48, 64, 96);
  DEFAULT_ZOOM_INDEX = 2;
  LIST_FONT_HEIGHT = -12;
  LAUNCHER_RUNNING_STATE_TEXT_COLORS: array[TLauncherRunningState] of TColor = (
    A2SCLauncherStoppedText, // lrsStopped
    A2SCLauncherRunningText, // lrsRunningNoWindow
    A2SCLauncherRunningText, // lrsRunningManaged
    A2SCLauncherRunningText  // lrsRunningAdopted
  );
  LAUNCHER_SPEECH_APP_RUNNING_STATE_TEXT_COLORS: array[TLauncherRunningState] of TColor = (
    A2SCLauncherStoppedText,        // lrsStopped
    A2SCLauncherRunningText,       // lrsRunningNoWindow
    A2SCLauncherSpeechManagedText, // lrsRunningManaged
    A2SCLauncherSpeechAdoptedText  // lrsRunningAdopted
  );

{ TLauncherListView }

constructor TLauncherListView.Create(AOwner: TComponent);
begin
  inherited;

  FFiles := TLauncherListViewList.Create;
  FRunningStateDetector := TLauncherRunningStateDetector.Create;
  FZoomIndex := DEFAULT_ZOOM_INDEX;
  FRunningTextColor := LAUNCHER_RUNNING_STATE_TEXT_COLORS[lrsRunningManaged];
  FSpeechAppManagedTextColor := LAUNCHER_SPEECH_APP_RUNNING_STATE_TEXT_COLORS[lrsRunningManaged];
  FSpeechAppAdoptedTextColor := LAUNCHER_SPEECH_APP_RUNNING_STATE_TEXT_COLORS[lrsRunningAdopted];
  FRunningRefreshTimer := TTimer.Create(Self);
  FRunningRefreshTimer.Enabled := False;
  FRunningRefreshTimer.Interval := 1000;
  FRunningRefreshTimer.OnTimer := RunningRefreshTimerTimer;

  ReadOnly := False;
  ParentFont := False;
  Font.Height := LIST_FONT_HEIGHT;
  RowSelect := True;
  HideSelection := False;
  ViewStyle := vsReport;
  MultiSelect := True;
  ShowColumnHeaders := False;
  DoubleBuffered := True;
  OnCustomDrawItem := ListViewCustomDrawItem;

  UpdateIconSize;

  Columns.Clear;
  Columns.Add.Caption := 'Name';
end;

destructor TLauncherListView.Destroy;
begin
  FRunningStateDetector.Free;
  FFiles.Free;
  inherited;
end;

procedure TLauncherListView.DoSpeechAppRunningChange(
  Item: TLauncherListViewItem; Wnd: HWND);
var
  AppKind: Integer;
begin
  if FRunningStateDetector = nil then Exit;
  if not FRunningStateDetector.TryDetectSpeechAppKind(Item.FileName, AppKind) then Exit;
  if not Assigned(FOnSpeechAppRunningChange) then Exit;

  FOnSpeechAppRunningChange(Self, AppKind, Wnd, Item.RunningState);
end;

function TLauncherListView.DetectRunningState(Item: TLauncherListViewItem;
  out Wnd: HWND): TLauncherRunningState;
begin
  if FRunningStateDetector = nil then
  begin
    Wnd := 0;
    Exit(lrsStopped);
  end;

  Result := FRunningStateDetector.DetectRunningState(Item, Wnd);
end;

function TLauncherListView.GetRunningStateTextColor(Item: TLauncherListViewItem;
  IsSpeechApp: Boolean): TColor;
begin
  Result := LAUNCHER_RUNNING_STATE_TEXT_COLORS[Item.RunningState];
  case Item.RunningState of
    lrsRunningManaged:
      if IsSpeechApp and Item.LaunchedByLauncher then
        Result := FSpeechAppManagedTextColor
      else
        Result := FRunningTextColor;
    lrsRunningAdopted:
      if IsSpeechApp then
        Result := FSpeechAppAdoptedTextColor
      else
        Result := FRunningTextColor;
    lrsRunningNoWindow:
      Result := FRunningTextColor;
  end;
end;

procedure TLauncherListView.AdjustNameColumnWidth;
begin
  if Parent = nil        then Exit;
  if not HandleAllocated then Exit;
  if Columns.Count = 0   then Exit;
  if ClientWidth <= 0    then Exit;

  Columns[0].Width := ClientWidth;
end;

function TLauncherListView.AddFile(const FileName: string): Boolean;
var
  Item: TLauncherListViewItem;
begin
  Result := False;
  if (FFiles = nil) or (not IsSupportedLauncherFile(FileName)) then Exit;

  Item := FFiles.AddFile(FileName);
  Result := Item <> nil;
end;

function TLauncherListView.AddFileIcon(const FileName: string): Integer;
begin
  Result := AddLauncherFileIcon(Images, FileName, ImageSize);
end;

procedure TLauncherListView.UpdateIconSize;
begin
  Images.ColorDepth := cd32Bit;
  ImageSize := GetScaledZoomIconSize;
end;

function TLauncherListView.GetScaledZoomIconSize: Integer;
var
  PPI: Integer;
begin
  PPI := CurrentPPI;
  if PPI <= 0 then PPI := Screen.PixelsPerInch;
  if PPI <= 0 then PPI := 96;

  Result := MulDiv(ZOOM_TBL[FZoomIndex], PPI, 96);
  if Result < 1 then Result := 1;
end;

function TLauncherListView.AddFiles(const Files: TArray<string>): Integer;
var
  FileName: string;
begin
  Result := 0;
  if FFiles = nil then Exit;

  for FileName in Files do
  begin
    if not AddFile(FileName) then Continue;

    Inc(Result);
  end;

  if Result = 0 then Exit;

  FFiles.SaveToFile;
  RebuildItems;
end;

function TLauncherListView.RemoveSelected: Boolean;
var
  I: Integer;
begin
  Result := False;
  if FFiles = nil then Exit;

  for I := Items.Count - 1 downto 0 do
  begin
    if not Items[I].Selected then Continue;
    if I >= FFiles.Count then Continue;

    FFiles.Delete(I);
    Result := True;
  end;

  if not Result then Exit;

  FFiles.SaveToFile;
  RebuildItems;
end;

procedure TLauncherListView.BeginRenameSelected;
begin
  if ItemIndex = -1 then Exit;

  BeginEdit(ItemIndex);
end;

procedure TLauncherListView.DblClick;
var
  Item: TLauncherListViewItem;
begin
  inherited;

  Item := GetSelectedItem;
  if Item = nil then Exit;

  if Assigned(FOnItemDblClick) then
    FOnItemDblClick(Self, Item)
  else
    LaunchItem(Item);
end;

procedure TLauncherListView.CreateWnd;
begin
  inherited;
  ListView_SetExtendedListViewStyleEx(Handle, LVS_EX_DOUBLEBUFFER, LVS_EX_DOUBLEBUFFER);
  UpdateIconSize;
  AdjustNameColumnWidth;
end;

function TLauncherListView.ContainsLauncherItem(
  Item: TLauncherListViewItem): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Item = nil then Exit;

  for I := 0 to Items.Count - 1 do
  begin
    if Items[I].Data <> Item then Continue;

    Result := True;
    Exit;
  end;
end;

procedure TLauncherListView.ListViewCustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
var
  LauncherItem: TLauncherListViewItem;
  AppKind: Integer;
  IsSpeechApp: Boolean;
begin
  DefaultDraw := True;
  if Item = nil then Exit;
  if not (TObject(Item.Data) is TLauncherListViewItem) then Exit;

  LauncherItem := TLauncherListViewItem(Item.Data);
  if LauncherItem.RunningState = lrsStopped then Exit;

  IsSpeechApp := (FRunningStateDetector <> nil) and
    FRunningStateDetector.TryDetectSpeechAppKind(LauncherItem.FileName, AppKind);
  Sender.Canvas.Font.Color := GetRunningStateTextColor(LauncherItem, IsSpeechApp);
end;

procedure TLauncherListView.DoCaptionEdited(Item: TListItem;
  const NewCaption: string; var Accept: Boolean);
var
  S: string;
begin
  inherited;

  if Item = nil then Exit;

  S := Trim(NewCaption);
  Accept := S <> '';
  if not Accept then Exit;

  if (FFiles = nil) or (Item.Index < 0) or (Item.Index >= FFiles.Count) then
  begin
    Accept := False;
    Exit;
  end;

  FFiles[Item.Index].Name := S;
  FFiles.SaveToFile;
end;

function TLauncherListView.GetFiles(Index: Integer): TLauncherListViewItem;
begin
  Result := FFiles[Index];
end;

function TLauncherListView.GetSelectedItem: TLauncherListViewItem;
begin
  Result := nil;
  if FFiles = nil then Exit;
  if ItemIndex < 0 then Exit;
  if ItemIndex >= FFiles.Count then Exit;

  Result := FFiles[ItemIndex];
end;

function TLauncherListView.IsApplicationRunning(const FileName: string): Boolean;
begin
  Result := (FRunningStateDetector <> nil) and
    FRunningStateDetector.IsApplicationRunning(FileName);
end;

procedure TLauncherListView.ItemDown;
var
  I: Integer;
begin
  I := ItemIndex;
  if FFiles = nil then Exit;
  if I = -1 then Exit;
  if I + 1 >= FFiles.Count then Exit;
  if I + 1 >= Items.Count then Exit;

  SelectClear;
  FFiles.Exchange(I, I + 1);
  Exchange(I, I + 1);
  FFiles.SaveToFile;

  ItemIndex := I + 1;
  if ItemIndex <> -1 then
  begin
    Items[ItemIndex].Selected := True;
    Items[ItemIndex].Focused := True;
  end;
  TopIndex := ItemIndex;
end;

procedure TLauncherListView.ItemUp;
var
  I: Integer;
begin
  I := ItemIndex;
  if FFiles = nil then Exit;
  if I <= 0 then Exit;
  if I >= Items.Count then Exit;

  SelectClear;
  FFiles.Exchange(I, I - 1);
  Exchange(I, I - 1);
  FFiles.SaveToFile;

  ItemIndex := I - 1;
  if ItemIndex <> -1 then
  begin
    Items[ItemIndex].Selected := True;
    Items[ItemIndex].Focused := True;
  end;
  TopIndex := ItemIndex;
end;

function TLauncherListView.ActivateItem(Item: TLauncherListViewItem): Boolean;
var
  PreviousState: TLauncherRunningState;
  RunningState: TLauncherRunningState;
  Wnd: HWND;
begin
  Result := False;
  if Item = nil then Exit;

  PreviousState := Item.RunningState;
  RunningState := DetectRunningState(Item, Wnd);
  Item.RunningState := RunningState;
  Item.WindowHandle := Wnd;
  RedrawLauncherItem(Item);

  if (PreviousState <> RunningState) or (RunningState <> lrsStopped) then
    DoSpeechAppRunningChange(Item, Wnd);

  if (RunningState = lrsStopped) or (Wnd = 0) then
    Exit;

  Result := ActivateLauncherWindow(Wnd);
end;

function TLauncherListView.ActivateSelected: Boolean;
begin
  Result := ActivateItem(GetSelectedItem);
end;

function TLauncherListView.LaunchItem(Item: TLauncherListViewItem): Boolean;
var
  ExecuteFileName: string;
  ProcessHandle: THandle;
begin
  Result := False;
  if Item = nil then Exit;

  ExecuteFileName := Item.FileName;
  if ExecuteFileName = '' then Exit;
  if not FileExists(ExecuteFileName) then Exit;
  if IsApplicationRunning(ExecuteFileName) then
  begin
    Result := ActivateItem(Item);
    Exit;
  end;

  Result := OpenLauncherFile(Handle, ExecuteFileName, ProcessHandle);
  if Result then
  begin
    Item.LaunchedByLauncher := True;
    if ProcessHandle <> 0 then WatchProcessExit(ProcessHandle, Item);

    WatchRunningStateRefresh(Item, 700);
    StartRunningRefreshTimer;
  end;
end;

function TLauncherListView.LaunchSelected: Boolean;
begin
  Result := LaunchItem(GetSelectedItem);
end;

procedure TLauncherListView.RebuildItems;
var
  I: Integer;
  HasRunning: Boolean;
  ListItem: TListItem;
  PreviousState: TLauncherRunningState;
  Wnd: HWND;
begin
  UpdateIconSize;
  HasRunning := False;

  Items.BeginUpdate;
  try
    Clear;

    if FFiles = nil then Exit;

    for I := 0 to FFiles.Count - 1 do
    begin
      PreviousState := FFiles[I].RunningState;
      FFiles[I].RunningState := DetectRunningState(FFiles[I], Wnd);
      FFiles[I].WindowHandle := Wnd;
      ListItem := Items.Add;
      ListItem.Caption := FFiles[I].Name;
      ListItem.Data := FFiles[I];
      ListItem.ImageIndex := AddFileIcon(FFiles[I].FileName);
      if (PreviousState <> FFiles[I].RunningState) or
         (FFiles[I].RunningState <> lrsStopped) then
        DoSpeechAppRunningChange(FFiles[I], Wnd);
      if FFiles[I].RunningState <> lrsStopped then HasRunning := True;
    end;
  finally
    Items.EndUpdate;
  end;

  FRunningRefreshTimer.Enabled := HasRunning;
  AdjustNameColumnWidth;
end;

procedure TLauncherListView.RefreshRunningStates;
var
  I: Integer;
begin
  if FFiles = nil then Exit;

  for I := 0 to FFiles.Count - 1 do
    RefreshLauncherItem(FFiles[I]);
end;

procedure TLauncherListView.RefreshLauncherItem(Item: TLauncherListViewItem);
var
  RunningState: TLauncherRunningState;
  Wnd: HWND;
begin
  if (Item = nil) or (not ContainsLauncherItem(Item)) then Exit;

  RunningState := DetectRunningState(Item, Wnd);
  Item.WindowHandle := Wnd;
  if Item.RunningState = RunningState then Exit;

  Item.RunningState := RunningState;
  RedrawLauncherItem(Item);
  DoSpeechAppRunningChange(Item, Wnd);
end;

procedure TLauncherListView.RedrawLauncherItem(Item: TLauncherListViewItem);
var
  I: Integer;
  R: TRect;
begin
  if (Item = nil) or (not HandleAllocated) then Exit;

  for I := 0 to Items.Count - 1 do
  begin
    if Items[I].Data <> Item then Continue;

    if ListView_GetItemRect(Handle, I, R, LVIR_BOUNDS) then
      InvalidateRect(Handle, @R, False)
    else
      ListView_RedrawItems(Handle, I, I);
    Exit;
  end;
end;

procedure TLauncherListView.RunningRefreshTimerTimer(Sender: TObject);
var
  I: Integer;
  HasRunning: Boolean;
begin
  RefreshRunningStates;

  HasRunning := False;
  if FFiles <> nil then
  begin
    for I := 0 to FFiles.Count - 1 do
    begin
      if FFiles[I].RunningState = lrsStopped then
        Continue;

      HasRunning := True;
      Break;
    end;
  end;

  FRunningRefreshTimer.Enabled := HasRunning;
end;

procedure TLauncherListView.StartRunningRefreshTimer;
begin
  FRunningRefreshTimer.Enabled := True;
end;

procedure TLauncherListView.WatchProcessExit(ProcessHandle: THandle;
  Item: TLauncherListViewItem);
var
  TargetHandle: HWND;
begin
  TargetHandle := Handle;
  TThread.CreateAnonymousThread(
    procedure
    begin
      WaitForSingleObject(ProcessHandle, INFINITE);
      CloseHandle(ProcessHandle);
      Sleep(700);
      PostMessage(TargetHandle, WM_LAUNCH_PROCESS_REFRESH, WPARAM(Item), 0);
    end
  ).Start;
end;

procedure TLauncherListView.WatchRunningStateRefresh(
  Item: TLauncherListViewItem; DelayMS: Cardinal);
var
  TargetHandle: HWND;
begin
  if Item = nil then Exit;

  TargetHandle := Handle;
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(DelayMS);
      PostMessage(TargetHandle, WM_LAUNCH_PROCESS_REFRESH, WPARAM(Item), 0);
    end
  ).Start;
end;

procedure TLauncherListView.Resize;
begin
  inherited;
  AdjustNameColumnWidth;
end;

procedure TLauncherListView.LoadFromFile;
begin
  if FFiles = nil then Exit;

  FFiles.LoadFromFile;
  RebuildItems;
end;

procedure TLauncherListView.SaveToFile;
begin
  if FFiles <> nil then FFiles.SaveToFile;
end;

procedure TLauncherListView.SetFiles(const Value: TLauncherListViewList);
begin
  if FFiles = Value then Exit;

  FFiles.Free;
  FFiles := Value;
  RebuildItems;
end;

procedure TLauncherListView.SetZoomIndex(const Value: Integer);
begin
  if Value < Low(ZOOM_TBL)  then Exit;
  if Value > High(ZOOM_TBL) then Exit;
  if FZoomIndex = Value     then Exit;

  FZoomIndex := Value;
  UpdateIconSize;
  RebuildItems;
  if Assigned(FOnZoomChange) then FOnZoomChange(Self, FZoomIndex);
end;

procedure TLauncherListView.WMMouseWheel(var Msg: TWMMouseWheel);
begin
  if GetKeyState(VK_CONTROL) >= 0 then
  begin
    inherited;
    Exit;
  end;

  if Msg.WheelDelta > 0 then
    SetZoomIndex(FZoomIndex + 1)
  else if Msg.WheelDelta < 0 then
    SetZoomIndex(FZoomIndex - 1);

  Msg.Result := 1;
end;

procedure TLauncherListView.WMLaunchProcessExited(var Msg: TMessage);
begin
  RefreshRunningStates;
end;

procedure TLauncherListView.WMLaunchProcessRefresh(var Msg: TMessage);
begin
  RefreshLauncherItem(TLauncherListViewItem(Msg.WParam));
end;

end.

