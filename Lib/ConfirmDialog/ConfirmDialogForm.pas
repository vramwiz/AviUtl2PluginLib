unit ConfirmDialogForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons,
  DarkButton, DarkPanel, DarkThemeDpiContext;

type
  TFormConfirmDialog = class(TForm)
    PanelCaption: TDarkPanel;
    Panel1: TDarkPanel;
    btnOk: TButton;
    btnCancel: TButton;
    sbtnOk: TSpeedButton;
    sbtnCancel: TSpeedButton;
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FCancelButton: TDarkButton;
    FDpiContext: TDarkThemeDpiContext;
    FOkButton: TDarkButton;
    procedure ApplyDarkTitleBar;
    procedure ApplyMetrics(TargetPPI: Integer);
    function DpiAtPoint(const P: TPoint): Integer;
    procedure LayoutButtons;
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
  protected
    procedure DoAfterMonitorDpiChanged(OldDPI, NewDPI: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    // VCLの倍率変更後に文字と固定レイアウトを基準寸法へ揃える。
    procedure ScaleForPPI(NewPPI: Integer); override;
    procedure ApplyDpi(TargetPPI: Integer);
    function Execute(const ACaption: string): TModalResult;
  end;

var
  FormConfirmDialog: TFormConfirmDialog;

implementation

uses
  Winapi.Dwmapi,
  DarkThemeColors, DarkThemeMetrics;

{$R *.dfm}

const
  DesignClientWidth = 199;
  DesignCaptionHeight = 35;
  DesignClientHeight = DesignCaptionHeight + DarkThemeButtonHeight;
  DesignCaptionFontHeight = 14;
  DesignCursorOffset = 8;

constructor TFormConfirmDialog.Create(AOwner: TComponent);
begin
  inherited;
  KeyPreview := True;
  FDpiContext := TDarkThemeDpiContext.Create(Self);
  FDpiContext.UpdateFromControl(Self);

  PanelCaption.DpiContext := FDpiContext;
  PanelCaption.DesignHeight := DesignCaptionHeight;
  Panel1.DpiContext := FDpiContext;
  btnOk.Visible := False;
  btnCancel.Visible := False;
  sbtnOk.Visible := False;
  sbtnCancel.Visible := False;

  FOkButton := TDarkButton.Create(Self);
  FOkButton.Parent := Panel1;
  FOkButton.DpiContext := FDpiContext;
  FOkButton.Caption := 'OK';
  FOkButton.Default := True;
  FOkButton.ModalResult := mrOk;
  FOkButton.TabOrder := 0;

  FCancelButton := TDarkButton.Create(Self);
  FCancelButton.Parent := Panel1;
  FCancelButton.DpiContext := FDpiContext;
  FCancelButton.Caption := 'キャンセル';
  FCancelButton.Cancel := True;
  FCancelButton.ModalResult := mrCancel;
  FCancelButton.TabOrder := 1;
  ApplyDpi(CurrentPPI);
end;

procedure TFormConfirmDialog.ApplyDarkTitleBar;
const
  DarkModeAttribute = 20;
  DarkModeAttributeLegacy = 19;
  BorderColorAttribute = 34;
  CaptionColorAttribute = 35;
  TextColorAttribute = 36;
var
  BorderColor: COLORREF;
  CaptionColor: COLORREF;
  DarkMode: BOOL;
  TextColor: COLORREF;
begin
  DarkMode := True;
  if Failed(DwmSetWindowAttribute(Handle, DarkModeAttribute, @DarkMode,
    SizeOf(DarkMode))) then
    DwmSetWindowAttribute(Handle, DarkModeAttributeLegacy, @DarkMode,
      SizeOf(DarkMode));
  CaptionColor := ColorToRGB(DarkThemePanelBackground);
  TextColor := ColorToRGB(DarkThemePanelText);
  BorderColor := ColorToRGB(DarkThemeControlBorder);
  DwmSetWindowAttribute(Handle, CaptionColorAttribute, @CaptionColor,
    SizeOf(CaptionColor));
  DwmSetWindowAttribute(Handle, TextColorAttribute, @TextColor,
    SizeOf(TextColor));
  DwmSetWindowAttribute(Handle, BorderColorAttribute, @BorderColor,
    SizeOf(BorderColor));
end;

procedure TFormConfirmDialog.ApplyMetrics(TargetPPI: Integer);
  procedure SetFont(ControlFont: TFont; DesignHeight: Integer);
  begin
    ControlFont.Name := 'Yu Gothic UI';
    ControlFont.PixelsPerInch := FDpiContext.Dpi;
    ControlFont.Height := FDpiContext.Metrics.FontHeight(DesignHeight);
  end;
begin
  // VCL can call ScaleForPPI while the inherited constructor is still loading.
  if FDpiContext = nil then
    Exit;
  DisableAlign;
  try
    FDpiContext.Dpi := TargetPPI;
    SetFont(Font, DarkThemeDefaultFontHeight);
    PanelCaption.ParentFont := False;
    SetFont(PanelCaption.Font, DesignCaptionFontHeight);
    Panel1.ParentFont := False;
    SetFont(Panel1.Font, DarkThemeDefaultFontHeight);
    if Assigned(FOkButton) then
      SetFont(FOkButton.Font, DarkThemeDefaultFontHeight);
    if Assigned(FCancelButton) then
      SetFont(FCancelButton.Font, DarkThemeDefaultFontHeight);
    ClientWidth := FDpiContext.Scale(DesignClientWidth);
    ClientHeight := FDpiContext.Scale(DesignClientHeight);
  finally
    EnableAlign;
  end;
  LayoutButtons;
end;

procedure TFormConfirmDialog.ScaleForPPI(NewPPI: Integer);
begin
  inherited;
  ApplyMetrics(NewPPI);
end;

procedure TFormConfirmDialog.DoAfterMonitorDpiChanged(OldDPI, NewDPI: Integer);
begin
  inherited;
  ApplyMetrics(NewDPI);
end;

procedure TFormConfirmDialog.ApplyDpi(TargetPPI: Integer);
begin
  // Keep VCL's DPI state and our shared control metrics at the same scale.
  ScaleForPPI(NormalizeDarkThemeDpi(TargetPPI));
end;

procedure TFormConfirmDialog.CMDialogKey(var Message: TCMDialogKey);
begin
  if Message.CharCode = VK_RETURN then
  begin
    ModalResult := mrOk;
    Message.Result := 1;
  end
  else if Message.CharCode = VK_ESCAPE then
  begin
    ModalResult := mrCancel;
    Message.Result := 1;
  end
  else
    inherited;
end;

function TFormConfirmDialog.DpiAtPoint(const P: TPoint): Integer;
begin
  Result := Screen.MonitorFromPoint(P).PixelsPerInch;
  if Result <= 0 then
    Result := Screen.PixelsPerInch;
  Result := NormalizeDarkThemeDpi(Result);
end;

function TFormConfirmDialog.Execute(const ACaption: string): TModalResult;
var
  CursorOffset: Integer;
  P: TPoint;
  PPI: Integer;
  R: TRect;
begin
  PanelCaption.Caption := ACaption;
  Color := DarkThemePanelBackground;
  Font.Color := DarkThemePanelText;

  GetCursorPos(P);
  PPI := DpiAtPoint(P);
  ApplyDpi(PPI);
  CursorOffset := FDpiContext.Scale(DesignCursorOffset);
  R := Screen.MonitorFromPoint(P).WorkareaRect;

  Left := P.X + CursorOffset;
  Top := P.Y + CursorOffset;
  HandleNeeded;
  ApplyDpi(CurrentPPI);
  if Left + Width > R.Right then
    Left := R.Right - Width;
  if Top + Height > R.Bottom then
    Top := R.Bottom - Height;
  if Left < R.Left then
    Left := R.Left;
  if Top < R.Top then
    Top := R.Top;

  ApplyDarkTitleBar;
  Result := ShowModal;
end;

procedure TFormConfirmDialog.FormResize(Sender: TObject);
begin
  LayoutButtons;
end;

procedure TFormConfirmDialog.FormShow(Sender: TObject);
begin
  ApplyDpi(CurrentPPI);
  ApplyDarkTitleBar;
  LayoutButtons;
  if FOkButton.CanFocus then
    FOkButton.SetFocus;
end;

procedure TFormConfirmDialog.LayoutButtons;
var
  HalfWidth: Integer;
begin
  if not Assigned(FOkButton) or not Assigned(FCancelButton) then
    Exit;
  HalfWidth := Panel1.ClientWidth div 2;
  FOkButton.SetBounds(0, 0, HalfWidth, Panel1.ClientHeight);
  FCancelButton.SetBounds(HalfWidth, 0, Panel1.ClientWidth - HalfWidth,
    Panel1.ClientHeight);
end;

end.
