unit VectorRendererImageList;

// 個別のVectorRendererDataファイルをCharacters.iniへ集約リソース化する。

interface

uses
  System.Classes,
  System.SysUtils,
  RTTIPersistentIni,
  RTTISectionPersistent,
  VectorRendererData;

type
  // 集約リソース内の画像1件分を管理する。
  TVectorRendererImageItem = class(TRTTIPersistentIni)
  private
    FFileName: string;                     // 元になった個別iniファイル名
    FFileDateTime: TDateTime;              // 元になった個別iniファイルの更新日時
    FDataText: string;                     // ベクターデータを別セクション記号で保存した文字列
    FData: TVectorRendererDataList;        // 画像本体のベクターデータ
    // ベクターデータをDataTextへ反映する。
    procedure SaveDataToText;
    // DataTextをベクターデータへ反映する。
    procedure LoadDataFromText;
  public
    // 内部データを生成する。
    constructor Create;
    // 内部データを破棄する。
    destructor Destroy; override;
    // 個別iniファイルを読み込んで画像データを差し替える。
    procedure LoadVectorFile(const AFileName: string);
    // 画像データを個別iniファイルとして保存する。
    function SaveVectorFile(const AFolder: string): Boolean;
    // RTTI保存用の文字列へ変換する。
    procedure SerializeToStrings(Instance: TPersistent; Dest: TStrings); override;
    // RTTI保存用の文字列から復元する。
    procedure DeserializeFromStrings(Instance: TPersistent; const Src: TStrings); override;
    property Data: TVectorRendererDataList read FData;
  published
    property FileName: string read FFileName write FFileName;
    property FileDateTime: TDateTime read FFileDateTime write FFileDateTime;
    property DataText: string read FDataText write FDataText;
  end;

  // Characters.iniとして複数の画像データを管理する。
  TVectorRendererImageList = class(TRTTISectionPersistentList<TVectorRendererImageItem>)
  private
    // ファイル名に一致する画像要素を返す。
    function GetImages(Index: Integer): TVectorRendererImageItem;
  public
    // ファイルから集約リソースを読み込む。
    procedure LoadFromFile; reintroduce;
    // ファイルへ集約リソースを保存する。
    procedure SaveToFile; reintroduce;
    // フォルダ内の個別iniをCharacters.iniへ反映する。
    function BuildResourceFromFolder(const AFolder: string): Integer;
    // 集約リソースから個別iniファイルを復元する。
    function RestoreFilesToFolder(const AFolder: string): Integer;
    // 集約リソースファイルを読み込んで個別iniファイルを復元する。
    function RestoreFilesFromFile(const AFileName, AFolder: string): Integer;
    // 集約リソース文字列を読み込んで個別iniファイルを復元する。
    function RestoreFilesFromStrings(AStrings: TStringList; const AFolder: string): Integer;
    // ファイル名に一致する画像要素を検索する。
    function FindByFileName(const AFileName: string): TVectorRendererImageItem;
    property Images[Index: Integer]: TVectorRendererImageItem read GetImages;
  end;

implementation

uses
  System.IOUtils;

const
  CHARACTER_RESOURCE_FILE = 'Characters.ini';
  VECTOR_DATA_LEFT_BRACKET = '<';
  VECTOR_DATA_RIGHT_BRACKET = '>';

{ TVectorRendererImageItem }

// 内部データを生成する。
constructor TVectorRendererImageItem.Create;
begin
  inherited Create;
  FFileName := '';
  FFileDateTime := 0;
  FDataText := '';
  FData := TVectorRendererDataList.Create;
end;

// 内部データを破棄する。
destructor TVectorRendererImageItem.Destroy;
begin
  FData.Free;
  inherited;
end;

// RTTI保存用の文字列から復元する。
procedure TVectorRendererImageItem.DeserializeFromStrings(Instance: TPersistent;
  const Src: TStrings);
begin
  inherited DeserializeFromStrings(Instance, Src);
  LoadDataFromText;
end;

// DataTextをベクターデータへ反映する。
procedure TVectorRendererImageItem.LoadDataFromText;
var
  SL: TStringList;                         // DataTextを展開する文字列リスト
begin
  FData.ClearData;
  if FDataText = '' then
    Exit;
  SL := TStringList.Create;
  try
    SL.Text := FDataText;
    FData.SetBrackets(VECTOR_DATA_LEFT_BRACKET, VECTOR_DATA_RIGHT_BRACKET);
    FData.LoadFromStrings(SL);
  finally
    SL.Free;
  end;
end;

// 個別iniファイルを読み込んで画像データを差し替える。
procedure TVectorRendererImageItem.LoadVectorFile(const AFileName: string);
begin
  FFileName := TPath.GetFileName(AFileName);
  FFileDateTime := TFile.GetLastWriteTime(AFileName);
  FData.ClearData;
  FData.SetBrackets('[', ']');
  FData.Filename := AFileName;
  FData.LoadFromFile;
  SaveDataToText;
end;

// 画像データを個別iniファイルとして保存する。
function TVectorRendererImageItem.SaveVectorFile(const AFolder: string): Boolean;
var
  OutputFileName: string;                  // 保存先の個別iniファイル名
