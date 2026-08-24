unit SerifSceneMsgList;

interface


uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,RTTIPersistentIni,
  AutoLineBreakAdjuster;

//--------------------------------------------------------------------------//
//  セリフ情報を管理するクラス                                              //
//--------------------------------------------------------------------------//
type
  TSerifSceneMsgItem = class(TRTTIPersistentIni)
  private
    { Private 宣言 }
    FFileNameWave   : string;      // Waveファイル名（相対パス）
    FFileNameText   : string;      // テキストファイル名（相対パス） ※中身を読み込んだあとは不要
    FText           : string;      // 生セリフテキスト
    FChara          : string;      // キャラ名
    FKeyword        : string;      // 棒読みちゃん対応: 取り込み元の配役キーワード
    FVoice          : string;      // セリフ
    FIndex          : Integer;     // 出力順
    FEmotion        : string;      // 感情
    FWaveLength     : Double;      // Waveファイルの長さ（秒）

    FIsOutput       : Boolean;     // True : 下記の値が正しく入っている
    FSerifLayer     : Integer;     // オブジェクトの表示レイヤー番号
    FWaveLayer      : Integer;
    FFrameStart     : Integer;     // 開始フレーム
    FFrameEnd       : Integer;     // 終了フレーム
    FFrameNext      : Integer;     // 次のセリフのフレーム位置
    FFrameSpaceE    : Integer;     // 次のフレームまでの空白

    FSceneId        : Integer;     // シーンID
    FIsFind         : Boolean;     // リモートからの問い合わせ True:該当する
    FDirection      : string;      // セリフに割り当てる演出
    FAIUEO          : string;      // セリフの母音データ
    FUID            : string;      // 識別するためのUID
    FLabs           : TStringList; // LABデータ
    procedure SetText(const Value: string);
    function GetLabStr: string;
    procedure SetLabStr(const Value: string);

  public
    { Public 宣言 }
    constructor Create();
    destructor Destroy;override;

    // Voice を指定位置で 1 回だけ改行する（0 は改行なし）
    procedure SetLinePosition(LineIndex: Integer);
    procedure SetLinePositionWithAdjuster(LineIndex: Integer; Adjuster: TAutoLineBreakAdjuster);
    // 関連するファイルを削除
    procedure DeleteItemFile(const ProjectFolder : string);
    // ユニークIDを設定する
    procedure SetUID;
    // フレーム位置を移動
    procedure FrameMove(Frame : Integer);

    procedure EmotionPrev;
    procedure EmotionNext;

    property Text : string read FText write SetText;
    property Labs : TStringList read FLabs;
 published
    property FileNameWave : string read FFileNameWave write FFileNameWave;
    property FileNameText : string read FFileNameText write FFileNameText;
    property Chara : string read FChara write FChara;
    // 棒読みちゃん対応: y/hなどの受信キーを保存し、配役名変更時の再割り当てに使う。
    property Keyword : string read FKeyword write FKeyword;
    property Voice : string read FVoice write FVoice;
    property Index : Integer read FIndex write FIndex;
    property Emotion : string read FEmotion write FEmotion;
    property Direction : string read FDirection write FDirection;
    property AIUEO     : string read FAIUEO write FAIUEO;
    property WaveLength: Double read FWaveLength write FWaveLength;

    property IsOutput    : Boolean read FIsOutput      write FIsOutput;
    property IsFind      : Boolean read FIsFind        write FIsFind;
    property SerifLayer  : Integer read FSerifLayer    write FSerifLayer;
    property WaveLayer   : Integer read FWaveLayer     write FWaveLayer;
    property FrameStart  : Integer read FFrameStart    write FFrameStart;
    property FrameEnd    : Integer read FFrameEnd      write FFrameEnd;
    property FrameNext   : Integer read FFrameNext     write FFrameNext;
    property FrameSpaceE : Integer read FFrameSpaceE   write FFrameSpaceE;
    property SceneId     : Integer read FSceneId       write FSceneId;
    property UID         : string  read FUID           write FUID;
    property LabStr      : string  read GetLabStr      write SetLabStr;

  end;

  TSerifSceneMsgList = class(TRTTIPersistentIniList<TSerifSceneMsgItem>)
  private
    function GetMsgs(Index: Integer): TSerifSceneMsgItem;
  public
    function GetFrameNextMaxMsg: TSerifSceneMsgItem;
    function IndexOfFrameSerifLayer(frame,layer : Integer) : Integer;
    function IndexOfUID(UID : string) : Integer;
    // Voice を指定位置で 1 回だけ改行する（0 は改行なし）
    procedure SetLinePosition(LineIndex: Integer);
    property Msgs[Index : Integer] : TSerifSceneMsgItem read GetMsgs;
  end;

  // 参照酒するリストクラス
  TSerifSceneMsgListEx = class(TList)
  private
    function GetMsgs(Index: Integer): TSerifSceneMsgItem;
  public
    property Msgs[Index : Integer] : TSerifSceneMsgItem read GetMsgs;default;
  end;

