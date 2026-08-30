unit PluginFilterTable;

interface

uses
  Winapi.Windows,System.SysUtils, AviUtl2FilterTypes,Vcl.Graphics;


procedure SetupPluginTable(Flag : Integer;Name : PWideChar;Label_  : PWideChar;
                           Information : PWideChar;VideoProc  : TFuncProcVideo;AudioProc  : TFuncProcAudio);

procedure AddFile(var Item: TFILTER_ITEM_FILE;Name: PWideChar;Value: PWideChar;FileFilter : PWideChar);
procedure AddButton(var Item : TFILTER_ITEM_BUTTON;Name : PWideChar;Callback : TFILTER_ITEM_BUTTON_CALLBACK);
procedure AddString(var Item  : TFILTER_ITEM_STRING;Name  : PWideChar;Value : PWideChar);
procedure AddColor(var Item  : TFILTER_ITEM_COLOR;Name  : PWideChar;Color : TColor;Alpha : Byte = 255);
procedure AddTrack(var Item  : TFILTER_ITEM_TRACK;Name: PWideChar;Value : Double;S : Double;E : Double;Step : Double);
procedure AddCheck(var Item : TFILTER_ITEM_CHECK;Name : PWideChar;Value : Integer);
procedure AddText(var Item : TFILTER_ITEM_TEXT;Name     : PWideChar;const Value : WideString);
procedure AddData(var Item : TFILTER_ITEM_DATA;Name     : PWideChar;Buffer   : PWideChar;Size     : Integer);
procedure AddSelect(var Item : TFILTER_ITEM_SELECT;Name : LPCWSTR;Value : Integer;List  : Pointer);
procedure AddGroup(var Item : TFILTER_ITEM_GROUP;Name     : PWideChar;DefaultVisible : Integer);

// Select 用リスト操作
procedure ClearSelectList;
procedure AddSelectList(var List : array of TFILTER_ITEM_SELECT_ITEM;Name: PWideChar; Value: Integer);

procedure GetData(const Item : TFILTER_ITEM_DATA;out Buffer  : PWideChar;out Size : Integer);
procedure SetData(var Item : TFILTER_ITEM_DATA;Buffer : PWideChar;Size : Integer);



function GetColor(const Item: TFILTER_ITEM_COLOR): TColor;
procedure SetColor(var Item  : TFILTER_ITEM_COLOR;Color : TColor;Alpha : PByte = nil);

var
  GTable: TFILTER_PLUGIN_TABLE;

implementation


const
  MAX_GUI_ITEMS = 100;  // 0..99

type
  TGuiItemIndex = 0..(MAX_GUI_ITEMS - 1);
var
  FItemIndex : Integer;                              // 登録数兼インデックス
  Items      : array[TGuiItemIndex] of Pointer;      // AviUtl2 用 GUI Items

var
  FSelectIndex : Integer;   // 現在の登録数（= 次に Add される位置）

procedure SetupPluginTable(Flag : Integer;Name : PWideChar;Label_  : PWideChar;
                           Information : PWideChar;VideoProc  : TFuncProcVideo;AudioProc  : TFuncProcAudio);
begin
  // 基本情報
  GTable.Flag        := Flag;
  GTable.Name        := Name;
  GTable.Label_      := Label_;
  GTable.Information := Information;

  // GUI Items（このユニットで管理している配列）
  GTable.Items := @Items[0];

  // コールバック
  GTable.Func_Proc_Video := VideoProc;
  GTable.Func_Proc_Audio := AudioProc;
end;

procedure AddFile(var Item: TFILTER_ITEM_FILE;Name: PWideChar;Value: PWideChar;FileFilter : PWideChar);
begin
  Items[FItemIndex] := @Item;

  Item.ItemType := 'file';
  Item.Name  := Name;
  Item.Value := Value;
  Item.FileFilter := FileFilter;

  Inc(FItemIndex);
end;

procedure AddButton(var Item : TFILTER_ITEM_BUTTON;Name : PWideChar;Callback : TFILTER_ITEM_BUTTON_CALLBACK);
begin
  Items[FItemIndex] := @Item;

  Item.ItemType := 'button';
  Item.Name     := Name;
  Item.Callback := Callback;

  Inc(FItemIndex);
end;

procedure AddString(var Item  : TFILTER_ITEM_STRING;Name  : PWideChar;Value : PWideChar);
begin
  Items[FItemIndex] := @Item;

  Item.ItemType := 'string';
  Item.Name     := Name;
  Item.Value    := Value;

  Inc(FItemIndex);
end;

procedure AddColor(var Item  : TFILTER_ITEM_COLOR;Name  : PWideChar;Color : TColor;Alpha : Byte);
var
  c: TColor;
