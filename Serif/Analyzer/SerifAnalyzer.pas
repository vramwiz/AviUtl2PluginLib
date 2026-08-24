unit SerifAnalyzer;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,StrUtils,FolderWatch,RTTIPersistentIni,
  SerifCharaList,System.IOUtils,SerifSceneMsgList,CharaAnalyzer,SerifConfig,
  AutoLineBreakAdjuster;

type
  TSerifAnalyzerFileItem = class(TRTTIPersistentIni)
  private
    { Private 宣言 }
    FSourceWav : string;      // コピー前の元wavファイル
    FSourceTxt : string;      // コピー前の元txtファイル
    FSourceLab : string;      // コピー前の元labファイル
    FWav      : string;      // 拡張子wavのファイル
    FTxt      : string;      // 拡張子txtのファイル
    FLab      : string;      // 拡張子labのファイル（存在する場合だけ扱う）
    FFileName : string;      // 元のファイル名（ファイル名部分のみ）
    FTextOrg  : string;
    function GetEnabled: Boolean;
  protected
  public
    property Enabled : Boolean read GetEnabled;
    property FileName : string read FFileName;
    property TextOrg : string read FTextOrg;
  published
    property Wav : string read FWav write FWav;
    property Txt : string read FTxt write FTxt;
    property Lab : string read FLab write FLab;
  end;

//--------------------------------------------------------------------------//
//   リストクラス                                                             //
//--------------------------------------------------------------------------//
  TSerifAnalyzerFileList = class(TRTTIPersistentIniList<TSerifAnalyzerFileItem>)
  private
    function GetWatchers(Index: Integer): TSerifAnalyzerFileItem;
  protected
  public
    function IndexOfWav(const FileName :string) : Integer;
    function IndexOfTxt(const FileName :string) : Integer;
    function IndexOfTxtWav(const FileName :string) : Integer;
    property FileNames[Index : Integer] : TSerifAnalyzerFileItem read GetWatchers;
  end;

//--------------------------------------------------------------------------//
//  アプリが出力すファイルを解析するクラス                                  //
//--------------------------------------------------------------------------//
type
  TSerifAnalyzer = class(TPersistent)
  private
    { Private 宣言 }
    //FCharas         : TSerifCharaList;              // 配役リスト
    FFileNames      : TSerifAnalyzerFileList;         // txtとwavの組み合わせリスト
    FColorCharas    : TSerifAnalyzerCharaList;
    FLineAdjuster : TAutoLineBreakAdjuster;
    FHasIndexedSequentialFiles: Boolean;
    FSendFolder     : string;

    // ファイル一覧をtxtとwavに分解
    function FileNamesToWavTxt( FileNames: TStringList;var Line : Integer) : Boolean;
    // txtとwavがそろったファイルをプロジェクトファイルにコピー
    function FileNamesCopy() : Boolean;
    // 処理が終わったファイルを削除
    function FileNamesDelete() : Boolean;
    // コピーしたtxt wavファイルをセリフリストに登録
    function FileNamesToSerifMsgs(Msgs : TSerifSceneMsgList) : Boolean;
    // 処理完了したペアを内部キューから削除
    procedure RemoveCompletedFileNames;

    // 解析したファイル名などから配役とセリフに割り当てる
    function FileNameToSerifMsg(Msg : TSerifSceneMsgItem;Item : TSerifAnalyzerFileItem) : Boolean;

    // 音声合成ソフトのキャラ判断処理
    // VOICROID用
    function FileNameToSerifMsgVoiceroid(Msg : TSerifSceneMsgItem;Item : TSerifAnalyzerFileItem;const Text : string) : Boolean;
    // VOICEVOX用
    function FileNameToSerifMsgVoicevox(Msg : TSerifSceneMsgItem;Item : TSerifAnalyzerFileItem;const Text : string) : Boolean;
    // VOICEPEAK用
    function FileNameToSerifMsgVoicepeak(Msg : TSerifSceneMsgItem;Item : TSerifAnalyzerFileItem;const Text : string) : Boolean;
    // A.I.VOICE2用
    function FileNameToSerifMsgAivoice2(Msg : TSerifSceneMsgItem;Item : TSerifAnalyzerFileItem;const Text : string) : Boolean;
    function FileNameToSerifMsgAivoice(Msg : TSerifSceneMsgItem;Item : TSerifAnalyzerFileItem) : Boolean;
    // 棒読みちゃん用: txt本文の "y)セリフ" 形式を解析する。
    function FileNameToSerifMsgBouyomi(Msg : TSerifSceneMsgItem;Item : TSerifAnalyzerFileItem;const Text : string) : Boolean;
    function CheckVOICEROID(): Boolean;
    // VOICEROID特有のソート
    procedure SortVOICEROID();

    function CheckVOICEVOXAIVOICE(Msgs: TSerifSceneMsgList): Boolean;
    procedure SortVOICEVOXAIVOICE(Msgs: TSerifSceneMsgList);
    function IsSequentialSerifItem(Item: TSerifAnalyzerFileItem): Boolean;
    function ShouldProcessItem(Item: TSerifAnalyzerFileItem): Boolean;
    function ShouldDeleteItem(Item: TSerifAnalyzerFileItem): Boolean;

    // セリフから配役を登録
    // 棒読みちゃん対応: Keywordで受けた配役を表示用Nameへ正規化する。
    procedure NormalizeMsgCharaNames(Charas  : TSerifCharaList;Msgs : TSerifSceneMsgList);
    procedure MsgsToCharas(Charas  : TSerifCharaList;Msgs : TSerifSceneMsgList);
    procedure ApplyMsgColors(Chara: TSerifCharaItem; Msg: TSerifSceneMsgItem);
    // セリフリストに長さを割り当て
    procedure MsgsToMagsLength(Msgs : TSerifSceneMsgList;Charas  : TSerifCharaList);
    // LABが無いセリフへWAV音量由来のvol LABを割り当て
    procedure MsgsToMissingLabFromWave(Msgs : TSerifSceneMsgList);
    // WAVの小音量終端に残った音素LABを切り詰める
    procedure MsgsToTrimQuietLabTailFromWave(Msgs : TSerifSceneMsgList);
    // 改行位置を設定
    procedure MsgsToMagsEnterPos(Msgs : TSerifSceneMsgList;Config : TSerifConfigItem);

  public
    { Public 宣言 }
    constructor Create;
    destructor Destroy; override;
    // 解析を実行
    function Execute(Msgs : TSerifSceneMsgList;Charas  : TSerifCharaList;SendFolder : string;FileNames : TStringList;Config : TSerifConfigItem;var ErrLine : Integer) : Boolean;
  end;

