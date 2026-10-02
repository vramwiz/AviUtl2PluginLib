unit PsdArtEditorForm;

interface

uses System.Types, System.Classes, System.SysUtils, System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Dialogs, Vcl.Menus, Vcl.Samples.Spin, Vcl.Graphics, ArtDocument, ArtLayerList, ArtFileHistory, ArtEditorDarkComboBox, ArtExchange, ArtUndo, ArtPipeBridge, ArtPipeProtocol, System.JSON;

type
  TArtEditorSaveInfo = record
    OldFileName, NewFileName: string;
    NamesChanged, VisibilityChanged, StructureChanged, VisualChanged: Boolean;
    // These clones are owned by the form and valid only during OnSaved.
    OriginalDocument, EditedDocument: TArtDocument;
  end;
  TArtEditorSavedEvent = procedure(Sender: TObject; const Info: TArtEditorSaveInfo) of object;
  TPsdArtEditorForm = class(TForm)
  private
    FExchange: TArtExchange;
    FUndo: TArtUndo;
    FPipe: TArtPipeBridge;
    FProtocol: TArtPipeProtocol;
    FCurrentJobId,FOperation: string;
    FBusy: Boolean;

    FActivity: TLabel;
    FCancelAi: TButton;
    FUndoItem,FRedoItem: TMenuItem;
    FPrompt: TMemo;
    FJobPath: TEdit;
    FExportAi, FImportAi: TButton;
    FResultDialog,FRecoveryDialog: TOpenDialog;
    FDocument: TArtDocument;
    FFileName: string;
    FModified: Boolean;
    FTree: TArtLayerList;
    FPaint: TPaintBox;
    FBitmap: Vcl.Graphics.TBitmap;
    FStatus: TLabel;
    FHistory: TArtFileHistory;
    FHistoryMenu: TMenuItem;
    FLoadingSaved: Boolean;
    FSave, FSaveAs, FClose: TMenuItem;
    FOpenDialog: TOpenDialog;
    FSaveDialog: TSaveDialog;
    FCanEdit, FCanRender, FManaged: Boolean;
    FManagedRoot, FExchangeRoot: string;
    FInitialDocument: TArtDocument;
    FLastWrittenPath: string;
    FLastWrittenBytes: TBytes;
    FOnSaved: TArtEditorSavedEvent;
    FReadOnlyAiPanel: TPanel;
    FPngDialog: TOpenDialog;
    FImportItem, FReplaceItem, FPositionItem: TMenuItem;
    FX,FY: TSpinEdit;
    FPositionApply: TButton;
    FPartGroup, FPartChoice: TArtEditorDarkComboBox;
    FGroupItem: TMenuItem;
    FUpdatingParts: Boolean;
    FZoom, FPanX, FPanY: Double;
    FDragging: Boolean;
    FDragStart: TPoint;
    function GetModified: Boolean;
    function IsManagedPath(const FileName: string): Boolean;
    procedure RequireManagedEdit;
    procedure CaptureInitialDocument;
    procedure RenameFileClick(Sender: TObject);
    procedure PreviewWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    function DispatchCommand(const Command: string; Args: TJSONObject): TJSONObject;
    function JobJson(Job: TArtExchangeJob): TJSONObject;
    procedure UpdateActivity;
    procedure BeginOperation(const Name: string);
    procedure EndOperation;
    procedure BeginEdit;
    procedure CommitEdit;
    procedure RestoreEdit(Redo: Boolean);
    procedure UndoClick(Sender: TObject);
    procedure RedoClick(Sender: TObject);
    procedure CancelAiClick(Sender: TObject);
    procedure RecoverAiClick(Sender: TObject);
    procedure ResetAiJobs;
    procedure ExportAiClick(Sender: TObject);
    procedure ImportAiClick(Sender: TObject);
    procedure UpdateParts;
    procedure PartGroupChange(Sender: TObject);
    procedure PartChoiceChange(Sender: TObject);
    procedure GroupClick(Sender: TObject);
    procedure NewPngClick(Sender: TObject);
    procedure ImportPngClick(Sender: TObject);
    procedure ReplacePngClick(Sender: TObject);
    procedure PositionClick(Sender: TObject);
    procedure PreviewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
    procedure PreviewMouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
    procedure PreviewMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
    function PreviewRect: TRect;
    procedure HistoryClick(Sender: TObject);
    procedure RebuildHistory;
    procedure LayerAttributes(Sender: TObject; Layer: TArtLayer; Visible: Boolean; Opacity: Byte);
    procedure OpenClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure SaveAsClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure ExitClick(Sender: TObject);
    procedure TreeChange(Sender: TObject);
    procedure LayerRename(Sender: TObject; Layer: TArtLayer; const Name: string);
    procedure PaintPreview(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    function ConfirmDiscard: Boolean;
    function RenderEditable: TBytes;
    procedure SetPreview(const RGBA: TBytes);
    procedure UpdateStatus;
    procedure RebuildTree;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateWithHistory(AOwner: TComponent; const HistoryDirectory: string);
    constructor CreateForHost(AOwner: TComponent; const ManagedRoot, ExchangeRoot, HistoryRoot: string);
    procedure NewBlank(const FileName: string; Width: Integer = 1024; Height: Integer = 1024);
    procedure RenamePsdFile(const NewBaseName: string);
    function TryFinish(ShowError: Boolean = True): Boolean;
    property FileName: string read FFileName;
    property ManagedDocument: Boolean read FManaged;
    property OnSaved: TArtEditorSavedEvent read FOnSaved write FOnSaved;
    property FileHistory: TArtFileHistory read FHistory;
    destructor Destroy; override;
    function ExportAiJob(const Prompt,Root: string; Workspace: TJSONObject = nil): string;
    function PipeName: string;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    procedure Undo;
    procedure Redo;
    procedure CancelAiJob(const Id: string);
    property Busy: Boolean read FBusy;
    property ActivityControl: TLabel read FActivity;
    procedure ImportAiResult(const FileName: string);
    procedure RecoverAiJob(const Directory: string);
    property PromptControl: TMemo read FPrompt;
    property AiJobPathControl: TEdit read FJobPath;
    procedure CreateGroup(const Name: string; Exclusive: Boolean);
    procedure SelectPart(Layer: TArtLayer);
    property PartGroupControl: TArtEditorDarkComboBox read FPartGroup;
    property PartChoiceControl: TArtEditorDarkComboBox read FPartChoice;
    procedure NewFromPng(const FileName: string);
    procedure ImportPngFile(const FileName: string);
    procedure ReplaceSelectedPng(const FileName: string);
    procedure MoveSelectedLayer(X,Y: Integer);
    procedure OpenPsdFile(const FileName: string);
    procedure SavePsdFile(const FileName: string);
    // 明示的なパーツ選択では、既に可視の対象でも兄弟の排他状態を揃える。
    procedure ApplySelectedLayer(const Name: string; Visible: Boolean; Opacity: Byte; ForceExclusive: Boolean = False);
    property OpenDialog: TOpenDialog read FOpenDialog;
    property SaveDialog: TSaveDialog read FSaveDialog;
    property Document: TArtDocument read FDocument;
    property LayerList: TArtLayerList read FTree;
    property PreviewControl: TPaintBox read FPaint;
    property PreviewBounds: TRect read PreviewRect;
    property Modified: Boolean read GetModified;
    property CanEdit: Boolean read FCanEdit;
  end;


implementation

uses System.Math, System.IOUtils, System.UITypes, Winapi.Windows, System.Hash, ArtPsd, ArtPng, ArtLayerName, ArtParts,
  ArtPipeEditorCommands;

{$R *.dfm}
type
  TArtPaintBoxAccess = class(TPaintBox);
  TArtPreviewPaintBox = class(TPaintBox)
  public
    constructor Create(AOwner: TComponent); override;
  end;

constructor TArtPreviewPaintBox.Create(AOwner: TComponent);
begin
  inherited;
  // PaintPreview covers every pixel; avoid erasing the background before it.
  ControlStyle := ControlStyle+[csOpaque];
end;

function TPsdArtEditorForm.PipeName: string;
begin if FPipe=nil then Result := '' else Result := FPipe.Name; end;
function TPsdArtEditorForm.CanUndo: Boolean;
begin Result := not FBusy and FCanEdit and FUndo.CanUndo; end;
function TPsdArtEditorForm.CanRedo: Boolean;
begin Result := not FBusy and FCanEdit and FUndo.CanRedo; end;
procedure TPsdArtEditorForm.BeginEdit;
var Id: string;
begin
  Id := ''; if FTree.Selected<>nil then Id := FTree.Selected.Id;
  FUndo.BeginEdit(FDocument,Id,FModified);
end;
procedure TPsdArtEditorForm.CommitEdit;
begin FUndo.CommitEdit; end;
procedure TPsdArtEditorForm.RestoreEdit(Redo: Boolean);
var Target,Current: TArtEditState; Candidate,Old: TArtDocument; Pixels: TBytes; L: TArtLayer; Selection: string;
begin
  if FBusy or not FCanEdit then raise EArtFormat.Create('今は元に戻せません。');
  FTree.FinishRename(True); Target := FUndo.Peek(Redo);
  Candidate := Target.Document.Clone; Current := nil;
  try
    // Restoring old content must never reuse an old revision number.
    Candidate.Revision := FDocument.Revision; Candidate.Changed;
    if FCanRender then Pixels := RenderPsdLayers(Candidate); Selection := '';
    if FTree.Selected<>nil then Selection := FTree.Selected.Id;
    Current := TArtEditState.Create(FDocument,Selection,FModified);
  except Candidate.Free; Current.Free; raise; end;
  Old := FDocument; FDocument := Candidate;
  try if FCanRender then SetPreview(Pixels); except FDocument := Old; Candidate.Free; Current.Free; raise; end;
  FTree.SetRoots(nil); Old.Free; FModified := Target.Modified; Selection := Target.SelectedId;
  FUndo.CommitRestore(Current,Redo); ResetAiJobs; RebuildTree;
  L := FDocument.FindLayer(Selection); if L<>nil then begin FTree.Selected := L; FTree.RevealSelected; end;
  UpdateStatus;
end;
procedure TPsdArtEditorForm.Undo;
begin RestoreEdit(False); end;
procedure TPsdArtEditorForm.Redo;
begin RestoreEdit(True); end;
procedure TPsdArtEditorForm.UndoClick(Sender: TObject);
begin try Undo; except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0); end; end;
procedure TPsdArtEditorForm.RedoClick(Sender: TObject);
begin try Redo; except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0); end; end;
procedure TPsdArtEditorForm.BeginOperation(const Name: string);
begin
  if FBusy then raise EArtFormat.Create('別の処理を実行中です。');
  FBusy := True; FOperation := Name; Screen.Cursor := crHourGlass;
  UpdateActivity; FActivity.Update;
