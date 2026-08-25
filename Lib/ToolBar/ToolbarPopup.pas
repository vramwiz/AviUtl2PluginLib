unit ToolbarPopup;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,
  NonActiveForm,Vcl.ImgList,ToolbarCaptions;

type
  // ポップアップ表示用のツールバーを提供する非アクティブフォーム
  TFormToolbarPopup = class(TFormNonActive)
  private
    FToolbar : TToolbarCaptions; // 表示するツールバー本体
    FTimer   : TTimer;           // 非表示判定を行うための監視タイマー
    FWatch: TWinControl;         // 将来のアクティブ状態監視用コントロール
    // ツールバーを表示状態として維持すべきかを判定する
    function IsVisible() : Boolean;
    // タイマー発火時に表示状態を監視する
    procedure OnTimer(Sender: TObject);
    // サブメニューからのポップアップを非表示通知
    procedure OnMenuHide(Sender: TObject);
    // ツールバーに使用するイメージリストを設定する
    procedure SetImages(const Value: TCustomImageList);
  public
    // ポップアップツールバー用フォームを生成する
    constructor Create(AOwner: TComponent); override;
    // ポップアップツールバー用フォームを破棄する
    destructor Destroy; override;
    // ポップアップ表示用に初期化を行いフォームを表示する
    procedure Show;
    // 現在のマウスカーソル位置にポップアップ表示する
    procedure Popup;
    // キャプション付きアイコンをツールバーに追加する
    function AddCaption(const ACaption: string;AImageIndex: Integer=-1;AHint : string=''): TToolbarCaptionItem;
  published
    property Watch : TWinControl read FWatch write FWatch; // 関連コントロールを監視するための拡張用プロパティ
    property Images: TCustomImageList write SetImages;     // ツールバーで使用する画像リスト

    //property Toolbar : TToolbarCaptions read FToolbar;
  end;

implementation

{ TFormToolbarPopup }

// ポップアップツールバー用フォームを初期化する
constructor TFormToolbarPopup.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FTimer := TTimer.Create(Self);
  FTimer.Enabled  := False;
  FTimer.Interval := 1000; // 1秒
  FTimer.OnTimer  := OnTimer;

  FToolbar := TToolbarCaptions.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.Align  := alClient;
  FToolbar.BevelInner := bvRaised;
  FToolbar.OnMenuHide := OnMenuHide;

end;

// ポップアップツールバー用フォームを破棄する
destructor TFormToolbarPopup.Destroy;
begin
  FreeAndNil(FToolbar);
  FreeAndNil(FTimer);
  inherited Destroy;
end;

// キャプション付きアイコンを内部ツールバーに追加する
function TFormToolbarPopup.AddCaption(const ACaption: string;AImageIndex: Integer=-1;AHint : string=''): TToolbarCaptionItem;
begin
  Result := FToolbar.AddCaption(ACaption,AImageIndex,AHint);
  Self.ClientWidth := FToolbar.GetRequiredWidth();

end;

// 現在も表示を維持すべき状態かを判定する
function TFormToolbarPopup.IsVisible: Boolean;
begin
  Result := False;
  // ツールバー内にマウスが無ければ非表示
  if FWatch<>nil then begin
    if FWatch.Focused then Exit(True);
  end;

  if FToolbar.IsHover then Exit(True);

end;

// ツールバーに使用するイメージリストを設定する
procedure TFormToolbarPopup.SetImages(const Value: TCustomImageList);
begin
  FToolbar.Images := Value;
end;

// ポップアップ表示用にフォームを表示しタイマーを開始する
procedure TFormToolbarPopup.Show;
begin
  //Height := (96 div Self.CurrentPPI)  * 32;

  FToolbar.HideSubMenu;                      // サブメニューを非表示
  inherited Show;

  FToolbar.Show;
  ClientWidth := FToolbar.Width;
  // 表示のたびにタイマーをリセット
  FTimer.Enabled := False;
  FTimer.Enabled := True;
end;

procedure TFormToolbarPopup.OnMenuHide(Sender: TObject);
begin
   Self.Hide;
end;

// タイマー発火時に表示継続可否を判定する
procedure TFormToolbarPopup.Ontimer(Sender: TObject);
begin
  // ワンショット動作
  FTimer.Enabled := False;

  if not IsVisible then begin                // ツールバー内にマウスが無ければ非表示
    FToolbar.HideSubMenu;                    // サブメニューを非表示
    Self.Hide;
    Exit;
  end;
  FTimer.Enabled := True;
end;

// マウスカーソル位置を基準にポップアップ表示する
procedure TFormToolbarPopup.Popup;
var
  P: TPoint;
begin
  GetCursorPos(P);

  Left := P.X + 16;
  Top  := P.Y + 8;
  ClientWidth := FToolbar.Width - 2;
  ClientHeight := FToolbar.Height;
  Show;
end;

end.

