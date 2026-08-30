object FrameSerifDrawFrameEditor: TFrameSerifDrawFrameEditor
  Left = 0
  Top = 0
  Width = 726
  Height = 352
  Align = alClient
  TabOrder = 0
  object PreviewHostPanel: TPanel
    Left = 0
    Top = 68
    Width = 550
    Height = 284
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
  end
  object TypePanel: TPanel
    Left = 0
    Top = 0
    Width = 726
    Height = 68
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object FrameKindComboBox: TComboBox
      Left = 8
      Top = 8
      Width = 112
      Height = 23
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 0
      OnChange = FrameKindComboBoxChange
      OnDrawItem = FrameKindComboBoxDrawItem
    end
    object FrameShapeComboBox: TComboBox
      Left = 126
      Top = 8
      Width = 104
      Height = 23
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 1
      OnChange = FrameShapeComboBoxChange
      OnDrawItem = FrameKindComboBoxDrawItem
    end
    object FrameLayerComboBox: TComboBox
      Left = 236
      Top = 8
      Width = 390
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 2
      OnChange = FrameLayerComboBoxChange
      OnDrawItem = FrameKindComboBoxDrawItem
    end
    object FrameOutlineStyleComboBox: TComboBox
      Left = 236
      Top = 8
      Width = 88
      Height = 23
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 3
      OnChange = FrameOutlineStyleComboBoxChange
      OnDrawItem = FrameKindComboBoxDrawItem
    end
    object FrameLayeringComboBox: TComboBox
      Left = 236
      Top = 8
      Width = 96
      Height = 23
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 4
      OnChange = FrameLayeringComboBoxChange
      OnDrawItem = FrameKindComboBoxDrawItem
    end
    object FramePresetComboBox: TComboBox
      Left = 236
      Top = 8
      Width = 112
      Height = 23
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 5
      OnChange = FramePresetComboBoxChange
      OnDrawItem = FrameKindComboBoxDrawItem
    end
    object FrameAccentSourceComboBox: TComboBox
      Left = 236
      Top = 8
      Width = 80
      Height = 23
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 6
      OnChange = FrameAccentSourceComboBoxChange
      OnDrawItem = FrameKindComboBoxDrawItem
    end
    object FrameLayoutPresetComboBox: TComboBox
      Left = 236
      Top = 8
      Width = 112
      Height = 23
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 7
      OnChange = FrameLayoutPresetComboBoxChange
      OnDrawItem = FrameKindComboBoxDrawItem
    end
    object FrameColorPresetComboBox: TComboBox
      Left = 236
      Top = 8
      Width = 112
      Height = 23
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 8
      OnChange = FrameColorPresetComboBoxChange
      OnDrawItem = FrameKindComboBoxDrawItem
    end
    object FrameFillModeComboBox: TComboBox
      Left = 464
      Top = 39
      Width = 104
      Height = 23
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 9
      OnChange = FrameFillModeComboBoxChange
      OnDrawItem = FrameKindComboBoxDrawItem
    end
    object FrameGradientStrengthLabel: TLabel
      Left = 574
      Top = 43
      Width = 64
      Height = 15
      Caption = #26126#26263#24046' 30%'
    end
    object FrameGradientStrengthTrackBar: TTrackBar
      Left = 644
      Top = 37
      Width = 74
      Height = 28
      Max = 100
      Frequency = 10
      Position = 30
      ShowSelRange = False
      ShowHint = True
      TabOrder = 10
      TickStyle = tsNone
      OnChange = FrameGradientStrengthTrackBarChange
    end
  end
  object CommonSettingsHostPanel: TPanel
    Left = 550
    Top = 68
    Width = 176
    Height = 284
    Align = alRight
    BevelOuter = bvNone
    Color = 2500134
    ParentBackground = False
    TabOrder = 2
  end
end
