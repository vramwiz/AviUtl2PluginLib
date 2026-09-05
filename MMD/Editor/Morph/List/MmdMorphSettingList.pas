unit MmdMorphSettingList;

// モーフ名、ウェイト、操作方式を仮想行で一覧編集する再利用可能GUI。

interface

uses
  System.Classes,
  System.Types,
  System.UITypes,
  Vcl.Controls,
  MmdMorphSettingRows,
  MmdMorphSettingValue,
  PmxModel,
  PmxMorph,
  VerticalScrollBarControl;

type
  // 分類見出しを含む仮想一覧として、モデル単位のモーフウェイトを編集する。
  TMmdMorphSettingList = class(TCustomControl)
  private
    FActiveRow: Integer;
    FDragging: Boolean;
    FEditingEnabled: Boolean;
    FModes: TMmdMorphControlModes;
    FModel: TPmxModel;
    FOnChange: TNotifyEvent;
    FOnEditFinished: TNotifyEvent;
    FRows: TMmdMorphSettingRows;
    FScrollWheelRemainder: Integer;
    FScrollBar: TVerticalScrollBarControl;
    FWeights: TPmxMorphWeights;
    function ContentWidth: Integer;
    function RowAt(Y: Integer): Integer;
    function RowHeight: Integer;
    function RowRect(Index: Integer): TRect;
    procedure ScrollChanged(Sender: TObject);
    procedure SetEditingEnabled(Value: Boolean);
    procedure SetWeightFromX(Index, X: Integer);
    function TrackHitRect(Index: Integer): TRect;
    function TrackRect(Index: Integer): TRect;
    procedure ToggleMode(Index: Integer);
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
    procedure Resize; override;
  public
    // 暗色テーマ、DPI対応寸法、独自縦スクロールバーを持つ空の一覧を生成する。
    constructor Create(AOwner: TComponent); override;
    // 全モーフを0へ戻し、変更通知と編集完了通知を発行する。
    procedure ClearWeights;
    // 現在の連続値／2値操作方式をモーフ番号順の配列として複製する。
    procedure CopyModes(out Modes: TMmdMorphControlModes);
    // 現在のウェイトをモーフ番号順の配列として複製する。
    procedure CopyWeights(out Weights: TPmxMorphWeights);
    // モデルのモーフ数に合わせて、外部から渡されたウェイトを0～1へ制限して設定する。
    procedure SetWeights(const Weights: TPmxMorphWeights);
    // 読取専用PMXモデルを接続し、ウェイト、操作方式、分類行、スクロール位置を初期化する。
    procedure SetModel(AModel: TPmxModel);
    // Falseの場合は一覧表示を維持したまま、ウェイト変更操作を無効にする。
    property EditingEnabled: Boolean read FEditingEnabled write SetEditingEnabled;
    // ウェイトが実際に変化した場合に通知する。
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    // ドラッグ完了、全解除、操作方式切替など、連続編集の区切りで通知する。
    property OnEditFinished: TNotifyEvent read FOnEditFinished write FOnEditFinished;
  published
    property Font;
    property ParentFont;
  end;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils,
  MmdMorphSettingListRenderer,
  MmdPoseEditorTheme;

function MorphScale(Value, PPI: Integer): Integer;
begin
  Result := MulDiv(Value, PPI, 96);
end;

constructor TMmdMorphSettingList.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse, csClickEvents];
  DoubleBuffered := True;
  TabStop := True;
  Color := MmdEditorBackground;
  Font.Color := MmdEditorText;
  FActiveRow := -1;
  FEditingEnabled := True;

  FScrollBar := TVerticalScrollBarControl.Create(Self);
  FScrollBar.Parent := Self;
  FScrollBar.Align := alRight;
  FScrollBar.Width := MorphScale(14, CurrentPPI);
  FScrollBar.BackgroundColor := MmdEditorBackground;
  FScrollBar.TrackColor := MmdEditorBorder;
  FScrollBar.ThumbColor := MmdEditorSelection;
  FScrollBar.OnChange := ScrollChanged;
end;

function TMmdMorphSettingList.ContentWidth: Integer;
begin
  Result := ClientWidth;
  if FScrollBar.Visible then
    Dec(Result, FScrollBar.Width + MorphScale(8, CurrentPPI));
  Result := Max(Result, 1);
end;

procedure TMmdMorphSettingList.CopyModes(out Modes: TMmdMorphControlModes);
begin
  Modes := Copy(FModes);
end;

procedure TMmdMorphSettingList.CopyWeights(out Weights: TPmxMorphWeights);
begin
  Weights := Copy(FWeights);
end;

