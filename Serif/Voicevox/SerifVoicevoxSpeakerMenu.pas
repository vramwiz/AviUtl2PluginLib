// 話者カタログから、キャラクターとstyleを選択する階層ポップアップメニューを構築する。
unit SerifVoicevoxSpeakerMenu;

interface

uses
  System.Classes, System.ImageList, Vcl.Controls, Vcl.Menus, Vcl.ImgList,
  SerifCharaIconRenderer,
  SerifVoicevoxSpeakerCatalog;

type
  TSerifVoicevoxSpeakerSelectedEvent = procedure(Sender: TObject;
    Speaker: TSerifVoicevoxSpeaker; Style: TSerifVoicevoxStyle) of object;

  TSerifVoicevoxSpeakerMenu = class
  private
    FCatalog: TSerifVoicevoxSpeakerCatalog;
    FIconRenderer: TSerifCharaIconRenderer;
    FImages: TImageList;
    FOnSelected: TSerifVoicevoxSpeakerSelectedEvent;
    FPopup: TPopupMenu;
    FSpeakerPopup: TPopupMenu;
    FStylePopup: TPopupMenu;
    FStyleSpeaker: TSerifVoicevoxSpeaker;
    procedure AddSpeakerIcon(const SpeakerName: string);
    procedure ItemClick(Sender: TObject);
    procedure SpeakerItemClick(Sender: TObject);
    procedure StyleItemClick(Sender: TObject);
    procedure UpdateChecks(const StyleId: Integer);
  public
    // カタログと共有アイコン描画器を参照し、2種類のポップアップを生成する。
    constructor Create(ACatalog: TSerifVoicevoxSpeakerCatalog;
      AIconRenderer: TSerifCharaIconRenderer);
    // 生成した3種類のポップアップと共通イメージリストを解放する。
    destructor Destroy; override;
    // 現在のカタログから、話者一覧とstyle一覧のメニュー項目を作り直す。
    procedure Build;
    // 話者を第1階層、styleを第2階層として指定スクリーン座標へ表示する。
    procedure Popup(const X, Y, CurrentStyleId: Integer);
    // キャラクターだけを1階層で表示し、選択時はその話者の先頭styleを返す。
    procedure PopupSpeakers(const X, Y: Integer;
      const CurrentSpeakerUUID: string);
    // 現在の話者に属するstyleだけを指定スクリーン座標へ表示する。
    procedure PopupStyles(const X, Y, CurrentStyleId: Integer);
    // 指定した話者のstyleだけを指定スクリーン座標へ表示する。
    procedure PopupStylesForSpeaker(const X, Y: Integer;
      Speaker: TSerifVoicevoxSpeaker; const CurrentStyleId: Integer);
    // 選択された話者とstyleを通知する。オブジェクトの所有権はカタログに残る。
    property OnSelected: TSerifVoicevoxSpeakerSelectedEvent
      read FOnSelected write FOnSelected;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Types, Vcl.Graphics,
  System.UITypes;

const
  MENU_ICON_SIZE = 24;

constructor TSerifVoicevoxSpeakerMenu.Create(
  ACatalog: TSerifVoicevoxSpeakerCatalog;
  AIconRenderer: TSerifCharaIconRenderer);
begin
  inherited Create;
  FCatalog := ACatalog;
  FIconRenderer := AIconRenderer;
  FPopup := TPopupMenu.Create(nil);
  FSpeakerPopup := TPopupMenu.Create(nil);
  FStylePopup := TPopupMenu.Create(nil);
  FImages := TImageList.Create(nil);
  FImages.ColorDepth := cd24Bit;
  FImages.Width := MENU_ICON_SIZE;
  FImages.Height := MENU_ICON_SIZE;
  FPopup.Images := FImages;
  FSpeakerPopup.Images := FImages;
end;

destructor TSerifVoicevoxSpeakerMenu.Destroy;
begin
  FStylePopup.Free;
  FSpeakerPopup.Free;
  FPopup.Free;
  FImages.Free;
  inherited;
end;

procedure TSerifVoicevoxSpeakerMenu.PopupStyles(const X, Y,
  CurrentStyleId: Integer);
var
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  if not FCatalog.FindStyle(CurrentStyleId, Speaker, Style) then Exit;
  PopupStylesForSpeaker(X, Y, Speaker, CurrentStyleId);
end;

procedure TSerifVoicevoxSpeakerMenu.PopupStylesForSpeaker(const X,
  Y: Integer; Speaker: TSerifVoicevoxSpeaker;
  const CurrentStyleId: Integer);
var
  Style: TSerifVoicevoxStyle;
  StyleItem: TMenuItem;
begin
  FStylePopup.Items.Clear;
  FStyleSpeaker := Speaker;
  if not Assigned(Speaker) then Exit;
  for Style in Speaker.Styles do
  begin
    StyleItem := TMenuItem.Create(FStylePopup);
    StyleItem.Caption := Style.Name;
    StyleItem.RadioItem := True;
    StyleItem.Checked := Style.Id = CurrentStyleId;
    StyleItem.Tag := Style.Id;
    StyleItem.OnClick := StyleItemClick;
    FStylePopup.Items.Add(StyleItem);
  end;
  FStylePopup.Popup(X, Y);
end;

procedure TSerifVoicevoxSpeakerMenu.StyleItemClick(Sender: TObject);
var
  Style: TSerifVoicevoxStyle;
