object FrameLauncherWizard: TFrameLauncherWizard
  Left = 0
  Top = 0
  Width = 365
  Height = 480
  TabOrder = 0
  object Panel1: TPanel
    Left = 0
    Top = 456
    Width = 365
    Height = 24
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object btnOk: TButton
      Left = 72
      Top = 0
      Width = 75
      Height = 25
      Caption = #30331#37682
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 216
      Top = 0
      Width = 75
      Height = 25
      Caption = #12461#12515#12531#12475#12523
      TabOrder = 1
    end
  end
  object MenuPopup: TPopupMenu
    Left = 120
    Top = 120
    object MenuAppRefresh: TMenuItem
      Caption = #26368#26032#12398#24773#22577#12395#26356#26032
      OnClick = MenuAppRefreshClick
    end
  end
end
