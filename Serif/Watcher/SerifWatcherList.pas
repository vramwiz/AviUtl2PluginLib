unit SerifWatcherList;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  System.IOUtils,
  Vcl.ExtCtrls,FolderWatch,RTTIPersistentIni;

//--------------------------------------------------------------------------//
//   変更のあったファイルリストを通知するイベント                          //
//--------------------------------------------------------------------------//
type
  TSerifVoiceWatcherEvent = procedure(Sender: TObject; Files: TStringList;var ErrLine : Integer) of object;

//--------------------------------------------------------------------------//
//  アプリが出力するフォルダを管理するクラス                                //
//--------------------------------------------------------------------------//
type
  TSerifWatcherItem = class(TRTTIPersistentIni)
  private
    { Private 宣言 }
    FName         : string;          // 監視対象の名称
    FFolder       : string;          // 監視フォルダ
    FDelaySec     : Double;          // 出力終了判定用タイマー値
    FErrLine      : Integer;         // 解析エラーを出した行
    FReadyPending : Boolean;         // ペア成立後にもう一度静寂待ちするフラグ

    FWatch        : TFolderWatch;    // フォルダ監視クラス
    FTimer        : TTimer;          // 静寂待ちタイマー
    FFileBefores  : TStringList;     // 監視前のファイルリスト
    FFileAfters   : TStringList;     // 監視後のファイルリスト
    FFileChanges  : TStringList;     // 変更のあったファイル（旧）
    FChangeOrder  : TStringList;     // 出力順（追加／更新イベントの順番）

    FOnDetectedFiles : TSerifVoiceWatcherEvent;
    FOnWaitFiles: TNotifyEvent;

    // 指定したフォルダ内のファイル一覧を List に取得
    procedure LoadFilesToList(List: TStringList);

    // TFolderWatch のイベント
    procedure OnFileChange(Sender: TObject;const AddNames: TStringList; const DelNames: TStringList; const ChangeNames: TStringList);

    // 出力順に記録（重複は最新位置に移動）
    procedure AddChangeInOrder(const FileName: string);
    // 指定ファイルが DelaySec より古く、書き込み完了状態か判定
    function IsFileStable(const FileName: string): Boolean;
    // 保留中の txt/wav がすべて揃っているか判定
    function AreTxtWavPairsReady(const Files: TStringList): Boolean;

    // タイマー静寂 → 処理フェーズ
    procedure OnTimerTimeout(Sender: TObject);

    // 静寂後の解析フェーズ
    procedure ProcessChanges;
  protected
     procedure DoDetecredFiles(Files: TStringList;var ErrLine : Integer);
     procedure DoWaitFiles();
  public
    constructor Create;
    destructor Destroy; override;

    procedure Start;
    procedure Stop;
    // ファイル追加変更イベント　このあと落ち着くまで待つ
    property OnWaitFiles : TNotifyEvent  read FOnWaitFiles write FOnWaitFiles;
    // 完了イベント
    property OnDetectedFiles : TSerifVoiceWatcherEvent  read FOnDetectedFiles write FOnDetectedFiles;
  published
    property Name      : string  read FName      write FName;
    property Folder    : string  read FFolder    write FFolder;
    property DelaySec  : Double  read FDelaySec  write FDelaySec;
  end;

//--------------------------------------------------------------------------//
//   リストクラス                                                             //
//--------------------------------------------------------------------------//
  TSerifWatcherList = class(TRTTIPersistentIniList<TSerifWatcherItem>)
  private
    FIsStartd : Boolean;
    FOnDetectedFiles : TSerifVoiceWatcherEvent;
    FOnWaitFiles     : TNotifyEvent;
    procedure OnSelfDetecredFiles(Sender: TObject; Files: TStringList;var ErrLine : Integer);
    procedure OnSelfWaitFiles(Sender: TObject);
    function GetWatchers(Index: Integer): TSerifWatcherItem;
  protected
     procedure DoDetecredFiles(Files: TStringList;var ErrLine : Integer);
     procedure DoWaitFiles();
  public
    procedure Start;
    procedure Stop;
    property Watchers[Index : Integer] : TSerifWatcherItem read GetWatchers;
    property IsStartd : Boolean read FIsStartd;
    property OnDetectedFiles : TSerifVoiceWatcherEvent  read FOnDetectedFiles write FOnDetectedFiles;
    // ファイル追加変更イベント　このあと落ち着くまで待つ
    property OnWaitFiles : TNotifyEvent  read FOnWaitFiles write FOnWaitFiles;
  end;



implementation

{ TSerifWatcherList }

function HasLeadingIndexHyphen(const FileName: string): Boolean;
var
  BaseName: string;
  P: Integer;
  IndexValue: Integer;
