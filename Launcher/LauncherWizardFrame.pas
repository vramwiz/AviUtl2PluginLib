unit LauncherWizardFrame;

// 起動中アプリを一覧表示し、ランチャー登録対象を選択するウィザードユニット。
interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.TlHelp32, Winapi.PsAPI,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus,LauncherListView,
  Vcl.StdCtrls, Vcl.ExtCtrls,
  DarkButton, DarkPanel, DarkThemeDpiContext;

type
  TLauncherWizardRegisterEvent = procedure(Sender: TObject;
    const FileName: string) of object;
  TLauncherWizardCancelEvent = procedure(Sender: TObject) of object;

type
  TFrameLauncherWizard = class(TFrame)
  private const
    // 96 DPI等倍では埋込み表示上で小さく見えるため、一覧との視覚差を
    // 抑えつつ200%時の過大表示へ戻らない約131%を登録操作部だけに使う。
    // 共通32pxボタンは42px、12px文字は16pxになる。
    LAUNCHER_WIZARD_UI_DPI = 126;
  published
    MenuPopup: TPopupMenu;
    MenuAppRefresh: TMenuItem;
    Panel1: TDarkPanel;
    btnOk: TButton;
    btnCancel: TButton;
    // 起動中アプリ一覧を再検索する。
    procedure MenuAppRefreshClick(Sender: TObject);
  private
    { Private 宣言 }
    FListView: TLauncherListView; // 起動中アプリを表示する一覧。
    FButtonOk: TDarkButton; // 共通ダークテーマの登録ボタン。
    FButtonCancel: TDarkButton; // 共通ダークテーマのキャンセルボタン。
    FDpiContext: TDarkThemeDpiContext; // この画面で共有するDPI情報。
    FOnCancel: TLauncherWizardCancelEvent; // キャンセル時の画面遷移通知。
    FOnRegister: TLauncherWizardRegisterEvent; // 登録確定時の通知。
    FRegisteredList: TLauncherListViewList; // 既に登録済みの除外対象リスト。
    // キャンセルボタン押下を通知する。
    procedure ButtonCancelClick(Sender: TObject);
    // OKボタン押下で選択項目を登録する。
    procedure ButtonOkClick(Sender: TObject);
    // 一覧ダブルクリックで選択項目を登録する。
    procedure ListViewItemDblClick(Sender: TObject; Item: TLauncherListViewItem);
    // 選択中の起動中アプリを登録通知する。
    procedure RegisterSelected;
    // 起動中アプリを検索して一覧へ表示する。
    procedure ScanRunningApplications;
    // 現在の表示モニターに合わせて共通寸法を反映する。
    procedure ApplyDpi;
  public
    { Public 宣言 }
    // ウィザードを初期化する。
    constructor Create(AOwner: TComponent); override;
    // ウィザードを破棄する。
    destructor Destroy;override;
    // 表示時に起動中アプリ一覧を更新する。
    procedure Show;
    property ListView : TLauncherListView read FListView;
    property OnCancel: TLauncherWizardCancelEvent read FOnCancel write FOnCancel;
    property OnRegister: TLauncherWizardRegisterEvent read FOnRegister write FOnRegister;
    property RegisteredList: TLauncherListViewList read FRegisteredList write FRegisteredList;
  end;

implementation

uses AppFolderUtils, DarkThemeColors, DarkThemeMetrics;

{$R *.dfm}

{ TFrameLauncherWizard }

