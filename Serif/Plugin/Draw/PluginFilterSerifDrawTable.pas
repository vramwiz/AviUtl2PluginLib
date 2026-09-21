unit PluginFilterSerifDrawTable;

interface

uses
  AviUtl2FilterTypes;

function GetTable: PFILTER_PLUGIN_TABLE;

implementation

uses
  System.SysUtils,
  System.UITypes,
  Vcl.Dialogs,
  Vcl.Forms,
  PluginFilterSerifDraw,
  PluginFilterSerifDrawDebugLog,
  PluginFilterSerifDrawAnimationItems,
  PluginFilterSerifDrawFrameCapture,
  PluginFilterSerifDrawSettings,
  PluginFilterSerifDrawStyle,
  PluginFilterSerifDrawSettingsForm,
  SerifDrawPluginProfile,
  PluginFilterTable;

var
  SettingsButton, StyleSaveButton, StyleLoadButton: TFILTER_ITEM_BUTTON;

procedure SettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  BackgroundHeight: Integer;
  BackgroundPixels: TBytes;
  BackgroundStatus: string;
  BackgroundWidth: Integer;
  CurrentSettings: TSerifDrawSettings;
  CurrentText, ExpectedStyleUID: string;
  ErrorText: string;
  FocusObject: OBJECT_HANDLE;
  Form: TFormSerifDrawSettings;
  Profile: TSerifDrawPluginProfile;
  SelectedSettings: TSerifDrawSettings;
  SelectedText: string;
  Utf8Text: UTF8String;
begin
  try
    Profile := CurrentSerifDrawPluginProfile;
    SerifDrawDebugLog('Settings button clicked.');
    ExpectedStyleUID := ResolvedSerifDrawStyleUID;
    CurrentText := '';
    if Assigned(SerifDrawSettingsItem.Value) then
      CurrentText := string(SerifDrawSettingsItem.Value);
    CurrentText := ResolveSerifDrawStyleText(CurrentText);
    SerifDrawDebugLog('Settings source data: ' + CurrentText);
    if Trim(CurrentText) = '' then
      CurrentSettings := TSerifDrawSettings.Default
    else if not TSerifDrawSettings.TryDecode(CurrentText, CurrentSettings,
      ErrorText) then
    begin
      CurrentSettings := TSerifDrawSettings.Default;
      SerifDrawDebugLog('Unsupported settings data was replaced with defaults: ' +
        ErrorText);
    end;

    Form := TFormSerifDrawSettings.Create(nil);
    try
      if CopySerifDrawFrame(BackgroundPixels, BackgroundWidth,
        BackgroundHeight, BackgroundStatus) then
        Form.SetBackgroundRgba(BackgroundPixels, BackgroundWidth,
          BackgroundHeight);
      Form.SetCaptureStatus(BackgroundStatus);
      Form.Caption := Form.Caption + ' - ' + SerifDrawStyleStatus;
      Form.LoadSettings(CurrentSettings);
      Form.SetSnapshots(CopyKnownSerifDrawSnapshots);
      Form.ShowModal;
      if not Form.TryGetSettings(SelectedSettings, ErrorText) then
      begin
        MessageDlg('設定値を保存できません。' + sLineBreak + ErrorText,
          mtError, [mbOK], 0);
        Exit;
      end;
      SelectedText := SelectedSettings.Encode;
      if SelectedText = CurrentText then
      begin
        SerifDrawDebugLog('Settings unchanged; object value was not written.');
        Exit;
      end;
      FocusObject := nil;
      if (Edit <> nil) and Assigned(Edit^.GetFocusObject) then
        FocusObject := Edit^.GetFocusObject();
      if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
        (FocusObject = nil) then
      begin
        MessageDlg('設定の保存対象を取得できませんでした。',
          mtError, [mbOK], 0);
        Exit;
      end;
      Utf8Text := UTF8String(SelectedText);
      if not Edit^.SetObjectItemValue(FocusObject,
        PWideChar(Profile.EffectName), PWideChar(Profile.SettingsItemName),
        PAnsiChar(Utf8Text)) then
      begin
        MessageDlg('設定をテキストパラメータ1へ反映できませんでした。',
          mtError, [mbOK], 0);
        Exit;
      end;
      SetCurrentSerifDrawStyleVersion(Edit, ExpectedStyleUID);
      SerifDrawDebugLog('Settings saved: ' + SelectedText);
    finally
      Form.Free;
    end;
  except
    on E: Exception do
    begin
      SerifDrawDebugLog('Settings callback failed: ' + E.ClassName + ': ' +
        E.Message);
      MessageDlg('設定画面を開けませんでした。' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
    end;
  end;
end;

procedure StyleSaveButtonCallback(Edit: PEDIT_SECTION); cdecl;
var Text: string; Settings: TSerifDrawSettings;
begin
  try
    Text := '';
    if SerifDrawSettingsItem.Value <> nil then Text := string(SerifDrawSettingsItem.Value);
    if Text = '' then
    begin
      Settings := TSerifDrawSettings.Default;
      Text := Settings.Encode;
    end;
    SaveCurrentSerifDrawStyle(Edit, Text);
  except
    on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure StyleLoadButtonCallback(Edit: PEDIT_SECTION); cdecl;
begin
  try
    LoadCurrentSerifDrawStyle(Edit);
  except
    on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

function FilterProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  ProcVideo(Video);
  Result := 1;
end;

function GetTable: PFILTER_PLUGIN_TABLE;
var
  Profile: TSerifDrawPluginProfile;
begin
  if GTable.Name = nil then
  begin
    Profile := CurrentSerifDrawPluginProfile;
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER,
      PWideChar(Profile.EffectName),
      PWideChar(Profile.GroupName),
      PWideChar(Profile.Information),
      @FilterProcVideo,
      nil);
    AddButton(SettingsButton, '設定', SettingsButtonCallback);
    AddSerifDrawStyleItems;
    AddButton(StyleSaveButton, 'スタイルを保存', StyleSaveButtonCallback);
    AddButton(StyleLoadButton, '読み込み', StyleLoadButtonCallback);
    AddSerifDrawAnimationItems;
    AddSerifDrawStyleInternalItems;
    AddString(SerifDrawSettingsItem, PWideChar(Profile.SettingsItemName), '');
  end;
  Result := @GTable;
end;

end.
