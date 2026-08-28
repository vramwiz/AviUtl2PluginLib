unit MmdAiDiagnosticProtocol;

// MMDモデルDLLのAI診断表示要求を検証し、JSON応答へ変換する。

interface

uses
  System.JSON;

// モデルDLLで一時診断表示を開始し、描画パスと解除トークンを返す。
function BeginMmdAiDiagnosticRequest(const ModelFile: string;
  Payload: TJSONObject): string;
// 開始時のトークンに対応する一時診断表示を解除する。
function EndMmdAiDiagnosticRequest(Payload: TJSONObject): string;

implementation

uses
  System.StrUtils,
  System.SysUtils,
  MmdAiDiagnosticState;

function ErrorJson(const Code, MessageText: string): string;
var
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'error');
    Root.AddPair('code', Code);
    Root.AddPair('message', MessageText);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function IsModelFilterHost: Boolean;
begin
  Result := ContainsText(ExtractFileName(GetModuleName(HInstance)),
    'MMD_Model_Filter');
end;

procedure AddFingerLegend(Root: TJSONObject);
var
  Legend: TJSONObject;
begin
  Legend := TJSONObject.Create;
  Root.AddPair('legend', Legend);
  Legend.AddPair('thumb', 'red');
  Legend.AddPair('index', 'yellow');
  Legend.AddPair('middle', 'green');
  Legend.AddPair('ring', 'blue');
  Legend.AddPair('little', 'purple');
  Legend.AddPair('other', 'gray');
  Legend.AddPair('right_side_brightness', '65%');
end;

procedure AddBoneLegend(Root: TJSONObject);
var
  Legend: TJSONObject;
begin
  Legend := TJSONObject.Create;
  Root.AddPair('legend', Legend);
  Legend.AddPair('left', 'blue');
  Legend.AddPair('right', 'red');
  Legend.AddPair('center', 'yellow');
end;

function BeginMmdAiDiagnosticRequest(const ModelFile: string;
  Payload: TJSONObject): string;
var
  ErrorCode, ErrorMessage, NormalizedPass, PassName, Token: string;
  Root: TJSONObject;
begin
  if not IsModelFilterHost then
    Exit(ErrorJson('diagnostic_view_unavailable',
      'Diagnostic rendering is available only from the model filter.'));
  if (Payload = nil) or not (Payload.GetValue('pass') is TJSONString) then
    Exit(ErrorJson('invalid_diagnostic_pass', 'payload.pass is required.'));
  PassName := TJSONString(Payload.GetValue('pass')).Value;
  if not BeginMmdAiDiagnosticView(ModelFile, PassName, Token, NormalizedPass,
    ErrorCode, ErrorMessage) then
    Exit(ErrorJson(ErrorCode, ErrorMessage));
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'ok');
    Root.AddPair('extension', 'mmd.pose');
    Root.AddPair('operation', 'begin_diagnostic_view');
    Root.AddPair('diagnostic_token', Token);
    Root.AddPair('pass', NormalizedPass);
    Root.AddPair('temporary', TJSONBool.Create(True));
    Root.AddPair('changes_project_state', TJSONBool.Create(False));
    Root.AddPair('model_left_is_character_left', TJSONBool.Create(True));
    if SameText(NormalizedPass, 'finger_id') then
      AddFingerLegend(Root)
    else if SameText(NormalizedPass, 'bones') or
            SameText(NormalizedPass, 'bone_overlay') then
      AddBoneLegend(Root)
    else if SameText(NormalizedPass, 'body_only') then
      Root.AddPair('limitation',
        'body_only uses material-name heuristics and must be checked against normal rendering.');
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function EndMmdAiDiagnosticRequest(Payload: TJSONObject): string;
var
  ErrorCode, ErrorMessage, Token: string;
  Root: TJSONObject;
begin
  if not IsModelFilterHost then
    Exit(ErrorJson('diagnostic_view_unavailable',
      'Diagnostic rendering is available only from the model filter.'));
  if (Payload = nil) or not (Payload.GetValue('token') is TJSONString) then
    Exit(ErrorJson('invalid_diagnostic_token', 'payload.token is required.'));
  Token := TJSONString(Payload.GetValue('token')).Value;
  if not EndMmdAiDiagnosticView(Token, ErrorCode, ErrorMessage) then
    Exit(ErrorJson(ErrorCode, ErrorMessage));
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'ok');
    Root.AddPair('extension', 'mmd.pose');
    Root.AddPair('operation', 'end_diagnostic_view');
    Root.AddPair('diagnostic_view_released', TJSONBool.Create(True));
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

end.