end;
procedure TPsdArtEditorForm.EndOperation;
begin FBusy := False; FOperation := ''; Screen.Cursor := crDefault; UpdateActivity; end;
procedure TPsdArtEditorForm.UpdateActivity;
var Job: TArtExchangeJob; StateText: string;
begin
  if FTree<>nil then FTree.VisibilityEnabled := not FBusy and FCanEdit and (FDocument<>nil);
  if FActivity=nil then Exit;
  StateText := '待機中';
  if FBusy then StateText := FOperation
  else if FCurrentJobId<>'' then begin
    Job := FExchange.FindJob(FCurrentJobId);
    if Job.State='queued' then StateText := 'AI生成待ち'
    else if Job.State='running' then StateText := 'AI生成中'
    else if Job.State='ready' then StateText := '生成完了・取込待ち'
    else if Job.State='failed' then StateText := 'AI処理失敗'
    else if Job.State='cancelled' then StateText := 'AI処理を中止しました'
    else StateText := '取込完了';
    if (Job.State<>'completed') and (Job.State<>'cancelled') and (FDocument<>nil) and (FDocument.Revision<>Job.Revision) then StateText := '文書が変更されています・新しいAIジョブを書き出してください';
    StateText := StateText+Format(' (%d%%) %s',[Job.Progress,Job.MessageText]);
  end;
  if (FPrompt<>nil) and (FActivity.Caption<>StateText) then FPrompt.Lines.Add('AI: '+StateText);
  FActivity.Caption := StateText;
  FActivity.Hint := '接続先: \\.\pipe\'+PipeName; FActivity.ShowHint := True;
  if FUndoItem<>nil then FUndoItem.Enabled := CanUndo;
  if FRedoItem<>nil then FRedoItem.Enabled := CanRedo;
  if FCancelAi<>nil then begin
    FCancelAi.Enabled := not FBusy and (FCurrentJobId<>'');
    if FCancelAi.Enabled then begin
      Job := FExchange.FindJob(FCurrentJobId);
      FCancelAi.Enabled := (Job.State<>'completed') and (Job.State<>'cancelled');
    end;
  end;
end;
procedure TPsdArtEditorForm.CancelAiJob(const Id: string);
var Job: TArtExchangeJob;
begin
  RequireManagedEdit;
  if FBusy then raise EArtFormat.Create('処理中です。');
  Job := FExchange.FindJob(Id);
  // Cancellation also works after local edits have made the result stale.
  if Job.State='completed' then raise EArtFormat.Create('取り込み済みです。Undoで戻してください。');
  FExchange.CancelJob(Id); UpdateActivity;
end;
procedure TPsdArtEditorForm.CancelAiClick(Sender: TObject);
begin try CancelAiJob(FCurrentJobId); except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0); end; end;
function TPsdArtEditorForm.JobJson(Job: TArtExchangeJob): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('jobId',Job.Id); Result.AddPair('directory',Job.Directory); Result.AddPair('state',Job.State);
  Result.AddPair('progress',TJSONNumber.Create(Job.Progress)); Result.AddPair('message',Job.MessageText);
  Result.AddPair('documentId',Job.DocumentId); Result.AddPair('ifRevision',UIntToStr(Job.Revision));
  Result.AddPair('stale',TJSONBool.Create((Job.State<>'completed') and ((FDocument=nil) or (FDocument.SessionId<>Job.DocumentId) or (FDocument.Revision<>Job.Revision))));
end;
function TPsdArtEditorForm.DispatchCommand(const Command: string; Args: TJSONObject): TJSONObject;
var Id,Path: string; Job: TArtExchangeJob;
begin
  if FBusy then raise EArtFormat.Create('Application is busy');
  if Command='status' then begin
    Result := TJSONObject.Create;
    Result.AddPair('pipeName',PipeName); Result.AddPair('busy',TJSONBool.Create(FBusy));
    Result.AddPair('canUndo',TJSONBool.Create(CanUndo)); Result.AddPair('canRedo',TJSONBool.Create(CanRedo));
    Result.AddPair('modified',TJSONBool.Create(GetModified)); Result.AddPair('canEdit',TJSONBool.Create(FCanEdit));
    Result.AddPair('managed',TJSONBool.Create(FManaged)); Result.AddPair('fileName',FFileName);
    Result.AddPair('supportedCommands',EditorPipeCommands);
    Result.AddPair('exchangeRoot',FExchangeRoot); Result.AddPair('pendingFileName',FLastWrittenPath);
    if FDocument<>nil then begin Result.AddPair('documentId',FDocument.SessionId); Result.AddPair('revision',UIntToStr(FDocument.Revision)); end;
    Id := FCurrentJobId; if Args.GetValue('jobId')<>nil then Id := CommandString(Args,'jobId');
    if Id<>'' then begin
      try Result.AddPair('job',JobJson(FExchange.FindJob(Id)));
      except Result.Free; raise; end;
    end;
    Exit;
  end;
  if TryEditorPipeCommand(Self,Command,Args,Result) then Exit;
  if not ((Command='undo') or (Command='redo')) then RequireManagedEdit;
  if Command='export' then begin
    if (Args.GetValue('workspace')<>nil) and not (Args.GetValue('workspace') is TJSONObject) then
      raise EArtFormat.Create('Workspace object expected');
    Path := ExportAiJob(CommandString(Args,'prompt'),FExchangeRoot,
      TJSONObject(Args.GetValue('workspace')));
    Exit(JobJson(FExchange.FindJob(ExtractFileName(Path))));
  end;
  if Command='recover' then begin
    if GetModified then raise EArtFormat.Create('Save the current document before recovery');
    RecoverAiJob(CommandString(Args,'directory')); Exit(JobJson(FExchange.FindJob(FCurrentJobId)));
  end;
  if Command='undo' then begin Undo; Exit(TJSONObject.Create); end;
  if Command='redo' then begin Redo; Exit(TJSONObject.Create); end;
  Id := CommandString(Args,'jobId'); Job := FExchange.FindJob(Id);
  if Command='import' then ImportAiResult(TPath.Combine(Job.Directory,'result.json'))
  else if Command='progress' then FExchange.NotifyJob(FDocument,Id,CommandString(Args,'state'),CommandString(Args,'message'),CommandInteger(Args,'progress'))
  else if Command='cancel' then CancelAiJob(Id)
  else raise EArtFormat.Create('Unknown command: '+Command);
  UpdateActivity; Result := JobJson(Job);
end;
constructor TPsdArtEditorForm.Create(AOwner: TComponent);
begin
  CreateWithHistory(AOwner,'');
end;

constructor TPsdArtEditorForm.CreateForHost(AOwner: TComponent; const ManagedRoot, ExchangeRoot, HistoryRoot: string);
begin
  if (ManagedRoot='') or (ExchangeRoot='') or (HistoryRoot='') then
    raise EArtFormat.Create('The host must provide the PSD, exchange and history directories');
  FManagedRoot := ExcludeTrailingPathDelimiter(TPath.GetFullPath(ManagedRoot));
  FExchangeRoot := ExcludeTrailingPathDelimiter(TPath.GetFullPath(ExchangeRoot));
  CreateWithHistory(AOwner,HistoryRoot);
end;
constructor TPsdArtEditorForm.CreateWithHistory(AOwner: TComponent; const HistoryDirectory: string);
var RightPanel, StatusPanel, PositionPanel, PartsPanel, AiPanel, AiButtons, PreviewPanel: TPanel; FileMenu, LayerMenu, Item: TMenuItem; LabelControl: TLabel;
    Splitter: TSplitter; EditMenu: TMenuItem;
