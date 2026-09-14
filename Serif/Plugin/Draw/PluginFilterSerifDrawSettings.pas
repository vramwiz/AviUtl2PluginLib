unit PluginFilterSerifDrawSettings;

// SerifDrawのSD7保存形式、共通設定、配役差分、描画用スタイル解決を担当する。

interface

uses
  AviUtl2FilterTypes;

type
  TSerifDrawFontStyles = Byte;

const
  SERIF_FONT_BOLD = $01;
  SERIF_FONT_ITALIC = $02;
  SERIF_ALIGN_LEADING = 0;
  SERIF_ALIGN_CENTER = 1;
  SERIF_ALIGN_TRAILING = 2;
  SERIF_FRAME_FILL_SOLID = 0;
  SERIF_FRAME_FILL_VERTICAL_GRADIENT = 1;
  SERIF_PLACEMENT_TOP_LEFT = 0;
  SERIF_PLACEMENT_TOP_CENTER = 1;
  SERIF_PLACEMENT_TOP_RIGHT = 2;
  SERIF_PLACEMENT_CENTER_LEFT = 3;
  SERIF_PLACEMENT_CENTER = 4;
  SERIF_PLACEMENT_CENTER_RIGHT = 5;
  SERIF_PLACEMENT_BOTTOM_LEFT = 6;
  SERIF_PLACEMENT_BOTTOM_CENTER = 7;
  SERIF_PLACEMENT_BOTTOM_RIGHT = 8;
  // 文字の縁・影はフォントサイズ比（%）で保持し、フォント変更時も見た目の比率を保つ。
  SERIF_TEXT_OUTLINE_WIDTH_MAX_PERCENT = 100.0;
  SERIF_TEXT_OUTLINE_BLUR_MAX_PERCENT = 20.0;
  SERIF_TEXT_SHADOW_BLUR_MAX_PERCENT = 20.0;
  SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT = 60.0;
  SERIF_TEXT_SHADOW_SPREAD_MAX_PERCENT = 30.0;
  // 比率上限だけでは大文字時に重いため、レンダラー境界で適用するpx上限も併用する。
  SERIF_TEXT_OUTLINE_WIDTH_MAX_PIXELS = 120.0;
  SERIF_TEXT_OUTLINE_BLUR_MAX_PIXELS = 40.0;
  SERIF_TEXT_SHADOW_BLUR_MAX_PIXELS = 40.0;
  SERIF_TEXT_SHADOW_OFFSET_MAX_PIXELS = 120.0;
  SERIF_TEXT_SHADOW_SPREAD_MAX_PIXELS = 60.0;

type
  // 配役ごとに独立して保持するのは色だけとする。
  // 配置・寸法・フォント・装飾形状はTSerifDrawSettingsの共通値を使う。
  TSerifDrawLayerColors = record
    // 各色はAARRGGBB。RoleNameは正規化済みの配役キー。
    BlurColor: Cardinal;
    FillColor: Cardinal;
    RoleName: string;
    // Layerは編集画面の選択情報で、保存・検索キーには使用しない。
    Layer: Integer;
    OutlineColor: Cardinal;
    ShadowColor: Cardinal;
  end;

  // 描画時に共通値と配役色を合成した一時的なスタイル。
  TSerifDrawLayerStyle = record
    // 文字の縁・影の装飾量は文字サイズ比（%）、配置と文字間隔はpx。
    Alignment: Byte;
    BlurColor: Cardinal;
    FillColor: Cardinal;
    FontName: string;
    FontSize: Double;
    FontStyles: TSerifDrawFontStyles;
    Layer: Integer;
    LetterSpacing: Double;
    LineSpacing: Double;
    OutlineColor: Cardinal;
    OutlineBlur: Double;
    OutlineEnabled: Boolean;
    OutlineWidth: Double;
    ShadowBlur: Double;
    ShadowColor: Cardinal;
    ShadowEnabled: Boolean;
    ShadowOffsetX: Double;
    ShadowOffsetY: Double;
    ShadowSpread: Double;
  end;

  // 共通枠またはレイヤー別枠として編集・描画する一式。
  TSerifDrawFrameStyle = record
    // 0は保存色、1は対象レイヤーの文字縁色RGBを使用する。
    AccentSource: Byte;
    // 尾方向は0=下、1=上、2=左、3=右。寸法と位置は映像座標系のピクセル値。
    BalloonTailDirection: Integer;
    BalloonTailLength: Integer;
    BalloonTailPosition: Integer;
    BalloonTailWidth: Integer;
    CornerRadius: Integer;
    DottedDashLength: Integer;
    DottedGapLength: Integer;
    // 色はAARRGGBB。Visibleは対応する効果を描画するかを示す。
    FillColor: Cardinal;
    // FillModeは0=単色、1=上下グラデーション。GradientStrengthは明暗差の割合。
    FillMode: Byte;
    GradientStrength: Byte;
    FillVisible: Boolean;
    Height: Integer;
    InnerOutlineColor: Cardinal;
    InnerPanelColor: Cardinal;
    InnerPanelInsetX: Integer;
    InnerPanelInsetY: Integer;
    InnerPanelRadius: Integer;
    // Layeringは0=単層、1=内側パネル。RoleNameは正規化済み配役キー。
    Layering: Byte;
    RoleName: string;
    // Layerは編集画面の選択情報で、保存・検索キーには使用しない。
    Layer: Integer;
    OutlineColor: Cardinal;
    // OutlineStyleは0=単線、1=二重線、2=ネオン、3=点線。
    OutlineStyle: Byte;
    OutlineVisible: Boolean;
    OutlineWidth: Integer;
    // 枠中心の映像中心からの相対位置。単位はピクセル。
    PositionX: Double;
    PositionY: Double;
    ShadowBlur: Double;
    ShadowColor: Cardinal;
    ShadowOffsetX: Double;
    ShadowOffsetY: Double;
    ShadowSpread: Double;
    ShadowVisible: Boolean;
    // Shapeは0=四角、1=角丸、2=タブ、3=吹き出し。
    Shape: Byte;
    TabHeight: Integer;
    TabOffset: Integer;
    TabWidth: Integer;
    Width: Integer;
  end;

  TSerifDrawSettings = record
    // 文字と枠の共通設定。文字装飾は%、その他の寸法は映像px、色はAARRGGBB。
    Alignment: Byte;
    BlurColor: Cardinal;
    FillColor: Cardinal;
    FontName: string;
    FontSize: Double;
    FontStyles: TSerifDrawFontStyles;
    // Frame接頭辞のフィールドは共通枠の保存値で、TSerifDrawFrameStyleと同じ意味を持つ。
    FrameBalloonTailDirection: Integer;
    FrameBalloonTailLength: Integer;
    FrameBalloonTailPosition: Integer;
    FrameBalloonTailWidth: Integer;
    FrameAccentSource: Byte;
    FrameFillColor: Cardinal;
    FrameFillMode: Byte;
    FrameGradientStrength: Byte;
    FrameFillVisible: Boolean;
    FrameHeight: Integer;
    FrameInnerOutlineColor: Cardinal;
    FrameInnerPanelColor: Cardinal;
    FrameInnerPanelInsetX: Integer;
    FrameInnerPanelInsetY: Integer;
    FrameInnerPanelRadius: Integer;
    FrameLayering: Byte;
    FrameKind: Byte;
    FrameCornerRadius: Integer;
    FrameDottedDashLength: Integer;
    FrameDottedGapLength: Integer;
    FrameShape: Byte;
    FrameOutlineColor: Cardinal;
    FrameOutlineStyle: Byte;
    FrameOutlineWidth: Integer;
    FrameOutlineVisible: Boolean;
    FramePositionX: Double;
    FramePositionY: Double;
    FrameShadowColor: Cardinal;
    FrameShadowBlur: Double;
    FrameShadowOffsetX: Double;
    FrameShadowOffsetY: Double;
    FrameShadowSpread: Double;
    FrameShadowVisible: Boolean;
    FrameTabHeight: Integer;
    FrameTabOffset: Integer;
    FrameTabWidth: Integer;
    FrameWidth: Integer;
    // キャラ別枠と文字色は配役名をキーにした共通値との差分だけを保持する。
    LayerFrames: TArray<TSerifDrawFrameStyle>;
    LayerColors: TArray<TSerifDrawLayerColors>;
    LetterSpacing: Double;
    LineSpacing: Double;
    OutlineColor: Cardinal;
    // 本文の縁・影の形状値はFontSizeに対する百分率。
    OutlineBlur: Double;
    OutlineEnabled: Boolean;
    OutlineWidth: Double;
    Placement: Byte;
    PositionX: Double;
    PositionY: Double;
    // 配役名はセリフ本文とは別の共通文字設定と共通配置を保持する。
    RoleNamePlacement: Byte;
    RoleNamePositionX: Double;
    RoleNamePositionY: Double;
    RoleNameBlurColor: Cardinal;
    RoleNameFillColor: Cardinal;
    RoleNameFontName: string;
    RoleNameFontSize: Double;
    RoleNameFontStyles: TSerifDrawFontStyles;
    RoleNameLetterSpacing: Double;
    RoleNameLineSpacing: Double;
    RoleNameVisible: Boolean;
    // 配役名の縁・影もRoleNameFontSizeに対する百分率。
    RoleNameOutlineBlur: Double;
    RoleNameOutlineColor: Cardinal;
    RoleNameOutlineEnabled: Boolean;
    RoleNameOutlineWidth: Double;
    RoleNameShadowBlur: Double;
    RoleNameShadowColor: Cardinal;
    RoleNameShadowEnabled: Boolean;
    RoleNameShadowOffsetX: Double;
    RoleNameShadowOffsetY: Double;
    RoleNameShadowSpread: Double;
    // 配役名のフォント・装飾形状・配置は共通とし、色だけを配役別に保持する。
    RoleNameLayerColors: TArray<TSerifDrawLayerColors>;
    ShadowBlur: Double;
    ShadowColor: Cardinal;
    ShadowEnabled: Boolean;
    ShadowOffsetX: Double;
    ShadowOffsetY: Double;
    ShadowSpread: Double;
    // 新規設定を既定値で初期化する。
    class function Default: TSerifDrawSettings; static;
    // 共通枠の保存フィールドを、描画・編集用の枠スタイルへまとめる。
    function CommonFrameStyle: TSerifDrawFrameStyle;
    // 現在値をSD7文字列へ直列化する。配役別色と枠も末尾へ含める。
    function Encode: string;
    // 指定配役に明示的なキャラ別枠が保存されているかを返す。
    function HasLayerFrameStyle(const ARoleName: string): Boolean;
    // 指定配役のキャラ別枠だけを削除し、以後は共通枠を継承させる。
    procedure RemoveLayerFrameStyle(const ARoleName: string);
    // 指定配役の文字色差分を削除する。
    procedure RemoveLayerColors(const ARoleName: string);
    // 共通文字設定へ指定配役の色差分を合成する。
    function ResolveStyle(const ALayer: Integer;
      const ARoleName: string): TSerifDrawLayerStyle;
    // 配役名専用の文字装飾を描画・編集用スタイルへまとめる。
    function ResolveRoleNameStyle(const ALayer: Integer;
      const ARoleName: string): TSerifDrawLayerStyle;
    // 指定配役のキャラ別枠がなければ共通枠を継承する。
    function ResolveFrameStyle(const ALayer: Integer;
      const ARoleName: string): TSerifDrawFrameStyle;
    // 共通枠へ対象配役の色を描画時だけ合成する。保存色は変更しない。
    function ResolveCommonFrameAppearance(
      const AAccentRoleName: string): TSerifDrawFrameStyle;
    // 継承解決後の枠へ指定配役の色を描画時だけ合成する。
    function ResolveFrameAppearance(const ALayer: Integer;
      const ARoleName: string): TSerifDrawFrameStyle;
    // 枠スタイルを共通枠の各保存フィールドへ反映する。
    procedure SetCommonFrameStyle(const AStyle: TSerifDrawFrameStyle);
    // RoleNameをキーにキャラ別枠を追加または置換する。空の配役名は無視する。
    procedure SetLayerFrameStyle(const AStyle: TSerifDrawFrameStyle);
    // RoleNameをキーに文字色差分を追加または置換する。
    procedure SetLayerColors(const AColors: TSerifDrawLayerColors);
    procedure RemoveRoleNameLayerColors(const ARoleName: string);
    procedure SetRoleNameLayerColors(const AColors: TSerifDrawLayerColors);
    // SD7文字列を検証しながら復元する。失敗時はFalseと理由を返す。
    class function TryDecode(const AText: string;
      out ASettings: TSerifDrawSettings; out AError: string): Boolean; static;
  end;

