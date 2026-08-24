unit ListViewEditPluginLib;
{
  ListViewEditPluginLib.pas
  ---------------------------------------------------------------------------
  ListViewEdit / ListViewRTTI 用の実用的なセル編集プラグイン群を定義するユニット。

  本ユニットでは、TListViewEditPlugin を継承した複数の具象プラグインを提供し、
  各セルに対して異なる編集スタイル（テキスト、選択式、読み取り専用など）を
  実際に実装するための基盤となります。

  含まれる主なクラス：

    - TListViewEditPluginEdit
        TEdit を使用した基本的な文字列編集プラグイン
        入力確定は OnEditExit や Enter キーで処理

    - TListViewEditPluginReadOnly
        編集コンポーネントを生成せず、セルを表示専用にするプラグイン

    - TListViewEditPluginCustomComboBox
        TComboBox を使用した選択式プラグイン
        高さ制御のためのサブクラス TListViewEditPluginComboBoxHeight を使用

  これらのプラグインは、ListView の各セルごとに動的に割り当てることで、
  柔軟で直感的な編集UIを構築することが可能です。
}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, System.Math,
  Vcl.Graphics,Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,Vcl.ExtCtrls,
  ShellApi,ShlObj,CommCtrl,Menus, ListViewEx,ListViewEditPlugin,ListViewRTTIList;

//--------------------------------------------------------------------------//
//  編集プラグイン TEdit                                                    //
//--------------------------------------------------------------------------//
type
	TListViewEditPluginEdit = class(TListViewEditPlugin)
	private
		{ Private 宣言 }
    FEdit : TEdit;                            // 編集用TEdit
    procedure OnEditExit(Sender: TObject);
    procedure OnEditKeyPress(Sender: TObject; var Key: Char);
  protected
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
	public
		{ Public 宣言 }
    constructor Create(); override;
    destructor Destroy;override;
  end;

//--------------------------------------------------------------------------//
//  編集しないプラグイン                                                    //
//--------------------------------------------------------------------------//
type
	TListViewEditPluginReadOnly = class(TListViewEditPlugin)
	private
		{ Private 宣言 }
  protected
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
	public
		{ Public 宣言 }
  end;

 // 高さを変えられるコンボボックス
type
  TListViewEditPluginComboBoxHeight = class(TComboBox)
  public
    procedure CreateParams(var Params: TCreateParams); override;
  end;

//--------------------------------------------------------------------------//
//  編集プラグイン TComboBox基礎クラス                                      //
//--------------------------------------------------------------------------//
type
	TListViewEditPluginCustomComboBox = class(TListViewEditPlugin)
	private
		{ Private 宣言 }
    procedure OnCBoxExit(Sender: TObject);
  protected
    FCBox : TListViewEditPluginComboBoxHeight;
    procedure SetComboBox(Parent : TWinControl;var Component : TWinControl;r : TRect;Items : TStringList;ItemIndex : Integer);
	public
		{ Public 宣言 }
    constructor Create(); override;
    destructor Destroy;override;
  end;

//--------------------------------------------------------------------------//
//  編集プラグイン TComboBox Boolean専用                                    //
//--------------------------------------------------------------------------//
type
	TListViewEditPluginBool = class(TListViewEditPluginCustomComboBox)
	private
		{ Private 宣言 }
    procedure OnCBoxChange(Sender: TObject);
  protected
    // 要素描画
    procedure DoDraw(Canvas : TCanvas;r : TRect;dr : TListViewRowItem);override;
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
	public
		{ Public 宣言 }
    constructor Create(); override;
  end;

//--------------------------------------------------------------------------//
//  編集プラグイン TComboBoxのStringsの値をそのまま文字列として使う         //
//--------------------------------------------------------------------------//
type
	TListViewEditPluginComboBoxStr = class(TListViewEditPluginCustomComboBox)
	private
		{ Private 宣言 }
    procedure OnCBoxChange(Sender: TObject);
  protected
    // 要素描画
    procedure DoDraw(Canvas : TCanvas;r : TRect;dr : TListViewRowItem);override;
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
	public
		{ Public 宣言 }
    constructor Create(); override;
  end;

//--------------------------------------------------------------------------//
//  編集プラグイン TComboBox                                                //
//--------------------------------------------------------------------------//
type
	TListViewEditPluginComboBox = class(TListViewEditPluginCustomComboBox)
	private
		{ Private 宣言 }
    procedure OnCBoxChange(Sender: TObject);
  protected
    // 要素描画
    procedure DoDraw(Canvas : TCanvas;r : TRect;dr : TListViewRowItem);override;
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
	public
		{ Public 宣言 }
    constructor Create(); override;
  end;

