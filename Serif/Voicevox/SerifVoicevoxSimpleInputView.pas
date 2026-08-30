// 1話者・1セリフを常時編集し、キーボード中心で送信・確認再生する入力ビュー。
unit SerifVoicevoxSimpleInputView;

interface

uses
  Winapi.Windows, System.Classes, System.Types, Vcl.Controls, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Graphics, Vcl.Forms, SerifCharaIconRenderer,
  ShortcutAction, DarkMemo;

type
  TSerifVoicevoxSimpleWheelEvent = procedure(Sender: TObject;
    const WheelDelta: Integer) of object;
  TSerifVoicevoxSimpleShortcutEvent = procedure(Sender: TObject;
    const Index: Integer) of object;

  TSerifVoicevoxSimpleInputView = class(TPanel)
  private const
    INPUT_HEIGHT = 66;
    TEXT_INPUT_HINT = 'ここにセリフを入力' + #13#10 +
      'Enter 決定  Ctrl+Enter 決定後に試聴  Shift+Enter 改行' + #13#10 +
      'F2 再編集  F5 試聴';
  private
    FAccentQueryJson: string;
    FIconRenderer: TSerifCharaIconRenderer;
    FLabelInputHint: TLabel;
    FLabelStyle: TLabel;
    FLoading: Boolean;
    FMemo: TDarkMemo;
    FOnPreview: TNotifyEvent;
    FOnEditorExit: TNotifyEvent;
    FOnReedit: TNotifyEvent;
    FOnSend: TNotifyEvent;
    FOnSendAndPreview: TNotifyEvent;
    FOnShortcut: TSerifVoicevoxSimpleShortcutEvent;
    FOnSpeakerClick: TNotifyEvent;
    FOnSpeakerWheel: TSerifVoicevoxSimpleWheelEvent;
    FOnStyleClick: TNotifyEvent;
    FOnStyleWheel: TSerifVoicevoxSimpleWheelEvent;
    FOnTextChanged: TNotifyEvent;
    FPaintSpeaker: TPaintBox;
    FPanelSpeaker: TPanel;
    FPanelStyle: TPanel;
    FPanelInputHint: TPanel;
    FPanelText: TPanel;
    FShortcuts: TShortcutAction;
    FSpeakerName: string;
    FSpeakerUUID: string;
    FStyleId: Integer;
    FStyleName: string;
    function GetText: string;
    procedure InputHintClick(Sender: TObject);
    procedure ExecuteShortcut(const Index: Integer);
    procedure MemoChange(Sender: TObject);
    procedure MemoExit(Sender: TObject);
    procedure MemoKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure MemoKeyPress(Sender: TObject; var Key: Char);
    procedure PaintSpeaker(Sender: TObject);
    procedure RegisterShortcuts;
    function ShortcutCanExecute: Boolean;
    procedure SpeakerClick(Sender: TObject);
    procedure SpeakerMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure StyleClick(Sender: TObject);
    procedure StyleMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure UpdateInputHint;
  public
    // 共有アイコン描画器を使い、話者＋感情の左列と本文領域を生成する。
    constructor Create(AOwner: TComponent;
      AIconRenderer: TSerifCharaIconRenderer); reintroduce;
    // ショートカット登録を解除してから動的コントロールを破棄する。
    destructor Destroy; override;
    // 実行時生成部品の寸法を、現在のモニターDPIに合わせて96 DPI基準から再計算する。
    procedure ApplyDpi;
    // 本文エディターへフォーカスし、SelectAll=Trueなら全文を選択する。
    procedure FocusEditor(const SelectAll: Boolean = False);
    // 話者選択メニューを表示するスクリーン座標を返す。
    function SpeakerPopupPoint: TPoint;
    // 感情選択メニューを表示するスクリーン座標を返す。
    function StylePopupPoint: TPoint;
    // 表示と送信に使う話者名・UUID・style名・style IDを一括更新する。
    procedure SetSpeaker(const ASpeakerName, ASpeakerUUID,
      AStyleName: string; const AStyleId: Integer);
    // 本文を置き換える。復元中の変更通知は発生させない。
    procedure SetText(const Value: string);
    // 現在の本文・styleに対応する編集済みaudio_query。
    property AccentQueryJson: string read FAccentQueryJson
      write FAccentQueryJson;
    // F5で現在の本文を確認再生する要求。ツールバーの再生要求とは親フレームで合流する。
    property OnPreview: TNotifyEvent read FOnPreview write FOnPreview;
    // フォーカス移動完了後に、親フレームが入力画面外への移動か判定する。
    property OnEditorExit: TNotifyEvent read FOnEditorExit write FOnEditorExit;
    // F2でAviUtl2の選択中セリフを再編集用に読み込む要求。
    property OnReedit: TNotifyEvent read FOnReedit write FOnReedit;
    // Enterで現在の本文と話者設定を送信する要求。
    property OnSend: TNotifyEvent read FOnSend write FOnSend;
    // Ctrl+Enterで送信成功後の確認再生も要求する。
    property OnSendAndPreview: TNotifyEvent read FOnSendAndPreview
      write FOnSendAndPreview;
    // Ctrl+1～0またはテンキーの同じ数字で割り当てを適用する要求。
    property OnShortcut: TSerifVoicevoxSimpleShortcutEvent
      read FOnShortcut write FOnShortcut;
    property OnSpeakerClick: TNotifyEvent
      read FOnSpeakerClick write FOnSpeakerClick;
    property OnSpeakerWheel: TSerifVoicevoxSimpleWheelEvent
      read FOnSpeakerWheel write FOnSpeakerWheel;
    property OnStyleClick: TNotifyEvent read FOnStyleClick write FOnStyleClick;
    property OnStyleWheel: TSerifVoicevoxSimpleWheelEvent
      read FOnStyleWheel write FOnStyleWheel;
    property OnTextChanged: TNotifyEvent read FOnTextChanged
      write FOnTextChanged;
    property SerifText: string read GetText;
    property SpeakerName: string read FSpeakerName;
    property SpeakerUUID: string read FSpeakerUUID;
    property StyleId: Integer read FStyleId;
    property StyleName: string read FStyleName;
  end;

