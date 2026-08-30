object FormSerifDrawSettings: TFormSerifDrawSettings
  Left = 0
  Top = 0
  Caption = 'セリフの配置・装飾を編集'
  ClientHeight = 390
  ClientWidth = 726
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnMouseWheel = FormMouseWheel
  TextHeight = 15
  object PreviewPaintBox: TPaintBox
    Left = 0
    Top = 38
    Width = 726
    Height = 352
    Align = alClient
    OnDblClick = PreviewPaintBoxDblClick
    OnMouseDown = PreviewPaintBoxMouseDown
    OnMouseMove = PreviewPaintBoxMouseMove
    OnMouseUp = PreviewPaintBoxMouseUp
    OnPaint = PreviewPaintBoxPaint
  end
  object ModePanel: TPanel
    Left = 0
    Top = 0
    Width = 726
    Height = 38
    Align = alTop
    BevelOuter = bvNone
    Caption = ''
    TabOrder = 0
  end
end