//--------------------------------------------------------------------------//
//  編集プラグイン TComboBox                                                //
//--------------------------------------------------------------------------//
type
  TListViewEditPluginComboBoxColor = class(TListViewEditPlugin)
  private
    { Private 宣言 }

    FCBox    : TListViewEditPluginComboBoxHeight; // 色選択用コンボボックス
    FEdit    : TEdit;                             // RGB手入力用エディット
    FStrings : TStringList;                       // 標準色・ユーザー色リスト

    // 色サンプルとRGB値を描画する共通処理
    procedure ListDrawColor(cv : TCanvas; Rect : TRect; aColor : TColor);
    // 編集完了／キャンセル後にコンボボックスへ戻す
    procedure SwitchToEdit;
    // 編集セッション終了処理（外部フォーカス喪失など）
    procedure SwitchToExit;
    // テキストを柔軟に解釈して色へ変換する
    function TryTextToColor(const S: string; out Color: TColor): Boolean;
    // コンボボックスのフォーカス喪失処理
    procedure OnCBoxExit(Sender: TObject);
    // コンボボックスの選択変更処理
    procedure OnCBoxChange(Sender: TObject);
    // コンボボックス項目のオーナードロー処理
    procedure OnCBoxDrawItem(Control: TWinControl; Index: Integer;Rect: TRect; State: TOwnerDrawState);
    // コンボボックスでのキー入力検出（Edit切替）
    procedure OnCBoxKeyDown(Sender: TObject; var Key: Word;Shift: TShiftState);
    // Editでのキー操作（Enter確定 / Escキャンセル）
    procedure OnEditKeyDown(Sender: TObject; var Key: Word;Shift: TShiftState);
    // Editのフォーカス喪失処理
    procedure OnEditExit(Sender: TObject);
    // コンボボックスを編集用コンポーネントとして配置
    procedure SetComboBox(Parent : TWinControl; var Component : TWinControl;r : TRect; Items : TStringList; ItemIndex : Integer);
    // Editを編集用コンポーネントとして配置
    procedure SetEdit(Parent : TWinControl; var Component : TWinControl;r : TRect; Text : string);
  protected
    // 要素描画
    procedure DoDraw(Canvas : TCanvas; r : TRect;dr : TListViewRowItem); override;
    // 編集開始時のUI決定処理
    procedure DoEditing(Parent : TWinControl; var Component : TWinControl;r : TRect; dr : TListViewRowItem); override;
  public
    { Public 宣言 }
    // 生成処理
    constructor Create(); override;
    // 破棄処理
    destructor Destroy; override;
  end;


//--------------------------------------------------------------------------//
//  編集プラグイン TComboBox  値は Items.Objectを採用する                   //
//--------------------------------------------------------------------------//
type
	TListViewEditPluginComboBoxObject = class(TListViewEditPluginCustomComboBox)
	private
		{ Private 宣言 }
    procedure OnCBoxChange(Sender: TObject);
  protected
    // 要素描画
    procedure DoDraw(Canvas : TCanvas;r : TRect;dr : TListViewRowItem);override;
    procedure DoEditing(Parent : TWinControl;var Component : TWinControl;r : TRect; dr : TListViewRowItem);override;
	public
		{ Public 宣言 }
    constructor Create(); override;
  end;

var
  ListViewEditPluginHideId           : Integer;                 // 要素非表示
  ListViewEditPluginReadOnlyId       : Integer;                 // 編集機能無し
  ListViewEditPluginEditId           : Integer;                 // TEdit編集プラグインID  ※たぶん0
  ListViewEditPluginBoolId           : Integer;                 // 真偽型を指定するときのID
  ListViewEditPluginComboBoxStrId    : Integer;                 // 文字列で管理するTComboBoxを指定するときのID
  ListViewEditPluginComboBoxId       : Integer;                 // 数値でTComboBoxを指定するときのID
  ListViewEditPluginComboBoxObjectId : Integer;                 // Objectを数値で管理するTComboBoxを指定するときのID
  ListViewEditPluginComboBoxColorId  : Integer;                 // 色を管理するTComboBoxを指定するときのID

implementation

uses AviUtl2StyleColors;
{ TListViewEditTypeEdit }

