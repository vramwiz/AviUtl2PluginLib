unit SerifBoardFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, System.SysUtils, System.Variants, System.Classes,Winapi.UxTheme,
  System.IOUtils, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,DragAgent,
  Vcl.ExtCtrls, SerifBoardList,RTTIPersistentFrame,ConfigPanel,SerifBoardRenderBatch,
  Vcl.Menus;

type
  TFrameSerifBoardBound = class(TRTTIFrame)
  private
    FZoomIndex         : Integer;
    FPanelConfigHeight : Integer;
    FEnableScript      : Boolean;
    FLayer             : Integer;
    FHold              : Integer;
    FFade              : Integer;
  public
    constructor Create;
    // フォームの座標情報をデータ化
    procedure FrameToSelf(AFrame : TFrame);override;
    // データをフォームの情報に復元
    procedure SelfToFrame(AFrame : TFrame);override;
  published
    property ZoomIndex         : Integer read FZoomIndex write FZoomIndex;
    property PanelConfigHeight : Integer read FPanelConfigHeight write FPanelConfigHeight;
    property EnableScript      : Boolean read FEnableScript write FEnableScript;
    property Layer             : Integer read FLayer write FLayer;
    property Hold              : Integer read FHold write FHold;
    property Fade              : Integer read FFade write FFade;
end;


type
  TFrameSerifBoard = class(TFrame)
    LBoxStyle: TListBox;
    CBoxResolution: TComboBox;
    PanelConfig: TPanel;
    Splitter1: TSplitter;
    MenuPop: TPopupMenu;
    MenuFolderOpen: TMenuItem;
    procedure CBoxResolutionChange(Sender: TObject);
    procedure LBoxStyleClick(Sender: TObject);
    procedure MenuFolderOpenClick(Sender: TObject);
  private
    { Private 宣言 }
    FBound       : TFrameSerifBoardBound;                // Window位置保存クラス
    FBoardFolder : string;
    FRenderBatch : TSerifBoardRenderBatch;
    FDrag        : TDragShellFile;
    FBoardList   : TSerifBoardListView;
    FPanelConfig : TConfigPanel;
    // 初期ボードフォルダ群を必要時のみ作成する
    procedure EnsureBoardStyleFolders;
    // 指定した解像度とスタイル名のボードフォルダを必要時のみ作成する
    procedure EnsureBoardStyleFolder(const AWidth, AHeight: Integer; const AStyleName: string);
    // 選択状態からボードフォルダ名を組み立てる
    function GetBoardStyleFolder: string;
    // ボードフォルダから解像度一覧をコンボボックスに反映する
    procedure ShowResolutionList;
    // 選択中の解像度に対応するスタイル一覧をリストボックスに反映する
    procedure ShowStyleList;
    procedure ShowCOnfig;
    // 選択中のボードフォルダを一覧へ反映する
    procedure ShowBoardList;
    procedure OnDrag(Sender: TObject; FileNames: TStringList);
    procedure OnConfigChange(Sender: TObject);
    procedure OnGenerateCoordAreaPreviewFinished(const AException: Exception);
    procedure RefreshBoardViews;
  public
    { Public 宣言 }
    // フレームを生成する
    constructor Create(AOwner: TComponent); override;
    // フレームを破棄する
    destructor Destroy;override;

    procedure Show;
    procedure ShowBoard;
  end;

implementation

{$R *.dfm}

uses AppFolderUtils,AviUtl2StyleColors,AviUtl2SerifBoard,ListViewRTTI,
     ListViewEditPluginLib;

{ TFrameSerifBoard }

constructor TFrameSerifBoard.Create(AOwner: TComponent);
begin
  inherited;

  GetAppFolder('Serif');       // Windows状態保存ファイル設定
  FBoardFolder := GetAppFolder('Serif\Board');

  FBound := TFrameSerifBoardBound.Create;
  FBound.Filename  := FBoardFolder +  'BoardFrame.ini';       // Windows状態保存ファイル名設定

  FRenderBatch := TSerifBoardRenderBatch.Create(FBoardFolder);

  LBoxStyle.Color := A2SCListBoxBackground;
  LBoxStyle.Font.Color := A2SCListBoxText;
  LBoxStyle.Font.Height := -13;
  LBoxStyle.ItemHeight := 24;

  CBoxResolution.Color := A2SCComboBackground;
  CBoxResolution.Font.Color := A2SCComboText;
  CBoxResolution.Font.Height := -12;


  FBoardList := TSerifBoardListView.Create(Self);
  FBoardList.Parent := Self;
  FBoardList.Align := alClient;
  FBoardList.Color := A2SCListViewBackground;
  FBoardList.Font.Height := -12;
  FBoardList.BorderStyle := bsNone;
  FBoardList.PopupMenu := MenuPop;

  FPanelConfig := TConfigPanel.Create(Self);
  FPanelConfig.Parent := PanelConfig;
  FPanelConfig.Align := alClient;
  FPanelConfig.Color := A2SCListViewBackground;
  FPanelConfig.ListViewColor := A2SCListViewBackground;
  FPanelConfig.Font.Height := -12;
  FPanelConfig.ListView.ItemHeight := 20;
  FPanelConfig.OnChange := OnConfigChange;

  FDrag := TDragShellFile.Create(Self);
  FDrag.Attach(FBoardList);
  FDrag.OnDragRequest := OnDrag;