procedure TMmdMorphSettingList.ClearWeights;
begin
  if FModel = nil then
    Exit;
  InitializeMorphWeights(FModel, FWeights);
  Invalidate;
  if Assigned(FOnChange) then
    FOnChange(Self);
  if Assigned(FOnEditFinished) then
    FOnEditFinished(Self);
end;

function TMmdMorphSettingList.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  Steps: Integer;
begin
  Result := WheelDelta <> 0;
  if not Result then
    Exit(inherited DoMouseWheel(Shift, WheelDelta, MousePos));
  Inc(FScrollWheelRemainder, WheelDelta);
  Steps := FScrollWheelRemainder div WHEEL_DELTA;
  FScrollWheelRemainder := FScrollWheelRemainder mod WHEEL_DELTA;
  if Steps <> 0 then
    FScrollBar.Position := FScrollBar.Position - Steps * RowHeight * 3;
end;

procedure TMmdMorphSettingList.KeyDown(var Key: Word; Shift: TShiftState);
var
  Delta, MorphIndex, NextRow: Integer;
begin
  if Length(FRows) = 0 then
  begin
    inherited;
    Exit;
  end;
  if FActiveRow < 0 then
    FActiveRow := FindSelectableMorphRow(FRows, 0, 1);
  case Key of
    VK_UP:
      begin
        NextRow := FindSelectableMorphRow(FRows, FActiveRow - 1, -1);
        if NextRow >= 0 then FActiveRow := NextRow;
      end;
    VK_DOWN:
      begin
        NextRow := FindSelectableMorphRow(FRows, FActiveRow + 1, 1);
        if NextRow >= 0 then FActiveRow := NextRow;
      end;
    VK_LEFT, VK_RIGHT:
      begin
        if not FEditingEnabled then
          Exit;
        MorphIndex := MorphIndexAtSettingRow(FRows, FActiveRow);
        if MorphIndex < 0 then Exit;
        if FModes[MorphIndex] = mcmToggle then
          Delta := 100
        else
          Delta := 1;
        if Key = VK_LEFT then
          Delta := -Delta;
        FWeights[MorphIndex] := EnsureRange(
          Round(FWeights[MorphIndex] * 100) + Delta, 0, 100) / 100;
        if Assigned(FOnChange) then
          FOnChange(Self);
      end;
    VK_RETURN, VK_SPACE:
      if FEditingEnabled then
      begin
        MorphIndex := MorphIndexAtSettingRow(FRows, FActiveRow);
        if MorphIndex >= 0 then ToggleMode(MorphIndex);
      end;
  else
    inherited;
    Exit;
  end;
  FScrollBar.Position := EnsureRange(FActiveRow * RowHeight -
    (ClientHeight - RowHeight) div 2, 0, FScrollBar.Maximum);
  Invalidate;
  Key := 0;
end;

procedure TMmdMorphSettingList.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Index: Integer;
begin
  inherited;
  if Button <> mbLeft then
    Exit;
  if CanFocus then
    SetFocus;
  Index := RowAt(Y);
  if MorphIndexAtSettingRow(FRows, Index) < 0 then
    Exit;
  FActiveRow := Index;
  // つまみの外周まで開始判定に含める。値の計算側で端へ丸めるため、
  // 左右端ぎりぎりのクリックはそれぞれ最小値・最大値になる。
  if FEditingEnabled and PtInRect(TrackHitRect(Index), Point(X, Y)) then
  begin
    FDragging := True;
    MouseCapture := True;
    SetWeightFromX(Index, X);
  end;
  Invalidate;
end;

procedure TMmdMorphSettingList.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FDragging and (FActiveRow >= 0) then
    SetWeightFromX(FActiveRow, X);
end;

procedure TMmdMorphSettingList.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button <> mbLeft then
    Exit;
  if FDragging then
  begin
    FDragging := False;
    MouseCapture := False;
    if Assigned(FOnEditFinished) then
      FOnEditFinished(Self);
  end;
end;

procedure TMmdMorphSettingList.Paint;
var
  FirstIndex, Index, LastIndex, MorphIndex, PPI: Integer;
  R, TrackBounds: TRect;
