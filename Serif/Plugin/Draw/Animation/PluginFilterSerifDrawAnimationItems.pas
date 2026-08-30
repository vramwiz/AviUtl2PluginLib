unit PluginFilterSerifDrawAnimationItems;

interface

// AviUtl2のオブジェクト設定に表示するセリフアニメーション用パラメーターを登録する。
// 種類によらない固定の共通スキーマを提供し、実装済みの種類だけ描画へ接続する。

uses
  AviUtl2FilterTypes,
  PluginFilterSerifDrawAnimationTypes;

procedure AddSerifDrawAnimationItems;
function CurrentSerifDrawAnimationParameters:
  TSerifDrawAnimationParameters;

var
  BeforeGroup: TFILTER_ITEM_GROUP;
  BeforeTypeItem: TFILTER_ITEM_SELECT;
  BeforeDirectionItem: TFILTER_ITEM_SELECT;
  BeforeZoomOriginItem: TFILTER_ITEM_SELECT;
  // 旧「前 値1」の登録位置を維持する非表示互換スロット。
  BeforeValue1CompatibilityItem: TFILTER_ITEM_DATA;

  DuringGroup: TFILTER_ITEM_GROUP;
  DuringEmotionItem: TFILTER_ITEM_CHECK;
  DuringSpeedItem: TFILTER_ITEM_TRACK;

  SyncGroup: TFILTER_ITEM_GROUP;
  SyncTypeItem: TFILTER_ITEM_SELECT;
  SyncPaintModeItem: TFILTER_ITEM_SELECT;
  SyncModeItem: TFILTER_ITEM_SELECT;
  SyncShapeItem: TFILTER_ITEM_SELECT;
  SyncColorItem: TFILTER_ITEM_COLOR;
  SyncSizeItem: TFILTER_ITEM_TRACK;
  SyncOffsetXItem: TFILTER_ITEM_TRACK;
  SyncOffsetYItem: TFILTER_ITEM_TRACK;

  AfterGroup: TFILTER_ITEM_GROUP;
  AfterTypeItem: TFILTER_ITEM_SELECT;
  AfterDirectionItem: TFILTER_ITEM_SELECT;
  AfterZoomDestinationItem: TFILTER_ITEM_SELECT;
  // 旧「後 値1」の登録位置を維持する非表示互換スロット。
  AfterValue1CompatibilityItem: TFILTER_ITEM_DATA;

implementation

uses
  PluginFilterTable;

const
  DEFAULT_SPEED = 1.00;
  SYNC_SPEED_DEFAULT = 1.00;
  SYNC_VALUE1_DEFAULT = 100.00;
  SYNC_SIZE_DEFAULT = 120.00;
  SPEED_MIN = 0.00;
  SPEED_MAX = 100.00;
  SIZE_MIN = 1.00;
  SIZE_MAX = 1000.00;
  SYNC_COLOR_DEFAULT = $0000FFFF;
  TRACK_STEP = 0.01;
  SYNC_OFFSET_MIN = -100.00;
  SYNC_OFFSET_MAX = 100.00;
  SYNC_OFFSET_STEP = 1.00;

var
  BeforeValue1CompatibilityValue: Double;
  AfterValue1CompatibilityValue: Double;
  BeforeTypeList: array[0..9] of TFILTER_ITEM_SELECT_ITEM;
  BeforeDirectionList: array[0..5] of TFILTER_ITEM_SELECT_ITEM;
  BeforeZoomOriginList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  SyncTypeList: array[0..8] of TFILTER_ITEM_SELECT_ITEM;
  SyncPaintModeList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  SyncModeList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  SyncShapeList: array[0..4] of TFILTER_ITEM_SELECT_ITEM;
  AfterTypeList: array[0..7] of TFILTER_ITEM_SELECT_ITEM;
  AfterDirectionList: array[0..5] of TFILTER_ITEM_SELECT_ITEM;
  AfterZoomDestinationList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;

procedure AddChoice(var AList: array of TFILTER_ITEM_SELECT_ITEM;
  const AName: PWideChar; const AValue: Integer);
begin
  AddSelectList(AList, AName, AValue);
end;

procedure BuildBeforeTypeList;
begin
  ClearSelectList;
  AddChoice(BeforeTypeList, 'なし', 0);
  AddChoice(BeforeTypeList, 'フェードイン', 1);
  AddChoice(BeforeTypeList, 'スライドイン', 2);
  AddChoice(BeforeTypeList, 'ズームイン', 3);
  AddChoice(BeforeTypeList, 'ポップイン', 4);
  AddChoice(BeforeTypeList, 'ワイプイン', 5);
  AddChoice(BeforeTypeList, 'ブラーイン', 6);
  AddChoice(BeforeTypeList, '回転イン', 10);
  AddChoice(BeforeTypeList, 'バウンドイン', 11);
end;

