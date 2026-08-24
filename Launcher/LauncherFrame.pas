unit LauncherFrame;

// ランチャー一覧と登録ウィザードの画面遷移を管理する親フレームユニット。
interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus,
  LauncherListFrame,LauncherWizardFrame,LauncherListView,LauncherGlobalHotkeys,
  RTTIPersistentFrame;

type
  TFrameLauncherSpeechAppEvent = procedure(Sender: TObject;
    AppKind: Integer; Wnd: HWND; RunningState: TLauncherRunningState) of object;

type
  TFrameLauncherBound = class(TRTTIFrame)
  private
    FListZoomIndex    : Integer;
  public
    constructor Create;
    // フレームが管理するコンポーネントをデータ化
    procedure FrameToSelf(AFrame : TFrame);override;
    // データをフレームの情報に復元
    procedure SelfToFrame(AFrame : TFrame);override;
  published
    property ListZoomIndex  : Integer read FListZoomIndex  write FListZoomIndex;
  end;

type
  TFrameLauncher = class(TFrame)
  private
    { Private 宣言 }
    FBound         : TFrameLauncherBound;                // Window位置保存クラス
    FBoundLoaded   : Boolean;                        // True:初回表示時の位置・拡大率復元済み
    FListLoaded    : Boolean;                        // True:ランチャー一覧読み込み済み
    FFrameListView : TFrameLauncherList; // ランチャーリスト画面。
    FFrameWizard   : TFrameLauncherWizard; // 登録用ウイザード画面。
    FGlobalHotkeys : TLauncherGlobalHotkeys; // Ctrl+Alt+数字のグローバルショートカット。
    FSwitchIndex   : Integer; // Ctrl+Alt+0 の前回成功した巡回位置。
    FOnSpeechAppRunningChange: TFrameLauncherSpeechAppEvent; // 音声合成ソフト起動状態通知。
    // ウィザードで選択したアプリを登録する。
    procedure RegisterApplication(Sender: TObject; const FileName: string);
    // ランチャーリスト画面へ切り替える。
    procedure ShowLauncherList;
    // 登録ウィザード画面へ切り替える。
    procedure ShowWizard(Sender: TObject);
    // ウィザードのキャンセルを受けて一覧へ戻る。
    procedure WizardCancel(Sender: TObject);
    // ランチャー一覧のズーム変更を保存する。
    procedure OnListZoomChange(Sender: TObject; ZoomIndex: Integer);
    // 現在のランチャー表示状態を保存する。
    procedure SaveBound;
    // ランチャー一覧ファイルを初回だけ読み込む。
    procedure EnsureListLoaded;
    // ランチャー一覧からの音声合成ソフト起動状態通知を中継する。
    procedure OnListSpeechAppRunningChange(Sender: TObject; AppKind: Integer;
      Wnd: HWND; RunningState: TLauncherRunningState);
    // Ctrl+Alt+数字のグローバルショートカットを処理する。
    procedure OnGlobalHotkey(Sender: TObject; KeyNumber: Integer);
    // ランチャー一覧の指定インデックスをアクティブ化、または設定により起動する。
    function ExecuteLauncherIndex(Index: Integer): Boolean;
    // ランチャー一覧を若い順に切り替える。
    function SwitchNextLauncher: Boolean;
  public
    { Public 宣言 }
    // 親フレームを初期化する。
    constructor Create(AOwner: TComponent); override;
    // 親フレームを破棄する。
    destructor Destroy;override;
    // ランチャーリストを表示する。
    procedure Show;
    // グローバルショートカットを有効化する。
    procedure EnableGlobalHotkeys;
    // 起動中状態を再判定して表示へ反映する。
    procedure RefreshRunningStates;
    // ドロップされたファイルをランチャー一覧へ渡す。
    function DropFiles(const Files: TArray<string>) : Boolean;
    property FrameListView : TFrameLauncherList read  FFrameListView;
    property OnSpeechAppRunningChange: TFrameLauncherSpeechAppEvent read FOnSpeechAppRunningChange write FOnSpeechAppRunningChange;
  end;

implementation

uses AppFolderUtils;

{$R *.dfm}

constructor TFrameLauncher.Create(AOwner: TComponent);
var
  s : string;
