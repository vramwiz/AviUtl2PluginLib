unit ListViewEditPluginDialog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  ListViewEx,ListViewEditPlugin,ListViewRTTIList, System.UITypes,
  SpeedButtonAviUtlStyle;

//--------------------------------------------------------------------------//
//  各ダイアログに対応する基本フレーム                                      //
//--------------------------------------------------------------------------//
type
  TFrameListViewEditPluginDialog = class(TFrame)
    DlgColor: TColorDialog;
    LBox: TListBox;
    DlgFont: TFontDialog;
    DlgOpen: TFileOpenDialog;
    procedure btnDialogClick(Sender: TObject);
    procedure LBoxDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
      State: TOwnerDrawState);
    procedure FrameResize(Sender: TObject);
  private
    { Private 宣言 }
    FOwner     : TObject;                          // TListViewEditDialogを逆参照
    FRows      : TListViewRowItem;
    FBtn       : TSpeedButtonAviUtlStyle;
    //FOnChange  : TNotifyEvent;
  protected
      //procedure DoChange();virtual;
    procedure OnButtonClick(Sender: TObject);
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Rows      : TListViewRowItem read FRows;
  end;

//--------------------------------------------------------------------------//
//  ダイアログ編集プラグイン基礎クラス                                      //
//--------------------------------------------------------------------------//
type
	TListViewEditPluginDialog = class(TListViewEditPlugin)
	private
		{ Private 宣言 }
    procedure OnEditExit(Sender: TObject);
    procedure OnEditKeyPress(Sender: TObject; var Key: Char);
  protected
    // ダイアログ用フレーム
    FFrame : TFrameListViewEditPluginDialog;
    procedure DoDraw(Canvas : TCanvas;r : TRect;dr : TListViewRowItem);override;
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
    procedure DoOpenDialog();virtual;abstract;
	public
		{ Public 宣言 }
    constructor Create(); override;
    destructor Destroy;override;

  end;

//--------------------------------------------------------------------------//
//  編集プラグイン TColorDialog                                             //
//--------------------------------------------------------------------------//
type
	TListViewEditPluginColorDialog = class(TListViewEditPluginDialog)
	private
		{ Private 宣言 }
    //function CalcDialogPos(const Dialog: TForm): TPoint;
    procedure OnEditKeyPress(Sender: TObject; var Key: Char);
    function GetColorDialog: TColorDialog;
  protected
    procedure DoDraw(Canvas : TCanvas;r : TRect;dr : TListViewRowItem);override;
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
    procedure DoOpenDialog();override;
	public
		{ Public 宣言 }
    constructor Create(); override;

    property ColorDialog : TColorDialog read GetColorDialog;
  end;


//--------------------------------------------------------------------------//
//  編集プラグイン TColorDialog                                             //
//--------------------------------------------------------------------------//
type
	TListViewEditPluginFontDialog = class(TListViewEditPluginDialog)
	private
		{ Private 宣言 }
    function GetFontDialog: TFontDialog;
  protected
    procedure DoDraw(Canvas : TCanvas;r : TRect;dr : TListViewRowItem);override;
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
    procedure DoOpenDialog();override;
	public
		{ Public 宣言 }
    property FontDialog :  TFontDialog read GetFontDialog;
  end;

//--------------------------------------------------------------------------//
//  編集プラグイン FileOpenDialog                                           //
//--------------------------------------------------------------------------//
type
	TListViewEditOpenFileDialog = class(TListViewEditPluginDialog)
	private
		{ Private 宣言 }
    function GetOpenDialog: TFileOpenDialog;
  protected
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
    procedure DoOpenDialog();override;
	public
		{ Public 宣言 }
    property OpenDialog : TFileOpenDialog read GetOpenDialog;
  end;

//--------------------------------------------------------------------------//
//  編集プラグイン FileOpenDialog                                           //
//--------------------------------------------------------------------------//
type
	TListViewEditOpenFolderDialog = class(TListViewEditPluginDialog)
	private
		{ Private 宣言 }
  protected
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
    procedure DoOpenDialog();override;
	public
		{ Public 宣言 }
  end;



