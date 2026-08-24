unit SerifAliasObjectAccessor;

interface

uses
  System.SysUtils, System.Classes, ALiasList;

type
  TSerifAliasObject = class
  private
    FFileName: string;             // 対象の.objectファイル名
    FAlias: TALiasList;            // エイリアス本体
    FLoadFromFileed: Boolean;      // 読込済みか
    FTargetItemIndex: Integer;     // 対象アイテム位置
    FTargetSectionIndex: Integer;  // 対象セクション位置
    // 対象セクション位置を未選択に戻す
    procedure ClearTarget;
    // Syncroh2用テキストセクションを探す
    function FindTargetTextSection: Boolean;
    // 現在の対象セクションを返す
    function GetTargetSection: TAliasSectionItem;
    // スクリプト全文を返す
    function GetRawScript: string;
    // スクリプト全文を書き換える
    procedure SetRawScript(const Value: string);
    // Syncroh2用セリフオブジェクトか返す
    function GetIsSyncroh2SerifObject: Boolean;
    // レイヤー番号を取得する
    function GetLayerIndex: Integer;
    // レイヤー番号を書き換える
    procedure SetLayerIndex(const Value: Integer);
    // mes(...)の引数式を返す
    function GetMessageExpression: string;
    // mes(...)の引数式を書き換える
    procedure SetMessageExpression(const Value: string);
    // スクリプト内のfilename変数を返す
    function GetScriptFileName: string;
    // スクリプト内のfilename変数を書き換える
    procedure SetScriptFileName(const Value: string);
    // Syncroh2_Moduleを使うスクリプトか判定する
    function HasSyncroh2Module(const Script: string): Boolean;
    // スクリプトからlayer値を抜き出す
    function ExtractLayerIndex(const Script: string): Integer;
    // スクリプト内のlayer値を書き換える
    function ReplaceLayerValue(const Script: string; const LayerValue: Integer): string;
    // スクリプトからfilename値を抜き出す
    function ExtractScriptFileName(const Script: string): string;
    // スクリプト内のfilename値を書き換える
    function ReplaceScriptFileName(const Script, Value: string): string;
    // スクリプトからmes(...)の中身を抜き出す
    function ExtractMessageExpression(const Script: string): string;
    // スクリプト内のmes(...)の中身を書き換える
    function ReplaceMessageExpression(const Script, Expr: string): string;
  public
    // インスタンスを生成する
    constructor Create;
    // 内部オブジェクトを破棄する
    destructor Destroy; override;
    // 読込状態を初期化する
    procedure Clear;
    // FileNameから.objectを読み込む
    function LoadFromFile: Boolean;
    // 文字列から.object内容を復元する
    function LoadFromText(const AliasText: string): Boolean;
    // 現在内容をFileNameへ保存する
    function SaveToFile: Boolean;
    // 現在内容を文字列へ保存する
    function SaveToText: string;
    property FileName: string read FFileName write FFileName;
    property LoadFromFileed: Boolean read FLoadFromFileed;
    property IsSyncroh2SerifObject: Boolean read GetIsSyncroh2SerifObject;
    property LayerIndex: Integer read GetLayerIndex write SetLayerIndex;
    property MessageExpression: string read GetMessageExpression write SetMessageExpression;
    property ScriptFileName: string read GetScriptFileName write SetScriptFileName;
    property RawScript: string read GetRawScript write SetRawScript;
  end;

implementation

uses
  System.StrUtils;

// インスタンスを生成する
constructor TSerifAliasObject.Create;
begin
  inherited;
  FAlias := TALiasList.Create;
  Clear;
end;

// 内部オブジェクトを破棄する
destructor TSerifAliasObject.Destroy;
begin
  FAlias.Free;
  inherited;
end;

// 対象セクション位置を未選択に戻す
procedure TSerifAliasObject.ClearTarget;
begin
  FTargetItemIndex := -1;
  FTargetSectionIndex := -1;
end;

// 読込状態を初期化する
procedure TSerifAliasObject.Clear;
begin
  FLoadFromFileed := False;
  ClearTarget;
  FAlias.Clear;
end;

// FileNameから.objectを読み込む
function TSerifAliasObject.LoadFromFile: Boolean;
begin
  Result := False;
  Clear;
  if (FFileName = '') or not FileExists(FFileName) then Exit;

  FAlias.LoadFromAlias(FFileName);
  FLoadFromFileed := True;
  FindTargetTextSection;
  Result := True;
end;

