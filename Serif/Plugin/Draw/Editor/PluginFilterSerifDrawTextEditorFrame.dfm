object FrameSerifDrawTextEditor: TFrameSerifDrawTextEditor
  Left = 0
  Top = 0
  Width = 726
  Height = 352
  Align = alClient
  TabOrder = 0
  object PreviewHostPanel: TPanel
    Left = 0
    Top = 38
    Width = 550
    Height = 314
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
  end
  object TopPanel: TPanel
    Left = 0
    Top = 0
    Width = 726
    Height = 38
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object FontComboBox: TComboBox
      Left = 416
      Top = 8
      Width = 180
      Height = 23
      AutoComplete = True
      Style = csOwnerDrawFixed
      ItemHeight = 20
      Sorted = True
      TabOrder = 0
    end
    object LayerComboBox: TComboBox
      Left = 8
      Top = 8
      Width = 402
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      Style = csOwnerDrawFixed
      ItemHeight = 20
      TabOrder = 1
    end
  end
  object ColorPanel: TPanel
    Left = 550
    Top = 38
    Width = 176
    Height = 314
    Align = alRight
    BevelOuter = bvNone
    Color = 2500134
    ParentBackground = False
    TabOrder = 2
  end
end
