// セリフを編集するフレーム
unit SerifSceneMsgFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Types,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus,
  System.ImageList, Vcl.ImgList, Vcl.ComCtrls, Vcl.ToolWin,ToolbarButtons,
  SerifSceneMsgPanel,SerifSceneMsgList,SerifCharaList,SerifConfig;

type
  TFrameSerifSceneMsgCursorFocusEvent = TSerifSceneMsgPanelCursorFocusEvent;

type
  TFrameSerifSceneMsg = class(TFrame)
    MenuPop: TPopupMenu;
    MenuSeenMove: TMenuItem;
    MenuDel: TMenuItem;
    MenuSelectAll: TMenuItem;
    N2: TMenuItem;
    MenuSendAll: TMenuItem;
    N3: TMenuItem;
    MenuItemUp: TMenuItem;
    MenuItemDown: TMenuItem;
    TimerKeySave: TTimer;
    ImageList1: TImageList;
    PanelFirst: TPanel;
    PanelLast: TPanel;
    N1: TMenuItem;
    MenuItemLeft: TMenuItem;
    MenuItemRight: TMenuItem;
    MenuItemMoreLeft: TMenuItem;
    MenuItemMoreRight: TMenuItem;
    N8: TMenuItem;
    N9: TMenuItem;
    N10: TMenuItem;
    EditAiueo: TEdit;
    procedure MenuCharaAddClick(Sender: TObject);
    procedure MenuDelClick(Sender: TObject);
    procedure MenuItemUpClick(Sender: TObject);
    procedure MenuItemDownClick(Sender: TObject);
    procedure MenuPopPopup(Sender: TObject);
    procedure MenuSendAllClick(Sender: TObject);
    procedure MenuSelectAllClick(Sender: TObject);
    procedure PanelFirstClick(Sender: TObject);
    procedure PanelLastClick(Sender: TObject);
    procedure MenuItemLeftClick(Sender: TObject);
    procedure MenuItemRightClick(Sender: TObject);
    procedure EditAiueoChange(Sender: TObject);
  private
    { Private 宣言 }
    FToolBar       : TToolbarButtons;            // 独自ツールバー
    FPanelMsg      : TSerifSceneMsgPanel;
    //FMenuItems     : TMenuSubItems;              // シーン移動サブメニュー
    FUpdatingAiueo : Boolean;

    FOnChange: TNotifyEvent;
    FOnCharaChange: TNotifyEvent;
    FOnMoveCursorFocus: TFrameSerifSceneMsgCursorFocusEvent;

    procedure ShowToolBar;


    procedure MsgChange(Sender: TObject);
    procedure PanelAIUEOChange(Sender: TObject; const AIUEO: string);
    procedure PanelMoveCursorFocus(Sender: TObject; Layer, Frame: Integer);
    procedure SetEditAiueoText(const Value: string);
    function GetAutoSend: Boolean;
    procedure SetAutoSend(const Value: Boolean);
  protected
    procedure DoChange();virtual;
    procedure DoCharaChange();virtual;
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;
    // セリフ一覧表示
    procedure ShowList(const ProjectFolder : string;Msgs : TSerifSceneMsgList;Charas : TSerifCharaList;Config : TSerifConfigItem);
    // 表示中の台本データとの参照を解除する。
    procedure CloseList;
    // セリフを追加
    function AddList(Msgs : TSerifSceneMsgList; ForceSend: Boolean = False;
      ContinuousSend: Boolean = False;
      RegisterOnly: Boolean = False): Boolean;
    // 表示中の情報を更新
    procedure View();
    procedure ShowIndexLast();
    // アクティブ時に1回発火するイベント　※以降は選択オブジェクト変化で
    procedure FrameActive;
    // セリフ一覧下端の「終了位置へ移動」ボタンと同じ処理を実行する。
    procedure CursorMoveLast;

    // 指定されたフレーム　レイヤーのセリフをアクティブに
    procedure ActiveSerif(frame,layerTxt,layerWav : Integer;UID : string);

    // True:AviUtl2へ自動送信
    property AutoSend : Boolean read GetAutoSend write SetAutoSend;

    property OnChange  : TNotifyEvent  read FOnChange write FOnChange;
    property OnCharaChange  : TNotifyEvent  read FOnCharaChange write FOnCharaChange;
    property OnMoveCursorFocus : TFrameSerifSceneMsgCursorFocusEvent read FOnMoveCursorFocus write FOnMoveCursorFocus;
  end;


