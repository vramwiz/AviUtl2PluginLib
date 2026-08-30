unit DarkTreeView;

// 標準ツリーの機能を保ち、配色・項目高・インデントを共通化する。
interface

uses
  System.Classes,
  Vcl.ComCtrls, Vcl.Forms,
  Winapi.Messages,
  DarkThemeDpiContext;

type
  // 標準TTreeViewの配色とDPI寸法だけを共通化する。
  // ノード、画像リスト、編集、展開イベントはTTreeViewのまま利用できる。
  TDarkTreeView = class(TTreeView)
  private
    FDesignFontHeight: Integer;
    FDesignIndent: Integer;
    FDesignItemHeight: Integer;
    FDpiContext: TDarkThemeDpiContext;
    FUseThemeFont: Boolean;
    procedure CMDarkThemeDpiChanged(var Message: TMessage);
      message CM_DARKTHEME_DPICHANGED;
    procedure SetDesignFontHeight(const Value: Integer);
    procedure SetDesignIndent(const Value: Integer);
    procedure SetDesignItemHeight(const Value: Integer);
    procedure SetDpiContext(const Value: TDarkThemeDpiContext);
    procedure SetUseThemeFont(const Value: Boolean);
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
    procedure CreateWnd; override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    // 標準ノードAPIを利用できるダークツリーを生成する。
    constructor Create(AOwner: TComponent); override;
    // 共有DPIコンテキストから切り離してツリーを破棄する。
    destructor Destroy; override;
    // 基準文字高・項目高・インデントを現在DPIへ反映する。
    procedure ApplyDpi;
    // 背景・文字・接続線の共通配色をネイティブControlへ再適用する。
    procedure ApplyTheme;
  published
    property DesignFontHeight: Integer read FDesignFontHeight
      write SetDesignFontHeight default 12;
    property DesignIndent: Integer read FDesignIndent
      write SetDesignIndent default 16;
    property DesignItemHeight: Integer read FDesignItemHeight
      write SetDesignItemHeight default 20;
    property DpiContext: TDarkThemeDpiContext read FDpiContext
      write SetDpiContext;
    property UseThemeFont: Boolean read FUseThemeFont write SetUseThemeFont
      default True;
  end;

implementation

uses
  Winapi.CommCtrl, Winapi.UxTheme, Winapi.Windows,
  Vcl.Graphics,
  DarkThemeColors, DarkThemeMetrics;

constructor TDarkTreeView.Create(AOwner: TComponent);
begin
  inherited;
  FDesignFontHeight := DarkThemeDefaultFontHeight;
  FDesignIndent := 16;
  FDesignItemHeight := 20;
  FUseThemeFont := True;
  ParentColor := False;
  ParentFont := False;
  BorderStyle := bsNone;
  HideSelection := False;
  RowSelect := True;
  ShowLines := True;
  ShowRoot := True;
  ApplyTheme;
  ApplyDpi;
end;

destructor TDarkTreeView.Destroy;
begin
  SetDpiContext(nil);
  inherited;
end;

procedure TDarkTreeView.ApplyDpi;
var
  Metrics: TDarkThemeMetrics;
begin
  if FDpiContext <> nil then Metrics := FDpiContext.Metrics
  else Metrics := TDarkThemeMetrics.Create(CurrentPPI);
  if FUseThemeFont then Font.Height := Metrics.FontHeight(FDesignFontHeight);
  if HandleAllocated then
  begin
    Indent := Metrics.Scale(FDesignIndent);
    SendMessage(Handle, WM_SETFONT, WPARAM(Font.Handle), LPARAM(1));
    SendMessage(Handle, TVM_SETITEMHEIGHT,
      Metrics.Scale(FDesignItemHeight), 0);
  end;
  Invalidate;
end;

procedure TDarkTreeView.ApplyTheme;
begin
  Color := DarkThemeTreeBackground;
  Font.Color := DarkThemeTreeText;
  if HandleAllocated then
  begin
    SetWindowTheme(Handle, '', '');
    TreeView_SetBkColor(Handle, ColorToRGB(DarkThemeTreeBackground));
    TreeView_SetTextColor(Handle, ColorToRGB(DarkThemeTreeText));
    SendMessage(Handle, TVM_SETLINECOLOR, 0,
      ColorToRGB(DarkThemeTreeLine));
  end;
  Invalidate;
end;

procedure TDarkTreeView.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited;
  if FDpiContext <> nil then FDpiContext.Dpi := M else ApplyDpi;
end;

procedure TDarkTreeView.CMDarkThemeDpiChanged(var Message: TMessage);
begin
  ApplyDpi;
end;

procedure TDarkTreeView.CreateWnd;
begin
  inherited;
  ApplyTheme;
  ApplyDpi;
end;

procedure TDarkTreeView.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDpiContext) then FDpiContext := nil;
end;

procedure TDarkTreeView.SetDesignFontHeight(const Value: Integer);
begin
  if (Value < 1) or (FDesignFontHeight = Value) then Exit;
  FDesignFontHeight := Value;
  ApplyDpi;
end;

procedure TDarkTreeView.SetDesignIndent(const Value: Integer);
begin
  if (Value < 1) or (FDesignIndent = Value) then Exit;
  FDesignIndent := Value;
  ApplyDpi;
end;

procedure TDarkTreeView.SetDesignItemHeight(const Value: Integer);
begin
  if (Value < 1) or (FDesignItemHeight = Value) then Exit;
  FDesignItemHeight := Value;
  ApplyDpi;
end;

procedure TDarkTreeView.SetDpiContext(const Value: TDarkThemeDpiContext);
begin
  if FDpiContext = Value then Exit;
  if FDpiContext <> nil then
  begin
    FDpiContext.UnregisterControl(Self);
    FDpiContext.RemoveFreeNotification(Self);
  end;
  FDpiContext := Value;
  if FDpiContext <> nil then
  begin
    FDpiContext.FreeNotification(Self);
    FDpiContext.RegisterControl(Self);
  end
  else ApplyDpi;
end;

procedure TDarkTreeView.SetUseThemeFont(const Value: Boolean);
begin
  if FUseThemeFont = Value then Exit;
  FUseThemeFont := Value;
  ApplyDpi;
end;

initialization
  System.Classes.RegisterClass(TDarkTreeView);

end.