end;

destructor TFrameSerifBoard.Destroy;
begin
  FBound.FrameToSelf(Self);
  FBound.SaveToFile;

  if Assigned(FRenderBatch) then FRenderBatch.DetachAsync;
  FRenderBatch.Free;

  FBoardList.Free;
  FDrag.Free;

  FBound.Free;
  inherited;
end;

procedure SetLayer(ts : TStringList);
var
  i : Integer;
  s : string;
begin
  ts.Clear;
  for i := 0 to 99 do begin
    s := 'レイヤー ' + IntToStr(i+1);
    ts.AddObject(s,TObject(i));
  end;
end;


procedure TFrameSerifBoard.ShowCOnfig;
var
  lv : TListViewRTTI;
  ts : TStringList;
begin
  lv := FPanelConfig.ListView;
  lv.Clear;
  lv.RTTINames['EnableScript'].AddCaption('セリフ連動','セリフがあるときのみ表示',clSkyBlue,ListViewEditPluginBoolId);
  lv.RTTINames['Layer'].AddCaption('参照レイヤー','セリフ参照レイヤー',clSkyBlue,ListViewEditPluginComboBoxObjectId);
  lv.RTTINames['Hold'].AddCaption('表示維持','セリフ後の表示維持',clSkyBlue);
  lv.RTTINames['Fade'].AddCaption('消失速度','フェードアウト速度',clSkyBlue);
  ts := lv.RTTINames['EnableScript'].Strings;
  ts.Clear;
  ts.Add('しない');
  ts.Add('する');

  ts := lv.RTTINames['Layer'].Strings;
  SetLayer(ts);
  FPanelConfig.ShowConfig(FBound);
end;

procedure TFrameSerifBoard.ShowBoard;
begin
  Show;

  if not Assigned(FRenderBatch) then Exit;
  if FRenderBatch.IsRunning then Exit;

  if FRenderBatch.NeedsRender then
    FRenderBatch.ExecuteAsync(OnGenerateCoordAreaPreviewFinished)
  else
    RefreshBoardViews;
end;

procedure TFrameSerifBoard.EnsureBoardStyleFolders;
begin
  //EnsureBoardStyleFolder(1920, 1080, 'sample');
end;

procedure TFrameSerifBoard.LBoxStyleClick(Sender: TObject);
begin
  ShowBoardList;
end;

procedure TFrameSerifBoard.MenuFolderOpenClick(Sender: TObject);
var
  FolderPath: string;
begin
  FolderPath := FBoardFolder;
  if FolderPath = '' then Exit;

  if not TDirectory.Exists(FolderPath) then TDirectory.CreateDirectory(FolderPath);

  ShellExecute(Handle, 'open', PChar(FolderPath), nil, nil, SW_SHOWNORMAL);
end;

procedure TFrameSerifBoard.EnsureBoardStyleFolder(const AWidth, AHeight: Integer; const AStyleName: string);
var
  FolderName: string;
  FolderPath: string;
begin
  if (AWidth <= 0) or (AHeight <= 0) or (AStyleName = '') then Exit;

  if not TDirectory.Exists(FBoardFolder) then
    TDirectory.CreateDirectory(FBoardFolder);

  FolderName := Format('%dx%d_%s', [AWidth, AHeight, AStyleName]);
  FolderPath := TPath.Combine(FBoardFolder, FolderName);
  if not TDirectory.Exists(FolderPath) then
    TDirectory.CreateDirectory(FolderPath);
end;

function TFrameSerifBoard.GetBoardStyleFolder: string;
begin
  Result := '';
  if CBoxResolution.Text = '' then
    Exit;
  if LBoxStyle.ItemIndex < 0 then
    Exit;

  Result := TPath.Combine(FBoardFolder, CBoxResolution.Text + '_' + LBoxStyle.Items[LBoxStyle.ItemIndex]);
end;

procedure TFrameSerifBoard.ShowResolutionList;
var
  DirPath: string;
  FolderName: string;
  DisplayName: string;
  SepPos: Integer;
