// PSD編集画面だけの配色を管理し、ホスト全体のVCLスタイルは変更しない。
unit ArtEditorTheme;

interface

uses
  System.Classes, System.Types, Winapi.Windows, Vcl.Graphics, Vcl.StdCtrls, Vcl.Menus;

const
  ArtEditorBackground = TColor($001A1A1A);
  ArtEditorPanel = TColor($00272727);
  ArtEditorInput = TColor($00212121);
  ArtEditorText = TColor($00E6E6E6);
  ArtEditorBorder = TColor($00424242);
  ArtEditorSelection = TColor($00865E24);

type
  TArtEditorMemo = class(TMemo)
  public
    constructor Create(AOwner: TComponent); override;
  protected
    procedure CreateWnd; override;
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
  end;

  TArtEditorEdit = class(TEdit)
  public
    constructor Create(AOwner: TComponent); override;
  protected
    procedure CreateWnd; override;
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
  end;

  TArtEditorPopupMenu = class(TPopupMenu)
  private
    function MenuPPI: Integer;
    procedure DrawItem(Sender: TObject; Canvas: TCanvas; ARect: TRect; Selected: Boolean);
    procedure MeasureItem(Sender: TObject; Canvas: TCanvas; var Width, Height: Integer);
  protected
    procedure DoPopup(Sender: TObject); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

// 対象ウィンドウのタイトル・境界だけをダーク配色へ設定する。
procedure ApplyArtEditorTitleBar(Window: HWND);

implementation

uses
  Vcl.Controls, Vcl.Forms, Winapi.UxTheme, Winapi.Dwmapi;

constructor TArtEditorMemo.Create(AOwner: TComponent);
begin
  inherited;
  StyleElements := [];
  Color := ArtEditorInput;
  Font.PixelsPerInch := CurrentPPI;
  Font.Height := -MulDiv(13, CurrentPPI, 96);
  Font.Color := ArtEditorText;
  BorderStyle := bsNone;
end;

procedure TArtEditorMemo.CreateWnd;
begin
  inherited;
  SetWindowTheme(Handle, 'DarkMode_Explorer', nil);
end;

procedure TArtEditorMemo.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited;
  if isDpiChange then
  begin
    Font.PixelsPerInch := M;
    Font.Height := -MulDiv(13, M, 96);
  end;
end;

constructor TArtEditorEdit.Create(AOwner: TComponent);
begin
  inherited;
  StyleElements := [];
  Color := ArtEditorInput;
  Font.PixelsPerInch := CurrentPPI;
  Font.Height := -MulDiv(13, CurrentPPI, 96);
  Font.Color := ArtEditorText;
  BorderStyle := bsNone;
end;

procedure TArtEditorEdit.CreateWnd;
begin
  inherited;
  SetWindowTheme(Handle, '', '');
end;

procedure TArtEditorEdit.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited;
  if isDpiChange then
  begin
    Font.PixelsPerInch := M;
    Font.Height := -MulDiv(13, M, 96);
  end;
end;

constructor TArtEditorPopupMenu.Create(AOwner: TComponent);
begin
  inherited;
  OwnerDraw := True;
end;

function TArtEditorPopupMenu.MenuPPI: Integer;
begin
  Result := 96;
  if Owner is TControl then Result := TControl(Owner).CurrentPPI;
end;

procedure TArtEditorPopupMenu.DoPopup(Sender: TObject);
var
  Item: TMenuItem;
begin
  for Item in Items do
  begin
    Item.OnDrawItem := DrawItem;
    Item.OnMeasureItem := MeasureItem;
  end;
  inherited;
end;

procedure TArtEditorPopupMenu.MeasureItem(Sender: TObject; Canvas: TCanvas; var Width, Height: Integer);
begin
  Canvas.Font.Name := 'Yu Gothic UI';
  Canvas.Font.Height := -MulDiv(13, MenuPPI, 96);
  Height := MulDiv(28, MenuPPI, 96);
  if TMenuItem(Sender).IsLine then Height := MulDiv(8, MenuPPI, 96);
  Width := Canvas.TextWidth(TMenuItem(Sender).Caption) + MulDiv(48, MenuPPI, 96);
end;

procedure TArtEditorPopupMenu.DrawItem(Sender: TObject; Canvas: TCanvas; ARect: TRect; Selected: Boolean);
var
  Item: TMenuItem;
  TextRect: TRect;
begin
  Item := TMenuItem(Sender);
  Canvas.Brush.Color := ArtEditorPanel;
  if Selected and Item.Enabled then Canvas.Brush.Color := ArtEditorSelection;
  Canvas.FillRect(ARect);
  if Item.IsLine then
  begin
    Canvas.Pen.Color := ArtEditorBorder;
    Canvas.MoveTo(ARect.Left, (ARect.Top + ARect.Bottom) div 2);
    Canvas.LineTo(ARect.Right, (ARect.Top + ARect.Bottom) div 2);
    Exit;
  end;
  Canvas.Font.Name := 'Yu Gothic UI';
  Canvas.Font.Height := -MulDiv(13, MenuPPI, 96);
  Canvas.Font.Color := ArtEditorText;
  if not Item.Enabled then Canvas.Font.Color := $00808080;
  Canvas.Brush.Style := bsClear;
  TextRect := ARect;
  TextRect.Left := TextRect.Left + MulDiv(8, MenuPPI, 96);
  if Item.Checked then
    DrawText(Canvas.Handle, '✓', 1, TextRect, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX);
  TextRect.Left := ARect.Left + MulDiv(28, MenuPPI, 96);
  DrawText(Canvas.Handle, PChar(Item.Caption), -1, TextRect, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX);
  Canvas.Brush.Style := bsSolid;
end;

procedure ApplyArtEditorTitleBar(Window: HWND);
var
  DarkMode: BOOL;
  CaptionColor, TextColor, BorderColor: COLORREF;
begin
  DarkMode := True;
  if Failed(DwmSetWindowAttribute(Window, 20, @DarkMode, SizeOf(DarkMode))) then
    DwmSetWindowAttribute(Window, 19, @DarkMode, SizeOf(DarkMode));
  CaptionColor := ColorToRGB(ArtEditorPanel);
  TextColor := ColorToRGB(ArtEditorText);
  BorderColor := ColorToRGB(ArtEditorBorder);
  DwmSetWindowAttribute(Window, 35, @CaptionColor, SizeOf(CaptionColor));
  DwmSetWindowAttribute(Window, 36, @TextColor, SizeOf(TextColor));
  DwmSetWindowAttribute(Window, 34, @BorderColor, SizeOf(BorderColor));
end;

end.
