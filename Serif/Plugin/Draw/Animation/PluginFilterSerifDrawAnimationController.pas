unit PluginFilterSerifDrawAnimationController;

interface

// セリフの入替えと消失を追跡し、前・中・後の評価に必要な時刻を管理する。

uses
  PluginFilterSerifDrawAnimationTypes,
  PluginFilterSerifDrawReceiver;

type
  TSerifDrawAnimationStage = (sdasHidden, sdasActive, sdasAfter);

  TSerifDrawAnimationController = class
  private
    FCurrentKey: string;
    FLastFrame: Integer;
    FSerifStartFrame: Integer;
    FStage: TSerifDrawAnimationStage;
    FStageStartFrame: Integer;
    FStoredSnapshots: TArray<TSerifDrawSnapshot>;
    function BuildKey(const ASnapshots: TArray<TSerifDrawSnapshot>): string;
    function SecondsBetween(const AFromFrame, AToFrame: Integer;
      const AFps: Double): Double;
  public
    constructor Create;
    procedure Reset;
    function Update(const AActiveSnapshots: TArray<TSerifDrawSnapshot>;
      const ACurrentFrame: Integer; const AFps: Double;
      const AParameters: TSerifDrawAnimationParameters;
      out ARenderSnapshots: TArray<TSerifDrawSnapshot>):
      TSerifDrawAnimationTransform;
  end;

implementation

uses
  System.SysUtils,
  PluginFilterSerifDrawAnimationEvaluator;

constructor TSerifDrawAnimationController.Create;
begin
  inherited;
  Reset;
end;

function TSerifDrawAnimationController.BuildKey(
  const ASnapshots: TArray<TSerifDrawSnapshot>): string;
var
  Snapshot: TSerifDrawSnapshot;
begin
  Result := IntToStr(Length(ASnapshots)) + '|';
  for Snapshot in ASnapshots do
    Result := Result + IntToStr(Snapshot.Layer) + ':' +
      IntToStr(Length(Snapshot.SourceObjectID)) + ':' +
      Snapshot.SourceObjectID + ':' + IntToStr(Length(Snapshot.Serif)) + ':' +
      Snapshot.Serif + '|';
end;

procedure TSerifDrawAnimationController.Reset;
begin
  FCurrentKey := '';
  FLastFrame := -1;
  FSerifStartFrame := -1;
  FStage := sdasHidden;
  FStageStartFrame := -1;
  FStoredSnapshots := nil;
end;

function TSerifDrawAnimationController.SecondsBetween(
  const AFromFrame, AToFrame: Integer; const AFps: Double): Double;
var
  EffectiveFps: Double;
begin
  EffectiveFps := AFps;
  if EffectiveFps <= 0.0 then
    EffectiveFps := 30.0;
  Result := (AToFrame - AFromFrame) / EffectiveFps;
  if Result < 0.0 then
    Result := 0.0;
end;

function TSerifDrawAnimationController.Update(
  const AActiveSnapshots: TArray<TSerifDrawSnapshot>;
  const ACurrentFrame: Integer; const AFps: Double;
  const AParameters: TSerifDrawAnimationParameters;
  out ARenderSnapshots: TArray<TSerifDrawSnapshot>):
  TSerifDrawAnimationTransform;
var
  ActiveKey: string;
  AfterElapsed: Double;
  EvaluationParameters: TSerifDrawAnimationParameters;
  I: Integer;
  TotalElapsed: Double;
begin
  ARenderSnapshots := nil;
  if (FLastFrame >= 0) and (ACurrentFrame < FLastFrame) then
    Reset;

  if Length(AActiveSnapshots) > 0 then
  begin
    ActiveKey := BuildKey(AActiveSnapshots);
    if (FStage <> sdasActive) or (ActiveKey <> FCurrentKey) then
    begin
      FCurrentKey := ActiveKey;
      FSerifStartFrame := ACurrentFrame;
      FStageStartFrame := ACurrentFrame;
      FStage := sdasActive;
    end;
    FStoredSnapshots := System.Copy(AActiveSnapshots, 0,
      Length(AActiveSnapshots));
    ARenderSnapshots := System.Copy(FStoredSnapshots, 0,
      Length(FStoredSnapshots));
    TotalElapsed := SecondsBetween(FSerifStartFrame, ACurrentFrame, AFps);
    EvaluationParameters := AParameters;
    EvaluationParameters.RuntimeEmote :=
      AActiveSnapshots[High(AActiveSnapshots)].Emote;
    Result := EvaluateSerifDrawActiveAnimation(EvaluationParameters,
      TotalElapsed);
  end
  else
  begin
    if (FStage = sdasActive) and (Length(FStoredSnapshots) > 0) then
    begin
      FStage := sdasAfter;
      FStageStartFrame := ACurrentFrame;
      for I := 0 to High(FStoredSnapshots) do
      begin
        FStoredSnapshots[I].HoldSpeechSync := True;
        FStoredSnapshots[I].SpeechActive := False;
      end;
    end;
    if FStage = sdasAfter then
    begin
      TotalElapsed := SecondsBetween(FSerifStartFrame, ACurrentFrame, AFps);
      AfterElapsed := SecondsBetween(FStageStartFrame, ACurrentFrame, AFps);
      EvaluationParameters := AParameters;
      EvaluationParameters.RuntimeEmote :=
        FStoredSnapshots[High(FStoredSnapshots)].Emote;
      Result := EvaluateSerifDrawAfterAnimation(EvaluationParameters,
        TotalElapsed, AfterElapsed);
      if Result.Visible then
        ARenderSnapshots := System.Copy(FStoredSnapshots, 0,
          Length(FStoredSnapshots))
      else
      begin
        FStage := sdasHidden;
        FStoredSnapshots := nil;
        FCurrentKey := '';
      end;
    end
    else
    begin
      Result := TSerifDrawAnimationTransform.Identity;
      Result.Alpha := 0.0;
      Result.Visible := False;
    end;
  end;
  FLastFrame := ACurrentFrame;
end;

end.
