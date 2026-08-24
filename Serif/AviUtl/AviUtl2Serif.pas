unit AviUtl2Serif;

interface

uses  System.SysUtils,System.Classes,SerifCharaList,SerifSceneMsgList,SerifConfig,Math,
      AviUtl2PluginTypes;

type
  // F2で読み込んだセリフをEnter確定時まで識別するための取得時情報。
  TSerifAviUtl2Selection = record
    ObjectHandle: TObjectHandle; // AviUtl2で取得時にフォーカスされていたオブジェクト。
    UID: string;                 // 内部セリフデータとの対応に使う永続識別子。
    Layer: Integer;              // 取得時のセリフレイヤー。未取得時は-1。
    FrameStart: Integer;         // 取得時の開始フレーム。未取得時は-1。
    FrameEnd: Integer;           // 取得時の終了フレーム。未取得時は-1。
  end;

// セリフをAviUtl2上の生成
function AviUtl2SerifMsgsSend(const ProjectFolder : string;    // プロジェクトフォルダ
                                   Msgs: TSerifSceneMsgListEx;  // セリフリスト
                                   Charas : TSerifCharaList;    // 配役リスト
                                   Config : TSerifConfigItem;   // 設定データ
                                   Send : Boolean               // True:送信 False;D&D用
                            ) : string;                         // D&Dで返すファイル名

// 通常送信を実行し、AviUtl2にオブジェクトを作成できたか返す。
function AviUtl2SerifMsgsSendNow(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem): Boolean;

// VOICEVOX入力からの連続送信。AviUtl2の終端でカーソルが止まる場合だけ、
// 直前送信時に計算した次開始フレームを引き継ぐ。
function AviUtl2SerifMsgsSendContinuous(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem): Boolean;
// 入力画面から離れた時や再編集開始時に、連続送信位置を破棄する。
procedure AviUtl2SerifResetContinuousSend;

// セリフが同期可能か判定
function AviUtl2SerifIsSync(Msg: TSerifSceneMsgItem) : Boolean;

// セリフを書き換える
function AviUtl2SerifSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
// セリフを取得
function AviUtl2SerifGetValue(const Layer,Frame : Integer) : string;
function AviUtl2SerifGetUID(const Layer,Frame : Integer) : string;
// 選択中のセリフ入力オブジェクトから本文、キャラ、感情を取得する。
// 複数選択時はフォーカス中のオブジェクトを優先する。
function AviUtl2SerifGetSelected(out SerifText, Character,
  Emotion: string): Boolean; overload;
// SelectionにはEnter確定時に同じ対象か確認するための取得時情報を返す。
function AviUtl2SerifGetSelected(out SerifText, Character,
  Emotion: string; out Selection: TSerifAviUtl2Selection): Boolean; overload;
// F2取得時と同じオブジェクトが現在も選択中ならTrueを返し、現在位置を出力する。
function AviUtl2SerifResolveSelected(const Selection: TSerifAviUtl2Selection;
  out Layer, FrameStart, FrameEnd: Integer): Boolean;
// タイムライン上の尺とUIDを維持してセリフ内容と対応WAV参照を更新し、実際のWAVレイヤーを返す。
function AviUtl2SerifUpdateSelected(const Selection: TSerifAviUtl2Selection;
  const PreferredWaveLayer: Integer; const OldWaveFileName,
  NewWaveFileName: string; const NewWaveLength: Double;
  const SerifText, Character, Emotion, Direction, AIUEO,
  LabText: string; out ActualWaveLayer: Integer): Boolean;
// セリフを削除
function AviUtl2SerifDelete(const Layer,Frame : Integer) : Boolean;
// セリフを移動
function AviUtl2SerifMove(const LayerTo,FrameTo,LayerFrom,FrameFrom : Integer) : Boolean;

// 演出を書き換える
function AviUtl2SerifDirectionSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
// 感情を書き換える
function AviUtl2SerifEmotionSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
// 母音を書き換える
function AviUtl2SerifAiueoSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;

// セリフ表示オブジェクトをD&D
function AviUtl2SerifMsgViewDandD(const Layer : Integer): string;
// 新しいセリフ表示フィルターだけをD&Dする。
function AviUtl2SerifDrawDandD: string; overload;
// 登録済みの完全エイリアスをそのままD&Dファイルにする。
function AviUtl2SerifDrawDandD(const AliasText: string): string; overload;
// 選択中の独立した新セリフ表示フィルターを完全エイリアスとして取得する。
function AviUtl2SerifDrawGetSelectedAlias(out AliasText,
  ErrorMessage: string): Boolean;

implementation

