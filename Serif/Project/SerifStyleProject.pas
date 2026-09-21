unit SerifStyleProject;

// Styles.iniの正本と共有公開を拡張側で所有する。フィルターのパラメーターには書き込まない。
interface

// プロジェクト切替時に旧定義を破棄して、新しい定義を公開する。空文字列は解除。
procedure OpenSerifStyleProject(const Folder: string);

implementation
uses Winapi.Windows, Winapi.Messages, System.Classes, System.SysUtils,
  System.IniFiles, System.IOUtils, SerifStyleSharedMemory;
type
  TSerifStyleProject = class
  private
    FFolder: string;
    FWindow: HWND;
    FChannel: TSerifStyleChannel;
    FStyles: TSerifSharedStyles;
    procedure WindowProc(var Msg: TMessage);
    procedure Save(const Styles: TSerifSharedStyles);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Open(const Folder: string);
  end;
var Project: TSerifStyleProject;

function TryStyleGUID(const Text: string; out ID: TGUID): Boolean;
begin
  try
    ID := StringToGUID(Text);
    Result := True;
  except
    Result := False;
  end;
end;

constructor TSerifStyleProject.Create;
begin
  inherited;
  FChannel := TSerifStyleChannel.Create('Syncroh2');
  FWindow := AllocateHWnd(WindowProc);
end;

destructor TSerifStyleProject.Destroy;
begin
  try FChannel.Publish(nil, 0) except end;
  DeallocateHWnd(FWindow);
  FChannel.Free;
  inherited;
end;

procedure TSerifStyleProject.Open(const Folder: string);
var Ini: TMemIniFile; Sections: TStringList; ID: string; S: TSerifSharedStyle;
    G: TGUID;
begin
  if Folder = FFolder then Exit;
  FFolder := '';
  FStyles := nil;
  FChannel.Publish(nil, 0);
  if Folder = '' then Exit;
  Ini := TMemIniFile.Create(TPath.Combine(Folder, 'Styles.ini'), TEncoding.UTF8);
  Sections := TStringList.Create;
  try
    Ini.ReadSections(Sections);
    for ID in Sections do
    begin
      if not TryStyleGUID(ID, G) then Continue;
      S.ID := GUIDToString(G);
      S.Name := Ini.ReadString(ID, 'Name', S.ID);
      S.UID := Ini.ReadString(ID, 'UID', '');
      S.Settings := Ini.ReadString(ID, 'Settings', '');
      S.Animation := Ini.ReadString(ID, 'Animation', '');
      if S.Settings <> '' then FStyles := FStyles + [S];
    end;
    FChannel.Publish(FStyles, FWindow);
    FFolder := Folder;
  finally Sections.Free; Ini.Free end;
end;

procedure TSerifStyleProject.Save(const Styles: TSerifSharedStyles);
var Ini: TMemIniFile; S: TSerifSharedStyle; Filename, Temp: string;
begin
  if FFolder = '' then raise Exception.Create('セリフプロジェクトが未設定です。');
  ForceDirectories(FFolder);
  Filename := TPath.Combine(FFolder, 'Styles.ini');
  Temp := Filename + '.tmp';
  Ini := TMemIniFile.Create(Temp, TEncoding.UTF8);
  try
    Ini.Clear;
    for S in Styles do
    begin
      Ini.WriteString(S.ID, 'Name', S.Name);
      Ini.WriteString(S.ID, 'UID', S.UID);
      Ini.WriteString(S.ID, 'Settings', S.Settings);
      Ini.WriteString(S.ID, 'Animation', S.Animation);
    end;
    Ini.UpdateFile;
  finally Ini.Free end;
  if not MoveFileEx(PChar(Temp), PChar(Filename), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
    RaiseLastOSError;
end;

procedure TSerifStyleProject.WindowProc(var Msg: TMessage);
var Data: PCopyDataStruct; Text, Command: string; Styles, Next: TSerifSharedStyles;
    S: TSerifSharedStyle; I, Index, P, Slot: Integer; G: TGUID;
begin
  if Msg.Msg <> WM_COPYDATA then
  begin
    Msg.Result := DefWindowProc(FWindow, Msg.Msg, Msg.WParam, Msg.LParam);
    Exit;
  end;
  Msg.Result := 0;
  try
    Data := PCopyDataStruct(Msg.LParam);
    if (Data = nil) or (Data.dwData <> SERIF_STYLE_COMMAND) or
      (Data.lpData = nil) or (Data.cbData < 2) or (Data.cbData > 4 * 1024 * 1024) or
      (Data.cbData mod 2 <> 0) or (FFolder = '') then Exit;
    SetString(Text, PChar(Data.lpData), Data.cbData div 2 - 1);
    P := Pos(#10, Text);
    if P = 0 then Exit;
    Command := Copy(Text, 1, P - 1);
    Styles := DecodeSerifStyles(Copy(Text, P + 1, MaxInt));
    if Length(Styles) <> 1 then Exit;
    S := Styles[0];
    if not TryStyleGUID(S.ID, G) then Exit;
    S.ID := GUIDToString(G);
    Index := -1;
    for I := 0 to High(FStyles) do
      if SameText(FStyles[I].ID, S.ID) then Index := I;
    Next := Copy(FStyles);
    if Command = 'save' then
    begin
      Slot := -1;
      for I := 0 to 9 do
        if SameText(S.ID, SerifStyleSlotID(I)) then Slot := I;
      if (Slot < 0) or (S.Settings = '') then Exit;
      if Slot = 0 then S.Name := '標準' else S.Name := Format('スタイル%d', [Slot]);
      CreateGUID(G); S.UID := GUIDToString(G);
      if Index < 0 then Next := Next + [S] else Next[Index] := S;
    end
    else if Command = 'create' then
    begin
      if (Index >= 0) or (Trim(S.Name) = '') or (S.Settings = '') then Exit;
      CreateGUID(G); S.UID := GUIDToString(G);
      Next := Next + [S];
    end
    else if Command = 'update' then
    begin
      if (Index < 0) or (S.Settings = '') or (S.UID <> FStyles[Index].UID) then Exit;
      CreateGUID(G); S.UID := GUIDToString(G);
      S.Name := FStyles[Index].Name;
      Next[Index] := S;
    end
    else Exit;
    // 公開可能な容量を保存前に検査し、保存成功後だけ描画へ反映する。
    if Length(EncodeSerifStyles(Next)) > (4 * 1024 * 1024 - 20) div 2 then Exit;
    Save(Next);
    FChannel.Publish(Next, FWindow);
    FStyles := Next;
    Msg.Result := 1;
  except
    // Windows/SDKのコールバック境界から例外を漏らさない。
    Msg.Result := 0;
  end;
end;

procedure OpenSerifStyleProject(const Folder: string);
begin
  try
    if Project = nil then Project := TSerifStyleProject.Create;
    Project.Open(Folder);
  except
    on E: Exception do
      OutputDebugString(PChar('SerifStyleProject: ' + E.Message));
  end;
end;

initialization
finalization
  Project.Free;
end.
