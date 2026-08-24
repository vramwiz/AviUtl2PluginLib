unit ExplorerListSound;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  ListViewEdit,ListViewEx,Vcl.Menus,System.Generics.Collections,
  Vcl.StdCtrls, Vcl.ExtCtrls,RTTIPersistent,ExplorerFileList,ExplorerListView,
  ListViewRTTI,DragAgent,AudioPlayer;


procedure ExplorerConfigSoundShow(lv : TListViewRTTI;Item : TExplorerFileItem);

// 標準ファイルの情報　このクラスは拡張しない
type
  TExplorerFileSoundItem = class(TExplorerFileItem)
  private
    FVolume    : Double;               // 音量
    FPan       : Double;               // 位置
    FPlaySpeed : Double;               // 再生速度
    FPlayLoop  : Integer;              // ループ再生
    FTrack     : Integer;              // トラック
    FFadeMode  : Integer;              // 0:なし 1:フェードイン 2:フェードアウト 3:フェードインアウト
    FFadeIn    : Double;               // フェードイン時間（秒）
    FFadeOut   : Double;               // フェードアウト時間（秒）
  protected
  public
    constructor Create;
  published
    property Volume    : Double  read FVolume       write FVolume;
    property Pan       : Double  read FPan          write FPan;
    property PlaySpeed : Double  read FPlaySpeed    write FPlaySpeed;
    property PlayLoop  : Integer read FPlayLoop     write FPlayLoop;
    property Track     : Integer read FTrack        write FTrack;
    // ここから先はオリジナル要素
    property FadeMode  : Integer read FFadeMode     write FFadeMode;
    property FadeIn    : Double  read FFadeIn       write FFadeIn;
    property FadeOut   : Double   read FFadeOut     write FFadeOut;
  end;

// ファイルリスト
type
  TExplorerFileSoundList = class(TExplorerFileList<TExplorerFileSoundItem>)
	private
    function GetFiles(Index: Integer): TExplorerFileSoundItem;
		{ Private 宣言 }
  protected
    function IsVisibleExtension(const FileName : string) : Boolean;override;
	public
		{ Public 宣言 }
    constructor Create;override;
    destructor Destroy; override;


    property Files[Index : Integer] : TExplorerFileSoundItem read GetFiles;default;
	end;
                                                           // ExplorerListView2
  //TExplorerListViewNormal<T: TExplorerFile2Item, constructor> = class(TListViewThumbnail)
  TExplorerListViewSound = class(TExplorerListView<TExplorerFileSoundItem>)
  private
    FDrag        : TDragShellFile;
    FAudioPlayer : TAudioPlayer;
    procedure OnDrag(Sender: TObject;FileNames : TStringList);
    function GetFiles(Index: Integer): TExplorerFileSoundItem;
  protected
    procedure WMLButtonDblClk(var Msg: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Files[Index : Integer] : TExplorerFileSoundItem read GetFiles;default;
  end;


implementation


uses ListViewEditPluginLib,ListViewEditPluginDialog,AviUtl2Sound;
 //uses  AppFolderUtils,AliasManagerStringList,;

{ TExplorerFileSoundList }

constructor TExplorerFileSoundList.Create;
begin
  inherited;
  FExtensions.Add('.wav');
  FExtensions.Add('.mp3');
  FExtensions.Add('.wma');
end;

destructor TExplorerFileSoundList.Destroy;
begin

  inherited;
end;

function TExplorerFileSoundList.GetFiles(Index: Integer): TExplorerFileSoundItem;
begin
  Result := inherited Items[Index];
end;

function TExplorerFileSoundList.IsVisibleExtension(
  const FileName: string): Boolean;
begin
  Result := True;
end;


{ TExplorerFileSoundItem }

constructor TExplorerFileSoundItem.Create;
begin
  FVolume    := 100.00;
  FPlaySpeed := 100.00;
  FFadeIn    := 2.00;
  FFadeout   := 2.00;
end;

procedure ExplorerConfigSoundShow(lv : TListViewRTTI;Item : TExplorerFileItem);
var
  ts : TStringList;
begin
  if not (Item is TExplorerFileItem) then Exit;

  lv.RTTINames['FileName'].EditType := ListViewEditPluginHideId;
  lv.RTTINames['Name'].EditType := ListViewEditPluginHideId;


  lv.RTTINames['Volume'].AddCaption('音量','音声ファイルの音量を設定',clSkyBlue);
  lv.RTTINames['Pan'].AddCaption('位置','再生位置（左右バランス）を設定',clMoneyGreen);

  lv.RTTINames['PlaySpeed'].AddCaption('早さ','音声の再生速度',clBtnFace);
  lv.RTTINames['PlayLoop'].AddCaption('ループ','音声のループ設定',clBtnFace,ListViewEditPluginBoolId);
  lv.RTTINames['Track'].AddCaption('トラック','',clBtnFace);

  lv.RTTINames['FadeMode'].AddCaption('フェード種類','フェードインフェードアウトを設定',clWebPink,ListViewEditPluginComboBoxId);
  lv.RTTINames['FadeIn'].AddCaption('フェードイン(秒)','フェードイン時間を設定',clWebPink);
  lv.RTTINames['FadeOut'].AddCaption('フェードアウト(秒)','フェードアウト時間を設定',clWebPink);

  ts := lv.RTTINames['PlayLoop'].Strings;
  ts.Clear;
  ts.Add('しない');
  ts.Add('する');

  ts := lv.RTTINames['FadeMode'].Strings;
  ts.Clear;
  ts.Add('しない');
  ts.Add('フェードイン');
  ts.Add('フェードアウト');
  ts.Add('フェードインアウト');

  //lv.SetVisibleIndex();
  lv.LoadFromObject(Item);
 // lv.Refresh;
  lv.FixedWidth := 100;

end;


{ TExplorerListViewSound }

constructor TExplorerListViewSound.Create(AOwner: TComponent);
begin
  inherited;
  FFiles := TExplorerFileSoundList.Create;
  FAudioPlayer := TAudioPlayer.Create;

  SetThumbnailSize(vsReport,24,24,True);

  FDrag := TDragShellFile.Create(Self);
  FDrag.Attach(Self);
  FDrag.OnDragRequest := OnDrag;

end;

destructor TExplorerListViewSound.Destroy;
begin
  FAudioPlayer.Free;
  FDrag.Free;
  FFiles.Free;
  inherited;
end;

function TExplorerListViewSound.GetFiles(Index: Integer): TExplorerFileSoundItem;
begin
  Result := TExplorerFileSoundItem(FFiles[Index]);
end;

procedure TExplorerListViewSound.OnDrag(Sender: TObject;FileNames: TStringList);
var
  i : Integer;
  s :string;
  Item : TExplorerFileSoundItem;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  Item := GetFiles(i);
  if Item = nil  then Exit;

  s := AviUtl2SoundDandD(Item);

  FileNames.Clear;
  FileNames.Add(s);
end;

procedure TExplorerListViewSound.WMLButtonDblClk(var Msg: TWMLButtonDblClk);
var
  i: Integer;
  Item: TExplorerFileSoundItem;
begin
  inherited;

  i := ItemIndex;
  if i = -1 then Exit;
  if FAudioPlayer = nil then Exit;

  Item := GetFiles(i);
  if Item = nil then Exit;
  if not FileExists(Item.FileName) then Exit;

  FAudioPlayer.Volume := Round(Item.Volume);
  FAudioPlayer.Play(Item.FileName);
end;

end.
