unit SerifDrawPluginProfile;

// 共通SerifDrawを組み込む製品ごとの公開名、グループ、ログ先を保持する。

interface

type
  TSerifDrawPluginProfile = record
    ProductID: string;
    EffectName: string;
    GroupName: string;
    Information: string;
    SettingsItemName: string;
    DebugLogFileName: string;
  end;

// GetTableまたはInitializeSerifDrawPluginより前に製品設定を登録する。
procedure RegisterSerifDrawPluginProfile(
  const Profile: TSerifDrawPluginProfile);
// 現在DLLへ登録された製品設定を返す。未登録時は例外を返す。
function CurrentSerifDrawPluginProfile: TSerifDrawPluginProfile;

implementation

uses
  System.SysUtils;

var
  RegisteredProfile: TSerifDrawPluginProfile;

procedure RegisterSerifDrawPluginProfile(
  const Profile: TSerifDrawPluginProfile);
begin
  if (Trim(Profile.ProductID) = '') or (Trim(Profile.EffectName) = '') or
    (Trim(Profile.GroupName) = '') or
    (Trim(Profile.SettingsItemName) = '') then
    raise EArgumentException.Create('SerifDraw plugin profile is incomplete.');
  RegisteredProfile := Profile;
end;

function CurrentSerifDrawPluginProfile: TSerifDrawPluginProfile;
begin
  Result := RegisteredProfile;
  if Trim(Result.ProductID) = '' then
    raise EInvalidOp.Create('SerifDraw plugin profile is not registered.');
end;

end.
