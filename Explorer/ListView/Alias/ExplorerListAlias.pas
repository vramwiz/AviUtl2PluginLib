unit ExplorerListAlias;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  ListViewEdit,ListViewEx,Vcl.Menus,System.Generics.Collections,
  Vcl.StdCtrls, Vcl.ExtCtrls,RTTIPersistent,ExplorerFileList,ExplorerListView,
  ListViewRTTI,DragAgent;

procedure ExplorerConfigAliasShow(lv : TListViewRTTI;Item : TExplorerFileItem);


// 標準ファイルの情報　このクラスは拡張しない
type
  TExplorerFileAliasItem = class(TExplorerFileItem)
  private
    FVolume    : Double;               // 音量
    FPan       : Double;               // 位置
    FPlaySpeed : Double;               // 再生速度
    FPlayLoop  : Integer;              // ループ再生
    FTrack     : Integer;              // トラック
    FFadeMode  : Integer;              // 0:なし 1:フェードイン 2:フェードアウト 3:フェードインアウト
    FFadeIn    : Double;               // フェードイン時間（秒）
    FFadeOut   : Double;               // フェードアウト時間（秒）
  protected
  public
    constructor Create;
  published
    property Volume    : Double  read FVolume       write FVolume;
    property Pan       : Double  read FPan          write FPan;
    property PlaySpeed : Double  read FPlaySpeed    write FPlaySpeed;
    property PlayLoop  : Integer read FPlayLoop     write FPlayLoop;
    property Track     : Integer read FTrack        write FTrack;
    // ここから先はオリジナル要素
    property FadeMode  : Integer read FFadeMode     write FFadeMode;
    property FadeIn    : Double  read FFadeIn       write FFadeIn;
    property FadeOut   : Double   read FFadeOut     write FFadeOut;
  end;

// ファイルリスト
type
  TExplorerFileAliasList = class(TExplorerFileList<TExplorerFileAliasItem>)
	private
    function GetFiles(Index: Integer): TExplorerFileAliasItem;
		{ Private 宣言 }
  protected
    function IsVisibleExtension(const FileName : string) : Boolean;override;
	public
		{ Public 宣言 }
    constructor Create;override;
    destructor Destroy; override;

    property Files[Index : Integer] : TExplorerFileAliasItem read GetFiles;default;
	end;
                                                           // ExplorerListView2
  //TExplorerListViewNormal<T: TExplorerFile2Item, constructor> = class(TListViewThumbnail)
  TExplorerListViewAlias = class(TExplorerListView<TExplorerFileAliasItem>)
  private
    FDrag        : TDragShellFile;
    // エリアスから表示に使う名称を取得
    function AliasToName(ts : TStringList) : string;
    function AliasFileToName(const FileName: string): string;
    procedure AliasToSave(FileName,Alias : string);
    procedure OnDrag(Sender: TObject;FileNames : TStringList);
    function GetFiles(Index: Integer): TExplorerFileAliasItem;
  protected
    procedure DoWatchAdd(const FileNames: TStringList); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ItemPaste();override;

    property Files[Index : Integer] : TExplorerFileAliasItem read GetFiles;default;
  end;


implementation

uses  ListViewEditPluginLib,ListViewEditPluginDialog,AviUtl2AliasSelected,SectionFileManager;


{ TExplorerFileAliasList }

constructor TExplorerFileAliasList.Create;
begin
  inherited;
  FExtensions.Add('.object');
end;

destructor TExplorerFileAliasList.Destroy;
begin

  inherited;
end;

function TExplorerFileAliasList.GetFiles(Index: Integer): TExplorerFileAliasItem;
begin
  Result := inherited Items[Index];
end;

function TExplorerFileAliasList.IsVisibleExtension(
  const FileName: string): Boolean;
begin
  Result := True;
end;


{ TExplorerFileAliasItem }

constructor TExplorerFileAliasItem.Create;
begin
  FVolume    := 100.00;
  FPlaySpeed := 100.00;
  FFadeIn    := 2.00;
  FFadeout   := 2.00;
end;


procedure ExplorerConfigAliasShow(lv : TListViewRTTI;Item : TExplorerFileItem);
begin
  if not (Item is TExplorerFileItem) then Exit;

  lv.RTTINames['FileName'].EditType := ListViewEditPluginHideId;
  lv.RTTINames['Name'].EditType := ListViewEditPluginHideId;

  lv.RTTINames['Text'].AddCaption('テキスト','オブジェクトのテキスト設定',clSkyBlue);


  lv.LoadFromObject(Item);
  lv.FixedWidth := 100;

