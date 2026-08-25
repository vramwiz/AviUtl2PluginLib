unit ListBoxEx;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Vcl.ComCtrls,Vcl.Menus,Vcl.CheckLst;

type TListBoxExEditStart = procedure (Sender : TObject; var EditStr : string) of object;
type TListBoxExEditOk = procedure (Sender : TObject;const  EditStr : string) of object;


//--------------------------------------------------------------------------//
//  リストロールを編集可能にする拡張リストコントロールクラス                //
//--------------------------------------------------------------------------//
type
  TListBoxEx = class(TListBox)
	private
		{ Private 宣言 }
    FTimer       : TTimer;
    FEnabled     : Boolean;
    FEdit        : TEdit;
    FClickIndex : Integer; // クリックした項目
    //FDrawed      : Boolean;            // True:描画中
    FOnEditOk    : TListBoxExEditOk;
    FOnEditNg    : TNotifyEvent;
    FOnEditStart : TListBoxExEditStart;
    FOnListClick : TNotifyEvent;
    FEditDisabled: Boolean;
    FPopMenu     : TPopupMenu;
    // 外部からの編集有効終了処理
    procedure EditOK();
    // 外部からの編集無効処理
    procedure EditNG();
    procedure OnSelfClick(Sender: TObject);
    procedure OnSelfDblClick(Sender: TObject);
    procedure OnEditExit(Sender: TObject);
    procedure OnEditKeyPress(Sender: TObject; var Key: Char);
    procedure OnTimer(Sender: TObject);
    procedure SetEditDisabled(const Value: Boolean);
    function GetItemTop() : Integer;
    function GetItemLeft() : Integer;
    function GetItemWidth() : Integer;
  protected
    procedure DoEditStart(var EditStr : string);virtual;
    procedure DoEditOk(const EditStr : string);virtual;
    procedure DoEditNg();virtual;
    procedure DoListClick();virtual;
  public
		{ Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    property EditDisabled : Boolean read FEditDisabled write SetEditDisabled;
    // 外部から編集開始状態に
    procedure EditStart();
    // 編集開始イベント
    property OnEditStart : TListBoxExEditStart read FOnEditStart write FOnEditStart;
    // 編集を有効にして終了するイベント
    property OnEditOk    : TListBoxExEditOk read FOnEditOk write FOnEditOk;
    // 編集を無効にして終了するイベント
    property OnEditNg    : TNotifyEvent read FOnEditNg write FOnEditNg;
    // リストクリックイベント
    property OnListClick : TNotifyEvent read FOnListClick write FOnListClick;
  published
    property OnDblClick;
  end;


//--------------------------------------------------------------------------//
//  行ごとに背景色を変えて見やすくしたリストコントロールクラス              //
//--------------------------------------------------------------------------//
type
  TListBoxExColor = class(TListBoxEx)
	private
		{ Private 宣言 }
    procedure OnListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;State: TOwnerDrawState);
  public
		{ Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;
  end;

type
  TCheckListBoxExColor = class(TCheckListBox)
	private
		{ Private 宣言 }
    procedure OnListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;State: TOwnerDrawState);
  public
		{ Public 宣言 }
    constructor Create(AOwner: TComponent); override;
  end;

// 背景塗りつぶしの描画代行のみ処理を外部からも使えるように
procedure ListBoxDrawRect(Canvas: TCanvas; Index: Integer; Rect: TRect;State: TOwnerDrawState);
    // 文字の描画代行
procedure ListBoxTextOut(Canvas: TCanvas;Rect: TRect;State: TOwnerDrawState;const str : string);overload;
procedure ListBoxTextOut(Canvas: TCanvas;const X,Y : Integer;State: TOwnerDrawState;const str : string);overload;


implementation

const
  COLOR_CURSOL = clNavy;


{ TTabControlEx }