var
  SerifDrawSettingsItem: TFILTER_ITEM_STRING;

// AviUtl2から受け取った現在の設定文字列を復元し、失敗時は既定値を返す。
function CurrentSerifDrawSettings: TSerifDrawSettings;
// 文字サイズ比の縁取り幅を負荷上限付きの描画pxへ変換する。
function SerifDrawOutlineWidthPixels(const APercent,
  AFontSize: Double): Double;
// 文字サイズ比の縁ぼかしを負荷上限付きの描画pxへ変換する。
function SerifDrawOutlineBlurPixels(const APercent,
  AFontSize: Double): Double;
// 文字サイズ比の影ぼかしを負荷上限付きの描画pxへ変換する。
function SerifDrawShadowBlurPixels(const APercent,
  AFontSize: Double): Double;
// 文字サイズ比の影移動量を符号を維持して描画pxへ変換する。
function SerifDrawShadowOffsetPixels(const APercent,
  AFontSize: Double): Double;
// 文字サイズ比の影広がりを負荷上限付きの描画pxへ変換する。
function SerifDrawShadowSpreadPixels(const APercent,
  AFontSize: Double): Double;
// 基準色のAlphaを維持し、枠中央を基準色、上端を明色、下端を暗色に補間する。
function SerifDrawFrameGradientColor(const AColor: Cardinal;
  const AFillMode, AStrength, AY, ATop, ABottom: Integer): Cardinal;

implementation

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  PluginFilterSerifDrawRoleNames,
  PluginFilterSerifDrawStyle
{$IFDEF DEBUG}
  , PluginFilterSerifDrawDebugLog,
  Winapi.Windows
{$ENDIF}
  ;

{$IFDEF DEBUG}
var
  SettingsReadLogCount: Integer;
{$ENDIF}

function SerifDrawTextRatioPixels(const APercent, AFontSize, AMaxPercent,
  AMaxPixels: Double): Double;
begin
  // 保存値は%のまま維持し、Skiaへ渡す直前だけpx化する。
  Result := Min(AMaxPixels,
    EnsureRange(APercent, 0.0, AMaxPercent) * Max(1.0, AFontSize) / 100.0);
end;

function SerifDrawOutlineWidthPixels(const APercent,
  AFontSize: Double): Double;
begin
  Result := SerifDrawTextRatioPixels(APercent, AFontSize,
    SERIF_TEXT_OUTLINE_WIDTH_MAX_PERCENT,
    SERIF_TEXT_OUTLINE_WIDTH_MAX_PIXELS);
end;

function SerifDrawOutlineBlurPixels(const APercent,
  AFontSize: Double): Double;
begin
  Result := SerifDrawTextRatioPixels(APercent, AFontSize,
    SERIF_TEXT_OUTLINE_BLUR_MAX_PERCENT,
    SERIF_TEXT_OUTLINE_BLUR_MAX_PIXELS);
end;

function SerifDrawShadowBlurPixels(const APercent,
  AFontSize: Double): Double;
begin
  Result := SerifDrawTextRatioPixels(APercent, AFontSize,
    SERIF_TEXT_SHADOW_BLUR_MAX_PERCENT,
    SERIF_TEXT_SHADOW_BLUR_MAX_PIXELS);
end;

function SerifDrawShadowOffsetPixels(const APercent,
  AFontSize: Double): Double;
var
  Magnitude: Double;
begin
  Magnitude := SerifDrawTextRatioPixels(Abs(APercent), AFontSize,
    SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT,
    SERIF_TEXT_SHADOW_OFFSET_MAX_PIXELS);
  if APercent < 0 then
    Result := -Magnitude
  else
    Result := Magnitude;
end;

function SerifDrawShadowSpreadPixels(const APercent,
  AFontSize: Double): Double;
begin
  Result := SerifDrawTextRatioPixels(APercent, AFontSize,
    SERIF_TEXT_SHADOW_SPREAD_MAX_PERCENT,
    SERIF_TEXT_SHADOW_SPREAD_MAX_PIXELS);
end;

function EncodeTextHex(const AText: string): string;
var
  B: Byte;
  Bytes: TBytes;
begin
  Result := '';
  Bytes := TEncoding.UTF8.GetBytes(AText);
  for B in Bytes do
    Result := Result + IntToHex(B, 2);
end;

function TryDecodeTextHex(const AText: string; out AValue: string): Boolean;
var
  Bytes: TBytes;
  I: Integer;
  Value: Integer;
begin
  AValue := '';
  if Odd(Length(AText)) or (Length(AText) > 512) then
    Exit(False);
  SetLength(Bytes, Length(AText) div 2);
  for I := 0 to High(Bytes) do
  begin
    if not TryStrToInt('$' + Copy(AText, I * 2 + 1, 2), Value) then
      Exit(False);
    Bytes[I] := Byte(Value);
  end;
  try
    AValue := TEncoding.UTF8.GetString(Bytes);
    Result := Length(AValue) <= 128;
  except
    Result := False;
  end;
end;

function InvariantFormatSettings: TFormatSettings;
begin
  Result := TFormatSettings.Create('en-US');
end;

function TryParseColor(const AText: string; out AColor: Cardinal): Boolean;
var
  Value: UInt64;
begin
  Result := (Length(AText) = 8) and TryStrToUInt64('$' + AText, Value) and
    (Value <= High(Cardinal));
  if Result then
    AColor := Cardinal(Value);
end;

function TryParseBoolean(const AText: string; out AValue: Boolean): Boolean;
var
  Value: Integer;
begin
  Result := TryStrToInt(AText, Value) and (Value in [0, 1]);
  if Result then
    AValue := Value <> 0;
end;

function TryParseLayerColors(const AText: string;
  out AColors: TSerifDrawLayerColors): Boolean;
var
  Fields: TStringList;
begin
  AColors := System.Default(TSerifDrawLayerColors);
  Fields := TStringList.Create;
  try
    Fields.StrictDelimiter := True;
    Fields.Delimiter := ',';
    Fields.DelimitedText := AText;
    Result := (Fields.Count = 5) and
      TryDecodeTextHex(Fields[0], AColors.RoleName) and
      TryParseColor(Fields[1], AColors.FillColor) and
      TryParseColor(Fields[2], AColors.OutlineColor) and
      TryParseColor(Fields[3], AColors.ShadowColor) and
      TryParseColor(Fields[4], AColors.BlurColor) and
      (AColors.RoleName <> '');
  finally
    Fields.Free;
  end;
end;

function TryParseFrameStyle(const AText: string;
  out AStyle: TSerifDrawFrameStyle): Boolean;
var
  FS: TFormatSettings;
  Fields: TStringList;
  OutlineStyleValue: Integer;
  ShapeValue: Integer;