uses System.StrUtils,AliasManager,AviUtl2PluginCore,AviUtl2TimeConvert,AviUtl2PluginCursorControl,
     AviUtl2PluginObjectCreate,AliasManagerNormalAudio,AliasManagerScriptSerif,AviUtl2PluginObjectFind,
     AviUtl2PluginObjectValue,AviUtl2PluginObjectInfo,AviUtl2PluginScene,AviUtl2PluginObjectControl,
     AliasManagerInputBase,AliasManagerFilterSerifDraw,AliasManagerStringList,AviUtl2TextUtils,
     SerifVoicevoxDebugLog,AviUtl2ObjectAliasValue,AviUtl2PluginObjectAlias,
     AppFolderUtils;

const
  EFECT_NAME = 'セリフ入力@Syncroh2_Script';
  DIRECTION_NONE = 'なし';

var
  GCursolFrame : Integer;
  GBaseLayer   : Integer;
  GtSceneId    : Integer;
  GSerifDrawDragFileName: string;

type
  TSerifContinuousSendState = record
    Valid: Boolean;
    ProjectFolder: string;
    SceneId: Integer;
    CursorFrame: Integer;
    CursorLayer: Integer;
    NextFrame: Integer;
    LastUID: string;
    LastLayer: Integer;
    LastFrameStart: Integer;
    LastFrameEnd: Integer;
  end;

var
  GContinuousSend: TSerifContinuousSendState;

procedure AviUtl2SerifResetContinuousSend;
begin
  Finalize(GContinuousSend);
  FillChar(GContinuousSend, SizeOf(GContinuousSend), 0);
  GContinuousSend.CursorFrame := -1;
  GContinuousSend.CursorLayer := -1;
  GContinuousSend.NextFrame := -1;
  GContinuousSend.LastLayer := -1;
  GContinuousSend.LastFrameStart := -1;
  GContinuousSend.LastFrameEnd := -1;
end;

function ContinuousSendMatches(const ProjectFolder: string;
  const SceneId, CursorFrame, CursorLayer: Integer): Boolean;
var
  FrameEnd: Integer;
  FrameStart: Integer;
  Layer: Integer;
  Obj: TObjectHandle;
begin
  Result := False;
  if not GContinuousSend.Valid then Exit;
  if not SameText(ExcludeTrailingPathDelimiter(ProjectFolder),
    ExcludeTrailingPathDelimiter(GContinuousSend.ProjectFolder)) then Exit;
  if SceneId <> GContinuousSend.SceneId then Exit;
  if CursorFrame <> GContinuousSend.CursorFrame then Exit;
  if CursorLayer <> GContinuousSend.CursorLayer then Exit;

  // カーソルを動かさない編集・削除も検出するため、直前セリフのUIDと尺を確認する。
  Obj := AviUtl2FindObject(GContinuousSend.LastLayer,
    GContinuousSend.LastFrameStart);
  if Obj = nil then Exit;
  if not AviUtl2GetObjectLayerFrame(Obj, Layer, FrameStart, FrameEnd) then Exit;
  if (Layer <> GContinuousSend.LastLayer) or
    (FrameStart <> GContinuousSend.LastFrameStart) or
    (FrameEnd <> GContinuousSend.LastFrameEnd) then Exit;
  Result := SameText(AviUtl2SerifGetUID(Layer, FrameStart),
    GContinuousSend.LastUID);
end;

procedure SetBaseLayer(const Layer : Integer);
begin
  if GBaseLayer = -1 then begin
    GBaseLayer  := Layer;
  end
  else if GBaseLayer > Layer then begin
    GBaseLayer  := Layer;
  end;

end;

function NormalizeDirectionValue(const Value: string): Integer;
begin
  Result := -1;
  //if Trim(Result) = '' then
  //  Result := DIRECTION_NONE;
end;

//-------------------------------------------------------------
// Audio オブジェクト生成
//-------------------------------------------------------------
procedure CreateAudioObject( const ProjectFolder : string;Msg   : TSerifSceneMsgItem;Chara : TSerifCharaItem;  StartFrame, LenFrame,Group : Integer);
var
  ItemAudio : TAliasManagerNormalAudio;
begin
  //GAliasManager.Clear;

  ItemAudio := GAliasManager.AddAudio(); //TAliasManagerNormalAudio(GAliasManager.Add('Audio'));
  ItemAudio.Filename    := ProjectFolder + Msg.FileNameWave;
  ItemAudio.Layer       := Chara.LayerWave;
  ItemAudio.StartPos    := 0;
  ItemAudio.EndPos      := Msg.WaveLength;
  ItemAudio.FrameStart  := StartFrame;
  ItemAudio.FrameLength := LenFrame;
  ItemAudio.Group       := Group;
  ItemAudio.Volume      := Chara.Volume;
  ItemAudio.Pan         := Chara.Pan;

  SetBaseLayer(ItemAudio.Layer);

  //AviUtl2Create(ItemAudio, GAliasManager.SaveToText());
  //GAliasManager.SaveToAlias();
end;