//--------------------------------------------------------------------------//
//  クラス生成                                                              //
//--------------------------------------------------------------------------//
constructor TListViewEditPluginEdit.Create;
begin
  inherited;
  FEdit := TEdit.Create(nil);
  FEdit.AutoSize := False;
  FEdit.Color := A2SCEditBackground;
  FEdit.Font.Color :=  A2SCEditText;
  FEdit.Font.Height := -13;

  FEdit.OnExit := OnEditExit;
  FEdit.OnKeyPress := OnEditKeyPress;
end;

//--------------------------------------------------------------------------//
//  クラス破棄                                                              //
//--------------------------------------------------------------------------//
destructor TListViewEditPluginEdit.Destroy;
begin
  if FEdit <> nil then FreeAndNil(FEdit);
  inherited;
end;

//--------------------------------------------------------------------------//
//  編集開始                                                                //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginEdit.DoEditing(Parent : TWinControl;var Component : TWinControl;r: TRect; dr : TListViewRowItem);
begin
  Component := FEdit;
  FEdit.Visible := False;
  FEdit.Parent := Parent;
  FEdit.Left    := r.Left;
  FEdit.Top     := r.Top;
  FEdit.Width   := r.Width;
  FEdit.Height  := r.Height;
  FEdit.Anchors := [akLeft, akRight, akTop, akBottom];
  FEdit.Text    :=  dr.Value;
  FEdit.BevelOuter := bvNone;
  FEdit.BevelInner := bvNone;
  FEdit.SelectAll;
  FEdit.Visible := True;
  //PostMessage(FEdit.Handle, WM_SETFOCUS, 0, 0);
  SafeSetFocus(FEdit);
end;

//--------------------------------------------------------------------------//
//  フォーカス消失                                                          //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginEdit.OnEditExit(Sender: TObject);
begin
  if Assigned(FEdit.Parent) and FEdit.Parent.HandleAllocated then
    PostMessage(FEdit.Parent.Handle, WM_SETFOCUS, 0, 0);
  FEdit.Visible := False;                   // 非表示
  DoEditCancel();                           // キャンセルイベント通知
end;

//--------------------------------------------------------------------------//
//  キー降下イベント                                                        //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginEdit.OnEditKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    #$0d : begin                            // エンターキー
      DoEdited(FEdit.Text);                 // 編集完了イベント発生
      FEdit.Visible := False;               // 非表示
      Key := #0;                            // キーを受け取り他で処理させない
    end;
    #$1b : begin                            // エスケープキー
      FEdit.Visible := False;               // 非表示
      DoEditCancel();                       // キャンセルイベント発生
      Key := #0;
    end;
  end;
end;


{ TListViewEditTypeCustomComboBox }

//--------------------------------------------------------------------------//
//  クラス生成                                                              //
//--------------------------------------------------------------------------//
constructor TListViewEditPluginCustomComboBox.Create;
begin
  inherited;
  FCBox := TListViewEditPluginComboBoxHeight.Create(nil);
  FCBox.Style := csDropDownList;
  FCBox.Color := A2SCComboBackground;
  FCBox.Font.Color := A2SCComboText;
  FCBox.Font.Height := -11;

  FCBox.OnExit := OnCBoxExit;
end;

//--------------------------------------------------------------------------//
//  クラス破棄                                                              //
//--------------------------------------------------------------------------//
destructor TListViewEditPluginCustomComboBox.Destroy;
begin
  FCBox.Free;
  inherited;
end;


//--------------------------------------------------------------------------//
//  フォーカス消失イベント                                                  //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginCustomComboBox.OnCBoxExit(Sender: TObject);
begin
  FCBox.Visible := False;                   // 非表示
  DoEditCancel();                           // キャンセルイベント発生
end;


//--------------------------------------------------------------------------//
//  TComboBox設定                                                           //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginCustomComboBox.SetComboBox(Parent: TWinControl;
  var Component: TWinControl; r: TRect;Items : TStringList;
  ItemIndex: Integer);
begin
  Component := FCBox;                       // 編集用コンポーネントとして登録
  FCBox.Parent := Parent;                   // ComboBoxを指定されたオブジェクトに配置

  FCBox.Items.BeginUpdate();
  FCBox.Left        := r.Left;              // 左側位置合わせ
  FCBox.Top         := r.Top;               // 上側位置合わせ
  FCBox.Width       := r.Width;             // 横幅位置合わせ
  FCBox.Height      := r.Height;            // 高さ位置合わせ
  FCBox.ItemHeight  := r.Height;            // 項目の高さ位置合わせ
  FCBox.Items.Assign(Items);                // 選択要素を登録
  FCBox.ItemIndex   := ItemIndex;           // 選択中とする要素指定
  FCBox.Visible     := True;                // 表示
  if not FCBox.DroppedDown then begin
    FCBox.DroppedDown := True;                // ドロップダウンリスト表示
  end;
  FCBox.Items.EndUpdate();
  SafeSetFocus(FCBox);                           // フォーカス状態とする