begin
  AStyle := System.Default(TSerifDrawFrameStyle);
  AStyle.AccentSource := 0;
  AStyle.FillMode := SERIF_FRAME_FILL_SOLID;
  AStyle.GradientStrength := 30;
  AStyle.CornerRadius := 32;
  AStyle.TabWidth := 250;
  AStyle.TabHeight := 64;
  AStyle.TabOffset := 24;
  AStyle.BalloonTailPosition := 0;
  AStyle.BalloonTailWidth := 100;
  AStyle.BalloonTailLength := 60;
  AStyle.BalloonTailDirection := 0;
  AStyle.OutlineStyle := 0;
  AStyle.InnerOutlineColor := $FFE6E6E6;
  AStyle.DottedDashLength := 24;
  AStyle.DottedGapLength := 24;
  AStyle.Layering := 0;
  AStyle.InnerPanelColor := $FFFFFFFF;
  AStyle.InnerPanelInsetX := 28;
  AStyle.InnerPanelInsetY := 20;
  AStyle.InnerPanelRadius := 16;
  FS := InvariantFormatSettings;
  Fields := TStringList.Create;
  try
    Fields.StrictDelimiter := True;
    Fields.Delimiter := ',';
    Fields.DelimitedText := AText;
    Result := (Fields.Count = 37) and
      TryDecodeTextHex(Fields[0], AStyle.RoleName) and
      TryStrToInt(Fields[1], ShapeValue) and
      TryStrToFloat(Fields[2], AStyle.PositionX, FS) and
      TryStrToFloat(Fields[3], AStyle.PositionY, FS) and
      TryStrToInt(Fields[4], AStyle.Width) and
      TryStrToInt(Fields[5], AStyle.Height) and
      TryParseBoolean(Fields[6], AStyle.FillVisible) and
      TryParseBoolean(Fields[7], AStyle.OutlineVisible) and
      TryStrToInt(Fields[8], AStyle.OutlineWidth) and
      TryParseBoolean(Fields[9], AStyle.ShadowVisible) and
      TryStrToFloat(Fields[10], AStyle.ShadowBlur, FS) and
      TryStrToFloat(Fields[11], AStyle.ShadowOffsetX, FS) and
      TryStrToFloat(Fields[12], AStyle.ShadowOffsetY, FS) and
      TryStrToFloat(Fields[13], AStyle.ShadowSpread, FS) and
      TryParseColor(Fields[14], AStyle.FillColor) and
      TryParseColor(Fields[15], AStyle.OutlineColor) and
      TryParseColor(Fields[16], AStyle.ShadowColor) and
      (AStyle.RoleName <> '') and
      (ShapeValue >= 0) and (ShapeValue <= 3) and
      (AStyle.Width >= 1) and (AStyle.Width <= 20000) and
      (AStyle.Height >= 1) and (AStyle.Height <= 20000) and
      (AStyle.PositionX >= -20000) and (AStyle.PositionX <= 20000) and
      (AStyle.PositionY >= -20000) and (AStyle.PositionY <= 20000) and
      (AStyle.OutlineWidth >= 0) and (AStyle.OutlineWidth <= 500) and
      (AStyle.ShadowBlur >= 0) and (AStyle.ShadowBlur <= 500) and
      (AStyle.ShadowOffsetX >= -2000) and
      (AStyle.ShadowOffsetX <= 2000) and
      (AStyle.ShadowOffsetY >= -2000) and
      (AStyle.ShadowOffsetY <= 2000) and
      (AStyle.ShadowSpread >= 0) and (AStyle.ShadowSpread <= 500);
    if Result and (Fields.Count = 18) then
      Result := TryStrToInt(Fields[17], AStyle.CornerRadius) and
        (AStyle.CornerRadius >= 0) and (AStyle.CornerRadius <= 500);
    if Result and (Fields.Count = 21) then
      Result := TryStrToInt(Fields[17], AStyle.CornerRadius) and
        TryStrToInt(Fields[18], AStyle.TabWidth) and
        TryStrToInt(Fields[19], AStyle.TabHeight) and
        TryStrToInt(Fields[20], AStyle.TabOffset) and
        (AStyle.CornerRadius >= 0) and (AStyle.CornerRadius <= 500) and
        (AStyle.TabWidth >= 1) and (AStyle.TabWidth <= 20000) and
        (AStyle.TabHeight >= 1) and (AStyle.TabHeight <= 20000) and
        (AStyle.TabOffset >= 0) and (AStyle.TabOffset <= 20000);
    if Result and (Fields.Count >= 24) then
      Result := TryStrToInt(Fields[17], AStyle.CornerRadius) and
        TryStrToInt(Fields[18], AStyle.TabWidth) and
        TryStrToInt(Fields[19], AStyle.TabHeight) and
        TryStrToInt(Fields[20], AStyle.TabOffset) and
        TryStrToInt(Fields[21], AStyle.BalloonTailPosition) and
        TryStrToInt(Fields[22], AStyle.BalloonTailWidth) and
        TryStrToInt(Fields[23], AStyle.BalloonTailLength) and
        (AStyle.CornerRadius >= 0) and (AStyle.CornerRadius <= 500) and
        (AStyle.TabWidth >= 1) and (AStyle.TabWidth <= 20000) and
        (AStyle.TabHeight >= 1) and (AStyle.TabHeight <= 20000) and
        (AStyle.TabOffset >= 0) and (AStyle.TabOffset <= 20000) and
        (AStyle.BalloonTailPosition >= -20000) and
        (AStyle.BalloonTailPosition <= 20000) and
        (AStyle.BalloonTailWidth >= 1) and
        (AStyle.BalloonTailWidth <= 20000) and
        (AStyle.BalloonTailLength >= 1) and
        (AStyle.BalloonTailLength <= 20000);
    if Result and (Fields.Count >= 25) then
      Result := TryStrToInt(Fields[24], AStyle.BalloonTailDirection) and
        (AStyle.BalloonTailDirection >= 0) and
        (AStyle.BalloonTailDirection <= 3);
    if Result and (Fields.Count >= 26) then
    begin
      Result := TryStrToInt(Fields[25], OutlineStyleValue) and
        (OutlineStyleValue >= 0) and (OutlineStyleValue <= 3);
      if Result then
        AStyle.OutlineStyle := OutlineStyleValue;
    end;
    if Result and (Fields.Count = 27) then
      Result := TryParseColor(Fields[26], AStyle.InnerOutlineColor);
    if Result and (Fields.Count >= 29) then
      Result := TryParseColor(Fields[26], AStyle.InnerOutlineColor) and
        TryStrToInt(Fields[27], AStyle.DottedDashLength) and
        TryStrToInt(Fields[28], AStyle.DottedGapLength) and
        (AStyle.DottedDashLength >= 1) and
        (AStyle.DottedDashLength <= 20000) and
        (AStyle.DottedGapLength >= 1) and
        (AStyle.DottedGapLength <= 20000);
    if Result and (Fields.Count >= 31) then
      Result := TryStrToInt(Fields[29], OutlineStyleValue) and
        (OutlineStyleValue in [0, 1]) and
        TryParseColor(Fields[30], AStyle.InnerPanelColor);
    if Result and (Fields.Count >= 31) then
      AStyle.Layering := OutlineStyleValue;
    if Result and (Fields.Count >= 34) then
      Result := TryStrToInt(Fields[31], AStyle.InnerPanelInsetX) and
        TryStrToInt(Fields[32], AStyle.InnerPanelInsetY) and
        TryStrToInt(Fields[33], AStyle.InnerPanelRadius) and
        (AStyle.InnerPanelInsetX >= 0) and
        (AStyle.InnerPanelInsetX <= 10000) and
        (AStyle.InnerPanelInsetY >= 0) and
        (AStyle.InnerPanelInsetY <= 10000) and
        (AStyle.InnerPanelRadius >= 0) and
        (AStyle.InnerPanelRadius <= 500);
    if Result and (Fields.Count >= 35) then
      Result := TryStrToInt(Fields[34], OutlineStyleValue) and
        (OutlineStyleValue in [0, 1]);
    if Result and (Fields.Count >= 35) then
      AStyle.AccentSource := OutlineStyleValue;
    if Result and (Fields.Count >= 36) then
      Result := TryStrToInt(Fields[35], OutlineStyleValue) and
        (OutlineStyleValue in [SERIF_FRAME_FILL_SOLID,
          SERIF_FRAME_FILL_VERTICAL_GRADIENT]);
    if Result and (Fields.Count >= 36) then
      AStyle.FillMode := OutlineStyleValue;
    if Result and (Fields.Count = 37) then
      Result := TryStrToInt(Fields[36], OutlineStyleValue) and
        (OutlineStyleValue >= 0) and (OutlineStyleValue <= 100);
    if Result and (Fields.Count = 37) then
      AStyle.GradientStrength := OutlineStyleValue;
    if Result and (Fields.Count < 27) then
      AStyle.InnerOutlineColor := AStyle.OutlineColor;
    if Result then
      AStyle.Shape := ShapeValue;
  finally
    Fields.Free;
  end;
end;

function CurrentSerifDrawSettings: TSerifDrawSettings;
var
  ErrorText: string;
  Text: string;
begin
  Text := '';
  if Assigned(SerifDrawSettingsItem.Value) then
    Text := string(SerifDrawSettingsItem.Value);
  Text := ResolveSerifDrawStyleText(Text);
  if not TSerifDrawSettings.TryDecode(Text, Result, ErrorText) then
  begin
{$IFDEF DEBUG}
    if InterlockedIncrement(SettingsReadLogCount) <= 40 then
      SerifDrawDebugLog(Format(
        'Settings read failed: length=%d error=%s text=%s',
        [Length(Text), ErrorText, Copy(Text, 1, 320)]));
{$ENDIF}
    Result := TSerifDrawSettings.Default;
  end
{$IFDEF DEBUG}
  else if InterlockedIncrement(SettingsReadLogCount) <= 40 then
    SerifDrawDebugLog(Format(
      'Settings read accepted: length=%d font=%.3f placement=%d pos=(%.3f,%.3f)',
      [Length(Text), Result.FontSize, Result.Placement,
       Result.PositionX, Result.PositionY]))
{$ENDIF}
  ;
end;

function SerifDrawFrameGradientColor(const AColor: Cardinal;
  const AFillMode, AStrength, AY, ATop, ABottom: Integer): Cardinal;
var
  B: Integer;
  Distance: Integer;
  G: Integer;
  HeightMinusOne: Integer;
  R: Integer;
  Strength: Integer;

  function AdjustChannel(const AValue: Integer): Integer;
  begin
    if Distance <= 0 then
      Exit(AValue);
    if AY * 2 <= ATop + ABottom - 1 then
      Result := AValue + ((255 - AValue) * Distance * Strength +
        HeightMinusOne * 50) div (HeightMinusOne * 100)
    else
      Result := AValue - (AValue * Distance * Strength +
        HeightMinusOne * 50) div (HeightMinusOne * 100);
    Result := EnsureRange(Result, 0, 255);
  end;
begin
  Strength := EnsureRange(AStrength, 0, 100);
  HeightMinusOne := ABottom - ATop - 1;
  if (AFillMode <> SERIF_FRAME_FILL_VERTICAL_GRADIENT) or
    (Strength = 0) or (HeightMinusOne <= 0) then
    Exit(AColor);
  Distance := Abs(2 * EnsureRange(AY - ATop, 0, HeightMinusOne) -
    HeightMinusOne);
  R := AdjustChannel((AColor shr 16) and $FF);
  G := AdjustChannel((AColor shr 8) and $FF);
  B := AdjustChannel(AColor and $FF);
  Result := (AColor and $FF000000) or (Cardinal(R) shl 16) or
    (Cardinal(G) shl 8) or Cardinal(B);
end;

{ TSerifDrawSettings }

class function TSerifDrawSettings.Default: TSerifDrawSettings;
begin
  Result := System.Default(TSerifDrawSettings);
  Result.Alignment := SERIF_ALIGN_CENTER;
  Result.FontSize := 54.0;
  Result.FontName := 'Yu Gothic UI';
  Result.FontStyles := SERIF_FONT_BOLD;
  Result.FrameKind := 0;
  Result.FrameAccentSource := 0;
  Result.FrameShape := 0;
  Result.FrameCornerRadius := 32;
  Result.FrameDottedDashLength := 24;
  Result.FrameDottedGapLength := 24;
  Result.FrameTabWidth := 250;
  Result.FrameTabHeight := 64;
  Result.FrameTabOffset := 24;
  Result.FrameBalloonTailPosition := 0;
  Result.FrameBalloonTailWidth := 100;
  Result.FrameBalloonTailLength := 60;
  Result.FrameBalloonTailDirection := 0;
  Result.FrameWidth := 1280;
  Result.FrameHeight := 180;
  Result.FramePositionX := 0;
  Result.FramePositionY := 0;
  Result.FrameFillVisible := True;
  Result.FrameOutlineVisible := True;
  Result.FrameOutlineWidth := 2;
  Result.FrameOutlineStyle := 0;
  Result.FrameShadowVisible := False;
  Result.FrameShadowBlur := 0;
  Result.FrameShadowOffsetX := 8;
  Result.FrameShadowOffsetY := 8;
  Result.FrameShadowSpread := 0;
  Result.FrameFillColor := $70303030;
  Result.FrameFillMode := SERIF_FRAME_FILL_SOLID;
  Result.FrameGradientStrength := 30;
  Result.FrameOutlineColor := $FFE6E6E6;
  Result.FrameInnerOutlineColor := $FFE6E6E6;
  Result.FrameLayering := 0;
  Result.FrameInnerPanelColor := $FFFFFFFF;
  Result.FrameInnerPanelInsetX := 28;
  Result.FrameInnerPanelInsetY := 20;
  Result.FrameInnerPanelRadius := 16;
  Result.FrameShadowColor := $6E000000;
  Result.LetterSpacing := 0;
  Result.LineSpacing := 0;
  Result.OutlineBlur := 0;
  Result.OutlineEnabled := True;
  Result.OutlineWidth := 30.0;
  Result.FillColor := $FFFFFFFF;
  Result.OutlineColor := $FF000000;
  Result.BlurColor := $FF000000;
  Result.Placement := SERIF_PLACEMENT_CENTER;
  Result.PositionX := 0.0;
  Result.PositionY := 0.0;
  Result.RoleNamePlacement := SERIF_PLACEMENT_CENTER;
  Result.RoleNamePositionX := 0.0;
  Result.RoleNamePositionY := 0.0;
  Result.RoleNameFontSize := Result.FontSize;
  Result.RoleNameFontName := Result.FontName;
  Result.RoleNameFontStyles := Result.FontStyles;
  Result.RoleNameLetterSpacing := Result.LetterSpacing;
  Result.RoleNameLineSpacing := Result.LineSpacing;
  Result.RoleNameVisible := False;
  Result.RoleNameOutlineBlur := 0;
  Result.RoleNameOutlineEnabled := True;
  Result.RoleNameOutlineWidth := Result.OutlineWidth;
  Result.RoleNameFillColor := $FFFFFFFF;
  Result.RoleNameOutlineColor := $FF000000;
  Result.RoleNameBlurColor := $FF000000;
  Result.ShadowEnabled := False;
  Result.ShadowOffsetX := 20;
  Result.ShadowOffsetY := 20;
  Result.ShadowBlur := 8;
  Result.ShadowSpread := 0;
  Result.ShadowColor := $A0000000;
  Result.RoleNameShadowEnabled := False;
  Result.RoleNameShadowOffsetX := 0;
  Result.RoleNameShadowOffsetY := 0;
  Result.RoleNameShadowBlur := 0;
  Result.RoleNameShadowSpread := 0;
  Result.RoleNameShadowColor := $FF000000;
