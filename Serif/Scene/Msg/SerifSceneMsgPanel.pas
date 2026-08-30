unit SerifSceneMsgPanel;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Types, System.Generics.Collections, Vcl.Graphics, Vcl.Controls, Vcl.ExtCtrls, Vcl.StdCtrls,
  SerifSceneMsgListBox, SerifSceneList, SerifSceneMsgList, SerifCharaList,
  SerifSceneMsgListBoxEditor, DragAgent, SerifConfig, ShortcutAction,
  SerifDirectionCatalog;

type
  TSerifSceneMsgPanelCursorFocusEvent = procedure(Sender: TObject; Layer, Frame: Integer) of object;
  TSerifSceneMsgPanelAIUEOChangeEvent = procedure(Sender: TObject; const AIUEO: string) of object;

type
  TSerifSceneMsgPanel = class(TPanel)
  private
    FLbox          : TSerifSceneMsgListBoxEditor; // 編集対象のセリフ一覧
    FDrag          : TDragShellFile;             // シェルドラッグ出力
    FShortcuts     : TShortcutAction;            // キー操作管理
    FTimerKeySave  : TTimer;                     // 遅延保存タイマー
    FMsgs          : TSerifSceneMsgList;         // 表示中のセリフ一覧
    FProjectFolder : string;                     // プロジェクトフォルダ
    FCharas        : TSerifCharaList;            // 配役一覧
    FConfig        : TSerifConfigItem;           // 設定情報
    FSelectMsg     : TSerifSceneMsgItem;         // 現在選択中のセリフ
    FIgnoreSyncOnce: Boolean;                    // 自己起因の戻り同期を1回だけ無視
    FIgnoreFrame   : Integer;                    // 無視対象フレーム
    FIgnoreLayer   : Integer;                    // 無視対象レイヤー
    FOnChange      : TNotifyEvent;               // 変更通知
    FOnCharaChange : TNotifyEvent;               // 配役変更通知
    FOnMoveCursorFocus: TSerifSceneMsgPanelCursorFocusEvent; // カーソル移動通知
    FOnAIUEOChange : TSerifSceneMsgPanelAIUEOChangeEvent; // 母音変更通知
    FAutoSend      : Boolean;                    // 自動送信設定
    // AviUtl連携
    procedure AviUtlSetValue();
    procedure AviUtlSetDirection();
    procedure AviUtlSetEmotion();
    procedure AviUtlSetAiueo();
    procedure SaveDelayMsgs();

    procedure ItemVoice(Voice : string);

    // リストイベント
    procedure OnListBoxClick(Sender : TObject);
    procedure OnListDblClick(Sender : TObject);
    procedure OnListEdited(Sender : TObject);
    procedure OnListRequestChara(Sender: TObject; const Index: Integer; var aChara: string; var aColorLight, aColorBase, aColorDark: TColor);
    procedure OnListBoxRequestMeasure(Sender: TObject;const Index : Integer;var str : string);
    procedure OnListKeyDown(Sender: TObject;var Key: Word; Shift: TShiftState);
    procedure OnListKeyPress(Sender: TObject; var Key: Char);
    procedure OnDrag(Sender: TObject;FileNames : TStringList);
    procedure TimerKeySaveTimer(Sender: TObject);
    procedure MoveCursorFocus(Layer, Frame: Integer);
    function ConsumeActiveSerifGuard(Frame, Layer: Integer): Boolean;
    function GetSelectedMsg: TSerifSceneMsgItem;
    function FindDirectionIndex(const DirectionName: string): Integer;
    procedure NotifyAIUEOChange;
  protected
    // 通知
    procedure DoChange(); virtual;
    procedure DoCharaChange(); virtual;
  public
    // ライフサイクル
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // 表示更新
    procedure ShowList(const ProjectFolder : string;Msgs : TSerifSceneMsgList;Charas : TSerifCharaList;Config : TSerifConfigItem);
    // 遅延保存を止め、表示中の台本データとの参照を解除する。
    procedure CloseList;
    function AddList(Msgs : TSerifSceneMsgList; ForceSend: Boolean = False;
      ContinuousSend: Boolean = False;
      RegisterOnly: Boolean = False): Boolean;
    procedure View();
    procedure ShowIndexLast();
    // 文字編集
    procedure ItemToggleExclamation;
    procedure ItemToggleQuestion;
    procedure ItemEnterPosPrev;
    procedure ItemEnterPosNext;
    procedure ItemEnterSelPrev;
    procedure ItemEnterSelNext;
    procedure ItemSend();
    procedure ItemSendAll();
    // アイテム操作
    procedure ItemEdit;
    procedure ItemDelete();
    procedure ItemSelectAll();
    procedure ItemSelectClear();
    procedure ItemLeft;
    procedure ItemRight;
    procedure ItemLeftAll;
    procedure ItemRightAll;
    procedure ItemUp;
    procedure ItemDown;

    // 感情を削除
    procedure ItemEmotionClear;
    // 1つ前の感情状態にする
    procedure ItemEmotionPrev;
    // 1つ後の感情状態にする
    procedure ItemEmotionNext;

    // 演出を削除
    procedure ItemDirectionClear;
    // 1つ前の演出状態にする
    procedure ItemDirectionPrev;
    // 1つ後の演出状態にする
    procedure ItemDirectionNext;

    procedure ItemVoiceA;
    procedure ItemVoiceI;
    procedure ItemVoiceU;
    procedure ItemVoiceE;
    procedure ItemVoiceO;
    procedure ItemVoiceN;
    procedure ItemVoiceBackSpace;
    procedure ItemVoiceClear;
    procedure ItemVoiceStr(const Value : string);

    // 配役操作
    procedure CharaAdd;
    // カーソル移動
    procedure CursorUp;
    procedure CursorDown;
    procedure CursorMoveFirst;
    procedure CursorMoveLast;
    // 選択参照
    function IsMsgSelect(const Index : Integer) : Boolean;
    procedure ActiveSerif(frame,layerTxt,layerWav : Integer;UID : string);
    // AviUtl2上のセリフオブジェクトと同期させる
    procedure SerifSync;
    // 公開プロパティ
    property Shortcuts  : TShortcutAction read FShortcuts;
    property AutoSend : Boolean read FAutoSend write FAutoSend;
    property OnChange : TNotifyEvent read FOnChange write FOnChange;
    property OnCharaChange : TNotifyEvent read FOnCharaChange write FOnCharaChange;
    property OnMoveCursorFocus : TSerifSceneMsgPanelCursorFocusEvent read FOnMoveCursorFocus write FOnMoveCursorFocus;
    property OnAIUEOChange : TSerifSceneMsgPanelAIUEOChangeEvent read FOnAIUEOChange write FOnAIUEOChange;
    property Listbox : TSerifSceneMsgListBoxEditor read FLbox;
  end;

