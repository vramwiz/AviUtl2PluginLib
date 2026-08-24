// Ctrl+数字へ割り当てる話者と感情を、10列の横スクロール領域へ表示する。
unit SerifVoicevoxShortcutFrame;

interface

uses
  Winapi.Messages, System.Classes, System.Generics.Collections, System.Types,
  Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.Graphics,
  HorizontalScrollBarControl,
  SerifCharaIconRenderer, SerifVoicevoxShortcutSettings,
  SerifVoicevoxSpeakerCatalog, SerifVoicevoxSpeakerMenu;

type
  // 1枠内で話者アイコン、感情名のどこを操作しているかを表す。vsrNumberは全面適用要求に使う。
  TSerifVoicevoxShortcutRegion = (vsrNone, vsrNumber, vsrSpeaker,
    vsrStyle);
  TSerifVoicevoxShortcutItemEvent = procedure(Sender: TObject;
    const Index: Integer; const Region: TSerifVoicevoxShortcutRegion)
    of object;
  TSerifVoicevoxShortcutWheelEvent = procedure(Sender: TObject;
    const Index: Integer; const Region: TSerifVoicevoxShortcutRegion;
    const WheelDelta: Integer) of object;
  TSerifVoicevoxShortcutHintEvent = procedure(Sender: TObject;
    const HintText: string; const ScreenPoint: TPoint;
    const DurationMs: Integer) of object;
  TSerifVoicevoxShortcutApplyEvent = procedure(Sender: TObject;
    const Index: Integer; Speaker: TSerifVoicevoxSpeaker;
    Style: TSerifVoicevoxStyle) of object;

  // 数字、話者アイコン、感情名を縦に並べたショートカット1枠分の表示。
  TSerifVoicevoxShortcutItem = class(TCustomControl)
  private const
    NUMBER_BADGE_HEIGHT = 14;
    NUMBER_BADGE_WIDTH = 12;
    NUMBER_GUTTER_WIDTH = 14;
    STYLE_HEIGHT = 18;
  private
    FHotRegion: TSerifVoicevoxShortcutRegion;
    FApplied: Boolean;
    FIconRenderer: TSerifCharaIconRenderer;
    FIndex: Integer;
    FNumberText: string;
    FOnHintRequest: TSerifVoicevoxShortcutHintEvent;
    FOnRegionClick: TSerifVoicevoxShortcutItemEvent;
    FOnRegionWheel: TSerifVoicevoxShortcutWheelEvent;
    FSpeakerName: string;
    FSpeakerUUID: string;
    FStyleId: Integer;
    FStyleName: string;
    function HintForRegion(
      const Region: TSerifVoicevoxShortcutRegion): string;
    function ValueHint: string;
    function RegionAt(const Point: TPoint): TSerifVoicevoxShortcutRegion;
    procedure RequestHint(const Region: TSerifVoicevoxShortcutRegion;
      const ScreenPoint: TPoint);
    procedure SetApplied(const Value: Boolean);
  protected
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Paint; override;
  public
    // ShortcutIndexはキーボード上段に合わせ、0～8を1～9、9を0として表示する。
    constructor CreateItem(AOwner: TComponent;
      AIconRenderer: TSerifCharaIconRenderer;
      const ShortcutIndex: Integer); reintroduce;
    // 初期表示する話者名と先頭の感情名を設定する。
    procedure SetAssignment(const SpeakerName, SpeakerUUID,
      StyleName: string; const StyleId: Integer);
    property SpeakerUUID: string read FSpeakerUUID;
    property StyleId: Integer read FStyleId;
    // 最後にセリフへ適用した枠を背景の選択色で表示する。
    property Applied: Boolean read FApplied write SetApplied;
    property OnHintRequest: TSerifVoicevoxShortcutHintEvent
      read FOnHintRequest write FOnHintRequest;
    property OnRegionClick: TSerifVoicevoxShortcutItemEvent
      read FOnRegionClick write FOnRegionClick;
    property OnRegionWheel: TSerifVoicevoxShortcutWheelEvent
      read FOnRegionWheel write FOnRegionWheel;
  end;

  TFrameSerifVoicevoxShortcuts = class(TFrame)
  public const
    DEFAULT_HEIGHT = 80;
  private const
    ITEM_COUNT = 10;
    ITEM_WIDTH = 56;
    SCROLL_BAR_HEIGHT = 16;
    SCROLL_BAR_TOP_PADDING = 8;
    SCROLL_BAR_TRACK_COLOR = $002C4A66;
    SCROLL_BAR_THUMB_COLOR = $004691DA;
  private
    FCatalog: TSerifVoicevoxSpeakerCatalog;
    FActiveIndex: Integer;
    FContent: TPanel;
    FIconRenderer: TSerifCharaIconRenderer;
    FItems: TObjectList<TSerifVoicevoxShortcutItem>;
    FMenu: TSerifVoicevoxSpeakerMenu;
    FOnApply: TSerifVoicevoxShortcutApplyEvent;
    FPopupIndex: Integer;
    FSaveTimer: TTimer;
    FScrollBar: THorizontalScrollBarControl;
    FSettings: TSerifVoicevoxShortcutSettings;
    FViewport: TPanel;
    function FindSpeaker(const SpeakerUUID: string): TSerifVoicevoxSpeaker;
    procedure ItemHintRequest(Sender: TObject; const HintText: string;
      const ScreenPoint: TPoint; const DurationMs: Integer);
    procedure ItemRegionClick(Sender: TObject; const Index: Integer;
      const Region: TSerifVoicevoxShortcutRegion);
    procedure ItemRegionWheel(Sender: TObject; const Index: Integer;
      const Region: TSerifVoicevoxShortcutRegion;
      const WheelDelta: Integer);
    procedure LayoutItems;
    procedure MenuSelected(Sender: TObject; Speaker: TSerifVoicevoxSpeaker;
      Style: TSerifVoicevoxStyle);
    procedure SaveTimerTimer(Sender: TObject);
    procedure ScrollPositionChange(Sender: TObject);
    procedure SetActiveIndex(const Index: Integer);
    procedure SetItemAssignment(const Index: Integer;
      Speaker: TSerifVoicevoxSpeaker; Style: TSerifVoicevoxStyle;
      const ScheduleSave: Boolean);
  protected
    procedure Resize; override;
  public
    // 共有アイコン描画器を使い、1～0の10枠と横スクロール領域を生成する。
    constructor CreateWithRenderer(AOwner: TComponent;
      AIconRenderer: TSerifCharaIconRenderer;
      ACatalog: TSerifVoicevoxSpeakerCatalog); reintroduce;
    // 保存待ちの割り当てを確定し、メニューと設定ストアを解放する。
    destructor Destroy; override;
    // 枠の高さと各ショートカット列を現在のモニターDPIへ合わせる。
    procedure ApplyDpi;
    // 手動の話者・感情変更時に、最後に適用した枠の選択色を解除する。
    procedure ClearApplied;
    // 旧プロジェクトを保存してから指定した音声合成プロジェクトの割り当てを読み込む。
    procedure OpenProject(const ProjectFolder: string);
    // 遅延保存待ちのショートカット割り当てを直ちに保存する。
    procedure Save;
    // 数字クリックまたはキー操作から指定枠の話者・感情を適用要求として通知する。
    procedure RequestApply(const Index: Integer);
    // styleを持つ話者を登録順に割り当て、不足分は先頭へ戻って10枠を埋める。
    procedure ShowCatalog(const Catalog: TSerifVoicevoxSpeakerCatalog);
    // 数字クリックまたはショートカットで解決した話者と感情を通知する。所有権はカタログに残る。
    property OnApply: TSerifVoicevoxShortcutApplyEvent
      read FOnApply write FOnApply;
  end;

