object FrameSerifMonitor: TFrameSerifMonitor
  Left = 0
  Top = 0
  Width = 200
  Height = 25
  TabOrder = 0
  object btnStartStop: TButton
    Left = 0
    Top = 0
    Width = 57
    Height = 25
    Align = alLeft
    Caption = #38283#22987
    Font.Height = -13
    ParentFont = False
    PopupMenu = MenuPop
    TabOrder = 0
    OnClick = btnStartStopClick
  end
  object PanelBase: TDarkPanel
    Left = 57
    Top = 0
    Width = 143
    Height = 25
    Align = alClient
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 1
    object LabelStatus: TDarkLabel
      Left = 6
      Top = 3
      Width = 26
      Height = 15
      Caption = #20572#27490
    end
  end
  object MenuPop: TPopupMenu
    Left = 172
    Top = 65533
    object MenuDelete: TMenuItem
      Caption = #30435#35222#12501#12457#12523#12480#12398#12501#12449#12452#12523#12434#21066#38500
      OnClick = MenuDeleteClick
    end
  end
  object PopupMenu1: TPopupMenu
    Left = 172
    Top = 65533
    object MenuItem1: TMenuItem
      Caption = #30435#35222#12501#12457#12523#12480#12398#12501#12449#12452#12523#12434#21066#38500
      ShortCut = 16430
      OnClick = MenuDeleteClick
    end
  end
end
