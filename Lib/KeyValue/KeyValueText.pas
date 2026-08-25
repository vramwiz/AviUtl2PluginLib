unit KeyValueText;

interface

uses
  System.SysUtils, System.StrUtils;

{-------------------------------------------------------
  外部公開 AddKeyValue（オーバーロード）
  ・文字列
  ・整数
  ・浮動小数
  ・真偽値
  最終的には内部の AddKeyValueSub を呼ぶ
-------------------------------------------------------}
procedure AddKeyValue(var LineText: string; const Key, Value: string); overload;
procedure AddKeyValue(var LineText: string; const Key: string; const Value: Integer); overload;
procedure AddKeyValue(var LineText: string; const Key: string; const Value: Double); overload;
procedure AddKeyValue(var LineText: string; const Key: string; const Value: Boolean); overload;

{-------------------------------------------------------
  外部公開 GetKeyValue（オーバーロード）
  ・string → string
  ・Int    → integer
  ・Float  → double
  ・Bool   → boolean
-------------------------------------------------------}
function GetKeyValue(const LineText, Key: string): string; overload;
function GetKeyValueInt(const LineText, Key: string): Integer;
function GetKeyValueFloat(const LineText, Key: string): Double;
function GetKeyValueBool(const LineText, Key: string): Boolean;

implementation

{-------------------------------------------------------
  内部処理 Sub
  ・Key=Value; を追加する最低限の処理
  ・内部専用（文字列固定）
-------------------------------------------------------}
procedure AddKeyValueSub(var LineText: string; const Key, Value: string);
begin
  LineText := LineText + Key + '=' + Value + ';';
end;

{-------------------------------------------------------
  内部処理 Sub
  ・Key=Value; から Value を取り出す最低限の処理
  ・内部専用（文字列固定）
-------------------------------------------------------}
function GetKeyValueSub(const LineText, Key: string): string;
var
  SearchKey: string;
  P, E: Integer;
begin
  Result := '';
  SearchKey := Key + '=';

  P := Pos(SearchKey, LineText);
  if P = 0 then
    Exit;

  P := P + Length(SearchKey);
  E := PosEx(';', LineText, P);
  if E = 0 then
    E := Length(LineText) + 1;

  Result := Copy(LineText, P, E - P);
end;

{-------------------------------------------------------
  外部公開 Add（string版）
-------------------------------------------------------}
procedure AddKeyValue(var LineText: string; const Key, Value: string);
begin
  AddKeyValueSub(LineText, Key, Value);
end;

{-------------------------------------------------------
  外部公開 Add（integer版）
-------------------------------------------------------}
procedure AddKeyValue(var LineText: string; const Key: string; const Value: Integer);
begin
  AddKeyValueSub(LineText, Key, IntToStr(Value));
end;

{-------------------------------------------------------
  外部公開 Add（double版）
-------------------------------------------------------}
procedure AddKeyValue(var LineText: string; const Key: string; const Value: Double);
begin
  AddKeyValueSub(LineText, Key, FloatToStr(Value));
end;

{-------------------------------------------------------
  外部公開 Add（boolean版）
-------------------------------------------------------}
procedure AddKeyValue(var LineText: string; const Key: string; const Value: Boolean);
begin
  if Value then
    AddKeyValueSub(LineText, Key, '1')
  else
    AddKeyValueSub(LineText, Key, '0');
end;

{-------------------------------------------------------
  外部公開 Get（string版）
-------------------------------------------------------}
function GetKeyValue(const LineText, Key: string): string;
begin
  Result := GetKeyValueSub(LineText, Key);
end;

{-------------------------------------------------------
  外部公開 Get（Int版）
-------------------------------------------------------}
function GetKeyValueInt(const LineText, Key: string): Integer;
var
  S: string;
begin
  if LineText = '' then Exit(-1);

  S := GetKeyValueSub(LineText, Key);
  Result := StrToIntDef(S, -1);
end;

{-------------------------------------------------------
  外部公開 Get（Float版）
-------------------------------------------------------}
function GetKeyValueFloat(const LineText, Key: string): Double;
var
  S: string;
begin
  S := GetKeyValueSub(LineText, Key);
  Result := StrToFloatDef(S, 0.0);
end;

{-------------------------------------------------------
  外部公開 Get（Bool版）
-------------------------------------------------------}
function GetKeyValueBool(const LineText, Key: string): Boolean;
var
  S: string;
begin
  S := GetKeyValueSub(LineText, Key);
  Result := (S = '1') or SameText(S, 'true');
end;

end.