end;

function TSerifDrawSettings.CommonFrameStyle: TSerifDrawFrameStyle;
begin
  Result.Layer := -1;
  Result.AccentSource := FrameAccentSource;
  Result.CornerRadius := FrameCornerRadius;
  Result.DottedDashLength := FrameDottedDashLength;
  Result.DottedGapLength := FrameDottedGapLength;
  Result.Shape := FrameShape;
  Result.TabWidth := FrameTabWidth;
  Result.TabHeight := FrameTabHeight;
  Result.TabOffset := FrameTabOffset;
  Result.BalloonTailPosition := FrameBalloonTailPosition;
  Result.BalloonTailWidth := FrameBalloonTailWidth;
  Result.BalloonTailLength := FrameBalloonTailLength;
  Result.BalloonTailDirection := FrameBalloonTailDirection;
  Result.PositionX := FramePositionX;
  Result.PositionY := FramePositionY;
  Result.Width := FrameWidth;
  Result.Height := FrameHeight;
  Result.FillVisible := FrameFillVisible;
  Result.OutlineVisible := FrameOutlineVisible;
  Result.OutlineWidth := FrameOutlineWidth;
  Result.OutlineStyle := FrameOutlineStyle;
  Result.ShadowVisible := FrameShadowVisible;
  Result.ShadowBlur := FrameShadowBlur;
  Result.ShadowOffsetX := FrameShadowOffsetX;
  Result.ShadowOffsetY := FrameShadowOffsetY;
  Result.ShadowSpread := FrameShadowSpread;
  Result.FillColor := FrameFillColor;
  Result.FillMode := FrameFillMode;
  Result.GradientStrength := FrameGradientStrength;
  Result.OutlineColor := FrameOutlineColor;
  Result.InnerOutlineColor := FrameInnerOutlineColor;
  Result.Layering := FrameLayering;
  Result.InnerPanelColor := FrameInnerPanelColor;
  Result.InnerPanelInsetX := FrameInnerPanelInsetX;
  Result.InnerPanelInsetY := FrameInnerPanelInsetY;
  Result.InnerPanelRadius := FrameInnerPanelRadius;
  Result.ShadowColor := FrameShadowColor;
end;

function TSerifDrawSettings.Encode: string;
var
  FS: TFormatSettings;
  I: Integer;
begin
  FS := InvariantFormatSettings;
  Result := 'SD7;fs=' + FormatFloat('0.###', FontSize, FS) +
    ';ow=' + FormatFloat('0.###', OutlineWidth, FS) +
    ';ob=' + FormatFloat('0.###', OutlineBlur, FS) +
    ';oe=' + IntToStr(Ord(OutlineEnabled)) +
    ';fc=' + IntToHex(FillColor, 8) +
    ';oc=' + IntToHex(OutlineColor, 8) +
    ';bc=' + IntToHex(BlurColor, 8) +
    ';fn=' + EncodeTextHex(FontName) +
    ';st=' + IntToStr(FontStyles) +
    ';se=' + IntToStr(Ord(ShadowEnabled)) +
    ';sx=' + FormatFloat('0.###', ShadowOffsetX, FS) +
    ';sy=' + FormatFloat('0.###', ShadowOffsetY, FS) +
    ';sb=' + FormatFloat('0.###', ShadowBlur, FS) +
    ';ss=' + FormatFloat('0.###', ShadowSpread, FS) +
    ';sc=' + IntToHex(ShadowColor, 8) +
    ';ls=' + FormatFloat('0.###', LineSpacing, FS) +
    ';cs=' + FormatFloat('0.###', LetterSpacing, FS) +
    ';al=' + IntToStr(Alignment) +
    ';pl=' + IntToStr(Placement) +
    ';x=' + FormatFloat('0.###', PositionX, FS) +
    ';y=' + FormatFloat('0.###', PositionY, FS) +
    ';rp=' + IntToStr(RoleNamePlacement) +
    ';rx=' + FormatFloat('0.###', RoleNamePositionX, FS) +
    ';ry=' + FormatFloat('0.###', RoleNamePositionY, FS) +
    ';rfs=' + FormatFloat('0.###', RoleNameFontSize, FS) +
    ';row=' + FormatFloat('0.###', RoleNameOutlineWidth, FS) +
    ';rob=' + FormatFloat('0.###', RoleNameOutlineBlur, FS) +
    ';roe=' + IntToStr(Ord(RoleNameOutlineEnabled)) +
    ';rfc=' + IntToHex(RoleNameFillColor, 8) +
    ';roc=' + IntToHex(RoleNameOutlineColor, 8) +
    ';rbc=' + IntToHex(RoleNameBlurColor, 8) +
    ';rfn=' + EncodeTextHex(RoleNameFontName) +
    ';rst=' + IntToStr(RoleNameFontStyles) +
    ';rse=' + IntToStr(Ord(RoleNameShadowEnabled)) +
    ';rsx=' + FormatFloat('0.###', RoleNameShadowOffsetX, FS) +
    ';rsy=' + FormatFloat('0.###', RoleNameShadowOffsetY, FS) +
    ';rsb=' + FormatFloat('0.###', RoleNameShadowBlur, FS) +
    ';rss=' + FormatFloat('0.###', RoleNameShadowSpread, FS) +
    ';rsc=' + IntToHex(RoleNameShadowColor, 8) +
    ';rls=' + FormatFloat('0.###', RoleNameLineSpacing, FS) +
    ';rcs=' + FormatFloat('0.###', RoleNameLetterSpacing, FS) +
    ';rv=' + IntToStr(Ord(RoleNameVisible)) +
    ';fk=' + IntToStr(FrameKind) +
    ';fas=' + IntToStr(FrameAccentSource) +
    ';fsh=' + IntToStr(FrameShape) +
    ';fcr=' + IntToStr(FrameCornerRadius) +
    ';fdl=' + IntToStr(FrameDottedDashLength) +
    ';fdg=' + IntToStr(FrameDottedGapLength) +
    ';ftw=' + IntToStr(FrameTabWidth) +
    ';fth=' + IntToStr(FrameTabHeight) +
    ';ftx=' + IntToStr(FrameTabOffset) +
    ';fbp=' + IntToStr(FrameBalloonTailPosition) +
    ';fbw=' + IntToStr(FrameBalloonTailWidth) +
    ';fbl=' + IntToStr(FrameBalloonTailLength) +
    ';fbd=' + IntToStr(FrameBalloonTailDirection) +
    ';fx=' + FormatFloat('0.###', FramePositionX, FS) +
    ';fy=' + FormatFloat('0.###', FramePositionY, FS) +
    ';fw=' + IntToStr(FrameWidth) +
    ';fh=' + IntToStr(FrameHeight) +
    ';ffv=' + IntToStr(Ord(FrameFillVisible)) +
    ';fov=' + IntToStr(Ord(FrameOutlineVisible)) +
    ';fow=' + IntToStr(FrameOutlineWidth) +
    ';fos=' + IntToStr(FrameOutlineStyle) +
    ';fsv=' + IntToStr(Ord(FrameShadowVisible)) +
    ';fsb=' + FormatFloat('0.###', FrameShadowBlur, FS) +
    ';fsx=' + FormatFloat('0.###', FrameShadowOffsetX, FS) +
    ';fsy=' + FormatFloat('0.###', FrameShadowOffsetY, FS) +
    ';fss=' + FormatFloat('0.###', FrameShadowSpread, FS) +
    ';ffc=' + IntToHex(FrameFillColor, 8) +
    ';ffm=' + IntToStr(FrameFillMode) +
    ';fgs=' + IntToStr(FrameGradientStrength) +
    ';foc=' + IntToHex(FrameOutlineColor, 8) +
    ';fic=' + IntToHex(FrameInnerOutlineColor, 8) +
    ';flg=' + IntToStr(FrameLayering) +
    ';fpc=' + IntToHex(FrameInnerPanelColor, 8) +
    ';fpx=' + IntToStr(FrameInnerPanelInsetX) +
    ';fpy=' + IntToStr(FrameInnerPanelInsetY) +
    ';fpr=' + IntToStr(FrameInnerPanelRadius) +
    ';fsc=' + IntToHex(FrameShadowColor, 8) + ';colors=';
  for I := 0 to High(LayerColors) do
  begin
    if I > 0 then
      Result := Result + '/';
    Result := Result + EncodeTextHex(LayerColors[I].RoleName) + ',' +
      IntToHex(LayerColors[I].FillColor, 8) + ',' +
      IntToHex(LayerColors[I].OutlineColor, 8) + ',' +
      IntToHex(LayerColors[I].ShadowColor, 8) + ',' +
      IntToHex(LayerColors[I].BlurColor, 8);
  end;
  Result := Result + ';frames=';
  for I := 0 to High(LayerFrames) do
  begin
    if I > 0 then
      Result := Result + '/';
    Result := Result + EncodeTextHex(LayerFrames[I].RoleName) + ',' +
      IntToStr(LayerFrames[I].Shape) + ',' +
      FormatFloat('0.###', LayerFrames[I].PositionX, FS) + ',' +
      FormatFloat('0.###', LayerFrames[I].PositionY, FS) + ',' +
      IntToStr(LayerFrames[I].Width) + ',' +
      IntToStr(LayerFrames[I].Height) + ',' +
      IntToStr(Ord(LayerFrames[I].FillVisible)) + ',' +
      IntToStr(Ord(LayerFrames[I].OutlineVisible)) + ',' +
      IntToStr(LayerFrames[I].OutlineWidth) + ',' +
      IntToStr(Ord(LayerFrames[I].ShadowVisible)) + ',' +
      FormatFloat('0.###', LayerFrames[I].ShadowBlur, FS) + ',' +
      FormatFloat('0.###', LayerFrames[I].ShadowOffsetX, FS) + ',' +
      FormatFloat('0.###', LayerFrames[I].ShadowOffsetY, FS) + ',' +
      FormatFloat('0.###', LayerFrames[I].ShadowSpread, FS) + ',' +
      IntToHex(LayerFrames[I].FillColor, 8) + ',' +
      IntToHex(LayerFrames[I].OutlineColor, 8) + ',' +
      IntToHex(LayerFrames[I].ShadowColor, 8) + ',' +
      IntToStr(LayerFrames[I].CornerRadius) + ',' +
      IntToStr(LayerFrames[I].TabWidth) + ',' +
      IntToStr(LayerFrames[I].TabHeight) + ',' +
      IntToStr(LayerFrames[I].TabOffset) + ',' +
      IntToStr(LayerFrames[I].BalloonTailPosition) + ',' +
      IntToStr(LayerFrames[I].BalloonTailWidth) + ',' +
      IntToStr(LayerFrames[I].BalloonTailLength) + ',' +
      IntToStr(LayerFrames[I].BalloonTailDirection) + ',' +
      IntToStr(LayerFrames[I].OutlineStyle) + ',' +
      IntToHex(LayerFrames[I].InnerOutlineColor, 8) + ',' +
      IntToStr(LayerFrames[I].DottedDashLength) + ',' +
      IntToStr(LayerFrames[I].DottedGapLength) + ',' +
      IntToStr(LayerFrames[I].Layering) + ',' +
      IntToHex(LayerFrames[I].InnerPanelColor, 8) + ',' +
      IntToStr(LayerFrames[I].InnerPanelInsetX) + ',' +
      IntToStr(LayerFrames[I].InnerPanelInsetY) + ',' +
      IntToStr(LayerFrames[I].InnerPanelRadius) + ',' +
      IntToStr(LayerFrames[I].AccentSource) + ',' +
      IntToStr(LayerFrames[I].FillMode) + ',' +
      IntToStr(LayerFrames[I].GradientStrength);
  end;
  Result := Result + ';rolecolors=';
  for I := 0 to High(RoleNameLayerColors) do
  begin
    if I > 0 then
      Result := Result + '/';
    Result := Result + EncodeTextHex(RoleNameLayerColors[I].RoleName) + ',' +
      IntToHex(RoleNameLayerColors[I].FillColor, 8) + ',' +
      IntToHex(RoleNameLayerColors[I].OutlineColor, 8) + ',' +
      IntToHex(RoleNameLayerColors[I].ShadowColor, 8) + ',' +
      IntToHex(RoleNameLayerColors[I].BlurColor, 8);
  end;