end;

{ TListViewEditTypeBool }

//--------------------------------------------------------------------------//
//  クラス生成                                                              //
//--------------------------------------------------------------------------//
constructor TListViewEditPluginBool.Create;
begin
  inherited;
  FCBox.OnChange := OnCBoxChange;
end;

//--------------------------------------------------------------------------//
//  描画イベント                                                           //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginBool.DoDraw(Canvas: TCanvas; r: TRect;dr : TListViewRowItem);
var
  s: string;
  i : Integer;
begin
  i := StrToIntDef(dr.Value,-1);            // 現在値を 0 1で取得
  if dr.Value = 'True' then i := 1;
  if dr.Value = 'False' then i := 0;

  s := '';

  if dr.Strings.Count = 2 then begin        // 項目リストに要素の指定がある場合
    if i <> -1 then begin
      s := dr.Strings[i];                     // 要素の表示を採用
    end;
  end
  else begin                                // 要素の指定がない場合
    if i = 0 then s := 'False';             // 0:false
    if i = 1 then s := 'True';              // 1:true
  end;
  Canvas.TextRect(r,r.Left+2,r.Top+2,s);    // 手動で描画
end;

//--------------------------------------------------------------------------//
//  編集開始                                                                //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginBool.DoEditing(Parent: TWinControl;var Component: TWinControl;r: TRect; dr : TListViewRowItem);
var
  i : Integer;
  ts : TStringList;
begin

  ts := TStringList.Create;
  try
    if dr.Strings.Count = 2 then begin        // 項目リストに要素の指定がある場合
      ts.Assign(dr.Strings);                  // 指定の要素を採用
    end
    else begin                                // 要素の指定がない場合
      ts.Add('False');                        // 0:false
      ts.Add('True');                         // 1:true
    end;

    i := StrToIntDef(dr.Value,0);             // true false状態を取得
    if SameText(dr.Value, 'True') then i := 1;
    if SameText(dr.Value, 'False') then i := 0;
    if i < 0 then i := 0;
    if i > 1 then i := 1;

    SetComboBox(Parent,Component,r,ts,i);     // ComboBox設定
  finally
    ts.Free;
  end;
end;

//--------------------------------------------------------------------------//
//  要素選択イベント                                                        //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginBool.OnCBoxChange(Sender: TObject);
var
  s : string;
begin
  s := IntToStr(FCBox.ItemIndex);           // 選択状態を文字で取得
  DoEdited(s);                              // 編集完了イベント発生
  FCBox.Visible := False;
end;


{ TComboBoxHeight }

procedure TListViewEditPluginComboBoxHeight.CreateParams(var Params: TCreateParams);
begin
  inherited;
  // デフォルトではCBS_DROPDOWNが設定されているはずなので
  // これにオーナー描画スタイルを追加する
  Params.Style := Params.Style or CBS_OWNERDRAWFIXED;
end;

{ TListViewEditPluginComboBoxStr }

constructor TListViewEditPluginComboBoxStr.Create;
begin
  inherited;
  FCBox.OnChange := OnCBoxChange;
end;

procedure TListViewEditPluginComboBoxStr.DoDraw(Canvas: TCanvas; r: TRect;dr: TListViewRowItem);
var
  s: string;
//  i : Integer;
begin
{
  i := dr.Strings.IndexOf(dr.Value);        // リスト位置を取得
  if i < 0 then begin
    s := FCBox.Font.Name;
    i := dr.Strings.IndexOf(dr.Value);      // リスト位置を取得
    if i = -1 then i := 0;
  end;
  if i > dr.Strings.Count-1 then exit;
  s := dr.Strings[i];                       // 要素の表示を採用
  }
  s := dr.Value;
  Canvas.TextRect(r,r.Left+2,r.Top+2,s);    // 手動で描画
end;

procedure TListViewEditPluginComboBoxStr.DoEditing(Parent: TWinControl;
  var Component: TWinControl; r: TRect; dr: TListViewRowItem);
var
  i : Integer;
  s: string;
begin
  i := dr.Strings.IndexOf(dr.Value);        // リスト位置を取得
  if i < 0 then begin
    s := FCBox.Font.Name;
    i := dr.Strings.IndexOf(dr.Value);      // リスト位置を取得
    if i = -1 then i := 0;
  end;
  if i > dr.Strings.Count-1 then exit;
  s := dr.Strings[i];                       // 要素の表示を採用
  if i > dr.Strings.Count-1 then i := -1;

  SetComboBox(Parent,Component,r,dr.Strings,i);
