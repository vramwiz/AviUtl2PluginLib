unit PluginFilterSerifDrawOverlap;

interface

// 重なったセリフの自動表示対象と、配役別Y方向クリップ範囲を決定する。

uses
  PluginFilterSerifDrawReceiver;

// 全本文が完全一致するときは重複配役を除いた全件、それ以外は最新1件を返す。
function SelectSerifDrawVisibleSnapshotIndices(
  const ASnapshots: TArray<TSerifDrawSnapshot>): TArray<Integer>;

// 複数配役の特殊表示では人数、単独表示では配役名を返す。
function SerifDrawRoleNameDisplayText(const AVisibleCount: Integer;
  const ASingleRoleName: string): string;

// 高さをACount個の連続した帯へ分割し、AIndex番目の上端と下端を返す。
procedure SerifDrawSplitBand(const AHeight, AIndex, ACount: Integer;
  out ATop, ABottom: Integer);
// 効果画像の余白ではなく文字レイアウト上で帯を等分する。
procedure SerifDrawSplitLayoutBand(const ALayoutHeight, AEffectTop,
  AEffectHeight, AIndex, ACount: Integer; out ATop, ABottom: Integer);

implementation

uses
  System.Generics.Collections,
  System.Math,
  System.SysUtils,
  PluginFilterSerifDrawRoleNames;

function SelectSerifDrawVisibleSnapshotIndices(
  const ASnapshots: TArray<TSerifDrawSnapshot>): TArray<Integer>;
var
  AllSame: Boolean;
  I: Integer;
  Key: string;
  LatestIndex: Integer;
  ReverseIndices: TArray<Integer>;
  SeenRoles: TDictionary<string, Byte>;
begin
  Result := nil;
  if Length(ASnapshots) = 0 then
    Exit;
  LatestIndex := High(ASnapshots);
  AllSame := Length(ASnapshots) > 1;
  if AllSame then
    for I := 0 to LatestIndex - 1 do
      if ASnapshots[I].Serif <> ASnapshots[LatestIndex].Serif then
      begin
        AllSame := False;
        Break;
      end;
  if not AllSame then
  begin
    SetLength(Result, 1);
    Result[0] := LatestIndex;
    Exit;
  end;

  SeenRoles := TDictionary<string, Byte>.Create;
  try
    // 新しい項目から重複を除き、最後に反転して送信順（古い→新しい）へ戻す。
    for I := LatestIndex downto 0 do
    begin
      Key := SerifDrawRoleNameKey(ASnapshots[I].Chara);
      if SeenRoles.ContainsKey(Key) then
        Continue;
      SeenRoles.Add(Key, 0);
      SetLength(ReverseIndices, Length(ReverseIndices) + 1);
      ReverseIndices[High(ReverseIndices)] := I;
    end;
  finally
    SeenRoles.Free;
  end;
  SetLength(Result, Length(ReverseIndices));
  for I := 0 to High(ReverseIndices) do
    Result[I] := ReverseIndices[High(ReverseIndices) - I];
end;

function SerifDrawRoleNameDisplayText(const AVisibleCount: Integer;
  const ASingleRoleName: string): string;
begin
  if AVisibleCount > 1 then
    Result := IntToStr(AVisibleCount) + #$4EBA
  else
    Result := Trim(ASingleRoleName);
end;

procedure SerifDrawSplitBand(const AHeight, AIndex, ACount: Integer;
  out ATop, ABottom: Integer);
begin
  if (AHeight <= 0) or (ACount <= 0) or (AIndex < 0) or
    (AIndex >= ACount) then
  begin
    ATop := 0;
    ABottom := 0;
    Exit;
  end;
  ATop := AHeight * AIndex div ACount;
  ABottom := AHeight * (AIndex + 1) div ACount;
end;

procedure SerifDrawSplitLayoutBand(const ALayoutHeight, AEffectTop,
  AEffectHeight, AIndex, ACount: Integer; out ATop, ABottom: Integer);
var
  LayoutTop, LayoutBottom: Integer;
begin
  if (ALayoutHeight <= 0) or (AEffectHeight <= 0) or (ACount <= 0) or
    (AIndex < 0) or (AIndex >= ACount) then
  begin
    ATop := 0;
    ABottom := 0;
    Exit;
  end;
  SerifDrawSplitBand(ALayoutHeight, AIndex, ACount,
    LayoutTop, LayoutBottom);
  if AIndex = 0 then
    ATop := 0
  else
    ATop := EnsureRange(LayoutTop - AEffectTop, 0, AEffectHeight);
  if AIndex = ACount - 1 then
    ABottom := AEffectHeight
  else
    ABottom := EnsureRange(LayoutBottom - AEffectTop, 0, AEffectHeight);
end;

end.
