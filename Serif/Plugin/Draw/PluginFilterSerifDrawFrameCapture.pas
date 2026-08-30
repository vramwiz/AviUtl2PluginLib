unit PluginFilterSerifDrawFrameCapture;

interface

uses
  System.SysUtils,
  AviUtl2FilterTypes;

procedure InitializeSerifDrawFrameCapture;
procedure FinalizeSerifDrawFrameCapture;
procedure CaptureSerifDrawFrame(Video: PFILTER_PROC_VIDEO);
function CopySerifDrawFrame(out Pixels: TBytes; out Width, Height: Integer;
  out Status: string): Boolean;

implementation

uses
  System.Math,
  PluginFilterSerifDrawDebugLog,
  Winapi.D3D11,
  Winapi.DXGIFormat,
  Winapi.Windows;

const
  MAX_CAPTURE_DIMENSION = 16384;
  // 設定画面の背景用なので、再生中の全フレームをGPUから読み戻さない。
  // 同じフレームに留まった時だけ更新し、停止後の表示を設定画面へ渡す。
  STATIONARY_CAPTURE_DELAY_MS = 250;

type
  TPixelWords = array[0..3] of Word;
  PPixelWords = ^TPixelWords;

var
  CaptureBuffer: Pointer;
  CaptureBufferSize: NativeInt;
  CaptureDevice: ID3D11Device;
  CaptureFormat: DXGI_FORMAT;
  CaptureHeight: Integer;
  CaptureInitialized: Boolean;
  CaptureLastObjectID: Int64;
  CaptureLastObservedFrame: Integer;
  CaptureLastTick: UInt64;
  CaptureLock: TRTLCriticalSection;
  CaptureObservationValid: Boolean;
  CaptureStagingTexture: ID3D11Texture2D;
  CaptureStatus: string;
  CaptureWidth: Integer;

function BytesPerPixel(Format: DXGI_FORMAT): Integer;
begin
  case Format of
    DXGI_FORMAT_R8G8B8A8_UNORM,
    DXGI_FORMAT_R8G8B8A8_UNORM_SRGB,
    DXGI_FORMAT_B8G8R8A8_UNORM,
    DXGI_FORMAT_B8G8R8A8_UNORM_SRGB:
      Result := 4;
    DXGI_FORMAT_R16G16B16A16_UNORM,
    DXGI_FORMAT_R16G16B16A16_FLOAT:
      Result := 8;
  else
    Result := 0;
  end;
end;

function HalfToSingle(Value: Word): Single;
var
  Exponent: Integer;
  Mantissa: Cardinal;
  ResultBits: Cardinal;
  SignBits: Cardinal;
begin
  SignBits := Cardinal(Value and $8000) shl 16;
  Exponent := (Value shr 10) and $1F;
  Mantissa := Value and $03FF;
  if Exponent = 0 then
  begin
    if Mantissa = 0 then
      ResultBits := SignBits
    else
    begin
      Exponent := -14;
      while (Mantissa and $0400) = 0 do
      begin
        Mantissa := Mantissa shl 1;
        Dec(Exponent);
      end;
      Mantissa := Mantissa and $03FF;
      ResultBits := SignBits or Cardinal(Exponent + 127) shl 23 or
        Mantissa shl 13;
    end;
  end
  else if Exponent = $1F then
    ResultBits := SignBits or $7F800000 or Mantissa shl 13
  else
    ResultBits := SignBits or Cardinal(Exponent + 112) shl 23 or
      Mantissa shl 13;
  Result := PSingle(@ResultBits)^;
end;

function FloatToByte(Value: Single): Byte;
begin
  if IsNan(Value) or (Value <= 0) then
    Exit(0);
  if Value >= 1 then
    Exit(255);
  Result := Round(Value * 255);
end;

procedure SetCaptureError(const Value: string);
begin
  CaptureWidth := 0;
  CaptureHeight := 0;
  CaptureBufferSize := 0;
  CaptureStatus := Value;
  SerifDrawDebugLog('Frame capture: ' + Value);
end;

procedure InitializeSerifDrawFrameCapture;
begin
  if CaptureInitialized then
    Exit;
  InitializeCriticalSection(CaptureLock);
  CaptureBuffer := nil;
  CaptureBufferSize := 0;
  CaptureWidth := 0;
  CaptureHeight := 0;
  CaptureStatus := 'No frame has been captured.';
  CaptureLastObjectID := 0;
  CaptureLastObservedFrame := 0;
  CaptureLastTick := 0;
  CaptureObservationValid := False;
  CaptureInitialized := True;
  SerifDrawDebugLog('Frame capture initialized.');