end;

procedure TListViewEditPluginComboBoxStr.OnCBoxChange(Sender: TObject);
var
  s : string;
  i : Integer;
begin
  i := FCBox.ItemIndex;
  if i = -1 then Exit;
  s := FCBox.Items.Strings[i];
  DoEdited(s);
end;


{ TListViewEditTypeComboBox }

constructor TListViewEditPluginComboBox.Create;
begin
  inherited;
  FCBox.OnChange := OnCBoxChange;
end;

//--------------------------------------------------------------------------//
//  描画イベント                                                           //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBox.DoDraw(Canvas: TCanvas; r: TRect; dr: TListViewRowItem);
var
  s: string;
  i : Integer;
begin
  i := StrToIntDef(dr.Value,-1);            // 現在値を 0 1で取得
  if i < 0 then exit;
  if i > dr.Strings.Count-1 then exit;
  s := dr.Strings[i];                     // 要素の表示を採用
  Canvas.TextRect(r,r.Left+2,r.Top+2,s);    // 手動で描画

end;

//--------------------------------------------------------------------------//
//  編集開始                                                                //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBox.DoEditing(Parent: TWinControl;
  var Component: TWinControl;r: TRect;dr: TListViewRowItem);
var
  i : Integer;
begin
  i := StrToIntDef(dr.Value,0);             // 状態を取得
  if i > dr.Strings.Count-1 then i := -1;

  SetComboBox(Parent,Component,r,dr.Strings,i);
end;

//--------------------------------------------------------------------------//
//  要素選択イベント                                                        //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBox.OnCBoxChange(Sender: TObject);
var
  s : string;
begin
  s := IntToStr(FCBox.ItemIndex);           // 選択状態を文字で取得
  DoEdited(s);                              // 編集完了イベント発生
end;


{ TListViewEditTypeComboBoxObject }

constructor TListViewEditPluginComboBoxObject.Create;
begin
  inherited;
  FCBox.OnChange := OnCBoxChange;
end;

//--------------------------------------------------------------------------//
//  描画イベント                                                           //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBoxObject.DoDraw(Canvas: TCanvas; r: TRect; dr: TListViewRowItem);
var
  s: string;
  i,v : Integer;
begin
  v := StrToIntDef(dr.Value,-1);             // 現在値を取得
  i := dr.Strings.IndexOfObject(TObject(v)); // リストの値から検索
  if i = -1 then exit;
  if i > dr.Strings.Count-1 then exit;
  s := dr.Strings[i];                        // 要素の表示を採用
  Canvas.TextRect(r,r.Left+2,r.Top+2,s);     // 手動で描画
end;

//--------------------------------------------------------------------------//
//  編集開始                                                                //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBoxObject.DoEditing(Parent: TWinControl;
  var Component: TWinControl;r: TRect;dr: TListViewRowItem);
var
  i,v : Integer;
begin
  v := StrToIntDef(dr.Value,0);             // 状態を取得
  i := dr.Strings.IndexOfObject(TObject(v)); // リストの値から検索
  SetComboBox(Parent,Component,r,dr.Strings,i);
end;

//--------------------------------------------------------------------------//
//  要素選択イベント                                                        //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBoxObject.OnCBoxChange(Sender: TObject);
var
  s : string;
  i,v : Integer;
begin
  i := FCBox.ItemIndex;
  v := Integer(FCBox.Items.Objects[i]);     // 選択アイテムのオブジェクト取得
  s := IntToStr(v);                         // オブジェクトを文字化
  DoEdited(s);                              // 編集完了イベント発生
end;

{ TListViewEditTypeEditNo }

procedure TListViewEditPluginReadOnly.DoEditing(Parent: TWinControl;
  var Component: TWinControl;r: TRect;dr: TListViewRowItem);
begin

end;

{ TListViewEditPluginComboBoxColor }