begin
  Items[FItemIndex] := @Item;

  Item.ItemType := 'color';
  Item.Name     := Name;

  c := ColorToRGB(Color);
  Item.R := GetRValue(c);
  Item.G := GetGValue(c);
  Item.B := GetBValue(c);
  Item.X := Alpha;

  Inc(FItemIndex);
end;

procedure AddCheck(var Item : TFILTER_ITEM_CHECK;Name : PWideChar;Value : Integer);
begin
  // 登録
  Items[FItemIndex] := @Item;

  // 基本設定
  Item.ItemType := 'check';
  Item.Name     := Name;

  // 初期値（0 / 1 前提）
  Item.Value    := Value;

  Inc(FItemIndex);
end;

procedure AddTrack(var Item  : TFILTER_ITEM_TRACK;Name : PWideChar;Value : Double;S : Double;E : Double;Step  : Double);
begin
  Items[FItemIndex] := @Item;

  Item.ItemType := 'track';
  Item.Name     := Name;
  Item.Value    := Value;
  Item.S        := S;
  Item.E        := E;
  Item.Step     := Step;

  Inc(FItemIndex);
end;

procedure AddText(var Item : TFILTER_ITEM_TEXT;Name     : PWideChar;const Value : WideString);
begin
  // 登録
  Items[FItemIndex] := @Item;

  // 基本設定
  Item.ItemType := 'text';
  Item.Name     := Name;

  // 初期文字列
  Item.Value    := PWideChar(Value);

  Inc(FItemIndex);
end;

procedure AddData(var Item : TFILTER_ITEM_DATA;Name     : PWideChar;Buffer   : PWideChar;Size     : Integer);
begin
  // 登録
  Items[FItemIndex] := @Item;

  // 基本設定
  Item.ItemType := 'data';
  Item.Name     := Name;

  // データ本体
  // ※ Buffer は「生存期間が保証されたバッファ」を前提とする
  Item.Value := Buffer;
  Item.Size  := Size;

  // 初期値（今回は Value と同一で可）
  Item.DefaultValue := Item.Value;

  Inc(FItemIndex);
end;

procedure AddSelect(var Item : TFILTER_ITEM_SELECT;Name : LPCWSTR;Value : Integer;List  : Pointer);
begin
  Items[FItemIndex] := @Item;

  Item.ItemType := 'select';
  Item.Name     := Name;
  Item.Value    := Value;
  Item.List     := List;  // ← 外部で宣言されたものを「参照」するだけ

  Inc(FItemIndex);

  ClearSelectList;
end;

procedure ClearSelectList;
begin
  FSelectIndex := 0;
end;

procedure AddSelectList(var List : array of TFILTER_ITEM_SELECT_ITEM;Name: PWideChar; Value: Integer);
begin
  // 実使用は MAX_SELECT_ITEMS - 1 まで（最後は NULL 終端専用）
  if FSelectIndex >= High(List) then
    Exit; // もしくは raise / DebugLog

  // 要素を登録
  List[FSelectIndex].Name  := Name;
  List[FSelectIndex].Value := Value;
  Inc(FSelectIndex);

  // 次要素を必ず NULL 終端にする（安全策）
  List[FSelectIndex].Name  := nil;
  List[FSelectIndex].Value := 0;
end;

procedure AddGroup(var Item : TFILTER_ITEM_GROUP;Name     : PWideChar;DefaultVisible : Integer);
begin
  // GUI Items に登録
  Items[FItemIndex] := @Item;

  // group 初期化
  Item.ItemType       := 'group';
  Item.Name           := Name;
  Item.DefaultVisible := DefaultVisible;

  Inc(FItemIndex);
end;

procedure GetData(const Item : TFILTER_ITEM_DATA;out Buffer  : PWideChar;out Size : Integer);
begin
  Buffer := Item.Value;
  Size   := Item.Size;
end;

procedure SetData(var Item : TFILTER_ITEM_DATA;Buffer : PWideChar;Size : Integer);
begin
  // データ本体を差し替える
  Item.Value := Buffer;
  Item.Size  := Size;

  // 初期値も現在値に追従させる（必要な設計の場合）
  Item.DefaultValue := Buffer;

    OutputDebugString(PWideChar(
  Format(
    'Save: DefaultValue=%p Size=%d Text="%s"',
    [
      Item.DefaultValue,
      Item.Size,
      PWideChar(Item.DefaultValue)
    ]
  )
));
end;


function GetColor(const Item: TFILTER_ITEM_COLOR): TColor;
begin
  Result := RGB(Item.R, Item.G, Item.B);
end;

procedure SetColor(var Item  : TFILTER_ITEM_COLOR;Color  : TColor;Alpha : PByte = nil);
var
  c: TColor;
begin
  c := ColorToRGB(Color);

  Item.R := GetRValue(c);
  Item.G := GetGValue(c);
  Item.B := GetBValue(c);

  if Alpha <> nil then
    Item.X := Alpha^;
end;

end.
