unit SerifDrawFrame;

interface

uses
  System.Classes, System.Types, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Graphics, Vcl.ImgList, DragAgent, ToolbarButtons,
  ListBoxEdit, DarkLabel, DarkPanel;

type
  TFrameSerifDraw = class(TFrame)
    PanelTitle: TDarkPanel;
    LabelTitle: TDarkLabel;
    PanelCommands: TDarkPanel;
    LBoxObjects: TListBoxEdit;
  private
    FDrag: TDragFiles;
    FToolBar: TToolbarButtons;
    FToolBarImages: TImageList;
    FPresetNames: TStringList;
    FPresetAliases: TStringList;
    FSettingsFileName: string;
    FListInitialized: Boolean;
    procedure CreateToolBarImages;
    procedure EnsureDefaultPreset;
    procedure LoadPresets;
    procedure SavePresets;
    procedure RefreshPresetList;
    function IsValidPresetAlias(const AliasText: string): Boolean;
    function CreatePresetName: string;
    procedure AddUnsetPreset;
    procedure RegisterSelected;
    procedure DeleteSelected;
    procedure RenameSelected;
    procedure MoveSelectedUp;
    procedure MoveSelectedDown;
    procedure MoveSelectedTo(NewIndex: Integer);
    procedure PresetNameEdited(Sender: TObject; Index: Integer;
      var NewText: string);
    function CanStartDrag(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer): Boolean;
    procedure OnDrag(Sender: TObject; FileNames: TStringList);
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils, System.IniFiles, System.NetEncoding, System.UITypes, Vcl.Dialogs,
  AppFolderUtils, AviUtl2Serif, AviUtl2StyleColors, SerifAviUtlProfile;

{$R *.dfm}

constructor TFrameSerifDraw.Create(AOwner: TComponent);
begin
  inherited;

  FPresetNames := TStringList.Create;
  FPresetAliases := TStringList.Create;
  FSettingsFileName := GetAppFolder('Serif') + 'SerifDraw.ini';
  LoadPresets;

  Color := A2SCPanelBackground;
  PanelTitle.Height := 20;
  PanelCommands.Color := A2SCToolBarBackground;
  PanelCommands.Height := 24;
  LabelTitle.TextColor := A2SCPanelText;
  LabelTitle.DesignFontHeight := 13;

  FToolBarImages := TImageList.Create(Self);
  FToolBarImages.ColorDepth := cd32Bit;
  // 既存ツールバーと同じ32px素材を24pxボタンへ縮小する構成にする。
  FToolBarImages.Width := 32;
  FToolBarImages.Height := 32;
  FToolBarImages.Scaled := False;
  CreateToolBarImages;

  FToolBar := TToolbarButtons.Create(Self);
  FToolBar.Parent := PanelCommands;
  FToolBar.Align := alClient;
  FToolBar.Height := 24;
  FToolBar.NormalColor := A2SCToolBarBackground;
  FToolBar.HoverColor := A2SCToolBarHot;
  FToolBar.DownColor := A2SCToolBarChecked;
  FToolBar.Images := FToolBarImages;
  FToolBar.AddIcon('設定なしを追加', 0, AddUnsetPreset);
  FToolBar.AddIcon('選択オブジェクトの設定を登録', 1, RegisterSelected);
  FToolBar.AddIcon('削除', 2, DeleteSelected);
  FToolBar.AddIcon('名前の変更', 3, RenameSelected);
  FToolBar.AddIcon('上へ移動', 4, MoveSelectedUp);
  FToolBar.AddIcon('下へ移動', 5, MoveSelectedDown);

  LBoxObjects.Color := A2SCListBoxBackground;
  LBoxObjects.Font.Color := A2SCListBoxText;
  LBoxObjects.Font.Height := -13;
  LBoxObjects.ItemHeight := 24;
  LBoxObjects.OnEdited := PresetNameEdited;

  // この一覧はドラッグ開始時に実在する一時 .object を生成するため、
  // ShellFolder から IDataObject を作り直さず CF_HDROP で直接渡す。
  FDrag := TDragFiles.Create(Self);
  FDrag.Attach(LBoxObjects);
  FDrag.OnCanStart := CanStartDrag;
  FDrag.OnDragRequest := OnDrag;
end;