//-------------------------------------------------------------
// SerifIn オブジェクト生成
//-------------------------------------------------------------
procedure CreateSerifObject(Msg   : TSerifSceneMsgItem;  Chara : TSerifCharaItem;  StartFrame, LenFrame,NextFrame,NextSpace,Group : Integer;Send : Boolean;const LabText : string);
var
  ItemSerif : TAliasManagerScriptSerifInput;
begin
  //GAliasManager.Clear;

  ItemSerif := GAliasManager.AddSerifIn(); //TAliasManagerScriptSerifInput(GAliasManager.Add('SerifIn'));
  ItemSerif.Character   := Chara.Name;       // キャラの名称を登録
  ItemSerif.Emotion     := Msg.Emotion;      // セリフに込めた感情を登録
  ItemSerif.Direction   := NormalizeDirectionValue(Msg.Direction); // セリフに込める演出を登録
  ItemSerif.Serif       := Msg.Voice;        // セリフのテキストを登録
  ItemSerif.Layer       := Chara.LayerSerif; // セリフのレイヤー位置を登録
  ItemSerif.FrameStart  := StartFrame;       // セリフの開始位置を登録
  ItemSerif.FrameLength := LenFrame;         // セリフの長さを登録
  ItemSerif.Group       := Group;            // セリフのグループを登録
  ItemSerif.LAB         := LabText;       // セリフのLABを登録
  ItemSerif.UID         := Msg.UID;          // セリフを識別するUIDを登録


  if not Send then Exit;                     // D&Dのときはフレーム位置をセリフに格納しない
  
  SetBaseLayer(ItemSerif.Layer);

  Msg.FrameStart  := ItemSerif.FrameStart;   // 開始フレーム位置をセリフに登録
  Msg.FrameEnd    := ItemSerif.FrameEnd;     // 終了フレーム位置をセリフに登録
  Msg.FrameNext   := NextFrame;              // 次のセリフ位置をセリフに登録
  Msg.FrameSpaceE := NextSpace;              // 次のセリフまでの空白をセリフに登録
  Msg.SerifLayer  := Chara.LayerSerif;       // セリフのレイヤー位置を登録
  Msg.WaveLayer   := Chara.LayerWave;        // セリフ音声のレイヤー位置を登録
  Msg.SceneId     := GtSceneId;              // 新番号をセリフに登録
  Msg.IsOutput    := True;                   // 同期送信したことを示すフラグセット

  //AviUtl2Create(ItemSerif, GAliasManager.SaveToText());
end;

//-------------------------------------------------------------
// メイン：セリフ送信 　複数
//-------------------------------------------------------------
function AviUtl2SerifMsgsSendCore(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem; Send, ContinuousSend: Boolean;
  out SendSucceeded: Boolean): string;
var
  j, i, StartFrame, LenFrame, AddStart,NextFrame, AddEnd: Integer;
  CreateFrame: Integer;
  CursorFrame: Integer;
  CursorLayer: Integer;
  KeepFirstFrameAtZero: Boolean;
  lensec, Convert : Double;
  CreatedObject: TObjectHandle;
  LastMsg: TSerifSceneMsgItem;
  Msg   : TSerifSceneMsgItem;
  Chara : TSerifCharaItem;
  LabText : string;
