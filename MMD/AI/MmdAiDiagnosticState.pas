unit MmdAiDiagnosticState;

// AI診断画像を取得する短い期間だけ、対象モデルの描画モードを安全に共有する。

interface

type
  TMmdAiDiagnosticMode = (
    madNormal,
    madBones,
    madBoneOverlay,
    madSilhouette,
    madFingerId,
    madBodyOnly
  );

// 診断表示を開始し、解除時に必要な一意トークンを返す。
function BeginMmdAiDiagnosticView(const ModelFile, PassName: string;
  out Token, NormalizedPass, ErrorCode, ErrorMessage: string): Boolean;
// 開始時のトークンが一致する診断表示だけを解除する。
function EndMmdAiDiagnosticView(const Token: string;
  out ErrorCode, ErrorMessage: string): Boolean;
// 描画対象モデルに有効な診断モードを返す。期限切れ状態は自動的に破棄する。
function TryGetMmdAiDiagnosticMode(const ModelFile: string;
  out Mode: TMmdAiDiagnosticMode): Boolean;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils;

const
  DIAGNOSTIC_VIEW_TIMEOUT_MS = 15000;

var
  ActiveExpiresAt: UInt64;
  ActiveModelFile: string;
  ActiveMode: TMmdAiDiagnosticMode;
  ActiveToken: string;
  LastEndedExpiresAt: UInt64;
  LastEndedToken: string;
  StateLock: TObject;

function NormalizeFileName(const FileName: string): string;
begin
  Result := LowerCase(TPath.GetFullPath(FileName));
end;

function TryParseMode(const Value: string; out Mode: TMmdAiDiagnosticMode;
  out Normalized: string): Boolean;
begin
  Result := True;
  if SameText(Value, 'normal') then
  begin
    Mode := madNormal;
    Normalized := 'normal';
  end
  else if SameText(Value, 'bones') then
  begin
    Mode := madBones;
    Normalized := 'bones';
  end
  else if SameText(Value, 'bone_overlay') then
  begin
    Mode := madBoneOverlay;
    Normalized := 'bone_overlay';
  end
  else if SameText(Value, 'silhouette') then
  begin
    Mode := madSilhouette;
    Normalized := 'silhouette';
  end
  else if SameText(Value, 'finger_id') then
  begin
    Mode := madFingerId;
    Normalized := 'finger_id';
  end
  else if SameText(Value, 'body_only') then
  begin
    Mode := madBodyOnly;
    Normalized := 'body_only';
  end
  else
  begin
    Mode := madNormal;
    Normalized := '';
    Result := False;
  end;
end;

procedure ClearActiveView;
begin
  ActiveToken := '';
  ActiveModelFile := '';
  ActiveExpiresAt := 0;
  ActiveMode := madNormal;
end;

function NewToken: string;
var
  Value: TGUID;
begin
  if CreateGUID(Value) <> 0 then
    RaiseLastOSError;
  Result := LowerCase(GUIDToString(Value));
end;

function BeginMmdAiDiagnosticView(const ModelFile, PassName: string;
  out Token, NormalizedPass, ErrorCode, ErrorMessage: string): Boolean;
var
  Mode: TMmdAiDiagnosticMode;
  NowTick: UInt64;
begin
  Result := False;
  Token := '';
  NormalizedPass := '';
  ErrorCode := '';
  ErrorMessage := '';
  if ModelFile = '' then
  begin
    ErrorCode := 'invalid_model_file';
    ErrorMessage := 'model_file must not be empty.';
    Exit;
  end;
  if not TryParseMode(PassName, Mode, NormalizedPass) then
  begin
    ErrorCode := 'unsupported_diagnostic_pass';
    ErrorMessage := 'The requested diagnostic pass is not supported.';
    Exit;
  end;
  TMonitor.Enter(StateLock);
  try
    NowTick := GetTickCount64;
    if (ActiveToken <> '') and (NowTick < ActiveExpiresAt) then
    begin
      if SameText(ActiveModelFile, NormalizeFileName(ModelFile)) and
         (ActiveMode = Mode) then
      begin
        Token := ActiveToken;
        Exit(True);
      end
      else
      begin
        ErrorCode := 'diagnostic_view_busy';
        ErrorMessage := 'Another diagnostic view is already active.';
        Exit;
      end;
    end;
    ClearActiveView;
    LastEndedToken := '';
    LastEndedExpiresAt := 0;
    ActiveToken := NewToken;
    ActiveModelFile := NormalizeFileName(ModelFile);
    ActiveMode := Mode;
    ActiveExpiresAt := NowTick + DIAGNOSTIC_VIEW_TIMEOUT_MS;
    Token := ActiveToken;
    Result := True;
  finally
    TMonitor.Exit(StateLock);
  end;
end;

function EndMmdAiDiagnosticView(const Token: string;
  out ErrorCode, ErrorMessage: string): Boolean;
begin
  Result := False;
  ErrorCode := '';
  ErrorMessage := '';
  TMonitor.Enter(StateLock);
  try
    if (ActiveToken = '') and SameText(Token, LastEndedToken) and
       (GetTickCount64 < LastEndedExpiresAt) then
      Exit(True);
    if (ActiveToken = '') or not SameText(Token, ActiveToken) then
    begin
      ErrorCode := 'diagnostic_token_mismatch';
      ErrorMessage := 'The diagnostic view token does not match.';
      Exit;
    end;
    LastEndedToken := ActiveToken;
    LastEndedExpiresAt := GetTickCount64 + DIAGNOSTIC_VIEW_TIMEOUT_MS;
    ClearActiveView;
    Result := True;
  finally
    TMonitor.Exit(StateLock);
  end;
end;

function TryGetMmdAiDiagnosticMode(const ModelFile: string;
  out Mode: TMmdAiDiagnosticMode): Boolean;
begin
  Mode := madNormal;
  TMonitor.Enter(StateLock);
  try
    if (ActiveToken <> '') and (GetTickCount64 >= ActiveExpiresAt) then
      ClearActiveView;
    Result := (ActiveToken <> '') and
      SameText(ActiveModelFile, NormalizeFileName(ModelFile));
    if Result then
      Mode := ActiveMode;
  finally
    TMonitor.Exit(StateLock);
  end;
end;

initialization
  StateLock := TObject.Create;

finalization
  StateLock.Free;

end.