destructor TFrameSerifDraw.Destroy;
begin
  FDrag.Free;
  FToolBar.Free;
  FToolBarImages.Free;
  FPresetAliases.Free;
  FPresetNames.Free;
  inherited;
end;

function TFrameSerifDraw.CreatePresetName: string;
var
  Index: Integer;
begin
  Result := '新セリフ表示';
  if FPresetNames.IndexOf(Result) < 0 then Exit;

  Index := 2;
  repeat
    Result := '新セリフ表示 ' + IntToStr(Index);
    Inc(Index);
  until FPresetNames.IndexOf(Result) < 0;
end;

procedure TFrameSerifDraw.EnsureDefaultPreset;
begin
  if FPresetNames.Count > 0 then Exit;
  FPresetNames.Add('未設定');
  FPresetAliases.Add('');
end;

procedure TFrameSerifDraw.LoadPresets;
var
  Ini: TMemIniFile;
  Count: Integer;
  I: Integer;
  Section: string;
  Name: string;
  EncodedAlias: string;
  AliasText: string;
  SaveRequired: Boolean;
begin
  FPresetNames.Clear;
  FPresetAliases.Clear;
  SaveRequired := not FileExists(FSettingsFileName);

  if not SaveRequired then
  begin
    Ini := TMemIniFile.Create(FSettingsFileName, TEncoding.UTF8);
    try
      Count := Ini.ReadInteger('General', 'Count', 0);
      if Count > 1000 then Count := 1000;
      for I := 0 to Count - 1 do
      begin
        Section := 'Preset' + IntToStr(I);
        Name := Trim(Ini.ReadString(Section, 'Name', ''));
        EncodedAlias := Ini.ReadString(Section, 'AliasBase64', '');
        AliasText := '';
        if EncodedAlias <> '' then
          try
            AliasText := TEncoding.UTF8.GetString(
              TNetEncoding.Base64.DecodeStringToBytes(EncodedAlias));
          except
            AliasText := '';
          end;

        if Name = '' then Name := '未設定';
        // 設定なしの項目は名前変更後も既定エイリアスを使う。
        if (EncodedAlias = '') or IsValidPresetAlias(AliasText) then
        begin
          FPresetNames.Add(Name);
          FPresetAliases.Add(AliasText);
        end
        else
          SaveRequired := True;
      end;
    finally
      Ini.Free;
    end;
  end;

  if FPresetNames.Count = 0 then
  begin
    EnsureDefaultPreset;
    SaveRequired := True;
  end;
  if SaveRequired then SavePresets;
end;

procedure TFrameSerifDraw.SavePresets;
var
  Ini: TMemIniFile;
  I: Integer;
  Section: string;
  EncodedAlias: string;