begin
  inherited;

  s :=  GetAppFolder('Launcher');
  FBound := TFrameLauncherBound.Create;
  FBound.Filename  := s +  'LauncherFrame.ini';       // Windows状態保存ファイル名設定
  // 起動直後は AviUtl2 が前面にいる想定なので、初回 Ctrl+Alt+0 は次の巡回先から始める。
  if GLOBAL_LAUNCHER_HOTKEYS_INCLUDE_AVIUTL2_IN_SWITCHING then
    FSwitchIndex := 0
  else
    FSwitchIndex := -1;

  FFrameListView := TFrameLauncherList.Create(Self);
  FFrameListView.Parent := Self;
  FFrameListView.Align := alClient;
  FFrameListView.OnAddRequest := ShowWizard;
  FFrameListView.ListView.OnZoomChange := OnListZoomChange;
  FFrameListView.ListView.OnSpeechAppRunningChange := OnListSpeechAppRunningChange;
  FFrameListView.ListView.FileList.Filename := s + 'LauncherList.ini';

  FFrameWizard := TFrameLauncherWizard.Create(Self);
  FFrameWizard.Parent := Self;
  FFrameWizard.Align := alClient;
  FFrameWizard.Visible := False;
  FFrameWizard.OnCancel := WizardCancel;
  FFrameWizard.OnRegister := RegisterApplication;
  FFrameWizard.RegisteredList := FFrameListView.ListView.FileList;

  FGlobalHotkeys := TLauncherGlobalHotkeys.Create;
  FGlobalHotkeys.OnHotkey := OnGlobalHotkey;
  // 親フレーム側から先行生成された時点で、ショートカットを使える状態にする。
  EnableGlobalHotkeys;
end;

destructor TFrameLauncher.Destroy;
begin
  SaveBound;
  FGlobalHotkeys.Free;
  FFrameWizard.Free;
  FFrameListView.Free;
  FBound.Free;
  inherited;
end;

{ TFrame1 }

function TFrameLauncher.DropFiles(const Files: TArray<string>): Boolean;
begin
  EnsureListLoaded;
  Result := FFrameListView.DropFiles(Files);
end;

procedure TFrameLauncher.EnableGlobalHotkeys;
begin
  if FGlobalHotkeys <> nil then
    FGlobalHotkeys.Enable;
end;

procedure TFrameLauncher.EnsureListLoaded;
begin
  if FListLoaded then
    Exit;

  FListLoaded := True;
  FFrameListView.ListView.LoadFromFile;
end;

function TFrameLauncher.ExecuteLauncherIndex(Index: Integer): Boolean;
var
  Item: TLauncherListViewItem;
begin
  Result := False;

  // ホットキーはフレーム表示前にも来るため、ここで必ず一覧を読み込む。
  EnsureListLoaded;

  if (FFrameListView = nil) or (FFrameListView.ListView = nil) then
    Exit;
  if FFrameListView.ListView.FileList = nil then
    Exit;

  // Ctrl+Alt+2 が index 0。範囲外の数字は何もしない。
  if (Index < 0) or (Index >= FFrameListView.ListView.FileList.Count) then
    Exit;

  Item := FFrameListView.ListView.FileList[Index];

  // グローバルショートカットの主目的は「起動中アプリを前面へ出す」こと。
  // 未起動アプリはここでは起動しない。
  Result := FFrameListView.ListView.ActivateItem(Item);
end;

procedure TFrameLauncher.RegisterApplication(Sender: TObject;
  const FileName: string);
begin
  EnsureListLoaded;
  FFrameListView.ListView.AddFile(FileName);
  FFrameListView.ListView.SaveToFile;
  FFrameListView.ListView.LoadFromFile;
  ShowLauncherList;
end;

procedure TFrameLauncher.RefreshRunningStates;
begin
  EnsureListLoaded;
  FFrameListView.RefreshRunningStates;
end;

procedure TFrameLauncher.SaveBound;
begin
  if (FBound = nil) or (FFrameListView = nil) then
    Exit;

  FBound.FrameToSelf(Self);
  FBound.SaveToFile;
end;

