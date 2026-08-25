object FrameListViewEditPluginDialog: TFrameListViewEditPluginDialog
  Left = 0
  Top = 0
  Width = 309
  Height = 23
  TabOrder = 0
  OnResize = FrameResize
  object LBox: TListBox
    Left = 0
    Top = 0
    Width = 309
    Height = 23
    Style = lbOwnerDrawFixed
    Align = alClient
    ItemHeight = 15
    TabOrder = 0
    OnDrawItem = LBoxDrawItem
    ExplicitLeft = 23
    ExplicitWidth = 286
  end
  object DlgColor: TColorDialog
    Left = 144
    Top = 8
  end
  object DlgFont: TFontDialog
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    Left = 208
    Top = 65531
  end
  object DlgOpen: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <>
    Options = []
    Left = 184
  end
end