end;

procedure FinalizeSerifDrawFrameCapture;
begin
  if not CaptureInitialized then
    Exit;
  EnterCriticalSection(CaptureLock);
  try
    CaptureStagingTexture := nil;
    CaptureDevice := nil;
    FreeMem(CaptureBuffer);
    CaptureBuffer := nil;
    CaptureBufferSize := 0;
  finally
    LeaveCriticalSection(CaptureLock);
  end;
  DeleteCriticalSection(CaptureLock);
  CaptureInitialized := False;
  SerifDrawDebugLog('Frame capture finalized.');
end;

procedure CaptureSerifDrawFrame(Video: PFILTER_PROC_VIDEO);
var
  ByteCount: NativeInt;
  Context: ID3D11DeviceContext;
  Destination: PByte;
  Device: ID3D11Device;
  Height: Integer;
  Mapped: D3D11_MAPPED_SUBRESOURCE;
  RowBytes: NativeInt;
  Source: PByte;
  SourceDesc: D3D11_TEXTURE2D_DESC;
  SourcePointer: Pointer;
  SourceTexture: ID3D11Texture2D;
  StagingDesc: D3D11_TEXTURE2D_DESC;
  CaptureNow: Boolean;
  CurrentFrame: Integer;
  CurrentObjectID: Int64;
  CurrentTick: UInt64;
  Width: Integer;
  Y: Integer;
begin
  if not CaptureInitialized then
    Exit;
  EnterCriticalSection(CaptureLock);
  try
    try
      if (Video = nil) or (Video^.Object_ = nil) then
        Exit;
      CurrentFrame := Video^.Object_^.FrameS + Video^.Object_^.Frame;
      CurrentObjectID := Video^.Object_^.ID;
      CurrentTick := GetTickCount64;
      CaptureNow := (CaptureBuffer = nil) or not CaptureObservationValid or
        (CurrentObjectID <> CaptureLastObjectID) or
        ((CurrentFrame = CaptureLastObservedFrame) and
         ((CaptureLastTick = 0) or
          (CurrentTick - CaptureLastTick >= STATIONARY_CAPTURE_DELAY_MS)));
      CaptureLastObjectID := CurrentObjectID;
      CaptureLastObservedFrame := CurrentFrame;
      CaptureObservationValid := True;
      if not CaptureNow then
        Exit;
      CaptureLastTick := CurrentTick;
      SourcePointer := nil;
      if Assigned(Video^.GetImageTexture2D) then
        SourcePointer := Video^.GetImageTexture2D();
      if (SourcePointer = nil) and Assigned(Video^.GetFramebufferTexture2D) then
        SourcePointer := Video^.GetFramebufferTexture2D();
      if SourcePointer = nil then
      begin
        SetCaptureError('Image texture is unavailable.');
        Exit;
      end;
      SourceTexture := ID3D11Texture2D(SourcePointer);
      SourceTexture.GetDesc(SourceDesc);
      Width := SourceDesc.Width;
      Height := SourceDesc.Height;
      RowBytes := NativeInt(Width) * BytesPerPixel(SourceDesc.Format);
      if (Width <= 0) or (Height <= 0) or
        (Width > MAX_CAPTURE_DIMENSION) or (Height > MAX_CAPTURE_DIMENSION) or
        (RowBytes = 0) or (SourceDesc.SampleDesc.Count <> 1) then
      begin
        SetCaptureError('Image texture format or size is unsupported.');
        Exit;
      end;
      SourceTexture.GetDevice(Device);
      if Device = nil then
      begin
        SetCaptureError('D3D11 device is unavailable.');
        Exit;
      end;
      if (CaptureStagingTexture = nil) or
        (Pointer(CaptureDevice) <> Pointer(Device)) or
        (CaptureWidth <> Width) or (CaptureHeight <> Height) or
        (CaptureFormat <> SourceDesc.Format) then
      begin
        CaptureStagingTexture := nil;
        CaptureDevice := nil;
        StagingDesc := SourceDesc;
        StagingDesc.MipLevels := 1;
        StagingDesc.ArraySize := 1;
        StagingDesc.Usage := D3D11_USAGE_STAGING;
        StagingDesc.BindFlags := 0;
        StagingDesc.CPUAccessFlags := D3D11_CPU_ACCESS_READ;
        StagingDesc.MiscFlags := 0;
        if Device.CreateTexture2D(StagingDesc, nil,
          CaptureStagingTexture) < 0 then
        begin
          SetCaptureError('Could not create the staging texture.');
          Exit;
        end;
        CaptureDevice := Device;
      end;
      Device.GetImmediateContext(Context);
      Context.CopyResource(CaptureStagingTexture, SourceTexture);
      FillChar(Mapped, SizeOf(Mapped), 0);
      if Context.Map(CaptureStagingTexture, 0, D3D11_MAP_READ, 0, Mapped) < 0 then
      begin
        SetCaptureError('Could not map the staging texture.');
        Exit;
      end;
      try
        ByteCount := RowBytes * Height;
        if CaptureBufferSize <> ByteCount then
        begin
          ReallocMem(CaptureBuffer, ByteCount);
          CaptureBufferSize := ByteCount;
        end;
        Source := Mapped.pData;
        Destination := CaptureBuffer;
        for Y := 0 to Height - 1 do
        begin
          Move(Source^, Destination^, RowBytes);
          Inc(Source, Mapped.RowPitch);
          Inc(Destination, RowBytes);
        end;
      finally
        Context.Unmap(CaptureStagingTexture, 0);
      end;
      CaptureWidth := Width;
      CaptureHeight := Height;
      CaptureFormat := SourceDesc.Format;
      CaptureStatus := Format('Captured %d x %d, DXGI format %d.',
        [Width, Height, Ord(SourceDesc.Format)]);
    except
      on E: Exception do
        SetCaptureError('Frame capture failed: ' + E.Message);
    end;
  finally
    LeaveCriticalSection(CaptureLock);
  end;