implementation

uses
  Winapi.Windows, System.Math, System.SysUtils, AviUtl2StyleColors,
  MainToolInfoService;

const
  OPERATION_HINT_DURATION_MS = 1200;
  // ホバーの青系と競合せず、ダーク背景から識別できる低明度の暖色。
  SHORTCUT_NUMBER_BADGE_COLOR = TColor($00284050);
  VALUE_HINT_DURATION_MS = 600;

function ShortcutScale(const Value, Ppi: Integer): Integer;
begin
  Result := MulDiv(Value, Ppi, 96);
end;

{$R *.dfm}

{ TSerifVoicevoxShortcutItem }

constructor TSerifVoicevoxShortcutItem.CreateItem(AOwner: TComponent;
  AIconRenderer: TSerifCharaIconRenderer; const ShortcutIndex: Integer);
begin
  inherited Create(AOwner);
  FIconRenderer := AIconRenderer;
  FIndex := ShortcutIndex;
  FStyleId := -1;
  if ShortcutIndex = 9 then
    FNumberText := '0'
  else
    FNumberText := IntToStr(ShortcutIndex + 1);
  ParentShowHint := False;
  ShowHint := False;
end;

procedure TSerifVoicevoxShortcutItem.CMMouseLeave(var Message: TMessage);
var
  CursorPoint: TPoint;
