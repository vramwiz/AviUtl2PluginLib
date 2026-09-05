unit MmdMorphSettingRows;

// PMXのモーフ順と分類境界から、設定一覧が表示する見出し行とモーフ行を構築する。

interface

uses
  MmdMorphSettingValue,
  PmxModel,
  PmxMorph;

type
  TMmdMorphSettingRowKind = (msrkHeader, msrkMorph);

  TMmdMorphSettingRow = record
    Kind: TMmdMorphSettingRowKind;
    MorphIndex: Integer;
    Panel: Byte;
  end;

  TMmdMorphSettingRows = TArray<TMmdMorphSettingRow>;

const
  MMD_MORPH_PANEL_DISPLAY_ACCESSORY = 5;

// PMXの並び順を維持し、分類値が変わる位置へ操作不能な見出し行を挿入する。
procedure BuildMorphSettingRows(const Model: TPmxModel; out Rows: TMmdMorphSettingRows);

// StartRowからDirection方向へ見出しを飛ばし、最初のモーフ行を返す。存在しない場合は-1を返す。
function FindSelectableMorphRow(const Rows: TMmdMorphSettingRows; StartRow, Direction: Integer): Integer;

// 表示行に対応するPMXモーフ番号を返す。見出し行または範囲外の場合は-1を返す。
function MorphIndexAtSettingRow(const Rows: TMmdMorphSettingRows; RowIndex: Integer): Integer;

// PMXの固定分類値と表示・アクセサリ分類を画面表示用名称へ変換する。
function MorphPanelCaption(Panel: Byte): string;

// PMXの眉・目・リップ・その他と内部表示分類以外を未分類値0へ正規化する。
function NormalizeMorphPanel(Panel: Byte): Byte;
// モデル接続時のウェイト、操作方式、表示行、初期選択をまとめて初期化する。
procedure InitializeMorphSettingRows(const Model: TPmxModel;
  out Weights: TPmxMorphWeights; out Modes: TMmdMorphControlModes;
  out Rows: TMmdMorphSettingRows; out ActiveRow: Integer);

implementation

procedure InitializeMorphSettingRows(const Model: TPmxModel;
  out Weights: TPmxMorphWeights; out Modes: TMmdMorphControlModes;
  out Rows: TMmdMorphSettingRows; out ActiveRow: Integer);
var
  Index: Integer;
begin
  InitializeMorphWeights(Model, Weights);
  SetLength(Modes, Length(Weights));
  for Index := 0 to High(Modes) do
    if Model.Morphs[Index].MorphType = pmtMaterial then
      Modes[Index] := mcmToggle
    else
      Modes[Index] := mcmContinuous;
  BuildMorphSettingRows(Model, Rows);
  ActiveRow := FindSelectableMorphRow(Rows, 0, 1);
end;

procedure BuildMorphSettingRows(const Model: TPmxModel; out Rows: TMmdMorphSettingRows);
var
  Index, RowIndex: Integer;
  Panel, PreviousPanel: Byte;
begin
  Rows := nil;
  if Model = nil then
    Exit;
  SetLength(Rows, Length(Model.Morphs) * 2);
  RowIndex := 0;
  PreviousPanel := $FF;
  for Index := 0 to High(Model.Morphs) do
  begin
    if Model.Morphs[Index].MorphType = pmtMaterial then
      Panel := MMD_MORPH_PANEL_DISPLAY_ACCESSORY
    else
      Panel := NormalizeMorphPanel(Model.Morphs[Index].Panel);
    if Panel <> PreviousPanel then
    begin
      Rows[RowIndex].Kind := msrkHeader;
      Rows[RowIndex].MorphIndex := -1;
      Rows[RowIndex].Panel := Panel;
      Inc(RowIndex);
      PreviousPanel := Panel;
    end;
    Rows[RowIndex].Kind := msrkMorph;
    Rows[RowIndex].MorphIndex := Index;
    Rows[RowIndex].Panel := Panel;
    Inc(RowIndex);
  end;
  SetLength(Rows, RowIndex);
end;

function FindSelectableMorphRow(const Rows: TMmdMorphSettingRows; StartRow, Direction: Integer): Integer;
begin
  Result := StartRow;
  while (Result >= 0) and (Result < Length(Rows)) do
  begin
    if Rows[Result].Kind = msrkMorph then
      Exit;
    Inc(Result, Direction);
  end;
  Result := -1;
end;

function MorphIndexAtSettingRow(const Rows: TMmdMorphSettingRows; RowIndex: Integer): Integer;
begin
  if (RowIndex < 0) or (RowIndex >= Length(Rows)) or (Rows[RowIndex].Kind <> msrkMorph) then
    Exit(-1);
  Result := Rows[RowIndex].MorphIndex;
end;

function MorphPanelCaption(Panel: Byte): string;
begin
  case NormalizeMorphPanel(Panel) of
    1: Result := #$7709;
    2: Result := #$76EE;
    3: Result := #$30EA#$30C3#$30D7;
    4: Result := #$305D#$306E#$4ED6;
    MMD_MORPH_PANEL_DISPLAY_ACCESSORY:
      Result := #$8868#$793A#$30FB#$30A2#$30AF#$30BB#$30B5#$30EA;
  else
    Result := #$672A#$5206#$985E;
  end;
end;

function NormalizeMorphPanel(Panel: Byte): Byte;
begin
  if Panel in [1, 2, 3, 4, MMD_MORPH_PANEL_DISPLAY_ACCESSORY] then
    Result := Panel
  else
    Result := 0;
end;

end.