begin
  inherited Create(AOwner);
  FHistory := TArtFileHistory.Create(HistoryDirectory);
  FExchange := TArtExchange.Create; FUndo := TArtUndo.Create;
  FBitmap := Vcl.Graphics.TBitmap.Create;
  Menu := TMainMenu.Create(Self);
  FileMenu := TMenuItem.Create(Self); FileMenu.Caption := 'ファイル(&F)'; Menu.Items.Add(FileMenu);
  Item := TMenuItem.Create(Self); Item.Caption := '開く(&O)...'; Item.ShortCut := TextToShortCut('Ctrl+O');
  Item.OnClick := OpenClick; Item.Enabled := False; FileMenu.Add(Item);
  FSave := TMenuItem.Create(Self); FSave.Caption := '上書き保存(&S)'; FSave.ShortCut := TextToShortCut('Ctrl+S');
  FSave.OnClick := SaveClick; FSave.Enabled := False; FileMenu.Add(FSave);
  FSaveAs := TMenuItem.Create(Self); FSaveAs.Caption := 'PSDファイル名を変更(&A)...';
  FSaveAs.ShortCut := TextToShortCut('Ctrl+Shift+S'); FSaveAs.OnClick := SaveAsClick;
  FSaveAs.Enabled := False; FileMenu.Add(FSaveAs);
  FClose := TMenuItem.Create(Self); FClose.Caption := '閉じる(&C)'; FClose.ShortCut := TextToShortCut('Ctrl+W');
  FClose.OnClick := CloseClick; FClose.Enabled := False; FileMenu.Add(FClose);
  Item := TMenuItem.Create(Self); Item.Caption := '-'; FileMenu.Add(Item);
  Item := TMenuItem.Create(Self); Item.Caption := '終了(&X)'; Item.OnClick := ExitClick; FileMenu.Add(Item);
  FHistoryMenu := TMenuItem.Create(Self); FHistoryMenu.Caption := '履歴(&H)'; FHistoryMenu.Visible := False; FileMenu.Insert(4,FHistoryMenu);
  Item := TMenuItem.Create(Self); Item.Caption := 'PNGから新規作成(&N)...'; Item.ShortCut := TextToShortCut('Ctrl+N'); Item.OnClick := NewPngClick;
  FImportItem := TMenuItem.Create(Self); FImportItem.Caption := 'PNGをレイヤーとして追加(&I)...'; FImportItem.ShortCut := TextToShortCut('Ctrl+I'); FImportItem.OnClick := ImportPngClick;
  LayerMenu := TMenuItem.Create(Self); LayerMenu.Caption := 'レイヤー(&L)';
  FReplaceItem := TMenuItem.Create(Self); FReplaceItem.Caption := '選択画像をPNGで置換(&R)...'; FReplaceItem.OnClick := ReplacePngClick; FReplaceItem.Enabled := False; LayerMenu.Add(FReplaceItem);
  FPositionItem := TMenuItem.Create(Self); FPositionItem.Caption := '配置座標を入力(&P)'; FPositionItem.OnClick := PositionClick; FPositionItem.Enabled := False; LayerMenu.Add(FPositionItem);
  FGroupItem := TMenuItem.Create(Self); FGroupItem.Caption := 'グループを作成(&G)...'; FGroupItem.OnClick := GroupClick; FGroupItem.Enabled := False; LayerMenu.Add(FGroupItem);
  EditMenu := TMenuItem.Create(Self); EditMenu.Caption := '編集(&E)';
  FUndoItem := TMenuItem.Create(Self); FUndoItem.Caption := '元に戻す(&U)'; FUndoItem.ShortCut := TextToShortCut('Ctrl+Z'); FUndoItem.OnClick := UndoClick; FUndoItem.Enabled := False; EditMenu.Add(FUndoItem);
  FRedoItem := TMenuItem.Create(Self); FRedoItem.Caption := 'やり直す(&R)'; FRedoItem.ShortCut := TextToShortCut('Ctrl+Y'); FRedoItem.OnClick := RedoClick; FRedoItem.Enabled := False; EditMenu.Add(FRedoItem);
  Item := TMenuItem.Create(Self); Item.Caption := 'AIジョブを再開...'; Item.OnClick := RecoverAiClick;
  RebuildHistory;
  // Keep legacy API control objects for existing integration callers; hide their panels.
  // The visible UI consists only of preview, read-only layers and the AI transcript.
  StatusPanel := TPanel.Create(Self); StatusPanel.Parent := Self; StatusPanel.Visible := False;
  StatusPanel.Align := alNone; StatusPanel.Height := 75;
  FStatus := TLabel.Create(Self); FStatus.Parent := StatusPanel;
  FStatus.Align := alClient; FStatus.WordWrap := True; FStatus.Layout := tlCenter;
  FStatus.Caption := 'PSDを開くと、レイヤー階層と画像を表示します。';
  FActivity := TLabel.Create(Self); FActivity.Parent := StatusPanel; FActivity.Align := alBottom; FActivity.Height := 20;
  AiPanel := TPanel.Create(Self); FReadOnlyAiPanel := AiPanel; AiPanel.Parent := Self; AiPanel.Align := alBottom; AiPanel.Height := 148;
  FJobPath := TEdit.Create(Self);  FJobPath.Align := alBottom; FJobPath.ReadOnly := True; FJobPath.Text := 'AIジョブのフォルダーがここに表示されます。';
  LabelControl := TLabel.Create(Self); LabelControl.Parent := AiPanel; LabelControl.Align := alTop; LabelControl.Caption := 'AIとのやりとり';
  AiButtons := TPanel.Create(Self); AiButtons.Parent := Self; AiButtons.Visible := False;  AiButtons.Align := alNone; AiButtons.Width := 194;
  FExportAi := TButton.Create(Self); FExportAi.Parent := AiButtons; FExportAi.SetBounds(8,6,176,28); FExportAi.Caption := 'AI向けに書き出す'; FExportAi.OnClick := ExportAiClick; FExportAi.Enabled := False;
  FImportAi := TButton.Create(Self); FImportAi.Parent := AiButtons; FImportAi.SetBounds(8,40,176,28); FImportAi.Caption := '生成結果を取り込む'; FImportAi.OnClick := ImportAiClick; FImportAi.Enabled := False;
  FCancelAi := TButton.Create(Self); FCancelAi.Parent := AiButtons; FCancelAi.SetBounds(8,74,176,28); FCancelAi.Caption := 'AI処理を中止'; FCancelAi.OnClick := CancelAiClick; FCancelAi.Enabled := False;
  FPrompt := TMemo.Create(Self); FPrompt.Parent := AiPanel; FPrompt.Align := alClient; FPrompt.ScrollBars := ssVertical; FPrompt.MaxLength := 16000;
  FPrompt.ReadOnly := True; FPrompt.Text := 'Codexからの指示を待っています。';
  RightPanel := TPanel.Create(Self); RightPanel.Parent := Self; RightPanel.Align := alRight; RightPanel.Left := ClientWidth-420; RightPanel.Width := 420;
  PositionPanel := TPanel.Create(Self); PositionPanel.Parent := Self; PositionPanel.Visible := False;  PositionPanel.Align := alNone; PositionPanel.Height := 58;
  LabelControl := TLabel.Create(Self); LabelControl.Parent := PositionPanel; LabelControl.SetBounds(8,7,30,18); LabelControl.Caption := 'X';
  FX := TSpinEdit.Create(Self); FX.Parent := PositionPanel; FX.SetBounds(25,4,95,26); FX.MinValue := -30000; FX.MaxValue := 30000; FX.Enabled := False;
  LabelControl := TLabel.Create(Self); LabelControl.Parent := PositionPanel; LabelControl.SetBounds(128,7,25,18); LabelControl.Caption := 'Y';
  FY := TSpinEdit.Create(Self); FY.Parent := PositionPanel; FY.SetBounds(145,4,95,26); FY.MinValue := -30000; FY.MaxValue := 30000; FY.Enabled := False;
  FPositionApply := TButton.Create(Self); FPositionApply.Parent := PositionPanel; FPositionApply.SetBounds(250,3,95,28); FPositionApply.Caption := '配置を適用'; FPositionApply.Enabled := False; FPositionApply.OnClick := PositionClick;
  LabelControl := TLabel.Create(Self); LabelControl.Parent := PositionPanel; LabelControl.SetBounds(8,34,400,18); LabelControl.Caption := '選択画像をプレビュー上でドラッグして配置できます。';
  PartsPanel := TPanel.Create(Self); PartsPanel.Parent := Self; PartsPanel.Visible := False;  PartsPanel.Align := alNone; PartsPanel.Height := 96;
  LabelControl := TLabel.Create(Self); LabelControl.Parent := PartsPanel; LabelControl.SetBounds(8,4,360,20); LabelControl.Caption := '表情・パーツ切替（* 排他選択）';
  FPartGroup := TArtEditorDarkComboBox.Create(Self); FPartGroup.Parent := PartsPanel; FPartGroup.SetBounds(8,26,400,28); FPartGroup.Anchors := [akLeft,akTop,akRight]; FPartGroup.OnChange := PartGroupChange; FPartGroup.Enabled := False;
  FPartChoice := TArtEditorDarkComboBox.Create(Self); FPartChoice.Parent := PartsPanel; FPartChoice.SetBounds(8,59,400,28); FPartChoice.Anchors := [akLeft,akTop,akRight]; FPartChoice.OnChange := PartChoiceChange; FPartChoice.Enabled := False;
  FTree := TArtLayerList.Create(Self); FTree.Parent := RightPanel; FTree.Align := alClient;
  FTree.OnSelect := TreeChange; FTree.OnRename := LayerRename; FTree.OnAttributes := LayerAttributes;
  Splitter := TSplitter.Create(Self); Splitter.Parent := Self; Splitter.Align := alRight; Splitter.Left := ClientWidth-424;
  // Buffer only the viewer so background and scaled image appear in one frame.
  PreviewPanel := TPanel.Create(Self); PreviewPanel.Parent := Self;
  PreviewPanel.Align := alClient; PreviewPanel.BevelOuter := bvNone;
  PreviewPanel.ParentBackground := False; PreviewPanel.Color := clGray;
  PreviewPanel.DoubleBuffered := True;
  FPaint := TArtPreviewPaintBox.Create(Self); FPaint.Parent := PreviewPanel; FPaint.Align := alClient;
  FPaint.OnPaint := PaintPreview; FPaint.OnMouseDown := PreviewMouseDown; FPaint.OnMouseMove := PreviewMouseMove; FPaint.OnMouseUp := PreviewMouseUp;
  FOpenDialog := TOpenDialog.Create(Self); FOpenDialog.Filter := 'PSD・PNG (*.psd;*.png)|*.psd;*.png';
  FOpenDialog.Options := [ofFileMustExist,ofPathMustExist,ofEnableSizing,ofNoChangeDir];
  FSaveDialog := TSaveDialog.Create(Self); FSaveDialog.Filter := 'Photoshop PSD (*.psd)|*.psd';
  FSaveDialog.DefaultExt := 'psd'; FSaveDialog.Options := [ofOverwritePrompt,ofPathMustExist,ofEnableSizing,ofNoChangeDir];
  FPngDialog := TOpenDialog.Create(Self); FPngDialog.Filter := 'PNG画像 (*.png)|*.png'; FPngDialog.Options := [ofFileMustExist,ofPathMustExist,ofEnableSizing,ofNoChangeDir];
  FPngDialog.InitialDir := FExchangeRoot;
  FResultDialog := TOpenDialog.Create(Self); FResultDialog.Filter := 'AI生成結果 (result.json)|result.json'; FResultDialog.Options := [ofFileMustExist,ofPathMustExist,ofEnableSizing,ofNoChangeDir];
  FRecoveryDialog := TOpenDialog.Create(Self); FRecoveryDialog.Filter := 'AI再開情報 (recovery.json)|recovery.json'; FRecoveryDialog.Options := [ofFileMustExist,ofPathMustExist,ofEnableSizing,ofNoChangeDir];
  FZoom := 1; OnMouseWheel := PreviewWheel;
  OnCloseQuery := CheckClose;
  FProtocol := TArtPipeProtocol.Create(DispatchCommand); FPipe := TArtPipeBridge.Create(FProtocol.Handle);
  FExchange.PipeName := FPipe.Name; UpdateActivity;
