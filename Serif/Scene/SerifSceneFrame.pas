unit SerifSceneFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,SerifSceneList,
  Vcl.ExtCtrls, Vcl.StdCtrls,SerifSceneMsgFrame,SerifCharaList,
  SerifWatcherList,SerifSceneMsgList,SerifConfig,RTTIPersistentFrame,
  DarkComboBox, DarkPanel;

type
  TFrameSerifSceneBound = class(TRTTIFrame)
  private
    FSceneIndex  : Integer;    // 0..99 0:Root 1:シーン1
  public
    constructor Create;
    // フォームの座標情報をデータ化
    procedure FrameToSelf(AFrame : TFrame);override;
    // データをフォームの情報に復元
    procedure SelfToFrame(AFrame : TFrame);override;
  published
    property SceneIndex : Integer read FSceneIndex write FSceneIndex;
  end;

type
  TFrameSerifSceneCursorFocusEvent = TFrameSerifSceneMsgCursorFocusEvent;

type
  TFrameSerifScene = class(TFrame)
    PanelTab: TDarkPanel;
    ComboScene: TDarkComboBox;
    procedure ComboSceneChange(Sender: TObject);
  private
    { Private 宣言 }
    FBound         : TFrameSerifSceneBound;             // Windows位置とサイズ記憶クラス
    FScenes        : TSerifSceneList;              // リーンリスト
    FCharas        : TSerifCharaList;              // 配役リスト
    FWatchers      : TSerifWatcherList;            // 音声合成アプリ監視
    FConfig        : TSerifConfigItem;             // 設定クラス

    FSelectScene   : TSerifSceneItem;            // 表示中のシーン
    FProjectFolder : string;

    FFrameMsgs     : TFrameSerifSceneMsg;

    FOnChange      : TNotifyEvent;
    FOnCharaChange : TNotifyEvent;
    FOnMoveCursorFocus: TFrameSerifSceneCursorFocusEvent;
    procedure PopulateSceneCombo;
    procedure SelectSceneByIndex(const SceneIndex: Integer; SaveSelection: Boolean);
    // セリフ変更イベント
    procedure OnMsChange(Sender: TObject);
    // セリフから配役追加イベント
    procedure OnMsCharaChange(Sender: TObject);
    procedure OnMsMoveCursorFocus(Sender: TObject; Layer, Frame: Integer);
    procedure SetAutoSend(const Value: Boolean);
  protected
    procedure DoChange();virtual;
    procedure DoCharaChange();virtual;
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    // シーン選択欄の文字・高さ・余白を現在DPIへ合わせる。
    procedure ApplyDpi;
    procedure ShowList(const ProjectFolder : string;Scenes : TSerifSceneList;Charas : TSerifCharaList;Watchers  : TSerifWatcherList;Config : TSerifConfigItem);
    // 表示中の台本と選択シーンへの参照を解除する。
    procedure CloseList;
    // 表示中の情報を更新
    procedure View();
    // Voice を指定位置で 1 回だけ改行する（0 は改行なし）
    procedure SetLinePosition(LineIndex: Integer);
    // セリフ追加
    function AddsMsg(Msgs : TSerifSceneMsgList; ForceSend: Boolean = False;
      ContinuousSend: Boolean = False;
      RegisterOnly: Boolean = False) : Boolean;

    // シーンを変更する
    procedure SceneChange(SceneID: Integer);
    // 指定されたフレーム　レイヤーのセリフをアクティブに
    procedure ActiveSerif(frame,layerTxt,layerWav : Integer;UID : string);
    // アクティブ時に1回発火するイベント　※以降は選択オブジェクト変化で
    procedure FrameActive;
    // 表示中シーンのセリフ終了位置へカーソルを移動する。
    procedure CursorMoveLast;

    property SelectScene : TSerifSceneItem read FSelectScene;
    // True:AviUtl2へ自動送信
    property AutoSend : Boolean write SetAutoSend;

    property OnChange  : TNotifyEvent  read FOnChange write FOnChange;
    property OnCharaChange  : TNotifyEvent  read FOnCharaChange write FOnCharaChange;
    property OnMoveCursorFocus : TFrameSerifSceneCursorFocusEvent read FOnMoveCursorFocus write FOnMoveCursorFocus;
  end;

implementation

{$R *.dfm}

uses AppFolderUtils,AviUtl2PluginScene,AviUtl2StyleColors;

{ TFrameSerifScene }

procedure TFrameSerifScene.ApplyDpi;
begin
  ComboScene.ApplyDpi;
  PanelTab.ApplyDpi;
  PanelTab.Padding.SetBounds(
    MulDiv(6, CurrentPPI, 96),
    MulDiv(3, CurrentPPI, 96),
    MulDiv(6, CurrentPPI, 96),
    MulDiv(3, CurrentPPI, 96));
end;

procedure TFrameSerifScene.CursorMoveLast;
begin
  if Assigned(FFrameMsgs) then FFrameMsgs.CursorMoveLast;
end;

procedure TFrameSerifScene.CloseList;
begin
  FSelectScene := nil;
  FProjectFolder := '';
  FScenes := nil;
  FCharas := nil;
  FWatchers := nil;
  FConfig := nil;
  ComboScene.ItemIndex := -1;
  FFrameMsgs.CloseList;
end;

constructor TFrameSerifScene.Create(AOwner: TComponent);
begin
  inherited;
  Color := A2SCPanelBackground;
  FBound  := TFrameSerifSceneBound.Create;
  FBound.Filename  := GetAppFolder('Serif') +  'SerifSceneFrame.ini';       // Windows状態保存ファイル名設定
  FBound.LoadFromFile;

  FFrameMsgs := TFrameSerifSceneMsg.Create(Self);
  FFrameMsgs.Parent := Self;
  FFrameMsgs.Align := alClient;
  FFrameMsgs.OnChange := OnMsChange;
  FFrameMsgs.OnCharaChange := OnMsCharaChange;
  // 2026-04: MsgFrame のカーソル移動通知を SerifFrame 側へ中継する
  FFrameMsgs.OnMoveCursorFocus := OnMsMoveCursorFocus;
