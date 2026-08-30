unit DarkPanel;

// 共通背景・文字色・枠と任意のDPI基準高さを持つパネルを提供する。
interface

uses
  Winapi.Messages,
  System.Classes,
  Vcl.Controls, Vcl.ExtCtrls,
  DarkThemeDpiContext;

type
  TDarkPanel = class(TPanel)
  private
    FDesignHeight: Integer;
    FDpiContext: TDarkThemeDpiContext;
    procedure CMDarkThemeDpiChanged(var Message: TMessage);
      message CM_DARKTHEME_DPICHANGED;
    procedure SetDesignHeight(const Value: Integer);
    procedure SetDpiContext(const Value: TDarkThemeDpiContext);
  protected
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    // 共通パネル配色を適用したコンテナを生成する。
    constructor Create(AOwner: TComponent); override;
    // 共有DPIコンテキストから切り離してパネルを破棄する。
    destructor Destroy; override;
    // DesignHeightが指定されている場合だけ現在DPIへ高さを反映する。
    procedure ApplyDpi;
    // 共通背景・文字色と枠なし表示を再適用する。
    procedure ApplyTheme;
  published
    property DesignHeight: Integer read FDesignHeight write SetDesignHeight
      default 0;
    property DpiContext: TDarkThemeDpiContext read FDpiContext
      write SetDpiContext;
  end;

implementation

uses
  DarkThemeColors, DarkThemeMetrics;

constructor TDarkPanel.Create(AOwner: TComponent);
begin
  inherited;
  ApplyTheme;
end;

destructor TDarkPanel.Destroy;
begin
  SetDpiContext(nil);
  inherited;
end;

procedure TDarkPanel.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited;
  if FDpiContext <> nil then
    FDpiContext.Dpi := M
  else
    ApplyDpi;
end;

procedure TDarkPanel.ApplyDpi;
begin
  if FDesignHeight <= 0 then
    Exit;
  if FDpiContext <> nil then
    Height := FDpiContext.Scale(FDesignHeight)
  else
    Height := ScaleDarkThemeValue(FDesignHeight, CurrentPPI);
end;

procedure TDarkPanel.ApplyTheme;
begin
  ParentBackground := False;
  Color := DarkThemePanelBackground;
  Font.Color := DarkThemePanelText;
  BevelOuter := bvNone;
  Invalidate;
end;

procedure TDarkPanel.CMDarkThemeDpiChanged(var Message: TMessage);
begin
  ApplyDpi;
end;

procedure TDarkPanel.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDpiContext) then
    FDpiContext := nil;
end;

procedure TDarkPanel.SetDesignHeight(const Value: Integer);
var
  NewValue: Integer;
begin
  if Value < 0 then
    NewValue := 0
  else
    NewValue := Value;
  if FDesignHeight = NewValue then
    Exit;
  FDesignHeight := NewValue;
  ApplyDpi;
end;

procedure TDarkPanel.SetDpiContext(const Value: TDarkThemeDpiContext);
begin
  if FDpiContext = Value then
    Exit;
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
  else
    ApplyDpi;
end;

initialization
  RegisterClass(TDarkPanel);

end.