procedure TFrameLauncher.Show;
begin
  inherited Show;
  EnableGlobalHotkeys;
  EnsureListLoaded;
  ShowLauncherList;
  if not FBoundLoaded then
  begin
    FBound.LoadFromFile;
    FBound.SelfToFrame(Self);
    FBoundLoaded := True;
  end;

end;

procedure TFrameLauncher.ShowLauncherList;
begin
  FFrameWizard.Hide;
  FFrameListView.Show;
  FFrameListView.BringToFront;
end;

procedure TFrameLauncher.ShowWizard(Sender: TObject);
begin
  FFrameWizard.RegisteredList := FFrameListView.ListView.FileList;
  FFrameListView.Hide;
  FFrameWizard.Show;
  FFrameWizard.BringToFront;
end;

procedure TFrameLauncher.WizardCancel(Sender: TObject);
begin
  ShowLauncherList;
end;

procedure TFrameLauncher.OnListZoomChange(Sender: TObject; ZoomIndex: Integer);
begin
  if not FBoundLoaded then
    Exit;

  SaveBound;
end;

procedure TFrameLauncher.OnListSpeechAppRunningChange(Sender: TObject;
  AppKind: Integer; Wnd: HWND; RunningState: TLauncherRunningState);
begin
  if Assigned(FOnSpeechAppRunningChange) then
    FOnSpeechAppRunningChange(Self, AppKind, Wnd, RunningState);
end;

procedure TFrameLauncher.OnGlobalHotkey(Sender: TObject; KeyNumber: Integer);
begin
  case KeyNumber of
    0:
      // Ctrl+Alt+0 は設定に従って AviUtl2 と登録アプリを若い順に切り替える。
      SwitchNextLauncher;
    1:
      // Ctrl+Alt+1 はホスト側の aviutl2.exe を直接前面へ出す。
      ActivateAviUtl2Window;
    2..9:
      // Ctrl+Alt+2 以降はランチャーの index 0 から対応する。
      ExecuteLauncherIndex(KeyNumber - 2);
  end;
end;

function TFrameLauncher.SwitchNextLauncher: Boolean;
var
  Count: Integer;
  Offset: Integer;
  Index: Integer;
  CycleCount: Integer;
  CycleIndex: Integer;
begin
  Result := False;
  EnsureListLoaded;

  if (FFrameListView = nil) or (FFrameListView.ListView = nil) then
    Exit;
  if FFrameListView.ListView.FileList = nil then
    Exit;

  Count := FFrameListView.ListView.FileList.Count;
  CycleCount := Count;
  if GLOBAL_LAUNCHER_HOTKEYS_INCLUDE_AVIUTL2_IN_SWITCHING then
    Inc(CycleCount);
  if CycleCount <= 0 then
    Exit;

  for Offset := 1 to CycleCount do
  begin
    // 前回成功位置の次から巡回し、起動中でアクティブ化できた項目で止める。
    CycleIndex := (FSwitchIndex + Offset) mod CycleCount;

    if GLOBAL_LAUNCHER_HOTKEYS_INCLUDE_AVIUTL2_IN_SWITCHING then
    begin
      // 巡回位置 0 は aviutl2.exe、1 以降はランチャー index 0 から対応する。
      if CycleIndex = 0 then
      begin
        if not ActivateAviUtl2Window then
          Continue;
      end
      else
      begin
        Index := CycleIndex - 1;
        if not ExecuteLauncherIndex(Index) then
          Continue;
      end;
    end
    else
    begin
      // AviUtl2 を巡回しない場合は、従来通りランチャー index だけを回す。
      Index := CycleIndex;
      if not ExecuteLauncherIndex(Index) then
        Continue;
    end;

    FSwitchIndex := CycleIndex;
    Result := True;
    Exit;
  end;
end;

{ TFrameLauncherBound }

constructor TFrameLauncherBound.Create;
begin
  FListZoomIndex := 2;
end;

procedure TFrameLauncherBound.FrameToSelf(AFrame: TFrame);
begin
  FListZoomIndex  := TFrameLauncher(AFrame).FFrameListView.ListView.ZoomIndex;
end;

procedure TFrameLauncherBound.SelfToFrame(AFrame: TFrame);
begin
  TFrameLauncher(AFrame).FFrameListView.ListView.ZoomIndex := FListZoomIndex;
end;

end.