// 文字列から.object内容を復元する
function TSerifAliasObject.LoadFromText(const AliasText: string): Boolean;
var
  Lines: TStringList;
begin
  // 文字列の alias を TStringList 化して既存の読込処理へ渡す。
  Result := False;
  Clear;
  if AliasText = '' then Exit;

  Lines := TStringList.Create;
  try
    Lines.Text := AliasText;
    FAlias.LoadFromStrings(Lines);
    FLoadFromFileed := True;
    FindTargetTextSection;
    Result := True;
  finally
    Lines.Free;
  end;
end;

// 現在内容をFileNameへ保存する
function TSerifAliasObject.SaveToFile: Boolean;
begin
  Result := False;
  //if not FLoadFromFileed then Exit;
  if FFileName = '' then Exit;

  FAlias.SaveToAlias(FFileName);
  Result := True;
end;

// 現在内容を文字列へ保存する
function TSerifAliasObject.SaveToText: string;
begin
  // 内部 alias を .object 相当のテキストへ戻す。
  Result := FAlias.SaveToText;
end;

// Syncroh2用テキストセクションを探す
function TSerifAliasObject.FindTargetTextSection: Boolean;
var
  ItemIndex: Integer;
  SectionIndex: Integer;
  Section: TAliasSectionItem;
  EffectName: string;
  Script: string;
begin
  Result := False;
  ClearTarget;

  for ItemIndex := 0 to FAlias.Count - 1 do
  begin
    for SectionIndex := 0 to FAlias[ItemIndex].Sections.Count - 1 do
    begin
      Section := FAlias[ItemIndex].Sections[SectionIndex];
      EffectName := Trim(Section.Values['effect.name']);
      if not SameText(EffectName, 'テキスト') then Continue;

      Script := Section.Values['テキスト'];
      if not HasSyncroh2Module(Script) then Continue;

      FTargetItemIndex := ItemIndex;
      FTargetSectionIndex := SectionIndex;
      Exit(True);
    end;
  end;
end;

// 現在の対象セクションを返す
function TSerifAliasObject.GetTargetSection: TAliasSectionItem;
begin
  Result := nil;
  if not FLoadFromFileed then Exit;
  if (FTargetItemIndex < 0) or (FTargetItemIndex >= FAlias.Count) then Exit;
  if (FTargetSectionIndex < 0) or
     (FTargetSectionIndex >= FAlias[FTargetItemIndex].Sections.Count) then Exit;
  Result := FAlias[FTargetItemIndex].Sections[FTargetSectionIndex];
end;

// スクリプト全文を返す
function TSerifAliasObject.GetRawScript: string;
var
  Section: TAliasSectionItem;
begin
  Result := '';
  Section := GetTargetSection;
  if Section = nil then Exit;
  Result := Section.Values['テキスト'];
end;

// スクリプト全文を書き換える
procedure TSerifAliasObject.SetRawScript(const Value: string);
var
  Section: TAliasSectionItem;
begin
  Section := GetTargetSection;
  if Section = nil then Exit;
  Section.Values['テキスト'] := Value;
end;

// Syncroh2用セリフオブジェクトか返す
function TSerifAliasObject.GetIsSyncroh2SerifObject: Boolean;
begin
  Result := GetTargetSection <> nil;
end;

// Syncroh2_Moduleを使うスクリプトか判定する
function TSerifAliasObject.HasSyncroh2Module(const Script: string): Boolean;
begin
  Result :=
    ContainsText(Script, 'obj.module("Syncroh2_Module")') and
    ContainsText(Script, 'mes(');
end;

// スクリプトからlayer値を抜き出す
function TSerifAliasObject.ExtractLayerIndex(const Script: string): Integer;
var
  P: Integer;
  StartPos: Integer;
  NumText: string;
begin
  Result := -1;
  P := Pos('layer=', Script);
  if P <= 0 then Exit;

  StartPos := P + Length('layer=');
  NumText := '';
  while (StartPos <= Length(Script)) and CharInSet(Script[StartPos], ['0'..'9']) do
  begin
    NumText := NumText + Script[StartPos];
    Inc(StartPos);
  end;

  if NumText = '' then Exit;

  Result := StrToIntDef(NumText, 0);
  if Result > 0 then Dec(Result);
  if Result < 0 then Result := -1;
end;

// スクリプト内のlayer値を書き換える
function TSerifAliasObject.ReplaceLayerValue(const Script: string; const LayerValue: Integer): string;
var
  P: Integer;
  StartPos: Integer;
  EndPos: Integer;