procedure BuildBeforeDirectionList;
begin
  ClearSelectList;
  AddChoice(BeforeDirectionList, '標準', SERIF_ANIMATION_DIRECTION_DEFAULT);
  AddChoice(BeforeDirectionList, '左', SERIF_ANIMATION_DIRECTION_LEFT);
  AddChoice(BeforeDirectionList, '右', SERIF_ANIMATION_DIRECTION_RIGHT);
  AddChoice(BeforeDirectionList, '上', SERIF_ANIMATION_DIRECTION_TOP);
  AddChoice(BeforeDirectionList, '下', SERIF_ANIMATION_DIRECTION_BOTTOM);
end;

procedure BuildBeforeZoomOriginList;
begin
  ClearSelectList;
  AddChoice(BeforeZoomOriginList, '奥から', SERIF_ANIMATION_ZOOM_FROM_BACK);
  AddChoice(BeforeZoomOriginList, '手前から', SERIF_ANIMATION_ZOOM_FROM_FRONT);
end;

procedure BuildAfterTypeList;
begin
  ClearSelectList;
  AddChoice(AfterTypeList, 'なし', 0);
  AddChoice(AfterTypeList, 'フェードアウト', SERIF_ANIMATION_AFTER_FADE);
  AddChoice(AfterTypeList, 'スライドアウト', SERIF_ANIMATION_AFTER_SLIDE);
  AddChoice(AfterTypeList, 'ズームアウト', SERIF_ANIMATION_AFTER_ZOOM);
  AddChoice(AfterTypeList, 'ワイプアウト', SERIF_ANIMATION_AFTER_WIPE);
  AddChoice(AfterTypeList, 'ブラーアウト', SERIF_ANIMATION_AFTER_BLUR);
  AddChoice(AfterTypeList, '回転アウト', SERIF_ANIMATION_AFTER_ROTATE);
end;

procedure BuildAfterDirectionList;
begin
  ClearSelectList;
  AddChoice(AfterDirectionList, '標準', SERIF_ANIMATION_DIRECTION_DEFAULT);
  AddChoice(AfterDirectionList, '左', SERIF_ANIMATION_DIRECTION_LEFT);
  AddChoice(AfterDirectionList, '右', SERIF_ANIMATION_DIRECTION_RIGHT);
  AddChoice(AfterDirectionList, '上', SERIF_ANIMATION_DIRECTION_TOP);
  AddChoice(AfterDirectionList, '下', SERIF_ANIMATION_DIRECTION_BOTTOM);
end;

procedure BuildAfterZoomDestinationList;
begin
  ClearSelectList;
  AddChoice(AfterZoomDestinationList, '奥へ', SERIF_ANIMATION_ZOOM_TO_BACK);
  AddChoice(AfterZoomDestinationList, '手前へ', SERIF_ANIMATION_ZOOM_TO_FRONT);
end;

procedure BuildSyncTypeList;
begin
  ClearSelectList;
  AddChoice(SyncTypeList, 'なし', 0);
  AddChoice(SyncTypeList, '色変え', SERIF_ANIMATION_SYNC_SPEECH_COLOR);
  AddChoice(SyncTypeList, '前面', SERIF_ANIMATION_SYNC_FRONT);
  AddChoice(SyncTypeList, '背面', SERIF_ANIMATION_SYNC_BACKING);
  AddChoice(SyncTypeList, '下線', SERIF_ANIMATION_SYNC_UNDERLINE);
  AddChoice(SyncTypeList, '拡大', SERIF_ANIMATION_SYNC_ZOOM);
  AddChoice(SyncTypeList, '発光', SERIF_ANIMATION_SYNC_GLOW);
  AddChoice(SyncTypeList, 'ジャンプ', SERIF_ANIMATION_SYNC_JUMP);
end;

procedure BuildSyncModeList;
begin
  ClearSelectList;
  AddChoice(SyncModeList, '戻す', SERIF_ANIMATION_SYNC_MODE_STANDARD);
  AddChoice(SyncModeList, '維持', SERIF_ANIMATION_SYNC_MODE_TRAIL);
end;

procedure BuildSyncPaintModeList;
begin
  ClearSelectList;
  AddChoice(SyncPaintModeList, '文字単位',
    SERIF_ANIMATION_SYNC_PAINT_CHARACTER);
  AddChoice(SyncPaintModeList, 'なめらか', SERIF_ANIMATION_SYNC_PAINT_SMOOTH);
end;

procedure BuildSyncShapeList;
begin
  ClearSelectList;
  AddChoice(SyncShapeList, '自動', SERIF_ANIMATION_SYNC_SHAPE_AUTO);
  AddChoice(SyncShapeList, '丸', SERIF_ANIMATION_SYNC_SHAPE_CIRCLE);
  AddChoice(SyncShapeList, '四角', SERIF_ANIMATION_SYNC_SHAPE_SQUARE);
  AddChoice(SyncShapeList, '三角', SERIF_ANIMATION_SYNC_SHAPE_TRIANGLE);
end;

