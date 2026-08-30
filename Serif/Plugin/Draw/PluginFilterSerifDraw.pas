unit PluginFilterSerifDraw;

// SerifDrawメディアオブジェクトの初期化と映像コールバックを担当する。

interface

uses
  AviUtl2FilterTypes,
  PluginFilterSerifDrawReceiver;

function InitializeSerifDrawPlugin: Boolean;
procedure FinalizeSerifDrawPlugin;
procedure ProcVideo(Video: PFILTER_PROC_VIDEO);
function CopyKnownSerifDrawSnapshots: TArray<TSerifDrawSnapshot>;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  PluginFilterSerifDrawAnimationController,
  PluginFilterSerifDrawAnimationItems,
  PluginFilterSerifDrawAnimationTypes,
  PluginFilterSerifDrawDebugLog,
  PluginFilterSerifDrawFrameCapture,
  PluginFilterSerifDrawGdiPlus,
  PluginFilterSerifDrawSettings,
  PluginFilterSerifDrawSkia;

type
  TSerifDrawRenderBackend = (GdiPlus, Skia);

const
  ACTIVE_RENDER_BACKEND = TSerifDrawRenderBackend.Skia;

var
  GGdiPlusRender: TSerifGdiPlusRender;
  GLastSnapshots: TArray<TSerifDrawSnapshot>;
  GReceiver: TSerifDrawReceiver;
  GRenderLock: TRTLCriticalSection;
  GSkiaRender: TSerifSkiaRender;
  GAnimationController: TSerifDrawAnimationController;

function InitializeSerifDrawPlugin: Boolean;
begin
  Result := False;
  try
    if (GGdiPlusRender <> nil) or (GSkiaRender <> nil) then
      Exit(True);
    ResetSerifDrawDebugLog;
    SerifDrawDebugLog('Plugin initialization started.');
    InitializeSerifDrawFrameCapture;
    case ACTIVE_RENDER_BACKEND of
      TSerifDrawRenderBackend.GdiPlus:
        begin
          SerifDrawDebugLog('Render backend: GDI+.');
          InitializeSerifDrawGraphics;
          GGdiPlusRender := TSerifGdiPlusRender.Create;
        end;
      TSerifDrawRenderBackend.Skia:
        begin
          SerifDrawDebugLog('Render backend: Skia raster-direct.');
          InitializeSerifDrawSkia;
          GReceiver := TSerifDrawReceiver.Create;
          GAnimationController := TSerifDrawAnimationController.Create;
          GSkiaRender := TSerifSkiaRender.Create;
        end;
    end;
    SerifDrawDebugLog('Plugin initialization completed.');
    Result := True;
  except
    on E: Exception do
    begin
      SerifDrawDebugLog('Initialization failed: ' + E.ClassName + ': ' +
        E.Message);
      FreeAndNil(GSkiaRender);
      FreeAndNil(GAnimationController);
      FreeAndNil(GReceiver);
      FreeAndNil(GGdiPlusRender);
      FinalizeSerifDrawSkia;
      FinalizeSerifDrawGraphics;
      FinalizeSerifDrawFrameCapture;
    end;
  end;
end;

procedure FinalizeSerifDrawPlugin;
begin
  SerifDrawDebugLog('Plugin finalization started.');
  FreeAndNil(GSkiaRender);
  FreeAndNil(GAnimationController);
  FreeAndNil(GReceiver);
  FreeAndNil(GGdiPlusRender);
  GLastSnapshots := nil;
  FinalizeSerifDrawSkia;
  FinalizeSerifDrawGraphics;
  FinalizeSerifDrawFrameCapture;
  SerifDrawDebugLog('Plugin finalization completed.');
end;

function CopyKnownSerifDrawSnapshots: TArray<TSerifDrawSnapshot>;
begin
  EnterCriticalSection(GRenderLock);
  try
    if GReceiver <> nil then
      Result := GReceiver.ReadHistory
    else
      Result := System.Copy(GLastSnapshots, 0, Length(GLastSnapshots));
  finally
    LeaveCriticalSection(GRenderLock);
  end;
end;

