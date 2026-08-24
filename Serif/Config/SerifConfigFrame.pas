unit SerifConfigFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  StdCtrls,Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,ListBoxEdit,
  SerifCharaList,ListViewRTTI, Vcl.Menus,SerifConfig,ConfigPanel;

type
  TFrameSerifConfig = class(TFrame)
  private
    { Private 宣言 }
    FPanelConfig : TConfigPanel;
    FOnChange: TNotifyEvent;
    FOnEnterPosChange: TNotifyEvent;
    procedure OnConfigChange(Sender: TObject);
  protected
    procedure DoChange();
    procedure DoEnterPosChange();
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowItem(Config : TSerifConfigItem);
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnEnterPosChange: TNotifyEvent read FOnEnterPosChange write FOnEnterPosChange;
  end;

implementation

uses ListViewEditPluginLib,AviUtl2StyleColors;

{$R *.dfm}

{ TFrameSerifConfig }

constructor TFrameSerifConfig.Create(AOwner: TComponent);
begin
  inherited;

  FPanelConfig := TConfigPanel.Create(Self);
  FPanelConfig.Parent := Self;
  FPanelConfig.Align := alClient;
  FPanelConfig.Color := A2SCListViewBackground;
  FPanelConfig.ListViewColor := A2SCListViewBackground;
  FPanelConfig.Font.Height := -12;
  FPanelConfig.ListView.ItemHeight := 20;
  FPanelConfig.OnChange := OnConfigChange;

end;

destructor TFrameSerifConfig.Destroy;
begin
  FPanelConfig.Free;

  inherited;
end;

procedure SetLayer(ts : TStringList);
var
  i : Integer;
begin
  ts.Clear;
  ts.AddObject('自動改行なし',TObject(0));
  for i := 12 to 48 do begin
    ts.AddObject(IntToStr(i+1),TObject(i+1));
  end;
end;


procedure TFrameSerifConfig.ShowItem(Config: TSerifConfigItem);
var
  lv : TListViewRTTI;
  ts : TStringList;
begin
  lv := FPanelConfig.ListView;
  lv.RTTINames['SecStart'].AddCaption('セリフ前(秒)','セリフの前の空白の長さ',clSkyBlue);
  lv.RTTINames['SecEnd'].AddCaption('セリフ後(秒)','セリフの後の空白の長さ',clSkyBlue);
  lv.RTTINames['EnterPos'].AddCaption('改行位置','セリフの改行位置',clMoneyGreen,ListViewEditPluginComboBoxObjectId);
  lv.RTTINames['SendLab'].AddCaption('音素','口パクを細かく制御する',clBtnFace,ListViewEditPluginBoolId);
  //FListView.RTTINames['EnterPos'].EditType :=  ListViewEditPluginComboBoxObjectId;
  SetLayer(lv.RTTINames['EnterPos'].Strings);

  ts := lv.RTTINames['SendLab'].Strings;
  ts.Clear;
  ts.Add('使わない');
  ts.Add('使う');
  {
  clSkyBlue
  clMoneyGreen
  clWebPink
  }

  FPanelConfig.ShowConfig(Config);
  lv.FixedWidth := 120;

end;

procedure TFrameSerifConfig.OnConfigChange(Sender: TObject);
var
  i : Integer;
begin
  //FConfig.SaveToFile;
  i := FPanelConfig.ListView.ItemIndex;
  if i = 2 then DoEnterPosChange();  // 改行数変更イベントを発火
  DoChange();
end;

procedure TFrameSerifConfig.DoChange;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;


procedure TFrameSerifConfig.DoEnterPosChange;
begin
  if Assigned(FOnEnterPosChange) then FOnEnterPosChange(Self);
end;

end.
