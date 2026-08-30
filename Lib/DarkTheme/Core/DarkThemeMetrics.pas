unit DarkThemeMetrics;

// 96 DPI基準の寸法を同じ丸め規則で実ピクセルへ変換する。
interface

const
  DarkThemeDesignDpi = 96;
  DarkThemeDefaultFontHeight = 12;
  DarkThemeButtonHeight = 32;
  DarkThemeButtonWidth = 96;
  DarkThemeBorderWidth = 1;
  DarkThemeFocusInset = 3;
  DarkThemeTextPadding = 3;

type
  TDarkThemeMetrics = record
  private
    FDpi: Integer;
  public
    // 指定DPIを正規化した、値型の寸法計算器を返す。
    class function Create(ADpi: Integer): TDarkThemeMetrics; static;
    // 96 DPI基準値を現在DPIのピクセル値へ変換する。
    function Scale(Value: Integer): Integer;
    // 正の基準値を最低1ピクセルとして現在DPIへ変換する。
    function ScaleAtLeastOne(Value: Integer): Integer;
    // 正の基準文字高をVCL Font.Height用の負値へ変換する。
    function FontHeight(DesignHeight: Integer = DarkThemeDefaultFontHeight): Integer;
    property Dpi: Integer read FDpi;
  end;

// 無効なDPI値を設計基準の96 DPIへ置き換える。
function NormalizeDarkThemeDpi(Dpi: Integer): Integer;
// 共有コンテキストを持たない呼出側向けに基準値を直接変換する。
function ScaleDarkThemeValue(Value, Dpi: Integer): Integer;

implementation

uses
  Winapi.Windows;

function NormalizeDarkThemeDpi(Dpi: Integer): Integer;
begin
  if Dpi <= 0 then
    Result := DarkThemeDesignDpi
  else
    Result := Dpi;
end;

function ScaleDarkThemeValue(Value, Dpi: Integer): Integer;
begin
  Result := MulDiv(Value, NormalizeDarkThemeDpi(Dpi), DarkThemeDesignDpi);
end;

class function TDarkThemeMetrics.Create(ADpi: Integer): TDarkThemeMetrics;
begin
  Result.FDpi := NormalizeDarkThemeDpi(ADpi);
end;

function TDarkThemeMetrics.FontHeight(DesignHeight: Integer): Integer;
begin
  Result := -ScaleAtLeastOne(DesignHeight);
end;

function TDarkThemeMetrics.Scale(Value: Integer): Integer;
begin
  Result := ScaleDarkThemeValue(Value, FDpi);
end;

function TDarkThemeMetrics.ScaleAtLeastOne(Value: Integer): Integer;
begin
  Result := Scale(Value);
  if (Value > 0) and (Result < 1) then
    Result := 1;
end;

end.
