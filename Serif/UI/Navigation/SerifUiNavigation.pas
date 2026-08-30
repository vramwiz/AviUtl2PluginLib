unit SerifUiNavigation;

interface

uses Vcl.ComCtrls, Vcl.ExtCtrls, ToolBarPanelManager, SerifSceneList,
     SerifCharaList, SerifWatcherList, SerifConfig, SerifSceneFrame,
     SerifVoicevoxSimpleInputFrame, SerifCharaListFrame, SerifConfigFrame,
     SerifWatcherFrame, SerifAliasFrame, SerifBoardFrame;

// Serif画面のページパネル順と共通ツールバー配色を設定する。
function CreateSerifToolbarManager(const Panels: array of TPanel;
  OnChange: TToolBarPanelChangeEvent): TToolBarPanelManager;

// プロジェクト有無に応じて通常ページのボタンを一括表示・非表示にする。
procedure SetSerifTabButtonsVisible(const Buttons: array of TToolButton;
  const Visible: Boolean);

// 選択ページに必要なデータ表示と未確定入力の確定を行う。
procedure ActivateSerifPage(const Index: Integer; const ProjectFolder: string;
  Scenes: TSerifSceneList; Charas: TSerifCharaList;
  Watchers: TSerifWatcherList; Config: TSerifConfigItem;
  InputFrame: TFrameSerifVoicevoxSimpleInput;
  SceneFrame: TFrameSerifScene; CharaFrame: TFrameSerifCharaList;
  ConfigFrame: TFrameSerifConfig; WatcherFrame: TFrameSerifWatcher;
  AliasFrame: TFrameSerifAlias; BoardFrame: TFrameSerifBoard);

// ページが変化した時だけメイン画面の操作ヒントを更新する。
procedure ShowSerifPageHint(const Index: Integer; var PreviousIndex: Integer);

implementation

uses System.SysUtils, AviUtl2StyleColors, MainToolInfoService,
     SerifVoicevoxDebugLog;

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

function CreateSerifToolbarManager(const Panels: array of TPanel;
  OnChange: TToolBarPanelChangeEvent): TToolBarPanelManager;
var
  I: Integer;
begin
  Result := TToolBarPanelManager.Create;
  Result.ToolBarBackgroundColor := A2SCToolBarBackground;
  Result.ToolBarFontColor := A2SCToolBarFont;
  Result.ToolBarCheckedColor := A2SCToolBarChecked;
  Result.ToolBarPressedColor := A2SCToolBarPressed;
  Result.ToolBarHotColor := A2SCToolBarHot;
  Result.ShowCaptions := False;
  Result.OnChange := OnChange;
  for I := Low(Panels) to High(Panels) do Result.AddPanel(Panels[I]);
end;

procedure SetSerifTabButtonsVisible(const Buttons: array of TToolButton;
  const Visible: Boolean);
var
  I: Integer;
begin
  for I := Low(Buttons) to High(Buttons) do Buttons[I].Visible := Visible;
end;

procedure ActivateSerifPage(const Index: Integer; const ProjectFolder: string;
  Scenes: TSerifSceneList; Charas: TSerifCharaList;
  Watchers: TSerifWatcherList; Config: TSerifConfigItem;
  InputFrame: TFrameSerifVoicevoxSimpleInput;
  SceneFrame: TFrameSerifScene; CharaFrame: TFrameSerifCharaList;
  ConfigFrame: TFrameSerifConfig; WatcherFrame: TFrameSerifWatcher;
  AliasFrame: TFrameSerifAlias; BoardFrame: TFrameSerifBoard);
begin
  VoicevoxDebugLog(Format('SerifFrame.OnToolBarChange index=%d input_expanded=%s',
    [Index, BoolToStr(Assigned(InputFrame) and InputFrame.Expanded, True)]));
  if (Index <> 0) and Assigned(InputFrame) then InputFrame.CommitPendingEdit;
  case Index of
    0: SceneFrame.ShowList(ProjectFolder, Scenes, Charas, Watchers, Config);
    1: CharaFrame.ShowList(Charas);
    2:
      begin
        ConfigFrame.ShowItem(Config);
        WatcherFrame.ShowList(Watchers);
      end;
    4: AliasFrame.ShowList;
    5: BoardFrame.ShowBoard;
  end;
end;

procedure ShowSerifPageHint(const Index: Integer; var PreviousIndex: Integer);
begin
  if Index = PreviousIndex then Exit;
  PreviousIndex := Index;
  case Index of
    0: ShowMainToolInfo('リストからセリフを選択し編集や削除するとAviUtl2へ同期します。D&&Dでもセリフを送れます');
    1: ShowMainToolInfo('キャラ毎に出力先レイヤーを指定すると流し込み先のレイヤーになります');
    2: ShowMainToolInfo('改行位置、セリフ間隔、音声合成ソフトの監視フォルダを設定します');
    3: ShowMainToolInfo('リストの「新セリフ表示」をAviUtl2へD&&Dします');
    4: ShowMainToolInfo('セリフ表示オブジェクトをAviUtl2へ送信します。参照レイヤーにセリフがあると表示します');
    5: ShowMainToolInfo('3分待つと表示されます。セリフの背景枠をAviUtl2へ送信します。同期を有効にするとセリフがあるときに表示します');
    6: ShowMainToolInfo('VOICEROId AI.Voiceeなど「＞」でキャラ名を指定するアプリでテキストから「＞」付きのテキストが生成できます');
    7: ShowMainToolInfo('動画1本毎に台本を1つ作ります。コピーするとセリフ以外の設定が引き継がれるので便利です');
  end;
end;

end.
