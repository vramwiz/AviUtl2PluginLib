object FrameDress: TFrameDress
  Left = 0
  Top = 0
  Width = 320
  Height = 240
  TabOrder = 0
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 320
    Height = 25
    Margins.Left = 6
    Margins.Top = 6
    Margins.Right = 6
    Margins.Bottom = 6
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object Panel3: TPanel
      Left = 0
      Top = 0
      Width = 86
      Height = 25
      Margins.Left = 6
      Margins.Top = 6
      Margins.Right = 6
      Margins.Bottom = 6
      Align = alLeft
      Caption = #36865#20449#12487#12540#12479
      TabOrder = 0
    end
    object cboxSend: TComboBox
      Left = 86
      Top = 0
      Width = 234
      Height = 21
      Margins.Left = 6
      Margins.Top = 6
      Margins.Right = 6
      Margins.Bottom = 6
      Align = alClient
      Style = csDropDownList
      TabOrder = 1
      OnChange = cboxSendChange
      Items.Strings = (
        'PSD'
        #30011#20687
        #21453#36578#27231#33021#20184#12365#30011#20687
        #31435#12385#32117#30011#20687)
    end
  end
  object MenuPop: TPopupMenu
    Left = 120
    Top = 88
    object MenuConfig: TMenuItem
      Caption = #26381#35013#12434#35373#23450
      ShortCut = 114
      OnClick = MenuConfigClick
    end
    object MenuReName: TMenuItem
      Caption = #21517#31216#22793#26356
      ShortCut = 113
      Visible = False
      OnClick = MenuReNameClick
    end
    object MenuUp: TMenuItem
      Caption = #19978#12395#31227#21205
      ShortCut = 8230
      OnClick = MenuUpClick
    end
    object MenuDown: TMenuItem
      Caption = #19979#12395#31227#21205
      ShortCut = 8232
      OnClick = MenuDownClick
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object MenuAdd: TMenuItem
      Caption = #26381#35013#12434#36861#21152
      ShortCut = 16452
      OnClick = MenuAddClick
    end
    object MenuCopy: TMenuItem
      Caption = #26381#35013#12434#12467#12500#12540
      ShortCut = 16451
      OnClick = MenuCopyClick
    end
    object MenuDel: TMenuItem
      Caption = #26381#35013#12434#21066#38500
      ShortCut = 46
      OnClick = MenuDelClick
    end
    object N4: TMenuItem
      Caption = '-'
    end
    object MenuAviUtlRec: TMenuItem
      Caption = 'AviUtl'#12363#12425#21462#24471
      ShortCut = 16466
      Visible = False
      OnClick = MenuAviUtlRecClick
    end
    object MenuAviUtlSend: TMenuItem
      Caption = 'AviUtl'#12408#36865#20449
      ShortCut = 16453
      OnClick = MenuAviUtlSendClick
    end
    object MenuSendPsdtool: TMenuItem
      Caption = 'PSDtoolkite'#12408#36865#20449
      ShortCut = 16471
      Visible = False
    end
  end
end
