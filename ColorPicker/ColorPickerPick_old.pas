unit ColorPickerPick;

interface

uses
  Winapi.Windows,Winapi.Messages,
  System.Classes,
  System.Types,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms;

type
  TColorPickerPickEvent = procedure(Sender: TObject; const AColor: TColor) of object;

  TColorPickerPick = class
  private
    FActive     : Boolean;
    FOnPick     : TColorPickerPickEvent;
    FOldCursor  : TCursor;
    FPickCursor : TCursor;
    FOldOnMsg   : TMessageEvent;

    procedure AppMessage(var Msg: TMsg; var Handled: Boolean);
    procedure DoPick(const ScreenPt: TPoint);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Start;
    procedure Stop;

    property Active: Boolean read FActive;
    property OnPick: TColorPickerPickEvent read FOnPick write FOnPick;
  end;

implementation


{ TColorPickerPick }

constructor TColorPickerPick.Create;
begin
  inherited Create;
  FPickCursor := crCross;
end;

destructor TColorPickerPick.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TColorPickerPick.Start;
begin
  if FActive then Exit;

  FActive := True;

  FOldCursor := Screen.Cursor;
  Screen.Cursor := FPickCursor;

  // Application メッセージフック
  FOldOnMsg := Application.OnMessage;
  Application.OnMessage := AppMessage;
end;

procedure TColorPickerPick.Stop;
begin
  if not FActive then Exit;

  // フック解除
  Application.OnMessage := FOldOnMsg;
  FOldOnMsg := nil;

  Screen.Cursor := FOldCursor;
  FActive := False;
end;

procedure TColorPickerPick.AppMessage(var Msg: TMsg; var Handled: Boolean);
begin
  if not FActive then Exit;

  if Msg.message = WM_LBUTTONDOWN then
  begin
    DoPick(Msg.pt);
    Handled := True; // 自アプリ内の誤動作防止
  end;
end;

procedure TColorPickerPick.DoPick(const ScreenPt: TPoint);
var
  DC  : HDC;
  Col : COLORREF;
begin
  DC := GetDC(0);
  try
    Col := GetPixel(DC, ScreenPt.X, ScreenPt.Y);
  finally
    ReleaseDC(0, DC);
  end;

  if Assigned(FOnPick) then
    FOnPick(Self, TColor(Col));

  Stop;
end;

end.