begin
  Result := '';
  SendSucceeded := not Send;
  // 送信指示でプラグインからの実行でなければ処理しない
  //if (Send) and  (not GAviUtl2Plugin) then Exit;

  GBaseLayer := -1;

  { 秒→フレーム変換係数 }
  Convert := AviUtl2Convert();
  GtSceneId := AviUtl2SceneGetID;

  CursorFrame := AviUtl2CursorGetFrame();
  CursorLayer := AviUtl2CursorGetLayer();
  KeepFirstFrameAtZero := False;
  GCursolFrame := CursorFrame;
  StartFrame := CursorFrame;
  if Send and ContinuousSend and ContinuousSendMatches(ProjectFolder,
    GtSceneId, CursorFrame, CursorLayer) then
  begin
    StartFrame := GContinuousSend.NextFrame;
    VoicevoxDebugLog(Format(
      'Serif continuous send accepted cursor=%d/%d next=%d uid=%s',
      [CursorFrame, CursorLayer, StartFrame, GContinuousSend.LastUID]));
  end
  else if Send then
  begin
    if ContinuousSend then
    begin
      if GContinuousSend.Valid then
        VoicevoxDebugLog('Serif continuous send discarded: timeline state changed');
      // 保持位置を再利用できなくても、終端へ制限されたカーソル上へ
      // 直前のセリフを重ねない。先頭フレームだけは0を維持する。
      if CursorFrame > 0 then StartFrame := CursorFrame + 1
      else KeepFirstFrameAtZero := True;
      VoicevoxDebugLog(Format(
        'Serif continuous send fallback cursor=%d/%d start=%d',
        [CursorFrame, CursorLayer, StartFrame]));
    end;
    AviUtl2SerifResetContinuousSend;
  end;
  CreateFrame := StartFrame;

  // Config の秒 → フレーム換算
  AddStart := Ceil(Config.SecStart / Convert);
  AddEnd   := Ceil(Config.SecEnd   / Convert);

  GAliasManager.Clear;
  LastMsg := nil;

  // 配置が最後まで成功した場合だけ、同期済みとして確定する。
  if Send then
    for j := 0 to Msgs.Count - 1 do
      Msgs[j].IsOutput := False;

  //  メインループ
  for j := 0 to Msgs.Count - 1 do begin
    Msg := Msgs[j];

    i := Charas.indexOfKeyword(Msg.Chara);
    if i = -1 then Continue;

    Chara := Charas[i];
    lensec := Msg.WaveLength;
    //Msg.SceneId := GtSceneId;

    // 秒 → フレーム
    LenFrame := Ceil(lensec / Convert);

    // 開始位置に AddStart を反映
    if KeepFirstFrameAtZero then KeepFirstFrameAtZero := False
    else StartFrame := StartFrame + AddStart;
    // 次の開始位置へ（終端ズレ対策で +1 も入れ
    NextFrame := StartFrame + LenFrame + AddEnd + 1;

    // Audio オブジェクト
    CreateAudioObject(ProjectFolder, Msg, Chara, StartFrame, LenFrame,1);

    // Serif オブジェクト
    if Assigned(Config) and Config.SendLab then
      LabText := AvrUtl2_StrToAviutl(Msg.LabStr)
    else
      LabText := '';
    CreateSerifObject(Msg, Chara, StartFrame, LenFrame,NextFrame,AddEnd,1,Send,LabText);
    LastMsg := Msg;

    // 次の開始位置へオフセットを移動
    StartFrame := NextFrame;
  end;

  if Send then begin
    // AviUtl2上にオブジェクト生成
    CreatedObject := AviUtl2Creates(CreateFrame,CreateFrame,GBaseLayer,
      GAliasManager.SaveToText());
    SendSucceeded := CreatedObject <> nil;
    if not SendSucceeded then
      for j := 0 to Msgs.Count - 1 do
        Msgs[j].IsOutput := False;
    // 最終カーソル位置を移動
    if SendSucceeded then
      AviUtl2CursorMoveFrame(StartFrame);

    AviUtl2SerifResetContinuousSend;
    if SendSucceeded and ContinuousSend and Assigned(LastMsg) then
    begin
      GContinuousSend.Valid := True;
      GContinuousSend.ProjectFolder := ProjectFolder;
      GContinuousSend.SceneId := GtSceneId;
      // 移動要求後の実位置を保存する。タイムライン終端ではFrameNextより手前になる。
      GContinuousSend.CursorFrame := AviUtl2CursorGetFrame();
      GContinuousSend.CursorLayer := AviUtl2CursorGetLayer();
      GContinuousSend.NextFrame := StartFrame;
      GContinuousSend.LastUID := LastMsg.UID;
      GContinuousSend.LastLayer := LastMsg.SerifLayer;
      GContinuousSend.LastFrameStart := LastMsg.FrameStart;
      GContinuousSend.LastFrameEnd := LastMsg.FrameEnd;
      VoicevoxDebugLog(Format(
        'Serif continuous send stored cursor=%d/%d next=%d uid=%s frame=%d-%d',
        [GContinuousSend.CursorFrame, GContinuousSend.CursorLayer,
         GContinuousSend.NextFrame, GContinuousSend.LastUID,
         GContinuousSend.LastFrameStart, GContinuousSend.LastFrameEnd]));
    end;
  end
  else begin
    // エリアスファイル化
    GAliasManager.SaveToAlias();
    // ファイル化したファイル名を返す
    Result := GAliasManager.FileName;
  end;
end;

function AviUtl2SerifMsgsSend(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem; Send: Boolean): string;
var
  SendSucceeded: Boolean;
begin
  Result := AviUtl2SerifMsgsSendCore(ProjectFolder, Msgs, Charas, Config,
    Send, False, SendSucceeded);
end;

function AviUtl2SerifMsgsSendNow(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem): Boolean;
var
  Unused: string;
begin
  Unused := AviUtl2SerifMsgsSendCore(ProjectFolder, Msgs, Charas, Config,
    True, False, Result);
end;

function AviUtl2SerifMsgsSendContinuous(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem): Boolean;
var
  Unused: string;
begin
  Unused := AviUtl2SerifMsgsSendCore(ProjectFolder, Msgs, Charas, Config,
    True, True, Result);
end;


function CreateSerifDrawDragFileName: string;
var
  Guid: TGUID;
  UniqueName: string;