constructor TListBoxEx.Create(AOwner: TComponent);
begin
  inherited;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 10;
  FTimer.Enabled := False;
  FTimer.OnTimer := OnTimer;

  ItemHeight := 24;
  ControlStyle := ControlStyle + [csClickEvents];
  OnDblClick := OnSelfDblClick;
  OnClick := OnSelfClick;

  FEdit := TEdit.Create(nil);
  FEdit.Parent := Self;
  FEdit.Visible := False;
  FEdit.OnExit := OnEditExit;
  FEdit.OnKeyPress := OnEditKeyPress;

end;

destructor TListBoxEx.Destroy;
begin
  EditNG();
  FTimer.OnTimer := nil;
  FTimer.Enabled := False;
  FTimer.Free;
  FEdit.OnExit := nil;
  FEdit.OnKeyPress := nil;
  FEdit.Visible := False;
  FEdit.Free;
  //if FEdit<> nil then FEdit.Free;
  inherited;
end;


procedure TListBoxEx.DoEditNg;
begin
  if Assigned(FOnEditNg) then begin
    FOnEditNg(Self);
  end;
end;

procedure TListBoxEx.DoEditOk(const EditStr: string);
begin
  if Assigned(FOnEditOk) then begin
    FOnEditOk(Self,EditStr);
  end;
end;

procedure TListBoxEx.DoEditStart(var EditStr: string);
begin
  if Assigned(FOnEditStart) then begin
    FOnEditStart(Self,EditStr);
  end;
end;

procedure TListBoxEx.DoListClick;
begin
  if Assigned(FOnListClick) then begin
    FOnListClick(Self);
  end;
end;

procedure TListBoxEx.EditNG;
begin
  if not Visible then exit;
  if not FEdit.Visible then exit;

  FEdit.Visible := False;
  PopupMenu := FPopMenu;
  //EditCtrl(False);
  DoEditNg();
  Self.SetFocus();
end;

procedure TListBoxEx.EditOK;
begin
  DoEditOk(FEdit.Text);
  FEdit.Visible := False;
  PopupMenu := FPopMenu;
  //EditCtrl(False);
  Self.SetFocus();
end;

procedure TListBoxEx.EditStart;
var
  str : string;
begin
  if FEdit<> nil then begin
    if FEdit.Visible then EditOk();        // 編集中の場合、編集結果を有効にしてから編集
  end;
  DoEditStart(str);
  FPopMenu := PopupMenu;
  Popupmenu := nil;
  //EditCtrl(True);
  if FEdit <> nil then begin
    FEdit.Left := GetItemLeft;
    FEdit.Top := GetItemTop;
    FEdit.Width := GetItemWidth;
  end;
  FEdit.Text := str;
  FEdit.BevelOuter := bvNone;
  FEdit.BevelInner := bvNone;
  FEdit.AutoSize := true;
  FEdit.SelectAll;
  FEdit.Visible := True;
  FEdit.SetFocus;
end;

function TListBoxEx.GetItemLeft: Integer;
var
  x : Integer;
begin
  if Columns = 0 then begin
    result := Left;
  end
  else begin
    x := ItemIndex mod Columns;
    result := x * GetItemWidth;
  end;
end;

function TListBoxEx.GetItemTop: Integer;
var
  y : Integer;
begin
  if Columns = 0 then begin
    y := ItemIndex;
  end
  else begin
    y := ItemIndex div Columns;
  end;
  result := (y -  TopIndex) * ItemHeight+1;  // 表示座標計算
end;

function TListBoxEx.GetItemWidth: Integer;
begin
  if Columns = 0 then begin
    result := Width;
  end
  else begin
    result := Width div Columns;
  end;
end;

procedure TListBoxEx.OnEditExit(Sender: TObject);
begin
//  if ItemIndex = FClickIndex then exit;
  EditNG();
end;

procedure TListBoxEx.OnEditKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    #$0d : begin
      EditOk();
      Key := #0;
    end;
    #$1b : begin
      EditNG();
      Key := #0;
    end;
  end;
end;

procedure TListBoxEx.OnSelfClick(Sender: TObject);
begin
//  if ItemIndex = FClickIndex then exit;
  if FEnabled then exit;
  FEnabled := True;
  FTimer.Enabled := True;
  EditNG();
  DoListClick();
