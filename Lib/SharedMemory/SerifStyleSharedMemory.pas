unit SerifStyleSharedMemory;

// プロセス・製品ごとに分離したスタイル定義。共有領域にはポインターを保存しない。
interface

uses Winapi.Windows, System.SysUtils, System.Classes, SharedMemoryBase;

const SERIF_STYLE_COMMAND = $53535432;
type
  TSerifSharedStyle = record
    ID, Name, UID, Settings: string;
    Animation: string; // AviUtl2側設定。空文字列は旧スタイルの未収録状態。
  end;
  TSerifSharedStyles = TArray<TSerifSharedStyle>;
  TSerifStyleChannel = class
  private
    FMemory: TSharedMemoryBase;
    FMutex: THandle;
    FRevision: UInt64;
    FCache: TSerifSharedStyles;
    function Lock: Boolean;
    function ReadStyles(CopyValues: Boolean): TSerifSharedStyles;
  public
    constructor Create(const Product: string);
    destructor Destroy; override;
    // 定義全体を原子的に公開する。容量不足は例外とし切り詰めない。
    procedure Publish(const Styles: TSerifSharedStyles; Owner: HWND);
    function Snapshot: TSerifSharedStyles;
    function Find(const ID: string; out Style: TSerifSharedStyle): Boolean;
    // 明示操作だけを拡張側のUIスレッドへ渡す。描画側はSnapshotのみ使う。
    function Request(const Command: string; const Style: TSerifSharedStyle): Boolean;
  end;
// 標準=0、スタイル1～9を製品内で不変の共有キーへ変換する。
function SerifStyleSlotID(Slot: Integer): string;
function EncodeSerifStyles(const Styles: TSerifSharedStyles): string;
function DecodeSerifStyles(const Text: string): TSerifSharedStyles;

implementation
uses System.JSON, System.Generics.Collections, Winapi.Messages;
const CAPACITY = 4 * 1024 * 1024;
type
  PHeader = ^THeader;
  THeader = packed record
    Revision: UInt64;
    Owner: UInt64;
    Length: Cardinal;
  end;

function SerifStyleSlotID(Slot: Integer): string;
begin
  if (Slot < 0) or (Slot > 9) then raise ERangeError.Create('Invalid style slot');
  Result := Format('{53535432-0000-4000-8000-00000000000%d}', [Slot]);
end;

function EncodeSerifStyles(const Styles: TSerifSharedStyles): string;
var A: TJSONArray; O: TJSONObject; S: TSerifSharedStyle;
begin
  A := TJSONArray.Create;
  try
    for S in Styles do
    begin
      O := TJSONObject.Create;
      O.AddPair('id', S.ID); O.AddPair('name', S.Name);
      O.AddPair('uid', S.UID); O.AddPair('settings', S.Settings);
      O.AddPair('animation', S.Animation);
      A.AddElement(O);
    end;
    Result := A.ToJSON;
  finally A.Free end;
end;

function DecodeSerifStyles(const Text: string): TSerifSharedStyles;
var V: TJSONValue; A: TJSONArray; I: Integer;
begin
  Result := nil;
  V := TJSONObject.ParseJSONValue(Text);
  try
    if not (V is TJSONArray) then Exit;
    A := TJSONArray(V);
    SetLength(Result, A.Count);
    for I := 0 to A.Count - 1 do
    begin
      Result[I].ID := A.Items[I].GetValue<string>('id');
      Result[I].Name := A.Items[I].GetValue<string>('name');
      Result[I].UID := A.Items[I].GetValue<string>('uid');
      Result[I].Settings := A.Items[I].GetValue<string>('settings');
      Result[I].Animation := A.Items[I].GetValue<string>('animation', '');
    end;
  finally V.Free end;
end;

constructor TSerifStyleChannel.Create(const Product: string);
var N: string;
begin
  inherited Create;
  N := Format('Local\%s.SerifStyles.V2.%d', [Product, GetCurrentProcessId]);
  FMutex := CreateMutex(nil, False, PChar(N + '.Lock'));
  if FMutex = 0 then RaiseLastOSError;
  if WaitForSingleObject(FMutex, INFINITE) in [WAIT_OBJECT_0, WAIT_ABANDONED] then
  try
    FMemory := TSharedMemoryBase.Create(N, CAPACITY);
  finally ReleaseMutex(FMutex) end
  else RaiseLastOSError;
end;

destructor TSerifStyleChannel.Destroy;
begin
  FMemory.Free;
  if FMutex <> 0 then CloseHandle(FMutex);
  inherited;
end;

function TSerifStyleChannel.Lock: Boolean;
var W: DWORD;
begin
  Result := False;
  if (FMutex = 0) or not FMemory.IsOpened then Exit;
  W := WaitForSingleObject(FMutex, 1000);
  Result := (W = WAIT_OBJECT_0) or (W = WAIT_ABANDONED);
end;

procedure TSerifStyleChannel.Publish(const Styles: TSerifSharedStyles; Owner: HWND);
var Text: string; H: PHeader;
begin
  Text := EncodeSerifStyles(Styles);
  if Length(Text) > (CAPACITY - SizeOf(THeader)) div SizeOf(Char) then
    raise ERangeError.Create('共有スタイルの容量を超えています。');
  if not Lock then raise Exception.Create('共有スタイルをロックできません。');
  try
    H := FMemory.View;
    Move(PChar(Text)^, (PByte(H) + SizeOf(THeader))^, Length(Text) * SizeOf(Char));
    H.Length := Length(Text);
    H.Owner := Owner;
    Inc(H.Revision);
  finally ReleaseMutex(FMutex) end;
end;

function TSerifStyleChannel.ReadStyles(CopyValues: Boolean): TSerifSharedStyles;
var H: PHeader; Text: string;
begin
  Result := nil;
  if not Lock then Exit;
  try
    H := FMemory.View;
    if H.Length > (CAPACITY - SizeOf(THeader)) div SizeOf(Char) then Exit;
    if FRevision <> H.Revision then
    begin
      SetString(Text, PChar(PByte(H) + SizeOf(THeader)), H.Length);
      FCache := DecodeSerifStyles(Text);
      FRevision := H.Revision;
    end;
    if CopyValues then Result := Copy(FCache) else Result := FCache;
  finally ReleaseMutex(FMutex) end;
end;

function TSerifStyleChannel.Snapshot: TSerifSharedStyles;
begin
  Result := ReadStyles(True);
end;

function TSerifStyleChannel.Find(const ID: string; out Style: TSerifSharedStyle): Boolean;
var S: TSerifSharedStyle;
begin
  Result := False;
  for S in ReadStyles(False) do
    if SameText(S.ID, ID) then
    begin
      Style := S;
      Exit(True);
    end;
end;

function TSerifStyleChannel.Request(const Command: string; const Style: TSerifSharedStyle): Boolean;
var Owner: HWND; Data: TCopyDataStruct; Text: string; PID: DWORD;
begin
  Result := False;
  if not Lock then Exit;
  try Owner := HWND(PHeader(FMemory.View).Owner) finally ReleaseMutex(FMutex) end;
  PID := 0;
  GetWindowThreadProcessId(Owner, @PID);
  if (Owner = 0) or (PID <> GetCurrentProcessId) or not IsWindow(Owner) then Exit;
  Text := Command + #10 + EncodeSerifStyles([Style]);
  Data.dwData := SERIF_STYLE_COMMAND;
  Data.cbData := (Length(Text) + 1) * SizeOf(Char);
  Data.lpData := PChar(Text);
  Result := SendMessage(Owner, WM_COPYDATA, 0, LPARAM(@Data)) = 1;
end;
end.