constructor TFrameLauncherWizard.Create(AOwner: TComponent);
begin
  inherited;

  ParentFont := False;
  Font.Height := -12;
  FDpiContext := TDarkThemeDpiContext.Create(Self);
  FDpiContext.Dpi := LAUNCHER_WIZARD_UI_DPI;
  Panel1.DpiContext := FDpiContext;
  Panel1.DesignHeight := DarkThemeButtonHeight;
  btnOk.Visible := False;
  btnCancel.Visible := False;

  FButtonCancel := TDarkButton.Create(Self);
  FButtonCancel.Parent := Panel1;
  FButtonCancel.DpiContext := FDpiContext;
  FButtonCancel.Align := alClient;
  FButtonCancel.Caption := btnCancel.Caption;
  FButtonCancel.Cancel := True;
  FButtonCancel.OnClick := ButtonCancelClick;

  FButtonOk := TDarkButton.Create(Self);
  FButtonOk.Parent := Panel1;
  FButtonOk.DpiContext := FDpiContext;
  FButtonOk.Align := alLeft;
  FButtonOk.Width := Panel1.Width div 2;
  FButtonOk.Caption := btnOk.Caption;
  FButtonOk.Default := True;
  FButtonOk.OnClick := ButtonOkClick;

  FListView := TLauncherListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.PopupMenu := MenuPopup;
  FListView.Color := DarkThemeListBackground;
  FListView.Font.Color := DarkThemeListText;
  FListView.OnItemDblClick := ListViewItemDblClick;
end;

procedure TFrameLauncherWizard.ApplyDpi;
begin
  // 親アプリの200% DPIへは追従せず、登録操作部用の中間寸法へ戻す。
  FDpiContext.Dpi := LAUNCHER_WIZARD_UI_DPI;
  Font.Height := FDpiContext.Metrics.FontHeight;
end;

destructor TFrameLauncherWizard.Destroy;
begin
  FListView.Free;
  inherited;
end;

procedure TFrameLauncherWizard.ButtonCancelClick(Sender: TObject);
begin
  if Assigned(FOnCancel) then
    FOnCancel(Self);
end;

procedure TFrameLauncherWizard.ButtonOkClick(Sender: TObject);
begin
  RegisterSelected;
end;

procedure TFrameLauncherWizard.ListViewItemDblClick(Sender: TObject;
  Item: TLauncherListViewItem);
begin
  RegisterSelected;
end;

procedure TFrameLauncherWizard.MenuAppRefreshClick(Sender: TObject);
begin
  ScanRunningApplications;
end;

procedure TFrameLauncherWizard.RegisterSelected;
var
  Item: TLauncherListViewItem;
begin
  Item := FListView.GetSelectedItem;
  if Item = nil then
    Exit;

  if Assigned(FOnRegister) then
    FOnRegister(Self, Item.FileName);
end;

procedure TFrameLauncherWizard.ScanRunningApplications;
var
  Snapshot: THandle;
  Entry: TProcessEntry32;
  ProcessHandle: THandle;
  Buffer: array[0..MAX_PATH - 1] of Char;
  Size: DWORD;
  FileName: string;
begin
  FListView.FileList.Clear;

  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
  begin
    FListView.RebuildItems;
    Exit;
  end;

  try
    ZeroMemory(@Entry, SizeOf(Entry));
    Entry.dwSize := SizeOf(Entry);

    if Process32First(Snapshot, Entry) then
    repeat
      ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False,
        Entry.th32ProcessID);
      if ProcessHandle = 0 then
        Continue;
      try
        Size := GetModuleFileNameEx(ProcessHandle, 0, Buffer, Length(Buffer));
        if Size > 0 then
        begin
          FileName := string(PChar(@Buffer[0]));
          if (FileName <> '') and
            ((FRegisteredList = nil) or (FRegisteredList.IndexOfFileName(FileName) = -1)) and
            (FListView.FileList.IndexOfFileName(FileName) = -1) then
            FListView.FileList.AddFile(FileName);
        end;
      finally
        CloseHandle(ProcessHandle);
      end;
    until not Process32Next(Snapshot, Entry);
  finally
    CloseHandle(Snapshot);
  end;

  FListView.RebuildItems;
end;

procedure TFrameLauncherWizard.Show;
begin
  inherited Show;
  ApplyDpi;
  ScanRunningApplications;
end;

end.
