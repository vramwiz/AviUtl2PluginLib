unit SerifWatcherFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,ListBoxEx,
  SerifWatcherList,ListViewRTTI,SerifWatcherListFrame,ConfigPanel;

type
  TFrameSerifWatcher = class(TFrame)
    PanelList: TPanel;
    PanelInfo: TPanel;
  private
    { Private 宣言 }
    FFrameList : TFrameSerifWatcherList;
    FWachers : TSerifWatcherList;
    //FListBox : TListBoxExColor;
    FPanelConfig : TConfigPanel;
    FOnChange: TNotifyEvent;
    procedure ShowInfo(Wacher : TSerifWatcherItem);
    procedure OnListBoxClick(Sender: TObject);
    procedure OnListViewChange(Sender: TObject);
  protected
    procedure DoChange();
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowList(Wachers : TSerifWatcherList);
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

uses ListViewEditPluginDialog,AviUtl2StyleColors;

{$R *.dfm}

{ TFrameSerifVoiceWatcherList }

constructor TFrameSerifWatcher.Create(AOwner: TComponent);
begin
  inherited;
  FFrameList := TFrameSerifWatcherList.Create(Self);
  FFrameList.Parent := PanelList;
  FFrameList.Align := alClient;
  FFrameList.Color := A2SCListBoxBackground;
  FFrameList.Font.Color := A2SCListBoxText;
  FFrameList.Font.Height := -12;
  FFrameList.OnListClick := OnListBoxClick;

  FPanelConfig := TConfigPanel.Create(Self);
  FPanelConfig.Parent := PanelInfo;
  FPanelConfig.Align := alClient;
  FPanelConfig.Color := A2SCListViewBackground;
  FPanelConfig.ListViewColor := A2SCListViewBackground;
  FPanelConfig.Font.Height := -12;
  FPanelConfig.ListView.ItemHeight := 20;
  FPanelConfig.OnChange := OnListViewChange;
end;

destructor TFrameSerifWatcher.Destroy;
begin
  FPanelConfig.Free;
  FFrameList.Free;
  inherited;
end;

procedure TFrameSerifWatcher.ShowList(Wachers: TSerifWatcherList);
begin
  FWachers := Wachers;
  FFrameList.ShowList(Wachers);
   if FWachers.Count > 0 then begin
     FFrameList.ItemIndex := 0;
     ShowInfo(FWachers[0]);
   end;
end;


procedure TFrameSerifWatcher.DoChange;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TFrameSerifWatcher.ShowInfo(Wacher: TSerifWatcherItem);
begin

  FPanelConfig.ListView.RTTINames['Folder'].AddCaption('監視フォルダ','音声合成ソフトが出力するフォルダ',clMoneyGreen,ListViewEditPluginOpenFolderDialogId);
  FPanelConfig.ListView.RTTINames['DelaySec'].AddCaption('出力待ち時間(秒)','出力が落ち着くまでの待ち時間(秒)',clWebPink);
    {
  clSkyBlue
  clMoneyGreen
  clWebPink
  }
  FPanelConfig.ShowConfig(Wacher);
  FPanelConfig.ListView.FixedWidth := 200;

end;

procedure TFrameSerifWatcher.OnListBoxClick(Sender: TObject);
var
  i : Integer;
  wacher : TSerifWatcherItem;
begin
  i := FFrameList.ItemIndex;
  if i = -1 then Exit;
  wacher := FWachers[i];
  ShowInfo(wacher);
end;


procedure TFrameSerifWatcher.OnListViewChange(Sender: TObject);
begin
  FWachers.SaveToFile;
  DoChange();
end;

end.

