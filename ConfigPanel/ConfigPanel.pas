unit ConfigPanel;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics,  Vcl.ExtCtrls,Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  ListViewRTTI,RTTIPersistentIni;

type
  TConfigPanel = class(TPanel)
  private
    { Private 宣言 }
    FConfig      : TRTTIPersistentIni;
    FListView    : TListViewRTTI;
    FOnChange: TNotifyEvent;
    function GetListViewColor: TColor;
    procedure SetListViewColor(const Value: TColor);

    procedure OnListViewChange(Sender: TObject);
  protected
    procedure DoChange();
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowConfig(Config : TRTTIPersistentIni);
    procedure View();

    property ListView : TListViewRTTI read FListView;
    property ListViewColor: TColor read GetListViewColor write SetListViewColor;

    property OnChange   : TNotifyEvent  read FOnChange write FOnChange;
  end;


implementation

uses
  AviUtl2StyleColors;

{ TConfigPanel }

constructor TConfigPanel.Create(AOwner: TComponent);
begin
  inherited;
  Color := A2SCPanelBackground;
  FListView := TListViewRTTI.Create(Self);
  FListView.Color := A2SCListViewBackground;
  FListView.Font.Color := A2SCListViewText;
  FListView.Font.Height := -12;
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.ItemHeight := 32;
  FListView.OnDataChange := OnListViewChange;
end;

destructor TConfigPanel.Destroy;
begin
  FListView.Free;
  inherited;
end;

procedure TConfigPanel.ShowConfig(Config: TRTTIPersistentIni);
begin
  FConfig := Config;
  FListView.LoadFromObject(FConfig);

  FListView.Height := FListView.GetViewHeight();
  Self.Height := FListView.Height;
  FListView.FixedWidth := 140;

end;

procedure TConfigPanel.View;
begin
  FListView.Refresh;
end;

function TConfigPanel.GetListViewColor: TColor;
begin
  Result := FListView.Color;
end;

procedure TConfigPanel.SetListViewColor(const Value: TColor);
begin
  FListView.Color := Value;
end;


procedure TConfigPanel.OnListViewChange(Sender: TObject);
begin
  DoChange();
end;

procedure TConfigPanel.DoChange;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

end.
