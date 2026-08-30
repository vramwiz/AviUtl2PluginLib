unit DarkListBox;

// 通常・選択・無効状態とDPI寸法を共通化した一覧を提供する。
interface

uses
  System.Classes, System.Types, System.UITypes,
  Vcl.Controls, Vcl.StdCtrls,
  Winapi.Messages,
  DarkThemeDpiContext;

type
  TDarkListBox = class(TListBox)
  private
    FDesignFontHeight: Integer;
    FDesignItemHeight: Integer;
    FDpiContext: TDarkThemeDpiContext;
    FUseThemeFont: Boolean;
    procedure CMDarkThemeDpiChanged(var Message: TMessage);
      message CM_DARKTHEME_DPICHANGED;
    procedure SetDesignFontHeight(const Value: Integer);
    procedure SetDesignItemHeight(const Value: Integer);
    procedure SetDpiContext(const Value: TDarkThemeDpiContext);
    procedure SetUseThemeFont(const Value: Boolean);
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
    procedure CreateWnd; override;
    procedure DrawItem(Index: Integer; Rect: TRect;
      State: TOwnerDrawState); override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    // 固定高のオーナー描画一覧を共通配色で生成する。
    constructor Create(AOwner: TComponent); override;
    // 共有DPIコンテキストから切り離して一覧を破棄する。
    destructor Destroy; override;
    // 基準文字高と項目高を現在DPIへ反映する。
    procedure ApplyDpi;
    // 通常・選択・無効状態の一覧配色を再適用する。
    procedure ApplyTheme;
  published
    property DesignFontHeight: Integer read FDesignFontHeight
      write SetDesignFontHeight default 12;
    property DesignItemHeight: Integer read FDesignItemHeight
      write SetDesignItemHeight default 24;
    property DpiContext: TDarkThemeDpiContext read FDpiContext
      write SetDpiContext;
    property UseThemeFont: Boolean read FUseThemeFont write SetUseThemeFont
      default True;
  end;

implementation

uses
  Winapi.UxTheme, Winapi.Windows,
  Vcl.Graphics,
  DarkThemeColors, DarkThemeMetrics;

constructor TDarkListBox.Create(AOwner: TComponent);
begin
  inherited;
  FDesignFontHeight := DarkThemeDefaultFontHeight;
  FDesignItemHeight := 24;
  FUseThemeFont := True;
  ParentColor := False;
  ParentFont := False;
  Style := lbOwnerDrawFixed;
  ApplyTheme;
  ApplyDpi;
end;

destructor TDarkListBox.Destroy;
begin
  SetDpiContext(nil);
  inherited;
end;

procedure TDarkListBox.ApplyDpi;
var
  Metrics: TDarkThemeMetrics;
begin
  if FDpiContext <> nil then Metrics := FDpiContext.Metrics
  else Metrics := TDarkThemeMetrics.Create(CurrentPPI);
  if FUseThemeFont then Font.Height := Metrics.FontHeight(FDesignFontHeight);
  ItemHeight := Metrics.Scale(FDesignItemHeight);
  Invalidate;
end;

procedure TDarkListBox.ApplyTheme;
begin
  Color := DarkThemeListBackground;
  Font.Color := DarkThemeListText;
  Invalidate;
end;

procedure TDarkListBox.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited;
  if FDpiContext <> nil then FDpiContext.Dpi := M else ApplyDpi;
end;

procedure TDarkListBox.CMDarkThemeDpiChanged(var Message: TMessage);
begin
  ApplyDpi;
end;

procedure TDarkListBox.CreateWnd;
begin
  inherited;
  SetWindowTheme(Handle, 'DarkMode_Explorer', nil);
end;

procedure TDarkListBox.DrawItem(Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  TextValue: string;
begin
  if odSelected in State then
  begin
    Canvas.Brush.Color := DarkThemeListSelection;
    Canvas.Font.Color := DarkThemeListSelectionText;
  end
  else
  begin
    Canvas.Brush.Color := DarkThemeListBackground;
    if Enabled then Canvas.Font.Color := DarkThemeListText
    else Canvas.Font.Color := DarkThemeControlDisabledText;
  end;
  Canvas.FillRect(Rect);
  TextValue := '';
  if (Index >= 0) and (Index < Items.Count) then TextValue := Items[Index];
  Inc(Rect.Left, 6);
  Canvas.TextRect(Rect, Rect.Left,
    Rect.Top + (Rect.Height - Canvas.TextHeight(TextValue)) div 2, TextValue);
  if odFocused in State then
  begin
    Dec(Rect.Left, 4);
    Canvas.DrawFocusRect(Rect);
  end;
end;

procedure TDarkListBox.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDpiContext) then FDpiContext := nil;
end;

procedure TDarkListBox.SetDesignFontHeight(const Value: Integer);
begin
  if (Value < 1) or (FDesignFontHeight = Value) then Exit;
  FDesignFontHeight := Value;
  ApplyDpi;
end;

procedure TDarkListBox.SetDesignItemHeight(const Value: Integer);
begin
  if (Value < 1) or (FDesignItemHeight = Value) then Exit;
  FDesignItemHeight := Value;
  ApplyDpi;
end;

procedure TDarkListBox.SetDpiContext(const Value: TDarkThemeDpiContext);
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

procedure TDarkListBox.SetUseThemeFont(const Value: Boolean);
begin
  if FUseThemeFont = Value then Exit;
  FUseThemeFont := Value;
  ApplyDpi;
end;

initialization
  System.Classes.RegisterClass(TDarkListBox);

end.
