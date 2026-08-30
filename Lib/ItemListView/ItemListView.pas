unit ItemListView;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math,
  System.Types, System.Generics.Collections,
  Vcl.Controls, Vcl.Graphics, Vcl.StdCtrls, VerticalScrollBarControl;

type
  TItemListLayout = (illRow, illIcon);
  TItemListSelectionStyle = (ilssRow, ilssImageOverlay);

  // ネイティブ ListView に依存しない、縦型一覧表示の共通基盤。
  // データは保持せず、派生クラスが件数・文字列・画像を提供する。
  TCustomItemListView = class(TCustomControl)
  private
    FItemIndex: Integer;
    FHotIndex: Integer;
    FScrollOffset: Integer;
    FRowHeight: Integer;
    FImageSize: Integer;
    FLayout: TItemListLayout;
    FCaptionVisible: Boolean;
    FWheelScrollRows: Integer;
    FMultiSelect: Boolean;
    FEdit: TEdit;
    FEditIndex: Integer;
    FOnSelectionChanged: TNotifyEvent;
    FScrollBar: TVerticalScrollBarControl;
    FSelectedIndices: TList<Integer>;
    FSelectionAnchor: Integer;
    FSelectionStyle: TItemListSelectionStyle;
    procedure SetItemIndex(const Value: Integer);
    procedure SetRowHeight(const Value: Integer);
    procedure SetImageSize(const Value: Integer);
    procedure SetLayout(const Value: TItemListLayout);
    procedure SetCaptionVisible(const Value: Boolean);
    procedure SetWheelScrollRows(const Value: Integer);
    procedure SetScrollOffset(const Value: Integer);
    procedure SetSelectionStyle(const Value: TItemListSelectionStyle);
    procedure EditExit(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    function GetCaptionEditing: Boolean;
    function GetMaxScrollOffset: Integer;
    procedure InvalidateContent;
    procedure UpdateScrollBar;
    procedure ScrollBarChange(Sender: TObject);
    procedure SelectFromMouse(Index: Integer; Shift: TShiftState);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure SetParent(AParent: TWinControl); override;
    function GetItemCount: Integer; virtual; abstract;
    function GetItemText(Index: Integer): string; virtual; abstract;
    procedure SetItemText(Index: Integer; const Value: string); virtual;
    procedure DrawItemImage(Index: Integer; const Bounds: TRect;
      Target: TCanvas); virtual;
    procedure DrawItem(Index: Integer; const Bounds: TRect); virtual;
    procedure DrawImageSelectionOverlay(const Bounds: TRect); virtual;
    function GetItemSelected(Index: Integer): Boolean; virtual;
    function ItemImageRect(Index: Integer): TRect;
    function ItemTextRect(Index: Integer): TRect;
    procedure SelectionChanged; virtual;
    procedure EndAuxiliaryEdit; virtual;
    procedure Paint; override;
    procedure Resize; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure WMLButtonDown(var Message: TWMLButtonDown); message WM_LBUTTONDOWN;
    procedure WMRButtonDown(var Message: TWMRButtonDown); message WM_RBUTTONDOWN;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    function ScaleValue(Value: Integer): Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure InvalidateList;
    procedure ReloadItem(Index: Integer);
    procedure EnsureVisible(Index: Integer);
    procedure BeginEdit(Index: Integer);
    procedure EndEdit(Accept: Boolean = True);
    function ItemAtPos(const P: TPoint): Integer;
    function ItemRect(Index: Integer): TRect;
    function TopIndex: Integer;
    procedure SetTopIndex(Index: Integer);
    procedure ClearSelection;
    procedure GetSelectedIndices(Dest: TList<Integer>);
    procedure SetSelectedIndices(Source: TList<Integer>; PrimaryIndex: Integer = -1);
    function SelectedCount: Integer;
    property DisplayCount: Integer read GetItemCount;
    property CaptionVisible: Boolean read FCaptionVisible
      write SetCaptionVisible;
    property WheelScrollRows: Integer read FWheelScrollRows
      write SetWheelScrollRows;
    property MultiSelect: Boolean read FMultiSelect write FMultiSelect;
    property CaptionEditing: Boolean read GetCaptionEditing;
    // 現在カーソル下にある項目位置を返し、一覧外では-1を返す。
    property HotIndex: Integer read FHotIndex;
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
    property RowHeight: Integer read FRowHeight write SetRowHeight;
    property ImageSize: Integer read FImageSize write SetImageSize;
    property Layout: TItemListLayout read FLayout write SetLayout;
    property ScrollOffset: Integer read FScrollOffset write SetScrollOffset;
    property SelectionStyle: TItemListSelectionStyle read FSelectionStyle
      write SetSelectionStyle;
    property VerticalScrollBar: TVerticalScrollBarControl read FScrollBar;
    property OnSelectionChanged: TNotifyEvent read FOnSelectionChanged
      write FOnSelectionChanged;
  published
    property PopupMenu;
    property OnClick;
    property OnDblClick;
    property OnKeyDown;
  end;

implementation

uses
  AviUtl2StyleColors;

{ TCustomItemListView }

const
  ITEM_CAPTION_FONT_HEIGHT_96 = 12;

procedure TCustomItemListView.CreateParams(var Params: TCreateParams);
begin
  inherited;
  // 子の独自スクロールバー領域を親の再描画対象から除外する。
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

procedure TCustomItemListView.SetParent(AParent: TWinControl);
begin
  inherited;
  if AParent = nil then Exit;

  // Runtime-created controls can retain a font that was already scaled for
  // the system DPI and have it scaled once more when attached to a scaled
  // frame.  Establish the caption font from one 96-DPI logical height after
  // the real parent (and therefore the effective PPI) is known.
  ParentFont := False;
  Font.Height := -MulDiv(ITEM_CAPTION_FONT_HEIGHT_96, AParent.CurrentPPI, 96);
end;

constructor TCustomItemListView.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  DoubleBuffered := True;
  BevelOuter := bvNone;
  BevelKind := bkSoft;
  BevelWidth := 1;
  TabStop := True;
  Color := A2SCListViewBackground;
  Font.Color := A2SCListViewText;
  FItemIndex := -1;
  FHotIndex := -1;
  FEditIndex := -1;
  FSelectionAnchor := -1;
  FSelectionStyle := ilssRow;
  FSelectedIndices := TList<Integer>.Create;
  FRowHeight := ScaleValue(104);
  FImageSize := ScaleValue(96);
  FLayout := illRow;
  FCaptionVisible := True;
  FWheelScrollRows := 3;
  FScrollBar := TVerticalScrollBarControl.Create(Self);
  FScrollBar.Parent := Self;
  FScrollBar.Align := alRight;
  FScrollBar.Width := ScaleValue(12);
  FScrollBar.BackgroundColor := A2SCListViewBackground;
  FScrollBar.TrackColor := $002C4A66;
  FScrollBar.ThumbColor := $004691DA;
  FScrollBar.OnChange := ScrollBarChange;
end;

destructor TCustomItemListView.Destroy;
begin
  FreeAndNil(FEdit);
  FreeAndNil(FScrollBar);
  FreeAndNil(FSelectedIndices);
  inherited;
end;

function TCustomItemListView.ScaleValue(Value: Integer): Integer;
begin
  Result := MulDiv(Value, CurrentPPI, 96);
end;

procedure TCustomItemListView.Paint;
var
  Index, FirstIndex, LastIndex: Integer;
  R: TRect;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  if (FRowHeight <= 0) or (GetItemCount = 0) then Exit;
  FirstIndex := Max(0, FScrollOffset div FRowHeight);
  LastIndex := Min(GetItemCount - 1,
    (FScrollOffset + ClientHeight) div FRowHeight);
  for Index := FirstIndex to LastIndex do
  begin
    R := ItemRect(Index);
    if R.Bottom >= 0 then
      DrawItem(Index, R);
  end;
end;

procedure TCustomItemListView.DrawItem(Index: Integer; const Bounds: TRect);
var
  R, ImageBounds, TextBounds: TRect;
  Background, TextColor: TColor;
  Selected: Boolean;
  TextFlags: Cardinal;
begin
  R := Bounds;
  Selected := GetItemSelected(Index);
  if Selected and (FSelectionStyle = ilssRow) then
  begin
    Background := A2SCListViewSelection;
    TextColor := A2SCListViewSelectionText;
  end
  else if Index = FHotIndex then
  begin
    Background := A2SCListViewHover;
    TextColor := A2SCListViewText;
  end
  else if Odd(Index) then
  begin
    Background := A2SCListViewAltBackground;
    TextColor := A2SCListViewText;
  end
  else
  begin
    Background := A2SCListViewBackground;
    TextColor := A2SCListViewText;
  end;

  Canvas.Brush.Color := Background;
  Canvas.FillRect(R);

  ImageBounds := ItemImageRect(Index);
  DrawItemImage(Index, ImageBounds, Canvas);
  if Selected and (FSelectionStyle = ilssImageOverlay) then
    DrawImageSelectionOverlay(ImageBounds);

  if FCaptionVisible then
  begin
    TextBounds := ItemTextRect(Index);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Assign(Font);
    Canvas.Font.Color := TextColor;
    TextFlags := DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX;
    if FLayout = illIcon then
      TextFlags := TextFlags or DT_CENTER
    else
      TextFlags := TextFlags or DT_LEFT;
    DrawText(Canvas.Handle, PChar(GetItemText(Index)), -1, TextBounds,
      TextFlags);
    Canvas.Brush.Style := bsSolid;
  end;

  Canvas.Pen.Color := A2SCToolBarBackground;
  Canvas.MoveTo(R.Left, R.Bottom - 1);
  Canvas.LineTo(R.Right, R.Bottom - 1);
end;

procedure TCustomItemListView.DrawImageSelectionOverlay(
  const Bounds: TRect);
var
  Blend: BLENDFUNCTION;
  Overlay: TBitmap;
begin
  if (Bounds.Right <= Bounds.Left) or (Bounds.Bottom <= Bounds.Top) then
    Exit;
  Overlay := TBitmap.Create;
  try
    Overlay.PixelFormat := pf32bit;
    Overlay.SetSize(Bounds.Width, Bounds.Height);
    Overlay.Canvas.Brush.Color := RGB(70, 120, 220);
    Overlay.Canvas.FillRect(Rect(0, 0, Overlay.Width, Overlay.Height));
    Blend.BlendOp := AC_SRC_OVER;
    Blend.BlendFlags := 0;
    Blend.SourceConstantAlpha := 72;
    Blend.AlphaFormat := 0;
    AlphaBlend(Canvas.Handle, Bounds.Left, Bounds.Top, Bounds.Width,
      Bounds.Height, Overlay.Canvas.Handle, 0, 0, Overlay.Width,
      Overlay.Height, Blend);
  finally
    Overlay.Free;
  end;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := RGB(110, 160, 255);
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(Bounds);
  Canvas.Brush.Style := bsSolid;
end;

function TCustomItemListView.GetItemSelected(Index: Integer): Boolean;
begin
  Result := FSelectedIndices.IndexOf(Index) >= 0;
end;

function TCustomItemListView.ItemImageRect(Index: Integer): TRect;
var
  ItemBounds: TRect;
  Side: Integer;
begin
  ItemBounds := ItemRect(Index);
  Side := Min(FImageSize, Max(0, ItemBounds.Width - ScaleValue(8)));
  if FLayout = illIcon then
    Result := Rect(ItemBounds.Left + (ItemBounds.Width - Side) div 2,
      ItemBounds.Top + ScaleValue(4),
      ItemBounds.Left + (ItemBounds.Width + Side) div 2,
      ItemBounds.Top + ScaleValue(4) + Side)
  else
    Result := Rect(ItemBounds.Left + ScaleValue(4),
      ItemBounds.Top + ScaleValue(4), ItemBounds.Left + ScaleValue(4) + Side,
      ItemBounds.Top + ScaleValue(4) + Side);
end;

function TCustomItemListView.ItemTextRect(Index: Integer): TRect;
var
  ImageBounds: TRect;
  ItemBounds: TRect;
begin
  if not FCaptionVisible then Exit(Rect(0, 0, 0, 0));
  ItemBounds := ItemRect(Index);
  ImageBounds := ItemImageRect(Index);
  if FLayout = illIcon then
    Result := Rect(ItemBounds.Left + ScaleValue(4),
      ImageBounds.Bottom + ScaleValue(2), ItemBounds.Right - ScaleValue(4),
      ItemBounds.Bottom - ScaleValue(3))
  else
    Result := Rect(ImageBounds.Right + ScaleValue(10), ItemBounds.Top,
      ItemBounds.Right - ScaleValue(8), ItemBounds.Bottom);
end;

procedure TCustomItemListView.DrawItemImage(Index: Integer;
  const Bounds: TRect; Target: TCanvas);
begin
  Target.Brush.Color := A2SCListViewAltBackground;
  Target.FillRect(Bounds);
end;

procedure TCustomItemListView.SetItemText(Index: Integer; const Value: string);
begin
end;

function TCustomItemListView.ItemRect(Index: Integer): TRect;
var
  ContentRight: Integer;
  TopPos: Integer;
begin
  TopPos := Index * FRowHeight - FScrollOffset;
  ContentRight := ClientWidth;
  if Assigned(FScrollBar) and FScrollBar.Visible then
    Dec(ContentRight, FScrollBar.Width);
  Result := Rect(0, TopPos, Max(ContentRight, 0), TopPos + FRowHeight);
end;

function TCustomItemListView.ItemAtPos(const P: TPoint): Integer;
begin
  Result := -1;
  if (P.X < 0) or (P.X >= ClientWidth) or (P.Y < 0) or
     (P.Y >= ClientHeight) or (FRowHeight <= 0) then Exit;
  Result := (P.Y + FScrollOffset) div FRowHeight;
  if Result >= GetItemCount then
    Result := -1;
end;

procedure TCustomItemListView.SetItemIndex(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := Value;
  if (NewValue < -1) or (NewValue >= GetItemCount) then
    NewValue := -1;
  if (FItemIndex = NewValue) and
     (((NewValue < 0) and (FSelectedIndices.Count = 0)) or
      ((NewValue >= 0) and (FSelectedIndices.Count = 1) and
       (FSelectedIndices[0] = NewValue))) then Exit;
  EndEdit(True);
  EndAuxiliaryEdit;
  FItemIndex := NewValue;
  FSelectedIndices.Clear;
  if FItemIndex >= 0 then FSelectedIndices.Add(FItemIndex);
  FSelectionAnchor := FItemIndex;
  EnsureVisible(FItemIndex);
  Invalidate;
  SelectionChanged;
end;

procedure TCustomItemListView.SelectionChanged;
begin
  if Assigned(FOnSelectionChanged) then
    FOnSelectionChanged(Self);
end;

procedure TCustomItemListView.WMLButtonDown(var Message: TWMLButtonDown);
var
  Index: Integer;
  Shift: TShiftState;
begin
  SetFocus;
  Index := ItemAtPos(Point(Message.XPos, Message.YPos));
  Shift := [];
  if (Message.Keys and MK_SHIFT) <> 0 then Include(Shift, ssShift);
  if (Message.Keys and MK_CONTROL) <> 0 then Include(Shift, ssCtrl);
  if Index <> -1 then SelectFromMouse(Index, Shift);
  inherited;
end;

procedure TCustomItemListView.WMRButtonDown(var Message: TWMRButtonDown);
var
  Index: Integer;
begin
  SetFocus;
  Index := ItemAtPos(Point(Message.XPos, Message.YPos));
  if (Index <> -1) and ((not FMultiSelect) or not GetItemSelected(Index)) then
    ItemIndex := Index;
  inherited;
end;

procedure TCustomItemListView.SelectFromMouse(Index: Integer;
  Shift: TShiftState);
var
  I, FirstIndex, LastIndex: Integer;
begin
  if (Index < 0) or (Index >= GetItemCount) then Exit;
  EndEdit(True);
  EndAuxiliaryEdit;

  if FMultiSelect and (ssShift in Shift) then
  begin
    if FSelectionAnchor < 0 then FSelectionAnchor := Index;
    FSelectedIndices.Clear;
    FirstIndex := Min(FSelectionAnchor, Index);
    LastIndex := Max(FSelectionAnchor, Index);
    for I := FirstIndex to LastIndex do FSelectedIndices.Add(I);
    FItemIndex := Index;
  end
  else if FMultiSelect and (ssCtrl in Shift) then
  begin
    I := FSelectedIndices.IndexOf(Index);
    if I >= 0 then
    begin
      FSelectedIndices.Delete(I);
      if FItemIndex = Index then
        if FSelectedIndices.Count > 0 then
          FItemIndex := FSelectedIndices[FSelectedIndices.Count - 1]
        else
          FItemIndex := -1;
    end
    else
    begin
      FSelectedIndices.Add(Index);
      FItemIndex := Index;
    end;
    FSelectionAnchor := Index;
  end
  else
  begin
    FSelectedIndices.Clear;
    FSelectedIndices.Add(Index);
    FItemIndex := Index;
    FSelectionAnchor := Index;
  end;

  EnsureVisible(FItemIndex);
  Invalidate;
  SelectionChanged;
end;

procedure TCustomItemListView.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewHot: Integer;
begin
  inherited;
  NewHot := ItemAtPos(Point(X, Y));
  if NewHot <> FHotIndex then
  begin
    FHotIndex := NewHot;
    Invalidate;
  end;
end;

procedure TCustomItemListView.CMMouseLeave(var Message: TMessage);
begin
  if FHotIndex <> -1 then
  begin
    FHotIndex := -1;
    Invalidate;
  end;
  inherited;
end;

procedure TCustomItemListView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_UP:
      if Shift = [] then
      begin
        if FItemIndex < 0 then ItemIndex := 0
        else ItemIndex := Max(0, FItemIndex - 1);
        Key := 0;
      end;
    VK_DOWN:
      if Shift = [] then
      begin
        if FItemIndex < 0 then ItemIndex := 0
        else ItemIndex := Min(GetItemCount - 1, FItemIndex + 1);
        Key := 0;
      end;
    VK_HOME:
      if Shift = [] then begin ItemIndex := 0; Key := 0; end;
    VK_END:
      if Shift = [] then begin ItemIndex := GetItemCount - 1; Key := 0; end;
  end;
  inherited;
end;

function TCustomItemListView.GetMaxScrollOffset: Integer;
var
  ViewHeight: Integer;
begin
  // Parent接続前のコンストラクタではClientHeightがHandleNeededを呼び、
  // 親ウィンドウなしのハンドル生成でInvalidControlOperationになる。
  if HandleAllocated then
    ViewHeight := ClientHeight
  else
    ViewHeight := Height;
  Result := Max(0, GetItemCount * FRowHeight - ViewHeight);
end;

procedure TCustomItemListView.SetScrollOffset(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := EnsureRange(Value, 0, GetMaxScrollOffset);
  if FScrollOffset = NewValue then Exit;
  EndEdit(True);
  EndAuxiliaryEdit;
  FScrollOffset := NewValue;
  if Assigned(FScrollBar) and (FScrollBar.Position <> FScrollOffset) then
    FScrollBar.Position := FScrollOffset;
  // 親全体を無効化すると、子の独自スクロールバーまで同時に再描画され、
  // ドラッグ中につまみがちらつく。行表示領域だけを更新する。
  InvalidateContent;
end;

procedure TCustomItemListView.SetSelectionStyle(
  const Value: TItemListSelectionStyle);
begin
  if FSelectionStyle = Value then Exit;
  FSelectionStyle := Value;
  Invalidate;
end;

procedure TCustomItemListView.InvalidateContent;
var
  R: TRect;
begin
  if not HandleAllocated then
  begin
    Invalidate;
    Exit;
  end;
  R := ClientRect;
  if Assigned(FScrollBar) and FScrollBar.Visible then
    R.Right := Max(R.Left, R.Right - FScrollBar.Width);
  Winapi.Windows.InvalidateRect(Handle, @R, False);
end;

procedure TCustomItemListView.UpdateScrollBar;
begin
  if not Assigned(FScrollBar) then Exit;
  FScrollBar.Width := ScaleValue(12);
  FScrollBar.SetRange(GetItemCount * FRowHeight,
    Max(Height, 1), Max(1, FRowHeight * FWheelScrollRows));
  FScrollBar.Position := FScrollOffset;
end;

procedure TCustomItemListView.ScrollBarChange(Sender: TObject);
begin
  if Assigned(FScrollBar) then ScrollOffset := FScrollBar.Position;
end;

procedure TCustomItemListView.WMMouseWheel(var Message: TWMMouseWheel);
begin
  ScrollOffset := FScrollOffset - MulDiv(Message.WheelDelta,
    Max(1, FRowHeight * FWheelScrollRows), WHEEL_DELTA);
  Message.Result := 1;
end;

procedure TCustomItemListView.EnsureVisible(Index: Integer);
var
  R: TRect;
begin
  if Index < 0 then Exit;
  R := ItemRect(Index);
  if R.Top < 0 then
    ScrollOffset := Index * FRowHeight
  else if R.Bottom > ClientHeight then
    ScrollOffset := Index * FRowHeight + FRowHeight - ClientHeight;
end;

procedure TCustomItemListView.BeginEdit(Index: Integer);
var
  R: TRect;
begin
  if not FCaptionVisible then Exit;
  if (Index < 0) or (Index >= GetItemCount) then Exit;
  EndAuxiliaryEdit;
  EnsureVisible(Index);
  if FEdit = nil then
  begin
    FEdit := TEdit.Create(Self);
    FEdit.Parent := Self;
    FEdit.AutoSize := False;
    FEdit.Color := A2SCEditBackground;
    FEdit.Font.Color := A2SCEditText;
    FEdit.OnExit := EditExit;
    FEdit.OnKeyDown := EditKeyDown;
  end;
  FEditIndex := Index;
  R := ItemTextRect(Index);
  InflateRect(R, -ScaleValue(2), 0);
  R.Right := Min(R.Right, ClientWidth);
  R.Bottom := Min(R.Bottom, ClientHeight);
  FEdit.SetBounds(Max(0, R.Left), Max(0, R.Top), Max(1, R.Width),
    Max(1, R.Height));
  FEdit.Text := GetItemText(Index);
  FEdit.Visible := True;
  FEdit.SelectAll;
  FEdit.SetFocus;
end;

function TCustomItemListView.TopIndex: Integer;
begin
  if FRowHeight <= 0 then Exit(0);
  Result := FScrollOffset div FRowHeight;
end;

procedure TCustomItemListView.SetTopIndex(Index: Integer);
begin
  if Index < 0 then Index := 0;
  ScrollOffset := Index * FRowHeight;
end;

procedure TCustomItemListView.EndEdit(Accept: Boolean);
var
  Index: Integer;
  Value: string;
begin
  if not GetCaptionEditing then Exit;
  Index := FEditIndex;
  Value := FEdit.Text;
  FEditIndex := -1;
  FEdit.Visible := False;
  if Accept and (Index >= 0) then
    SetItemText(Index, Value);
  Invalidate;
end;

procedure TCustomItemListView.EditExit(Sender: TObject);
begin
  EndEdit(True);
end;

procedure TCustomItemListView.EditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    EndEdit(True);
    SetFocus;
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    EndEdit(False);
    SetFocus;
    Key := 0;
  end;
end;

function TCustomItemListView.GetCaptionEditing: Boolean;
begin
  Result := (FEdit <> nil) and FEdit.Visible;
end;

procedure TCustomItemListView.EndAuxiliaryEdit;
begin
end;

procedure TCustomItemListView.InvalidateList;
var
  I: Integer;
begin
  if FItemIndex >= GetItemCount then
    FItemIndex := GetItemCount - 1;
  for I := FSelectedIndices.Count - 1 downto 0 do
    if FSelectedIndices[I] >= GetItemCount then FSelectedIndices.Delete(I);
  if (FItemIndex >= 0) and (FSelectedIndices.IndexOf(FItemIndex) < 0) then
    FSelectedIndices.Add(FItemIndex);
  FScrollOffset := EnsureRange(FScrollOffset, 0, GetMaxScrollOffset);
  UpdateScrollBar;
  Invalidate;
end;

procedure TCustomItemListView.ClearSelection;
begin
  EndEdit(True);
  EndAuxiliaryEdit;
  FItemIndex := -1;
  FSelectionAnchor := -1;
  FSelectedIndices.Clear;
  Invalidate;
  SelectionChanged;
end;

procedure TCustomItemListView.GetSelectedIndices(Dest: TList<Integer>);
begin
  if Dest = nil then Exit;
  Dest.Clear;
  Dest.AddRange(FSelectedIndices);
  Dest.Sort;
end;

function TCustomItemListView.SelectedCount: Integer;
begin
  Result := FSelectedIndices.Count;
end;

procedure TCustomItemListView.SetSelectedIndices(Source: TList<Integer>;
  PrimaryIndex: Integer);
var
  I, Index: Integer;
begin
  EndEdit(True);
  EndAuxiliaryEdit;
  FSelectedIndices.Clear;
  if Source <> nil then
    for I := 0 to Source.Count - 1 do
    begin
      Index := Source[I];
      if (Index >= 0) and (Index < GetItemCount) and
         (FSelectedIndices.IndexOf(Index) < 0) then
        FSelectedIndices.Add(Index);
    end;
  if (PrimaryIndex >= 0) and (FSelectedIndices.IndexOf(PrimaryIndex) >= 0) then
    FItemIndex := PrimaryIndex
  else if FSelectedIndices.Count > 0 then
    FItemIndex := FSelectedIndices[0]
  else
    FItemIndex := -1;
  FSelectionAnchor := FItemIndex;
  EnsureVisible(FItemIndex);
  Invalidate;
  SelectionChanged;
end;

procedure TCustomItemListView.ReloadItem(Index: Integer);
var
  R: TRect;
begin
  if (Index < 0) or (Index >= GetItemCount) then Exit;
  R := ItemRect(Index);
  InvalidateRect(Handle, @R, False);
end;

procedure TCustomItemListView.SetRowHeight(const Value: Integer);
begin
  if Value <= 0 then Exit;
  if FRowHeight = Value then Exit;
  FRowHeight := Value;
  InvalidateList;
end;

procedure TCustomItemListView.SetImageSize(const Value: Integer);
begin
  if Value <= 0 then Exit;
  if FImageSize = Value then Exit;
  FImageSize := Value;
  Invalidate;
end;

procedure TCustomItemListView.SetLayout(const Value: TItemListLayout);
begin
  if FLayout = Value then Exit;
  EndEdit(True);
  EndAuxiliaryEdit;
  FLayout := Value;
  InvalidateList;
end;

procedure TCustomItemListView.SetCaptionVisible(const Value: Boolean);
begin
  if FCaptionVisible = Value then Exit;
  EndEdit(True);
  FCaptionVisible := Value;
  InvalidateList;
end;

procedure TCustomItemListView.SetWheelScrollRows(const Value: Integer);
begin
  if Value < 1 then Exit;
  if FWheelScrollRows = Value then Exit;
  FWheelScrollRows := Value;
  UpdateScrollBar;
end;

procedure TCustomItemListView.Resize;
begin
  inherited;
  InvalidateList;
end;

procedure TCustomItemListView.CMFontChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;

end.