end;

function TSerifDrawSettings.ResolveStyle(
  const ALayer: Integer; const ARoleName: string): TSerifDrawLayerStyle;
var
  Colors: TSerifDrawLayerColors;
  Key: string;
begin
  Result.Alignment := Alignment;
  Result.Layer := ALayer;
  Result.FontSize := FontSize;
  Result.FontName := FontName;
  Result.FontStyles := FontStyles;
  Result.LetterSpacing := LetterSpacing;
  Result.LineSpacing := LineSpacing;
  Result.OutlineBlur := OutlineBlur;
  Result.OutlineEnabled := OutlineEnabled;
  Result.OutlineWidth := OutlineWidth;
  Result.FillColor := FillColor;
  Result.OutlineColor := OutlineColor;
  Result.BlurColor := BlurColor;
  Result.ShadowEnabled := ShadowEnabled;
  Result.ShadowOffsetX := ShadowOffsetX;
  Result.ShadowOffsetY := ShadowOffsetY;
  Result.ShadowBlur := ShadowBlur;
  Result.ShadowSpread := ShadowSpread;
  Result.ShadowColor := ShadowColor;
  Key := SerifDrawRoleNameKey(ARoleName);
  for Colors in LayerColors do
    if Colors.RoleName = Key then
    begin
      Result.FillColor := Colors.FillColor;
      Result.OutlineColor := Colors.OutlineColor;
      Result.ShadowColor := Colors.ShadowColor;
      Result.BlurColor := Colors.BlurColor;
      Exit;
    end;
end;

function TSerifDrawSettings.ResolveRoleNameStyle(
  const ALayer: Integer; const ARoleName: string): TSerifDrawLayerStyle;
var
  Colors: TSerifDrawLayerColors;
  Key: string;
begin
  Result.Alignment := RoleNamePlacement mod 3;
  Result.Layer := ALayer;
  Result.FontSize := RoleNameFontSize;
  Result.FontName := RoleNameFontName;
  Result.FontStyles := RoleNameFontStyles;
  Result.LetterSpacing := RoleNameLetterSpacing;
  Result.LineSpacing := RoleNameLineSpacing;
  Result.OutlineBlur := RoleNameOutlineBlur;
  Result.OutlineEnabled := RoleNameOutlineEnabled;
  Result.OutlineWidth := RoleNameOutlineWidth;
  Result.FillColor := RoleNameFillColor;
  Result.OutlineColor := RoleNameOutlineColor;
  Result.BlurColor := RoleNameBlurColor;
  Result.ShadowEnabled := RoleNameShadowEnabled;
  Result.ShadowOffsetX := RoleNameShadowOffsetX;
  Result.ShadowOffsetY := RoleNameShadowOffsetY;
  Result.ShadowBlur := RoleNameShadowBlur;
  Result.ShadowSpread := RoleNameShadowSpread;
  Result.ShadowColor := RoleNameShadowColor;
  Key := SerifDrawRoleNameKey(ARoleName);
  for Colors in RoleNameLayerColors do
    if Colors.RoleName = Key then
    begin
      Result.FillColor := Colors.FillColor;
      Result.OutlineColor := Colors.OutlineColor;
      Result.ShadowColor := Colors.ShadowColor;
      Result.BlurColor := Colors.BlurColor;
      Exit;
    end;
end;

function TSerifDrawSettings.ResolveFrameStyle(
  const ALayer: Integer; const ARoleName: string): TSerifDrawFrameStyle;
var
  Key: string;
  Style: TSerifDrawFrameStyle;
begin
  Result := CommonFrameStyle;
  Result.Layer := ALayer;
  Key := SerifDrawRoleNameKey(ARoleName);
  Result.RoleName := Key;
  for Style in LayerFrames do
    if Style.RoleName = Key then
    begin
      Result := Style;
      Result.Layer := ALayer;
      Break;
    end;
end;

function TSerifDrawSettings.ResolveFrameAppearance(
  const ALayer: Integer; const ARoleName: string): TSerifDrawFrameStyle;
var
  Accent: Cardinal;
  TextStyle: TSerifDrawLayerStyle;

  function WithAccentRgb(const Color: Cardinal): Cardinal;
  begin
    Result := (Color and $FF000000) or (Accent and $00FFFFFF);
  end;
begin
  Result := ResolveFrameStyle(ALayer, ARoleName);
  if Result.AccentSource = 1 then
  begin
    TextStyle := ResolveStyle(ALayer, ARoleName);
    Accent := TextStyle.OutlineColor;
    if Result.Layering = 1 then
      Result.FillColor := WithAccentRgb(Result.FillColor);
    Result.OutlineColor := WithAccentRgb(Result.OutlineColor);
    Result.InnerOutlineColor := WithAccentRgb(Result.InnerOutlineColor);
    Result.ShadowColor := WithAccentRgb(Result.ShadowColor);
  end;
end;

function TSerifDrawSettings.ResolveCommonFrameAppearance(
  const AAccentRoleName: string): TSerifDrawFrameStyle;
var
  Accent: Cardinal;
  TextStyle: TSerifDrawLayerStyle;

  function WithAccentRgb(const Color: Cardinal): Cardinal;
  begin
    Result := (Color and $FF000000) or (Accent and $00FFFFFF);
  end;
begin
  Result := CommonFrameStyle;
  if Result.AccentSource = 1 then
  begin
    TextStyle := ResolveStyle(-1, AAccentRoleName);
    Accent := TextStyle.OutlineColor;
    if Result.Layering = 1 then
      Result.FillColor := WithAccentRgb(Result.FillColor);
    Result.OutlineColor := WithAccentRgb(Result.OutlineColor);
    Result.InnerOutlineColor := WithAccentRgb(Result.InnerOutlineColor);
    Result.ShadowColor := WithAccentRgb(Result.ShadowColor);
  end;
end;

procedure TSerifDrawSettings.SetCommonFrameStyle(
  const AStyle: TSerifDrawFrameStyle);
begin
  FrameShape := AStyle.Shape;
  FrameAccentSource := AStyle.AccentSource;
  FrameCornerRadius := AStyle.CornerRadius;
  FrameDottedDashLength := AStyle.DottedDashLength;
  FrameDottedGapLength := AStyle.DottedGapLength;
  FrameTabWidth := AStyle.TabWidth;
  FrameTabHeight := AStyle.TabHeight;
  FrameTabOffset := AStyle.TabOffset;
  FrameBalloonTailPosition := AStyle.BalloonTailPosition;
  FrameBalloonTailWidth := AStyle.BalloonTailWidth;
  FrameBalloonTailLength := AStyle.BalloonTailLength;
  FrameBalloonTailDirection := AStyle.BalloonTailDirection;
  FramePositionX := AStyle.PositionX;
  FramePositionY := AStyle.PositionY;
  FrameWidth := AStyle.Width;
  FrameHeight := AStyle.Height;
  FrameFillVisible := AStyle.FillVisible;
  FrameOutlineVisible := AStyle.OutlineVisible;
  FrameOutlineWidth := AStyle.OutlineWidth;
  FrameOutlineStyle := AStyle.OutlineStyle;
  FrameShadowVisible := AStyle.ShadowVisible;
  FrameShadowBlur := AStyle.ShadowBlur;
  FrameShadowOffsetX := AStyle.ShadowOffsetX;
  FrameShadowOffsetY := AStyle.ShadowOffsetY;
  FrameShadowSpread := AStyle.ShadowSpread;
  FrameFillColor := AStyle.FillColor;
  FrameFillMode := AStyle.FillMode;
  FrameGradientStrength := AStyle.GradientStrength;
  FrameOutlineColor := AStyle.OutlineColor;
  FrameInnerOutlineColor := AStyle.InnerOutlineColor;
  FrameLayering := AStyle.Layering;
  FrameInnerPanelColor := AStyle.InnerPanelColor;
  FrameInnerPanelInsetX := AStyle.InnerPanelInsetX;
  FrameInnerPanelInsetY := AStyle.InnerPanelInsetY;
  FrameInnerPanelRadius := AStyle.InnerPanelRadius;
  FrameShadowColor := AStyle.ShadowColor;
end;

procedure TSerifDrawSettings.SetLayerFrameStyle(
  const AStyle: TSerifDrawFrameStyle);
var
  I: Integer;
  Style: TSerifDrawFrameStyle;
begin
  Style := AStyle;
  Style.RoleName := SerifDrawRoleNameKey(Style.RoleName);
  if Style.RoleName = '' then
    Exit;
  for I := 0 to High(LayerFrames) do
    if LayerFrames[I].RoleName = Style.RoleName then
    begin
      LayerFrames[I] := Style;
      Exit;
    end;
  SetLength(LayerFrames, Length(LayerFrames) + 1);
  LayerFrames[High(LayerFrames)] := Style;