begin
  inherited;
  // ヒントウィンドウ表示に伴う疑似Leaveでは消さず、実座標が枠外の場合だけ終了する。
  if GetCursorPos(CursorPoint) and
    PtInRect(ClientRect, ScreenToClient(CursorPoint)) then Exit;
  FHotRegion := vsrNone;
  Cursor := crDefault;
  if Assigned(FOnHintRequest) then
    FOnHintRequest(Self, '', Point(0, 0), 0);
  Invalidate;
end;

function TSerifVoicevoxShortcutItem.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  Region: TSerifVoicevoxShortcutRegion;
begin
  if ssShift in Shift then Region := vsrNone
  else Region := RegionAt(ScreenToClient(MousePos));
  Result := (Region = vsrNone) or (Region in [vsrSpeaker, vsrStyle]);
  if not Result then
  begin
    Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
    Exit;
  end;
  if Assigned(FOnRegionWheel) then
    FOnRegionWheel(Self, FIndex, Region, WheelDelta);
  if (Region <> vsrNone) and Assigned(FOnHintRequest) then
    FOnHintRequest(Self, ValueHint, MousePos, VALUE_HINT_DURATION_MS);
end;

function TSerifVoicevoxShortcutItem.HintForRegion(
  const Region: TSerifVoicevoxShortcutRegion): string;
begin
  case Region of
    vsrNumber:
      Result := 'Ctrl+' + FNumberText + ': ' + FSpeakerName + ' / ' +
        FStyleName + '　クリックで適用';
    vsrSpeaker:
      Result := '話者: ' + FSpeakerName + '　右クリック/ホイールで変更';
    vsrStyle:
      Result := '感情: ' + FStyleName + '　右クリック/ホイールで変更';
  else
    Result := '';
  end;
end;

procedure TSerifVoicevoxShortcutItem.MouseMove(Shift: TShiftState;
  X, Y: Integer);
var
  Region: TSerifVoicevoxShortcutRegion;
begin
  inherited;
  Region := RegionAt(Point(X, Y));
  if Region in [vsrNumber, vsrSpeaker, vsrStyle] then Cursor := crHandPoint
  else Cursor := crDefault;
  if FHotRegion = Region then Exit;
  FHotRegion := Region;
  RequestHint(Region, ClientToScreen(Point(X, Y)));
  Invalidate;
end;

procedure TSerifVoicevoxShortcutItem.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Region: TSerifVoicevoxShortcutRegion;
begin
  inherited;
  if Button = mbLeft then
    Region := vsrNumber
  else if Button = mbRight then
    Region := RegionAt(Point(X, Y))
  else
    Exit;
  if Assigned(FOnRegionClick) then
    FOnRegionClick(Self, FIndex, Region);
