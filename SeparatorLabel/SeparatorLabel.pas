unit SeparatorLabel;

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Graphics,
  Winapi.Windows;

type
  TTextAlignment = (taLeft, taCenter, taRight);

  TSeparatorLabel = class(TCustomControl)
  private
    FCaption     : string;     // 表示文字
    FColor       : TColor;     // 背景色
    FFontColor   : TColor;     // 文字色
    FAlignment   : TTextAlignment; // 文字の位置

    procedure SetCaption(const Value: string);
    procedure SetBackColor(const Value: TColor);
    procedure SetFontColor(const Value: TColor);
    procedure SetAlignment(const Value: TTextAlignment);

  protected
    procedure Paint; override;

  public
    constructor Create(AOwner: TComponent); override;

  published
    property Caption: string read FCaption write SetCaption;
    property BackColor: TColor read FColor write SetBackColor;
    property FontColor: TColor read FFontColor write SetFontColor;
    property TextAlignment: TTextAlignment read FAlignment write SetAlignment;

    // TGraphicControl なので Align/Margins は自動的に利用可能
    property Align;
    property AlignWithMargins;
    property Margins;
    property Visible;
    property Height;
    property Width;
  end;

implementation

{ TSeparatorLabel }

constructor TSeparatorLabel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FCaption := 'Separator';
  FColor := $F0F0F0;     // デフォルト薄グレー
  FFontColor := clBlack; // 文字色
  FAlignment := taLeft;

  Height := 24; // デフォルト高さ
  Width := 200;

end;

procedure TSeparatorLabel.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Invalidate;
  end;
end;

procedure TSeparatorLabel.SetBackColor(const Value: TColor);
begin
  if FColor <> Value then
  begin
    FColor := Value;
    Invalidate;
  end;
end;

procedure TSeparatorLabel.SetFontColor(const Value: TColor);
begin
  if FFontColor <> Value then
  begin
    FFontColor := Value;
    Invalidate;
  end;
end;

procedure TSeparatorLabel.SetAlignment(const Value: TTextAlignment);
begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    Invalidate;
  end;
end;

procedure TSeparatorLabel.Paint;
var
  R: TRect;
  Flags: Longint;
begin
  R := ClientRect;

  // 背景
  Canvas.Brush.Color := FColor;
  Canvas.FillRect(R);

  // 文字描画設定
  Canvas.Font.Color := FFontColor;

  case FAlignment of
    taLeft:   Flags := DT_LEFT or DT_VCENTER or DT_SINGLELINE;
    taCenter: Flags := DT_CENTER or DT_VCENTER or DT_SINGLELINE;
    taRight:  Flags := DT_RIGHT or DT_VCENTER or DT_SINGLELINE;
  else
    Flags := DT_LEFT;
  end;

  DrawText(Canvas.Handle, PChar(FCaption), -1, R, Flags);
end;

end.