begin
  // AviUtl2が前回と同じファイルを同一オブジェクトとして扱わないよう、
  // D&D要求ごとに異なる実在ファイルを渡す。
  if GSerifDrawDragFileName <> '' then
    DeleteFile(GSerifDrawDragFileName);

  CreateGUID(Guid);
  UniqueName := GUIDToString(Guid);
  UniqueName := StringReplace(UniqueName, '{', '', [rfReplaceAll]);
  UniqueName := StringReplace(UniqueName, '}', '', [rfReplaceAll]);
  UniqueName := StringReplace(UniqueName, '-', '', [rfReplaceAll]);
  Result := GetAppFolder('Temp') + 'SerifDraw_' + UniqueName + '.object';
  GSerifDrawDragFileName := Result;
end;

function AviUtl2SerifDrawDandD: string;
var
  AliasStrings: TAliasStringList;
  SerifDraw: TAliasManagerFilterSerifDraw;
  FileName: string;
begin
  Result := '';
  AliasStrings := TAliasStringList.Create;
  SerifDraw := TAliasManagerFilterSerifDraw.Create;
  try
    SerifDraw.SaveAsFilterAlias(AliasStrings);
    FileName := CreateSerifDrawDragFileName;
    AliasStrings.SaveToFile(FileName);
    Result := FileName;
  finally
    SerifDraw.Free;
    AliasStrings.Free;
  end;
end;

function AviUtl2SerifDrawDandD(const AliasText: string): string;
var
  Lines: TStringList;
  Encoding: TEncoding;
  FileName: string;
begin
  Result := '';
  if Trim(AliasText) = '' then Exit;

  Lines := TStringList.Create;
  Encoding := TUTF8Encoding.Create(False);
  try
    Lines.Text := AliasText;
    FileName := CreateSerifDrawDragFileName;
    Lines.SaveToFile(FileName, Encoding);
    Result := FileName;
  finally
    Encoding.Free;
    Lines.Free;
  end;
end;

function AviUtl2SerifDrawGetSelectedAlias(out AliasText,
  ErrorMessage: string): Boolean;
var
  Obj: TObjectHandle;
  SelectedCount: Integer;
  AliasValue: TAviUtl2ObjectAliasValue;
  Lines: TStringList;
  I: Integer;
  Layer: Integer;
  FrameStart: Integer;
  FrameEnd: Integer;
  HasSerifDraw: Boolean;
  HasLayer: Boolean;
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
    if not AliasValue.LoadFromAviUtl2Object(Obj) then
    begin
      ErrorMessage := '選択中オブジェクトのエイリアスを取得できませんでした。';
      Exit;
    end;

    if (AliasValue.Filters.Count = 0) or
       not SameText(AliasValue.Filters[0].Filter, 'フィルタオブジェクト') then
    begin
      ErrorMessage := '選択中オブジェクトは独立したフィルタオブジェクトではありません。';
      Exit;
    end;

    HasSerifDraw := False;
    for I := 1 to AliasValue.Filters.Count - 1 do
      if SameText(AliasValue.Filters[I].Filter, '新旧朗2 セリフ表示') then
      begin
        HasSerifDraw := True;
        Break;
      end;

    if not HasSerifDraw then
    begin
      ErrorMessage := '選択中オブジェクトに「新旧朗2 セリフ表示」がありません。';
      Exit;
    end;

    Lines.Text := AliasValue.AliasText;
    if Lines.Count = 0 then
    begin
      ErrorMessage := '選択中オブジェクトのエイリアスが空です。';
      Exit;
    end;

    // SDKの単体取得形式[Object]を、D&D用.objectの単一オブジェクト形式[0]へ変換する。
    for I := 0 to Lines.Count - 1 do
      if SameText(Lines[I], '[Object]') then
        Lines[I] := '[0]'
      else if StartsText('[Object.', Lines[I]) then
        Lines[I] := '[0.' + Copy(Lines[I], Length('[Object.') + 1, MaxInt);

    AviUtl2GetObjectLayerFrame(Obj, Layer, FrameStart, FrameEnd);
    HasLayer := False;
    for I := 0 to Lines.Count - 1 do
      if StartsText('layer=', Lines[I]) then
      begin
        HasLayer := True;
        Break;
      end;
    if not HasLayer then
      Lines.Insert(1, 'layer=' + IntToStr(Layer));

    AliasText := Lines.Text;
    Result := True;
  finally
    Lines.Free;
    AliasValue.Free;
  end;
end;

function AviUtl2SerifMsgViewDandD(const Layer : Integer): string;
var
  Convert ,len,Sec: Double;
  ItemSerif : TAliasManagerScriptSerifOutput;
begin
  Result := '';

  Convert := AviUtl2Convert();
  GAliasManager.ObjectName := '';
  GAliasManager.Clear;
  Sec := 0.0;
  len := 5.0;

  ItemSerif := GAliasManager.AddSerifOut(); // TAliasManagerScriptSerifOutput(GAliasManager.Add('SerifOut'));
  ItemSerif.LayerView := Layer;
  ItemSerif.FrameStart := Round(Sec / Convert);
  ItemSerif.FrameLength := Round(len / Convert);

  GAliasManager.SaveToAlias();
  Result := GAliasManager.FileName;