end;


procedure TListBoxEx.OnSelfDblClick(Sender: TObject);
begin
  FClickIndex := ItemIndex;
  if not Assigned(FOnEditStart) then exit;

  if FEdit.Visible then exit;   // 編集中のダブルクリック 試しに無視
  if ItemIndex = -1 then exit;

  EditStart();
end;

procedure TListBoxEx.OnTimer(Sender: TObject);
begin
  FTimer.Enabled := False;
  FEnabled := False;
end;

procedure TListBoxEx.SetEditDisabled(const Value: Boolean);
begin
  FEditDisabled := Value;
  if Value then begin
    OnDblClick       := nil;
    //OnClick          := nil;
    FEdit.OnExit     := nil;
    FEdit.OnKeyPress := nil;
  end
  else begin
    OnDblClick       := OnSelfDblClick;
    //OnClick          := OnSelfClick;
    FEdit.OnExit     := OnEditExit;
    FEdit.OnKeyPress := OnEditKeyPress;
  end;
end;

{ TListBoxExColor }

constructor TListBoxExColor.Create(AOwner: TComponent);
begin
  inherited;
  OnDrawItem := OnListDrawItem;
  Style := lbOwnerDrawFixed;
end;

destructor TListBoxExColor.Destroy;
begin
  Style := lbStandard;
  OnDrawItem := nil;
  inherited;
end;

procedure TListBoxExColor.OnListDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  cv : TCanvas;
  s :string;
begin
  cv := Canvas;
  ListBoxDrawRect(cv,Index,Rect,State);
  s := Items.Strings[Index];
  cv.Brush.Style:= bsClear;
  ListBoxTextOut(cv,Rect,State,s);
end;

procedure ListBoxDrawRect(Canvas: TCanvas; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  cv : TCanvas;
  cF,cB : TColor;     // 通常時の文字色と背景色
begin
  cv := Canvas;
  if Index mod 2 = 0 then begin
    //cB := clWhite;
    cb := $00FFF0F0;
    cF := clBlack;
  end
  else begin
    //cB := clWebLightSkyBlue;
    cb := $00FFC0C0;
    cF := clBlack;
  end;
  if (odFocused in State) or (odSelected in State)  then begin
    //CB := clActiveCaption  ;
    CB := COLOR_CURSOL ;
    CF := clWhite;
  end;
  cv.Brush.Color:= cB;
  cv.Font.Color := cF;
  cv.FillRect(Rect);
end;

procedure ListBoxTextOut(Canvas: TCanvas;Rect: TRect;State: TOwnerDrawState; const str: string);
var
  cv : TCanvas;
begin
  cv := Canvas;
  if (odFocused in State) or (odSelected in State)  then begin
    Canvas.Brush.Color := COLOR_CURSOL ;
    Canvas.Font.Color  := clWhite;
  end;
  cv.TextRect(Rect,Rect.Left+5,Rect.Top+3,str);
end;

procedure ListBoxTextOut(Canvas: TCanvas;const X,Y : Integer;State: TOwnerDrawState;const str : string);overload;
var
  cv : TCanvas;
begin
  cv := Canvas;
  if (odFocused in State) or (odSelected in State)  then begin
    Canvas.Brush.Color := COLOR_CURSOL ;
    Canvas.Font.Color  := clWhite;
  end;
  cv.TextOut(x,y,str);
end;

{ TCheckListBoxExColor }

constructor TCheckListBoxExColor.Create(AOwner: TComponent);
begin
  inherited;
  OnDrawItem := OnListDrawItem;
  Style := lbOwnerDrawFixed;
end;

procedure TCheckListBoxExColor.OnListDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  cv : TCanvas;
  s :string;
begin
  cv := Canvas;
  ListBoxDrawRect(cv,Index,Rect,State);
  s := Items.Strings[Index];
  ListBoxTextOut(cv,Rect,State,s);
end;

end.