implementation

uses
  AviUtl2PluginCore, AviUtl2Serif, AviUtl2PluginCursorControl,
  AviUtl2PluginObjectFind,
  SerifHostNotifications, AviUtl2TextUtils;

constructor TSerifSceneMsgPanel.Create(AOwner: TComponent);
begin
  inherited;

  BevelOuter := bvNone;

  FLbox := TSerifSceneMsgListBoxEditor.Create(Self);
  FLbox.Parent := Self;
  FLbox.Align := alClient;
  FLbox.MultiSelect := True;
  FLbox.Font.Height := -13;
  FLbox.DoubleBuffered := True;

  FLbox.OnClick := OnListBoxClick;
  FLbox.OnDblClick := OnListDblClick;
  FLbox.OnRequestMeasure := OnListBoxRequestMeasure;
  FLbox.OnRequestChara := OnListRequestChara;
  FLbox.OnEdited := OnListEdited;
  FLbox.OnKeyDown := OnListKeyDown;
  FLbox.OnKeyPress := OnListKeyPress;

  FShortcuts := TShortcutAction.Create;

  FDrag := TDragShellFile.Create(Self);
  FDrag.Attach(FLbox);
  FDrag.OnDragRequest := OnDrag;

  FTimerKeySave := TTimer.Create(Self);
  FTimerKeySave.Enabled := False;
  FTimerKeySave.OnTimer := TimerKeySaveTimer;

  FIgnoreSyncOnce := False;
  FIgnoreFrame := -1;
  FIgnoreLayer := -1;
end;

destructor TSerifSceneMsgPanel.Destroy;
begin
  FShortcuts.Free;
  FDrag.Free;
  FLbox.Free;
  inherited;
end;

procedure TSerifSceneMsgPanel.CloseList;
begin
  FTimerKeySave.Enabled := False;
  FProjectFolder := '';
  FMsgs := nil;
  FCharas := nil;
  FConfig := nil;
  FSelectMsg := nil;
  FIgnoreSyncOnce := False;
  FIgnoreFrame := -1;
  FIgnoreLayer := -1;
  FLbox.Clear;
end;

procedure TSerifSceneMsgPanel.ShowList(const ProjectFolder : string;Msgs : TSerifSceneMsgList;Charas : TSerifCharaList;Config : TSerifConfigItem);
begin
  FProjectFolder := ProjectFolder;
  FMsgs := Msgs;
  FCharas := Charas;
  FConfig := Config;
  if FMsgs = nil then Exit;
  if FCharas = nil then Exit;
  if FConfig = nil then Exit;
  FLbox.ShowList(FMsgs);
  FSelectMsg := GetSelectedMsg;
  NotifyAIUEOChange;
end;

procedure TSerifSceneMsgPanel.AviUtlSetValue();
var
  i : Integer;
  Msg : TSerifSceneMsgItem;
begin
  i := FLbox.ItemIndex;
  if i = -1 then Exit;
  Msg := TSerifSceneMsgItem(FLbox.Items.Objects[i]);
  FMsgs[i].Assign(Msg);
  AviUtl2SerifSetValue(Msg.SerifLayer,Msg.FrameStart,Msg.Voice);
end;

procedure TSerifSceneMsgPanel.AviUtlSetAiueo;
var
  i : Integer;
  Msg : TSerifSceneMsgItem;
