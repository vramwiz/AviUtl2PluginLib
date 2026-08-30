object FrameSerifScene: TFrameSerifScene
  Left = 0
  Top = 0
  Width = 640
  Height = 480
  TabOrder = 0
  object PanelTab: TDarkPanel
    Left = 0
    Top = 0
    Width = 640
    Height = 29
    Align = alTop
    BevelOuter = bvNone
    DesignHeight = 29
    Padding.Left = 6
    Padding.Top = 3
    Padding.Right = 6
    Padding.Bottom = 3
    TabOrder = 0
    object ComboScene: TDarkComboBox
      Left = 6
      Top = 3
      Width = 628
      Height = 23
      Align = alClient
      Style = csDropDownList
      TabOrder = 0
      OnChange = ComboSceneChange
    end
  end
end
