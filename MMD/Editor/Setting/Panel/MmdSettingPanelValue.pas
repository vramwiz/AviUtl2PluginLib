unit MmdSettingPanelValue;

// モーフ設定パネルで共通するコンボ項目の解決と数値入力の検証を提供する。

interface

uses
  Vcl.StdCtrls,
  MmdPoseEditorTheme,
  MmdPoseEditorComboTheme,
  PmxModel;

// 編集文字列を有限値として読み、失敗時は既定値、成功時は指定範囲へ収めて返す。
function ReadMmdSettingEditValue(Edit: TEdit; DefaultValue, Minimum,
  Maximum: Double): Double;
// 選択可能なモーフを「なし」に続けて追加し、初期選択を「なし」に戻す。
procedure PopulateMmdMorphCombo(Combo: TMmdDarkComboBox; Model: TPmxModel);
// コンボが指す現在モデルのモーフ番号を返し、無効な選択では-1を返す。
function ResolveMmdMorphComboIndex(Combo: TMmdDarkComboBox;
  Model: TPmxModel): Integer;
// コンボが指す現在モデルのモーフ名を返し、無効な選択では空文字列を返す。
function ResolveMmdMorphComboName(Combo: TMmdDarkComboBox;
  Model: TPmxModel): string;
// モーフ名の完全一致項目を選び、空文字列または未登録名では「なし」を選ぶ。
procedure SelectMmdMorphCombo(Combo: TMmdDarkComboBox;
  const MorphName: string);

implementation

uses
  System.Math,
  System.SysUtils,
  PmxMorph;

function ReadMmdSettingEditValue(Edit: TEdit; DefaultValue, Minimum,
  Maximum: Double): Double;
begin
  if (Edit = nil) or not TryStrToFloat(Trim(Edit.Text), Result) or
    IsNan(Result) or IsInfinite(Result) then
    Result := DefaultValue;
  Result := EnsureRange(Result, Minimum, Maximum);
end;

procedure PopulateMmdMorphCombo(Combo: TMmdDarkComboBox; Model: TPmxModel);
var
  MorphIndex: Integer;
begin
  Combo.Items.BeginUpdate;
  try
    Combo.Clear;
    Combo.Items.Add(#$306A#$3057);
    if Model <> nil then
      for MorphIndex := 0 to High(Model.Morphs) do
        if Model.Morphs[MorphIndex].MorphType in
          [pmtGroup, pmtVertex, pmtBone, pmtFlip] then
          Combo.Items.AddObject(Model.Morphs[MorphIndex].Name,
            TObject(NativeInt(MorphIndex + 1)));
    Combo.ItemIndex := 0;
  finally
    Combo.Items.EndUpdate;
  end;
end;

function ResolveMmdMorphComboIndex(Combo: TMmdDarkComboBox;
  Model: TPmxModel): Integer;
begin
  Result := -1;
  if (Combo = nil) or (Combo.ItemIndex <= 0) or
    (Combo.ItemIndex >= Combo.Items.Count) then
    Exit;
  Result := NativeInt(Combo.Items.Objects[Combo.ItemIndex]) - 1;
  if (Model = nil) or (Result < 0) or (Result > High(Model.Morphs)) then
    Result := -1;
end;

function ResolveMmdMorphComboName(Combo: TMmdDarkComboBox;
  Model: TPmxModel): string;
var
  MorphIndex: Integer;
begin
  MorphIndex := ResolveMmdMorphComboIndex(Combo, Model);
  if MorphIndex < 0 then
    Exit('');
  Result := Model.Morphs[MorphIndex].Name;
end;

procedure SelectMmdMorphCombo(Combo: TMmdDarkComboBox;
  const MorphName: string);
var
  I: Integer;
begin
  Combo.ItemIndex := 0;
  if MorphName = '' then
    Exit;
  for I := 1 to Combo.Items.Count - 1 do
    if SameText(Combo.Items[I], MorphName) then
    begin
      Combo.ItemIndex := I;
      Exit;
    end;
end;

end.
