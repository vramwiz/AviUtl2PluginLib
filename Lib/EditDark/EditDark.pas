unit EditDark;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Graphics,Winapi.UxTheme;

type
  EditTDark = class(TEdit)
  private
    FBackColor : TColor;
    FFontColor : TColor;

    procedure SetDarkBackColor(Value: TColor);
    procedure SetDarkFontColor(Value: TColor);
  protected
    procedure CreateWnd; override;
    procedure WM_PAINT(var Msg: TWMPaint); message WM_PAINT;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property BackColor : TColor read FBackColor write SetDarkBackColor;
    property TextColor : TColor read FFontColor write SetDarkFontColor;
  end;

implementation

constructor EditTDark.Create(AOwner: TComponent);
begin
  inherited;

  FBackColor := clBlack;
  FFontColor := clWhite;

  ParentColor := False;
end;

procedure EditTDark.SetDarkBackColor(Value: TColor);
begin
  FBackColor := Value;
  Color := Value;
  Invalidate;
end;

procedure EditTDark.SetDarkFontColor(Value: TColor);
begin
  FFontColor := Value;
  Font.Color := Value;
  Invalidate;
end;

procedure EditTDark.CreateWnd;
begin
  inherited;

  SetWindowTheme(Handle, '', '');
  Color := clBlack;
  Font.Color := clWhite;
end;

procedure EditTDark.WM_PAINT(var Msg: TWMPaint);
begin
  inherited;

  Color := FBackColor;
  Font.Color := FFontColor;
end;

end.
