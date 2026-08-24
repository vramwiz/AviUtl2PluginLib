unit FolderWatch;

{
  Unit Name  : FolderWatch

  概要:
    指定フォルダを監視し、追加・削除・更新を検出してイベント通知する。
    本版では、スレッド→メインスレッドへの通知を Synchronize ではなく
    PostMessage + 内部バッファ方式で行う。

  公開インターフェース（TFolderWatch の public/protected）は
  元のバージョンから変更していません。
}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls;

type
  TFolderWatchEvent = procedure(Sender: TObject; const FileNames: TStringList) of object;
  TFolderWatchAllEvent = procedure(Sender: TObject;
    const AddFiles: TStringList; const DelFiles: TStringList; const UpdateFiles: TStringList) of object;

const
  WM_FOLDERWATCH_NOTIFY = WM_USER + $4200;

type
  TFolderWatchThread = class(TThread)
  private
    FFolderPath        : string;
    FFirstScanDone     : Boolean;
    FIncludeSubFolders : Boolean;
    FNotifyFilter      : DWORD;
    FExtFilters        : TStringList;
    FOwner             : TObject; // TFolderWatch

    FLastSnapshot      : TDictionary<string, TDateTime>;
    FNotificationHandle: THandle;

    procedure ScanAndCompare;
    procedure ScanSearch(CurrentFiles: TDictionary<string, TDateTime>);
    procedure ScanUpdate(CurrentFiles: TDictionary<string, TDateTime>);
    procedure ScanDone;
    function  IsVisible(const FileName: string): Boolean;
    procedure NotifyChanges(const AddList, DelList, ModList: TStringList);
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TObject);
    destructor Destroy; override;
  end;

type
  TFolderWatch = class(TPersistent)
  private
    { Private 宣言 }
    FFolderPath        : string;
    FIncludeSubFolders : Boolean;
    FNotifyFilter      : DWORD;
    FThread            : TFolderWatchThread;
    FOnFileChange      : TFolderWatchAllEvent;
    FOnFileAdd         : TFolderWatchEvent;
    FOnFileDelete      : TFolderWatchEvent;
    FOnFileUpdate      : TFolderWatchEvent;
    FFirstScanDone     : Boolean;
    FExtFilters        : TStringList;

    // ★ メッセージ通知用
    FMsgWnd     : HWND;
    FAddBuffer  : TStringList;
    FDelBuffer  : TStringList;
    FModBuffer  : TStringList;

    procedure StartWatching;
    procedure StopWatching;
    procedure RestartWatchingIfRunning(const Action: TProc);
    procedure SetFolderPath(const Value: string);
    procedure SetIncludeSubFolders(const Value: Boolean);
    procedure SetNotifyFilter(const Value: DWORD);
    procedure SetFirstScanDone(const Value: Boolean);

    procedure WndProc(var Msg: TMessage);
  protected
    procedure DoFileAdd(const FileNames: TStringList);
    procedure DoFileDelete(const FileNames: TStringList);
    procedure DoFileUpdate(const FileNames: TStringList);
    procedure DoFileChange(const AddFiles: TStringList; const DelFiles: TStringList; const UpdateFiles: TStringList);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property FolderPath: string read FFolderPath write SetFolderPath;
    property IncludeSubFolders: Boolean read FIncludeSubFolders write SetIncludeSubFolders;
    property NotifyFilter: DWORD read FNotifyFilter write SetNotifyFilter;
    // 初回はイベントを発生させない
    property FirstScanDone : Boolean read FFirstScanDone write SetFirstScanDone;
    // 拡張子フィルター ※設定後再起動が必要
    property ExtFilters: TStringList read FExtFilters;
    property OnFileChange: TFolderWatchAllEvent read FOnFileChange write FOnFileChange;
    property OnFileAdd: TFolderWatchEvent       read FOnFileAdd    write FOnFileAdd;
    property OnFileDelete: TFolderWatchEvent    read FOnFileDelete write FOnFileDelete;
    property OnFileUpdate: TFolderWatchEvent    read FOnFileUpdate write FOnFileUpdate;
  end;

implementation

uses System.IOUtils;

const
  MinTimeGapSec = 1.0; // 1秒以内の変更は無視

{ TFolderWatch }

constructor TFolderWatch.Create;
begin
  inherited Create;

  // 初期値
  FFolderPath := '';
  FIncludeSubFolders := False;

  FExtFilters := TStringList.Create;
  FExtFilters.CaseSensitive := False;

  // 初期登録（必要なら外部から追加／削除可能）
  FExtFilters.Add('.crdownload');
  FExtFilters.Add('.tmp');
  FExtFilters.Add('.part');
  FNotifyFilter := FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_LAST_WRITE;

  // バッファ
  FAddBuffer := TStringList.Create;
  FDelBuffer := TStringList.Create;
  FModBuffer := TStringList.Create;

  // メッセージ受信用の隠しウィンドウ
  FMsgWnd := AllocateHWnd(WndProc);