procedure AddSerifDrawAnimationItems;
begin
  BuildBeforeTypeList;
  BuildBeforeDirectionList;
  BuildBeforeZoomOriginList;
  BuildSyncTypeList;
  BuildSyncPaintModeList;
  BuildSyncModeList;
  BuildSyncShapeList;
  BuildAfterTypeList;
  BuildAfterDirectionList;
  BuildAfterZoomDestinationList;

  AddGroup(BeforeGroup, '表示前', 1);
  AddSelect(BeforeTypeItem, '前 種類', 0, @BeforeTypeList[0]);
  AddSelect(BeforeDirectionItem, '前 方向', SERIF_ANIMATION_DIRECTION_DEFAULT,
    @BeforeDirectionList[0]);
  AddSelect(BeforeZoomOriginItem, '前 奥行き', SERIF_ANIMATION_ZOOM_FROM_BACK,
    @BeforeZoomOriginList[0]);
  AddData(BeforeValue1CompatibilityItem, '前 値1',
    PWideChar(@BeforeValue1CompatibilityValue),
    SizeOf(BeforeValue1CompatibilityValue));

  AddGroup(DuringGroup, '常時', 1);
  AddCheck(DuringEmotionItem, '常時 感情表現', 0);
  AddTrack(DuringSpeedItem, '常時 速さ', DEFAULT_SPEED, SPEED_MIN, SPEED_MAX,
    TRACK_STEP);

  AddGroup(SyncGroup, '同期', 1);
  AddSelect(SyncTypeItem, '同期 種類', 0, @SyncTypeList[0]);
  AddSelect(SyncPaintModeItem, '同期 色塗り',
    SERIF_ANIMATION_SYNC_PAINT_CHARACTER, @SyncPaintModeList[0]);
  AddSelect(SyncModeItem, '同期 通過後', SERIF_ANIMATION_SYNC_MODE_STANDARD,
    @SyncModeList[0]);
  AddSelect(SyncShapeItem, '同期 形', SERIF_ANIMATION_SYNC_SHAPE_AUTO,
    @SyncShapeList[0]);
  AddColor(SyncColorItem, '同期 色', SYNC_COLOR_DEFAULT);
  AddTrack(SyncSizeItem, '同期 サイズ', SYNC_SIZE_DEFAULT, SIZE_MIN, SIZE_MAX,
    TRACK_STEP);
  AddTrack(SyncOffsetXItem, '同期 オフセットX', 0.00, SYNC_OFFSET_MIN,
    SYNC_OFFSET_MAX, SYNC_OFFSET_STEP);
  AddTrack(SyncOffsetYItem, '同期 オフセットY', 0.00, SYNC_OFFSET_MIN,
    SYNC_OFFSET_MAX, SYNC_OFFSET_STEP);

  AddGroup(AfterGroup, '表示後', 1);
  AddSelect(AfterTypeItem, '後 種類', 0, @AfterTypeList[0]);
  AddSelect(AfterDirectionItem, '後 方向', SERIF_ANIMATION_DIRECTION_DEFAULT,
    @AfterDirectionList[0]);
  AddSelect(AfterZoomDestinationItem, '後 奥行き', SERIF_ANIMATION_ZOOM_TO_BACK,
    @AfterZoomDestinationList[0]);
  AddData(AfterValue1CompatibilityItem, '後 値1',
    PWideChar(@AfterValue1CompatibilityValue),
    SizeOf(AfterValue1CompatibilityValue));
end;

function CurrentSerifDrawAnimationParameters:
  TSerifDrawAnimationParameters;
begin
  Result := System.Default(TSerifDrawAnimationParameters);
  Result.BeforeKind := BeforeTypeItem.Value;
  Result.BeforeDirection := BeforeDirectionItem.Value;
  Result.BeforeZoomOrigin := BeforeZoomOriginItem.Value;
  Result.DuringEmotionEnabled := DuringEmotionItem.Value <> 0;
  Result.DuringSpeed := DuringSpeedItem.Value;
  Result.SyncKind := SyncTypeItem.Value;
  Result.SyncPaintMode := SyncPaintModeItem.Value;
  Result.SyncMode := SyncModeItem.Value;
  Result.SyncShape := SyncShapeItem.Value;
  Result.SyncColor := Cardinal($FF000000) or
    (SyncColorItem.R shl 16) or (SyncColorItem.G shl 8) or SyncColorItem.B;
  Result.SyncSize := SyncSizeItem.Value;
  Result.SyncOffsetX := SyncOffsetXItem.Value;
  Result.SyncOffsetY := SyncOffsetYItem.Value;
  Result.SyncSpeed := SYNC_SPEED_DEFAULT;
  Result.SyncValue1 := SYNC_VALUE1_DEFAULT;
  Result.AfterKind := AfterTypeItem.Value;
  Result.AfterDirection := AfterDirectionItem.Value;
  Result.AfterZoomDestination := AfterZoomDestinationItem.Value;
end;

end.