implementation

uses AviUtl2PluginCore, AviUtl2Serif, AviUtl2PluginCursorControl,
     AviUtl2StyleColors;

{$R *.dfm}

{ TFrameVoiceSeenClient }

procedure TFrameSerifSceneMsg.CursorMoveLast;
begin
  FPanelMsg.CursorMoveLast;
end;

constructor TFrameSerifSceneMsg.Create(AOwner: TComponent);
begin
  inherited;
  //FMenuItems := TMenuSubItems.Create;
  FToolBar := TToolbarButtons.Create(Self);
  FToolBar.Parent := Self;
  FToolBar.Align := alTop;
  FToolBar.Top := 0;
  FToolBar.Height := 24;
  FToolBar.NormalColor := A2SCToolBarBackground;
  FToolBar.HoverColor := A2SCToolBarHot;
  FToolBar.DownColor := A2SCToolBarChecked;
  FToolBar.Images := ImageList1;

  PanelFirst.ParentBackground := false;
  PanelFirst.Color := A2SCPanelBackground;
  PanelFirst.Font.Color := A2SCPanelText;
  PanelFirst.Font.Height := -13;


  PanelLast.ParentBackground := false;
  PanelLast.Color := A2SCPanelBackground;
  PanelLast.Font.Color := A2SCPanelText;
  PanelLast.Font.Height := -13;

  FPanelMsg := TSerifSceneMsgPanel.Create(Self);
  FPanelMsg.Parent := Self;
  FPanelMsg.Align := alClient;
  FPanelMsg.PopupMenu := MenuPop;
  FPanelMsg.OnChange := MsgChange;
  FPanelMsg.OnAIUEOChange := PanelAIUEOChange;
  // 2026-04: MsgPanel のカーソル移動通知を上位へ中継する
  FPanelMsg.OnMoveCursorFocus := PanelMoveCursorFocus;

  FPanelMsg.Shortcuts.Add(VK_UP, [ssCtrl], FPanelMsg.ItemUp);
  FPanelMsg.Shortcuts.Add(VK_DOWN, [ssCtrl], FPanelMsg.ItemDown);
  FPanelMsg.Shortcuts.Add('?', FPanelMsg.ItemToggleQuestion);
  FPanelMsg.Shortcuts.Add('!', FPanelMsg.ItemToggleExclamation);
  FPanelMsg.Shortcuts.Add(VK_LEFT, [], FPanelMsg.ItemEnterPosPrev);
  FPanelMsg.Shortcuts.Add(VK_RIGHT, [], FPanelMsg.ItemEnterPosNext);
  FPanelMsg.Shortcuts.Add(VK_LEFT, [ssShift], FPanelMsg.ItemLeft);
  FPanelMsg.Shortcuts.Add(VK_RIGHT, [ssShift], FPanelMsg.ItemRight);
  FPanelMsg.Shortcuts.Add(VK_LEFT, [ssCtrl], FPanelMsg.ItemLeftAll);
  FPanelMsg.Shortcuts.Add(VK_RIGHT, [ssCtrl], FPanelMsg.ItemRightAll);
  //FPanelMsg.Shortcuts.Add(VK_RETURN, [ssCtrl], FPanelMsg.ItemSend);
  FPanelMsg.Shortcuts.Add(VK_RETURN, [], FPanelMsg.ItemEdit);
  FPanelMsg.Shortcuts.Add(VK_DELETE, [], FPanelMsg.ItemDelete);
  FPanelMsg.Shortcuts.Add(Ord('A'), [ssCtrl], FPanelMsg.ItemSelectAll);
  FPanelMsg.Shortcuts.Add(VK_ESCAPE, [], FPanelMsg.ItemSelectClear);
  FPanelMsg.Shortcuts.Add(VK_UP, [], FPanelMsg.CursorUp);
  FPanelMsg.Shortcuts.Add(VK_DOWN, [], FPanelMsg.CursorDown);
  FPanelMsg.Shortcuts.Add('z', FPanelMsg.ItemDirectionClear);
  FPanelMsg.Shortcuts.Add('x', FPanelMsg.ItemDirectionPrev);
  FPanelMsg.Shortcuts.Add('c', FPanelMsg.ItemDirectionNext);
  //FPanelMsg.Shortcuts.Add('a', FPanelMsg.ItemEmotionClear);
  FPanelMsg.Shortcuts.Add('v', FPanelMsg.ItemEmotionPrev);
  FPanelMsg.Shortcuts.Add('b', FPanelMsg.ItemEmotionNext);

  FPanelMsg.Shortcuts.Add('a', FPanelMsg.ItemVoiceA);
  FPanelMsg.Shortcuts.Add('i', FPanelMsg.ItemVoiceI);
  FPanelMsg.Shortcuts.Add('u', FPanelMsg.ItemVoiceU);
  FPanelMsg.Shortcuts.Add('e', FPanelMsg.ItemVoiceE);
  FPanelMsg.Shortcuts.Add('o', FPanelMsg.ItemVoiceO);
  FPanelMsg.Shortcuts.Add('n', FPanelMsg.ItemVoiceN);
  FPanelMsg.Shortcuts.Add('r', FPanelMsg.ItemVoiceClear);
  FPanelMsg.Shortcuts.Add(VK_BACK,[], FPanelMsg.ItemVoiceBackSpace);

  EditAiueo.Color := A2SCEditBackground;
  EditAiueo.Font.Color :=  A2SCEditText;
  EditAiueo.Font.Height := -13;