end;

destructor TFrameSerifScene.Destroy;
begin
  FBound.FrameToSelf(Self);                          // フォームの状態をデータ化
  FBound.SaveToFile;
  FFrameMsgs.Free;
  FBound.Free;
  inherited;
end;

procedure TFrameSerifScene.ShowList(const ProjectFolder : string;Scenes: TSerifSceneList;Charas : TSerifCharaList;Watchers  : TSerifWatcherList;Config : TSerifConfigItem);
var
  i : Integer;
  f : Boolean;
  Item : TSerifSceneItem;
begin
  FBound.SelfToFrame(Self);
  ApplyDpi;

  FProjectFolder := ProjectFolder;
  FScenes        := Scenes;
  FCharas        := Charas;
  FWatchers      := Watchers;
  FConfig        := Config;

  f := False;
  while FScenes.Count < 100 do begin
    Item := FScenes.AddNew();                     // シーンを追加
    if FScenes.Count = 1 then begin
      Item.Name := 'Root';
    end
    else begin
      Item.Name := Format('%.2d', [FScenes.Count-1]); // 00～99
    end;
  end;
  if f then FScenes.SaveToFile;

  PopulateSceneCombo;

  // 台本の再読込では現在選択を維持し、初回だけ保存値を使用する。
  i := ComboScene.ItemIndex;
  if i < 0 then i := FBound.SceneIndex;
  if i < 0 then i := 0;
  if i >= FScenes.Count then i := FScenes.Count - 1;
  SelectSceneByIndex(i, False);
end;

procedure TFrameSerifScene.View;
begin
  if FSelectScene = nil then Exit;

  FFrameMsgs.View();
end;

procedure TFrameSerifScene.SceneChange(SceneID: Integer);
var
  i: Integer;
begin
  i := SceneID;
  if i = -1 then Exit;
  if i < 0 then Exit;
  if FScenes = nil then Exit;

  if i >= FScenes.Count then Exit;
  SelectSceneByIndex(i, True);
end;



procedure TFrameSerifScene.ActiveSerif(frame, layerTxt, layerWav: Integer;UID : string);
begin
  FFrameMsgs.ActiveSerif(frame,layerTxt,layerWav,UID);
end;

function TFrameSerifScene.AddsMsg(Msgs: TSerifSceneMsgList;
  ForceSend, ContinuousSend, RegisterOnly: Boolean): Boolean;
begin
  Result := False;
  if FSelectScene = nil then Exit;
  Result := FFrameMsgs.AddList(Msgs, ForceSend, ContinuousSend,
    RegisterOnly);
end;


procedure TFrameSerifScene.DoChange;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TFrameSerifScene.DoCharaChange;
begin
  if Assigned(FOnCharaChange) then FOnCharaChange(Self);
end;

procedure TFrameSerifScene.FrameActive;
begin
  FFrameMsgs.FrameActive;
end;

procedure TFrameSerifScene.OnMsChange(Sender: TObject);
begin
  DoChange();
end;

procedure TFrameSerifScene.OnMsCharaChange(Sender: TObject);
begin
  DoCharaChange();
end;

procedure TFrameSerifScene.OnMsMoveCursorFocus(Sender: TObject; Layer,
  Frame: Integer);
begin
  // 2026-04: ガード要求を SerifFrame 側へ受け渡す
  if Assigned(FOnMoveCursorFocus) then
    FOnMoveCursorFocus(Self, Layer, Frame);
end;

procedure TFrameSerifScene.PopulateSceneCombo;
var
  I: Integer;
begin
  if ComboScene.Items.Count = 100 then Exit;
  ComboScene.Items.BeginUpdate;
  try
    ComboScene.Items.Clear;
    ComboScene.Items.Add('Root');
    for I := 1 to 99 do
      ComboScene.Items.Add('シーン' + I.ToString);
  finally
    ComboScene.Items.EndUpdate;
  end;
end;

procedure TFrameSerifScene.SelectSceneByIndex(const SceneIndex: Integer;
  SaveSelection: Boolean);
begin
  if not Assigned(FScenes) then Exit;
  if (SceneIndex < 0) or (SceneIndex >= FScenes.Count) then Exit;

  ComboScene.ItemIndex := SceneIndex;
  FSelectScene := FScenes[SceneIndex];
  if FSelectScene = nil then Exit;
  FFrameMsgs.ShowList(FProjectFolder,FSelectScene.Msgs,FCharas,FConfig);

  FBound.SceneIndex := SceneIndex;
  if SaveSelection then FBound.SaveToFile;
end;

procedure TFrameSerifScene.ComboSceneChange(Sender: TObject);
begin
  SelectSceneByIndex(ComboScene.ItemIndex, True);
end;

procedure TFrameSerifScene.SetAutoSend(const Value: Boolean);
begin
  FFrameMsgs.AutoSend := Value;
end;

procedure TFrameSerifScene.SetLinePosition(LineIndex: Integer);
begin
  if FSelectScene = nil then Exit;
  FSelectScene.Msgs.SetLinePosition(LineIndex);
end;




{ TFrameSerifSceneBound }

constructor TFrameSerifSceneBound.Create;
begin

end;

procedure TFrameSerifSceneBound.FrameToSelf(AFrame: TFrame);
begin
  inherited;

end;

procedure TFrameSerifSceneBound.SelfToFrame(AFrame: TFrame);
begin
  inherited;

end;

end.



