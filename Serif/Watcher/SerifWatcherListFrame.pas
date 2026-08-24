unit SerifWatcherListFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,ListBoxEx,
  SerifWatcherList;

type
  TFrameSerifWatcherList = class(TFrame)
  private
    { Private 宣言 }
    FWachers : TSerifWatcherList;
    FListBox : TListBoxExColor;
    FOnListClick: TNotifyEvent;
    procedure OnListBoxClick(Sender: TObject);
    function GetItemIndex: Integer;
    procedure SetItemIndex(const Value: Integer);
  protected
    procedure DoListClick();
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowList(Wachers : TSerifWatcherList);

    property ItemIndex : Integer read GetItemIndex write SetItemIndex;

    property OnListClick: TNotifyEvent read FOnListClick write FOnListClick;
  end;

implementation

uses ListViewEditPluginDialog,AviUtl2StyleColors;

{$R *.dfm}

{ TFrameSerifVoiceWatcherList }

constructor TFrameSerifWatcherList.Create(AOwner: TComponent);
begin
  inherited;
  FListBox := TListBoxExColor.Create(Self);
  FListBox.Parent := Self;
  FListBox.Align := alClient;
  FListBox.Color := A2SCListBoxBackground;
  FListBox.Font.Color := A2SCListBoxText;
  FListBox.Font.Height := -12;
  FListBox.OnListClick := OnListBoxClick;
end;

destructor TFrameSerifWatcherList.Destroy;
begin
  FListBox.Free;
  inherited;
end;

procedure TFrameSerifWatcherList.ShowList(Wachers: TSerifWatcherList);
var
  i : Integer;
  wacher : TSerifWatcherItem;
begin
  FWachers := Wachers;
  FListBox.Items.BeginUpdate;
  try
     FListBox.Clear;
     for i := 0 to FWachers.Count-1 do begin
       wacher := FWachers[i];
       FListBox.Items.AddObject(wacher.Name,wacher);
     end;

  finally
    FListBox.Items.EndUpdate;
  end;
end;


procedure TFrameSerifWatcherList.DoListClick;
begin
  if Assigned(FOnListClick) then FOnListClick(Self);
end;

function TFrameSerifWatcherList.GetItemIndex: Integer;
begin
  Result := FListBox.ItemIndex;
end;

procedure TFrameSerifWatcherList.SetItemIndex(const Value: Integer);
begin
  FListBox.ItemIndex := Value;
end;

procedure TFrameSerifWatcherList.OnListBoxClick(Sender: TObject);
begin
  DoListClick;
end;

end.