end;

function TSerifDrawSettings.HasLayerFrameStyle(
  const ARoleName: string): Boolean;
var
  Key: string;
  Style: TSerifDrawFrameStyle;
begin
  Result := False;
  Key := SerifDrawRoleNameKey(ARoleName);
  if Key = '' then
    Exit;
  for Style in LayerFrames do
    if Style.RoleName = Key then
      Exit(True);
end;

procedure TSerifDrawSettings.RemoveLayerFrameStyle(const ARoleName: string);
var
  I: Integer;
  J: Integer;
  Key: string;
begin
  Key := SerifDrawRoleNameKey(ARoleName);
  for I := 0 to High(LayerFrames) do
    if LayerFrames[I].RoleName = Key then
    begin
      for J := I to High(LayerFrames) - 1 do
        LayerFrames[J] := LayerFrames[J + 1];
      SetLength(LayerFrames, Length(LayerFrames) - 1);
      Exit;
    end;
end;

procedure TSerifDrawSettings.RemoveLayerColors(const ARoleName: string);
var
  I: Integer;
  J: Integer;
  Key: string;
begin
  Key := SerifDrawRoleNameKey(ARoleName);
  for I := 0 to High(LayerColors) do
    if LayerColors[I].RoleName = Key then
    begin
      for J := I to High(LayerColors) - 1 do
        LayerColors[J] := LayerColors[J + 1];
      SetLength(LayerColors, Length(LayerColors) - 1);
      Exit;
    end;
end;

procedure TSerifDrawSettings.SetLayerColors(
  const AColors: TSerifDrawLayerColors);
var
  Colors: TSerifDrawLayerColors;
  I: Integer;
begin
  Colors := AColors;
  Colors.RoleName := SerifDrawRoleNameKey(Colors.RoleName);
  if Colors.RoleName = '' then
    Exit;
  for I := 0 to High(LayerColors) do
    if LayerColors[I].RoleName = Colors.RoleName then
    begin
      LayerColors[I] := Colors;
      Exit;
    end;
  SetLength(LayerColors, Length(LayerColors) + 1);
  LayerColors[High(LayerColors)] := Colors;
end;

procedure TSerifDrawSettings.RemoveRoleNameLayerColors(
  const ARoleName: string);
var
  I: Integer;
  J: Integer;
  Key: string;
begin
  Key := SerifDrawRoleNameKey(ARoleName);
  for I := 0 to High(RoleNameLayerColors) do
    if RoleNameLayerColors[I].RoleName = Key then
    begin
      for J := I to High(RoleNameLayerColors) - 1 do
        RoleNameLayerColors[J] := RoleNameLayerColors[J + 1];
      SetLength(RoleNameLayerColors, Length(RoleNameLayerColors) - 1);
      Exit;
    end;
end;

procedure TSerifDrawSettings.SetRoleNameLayerColors(
  const AColors: TSerifDrawLayerColors);
var
  Colors: TSerifDrawLayerColors;
  I: Integer;
begin
  Colors := AColors;
  Colors.RoleName := SerifDrawRoleNameKey(Colors.RoleName);
  if Colors.RoleName = '' then
    Exit;
  for I := 0 to High(RoleNameLayerColors) do
    if RoleNameLayerColors[I].RoleName = Colors.RoleName then
    begin
      RoleNameLayerColors[I] := Colors;
      Exit;
    end;
  SetLength(RoleNameLayerColors, Length(RoleNameLayerColors) + 1);
  RoleNameLayerColors[High(RoleNameLayerColors)] := Colors;
end;

class function TSerifDrawSettings.TryDecode(const AText: string;
  out ASettings: TSerifDrawSettings; out AError: string): Boolean;
var
  FS: TFormatSettings;
  FrameStyle: TSerifDrawFrameStyle;
  FontStylesValue: Integer;
  HasBlurColor: Boolean;
  HasFrameInnerOutlineColor: Boolean;
  HasRoleNameStyle: Boolean;
  I: Integer;
  Key: string;
  LayerItems: TStringList;
  LayerColor: TSerifDrawLayerColors;
  OpacityValue: Integer;
  Parts: TStringList;
  PlacementValue: Integer;
  Separator: Integer;
  ShadowEnabledValue: Integer;
  Value: string;