var
  ListViewEditPluginColorDialogId      : Integer;              // TColorDialog編集プラグインID
  ListViewEditPluginFontDialogId       : Integer;              // TColorDialog編集プラグインID
  ListViewEditPluginOpenDialogId       : Integer;              // TOpenDialog編集プラグインID
  ListViewEditPluginOpenFolderDialogId : Integer;              // TOpenDialog編集プラグインID


// 色を示す表示を描画
procedure ListDrawColor(cv : TCanvas;Rect : TRect;aColor : TColor);


implementation

{$R *.dfm}

uses  ShlObj, ActiveX,ColorPickerDialog,ColorPickerDialogFrame,AviUtl2StyleColors;


constructor TFrameListViewEditPluginDialog.Create(AOwner: TComponent);
begin
  inherited;
  FBtn := TSpeedButtonAviUtlStyle.Create(Self);
  FBtn.Parent := Self;
  FBtn.Align := alLeft;
  FBtn.Width := 23;
  FBtn.Caption := '..';
  FBtn.OnClick := OnButtonClick;

  LBox.Color := A2SCListBoxBackground;
  LBox.Font.Color := A2SCListBoxText;
  LBox.Font.Height := -13;
  LBox.ItemHeight := 22;end;

destructor TFrameListViewEditPluginDialog.Destroy;
begin
  FBtn.Free;
  inherited;
end;

procedure TFrameListViewEditPluginDialog.FrameResize(Sender: TObject);
begin
  LBox.ItemHeight := Height;
end;

procedure ListDrawColor(cv : TCanvas;Rect : TRect;aColor : TColor);
var
  r : TRect;
  s : string;
  rgb,ir,ig,ib : Integer;
begin
  cv.Pen.Color := clWhite;
  cv.Brush.Color := aColor;
  r := Rect;
  r.Left := r.Left + 2;
  r.Top := r.Top + 2;
  r.Bottom := r.Top + 15;
  r.Width := 32;
  cv.Rectangle(r);

  rgb := ColorToRGB(aColor);
  ir := LOBYTE(LOWORD(rgb));
  ig := HIBYTE(LOWORD(rgb));
  ib := LOBYTE(HIWORD(rgb));
  s := Format('R%3.3d G%3.3d B%3.3d' ,[ir,ig,ib]);

  cv.Brush.Style := bsClear;
  cv.Brush.Color := A2SCListViewBackground;
  cv.Font.Color := A2SCListViewText;
  r := Rect;
  r.Left := r.Left + 40;
  r.Top := r.Top + 2;
  cv.TextRect(r,r.Left,r.Top,s);
end;

procedure ListDrawFont(cv : TCanvas;Rect : TRect;aFontName : string);
begin
  cv.Font.Name := aFontName;
  cv.TextRect(Rect,Rect.Left+2,Rect.Top+2,aFontName);  // 手動で描画
end;

procedure ListDraw(cv : TCanvas;Rect : TRect;aFontName : string);
begin
  cv.TextRect(Rect,Rect.Left+2,Rect.Top+2,aFontName);  // 手動で描画
end;


//--------------------------------------------------------------------------//
//  描画イベント                                                            //
//--------------------------------------------------------------------------//
procedure TFrameListViewEditPluginDialog.LBoxDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  TListViewEditPluginDialog(FOwner).DoDraw(LBox.Canvas,Rect,FRows);
end;


//--------------------------------------------------------------------------//
//  「..」クリックイベント                                                  //
//--------------------------------------------------------------------------//
procedure TFrameListViewEditPluginDialog.OnButtonClick(Sender: TObject);
begin
  TListViewEditPluginDialog(FOwner).DoOpenDialog();
end;

procedure TFrameListViewEditPluginDialog.btnDialogClick(Sender: TObject);
begin
  TListViewEditPluginDialog(FOwner).DoOpenDialog();