constructor TListViewEditPluginComboBoxColor.Create;
begin
  inherited;
  FStrings := TStringList.Create;
  FCBox := TListViewEditPluginComboBoxHeight.Create(nil);
  FCBox.Style      := csOwnerDrawFixed;
  FCBox.OnDrawItem := OnCBoxDrawItem;
  FCBox.OnChange := OnCBoxChange;
  FCBox.OnKeyDown := OnCBoxKeyDown;
  FCBox.Color := A2SCComboBackground;
  FCBox.Font.Color := A2SCComboText;
  FCBox.Font.Height := -12;

  // --- RGB入力用 Edit ---
  FEdit := TEdit.Create(nil);
  FEdit.Visible := False;          // 編集開始時のみ表示
  FEdit.AutoSize := False;         // TEdit は既定だとフォント高さへ戻る
  FEdit.BorderStyle := bsSingle;   // 通常の入力欄
  FEdit.AutoSelect := True;        // フォーカス時に全選択
  FEdit.TextHint := 'R,G,B または #RRGGBB';
  FEdit.Color := A2SCEditBackground;
  FEdit.Font.Color :=  A2SCEditText;
  FEdit.Font.Height := -13;

  // 使用イベント
  FEdit.OnKeyDown := OnEditKeyDown;
  FEdit.OnExit    := OnEditExit;

  FStrings.AddObject('', Pointer(clBlack));
  FStrings.AddObject('', Pointer(clRed));
  FStrings.AddObject('', Pointer(clLime));
  FStrings.AddObject('', Pointer(clYellow));
  FStrings.AddObject('', Pointer(clBlue));
  FStrings.AddObject('', Pointer(clFuchsia));
  FStrings.AddObject('', Pointer(clAqua));
  FStrings.AddObject('', Pointer(clSilver));
  FStrings.AddObject('', Pointer(clWhite));

  FStrings.AddObject('', Pointer(clMaroon));
  FStrings.AddObject('', Pointer(clGreen));
  FStrings.AddObject('', Pointer(clOlive));
  FStrings.AddObject('', Pointer(clNavy));
  FStrings.AddObject('', Pointer(clPurple));
  FStrings.AddObject('', Pointer(clTeal));
  FStrings.AddObject('', Pointer(clGray));


end;

destructor TListViewEditPluginComboBoxColor.Destroy;
begin
  FEdit.Free;
  FCBox.Free;
  FStrings.Free;
  inherited;
end;

//--------------------------------------------------------------------------//
//  描画イベント                                                           //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBoxColor.DoDraw(
  Canvas: TCanvas; r: TRect; dr: TListViewRowItem);
var
  c : TColor;
begin
  c := StrToIntDef(dr.Value, 0);
  ListDrawColor(Canvas, r, c);
end;

//--------------------------------------------------------------------------//
//  編集開始                                                                //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBoxColor.DoEditing(Parent: TWinControl;
  var Component: TWinControl; r: TRect; dr: TListViewRowItem);
var
  i,v : Integer;
begin
  v := StrToIntDef(dr.Value,0);                // 状態を取得
  i := dr.Strings.IndexOfObject(TObject(v));   // リストの値から検索
  if dr.Strings.Count = 0 then begin
    dr.Strings.Assign(FStrings);
  end;

  SetComboBox(Parent,Component,r,dr.Strings,i);
end;

procedure TListViewEditPluginComboBoxColor.ListDrawColor(
  cv: TCanvas; Rect: TRect; aColor: TColor);
var
  r   : TRect;
  s   : string;
  rgb : Integer;
  ir, ig, ib : Integer;
begin
  // --- 色サンプル ---
  cv.Pen.Color := clWhite;
  cv.Brush.Color := aColor;

  r := Rect;
  r.Left   := r.Left + 2;
  r.Top    := r.Top + 2;
  r.Right  := r.Left + 32;
  r.Bottom := r.Top + 15;

  cv.Rectangle(r);

  // --- RGB 文字列生成 ---
  rgb := ColorToRGB(aColor);
  ir  := LOBYTE(LOWORD(rgb));
  ig  := HIBYTE(LOWORD(rgb));
  ib  := LOBYTE(HIWORD(rgb));

  s := Format('R%3.3d G%3.3d B%3.3d', [ir, ig, ib]);

  // --- 文字描画 ---
  cv.Brush.Style := bsClear;
  cv.Font.Color  := A2SCListViewText;

  r := Rect;
  r.Left := Rect.Left + 40;
  r.Top  := Rect.Top + 2;

  cv.TextRect(r, r.Left, r.Top, s);
end;


//--------------------------------------------------------------------------//
//  要素選択イベント                                                        //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBoxColor.OnCBoxChange(Sender: TObject);
var
  s : string;
  i,v : Integer;
begin
  i := FCBox.ItemIndex;
  v := Integer(FCBox.Items.Objects[i]);     // 選択アイテムのオブジェクト取得
  s := IntToStr(v);                         // オブジェクトを文字化
  DoEdited(s);                              // 編集完了イベント発生
end;

