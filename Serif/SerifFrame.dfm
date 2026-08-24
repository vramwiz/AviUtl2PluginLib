object FrameSerif: TFrameSerif
  Left = 0
  Top = 0
  Width = 640
  Height = 480
  TabOrder = 0
  object PanelClient: TPanel
    Left = 0
    Top = 48
    Width = 640
    Height = 432
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object PanelChara: TPanel
      Left = 0
      Top = 0
      Width = 640
      Height = 432
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 0
    end
    object PanelConfig: TPanel
      Left = 0
      Top = 0
      Width = 640
      Height = 432
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
    end
    object PanelProject: TPanel
      Left = 0
      Top = 0
      Width = 640
      Height = 432
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 3
    end
    object PanelScenario: TPanel
      Left = 0
      Top = 0
      Width = 640
      Height = 432
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 4
    end
    object PanelSerif: TPanel
      Left = 0
      Top = 0
      Width = 640
      Height = 432
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 5
    end
    object PanelDraw: TPanel
      Left = 0
      Top = 0
      Width = 640
      Height = 432
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 6
    end
    object PanelView: TPanel
      Left = 0
      Top = 0
      Width = 640
      Height = 432
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 7
    end
    object PanelBoard: TPanel
      Left = 0
      Top = 0
      Width = 640
      Height = 432
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 8
    end
  end
  object ToolBar1: TToolBar
    Left = 0
    Top = 23
    Width = 640
    Height = 25
    AutoSize = True
    ButtonHeight = 23
    ButtonWidth = 35
    Caption = 'ToolBar1'
    Flat = False
    ShowCaptions = True
    TabOrder = 1
    object tbSerif: TToolButton
      Left = 0
      Top = 0
      Caption = #12475#12522#12501
      ImageIndex = 2
      Style = tbsCheck
    end
    object tbChara: TToolButton
      Left = 35
      Top = 0
      Caption = #37197#24441
      ImageIndex = 4
    end
    object tbConfig: TToolButton
      Left = 70
      Top = 0
      Caption = #35373#23450
      ImageIndex = 6
    end
    object tbNewText: TToolButton
      Left = 105
      Top = 0
      Caption = #26032#12475#12522#12501#34920#31034
      ImageIndex = 7
    end
    object tbView: TToolButton
      Left = 140
      Top = 0
      Caption = #12475#12522#12501#34920#31034
      ImageIndex = 8
    end
    object tbBoard: TToolButton
      Left = 175
      Top = 0
      Caption = #26528
      ImageIndex = 9
      Visible = False
    end
    object tbScenario: TToolButton
      Left = 210
      Top = 0
      Caption = #33050#26412
      ImageIndex = 1
      Style = tbsCheck
    end
    object tbProject: TToolButton
      Left = 245
      Top = 0
      Caption = #21488#26412
      ImageIndex = 0
      Style = tbsCheck
    end
  end
  object PanelMonitor: TPanel
    Left = 0
    Top = 0
    Width = 640
    Height = 23
    Align = alTop
    AutoSize = True
    TabOrder = 2
  end
end