begin
  Canvas.Brush.Color := MmdEditorBackground;
  Canvas.FillRect(ClientRect);
  if (FModel = nil) or (Length(FRows) = 0) then
    Exit;
  PPI := CurrentPPI;
  FirstIndex := Max(FScrollBar.Position div RowHeight, 0);
  LastIndex := Min((FScrollBar.Position + ClientHeight) div RowHeight,
    High(FRows));
  Canvas.Font.Assign(Font);
  for Index := FirstIndex to LastIndex do
  begin
    R := RowRect(Index);
    if FRows[Index].Kind = msrkHeader then
    begin
      DrawMorphSettingHeader(Canvas, R, ContentWidth, PPI, FRows[Index].Panel);
      Continue;
    end;
    MorphIndex := FRows[Index].MorphIndex;
    TrackBounds := TrackRect(Index);
    DrawMorphSettingRow(Canvas, R, TrackBounds, PPI,
      FModel.Morphs[MorphIndex].Name, FWeights[MorphIndex], FEditingEnabled,
      Index = FActiveRow, Odd(Index));
  end;
end;

procedure TMmdMorphSettingList.Resize;
begin
  inherited;
  FScrollBar.Width := MorphScale(14, CurrentPPI);
  FScrollBar.SetRange(Length(FRows) * RowHeight, ClientHeight, RowHeight);
end;

function TMmdMorphSettingList.RowAt(Y: Integer): Integer;
begin
  Result := (Y + FScrollBar.Position) div RowHeight;
  if (Result < 0) or (Result >= Length(FRows)) then
    Result := -1;
end;

function TMmdMorphSettingList.RowHeight: Integer;
begin
  Result := MorphScale(30, CurrentPPI);
end;

function TMmdMorphSettingList.RowRect(Index: Integer): TRect;
begin
  Result := Rect(0, Index * RowHeight - FScrollBar.Position,
    ContentWidth, (Index + 1) * RowHeight - FScrollBar.Position);
end;

procedure TMmdMorphSettingList.ScrollChanged(Sender: TObject);
begin
  Invalidate;
end;

procedure TMmdMorphSettingList.SetEditingEnabled(Value: Boolean);
begin
  if FEditingEnabled = Value then
    Exit;
  FEditingEnabled := Value;
  Invalidate;
end;

procedure TMmdMorphSettingList.SetModel(AModel: TPmxModel);
begin
  FModel := AModel;
  FActiveRow := -1;
  if FModel = nil then
  begin
    FWeights := nil;
    FModes := nil;
    FRows := nil;
  end
  else
    InitializeMorphSettingRows(FModel, FWeights, FModes, FRows, FActiveRow);
  FScrollBar.Position := 0;
  FScrollBar.SetRange(Length(FRows) * RowHeight, ClientHeight, RowHeight);
  Invalidate;
end;
procedure TMmdMorphSettingList.SetWeights(const Weights: TPmxMorphWeights);
begin
  if FModel = nil then
    Exit;
  AssignMorphWeights(FModel, Weights, FWeights);
  Invalidate;
end;

procedure TMmdMorphSettingList.SetWeightFromX(Index, X: Integer);
var
  Bounds: TRect;
  MorphIndex: Integer;
  NewWeight: Single;
begin
  MorphIndex := MorphIndexAtSettingRow(FRows, Index);
  if MorphIndex < 0 then
    Exit;
  Bounds := TrackRect(Index);
  NewWeight := MorphWeightFromTrackPosition(FModes[MorphIndex], X, Bounds,
    MorphScale(8, CurrentPPI));
  if Abs(FWeights[MorphIndex] - NewWeight) < 0.0001 then
    Exit;
  FWeights[MorphIndex] := NewWeight;
  Invalidate;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

function TMmdMorphSettingList.TrackRect(Index: Integer): TRect;
var
  R: TRect;
begin
  R := RowRect(Index);
  Result.Left := Max(MorphScale(82, CurrentPPI), ContentWidth div 3);
  Result.Right := ContentWidth - MorphScale(12, CurrentPPI);
  Result.Top := (R.Top + R.Bottom) div 2;
  Result.Bottom := Result.Top;
end;

function TMmdMorphSettingList.TrackHitRect(Index: Integer): TRect;
begin
  Result := TrackRect(Index);
  InflateRect(Result, MorphScale(8, CurrentPPI),
    Max((RowHeight div 2) - MorphScale(2, CurrentPPI), 1));
  Inc(Result.Right);
end;

procedure TMmdMorphSettingList.ToggleMode(Index: Integer);
begin
  if (Index < 0) or (Index >= Length(FModes)) then
    Exit;
  // 材質モーフは表示物のON/OFFとして扱い、連続値へ切り替えない。
  if Assigned(FModel) and
    (FModel.Morphs[Index].MorphType = pmtMaterial) then
    Exit;
  ToggleMorphControlMode(FModes[Index], FWeights[Index]);
  Invalidate;
  if Assigned(FOnChange) then
    FOnChange(Self);
  if Assigned(FOnEditFinished) then
    FOnEditFinished(Self);
end;

end.