end;

{
function TListViewEditPluginColorDialog.CalcDialogPos(const Dialog: TForm): TPoint;
var
  P       : TPoint;
  Work    : TRect;
begin
  // 作業領域（タスクバー除外）
  Work := Screen.WorkAreaRect;

  // 基本位置：フレームの左下
  P := FFrame.ClientToScreen(Point(0, FFrame.Height));

  // --- 縦方向補正 ---
  // 下にはみ出る場合 → 上に出す
  if P.Y + Dialog.Height > Work.Bottom then
    P.Y := FFrame.ClientToScreen(Point(0, -Dialog.Height)).Y;

  // それでも上にはみ出る場合 → 作業領域上端へ
  if P.Y < Work.Top then
    P.Y := Work.Top;

  // --- 横方向補正 ---
  // 右にはみ出る場合 → 右端に寄せる
  if P.X + Dialog.Width > Work.Right then
    P.X := Work.Right - Dialog.Width;

  // 左にはみ出る場合 → 作業領域左端へ
  if P.X < Work.Left then
    P.X := Work.Left;

  Result := P;
end;
}


{ TListViewEditPluginColorDialog }

//--------------------------------------------------------------------------//
//  クラス生成                                                              //
//--------------------------------------------------------------------------//
constructor TListViewEditPluginColorDialog.Create;
begin
  inherited;
  FFrame.OnKeyPress := OnEditKeyPress;
  //FFrame.OnChange := OnChange;
end;

procedure TListViewEditPluginColorDialog.DoDraw(Canvas: TCanvas; r: TRect;dr: TListViewRowItem);
var
  c : TColor;
begin
  c := StrToIntDef(dr.Value,0);
  ListDrawColor(Canvas,r,c);
end;

//--------------------------------------------------------------------------//
//  編集開始                                                                //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginColorDialog.DoEditing(Parent : TWinControl;var Component : TWinControl;r: TRect; dr : TListViewRowItem);
begin
  inherited;
  FFrame.Color := StrToIntDef(dr.Value,0);
end;

procedure TListViewEditPluginColorDialog.DoOpenDialog;
var
  Frame : TFrameColorPickerDialog;
begin
  Frame := TFrameColorPickerDialog.Create(FFrame);
  try
    Frame.Color :=  StrToIntDef(FFrame.FRows.Value,0);
    //P := CalcDialogPos(Form);
    //Form.Left := P.X;
    //Form.Top  := P.Y;
    Frame.Parent := FFrame;
    FFrame.AutoSize := True;
    Frame.ShowColor;
    //if not Frame.Execute() then exit;
    //FFrame.Color := Form.Color;
    //DoEdited(IntToStr(FFrame.Color));                 // 編集完了イベント発生
  finally
    //FFrame.AutoSize := False;
    //Form.Free;
  end;
  //FFrame.Visible := False;                        // 非表示
end;
{
procedure TListViewEditPluginColorDialog.DoOpenDialog;
var
  Form : TFormColorPickerDialog;
  P: TPoint;
begin
  Form := TFormColorPickerDialog.Create(FFrame);
  try
    Form.Color :=  StrToIntDef(FFrame.FRows.Value,0);
    P := CalcDialogPos(Form);
    //Form.Left := P.X;
    //Form.Top  := P.Y;
    Form.Parent := FFrame;
    FFrame.AutoSize := True;
    if not Form.Execute() then exit;
    FFrame.Color := Form.Color;
    DoEdited(IntToStr(FFrame.Color));                 // 編集完了イベント発生
  finally
    FFrame.AutoSize := False;
    Form.Free;
  end;
  FFrame.Visible := False;                        // 非表示
end;

}

