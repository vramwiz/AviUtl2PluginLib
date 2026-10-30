// 直接入力内の単語登録・一覧ページ。辞書更新後も編集対象を保持し、セリフ全体を試聴できる。
unit SerifVoicevoxDictionaryPage;

interface

uses
  Winapi.Windows, Winapi.Messages, System.Classes, Vcl.Controls, Vcl.ExtCtrls,
  Vcl.Forms, Vcl.StdCtrls, DarkEdit, DarkComboBox, DarkButton, DarkListBox,
  DarkThemeDpiContext, SerifVoicevoxAccentView, SerifVoicevoxUserDictionary,
  SerifVoicevoxDictionaryWorker;

type
  TSerifVoicevoxDictionaryPage = class(TPanel)
  private
    FAccent: TDarkComboBox;
    FAccentHint: TLabel;
    FAccentLabel: TLabel;
    FAccentPaint: TSerifVoicevoxAccentPaintControl;
    FAccentScroll: TScrollBox;
    FAnalyzeButton: TDarkButton;
    FAnalyzePending: Boolean;
    FBackButton: TDarkButton;
    FContextText: string;
    FDeleteButton: TDarkButton;
    FDeleteCancel: TDarkButton;
    FDeleteUUID: string;
    FDpiContext: TDarkThemeDpiContext;
    FEditor: TScrollBox;
    FEditorBody: TPanel;
    FEditButton: TDarkButton;
    FFilter: TDarkEdit;
    FInputRevision: Cardinal;
    FInitialized: Boolean;
    FList: TDarkListBox;
    FListActions: TPanel;
    FListMode: Boolean;
    FListNewButton: TDarkButton;
    FListPanel: TPanel;
    FListTitle: TLabel;
    FLoadPending: Boolean;
    FLoaded: Boolean;
    FNewButton: TDarkButton;
    FNotifyHandle: HWND;
    FOnBack: TNotifyEvent;
    FOnChanged: TNotifyEvent;
    FOnEdit: TNotifyEvent;
    FOnPreview: TNotifyEvent;
    FOriginal: TSerifVoicevoxDictionaryWord;
    FPlayAfterSave: Boolean;
    FPreviewActive: Boolean;
    FPriority: TDarkComboBox;
    FPriorityLabel: TLabel;
    FReading: TDarkEdit;
    FReadingLabel: TLabel;
    FRefreshButton: TDarkButton;
    FResetButton: TDarkButton;
    FReturnAfterSave: Boolean;
    FSaveButton: TDarkButton;
    FStatus: TLabel;
    FStyleId: Integer;
    FSurface: TDarkEdit;
    FSurfaceLabel: TLabel;
    FTimer: TTimer;
    FTitle: TLabel;
    FType: TDarkComboBox;
    FTypeLabel: TLabel;
    FUpdating: Boolean;
    FVisibleWords: TArray<Integer>;
    FWordPreviewButton: TDarkButton;
    FWords: TArray<TSerifVoicevoxDictionaryWord>;
    FWorker: TSerifVoicevoxDictionaryWorker;
    procedure AccentChanged(Sender: TObject);
    procedure AccentPosition(Sender: TObject; const PhraseIndex, Accent: Integer);
    procedure AnalyzeClick(Sender: TObject);
    procedure BackClick(Sender: TObject);
    procedure Complete(var Msg: TMessage);
    procedure CreateEditor;
    procedure CreateList;
    procedure DeleteCancelClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    function Draft: TSerifVoicevoxDictionaryWord;
    procedure EditClick(Sender: TObject);
    procedure FieldKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FilterChange(Sender: TObject);
    function GetDirty: Boolean;
    procedure Initialize;
    procedure LayoutPages;
    procedure ListSelection(Sender: TObject);
    function NewButton(const Caption: string; ParentControl: TWinControl; Handler: TNotifyEvent): TDarkButton;
    function NewEdit(ParentControl: TWinControl): TDarkEdit;
    function NewLabel(const Caption: string; ParentControl: TWinControl): TLabel;
    procedure NewClick(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    procedure ReadingChange(Sender: TObject);
    procedure RebuildAccent(const AccentType: Integer);
    procedure RefreshClick(Sender: TObject);
    procedure ResetClick(Sender: TObject);
    procedure Restore(const Word: TSerifVoicevoxDictionaryWord);
    procedure SaveClick(Sender: TObject);
    procedure SaveWord(const PlayAfterSave, ReturnAfterSave: Boolean);
    function SelectedWord(out Word: TSerifVoicevoxDictionaryWord): Boolean;
    procedure SetStatus(const Text: string);
    procedure Start(const Action: TSerifVoicevoxDictionaryAction; const Word: TSerifVoicevoxDictionaryWord);
    procedure SurfaceChange(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure UpdateGraph;
    procedure UpdateList;
    procedure UpdateState;
  protected
    procedure Resize; override;
  public
    // 登録と一覧を同じ親ページ内へ作成する。API要求は専用ワーカーで直列に実行する。
    constructor Create(AOwner: TComponent); override;
    // ワーカー終了を待ってから通知先を破棄する。完了通知から破棄済みUIへアクセスさせない。
    destructor Destroy; override;
    // 編集欄とスクロール領域を、現在のモニターDPIへ合わせる。
    procedure ApplyDpi;
    // 本文・話者の変更では保留中の自動試聴を取り消す。単語の編集中の値は保持する。
    procedure SetContext(const Text: string; const StyleId: Integer);
    // 実行済みの登録要求は維持し、完了後の試聴・ページ移動だけを取り消す。
    procedure CancelPendingActions;
    // 直前に登録・編集中の単語を保持して、登録ページへ切り替える。
    procedure ShowEditor;
    // 一覧が未取得ならEngineから読み込み、単語一覧ページへ切り替える。
    procedure ShowList;
    // 新規・変更中の単語は登録してから試聴を要求する。完了後にOnPreviewを通知する。
    procedure SaveAndPreview;
    // 既存の共通プレビューに合わせ、ページ内の試聴ボタンも停止表示にする。
    procedure SetPreviewActive(const Value: Boolean);
    // 読取・解析・登録・削除のAPI処理中ならTrue。
    function Busy: Boolean;
    property Dirty: Boolean read GetDirty;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
    property OnPreview: TNotifyEvent read FOnPreview write FOnPreview;
    property OnBack: TNotifyEvent read FOnBack write FOnBack;
    property OnEdit: TNotifyEvent read FOnEdit write FOnEdit;
  end;

implementation

uses
  System.SysUtils, System.Math, System.Generics.Collections, System.Generics.Defaults,
  AviUtl2StyleColors;

const
  WordTypes: array[0..4] of string = ('PROPER_NOUN', 'COMMON_NOUN', 'VERB', 'ADJECTIVE', 'SUFFIX');

constructor TSerifVoicevoxDictionaryPage.Create(AOwner: TComponent);
begin
  inherited;
  BevelOuter := bvNone;
  ParentBackground := False;
  Color := A2SCPanelBackground;
  Font.Color := A2SCPanelText;
  FStyleId := -1;
  FDpiContext := TDarkThemeDpiContext.Create(Self);
  FNotifyHandle := AllocateHWnd(Complete);
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 350;
  FTimer.OnTimer := TimerTimer;

  FStatus := NewLabel('', Self);
  FStatus.Align := alBottom;
  FStatus.AutoSize := False;
  FStatus.WordWrap := True;
  CreateEditor;
  CreateList;
  FOriginal := TSerifVoicevoxDictionaryWord.NewWord;
  FListPanel.Visible := False;
end;

destructor TSerifVoicevoxDictionaryPage.Destroy;
begin
  FTimer.Enabled := False;
  if Assigned(FWorker) then
  begin
    FWorker.Terminate;
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;
  if FNotifyHandle <> 0 then DeallocateHWnd(FNotifyHandle);
  inherited;
end;

function TSerifVoicevoxDictionaryPage.NewLabel(const Caption: string;
  ParentControl: TWinControl): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := ParentControl;
  Result.Caption := Caption;
end;

function TSerifVoicevoxDictionaryPage.NewEdit(ParentControl: TWinControl): TDarkEdit;
begin
  Result := TDarkEdit.Create(Self);
  Result.Parent := ParentControl;
  Result.DpiContext := FDpiContext;
  Result.DesignFontHeight := 13;
  Result.OnKeyDown := FieldKeyDown;
end;

function TSerifVoicevoxDictionaryPage.NewButton(const Caption: string;
  ParentControl: TWinControl; Handler: TNotifyEvent): TDarkButton;
begin
  Result := TDarkButton.Create(Self);
  Result.Parent := ParentControl;
  Result.DpiContext := FDpiContext;
  Result.Caption := Caption;
  Result.OnClick := Handler;
  Result.OnKeyDown := FieldKeyDown;
end;

procedure TSerifVoicevoxDictionaryPage.CreateEditor;
begin
  FEditor := TScrollBox.Create(Self);
  FEditor.Parent := Self;
  FEditor.Align := alClient;
  FEditor.BorderStyle := bsNone;
  FEditor.Color := Color;
  FEditor.HorzScrollBar.Visible := False;
  FEditorBody := TPanel.Create(Self);
  FEditorBody.Parent := FEditor;
  FEditorBody.Align := alTop;
  FEditorBody.BevelOuter := bvNone;
  FEditorBody.ParentBackground := False;
  FEditorBody.Color := Color;
  FTitle := NewLabel('単語を登録', FEditorBody);
  FSurfaceLabel := NewLabel('単語', FEditorBody);
  FSurface := NewEdit(FEditorBody);
  FSurface.OnChange := SurfaceChange;
  FAnalyzeButton := NewButton('読みを取得', FEditorBody, AnalyzeClick);
  FReadingLabel := NewLabel('読み（カタカナ）', FEditorBody);
  FReading := NewEdit(FEditorBody);
  FReading.OnChange := ReadingChange;
  FTypeLabel := NewLabel('品詞', FEditorBody);
  FType := TDarkComboBox.Create(Self);
  FType.Parent := FEditorBody;
  FType.DpiContext := FDpiContext;
  FType.OnChange := AccentChanged;
  FType.OnKeyDown := FieldKeyDown;
  FPriorityLabel := NewLabel('優先度', FEditorBody);
  FPriority := TDarkComboBox.Create(Self);
  FPriority.Parent := FEditorBody;
  FPriority.DpiContext := FDpiContext;
  FPriority.Hint := '大きいほど、この読み方を優先します。';
  FPriority.ShowHint := True;
  FPriority.OnChange := AccentChanged;
  FPriority.OnKeyDown := FieldKeyDown;
  FAccentLabel := NewLabel('アクセント', FEditorBody);
  FAccent := TDarkComboBox.Create(Self);
  FAccent.Parent := FEditorBody;
  FAccent.DpiContext := FDpiContext;
  FAccent.OnChange := AccentChanged;
  FAccent.OnKeyDown := FieldKeyDown;
  FAccentScroll := TScrollBox.Create(Self);
  FAccentScroll.Parent := FEditorBody;
  FAccentScroll.BorderStyle := bsNone;
  FAccentScroll.Color := Color;
  FAccentScroll.VertScrollBar.Visible := False;
  FAccentPaint := TSerifVoicevoxAccentPaintControl.Create(Self);
  FAccentPaint.Parent := FAccentScroll;
  FAccentPaint.AllowPhraseEditing := False;
  FAccentPaint.OnAccentPosition := AccentPosition;
  FAccentPaint.OnPreview := PreviewClick;
  FAccentHint := NewLabel('線をドラッグしてアクセントを変更。末尾の「ガ」は確認用です。', FEditorBody);
  FAccentHint.WordWrap := True;
  FAccentHint.AutoSize := False;
  FSaveButton := NewButton('登録', FEditorBody, SaveClick);
  FWordPreviewButton := NewButton('登録してセリフ試聴', FEditorBody, PreviewClick);
  FBackButton := NewButton('登録して読みへ戻る', FEditorBody, BackClick);
  FNewButton := NewButton('新しい単語', FEditorBody, NewClick);
  FResetButton := NewButton('変更を戻す', FEditorBody, ResetClick);
end;

procedure TSerifVoicevoxDictionaryPage.CreateList;
begin
  FListPanel := TPanel.Create(Self);
  FListPanel.Parent := Self;
  FListPanel.Align := alClient;
  FListPanel.BevelOuter := bvNone;
  FListPanel.Color := Color;
  FListTitle := NewLabel('登録済み単語　選択して編集／削除', FListPanel);
  FListTitle.Align := alTop;
  FListTitle.AutoSize := False;
  FFilter := NewEdit(FListPanel);
  FFilter.Align := alTop;
  FFilter.TextHint := '単語・読みで絞り込み';
  FFilter.OnChange := FilterChange;
  FListActions := TPanel.Create(Self);
  FListActions.Parent := FListPanel;
  FListActions.Align := alBottom;
  FListActions.BevelOuter := bvNone;
  FListActions.Color := Color;
  FListNewButton := NewButton('新規', FListActions, NewClick);
  FEditButton := NewButton('編集', FListActions, EditClick);
  FDeleteButton := NewButton('削除', FListActions, DeleteClick);
  FDeleteCancel := NewButton('削除取消', FListActions, DeleteCancelClick);
  FDeleteCancel.Visible := False;
  FRefreshButton := NewButton('一覧を更新', FListActions, RefreshClick);
  FList := TDarkListBox.Create(Self);
  FList.Parent := FListPanel;
  FList.Align := alClient;
  FList.DpiContext := FDpiContext;
  FList.DesignFontHeight := 13;
  FList.DesignItemHeight := 28;
  FList.OnClick := ListSelection;
  FList.OnDblClick := EditClick;
  FList.OnKeyDown := FieldKeyDown;
end;

procedure TSerifVoicevoxDictionaryPage.ApplyDpi;
begin
  FDpiContext.UpdateFromControl(Self);
  Font.Height := -MulDiv(13, CurrentPPI, 96);
  FAccentPaint.Font.Height := -MulDiv(14, CurrentPPI, 96);
  LayoutPages;
end;

procedure TSerifVoicevoxDictionaryPage.Resize;
begin
  inherited;
  LayoutPages;
end;

procedure TSerifVoicevoxDictionaryPage.LayoutPages;
var
  ContentWidth: Integer;
  Gap: Integer;
  LabelWidth: Integer;
  RowHeight: Integer;
  X: Integer;
  Y: Integer;
  procedure PlaceButton(Button: TDarkButton; const LogicalWidth: Integer; const MaxWidth: Integer);
  var
    ButtonWidth: Integer;
  begin
    if not Button.Visible then Exit;
    ButtonWidth := Min(MulDiv(LogicalWidth, CurrentPPI, 96), MaxWidth);
    if (X > Gap) and (X + ButtonWidth > MaxWidth) then
    begin
      X := Gap;
      Inc(Y, RowHeight + Gap);
    end;
    Button.SetBounds(X, Y, ButtonWidth, RowHeight);
    Inc(X, ButtonWidth + Gap);
  end;
begin
  if not Assigned(FResetButton) or not Assigned(FList) then Exit;
  Gap := MulDiv(6, CurrentPPI, 96);
  RowHeight := MulDiv(30, CurrentPPI, 96);
  LabelWidth := MulDiv(104, CurrentPPI, 96);
  // 未接続の親のハンドルを作らないよう、配置計算にはWidthだけを使う。
  ContentWidth := Max(MulDiv(220, CurrentPPI, 96), FEditor.Width - MulDiv(24, CurrentPPI, 96));
  FStatus.Height := MulDiv(44, CurrentPPI, 96);
  FEditorBody.Height := MulDiv(370, CurrentPPI, 96);
  FTitle.SetBounds(Gap, Gap, ContentWidth - Gap, RowHeight);
  FSurfaceLabel.SetBounds(Gap, RowHeight + Gap, LabelWidth, RowHeight);
  FSurface.SetBounds(LabelWidth, RowHeight + Gap, ContentWidth - LabelWidth, RowHeight);
  FReadingLabel.SetBounds(Gap, 2 * (RowHeight + Gap), LabelWidth, RowHeight);
  FReading.SetBounds(LabelWidth, 2 * (RowHeight + Gap), ContentWidth - LabelWidth, RowHeight);
  FTypeLabel.SetBounds(Gap, 3 * (RowHeight + Gap), MulDiv(36, CurrentPPI, 96), RowHeight);
  FType.SetBounds(MulDiv(36, CurrentPPI, 96), 3 * (RowHeight + Gap),
    MulDiv(88, CurrentPPI, 96), RowHeight);
  FPriorityLabel.SetBounds(MulDiv(132, CurrentPPI, 96), 3 * (RowHeight + Gap),
    MulDiv(36, CurrentPPI, 96), RowHeight);
  FPriority.SetBounds(MulDiv(168, CurrentPPI, 96), 3 * (RowHeight + Gap),
    MulDiv(52, CurrentPPI, 96), RowHeight);
  FAccentLabel.SetBounds(Gap, 4 * (RowHeight + Gap), LabelWidth, RowHeight);
  FAccent.SetBounds(LabelWidth, 4 * (RowHeight + Gap), ContentWidth - LabelWidth, RowHeight);
  FAccentScroll.SetBounds(Gap, 5 * (RowHeight + Gap), ContentWidth - Gap,
    MulDiv(120, CurrentPPI, 96));
  UpdateGraph;
  Y := FAccentScroll.Top + FAccentScroll.Height + Gap;
  FAccentHint.SetBounds(Gap, Y, ContentWidth - Gap, MulDiv(36, CurrentPPI, 96));
  Inc(Y, FAccentHint.Height + Gap);
  X := Gap;
  PlaceButton(FSaveButton, 70, ContentWidth);
  PlaceButton(FWordPreviewButton, 160, ContentWidth);
  PlaceButton(FBackButton, 160, ContentWidth);
  PlaceButton(FAnalyzeButton, 100, ContentWidth);
  PlaceButton(FNewButton, 100, ContentWidth);
  PlaceButton(FResetButton, 100, ContentWidth);
  FEditorBody.Height := Y + RowHeight + Gap;
  FListTitle.Height := RowHeight;
  ContentWidth := Max(RowHeight, FListPanel.Width - Gap);
  X := Gap;
  Y := Gap;
  PlaceButton(FListNewButton, 54, ContentWidth);
  PlaceButton(FEditButton, 54, ContentWidth);
  PlaceButton(FDeleteButton, 90, ContentWidth);
  PlaceButton(FDeleteCancel, 90, ContentWidth);
  PlaceButton(FRefreshButton, 100, ContentWidth);
  FListActions.Height := Y + RowHeight + Gap;
end;

function TSerifVoicevoxDictionaryPage.Draft: TSerifVoicevoxDictionaryWord;
begin
  Result := FOriginal;
  if not FInitialized then Exit;
  Result.Surface := Trim(FSurface.Text);
  Result.Pronunciation := TSerifVoicevoxUserDictionary.NormalizeReading(FReading.Text);
  Result.WordType := '';
  if (FType.ItemIndex >= Low(WordTypes)) and (FType.ItemIndex <= High(WordTypes)) then
    Result.WordType := WordTypes[FType.ItemIndex];
  Result.AccentType := FAccent.ItemIndex;
  Result.Priority := FPriority.ItemIndex;
end;

function TSerifVoicevoxDictionaryPage.GetDirty: Boolean;
var
  Word: TSerifVoicevoxDictionaryWord;
begin
  Word := Draft;
  Result := not Word.SameValues(FOriginal);
end;

procedure TSerifVoicevoxDictionaryPage.Initialize;
var
  I: Integer;
begin
  if FInitialized then Exit;
  // ComboBoxのItemsとItemIndexはHandleを要求するため、最初のページ表示まで遅延する。
  FType.Items.AddStrings(['固有名詞', '普通名詞', '動詞', '形容詞', '接尾語']);
  for I := 0 to 10 do FPriority.Items.Add(IntToStr(I));
  FInitialized := True;
  Restore(FOriginal);
end;

procedure TSerifVoicevoxDictionaryPage.Restore(const Word: TSerifVoicevoxDictionaryWord);
var
  I: Integer;
begin
  Inc(FInputRevision);
  FAnalyzePending := False;
  FTimer.Enabled := False;
  FUpdating := True;
  try
    FOriginal := Word;
    FSurface.Text := Word.Surface;
    FReading.Text := Word.Pronunciation;
    FPriority.ItemIndex := EnsureRange(Word.Priority, 0, 10);
    FType.ItemIndex := -1;
    for I := Low(WordTypes) to High(WordTypes) do
      if WordTypes[I] = Word.WordType then FType.ItemIndex := I;
    RebuildAccent(Word.AccentType);
  finally
    FUpdating := False;
  end;
  UpdateState;
end;

procedure TSerifVoicevoxDictionaryPage.RebuildAccent(const AccentType: Integer);
var
  Count: Integer;
  I: Integer;
begin
  Count := Length(TSerifVoicevoxUserDictionary.Moras(
    TSerifVoicevoxUserDictionary.NormalizeReading(FReading.Text)));
  FAccent.Items.BeginUpdate;
  try
    FAccent.Items.Clear;
    FAccent.Items.Add('平板（下げない）');
    for I := 1 to Count do FAccent.Items.Add(Format('%d拍目の後で下げる', [I]));
    FAccent.ItemIndex := EnsureRange(AccentType, 0, Count);
  finally
    FAccent.Items.EndUpdate;
  end;
  UpdateGraph;
end;

procedure TSerifVoicevoxDictionaryPage.UpdateGraph;
var
  Word: TSerifVoicevoxDictionaryWord;
begin
  if not FInitialized or not Assigned(FAccentPaint) or not Assigned(FAccent) or
    not Assigned(FReading) then Exit;
  Word := Draft;
  if Length(TSerifVoicevoxUserDictionary.Moras(Word.Pronunciation)) = 0 then FAccentPaint.Clear
  else FAccentPaint.SetQueryJson(
    TSerifVoicevoxUserDictionary.AccentDisplay(Word.Pronunciation, Word.AccentType));
  FAccentPaint.SetBounds(0, 0, Max(FAccentScroll.Width - MulDiv(18, CurrentPPI, 96),
    FAccentPaint.ContentWidth), MulDiv(92, CurrentPPI, 96));
end;

procedure TSerifVoicevoxDictionaryPage.SurfaceChange(Sender: TObject);
begin
  if FUpdating then Exit;
  Inc(FInputRevision);
  FUpdating := True;
  try
    FReading.Clear;
    RebuildAccent(0);
  finally
    FUpdating := False;
  end;
  FAnalyzePending := Trim(FSurface.Text) <> '';
  FTimer.Enabled := False;
  FTimer.Enabled := FAnalyzePending;
  SetStatus('単語を解析して現在の読みを表示します。');
  UpdateState;
end;

procedure TSerifVoicevoxDictionaryPage.ReadingChange(Sender: TObject);
begin
  if FUpdating then Exit;
  Inc(FInputRevision); // 手入力した読みを、先に開始した自動解析で上書きしない。
  FAnalyzePending := False;
  FTimer.Enabled := False;
  RebuildAccent(FAccent.ItemIndex);
  UpdateState;
end;

procedure TSerifVoicevoxDictionaryPage.AccentChanged(Sender: TObject);
begin
  if FUpdating then Exit;
  if Sender = FAccent then
  begin
    Inc(FInputRevision);
    FAnalyzePending := False;
    FTimer.Enabled := False;
  end;
  UpdateGraph;
  UpdateState;
end;

procedure TSerifVoicevoxDictionaryPage.AccentPosition(Sender: TObject; const PhraseIndex, Accent: Integer);
var
  Count: Integer;
begin
  Count := FAccent.Items.Count - 1;
  if Accent > Count then FAccent.ItemIndex := 0
  else FAccent.ItemIndex := EnsureRange(Accent, 0, Count);
  AccentChanged(FAccent);
end;

procedure TSerifVoicevoxDictionaryPage.AnalyzeClick(Sender: TObject);
begin
  if Assigned(FWorker) then Exit;
  Inc(FInputRevision);
  FAnalyzePending := True;
  TimerTimer(nil);
end;

procedure TSerifVoicevoxDictionaryPage.TimerTimer(Sender: TObject);
begin
  FTimer.Enabled := False;
  if not FAnalyzePending or Assigned(FWorker) then Exit;
  FAnalyzePending := False;
  if (Trim(FSurface.Text) = '') or (FStyleId < 0) then Exit;
  SetStatus('現在の読みを取得中…');
  Start(vdaAnalyze, Draft);
end;

procedure TSerifVoicevoxDictionaryPage.Start(const Action: TSerifVoicevoxDictionaryAction;
  const Word: TSerifVoicevoxDictionaryWord);
begin
  if Assigned(FWorker) then Exit;
  FWorker := TSerifVoicevoxDictionaryWorker.Create(FNotifyHandle, Action,
    FInputRevision, FStyleId, Word);
  UpdateState;
  FWorker.Start;
end;

procedure TSerifVoicevoxDictionaryPage.Complete(var Msg: TMessage);
var
  Worker: TSerifVoicevoxDictionaryWorker;
  PlayAfterSave: Boolean;
  ReturnAfterSave: Boolean;
begin
  if Msg.Msg <> VOICEVOX_DICTIONARY_COMPLETE then
  begin
    Msg.Result := DefWindowProc(FNotifyHandle, Msg.Msg, Msg.WParam, Msg.LParam);
    Exit;
  end;
  Msg.Result := 0;
  if not Assigned(FWorker) or (Cardinal(Msg.WParam) <> FWorker.Revision) then Exit;
  Worker := FWorker;
  Worker.WaitFor;
  FWorker := nil;
  try
    if Worker.Action = vdaAnalyze then
    begin
      if Worker.Revision = FInputRevision then
        if Worker.Success then
        begin
          FUpdating := True;
          try
            FReading.Text := Worker.Word.Pronunciation;
            RebuildAccent(Worker.Word.AccentType);
          finally
            FUpdating := False;
          end;
          SetStatus('読みとアクセントを修正し、「登録してセリフ試聴」で文中の読み方を確認できます。');
        end
        else SetStatus(Worker.ErrorMessage);
    end
    else if Worker.Success then
      case Worker.Action of
        vdaLoad:
          begin
            FWords := Worker.Words;
            TArray.Sort<TSerifVoicevoxDictionaryWord>(FWords,
              TComparer<TSerifVoicevoxDictionaryWord>.Construct(
                function(const Left, Right: TSerifVoicevoxDictionaryWord): Integer
                begin
                  Result := CompareText(Left.Surface, Right.Surface);
                end));
            FLoaded := True;
            UpdateList;
            if FListMode then SetStatus(Format('%d件の単語が登録されています。', [Length(FWords)]));
          end;
        vdaSave:
          begin
            PlayAfterSave := FPlayAfterSave;
            ReturnAfterSave := FReturnAfterSave;
            CancelPendingActions;
            Restore(Worker.Word);
            FLoaded := False;
            SetStatus('登録しました。続けて修正すると同じ単語を更新します。');
            if Assigned(FOnChanged) then FOnChanged(Self);
            if ReturnAfterSave and Assigned(FOnBack) then FOnBack(Self);
            if PlayAfterSave and Assigned(FOnPreview) then FOnPreview(Self);
          end;
        vdaDelete:
          begin
            FLoaded := False;
            if FOriginal.UUID = Worker.Word.UUID then Restore(TSerifVoicevoxDictionaryWord.NewWord);
            SetStatus('単語を削除しました。');
            if Assigned(FOnChanged) then FOnChanged(Self);
            FLoadPending := True;
          end;
      end
    else
    begin
      CancelPendingActions;
      // タイムアウト等ではEngine側だけ更新済みの可能性もあるため旧解析を無効にする。
      if (Worker.Action in [vdaSave, vdaDelete]) and Assigned(FOnChanged) then FOnChanged(Self);
      SetStatus(Worker.ErrorMessage);
    end;
  finally
    Worker.Free;
    UpdateState;
  end;
  if FLoadPending and FListMode then RefreshClick(nil)
  else if FAnalyzePending then FTimer.Enabled := True;
end;

procedure TSerifVoicevoxDictionaryPage.SetStatus(const Text: string);
begin
  FStatus.Caption := Text;
  FStatus.Hint := Text;
  FStatus.ShowHint := True;
end;

procedure TSerifVoicevoxDictionaryPage.UpdateState;
var
  Mutation: Boolean;
  Valid: Boolean;
  Word: TSerifVoicevoxDictionaryWord;
  Selection: TSerifVoicevoxDictionaryWord;
begin
  if not FInitialized or not Assigned(FList) then Exit;
  Word := Draft;
  Mutation := Assigned(FWorker) and (FWorker.Action in [vdaSave, vdaDelete]);
  Valid := (Word.Surface <> '') and (Word.WordType <> '') and
    (Length(TSerifVoicevoxUserDictionary.Moras(Word.Pronunciation)) > 0);
  FSurface.Enabled := not Mutation;
  FReading.Enabled := not Mutation;
  FType.Enabled := not Mutation;
  FPriority.Enabled := not Mutation;
  FAccent.Enabled := not Mutation and Valid;
  FAccentPaint.Enabled := FAccent.Enabled;
  FAnalyzeButton.Enabled := not Assigned(FWorker) and (Word.Surface <> '') and (FStyleId >= 0);
  FSaveButton.Enabled := not Assigned(FWorker) and Valid;
  FWordPreviewButton.Enabled := FPreviewActive or (FSaveButton.Enabled and (FContextText <> ''));
  FBackButton.Enabled := FSaveButton.Enabled;
  FNewButton.Enabled := not Mutation;
  FResetButton.Enabled := not Mutation;
  FListNewButton.Enabled := not Mutation;
  FEditButton.Enabled := not Assigned(FWorker) and SelectedWord(Selection);
  FDeleteButton.Enabled := not Assigned(FWorker) and SelectedWord(Selection);
  FRefreshButton.Enabled := not Assigned(FWorker);
  if FOriginal.UUID = '' then
  begin
    FTitle.Caption := '単語を登録';
    FSaveButton.Caption := '登録';
    FWordPreviewButton.Caption := '登録してセリフ試聴';
    FBackButton.Caption := '登録して読みへ戻る';
  end
  else
  begin
    FTitle.Caption := '登録単語を編集';
    FSaveButton.Caption := '更新';
    FWordPreviewButton.Caption := '更新してセリフ試聴';
    FBackButton.Caption := '更新して読みへ戻る';
  end;
  if FPreviewActive then FWordPreviewButton.Caption := '停止';
end;

procedure TSerifVoicevoxDictionaryPage.SaveWord(const PlayAfterSave, ReturnAfterSave: Boolean);
var
  Word: TSerifVoicevoxDictionaryWord;
begin
  if Assigned(FWorker) then
  begin
    SetStatus('処理の完了後にもう一度操作してください。');
    Exit;
  end;
  Word := Draft;
  if (Word.Surface = '') or (Word.WordType = '') or
    (Length(TSerifVoicevoxUserDictionary.Moras(Word.Pronunciation)) = 0) then
  begin
    SetStatus('単語・カタカナの読み・品詞を入力してください。');
    Exit;
  end;
  if not Dirty and (Word.UUID <> '') then
  begin
    if ReturnAfterSave and Assigned(FOnBack) then FOnBack(Self);
    if PlayAfterSave and Assigned(FOnPreview) then FOnPreview(Self);
    Exit;
  end;
  FPlayAfterSave := PlayAfterSave;
  FReturnAfterSave := ReturnAfterSave;
  FAnalyzePending := False;
  FTimer.Enabled := False;
  SetStatus('辞書へ登録中…');
  Start(vdaSave, Word);
end;

procedure TSerifVoicevoxDictionaryPage.SaveClick(Sender: TObject);
begin
  SaveWord(False, False);
end;

procedure TSerifVoicevoxDictionaryPage.SaveAndPreview;
begin
  SaveWord(True, False);
end;

procedure TSerifVoicevoxDictionaryPage.SetPreviewActive(const Value: Boolean);
begin
  FPreviewActive := Value;
  UpdateState;
end;

procedure TSerifVoicevoxDictionaryPage.PreviewClick(Sender: TObject);
begin
  if Assigned(FOnPreview) then FOnPreview(Self);
end;

function TSerifVoicevoxDictionaryPage.Busy: Boolean;
begin
  Result := Assigned(FWorker);
end;

procedure TSerifVoicevoxDictionaryPage.BackClick(Sender: TObject);
begin
  SaveWord(False, True);
end;

procedure TSerifVoicevoxDictionaryPage.ResetClick(Sender: TObject);
begin
  if Assigned(FWorker) and (FWorker.Action in [vdaSave, vdaDelete]) then Exit;
  Restore(FOriginal);
  SetStatus('編集前の値へ戻しました。');
end;

procedure TSerifVoicevoxDictionaryPage.NewClick(Sender: TObject);
begin
  if Assigned(FWorker) and (FWorker.Action in [vdaSave, vdaDelete]) then Exit;
  if Dirty then SetStatus('未登録の変更があります。登録するか「変更を戻す」を押してから新しい単語へ進んでください。')
  else
  begin
    Restore(TSerifVoicevoxDictionaryWord.NewWord);
    SetStatus('登録する単語を入力してください。現在の読みがカタカナで表示されます。');
  end;
  if Assigned(FOnEdit) then FOnEdit(Self);
end;

procedure TSerifVoicevoxDictionaryPage.SetContext(const Text: string; const StyleId: Integer);
begin
  if (FContextText <> Text) or (FStyleId <> StyleId) then CancelPendingActions;
  if FStyleId <> StyleId then
  begin
    Inc(FInputRevision);
    if FInitialized and (Trim(FSurface.Text) <> '') and (Trim(FReading.Text) = '') then
    begin
      FAnalyzePending := True;
      FTimer.Enabled := True;
    end;
  end;
  FContextText := Text;
  FStyleId := StyleId;
  UpdateState;
end;

procedure TSerifVoicevoxDictionaryPage.CancelPendingActions;
begin
  FPlayAfterSave := False;
  FReturnAfterSave := False;
end;

procedure TSerifVoicevoxDictionaryPage.ShowEditor;
begin
  Initialize;
  FListMode := False;
  FListPanel.Visible := False;
  FEditor.Visible := True;
  UpdateState;
  LayoutPages;
  if FSurface.Text = '' then
  begin
    if FSurface.CanFocus then FSurface.SetFocus;
  end
  else if FReading.CanFocus then FReading.SetFocus;
end;

procedure TSerifVoicevoxDictionaryPage.ShowList;
begin
  Initialize;
  FListMode := True;
  FEditor.Visible := False;
  FListPanel.Visible := True;
  if not FLoaded then RefreshClick(nil);
  UpdateState;
  LayoutPages;
  if FFilter.CanFocus then FFilter.SetFocus;
end;

procedure TSerifVoicevoxDictionaryPage.RefreshClick(Sender: TObject);
begin
  FLoadPending := True;
  if Assigned(FWorker) then Exit;
  FLoadPending := False;
  FDeleteUUID := '';
  FDeleteCancel.Visible := False;
  FDeleteButton.Caption := '削除';
  SetStatus('辞書一覧を取得中…');
  Start(vdaLoad, TSerifVoicevoxDictionaryWord.NewWord);
end;

procedure TSerifVoicevoxDictionaryPage.UpdateList;
var
  Filter: string;
  ReadingFilter: string;
  I: Integer;
  Index: Integer;
begin
  Filter := Trim(FFilter.Text);
  ReadingFilter := TSerifVoicevoxUserDictionary.NormalizeReading(Filter);
  FList.Items.BeginUpdate;
  try
    FList.Clear;
    FVisibleWords := nil;
    for I := 0 to High(FWords) do
      if (Filter = '') or FWords[I].Surface.Contains(Filter) or
        FWords[I].Surface.Contains(ReadingFilter) or FWords[I].Pronunciation.Contains(ReadingFilter) then
      begin
        Index := Length(FVisibleWords);
        SetLength(FVisibleWords, Index + 1);
        FVisibleWords[Index] := I;
        FList.Items.Add(FWords[I].Surface + '　' + FWords[I].Pronunciation +
          Format('　［アクセント %d］', [FWords[I].AccentType]));
      end;
  finally
    FList.Items.EndUpdate;
  end;
  ListSelection(nil);
end;

procedure TSerifVoicevoxDictionaryPage.FilterChange(Sender: TObject);
begin
  UpdateList;
end;

function TSerifVoicevoxDictionaryPage.SelectedWord(out Word: TSerifVoicevoxDictionaryWord): Boolean;
var
  Index: Integer;
begin
  Word := TSerifVoicevoxDictionaryWord.NewWord;
  Index := FList.ItemIndex;
  Result := (Index >= 0) and (Index < Length(FVisibleWords));
  if Result then Word := FWords[FVisibleWords[Index]];
end;

procedure TSerifVoicevoxDictionaryPage.ListSelection(Sender: TObject);
begin
  FDeleteUUID := '';
  FDeleteCancel.Visible := False;
  FDeleteButton.Caption := '削除';
  UpdateState;
  LayoutPages;
end;

procedure TSerifVoicevoxDictionaryPage.EditClick(Sender: TObject);
var
  Word: TSerifVoicevoxDictionaryWord;
begin
  if Assigned(FWorker) then Exit;
  if not SelectedWord(Word) then Exit;
  if Dirty then
    SetStatus('未登録の変更があります。登録するか「変更を戻す」を押してから別の単語を開いてください。')
  else
  begin
    Restore(Word);
    SetStatus('読み・アクセントを変更できます。試聴は上のセリフ全体が対象です。');
  end;
  if Assigned(FOnEdit) then FOnEdit(Self);
end;

procedure TSerifVoicevoxDictionaryPage.DeleteClick(Sender: TObject);
var
  Word: TSerifVoicevoxDictionaryWord;
begin
  if Assigned(FWorker) or not SelectedWord(Word) then Exit;
  if Dirty and (FOriginal.UUID = Word.UUID) then
  begin
    SetStatus('この単語には未登録の変更があります。登録するか、編集ページで「変更を戻す」を押してください。');
    Exit;
  end;
  if FDeleteUUID <> Word.UUID then
  begin
    FDeleteUUID := Word.UUID;
    FDeleteButton.Caption := '削除を確定';
    FDeleteCancel.Visible := True;
    SetStatus('「' + Word.Surface + '」を辞書から削除します。もう一度「削除を確定」を押してください。');
    LayoutPages;
    Exit;
  end;
  DeleteCancelClick(nil);
  SetStatus('単語を削除中…');
  Start(vdaDelete, Word);
end;

procedure TSerifVoicevoxDictionaryPage.DeleteCancelClick(Sender: TObject);
begin
  FDeleteUUID := '';
  FDeleteButton.Caption := '削除';
  FDeleteCancel.Visible := False;
  if Assigned(Sender) then SetStatus('削除を取り消しました。');
  LayoutPages;
end;

procedure TSerifVoicevoxDictionaryPage.FieldKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_F5) and (Shift = []) then
  begin
    Key := 0;
    if Assigned(FOnPreview) then FOnPreview(Self);
  end
  else if (Sender = FList) and (Key = VK_RETURN) then
  begin
    Key := 0;
    EditClick(nil);
  end
  else if (Sender = FList) and (Key = VK_DELETE) then
  begin
    Key := 0;
    DeleteClick(nil);
  end;
end;

end.
