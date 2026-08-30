unit SerifAviUtlProfile;

interface

type
  TSerifAviUtlProfile = record
    ProductID: string;
    ProjectFolderKey: AnsiString;
    SerifEffectName: string;
    SerifTextItem: string;
    CharacterItem: string;
    EmotionItem: string;
    DirectionItem: string;
    AiueoItem: string;
    LabItem: string;
    UIDItem: string;
    AudioEffectName: string;
    AudioFileItem: string;
    AudioPlaybackItem: string;
    FilterObjectName: string;
    SerifDrawEffectName: string;
  end;

// 製品起動時に一度だけAviUtl2上の名称プロファイルを登録する。
// 異なる製品IDによる再登録は構成ミスとして例外にする。
procedure RegisterSerifAviUtlProfile(const Profile: TSerifAviUtlProfile);

// 登録済みの読み取り専用プロファイルを返す。未登録なら構成エラーにする。
function CurrentSerifAviUtlProfile: TSerifAviUtlProfile;

implementation

uses System.SysUtils;

var
  GProfile: TSerifAviUtlProfile;
  GProfileRegistered: Boolean;

procedure RegisterSerifAviUtlProfile(const Profile: TSerifAviUtlProfile);
begin
  if Trim(Profile.ProductID) = '' then
    raise EArgumentException.Create('Serif AviUtl profile ProductID is empty');
  if GProfileRegistered then
  begin
    if SameText(GProfile.ProductID, Profile.ProductID) then Exit;
    raise EInvalidOp.CreateFmt(
      'Serif AviUtl profile is already registered: %s',
      [GProfile.ProductID]);
  end;
  GProfile := Profile;
  GProfileRegistered := True;
end;

function CurrentSerifAviUtlProfile: TSerifAviUtlProfile;
begin
  if not GProfileRegistered then
    raise EInvalidOp.Create('Serif AviUtl profile is not registered');
  Result := GProfile;
end;

initialization
  GProfileRegistered := False;

end.