end;

destructor TPsdArtEditorForm.Destroy;
begin
  FPipe.Free; FProtocol.Free; FUndo.Free;
  if FTree<>nil then begin FTree.OnSelect := nil; FTree.SetRoots(nil); end;
  FDocument.Free; FInitialDocument.Free; FBitmap.Free; FHistory.Free; FExchange.Free;
  inherited;
end;

function TPsdArtEditorForm.ConfirmDiscard: Boolean;
begin
  Result := TryFinish(True);
end;

function TPsdArtEditorForm.TryFinish(ShowError: Boolean): Boolean;
begin
  Result := False;
  if FBusy then Exit;
  try
    FTree.FinishRename(True);
    if GetModified then begin
      if FFileName='' then raise EArtFormat.Create('保存先が指定されていません。');
      if FLastWrittenPath<>'' then SavePsdFile(FLastWrittenPath)
      else SavePsdFile(FFileName);
    end;
    Result := True;
  except
    on E: Exception do
      if ShowError then MessageDlg('保存できませんでした。編集内容を保持しています。'+sLineBreak+E.Message,mtError,[mbOK],0);
  end;
end;

procedure TPsdArtEditorForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := ConfirmDiscard;
end;


function TPsdArtEditorForm.GetModified: Boolean;
begin
  Result := (FLastWrittenPath<>'') or not SameArtDocumentContent(FInitialDocument,FDocument);
  FModified := Result;
end;

procedure TPsdArtEditorForm.CaptureInitialDocument;
begin
  FreeAndNil(FInitialDocument);
  if FDocument<>nil then FInitialDocument := FDocument.Clone;
  FModified := False;
  FLastWrittenPath := ''; FLastWrittenBytes := nil;
end;

function TPsdArtEditorForm.IsManagedPath(const FileName: string): Boolean;
var Target, Root: string;
begin
  Result := False;
  if (FManagedRoot='') or (FileName='') then Exit;
  Target := TPath.GetFullPath(FileName);
  Root := IncludeTrailingPathDelimiter(FManagedRoot);
  Result := SameText(Copy(Target,1,Length(Root)),Root);
end;

procedure TPsdArtEditorForm.RequireManagedEdit;
begin
  if FBusy then raise EArtFormat.Create('別の処理を実行しています。');
  if not FManaged then raise EArtFormat.Create('外部PSDでは名前・補助記号・表示状態だけを変更できます。');
  if not FCanRender then raise EArtFormat.Create('このPSDの画像・構造の編集は未対応です。'+FDocument.Unsupported.Text);
end;

procedure TPsdArtEditorForm.NewBlank(const FileName: string; Width,Height: Integer);
var NewDoc,Old: TArtDocument; Layer: TArtLayer; Pixels: TBytes;
begin
  if FDocument<>nil then raise EArtFormat.Create('新規PSDは空の編集画面で作成してください。');
  if not IsManagedPath(FileName) then raise EArtFormat.Create('新規PSDの保存先はホストのPSD管理フォルダ内にしてください。');
  if FileExists(FileName) then raise EArtFormat.Create('新規PSDと同じ名前のファイルが既に存在します。');
  if (Width<1) or (Height<1) then raise EArtFormat.Create('キャンバス寸法は1以上です。');
  NewDoc := TArtDocument.Create;
  try
    NewDoc.Width := Width; NewDoc.Height := Height;
    Layer := NewDoc.AddLayer(alkImage,'立ち絵',TArtBounds.Create(0,0,Width,Height));
    SetLength(Pixels,PixelByteCount(Width,Height,4)); Layer.Pixels := Pixels;
    Pixels := NewDoc.RenderRGBA;
  except NewDoc.Free; raise; end;
  Old := FDocument; FDocument := NewDoc;
  try SetPreview(Pixels); except FDocument := Old; NewDoc.Free; raise; end;
  FTree.SetRoots(nil); Old.Free; FreeAndNil(FInitialDocument);
  FUndo.Clear; ResetAiJobs; FFileName := TPath.GetFullPath(FileName);
  FManaged := True; FCanEdit := True; FCanRender := True; FModified := True;
  RebuildTree; UpdateStatus; SavePsdFile(FFileName);
end;

