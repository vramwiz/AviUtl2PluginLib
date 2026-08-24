unit SerifForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ComCtrls, Vcl.ExtCtrls,RTTIPersistentForm,SerifFrame;
type
  TFormSerif = class(TForm)
    TraySerif: TTrayIcon;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure TraySerifClick(Sender: TObject);
  private
    { Private 宣言 }
    FBound          : TRTTIFormBounds;              // Windows位置とサイズ記憶クラス
    FFormVisibleSerif: Boolean;                      // True:フォーム表示中
    FFrameSerif     : TFrameSerif;
  public
    { Public 宣言 }
    procedure RequestClose();
  end;

var
  FormSerif: TFormSerif;

implementation

uses  AppFolderUtils, System.IOUtils, BootManager;

var
  IsRequestClose : Boolean;

{$R *.dfm}

procedure TFormSerif.FormCreate(Sender: TObject);
begin

  FBound := TRTTIFormBounds.Create;
  FBound.Filename  := GetAppFolder('Serif') +  'SerifWindow.ini';       // Windows状態保存ファイル名設定

  FFrameSerif := TFrameSerif.Create(Self);
  FFrameSerif.Parent := Self;
  FFrameSerif.Align := alClient;
end;

procedure TFormSerif.FormDestroy(Sender: TObject);
begin
  FFrameSerif.Free;
  FBound.Free;
  FormSerif := nil;
end;

procedure TFormSerif.FormShow(Sender: TObject);
begin
  if FFormVisibleSerif then Exit;

  if not FBound.LoadFromFile then begin
    FBound.InitializeFromForm(Self);
  end;
  FBound.SelfToForm(Self);
  FFormVisibleSerif := True;
  FFrameSerif.Show;
end;

procedure TFormSerif.FormClose(Sender: TObject; var Action: TCloseAction);
var
  f : Boolean;
begin
  f := False;
  if IsRequestClose         then f := True;           // 終了要求がある場合
  if not FFrameSerif.IsStartd then f := True;           // 監視中でない場合
  // Desktopのツールナビゲーションから起動した場合、閉じる操作はトレイ格納ではなくツール終了とする。
  // フォーム解放をBootManagerが検出すると、非表示にしたツールバーが再表示される。
  if Assigned(GBootManager.OnToolFinish) then f := True;

  if f then begin                                     // 終了する場合
    FFormVisibleSerif := False;
    FBound.FormToSelf(Self);                          // フォームの状態をデータ化
    FBound.SaveToFile;
    Action := caFree;                                 // フォームを解放
    TraySerif.Visible := False;                       // トレイアイコンを非表示
    Exit;
  end;

  TraySerif.Visible := True;                          // トレイアイコンに表示
  Action := TCloseAction.caHide;                      // フォームを非表示

end;

procedure TFormSerif.RequestClose;
begin
  IsRequestClose := True;
  Close;
end;


procedure TFormSerif.TraySerifClick(Sender: TObject);
begin
  Self.Show;
end;

end.