end;

procedure TSerifVoicevoxShortcutItem.Paint;
var
  BadgeHeight: Integer;
  BadgeWidth: Integer;
  BorderColor: TColor;
  IconInset: Integer;
  IconSize: Integer;
  SideMargin: Integer;
  StyleHeight: Integer;
  ItemColor: TColor;
  IconRect: TRect;
  NumberRect: TRect;
  StyleRect: TRect;
begin
  StyleHeight := ShortcutScale(STYLE_HEIGHT, CurrentPPI);
  SideMargin := ShortcutScale(3, CurrentPPI);
  if FApplied then
    ItemColor := A2SCToolBarChecked
  else
    ItemColor := A2SCPanelBackground;
  Canvas.Brush.Color := ItemColor;
  Canvas.FillRect(ClientRect);

  // 左ガターを番号専用に確保し、バッジが話者アイコンへ重ならないようにする。
  IconRect := Rect(ShortcutScale(NUMBER_GUTTER_WIDTH, CurrentPPI),
    SideMargin, ClientWidth - SideMargin, ClientHeight - StyleHeight);
  IconInset := ShortcutScale(2, CurrentPPI);
  InflateRect(IconRect, -IconInset, -IconInset);
  // 列幅を詰めても入力欄と同じアイコン寸法を維持する。
  IconSize := Min(ShortcutScale(38, CurrentPPI),
    Min(IconRect.Width, IconRect.Height));
  IconRect := Rect(IconRect.Left + (IconRect.Width - IconSize) div 2,
    IconRect.Top + (IconRect.Height - IconSize) div 2, 0, 0);
  IconRect.Right := IconRect.Left + IconSize;
  IconRect.Bottom := IconRect.Top + IconSize;
  Canvas.Brush.Color := ItemColor;
  Canvas.FillRect(IconRect);
  if Assigned(FIconRenderer) and (FSpeakerName <> '') then
    FIconRenderer.DrawOrFallback(Canvas, FSpeakerName, IconRect);

  // 数字は操作領域を持たない小さなバッジとして、左ガター上端へ描画する。
  BadgeWidth := ShortcutScale(NUMBER_BADGE_WIDTH, CurrentPPI);
  BadgeHeight := ShortcutScale(NUMBER_BADGE_HEIGHT, CurrentPPI);
  NumberRect := Rect(ShortcutScale(1, CurrentPPI),
    ShortcutScale(2, CurrentPPI),
    ShortcutScale(1, CurrentPPI) + BadgeWidth,
    ShortcutScale(2, CurrentPPI) + BadgeHeight);
  Canvas.Brush.Color := SHORTCUT_NUMBER_BADGE_COLOR;
  Canvas.FillRect(NumberRect);
  Canvas.Font.Assign(Font);
  Canvas.Font.Height := -ShortcutScale(10, CurrentPPI);
  Canvas.Font.Color := A2SCToolBarFont;
  DrawText(Canvas.Handle, PChar(FNumberText), -1, NumberRect,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);

  SideMargin := ShortcutScale(2, CurrentPPI);
  StyleRect := Rect(SideMargin, ClientHeight - StyleHeight,
    ClientWidth - SideMargin, ClientHeight);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ItemColor;
  Canvas.FillRect(StyleRect);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Height := -ShortcutScale(14, CurrentPPI);
  if (FHotRegion <> vsrNone) or FApplied then
    Canvas.Font.Color := A2SCToolBarFont
  else
    Canvas.Font.Color := A2SCPanelText;
  DrawText(Canvas.Handle, PChar(FStyleName), -1, StyleRect,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or
    DT_NOPREFIX);
  Canvas.Brush.Style := bsSolid;
  if FHotRegion <> vsrNone then BorderColor := A2SCToolBarHot
  else if FApplied then BorderColor := A2SCToolBarFont
  else BorderColor := A2SCToolBarBackground;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := BorderColor;
  Canvas.Rectangle(0, 0, ClientWidth, ClientHeight);
  Canvas.Brush.Style := bsSolid;