implementation

uses
  System.SysUtils, System.Math, AviUtl2StyleColors, MainToolInfoService;

type
  TMouseWheelControlAccess = class(TControl)
  public
    property OnMouseWheel;
  end;

function TSerifVoicevoxSimpleInputViewScale(const Value,
  Ppi: Integer): Integer;
begin
  Result := MulDiv(Value, Ppi, 96);
end;

function NormalizeText(const Value: string): string;
begin
  Result := StringReplace(Value, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #10, sLineBreak, [rfReplaceAll]);
  Result := Trim(Result);
end;

constructor TSerifVoicevoxSimpleInputView.Create(AOwner: TComponent;
  AIconRenderer: TSerifCharaIconRenderer);
begin
  inherited Create(AOwner);
  FIconRenderer := AIconRenderer;
  FStyleId := -1;
  // 話者・感情・本文を一つの入力領域として識別できるよう、外周だけを囲う。
  BevelOuter := bvLowered;
  BevelWidth := 1;
  Color := A2SCEditBackground;
  ParentBackground := False;
  Height := INPUT_HEIGHT;

  FPanelSpeaker := TPanel.Create(Self);
  FPanelSpeaker.Parent := Self;
  FPanelSpeaker.Align := alLeft;
  FPanelSpeaker.BevelOuter := bvNone;
  FPanelSpeaker.Color := A2SCEditBackground;
  FPanelSpeaker.ParentBackground := False;
  FPanelSpeaker.Width := 64;
  FPanelSpeaker.ShowHint := True;
  FPanelSpeaker.Cursor := crHandPoint;
  FPanelSpeaker.OnClick := SpeakerClick;
  TMouseWheelControlAccess(FPanelSpeaker).OnMouseWheel := SpeakerMouseWheel;

  // 左列の下段は感情、残った上段を話者アイコンとして使う。
  FPanelStyle := TPanel.Create(Self);
  FPanelStyle.Parent := FPanelSpeaker;
  FPanelStyle.Align := alBottom;
  FPanelStyle.BevelOuter := bvNone;
  FPanelStyle.Color := A2SCEditBackground;
  FPanelStyle.ParentBackground := False;
  FPanelStyle.Height := 18;
  FPanelStyle.Cursor := crHandPoint;
  FPanelStyle.OnClick := StyleClick;
  TMouseWheelControlAccess(FPanelStyle).OnMouseWheel := StyleMouseWheel;

  FLabelStyle := TLabel.Create(Self);
  FLabelStyle.Parent := FPanelStyle;
  FLabelStyle.Align := alClient;
  FLabelStyle.Alignment := taCenter;
  FLabelStyle.AutoSize := False;
  FLabelStyle.Cursor := crHandPoint;
  FLabelStyle.Font.Color := A2SCEditText;
  FLabelStyle.Layout := tlCenter;
  FLabelStyle.OnClick := StyleClick;
  TMouseWheelControlAccess(FLabelStyle).OnMouseWheel := StyleMouseWheel;

  FPaintSpeaker := TPaintBox.Create(Self);
  FPaintSpeaker.Parent := FPanelSpeaker;
  FPaintSpeaker.Align := alClient;
  FPaintSpeaker.Cursor := crHandPoint;
  FPaintSpeaker.ShowHint := True;
  FPaintSpeaker.OnClick := SpeakerClick;
  TMouseWheelControlAccess(FPaintSpeaker).OnMouseWheel := SpeakerMouseWheel;
  FPaintSpeaker.OnPaint := PaintSpeaker;

  FPanelText := TPanel.Create(Self);
  FPanelText.Parent := Self;
  FPanelText.Align := alClient;
  FPanelText.BevelOuter := bvNone;
  FPanelText.Color := A2SCEditBackground;
  FPanelText.ParentBackground := False;
  FPanelText.Padding.SetBounds(7, 6, 5, 6);

  FMemo := TDarkMemo.Create(Self);
  FMemo.Parent := FPanelText;
  FMemo.Align := alClient;
  FMemo.BorderStyle := bsNone;
  FMemo.Cursor := crIBeam;
  FMemo.DesignFontHeight := 14;
  FMemo.ScrollBars := ssNone;
  FMemo.WantReturns := True;
  FMemo.WordWrap := True;
  FMemo.OnChange := MemoChange;
  FMemo.OnExit := MemoExit;
  FMemo.OnKeyDown := MemoKeyDown;
  FMemo.OnKeyPress := MemoKeyPress;

  // 複数行のTextHintは環境依存で表示されないため、空欄用ラベルを重ねる。
  FPanelInputHint := TPanel.Create(Self);
  FPanelInputHint.Parent := FPanelText;
  FPanelInputHint.Align := alClient;
  FPanelInputHint.BevelOuter := bvNone;
  FPanelInputHint.Color := A2SCEditBackground;
  FPanelInputHint.Cursor := crIBeam;
  FPanelInputHint.ParentBackground := False;
  FPanelInputHint.OnClick := InputHintClick;

  FLabelInputHint := TLabel.Create(Self);
  FLabelInputHint.Parent := FPanelInputHint;
  FLabelInputHint.Align := alClient;
  FLabelInputHint.AutoSize := False;
  FLabelInputHint.Caption := TEXT_INPUT_HINT;
  FLabelInputHint.Cursor := crIBeam;
  FLabelInputHint.Font.Color := A2SCMemoLineNumberText;
  FLabelInputHint.Font.Height := -11;
  FLabelInputHint.Layout := tlTop;
  FLabelInputHint.Transparent := True;
  FLabelInputHint.WordWrap := True;
  FLabelInputHint.OnClick := InputHintClick;
  FPanelInputHint.BringToFront;

  FShortcuts := TShortcutAction.Create;
  FShortcuts.OnCanExecute := ShortcutCanExecute;
  RegisterShortcuts;
  ApplyDpi;
end;

procedure TSerifVoicevoxSimpleInputView.ApplyDpi;
begin
  Height := TSerifVoicevoxSimpleInputViewScale(INPUT_HEIGHT, CurrentPPI);
  FPanelSpeaker.Width := TSerifVoicevoxSimpleInputViewScale(64, CurrentPPI);
  FPanelStyle.Height := TSerifVoicevoxSimpleInputViewScale(18, CurrentPPI);
  FPanelText.Padding.SetBounds(
    TSerifVoicevoxSimpleInputViewScale(7, CurrentPPI),
    TSerifVoicevoxSimpleInputViewScale(6, CurrentPPI),
    TSerifVoicevoxSimpleInputViewScale(5, CurrentPPI),
    TSerifVoicevoxSimpleInputViewScale(6, CurrentPPI));
  // 200%時の28pxを基準に、ほかのDPIでも周囲と同じ比率で拡縮する。
  FLabelStyle.Font.Height := -TSerifVoicevoxSimpleInputViewScale(14, CurrentPPI);
  FMemo.ApplyDpi;
  FLabelInputHint.Font.Height :=
    -TSerifVoicevoxSimpleInputViewScale(11, CurrentPPI);
  FPaintSpeaker.Invalidate;
end;

destructor TSerifVoicevoxSimpleInputView.Destroy;
begin
  FShortcuts.Free;
  inherited;
end;

procedure TSerifVoicevoxSimpleInputView.ExecuteShortcut(
  const Index: Integer);
begin
  if Assigned(FOnShortcut) then FOnShortcut(Self, Index);
end;

procedure TSerifVoicevoxSimpleInputView.FocusEditor(const SelectAll: Boolean);
begin
  if not FMemo.CanFocus then Exit;
  FMemo.SetFocus;
  if SelectAll then FMemo.SelectAll
  else FMemo.SelStart := Length(FMemo.Text);
end;

function TSerifVoicevoxSimpleInputView.GetText: string;
begin
  Result := NormalizeText(FMemo.Text);
end;

procedure TSerifVoicevoxSimpleInputView.InputHintClick(Sender: TObject);
begin
  FPanelInputHint.Visible := False;
  FocusEditor(False);
end;

procedure TSerifVoicevoxSimpleInputView.MemoChange(Sender: TObject);
begin
  UpdateInputHint;
  if FLoading then Exit;
  FAccentQueryJson := '';
  if Assigned(FOnTextChanged) then FOnTextChanged(Self);
end;

procedure TSerifVoicevoxSimpleInputView.MemoExit(Sender: TObject);
begin
  if Assigned(FOnEditorExit) then FOnEditorExit(Self);
end;

procedure TSerifVoicevoxSimpleInputView.UpdateInputHint;
begin
  FPanelInputHint.Visible := FMemo.Text = '';
  if FPanelInputHint.Visible then FPanelInputHint.BringToFront;
end;

procedure TSerifVoicevoxSimpleInputView.MemoKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if FShortcuts.KeyDown(Key, Shift) then Exit;
  case Key of
    VK_F2:
      begin
        Key := 0;
        if Assigned(FOnReedit) then FOnReedit(Self);
      end;
    VK_RETURN:
      if not (ssShift in Shift) then
      begin
        Key := 0;
        if ssCtrl in Shift then
        begin
          if Assigned(FOnSendAndPreview) then FOnSendAndPreview(Self);
        end
        else if Assigned(FOnSend) then FOnSend(Self);
      end;
    VK_F5:
      begin
        Key := 0;
        if Assigned(FOnPreview) then FOnPreview(Self);
      end;
  end;
end;

procedure TSerifVoicevoxSimpleInputView.MemoKeyPress(Sender: TObject;
  var Key: Char);
begin
  // KeyDown後にも届くEnterで、送信後に全選択した本文を改行へ置換させない。
  // Shift+Enterだけは本文中の改行としてTMemoへ渡す。
  if ((Key = #10) or (Key = #13)) and
    (GetKeyState(VK_SHIFT) >= 0) then Key := #0;
end;

procedure TSerifVoicevoxSimpleInputView.RegisterShortcuts;
begin
  FShortcuts.Add(Ord('1'), [ssCtrl], procedure begin ExecuteShortcut(0) end);
  FShortcuts.Add(Ord('2'), [ssCtrl], procedure begin ExecuteShortcut(1) end);
  FShortcuts.Add(Ord('3'), [ssCtrl], procedure begin ExecuteShortcut(2) end);
  FShortcuts.Add(Ord('4'), [ssCtrl], procedure begin ExecuteShortcut(3) end);
  FShortcuts.Add(Ord('5'), [ssCtrl], procedure begin ExecuteShortcut(4) end);
  FShortcuts.Add(Ord('6'), [ssCtrl], procedure begin ExecuteShortcut(5) end);
  FShortcuts.Add(Ord('7'), [ssCtrl], procedure begin ExecuteShortcut(6) end);
  FShortcuts.Add(Ord('8'), [ssCtrl], procedure begin ExecuteShortcut(7) end);
  FShortcuts.Add(Ord('9'), [ssCtrl], procedure begin ExecuteShortcut(8) end);
  FShortcuts.Add(Ord('0'), [ssCtrl], procedure begin ExecuteShortcut(9) end);
  FShortcuts.Add(VK_NUMPAD1, [ssCtrl], procedure begin ExecuteShortcut(0) end);
  FShortcuts.Add(VK_NUMPAD2, [ssCtrl], procedure begin ExecuteShortcut(1) end);
  FShortcuts.Add(VK_NUMPAD3, [ssCtrl], procedure begin ExecuteShortcut(2) end);
  FShortcuts.Add(VK_NUMPAD4, [ssCtrl], procedure begin ExecuteShortcut(3) end);
  FShortcuts.Add(VK_NUMPAD5, [ssCtrl], procedure begin ExecuteShortcut(4) end);
  FShortcuts.Add(VK_NUMPAD6, [ssCtrl], procedure begin ExecuteShortcut(5) end);
  FShortcuts.Add(VK_NUMPAD7, [ssCtrl], procedure begin ExecuteShortcut(6) end);
  FShortcuts.Add(VK_NUMPAD8, [ssCtrl], procedure begin ExecuteShortcut(7) end);
  FShortcuts.Add(VK_NUMPAD9, [ssCtrl], procedure begin ExecuteShortcut(8) end);
  FShortcuts.Add(VK_NUMPAD0, [ssCtrl], procedure begin ExecuteShortcut(9) end);
end;

function TSerifVoicevoxSimpleInputView.ShortcutCanExecute: Boolean;
begin
  Result := Assigned(FMemo) and FMemo.Enabled and FMemo.Focused and Visible;
end;

procedure TSerifVoicevoxSimpleInputView.SpeakerClick(Sender: TObject);
begin
  if Assigned(FOnSpeakerClick) then FOnSpeakerClick(Self);
end;

procedure TSerifVoicevoxSimpleInputView.SpeakerMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
begin
  Handled := Assigned(FOnSpeakerWheel);
  if Handled then
  begin
    FOnSpeakerWheel(Self, WheelDelta);
    ShowMainToolInfo(FSpeakerName + ' / ' + FStyleName);
  end;
end;

procedure TSerifVoicevoxSimpleInputView.StyleClick(Sender: TObject);
begin
  if Assigned(FOnStyleClick) then FOnStyleClick(Self);
end;

procedure TSerifVoicevoxSimpleInputView.StyleMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
begin
  Handled := Assigned(FOnStyleWheel);
  if Handled then
  begin
    FOnStyleWheel(Self, WheelDelta);
    ShowMainToolInfo(FSpeakerName + ' / ' + FStyleName);
  end;
end;

procedure TSerifVoicevoxSimpleInputView.PaintSpeaker(Sender: TObject);
var
  Box: TRect;
  IconSize: Integer;
  IconRect: TRect;
begin
  Box := FPaintSpeaker.ClientRect;
  FPaintSpeaker.Canvas.Brush.Color := RGB(65, 72, 82);
  FPaintSpeaker.Canvas.FillRect(Box);
  // 外枠はDPIへ追従させ、アイコンだけを一回り小さくして余白を確保する。
  IconSize := MulDiv(Min(Box.Width, Box.Height), 4, 5);
  IconRect := Rect(Box.Left + ((Box.Width - IconSize) div 2),
    Box.Top + ((Box.Height - IconSize) div 2), 0, 0);
  IconRect.Right := IconRect.Left + IconSize;
  IconRect.Bottom := IconRect.Top + IconSize;
  if Assigned(FIconRenderer) and (FSpeakerName <> '') then
    FIconRenderer.DrawOrFallback(FPaintSpeaker.Canvas, FSpeakerName,
      IconRect);
end;

procedure TSerifVoicevoxSimpleInputView.SetSpeaker(const ASpeakerName,
  ASpeakerUUID, AStyleName: string; const AStyleId: Integer);
begin
  if (FSpeakerUUID <> ASpeakerUUID) or (FStyleId <> AStyleId) then
    FAccentQueryJson := '';
  FSpeakerName := ASpeakerName;
  FSpeakerUUID := ASpeakerUUID;
  FStyleName := AStyleName;
  FStyleId := AStyleId;
  FPanelSpeaker.Hint := FSpeakerName + sLineBreak +
    'クリック: 話者選択 / ホイール: 話者切替';
  FPaintSpeaker.Hint := FPanelSpeaker.Hint;
  FLabelStyle.Caption := FStyleName;
  FPanelStyle.Hint := FStyleName + sLineBreak +
    'クリック: 感情選択 / ホイール: 感情切替';
  FLabelStyle.Hint := FPanelStyle.Hint;
  FPanelStyle.ShowHint := True;
  FLabelStyle.ShowHint := True;
  FPaintSpeaker.Invalidate;
end;

procedure TSerifVoicevoxSimpleInputView.SetText(const Value: string);
begin
  FLoading := True;
  try
    FMemo.Text := Value;
  finally
    FLoading := False;
  end;
  FAccentQueryJson := '';
end;

function TSerifVoicevoxSimpleInputView.SpeakerPopupPoint: TPoint;
begin
  Result := FPanelSpeaker.ClientToScreen(Point(0, FPanelSpeaker.Height));
end;

function TSerifVoicevoxSimpleInputView.StylePopupPoint: TPoint;
begin
  Result := FPanelStyle.ClientToScreen(Point(0, FPanelStyle.Height));
end;

end.