procedure TPsdArtEditorForm.RenamePsdFile(const NewBaseName: string);
var NewName,Target: string;
begin
  RequireManagedEdit;
  NewName := Trim(NewBaseName);
  if (NewName='') or (ExtractFileName(NewName)<>NewName) or
    (Pos(':',NewName)>0) or (Pos('/',NewName)>0) or (Pos('\',NewName)>0) then
    raise EArtFormat.Create('PSDファイル名だけを入力してください。');
  if not SameText(ExtractFileExt(NewName),'.psd') then NewName := NewName+'.psd';
  Target := TPath.Combine(ExtractFilePath(FFileName),NewName);
  SavePsdFile(Target);
end;

procedure TPsdArtEditorForm.RenameFileClick(Sender: TObject);
var Value: string;
begin
  Value := ExtractFileName(FFileName);
  if not InputQuery('PSDファイル名の変更','ファイル名',Value) then Exit;
  try RenamePsdFile(Value);
  except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
end;

function TPsdArtEditorForm.RenderEditable: TBytes;
begin Result := RenderPsdLayers(FDocument); end;

procedure TPsdArtEditorForm.SetPreview(const RGBA: TBytes);
var X,Y,P,C,Base,A,Value: Integer; Row: PByte;
begin
  FBitmap.PixelFormat := pf32bit; FBitmap.SetSize(FDocument.Width,FDocument.Height);
  for Y := 0 to FDocument.Height-1 do begin
    Row := FBitmap.ScanLine[Y];
    for X := 0 to FDocument.Width-1 do begin
      P := (Y*FDocument.Width+X)*4; A := RGBA[P+3];
      if ((X div 12+Y div 12) mod 2)=0 then Base := 225 else Base := 175;
      for C := 0 to 2 do begin
        Value := (RGBA[P+C]*A+Base*(255-A)+127) div 255;
        Row[X*4+2-C] := Value;
      end;
      Row[X*4+3] := 255;
    end;
  end;
  FPaint.Invalidate;
end;

procedure TPsdArtEditorForm.NewFromPng(const FileName: string);
var Image: TArtPngData; NewDoc,Old: TArtDocument; L: TArtLayer; RGBA: TBytes;
begin
  RequireManagedEdit;
  FZoom := 1; FPanX := 0; FPanY := 0;
  Image := ReadPng(FileName); NewDoc := TArtDocument.Create;
  try
    NewDoc.Width := Image.Width; NewDoc.Height := Image.Height;
    L := NewDoc.AddLayer(alkImage,ChangeFileExt(ExtractFileName(FileName),''),TArtBounds.Create(0,0,Image.Width,Image.Height)); L.Pixels := Image.Pixels;
    RGBA := NewDoc.RenderRGBA;
  except NewDoc.Free; raise; end;
  Old := FDocument; FDocument := NewDoc;
  try SetPreview(RGBA); except FDocument := Old; NewDoc.Free; raise; end;
  FUndo.Clear; ResetAiJobs; FTree.SetRoots(nil); Old.Free; FDocument.Changed; FModified := True; FCanEdit := True; FCanRender := True;
  FSave.Enabled := True; FSaveAs.Enabled := True; FClose.Enabled := True; RebuildTree; UpdateStatus;
end;
procedure TPsdArtEditorForm.ImportPngFile(const FileName: string);
var Image: TArtPngData; Parent,Selected,L: TArtLayer; List: TList<TArtLayer>; Index: Integer;
  function Find(List: TList<TArtLayer>; Target: TArtLayer; out Parent: TArtLayer): Boolean;
  var Item: TArtLayer;
  begin
    Result := False;
    for Item in List do begin
      if Item.Children.Contains(Target) then begin Parent := Item; Exit(True); end;
      if Find(Item.Children,Target,Parent) then Exit(True);
    end;
  end;
begin
  RequireManagedEdit;
  if FDocument=nil then begin NewFromPng(FileName); Exit; end;
  if not FCanEdit then raise EArtFormat.Create('この文書へのPNG追加は未対応です。');
  FTree.FinishRename(True); Image := ReadPng(FileName); Selected := FTree.Selected; Parent := nil;
  if Selected<>nil then begin
    if Selected.Kind=alkGroup then Parent := Selected else Find(FDocument.Roots,Selected,Parent);
  end;
  if Parent=nil then List := FDocument.Roots else List := Parent.Children;
  Index := List.IndexOf(Selected); if Index<0 then Index := 0;
  BeginEdit; L := FDocument.AddLayer(alkImage,ChangeFileExt(ExtractFileName(FileName),''),TArtBounds.Create(0,0,Image.Width,Image.Height),Parent);
  L.Pixels := Image.Pixels; List.Remove(L); List.Insert(Index,L);
  try SetPreview(RenderEditable);
  except FDocument.RemoveNewLayer(L); raise; end;
  FDocument.Changed; CommitEdit; FModified := True; RebuildTree; FTree.Selected := L; FTree.RevealSelected; UpdateStatus;
end;
procedure TPsdArtEditorForm.ReplaceSelectedPng(const FileName: string);
var Image: TArtPngData; L: TArtLayer; OldPixels: TBytes; OldBounds,NewBounds: TArtBounds;
begin
  RequireManagedEdit;
  if not FCanEdit or (FTree.Selected=nil) or (FTree.Selected.Kind<>alkImage) then raise EArtFormat.Create('置換する画像レイヤーを選択してください。');
  FTree.FinishRename(True); Image := ReadPng(FileName); L := FTree.Selected;
  OldPixels := L.Pixels; OldBounds := L.Bounds;
  NewBounds := TArtBounds.Create(OldBounds.Left,OldBounds.Top,OldBounds.Left+Image.Width,OldBounds.Top+Image.Height);
  BeginEdit; L.Pixels := Image.Pixels; L.Bounds := NewBounds;
  try SetPreview(RenderEditable);
  except L.Pixels := OldPixels; L.Bounds := OldBounds; raise; end;
  FDocument.Changed; CommitEdit; FModified := True; FTree.RefreshImages; TreeChange(Self); UpdateStatus;
end;
procedure TPsdArtEditorForm.MoveSelectedLayer(X,Y: Integer);
var L: TArtLayer; OldBounds,OldMask,NewBounds,NewMask: TArtBounds; DX,DY: Integer;
begin
  RequireManagedEdit;
  if not FCanEdit or (FTree.Selected=nil) or (FTree.Selected.Kind<>alkImage) then raise EArtFormat.Create('配置する画像レイヤーを選択してください。');
  if (X<-30000) or (X>30000) or (Y<-30000) or (Y>30000) then raise EArtFormat.Create('配置座標は-30000～30000です。');
  L := FTree.Selected; OldBounds := L.Bounds; OldMask := L.MaskBounds;
  if (OldBounds.Left=X) and (OldBounds.Top=Y) then Exit;
  DX := X-OldBounds.Left; DY := Y-OldBounds.Top;
  NewBounds := TArtBounds.Create(X,Y,X+OldBounds.Width,Y+OldBounds.Height); NewMask := OldMask;
  if L.HasMask then NewMask := TArtBounds.Create(OldMask.Left+DX,OldMask.Top+DY,OldMask.Right+DX,OldMask.Bottom+DY);
  BeginEdit; L.Bounds := NewBounds; L.MaskBounds := NewMask;
  try SetPreview(RenderEditable);
  except L.Bounds := OldBounds; L.MaskBounds := OldMask; raise; end;
  FDocument.Changed; CommitEdit; FModified := True; TreeChange(Self); UpdateStatus;
end;
procedure TPsdArtEditorForm.NewPngClick(Sender: TObject);
begin
  if not ConfirmDiscard then Exit;
  if FPngDialog.Execute then try NewFromPng(FPngDialog.FileName); except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
end;
procedure TPsdArtEditorForm.ImportPngClick(Sender: TObject);
begin
  if FPngDialog.Execute then try ImportPngFile(FPngDialog.FileName); except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
end;
procedure TPsdArtEditorForm.ReplacePngClick(Sender: TObject);
begin
  if FPngDialog.Execute then try ReplaceSelectedPng(FPngDialog.FileName); except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
end;
procedure TPsdArtEditorForm.PositionClick(Sender: TObject);
begin
  if Sender=FPositionItem then begin FX.SetFocus; FX.SelectAll; Exit; end;
  try MoveSelectedLayer(FX.Value,FY.Value); except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
end;

procedure TPsdArtEditorForm.OpenPsdFile(const FileName: string);
var NewDoc,OldDoc: TArtDocument; RGBA: TBytes; P,C,A,Value: Integer; NewCanEdit: Boolean;
begin
  if not FLoadingSaved and (FFileName<>'') and
    not SameText(FFileName,TPath.GetFullPath(FileName)) then
    raise EArtFormat.Create('別のPSDはホストのPSD一覧から開いてください。');
  Screen.Cursor := crHourGlass;
  try
    NewDoc := ReadPsd(FileName); OldDoc := FDocument; FDocument := NewDoc;
    try
      NewCanEdit := True;
      try RGBA := RenderEditable; except on E: EArtFormat do begin
        NewCanEdit := False;
        SetLength(RGBA,PixelByteCount(NewDoc.Width,NewDoc.Height,4));
        for P := 0 to Length(RGBA) div 4-1 do begin
          A := 255;
          if NewDoc.MergedHasTransparency and (Length(NewDoc.MergedPlanes)>=4) then A := NewDoc.MergedPlanes[3][P];
          for C := 0 to 2 do begin
            Value := NewDoc.MergedPlanes[C][P];
            if A=0 then Value := 0
            else if A<255 then Value := EnsureRange((Value*255-255*(255-A)+A div 2) div A,0,255);
            RGBA[P*4+C] := Value;
          end;
          RGBA[P*4+3] := A;
        end;
      end; end;
      SetPreview(RGBA);
    except FDocument := OldDoc; NewDoc.Free; raise; end;
    // Nodes hold document pointers: clear them before releasing the previous document.
    FUndo.Clear; ResetAiJobs; FTree.SetRoots(nil); OldDoc.Free; FFileName := TPath.GetFullPath(FileName);
    FCanRender := NewCanEdit; FCanEdit := True; FManaged := IsManagedPath(FFileName);
    CaptureInitialDocument;
    FSave.Enabled := True; FSaveAs.Enabled := FManaged; FClose.Enabled := True;
    RebuildTree; UpdateStatus;
    if not FLoadingSaved then begin
      FZoom := 1; FPanX := 0; FPanY := 0; FPaint.Invalidate;
      try FHistory.AddFile(FFileName); except on E: Exception do FStatus.Caption := FStatus.Caption+sLineBreak+'履歴保存失敗: '+E.Message; end;
      RebuildHistory;
    end;
  finally Screen.Cursor := crDefault; end;
end;

procedure TPsdArtEditorForm.RebuildTree;
begin
  FTree.EditEnabled := FCanEdit;
  FTree.OpacityEnabled := FManaged and FCanRender;
  FTree.SetRoots(FDocument.Roots);
end;

procedure TPsdArtEditorForm.TreeChange(Sender: TObject);
var L: TArtLayer; CanImage: Boolean;
begin
  L := FTree.Selected; CanImage := FManaged and FCanRender and (L<>nil) and (L.Kind=alkImage);
  FReplaceItem.Enabled := CanImage; FPositionItem.Enabled := CanImage; FX.Enabled := CanImage; FY.Enabled := CanImage; FPositionApply.Enabled := CanImage;
  FImportItem.Enabled := FManaged and FCanRender;
  FGroupItem.Enabled := FManaged and FCanRender and (FDocument<>nil);
  FExportAi.Enabled := FManaged and FCanRender and (FDocument<>nil); FImportAi.Enabled := FExportAi.Enabled;
  if FReadOnlyAiPanel<>nil then FReadOnlyAiPanel.Visible := FManaged;
  FSaveAs.Enabled := FManaged;
  UpdateParts; UpdateActivity;
  if CanImage then begin FX.Value := L.Bounds.Left; FY.Value := L.Bounds.Top; end;
  if FPaint<>nil then begin TArtPaintBoxAccess(FPaint).MouseCapture := False; FPaint.Cursor := crDefault; FPaint.Invalidate; end; FDragging := False;
end;
procedure TPsdArtEditorForm.LayerAttributes(Sender: TObject; Layer: TArtLayer; Visible: Boolean; Opacity: Byte);
begin
  if Layer<>FTree.Selected then raise EArtFormat.Create('Selection changed during attributes edit');
  ApplySelectedLayer(Layer.Name,Visible,Opacity);
end;
procedure TPsdArtEditorForm.RebuildHistory;
  procedure Populate(Menu: TMenuItem; List: TStringList);
  var I: Integer; Item: TMenuItem;
  begin
    Menu.Clear;
    for I := 0 to List.Count-1 do begin
      Item := TMenuItem.Create(Self); Item.Caption := StringReplace(List[I],'&','&&',[rfReplaceAll]);
      Item.Hint := List[I]; Item.OnClick := HistoryClick; Menu.Add(Item);
    end;
    if Menu.Count=0 then begin
      Item := TMenuItem.Create(Self); Item.Caption := '（履歴なし）'; Item.Enabled := False; Menu.Add(Item);
    end;
  end;
begin Populate(FHistoryMenu,FHistory.Files); end;
procedure TPsdArtEditorForm.HistoryClick(Sender: TObject);
var FileName: string;
begin
  FileName := TMenuItem(Sender).Hint;
  if not ConfirmDiscard then Exit;
  try OpenPsdFile(FileName);
  except on E: Exception do MessageDlg('PSDを開けませんでした。'+sLineBreak+E.Message,mtError,[mbOK],0); end;
end;

procedure TPsdArtEditorForm.LayerRename(Sender: TObject; Layer: TArtLayer; const Name: string);
begin
  if Layer<>FTree.Selected then raise EArtFormat.Create('Selection changed during rename');
  ApplySelectedLayer(Name,Layer.Visible,Layer.Opacity); TreeChange(Self);
end;

procedure TPsdArtEditorForm.ApplySelectedLayer(const Name: string; Visible: Boolean; Opacity: Byte;
  ForceExclusive: Boolean);
var L: TArtLayer; OldName: string; OldOpacity: Byte;
    States: TDictionary<TArtLayer,Boolean>; Pair: TPair<TArtLayer,Boolean>;
    Changed,VisualChanged: Boolean;
  procedure Snapshot(List: TList<TArtLayer>);
  var Item: TArtLayer;
  begin for Item in List do begin States.Add(Item,Item.Visible); Snapshot(Item.Children); end; end;
begin
  if FBusy then raise EArtFormat.Create('処理中です。');
  if not FCanEdit or (FTree.Selected=nil) then raise EArtFormat.Create('レイヤーを選択してください。');
  L := FTree.Selected; OldName := L.Name; OldOpacity := L.Opacity;
  if (Name<>OldName) and ((Trim(Name)='') or (Length(Name)>255)) then
    raise EArtFormat.Create('レイヤー名は1～255文字で指定してください。');
  if not FManaged and (Opacity<>OldOpacity) then
    raise EArtFormat.Create('外部PSDの不透明度は変更できません。');
  States := TDictionary<TArtLayer,Boolean>.Create;
  try
    Snapshot(FDocument.Roots);
    if not ForceExclusive and (Name=OldName) and (Visible=L.Visible) and (Opacity=OldOpacity) then Exit;
    BeginEdit; L.Name := Name; L.Visible := Visible; L.Opacity := Opacity;
    try
      // Naming/modifier edits never change visibility or sibling exclusivity.
      if ((States[L]<>Visible) or ForceExclusive) and IsExclusive(L) and Visible then SelectExclusive(FDocument,L);
      Changed := (OldName<>Name) or (OldOpacity<>Opacity);
      VisualChanged := OldOpacity<>Opacity;
      for Pair in States do begin
        Changed := Changed or (Pair.Key.Visible<>Pair.Value);
        VisualChanged := VisualChanged or (Pair.Key.Visible<>Pair.Value);
      end;
      if not Changed then Exit;
      if VisualChanged then SetPreview(RenderEditable);
    except
      L.Name := OldName; L.Opacity := OldOpacity;
      for Pair in States do Pair.Key.Visible := Pair.Value;
      raise;
    end;
    FDocument.Changed; CommitEdit; FModified := GetModified;
    FTree.RefreshLayerNames; UpdateParts; UpdateStatus;
  finally States.Free; end;
end;

procedure TPsdArtEditorForm.SelectPart(Layer: TArtLayer);
var Previous: TArtLayer;
begin
  if not FCanEdit then raise EArtFormat.Create('この文書の切替は未対応です。');
  LayerSiblings(FDocument,Layer);
  if not IsExclusive(Layer) then raise EArtFormat.Create('排他選択 (*) を設定してください。');
  FTree.FinishRename(True); Previous := FTree.Selected; FTree.Selected := Layer;
  try ApplySelectedLayer(Layer.Name,True,Layer.Opacity,True);
  except FTree.Selected := Previous; raise; end;
  FTree.RevealSelected;
end;

procedure TPsdArtEditorForm.RecoverAiClick(Sender: TObject);
begin
  if not ConfirmDiscard then Exit;
  FRecoveryDialog.FileName := 'recovery.json';
  if FRecoveryDialog.Execute then
    try RecoverAiJob(ExtractFilePath(FRecoveryDialog.FileName));
    except on E: Exception do MessageDlg('AIジョブを再開できませんでした。'+sLineBreak+E.Message,mtError,[mbOK],0); end;
end;
procedure TPsdArtEditorForm.RecoverAiJob(const Directory: string);
var Candidate,Old: TArtDocument; Job: TArtExchangeJob; Pixels: TBytes;
begin
  RequireManagedEdit; FTree.FinishRename(True);
  if GetModified then raise EArtFormat.Create('Save the current document before recovery');
  BeginOperation('AIジョブの再開中');
  try
    Candidate := FExchange.LoadRecovery(ExcludeTrailingPathDelimiter(Directory),Job);
    try
      // A reopened PSD has a fresh session ID. Bind recovery to its saved path
      // and source bytes so another PSD or a newer save cannot be replaced.
      if Job.SourceFileName<>'' then begin
        if not SameText(TPath.GetFullPath(Job.SourceFileName),FFileName) then
          raise EArtFormat.Create('別のPSDのAIジョブはこの編集画面で再開できません。');
        if not FileExists(FFileName) or
          (LowerCase(THashSHA2.GetHashStringFromFile(FFileName))<>Job.SourceSha256) then
          raise EArtFormat.Create('AIジョブの書出し後に元PSDが変更されました。');
      end else if (FDocument=nil) or (Candidate.SessionId<>FDocument.SessionId) then
        raise EArtFormat.Create('旧形式のAIジョブは同じ編集セッションでのみ再開できます。');
    except Candidate.Free; Job.Free; raise; end;
    try Pixels := RenderPsdLayers(Candidate); FExchange.WriteJobConnection(Job); except Candidate.Free; Job.Free; raise; end;
    Old := FDocument; FDocument := Candidate;
    try SetPreview(Pixels); except FDocument := Old; Candidate.Free; Job.Free; raise; end;
    FUndo.Clear; ResetAiJobs; FTree.SetRoots(nil); Old.Free;
    FZoom := 1; FPanX := 0; FPanY := 0; FPaint.Invalidate;
    FExchange.RegisterRecovered(Job); FCurrentJobId := Job.Id; FJobPath.Text := Job.Directory;
    FJobPath.Hint := Job.Directory; FJobPath.ShowHint := True;
    FPrompt.Lines.Add('Codex: '+Job.PromptText); FModified := True; FCanEdit := True; FCanRender := True;
    FSave.Enabled := True; FSaveAs.Enabled := True; FClose.Enabled := True;
    RebuildTree; UpdateStatus;
  finally EndOperation; end;
end;
procedure TPsdArtEditorForm.ResetAiJobs;
begin
  FCurrentJobId := ''; FExchange.ClearJobs; FJobPath.Text := 'AIジョブのフォルダーがここに表示されます。';
  FJobPath.Hint := ''; FJobPath.ShowHint := False; UpdateActivity;
end;

function TPsdArtEditorForm.ExportAiJob(const Prompt,Root: string; Workspace: TJSONObject): string;
begin
  RequireManagedEdit;
  if (FExchangeRoot='') or not SameText(ExcludeTrailingPathDelimiter(TPath.GetFullPath(Root)),FExchangeRoot) then
    raise EArtFormat.Create('AI交換先はホストが指定したExchangeフォルダを使用してください。');
  if not FCanEdit then raise EArtFormat.Create('編集対応文書を開いてください。');
  FPrompt.Lines.Add('Codex: '+Prompt);
  FTree.FinishRename(True); BeginOperation('AI向け書出し中');
  try Result := FExchange.ExportJob(FDocument,Prompt,Root,Workspace,FFileName); FCurrentJobId := ExtractFileName(Result);
  finally EndOperation; end;
  FJobPath.Text := Result; FJobPath.Hint := Result; FJobPath.ShowHint := True;
end;
procedure TPsdArtEditorForm.ImportAiResult(const FileName: string);
var Candidate,Old: TArtDocument; Job: TArtExchangeJob; Digest,SelectedId: string; L: TArtLayer; Pixels: TBytes;
begin
  RequireManagedEdit;
  if not FCanEdit then raise EArtFormat.Create('編集対応文書を開いてください。');
  FTree.FinishRename(True); BeginOperation('生成結果の検証・取込中');
  try
  Candidate := FExchange.PrepareResult(FDocument,FileName,Job,Digest);
  if Candidate=nil then begin UpdateStatus; FStatus.Caption := FStatus.Caption+sLineBreak+'この生成結果は既に取り込み済みです。'; Exit; end;
  SelectedId := ''; if FTree.Selected<>nil then SelectedId := FTree.Selected.Id;
  try Pixels := RenderPsdLayers(Candidate); except Candidate.Free; raise; end;
  try BeginEdit; except Candidate.Free; raise; end;
  Old := FDocument; FDocument := Candidate;
  try SetPreview(Pixels); except FDocument := Old; Candidate.Free; raise; end;
  FTree.SetRoots(nil); Old.Free; CommitEdit; FModified := True;
  FExchange.CommitResult(Job,Digest); RebuildTree;
  L := FDocument.FindLayer(SelectedId); if L<>nil then begin FTree.Selected := L; FTree.RevealSelected; end;
  UpdateStatus; FStatus.Caption := FStatus.Caption+sLineBreak+'生成結果を取り込みました。PSDを保存して確定してください。';
  finally EndOperation; end;
end;
procedure TPsdArtEditorForm.ExportAiClick(Sender: TObject);
begin
  try ExportAiJob(FPrompt.Text,FExchangeRoot);
  except on E: Exception do MessageDlg('AI向けの書き出しに失敗しました。'+sLineBreak+E.Message,mtError,[mbOK],0); end;
end;
procedure TPsdArtEditorForm.ImportAiClick(Sender: TObject);
begin
  if DirectoryExists(FJobPath.Text) then FResultDialog.InitialDir := FJobPath.Text;
  FResultDialog.FileName := 'result.json';
  if FResultDialog.Execute then
    try ImportAiResult(FResultDialog.FileName);
    except on E: Exception do MessageDlg('生成結果を取り込めませんでした。'+sLineBreak+E.Message,mtError,[mbOK],0); end;
end;

procedure TPsdArtEditorForm.UpdateParts;
var Previous: TObject;
  procedure Collect(List: TList<TArtLayer>; Parent: TArtLayer; const Path: string);
  var L: TArtLayer; HasParts: Boolean; Caption: string;
  begin
    HasParts := False; for L in List do HasParts := HasParts or IsExclusive(L);
    if HasParts then FPartGroup.Items.AddObject(Path,Parent);
    for L in List do if L.Kind=alkGroup then begin
      Caption := ParseLayerName(L.Name).DisplayName;
      if Parent<>nil then Caption := Path+' / '+Caption;
      Collect(L.Children,L,Caption);
    end;
  end;
begin
  if (FPartGroup=nil) or FUpdatingParts then Exit;
  FUpdatingParts := True;
  try
    Previous := nil;
    if FPartGroup.ItemIndex>=0 then Previous := FPartGroup.Items.Objects[FPartGroup.ItemIndex];
    FPartGroup.Items.Clear;
    if FDocument<>nil then Collect(FDocument.Roots,nil,'文書直下');
    FPartGroup.ItemIndex := FPartGroup.Items.IndexOfObject(Previous);
    if (FPartGroup.ItemIndex<0) and (FPartGroup.Items.Count>0) then FPartGroup.ItemIndex := 0;
    FPartGroup.Enabled := FCanEdit and FCanRender and (FPartGroup.Items.Count>0);
    PartGroupChange(Self);
  finally FUpdatingParts := False; end;
end;
procedure TPsdArtEditorForm.PartGroupChange(Sender: TObject);
var Parent,L: TArtLayer; List: TList<TArtLayer>; Active,VisibleCount: Integer;
begin
  FPartChoice.Items.Clear; Active := -1; VisibleCount := 0;
  if (FDocument<>nil) and (FPartGroup.ItemIndex>=0) then begin
    Parent := TArtLayer(FPartGroup.Items.Objects[FPartGroup.ItemIndex]);
    if Parent=nil then List := FDocument.Roots else List := Parent.Children;
    for L in List do if IsExclusive(L) then begin
      FPartChoice.Items.AddObject(ParseLayerName(L.Name).DisplayName,L);
      if L.Visible then begin Active := FPartChoice.Items.Count-1; Inc(VisibleCount); end;
    end;
  end;
  if VisibleCount<>1 then Active := -1;
  FPartChoice.ItemIndex := Active; FPartChoice.Enabled := FCanEdit and FCanRender and (FPartChoice.Items.Count>0);
  FPartChoice.Hint := '選択すると同じ親の * パーツを1つだけ表示します。親が非表示なら目アイコンで表示してください。'; FPartChoice.ShowHint := True;
end;
procedure TPsdArtEditorForm.PartChoiceChange(Sender: TObject);
var L: TArtLayer;
begin
  if FUpdatingParts or (FPartChoice.ItemIndex<0) then Exit;
  L := TArtLayer(FPartChoice.Items.Objects[FPartChoice.ItemIndex]);
  try SelectPart(L); except on E: Exception do begin UpdateParts; MessageDlg(E.Message,mtError,[mbOK],0); end; end;
end;
procedure TPsdArtEditorForm.CreateGroup(const Name: string; Exclusive: Boolean);
var Parent,Selected,L: TArtLayer; List: TList<TArtLayer>; Index: Integer; GroupName: string;
begin
  RequireManagedEdit;
  if not FCanEdit or (FDocument=nil) then raise EArtFormat.Create('編集できる文書を開いてください。');
  GroupName := RenameLayerDisplay('',Name); if Exclusive then GroupName := SetLayerPrefix(GroupName,'*');
  FTree.FinishRename(True); Selected := FTree.Selected; Parent := nil; List := FDocument.Roots;
  if Selected<>nil then begin
    if Selected.Kind=alkGroup then begin Parent := Selected; List := Parent.Children; end
    else List := LayerSiblings(FDocument,Selected);
  end;
  Index := List.IndexOf(Selected); if Index<0 then Index := 0;
  BeginEdit; L := FDocument.AddLayer(alkGroup,GroupName,TArtBounds.Create(0,0,0,0),Parent);
  FDocument.Roots.Remove(L); if Parent<>nil then Parent.Children.Remove(L);
  List.Insert(Index,L);
  if Exclusive then begin
    for var Sibling in List do if (Sibling<>L) and IsExclusive(Sibling) and Sibling.Visible then L.Visible := False;
  end;
  try SetPreview(RenderEditable); except FDocument.RemoveNewLayer(L); raise; end;
  FDocument.Changed; CommitEdit; FModified := True; RebuildTree; FTree.Selected := L; FTree.RevealSelected; UpdateStatus;
end;
procedure TPsdArtEditorForm.GroupClick(Sender: TObject);
var Name: string; Exclusive: Boolean; Answer: Integer;
begin
  Name := '表情'; if not InputQuery('グループ作成','グループ名',Name) then Exit;
  Answer := MessageDlg('表情・パーツの差分として排他選択 (*) を設定しますか？',mtConfirmation,[mbYes,mbNo,mbCancel],0);
  if Answer=mrCancel then Exit; Exclusive := Answer=mrYes;
  try CreateGroup(Name,Exclusive); except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
end;

procedure TPsdArtEditorForm.UpdateStatus;
var Mode,Star: string;
begin
  if FDocument=nil then Exit;
  if GetModified then Star := ' *' else Star := '';
  if FManaged then Caption := 'PSD編集 - '+ExtractFileName(FFileName)+Star
  else Caption := 'PSD編集 (外部PSD) - '+ExtractFileName(FFileName)+Star;
  if FManaged then Mode := '管理PSD: AI・画像・構造・名前・表示を編集できます。'
  else Mode := '外部PSD: 名前・補助記号・表示状態だけを編集できます。';
  if not FCanRender then Mode := Mode+' 表示変更の合成は未対応です。';
  FStatus.Caption := Format('%d × %d / %dレイヤー %s',[FDocument.Width,FDocument.Height,FTree.RowCount,Mode]);
  FStatus.Hint := FStatus.Caption; FStatus.ShowHint := True; UpdateActivity;
end;

procedure TPsdArtEditorForm.SavePsdFile(const FileName: string);
var Path: TArray<Integer>; Selected: TArtLayer; List: TList<TArtLayer>; Index: Integer;
    Target: string; Info: TArtEditorSaveInfo; BeforeDoc,EditedDoc: TArtDocument;
    CurrentBytes: TBytes;
  function SameBytes(const A,B: TBytes): Boolean;
  begin
    Result := Length(A)=Length(B);
    if Result and (Length(A)>0) then Result := CompareMem(@A[0],@B[0],Length(A));
  end;
  function FindPath(List: TList<TArtLayer>): Boolean;
  var I: Integer;
  begin
    Result := False;
    for I := 0 to List.Count-1 do begin
      SetLength(Path,Length(Path)+1); Path[High(Path)] := I;
      if (List[I]=Selected) or FindPath(List[I].Children) then Exit(True);
      SetLength(Path,Length(Path)-1);
    end;
  end;
  function SameNames(A,B: TList<TArtLayer>): Boolean;
  var I: Integer;
  begin
    Result := False;
    if A.Count<>B.Count then Exit;
    for I := 0 to A.Count-1 do
      if (A[I].Name<>B[I].Name) or not SameNames(A[I].Children,B[I].Children) then Exit;
    Result := True;
  end;
begin
  if FDocument=nil then raise EArtFormat.Create('PSDを開いてください。');
  if FBusy then raise EArtFormat.Create('処理中です。');
  FTree.FinishRename(True); Target := TPath.GetFullPath(FileName);
  if FManaged then begin
    if not IsManagedPath(Target) then raise EArtFormat.Create('保存先はPSD管理フォルダ内にしてください。');
  end else if not SameText(Target,FFileName) then
    raise EArtFormat.Create('外部PSDのファイル名・保存先は変更できません。');
  if not GetModified and SameText(Target,FFileName) then Exit;
  // Reject another application's edits. A previous write by this form is allowed
  // when the host callback failed and the same in-memory edit is being retried.
  if FileExists(FFileName) and (FInitialDocument<>nil) then begin
    CurrentBytes := TFile.ReadAllBytes(FFileName);
    if not SameBytes(CurrentBytes,FInitialDocument.SourceBytes) and
      not (SameText(FFileName,FLastWrittenPath) and SameBytes(CurrentBytes,FLastWrittenBytes)) then
      raise EArtFormat.Create('編集開始後にPSDが別のアプリで変更されました。編集内容を保持しています。');
  end else if (FInitialDocument<>nil) and (Length(FInitialDocument.SourceBytes)>0) and
    not ((FLastWrittenPath<>'') and FileExists(FLastWrittenPath) and
      SameBytes(TFile.ReadAllBytes(FLastWrittenPath),FLastWrittenBytes)) then
    raise EArtFormat.Create('編集開始後にPSDファイルが削除されました。');
  if not SameText(Target,FFileName) and FileExists(Target) and
    not (SameText(Target,FLastWrittenPath) and SameBytes(TFile.ReadAllBytes(Target),FLastWrittenBytes)) then
    raise EArtFormat.Create('同名のPSDファイルが既に存在します。');
  BeforeDoc := nil; EditedDoc := nil;
  BeginOperation('PSDの保存中');
  try
    if FInitialDocument<>nil then BeforeDoc := FInitialDocument.Clone;
    EditedDoc := FDocument.Clone;
    Info.OldFileName := FFileName; Info.NewFileName := Target;
    Info.OriginalDocument := BeforeDoc; Info.EditedDocument := EditedDoc;
    Info.StructureChanged := not SameArtDocumentStructure(BeforeDoc,EditedDoc);
    Info.NamesChanged := (BeforeDoc=nil) or not SameNames(BeforeDoc.Roots,EditedDoc.Roots);
    Info.VisibilityChanged := not SameArtDocumentVisibility(BeforeDoc,EditedDoc);
    Info.VisualChanged := not SameArtDocumentVisualContent(BeforeDoc,EditedDoc);
    Selected := FTree.Selected; FindPath(FDocument.Roots);
    Screen.Cursor := crHourGlass;
    try
      if not FManaged then SaveExternalLayerPropertiesPsd(FDocument,Target)
      else if Length(FDocument.SourceBytes)=0 then WriteNewPsd(FDocument,Target,pcRle)
      else if GetModified then begin
        try SaveLayerPropertiesPsd(FDocument,Target);
        except on E: EArtFormat do SaveImageCompositionPsd(FDocument,Target); end;
      end else SaveUnchangedPsd(FDocument,Target);
    finally Screen.Cursor := crDefault; end;
    FLastWrittenPath := Target;
    FLastWrittenBytes := TFile.ReadAllBytes(Target);
    // Host synchronization is part of accepting the save. If it fails, retain
    // the editable document, original path and dirty baseline for a retry.
    if Assigned(FOnSaved) then FOnSaved(Self,Info);
    // Save failure exits before reload: the original editable content remains alive.
    FLoadingSaved := True;
    try OpenPsdFile(Target); finally FLoadingSaved := False; end;
    Selected := nil; List := FDocument.Roots;
    for Index in Path do begin
      if (Index<0) or (Index>=List.Count) then begin Selected := nil; Break; end;
      Selected := List[Index]; List := Selected.Children;
    end;
    if Selected<>nil then begin FTree.Selected := Selected; FTree.RevealSelected; end;
    try FHistory.AddFile(FFileName);
    except on E: Exception do FStatus.Caption := FStatus.Caption+sLineBreak+'履歴保存失敗: '+E.Message; end;
    RebuildHistory;
  finally EndOperation; EditedDoc.Free; BeforeDoc.Free; end;
end;



procedure TPsdArtEditorForm.OpenClick(Sender: TObject);
begin
  if not ConfirmDiscard then Exit;
  if FOpenDialog.Execute then
    try if SameText(ExtractFileExt(FOpenDialog.FileName),'.png') then NewFromPng(FOpenDialog.FileName) else OpenPsdFile(FOpenDialog.FileName); except on E: Exception do MessageDlg('PSDを開けませんでした。'+sLineBreak+E.Message,mtError,[mbOK],0); end;
end;

procedure TPsdArtEditorForm.SaveClick(Sender: TObject);
begin
  if FDocument=nil then Exit;
  if FFileName='' then begin SaveAsClick(Sender); Exit; end;
  try SavePsdFile(FFileName);
  except on E: Exception do MessageDlg('保存できませんでした。'+sLineBreak+E.Message,mtError,[mbOK],0); end;
end;

procedure TPsdArtEditorForm.CloseClick(Sender: TObject);
begin Close; end;

procedure TPsdArtEditorForm.ExitClick(Sender: TObject);
begin Close; end;

procedure TPsdArtEditorForm.SaveAsClick(Sender: TObject);
begin RenameFileClick(Sender); end;

function TPsdArtEditorForm.PreviewRect: TRect;
var Scale: Double; W,H,X,Y: Integer;
begin
  Result := Rect(0,0,0,0); if FBitmap.Empty then Exit;
  Scale := Min(FPaint.Width/FBitmap.Width,FPaint.Height/FBitmap.Height)*FZoom;
  W := Max(1,Round(FBitmap.Width*Scale)); H := Max(1,Round(FBitmap.Height*Scale));
  X := Round((FPaint.Width-W)/2+FPanX); Y := Round((FPaint.Height-H)/2+FPanY);
  Result := Rect(X,Y,X+W,Y+H);
end;
procedure TPsdArtEditorForm.PreviewWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var P: TPoint; Ratio,NewZoom: Double;
begin
  P := FPaint.ScreenToClient(MousePos);
  if FBitmap.Empty or not PtInRect(FPaint.ClientRect,P) then Exit;
  NewZoom := EnsureRange(FZoom*Power(1.15,WheelDelta/120),0.05,32.0);
  Ratio := NewZoom/FZoom;
  FPanX := P.X-FPaint.Width/2+(FPaint.Width/2+FPanX-P.X)*Ratio;
  FPanY := P.Y-FPaint.Height/2+(FPaint.Height/2+FPanY-P.Y)*Ratio;
  FZoom := NewZoom; Handled := True; FPaint.Invalidate;
end;
procedure TPsdArtEditorForm.PreviewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
begin
  if (Button<>mbLeft) or FBitmap.Empty then Exit;
  FDragStart := Point(X,Y); FDragging := True;
  TArtPaintBoxAccess(FPaint).MouseCapture := True; FPaint.Cursor := crSizeAll;
end;
procedure TPsdArtEditorForm.PreviewMouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
begin
  if not FDragging then Exit;
  FPanX := FPanX+X-FDragStart.X; FPanY := FPanY+Y-FDragStart.Y;
  FDragStart := Point(X,Y); FPaint.Invalidate;
end;
procedure TPsdArtEditorForm.PreviewMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
begin
  if (Button<>mbLeft) or not FDragging then Exit;
  PreviewMouseMove(Sender,Shift,X,Y); FDragging := False;
  TArtPaintBoxAccess(FPaint).MouseCapture := False; FPaint.Cursor := crDefault;
end;
procedure TPsdArtEditorForm.PaintPreview(Sender: TObject);
begin
  FPaint.Canvas.Brush.Color := clGray; FPaint.Canvas.FillRect(FPaint.ClientRect);
  if not FBitmap.Empty then FPaint.Canvas.StretchDraw(PreviewRect,FBitmap);
end;

end.