end;

procedure TSerifVoicevoxShortcutItem.SetApplied(const Value: Boolean);
begin
  if FApplied = Value then Exit;
  FApplied := Value;
  Invalidate;
end;

function TSerifVoicevoxShortcutItem.RegionAt(
  const Point: TPoint): TSerifVoicevoxShortcutRegion;
var
  StyleHeight: Integer;
begin
  Result := vsrNone;
  if not PtInRect(ClientRect, Point) then Exit;
  StyleHeight := ShortcutScale(STYLE_HEIGHT, CurrentPPI);
  if Point.Y >= ClientHeight - StyleHeight then
    Result := vsrStyle
  else
    Result := vsrSpeaker;
end;

procedure TSerifVoicevoxShortcutItem.RequestHint(
  const Region: TSerifVoicevoxShortcutRegion; const ScreenPoint: TPoint);
begin
  if Assigned(FOnHintRequest) then
    FOnHintRequest(Self, HintForRegion(Region), ScreenPoint,
      OPERATION_HINT_DURATION_MS);
end;

function TSerifVoicevoxShortcutItem.ValueHint: string;
begin
  Result := FSpeakerName;
  if FStyleName <> '' then Result := Result + ' / ' + FStyleName;
end;

procedure TSerifVoicevoxShortcutItem.SetAssignment(
  const SpeakerName, SpeakerUUID, StyleName: string;
  const StyleId: Integer);
begin
  FSpeakerName := SpeakerName;
  FSpeakerUUID := SpeakerUUID;
  FStyleName := StyleName;
  FStyleId := StyleId;
  Invalidate;
end;

{ TFrameSerifVoicevoxShortcuts }

constructor TFrameSerifVoicevoxShortcuts.CreateWithRenderer(
  AOwner: TComponent; AIconRenderer: TSerifCharaIconRenderer;
  ACatalog: TSerifVoicevoxSpeakerCatalog);
var
  I: Integer;
  Item: TSerifVoicevoxShortcutItem;
begin
  inherited Create(AOwner);
  FIconRenderer := AIconRenderer;
  FCatalog := ACatalog;
  FActiveIndex := -1;
  FPopupIndex := -1;
  Height := DEFAULT_HEIGHT;
  Color := A2SCPanelBackground;

  FSettings := TSerifVoicevoxShortcutSettings.Create;
  FSaveTimer := TTimer.Create(Self);
  FSaveTimer.Enabled := False;
  FSaveTimer.Interval := 300;
  FSaveTimer.OnTimer := SaveTimerTimer;
  FMenu := TSerifVoicevoxSpeakerMenu.Create(FCatalog, FIconRenderer);
  FMenu.OnSelected := MenuSelected;

  FScrollBar := THorizontalScrollBarControl.Create(Self);
  FScrollBar.Parent := Self;
  FScrollBar.Align := alBottom;
  FScrollBar.Height := SCROLL_BAR_HEIGHT;
  // 感情名の選択線と操作領域が隣接しないよう、上側に専用の空間を確保する。
  FScrollBar.TopPadding := SCROLL_BAR_TOP_PADDING;
  FScrollBar.BackgroundColor := A2SCPanelBackground;
  FScrollBar.TrackColor := SCROLL_BAR_TRACK_COLOR;
  FScrollBar.ThumbColor := SCROLL_BAR_THUMB_COLOR;
  FScrollBar.OnChange := ScrollPositionChange;

  FViewport := TPanel.Create(Self);
  FViewport.Parent := Self;
  FViewport.Align := alClient;
  FViewport.BevelOuter := bvNone;
  FViewport.Color := A2SCPanelBackground;
  FViewport.ParentBackground := False;

  FContent := TPanel.Create(Self);
  FContent.Parent := FViewport;
  FContent.BevelOuter := bvNone;
  FContent.Color := A2SCPanelBackground;
  FContent.Left := 0;
  FContent.Top := 0;

  FItems := TObjectList<TSerifVoicevoxShortcutItem>.Create(False);
  for I := 0 to ITEM_COUNT - 1 do
  begin
    Item := TSerifVoicevoxShortcutItem.CreateItem(Self,
      FIconRenderer, I);
    Item.Parent := FContent;
    Item.OnHintRequest := ItemHintRequest;
    Item.OnRegionClick := ItemRegionClick;
    Item.OnRegionWheel := ItemRegionWheel;
    FItems.Add(Item);
  end;
  LayoutItems;
