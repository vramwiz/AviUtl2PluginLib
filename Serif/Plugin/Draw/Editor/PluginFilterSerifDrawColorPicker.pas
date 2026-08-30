unit PluginFilterSerifDrawColorPicker;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  ColorPickerHueBar,
  ColorPickerSVArea;

type
  // SerifDrawの設定画面内で使用する、数値入力を持たない色選択コントロール。
  TSerifDrawColorPickerControl = class(TCustomControl)
  private
    FColor: TColor;
    FCurrentHue: Double;
    FHueBar: TColorPickerHueBar;
    FOnChange: TNotifyEvent;
    FSVArea: TColorPickerSVArea;
    FUpdating: Boolean;
    procedure HueBarChange(Sender: TObject);
    procedure SetColor(const Value: TColor);
    procedure SVAreaChange(Sender: TObject);
    procedure SyncControls;
  protected
    procedure DoChange; virtual;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Color: TColor read FColor write SetColor;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

uses
  Winapi.Windows,
  ColorPickerColorMath;

constructor TSerifDrawColorPickerControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FColor := clWhite;
  FCurrentHue := 0;

  FHueBar := TColorPickerHueBar.Create(Self);
  FHueBar.Parent := Self;
  FHueBar.Align := alRight;
  FHueBar.Width := MulDiv(24, CurrentPPI, 96);
  FHueBar.OnChange := HueBarChange;

  FSVArea := TColorPickerSVArea.Create(Self);
  FSVArea.Parent := Self;
  FSVArea.Align := alClient;
  FSVArea.OnChange := SVAreaChange;
  SyncControls;
end;

procedure TSerifDrawColorPickerControl.Resize;
begin
  inherited;
  if FHueBar <> nil then
    FHueBar.Width := MulDiv(24, CurrentPPI, 96);
end;

procedure TSerifDrawColorPickerControl.DoChange;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TSerifDrawColorPickerControl.HueBarChange(Sender: TObject);
var
  Saturation: Double;
  Value: Double;
begin
  if FUpdating then
    Exit;
  FCurrentHue := ColorHue(FHueBar.Color);
  ColorToSv(FColor, Saturation, Value);
  FColor := HsvToColor(FCurrentHue, Saturation, Value);
  SyncControls;
  DoChange;
end;

procedure TSerifDrawColorPickerControl.SetColor(const Value: TColor);
var
  ColorValue: Double;
  Hue: Double;
  Saturation: Double;
begin
  FColor := ColorToRGB(Value);
  ColorToHsv(FColor, Hue, Saturation, ColorValue);
  if (Saturation > 0.000001) and (ColorValue > 0) then
    FCurrentHue := Hue;
  SyncControls;
end;

procedure TSerifDrawColorPickerControl.SVAreaChange(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FColor := FSVArea.Color;
  SyncControls;
  DoChange;
end;

procedure TSerifDrawColorPickerControl.SyncControls;
begin
  if FUpdating then
    Exit;
  FUpdating := True;
  try
    FHueBar.Color := HsvToColor(FCurrentHue, 1, 1);
    FSVArea.BaseColor := HsvToColor(FCurrentHue, 1, 1);
    FSVArea.Color := FColor;
  finally
    FUpdating := False;
  end;
end;

end.
