unit MmdMorphSettingValue;

// モーフ設定GUIの連続値、2値切替、トラック端吸着に関する値決定規則を提供する。

interface

uses
  System.Types,
  PmxModel,
  PmxMorph;

type
  TMmdMorphControlMode = (mcmContinuous, mcmToggle);
  TMmdMorphControlModes = TArray<TMmdMorphControlMode>;

// マウスX座標を0～1へ変換し、端吸着と2値モードの丸めを適用したウェイトを返す。
function MorphWeightFromTrackPosition(Mode: TMmdMorphControlMode; X: Integer;
  const TrackBounds: TRect; SnapDistance: Integer): Single;

// 操作方式を連続値と2値の間で切り替え、2値へ移る場合は現在値を0または1へ丸める。
procedure ToggleMorphControlMode(var Mode: TMmdMorphControlMode; var Weight: Single);
// モデル数に合う独立配列を作り、入力値を0～1へ制限して複製する。
procedure AssignMorphWeights(const Model: TPmxModel;
  const Source: TPmxMorphWeights; out Target: TPmxMorphWeights);

implementation

uses
  Winapi.Windows,
  System.Math;

procedure AssignMorphWeights(const Model: TPmxModel;
  const Source: TPmxMorphWeights; out Target: TPmxMorphWeights);
var
  Index: Integer;
begin
  InitializeMorphWeights(Model, Target);
  for Index := 0 to Min(High(Target), High(Source)) do
    Target[Index] := EnsureRange(Source[Index], 0.0, 1.0);
end;

function MorphWeightFromTrackPosition(Mode: TMmdMorphControlMode; X: Integer;
  const TrackBounds: TRect; SnapDistance: Integer): Single;
var
  Percent: Integer;
begin
  if X <= TrackBounds.Left + SnapDistance then
    Percent := 0
  else if X >= TrackBounds.Right - SnapDistance then
    Percent := 100
  else
    Percent := MulDiv(X - TrackBounds.Left, 100, Max(TrackBounds.Width, 1));
  if Mode = mcmToggle then
  begin
    if Percent >= 50 then
      Result := 1
    else
      Result := 0;
  end
  else
    Result := Percent / 100;
end;

procedure ToggleMorphControlMode(var Mode: TMmdMorphControlMode; var Weight: Single);
begin
  if Mode = mcmContinuous then
  begin
    Mode := mcmToggle;
    if Weight >= 0.5 then
      Weight := 1
    else
      Weight := 0;
  end
  else
    Mode := mcmContinuous;
end;

end.