{
procedure TListViewEditPluginColorDialog.DoOpenDialog;
begin
  FFrame.DlgColor.Color := StrToIntDef(FFrame.FRows.Value,0);
  if not FFrame.DlgColor.Execute() then exit;
  FFrame.Color := FFrame.DlgColor.Color;
  //FFrame.DoChange();
  DoEdited(IntToStr(FFrame.Color));                 // 編集完了イベント発生
  FFrame.Visible := False;                        // 非表示
end;
}

function TListViewEditPluginColorDialog.GetColorDialog: TColorDialog;
begin
  result := FFrame.DlgColor;
end;

//--------------------------------------------------------------------------//
//  キー降下イベント                                                        //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginColorDialog.OnEditKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    #$0d : begin                            // エンターキー
      DoEdited(IntToStr(FFrame.Color));                 // 編集完了イベント発生
      FFrame.Visible := False;               // 非表示
      Key := #0;                            // キーを受け取り他で処理させない
    end;
    #$1b : begin                            // エスケープキー
      FFrame.Visible := False;               // 非表示
      DoEditCancel();                       // キャンセルイベント発生
      Key := #0;
    end;
  end;
end;

{ TListViewEditPluginDialog }

//--------------------------------------------------------------------------//
//  クラス生成                                                              //
//--------------------------------------------------------------------------//
constructor TListViewEditPluginDialog.Create;
begin
  inherited;
  FFrame := TFrameListViewEditPluginDialog.Create(nil);
  FFrame.FOwner := Self;
  FFrame.OnExit := OnEditExit;
  FFrame.OnKeyPress := OnEditKeyPress;
  //FFrame.OnChange := OnChange;
end;

//--------------------------------------------------------------------------//
//  クラス破棄                                                              //
//--------------------------------------------------------------------------//
destructor TListViewEditPluginDialog.Destroy;
begin

  inherited;
end;

//--------------------------------------------------------------------------//
//  描画イベント                                                            //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginDialog.DoDraw(Canvas: TCanvas; r: TRect;dr: TListViewRowItem);
begin
  Canvas.TextRect(r,r.Left+2,r.Top+2,dr.Value);  // 手動で描画
end;

//--------------------------------------------------------------------------//
//  編集開始                                                                //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginDialog.DoEditing(Parent: TWinControl;
  var Component: TWinControl;r: TRect;dr: TListViewRowItem);
begin
  Component      := FFrame;
  FFrame.Visible := False;
  FFrame.Parent  := Parent;
  FFrame.Left    := r.Left;
  FFrame.Top     := r.Top;
  FFrame.Width   := r.Width;
  FFrame.Height  := r.Height;
  FFrame.Anchors := [akLeft, akRight, akTop, akBottom];
  FFrame.BevelOuter := bvNone;
  FFrame.BevelInner := bvNone;
  FFrame.FRows   := dr;
  FFrame.Visible := True;
  SafeSetFocus(FFrame);
  if FFrame.LBox.Count = 0 then begin
    FFrame.LBox.Items.Add('');
  end;
  FFrame.LBox.Items.Strings[0] := '';
end;


//--------------------------------------------------------------------------//
//  フォーカス消失                                                          //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginDialog.OnEditExit(Sender: TObject);
begin
  FFrame.Visible := False;                   // 非表示
  DoEditCancel();                           // キャンセルイベント通知
end;

//--------------------------------------------------------------------------//
//  キー降下イベント                                                        //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginDialog.OnEditKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    #$0d : begin                            // エンターキー
      DoEdited(FFrame.FRows.Value);         // 編集完了イベント発生
      FFrame.Visible := False;              // 非表示
      Key := #0;                            // キーを受け取り他で処理させない
    end;
    #$1b : begin                            // エスケープキー
      FFrame.Visible := False;              // 非表示
      DoEditCancel();                       // キャンセルイベント発生
      Key := #0;
    end;
  end;
end;

{ TListViewEditPluginFontDialog }

procedure TListViewEditPluginFontDialog.DoDraw(Canvas: TCanvas; r: TRect;dr: TListViewRowItem);
begin
  Canvas.Font.Name := dr.Value;
  Canvas.TextRect(r,r.Left+2,r.Top+2,dr.Value);  // 手動で描画
