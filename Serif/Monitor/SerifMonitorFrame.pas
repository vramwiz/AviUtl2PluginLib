unit SerifMonitorFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,System.IOUtils,System.Types,
  SerifWatcherList,Vcl.Menus, Vcl.ExtCtrls;

type
  // セリフ監視／送信状態
  TSerifWatchState = (swsStandby,   // 待機（デフォルト）
                      swsWatch,     // 旧監視状態。現在は swsSend として扱う
                      swsSend       // 送信（監視＋AviUtl2へ流し込み）
  );
type  TFrameSerifMonitorEvent = procedure(Sender: TObject;const WatchState : TSerifWatchState) of object;

type
  TFrameSerifMonitor = class(TFrame)
    btnStartStop: TButton;
    LabelStatus: TLabel;
    MenuPop: TPopupMenu;
    MenuDelete: TMenuItem;
    PanelBase: TPanel;
    PopupMenu1: TPopupMenu;
    MenuItem1: TMenuItem;
    procedure btnStartStopClick(Sender: TObject);
    procedure MenuDeleteClick(Sender: TObject);
  private
    { Private 宣言 }
    FOnChange: TFrameSerifMonitorEvent;
    FWatchState : TSerifWatchState;
    FWatchers : TSerifWatcherList;
    FStatusText: string;
    FWatchText: string;
    procedure ApplyStatusText;
    procedure SetStatusText(const Text: string; Color: TColor; Style: TFontStyles);
    procedure SetWatchState(const Value: TSerifWatchState);
  protected
      procedure DoChange(const AWatchState : TSerifWatchState);virtual;
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;
    procedure ShowStatus(Watchers : TSerifWatcherList);
    // 状態表示を更新
    procedure ShowWatch(aWache : string);
    property WatchState : TSerifWatchState read FWatchState write SetWatchState;
    property OnChange : TFrameSerifMonitorEvent read FOnChange write FOnChange;
  end;

implementation

uses AviUtl2PluginCore,AviUtl2StyleColors;

{$R *.dfm}

{ TFrameSerifVoiceWatcher }

constructor TFrameSerifMonitor.Create(AOwner: TComponent);
begin
  inherited;

  PanelBase.Color := A2SCPanelBackground;
  PanelBase.Font.Color := A2SCPanelText;
  PanelBase.Font.Height := -13;
  LabelStatus.Align := alClient;
  LabelStatus.Alignment := taCenter;
  LabelStatus.AutoSize := False;
  LabelStatus.Layout := tlCenter;
  LabelStatus.Transparent := True;

end;

destructor TFrameSerifMonitor.Destroy;
begin
  inherited;
end;

procedure TFrameSerifMonitor.ShowWatch(aWache: string);
begin
  FWatchText := aWache;
  ApplyStatusText;
end;

procedure TFrameSerifMonitor.ApplyStatusText;
begin
  if FWatchText <> '' then
    LabelStatus.Caption := FWatchText
  else
    LabelStatus.Caption := FStatusText;
end;

procedure TFrameSerifMonitor.SetStatusText(const Text: string; Color: TColor;
  Style: TFontStyles);
begin
  FStatusText := Text;
  LabelStatus.Font.Color := Color;
  LabelStatus.Font.Style := Style;
  ApplyStatusText;
end;

procedure TFrameSerifMonitor.SetWatchState(const Value: TSerifWatchState);
begin
  // swsWatch は旧設定互換用。画面表示上も現在の swsSend に寄せる。
  if Value = swsWatch then
    FWatchState := swsSend
  else
    FWatchState := Value;
  ShowStatus(FWatchers);
end;

procedure TFrameSerifMonitor.ShowStatus(Watchers : TSerifWatcherList);
begin
  FWatchers := Watchers;
  // 古い swsWatch が残っていても、ステータス表示は流し込み中として扱う。
  if FWatchState = swsWatch then
    FWatchState := swsSend;
  FWatchText := '';
  btnStartStop.Enabled := False;
  btnStartStop.Caption := '開始';
  Self.Color := clBlack;
  if FWatchers = nil then begin
    SetStatusText('セリフ未接続', clYellow, []);
    Exit;
  end;
  if FWatchers.Count = 0 then begin
    SetStatusText('監視設定なし', clYellow, []);
    Exit;
  end;
  if FWatchers[0].Folder = '' then begin
    SetStatusText('フォルダ未設定', clYellow, []);
    Exit;
  end;
  btnStartStop.Enabled := True;
  case FWatchState of
    swsStandby: begin
      btnStartStop.Caption := '開始';
      SetStatusText('待機中', clWhite, []);
    end;
    swsWatch: begin
      if GAviUtl2Plugin then begin
        btnStartStop.Caption := '流入';
        SetStatusText('監視中', clRed, [TFontStyle.fsBold]);
      end
      else begin
        btnStartStop.Caption := '停止';
        SetStatusText('流し込み中', clRed, [TFontStyle.fsBold]);
      end;
    end;
    swsSend: begin
      btnStartStop.Caption := '停止';
      Self.Color := clBlue;
      SetStatusText('流入中', clRed, [TFontStyle.fsBold]);
    end;
  end;
end;


procedure TFrameSerifMonitor.btnStartStopClick(Sender: TObject);
begin
  case FWatchState of
    // 現在は単独監視 swsWatch を使わず、開始は常に流し込み状態にする。
    swsStandby : FWatchState := swsSend;
    swsWatch   : FWatchState := swsStandby;
    swsSend    : FWatchState := swsStandby;
  end;
  DoChange(FWatchState);
end;

procedure TFrameSerifMonitor.MenuDeleteClick(Sender: TObject);
var
  i : Integer;
  folder : string;
  files : TStringDynArray;
  fileName : string;
begin
  for i := 0 to FWatchers.Count-1 do
  begin
    folder := FWatchers[i].Folder;

    if not TDirectory.Exists(folder) then
      Continue;

    files := TDirectory.GetFiles(folder);

    for fileName in files do
      TFile.Delete(fileName);
  end;
end;

procedure TFrameSerifMonitor.DoChange(const AWatchState : TSerifWatchState);
begin
 if Assigned(FOnChange) then FOnChange(Self,AWatchState);
end;


end.