end;

function CopySerifDrawFrame(out Pixels: TBytes; out Width, Height: Integer;
  out Status: string): Boolean;
var
  Destination: PByte;
  I: NativeInt;
  PixelCount: NativeInt;
  Source: PByte;
  SourceWords: PPixelWords;
begin
  Pixels := nil;
  Width := 0;
  Height := 0;
  Status := '';
  if not CaptureInitialized then
    Exit(False);
  EnterCriticalSection(CaptureLock);
  try
    Status := CaptureStatus;
    Result := (CaptureBuffer <> nil) and (CaptureBufferSize > 0) and
      (CaptureWidth > 0) and (CaptureHeight > 0);
    if not Result then
      Exit;
    Width := CaptureWidth;
    Height := CaptureHeight;
    PixelCount := NativeInt(Width) * Height;
    SetLength(Pixels, PixelCount * 4);
    Source := CaptureBuffer;
    Destination := @Pixels[0];
    case CaptureFormat of
      DXGI_FORMAT_R8G8B8A8_UNORM,
      DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
        Move(Source^, Destination^, Length(Pixels));
      DXGI_FORMAT_B8G8R8A8_UNORM,
      DXGI_FORMAT_B8G8R8A8_UNORM_SRGB:
        for I := 0 to PixelCount - 1 do
        begin
          Destination[0] := Source[2];
          Destination[1] := Source[1];
          Destination[2] := Source[0];
          Destination[3] := Source[3];
          Inc(Source, 4);
          Inc(Destination, 4);
        end;
      DXGI_FORMAT_R16G16B16A16_UNORM:
        begin
          SourceWords := PPixelWords(Source);
          for I := 0 to PixelCount - 1 do
          begin
            Destination[0] := SourceWords[0] div 257;
            Destination[1] := SourceWords[1] div 257;
            Destination[2] := SourceWords[2] div 257;
            Destination[3] := SourceWords[3] div 257;
            Inc(SourceWords);
            Inc(Destination, 4);
          end;
        end;
      DXGI_FORMAT_R16G16B16A16_FLOAT:
        begin
          SourceWords := PPixelWords(Source);
          for I := 0 to PixelCount - 1 do
          begin
            Destination[0] := FloatToByte(HalfToSingle(SourceWords[0]));
            Destination[1] := FloatToByte(HalfToSingle(SourceWords[1]));
            Destination[2] := FloatToByte(HalfToSingle(SourceWords[2]));
            Destination[3] := Round(EnsureRange(
              HalfToSingle(SourceWords[3]), 0.0, 1.0) * 255);
            Inc(SourceWords);
            Inc(Destination, 4);
          end;
        end;
    else
      Pixels := nil;
      Result := False;
    end;
  finally
    LeaveCriticalSection(CaptureLock);
  end;
end;

end.
