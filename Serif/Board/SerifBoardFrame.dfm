object FrameSerifBoard: TFrameSerifBoard
  Left = 0
  Top = 0
  Width = 395
  Height = 269
  PopupMenu = MenuPop
  TabOrder = 0
  object Splitter1: TSplitter
    Left = 0
    Top = 208
    Width = 395
    Height = 5
    Cursor = crVSplit
    Align = alBottom
    Beveled = True
    MinSize = 50
    ExplicitTop = 205
    ExplicitWidth = 435
  end
  object LBoxStyle: TListBox
    Left = 0
    Top = 23
    Width = 395
    Height = 73
    Align = alTop
    ItemHeight = 15
    TabOrder = 0
    OnClick = LBoxStyleClick
  end
  object CBoxResolution: TComboBox
    Left = 0
    Top = 0
    Width = 395
    Height = 23
    Align = alTop
    Style = csDropDownList
    TabOrder = 1
    OnChange = CBoxResolutionChange
  end
  object PanelConfig: TPanel
    Left = 0
    Top = 213
    Width = 395
    Height = 56
    Align = alBottom
    BevelOuter = bvNone
    Constraints.MinHeight = 56
    TabOrder = 2
  end
  object MenuPop: TPopupMenu
    Left = 88
    Top = 120
    object MenuFolderOpen: TMenuItem
      Caption = #26528#30011#20687#12501#12457#12523#12480#12434#38283#12367
      OnClick = MenuFolderOpenClick
    end
  end
end