end;

procedure TFrameSerifVoicevoxShortcuts.ApplyDpi;
begin
  Height := ShortcutScale(DEFAULT_HEIGHT, CurrentPPI);
  FScrollBar.Height := ShortcutScale(SCROLL_BAR_HEIGHT, CurrentPPI);
  FScrollBar.TopPadding := ShortcutScale(SCROLL_BAR_TOP_PADDING, CurrentPPI);
  LayoutItems;
end;

procedure TFrameSerifVoicevoxShortcuts.ClearApplied;
begin
  SetActiveIndex(-1);
end;

destructor TFrameSerifVoicevoxShortcuts.Destroy;
begin
  FSaveTimer.Enabled := False;
  FSettings.Save;
  FMenu.Free;
  FSettings.Free;
  FItems.Free;
  inherited;
end;

function TFrameSerifVoicevoxShortcuts.FindSpeaker(
  const SpeakerUUID: string): TSerifVoicevoxSpeaker;
var
  Speaker: TSerifVoicevoxSpeaker;
begin
  Result := nil;
  if not Assigned(FCatalog) then Exit;
  for Speaker in FCatalog.Speakers do
    if SameText(Speaker.UUID, SpeakerUUID) then Exit(Speaker);
end;

procedure TFrameSerifVoicevoxShortcuts.ItemHintRequest(Sender: TObject;
  const HintText: string; const ScreenPoint: TPoint;
  const DurationMs: Integer);
begin
  if HintText <> '' then ShowMainToolInfo(HintText);
end;

procedure TFrameSerifVoicevoxShortcuts.ItemRegionClick(Sender: TObject;
  const Index: Integer; const Region: TSerifVoicevoxShortcutRegion);
var
  Item: TSerifVoicevoxShortcutItem;
  PopupPoint: TPoint;
  Speaker: TSerifVoicevoxSpeaker;
begin
  if (Index < 0) or (Index >= FItems.Count) or not Assigned(FMenu) then Exit;
  Item := FItems[Index];
  FPopupIndex := Index;
  PopupPoint := Item.ClientToScreen(Point(0, Item.Height));
  case Region of
    vsrNumber:
      RequestApply(Index);
    vsrSpeaker:
      FMenu.PopupSpeakers(PopupPoint.X, PopupPoint.Y, Item.SpeakerUUID);
    vsrStyle:
      begin
        Speaker := FindSpeaker(Item.SpeakerUUID);
        if Assigned(Speaker) then
          FMenu.PopupStylesForSpeaker(PopupPoint.X, PopupPoint.Y,
            Speaker, Item.StyleId);
      end;
  end;
end;

procedure TFrameSerifVoicevoxShortcuts.ItemRegionWheel(Sender: TObject;
  const Index: Integer; const Region: TSerifVoicevoxShortcutRegion;
  const WheelDelta: Integer);
