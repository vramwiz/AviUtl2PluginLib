object FrameImagePreview: TFrameImagePreview
  Left = 0
  Top = 0
  Width = 640
  Height = 480
  TabOrder = 0
  OnResize = FrameResize
  object scrBox: TScrollBox
    Left = 0
    Top = 0
    Width = 640
    Height = 480
    Align = alClient
    BevelInner = bvNone
    BevelOuter = bvNone
    BorderStyle = bsNone
    TabOrder = 0
    object ImagePsd: TImage
      Left = 0
      Top = 0
      Width = 640
      Height = 480
      Cursor = crSizeAll
      OnMouseDown = ImagePsdMouseDown
      OnMouseMove = ImagePsdMouseMove
      OnMouseUp = ImagePsdMouseUp
    end
  end
end
