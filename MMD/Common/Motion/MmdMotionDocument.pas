unit MmdMotionDocument;

// VMD等の入力形式から独立した、編集可能なMMDモーション全トラックを定義する。

interface

uses
  System.Generics.Collections,
  PmxModel,
  PmxPoseTypes;

const
  MmdMotionDocumentVersion = 1;
  MmdMotionDefaultFrameRate = 30.0;

type
  TMmdBezierCurve = record
    X1: Byte;
    Y1: Byte;
    X2: Byte;
    Y2: Byte;
  end;
  TMmdMotionBoneKey = record
    Frame: Cardinal;
    Translation: TPmxVector3;
    Rotation: TPmxQuaternion;
    TranslationXCurve: TMmdBezierCurve;
    TranslationYCurve: TMmdBezierCurve;
    TranslationZCurve: TMmdBezierCurve;
    RotationCurve: TMmdBezierCurve;
  end;
  TMmdMotionMorphKey = record
    Frame: Cardinal;
    Weight: Single;
  end;
  TMmdMotionBoneTrack = class
  public
    Name: string;
    Keys: TList<TMmdMotionBoneKey>;
    constructor Create(const AName: string);
    destructor Destroy; override;
  end;
  TMmdMotionMorphTrack = class
  public
    Name: string;
    Keys: TList<TMmdMotionMorphKey>;
    constructor Create(const AName: string);
    destructor Destroy; override;
  end;
  TMmdMotionDocument = class
  private
    FBoneTracks: TObjectList<TMmdMotionBoneTrack>;
    FFrameRate: Single;
    FModelName: string;
    FMorphTracks: TObjectList<TMmdMotionMorphTrack>;
    function GetMaxFrame: Cardinal;
  public
    // 空のトラック集合を30fpsで生成する。
    constructor Create;
    destructor Destroy; override;
    // 編集用に全トラックとキーをディープコピーする。
    function Clone: TMmdMotionDocument;
    property BoneTracks: TObjectList<TMmdMotionBoneTrack> read FBoneTracks;
    property FrameRate: Single read FFrameRate write FFrameRate;
    property MaxFrame: Cardinal read GetMaxFrame;
    property ModelName: string read FModelName write FModelName;
    property MorphTracks: TObjectList<TMmdMotionMorphTrack> read FMorphTracks;
  end;

// MMDの標準線形補間制御点を返す。
function LinearMmdBezierCurve: TMmdBezierCurve;

implementation

constructor TMmdMotionBoneTrack.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  Keys := TList<TMmdMotionBoneKey>.Create;
end;

destructor TMmdMotionBoneTrack.Destroy;
begin
  Keys.Free;
  inherited;
end;

constructor TMmdMotionMorphTrack.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  Keys := TList<TMmdMotionMorphKey>.Create;
end;

destructor TMmdMotionMorphTrack.Destroy;
begin
  Keys.Free;
  inherited;
end;

constructor TMmdMotionDocument.Create;
begin
  inherited;
  FBoneTracks := TObjectList<TMmdMotionBoneTrack>.Create(True);
  FMorphTracks := TObjectList<TMmdMotionMorphTrack>.Create(True);
  FFrameRate := MmdMotionDefaultFrameRate;
end;

destructor TMmdMotionDocument.Destroy;
begin
  FMorphTracks.Free;
  FBoneTracks.Free;
  inherited;
end;

function TMmdMotionDocument.Clone: TMmdMotionDocument;
var
  BoneTrack, NewBoneTrack: TMmdMotionBoneTrack;
  MorphTrack, NewMorphTrack: TMmdMotionMorphTrack;
begin
  Result := TMmdMotionDocument.Create;
  Result.FrameRate := FrameRate;
  Result.ModelName := ModelName;
  for BoneTrack in BoneTracks do
  begin
    NewBoneTrack := TMmdMotionBoneTrack.Create(BoneTrack.Name);
    NewBoneTrack.Keys.AddRange(BoneTrack.Keys.ToArray);
    Result.BoneTracks.Add(NewBoneTrack);
  end;
  for MorphTrack in MorphTracks do
  begin
    NewMorphTrack := TMmdMotionMorphTrack.Create(MorphTrack.Name);
    NewMorphTrack.Keys.AddRange(MorphTrack.Keys.ToArray);
    Result.MorphTracks.Add(NewMorphTrack);
  end;
end;

function TMmdMotionDocument.GetMaxFrame: Cardinal;
var
  BoneTrack: TMmdMotionBoneTrack;
  MorphTrack: TMmdMotionMorphTrack;
begin
  Result := 0;
  for BoneTrack in BoneTracks do
    if (BoneTrack.Keys.Count > 0) and
      (BoneTrack.Keys[BoneTrack.Keys.Count - 1].Frame > Result) then
      Result := BoneTrack.Keys[BoneTrack.Keys.Count - 1].Frame;
  for MorphTrack in MorphTracks do
    if (MorphTrack.Keys.Count > 0) and
      (MorphTrack.Keys[MorphTrack.Keys.Count - 1].Frame > Result) then
      Result := MorphTrack.Keys[MorphTrack.Keys.Count - 1].Frame;
end;

function LinearMmdBezierCurve: TMmdBezierCurve;
begin
  Result.X1 := 20;
  Result.Y1 := 20;
  Result.X2 := 107;
  Result.Y2 := 107;
end;

end.
