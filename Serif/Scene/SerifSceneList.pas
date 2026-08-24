unit SerifSceneList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,RTTIPersistentIni,
  SerifSceneMsgList;


//--------------------------------------------------------------------------//
//  セリフ情報を管理するクラス                                              //
//--------------------------------------------------------------------------//
type
  TSerifSceneItem = class(TRTTIPersistentIni)
  private
    { Private 宣言 }
    FVersion : Integer;                  // 0: MsgsStrで保存 1:二重セクションで保存
    FName: string;
    FMsgs: TSerifSceneMsgList;
    function GetMsgsStr: string;
    procedure SetMsgsStr(const Value: string);

  public
    { Public 宣言 }
    constructor Create();
    destructor Destroy;override;

    property Msgs : TSerifSceneMsgList read FMsgs;
 published
    property Name :string read FName write FName;
    property MsgsStr : string read GetMsgsStr write SetMsgsStr;
  end;

  TSerifSceneList = class(TRTTIPersistentIniList<TSerifSceneItem>)
  private
    FVersion : Integer;                  // 0: MsgsStrで保存 1:二重セクションで保存
    function GetScenes(Index: Integer): TSerifSceneItem;
    // UIDがセットされていないときセットする
    procedure SetUID;
  public
    // ファイル読み込み
    procedure LoadFromFile;override;
    // ファイル保存
    procedure SaveToFile;override;
    property Scenes[Index : Integer] : TSerifSceneItem read GetScenes;
  end;


implementation

uses SectionFileManager;

{ TSerifSceneList }

function TSerifSceneList.GetScenes(Index: Integer): TSerifSceneItem;
begin
  Result := TSerifSceneItem(inherited Items[Index]);
end;

procedure TSerifSceneList.LoadFromFile;
var
  tss,ts : TSectionFileManager;
  t : TStringList;
  i,j : Integer;
  Scene : TSerifSceneItem;
  Msg : TSerifSceneMsgItem;
begin
  Clear;
  ts := TSectionFileManager.Create;
  tss := TSectionFileManager.Create;
  try
    ts.SetBrackets('{','}');
    if not FileExists(Filename) then Exit;

    tss.LoadFromFile(Filename);
    t := tss.GetSection('Root');
    if t= nil then begin                       // [Root]が存在しない場合旧形式
      FVersion := 0;
      inherited;                               // 旧形式として読み込む
      Exit;
    end;
    FVersion := 1;

    j := 0;                                    // シーン数ループの初期値
    while j <9999 do begin                     // 暫定最大値ループ
      t := tss.GetSection(IntToStr(j));        // [n] を検索
      if t = nil then break;                   // 無ければ終了
      ts.LoadFromStrings(t);                  // [n]セクションを[nn}形式で解析
      Scene := AddNew();                       // シーン生成
      Scene.FVersion := FVersion;

      t := ts.GetSection('Root');              // シーンのデータセクションを取得
      if t <> nil then begin                   // 存在する場合
        Scene.DeserializeFromStrings(Scene,t); // シーンのデータとして読み込み
      end;

      i := 0;                                  // セリフ数ループの初期値
      while i < 9999 do begin                  // 暫定最大数ループ
        t := ts.GetSection(IntToStr(i));       // {n}セクションを取得
        if t = nil then break;                 // 存在しない場合ループ脱出
        Msg := Scene.Msgs.AddNew();            // セリフ生成

        Msg.DeserializeFromStrings(Msg,t);     // セリフデータとして読み込み

        Inc(i);
      end;
      Inc(j);
    end;
  finally
    tss.Free;
    ts.Free;
  end;
  SetUID;
end;

procedure TSerifSceneList.SaveToFile;
var
  tss,ts : TSectionFileManager;
  t : TStringList;
  i,j : Integer;
  Scene : TSerifSceneItem;
  Msg : TSerifSceneMsgItem;
begin
  t := TStringList.Create;
  ts := TSectionFileManager.Create;
  tss := TSectionFileManager.Create;
  try
    ts.SetBrackets('{','}');
    tss.AddSection('Root',t);                  // 新しい方式である事を示す[Root]セクション追加
    for j := 0 to Count-1 do begin             // シーン数ループ
      Scene := Scenes[j];                      // シーン参照
      t.Clear;
      ts.Clear;

      Scene.SerializeToStrings(Scene,t);       // シーンデータを文字列リストに保存
      ts.AddSection('Root',t);                 // シーンのデータをセクションに書き込み

      for i := 0 to Scene.Msgs.Count-1 do begin             // セリフ数ループ
        Msg := Scene.Msgs[i];                  // メッセージ参照
        t.Clear;
        Msg.SerializeToStrings(Msg,t);         // セリフを文字列リストに書き込み
        ts.AddSection(IntToStr(i),t);          // セリフを{nn}セクションに追加
      end;
      t.Clear;
      ts.SaveToStrings(t);                     // {nn}セクション全て文字列リストに
      tss.AddSection(IntToStr(j),t);           // [n]セクションとして追加
    end;
    tss.SaveToFile(Filename);                  //
  finally
    tss.Free;
    ts.Free;
    t.Free;
  end;
end;

procedure TSerifSceneList.SetUID;
var
  i,j : Integer;
  f : Boolean;
begin
  f := False;
  for j := 0 to Count-1 do begin
    for i := 0 to Scenes[j].Msgs.Count-1 do begin
      if Scenes[j].Msgs[i].UID = '' then begin
        Scenes[j].Msgs[i].SetUID;
        f := True;
      end;
    end;
  end;

  if f then SaveToFile;
end;

{ TSerifSceneItem }

constructor TSerifSceneItem.Create;
begin
  FMsgs := TSerifSceneMsgList.Create;
end;

destructor TSerifSceneItem.Destroy;
begin
  FMsgs.Free;
  inherited;
end;

function TSerifSceneItem.GetMsgsStr: string;
begin
  Result := '';
  if FVersion = 0 then Result := FMsgs.SerializeToText();
end;

procedure TSerifSceneItem.SetMsgsStr(const Value: string);
begin
  if FVersion = 0 then FMsgs.DeserializeFromText(Value);
end;

end.
