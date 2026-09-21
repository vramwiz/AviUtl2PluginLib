unit PluginFilterSerifDrawStyle;

// スタイル番号の選択、明示的な保存／読み込み、描画時の世代解決を担当する。
interface
uses AviUtl2FilterTypes;
// セレクタは先頭側、内部値は全ユーザー項目の後へ登録する。
procedure AddSerifDrawStyleItems;
procedure AddSerifDrawStyleInternalItems;
function CurrentSerifDrawStyleID: string;
function ResolvedSerifDrawStyleUID: string;
function SerifDrawStyleStatus: string;
// 旧世代だけ共有定義を参照し、保存済みオブジェクトには書き戻さない。
function ResolveSerifDrawStyleText(const ALocalText: string): string;
function TryResolveSerifDrawStyleAnimation(out Text: string): Boolean;
// 明示保存は自身の値を公開し、読み込みは共有値を自身へ取り込む。
procedure SaveCurrentSerifDrawStyle(Edit: PEDIT_SECTION; const LocalText: string);
procedure LoadCurrentSerifDrawStyle(Edit: PEDIT_SECTION);
// 個別編集後の設定がどの共有世代を基にしているか記録する。
procedure SetCurrentSerifDrawStyleVersion(Edit: PEDIT_SECTION; const UID: string);

implementation
uses System.SysUtils, PluginFilterTable, SerifDrawPluginProfile, SerifStyleSharedMemory,
  PluginFilterSerifDrawAnimationItems;
var
  StyleItem: TFILTER_ITEM_SELECT;
  StyleIDItem, StyleUIDItem, StyleAnimationUIDItem: TFILTER_ITEM_STRING;
  InternalGroup: TFILTER_ITEM_GROUP;
  Names: array[0..9] of string;
  Choices: array[0..10] of TFILTER_ITEM_SELECT_ITEM;
  Channel: TSerifStyleChannel;

procedure AddSerifDrawStyleItems;
var I: Integer;
begin
  if Channel = nil then
    Channel := TSerifStyleChannel.Create(CurrentSerifDrawPluginProfile.ProductID);
  for I := 0 to 9 do
  begin
    if I = 0 then Names[I] := '標準' else Names[I] := Format('スタイル%d', [I]);
    Choices[I].Name := PChar(Names[I]);
    Choices[I].Value := I;
  end;
  Choices[10].Name := nil;
  AddSelect(StyleItem, 'スタイル', 0, @Choices[0]);
end;

procedure AddSerifDrawStyleInternalItems;
begin
  AddGroup(InternalGroup, '内部データ', 0);
  AddString(StyleIDItem, 'StyleID', '');
  AddString(StyleUIDItem, 'StyleUID', '');
  AddString(StyleAnimationUIDItem, 'StyleAnimationUID', '');
end;

function CurrentSerifDrawStyleID: string;
begin
  // 番号から安定した内部IDを作り、別オブジェクトでも同じ共有先を参照する。
  if (StyleItem.Value < 0) or (StyleItem.Value > 9) then
    Result := SerifStyleSlotID(0)
  else Result := SerifStyleSlotID(StyleItem.Value);
end;

function TryStyle(out Style: TSerifSharedStyle): Boolean;
begin
  Result := (Channel <> nil) and Channel.Find(CurrentSerifDrawStyleID, Style);
end;

function IsCurrentGeneration(const Style: TSerifSharedStyle): Boolean;
begin
  Result := (StyleIDItem.Value <> nil) and (StyleUIDItem.Value <> nil) and
    SameText(string(StyleIDItem.Value), Style.ID) and
    (string(StyleUIDItem.Value) = Style.UID) and (Style.UID <> '');
end;

function ResolveSerifDrawStyleText(const ALocalText: string): string;
var S: TSerifSharedStyle;
begin
  Result := ALocalText;
  if TryStyle(S) and not IsCurrentGeneration(S) then Result := S.Settings;
end;

