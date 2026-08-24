object FramePsdFileImageScale: TFramePsdFileImageScale
  Left = 0
  Top = 0
  Width = 128
  Height = 128
  TabOrder = 0
  OnExit = FrameExit
  object ImageScale: TImage
    Left = 0
    Top = 0
    Width = 128
    Height = 128
    Cursor = crSizeAll
    Margins.Left = 6
    Margins.Top = 6
    Margins.Right = 6
    Margins.Bottom = 6
    OnMouseDown = ImageScaleMouseDown
    OnMouseMove = ImageScaleMouseMove
    OnMouseUp = ImageScaleMouseUp
  end
end
