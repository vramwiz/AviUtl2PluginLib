unit AviUtl2Serif;

interface

uses  System.SysUtils,System.Classes,SerifCharaList,SerifSceneMsgList,SerifConfig,Math,
      AviUtl2PluginTypes,SerifAviUtlSelection;

type
  TSerifAviUtl2Selection = SerifAviUtlSelection.TSerifAviUtl2Selection;

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

uses SerifAviUtlDragAlias, SerifAviUtlSender, SerifAviUtlTimeline;

function AviUtl2SerifMsgsSend(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem; Send: Boolean): string;
begin
  Result := SendSerifMessages(ProjectFolder, Msgs, Charas, Config, Send);
end;

function AviUtl2SerifMsgsSendNow(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem): Boolean;
begin
  Result := SendSerifMessagesNow(ProjectFolder, Msgs, Charas, Config);
end;

function AviUtl2SerifMsgsSendContinuous(const ProjectFolder: string;
  Msgs: TSerifSceneMsgListEx; Charas: TSerifCharaList;
  Config: TSerifConfigItem): Boolean;
begin
  Result := SendSerifMessagesContinuous(ProjectFolder, Msgs, Charas, Config);
end;

procedure AviUtl2SerifResetContinuousSend;
begin
  ResetSerifContinuousSend;
end;


function AviUtl2SerifDrawDandD: string;
begin
  Result := CreateSerifDrawDragAlias;
end;

function AviUtl2SerifDrawDandD(const AliasText: string): string;
begin
  Result := CreateSerifDrawDragAlias(AliasText);
end;

function AviUtl2SerifDrawGetSelectedAlias(out AliasText,
  ErrorMessage: string): Boolean;
begin
  Result := GetSelectedSerifDrawAlias(AliasText, ErrorMessage);
end;

function AviUtl2SerifMsgViewDandD(const Layer : Integer): string;
begin
  Result := CreateSerifMessageViewDragAlias(Layer);
end;

function AviUtl2SerifIsSync(Msg: TSerifSceneMsgItem) : Boolean;
begin
  Result := SerifAviUtlIsSynchronized(Msg);
end;

function AviUtl2SerifSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
begin
  Result := SerifAviUtlSetText(Layer, Frame, Value);
end;

function AviUtl2SerifDirectionSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
begin
  Result := SerifAviUtlSetDirection(Layer, Frame, Value);
end;

function AviUtl2SerifEmotionSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
begin
  Result := SerifAviUtlSetEmotion(Layer, Frame, Value);
end;

function AviUtl2SerifAiueoSetValue(const Layer,Frame : Integer;const Value : string) : Boolean;
begin
  Result := SerifAviUtlSetAiueo(Layer, Frame, Value);
end;


function AviUtl2SerifGetValue(const Layer,Frame : Integer) : string;
begin
  Result := SerifAviUtlGetText(Layer, Frame);
end;

function AviUtl2SerifGetUID(const Layer,Frame : Integer) : string;
begin
  Result := SerifAviUtlGetUID(Layer, Frame);
end;

// 未取得状態を、ハンドルnilと位置-1で統一する。
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
begin
  Result := SerifAviUtlGetSelected(SerifText, Character, Emotion, Selection);
end;

function AviUtl2SerifResolveSelected(const Selection: TSerifAviUtl2Selection;
  out Layer, FrameStart, FrameEnd: Integer): Boolean;
begin
  Result := SerifAviUtlResolveSelected(Selection, Layer, FrameStart, FrameEnd);
end;

function AviUtl2SerifUpdateSelected(const Selection: TSerifAviUtl2Selection;
  const PreferredWaveLayer: Integer; const OldWaveFileName,
  NewWaveFileName: string; const NewWaveLength: Double;
  const SerifText, Character, Emotion, Direction, AIUEO,
  LabText: string; out ActualWaveLayer: Integer): Boolean;
begin
  Result := SerifAviUtlUpdateSelected(Selection, PreferredWaveLayer,
    OldWaveFileName, NewWaveFileName, NewWaveLength, SerifText, Character,
    Emotion, Direction, AIUEO, LabText, ActualWaveLayer);
end;


function AviUtl2SerifDelete(const Layer,Frame : Integer) : Boolean;
begin
  Result := SerifAviUtlDelete(Layer, Frame);
end;

function AviUtl2SerifMove(const LayerTo,FrameTo,LayerFrom,FrameFrom : Integer) : Boolean;
begin
  Result := SerifAviUtlMove(LayerTo, FrameTo, LayerFrom, FrameFrom);
end;

initialization

end.
