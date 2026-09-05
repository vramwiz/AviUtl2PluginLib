unit MmdD3DViewportInputState;

// D3D Viewportの固定視点キー押下状態とボーン固定状態を保持する。

interface

uses
  MmdD3DInteraction;

type
  TMmdPressedViewKeys = set of Byte;
  TMmdD3DViewportInputState = class
  private
    FBoneLocks: TArray<Boolean>;
    FFixedViewOpposite: Boolean;
    FLastFixedViewKey: Word;
    FPressedViewKeys: TMmdPressedViewKeys;
  public
    // モデル変更時にボーン数へ合わせて固定状態を全解除する。
    procedure ResetBoneLocks(BoneCount: Integer);
    // 指定ボーンが有効範囲内で固定されているか返す。
    function IsBoneLocked(BoneIndex: Integer): Boolean;
    // 指定ボーンの固定状態を反転し、変更後の状態を返す。範囲外ならFalseを返す。
    function ToggleBoneLock(BoneIndex: Integer): Boolean;
    // A/S/D/Lの初回押下を解釈する。処理対象ならTrueと視点・固定操作を返す。
    function KeyDown(Key: Word; TargetDragging: Boolean;
      out View: TMmdFixedView; out ApplyView, ToggleLock: Boolean): Boolean;
    // 対応キーの離上を記録し、次回押下を受理できる状態へ戻す。
    procedure KeyUp(Key: Word);
    property FixedViewOpposite: Boolean read FFixedViewOpposite;
  end;

implementation

procedure TMmdD3DViewportInputState.ResetBoneLocks(BoneCount: Integer);
begin
  if BoneCount < 0 then
    BoneCount := 0;
  SetLength(FBoneLocks, BoneCount);
end;

function TMmdD3DViewportInputState.IsBoneLocked(BoneIndex: Integer): Boolean;
begin
  Result := (BoneIndex >= 0) and (BoneIndex < Length(FBoneLocks)) and
    FBoneLocks[BoneIndex];
end;

function TMmdD3DViewportInputState.ToggleBoneLock(
  BoneIndex: Integer): Boolean;
begin
  Result := False;
  if (BoneIndex < 0) or (BoneIndex >= Length(FBoneLocks)) then
    Exit;
  FBoneLocks[BoneIndex] := not FBoneLocks[BoneIndex];
  Result := FBoneLocks[BoneIndex];
end;

function TMmdD3DViewportInputState.KeyDown(Key: Word;
  TargetDragging: Boolean; out View: TMmdFixedView;
  out ApplyView, ToggleLock: Boolean): Boolean;
begin
  Result := False;
  ApplyView := False;
  ToggleLock := False;
  if TargetDragging or
    not (Key in [Ord('A'), Ord('S'), Ord('D'), Ord('L')]) then
    Exit;
  Result := True;
  if Byte(Key) in FPressedViewKeys then
    Exit;
  Include(FPressedViewKeys, Byte(Key));
  ToggleLock := Key = Ord('L');
  if ToggleLock then
    Exit;
  ApplyView := True;
  if Key = FLastFixedViewKey then
    FFixedViewOpposite := not FFixedViewOpposite
  else
  begin
    FLastFixedViewKey := Key;
    FFixedViewOpposite := False;
  end;
  case Key of
    Ord('A'): View := fvFront;
    Ord('S'): View := fvSide;
  else
    View := fvVertical;
  end;
end;

procedure TMmdD3DViewportInputState.KeyUp(Key: Word);
begin
  if Key in [Ord('A'), Ord('S'), Ord('D'), Ord('L')] then
    Exclude(FPressedViewKeys, Byte(Key));
end;

end.