begin
  if not (Sender is TMenuItem) or not Assigned(FStyleSpeaker) then Exit;
  Style := FStyleSpeaker.FindStyle(TMenuItem(Sender).Tag);
  if Assigned(Style) and Assigned(FOnSelected) then
    FOnSelected(Self, FStyleSpeaker, Style);
end;

procedure TSerifVoicevoxSpeakerMenu.AddSpeakerIcon(
  const SpeakerName: string);
var
  Bitmap: TBitmap;
begin
  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf24bit;
    Bitmap.SetSize(MENU_ICON_SIZE, MENU_ICON_SIZE);
    Bitmap.Canvas.Brush.Color := clMenu;
    Bitmap.Canvas.FillRect(Rect(0, 0, MENU_ICON_SIZE, MENU_ICON_SIZE));
    FIconRenderer.DrawOrFallback(Bitmap.Canvas, SpeakerName,
      Rect(0, 0, MENU_ICON_SIZE, MENU_ICON_SIZE));
    FImages.Add(Bitmap, nil);
  finally
    Bitmap.Free;
  end;
end;

procedure TSerifVoicevoxSpeakerMenu.Build;
var
  I: Integer;
  J: Integer;
  FlatSpeakerItem: TMenuItem;
  Speaker: TSerifVoicevoxSpeaker;
  SpeakerItem: TMenuItem;
  Style: TSerifVoicevoxStyle;
  StyleItem: TMenuItem;
begin
  FPopup.Items.Clear;
  FSpeakerPopup.Items.Clear;
  FImages.Clear;
  for I := 0 to FCatalog.Speakers.Count - 1 do
  begin
    Speaker := FCatalog.Speakers[I];
    AddSpeakerIcon(Speaker.Name);
    SpeakerItem := TMenuItem.Create(FPopup);
    SpeakerItem.Caption := Speaker.Name;
    SpeakerItem.ImageIndex := I;
    SpeakerItem.Tag := I;
    FPopup.Items.Add(SpeakerItem);
    FlatSpeakerItem := TMenuItem.Create(FSpeakerPopup);
    FlatSpeakerItem.Caption := Speaker.Name;
    FlatSpeakerItem.ImageIndex := I;
    FlatSpeakerItem.Tag := I;
    FlatSpeakerItem.RadioItem := True;
    FlatSpeakerItem.OnClick := SpeakerItemClick;
    FSpeakerPopup.Items.Add(FlatSpeakerItem);
    for J := 0 to Speaker.Styles.Count - 1 do
    begin
      Style := Speaker.Styles[J];
      StyleItem := TMenuItem.Create(FPopup);
      StyleItem.Caption := Style.Name;
      StyleItem.RadioItem := True;
      StyleItem.Tag := Style.Id;
      StyleItem.OnClick := ItemClick;
      SpeakerItem.Add(StyleItem);
    end;
  end;
end;

procedure TSerifVoicevoxSpeakerMenu.PopupSpeakers(const X, Y: Integer;
  const CurrentSpeakerUUID: string);
var
  I: Integer;
begin
  for I := 0 to FSpeakerPopup.Items.Count - 1 do
    FSpeakerPopup.Items[I].Checked :=
      SameText(FCatalog.Speakers[I].UUID, CurrentSpeakerUUID);
  FSpeakerPopup.Popup(X, Y);
end;

procedure TSerifVoicevoxSpeakerMenu.SpeakerItemClick(Sender: TObject);
var
  SpeakerIndex: Integer;
  Speaker: TSerifVoicevoxSpeaker;
begin
  if not (Sender is TMenuItem) then Exit;
  SpeakerIndex := TMenuItem(Sender).Tag;
  if (SpeakerIndex < 0) or (SpeakerIndex >= FCatalog.Speakers.Count) then Exit;
  Speaker := FCatalog.Speakers[SpeakerIndex];
  if (Speaker.Styles.Count > 0) and Assigned(FOnSelected) then
    FOnSelected(Self, Speaker, Speaker.Styles[0]);
end;

procedure TSerifVoicevoxSpeakerMenu.ItemClick(Sender: TObject);
var
  SpeakerIndex: Integer;
  Speaker: TSerifVoicevoxSpeaker;
  Style: TSerifVoicevoxStyle;
begin
  if not (Sender is TMenuItem) then Exit;
  SpeakerIndex := TMenuItem(Sender).Parent.Tag;
  if (SpeakerIndex < 0) or (SpeakerIndex >= FCatalog.Speakers.Count) then Exit;
  Speaker := FCatalog.Speakers[SpeakerIndex];
  Style := Speaker.FindStyle(TMenuItem(Sender).Tag);
  if Assigned(Style) and Assigned(FOnSelected) then
    FOnSelected(Self, Speaker, Style);
end;

procedure TSerifVoicevoxSpeakerMenu.Popup(const X, Y,
  CurrentStyleId: Integer);
begin
  UpdateChecks(CurrentStyleId);
  FPopup.Popup(X, Y);
end;

procedure TSerifVoicevoxSpeakerMenu.UpdateChecks(const StyleId: Integer);
var
  I: Integer;
  J: Integer;
begin
  for I := 0 to FPopup.Items.Count - 1 do
    for J := 0 to FPopup.Items[I].Count - 1 do
      FPopup.Items[I].Items[J].Checked :=
        FPopup.Items[I].Items[J].Tag = StyleId;
end;

end.