begin
  Result := Script;
  P := Pos('layer=', Script);
  if P <= 0 then
    Exit;

  StartPos := P + Length('layer=');
  EndPos := StartPos;
  while (EndPos <= Length(Script)) and CharInSet(Script[EndPos], ['0'..'9']) do
    Inc(EndPos);

  Result := Copy(Script, 1, StartPos - 1) + IntToStr(LayerValue) + Copy(Script, EndPos, MaxInt);
end;

// スクリプトからfilename値を抜き出す
function TSerifAliasObject.ExtractScriptFileName(const Script: string): string;
var
  StartPos: Integer;
  EndPos: Integer;
begin
  Result := '';
  StartPos := Pos('local filename="', Script);
  if StartPos <= 0 then Exit;

  Inc(StartPos, Length('local filename="'));
  EndPos := PosEx('"', Script, StartPos);
  if EndPos <= 0 then Exit;

  Result := Copy(Script, StartPos, EndPos - StartPos);
  Result := Result.Replace('\"', '"', [rfReplaceAll]);
  Result := Result.Replace('\\', '\', [rfReplaceAll]);
end;

// スクリプト内のfilename値を書き換える
function TSerifAliasObject.ReplaceScriptFileName(const Script, Value: string): string;
var
  StartPos: Integer;
  EndPos: Integer;
  EscapedValue: string;
begin
  Result := Script;
  StartPos := Pos('local filename="', Script);
  if StartPos <= 0 then Exit;

  Inc(StartPos, Length('local filename="'));
  EndPos := PosEx('"', Script, StartPos);
  if EndPos <= 0 then Exit;

  EscapedValue := Value.Replace('\', '\\', [rfReplaceAll]);
  EscapedValue := EscapedValue.Replace('"', '\"', [rfReplaceAll]);

  Result := Copy(Script, 1, StartPos - 1) + EscapedValue + Copy(Script, EndPos, MaxInt);
end;

// レイヤー番号を取得する
function TSerifAliasObject.GetLayerIndex: Integer;
begin
  Result := ExtractLayerIndex(GetRawScript);
end;

// レイヤー番号を書き換える
procedure TSerifAliasObject.SetLayerIndex(const Value: Integer);
var
  LayerValue: Integer;
begin
  if not IsSyncroh2SerifObject then Exit;

  LayerValue := Value + 1;
  if Value < 0 then LayerValue := 0;
  RawScript := ReplaceLayerValue(GetRawScript, LayerValue);
end;

// スクリプトからmes(...)の中身を抜き出す
function TSerifAliasObject.ExtractMessageExpression(const Script: string): string;
var
  StartPos: Integer;
  EndPos: Integer;
begin
  Result := '';
  StartPos := Pos('mes(', Script);
  if StartPos <= 0 then Exit;

  Inc(StartPos, Length('mes('));
  EndPos := PosEx(');', Script, StartPos);
  if EndPos <= 0 then Exit;

  Result := Trim(Copy(Script, StartPos, EndPos - StartPos));
end;

// スクリプト内のmes(...)の中身を書き換える
function TSerifAliasObject.ReplaceMessageExpression(const Script, Expr: string): string;
var
  StartPos: Integer;
  EndPos: Integer;
begin
  Result := Script;
  StartPos := Pos('mes(', Script);
  if StartPos <= 0 then Exit;

  Inc(StartPos, Length('mes('));
  EndPos := PosEx(');', Script, StartPos);
  if EndPos <= 0 then Exit;

  Result := Copy(Script, 1, StartPos - 1) + Expr + Copy(Script, EndPos, MaxInt);
end;

// mes(...)の引数式を返す
function TSerifAliasObject.GetMessageExpression: string;
begin
  Result := ExtractMessageExpression(GetRawScript);
end;

// mes(...)の引数式を書き換える
procedure TSerifAliasObject.SetMessageExpression(const Value: string);
begin
  if not IsSyncroh2SerifObject then Exit;
  RawScript := ReplaceMessageExpression(GetRawScript, Value);
end;

// スクリプト内のfilename変数を返す
function TSerifAliasObject.GetScriptFileName: string;
begin
  Result := ExtractScriptFileName(GetRawScript);
end;

// スクリプト内のfilename変数を書き換える
procedure TSerifAliasObject.SetScriptFileName(const Value: string);
begin
  if not IsSyncroh2SerifObject then Exit;
  RawScript := ReplaceScriptFileName(GetRawScript, Value);
end;
end.
