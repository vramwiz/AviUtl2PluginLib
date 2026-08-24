unit LauncherWizardFrame;

// 起動中アプリを一覧表示し、ランチャー登録対象を選択するウィザードユニット。
interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.TlHelp32, Winapi.PsAPI,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus,LauncherListView,
  Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TLauncherWizardRegisterEvent = procedure(Sender: TObject;
    const FileName: string) of object;
  TLauncherWizardCancelEvent = procedure(Sender: TObject) of object;

type
  TFrameLauncherWizard = class(TFrame)
    MenuPopup: TPopupMenu;
    MenuAppRefresh: TMenuItem;
    Panel1: TPanel;
    btnOk: TButton;
    btnCancel: TButton;
    // 起動中アプリ一覧を再検索する。
    procedure MenuAppRefreshClick(Sender: TObject);
  private
    { Private 宣言 }
    FListView: TLauncherListView; // 起動中アプリを表示する一覧。
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

uses AppFolderUtils,AviUtl2StyleColors;

{$R *.dfm}

{ TFrameLauncherWizard }

constructor TFrameLauncherWizard.Create(AOwner: TComponent);
begin
  inherited;

  ParentFont := False;
  Font.Height := -12;
  Panel1.Height := MulDiv(32, CurrentPPI, 96);
  Panel1.ParentFont := False;
  Panel1.Font.Height := -12;
  btnOk.Align := alLeft;
  btnOk.Width := Panel1.Width div 2;
  btnOk.ParentFont := False;
  btnOk.Font.Height := -12;
  btnCancel.Align := alClient;
  btnCancel.ParentFont := False;
  btnCancel.Font.Height := -12;
  btnOk.OnClick := ButtonOkClick;
  btnCancel.OnClick := ButtonCancelClick;

  FListView := TLauncherListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.PopupMenu := MenuPopup;
  FListView.Color := A2SCListViewBackground;
  FListView.Font.Color := A2SCListViewText;
  FListView.OnItemDblClick := ListViewItemDblClick;
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
  ScanRunningApplications;
end;

end.