end;

//--------------------------------------------------------------------------//
//  編集開始                                                                //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginFontDialog.DoEditing(Parent : TWinControl;var Component : TWinControl;r: TRect; dr : TListViewRowItem);
begin
  FFrame.Font.Name   := dr.Value;
  inherited;
  //FFrame.OnChange := OnChange;
end;


procedure TListViewEditPluginFontDialog.DoOpenDialog;
begin
  FFrame.DlgFont.Font.Name := FFrame.FRows.Value;
  if not FFrame.DlgFont.Execute() then exit;
  DoEdited(FFrame.DlgFont.Font.Name);             // 編集完了イベント発生
  FFrame.Visible := False;                        // 非表示
end;

function TListViewEditPluginFontDialog.GetFontDialog: TFontDialog;
begin
  result := FFrame.DlgFont;
end;

{ TListViewEditTypeEdit }

//--------------------------------------------------------------------------//
//  編集開始                                                                //
//--------------------------------------------------------------------------//
procedure TListViewEditOpenFileDialog.DoEditing(Parent : TWinControl;var Component : TWinControl;r: TRect; dr : TListViewRowItem);
begin
  inherited;
  FFrame.DlgOpen.FileName := ExtractFileName(dr.Value);
  FFrame.DlgOpen.DefaultFolder := ExtractFilePath(dr.Value);
  //FFrame.DlgOpen.FileName := dr.Value;
end;

procedure TListViewEditOpenFileDialog.DoOpenDialog;
begin
  FFrame.DlgOpen.Title := 'ファイルの選択';
  FFrame.DlgOpen.DefaultFolder := ExtractFilePath(FFrame.FRows.Value);
  FFrame.DlgOpen.FileName := ExtractFileName(FFrame.FRows.Value);
  FFrame.DlgOpen.FileName := '';
  FFrame.DlgOpen.FileName := ExtractFileName(FFrame.FRows.Value);
  if not FFrame.DlgOpen.Execute() then exit;
  DoEdited(FFrame.DlgOpen.FileName);              // 編集完了イベント発生
  FFrame.Visible := False;                        // 非表示
end;

function TListViewEditOpenFileDialog.GetOpenDialog: TFileOpenDialog;
begin
  result := FFrame.DlgOpen;
end;



{ TListViewEditOpenFolderDialog }

procedure TListViewEditOpenFolderDialog.DoEditing(Parent: TWinControl;
  var Component: TWinControl; r: TRect; dr: TListViewRowItem);
begin
  inherited;
  FFrame.DlgOpen.FileName := '';
  FFrame.DlgOpen.DefaultFolder := ExtractFilePath(dr.Value);

end;

procedure TListViewEditOpenFolderDialog.DoOpenDialog;
begin
  FFrame.DlgOpen.Options := FFrame.DlgOpen.Options + [TFileDialogOption.fdoPickFolders];
  FFrame.DlgOpen.DefaultFolder := ExtractFilePath(FFrame.DlgOpen.FileName);
  FFrame.DlgOpen.Title := '監視フォルダの選択';
  if not FFrame.DlgOpen.Execute() then exit;
  DoEdited(FFrame.DlgOpen.FileName);              // 編集完了イベント発生
  FFrame.Visible := False;                        // 非表示
end;

initialization

  ListViewEditPluginColorDialogId      := ListViewEditPlugins.RegisterPlugin(TListViewEditPluginColorDialog);
  ListViewEditPluginFontDialogId       := ListViewEditPlugins.RegisterPlugin(TListViewEditPluginFontDialog);
  ListViewEditPluginOpenDialogId       := ListViewEditPlugins.RegisterPlugin(TListViewEditOpenFileDialog);
  ListViewEditPluginOpenFolderDialogId := ListViewEditPlugins.RegisterPlugin(TListViewEditOpenFolderDialog);

finalization



end.

