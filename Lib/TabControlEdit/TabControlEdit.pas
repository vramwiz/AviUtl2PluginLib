unit TabControlEdit;

interface

uses
  Winapi.Windows, Winapi.CommCtrl, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Vcl.ComCtrls, Vcl.Menus;

type TTabControlEditEditStart = procedure (Sender : TObject; var EditStr : string) of object;
type TTabControlEditEditOk = procedure (Sender : TObject;const  EditStr : string) of object;


//--------------------------------------------------------------------------//
//  タブコントロールの名称を編集可能にする拡張タブコントロールクラス        //
//--------------------------------------------------------------------------//
type
  TTabControlEdit = class(TTabControl)
	private
		{ Private 宣言 }
    FEdit : TEdit;
    FProc : TWndMethod;
    FPopMenu : TPopupMenu;      // ポップアップメニューを一時待避

    FOnEditOk: TTabControlEditEditOk;
    FOnEditNg: TNotifyEvent;
    FOnEditStart: TTabControlEditEditStart;
    FOnTabClick: TNotifyEvent;
    FEditing: Boolean;
    FOnTabSelect: TNotifyEvent;
    // 外部からの編集有効終了処理
    procedure EditOK();
    // 外部からの編集無効処理
    procedure EditNG();

    // ホイールスクロールイベント
    procedure WMMousewheel(var Msg: TMessage); message WM_MOUSEWHEEL;

    procedure OnSelfChange(Sender: TObject);
    procedure OnSelfDblClick(Sender: TObject);
    procedure OnEditExit(Sender: TObject);
    procedure OnEditKeyPress(Sender: TObject; var Key: Char);
    procedure OnSelfDrawTab(Control: TCustomTabControl; TabIndex: Integer; const Rect: TRect; Active: Boolean);
  protected
    procedure DoEditStart(var EditStr : string);virtual;
    procedure DoEditOk(const EditStr : string);virtual;
    procedure DoEditNg();virtual;
    procedure DoTabClick();virtual;
    procedure DoTabSelect();virtual;
  public
		{ Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;
    // 外部から編集開始状態に
    procedure EditStart();
    // ウインドウメッセージをフック
    procedure WMProc(var Msg:TMessage);
    procedure ScrollToTab(Index: Integer);
    // True : 編集中
    property Editing : Boolean read FEditing;

    // 編集開始イベント
    property OnEditStart : TTabControlEditEditStart read FOnEditStart write FOnEditStart;
    // 編集を有効にして終了するイベント
    property OnEditOk    : TTabControlEditEditOk read FOnEditOk write FOnEditOk;
    // 編集を無効にして終了するイベント
    property OnEditNg    : TNotifyEvent read FOnEditNg write FOnEditNg;
    // タブクリックイベント
    property OnTabClick : TNotifyEvent read FOnTabClick write FOnTabClick;
    // タブ選択イベント
    property OnTabSelect : TNotifyEvent read FOnTabSelect write FOnTabSelect;
  published
    property OnDblClick;
  end;

procedure TabControlDraRectClear(cv: TCanvas; TabIndex: Integer; Rect: TRect);
// 背景塗りつぶしの描画代行のみ処理を外部からも使えるように
procedure TabControlDrawRect(Canvas: TCanvas; TabIndex: Integer; Rect: TRect;Active: Boolean);
// 指定した領域にタブの台形を描画
procedure TabControlDrawRectPolygon(Canvas: TCanvas;Rect: TRect);
procedure TabControlTextOut(Canvas: TCanvas;Rect: TRect;Active: Boolean;const str : string);




implementation

uses AviUtl2StyleColors;

// デバッグ用
//uses MainForm;

const
  COLOR_CURSOL = clNavy;


{ TTabControlEdit }

constructor TTabControlEdit.Create(AOwner: TComponent);
begin
  inherited;

  FProc := WindowProc;
  WindowProc := WMProc;

  ControlStyle := ControlStyle + [csClickEvents];
  OnDblClick := OnSelfDblClick;
  OnChange := OnSelfChange;
  OnDrawTab := OnSelfDrawTab;
  Color :=  A2SCTabBackground;
  OwnerDraw := true;
  Style := tsButtons;

  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.Visible := False;
  FEdit.OnExit := OnEditExit;
  FEdit.OnKeyPress := OnEditKeyPress;
end;

destructor TTabControlEdit.Destroy;
begin
  WindowProc := FProc;
  FEdit.Free;
  inherited;
end;


procedure TTabControlEdit.DoEditNg;
begin
  if Assigned(FOnEditNg) then begin
    FOnEditNg(Self);
  end;
end;

procedure TTabControlEdit.DoEditOk(const EditStr: string);
begin
  if Assigned(FOnEditOk) then begin
    FOnEditOk(Self,EditStr);
  end;
end;

procedure TTabControlEdit.DoEditStart(var EditStr: string);
begin
  if Assigned(FOnEditStart) then begin
    FOnEditStart(Self,EditStr);
  end;
end;

procedure TTabControlEdit.DoTabClick;
begin
  if Assigned(FOnTabClick) then begin
    FOnTabClick(Self);
  end;
end;

procedure TTabControlEdit.DoTabSelect;
begin
  if Assigned(FOnTabSelect) then begin
    FOnTabSelect(Self);
  end;
end;

procedure TTabControlEdit.EditNG;
begin
  if not Visible then exit;
  FEdit.Visible := False;
  DoEditNg();
  PopupMenu := FPopMenu;
  FEditing := False;
end;

procedure TTabControlEdit.EditOK;
var
  i : Integer;
begin
  i :=TabIndex;
  if i =-1 then exit;
  DoEditOk(FEdit.Text);
  Tabs[i] := FEdit.Text;
  FEdit.Visible := False;
  PopupMenu := FPopMenu;
  FEditing := False;
end;

procedure TTabControlEdit.EditStart;
var
  str : string;
  i : Integer;
begin
  if FEdit.Visible then EditOk();        // 編集中の場合、編集結果を有効にしてから編集
  FPopMenu := PopupMenu;
  PopupMenu := nil;
  FEditing := True;
  i := TabIndex;
  if i = -1 then exit;
  str := Tabs[i];
  DoEditStart(str);
  if FEdit <> nil then begin
    FEdit.Left := TabRect(TabIndex).Left;
    FEdit.Top := 0;                       // 表示座標計算
    FEdit.Width := TabRect(TabIndex).Width;
    FEdit.Color := A2SCEditBackground;
    FEdit.font.Color := A2SCEditText;
  end;
  FEdit.Text := str;
  FEdit.Visible := True;
  //FEdit.AutoSize := true;
  FEdit.SelectAll;
  FEdit.SetFocus;
end;

procedure TTabControlEdit.OnEditExit(Sender: TObject);
begin
  EditNG();
end;

procedure TTabControlEdit.OnEditKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #$0d then begin
    EditOk();
    Key := #0;
  end;
end;

procedure TTabControlEdit.OnSelfChange(Sender: TObject);
begin
  EditNG();
  DoTabClick();
end;

procedure TTabControlEdit.OnSelfDblClick(Sender: TObject);
begin
  EditStart();
end;

procedure TTabControlEdit.OnSelfDrawTab(Control: TCustomTabControl;
  TabIndex: Integer; const Rect: TRect; Active: Boolean);
var
  cv : TCanvas;
  s : string;
begin
  cv := Canvas;
  s := Tabs.Strings[TabIndex];
  //TabControlDraRectClear(cv,TabIndex,Rect);
  TabControlDrawRect(cv,TabIndex,Rect,Active);
  TabcontrolTextOut(cv,Rect,Active,s);
end;

procedure TTabControlEdit.ScrollToTab(Index: Integer);
var
  R: TRect;
begin
  TabIndex := Index;

  SendMessage(Handle, TCM_GETITEMRECT, Index, LPARAM(@R));

  while R.Right > ClientWidth do begin
    Perform(WM_HSCROLL, SB_RIGHT, 0);
    SendMessage(Handle, TCM_GETITEMRECT, Index, LPARAM(@R));
  end;

  while R.Left < 0 do begin
    Perform(WM_HSCROLL, SB_LEFT, 0);
    SendMessage(Handle, TCM_GETITEMRECT, Index, LPARAM(@R));
  end;
end;

const TCM_GETITEMCOUNT = $1304;        // タブの個数を取得※追加時に送られてくる
      TCM_DELETEITEM   = $1308;        // タブ削除

procedure TTabControlEdit.WMMousewheel(var Msg: TMessage);
var
  i,d : Integer;
begin
  d := shortint(HiWord(Msg.wParam));
  i := TabIndex;
  if (d > 0) then begin                // ホイールを奥
    // left
    if i < 1 then exit;
    Dec(i);
    TabIndex := i;
    DoTabSelect();
  end
  else begin                           // ホイール手前
    //  right
    if i >= Tabs.Count then exit;
    Inc(i);
    TabIndex := i;
    DoTabSelect();
  end;
end;

procedure TTabControlEdit.WMProc(var Msg: TMessage);
begin
  FProc(Msg);                             // 元のプロセスにも送る
  //FormMain.MsgDebug(Msg.Msg);             // ※デバッグ用
  case Msg.Msg of
    WM_HSCROLL:EditNG;
//    TCM_GETITEMCOUNT :EditNG;
    TCM_DELETEITEM   :EditNG;
    WM_SIZE          :EditNG;
  end;
end;

procedure TabControlDraRectClear(cv: TCanvas; TabIndex: Integer; Rect: TRect);
begin
  cv.Brush.Style := bsSolid;
  cv.Brush.Color := clBtnFace;
  cv.FillRect(Rect);
end;

procedure TabControlDrawRect(Canvas: TCanvas; TabIndex: Integer; Rect: TRect; Active: Boolean);
var
  cv : TCanvas;
  cF,cB : TColor;
begin
  cv := Canvas;

  if Active then
  begin
    cB := A2SCTabActive;
    cF := A2SCTabActiveText;
  end
  else
  begin
    cB := A2SCTabNormal;
    cF := A2SCTabText;
  end;

  cv.Brush.Color := cB;
  cv.Font.Color  := cF;

  TabControlDrawRectPolygon(cv, Rect);
end;

procedure TabControlDrawRectPolygon(Canvas: TCanvas;Rect: TRect);
var
  p : array[0..4] of TPoint;
begin
  p[0].X := Rect.Left;
  p[0].Y := Rect.Bottom;
  p[1].X := Rect.Left + 2;
  p[1].Y := Rect.Top;
  p[2].X := Rect.Right - 2;
  p[2].Y := Rect.Top;
  p[3].X := Rect.Right;
  p[3].Y := Rect.Bottom;
  p[4].X := Rect.Left;
  p[4].Y := Rect.Bottom;
  Canvas.Polygon(p);
end;

procedure TabControlTextOut(Canvas: TCanvas;Rect: TRect;Active: Boolean;const str : string);
var
  cv : TCanvas;
begin
  cv := Canvas;
  if Active then begin
    cv.Brush.Color := COLOR_CURSOL ;
    cv.Font.Color  := clWhite;
  end;
  cv.Brush.Style := bsClear;
  cv.TextOut(Rect.Left+5,Rect.Top+3,str);
end;

end.