end;

destructor TFolderWatch.Destroy;
begin
  StopWatching;

  if FMsgWnd <> 0 then
    DeallocateHWnd(FMsgWnd);

  FAddBuffer.Free;
  FDelBuffer.Free;
  FModBuffer.Free;
  FExtFilters.Free;

  inherited Destroy;
end;

procedure TFolderWatch.Start;
begin
  StartWatching;
end;

procedure TFolderWatch.Stop;
begin
  StopWatching;
end;

procedure TFolderWatch.StartWatching;
begin
  if Assigned(FThread) then
    Exit; // すでに開始されていれば無視

  FThread := TFolderWatchThread.Create(Self);
  FThread.FFolderPath        := FFolderPath;
  FThread.FIncludeSubFolders := FIncludeSubFolders;
  FThread.FNotifyFilter      := FNotifyFilter;
  FThread.FreeOnTerminate    := False;
  FThread.FFirstScanDone     := FFirstScanDone;
  FThread.FExtFilters.Assign(FExtFilters);
  FThread.Start;
end;

procedure TFolderWatch.StopWatching;
begin
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
end;

procedure TFolderWatch.SetFirstScanDone(const Value: Boolean);
begin
  FFirstScanDone := Value;
end;

procedure TFolderWatch.SetFolderPath(const Value: string);
begin
  if SameText(FFolderPath, Value) then Exit;

  RestartWatchingIfRunning(
    procedure
    begin
      FFolderPath := Value;
    end);
end;

procedure TFolderWatch.SetIncludeSubFolders(const Value: Boolean);
begin
  if FIncludeSubFolders = Value then Exit;

  RestartWatchingIfRunning(
    procedure
    begin
      FIncludeSubFolders := Value;
    end);
end;

procedure TFolderWatch.SetNotifyFilter(const Value: DWORD);
begin
  if FNotifyFilter = Value then
    Exit;

  RestartWatchingIfRunning(
    procedure
    begin
      FNotifyFilter := Value;
    end);
end;

procedure TFolderWatch.RestartWatchingIfRunning(const Action: TProc);
var
  WasRunning: Boolean;
begin
  WasRunning := Assigned(FThread) and (FThread.Finished = False);
  if WasRunning then
    StopWatching;

  Action(); // 値の変更

  if WasRunning then
    StartWatching;
end;

procedure TFolderWatch.DoFileAdd(const FileNames: TStringList);
begin
  if Assigned(FOnFileAdd) then FOnFileAdd(Self, FileNames);
end;

procedure TFolderWatch.DoFileUpdate(const FileNames: TStringList);
begin
  if Assigned(FOnFileUpdate) then FOnFileUpdate(Self, FileNames);
end;

procedure TFolderWatch.DoFileDelete(const FileNames: TStringList);
begin
  if Assigned(FOnFileDelete) then FOnFileDelete(Self, FileNames);
end;

procedure TFolderWatch.DoFileChange(const AddFiles, DelFiles,UpdateFiles: TStringList);
begin
  if Assigned(FOnFileChange) then FOnFileChange(Self,AddFiles, DelFiles,UpdateFiles);
end;

procedure TFolderWatch.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = WM_FOLDERWATCH_NOTIFY then
  begin
    // メインスレッド側でイベント発火
    DoFileChange(FAddBuffer, FDelBuffer, FModBuffer);

    if FAddBuffer.Count > 0 then
      DoFileAdd(FAddBuffer);
    if FDelBuffer.Count > 0 then
      DoFileDelete(FDelBuffer);
    if FModBuffer.Count > 0 then
      DoFileUpdate(FModBuffer);
  end
  else
    Msg.Result := DefWindowProc(FMsgWnd, Msg.Msg, Msg.WParam, Msg.LParam);
end;


{ TFolderWatchThread }

constructor TFolderWatchThread.Create(AOwner: TObject);
begin
  inherited Create(True); // Suspended=True（Startは外で呼ぶ）

  FreeOnTerminate := False; // 明示的に解放する想定
  FOwner := AOwner;

  FFolderPath := '';
  FIncludeSubFolders := False;
  FNotifyFilter := FILE_NOTIFY_CHANGE_FILE_NAME or
                   FILE_NOTIFY_CHANGE_LAST_WRITE or
                   FILE_NOTIFY_CHANGE_SIZE;

  FExtFilters := TStringList.Create;
  FNotificationHandle := 0;
  FLastSnapshot := TDictionary<string, TDateTime>.Create;
end;

destructor TFolderWatchThread.Destroy;
begin
  if FNotificationHandle <> 0 then
  begin
    FindCloseChangeNotification(FNotificationHandle);
    FNotificationHandle := 0;
  end;

  FLastSnapshot.Free;
  FExtFilters.Free;
  inherited;
end;