begin
  BaseName := ChangeFileExt(ExtractFileName(FileName), '');
  P := Pos('-', BaseName);
  Result := (P > 1) and TryStrToInt(Copy(BaseName, 1, P - 1), IndexValue);
end;

procedure TSerifWatcherList.DoDetecredFiles(Files: TStringList;var ErrLine : Integer);
begin
  if Assigned(FOnDetectedFiles) then  FOnDetectedFiles(Self, Files,ErrLine);
end;

procedure TSerifWatcherList.DoWaitFiles;
begin
  if Assigned(FOnWaitFiles) then  FOnWaitFiles(Self);
end;

function TSerifWatcherList.GetWatchers(Index: Integer): TSerifWatcherItem;
begin
  Result := TSerifWatcherItem(inherited Items[Index]);
end;


procedure TSerifWatcherList.OnSelfDetecredFiles(Sender: TObject;  Files: TStringList;var ErrLine : Integer);
begin
  DoDetecredFiles(Files,ErrLine);
end;

procedure TSerifWatcherList.OnSelfWaitFiles(Sender: TObject);
begin
  DoWaitFiles();
end;

procedure TSerifWatcherList.Start;
var
  i : Integer;
begin
  FIsStartd := True;
  for i := 0 to Count-1 do begin
    Watchers[i].OnDetectedFiles := OnSelfDetecredFiles;
    Watchers[i].OnWaitFiles := OnSelfWaitFiles;
    Watchers[i].Start();
  end;
end;

procedure TSerifWatcherList.Stop;
var
  i : Integer;
begin
  FIsStartd := False;
  for i := 0 to Count-1 do begin
    Watchers[i].Stop();
  end;
end;

{ TSerifWatcherItem }

constructor TSerifWatcherItem.Create;
begin
  inherited Create;

  FFileBefores := TStringList.Create;
  FFileAfters  := TStringList.Create;
  FFileChanges := TStringList.Create;
  FChangeOrder := TStringList.Create;

  FWatch := TFolderWatch.Create;
  FWatch.OnFileChange := OnFileChange;

  FDelaySec := 0.5;

  // 静寂待ち用タイマー（最初は無効）
  FTimer := TTimer.Create(nil);
  FTimer.Enabled  := False;
  FTimer.OnTimer  := OnTimerTimeout;
end;

destructor TSerifWatcherItem.Destroy;
begin
  FTimer.Free;
  FWatch.Free;
  FChangeOrder.Free;
  FFileChanges.Free;
  FFileAfters.Free;
  FFileBefores.Free;
  inherited;
end;

procedure TSerifWatcherItem.DoDetecredFiles(Files: TStringList;var ErrLine : Integer);
begin
  if Assigned(FOnDetectedFiles) then  FOnDetectedFiles(Self, Files,ErrLine);
end;

procedure TSerifWatcherItem.DoWaitFiles;
begin
  if Assigned(FOnWaitFiles) then  FOnWaitFiles(Self);
end;

procedure TSerifWatcherItem.Start;
begin
  FErrLine := -2;
  FReadyPending := False;
  FTimer.Interval := Round(FDelaySec * 1000);     // 秒 → ミリ秒に変換して四捨五入
  // 最初の監視前ファイル一覧
  LoadFilesToList(FFileBefores);

  FWatch.FolderPath := FFolder;
  FWatch.FirstScanDone := True;
  FWatch.Start;
end;

procedure TSerifWatcherItem.Stop;
begin
  FWatch.Stop;
  FTimer.Enabled := False;
end;

procedure TSerifWatcherItem.LoadFilesToList(List: TStringList);
var
  SR: TSearchRec;
  Path: string;