var
  EligibleSpeakers: TList<TSerifVoicevoxSpeaker>;
  I: Integer;
  NextIndex: Integer;
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  if (Index < 0) or (Index >= FItems.Count) or
    not Assigned(FCatalog) or (WheelDelta = 0) then Exit;
  if Region = vsrNone then
  begin
    if WheelDelta > 0 then
      FScrollBar.Position := FScrollBar.Position -
        ShortcutScale(ITEM_WIDTH, CurrentPPI)
    else
      FScrollBar.Position := FScrollBar.Position +
        ShortcutScale(ITEM_WIDTH, CurrentPPI);
    Exit;
  end;
  Speaker := FindSpeaker(FItems[Index].SpeakerUUID);
  case Region of
    vsrSpeaker:
      begin
        EligibleSpeakers := TList<TSerifVoicevoxSpeaker>.Create;
        try
          for Speaker in FCatalog.Speakers do
            if Speaker.Styles.Count > 0 then EligibleSpeakers.Add(Speaker);
          if EligibleSpeakers.Count = 0 then Exit;
          NextIndex := EligibleSpeakers.IndexOf(
            FindSpeaker(FItems[Index].SpeakerUUID));
          if NextIndex < 0 then NextIndex := 0
          else if WheelDelta > 0 then
            NextIndex := (NextIndex + EligibleSpeakers.Count - 1) mod
              EligibleSpeakers.Count
          else
            NextIndex := (NextIndex + 1) mod EligibleSpeakers.Count;
          Speaker := EligibleSpeakers[NextIndex];
          SetItemAssignment(Index, Speaker, Speaker.Styles[0], True);
        finally
          EligibleSpeakers.Free;
        end;
      end;
    vsrStyle:
      begin
        if not Assigned(Speaker) or (Speaker.Styles.Count = 0) then Exit;
        NextIndex := 0;
        for I := 0 to Speaker.Styles.Count - 1 do
          if Speaker.Styles[I].Id = FItems[Index].StyleId then
          begin
            NextIndex := I;
            Break;
          end;
        if WheelDelta > 0 then
          NextIndex := (NextIndex + Speaker.Styles.Count - 1) mod
            Speaker.Styles.Count
        else
          NextIndex := (NextIndex + 1) mod Speaker.Styles.Count;
        Style := Speaker.Styles[NextIndex];
        SetItemAssignment(Index, Speaker, Style, True);
      end;
  end;
end;

procedure TFrameSerifVoicevoxShortcuts.LayoutItems;
var
  AvailableHeight: Integer;
  ContentWidth: Integer;
  I: Integer;
  ItemWidth: Integer;
begin
  if not Assigned(FViewport) or not Assigned(FScrollBar) or
    not Assigned(FContent) or
    not Assigned(FItems) then Exit;
  // 親へ接続される前のコンストラクタ中でもHandleを生成しないよう外形寸法だけを使う。
  AvailableHeight := Max(1, FViewport.Height);
  ItemWidth := ShortcutScale(ITEM_WIDTH, CurrentPPI);
  ContentWidth := ITEM_COUNT * ItemWidth;
  FScrollBar.SetRange(ContentWidth, FViewport.Width, ItemWidth);
  FContent.SetBounds(-FScrollBar.Position, 0, ContentWidth,
    AvailableHeight);
  for I := 0 to FItems.Count - 1 do
    FItems[I].SetBounds(I * ItemWidth, 0, ItemWidth, AvailableHeight);
end;

procedure TFrameSerifVoicevoxShortcuts.MenuSelected(Sender: TObject;
  Speaker: TSerifVoicevoxSpeaker; Style: TSerifVoicevoxStyle);
begin
  if (FPopupIndex < 0) or not Assigned(Speaker) or not Assigned(Style) then
    Exit;
  SetItemAssignment(FPopupIndex, Speaker, Style, True);
end;

procedure TFrameSerifVoicevoxShortcuts.OpenProject(
  const ProjectFolder: string);
begin
  FSaveTimer.Enabled := False;
  FSettings.OpenProject(ProjectFolder);
  if Assigned(FCatalog) and (FCatalog.Speakers.Count > 0) then
    ShowCatalog(FCatalog);
end;

procedure TFrameSerifVoicevoxShortcuts.Resize;
begin
  inherited;
  LayoutItems;
end;