end;

{ TExplorerListViewAlias }

constructor TExplorerListViewAlias.Create(AOwner: TComponent);
begin
  inherited;
  FFiles := TExplorerFileAliasList.Create;

  SetThumbnailSize(vsReport,24,24,True);

  FDrag := TDragShellFile.Create(Self);
  FDrag.Attach(Self);
  FDrag.OnDragRequest := OnDrag;

end;

destructor TExplorerListViewAlias.Destroy;
begin
  FDrag.Free;
  FFiles.Free;
  inherited;
end;

function TExplorerListViewAlias.GetFiles(Index: Integer): TExplorerFileAliasItem;
begin
  Result := TExplorerFileAliasItem(FFiles[Index]);
end;

procedure TExplorerListViewAlias.ItemPaste;
var
  Alias : string;
  ts : TStringList;
  FileName,Name : string;
begin
  ts := TStringList.Create;
  try
    AviUtl2GetSelectedAlias(ts);
    Name := AliasToName(ts);
    Alias := ts.Text;
  finally
    ts.Free;
  end;

  if Alias = '' then Exit;

  FileName := FFolder;
  FileName := FileName + 'Alias_' + FormatDateTime('yyyymmddhhnnsszzz', Now) + '.object';
  if Name = '' then ExtractFileName(FileName);

  AliasToSave(FileName,Alias);
end;


function TExplorerListViewAlias.AliasToName(ts: TStringList): string;
var
  i, p : Integer;
  s, Name : string;
  SecMgr : TSectionFileManager;
  t : TStringList;
begin
  Result := '';
  s := '';

  SecMgr := TSectionFileManager.Create;
  try
    SecMgr.LoadFromStrings(ts);

    i := 0;
    while i < 999 do
    begin
      t := SecMgr.GetSection(IntToStr(i) + '.0');
      if t = nil then Break;

      Name := t.Values['effect.name'];

      p := Pos('@', Name);
      if p > 0 then Name := Copy(Name, 1, p - 1);

      if Name <> '' then
      begin
        if s <> '' then s := s + '/';
        s := s + Name;
      end;

      Inc(i);
    end;

    Result := s;
  finally
    SecMgr.Free;
  end;
end;

function TExplorerListViewAlias.AliasFileToName(const FileName: string): string;
var
  SL: TStringList;
begin
  Result := '';
  if not FileExists(FileName) then Exit;

  SL := TStringList.Create;
  try
    try
      SL.LoadFromFile(FileName, TEncoding.UTF8);
    except
      SL.LoadFromFile(FileName, TEncoding.Default);
    end;
    Result := AliasToName(SL);
  finally
    SL.Free;
  end;
end;

procedure TExplorerListViewAlias.AliasToSave(FileName,Alias: string);
var
  SL   : TStringList;
  Utf8 : TEncoding;
begin
  // ★ BOMなし UTF-8 を明示生成
  Utf8 := TUTF8Encoding.Create(False);  // emitBOM = False
  try
    SL := TStringList.Create;
    try
      SL.Text := Alias;
      SL.SaveToFile(FileName, Utf8);    // ← ここが重要
    finally
      SL.Free;
    end;
  finally
    Utf8.Free;
  end;

end;

procedure TExplorerListViewAlias.DoWatchAdd(const FileNames: TStringList);
var
  I: Integer;
  FileName: string;
  Name: string;
  Item: TExplorerFileAliasItem;
begin
  if FFiles = nil then Exit;
  if FileNames = nil then Exit;

  for I := 0 to FileNames.Count - 1 do
  begin
    FileName := FileNames[I];
    if not SameText(ExtractFileExt(FileName), '.object') then Continue;
    if not FileExists(FileName) then Continue;
    if FFiles.IndexOfFileName(FileName) <> -1 then Continue;

    Name := AliasFileToName(FileName);
    if Name = '' then
      Name := ChangeFileExt(ExtractFileName(FileName), '');

    Item := FFiles.InsertNew(0);
    Item.FileName := FileName;
    Item.Name := Name;
    ShowItem(Name, 0);
  end;

  FFiles.SaveToFile();
end;



procedure TExplorerListViewAlias.OnDrag(Sender: TObject; FileNames: TStringList);
var
  i : Integer;
  Item : TExplorerFileAliasItem;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  Item := GetFiles(i);
  if Item = nil  then Exit;

  FileNames.Clear;
  FileNames.Add(Item.FileName);
end;

end.