begin
  // 選択中セリフの演出文字列をAviUtl2側へ反映する
  i := FLbox.ItemIndex;
  if i = -1 then Exit;
  Msg := TSerifSceneMsgItem(FLbox.Items.Objects[i]);
  FMsgs[i].Assign(Msg);
  // 母音のデータを設定
  AviUtl2SerifAiueoSetValue(Msg.SerifLayer,Msg.FrameStart,Msg.AIUEO);
end;

procedure TSerifSceneMsgPanel.AviUtlSetDirection();
var
  i : Integer;
  Msg : TSerifSceneMsgItem;
begin
  // 選択中セリフの演出文字列をAviUtl2側へ反映する
  i := FLbox.ItemIndex;
  if i = -1 then Exit;
  Msg := TSerifSceneMsgItem(FLbox.Items.Objects[i]);
  FMsgs[i].Assign(Msg);
  // 表情遅延を無効にする
  NotifySerifHostVisualRefresh;
  AviUtl2SerifDirectionSetValue(Msg.SerifLayer,Msg.FrameStart,Msg.Direction);
end;

procedure TSerifSceneMsgPanel.AviUtlSetEmotion;
var
  i : Integer;
  Msg : TSerifSceneMsgItem;
begin
  i := FLbox.ItemIndex;
  if i = -1 then Exit;
  Msg := TSerifSceneMsgItem(FLbox.Items.Objects[i]);
  FMsgs[i].Assign(Msg);
  // 表情遅延を無効にする
  NotifySerifHostVisualRefresh;
  AviUtl2SerifEmotionSetValue(Msg.SerifLayer,Msg.FrameStart,Msg.Emotion);
end;

procedure TSerifSceneMsgPanel.TimerKeySaveTimer(Sender: TObject);
begin
  FTimerKeySave.Enabled := False;
  DoChange();
end;

procedure TSerifSceneMsgPanel.ActiveSerif(frame, layerTxt, layerWav: Integer;UID : string);
var
  i : Integer;
  s  : string;
  f : Boolean;
  Chara : TSerifCharaItem;
begin
  if ConsumeActiveSerifGuard(frame, layerTxt) then Exit;
  if FMsgs = nil then Exit;
  if UID <> '' then
    i := FMsgs.IndexOfUID(UID)
  else
    i := FMsgs.IndexOfFrameSerifLayer(frame,layerTxt);
  if i = -1 then Exit;
  FLbox.ItemIndex := i;
  FSelectMsg := FMsgs[i];
  FSelectMsg.SerifLayer := layerTxt;
  if layerWav <> -1 then FSelectMsg.WaveLayer := layerWav;
  s := FSelectMsg.Chara;
  i := FCharas.indexOfKeyword(s);
  if i <> -1 then begin
    f := False;
    Chara := FCharas[i];
    if Chara.LayerSerif <> layerTxt then f := True;
    if (layerWav <> -1) and (Chara.LayerWave <> layerWav) then f := True;

    if f then begin
      Chara.LayerSerif := layerTxt;
      // 対応する音声が見つからない場合は、現在の配役設定を維持する。
      if layerWav <> -1 then Chara.LayerWave := layerWav;
      FCharas.SaveToFile;
    end;
  end;

  NotifyAIUEOChange;
end;

function TSerifSceneMsgPanel.ConsumeActiveSerifGuard(Frame, Layer: Integer): Boolean;
begin
  Result := False;
  if not FIgnoreSyncOnce then Exit;
  FIgnoreSyncOnce := False;
  Result := (FIgnoreFrame = Frame) and (FIgnoreLayer = Layer);
end;

