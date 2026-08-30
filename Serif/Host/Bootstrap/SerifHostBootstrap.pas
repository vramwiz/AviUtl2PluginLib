unit SerifHostBootstrap;

// 製品ホストが共有SerifFrameを生成する前提を検証し、親接続までを行う。
// 製品別Profile／Providerの登録自体は各アダプターユニットが担当する。

interface

uses
  System.Classes,
  Vcl.Controls,
  SerifFrame;

type
  TSerifHostConfig = record
    ProductID: string;
    AppFolderName: string;
    Parent: TWinControl;
    OnMoveCursorFocus: TFrameSerifCursorFocusEvent;
  end;

// 保存ルートとAviUtl2製品境界を検証し、alClientで接続済みのフレームを返す。
// 構成不備や生成失敗時は例外を返し、途中生成したフレームは残さない。
function CreateHostedSerifFrame(AOwner: TComponent;
  const Config: TSerifHostConfig): TFrameSerif;

implementation

uses
  System.SysUtils,
  AppFolderUtils,
  SerifAviUtlAliasProvider,
  SerifAviUtlProfile;

procedure ValidateHostConfig(const Config: TSerifHostConfig);
var
  Profile: TSerifAviUtlProfile;
  ProviderProductID: string;
begin
  if Trim(Config.ProductID) = '' then
    raise EArgumentException.Create('Serif host ProductID is empty.');
  if Trim(Config.AppFolderName) = '' then
    raise EArgumentException.Create('Serif host app folder name is empty.');
  if Config.Parent = nil then
    raise EArgumentNilException.Create('Serif host parent is nil.');

  SetAppFolderRoot(Config.AppFolderName);
  if GetAppRootFolder = '' then
    raise EInvalidOp.CreateFmt('Serif app folder is unavailable: %s',
      [Config.AppFolderName]);

  Profile := CurrentSerifAviUtlProfile;
  ProviderProductID := CurrentSerifAviUtlAliasProviderProductID;
  if not SameText(Profile.ProductID, Config.ProductID) then
    raise EInvalidOp.CreateFmt(
      'Serif AviUtl profile mismatch: expected %s, registered %s',
      [Config.ProductID, Profile.ProductID]);
  if not SameText(ProviderProductID, Config.ProductID) then
    raise EInvalidOp.CreateFmt(
      'Serif AviUtl alias provider mismatch: expected %s, registered %s',
      [Config.ProductID, ProviderProductID]);
end;

function CreateHostedSerifFrame(AOwner: TComponent;
  const Config: TSerifHostConfig): TFrameSerif;
begin
  ValidateHostConfig(Config);
  Result := TFrameSerif.Create(AOwner);
  try
    Result.Parent := Config.Parent;
    Result.Align := alClient;
    Result.OnMoveCursorFocus := Config.OnMoveCursorFocus;
    Result.DisplayPagesEnabled := Trim(
      CurrentSerifAviUtlProfile.SerifDrawEffectName) <> '';
  except
    Result.Free;
    raise;
  end;
end;

end.