//--------------------------------------------------------------------------//
//  選択リスト描画イベント                                                  //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBoxColor.OnCBoxDrawItem(
  Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  CBox : TComboBox;
  c    : TColor;
begin
  CBox := TComboBox(Control);

  // --- インデックス範囲チェック ---
  if (Index < 0) or (Index >= CBox.Items.Count) then
    Exit;

  // --- 背景描画（選択状態考慮） ---
  if odSelected in State then begin
    CBox.Canvas.Brush.Color := clHighlight;
    CBox.Canvas.Font.Color  := clHighlightText;
  end
  else begin
    CBox.Canvas.Brush.Color := CBox.Color;
    CBox.Canvas.Font.Color  := CBox.Font.Color;
  end;
  CBox.Canvas.FillRect(Rect);

  // --- 色取得（nil ガード） ---
  if CBox.Items.Objects[Index] <> nil then
    c := TColor(CBox.Items.Objects[Index])
  else
    c := clBlack;

  // --- 共通描画処理に委譲 ---
  ListDrawColor(CBox.Canvas, Rect, c);
end;


//--------------------------------------------------------------------------//
//  フォーカス消失イベント                                                  //
//--------------------------------------------------------------------------//
procedure TListViewEditPluginComboBoxColor.OnCBoxExit(Sender: TObject);
begin
  FCBox.Visible := False;                   // 非表示
  FEdit.Visible := False;
  DoEditCancel();                           // キャンセルイベント発生
end;

procedure TListViewEditPluginComboBoxColor.OnCBoxKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  r : TRect;
  ch : Char;
begin
  // --------------------------------------------------
  // ComboBox 本来の操作に使うキーは通す
  // --------------------------------------------------
  case Key of
    VK_UP, VK_DOWN,
    VK_LEFT, VK_RIGHT,
    VK_HOME, VK_END,
    VK_PRIOR, VK_NEXT,
    VK_ESCAPE,VK_RETURN: Exit;
  end;

  // --------------------------------------------------
  // Edit へ切り替え
  // --------------------------------------------------
  r := FCBox.BoundsRect;

  SetEdit(FCBox.Parent, TWinControl(FCBox), r, '');

  // --------------------------------------------------
  // 押されたキーを Edit に引き継ぐ
  // --------------------------------------------------
  if (Key >= Ord(' ')) and (Key <= $FF) then
  begin
    ch := Char(Key);
    FEdit.Text := ch;
    FEdit.SelStart := Length(FEdit.Text);
  end;

  // ComboBox 側でこれ以上処理させない
  Key := 0;
end;


procedure TListViewEditPluginComboBoxColor.OnEditExit(Sender: TObject);
begin
  SwitchToEdit;
end;

procedure TListViewEditPluginComboBoxColor.OnEditKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  Color : TColor;
begin
  case Key of
    VK_RETURN:
      begin
        // Enter : 決定
        // 文字列 → 色変換（拡張用 private 関数）
        if TryTextToColor(FEdit.Text, Color) then
        begin
          // 値を確定（既存フローに合流）
          DoEdited(IntToStr(Color));
        end
        else
        begin
          // 変換失敗時はキャンセル扱い
          DoEditCancel;
        end;

        // ComboBox に戻す
        SwitchToExit;

        Key := 0; // これ以上処理させない
      end;

    VK_ESCAPE:
      begin
        // Esc : キャンセル
        DoEditCancel;
        SwitchToExit;

        Key := 0; // これ以上処理させない
      end;
  end;
end;


procedure TListViewEditPluginComboBoxColor.SetComboBox(Parent: TWinControl;
  var Component: TWinControl; r: TRect; Items: TStringList; ItemIndex: Integer);
begin
  Component := FCBox;                       // 編集用コンポーネントとして登録
  FCBox.Parent := Parent;                   // ComboBoxを指定されたオブジェクトに配置

  FCBox.Items.BeginUpdate();
  FCBox.Left        := r.Left;              // 左側位置合わせ
  FCBox.Top         := r.Top;               // 上側位置合わせ
  FCBox.Width       := r.Width;             // 横幅位置合わせ
  FCBox.Height      := r.Height;            // 高さ位置合わせ
  FCBox.ItemHeight  := r.Height;            // 項目の高さ位置合わせ
  FCBox.Items.Assign(Items);                // 選択要素を登録
  FCBox.ItemIndex   := ItemIndex;           // 選択中とする要素指定
  FCBox.Visible     := True;                // 表示
  if not FCBox.DroppedDown then begin
    FCBox.DroppedDown := True;                // ドロップダウンリスト表示
  end;
  FCBox.Items.EndUpdate();
  SafeSetFocus(FCBox);                           // フォーカス状態とする
  FCBox.OnExit := OnCBoxExit;