function TryResolveSerifDrawStyleAnimation(out Text: string): Boolean;
var S: TSerifSharedStyle;
begin
  Text := '';
  Result := TryStyle(S) and (S.Animation <> '');
  if not Result then Exit;
  Result := not ((StyleIDItem.Value <> nil) and (StyleAnimationUIDItem.Value <> nil) and
    SameText(string(StyleIDItem.Value), S.ID) and (string(StyleAnimationUIDItem.Value) = S.UID));
  if Result then Text := S.Animation;
end;

function ResolvedSerifDrawStyleUID: string;
var S: TSerifSharedStyle;
begin
  Result := '';
  if TryStyle(S) then Result := S.UID;
end;

function SerifDrawStyleStatus: string;
var S: TSerifSharedStyle;
begin
  if not TryStyle(S) then Result := '共有スタイル未保存: 自身の設定で表示'
  else if IsCurrentGeneration(S) then Result := S.Name + ': 自身の設定（最新世代）'
  else Result := S.Name + ': 共有側の最新設定で表示（読み込みで自身へ取得）';
end;

procedure WriteObjectValue(Edit: PEDIT_SECTION; const Name, Text: string);
var Obj: OBJECT_HANDLE; Value: UTF8String; Profile: TSerifDrawPluginProfile;
begin
  if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or
    not Assigned(Edit^.SetObjectItemValue) then
    raise Exception.Create('保存対象のオブジェクトを取得できません。');
  Obj := Edit^.GetFocusObject();
  if Obj = nil then raise Exception.Create('保存対象のオブジェクトがありません。');
  Profile := CurrentSerifDrawPluginProfile;
  Value := UTF8String(Text);
  if not Edit^.SetObjectItemValue(Obj, PWideChar(Profile.EffectName), PWideChar(Name), PAnsiChar(Value)) then
    raise Exception.Create('オブジェクトの値を保存できませんでした: ' + Name);
end;

procedure SetCurrentSerifDrawStyleVersion(Edit: PEDIT_SECTION; const UID: string);
begin
  WriteObjectValue(Edit, 'StyleID', CurrentSerifDrawStyleID);
  WriteObjectValue(Edit, 'StyleUID', UID);
end;

procedure SaveCurrentSerifDrawStyle(Edit: PEDIT_SECTION; const LocalText: string);
var S, Published: TSerifSharedStyle; Profile: TSerifDrawPluginProfile;
begin
  if Channel = nil then Exit;
  S.ID := CurrentSerifDrawStyleID;
  S.Settings := LocalText;
  S.Animation := EncodeSerifDrawAnimation(LocalSerifDrawAnimationParameters);
  // 共有側の解決済み値ではなく、必ず自身の保存データを公開する。
  if not Channel.Request('save', S) then
    raise Exception.Create('スタイルを保存できませんでした。拡張側でセリフプロジェクトを開いてください。');
  if not Channel.Find(S.ID, Published) then
    raise Exception.Create('保存したスタイルを確認できませんでした。');
  Profile := CurrentSerifDrawPluginProfile;
  WriteObjectValue(Edit, Profile.SettingsItemName, LocalText);
  WriteObjectValue(Edit, 'StyleAnimationUID', Published.UID);
  SetCurrentSerifDrawStyleVersion(Edit, Published.UID);
end;

procedure LoadCurrentSerifDrawStyle(Edit: PEDIT_SECTION);
var S: TSerifSharedStyle; Profile: TSerifDrawPluginProfile;
begin
  if not TryStyle(S) then
    raise Exception.Create('選択中のスタイルはまだ共有側に保存されていません。');
  Profile := CurrentSerifDrawPluginProfile;
  LoadSerifDrawAnimation(Edit, Profile.EffectName, S.Animation);
  WriteObjectValue(Edit, Profile.SettingsItemName, S.Settings);
  WriteObjectValue(Edit, 'StyleAnimationUID', S.UID);
  SetCurrentSerifDrawStyleVersion(Edit, S.UID);
end;

initialization
finalization
  Channel.Free;
end.