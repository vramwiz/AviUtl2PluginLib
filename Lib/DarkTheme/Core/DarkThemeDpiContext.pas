unit DarkThemeDpiContext;

// 同じ画面に属するダークControlへDPIと寸法計算結果を一括配布する。
interface

uses
  System.Classes, System.Generics.Collections,
  Vcl.Controls,
  DarkThemeMetrics;

const
  CM_DARKTHEME_DPICHANGED = CM_BASE + 151;

type
  TDarkThemeDpiContext = class(TComponent)
  private
    FDpi: Integer;
    FControls: TList<TControl>;
    FMetrics: TDarkThemeMetrics;
    procedure SetDpi(const Value: Integer);
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    // 96 DPIを初期値とする画面単位のDPIコンテキストを生成する。
    constructor Create(AOwner: TComponent); override;
    // 登録Controlへの通知関係と内部一覧を破棄する。
    destructor Destroy; override;
    // Controlを登録し、現在DPIを直ちに通知する。nilと重複登録は無視する。
    procedure RegisterControl(Control: TControl);
    // Controlを通知対象から外す。未登録またはnilでも例外を発生させない。
    procedure UnregisterControl(Control: TControl);
    // ControlのCurrentPPIを正本として画面DPIを更新し、登録Controlへ通知する。
    procedure UpdateFromControl(Control: TControl);
    // 96 DPI基準値を現在の画面DPIへ変換する。
    function Scale(Value: Integer): Integer;
    property Dpi: Integer read FDpi write SetDpi;
    property Metrics: TDarkThemeMetrics read FMetrics;
  end;

implementation

uses
  Winapi.Windows;

constructor TDarkThemeDpiContext.Create(AOwner: TComponent);
begin
  inherited;
  FControls := TList<TControl>.Create;
  SetDpi(DarkThemeDesignDpi);
end;

destructor TDarkThemeDpiContext.Destroy;
begin
  FControls.Free;
  inherited;
end;

procedure TDarkThemeDpiContext.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent is TControl) then
    FControls.Remove(TControl(AComponent));
end;

procedure TDarkThemeDpiContext.RegisterControl(Control: TControl);
begin
  if (Control = nil) or FControls.Contains(Control) then
    Exit;
  FControls.Add(Control);
  Control.FreeNotification(Self);
  Control.Perform(CM_DARKTHEME_DPICHANGED, FDpi, 0);
end;

function TDarkThemeDpiContext.Scale(Value: Integer): Integer;
begin
  Result := FMetrics.Scale(Value);
end;

procedure TDarkThemeDpiContext.SetDpi(const Value: Integer);
var
  Control: TControl;
  NewDpi: Integer;
begin
  NewDpi := NormalizeDarkThemeDpi(Value);
  if (FDpi = NewDpi) and (FMetrics.Dpi = NewDpi) then
    Exit;
  FDpi := NewDpi;
  FMetrics := TDarkThemeMetrics.Create(FDpi);
  if FControls = nil then
    Exit;
  for Control in FControls.ToArray do
    if FControls.Contains(Control) then
      Control.Perform(CM_DARKTHEME_DPICHANGED, FDpi, 0);
end;

procedure TDarkThemeDpiContext.UnregisterControl(Control: TControl);
begin
  if Control = nil then
    Exit;
  FControls.Remove(Control);
  Control.RemoveFreeNotification(Self);
end;

procedure TDarkThemeDpiContext.UpdateFromControl(Control: TControl);
var
  TargetDpi: Integer;
begin
  // 埋め込みフレームでは親ウィンドウのGetDpiForWindow値と、VCLが既に
  // 適用したCurrentPPIが異なる場合がある。VCL寸法の二重拡大を避けるため、
  // コントロールが管理するPPIを正本とし、取得できない時だけHWNDへ戻る。
  TargetDpi := 0;
  if Control <> nil then
    TargetDpi := Control.CurrentPPI;
  if (TargetDpi <= 0) and (Control is TWinControl) and
    TWinControl(Control).HandleAllocated then
    TargetDpi := GetDpiForWindow(TWinControl(Control).Handle);
  Dpi := TargetDpi;
end;

end.