implementation

uses SoundFileUtilsWave,TextEncodingUtils,SerifAnalyzerLab,WaveVolumeLab
  {$IFDEF DEBUG},PSDImageDebugLog{$ENDIF};

{ TSerifAnalyzer }

function HasLeadingIndexHyphen(const FileName: string): Boolean;
var
  BaseName: string;
  P: Integer;
  IndexValue: Integer;
begin
  BaseName := ChangeFileExt(ExtractFileName(FileName), '');
  P := Pos('-', BaseName);
  Result := (P > 1) and TryStrToInt(Copy(BaseName, 1, P - 1), IndexValue);
end;

function ResolveSendFileName(const SendFolder, FileName: string): string;
begin
  Result := '';
  if FileName = '' then Exit;
  if (ExtractFileDrive(FileName) <> '') or
     ((Length(FileName) >= 2) and (FileName[1] = '\') and (FileName[2] = '\')) then
    Exit(FileName);
  Result := IncludeTrailingPathDelimiter(SendFolder) + FileName;
end;


function TSerifAnalyzer.CheckVOICEROID: Boolean;
var
  i, P1: Integer;
  S, NumStr: string;
  N: Integer;
begin
  Result := False; // まず False

  for i := 0 to FFileNames.Count - 1 do
  begin
    if not ShouldProcessItem(FFileNames[i]) then
      Continue;
    S := FFileNames[i].FileName;

    // 拡張子を取る
    S := ChangeFileExt(S, '');

    // '-xxx' を探す
    P1 := LastDelimiter('-', S); // ← 後ろから '-'
    if P1 <= 0 then Exit;        // 形式が違う → 中止

    // '-xxx' の後を取得
    NumStr := Copy(S, P1 + 1, MaxInt);

    // 数字か確認
    N := StrToIntDef(NumStr, -1);
    if N < 0 then Exit; // 数字でない → 中止
  end;

  // 全て問題なし
  Result := True;
end;




constructor TSerifAnalyzer.Create;
begin
  FFileNames := TSerifAnalyzerFileList.Create;
  FColorCharas := TSerifAnalyzerCharaList.Create;
  FLineAdjuster := TAutoLineBreakAdjuster.Create;
  FHasIndexedSequentialFiles := False;
end;

destructor TSerifAnalyzer.Destroy;
begin
  FLineAdjuster.Free;
  FColorCharas.Free;
  FFileNames.Free;
  inherited;
end;

function TSerifAnalyzer.Execute(Msgs : TSerifSceneMsgList;Charas : TSerifCharaList; SendFolder: string;  FileNames: TStringList;Config : TSerifConfigItem;var ErrLine : Integer): Boolean;
var
  i : Integer;
  f : Boolean;
begin
  Result := False;
  {$IFDEF DEBUG}
  PSDDebugLog('SerifAnalyzer', Format(
    'Execute start send_folder="%s" files=%d',
    [SendFolder, FileNames.Count]));
  for i := 0 to FileNames.Count - 1 do
    PSDDebugLog('SerifAnalyzer', Format('Execute file[%d]="%s"', [i, FileNames[i]]));
  {$ENDIF}
  // フォルダ末尾に区切りを付与
  FSendFolder := IncludeTrailingPathDelimiter(SendFolder);

  Msgs.Clear;                                             // 出力数rセリフを初期化

  f := FilenamestoWavTxt(FileNames,i);                    // txt と wavに分解
  if not f then begin                                     // 失敗した場合
    ErrLine := -1;                                        // 未完成ペア待ち
    {$IFDEF DEBUG}
    PSDDebugLog('SerifAnalyzer', 'Execute stop: FileNamesToWavTxt returned false');
    {$ENDIF}
    Exit;                                                 // 次回のファイル到着を待つ
  end;
  {$IFDEF DEBUG}
  PSDDebugLog('SerifAnalyzer', Format(
    'Execute after FileNamesToWavTxt queue_count=%d indexed_sequential=%s',
    [FFileNames.Count, BoolToStr(FHasIndexedSequentialFiles, True)]));
  {$ENDIF}

  if CheckVOICEROID() then                                // VOICEROIDデータの場合
    SortVOICEROID();                                      // VOICEROID用に並びかえる
  if not FileNamesCopy() then
  begin
    {$IFDEF DEBUG}
    PSDDebugLog('SerifAnalyzer', 'Execute stop: FileNamesCopy returned false');
    {$ENDIF}
    Exit;                                                 // ロジェクトフォルダにコピー
  end;
  {$IFDEF DEBUG}
  PSDDebugLog('SerifAnalyzer', 'Execute after FileNamesCopy');
  {$ENDIF}
  if not FileNamesToSerifMsgs(Msgs) then
  begin
    {$IFDEF DEBUG}
    PSDDebugLog('SerifAnalyzer', 'Execute stop: FileNamesToSerifMsgs returned false');
    {$ENDIF}
    Exit;                                                 // セリフに登録
  end;
  {$IFDEF DEBUG}
  PSDDebugLog('SerifAnalyzer', Format('Execute after FileNamesToSerifMsgs msgs=%d', [Msgs.Count]));
  {$ENDIF}
  if CheckVOICEVOXAIVOICE(Msgs) then                      // VOICEVOX/A.I.VOICE/VOICEPEAK データの場合
    SortVOICEVOXAIVOICE(Msgs);                            // インデックスで並びかえる
  MsgsToMagsLength(Msgs,Charas);                          // セリフの長さ計算
  {$IFDEF DEBUG}
  PSDDebugLog('SerifAnalyzer', 'Execute before MsgsToMissingLabFromWave');
  {$ENDIF}
  // LABファイルが無い場合だけWAV音量からvol LABを生成する。
  // 問題が出た場合は、この1行をコメントアウトすると従来のLAB処理だけに戻せる。
  MsgsToMissingLabFromWave(Msgs);
  {$IFDEF DEBUG}
  PSDDebugLog('SerifAnalyzer', 'Execute after MsgsToMissingLabFromWave');
  {$ENDIF}
  NormalizeSerifMsgLabs(Msgs);                             // WAV長を基準にLABを内部共通形式へ変換
  {$IFDEF DEBUG}
  PSDDebugLog('SerifAnalyzer', 'Execute after NormalizeSerifMsgLabs');
  {$ENDIF}
  MsgsToTrimQuietLabTailFromWave(Msgs);                    // 音素LABの末尾に残る小音量区間を閉じ口扱いへ寄せる
  {$IFDEF DEBUG}
  PSDDebugLog('SerifAnalyzer', 'Execute after MsgsToTrimQuietLabTailFromWave');
  {$ENDIF}
  MsgsToMagsEnterPos(Msgs,Config);                        // 改行位置を計算
  NormalizeMsgCharaNames(Charas,Msgs);                     // 棒読みちゃん等のKeyword配役を表示用Nameに変換
  MsgsToCharas(Charas,Msgs);                              // 配役に登録
  if not FileNamesDelete() then
  begin
    {$IFDEF DEBUG}
    PSDDebugLog('SerifAnalyzer', 'Execute stop: FileNamesDelete returned false');
    {$ENDIF}
    Exit;                                                 // 元ファイルを削除
  end;
  RemoveCompletedFileNames;                               // 完了済みペアを内部キューから削除
  ErrLine := -1;

  Result := True;
  {$IFDEF DEBUG}
  PSDDebugLog('SerifAnalyzer', Format('Execute finish msgs=%d charas=%d', [Msgs.Count, Charas.Count]));
  {$ENDIF}
end;

function TSerifAnalyzer.FileNamesToWavTxt(FileNames: TStringList;var Line : Integer) : Boolean;
var
  i,j : Integer;
  s,ext : string;
  Item : TSerifAnalyzerFileItem;
begin
  Result := False;
  for j := 0 to FileNames.Count-1 do begin
    s := FileNames[j];
    ext := LowerCase(ExtractFileExt(s));
    i:= FFileNames.IndexOfTxtWav(s);                // Wav Txtどちらかが一致するファイル名インデクス取得
    if i = -1 then Item := FFileNames.AddNew()      // 該当しなければ追加
              else Item := FFileNames[i];
    if ext = '.txt' then begin
      Item.FTxt := s;                               // テキストファイル名を設定
      Item.FSourceTxt := s;                         // 元txtを保持
    end;
    if ext = '.wav' then begin
      Item.FWav := s;                               // 音声ファイル名を設定
      Item.FSourceWav := s;                         // 元wavを保持
    end;
    if ext = '.lab' then begin
      // LABはtxt/wavと同じ基底名で紐づけ、ペア成立条件には含めない。
      Item.FLab := s;                               // LABファイル名を設定
      Item.FSourceLab := s;                         // 元labを保持
    end;
  end;
  for j := FFileNames.Count-1 downto 0 do begin     // 逆順に探索
    Item := FFileNames[j];                          // 該当する要素参照
    if Item.FTxt <> '' then
      Item.FFilename := ExtractFileName(Item.FTxt)
    else if Item.FWav <> '' then
      Item.FFilename := ExtractFileName(Item.FWav)  // wav先着でも名前を持たせる
    else
      Item.FFilename := ExtractFileName(Item.FLab); // lab先着でも名前を持たせる
    Item.FFileName := ChangeFileExt(Item.FFileName,''); // 拡張子を削除
  end;

  FHasIndexedSequentialFiles := False;
  for i := 0 to FFileNames.Count - 1 do
  begin
    if not FFileNames[i].Enabled then
      Continue;
    if not IsSequentialSerifItem(FFileNames[i]) then
      Continue;
    FHasIndexedSequentialFiles := True;
    Break;
  end;

  Result := False;
  for i := 0 to FFileNames.Count-1 do begin             //
     if ShouldProcessItem(FFileNames[i]) then begin
       Line := -1;
       Exit(True);     // 1件でも有効なデータがあれば正常
     end;
  end;
end;

function TSerifAnalyzer.FileNamesCopy(): Boolean;
var
  i: Integer;
  Item : TSerifAnalyzerFileItem;
  BaseName, DestTxt, DestWav: string;
  TS: string;
begin
  //Result := False;

  // フォルダが無ければ作成
  if not DirectoryExists(FSendFolder) then
    if not ForceDirectories(FSendFolder) then
      Exit(False);

  // タイムスタンプ（1回のみ）
  TS := FormatDateTime('yyyymmdd_hhnnss_zzz', Now);

  try
    for i := 0 to FFileNames.Count - 1 do
    begin
      Item := FFileNames[i];
      if not ShouldProcessItem(Item) then
        Continue;

      // 新しい基底名
      BaseName := TS + '_' + Format('%.3d', [i]);

      // コピー先ファイル名（フルパス）
      DestTxt := FSendFolder + BaseName + '.txt';
      DestWav := FSendFolder + BaseName + '.wav';

      // --- TXT コピー ---
      if FileExists(Item.Txt) then
      begin
        TFile.Copy(Item.Txt, DestTxt, True);
        Item.FTextOrg := Item.FTxt;             // オリジナルを残す
        Item.FTxt     := BaseName + '.txt';     // ★ ここで更新
      end;

      // --- WAV コピー ---
      if FileExists(Item.Wav) then
      begin
        TFile.Copy(Item.Wav, DestWav, True);
        Item.FWav := BaseName + '.wav';         // ★ ここで更新
      end;
    end;

    Result := True;

  except
    Result := False;
  end;
end;

function TSerifAnalyzer.FileNamesDelete(): Boolean;
var
  i: Integer;
  Item: TSerifAnalyzerFileItem;

  procedure DeleteFileSafe(const FN: string);
  begin
    if FN = '' then Exit;
    if not TFile.Exists(FN) then Exit;
    try
      TFile.Delete(FN);
    except
      Result := False;
    end;
  end;
begin
  Result := True;

  for i := 0 to FFileNames.Count - 1 do
  begin
    Item := FFileNames[i];
    if not ShouldDeleteItem(Item) then
      Continue;
    DeleteFileSafe(Item.FSourceTxt);
    DeleteFileSafe(Item.FSourceWav);
    DeleteFileSafe(Item.FSourceLab);
  end;
end;

function TSerifAnalyzer.FileNamesToSerifMsgs(Msgs: TSerifSceneMsgList): Boolean;
var
  i : Integer;
  msg : TSerifSceneMsgItem;
  Item : TSerifAnalyzerFileItem;
  LabFileName: string;
begin
  //Result := False;
  for i := 0 to FFileNames.Count - 1 do
  begin
    Item := FFileNames[i];              // ★ ここで必ず要素を取得
    if not ShouldProcessItem(Item) then
      Continue;
    msg := Msgs.AddNew;

    msg.FileNameWave := Item.FWav;      // コピー後の wav
    msg.FileNameText := Item.FTxt;      // コピー後の txt

    FileNameToSerifMsg(msg,Item);

    // LAB原文をMsg.Labsへ読み込み、後続のNormalizeSerifMsgLabsで内部形式へ置き換える。
    LabFileName := ResolveSendFileName(FSendFolder, Item.FLab);
    if (LabFileName <> '') and FileExists(LabFileName) then
      msg.LabStr := LoadTextAutoEncoding(LabFileName);
  end;
  Result := True;
end;

procedure TSerifAnalyzer.RemoveCompletedFileNames;
var
  i: Integer;
begin
  for i := FFileNames.Count - 1 downto 0 do
  begin
    if ShouldDeleteItem(FFileNames[i]) then
      FFileNames.Delete(i);
  end;
end;

function TSerifAnalyzer.IsSequentialSerifItem(
  Item: TSerifAnalyzerFileItem): Boolean;
begin
  Result := False;
  if Item = nil then Exit;
  if Item.FSourceTxt <> '' then
    Exit(HasLeadingIndexHyphen(Item.FSourceTxt));
  if Item.FSourceWav <> '' then
    Exit(HasLeadingIndexHyphen(Item.FSourceWav));
  if Item.FSourceLab <> '' then
    Exit(HasLeadingIndexHyphen(Item.FSourceLab));
end;

function TSerifAnalyzer.ShouldProcessItem(
  Item: TSerifAnalyzerFileItem): Boolean;
begin
  Result := False;
  if Item = nil then Exit;
  if not Item.Enabled then Exit;
  if FHasIndexedSequentialFiles and (not IsSequentialSerifItem(Item)) then
    Exit;
  Result := True;
end;

function TSerifAnalyzer.ShouldDeleteItem(Item: TSerifAnalyzerFileItem): Boolean;
begin
  Result := False;
  if Item = nil then Exit;
  if ShouldProcessItem(Item) then
    Exit(True);
  if not FHasIndexedSequentialFiles then Exit;
  if IsSequentialSerifItem(Item) then Exit;
  Result := (Item.FSourceTxt <> '') or (Item.FSourceWav <> '') or (Item.FSourceLab <> '');
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

function NormalizeLineBreaks(const S: string): string;
var
  Tmp: string;
begin
  Tmp := StringReplace(S, #13#10, #10, [rfReplaceAll]);
  Tmp := StringReplace(Tmp, #13, #10, [rfReplaceAll]);
  Result := StringReplace(Tmp, #10, #13#10, [rfReplaceAll]);
end;

function HasLineBreak(const S: string): Boolean;
begin
  Result := (Pos(#13, S) > 0) or (Pos(#10, S) > 0);
end;


function TSerifAnalyzer.FileNameToSerifMsg(Msg: TSerifSceneMsgItem;Item: TSerifAnalyzerFileItem): Boolean;
var
  str : string;
  TxtFileName: string;
  IsAivoice: Boolean;
begin
  Result := False;
  str := '';
  TxtFileName := ResolveSendFileName(FSendFolder, Item.FTxt);
  if not FileExists(TxtFileName) then Exit;
  // txtファイル読み込み → Text へセット
  str := LoadTextAutoEncoding(TxtFileName);
  str := NormalizeLineBreaks(str);
  str := StrLastEnterCut(str);

  IsAivoice := FileNameToSerifMsgAivoice(Msg, Item);

  // 棒読みちゃん形式: txt本文の先頭キーを配役 Keyword として扱う。
  if FileNameToSerifMsgBouyomi(Msg,Item,str) then Exit(True);
  // VOICEPEAKとして解析
  if FileNameToSerifMsgVoicepeak(Msg,Item,str) then Exit(True);
  // A.I.VOICE2として解析
  if FileNameToSerifMsgAivoice2(Msg,Item,str) then Exit(True);
  // VOICEVOXとして解析
  if FileNameToSerifMsgVoicevox(Msg,Item,str) then Exit(True);
  // VOICEROIDとして解析
  if FileNameToSerifMsgVoiceroid(Msg,Item,str) then Exit(True);

  // A.I.VOICE2形式: ファイル名はA.I.VOICE同様のIndex+セリフ抜粋、txt本文はセリフのみ。
  if IsAivoice then
  begin
    Msg.Voice := str;
    Exit(True);
  end;
end;

const
  OPEN_BRACKETS  = '（({[｛［';
  CLOSE_BRACKETS = '）)}]｝］';

function ExtractEmotion(const S: string; out Base, Emotion: string): Boolean;
var
  i, openPos, closePos, idx: Integer;
  closeChar: Char;
begin
  Result := False;
  Base := S;
  Emotion := '';

  openPos := 0;
  closeChar := #0;

  // 開き括弧を検索
  for i := 1 to Length(S) do
  begin
    idx := Pos(S[i], OPEN_BRACKETS);
    if idx > 0 then
    begin
      openPos := i;
      //openChar := S[i];
      // 対応する閉じ括弧を決定
      closeChar := CLOSE_BRACKETS[idx];
      Break;
    end;
  end;

  // 開き括弧なし → Emotionなし
  if openPos = 0 then Exit;

  // 閉じ括弧位置を探す
  closePos := PosEx(closeChar, S, openPos + 1);
  if closePos = 0 then Exit;   // 括弧不整合

  // Base と Emotion に分解
  Base := Trim(Copy(S, 1, openPos - 1));
  Emotion := Trim(Copy(S, openPos + 1, closePos - openPos - 1));

  Result := True;
end;

function SameCharaName(const A, B: string): Boolean;
var
  SA, SB: string;
begin
  SA := Trim(A);
  SB := Trim(B);

  SA := SA.Replace(' ', '', [rfReplaceAll]);
  SA := SA.Replace('　', '', [rfReplaceAll]);

  SB := SB.Replace(' ', '', [rfReplaceAll]);
  SB := SB.Replace('　', '', [rfReplaceAll]);

  Result := SameText(SA, SB);
end;

function TextToVoiceByFileChara(const Text, Chara: string; var Emotion: string): string;
var
  p: Integer;
  LeftStr, RightStr, Base, ParsedEmotion: string;
begin
  Result := Text;

  p := Pos('＞', Text);
  if p = 0 then Exit;

  LeftStr  := Copy(Text, 1, p - 1);
  RightStr := Copy(Text, p + 1, MaxInt);
  RightStr := StrLastEnterCut(RightStr);

  if ExtractEmotion(LeftStr, Base, ParsedEmotion) then
  begin
    if not SameCharaName(Base, Chara) then Exit;
    if ParsedEmotion <> '' then
      Emotion := ParsedEmotion;
  end
  else
  begin
    if not SameCharaName(LeftStr, Chara) then Exit;
  end;

  Result := RightStr;
end;

function TSerifAnalyzer.FileNameToSerifMsgVoiceroid(
  Msg: TSerifSceneMsgItem; Item: TSerifAnalyzerFileItem;
  const Text: string): Boolean;
var
  p: Integer;
  LeftStr, RightStr: string;
  Base, Emotion: string;
begin
  Result := False;

  // 「＞」が無ければ解析しない
  p := Pos('＞', Text);
  if p = 0 then Exit;

  // 左：キャラ＋感情
  LeftStr  := Copy(Text, 1, p - 1);

  // 右：セリフ
  RightStr := Copy(Text, p + 1, MaxInt);
  RightStr := StrLastEnterCut(RightStr);

  // 感情解析（成功すれば Base=キャラ, Emotion=感情）
  if ExtractEmotion(LeftStr, Base, Emotion) then
  begin
    Msg.Chara   := Base;
    Msg.Emotion := Emotion;
  end
  else
  begin
    // 感情なし
    Msg.Chara   := Trim(LeftStr);
    Msg.Emotion := '';
  end;

  Msg.Voice := RightStr;
  Result := True;
end;


function ExtractFileNameManual(const FullPath: string): string;
var
  p: Integer;
begin
  p := LastDelimiter('\', FullPath);
  if p > 0 then
    Result := Copy(FullPath, p + 1, MaxInt)
  else
    Result := FullPath;  // 念のため
end;

function TSerifAnalyzer.FileNameToSerifMsgBouyomi(
  Msg: TSerifSceneMsgItem; Item: TSerifAnalyzerFileItem;
  const Text: string): Boolean;
var
  S, Key, Voice, BaseName, IndexText: string;
  P, DelimPos, Index: Integer;
begin
  Result := False;

  // 棒読みちゃん対応: "y)こんにちは" のように先頭の ")" までを配役 Keyword として読む。
  S := Trim(Text);
  P := Pos(')', S);
  if P <= 1 then Exit;

  Key := Trim(Copy(S, 1, P - 1));
  Voice := Copy(S, P + 1, MaxInt);
  if (Key = '') or (Voice = '') then Exit;

  Msg.Chara := Key;
  Msg.Keyword := Key; // 棒読みちゃん対応: 後から配役Nameを変えても再割り当てできるようキーを保持する。
  Msg.Emotion := '';
  Msg.Voice := StrLastEnterCut(Voice);

  // 棒読みちゃん対応: sample_0000 の末尾番号を並び替え用 Index にする。
  BaseName := ChangeFileExt(ExtractFileNameManual(Item.TextOrg), '');
  DelimPos := LastDelimiter('_-', BaseName);
  if DelimPos > 0 then
  begin
    IndexText := Copy(BaseName, DelimPos + 1, MaxInt);
    Index := StrToIntDef(IndexText, -1);
    if Index >= 0 then
      Msg.Index := Index;
  end;

  Result := True;
end;

function TSerifAnalyzer.FileNameToSerifMsgVoicevox(
  Msg: TSerifSceneMsgItem;
  Item: TSerifAnalyzerFileItem;
  const Text: string): Boolean;
var
  S, NameAndEmotion, CharacterName, Emotion: string;
  P1, P2, POpen, PClose, Index: Integer;
begin
  Result := False;  // 未確定

  // 生の絶対パスからファイル名だけ取得
  S := ExtractFileNameManual(Item.TextOrg);
  // 拡張子を除去（キャラ名に . があっても最後の . だけ消える）
  S := ChangeFileExt(S, '');

  // 形式想定： 001_キャラ名（感情）_セリフ抜粋
  // ① 先頭の "_" までが Index
  P1 := Pos('_', S);
  if P1 <= 0 then Exit;

  Index := StrToIntDef(Copy(S, 1, P1 - 1), -1);
  if Index < 0 then Exit;

  // ② 2つ目の "_" までが「キャラ名＋感情」
  P2 := PosEx('_', S, P1 + 1);
  if P2 <= 0 then Exit;

  NameAndEmotion := Copy(S, P1 + 1, P2 - P1 - 1);

  // ③ NameAndEmotion から感情（全角括弧）を抜き出す
  //    例： "琴葉 茜（普）" → "琴葉 茜" / "普"
  POpen  := Pos('（', NameAndEmotion);
  PClose := Pos('）', NameAndEmotion);

  if (POpen > 0) and (PClose > POpen) then
  begin
    CharacterName := Trim(Copy(NameAndEmotion, 1, POpen - 1));
    Emotion       := Trim(Copy(NameAndEmotion, POpen + 1, PClose - POpen - 1));
  end
  else
  begin
    // 感情なしパターン
    CharacterName := Trim(NameAndEmotion);
    Emotion := '';
  end;

  if CharacterName = '' then Exit;

  // ---- ④ 成功 ----
  Msg.Index   := Index;
  Msg.Chara   := CharacterName;
  Msg.Emotion := Emotion;  // 感情なしなら ''
  Emotion     := Msg.Emotion;
  Msg.Voice   := TextToVoiceByFileChara(Text, Msg.Chara, Emotion); // txt本文を採用し、必要なら話者部分を除去
  Msg.Emotion := Emotion;

  Result := True;
end;

function TSerifAnalyzer.FileNameToSerifMsgVoicepeak(
  Msg: TSerifSceneMsgItem; Item: TSerifAnalyzerFileItem;
  const Text: string): Boolean;
var
  S, IndexText, CharacterName, Emotion: string;
  P1, P2, P3, Index: Integer;
begin
  Result := False;

  // VOICEPEAK形式: Index-Chara-SerifText-ProjectName
  // セリフ抜粋が空の場合は Index-Chara--ProjectName になる。
  // セリフはファイル名ではなくtxt本文を採用する。
  S := ExtractFileNameManual(Item.TextOrg);
  S := ChangeFileExt(S, '');

  P1 := Pos('-', S);
  if P1 <= 1 then Exit;

  IndexText := Copy(S, 1, P1 - 1);
  Index := StrToIntDef(IndexText, -1);
  if Index < 0 then Exit;

  P2 := PosEx('-', S, P1 + 1);
  if P2 <= P1 + 1 then Exit;

  P3 := PosEx('-', S, P2 + 1);
  if P3 = 0 then Exit;

  CharacterName := Trim(Copy(S, P1 + 1, P2 - P1 - 1));
  if CharacterName = '' then Exit;

  Msg.Index   := Index;
  Msg.Chara   := CharacterName;
  Msg.Emotion := '';
  Emotion     := Msg.Emotion;
  Msg.Voice   := TextToVoiceByFileChara(Text, Msg.Chara, Emotion);
  Msg.Emotion := Emotion;

  Result := True;
end;

function TSerifAnalyzer.FileNameToSerifMsgAivoice2(
  Msg: TSerifSceneMsgItem; Item: TSerifAnalyzerFileItem;
  const Text: string): Boolean;
var
  S, Rest, CharaName, Emotion: string;
  i, Index: Integer;
begin
  Result := False;

  // A.I.VOICE2形式: {Number=3}{Character}{Text=10}
  // 区切り文字が無いため、3桁番号の直後を既知キャラ名の最長一致で判定する。
  S := ExtractFileNameManual(Item.TextOrg);
  S := ChangeFileExt(S, '');
  if Length(S) < 4 then Exit;
  if not CharInSet(S[1], ['0'..'9']) then Exit;
  if not CharInSet(S[2], ['0'..'9']) then Exit;
  if not CharInSet(S[3], ['0'..'9']) then Exit;
  if S[4] = '_' then Exit;  // VOICEVOX の 001_... は除外

  Index := StrToIntDef(Copy(S, 1, 3), -1);
  if Index < 0 then Exit;

  Rest := Copy(S, 4, MaxInt);
  CharaName := '';
  for i := 0 to FColorCharas.Count - 1 do
  begin
    if not StartsText(FColorCharas.Charas[i].Name, Rest) then Continue;
    if Length(FColorCharas.Charas[i].Name) <= Length(CharaName) then Continue;
    CharaName := FColorCharas.Charas[i].Name;
  end;
  if CharaName = '' then Exit;

  Msg.Index   := Index;
  Msg.Chara   := CharaName;
  Msg.Emotion := '';
  Emotion     := Msg.Emotion;
  Msg.Voice   := TextToVoiceByFileChara(Text, Msg.Chara, Emotion);
  Msg.Emotion := Emotion;

  Result := True;
end;

function TSerifAnalyzer.FileNameToSerifMsgAivoice(
  Msg: TSerifSceneMsgItem; Item: TSerifAnalyzerFileItem): Boolean;
var
  S: string;
  Index: Integer;
begin
  Result := False;

  // 形式想定： 001セリフ抜粋
  S := ExtractFileNameManual(Item.TextOrg);
  S := ChangeFileExt(S, '');
  if Length(S) < 4 then Exit;
  if not CharInSet(S[1], ['0'..'9']) then Exit;
  if not CharInSet(S[2], ['0'..'9']) then Exit;
  if not CharInSet(S[3], ['0'..'9']) then Exit;
  if S[4] = '_' then Exit;  // VOICEVOX の 001_... は除外

  Index := StrToIntDef(Copy(S, 1, 3), -1);
  if Index < 0 then Exit;

  Msg.Index := Index;
  Result := True;
end;


function TSerifAnalyzer.CheckVOICEVOXAIVOICE( Msgs: TSerifSceneMsgList): Boolean;
var
  i : Integer;
begin
  Result := False;
  if Msgs.Count <= 1 then Exit;
  for i := 0 to Msgs.Count-1 do begin
    if Msgs[i].Index <> 0 then Exit(True);
  end;
end;

procedure TSerifAnalyzer.SortVOICEVOXAIVOICE(Msgs: TSerifSceneMsgList);
var
  i, j: Integer;
begin
  if Msgs.Count <= 1 then Exit;

  // バブルソート（Index 昇順）
  for i := 0 to Msgs.Count - 2 do
  begin
    for j := i + 1 to Msgs.Count - 1 do
    begin
      // Index が大きいものを後ろに
      if Msgs[i].Index > Msgs[j].Index then
        Msgs.Exchange(i, j);
    end;
  end;
end;

procedure TSerifAnalyzer.NormalizeMsgCharaNames(Charas: TSerifCharaList;
  Msgs: TSerifSceneMsgList);
var
  i, CharaIndex: Integer;
  Msg: TSerifSceneMsgItem;
begin
  if Charas = nil then Exit;

  for i := 0 to Msgs.Count - 1 do
  begin
    Msg := Msgs[i];
    if Msg = nil then Continue;

    // 棒読みちゃん対応: Keywordを保持している場合は、それを優先して表示用Nameへ置き換える。
    if Trim(Msg.Keyword) = '' then
      Msg.Keyword := Msg.Chara;

    CharaIndex := Charas.indexOfKeyword(Msg.Keyword);
    if CharaIndex < 0 then Continue;
    if Trim(Charas[CharaIndex].Name) = '' then Continue;

    Msg.Chara := Charas[CharaIndex].Name;
  end;
end;

procedure TSerifAnalyzer.MsgsToCharas(Charas: TSerifCharaList;  Msgs: TSerifSceneMsgList);
var
  i,j : Integer;
  Msg: TSerifSceneMsgItem;
  Chara : TSerifCharaItem;
begin
  for j := 0 to Msgs.Count-1 do begin
    Msg := Msgs[j];
    i := Charas.indexOfKeyword(Msg.Chara);
    if i <> -1 then Continue;                     // 配役が存在する場合処理しない
    Chara := Charas.AddNew();
    Chara.Name      := Msg.Chara;
    // 棒読みちゃん対応: Msg.Keywordがある場合は受信キーとして登録する。
    if Trim(Msg.Keyword) <> '' then
      Chara.Keyword := Msg.Keyword
    else
      Chara.Keyword := Msg.Chara;
    Chara.Emotion   := Msg.Emotion;
    ApplyMsgColors(Chara, Msg);
  end;

end;

procedure TSerifAnalyzer.ApplyMsgColors(Chara: TSerifCharaItem;
  Msg: TSerifSceneMsgItem);
var
  ColorLight, ColorBase, ColorDark: TColor;
begin
  if Chara = nil then Exit;
  if Msg = nil then Exit;

  // 3色化フェーズ3: 定義済み配役は Light/Base/Dark をまとめて登録する。
  if FColorCharas.TryGetCharaColors(Msg.Chara, ColorLight, ColorBase, ColorDark) then
    Chara.SetImageColors(ColorLight, ColorBase, ColorDark)
  else
    Chara.ColorBack := clWhite;
end;

procedure TSerifAnalyzer.MsgsToMagsLength(Msgs: TSerifSceneMsgList;  Charas: TSerifCharaList);
var
  i : Integer;
  Msg : TSerifSceneMsgItem;
  WaveFileName: string;
begin
  for i := 0 to Msgs.Count-1 do begin
    Msg := Msgs[i];
    WaveFileName := ResolveSendFileName(FSendFolder, Msg.FileNameWave);
    Msg.WaveLength := GetWaveLengthSec(WaveFileName);
  end;
end;

procedure TSerifAnalyzer.MsgsToMissingLabFromWave(Msgs: TSerifSceneMsgList);
var
  i, j, BeforeCount: Integer;
  Msg: TSerifSceneMsgItem;
  WaveFileName: string;
begin
  for i := 0 to Msgs.Count - 1 do
  begin
    Msg := Msgs[i];
    if Msg.Labs.Count > 0 then
    begin
      {$IFDEF DEBUG}
      PSDDebugLog('SerifAnalyzer', Format(
        'skip volume LAB because LAB already exists index=%d wave="%s" lab_count=%d',
        [i, Msg.FileNameWave, Msg.Labs.Count]));
      {$ENDIF}
      Continue;
    end;
    if Msg.FileNameWave = '' then
    begin
      {$IFDEF DEBUG}
      PSDDebugLog('SerifAnalyzer', Format(
        'skip volume LAB because wave name is empty index=%d', [i]));
      {$ENDIF}
      Continue;
    end;

    WaveFileName := ResolveSendFileName(FSendFolder, Msg.FileNameWave);
    if not FileExists(WaveFileName) then
    begin
      {$IFDEF DEBUG}
      PSDDebugLog('SerifAnalyzer', Format(
        'skip volume LAB because wave file does not exist index=%d source="%s" wave="%s"',
        [i, Msg.FileNameWave, WaveFileName]));
      {$ENDIF}
      Continue;
    end;

    {$IFDEF DEBUG}
    PSDDebugLog('SerifAnalyzer', Format(
      'generate volume LAB start index=%d wave="%s" length=%.4f',
      [i, WaveFileName, Msg.WaveLength]));
    {$ENDIF}

    BeforeCount := Msg.Labs.Count;
    WaveFileToVolumeLabLines(WaveFileName, Msg.Labs);

    {$IFDEF DEBUG}
    PSDDebugLog('SerifAnalyzer', Format(
      'generate volume LAB finish index=%d wave="%s" before=%d after=%d',
      [i, WaveFileName, BeforeCount, Msg.Labs.Count]));
    for j := 0 to Msg.Labs.Count - 1 do
      PSDDebugLog('SerifAnalyzer', Format(
        'generated lab index=%d line=%d %s', [i, j, Msg.Labs[j]]));
    {$ENDIF}
  end;
end;

procedure TSerifAnalyzer.MsgsToTrimQuietLabTailFromWave(Msgs: TSerifSceneMsgList);
const
  QUIET_TAIL_MIN_VOLUME = 20;
  QUIET_TAIL_MAX_TRIM_SEC = 0.25;
var
  i, BeforeCount: Integer;
  Msg: TSerifSceneMsgItem;
  WaveFileName: string;
  ActiveEndSec, QuietTailSec: Double;
begin
  for i := 0 to Msgs.Count - 1 do
  begin
    Msg := Msgs[i];
    if Msg.Labs.Count = 0 then Continue;
    if Msg.FileNameWave = '' then Continue;

    WaveFileName := ResolveSendFileName(FSendFolder, Msg.FileNameWave);
    if not FileExists(WaveFileName) then Continue;

    ActiveEndSec := WaveFileActiveEndSec(WaveFileName, QUIET_TAIL_MIN_VOLUME);
    if ActiveEndSec <= 0 then Continue;
    if (Msg.WaveLength > 0) and (ActiveEndSec >= Msg.WaveLength) then Continue;
    if Msg.WaveLength <= 0 then Continue;

    QuietTailSec := Msg.WaveLength - ActiveEndSec;
    if QuietTailSec > QUIET_TAIL_MAX_TRIM_SEC then
    begin
      {$IFDEF DEBUG}
      PSDDebugLog('SerifAnalyzer', Format(
        'skip quiet LAB tail trim because tail is too long index=%d wave="%s" active_end=%.4f wave_length=%.4f tail=%.4f max_tail=%.4f min_volume=%d',
        [i, WaveFileName, ActiveEndSec, Msg.WaveLength, QuietTailSec,
         QUIET_TAIL_MAX_TRIM_SEC, QUIET_TAIL_MIN_VOLUME]));
      {$ENDIF}
      Continue;
    end;

    BeforeCount := Msg.Labs.Count;
    TrimSerifMsgLabAfterSec(Msg, ActiveEndSec);

    {$IFDEF DEBUG}
    PSDDebugLog('SerifAnalyzer', Format(
      'trim quiet LAB tail index=%d wave="%s" active_end=%.4f wave_length=%.4f before=%d after=%d min_volume=%d',
      [i, WaveFileName, ActiveEndSec, Msg.WaveLength, BeforeCount,
       Msg.Labs.Count, QUIET_TAIL_MIN_VOLUME]));
    {$ENDIF}
  end;
end;

procedure TSerifAnalyzer.MsgsToMagsEnterPos(Msgs: TSerifSceneMsgList;Config: TSerifConfigItem);
var
  i: Integer;
begin
  for i := 0 to Msgs.Count - 1 do
  begin
    // A.I.VOICE2 の「改行付きセリフ」など、出力データ側に改行が
    // すでに含まれる場合は、その改行を正として自動改行を重ねない。
    if HasLineBreak(Msgs[i].Voice) then
      Continue;
    Msgs[i].SetLinePositionWithAdjuster(Config.EnterPos, FLineAdjuster);
  end;
end;

procedure TSerifAnalyzer.SortVOICEROID();
var
  i, j: Integer;
  S: string;
  P: Integer;
  NumI, NumJ: Integer;
begin
  // すでに事前チェック済み（-xxx 形式のみ）

  // バブルソート
  for i := 0 to FFileNames.Count - 2 do
  begin
    for j := i + 1 to FFileNames.Count - 1 do
    begin
      // -------- index I を取得 --------
      S := ChangeFileExt(FFileNames[i].FileName, '');
      P := LastDelimiter('-', S);
      NumI := StrToIntDef(Copy(S, P + 1, MaxInt), 0);

      // -------- index J を取得 --------
      S := ChangeFileExt(FFileNames[j].FileName, '');
      P := LastDelimiter('-', S);
      NumJ := StrToIntDef(Copy(S, P + 1, MaxInt), 0);

      // -------- 若い番号を先に並べる（昇順） --------
      if NumI > NumJ then
        FFileNames.Exchange(i, j);
    end;
  end;
end;

{ TSerifAnalyzerFileList }

function TSerifAnalyzerFileList.GetWatchers(  Index: Integer): TSerifAnalyzerFileItem;
begin
  Result := TSerifAnalyzerFileItem(inherited Items[Index]);
end;

function TSerifAnalyzerFileList.IndexOfTxt(const FileName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Count-1 do begin
    if FileNames[i].FTxt <> FileName then Continue;
    Result := i;
    Exit;
  end;
end;

function TSerifAnalyzerFileList.IndexOfWav(const FileName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Count-1 do begin
    if FileNames[i].FWav <> FileName then Continue;
    Result := i;
    Exit;
  end;
end;

function TSerifAnalyzerFileList.IndexOfTxtWav(const FileName: string): Integer;
var
  i: Integer;
  s : string;
  Item : TSerifAnalyzerFileItem;
begin
  s := ChangeFileExt(FileName, '');
  Result := -1;
  for i := 0 to Count-1 do begin
    Item := FileNames[i];
    if ChangeFileExt(Item.FTxt, '') = s then begin
      Result := i;
      Exit;
    end;
    if ChangeFileExt(Item.FWav, '') = s then begin
      Result := i;
      Exit;
    end;
    if ChangeFileExt(Item.FLab, '') = s then begin
      // labが先に到着した場合でも、後から来るtxt/wavと同じアイテムへ結合する。
      Result := i;
      Exit;
    end;
  end;
end;

{ TSerifAnalyzerFileItem }

function TSerifAnalyzerFileItem.GetEnabled: Boolean;
begin
  Result := (FWav <> '') and (FTxt <> '');
end;

end.