begin
  Result := False;
  if FFileName = '' then
    Exit;
  OutputFileName := TPath.Combine(AFolder, FFileName);
  if FileExists(OutputFileName) and
    (TFile.GetLastWriteTime(OutputFileName) = FFileDateTime) then
    Exit;
  ForceDirectories(AFolder);
  FData.SetBrackets('[', ']');
  FData.Filename := OutputFileName;
  FData.SaveToFile;
  if FFileDateTime <> 0 then
    TFile.SetLastWriteTime(OutputFileName, FFileDateTime);
  Result := True;
end;

// ベクターデータをDataTextへ反映する。
procedure TVectorRendererImageItem.SaveDataToText;
var
  SL: TStringList;                         // ベクターデータを受け取る文字列リスト
begin
  SL := TStringList.Create;
  try
    FData.SetBrackets(VECTOR_DATA_LEFT_BRACKET, VECTOR_DATA_RIGHT_BRACKET);
    FData.SaveToStrings(SL);
    FDataText := SL.Text;
  finally
    SL.Free;
  end;
end;

// RTTI保存用の文字列へ変換する。
procedure TVectorRendererImageItem.SerializeToStrings(Instance: TPersistent;
  Dest: TStrings);
begin
  SaveDataToText;
  inherited SerializeToStrings(Instance, Dest);
end;

{ TVectorRendererImageList }

// フォルダ内の個別iniをCharacters.iniへ反映する。
function TVectorRendererImageList.BuildResourceFromFolder(
  const AFolder: string): Integer;
var
  Files: TArray<string>;                   // フォルダ内のiniファイル一覧
  FileName: string;                        // 現在処理中のiniファイル
  Item: TVectorRendererImageItem;          // 更新対象の画像要素
  CurrentDateTime: TDateTime;              // 現在のファイル更新日時
begin
  Result := 0;
  Self.Filename := TPath.Combine(AFolder, CHARACTER_RESOURCE_FILE);
  LoadFromFile;
  if not TDirectory.Exists(AFolder) then
    Exit;
  Files := TDirectory.GetFiles(AFolder, '*.ini');
  for FileName in Files do
  begin
    if SameText(TPath.GetFileName(FileName), CHARACTER_RESOURCE_FILE) then
      Continue;
    CurrentDateTime := TFile.GetLastWriteTime(FileName);
    Item := FindByFileName(TPath.GetFileName(FileName));
    if Item = nil then
    begin
      Item := AddNew;
      Item.LoadVectorFile(FileName);
      Inc(Result);
      Continue;
    end;
    if Item.FileDateTime <> CurrentDateTime then
    begin
      Item.LoadVectorFile(FileName);
      Inc(Result);
    end;
  end;
  SaveToFile;
end;

// ファイル名に一致する画像要素を検索する。
function TVectorRendererImageList.FindByFileName(
  const AFileName: string): TVectorRendererImageItem;
var
  I: Integer;                              // 画像要素の走査位置
begin
  Result := nil;
  for I := 0 to Count - 1 do
  begin
    if SameText(Items[I].FileName, AFileName) then
      Exit(Items[I]);
  end;
end;

// 集約リソースファイルを読み込んで個別iniファイルを復元する。
function TVectorRendererImageList.RestoreFilesFromFile(const AFileName,
  AFolder: string): Integer;
begin
  Filename := AFileName;
  LoadFromFile;
  Result := RestoreFilesToFolder(AFolder);
end;

// 集約リソース文字列を読み込んで個別iniファイルを復元する。
function TVectorRendererImageList.RestoreFilesFromStrings(AStrings: TStringList;
  const AFolder: string): Integer;
begin
  Clear;
  inherited LoadFromStrings(AStrings, '[', ']');
  Result := RestoreFilesToFolder(AFolder);
end;

// 集約リソースから個別iniファイルを復元する。
function TVectorRendererImageList.RestoreFilesToFolder(
  const AFolder: string): Integer;
var
  I: Integer;                              // 画像要素の走査位置
begin
  Result := 0;
  for I := 0 to Count - 1 do
  begin
    if Images[I].SaveVectorFile(AFolder) then
      Inc(Result);
  end;
end;

// ファイル名に一致する画像要素を返す。
function TVectorRendererImageList.GetImages(
  Index: Integer): TVectorRendererImageItem;
begin
  Result := TVectorRendererImageItem(inherited Items[Index]);
end;

// ファイルから集約リソースを読み込む。
procedure TVectorRendererImageList.LoadFromFile;
var
  SL: TStringList;                         // 集約リソースの読み込み先
begin
  Clear;
  if (Filename = '') or not FileExists(Filename) then
    Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(Filename, TEncoding.UTF8);
    inherited LoadFromStrings(SL, '[', ']');
  finally
    SL.Free;
  end;
end;

// ファイルへ集約リソースを保存する。
procedure TVectorRendererImageList.SaveToFile;
var
  SL: TStringList;                         // 集約リソースの保存元
begin
  if Filename = '' then
    Exit;
  SL := TStringList.Create;
  try
    inherited SaveToStrings(SL, '[', ']');
    ForceDirectories(TPath.GetDirectoryName(Filename));
    SL.SaveToFile(Filename, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

end.