procedure TFrameSerifVoicevoxShortcuts.RequestApply(const Index: Integer);
var
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  if (Index < 0) or (Index >= FItems.Count) then Exit;
  Speaker := FindSpeaker(FItems[Index].SpeakerUUID);
  if not Assigned(Speaker) then Exit;
  Style := Speaker.FindStyle(FItems[Index].StyleId);
  if not Assigned(Style) then Exit;
  SetActiveIndex(Index);
  if Assigned(FOnApply) then FOnApply(Self, Index, Speaker, Style);
end;

procedure TFrameSerifVoicevoxShortcuts.SaveTimerTimer(Sender: TObject);
begin
  FSaveTimer.Enabled := False;
  FSettings.Save;
end;

procedure TFrameSerifVoicevoxShortcuts.Save;
begin
  FSaveTimer.Enabled := False;
  FSettings.Save;
end;

procedure TFrameSerifVoicevoxShortcuts.ScrollPositionChange(Sender: TObject);
begin
  if Assigned(FContent) and Assigned(FScrollBar) then
    FContent.Left := -FScrollBar.Position;
end;

procedure TFrameSerifVoicevoxShortcuts.SetActiveIndex(
  const Index: Integer);
var
  I: Integer;
begin
  if (Index < -1) or (Index >= FItems.Count) then Exit;
  FActiveIndex := Index;
  for I := 0 to FItems.Count - 1 do
    FItems[I].Applied := I = FActiveIndex;
end;

procedure TFrameSerifVoicevoxShortcuts.SetItemAssignment(
  const Index: Integer; Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle; const ScheduleSave: Boolean);
var
  Assignment: TSerifVoicevoxShortcutAssignment;
begin
  if (Index < 0) or (Index >= FItems.Count) or not Assigned(Speaker) or
    not Assigned(Style) then Exit;
  FItems[Index].SetAssignment(Speaker.Name, Speaker.UUID,
    Style.Name, Style.Id);
  Assignment.EngineID := 'VOICEVOX';
  Assignment.SpeakerUUID := Speaker.UUID;
  Assignment.StyleId := Style.Id;
  FSettings.SetAssignment(Index, Assignment);
  if ScheduleSave then
  begin
    if FActiveIndex = Index then SetActiveIndex(-1);
    FSaveTimer.Enabled := False;
    FSaveTimer.Enabled := True;
  end;
end;

procedure TFrameSerifVoicevoxShortcuts.ShowCatalog(
  const Catalog: TSerifVoicevoxSpeakerCatalog);
var
  Assignment: TSerifVoicevoxShortcutAssignment;
  EligibleSpeakers: TList<TSerifVoicevoxSpeaker>;
  I: Integer;
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  FCatalog := Catalog;
  FMenu.Build;
  EligibleSpeakers := TList<TSerifVoicevoxSpeaker>.Create;
  try
    if Assigned(Catalog) then
      for Speaker in Catalog.Speakers do
        if Speaker.Styles.Count > 0 then EligibleSpeakers.Add(Speaker);
    for I := 0 to FItems.Count - 1 do
      if EligibleSpeakers.Count = 0 then
        FItems[I].SetAssignment('', '', '', -1)
      else
      begin
        Assignment := FSettings.GetAssignment(I);
        Speaker := nil;
        Style := nil;
        if Assignment.EngineID <> '' then
        begin
          // 他エンジンまたは一時的に解決不能な割り当ては、VOICEVOXの既定値で上書きしない。
          if SameText(Assignment.EngineID, 'VOICEVOX') then
          begin
            Speaker := FindSpeaker(Assignment.SpeakerUUID);
            if Assigned(Speaker) then
              Style := Speaker.FindStyle(Assignment.StyleId);
          end;
          if not Assigned(Style) then
          begin
            FItems[I].SetAssignment('', '', '', -1);
            Continue;
          end;
        end
        else
        begin
          Speaker := EligibleSpeakers[I mod EligibleSpeakers.Count];
          Style := Speaker.Styles[0];
        end;
        SetItemAssignment(I, Speaker, Style, True);
      end;
  finally
    EligibleSpeakers.Free;
  end;
end;

end.