implementation

{ TSerifSceneMsgList }

function TSerifSceneMsgList.GetMsgs(Index: Integer): TSerifSceneMsgItem;
begin
  Result := TSerifSceneMsgItem(inherited Items[Index]);
end;

function TSerifSceneMsgList.GetFrameNextMaxMsg: TSerifSceneMsgItem;
var
  I: Integer;
  Msg: TSerifSceneMsgItem;
begin
  Result := nil;
  for I := 0 to Count - 1 do
  begin
    Msg := Msgs[I];
    if Msg = nil then Continue;
    if (Result = nil) or (Msg.FrameNext > Result.FrameNext) then
      Result := Msg;
  end;
end;

{ TSerifSceneMsgListEx }

function TSerifSceneMsgListEx.GetMsgs(Index: Integer): TSerifSceneMsgItem;
begin
  Result := TSerifSceneMsgItem(inherited Items[Index]);
end;

function TSerifSceneMsgList.IndexOfFrameSerifLayer(frame, layer: Integer): Integer;
var
  i : Integer;
  Msg : TSerifSceneMsgItem;
begin
  Result := -1;
  for i := 0 to Count-1 do begin
    Msg := Msgs[i];
    if Msg.FrameStart <> frame then continue;
    if Msg.SerifLayer <> layer then continue;
    Exit(i);
  end;
end;

function TSerifSceneMsgList.IndexOfUID(UID: string): Integer;
var
  i : Integer;
  Msg : TSerifSceneMsgItem;
begin
  Result := -1;
  for i := 0 to Count-1 do begin
    Msg := Msgs[i];
    if Msg.UID <> UID then continue;
    Exit(i);
  end;
end;

procedure TSerifSceneMsgList.SetLinePosition(LineIndex: Integer);
var
  i : Integer;
begin
  for i := 0 to Count-1 do begin
    Msgs[i].SetLinePosition(LineIndex);
  end;
end;

{ TSerifSceneMsgItem }

constructor TSerifSceneMsgItem.Create;
begin
  FLabs := TStringList.Create;
end;

destructor TSerifSceneMsgItem.Destroy;
begin
  FLabs.Free;
  inherited;
end;

procedure TSerifSceneMsgItem.EmotionNext;
const
  EMOTION_VALUES: array[0..4] of string = ('喜', '怒', '哀', '楽','');
var
  I: Integer;
begin
  for I := Low(EMOTION_VALUES) to High(EMOTION_VALUES) do
  begin
    if Pos(EMOTION_VALUES[I], FEmotion) > 0 then
    begin
      if I >= High(EMOTION_VALUES) then
        FEmotion := EMOTION_VALUES[Low(EMOTION_VALUES)]
      else
        FEmotion := EMOTION_VALUES[I + 1];
      Exit;
    end;
  end;

  FEmotion := EMOTION_VALUES[Low(EMOTION_VALUES)];
end;

procedure TSerifSceneMsgItem.EmotionPrev;
const
  EMOTION_VALUES: array[0..4] of string = ('喜', '怒', '哀', '楽','');
var
  I: Integer;
begin
  for I := Low(EMOTION_VALUES) to High(EMOTION_VALUES) do
  begin
    if Pos(EMOTION_VALUES[I], FEmotion) > 0 then
    begin
      if I <= Low(EMOTION_VALUES) then
        FEmotion := EMOTION_VALUES[High(EMOTION_VALUES)]
      else
        FEmotion := EMOTION_VALUES[I - 1];
      Exit;
    end;
  end;

  FEmotion := EMOTION_VALUES[High(EMOTION_VALUES)];
