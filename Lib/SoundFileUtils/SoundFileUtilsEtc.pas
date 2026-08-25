unit SoundFileUtilsEtc;

interface

uses
  Winapi.Windows,
  Winapi.ActiveX,
  Winapi.PropSys,        // ★ 新しい IPropertyStore, PROPERTYKEY, PropVariant
  Winapi.ShlObj,
  Winapi.ShLwApi,        // SHGetPropertyStoreFromParsingName 用
  System.SysUtils;
   {
uses
  Winapi.Windows,
  Winapi.ActiveX,
  Winapi.PropSys,
  Winapi.ShlObj,
  System.SysUtils;
  }

{--------------------------------------------------------------
  音声解析に失敗したときの保険処理（Fallback）
  ・Windows の IPropertyStore より再生時間を取得する
  ・取得できれば ms で返す
  ・取得不可の場合は 0
--------------------------------------------------------------}
function GetMediaDurationFallbackSec(const AbsoluteFileName: string): Integer;

implementation

const
  PKEY_Media_Duration: TPropertyKey = (
    fmtid: '{64440490-4C8B-11D1-8B70-080036B11A03}';
    pid: 3
  );

function GetMediaDurationFallbackSec(const AbsoluteFileName: string): Integer;
var
   PropStore : Winapi.PropSys.IPropertyStore;
  PropVar   : TPropVariant;
  Duration100ns : Int64;
  DurationSec  : Double;  // 秒単位に変換するための変数
begin
  Result := 0;

  if not FileExists(AbsoluteFileName) then
    Exit;

  // COM 初期化（多重初期化は OS が調整するので安全）
  CoInitialize(nil);
  try
    // IPropertyStore を取得
  if SHGetPropertyStoreFromParsingName(
       PWideChar(AbsoluteFileName),
       nil,
       Winapi.PropSys.GPS_DEFAULT,          // ★ 修正
       Winapi.PropSys.IPropertyStore,       // こちらも正しい
       PropStore
     ) = S_OK then
    begin
      // PKEY_Media_Duration を取得
      if PropStore.GetValue(PKEY_Media_Duration, PropVar) = S_OK then
      begin
        // 値は 100ns 単位
        Duration100ns := PropVar.uhVal.QuadPart;

        // 100ns → 秒（1秒 = 10,000,000 * 100ns）
        DurationSec := Duration100ns / 10000000.0;

        // 秒を四捨五入して整数に
        Result := Round(DurationSec);
      end;

      PropVariantClear(PropVar);
    end;

  finally
    CoUninitialize;
  end;
end;


end.