begin
  EnsureDefaultPreset;
  Ini := TMemIniFile.Create(FSettingsFileName, TEncoding.UTF8);
  try
    Ini.Clear;
    Ini.WriteInteger('General', 'Count', FPresetNames.Count);
    for I := 0 to FPresetNames.Count - 1 do
    begin
      Section := 'Preset' + IntToStr(I);
      Ini.WriteString(Section, 'Name', FPresetNames[I]);
      EncodedAlias := '';
      if FPresetAliases[I] <> '' then
      begin
        EncodedAlias := TNetEncoding.Base64.EncodeBytesToString(
          TEncoding.UTF8.GetBytes(FPresetAliases[I]));
        EncodedAlias := StringReplace(EncodedAlias, #13, '', [rfReplaceAll]);
        EncodedAlias := StringReplace(EncodedAlias, #10, '', [rfReplaceAll]);
      end;
      Ini.WriteString(Section, 'AliasBase64', EncodedAlias);
    end;
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

function TFrameSerifDraw.IsValidPresetAlias(const AliasText: string): Boolean;
var
  Profile: TSerifAviUtlProfile;
begin
  Profile := CurrentSerifAviUtlProfile;
  Result := (Pos('effect.name=' + Profile.FilterObjectName, AliasText) > 0) and
            (Pos('effect.name=' + Profile.SerifDrawEffectName, AliasText) > 0);
end;

procedure TFrameSerifDraw.RefreshPresetList;
var
  I: Integer;
begin
  LBoxObjects.Items.BeginUpdate;
  try
    LBoxObjects.Items.Clear;
    for I := 0 to FPresetNames.Count - 1 do
      LBoxObjects.Items.Add(FPresetNames[I]);
    if LBoxObjects.Items.Count > 0 then
      LBoxObjects.ItemIndex := 0;
  finally
    LBoxObjects.Items.EndUpdate;
  end;
end;

procedure TFrameSerifDraw.AddUnsetPreset;
var
  PresetIndex: Integer;
begin
  if LBoxObjects.IsEditing then
    LBoxObjects.EndEdit(False);

  PresetIndex := FPresetNames.Add(CreatePresetName);
  FPresetAliases.Add('');
  SavePresets;
  RefreshPresetList;
  LBoxObjects.ItemIndex := PresetIndex;
end;

procedure TFrameSerifDraw.RegisterSelected;
var
  AliasText: string;
  ErrorMessage: string;
  PresetIndex: Integer;
begin
  if not AviUtl2SerifDrawGetSelectedAlias(AliasText, ErrorMessage) then
  begin
    MessageDlg(ErrorMessage, mtInformation, [mbOK], 0);
    Exit;
  end;

  PresetIndex := LBoxObjects.ItemIndex;
  if (PresetIndex < 0) or (PresetIndex >= FPresetAliases.Count) or
     (FPresetAliases[PresetIndex] <> '') then
  begin
    PresetIndex := FPresetNames.Add('');
    FPresetAliases.Add('');
    FPresetNames[PresetIndex] := CreatePresetName;
  end;

  // 起動時に自動作成した旧「未設定」項目だけは登録時に自動名へ更新する。
  if SameText(FPresetNames[PresetIndex], '未設定') then
    FPresetNames[PresetIndex] := CreatePresetName;
  FPresetAliases[PresetIndex] := AliasText;
  SavePresets;
  RefreshPresetList;
  LBoxObjects.ItemIndex := PresetIndex;
end;

procedure TFrameSerifDraw.DeleteSelected;
var
  PresetIndex: Integer;
begin
  if FPresetNames.Count <= 1 then Exit;

  PresetIndex := LBoxObjects.ItemIndex;
  if (PresetIndex < 0) or (PresetIndex >= FPresetNames.Count) then Exit;

  if LBoxObjects.IsEditing then
    LBoxObjects.EndEdit(False);
  FPresetNames.Delete(PresetIndex);
  FPresetAliases.Delete(PresetIndex);
  SavePresets;
  RefreshPresetList;
  if PresetIndex >= LBoxObjects.Items.Count then
    PresetIndex := LBoxObjects.Items.Count - 1;
  LBoxObjects.ItemIndex := PresetIndex;
end;

procedure TFrameSerifDraw.RenameSelected;
var
  PresetIndex: Integer;
begin
  PresetIndex := LBoxObjects.ItemIndex;
  if (PresetIndex < 0) or (PresetIndex >= FPresetNames.Count) then Exit;
  LBoxObjects.BeginEdit(PresetIndex);
end;

procedure TFrameSerifDraw.MoveSelectedUp;
begin
  MoveSelectedTo(LBoxObjects.ItemIndex - 1);
end;

procedure TFrameSerifDraw.MoveSelectedDown;
begin
  MoveSelectedTo(LBoxObjects.ItemIndex + 1);
end;

procedure TFrameSerifDraw.MoveSelectedTo(NewIndex: Integer);
var
  CurrentIndex: Integer;
begin
  CurrentIndex := LBoxObjects.ItemIndex;
  if (CurrentIndex < 0) or (CurrentIndex >= FPresetNames.Count) or
     (NewIndex < 0) or (NewIndex >= FPresetNames.Count) or
     (CurrentIndex = NewIndex) then Exit;

  if LBoxObjects.IsEditing then
    LBoxObjects.EndEdit(False);
  FPresetNames.Exchange(CurrentIndex, NewIndex);
  FPresetAliases.Exchange(CurrentIndex, NewIndex);
  SavePresets;
  RefreshPresetList;
  LBoxObjects.ItemIndex := NewIndex;
end;

procedure TFrameSerifDraw.PresetNameEdited(Sender: TObject; Index: Integer;
  var NewText: string);
begin
  if (Index < 0) or (Index >= FPresetNames.Count) then Exit;

  NewText := Trim(NewText);
  if NewText = '' then
    NewText := FPresetNames[Index];
  FPresetNames[Index] := NewText;
  SavePresets;
end;

procedure TFrameSerifDraw.CreateToolBarImages;
var
  Bitmap: TBitmap;
  I: Integer;
  Points: array[0..2] of TPoint;
begin
  Bitmap := TBitmap.Create;
  try
    Bitmap.SetSize(32, 32);
    Bitmap.PixelFormat := pf32bit;

    for I := 0 to 5 do
    begin
      Bitmap.Canvas.Brush.Color := clFuchsia;
      Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
      Bitmap.Canvas.Brush.Style := bsClear;
      Bitmap.Canvas.Pen.Color := A2SCToolBarFont;
      Bitmap.Canvas.Pen.Width := 2;

      case I of
        0:
          begin
            Bitmap.Canvas.MoveTo(7, 16);
            Bitmap.Canvas.LineTo(25, 16);
            Bitmap.Canvas.MoveTo(16, 7);
            Bitmap.Canvas.LineTo(16, 25);
          end;
        1:
          begin
            Bitmap.Canvas.Rectangle(7, 6, 21, 27);
            Bitmap.Canvas.MoveTo(20, 19);
            Bitmap.Canvas.LineTo(29, 19);
            Bitmap.Canvas.MoveTo(24, 15);
            Bitmap.Canvas.LineTo(24, 24);
          end;
        2:
          begin
            Bitmap.Canvas.MoveTo(8, 9);
            Bitmap.Canvas.LineTo(25, 9);
            Bitmap.Canvas.Rectangle(10, 12, 23, 27);
            Bitmap.Canvas.MoveTo(12, 5);
            Bitmap.Canvas.LineTo(22, 5);
          end;
        3:
          begin
            Bitmap.Canvas.MoveTo(7, 26);
            Bitmap.Canvas.LineTo(12, 24);
            Bitmap.Canvas.LineTo(26, 10);
            Bitmap.Canvas.LineTo(22, 6);
            Bitmap.Canvas.LineTo(8, 20);
            Bitmap.Canvas.LineTo(7, 26);
          end;
        4:
          begin
            Points[0] := Point(16, 5);
            Points[1] := Point(7, 15);
            Points[2] := Point(25, 15);
            Bitmap.Canvas.Brush.Style := bsSolid;
            Bitmap.Canvas.Brush.Color := A2SCToolBarFont;
            Bitmap.Canvas.Polygon(Points);
            Bitmap.Canvas.FillRect(Rect(13, 14, 20, 28));
          end;
        5:
          begin
            Points[0] := Point(16, 27);
            Points[1] := Point(7, 17);
            Points[2] := Point(25, 17);
            Bitmap.Canvas.Brush.Style := bsSolid;
            Bitmap.Canvas.Brush.Color := A2SCToolBarFont;
            Bitmap.Canvas.Polygon(Points);
            Bitmap.Canvas.FillRect(Rect(13, 4, 20, 18));
          end;
      end;

      FToolBarImages.AddMasked(Bitmap, clFuchsia);
    end;
  finally
    Bitmap.Free;
  end;
end;

procedure TFrameSerifDraw.CreateWnd;
begin
  inherited;
  if not FListInitialized then
  begin
    RefreshPresetList;
    FListInitialized := True;
  end;
end;

function TFrameSerifDraw.CanStartDrag(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer): Boolean;
var
  Index: Integer;
begin
  Index := LBoxObjects.ItemAtPos(Point(X, Y), True);
  Result := Index >= 0;
  if Result then
    LBoxObjects.ItemIndex := Index;
end;

procedure TFrameSerifDraw.OnDrag(Sender: TObject; FileNames: TStringList);
var
  AliasFileName: string;
  Index: Integer;
begin
  FileNames.Clear;
  Index := LBoxObjects.ItemIndex;
  if (Index < 0) or (Index >= FPresetAliases.Count) then Exit;

  if FPresetAliases[Index] = '' then
    AliasFileName := AviUtl2SerifDrawDandD
  else
  begin
    if not IsValidPresetAlias(FPresetAliases[Index]) then Exit;
    AliasFileName := AviUtl2SerifDrawDandD(FPresetAliases[Index]);
  end;
  if AliasFileName <> '' then
    FileNames.Add(AliasFileName);
end;

end.
