// 複数行版VOICEVOX入力GUIの1行分について、話者・本文・確認再生の表示と編集を管理する。
unit SerifVoicevoxInputRow;

interface

uses
  Winapi.Windows, System.Types, System.SysUtils, System.Classes, System.Math, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Graphics, Vcl.Forms,
  SerifCharaIconRenderer, DarkMemo;

type
  TSerifVoicevoxInputRow = class;
  TSerifVoicevoxRowEvent = procedure(Row: TSerifVoicevoxInputRow) of object;
  TSerifVoicevoxRowDeleteEvent = procedure(Row: TSerifVoicevoxInputRow;
    const MoveToPrevious: Boolean) of object;
  TSerifVoicevoxSpeakerClickEvent = procedure(Row: TSerifVoicevoxInputRow;
    Button: TMouseButton) of object;

  TSerifVoicevoxInputRow = class(TPanel)
  private const
    ROW_MIN_HEIGHT = 48;
    TEXT_SERIF = #$30BB#$30EA#$30D5;
  private
    FIconRenderer: TSerifCharaIconRenderer;
    FAccentQueryJson: string;
    FLabelText: TLabel;
    FMemo: TDarkMemo;
    FOnBeforeEdit: TSerifVoicevoxRowEvent;
    FOnDelete: TSerifVoicevoxRowDeleteEvent;
    FOnEditFinished: TSerifVoicevoxRowEvent;
    FOnEnterRow: TSerifVoicevoxRowEvent;
    FOnLayoutRequest: TSerifVoicevoxRowEvent;
    FOnPreview: TSerifVoicevoxRowEvent;
    FOnSpeakerClick: TSerifVoicevoxSpeakerClickEvent;
    FOnTextChanged: TSerifVoicevoxRowEvent;
    FOriginalText: string;
    FLoadingMemo: Boolean;
    FPaintBoxSpeaker: TPaintBox;
    FPaintBoxPreview: TPaintBox;
    FPanelPreview: TPanel;
    FPanelSpeaker: TPanel;
    FPanelText: TPanel;
    FPreviewActive: Boolean;
    FSpeakerName: string;
    FSpeakerUUID: string;
    FStyleId: Integer;
    FStyleName: string;
    FText: string;
    function GetDesiredHeight: Integer;
    function GetCurrentText: string;
    function GetEditing: Boolean;
    function GetTextHeight(const Value: string; AFont: TFont): Integer;
    procedure LabelClick(Sender: TObject);
    procedure MemoChange(Sender: TObject);
    procedure MemoExit(Sender: TObject);
    procedure MemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PaintSpeaker(Sender: TObject);
    procedure PaintPreview(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    procedure RefreshDisplay;
    procedure SetAccentQueryJson(const Value: string);
    procedure SetText(const Value: string);
    procedure SpeakerMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  public
    // アイコン描画器を共有し、話者・本文・プレビューの各領域を動的に生成する。
    constructor Create(AOwner: TComponent;
      AIconRenderer: TSerifCharaIconRenderer); reintroduce;
    // 表示ラベルを編集メモへ切り替え、取消用に現在値を退避する。
    procedure BeginEdit;
    // 編集開始時の本文へ戻して表示モードへ切り替える。
    procedure CancelEdit;
    // メモの本文を採用して表示モードへ切り替える。
    procedure CommitEdit;
    // 話者選択メニューを表示するスクリーン座標を返す。
    function SpeakerPopupPoint: TPoint;
    // Falseでは編集中でも確定し、本文編集へ入れないようにする。
    procedure SetEditingEnabled(const Value: Boolean);
    // この行の生成・再生中は三角を停止用の四角へ切り替える。
    procedure SetPreviewActive(const Value: Boolean);
    // 表示・送信に使う話者UUID、表示名、style名、style IDを一括更新する。
    procedure SetSpeaker(const ASpeakerName, ASpeakerUUID, AStyleName: string;
      const AStyleId: Integer);
    // 折り返した本文を全て表示するために必要な行の高さ。
    property DesiredHeight: Integer read GetDesiredHeight;
    // 編集中はメモ、表示中は確定済み本文から取得する現在値。
    property CurrentText: string read GetCurrentText;
    // 現在の本文・styleに対応する編集済みaudio_query。本文変更時は破棄される。
    property AccentQueryJson: string read FAccentQueryJson write SetAccentQueryJson;
    property Editing: Boolean read GetEditing;
    property OnBeforeEdit: TSerifVoicevoxRowEvent read FOnBeforeEdit write FOnBeforeEdit;
    property OnDelete: TSerifVoicevoxRowDeleteEvent read FOnDelete write FOnDelete;
    property OnEditFinished: TSerifVoicevoxRowEvent read FOnEditFinished write FOnEditFinished;
    property OnEnterRow: TSerifVoicevoxRowEvent read FOnEnterRow write FOnEnterRow;
    property OnLayoutRequest: TSerifVoicevoxRowEvent read FOnLayoutRequest write FOnLayoutRequest;
    property OnPreview: TSerifVoicevoxRowEvent read FOnPreview write FOnPreview;
    property OnSpeakerClick: TSerifVoicevoxSpeakerClickEvent
      read FOnSpeakerClick write FOnSpeakerClick;
    property OnTextChanged: TSerifVoicevoxRowEvent read FOnTextChanged write FOnTextChanged;
    property SerifText: string read FText write SetText;
    property SpeakerName: string read FSpeakerName;
    property SpeakerUUID: string read FSpeakerUUID;
    property StyleId: Integer read FStyleId;
    property StyleName: string read FStyleName;
  end;

// 改行と空白をVOICEVOXへ渡す1行の本文へ正規化する。
function NormalizeSerifVoicevoxText(const Value: string): string;

implementation

uses
  System.UITypes, AviUtl2StyleColors;

function NormalizeSerifVoicevoxText(const Value: string): string;
begin
  Result := StringReplace(Value, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #10, sLineBreak, [rfReplaceAll]);
  Result := Trim(Result);
end;

constructor TSerifVoicevoxInputRow.Create(AOwner: TComponent;
  AIconRenderer: TSerifCharaIconRenderer);
begin
  inherited Create(AOwner);
  FIconRenderer := AIconRenderer;
  FStyleId := -1;
  BevelOuter := bvNone;
  Color := A2SCEditBackground;
  Height := ROW_MIN_HEIGHT;

  FPanelSpeaker := TPanel.Create(Self);
  FPanelSpeaker.Parent := Self;
  FPanelSpeaker.Align := alLeft;
  FPanelSpeaker.BevelOuter := bvNone;
  FPanelSpeaker.Color := A2SCEditBackground;
  FPanelSpeaker.Width := ROW_MIN_HEIGHT;
  FPanelSpeaker.ShowHint := True;
  FPanelSpeaker.OnMouseDown := SpeakerMouseDown;

  FPaintBoxSpeaker := TPaintBox.Create(Self);
  FPaintBoxSpeaker.Parent := FPanelSpeaker;
  FPaintBoxSpeaker.Align := alClient;
  FPaintBoxSpeaker.ShowHint := True;
  FPaintBoxSpeaker.OnMouseDown := SpeakerMouseDown;
  FPaintBoxSpeaker.OnPaint := PaintSpeaker;

  FPanelPreview := TPanel.Create(Self);
  FPanelPreview.Parent := Self;
  FPanelPreview.Align := alLeft;
  FPanelPreview.BevelOuter := bvNone;
  FPanelPreview.Color := A2SCEditBackground;
  FPanelPreview.Width := 32;

  FPaintBoxPreview := TPaintBox.Create(Self);
  FPaintBoxPreview.Parent := FPanelPreview;
  FPaintBoxPreview.Align := alClient;
  FPaintBoxPreview.Cursor := crHandPoint;
  FPaintBoxPreview.Hint := #$518D#$751F;
  FPaintBoxPreview.ShowHint := True;
  FPaintBoxPreview.OnClick := PreviewClick;
  FPaintBoxPreview.OnPaint := PaintPreview;

  FPanelText := TPanel.Create(Self);
  FPanelText.Parent := Self;
  FPanelText.Align := alClient;
  FPanelText.BevelOuter := bvNone;
  FPanelText.Color := A2SCEditBackground;
  FPanelText.Padding.SetBounds(6, 4, 4, 4);

  FLabelText := TLabel.Create(Self);
  FLabelText.Parent := FPanelText;
  FLabelText.Align := alClient;
  FLabelText.Alignment := taLeftJustify;
  FLabelText.AutoSize := False;
  FLabelText.Cursor := crIBeam;
  FLabelText.Font.Color := A2SCEditText;
  FLabelText.Font.Height := -11;
  FLabelText.Layout := tlCenter;
  FLabelText.WordWrap := True;
  FLabelText.OnClick := LabelClick;

  FMemo := TDarkMemo.Create(Self);
  FMemo.Parent := FPanelText;
  FMemo.Align := alClient;
  FMemo.BorderStyle := bsNone;
  FMemo.DesignFontHeight := 11;
  FMemo.ScrollBars := ssNone;
  FMemo.WantReturns := True;
  FMemo.WordWrap := True;
  FMemo.OnChange := MemoChange;
  FMemo.OnExit := MemoExit;
  FMemo.OnKeyDown := MemoKeyDown;
  FMemo.Visible := False;
  RefreshDisplay;
end;

procedure TSerifVoicevoxInputRow.BeginEdit;
begin
  if Editing then
  begin
    if FMemo.CanFocus then FMemo.SetFocus;
    Exit;
  end;
  if Assigned(FOnBeforeEdit) then FOnBeforeEdit(Self);
  FOriginalText := FText;
  FLoadingMemo := True;
  try
    FMemo.Text := FText;
  finally
    FLoadingMemo := False;
  end;
  FLabelText.Visible := False;
  FMemo.Visible := True;
  FMemo.BringToFront;
  if FMemo.CanFocus then
  begin
    FMemo.SetFocus;
    FMemo.SelStart := Length(FMemo.Text);
  end;
end;

procedure TSerifVoicevoxInputRow.CancelEdit;
begin
  FText := FOriginalText;
  FMemo.Visible := False;
  RefreshDisplay;
  if Assigned(FOnEditFinished) then FOnEditFinished(Self);
  if Assigned(FOnLayoutRequest) then FOnLayoutRequest(Self);
end;

procedure TSerifVoicevoxInputRow.CommitEdit;
begin
  FText := NormalizeSerifVoicevoxText(FMemo.Text);
  FMemo.Visible := False;
  RefreshDisplay;
  if Assigned(FOnEditFinished) then FOnEditFinished(Self);
  if Assigned(FOnLayoutRequest) then FOnLayoutRequest(Self);
end;

function TSerifVoicevoxInputRow.GetDesiredHeight: Integer;
var
  TextHeight: Integer;
begin
  if Editing then TextHeight := GetTextHeight(FMemo.Text, FMemo.Font)
  else TextHeight := GetTextHeight(FText, FLabelText.Font);
  Result := Max(ROW_MIN_HEIGHT, TextHeight + 8);
end;

function TSerifVoicevoxInputRow.GetCurrentText: string;
begin
  if Editing then Result := NormalizeSerifVoicevoxText(FMemo.Text)
  else Result := FText;
end;

function TSerifVoicevoxInputRow.GetEditing: Boolean;
begin
  Result := FMemo.Visible;
end;

function TSerifVoicevoxInputRow.GetTextHeight(const Value: string;
  AFont: TFont): Integer;
var
  Canvas: TCanvas;
  DC: HDC;
  DrawRect: TRect;
  TextWidth: Integer;
begin
  TextWidth := Max(Width - FPanelSpeaker.Width - FPanelPreview.Width -
    FPanelText.Padding.Left - FPanelText.Padding.Right, 1);
  DrawRect := Rect(0, 0, TextWidth, 0);
  DC := GetDC(0);
  Canvas := TCanvas.Create;
  try
    Canvas.Handle := DC;
    try
      Canvas.Font.Assign(AFont);
      Winapi.Windows.DrawText(Canvas.Handle, PChar(Value), Length(Value),
        DrawRect, DT_CALCRECT or DT_WORDBREAK or DT_EDITCONTROL or DT_NOPREFIX);
      Result := DrawRect.Bottom - DrawRect.Top;
    finally
      Canvas.Handle := 0;
    end;
  finally
    Canvas.Free;
    ReleaseDC(0, DC);
  end;
end;

procedure TSerifVoicevoxInputRow.LabelClick(Sender: TObject);
begin
  BeginEdit;
end;

procedure TSerifVoicevoxInputRow.MemoChange(Sender: TObject);
begin
  if FLoadingMemo then Exit;
  if NormalizeSerifVoicevoxText(FMemo.Text) <> FText then
    FAccentQueryJson := '';
  if Assigned(FOnTextChanged) then FOnTextChanged(Self);
  if Assigned(FOnLayoutRequest) then FOnLayoutRequest(Self);
end;

procedure TSerifVoicevoxInputRow.MemoExit(Sender: TObject);
begin
  if Editing then CommitEdit;
end;

procedure TSerifVoicevoxInputRow.MemoKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  PressedKey: Word;
begin
  PressedKey := Key;
  if (PressedKey in [VK_DELETE, VK_BACK]) and
    (NormalizeSerifVoicevoxText(FMemo.Text) = '') then
  begin
    Key := 0;
    if Assigned(FOnDelete) then FOnDelete(Self, PressedKey = VK_BACK);
    Exit;
  end;
  case PressedKey of
    VK_RETURN:
      if not (ssShift in Shift) then
      begin
        Key := 0;
        CommitEdit;
        if Assigned(FOnEnterRow) then FOnEnterRow(Self);
      end;
    VK_ESCAPE:
      begin
        Key := 0;
        CancelEdit;
      end;
  end;
end;

procedure TSerifVoicevoxInputRow.PaintSpeaker(Sender: TObject);
var
  Box: TRect;
  IconRect: TRect;
begin
  Box := FPaintBoxSpeaker.ClientRect;
  FPaintBoxSpeaker.Canvas.Brush.Color := RGB(65, 72, 82);
  FPaintBoxSpeaker.Canvas.FillRect(Box);
  IconRect := Rect(Box.Left, Box.Top, Box.Left + Min(Box.Width, ROW_MIN_HEIGHT),
    Box.Top + Min(Box.Height, ROW_MIN_HEIGHT));
  if Assigned(FIconRenderer) and (FSpeakerName <> '') then
    FIconRenderer.DrawOrFallback(FPaintBoxSpeaker.Canvas, FSpeakerName,
      IconRect);
end;

procedure TSerifVoicevoxInputRow.PaintPreview(Sender: TObject);
var
  CenterX: Integer;
  CenterY: Integer;
  Triangle: array[0..2] of TPoint;
begin
  FPaintBoxPreview.Canvas.Brush.Color := A2SCEditBackground;
  FPaintBoxPreview.Canvas.FillRect(FPaintBoxPreview.ClientRect);
  CenterX := FPaintBoxPreview.ClientWidth div 2;
  CenterY := FPaintBoxPreview.ClientHeight div 2;
  FPaintBoxPreview.Canvas.Brush.Color := RGB(166, 216, 178);
  FPaintBoxPreview.Canvas.Pen.Color := RGB(166, 216, 178);
  FPaintBoxPreview.Canvas.Pen.Width := 1;
  FPaintBoxPreview.Canvas.Ellipse(CenterX - 11, CenterY - 11,
    CenterX + 11, CenterY + 11);
  FPaintBoxPreview.Canvas.Brush.Style := bsSolid;
  FPaintBoxPreview.Canvas.Brush.Color := clBlack;
  FPaintBoxPreview.Canvas.Pen.Color := clBlack;
  if FPreviewActive then
  begin
    FPaintBoxPreview.Canvas.Rectangle(CenterX - 4, CenterY - 4,
      CenterX + 5, CenterY + 5);
    Exit;
  end;
  Triangle[0] := Point(CenterX - 3, CenterY - 6);
  Triangle[1] := Point(CenterX - 3, CenterY + 6);
  Triangle[2] := Point(CenterX + 6, CenterY);
  FPaintBoxPreview.Canvas.Polygon(Triangle);
end;

procedure TSerifVoicevoxInputRow.PreviewClick(Sender: TObject);
begin
  if FPaintBoxPreview.Enabled and Assigned(FOnPreview) then FOnPreview(Self);
end;

procedure TSerifVoicevoxInputRow.RefreshDisplay;
begin
  if FText = '' then FLabelText.Caption := TEXT_SERIF
  else FLabelText.Caption := FText;
  FLabelText.Visible := not FMemo.Visible;
end;

procedure TSerifVoicevoxInputRow.SetEditingEnabled(const Value: Boolean);
begin
  FMemo.Enabled := Value;
  FLabelText.Enabled := Value;
  FPaintBoxPreview.Enabled := Value;
end;

procedure TSerifVoicevoxInputRow.SetAccentQueryJson(const Value: string);
begin
  FAccentQueryJson := Value;
end;

procedure TSerifVoicevoxInputRow.SetPreviewActive(const Value: Boolean);
begin
  if FPreviewActive = Value then Exit;
  FPreviewActive := Value;
  if Value then FPaintBoxPreview.Hint := #$505C#$6B62
  else FPaintBoxPreview.Hint := #$518D#$751F;
  FPaintBoxPreview.Invalidate;
end;

procedure TSerifVoicevoxInputRow.SetSpeaker(const ASpeakerName, ASpeakerUUID,
  AStyleName: string; const AStyleId: Integer);
var
  HintText: string;
begin
  if (FSpeakerUUID <> ASpeakerUUID) or (FStyleId <> AStyleId) then
    FAccentQueryJson := '';
  FSpeakerName := ASpeakerName;
  FSpeakerUUID := ASpeakerUUID;
  FStyleName := AStyleName;
  FStyleId := AStyleId;
  HintText := FSpeakerName;
  if FStyleName <> '' then HintText := HintText + ' / ' + FStyleName;
  FPanelSpeaker.Hint := HintText;
  FPaintBoxSpeaker.Hint := HintText;
  FPaintBoxSpeaker.Invalidate;
end;

procedure TSerifVoicevoxInputRow.SetText(const Value: string);
var
  NormalizedText: string;
begin
  NormalizedText := NormalizeSerifVoicevoxText(Value);
  if FText <> NormalizedText then FAccentQueryJson := '';
  FText := NormalizedText;
  FMemo.Visible := False;
  RefreshDisplay;
end;

procedure TSerifVoicevoxInputRow.SpeakerMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button in [mbLeft, mbRight]) and Assigned(FOnSpeakerClick) then
    FOnSpeakerClick(Self, Button);
end;

function TSerifVoicevoxInputRow.SpeakerPopupPoint: TPoint;
begin
  Result := FPaintBoxSpeaker.ClientToScreen(Point(0, FPaintBoxSpeaker.Height));
end;

end.
