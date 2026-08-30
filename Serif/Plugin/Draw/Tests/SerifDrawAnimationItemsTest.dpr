program SerifDrawAnimationItemsTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Lib\AviUtl2Filter\AviUtl2FilterTypes.pas',
  PluginFilterTable in 'Lib\AviUtl2Filter\PluginFilterTable.pas',
  PluginFilterSerifDrawAnimationTypes in
    'Serif\Plugin\Draw\Animation\PluginFilterSerifDrawAnimationTypes.pas',
  PluginFilterSerifDrawAnimationItems in
    'Serif\Plugin\Draw\Animation\PluginFilterSerifDrawAnimationItems.pas';

type
  TSelectItemArray = array[0..99] of TFILTER_ITEM_SELECT_ITEM;
  PSelectItemArray = ^TSelectItemArray;
  TItemPointerArray = array[0..99] of Pointer;
  PItemPointerArray = ^TItemPointerArray;

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function SelectName(const AItem: TFILTER_ITEM_SELECT;
  const AIndex: Integer): string;
begin
  Result := string(PSelectItemArray(AItem.List)^[AIndex].Name);
end;

var
  Items: PItemPointerArray;
begin
  SetupPluginTable(FILTER_FLAG_VIDEO, 'test', 'test', 'test', nil, nil);
  AddSerifDrawAnimationItems;
  Items := PItemPointerArray(GTable.Items);

  Require((Items^[0] = @BeforeGroup) and (Items^[5] = @DuringGroup) and
    (Items^[8] = @SyncGroup) and (Items^[17] = @AfterGroup) and
    (Items^[22] = nil),
    'Animation parameter groups or item order mismatch.');
  Require((string(BeforeGroup.Name) = '表示前') and
    (string(DuringGroup.Name) = '常時') and
    (string(SyncGroup.Name) = '同期') and
    (string(AfterGroup.Name) = '表示後'),
    'Animation group labels mismatch.');
  Require((string(BeforeTypeItem.Name) = '前 種類') and
    (string(BeforeDirectionItem.Name) = '前 方向') and
    (string(BeforeZoomOriginItem.Name) = '前 奥行き') and
    (string(BeforeValue1Item.Name) = '前 値1') and
    (string(DuringEmotionItem.Name) = '常時 感情表現') and
    (string(DuringSpeedItem.Name) = '常時 速さ') and
    (string(SyncTypeItem.Name) = '同期 種類') and
    (string(SyncPaintModeItem.Name) = '同期 色塗り') and
    (string(SyncModeItem.Name) = '同期 通過後') and
    (string(AfterTypeItem.Name) = '後 種類') and
    (string(AfterDirectionItem.Name) = '後 方向') and
    (string(AfterZoomDestinationItem.Name) = '後 奥行き') and
    (string(AfterValue1Item.Name) = '後 値1') and
    (AfterValue1Item.Value = 0.0),
    'Animation parameter labels mismatch.');
  Require((BeforeTypeItem.Value = 0) and (SyncTypeItem.Value = 0) and
    (AfterTypeItem.Value = 0),
    'Animation types must default to none.');
  Require(DuringSpeedItem.Value = 1.00,
    'Animation speed default mismatch.');
  Require(DuringEmotionItem.Value = 0,
    'Emotion animation must default to disabled.');
  Require(CurrentSerifDrawAnimationParameters.SyncColor = Cardinal($FFFFFF00),
    'Sync-animation color default mismatch.');
  Require(SyncSizeItem.Value = 120.0,
    'Sync-animation size must default to 120 percent.');
  Require((SyncOffsetXItem.S = -100.0) and
    (SyncOffsetXItem.E = 100.0) and (SyncOffsetXItem.Step = 1.0) and
    (SyncOffsetYItem.S = -100.0) and
    (SyncOffsetYItem.E = 100.0) and (SyncOffsetYItem.Step = 1.0),
    'Sync-animation offsets must use a -100..100 pixel range and 1px steps.');
  BeforeTypeItem.Value := 1;
  BeforeDirectionItem.Value := SERIF_ANIMATION_DIRECTION_RIGHT;
  BeforeZoomOriginItem.Value := SERIF_ANIMATION_ZOOM_FROM_FRONT;
  DuringEmotionItem.Value := 1;
  SyncTypeItem.Value := SERIF_ANIMATION_SYNC_SPEECH_COLOR;
  SyncPaintModeItem.Value := SERIF_ANIMATION_SYNC_PAINT_SMOOTH;
  SyncModeItem.Value := SERIF_ANIMATION_SYNC_MODE_TRAIL;
  SyncShapeItem.Value := SERIF_ANIMATION_SYNC_SHAPE_TRIANGLE;
  SyncColorItem.R := 1;
  SyncColorItem.G := 2;
  SyncColorItem.B := 3;
  // AviUtl2のプロジェクトにはRGBだけが保存されるため、再読込時のX=0でも不透明色として扱う。
  SyncColorItem.X := 0;
  SyncSizeItem.Value := 125.0;
  SyncOffsetXItem.Value := 6.0;
  SyncOffsetYItem.Value := -7.0;
  AfterTypeItem.Value := 1;
  AfterDirectionItem.Value := SERIF_ANIMATION_DIRECTION_LEFT;
  AfterZoomDestinationItem.Value := SERIF_ANIMATION_ZOOM_TO_FRONT;
  Require((CurrentSerifDrawAnimationParameters.BeforeKind = 1) and
    (CurrentSerifDrawAnimationParameters.BeforeDirection =
      SERIF_ANIMATION_DIRECTION_RIGHT) and
    (CurrentSerifDrawAnimationParameters.BeforeZoomOrigin =
      SERIF_ANIMATION_ZOOM_FROM_FRONT) and
    CurrentSerifDrawAnimationParameters.DuringEmotionEnabled and
    (CurrentSerifDrawAnimationParameters.SyncKind =
      SERIF_ANIMATION_SYNC_SPEECH_COLOR) and
    (CurrentSerifDrawAnimationParameters.SyncPaintMode =
      SERIF_ANIMATION_SYNC_PAINT_SMOOTH) and
    (CurrentSerifDrawAnimationParameters.SyncMode =
      SERIF_ANIMATION_SYNC_MODE_TRAIL) and
    (CurrentSerifDrawAnimationParameters.SyncShape =
      SERIF_ANIMATION_SYNC_SHAPE_TRIANGLE) and
    (CurrentSerifDrawAnimationParameters.SyncColor = Cardinal($FF010203)) and
    (CurrentSerifDrawAnimationParameters.SyncSize = 125.0) and
    (CurrentSerifDrawAnimationParameters.SyncOffsetX = 6.0) and
    (CurrentSerifDrawAnimationParameters.SyncOffsetY = -7.0) and
    (CurrentSerifDrawAnimationParameters.AfterKind = 1) and
    (CurrentSerifDrawAnimationParameters.AfterDirection =
      SERIF_ANIMATION_DIRECTION_LEFT) and
    (CurrentSerifDrawAnimationParameters.AfterZoomDestination =
      SERIF_ANIMATION_ZOOM_TO_FRONT),
    'Animation parameter values were not exposed to the renderer.');
  Require((SelectName(BeforeTypeItem, 0) = 'なし') and
    (SelectName(BeforeTypeItem, 5) = 'ワイプイン') and
    (SelectName(BeforeTypeItem, 6) = 'ブラーイン') and
    (SelectName(BeforeTypeItem, 7) = '回転イン') and
    (SelectName(BeforeTypeItem, 8) = 'バウンドイン') and
    (PSelectItemArray(BeforeTypeItem.List)^[9].Name = nil),
    'Before-animation candidates mismatch.');
  Require((SelectName(BeforeDirectionItem, 0) = '標準') and
    (SelectName(BeforeDirectionItem, 1) = '左') and
    (SelectName(BeforeDirectionItem, 2) = '右') and
    (SelectName(BeforeDirectionItem, 3) = '上') and
    (SelectName(BeforeDirectionItem, 4) = '下') and
    (PSelectItemArray(BeforeDirectionItem.List)^[5].Name = nil),
    'Before-animation direction candidates mismatch.');
  Require((SelectName(BeforeZoomOriginItem, 0) = '奥から') and
    (SelectName(BeforeZoomOriginItem, 1) = '手前から') and
    (PSelectItemArray(BeforeZoomOriginItem.List)^[2].Name = nil),
    'Before-animation zoom-origin candidates mismatch.');
  Require((SelectName(SyncTypeItem, 0) = 'なし') and
    (SelectName(SyncTypeItem, 1) = '色変え') and
    (SelectName(SyncTypeItem, 2) = '前面') and
    (SelectName(SyncTypeItem, 3) = '背面') and
    (SelectName(SyncTypeItem, 4) = '下線') and
    (SelectName(SyncTypeItem, 5) = '拡大') and
    (SelectName(SyncTypeItem, 6) = '発光') and
    (SelectName(SyncTypeItem, 7) = 'ジャンプ') and
    (PSelectItemArray(SyncTypeItem.List)^[8].Name = nil),
    'Sync-animation candidates mismatch.');
  Require((PSelectItemArray(SyncTypeItem.List)^[1].Value = 1) and
    (PSelectItemArray(SyncTypeItem.List)^[2].Value = 2) and
    (PSelectItemArray(SyncTypeItem.List)^[3].Value = 3) and
    (PSelectItemArray(SyncTypeItem.List)^[7].Value = 7),
    'Sync-animation values must preserve the displayed list order.');
  Require((SelectName(SyncPaintModeItem, 0) = '文字単位') and
    (SelectName(SyncPaintModeItem, 1) = 'なめらか') and
    (PSelectItemArray(SyncPaintModeItem.List)^[2].Name = nil),
    'Sync-animation paint modes mismatch.');
  Require((SelectName(SyncModeItem, 0) = '戻す') and
    (SelectName(SyncModeItem, 1) = '維持') and
    (PSelectItemArray(SyncModeItem.List)^[2].Name = nil),
    'Sync-animation mode candidates mismatch.');
  Require((SelectName(AfterTypeItem, 1) = 'フェードアウト') and
    (SelectName(AfterTypeItem, 2) = 'スライドアウト') and
    (SelectName(AfterTypeItem, 3) = 'ズームアウト') and
    (SelectName(AfterTypeItem, 4) = 'ワイプアウト') and
    (SelectName(AfterTypeItem, 5) = 'ブラーアウト') and
    (SelectName(AfterTypeItem, 6) = '回転アウト') and
    (PSelectItemArray(AfterTypeItem.List)^[7].Name = nil),
    'After-animation candidates mismatch.');
  Require((SelectName(AfterDirectionItem, 0) = '標準') and
    (SelectName(AfterDirectionItem, 1) = '左') and
    (SelectName(AfterDirectionItem, 4) = '下') and
    (PSelectItemArray(AfterDirectionItem.List)^[5].Name = nil),
    'After-animation direction candidates mismatch.');
  Require((SelectName(AfterZoomDestinationItem, 0) = '奥へ') and
    (SelectName(AfterZoomDestinationItem, 1) = '手前へ') and
    (PSelectItemArray(AfterZoomDestinationItem.List)^[2].Name = nil),
    'After-animation zoom-destination candidates mismatch.');

  Writeln('SerifDraw animation parameter test passed.');
end.
