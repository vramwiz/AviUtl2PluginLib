unit SerifAviUtlDragAlias;


{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

// Syncroh2形式のセリフ表示オブジェクトをD&D用エイリアスへ変換する。
// セリフ入力の生成・更新から分離し、一時ファイルの所有と破棄もこの境界で完結する。

interface

// 新しいセリフ表示フィルターのD&D用ファイルを生成する。
function CreateSerifDrawDragAlias: string; overload;
// 登録済みの完全エイリアスからD&D用ファイルを生成する。
function CreateSerifDrawDragAlias(const AliasText: string): string; overload;
// 選択中の新セリフ表示フィルターを完全エイリアスとして取得する。
function GetSelectedSerifDrawAlias(out AliasText,
  ErrorMessage: string): Boolean;
// 旧セリフ表示スクリプトのD&D用ファイルを生成する。
function CreateSerifMessageViewDragAlias(const Layer: Integer): string;

implementation

uses
  System.Classes,
  System.StrUtils,
  System.SysUtils,
  AppFolderUtils,
  AviUtl2ObjectAliasValue,
  AviUtl2PluginObjectFind,
  AviUtl2PluginObjectInfo,
  AviUtl2PluginTypes,
  AviUtl2TimeConvert,
  SerifAviUtlAliasProvider,
  SerifAviUtlDrawAliasBuilder,
  SerifAviUtlProfile;

var
  DragFileName: string;

function CreateUniqueDragFileName: string;
var
  Guid: TGUID;
  UniqueName: string;
begin
  if DragFileName <> '' then
    DeleteFile(DragFileName);

  CreateGUID(Guid);
  UniqueName := GUIDToString(Guid);
  UniqueName := StringReplace(UniqueName, '{', '', [rfReplaceAll]);
  UniqueName := StringReplace(UniqueName, '}', '', [rfReplaceAll]);
  UniqueName := StringReplace(UniqueName, '-', '', [rfReplaceAll]);
  Result := GetAppFolder('Temp') + 'SerifDraw_' + UniqueName + '.object';
  DragFileName := Result;
end;

function CreateSerifDrawDragAlias: string;
begin
  Result := CreateSerifDrawDragAlias(BuildSerifAviUtlDrawAlias);
end;

function CreateSerifDrawDragAlias(const AliasText: string): string;
var
  Encoding: TEncoding;
  FileName: string;
  Lines: TStringList;
begin
  Result := '';
  if Trim(AliasText) = '' then Exit;

  Lines := TStringList.Create;
  Encoding := TUTF8Encoding.Create(False);
  try
    Lines.Text := NormalizeSerifDrawDragAlias(AliasText);
    FileName := CreateUniqueDragFileName;
    Lines.SaveToFile(FileName, Encoding);
    Result := FileName;
  finally
    Encoding.Free;
    Lines.Free;
  end;
end;

function GetSelectedSerifDrawAlias(out AliasText,
  ErrorMessage: string): Boolean;
var
  AliasValue: TAviUtl2ObjectAliasValue;
  FrameEnd: Integer;
  FrameStart: Integer;
  HasLayer: Boolean;
  HasSerifDraw: Boolean;
  Index: Integer;
  Layer: Integer;
  Lines: TStringList;
  Obj: TObjectHandle;
  Profile: TSerifAviUtlProfile;
  SelectedCount: Integer;
begin
  Result := False;
  AliasText := '';
  ErrorMessage := '';

  SelectedCount := AviUtl2FindObjectSelectedNum;
  if SelectedCount > 1 then
  begin
    ErrorMessage := '登録するオブジェクトを1個だけ選択してください。';
    Exit;
  end;
  if SelectedCount = 1 then
    Obj := AviUtl2FindObjectSelected(0)
  else
    Obj := AviUtl2FindObjectFocus;
  if Obj = nil then
  begin
    ErrorMessage := '登録するオブジェクトが選択されていません。';
    Exit;
  end;

  AliasValue := TAviUtl2ObjectAliasValue.Create;
  Lines := TStringList.Create;
  try
    Profile := CurrentSerifAviUtlProfile;
    if not AliasValue.LoadFromAviUtl2Object(Obj) then
    begin
      ErrorMessage := '選択中オブジェクトのエイリアスを取得できませんでした。';
      Exit;
    end;
    if (AliasValue.Filters.Count = 0) or
       not SameText(AliasValue.Filters[0].Filter,
         Profile.FilterObjectName) then
    begin
      ErrorMessage := '選択中オブジェクトは独立したフィルタオブジェクトではありません。';
      Exit;
    end;

    HasSerifDraw := False;
    for Index := 1 to AliasValue.Filters.Count - 1 do
      if SameText(AliasValue.Filters[Index].Filter,
        Profile.SerifDrawEffectName) then
      begin
        HasSerifDraw := True;
        Break;
      end;
    if not HasSerifDraw then
    begin
      ErrorMessage := '選択中オブジェクトに「' +
        Profile.SerifDrawEffectName + '」がありません。';
      Exit;
    end;

    Lines.Text := AliasValue.AliasText;
    if Lines.Count = 0 then
    begin
      ErrorMessage := '選択中オブジェクトのエイリアスが空です。';
      Exit;
    end;
    AviUtl2GetObjectLayerFrame(Obj, Layer, FrameStart, FrameEnd);
    HasLayer := False;
    for Index := 0 to Lines.Count - 1 do
      if StartsText('layer=', Lines[Index]) then
      begin
        HasLayer := True;
        Break;
      end;
    if not HasLayer then
      Lines.Insert(1, 'layer=' + IntToStr(Layer));

    AliasText := NormalizeSerifDrawDragAlias(Lines.Text);
    Result := True;
  finally
    Lines.Free;
    AliasValue.Free;
  end;
end;

function CreateSerifMessageViewDragAlias(const Layer: Integer): string;
var
  Convert: Double;
begin
  Convert := AviUtl2Convert;
  Result := CreateSerifAviUtlOutputAlias(Layer, Round(5.0 / Convert));
end;

initialization

finalization
  if DragFileName <> '' then
    DeleteFile(DragFileName);

end.