end;

procedure TListViewEditPluginComboBoxColor.SetEdit(Parent: TWinControl;
  var Component: TWinControl; r: TRect; Text: string);
begin
  FCBox.OnExit := nil;
  Component := FEdit;                       // 編集用コンポーネントとして登録
  FEdit.Visible := False;
  FEdit.Parent := Parent;
  FEdit.Left    := r.Left;
  FEdit.Top     := r.Top;
  FEdit.Width   := r.Width;
  FEdit.Height  := r.Height;
  FEdit.Anchors := [akLeft, akTop];
  FEdit.Text    :=  Text;
  FEdit.BevelOuter := bvNone;
  FEdit.BevelInner := bvNone;
  FEdit.SelectAll;
  FEdit.Visible := True;
  //PostMessage(FEdit.Handle, WM_SETFOCUS, 0, 0);
  SafeSetFocus(FEdit);
end;

procedure TListViewEditPluginComboBoxColor.SwitchToEdit;
begin
  FEdit.Visible := False;
  FCBox.OnExit := OnCBoxExit;
  FCBox.Visible := True;
  SafeSetFocus(FCBox);                           // フォーカス状態とする
end;

procedure TListViewEditPluginComboBoxColor.SwitchToExit;
begin
  FEdit.Visible := False;
  FCBox.Visible := False;
end;

function IsAllDigits(const S: string): Boolean;
var
  C: Char;
begin
  Result := S <> '';
  for C in S do
    if not CharInSet(C, ['0'..'9']) then
      Exit(False);
end;

function TListViewEditPluginComboBoxColor.TryTextToColor(
  const S: string; out Color: TColor): Boolean;
var
  T    : string;
  Parts: TArray<string>;
  R,G,B: Integer;
begin
  Result := False;
  T := Trim(S);
  if T = '' then Exit;

  // ---------------------------------------------
  // カンマ or 空白区切り (255,255,255 / 255 255 255)
  // ---------------------------------------------
  if (Pos(',', T) > 0) or (Pos(' ', T) > 0) then
  begin
    T := StringReplace(T, ',', ' ', [rfReplaceAll]);
    Parts := T.Split([' '], TStringSplitOptions.ExcludeEmpty);

    if Length(Parts) = 3 then
    begin
      if TryStrToInt(Parts[0], R) and
         TryStrToInt(Parts[1], G) and
         TryStrToInt(Parts[2], B) and
         (R >= 0) and (R <= 255) and
         (G >= 0) and (G <= 255) and
         (B >= 0) and (B <= 255) then
      begin
        Color := RGB(R, G, B);
        Exit(True);
      end;
    end;
  end;

  // ---------------------------------------------
  // 連結数字 (255255255)
  // ---------------------------------------------
  if (Length(T) = 9) and IsAllDigits(T) then
  begin
    if TryStrToInt(Copy(T, 1, 3), R) and
       TryStrToInt(Copy(T, 4, 3), G) and
       TryStrToInt(Copy(T, 7, 3), B) and
       (R >= 0) and (R <= 255) and
       (G >= 0) and (G <= 255) and
       (B >= 0) and (B <= 255) then
    begin
      Color := RGB(R, G, B);
      Exit(True);
    end;
  end;
end;



initialization
  ListViewEditPlugins := TListViewEditPluginList.Create;

  ListViewEditPluginHideId           :=   ListViewEditPlugins.RegisterPlugin(TListViewEditPluginEdit);
  ListViewEditPluginReadOnlyId       := ListViewEditPlugins.RegisterPlugin(TListViewEditPluginReadOnly);
  ListViewEditPluginEditId           := ListViewEditPlugins.RegisterPlugin(TListViewEditPluginEdit);
  ListViewEditPluginBoolId           := ListViewEditPlugins.RegisterPlugin(TListViewEditPluginBool);
  ListViewEditPluginComboBoxStrId    := ListViewEditPlugins.RegisterPlugin(TListViewEditPluginComboBoxStr);
  ListViewEditPluginComboBoxId       := ListViewEditPlugins.RegisterPlugin(TListViewEditPluginComboBox);
  ListViewEditPluginComboBoxObjectId := ListViewEditPlugins.RegisterPlugin(TListViewEditPluginComboBoxObject);
  ListViewEditPluginComboBoxColorId  := ListViewEditPlugins.RegisterPlugin(TListViewEditPluginComboBoxColor);


finalization
  ListViewEditPlugins.Free;

end.