end;


destructor TFrameSerifSceneMsg.Destroy;
begin
  FPanelMsg.Free;
  FToolBar.Free;
  //FMenuItems.Free;
  inherited;
end;



procedure TFrameSerifSceneMsg.ShowList(const ProjectFolder : string;Msgs : TSerifSceneMsgList;Charas : TSerifCharaList;Config : TSerifConfigItem);
begin
  FPanelMsg.BevelInner := bvNone;
  FPanelMsg.BevelOuter := bvNone;
  FPanelMsg.ShowList(ProjectFolder,Msgs,Charas,Config);
  ShowToolBar;

  PanelFirst.Top := FToolBar.Height + 1;

end;

procedure TFrameSerifSceneMsg.ShowToolBar;
begin
  if FToolBar.Tag = 0 then begin
    FToolBar.AddIcon('セリフを削除',2,FPanelMsg.ItemDelete);
    FToolBar.AddSeparator;
    FToolBar.AddIcon('上に移動',3,FPanelMsg.ItemUp);
    FToolBar.AddIcon('下に移動',4,FPanelMsg.ItemDown);
    FToolBar.AddIcon('改行位置を左へ',5,FPanelMsg.ItemEnterPosPrev);
    FToolBar.AddIcon('改行位置を右へ',6,FPanelMsg.ItemEnterPosNext);
    FToolBar.AddIcon('「？」を文末に追加削除',7,FPanelMsg.ItemToggleQuestion);
    FToolBar.AddIcon('「！」を文末に追加削除',8,FPanelMsg.ItemToggleExclamation);
    //FToolBar.AddIcon('AviUtl2へ送信',9,FPanelMsg.ItemSend);
    FToolBar.Tag := 1;
  end;
end;


procedure TFrameSerifSceneMsg.ActiveSerif(frame, layerTxt, layerWav: Integer;UID : string);
begin
  FPanelMsg.ActiveSerif(frame,layerTxt,layerWav,UID);
end;

function TFrameSerifSceneMsg.AddList(Msgs: TSerifSceneMsgList;
  ForceSend, ContinuousSend, RegisterOnly: Boolean): Boolean;
begin
  Result := FPanelMsg.AddList(Msgs, ForceSend, ContinuousSend, RegisterOnly);