end;

procedure TSerifSceneMsgItem.FrameMove(Frame: Integer);
var
  h : Integer;
begin
  if Frame < 0 then Frame := 0;
  h := Frame - FrameStart;
  FFrameStart := Frame;
  FFrameEnd := FFrameEnd + h;
  FFrameNext := FFrameNext + h;
end;

procedure TSerifSceneMsgItem.DeleteItemFile(const ProjectFolder : string);
var
  s : string;
begin
  s := ProjectFolder + FFileNameWave;
  if FileExists(s) then DeleteFile(s);

  s := ProjectFolder + FFileNameText;
  if FileExists(s) then DeleteFile(s);
end;


function StrLastEnterCut(const str : string) : string;
var
  len : Integer;
begin
  result := str;
  len := Length(str);
  if len < 2 then exit;
  if (Copy(str,len-1,2) = #$0d#$0a) then begin
    result := Copy(str,1,len-2);
  end;
end;


function TSerifSceneMsgItem.GetLabStr: string;
begin
  Result := FLabs.Text;
end;

procedure TSerifSceneMsgItem.SetLabStr(const Value: string);
begin
  FLabs.Text := Value;
end;

procedure TSerifSceneMsgItem.SetLinePosition(LineIndex: Integer);
var
  Adjuster: TAutoLineBreakAdjuster;
begin
  Adjuster := TAutoLineBreakAdjuster.Create;
  try
    SetLinePositionWithAdjuster(LineIndex, Adjuster);
  finally
    Adjuster.Free;
  end;
end;

procedure TSerifSceneMsgItem.SetLinePositionWithAdjuster(LineIndex: Integer;
  Adjuster: TAutoLineBreakAdjuster);
var
  S: string;
  I: Integer;
begin
  S := FVoice;
  if S = '' then Exit;

  // ---------------------------------------------------------
  // 既存の CRLF (#13#10) をすべて除去
  // ---------------------------------------------------------
  I := 1;
  while I <= Length(S) - 1 do
  begin
    if (S[I] = #13) and (S[I+1] = #10) then
      Delete(S, I, 2)   // CRLF 削除
    else
      Inc(I);
  end;

  // ---------------------------------------------------------
  // LineIndex = 0 → 改行なしのまま終了
  // ---------------------------------------------------------
  if LineIndex <= 0 then
  begin
    FVoice := S;
    Exit;
  end;

  // ---------------------------------------------------------
  // LineIndex が文字数超え → 行数を超えないよう調整
  // ---------------------------------------------------------
  if LineIndex >= Length(S) then
    LineIndex := Length(S);

  {
  // ---------------------------------------------------------
  // 旧仕様: 指定位置 LineIndex の直後に CRLF を追加
  // ---------------------------------------------------------
  P := LineIndex + 1;  // 1-based なので +1
  Insert(#13#10, S, P);

  // 文末 CRLF の削除（安全措置）
  if (Length(S) >= 2) and
     (S[Length(S)-1] = #13) and
     (S[Length(S)]   = #10) then
  begin
    SetLength(S, Length(S)-2);
  end;
  }

  if Assigned(Adjuster) then
    S := Adjuster.Adjust(S, LineIndex);

  FVoice := S;
end;


procedure TSerifSceneMsgItem.SetText(const Value: string);
var
  i : Integer;
  s,sv : string;
begin
  FText := Value;
  s := '＞';
  i := Pos(s,Value);
  if i <> 0 then begin
    FChara := Copy(Value,1,i - Length(s));
    sv := Copy(Value,i + Length(s),Length(Value));
    sv := StrLastEnterCut(sv);
    FVoice  := sv;
  end
  else begin
    sv  := Copy(Value,i + Length(s),Length(Value));
    sv := StrLastEnterCut(sv);
    FVoice  := sv;
  end;
end;

procedure TSerifSceneMsgItem.SetUID;
var
  Guid: TGUID;
begin
  if CreateGUID(Guid) = S_OK then UID := GUIDToString(Guid);
end;

end.