procedure ProcVideo(Video: PFILTER_PROC_VIDEO);
var
  AnimationParameters: TSerifDrawAnimationParameters;
  AnimationTransform: TSerifDrawAnimationTransform;
  CurrentFrame: Integer;
  Fps: Double;
  IndexedLayers: TArray<Integer>;
  RenderSnapshots: TArray<TSerifDrawSnapshot>;
  Settings: TSerifDrawSettings;
  Snapshots: TArray<TSerifDrawSnapshot>;
  ValidatedLayers: TArray<Integer>;
{$IFDEF DEBUG}
  I: Integer;
  ObjectFrame: Integer;
  ObjectStart: Integer;
{$ENDIF}
  Layer: Integer;
{$IFDEF DEBUG}
  LayerIsValidated: Boolean;
{$ENDIF}
begin
  try
    if (GGdiPlusRender = nil) and (GSkiaRender = nil) and
      not InitializeSerifDrawPlugin then
      Exit;
    CaptureSerifDrawFrame(Video);
    if (GSkiaRender <> nil) and (GReceiver <> nil) then
    begin
      EnterCriticalSection(GRenderLock);
      try
        if (Video <> nil) and (Video^.Object_ <> nil) then
        begin
          CurrentFrame := Video^.Object_^.FrameS + Video^.Object_^.Frame;
{$IFDEF DEBUG}
          ObjectStart := Video^.Object_^.FrameS;
          ObjectFrame := Video^.Object_^.Frame;
{$ENDIF}
        end
        else
        begin
          CurrentFrame := -1;
{$IFDEF DEBUG}
          ObjectStart := -1;
          ObjectFrame := -1;
{$ENDIF}
        end;
        Fps := 30.0;
        if (Video <> nil) and (Video^.Scene <> nil) and
          (Video^.Scene^.Scale <> 0) then
          Fps := Video^.Scene^.Rate / Video^.Scene^.Scale;
        Settings := CurrentSerifDrawSettings;
        IndexedLayers := GReceiver.ReadIndexedLayers(CurrentFrame);
        if (Video <> nil) and Assigned(Video^.GetImageObject) then
          for Layer in IndexedLayers do
            if Layer > 0 then
              try
{$IFDEF DEBUG}
                LayerIsValidated := False;
{$ENDIF}
                if Video^.GetImageObject(Layer - 1, 0.0) <> nil then
                begin
                  SetLength(ValidatedLayers, Length(ValidatedLayers) + 1);
                  ValidatedLayers[High(ValidatedLayers)] := Layer;
{$IFDEF DEBUG}
                  LayerIsValidated := True;
{$ENDIF}
                end;
{$IFDEF DEBUG}
                SerifDrawDebugLog(Format(
                  'Video source evaluated: frame=%d shared_layer=%d sdk_layer=%d validated=%d',
                  [CurrentFrame, Layer, Layer - 1,
                   Ord(LayerIsValidated)]));
{$ENDIF}
              except
                on E: Exception do
                  SerifDrawDebugLog(Format(
                    'Video source evaluation failed: frame=%d layer=%d error=%s: %s',
                    [CurrentFrame, Layer, E.ClassName, E.Message]));
              end;
        Snapshots := GReceiver.ReadActive(CurrentFrame, ValidatedLayers);
        GLastSnapshots := System.Copy(Snapshots, 0, Length(Snapshots));
{$IFDEF DEBUG}
        SerifDrawDebugLog(Format(
          'Video receive: frame=%d fps=%.3f snapshots=%d object_start=%d object_frame=%d',
          [CurrentFrame, Fps, Length(Snapshots), ObjectStart,
           ObjectFrame]));
        for I := 0 to High(Snapshots) do
          SerifDrawDebugLog(Format(
            'Video snapshot: index=%d layer=%d source=%s uid=%d serif=%d timeline=%d/%d speech=%d progress=%.4f',
            [I, Snapshots[I].Layer, Snapshots[I].SourceObjectID,
             Length(Snapshots[I].UID), Length(Snapshots[I].Serif),
             Snapshots[I].TimelineFrame,
             Snapshots[I].TimelineTotalFrames,
             Ord(Snapshots[I].SpeechActive),
             Snapshots[I].SpeechProgress]));
{$ENDIF}
        AnimationParameters := CurrentSerifDrawAnimationParameters;
        AnimationTransform := GAnimationController.Update(Snapshots,
          CurrentFrame, Fps, AnimationParameters, RenderSnapshots);
{$IFDEF DEBUG}
        SerifDrawDebugLog(Format(
          'Video animation: frame=%d input=%d rendered=%d visible=%d alpha=%.4f offset=(%.3f,%.3f) scale=(%.4f,%.4f) rotation=%.3f blur=%.3f reveal=%d/%.4f',
          [CurrentFrame, Length(Snapshots), Length(RenderSnapshots),
           Ord(AnimationTransform.Visible), AnimationTransform.Alpha,
           AnimationTransform.OffsetX, AnimationTransform.OffsetY,
           AnimationTransform.ScaleX, AnimationTransform.ScaleY,
           AnimationTransform.RotationDegrees, AnimationTransform.BlurRadius,
           Ord(AnimationTransform.RevealMode),
           AnimationTransform.RevealProgress]));
{$ENDIF}
        GSkiaRender.Update(RenderSnapshots, Settings, AnimationParameters);
        GSkiaRender.SendToAviUtl2(Video, AnimationTransform);
      finally
        LeaveCriticalSection(GRenderLock);
      end;
    end
    else if GGdiPlusRender <> nil then
      GGdiPlusRender.SendToAviUtl2(Video);
  except
    on E: Exception do
      SerifDrawDebugLog('Video callback failed: ' + E.ClassName + ': ' +
        E.Message);
  end;
end;

initialization
  InitializeCriticalSection(GRenderLock);

finalization
  DeleteCriticalSection(GRenderLock);

end.