end;

procedure TFrameSerifSceneMsg.CloseList;
begin
  SetEditAiueoText('');
  FPanelMsg.CloseList;
end;

procedure TFrameSerifSceneMsg.View;
begin
  FPanelMsg.View;
end;

// 配役を追加
procedure TFrameSerifSceneMsg.MenuCharaAddClick(Sender: TObject);
begin
  FPanelMsg.CharaAdd;
  DoCharaChange();
end;

procedure TFrameSerifSceneMsg.MenuDelClick(Sender: TObject);
begin
  FPanelMsg.ItemDelete();
end;



procedure TFrameSerifSceneMsg.MenuPopPopup(Sender: TObject);
begin
  MenuSendAll.Enabled := GAviUtl2Plugin;
end;

procedure TFrameSerifSceneMsg.MenuSelectAllClick(Sender: TObject);
begin
  FPanelMsg.ItemSelectAll;
end;

procedure TFrameSerifSceneMsg.MenuSendAllClick(Sender: TObject);
begin
  FPanelMsg.ItemSendAll;
end;

procedure TFrameSerifSceneMsg.MsgChange(Sender: TObject);
begin
  DoChange;
end;

procedure TFrameSerifSceneMsg.PanelAIUEOChange(Sender: TObject;
  const AIUEO: string);
begin
  SetEditAiueoText(AIUEO);
end;

procedure TFrameSerifSceneMsg.PanelMoveCursorFocus(Sender: TObject; Layer,
  Frame: Integer);
begin
  // 2026-04: ガード要求を SceneFrame 側へ受け渡す
  if Assigned(FOnMoveCursorFocus) then
    FOnMoveCursorFocus(Self, Layer, Frame);
end;

procedure TFrameSerifSceneMsg.MenuItemLeftClick(Sender: TObject);
begin
  FPanelMsg.ItemLeft;
end;

procedure TFrameSerifSceneMsg.MenuItemRightClick(Sender: TObject);
begin
  FPanelMsg.ItemRight;
end;

procedure TFrameSerifSceneMsg.MenuItemDownClick(Sender: TObject);
begin
  FPanelMsg.ItemDown();
end;

procedure TFrameSerifSceneMsg.MenuItemUpClick(Sender: TObject);
begin
  FPanelMsg.ItemUp();
end;


procedure TFrameSerifSceneMsg.PanelFirstClick(Sender: TObject);
begin
  FPanelMsg.CursorMoveFirst;
end;

procedure TFrameSerifSceneMsg.PanelLastClick(Sender: TObject);
begin
  FPanelMsg.CursorMoveLast;
end;

procedure TFrameSerifSceneMsg.ShowIndexLast;
begin
  FPanelMsg.ShowIndexLast;
end;

procedure TFrameSerifSceneMsg.DoChange();
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TFrameSerifSceneMsg.DoCharaChange;
begin
  if Assigned(FOnCharaChange) then FOnCharaChange(Self);
end;

procedure TFrameSerifSceneMsg.SetEditAiueoText(const Value: string);
begin
  if EditAiueo.Text = Value then Exit;

  FUpdatingAiueo := True;
  try
    EditAiueo.Text := Value;
  finally
    FUpdatingAiueo := False;
  end;
end;

procedure TFrameSerifSceneMsg.EditAiueoChange(Sender: TObject);
begin
  if FUpdatingAiueo then Exit;
  FPanelMsg.ItemVoiceStr(EditAiueo.Text);
end;

procedure TFrameSerifSceneMsg.FrameActive;
begin
  FPanelMsg.SerifSync;    // AviUtl2上のセリフと同期させる
end;

function TFrameSerifSceneMsg.GetAutoSend: Boolean;
begin
  Result := FPanelMsg.AutoSend;
end;

procedure TFrameSerifSceneMsg.SetAutoSend(const Value: Boolean);
begin
  FPanelMsg.AutoSend := Value;
  MenuSendAll.Enabled := not Value;      // 流し込み中は全て送信を無効
end;


end.