procedure TFolderWatchThread.Execute;
begin
  FNotificationHandle := FindFirstChangeNotification(
    PChar(FFolderPath),
    FIncludeSubFolders,
    FNotifyFilter
  );

  if FNotificationHandle = INVALID_HANDLE_VALUE then
    Exit;

  if FFirstScanDone then begin
    ScanDone();
  end;

  try
    // 初回スナップショット作成
    ScanAndCompare;

    while not Terminated do
    begin
      // 変更が通知されるまで待機
      case WaitForSingleObject(FNotificationHandle, 500) of
        WAIT_OBJECT_0:
        begin
          if Terminated then Break;
          Sleep(500);             // 追加・削除・変更の誤検出を避けるため、通知後に少し待つ
          ScanAndCompare;         // DL完了 or メタデータ更新の余波を吸収する

          // 次の通知を再設定
          if not FindNextChangeNotification(FNotificationHandle) then
            Break;
        end;

        WAIT_FAILED:
          Break;
      end;
    end;

  finally
    if FNotificationHandle <> 0 then
    begin
      FindCloseChangeNotification(FNotificationHandle);
      FNotificationHandle := 0;
    end;
  end;
end;

function TFolderWatchThread.IsVisible(const FileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := FExtFilters.IndexOf(Ext) = -1; // フィルターに含まれていなければ表示対象
end;

procedure TFolderWatchThread.NotifyChanges(const AddList, DelList,
  ModList: TStringList);
var
  Owner: TFolderWatch;
begin
  if not (FOwner is TFolderWatch) then
    Exit;

  Owner := TFolderWatch(FOwner);

  // ★ スレッド内で TFolderWatch のバッファにコピーするだけ
  Owner.FAddBuffer.Assign(AddList);
  Owner.FDelBuffer.Assign(DelList);
  Owner.FModBuffer.Assign(ModList);

  // ★ メインスレッドに「変化あり」を通知（データはバッファ経由）
  PostMessage(Owner.FMsgWnd, WM_FOLDERWATCH_NOTIFY, 0, 0);
end;

procedure TFolderWatchThread.ScanAndCompare;
var
  CurrentFiles: TDictionary<string, TDateTime>;
  AddList, DelList, ModList: TStringList;
  Pair: TPair<string, TDateTime>;
  Value: TDateTime;
begin
  CurrentFiles := TDictionary<string, TDateTime>.Create;
  AddList := TStringList.Create;
  DelList := TStringList.Create;
  ModList := TStringList.Create;
  try
    // 再帰しない単純な走査（再帰対応はあとで改良可）
    ScanSearch(CurrentFiles);

    // 追加／更新チェック
    for Pair in CurrentFiles do
    begin
      if not FLastSnapshot.TryGetValue(Pair.Key, Value) then
      begin
        AddList.Add(Pair.Key); // 新規追加
      end
      else if (FLastSnapshot[Pair.Key] <> Pair.Value) and
              ((Now - FLastSnapshot[Pair.Key]) * 86400 > MinTimeGapSec) then
      begin
        ModList.Add(Pair.Key); // 更新あり
      end;
    end;

    // 削除チェック
    for Pair in FLastSnapshot do
    begin
      if not CurrentFiles.ContainsKey(Pair.Key) then
        DelList.Add(Pair.Key);
    end;

    // 通知実行
    NotifyChanges(AddList, DelList, ModList);

    // 現在の情報を保存
    ScanUpdate(CurrentFiles);

  finally
    AddList.Free;
    DelList.Free;
    ModList.Free;
    CurrentFiles.Free;
  end;
end;

procedure TFolderWatchThread.ScanSearch(
  CurrentFiles: TDictionary<string, TDateTime>);
var
  SearchRec: TSearchRec;
  FilePath: string;
begin
  // 再帰しない単純な走査（再帰対応はあとで改良可）
  if FindFirst(IncludeTrailingPathDelimiter(FFolderPath) + '*.*', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        if not IsVisible(SearchRec.Name) then Continue;   // 監視対象か判断
        FilePath := IncludeTrailingPathDelimiter(FFolderPath) + SearchRec.Name;
        CurrentFiles.Add(FilePath, SearchRec.TimeStamp);  // Delphi10以降対応
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
end;

procedure TFolderWatchThread.ScanUpdate(
  CurrentFiles: TDictionary<string, TDateTime>);
var
  Pair: TPair<string, TDateTime>;
begin
  FLastSnapshot.Clear;
  for Pair in CurrentFiles do begin
    if not IsVisible(Pair.Key) then Continue;   // 監視対象か判断
    FLastSnapshot.Add(Pair.Key, Pair.Value);
  end;
end;

procedure TFolderWatchThread.ScanDone;
var
  CurrentFiles: TDictionary<string, TDateTime>;
begin
  CurrentFiles := TDictionary<string, TDateTime>.Create;
  try
    ScanSearch(CurrentFiles);
    ScanUpdate(CurrentFiles);
  finally
    CurrentFiles.Free;
  end;
end;

end.

