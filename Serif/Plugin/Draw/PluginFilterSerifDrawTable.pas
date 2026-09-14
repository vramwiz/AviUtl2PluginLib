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
  SettingsButton: TFILTER_ITEM_BUTTON;

procedure SettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  BackgroundHeight: Integer;
  BackgroundPixels: TBytes;
  BackgroundStatus: string;
  BackgroundWidth: Integer;
  CurrentSettings: TSerifDrawSettings;
  CurrentText: string;
  ErrorText: string;
  FocusObject: OBJECT_HANDLE;
  Form: TFormSerifDrawSettings;
  Profile: TSerifDrawPluginProfile;
  SelectedSettings: TSerifDrawSettings;
  SelectedText: string;
  Utf8Text: UTF8String;
  Generation: UInt64;
begin
  try
    Profile := CurrentSerifDrawPluginProfile;
    SerifDrawDebugLog('Settings button clicked.');
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
      Generation := NewSerifDrawStyleGeneration;
      SetCurrentSerifDrawStyleMeta(CurrentSerifDrawStyleNo, Generation);
      PublishSerifDrawStyle(CurrentSerifDrawStyleNo, Generation, SelectedText);
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
    AddString(SerifDrawSettingsItem, PWideChar(Profile.SettingsItemName), '');
    AddSerifDrawAnimationItems;
  end;
  Result := @GTable;
end;

end.