end;

function AviUtl2SerifIsSync(Msg: TSerifSceneMsgItem) : Boolean;
var
  obj : TObjectHandle;
begin
  Result := False;
  obj := AviUtl2FindObject(Msg.SerifLayer,Msg.FrameStart);
  if obj = nil then Exit;
  Result := True;
end;

function AviUtl2SerifSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
var
  obj : TObjectHandle;
begin
  Result := False;
  obj := AviUtl2FindObject(Layer,Frame);
  if obj = nil then Exit;
  //AviUtl2SetObjectItemValue(obj,EFECT_NAME,'セリフ',Value+' ');
  AviUtl2SetObjectItemValue(obj,EFECT_NAME,'セリフ',Value);
  Result := True;
end;

function AviUtl2SerifDirectionSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
var
  obj : TObjectHandle;
begin
  Result := False;
  obj := AviUtl2FindObject(Layer,Frame);
  if obj = nil then Exit;
  AviUtl2SetObjectItemInt(obj,EFECT_NAME,'演出',NormalizeDirectionValue(Value));
  Result := True;
end;

function AviUtl2SerifEmotionSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
var
  obj : TObjectHandle;
begin
  Result := False;
  obj := AviUtl2FindObject(Layer,Frame);
  if obj = nil then Exit;
  AviUtl2SetObjectItemValue(obj,EFECT_NAME,'感情',Value);
  Result := True;
end;

function AviUtl2SerifAiueoSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
var
  obj : TObjectHandle;
begin
  Result := False;
  obj := AviUtl2FindObject(Layer,Frame);
  if obj = nil then Exit;
  AviUtl2SetObjectItemValue(obj,EFECT_NAME,'母音',Value);
  Result := True;
end;


function AviUtl2SerifGetValue(const Layer,Frame : Integer) : string;
var
  obj : TObjectHandle;
  s : string;
begin
  Result := '';
  obj := AviUtl2FindObject(Layer,Frame);
  if obj = nil then Exit;
  AviUtl2GetObjectItemValue(obj,EFECT_NAME,'セリフ',s);
  Result := s;
end;

function AviUtl2SerifGetUID(const Layer,Frame : Integer) : string;
var
  obj : TObjectHandle;
  s : string;
begin
  Result := '';
  obj := AviUtl2FindObject(Layer,Frame);
  if obj = nil then Exit;
  AviUtl2GetObjectItemValue(obj,EFECT_NAME,'UID',s);
  Result := s;
end;

// 未取得状態を、ハンドルnilと位置-1で統一する。
procedure ClearSerifSelection(out Selection: TSerifAviUtl2Selection);
begin
  Selection.ObjectHandle := nil;
  Selection.UID := '';
  Selection.Layer := -1;
  Selection.FrameStart := -1;
  Selection.FrameEnd := -1;
end;

// オブジェクトのエイリアスを一度だけ解析し、表示値と再編集用識別情報をまとめて取得する。
function TryGetSerifObjectValues(const Obj: TObjectHandle;
  out SerifText, Character, Emotion: string;
  out Selection: TSerifAviUtl2Selection): Boolean;
var
  AliasValue: TAviUtl2ObjectAliasValue;
  CharacterOk: Boolean;
  EmotionOk: Boolean;
  AliasLoaded: Boolean;
  SerifOk: Boolean;
  LogCharacter: string;
  LogEmotion: string;
  LogSerif: string;
