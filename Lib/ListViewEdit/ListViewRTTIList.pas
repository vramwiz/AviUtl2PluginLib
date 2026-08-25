unit ListViewRTTIList;
interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus,Vcl.StdCtrls,Vcl.ComCtrls,
  System.TypInfo,ListViewEx,System.Generics.Collections;


type
  TListViewRowItem = class(TPersistent)
  private
    { Private 宣言 }
    FCaption   : string;                         // 値の名称
    FEditType  : Integer;                        // 編集方法
    FValue     : string;                         // 値
    FHint      : string;                         // ヒント
    FPName     : string;                         // プロパティ名
    FStrings   : TStringList;                    // 選択リストに使用する値
    FColorBack : TColor;                         // 背景色
    FColorFont : TColor;                         // 文字色
    FData: Pointer;                              // ListItemのData
    //FWidth     : Integer;                        // 列の横幅※横方向編集画面で使用

  protected
  public
    { Public 宣言 }
    constructor Create();
    destructor Destroy;override;

    // 変数名に該当する設定名ヒント編集方法を割り当てる
    procedure AddCaption(Caption, Hint: string;aColor : TColor = clBtnFace;aType : Integer = 2);overload;


    property PName   : string read FPName write FPName;
    property Caption : string read FCaption write FCaption;
    property Hint    : string read FHint    write FHint;
    property Value   : string read FValue write FValue;
    property Data    : Pointer read FData write FData;

    property EditType  : Integer read FEditType write FEditType;

    property ColorFont : TColor read FColorFont write FColorFont;
    property ColorBack : TColor read FColorBack write FColorBack;

    property Strings  : TStringList read FStrings;

  end;

type
	TListViewRowList =  class(TObjectList<TListViewRowItem>)
	private
		{ Private 宣言 }
    function GetRows(Index: Integer): TListViewRowItem;
    function GetPName(PName: string): TListViewRowItem;
	public
		{ Public 宣言 }
    destructor Destroy;override;

    // 要素追加
    function AddNew: TListViewRowItem;
    function IndexOfPName(const PName : string) : Integer;

		property Rows[Index: Integer] : TListViewRowItem read GetRows ;default;
    property PNames[PName : string] : TListViewRowItem read GetPName;

	end;

//--------------------------------------------------------------------------//
//  非表示の行の換算クラス                                                  //
//--------------------------------------------------------------------------//
type
	TListViewRowListEx = class(TList)
	private
		{ Private 宣言 }
    function GetRows(Index: Integer): Integer;
	public
		{ Public 宣言 }

    procedure Add(const Row : Integer);
    function IndexOf(const Row : Integer) : Integer;
		property Rows[Index: Integer] : Integer read GetRows ;default;
  end;


implementation

uses ListViewEditPlugin,ListViewEditPluginLib;


{ TConfigRTTIListViewItem }

destructor TListViewRowList.Destroy;
begin
  Clear();
  inherited;
end;

function TListViewRowList.AddNew: TListViewRowItem;
var
  Item: TListViewRowItem;
begin
  Item := TListViewRowItem.Create;
  Add(Item);
  Result := Item;
end;

function TListViewRowList.GetRows(Index: Integer): TListViewRowItem;
begin
  result := inherited Items[Index];
end;

function TListViewRowList.GetPName(PName: string): TListViewRowItem;
var
  i : Integer;
  dr : TListViewRowItem;
begin
  i := IndexOfPName(PName);
  if i <> -1 then begin
    result := Items[i];
    exit;
  end;
  dr := AddNew();
  dr.FPName := PName;
  result := dr;
end;


function TListViewRowList.IndexOfPName(const PName: string): Integer;
var
  i : Integer;
begin
  result := -1;
  for i := 0 to Count-1 do begin
    if Items[i].FPName = PName then Exit(i)
  end;
end;


{ TListViewRowItem }


procedure TListViewRowItem.AddCaption(Caption, Hint: string;aColor : TColor = clBtnFace;aType : Integer = 2);
begin
  FCaption := Caption;
  FHint := '';
  FEditType := aType;
  FColorBack := aColor;
end;

constructor TListViewRowItem.Create;
begin
  FStrings := TStringList.Create;
  FColorFont := clBlack;
  FColorBack := clBtnFace;
  FEditType := ListViewEditPluginEditId;
end;

destructor TListViewRowItem.Destroy;
begin
  FStrings.Free;
  inherited;
end;


{ TListViewRowListEx }

procedure TListViewRowListEx.Add(const Row: Integer);
begin
  inherited Add(Pointer(Row));
end;

function TListViewRowListEx.GetRows(Index: Integer): Integer;
begin
  result := Integer(inherited Items[Index]);
end;

function TListViewRowListEx.IndexOf(const Row: Integer): Integer;
var
  i: Integer;
begin
  result := -1;
  for i := 0 to Count-1 do begin
    if Rows[i] = Row then Exit(i);
  end;
end;

end.
