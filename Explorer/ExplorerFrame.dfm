object FrameExplorer: TFrameExplorer
  Left = 0
  Top = 0
  Width = 640
  Height = 480
  TabOrder = 0
  object Splitter1: TSplitter
    Left = 0
    Top = 385
    Width = 640
    Height = 3
    Cursor = crVSplit
    Align = alBottom
    ExplicitTop = 383
  end
  object Splitter2: TSplitter
    Left = 0
    Top = 154
    Width = 640
    Height = 3
    Cursor = crVSplit
    Align = alTop
    ExplicitTop = 129
  end
  object PanelConfig: TDarkPanel
    Left = 0
    Top = 388
    Width = 640
    Height = 92
    Align = alBottom
    Constraints.MinHeight = 92
    TabOrder = 0
    Visible = False
  end
  object PanelExplorer: TDarkPanel
    Left = 0
    Top = 157
    Width = 640
    Height = 228
    Align = alClient
    TabOrder = 1
  end
  object PanelTool: TDarkPanel
    Left = 0
    Top = 0
    Width = 640
    Height = 25
    Align = alTop
    AutoSize = True
    Color = clBlack
    ParentBackground = False
    TabOrder = 2
    object ToolBar1: TToolBar
      Left = 1
      Top = 1
      Width = 638
      Height = 23
      AutoSize = True
      ButtonHeight = 23
      ButtonWidth = 62
      Caption = 'ToolBar1'
      Color = clBtnFace
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clBlack
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentColor = False
      ParentFont = False
      ShowCaptions = True
      TabOrder = 0
      object tbFavorite: TToolButton
        Left = 0
        Top = 0
        Caption = #12362#27671#12395#20837#12426
        ImageIndex = 0
      end
      object tbTree: TToolButton
        Left = 62
        Top = 0
        Caption = #12484#12522#12540
        ImageIndex = 1
      end
    end
  end
  object PanelEdit: TDarkPanel
    Left = 0
    Top = 25
    Width = 640
    Height = 129
    Align = alTop
    TabOrder = 3
    object PanelFavorite: TDarkPanel
      Left = 1
      Top = 130
      Width = 638
      Height = 129
      Align = alTop
      TabOrder = 0
    end
    object PanelTree: TDarkPanel
      Left = 1
      Top = 1
      Width = 638
      Height = 129
      Align = alTop
      Constraints.MinHeight = 129
      TabOrder = 1
    end
  end
  object TimerDandD: TTimer
    Enabled = False
    OnTimer = TimerDandDTimer
    Left = 216
    Top = 280
  end
end
