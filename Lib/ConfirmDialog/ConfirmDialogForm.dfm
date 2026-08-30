object FormConfirmDialog: TFormConfirmDialog
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = #30906#35469
  ClientHeight = 56
  ClientWidth = 199
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  OnResize = FormResize
  OnShow = FormShow
  TextHeight = 15
  object PanelCaption: TDarkPanel
    Left = 0
    Top = 0
    Width = 199
    Height = 35
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
  end
  object Panel1: TDarkPanel
    Left = 0
    Top = 35
    Width = 199
    Height = 21
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object sbtnOk: TSpeedButton
      Left = 75
      Top = 0
      Width = 23
      Height = 21
      Align = alLeft
      Caption = 'OK'
      Visible = False
      ExplicitLeft = 64
      ExplicitTop = -1
      ExplicitHeight = 22
    end
    object sbtnCancel: TSpeedButton
      Left = 101
      Top = 0
      Width = 23
      Height = 21
      Align = alRight
      Caption = #12461#12515#12531#12475#12523
      Visible = False
      ExplicitLeft = 64
      ExplicitTop = -1
      ExplicitHeight = 22
    end
    object btnOk: TButton
      Left = 0
      Top = 0
      Width = 75
      Height = 21
      Align = alLeft
      Caption = 'OK'
      Default = True
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 124
      Top = 0
      Width = 75
      Height = 21
      Align = alRight
      Cancel = True
      Caption = #12461#12515#12531#12475#12523
      TabOrder = 1
    end
  end
end
