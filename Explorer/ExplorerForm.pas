unit ExplorerForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,RTTIPersistentForm,ListViewThumbnail,
  Vcl.StdCtrls, Vcl.ExtCtrls,ExplorerFileList,ExplorerHistFrame,ExplorerHist,
  ExplorerListViewFrame,DropFile,ExplorerFrame;

type
  TFormExplorerBound = class(TRTTIFormBounds)
  private
    FPictureZoomIndex  : Integer;
  public
    constructor Create;
  published
    property PictureZoomIndex  : Integer read FPictureZoomIndex  write FPictureZoomIndex;
end;


type
  TFormExplorer = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private 宣言 }
    FBound          : TFormExplorerBound;
    FDrop           : TDropFile;
    FFrameExplorer  : TFrameExplorer;
  public
    { Public 宣言 }
    // ファイルドロップイベント
    procedure OnDropFile(Sender: TObject; Control: TWinControl; const FileNames: TArray<string>);
  end;


var
  FormExplorer: TFormExplorer;

implementation

uses  AppFolderUtils, Winapi.ShlObj,Winapi.KnownFolders,Winapi.ActiveX;


{$R *.dfm}

procedure TFormExplorer.FormCreate(Sender: TObject);
var
  s : string;
begin

  s :=  GetAppFolder('Explorer');
  FBound := TFormExplorerBound.Create;
  FBound.Filename  := s +  'ExplorerForm.ini';       // Windows状態保存ファイル名設定


  FFrameExplorer  := TFrameExplorer.Create(Self);
  FFrameExplorer.Parent := Self;
  FFrameExplorer.Align := alClient;

  FDrop  := TDropFile.Create;
  FDrop.Attach(Self);
  FDrop.OnDropReceived := OnDropFile;
end;

procedure TFormExplorer.FormDestroy(Sender: TObject);
begin
  FDrop.Free;
  FFrameExplorer.Free;
  FBound.Free;
  FormExplorer := nil;
end;


procedure TFormExplorer.FormShow(Sender: TObject);
begin

  if not FBound.LoadFromFile then begin
    FBound.InitializeFromForm(Self);
  end;
  FBound.SelfToForm(Self);
  FFrameExplorer.Show;
end;

procedure TFormExplorer.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FBound.FormToSelf(Self);                           // フォームの状態をデータ化
  FBound.SaveToFile;
  Action := caFree;

end;


procedure TFormExplorer.OnDropFile(Sender: TObject; Control: TWinControl;
  const FileNames: TArray<string>);
begin
  FFrameExplorer.DropFile(FileNames);
end;



{ TFormExplorerBound }

constructor TFormExplorerBound.Create;
begin
  FPictureZoomIndex  := 2;
end;

end.
