unit SongDataCacheList;

interface

uses
  System.SysUtils, System.IOUtils,
  System.Classes,
  System.Generics.Collections,
  SongData;

type
  //============================================================
  // 1ファイル分のキャッシュアイテム
  //============================================================
  TSongDataCacheItem = class
  private
    FFileName      : string;     // キャッシュキー（フルパス）
    FLastWriteTime : TDateTime;  // ファイル最終更新日時
    FData          : TSongData;  // 楽曲データ本体
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;

    property FileName      : string    read FFileName;
    property LastWriteTime : TDateTime read FLastWriteTime write FLastWriteTime;
    property Data          : TSongData read FData;
  end;

  //============================================================
  // SongData キャッシュ管理リスト
  //============================================================
  TSongDataCacheList = class
  private
    FItems : TObjectList<TSongDataCacheItem>; // キャッシュ本体（所有）

    function GetItem(Index: Integer): TSongDataCacheItem;
    function IndexOfFileName(const FileName: string): Integer;
    function GetFileLastWriteTime(const FileName: string): TDateTime;
  public
    constructor Create;
    destructor Destroy; override;

    // ファイル名から取得または生成（更新日時が違えば再生成）
    function GetOrCreate(const FileName: string): TSongData;

    // 全キャッシュ破棄
    procedure Clear;

    property Items[Index: Integer]: TSongDataCacheItem read GetItem;
  end;

implementation

{============================================================
  TSongDataCacheItem
============================================================}

constructor TSongDataCacheItem.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FData := TSongData.Create;
end;

destructor TSongDataCacheItem.Destroy;
begin
  FData.Free;
  inherited;
end;

{============================================================
  TSongDataCacheList
============================================================}

constructor TSongDataCacheList.Create;
begin
  inherited Create;
  FItems := TObjectList<TSongDataCacheItem>.Create(True); // 所有あり
end;

destructor TSongDataCacheList.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TSongDataCacheList.Clear;
begin
  FItems.Clear;
end;

function TSongDataCacheList.GetItem(Index: Integer): TSongDataCacheItem;
begin
  Result := FItems[Index];
end;

function TSongDataCacheList.IndexOfFileName(const FileName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FItems.Count - 1 do
  begin
    if SameText(FItems[I].FileName, FileName) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

function TSongDataCacheList.GetFileLastWriteTime(const FileName: string): TDateTime;
begin
  if not TFile.Exists(FileName) then
    Exit(0);

  Result := TFile.GetLastWriteTime(FileName);
end;

function TSongDataCacheList.GetOrCreate(const FileName: string): TSongData;
var
  Index      : Integer;
  Item       : TSongDataCacheItem;
  FileTime   : TDateTime;
begin
  FileTime := GetFileLastWriteTime(FileName);

  Index := IndexOfFileName(FileName);
  if Index <> -1 then
  begin
    Item := FItems[Index];

    // 更新日時が同じ → キャッシュ利用
    if Item.LastWriteTime = FileTime then
    begin
      Result := Item.Data;
      Exit;
    end;

    // 更新されている → 再解析
    Item.Data.LoadFromFile(FileName);
    Item.LastWriteTime := FileTime;

    Result := Item.Data;
    Exit;
  end;

  // 新規作成
  Item := TSongDataCacheItem.Create(FileName);
  Item.LastWriteTime := FileTime;
  Item.Data.LoadFromFile(FileName);
  FItems.Add(Item);

  Result := Item.Data;
end;

end.