begin
  if List = nil then Exit;

  List.Clear;
  Path := IncludeTrailingPathDelimiter(FFolder);

  if FindFirst(Path + '*.*', faAnyFile and not faDirectory, SR) = 0 then
  begin
    try
      repeat
        List.Add(Path + SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;



//--------------------------------------------------------------------------//
//  フォルダ変化イベント（Watching フェーズ）                                 //
//--------------------------------------------------------------------------//
procedure TSerifWatcherItem.OnFileChange(Sender: TObject;
  const AddNames, DelNames, ChangeNames: TStringList);
var
  i: Integer;
begin
  // タイマーを再スタート（＝まだ変化が続いている）
  FTimer.Enabled := False;
  FTimer.Enabled := True;
  FReadyPending := False;

  // 出力順を保存（追加・変更のみ）
  for i := 0 to AddNames.Count - 1 do
    AddChangeInOrder(AddNames[i]);

  for i := 0 to ChangeNames.Count - 1 do
    AddChangeInOrder(ChangeNames[i]);

  // 追加変化が合った場合落ち着くまで待機を通知
  if (AddNames.Count>0) or (ChangeNames.Count>0) then begin
    DoWaitFiles();
  end;

end;



//--------------------------------------------------------------------------//
//  出力順記録（同じファイルは最新位置に移動）                               //
//--------------------------------------------------------------------------//
procedure TSerifWatcherItem.AddChangeInOrder(const FileName: string);
var
  idx: Integer;
begin
  idx := FChangeOrder.IndexOf(FileName);
  if idx >= 0 then
    FChangeOrder.Delete(idx);

  FChangeOrder.Add(FileName);
end;

function TSerifWatcherItem.IsFileStable(const FileName: string): Boolean;
var
  LastWrite: TDateTime;
begin
  Result := False;
  if FileName = '' then Exit;
  if not TFile.Exists(FileName) then Exit;

  try
    LastWrite := TFile.GetLastWriteTime(FileName);
  except
    Exit;
  end;

  Result := ((Now - LastWrite) * 24 * 60 * 60) >= FDelaySec;
end;

function TSerifWatcherItem.AreTxtWavPairsReady(const Files: TStringList): Boolean;
var
  i: Integer;
  FileName: string;
  Ext: string;
  PairName: string;
  HasIndexedSequentialFiles: Boolean;
begin
  Result := True;
  if Files = nil then Exit;

  HasIndexedSequentialFiles := False;
  for i := 0 to Files.Count - 1 do
  begin
    Ext := LowerCase(ExtractFileExt(Files[i]));
    if (Ext <> '.txt') and (Ext <> '.wav') then
      Continue;
    if not HasLeadingIndexHyphen(Files[i]) then
      Continue;
    HasIndexedSequentialFiles := True;
    Break;
  end;

  // 対象の txt/wav が両方存在し、両方とも DelaySec 以上更新されていないか確認する
  for i := 0 to Files.Count - 1 do
  begin
    FileName := Files[i];
    Ext := LowerCase(ExtractFileExt(FileName));
    if (Ext <> '.txt') and (Ext <> '.wav') then
      Continue;

    if Ext = '.txt' then
      PairName := ChangeFileExt(FileName, '.wav')
    else
      PairName := ChangeFileExt(FileName, '.txt');

    if FFileAfters.IndexOf(PairName) >= 0 then
    begin
      if IsFileStable(FileName) and IsFileStable(PairName) then
        Continue;
    end;

    if HasIndexedSequentialFiles and (not HasLeadingIndexHyphen(FileName)) then
      Continue;

    Result := False;
    Exit;
  end;
end;



//--------------------------------------------------------------------------//
//  静寂タイマー発火 → PROCESSING フェーズへ                                  //
//--------------------------------------------------------------------------//
procedure TSerifWatcherItem.OnTimerTimeout(Sender: TObject);
begin
  FTimer.Enabled := False;
  ProcessChanges;
end;



//--------------------------------------------------------------------------//
//  解析（変化収束後）                                                        //
//--------------------------------------------------------------------------//
procedure TSerifWatcherItem.ProcessChanges;
var
  FinalList : TStringList;
  i: Integer;
  FileName : string;
begin
  // 現在のフォルダ内容を取得
  LoadFilesToList(FFileAfters);

  FinalList := TStringList.Create;
  try
    // 出力順に沿って、現在存在するファイルだけを抽出
    for i := 0 to FChangeOrder.Count - 1 do
    begin
      FileName := FChangeOrder[i];
      if FFileAfters.IndexOf(FileName) >= 0 then
        FinalList.Add(FileName);
    end;

    // txt/wav が未完成な間は通知せず、変更リストを保持したまま待機を続ける
    if not AreTxtWavPairsReady(FinalList) then
    begin
      FReadyPending := False;
      DoWaitFiles();
      FTimer.Enabled := False;
      FTimer.Enabled := True;
      Exit;
    end;

    // ペア成立直後はもう一度 DelaySec 待ち、追加入力が止まったことを確認する
    if not FReadyPending then
    begin
      FReadyPending := True;
      DoWaitFiles();
      FTimer.Enabled := False;
      FTimer.Enabled := True;
      Exit;
    end;

    // ユーザーへ通知（コピー渡し）
    DoDetecredFiles(FinalList,i);
    FReadyPending := False;
    if i <> -1 then begin                // エラーの場合
      if i > FErrLine then begin         // 前回のエラーと異なる場合
        FErrLine := i;                   // エラー行を記憶
        FTimer.Enabled := False;
        FTimer.Enabled := True;          // タイマー開始
      end;
    end;
    FErrLine := -2;                      // エラー位置をリセット

  finally
    FinalList.Free;
  end;

  // 次回に備えてクリア
  FChangeOrder.Clear;
  FFileBefores.Assign(FFileAfters);
end;

end.