begin
  ASettings := Default;
  HasBlurColor := False;
  HasFrameInnerOutlineColor := False;
  HasRoleNameStyle := False;
  AError := '';
  if AText = '' then
    Exit(True);
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ';';
    Parts.DelimitedText := AText;
    // SD2は本文・配置・配役別色の各キーがSD7と互換であり、
    // 未実装だった後発項目はDefault値で補える。既存プロジェクトを
    // 既定値へ落とさず読み込み、次回保存時にEncodeでSD7へ更新する。
    if (Parts.Count = 0) or
      ((Parts[0] <> 'SD2') and (Parts[0] <> 'SD7')) then
    begin
      AError := 'Unsupported settings data version.';
      Exit(False);
    end;
    FS := InvariantFormatSettings;
    for I := 1 to Parts.Count - 1 do
    begin
      Separator := Pos('=', Parts[I]);
      if Separator <= 1 then
        Continue;
      Key := Copy(Parts[I], 1, Separator - 1);
      Value := Copy(Parts[I], Separator + 1, MaxInt);
      if Key = 'fs' then
      begin
        if not TryStrToFloat(Value, ASettings.FontSize, FS) then
        begin
          AError := 'Invalid font size.';
          Exit(False);
        end;
      end
      else if Key = 'ow' then
      begin
        if not TryStrToFloat(Value, ASettings.OutlineWidth, FS) then
        begin
          AError := 'Invalid outline width.';
          Exit(False);
        end;
      end
      else if Key = 'ob' then
      begin
        if not TryStrToFloat(Value, ASettings.OutlineBlur, FS) then
        begin
          AError := 'Invalid outline blur.';
          Exit(False);
        end;
      end
      else if (Key = 'oe') and not TryParseBoolean(Value,
        ASettings.OutlineEnabled) then
      begin
        AError := 'Invalid outline enabled value.';
        Exit(False);
      end
      else if (Key = 'fc') and not TryParseColor(Value,
        ASettings.FillColor) then
      begin
        AError := 'Invalid fill color.';
        Exit(False);
      end
      else if (Key = 'oc') and not TryParseColor(Value,
        ASettings.OutlineColor) then
      begin
        AError := 'Invalid outline color.';
        Exit(False);
      end
      else if Key = 'bc' then
      begin
        if not TryParseColor(Value, ASettings.BlurColor) then
        begin
          AError := 'Invalid blur color.';
          Exit(False);
        end;
        HasBlurColor := True;
      end
      else if Key = 'fn' then
      begin
        if not TryDecodeTextHex(Value, ASettings.FontName) or
          (ASettings.FontName = '') then
        begin
          AError := 'Invalid font name.';
          Exit(False);
        end;
      end
      else if Key = 'st' then
      begin
        if not TryStrToInt(Value, FontStylesValue) or
          (FontStylesValue < 0) or (FontStylesValue > High(Byte)) then
        begin
          AError := 'Invalid font style.';
          Exit(False);
        end;
        ASettings.FontStyles := FontStylesValue;
        if (ASettings.FontStyles and not (SERIF_FONT_BOLD or
          SERIF_FONT_ITALIC)) <> 0 then
        begin
          AError := 'Invalid font style.';
          Exit(False);
        end;
      end
      else if Key = 'se' then
      begin
        if not TryStrToInt(Value, ShadowEnabledValue) or
          not (ShadowEnabledValue in [0, 1]) then
        begin
          AError := 'Invalid shadow enabled value.';
          Exit(False);
        end;
        ASettings.ShadowEnabled := ShadowEnabledValue <> 0;
      end
      else if Key = 'sx' then
      begin
        if not TryStrToFloat(Value, ASettings.ShadowOffsetX, FS) then
        begin
          AError := 'Invalid shadow X offset.';
          Exit(False);
        end;
      end
      else if Key = 'sy' then
      begin
        if not TryStrToFloat(Value, ASettings.ShadowOffsetY, FS) then
        begin
          AError := 'Invalid shadow Y offset.';
          Exit(False);
        end;
      end
      else if Key = 'sb' then
      begin
        if not TryStrToFloat(Value, ASettings.ShadowBlur, FS) then
        begin
          AError := 'Invalid shadow blur.';
          Exit(False);
        end;
      end
      else if Key = 'ss' then
      begin
        if not TryStrToFloat(Value, ASettings.ShadowSpread, FS) then
        begin
          AError := 'Invalid shadow spread.';
          Exit(False);
        end;
      end
      else if (Key = 'sc') and not TryParseColor(Value,
        ASettings.ShadowColor) then
      begin
        AError := 'Invalid shadow color.';
        Exit(False);
      end
      else if Key = 'ls' then
      begin
        if not TryStrToFloat(Value, ASettings.LineSpacing, FS) then
        begin
          AError := 'Invalid line spacing.';
          Exit(False);
        end;
      end
      else if Key = 'cs' then
      begin
        if not TryStrToFloat(Value, ASettings.LetterSpacing, FS) then
        begin
          AError := 'Invalid letter spacing.';
          Exit(False);
        end;
      end
      else if Key = 'al' then
      begin
        if not TryStrToInt(Value, FontStylesValue) or
          (FontStylesValue < SERIF_ALIGN_LEADING) or
          (FontStylesValue > SERIF_ALIGN_TRAILING) then
        begin
          AError := 'Invalid text alignment.';
          Exit(False);
        end;
        ASettings.Alignment := FontStylesValue;
      end
      else if Key = 'op' then
      begin
        if not TryStrToInt(Value, OpacityValue) or
          (OpacityValue < 0) or (OpacityValue > 255) then
        begin
          AError := 'Invalid opacity.';
          Exit(False);
        end;
        // 旧版の全体透明度は互換読み込みのみ行い、現在は使用しない。
      end
      else if Key = 'pl' then
      begin
        if not TryStrToInt(Value, PlacementValue) or
          (PlacementValue < SERIF_PLACEMENT_TOP_LEFT) or
          (PlacementValue > SERIF_PLACEMENT_BOTTOM_RIGHT) then
        begin
          AError := 'Invalid text placement.';
          Exit(False);
        end;
        ASettings.Placement := PlacementValue;
      end
      else if Key = 'x' then
      begin
        if not TryStrToFloat(Value, ASettings.PositionX, FS) then
        begin
          AError := 'Invalid X position.';
          Exit(False);
        end;
      end
      else if Key = 'y' then
      begin
        if not TryStrToFloat(Value, ASettings.PositionY, FS) then
        begin
          AError := 'Invalid Y position.';
          Exit(False);
        end;
      end
      else if Key = 'rp' then
      begin
        if not TryStrToInt(Value, PlacementValue) or
          (PlacementValue < SERIF_PLACEMENT_TOP_LEFT) or
          (PlacementValue > SERIF_PLACEMENT_BOTTOM_RIGHT) then
        begin
          AError := 'Invalid role name placement.';
          Exit(False);
        end;
        ASettings.RoleNamePlacement := PlacementValue;
      end
      else if Key = 'rx' then
      begin
        if not TryStrToFloat(Value, ASettings.RoleNamePositionX, FS) then
        begin
          AError := 'Invalid role name X position.';
          Exit(False);
        end;
      end
      else if Key = 'ry' then
      begin
        if not TryStrToFloat(Value, ASettings.RoleNamePositionY, FS) then
        begin
          AError := 'Invalid role name Y position.';
          Exit(False);
        end;
      end
      else if Key = 'rfs' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToFloat(Value, ASettings.RoleNameFontSize, FS) then
          Exit(False);
      end
      else if Key = 'row' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToFloat(Value, ASettings.RoleNameOutlineWidth, FS) then
          Exit(False);
      end
      else if Key = 'rob' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToFloat(Value, ASettings.RoleNameOutlineBlur, FS) then
          Exit(False);
      end
      else if Key = 'roe' then
      begin
        HasRoleNameStyle := True;
        if not TryParseBoolean(Value,
          ASettings.RoleNameOutlineEnabled) then
          Exit(False);
      end
      else if Key = 'rfc' then
      begin
        HasRoleNameStyle := True;
        if not TryParseColor(Value, ASettings.RoleNameFillColor) then
          Exit(False);
      end
      else if Key = 'roc' then
      begin
        HasRoleNameStyle := True;
        if not TryParseColor(Value, ASettings.RoleNameOutlineColor) then
          Exit(False);
      end
      else if Key = 'rbc' then
      begin
        HasRoleNameStyle := True;
        if not TryParseColor(Value, ASettings.RoleNameBlurColor) then
          Exit(False);
      end
      else if Key = 'rfn' then
      begin
        HasRoleNameStyle := True;
        if not TryDecodeTextHex(Value, ASettings.RoleNameFontName) or
          (ASettings.RoleNameFontName = '') then
          Exit(False);
      end
      else if Key = 'rst' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToInt(Value, FontStylesValue) or
          ((FontStylesValue and not (SERIF_FONT_BOLD or SERIF_FONT_ITALIC)) <> 0)
          then Exit(False);
        ASettings.RoleNameFontStyles := FontStylesValue;
      end
      else if Key = 'rse' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToInt(Value, ShadowEnabledValue) or
          not (ShadowEnabledValue in [0, 1]) then Exit(False);
        ASettings.RoleNameShadowEnabled := ShadowEnabledValue <> 0;
      end
      else if Key = 'rsx' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToFloat(Value, ASettings.RoleNameShadowOffsetX, FS) then
          Exit(False);
      end
      else if Key = 'rsy' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToFloat(Value, ASettings.RoleNameShadowOffsetY, FS) then
          Exit(False);
      end
      else if Key = 'rsb' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToFloat(Value, ASettings.RoleNameShadowBlur, FS) then
          Exit(False);
      end
      else if Key = 'rss' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToFloat(Value, ASettings.RoleNameShadowSpread, FS) then
          Exit(False);
      end
      else if Key = 'rsc' then
      begin
        HasRoleNameStyle := True;
        if not TryParseColor(Value, ASettings.RoleNameShadowColor) then
          Exit(False);
      end
      else if Key = 'rls' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToFloat(Value, ASettings.RoleNameLineSpacing, FS) then
          Exit(False);
      end
      else if Key = 'rcs' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToFloat(Value, ASettings.RoleNameLetterSpacing, FS) then
          Exit(False);
      end
      else if Key = 'rop' then
      begin
        HasRoleNameStyle := True;
        if not TryStrToInt(Value, OpacityValue) or
          (OpacityValue < 0) or (OpacityValue > 255) then Exit(False);
        // 旧版の配役名全体透明度も現在は使用しない。
      end
      else if Key = 'rv' then
      begin
        if not TryStrToInt(Value, ShadowEnabledValue) or
          not (ShadowEnabledValue in [0, 1]) then
        begin
          AError := 'Invalid role name visibility.';
          Exit(False);
        end;
        ASettings.RoleNameVisible := ShadowEnabledValue <> 0;
      end
      else if Key = 'fk' then
      begin
        if not TryStrToInt(Value, FontStylesValue) or
          not (FontStylesValue in [0, 1, 2]) then
        begin
          AError := 'Invalid frame kind.';
          Exit(False);
        end;
        ASettings.FrameKind := FontStylesValue;
      end
      else if Key = 'fsh' then
      begin
        if not TryStrToInt(Value, FontStylesValue) or
          (FontStylesValue < 0) or (FontStylesValue > 3) then
        begin
          AError := 'Invalid frame shape.';
          Exit(False);
        end;
        ASettings.FrameShape := FontStylesValue;
      end
      else if Key = 'fas' then
      begin
        if not TryStrToInt(Value, FontStylesValue) or
          not (FontStylesValue in [0, 1]) then
        begin
          AError := 'Invalid frame accent source.';
          Exit(False);
        end;
        ASettings.FrameAccentSource := FontStylesValue;
      end
      else if Key = 'fcr' then
      begin
        if not TryStrToInt(Value, ASettings.FrameCornerRadius) then
        begin
          AError := 'Invalid frame corner radius.';
          Exit(False);
        end;
      end
      else if Key = 'fdl' then
      begin
        if not TryStrToInt(Value, ASettings.FrameDottedDashLength) then
        begin
          AError := 'Invalid frame dotted dash length.';
          Exit(False);
        end;
      end
      else if Key = 'fdg' then
      begin
        if not TryStrToInt(Value, ASettings.FrameDottedGapLength) then
        begin
          AError := 'Invalid frame dotted gap length.';
          Exit(False);
        end;
      end
      else if Key = 'ftw' then
      begin
        if not TryStrToInt(Value, ASettings.FrameTabWidth) then
        begin
          AError := 'Invalid frame tab width.';
          Exit(False);
        end;
      end
      else if Key = 'fth' then
      begin
        if not TryStrToInt(Value, ASettings.FrameTabHeight) then
        begin
          AError := 'Invalid frame tab height.';
          Exit(False);
        end;
      end
      else if Key = 'ftx' then
      begin
        if not TryStrToInt(Value, ASettings.FrameTabOffset) then
        begin
          AError := 'Invalid frame tab offset.';
          Exit(False);
        end;
      end
      else if Key = 'fbp' then
      begin
        if not TryStrToInt(Value, ASettings.FrameBalloonTailPosition) then
        begin
          AError := 'Invalid frame balloon tail position.';
          Exit(False);
        end;
      end
      else if Key = 'fbw' then
      begin
        if not TryStrToInt(Value, ASettings.FrameBalloonTailWidth) then
        begin
          AError := 'Invalid frame balloon tail width.';
          Exit(False);
        end;
      end
      else if Key = 'fbl' then
      begin
        if not TryStrToInt(Value, ASettings.FrameBalloonTailLength) then
        begin
          AError := 'Invalid frame balloon tail length.';
          Exit(False);
        end;
      end
      else if Key = 'fbd' then
      begin
        if not TryStrToInt(Value, ASettings.FrameBalloonTailDirection) then
        begin
          AError := 'Invalid frame balloon tail direction.';
          Exit(False);
        end;
      end
      else if Key = 'fx' then
      begin
        if not TryStrToFloat(Value, ASettings.FramePositionX, FS) then
        begin
          AError := 'Invalid frame X position.';
          Exit(False);
        end;
      end
      else if Key = 'fy' then
      begin
        if not TryStrToFloat(Value, ASettings.FramePositionY, FS) then
        begin
          AError := 'Invalid frame Y position.';
          Exit(False);
        end;
      end
      else if Key = 'fw' then
      begin
        if not TryStrToInt(Value, ASettings.FrameWidth) then
        begin
          AError := 'Invalid frame width.';
          Exit(False);
        end;
      end
      else if Key = 'fh' then
      begin
        if not TryStrToInt(Value, ASettings.FrameHeight) then
        begin
          AError := 'Invalid frame height.';
          Exit(False);
        end;
      end
      else if (Key = 'ffv') and not TryParseBoolean(Value,
        ASettings.FrameFillVisible) then
      begin
        AError := 'Invalid frame fill visibility.';
        Exit(False);
      end
      else if (Key = 'fov') and not TryParseBoolean(Value,
        ASettings.FrameOutlineVisible) then
      begin
        AError := 'Invalid frame outline visibility.';
        Exit(False);
      end
      else if Key = 'fow' then
      begin
        if not TryStrToInt(Value, ASettings.FrameOutlineWidth) then
        begin
          AError := 'Invalid frame outline width.';
          Exit(False);
        end;
      end
      else if Key = 'fos' then
      begin
        if not TryStrToInt(Value, FontStylesValue) or
          not (FontStylesValue in [0, 1, 2, 3]) then
        begin
          AError := 'Invalid frame outline style.';
          Exit(False);
        end;
        ASettings.FrameOutlineStyle := FontStylesValue;
      end
      else if (Key = 'fsv') and not TryParseBoolean(Value,
        ASettings.FrameShadowVisible) then
      begin
        AError := 'Invalid frame shadow visibility.';
        Exit(False);
      end
      else if Key = 'fsb' then
      begin
        if not TryStrToFloat(Value, ASettings.FrameShadowBlur, FS) then
        begin
          AError := 'Invalid frame shadow blur.';
          Exit(False);
        end;
      end
      else if Key = 'fsx' then
      begin
        if not TryStrToFloat(Value, ASettings.FrameShadowOffsetX, FS) then
        begin
          AError := 'Invalid frame shadow X offset.';
          Exit(False);
        end;
      end
      else if Key = 'fsy' then
      begin
        if not TryStrToFloat(Value, ASettings.FrameShadowOffsetY, FS) then
        begin
          AError := 'Invalid frame shadow Y offset.';
          Exit(False);
        end;
      end
      else if Key = 'fss' then
      begin
        if not TryStrToFloat(Value, ASettings.FrameShadowSpread, FS) then
        begin
          AError := 'Invalid frame shadow spread.';
          Exit(False);
        end;
      end
      else if (Key = 'ffc') and not TryParseColor(Value,
        ASettings.FrameFillColor) then
      begin
        AError := 'Invalid frame fill color.';
        Exit(False);
      end
      else if Key = 'ffm' then
      begin
        if not TryStrToInt(Value, FontStylesValue) or
          not (FontStylesValue in [SERIF_FRAME_FILL_SOLID,
            SERIF_FRAME_FILL_VERTICAL_GRADIENT]) then
        begin
          AError := 'Invalid frame fill mode.';
          Exit(False);
        end;
        ASettings.FrameFillMode := FontStylesValue;
      end
      else if Key = 'fgs' then
      begin
        if not TryStrToInt(Value, FontStylesValue) or
          (FontStylesValue < 0) or (FontStylesValue > 100) then
        begin
          AError := 'Invalid frame gradient strength.';
          Exit(False);
        end;
        ASettings.FrameGradientStrength := FontStylesValue;
      end
      else if (Key = 'foc') and not TryParseColor(Value,
        ASettings.FrameOutlineColor) then
      begin
        AError := 'Invalid frame outline color.';
        Exit(False);
      end
      else if Key = 'fic' then
      begin
        if not TryParseColor(Value, ASettings.FrameInnerOutlineColor) then
        begin
          AError := 'Invalid frame inner outline color.';
          Exit(False);
        end;
        HasFrameInnerOutlineColor := True;
      end
      else if Key = 'flg' then
      begin
        if not TryStrToInt(Value, FontStylesValue) or
          not (FontStylesValue in [0, 1]) then
        begin
          AError := 'Invalid frame layering.';
          Exit(False);
        end;
        ASettings.FrameLayering := FontStylesValue;
      end
      else if (Key = 'fpc') and not TryParseColor(Value,
        ASettings.FrameInnerPanelColor) then
      begin
        AError := 'Invalid frame inner panel color.';
        Exit(False);
      end
      else if Key = 'fpx' then
      begin
        if not TryStrToInt(Value, ASettings.FrameInnerPanelInsetX) then
        begin
          AError := 'Invalid frame inner panel horizontal inset.';
          Exit(False);
        end;
      end
      else if Key = 'fpy' then
      begin
        if not TryStrToInt(Value, ASettings.FrameInnerPanelInsetY) then
        begin
          AError := 'Invalid frame inner panel vertical inset.';
          Exit(False);
        end;
      end
      else if Key = 'fpr' then
      begin
        if not TryStrToInt(Value, ASettings.FrameInnerPanelRadius) then
        begin
          AError := 'Invalid frame inner panel radius.';
          Exit(False);
        end;
      end
      else if (Key = 'fsc') and not TryParseColor(Value,
        ASettings.FrameShadowColor) then
      begin
        AError := 'Invalid frame shadow color.';
        Exit(False);
      end
      else if (Key = 'colors') and (Value <> '') then
      begin
        LayerItems := TStringList.Create;
        try
          LayerItems.StrictDelimiter := True;
          LayerItems.Delimiter := '/';
          LayerItems.DelimitedText := Value;
          for Separator := 0 to LayerItems.Count - 1 do
          begin
            if not TryParseLayerColors(LayerItems[Separator], LayerColor) then
            begin
              AError := 'Invalid role colors.';
              Exit(False);
            end;
            ASettings.SetLayerColors(LayerColor);
          end;
        finally
          LayerItems.Free;
        end;
      end
      else if (Key = 'frames') and (Value <> '') then
      begin
        LayerItems := TStringList.Create;
        try
          LayerItems.StrictDelimiter := True;
          LayerItems.Delimiter := '/';
          LayerItems.DelimitedText := Value;
          for Separator := 0 to LayerItems.Count - 1 do
          begin
            if not TryParseFrameStyle(LayerItems[Separator], FrameStyle) then
            begin
              AError := 'Invalid role frame settings.';
              Exit(False);
            end;
            ASettings.SetLayerFrameStyle(FrameStyle);
          end;
        finally
          LayerItems.Free;
        end;
      end
      else if (Key = 'rolecolors') and (Value <> '') then
      begin
        LayerItems := TStringList.Create;
        try
          LayerItems.StrictDelimiter := True;
          LayerItems.Delimiter := '/';
          LayerItems.DelimitedText := Value;
          for Separator := 0 to LayerItems.Count - 1 do
          begin
            if not TryParseLayerColors(LayerItems[Separator], LayerColor) then
            begin
              AError := 'Invalid role name colors.';
              Exit(False);
            end;
            ASettings.SetRoleNameLayerColors(LayerColor);
          end;
        finally
          LayerItems.Free;
        end;
      end;
    end;
    if not HasBlurColor then
      ASettings.BlurColor := ASettings.OutlineColor;
    if not HasFrameInnerOutlineColor then
      ASettings.FrameInnerOutlineColor := ASettings.FrameOutlineColor;
    if not HasRoleNameStyle then
    begin
      ASettings.RoleNameFontSize := ASettings.FontSize;
      ASettings.RoleNameFontName := ASettings.FontName;
      ASettings.RoleNameFontStyles := ASettings.FontStyles;
      ASettings.RoleNameLetterSpacing := ASettings.LetterSpacing;
      ASettings.RoleNameLineSpacing := ASettings.LineSpacing;
      ASettings.RoleNameOutlineEnabled := ASettings.OutlineEnabled;
      ASettings.RoleNameOutlineWidth := ASettings.OutlineWidth;
    end;
    Result := (ASettings.FontSize >= 1) and (ASettings.FontSize <= 2000) and
      (ASettings.OutlineWidth >= 0) and
      (ASettings.OutlineWidth <= SERIF_TEXT_OUTLINE_WIDTH_MAX_PERCENT) and
      (ASettings.OutlineBlur >= 0) and
      (ASettings.OutlineBlur <= SERIF_TEXT_OUTLINE_BLUR_MAX_PERCENT) and
      (ASettings.FontName <> '') and (Length(ASettings.FontName) <= 128) and
      (ASettings.ShadowOffsetX >= -SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT) and
      (ASettings.ShadowOffsetX <= SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT) and
      (ASettings.ShadowOffsetY >= -SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT) and
      (ASettings.ShadowOffsetY <= SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT) and
      (ASettings.ShadowBlur >= 0) and
      (ASettings.ShadowBlur <= SERIF_TEXT_SHADOW_BLUR_MAX_PERCENT) and
      (ASettings.ShadowSpread >= 0) and
      (ASettings.ShadowSpread <= SERIF_TEXT_SHADOW_SPREAD_MAX_PERCENT) and
      (ASettings.LineSpacing >= -500) and
      (ASettings.LineSpacing <= 500) and
      (ASettings.LetterSpacing >= -500) and
      (ASettings.LetterSpacing <= 500) and
      (ASettings.Alignment <= SERIF_ALIGN_TRAILING) and
      (ASettings.Placement <= SERIF_PLACEMENT_BOTTOM_RIGHT) and
      (ASettings.PositionX >= -20000) and
      (ASettings.PositionX <= 20000) and
      (ASettings.PositionY >= -20000) and
      (ASettings.PositionY <= 20000) and
      (ASettings.RoleNamePlacement <= SERIF_PLACEMENT_BOTTOM_RIGHT) and
      (ASettings.RoleNamePositionX >= -20000) and
      (ASettings.RoleNamePositionX <= 20000) and
      (ASettings.RoleNamePositionY >= -20000) and
      (ASettings.RoleNamePositionY <= 20000) and
      (ASettings.RoleNameFontSize >= 1) and
      (ASettings.RoleNameFontSize <= 2000) and
      (ASettings.RoleNameFontName <> '') and
      (Length(ASettings.RoleNameFontName) <= 128) and
      (ASettings.RoleNameOutlineWidth >= 0) and
      (ASettings.RoleNameOutlineWidth <=
        SERIF_TEXT_OUTLINE_WIDTH_MAX_PERCENT) and
      (ASettings.RoleNameOutlineBlur >= 0) and
      (ASettings.RoleNameOutlineBlur <=
        SERIF_TEXT_OUTLINE_BLUR_MAX_PERCENT) and
      (ASettings.RoleNameLetterSpacing >= -500) and
      (ASettings.RoleNameLetterSpacing <= 500) and
      (ASettings.RoleNameLineSpacing >= -500) and
      (ASettings.RoleNameLineSpacing <= 500) and
      (ASettings.RoleNameShadowOffsetX >=
        -SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT) and
      (ASettings.RoleNameShadowOffsetX <=
        SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT) and
      (ASettings.RoleNameShadowOffsetY >=
        -SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT) and
      (ASettings.RoleNameShadowOffsetY <=
        SERIF_TEXT_SHADOW_OFFSET_MAX_PERCENT) and
      (ASettings.RoleNameShadowBlur >= 0) and
      (ASettings.RoleNameShadowBlur <=
        SERIF_TEXT_SHADOW_BLUR_MAX_PERCENT) and
      (ASettings.RoleNameShadowSpread >= 0) and
      (ASettings.RoleNameShadowSpread <=
        SERIF_TEXT_SHADOW_SPREAD_MAX_PERCENT) and
      (ASettings.FrameKind <= 2) and
      (ASettings.FrameAccentSource in [0, 1]) and
      (ASettings.FrameFillMode in [SERIF_FRAME_FILL_SOLID,
        SERIF_FRAME_FILL_VERTICAL_GRADIENT]) and
      (ASettings.FrameGradientStrength <= 100) and
      (ASettings.FrameShape <= 3) and
      (ASettings.FrameCornerRadius >= 0) and
      (ASettings.FrameCornerRadius <= 500) and
      (ASettings.FrameDottedDashLength >= 1) and
      (ASettings.FrameDottedDashLength <= 20000) and
      (ASettings.FrameDottedGapLength >= 1) and
      (ASettings.FrameDottedGapLength <= 20000) and
      (ASettings.FrameLayering in [0, 1]) and
      (ASettings.FrameInnerPanelInsetX >= 0) and
      (ASettings.FrameInnerPanelInsetX <= 10000) and
      (ASettings.FrameInnerPanelInsetY >= 0) and
      (ASettings.FrameInnerPanelInsetY <= 10000) and
      (ASettings.FrameInnerPanelRadius >= 0) and
      (ASettings.FrameInnerPanelRadius <= 500) and
      (ASettings.FrameTabWidth >= 1) and
      (ASettings.FrameTabWidth <= 20000) and
      (ASettings.FrameTabHeight >= 1) and
      (ASettings.FrameTabHeight <= 20000) and
      (ASettings.FrameTabOffset >= 0) and
      (ASettings.FrameTabOffset <= 20000) and
      (ASettings.FrameBalloonTailPosition >= -20000) and
      (ASettings.FrameBalloonTailPosition <= 20000) and
      (ASettings.FrameBalloonTailWidth >= 1) and
      (ASettings.FrameBalloonTailWidth <= 20000) and
      (ASettings.FrameBalloonTailLength >= 1) and
      (ASettings.FrameBalloonTailLength <= 20000) and
      (ASettings.FrameBalloonTailDirection >= 0) and
      (ASettings.FrameBalloonTailDirection <= 3) and
      (ASettings.FrameWidth >= 1) and (ASettings.FrameWidth <= 20000) and
      (ASettings.FrameHeight >= 1) and (ASettings.FrameHeight <= 20000) and
      (ASettings.FrameOutlineWidth >= 0) and
      (ASettings.FrameOutlineWidth <= 500) and
      (ASettings.FrameOutlineStyle <= 3) and
      (ASettings.FramePositionX >= -20000) and
      (ASettings.FramePositionX <= 20000) and
      (ASettings.FramePositionY >= -20000) and
      (ASettings.FramePositionY <= 20000) and
      (ASettings.FrameShadowOffsetX >= -2000) and
      (ASettings.FrameShadowOffsetX <= 2000) and
      (ASettings.FrameShadowOffsetY >= -2000) and
      (ASettings.FrameShadowOffsetY <= 2000) and
      (ASettings.FrameShadowBlur >= 0) and
      (ASettings.FrameShadowBlur <= 500) and
      (ASettings.FrameShadowSpread >= 0) and
      (ASettings.FrameShadowSpread <= 500);
    if not Result then
      AError := 'Settings are outside the supported range.';
  finally
    Parts.Free;
  end;
end;

end.
