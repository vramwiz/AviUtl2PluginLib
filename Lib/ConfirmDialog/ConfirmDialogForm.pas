unit ConfirmDialogForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Buttons;

type
  TFormConfirmDialog = class(TForm)
    PanelCaption: TPanel;
    Panel1: TPanel;
    btnOk: TButton;
    btnCancel: TButton;
    sbtnOk: TSpeedButton;
    sbtnCancel: TSpeedButton;
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private 宣言 }
  public
    { Public 宣言 }
    function Execute(const ACaption: string): TModalResult;
  end;

var
  FormConfirmDialog: TFormConfirmDialog;

implementation

uses AviUtl2StyleColors;

{$R *.dfm}

function TFormConfirmDialog.Execute(const ACaption: string): TModalResult;
var
  P: TPoint;
  R: TRect;
begin
  // 表示文字列
  PanelCaption.Caption := ACaption;

  // ボタン役割固定
  btnOk.ModalResult     := mrOk;
  btnOk.Default         := True;

  btnCancel.ModalResult := mrCancel;
  btnCancel.Cancel      := True;

  Color := A2SCPanelBackground;
  Font.Color := A2SCPanelText;
  Font.Height := -14;

  // マウス位置取得
  GetCursorPos(P);

  // 画面外に出ないよう補正
  R := Screen.MonitorFromPoint(P).WorkareaRect;

  Left := P.X + 8;
  Top  := P.Y + 8;

  if Left + Width > R.Right then
    Left := R.Right - Width;
  if Top + Height > R.Bottom then
    Top := R.Bottom - Height;

  // モーダル実行（ここで処理が待つ）
  Result := ShowModal;
end;

procedure TFormConfirmDialog.FormResize(Sender: TObject);
begin
  btnOk.Width := ClientWidth div 2;
  btnCancel.Width := ClientWidth div 2;
end;

procedure TFormConfirmDialog.FormShow(Sender: TObject);
begin
  btnOk.Width := ClientWidth div 2;
  btnCancel.Width := ClientWidth div 2;
end;

end.