function TSerifSceneMsgPanel.FindDirectionIndex(const DirectionName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  // 未設定の演出は該当なしとして扱う
  if Trim(DirectionName) = '' then
    Exit;

  // 演出名に対応する固定一覧の位置を探す
  for I := Low(SerifDirectionNames) to High(SerifDirectionNames) do
    if SameText(SerifDirectionNames[I], DirectionName) then
      Exit(I);
end;

function TSerifSceneMsgPanel.GetSelectedMsg: TSerifSceneMsgItem;
var
  I: Integer;
begin
  Result := nil;
  // 現在のリスト選択から編集対象のメッセージを取得する
  if FMsgs = nil then Exit;
  if FLbox = nil then Exit;

  I := FLbox.ItemIndex;
  if I < 0 then Exit;
  if I >= FMsgs.Count then Exit;

  Result := FMsgs[I];
end;

procedure TSerifSceneMsgPanel.MoveCursorFocus(Layer, Frame: Integer);
begin
  // 2026-04: ガード処理は上位フレームへ通知して実行する
  if Assigned(FOnMoveCursorFocus) then FOnMoveCursorFocus(Self, Layer, Frame);
  FIgnoreSyncOnce := True;
  FIgnoreFrame := Frame;
  FIgnoreLayer := Layer;
  AviUtl2CursorMoveFrameFocus(Layer, Frame);
end;

function TSerifSceneMsgPanel.AddList(Msgs: TSerifSceneMsgList;
  ForceSend, ContinuousSend, RegisterOnly: Boolean): Boolean;
var
  i : Integer;
  aMsgs : TSerifSceneMsgListEx;
  Msg : TSerifSceneMsgItem;
  List : TSerifSceneMsgListEx;
  ShouldSend: Boolean;
begin
  Result := False;
  if FMsgs = nil then Exit;
  if FCharas = nil then Exit;

  aMsgs := TSerifSceneMsgListEx.Create;
  List := TSerifSceneMsgListEx.Create;
  try
    for i := 0 to Msgs.Count-1 do begin       // 登録するセリフ数ループ
      Msg := FMsgs.AddNew();                  // セリフリストに追加
      Msg.Assign(Msgs[i]);                    // 値を代入
      aMsgs.Add(Msg);                         // 参照リストにも追加
      Msg.SetUID;                             // UIDを割り当てる
      List.Add(Msg);                          //
    end;
    // 登録専用ではタイムラインへ触れず、未送信セリフとして一覧へ追加する。
    ShouldSend := (FAutoSend or ForceSend) and not RegisterOnly;
    if ShouldSend then begin
      if ContinuousSend then
        Result := AviUtl2SerifMsgsSendContinuous(FProjectFolder, aMsgs,
          FCharas, FConfig)
      else
        Result := AviUtl2SerifMsgsSendNow(FProjectFolder, aMsgs,
          FCharas, FConfig);
    end;
    if not ShouldSend then Result := True;
    if Result then
      FLbox.AddList(List)                     // 送信成功または登録専用なら一覧へ反映
    else
      for i := List.Count - 1 downto 0 do
        FMsgs.DeleteItem(List[i]);            // 作成失敗時は追加した内部データを戻す
  finally
    List.Free;
    aMsgs.Free;
  end;
end;

procedure TSerifSceneMsgPanel.View();
begin
  if FMsgs = nil then Exit;
  if FCharas = nil then Exit;
  FLbox.ShowList(FMsgs);
  FSelectMsg := GetSelectedMsg;
  NotifyAIUEOChange;
end;

procedure TSerifSceneMsgPanel.CharaAdd;
var
  i : Integer;
  Msg : TSerifSceneMsgItem;
begin
  i := FLbox.ItemIndex;
  if i = -1 then Exit;
  Msg := FMsgs[i];
  if Msg = nil  then Exit;

  FCharas.AddChara(Msg.Chara);

end;

procedure TSerifSceneMsgPanel.CursorUp;
var
  i : Integer;
begin
  i := FLbox.ItemIndex;
  if FLbox = nil then Exit;
  if FLbox.Count = 0 then Exit;
  // 一番上の位置では、開始より1つ前へカーソルを移動する
  if i = 0 then begin
    FSelectMsg := FMsgs.First;
    MoveCursorFocus(FSelectMsg.SerifLayer,0);
  end
  else begin
    FLbox.ItemIndex := FLbox.ItemIndex - 1;
    FSelectMsg := FMsgs[FLbox.ItemIndex];
    NotifyAIUEOChange;
    MoveCursorFocus(FSelectMsg.SerifLayer,FSelectMsg.FrameStart);
  end;
end;

procedure TSerifSceneMsgPanel.CursorDown;
var
  i : Integer;
  LastMsg: TSerifSceneMsgItem;
begin
  i := FLbox.ItemIndex;
  if FLbox = nil then Exit;
  if FLbox.Count = 0 then Exit;
  // 一番下の位置では、末尾より1つ後ろへカーソルを移動する
  if i >= FLbox.Count-1 then begin
    FSelectMsg := FMsgs.GetFrameNextMaxMsg;
    LastMsg := FSelectMsg;
    if LastMsg = nil then Exit;
    MoveCursorFocus(LastMsg.SerifLayer,LastMsg.FrameNext);
  end
  else begin
    FLbox.ItemIndex := FLbox.ItemIndex + 1;
    FSelectMsg := FMsgs[FLbox.ItemIndex];
    NotifyAIUEOChange;
    MoveCursorFocus(FSelectMsg.SerifLayer,FSelectMsg.FrameStart);
  end;
end;

procedure TSerifSceneMsgPanel.CursorMoveFirst;
begin
  //if FMsgs = nil then Exit;
  //if FMsgs.Count = 0 then Exit;
  //layer := AviUtl2CursorGetLayer;

  //FSelectMsg := FMsgs.First;                 // 選択セリフを先頭へ
  // カーソル位置へフォーカス
  AviUtl2CursorMoveFrame(0);
end;

procedure TSerifSceneMsgPanel.CursorMoveLast;
var
  LastMsg: TSerifSceneMsgItem;
begin
  if FMsgs = nil then Exit;
  if FMsgs.Count = 0 then Exit;
  FSelectMsg := FMsgs.GetFrameNextMaxMsg;
  LastMsg := FSelectMsg;
  if LastMsg = nil then Exit;
  // カーソル位置へフォーカス
  MoveCursorFocus(LastMsg.SerifLayer,LastMsg.FrameNext);
end;

procedure TSerifSceneMsgPanel.ItemEdit;
begin
  FLbox.BeginEdit;
end;

procedure TSerifSceneMsgPanel.ItemEnterPosNext;
begin
  FLbox.ItemEnterPosNext();
  AviUtlSetValue();
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemEnterPosPrev;
begin
  FLbox.ItemEnterPosPrev();
  AviUtlSetValue();
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemEnterSelNext;
begin
  FLbox.ItemEnterSelNext();
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemEnterSelPrev;
begin
  FLbox.ItemEnterSelPrev();
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemLeft;
var
  frame : Integer;
  Msg : TSerifSceneMsgItem;
begin
  if FSelectMsg = nil then Exit;

  Msg := FSelectMsg;
  frame := Msg.FrameStart-10;
  if frame < 0 then frame := 0;

  AviUtl2SerifMove(Msg.SerifLayer,frame,Msg.SerifLayer,Msg.FrameStart);
  AviUtl2SerifMove(Msg.WaveLayer,frame,Msg.WaveLayer,Msg.FrameStart);
  Msg.FrameMove(frame);

  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemLeftAll;
var
  i,frame : Integer;
  f : Boolean;
  Msg : TSerifSceneMsgItem;
begin
  if FSelectMsg = nil then Exit;
  // 選択位置から末尾セリフまでを前へ詰める
  f := False;
  for i := 0 to FMsgs.Count-1 do begin
    Msg := FMsgs[i];
    if FSelectMsg = Msg then f := True;
    if not f then Continue;

    frame := Msg.FrameStart-10;
    if frame < 0 then frame := 0;

    AviUtl2SerifMove(Msg.SerifLayer,frame,Msg.SerifLayer,Msg.FrameStart);
    AviUtl2SerifMove(Msg.WaveLayer,frame,Msg.WaveLayer,Msg.FrameStart);
    Msg.FrameMove(frame);
  end;
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemRight;
var
  Msg : TSerifSceneMsgItem;
begin
  if FSelectMsg = nil then Exit;

  Msg := FSelectMsg;
  AviUtl2SerifMove(Msg.SerifLayer,Msg.FrameStart+10,Msg.SerifLayer,Msg.FrameStart);
  AviUtl2SerifMove(Msg.WaveLayer,Msg.FrameStart+10,Msg.WaveLayer,Msg.FrameStart);
  Msg.FrameMove(Msg.FrameStart + 10);

  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemRightAll;
var
  i : Integer;
  Msg : TSerifSceneMsgItem;
begin
  if FSelectMsg = nil then Exit;
  // 選択位置までのセリフを後ろへずらす
  for i := FMsgs.Count-1 downto 0 do begin
    Msg := FMsgs[i];
    AviUtl2SerifMove(Msg.SerifLayer,Msg.FrameStart+10,Msg.SerifLayer,Msg.FrameStart);
    AviUtl2SerifMove(Msg.WaveLayer,Msg.FrameStart+10,Msg.WaveLayer,Msg.FrameStart);
    Msg.FrameMove(Msg.FrameStart + 10);
    if FSelectMsg = Msg then Break;
  end;
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemUp;
begin
  FLbox.ItemUp;
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemVoice(Voice: string);
begin
  if FSelectMsg = nil then
    FSelectMsg := GetSelectedMsg;
  if FSelectMsg = nil then Exit;

  ItemVoiceStr(FSelectMsg.AIUEO + Voice);
end;

procedure TSerifSceneMsgPanel.ItemVoiceClear;
begin
  ItemVoiceStr('');
end;

procedure TSerifSceneMsgPanel.ItemVoiceA;
begin
  ItemVoice('a');
end;

procedure TSerifSceneMsgPanel.ItemVoiceBackSpace;
var
  Msg: TSerifSceneMsgItem;
  S: string;
begin
  Msg := GetSelectedMsg;
  if Msg = nil then Exit;

  S := Msg.AIUEO;
  if S = '' then
  begin
    NotifyAIUEOChange;
    Exit;
  end;

  Delete(S, Length(S), 1);
  ItemVoiceStr(S);
end;

procedure TSerifSceneMsgPanel.ItemVoiceI;
begin
  ItemVoice('i');
end;

procedure TSerifSceneMsgPanel.ItemVoiceU;
begin
  ItemVoice('u');
end;

procedure TSerifSceneMsgPanel.ItemVoiceE;
begin
  ItemVoice('e');
end;

procedure TSerifSceneMsgPanel.ItemVoiceO;
begin
  ItemVoice('o');
end;

procedure TSerifSceneMsgPanel.ItemVoiceN;
begin
  ItemVoice('n');
end;

procedure TSerifSceneMsgPanel.ItemVoiceStr(const Value: string);
var
  Msg: TSerifSceneMsgItem;
begin
  Msg := GetSelectedMsg;
  if Msg = nil then Exit;

  if Msg.AIUEO = Value then
  begin
    NotifyAIUEOChange;
    Exit;
  end;

  Msg.AIUEO := Value;
  FSelectMsg := Msg;
  FLbox.Invalidate;
  AviUtlSetAiueo;
  NotifyAIUEOChange;
  DoChange();
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemDelete;
var
  i : Integer;
  s : string;
  Msg : TSerifSceneMsgItem;
begin
  for i := FMsgs.Count-1 downto 0 do begin
    if not FLbox.Selected[i] then Continue;
    Msg := FMsgs[i];
    s := AviUtl2SerifGetValue(Msg.SerifLayer,Msg.FrameStart);
    s := AvrUtl2_AviUtlToStr(s);
    if Msg.Voice = s then begin                               // AviUtl2のセリフと一致する場合
      AviUtl2SerifDelete(Msg.SerifLayer,Msg.FrameStart);      // セリフオブジェクト削除
      AviUtl2SerifDelete(Msg.WaveLayer ,Msg.FrameStart);      // セリフ音声削除
      FMsgs[i].DeleteItemFile(FProjectFolder);                  // 音声データを削除
    end;
    FMsgs.Delete(i);                                          // 管理しているデータを削除
    FLbox.Items.Delete(i);                                    // リストから削除
  end;
  SaveDelayMsgs();                                            // 遅延保存
end;


procedure TSerifSceneMsgPanel.ItemEmotionClear;
var
  Msg: TSerifSceneMsgItem;
begin
  Msg := GetSelectedMsg;
  if Msg = nil then Exit;

  // 感情指定を外して未設定状態に戻す
  Msg.Emotion := '';
  FLbox.Invalidate;
  DoChange();
  SaveDelayMsgs();
  // AviUtl2の演出に書き込む
  AviUtlSetEmotion;
end;

procedure TSerifSceneMsgPanel.ItemEmotionPrev;
var
  Msg: TSerifSceneMsgItem;
begin
  Msg := GetSelectedMsg;
  if Msg = nil then Exit;

  // 感情指定を逆順に進める
  Msg.EmotionPrev;

  FLbox.Invalidate;
  DoChange();
  SaveDelayMsgs();
  // AviUtl2の演出に書き込む
  AviUtlSetEmotion;
end;

procedure TSerifSceneMsgPanel.ItemEmotionNext;
var
  Msg: TSerifSceneMsgItem;
begin
  Msg := GetSelectedMsg;
  if Msg = nil then Exit;

  // 感情指定を順に進める
  Msg.EmotionNext;

  FLbox.Invalidate;
  DoChange();
  SaveDelayMsgs();
  // AviUtl2の演出に書き込む
  AviUtlSetEmotion;
end;


procedure TSerifSceneMsgPanel.ItemDirectionClear;
var
  Msg: TSerifSceneMsgItem;
begin
  Msg := GetSelectedMsg;
  if Msg = nil then Exit;

  // 演出指定を外して未設定状態に戻す
  Msg.Direction := 'なし';
  FLbox.Invalidate;
  DoChange();
  SaveDelayMsgs();
  // AviUtl2の演出に書き込む
  AviUtlSetDirection;
end;

procedure TSerifSceneMsgPanel.ItemDirectionPrev;
var
  Msg: TSerifSceneMsgItem;
  Index: Integer;
begin
  Msg := GetSelectedMsg;
  if Msg = nil then Exit;

  // 現在の演出位置を1つ前へ戻し、先頭なら未設定にする
  Index := FindDirectionIndex(Msg.Direction);
  if Index < 0 then
    Index := High(SerifDirectionNames)
  else if Index = Low(SerifDirectionNames) then
    Index := High(SerifDirectionNames)
  else
    Dec(Index);

  if Index >= 0 then
    Msg.Direction := SerifDirectionNames[Index];

  FLbox.Invalidate;
  DoChange();
  SaveDelayMsgs();
  // AviUtl2の演出に書き込む
  AviUtlSetDirection;
end;

procedure TSerifSceneMsgPanel.ItemDirectionNext;
var
  Msg: TSerifSceneMsgItem;
  Index: Integer;
begin
  Msg := GetSelectedMsg;
  if Msg = nil then Exit;

  // 現在の演出位置を1つ先へ進め、未設定なら先頭から始める
  Index := FindDirectionIndex(Msg.Direction);
  if Index < 0 then
    Index := Low(SerifDirectionNames)
  else if Index >= High(SerifDirectionNames) then
    Index := Low(SerifDirectionNames)
  else
    Inc(Index);

  Msg.Direction := SerifDirectionNames[Index];

  FLbox.Invalidate;
  DoChange();
  SaveDelayMsgs();
  // AviUtl2の演出に書き込む
  AviUtlSetDirection;
end;

procedure TSerifSceneMsgPanel.ItemDown;
var
  i : Integer;
  //Msg1,Msg2,Msgt : TSerifSceneMsgItem;
begin
  i := FLbox.ItemIndex;
  if i = -1 then Exit;
  if i >= FMsgs.Count-1 then Exit;
  //Msg1 := FMsgs[i];
  //Msg2 := FMsgs[i+1];
  //Msgt := FMsgs.Last;
  //TmpFrame := Msgt.FrameStart + 30 * 10;

  FLbox.ItemDown;
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemSelectAll;
begin
  FLbox.SelectAll;
end;

procedure TSerifSceneMsgPanel.ItemSelectClear;
begin
  FLbox.ItemSelectClear;
end;

procedure TSerifSceneMsgPanel.ItemSend;
var
  Msgs : TSerifSceneMsgListEx;
  i : Integer;
begin
  Msgs := TSerifSceneMsgListEx.Create;
  try
    for i := 0 to FLbox.Items.Count-1 do begin
      if FLbox.Selected[i] then Msgs.Add(FMsgs[i]);
    end;
    // 複数選択がある場合は選択対象を送信する
    if Msgs.Count > 0 then begin
      AviUtl2SerifMsgsSend(FProjectFolder,Msgs,FCharas,FConfig,True);
      Exit;
    end;

    i := FLbox.ItemIndex;
    if i = -1 then Exit;

    Msgs.Add(FMsgs[i]);
    AviUtl2SerifMsgsSend(FProjectFolder,Msgs,FCharas,FConfig,True);
    FLbox.ClearSelection;
    Inc(i);
    if i < FLbox.Items.Count then begin
      FLbox.ItemIndex := i;
      FLbox.TopIndex := i;
    end;

    DoChange();
  finally
    Msgs.Free;
  end;
end;

procedure TSerifSceneMsgPanel.ItemSendAll;
var
  i : Integer;
  Msgs : TSerifSceneMsgListEx;
  Msg : TSerifSceneMsgItem;
begin
  Msgs := TSerifSceneMsgListEx.Create;
  try
    for i := 0 to FMsgs.Count-1 do begin
      Msgs.Add(FMsgs[i]);
    end;

    AviUtl2SerifMsgsSend(FProjectFolder,Msgs,FCharas,FConfig,True);

    for i := 0 to FMsgs.Count-1 do begin
      Msg := Msgs[i];
      FMsgs[i].FrameStart := Msg.FrameStart;
      FMsgs[i].FrameEnd := Msg.FrameEnd;
      FMsgs[i].FrameNext := Msg.FrameNext;
    end;

    DoChange();
  finally
    Msgs.Free;
  end;
end;

procedure TSerifSceneMsgPanel.ItemToggleExclamation;
begin
  FLbox.ItemToggleExclamation();
  AviUtlSetValue();
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.ItemToggleQuestion;
begin
  FLbox.ItemToggleQuestion();
  // AviUtl2のセリフに書き込む
  AviUtlSetValue();
  // 遅延保存
  SaveDelayMsgs();
end;

procedure TSerifSceneMsgPanel.OnDrag(Sender: TObject; FileNames: TStringList);
var
  i : Integer;
  s : string;
  Msgs : TSerifSceneMsgListEx;
begin
  Msgs := TSerifSceneMsgListEx.Create;
  try
    for i := 0 to FLbox.Items.Count-1 do begin
      if not IsMsgSelect(i) then Continue;
      Msgs.Add(FMsgs[i]);
    end;
    s := AviUtl2SerifMsgsSend(FProjectFolder,Msgs,FCharas,FConfig,False);
  finally
    Msgs.Free;
  end;
  FileNames.Clear;
  FileNames.Add(s);
end;

procedure TSerifSceneMsgPanel.OnListBoxClick(Sender: TObject);
var
  i : Integer;
begin
  i := FLbox.ItemIndex;
  if i = -1 then Exit;
  FSelectMsg := FMsgs[i];
  NotifyAIUEOChange;
  // 表情遅延を無効にする
  NotifySerifHostVisualRefresh;
  // 未送信セリフには確定したレイヤー・フレーム位置がない。
  if not FSelectMsg.IsOutput then Exit;
  MoveCursorFocus(FSelectMsg.SerifLayer,FSelectMsg.FrameStart);
end;

procedure TSerifSceneMsgPanel.OnListBoxRequestMeasure(Sender: TObject; const Index: Integer; var str: string);
begin
  str := FMsgs[Index].Voice;
end;

procedure TSerifSceneMsgPanel.OnListDblClick(Sender: TObject);
begin
  FLbox.BeginEdit();
end;

procedure TSerifSceneMsgPanel.OnListEdited(Sender: TObject);
begin
  DoChange();
  AviUtlSetValue();
end;

procedure TSerifSceneMsgPanel.OnListKeyDown(Sender: TObject;var Key: Word; Shift: TShiftState);
begin
  FShortcuts.KeyDown(Key,Shift);
end;

procedure TSerifSceneMsgPanel.OnListKeyPress(Sender: TObject; var Key: Char);
begin
  FShortcuts.ProcessKeyPress(Key);
end;

procedure TSerifSceneMsgPanel.OnListRequestChara(Sender: TObject;
  const Index: Integer; var aChara: string; var aColorLight, aColorBase,
  aColorDark: TColor);
var
  i : Integer;
  Msg : TSerifSceneMsgItem;
  Chara : TSerifCharaItem;
begin
  i := Index;
  if i = -1 then Exit;
  Msg := FMsgs[i];
  if Msg = nil then Exit;
  i := FCharas.IndexOfKeyword(Msg.Chara);
  if i = -1 then Exit;
  Chara := FCharas[i];
  if Chara = nil then Exit;
  // 3色化フェーズ4: セリフ一覧の配役帯へ Light/Base/Dark を渡す。
  aColorLight := Chara.ColorLight;
  aColorBase := Chara.ColorBase;
  aColorDark := Chara.ColorDark;
end;

procedure TSerifSceneMsgPanel.SaveDelayMsgs();
begin
  FTimerKeySave.Enabled := False;
  FTimerKeySave.Enabled := True;
end;

procedure TSerifSceneMsgPanel.SerifSync;
var
  i,idx,Count,Layer,Frame,FrameS,FrameE: Integer;
  Msg, SelectedMsg: TSerifSceneMsgItem;       // 選択復元用に同期前のセリフを保持
  uid : string;
  Layers: TList<Integer>;
  Changed, Sorted: Boolean;                   // 同期更新と並び替えの発生状態
begin
  if FMsgs = nil then Exit;                  // リストが無い場合未処理
  if FLbox.IsEditing then Exit;               // 編集中の並び替え事故を避ける

  Changed := False;                           // フレーム同期変更フラグを初期化
  Sorted := False;                            // 並び替え変更フラグを初期化
  SelectedMsg := GetSelectedMsg;              // Indexではなくセリフ実体で選択を保持

  Layers := TList<Integer>.Create;           // 使用レイヤー管理リスト
  try
    for i := 0 to FMsgs.Count - 1 do begin   // セリフ数ループ
      Msg := FMsgs[i];                       // セリフ参照
      if Msg = nil then Continue;            // セリフの実態が無い場合次へ
      Layer := Msg.SerifLayer;               // セリフのレイヤー位置参照
      if not Layers.Contains(Layer) then Layers.Add(Layer);  // リストに無ければ登録
      //if not Layers.Contains(Msg.WaveLayer) then Layers.Add(Msg.WaveLayer);
    end;

    for i := 0 to Layers.Count-1 do begin                               // 使用レイヤー数ループ
      Layer := Layers[i];                                               // レイヤー参照
      Frame := 0;                                                       // 探索開始フレーム位置
      Count := 1000;                                                    // 最大ループ回数
      while AviUtl2FindObjectNext(Layer,Frame,FrameS,FrameE) do begin   // オブジェクトが見つかった場合
        uid := AviUtl2SerifGetUID(Layer,FrameS);                        // UIDを取得
        Frame := FrameE + 1;                                            // 次の探索位置を終了フレーム位置+1
        Dec(Count);                                                     // ループカウントダウン
        if Count < 0 then Break;                                        // 永久ループ防止

        if uid = '' then Continue;                                      // UIDが無い場合処理しない
        idx := FMsgs.IndexOfUID(uid);                                   // UIDからセリフを探索
        if idx = -1 then Continue;                                      // 存在しない場合処理しない
        Msg := FMsgs[idx];                                              // セリフクラス参照
        if (Msg.FrameStart <> FrameS) or
           (Msg.FrameEnd <> FrameE) or
           (Msg.FrameNext <> FrameE + Msg.FrameSpaceE) then
          Changed := True;                                             // AviUtl側との差分がある
        Msg.FrameStart  := FrameS;                                      // セリフ開始位置を同期
        Msg.FrameEnd    := FrameE;                                      // セリフ終了位置を同期
        Msg.FrameNext   := Msg.FrameEnd + Msg.FrameSpaceE;              // 空白を開けて次のフレーム位置にする
      end;
    end;

    Sorted := FLbox.SortByTimeline;                                     // 開始フレームとレイヤー順で表示を整列
    if Sorted and (SelectedMsg <> nil) then
    begin
      idx := FMsgs.IndexOf(SelectedMsg);                                // 並び替え後の選択セリフ位置を探す
      if idx <> -1 then
      begin
        FLbox.ItemIndex := idx;                                         // 選択セリフを再選択する
        FLbox.TopIndex := idx;                                          // 選択セリフが見える位置へスクロール
        FSelectMsg := SelectedMsg;                                      // 現在選択中セリフを復元
        NotifyAIUEOChange;                                              // 母音表示を選択セリフに合わせる
      end;
    end
    else if Sorted then
      FLbox.ItemSelectClear;                                            // 選択セリフが無い場合は複数選択を解除

    if Changed or Sorted then
      SaveDelayMsgs;                                                    // フレーム同期または整列結果を保存対象にする

  finally
    Layers.Free;
  end;
end;

procedure TSerifSceneMsgPanel.NotifyAIUEOChange;
var
  Msg: TSerifSceneMsgItem;
  S: string;
begin
  S := '';
  Msg := GetSelectedMsg;
  if Msg <> nil then S := Msg.AIUEO;
  if Assigned(FOnAIUEOChange) then FOnAIUEOChange(Self, S);
end;

procedure TSerifSceneMsgPanel.ShowIndexLast();
begin
  FLbox.ItemIndex := FLbox.Items.Count-1;
  FSelectMsg := GetSelectedMsg;
  NotifyAIUEOChange;
end;

function TSerifSceneMsgPanel.IsMsgSelect(const Index : Integer) : Boolean;
var
  f : Boolean;
begin
  Result := False;
  f := False;
  if Index < 0 then Exit;
  if Index >= FLbox.Items.Count then Exit;
  // カーソル位置も選択状態として扱う
  if FLbox.Selected[Index] then f := True;
  if FLbox.ItemIndex = Index then f := True;
  Result := f;
end;

procedure TSerifSceneMsgPanel.DoChange();
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TSerifSceneMsgPanel.DoCharaChange();
begin
  if Assigned(FOnCharaChange) then FOnCharaChange(Self);
end;

end.