begin
  ClearSerifSelection(Selection);
  SerifText := '';
  Character := '';
  Emotion := '';
  if not Assigned(Obj) then
  begin
    VoicevoxDebugLog('Reedit library object=nil');
    Exit(False);
  end;
  AliasValue := TAviUtl2ObjectAliasValue.Create(VoicevoxDebugLog);
  try
    AliasLoaded := AliasValue.LoadFromAviUtl2Object(Obj);
    SerifOk := AliasLoaded and AliasValue.TryGetValue(EFECT_NAME,
      'セリフ', SerifText);
    CharacterOk := AliasLoaded and AliasValue.TryGetValue(EFECT_NAME,
      'キャラ', Character);
    EmotionOk := AliasLoaded and AliasValue.TryGetValue(EFECT_NAME,
      '感情', Emotion);
    if AliasLoaded then
      AliasValue.TryGetValue(EFECT_NAME, 'UID', Selection.UID);
  finally
    AliasValue.Free;
  end;
  LogSerif := StringReplace(StringReplace(SerifText, #13, '\r',
    [rfReplaceAll]), #10, '\n', [rfReplaceAll]);
  LogCharacter := StringReplace(StringReplace(Character, #13, '\r',
    [rfReplaceAll]), #10, '\n', [rfReplaceAll]);
  LogEmotion := StringReplace(StringReplace(Emotion, #13, '\r',
    [rfReplaceAll]), #10, '\n', [rfReplaceAll]);
  VoicevoxDebugLog(Format(
    'Reedit library alias_loaded=%s object=%s serif_ok=%s char_ok=%s emotion_ok=%s serif="%s" char="%s" emotion="%s"',
    [BoolToStr(AliasLoaded, True),
     IntToHex(NativeUInt(Obj), SizeOf(Pointer) * 2),
     BoolToStr(SerifOk, True), BoolToStr(CharacterOk, True),
     BoolToStr(EmotionOk, True), LogSerif, LogCharacter, LogEmotion]));
  Result := SerifOk;
  if not Result then Exit;
  SerifText := AvrUtl2_AviUtlToStr(SerifText);
  Character := AvrUtl2_AviUtlToStr(Character);
  Emotion := AvrUtl2_AviUtlToStr(Emotion);
  if not AviUtl2GetObjectLayerFrame(Obj, Selection.Layer,
    Selection.FrameStart, Selection.FrameEnd) then Exit(False);
  Selection.ObjectHandle := Obj;
end;

function AviUtl2SerifGetSelected(out SerifText, Character,
  Emotion: string): Boolean;
var
  Selection: TSerifAviUtl2Selection;
begin
  Result := AviUtl2SerifGetSelected(SerifText, Character, Emotion,
    Selection);
end;

function AviUtl2SerifGetSelected(out SerifText, Character,
  Emotion: string; out Selection: TSerifAviUtl2Selection): Boolean;
var
  CursorObject: TObjectHandle;
  FocusObject: TObjectHandle;
  I: Integer;
  Obj: TObjectHandle;
  SelectedCount: Integer;
begin
  Result := False;
  ClearSerifSelection(Selection);
  SerifText := '';
  Character := '';
  Emotion := '';
  SelectedCount := AviUtl2FindObjectSelectedNum;
  FocusObject := AviUtl2FindObjectFocus;
  VoicevoxDebugLog(Format('Reedit library selected_count=%d focus=%s',
    [SelectedCount, IntToHex(NativeUInt(FocusObject),
      SizeOf(Pointer) * 2)]));

  // 単一選択はGetSelectedObjectNumへ含まれないため、フォーカス中の
  // オブジェクトを選択対象として最初に解析する。
  if Assigned(FocusObject) and
    TryGetSerifObjectValues(FocusObject, SerifText, Character,
      Emotion, Selection) then
  begin
    VoicevoxDebugLog('Reedit library result=success source=focus');
    Exit(True);
  end;

  // 設定項目の更新直後はAviUtl2のフォーカスハンドルが古くなることがある。
  // カーソル位置から現在のハンドルを取り直して再試行する。
  CursorObject := AviUtl2FindObjectCursor;
  if Assigned(CursorObject) and (CursorObject <> FocusObject) and
    TryGetSerifObjectValues(CursorObject, SerifText, Character,
      Emotion, Selection) then
  begin
    VoicevoxDebugLog('Reedit library result=success source=cursor');
    Exit(True);
  end;

  // 複数選択時は一覧から最初のセリフ入力オブジェクトを探す。
  for I := 0 to SelectedCount - 1 do
  begin
    Obj := AviUtl2FindObjectSelected(I);
    if Obj = FocusObject then Continue;
    if TryGetSerifObjectValues(Obj, SerifText, Character, Emotion,
      Selection) then
    begin
      VoicevoxDebugLog(Format(
        'Reedit library result=success source=selected index=%d', [I]));
      Exit(True);
    end;
  end;
  VoicevoxDebugLog('Reedit library result=failed reason=no serif effect');
end;

function AviUtl2SerifResolveSelected(const Selection: TSerifAviUtl2Selection;
  out Layer, FrameStart, FrameEnd: Integer): Boolean;
var
  FocusObject: TObjectHandle;
  I: Integer;
  Obj: TObjectHandle;
begin
  Result := False;
  Layer := -1;
  FrameStart := -1;
  FrameEnd := -1;
  if not Assigned(Selection.ObjectHandle) then Exit;

  FocusObject := AviUtl2FindObjectFocus;
  if FocusObject = Selection.ObjectHandle then
    Exit(AviUtl2GetObjectLayerFrame(FocusObject, Layer, FrameStart,
      FrameEnd));

  for I := 0 to AviUtl2FindObjectSelectedNum - 1 do
  begin
    Obj := AviUtl2FindObjectSelected(I);
    if Obj <> Selection.ObjectHandle then Continue;
    Exit(AviUtl2GetObjectLayerFrame(Obj, Layer, FrameStart, FrameEnd));
  end;
end;

function NormalizeFileNameForCompare(const FileName: string): string;
begin
  Result := Trim(FileName);
  if Result = '' then Exit;
  try
    Result := ExpandFileName(Result);
  except
    // 比較不能な古いパスでも元文字列による比較は続ける。
  end;
end;

// 記録済みレイヤーとセリフ隣接レイヤーから、旧ファイル名に一致する音声オブジェクトを探す。
function TryFindWaveObject(const SerifLayer, FrameStart,
  PreferredWaveLayer: Integer; const ExpectedFileName: string;
  out WaveObject: TObjectHandle; out WaveLayer: Integer): Boolean;
var
  CandidateLayers: array[0..2] of Integer;
  CurrentFileName: string;
  ExpectedNormalized: string;
  I: Integer;
begin
  Result := False;
  WaveObject := nil;
  WaveLayer := -1;
  CandidateLayers[0] := PreferredWaveLayer;
  CandidateLayers[1] := SerifLayer + 1;
  CandidateLayers[2] := SerifLayer - 1;
  ExpectedNormalized := NormalizeFileNameForCompare(ExpectedFileName);

  for I := Low(CandidateLayers) to High(CandidateLayers) do
  begin
    if CandidateLayers[I] < 0 then Continue;
    if (I > Low(CandidateLayers)) and
      ((CandidateLayers[I] = CandidateLayers[0]) or
       ((I = High(CandidateLayers)) and
        (CandidateLayers[I] = CandidateLayers[1]))) then Continue;
    WaveObject := AviUtl2FindObject(CandidateLayers[I], FrameStart);
    if not Assigned(WaveObject) then Continue;
    if not AviUtl2GetObjectItemValue(WaveObject, '音声ファイル',
      'ファイル', CurrentFileName) then Continue;
    if (ExpectedNormalized <> '') and not SameText(
      NormalizeFileNameForCompare(CurrentFileName), ExpectedNormalized) then
      Continue;
    WaveLayer := CandidateLayers[I];
    Exit(True);
  end;
  WaveObject := nil;
end;

function AviUtl2SerifUpdateSelected(const Selection: TSerifAviUtl2Selection;
  const PreferredWaveLayer: Integer; const OldWaveFileName,
  NewWaveFileName: string; const NewWaveLength: Double;
  const SerifText, Character, Emotion, Direction, AIUEO,
  LabText: string; out ActualWaveLayer: Integer): Boolean;
var
  FrameEnd: Integer;
  FrameStart: Integer;
  Layer: Integer;
  PlaybackRange: string;
  SerifObject: TObjectHandle;
  WaveObject: TObjectHandle;
begin
  Result := False;
  ActualWaveLayer := -1;
  if not AviUtl2SerifResolveSelected(Selection, Layer, FrameStart,
    FrameEnd) then Exit;
  if not TryFindWaveObject(Layer, FrameStart, PreferredWaveLayer,
    OldWaveFileName, WaveObject, ActualWaveLayer) then Exit;

  // タイムライン上の開始・終了フレームは変更しない。
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle, EFECT_NAME,
    'セリフ', SerifText) then Exit;
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle, EFECT_NAME,
    'キャラ', Character) then Exit;
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle, EFECT_NAME,
    '感情', Emotion) then Exit;
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle, EFECT_NAME,
    '演出', Direction) then Exit;
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle, EFECT_NAME,
    '母音', AIUEO) then Exit;
  if not AviUtl2SetObjectItemValue(Selection.ObjectHandle, EFECT_NAME,
    'LAB', AvrUtl2_StrToAviutl(LabText)) then Exit;

  PlaybackRange := '0.000,' + FloatToStr(NewWaveLength,
    TFormatSettings.Invariant) + ',再生範囲,0';
  if not AviUtl2SetObjectItemValue(WaveObject, '音声ファイル',
    'ファイル', NewWaveFileName) then Exit;
  if not AviUtl2SetObjectItemValue(WaveObject, '音声ファイル',
    '再生位置', PlaybackRange) then Exit;

  // 音声側を最後に更新するとAviUtl2のフォーカスハンドルが変わるため、
  // 位置からセリフを取り直し、次回F2が同じ対象を取得できる状態へ戻す。
  SerifObject := AviUtl2FindObject(Layer, FrameStart);
  if Assigned(SerifObject) then
    AviUtl2CursorSetFocusObject(SerifObject);
  Result := True;
end;


function AviUtl2SerifDelete(const Layer,Frame : Integer) : Boolean;
var
  obj : TObjectHandle;
begin
  Result := False;
  obj := AviUtl2FindObject(Layer,Frame);
  if obj = nil then Exit;
  AviUtl2DeleteObject(obj);
  Result := True;
end;

function AviUtl2SerifMove(const LayerTo,FrameTo,LayerFrom,FrameFrom : Integer) : Boolean;
var
  obj : TObjectHandle;
begin
  Result := False;
  obj := AviUtl2FindObject(LayerFrom,FrameFrom);
  if obj = nil then Exit;
  Result := AviUtl2MoveObject(obj,LayerTo,FrameTo);
end;

initialization

finalization
  if GSerifDrawDragFileName <> '' then
    DeleteFile(GSerifDrawDragFileName);

end.