begin
  CBoxResolution.Items.BeginUpdate;
  try
    CBoxResolution.Items.Clear;

    if not TDirectory.Exists(FBoardFolder) then Exit;

    for DirPath in TDirectory.GetDirectories(FBoardFolder) do begin
      FolderName := ExtractFileName(DirPath);
      SepPos := FolderName.IndexOf('_');
      if SepPos <= 0 then Continue;

      DisplayName := FolderName.Substring(0, SepPos);
      if DisplayName = '' then Continue;
      if CBoxResolution.Items.IndexOf(DisplayName) <> -1 then Continue;

      CBoxResolution.Items.Add(DisplayName);
    end;

    if CBoxResolution.Items.Count > 0 then
      CBoxResolution.ItemIndex := 0
    else
      CBoxResolution.ItemIndex := -1;

    ShowStyleList;
  finally
    CBoxResolution.Items.EndUpdate;
  end;
end;

procedure TFrameSerifBoard.ShowStyleList;
var
  DirPath: string;
  FolderName: string;
  ResolutionName: string;
  StyleName: string;
  SepPos: Integer;
begin
  LBoxStyle.Items.BeginUpdate;
  try
    LBoxStyle.Items.Clear;

    if (CBoxResolution.Text = '') or not TDirectory.Exists(FBoardFolder) then
      Exit;

    for DirPath in TDirectory.GetDirectories(FBoardFolder) do begin
      FolderName := ExtractFileName(DirPath);
      SepPos := FolderName.IndexOf('_');
      if SepPos <= 0 then
        Continue;

      ResolutionName := FolderName.Substring(0, SepPos);
      if ResolutionName <> CBoxResolution.Text then
        Continue;

      StyleName := FolderName.Substring(SepPos + 1);
      if StyleName = '' then
        Continue;

      LBoxStyle.Items.Add(StyleName);
    end;

    if LBoxStyle.Items.Count > 0 then
      LBoxStyle.ItemIndex := 0
    else
      LBoxStyle.ItemIndex := -1;

    ShowBoardList;
  finally
    LBoxStyle.Items.EndUpdate;
  end;
end;

procedure TFrameSerifBoard.ShowBoardList;
var
  FolderPath: string;
begin
  FolderPath := GetBoardStyleFolder;

  FBoardList.Clear;
  if FolderPath = '' then Exit;

  FBoardList.ShowFolder(FolderPath);
end;



procedure TFrameSerifBoard.OnConfigChange(Sender: TObject);
begin
  FBound.SaveToFile;
end;

procedure TFrameSerifBoard.OnDrag(Sender: TObject; FileNames: TStringList);
var
  i : Integer;
  s,FileName : string;
begin
  i := FBoardList.ItemIndex;
  if i = -1 then Exit;

  FileName := FBoardList.Files[i].FileName;
  s := AviUtl2SerifBoardSend(0,FileName,FBound.EnableScript,FBound.Layer,FBound.Hold,FBound.Fade,False);
  FileNames.Clear;
  FileNames.Add(s);
end;

procedure TFrameSerifBoard.OnGenerateCoordAreaPreviewFinished(
  const AException: Exception);
begin
  if Assigned(AException) then Exit;

  RefreshBoardViews;
  ShowBoard;
end;

procedure TFrameSerifBoard.RefreshBoardViews;
begin
  ShowResolutionList;
end;

procedure TFrameSerifBoard.CBoxResolutionChange(Sender: TObject);
begin
  ShowStyleList;
end;

procedure TFrameSerifBoard.Show;
begin
  FBound.LoadFromFile;
  FBound.SelfToFrame(Self);

  ShowCOnfig;

  // コンボボックスのテーマを外して一覧表示を揃える
  CBoxResolution.HandleNeeded;
  SetWindowTheme(CBoxResolution.Handle, '', '');

  EnsureBoardStyleFolders;
  if Assigned(FRenderBatch) and FRenderBatch.NeedsRender then
  begin
    CBoxResolution.Items.Clear;
    CBoxResolution.ItemIndex := -1;
    LBoxStyle.Items.Clear;
    LBoxStyle.ItemIndex := -1;
    FBoardList.Clear;
  end
  else
    RefreshBoardViews;

  inherited Show;
end;

{ TFrameSerifBoardBound }

constructor TFrameSerifBoardBound.Create;
begin
  FHold := 5;
  FFade := 5;
  FPanelConfigHeight := 50;
end;

procedure TFrameSerifBoardBound.FrameToSelf(AFrame: TFrame);
begin
  FZoomIndex := TFrameSerifBoard(AFrame).FBoardList.ZoomIndex;
  FPanelConfigHeight := TFrameSerifBoard(AFrame).PanelConfig.Height;
  if FPanelConfigHeight = 0 then FPanelConfigHeight := 70;

end;

procedure TFrameSerifBoardBound.SelfToFrame(AFrame: TFrame);
begin
  TFrameSerifBoard(AFrame).FBoardList.ZoomIndex := FZoomIndex;
  TFrameSerifBoard(AFrame).PanelConfig.Height := FPanelConfigHeight;
end;

end.
