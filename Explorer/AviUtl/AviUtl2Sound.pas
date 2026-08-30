unit AviUtl2Sound;

interface

uses
  ExplorerListSound;

function AviUtl2SoundDandD(Sound: TExplorerFileSoundItem): string;

implementation

uses
  System.Math,
  System.SysUtils,
  AppFolderUtils,
  ExplorerAliasBuilder,
  ExplorerAviUtlBridge,
  SoundFileUtils;

const
  TextSoundFile = #$97F3#$58F0#$30D5#$30A1#$30A4#$30EB;
  TextPlaybackPosition = #$518D#$751F#$4F4D#$7F6E;
  TextPlaybackRange = #$518D#$751F#$7BC4#$56F2;
  TextPlaybackSpeed = #$518D#$751F#$901F#$5EA6;
  TextFile = #$30D5#$30A1#$30A4#$30EB;
  TextTrack = #$30C8#$30E9#$30C3#$30AF;
  TextLoopPlayback = #$30EB#$30FC#$30D7#$518D#$751F;
  TextSoundPlayback = #$97F3#$58F0#$518D#$751F;
  TextLinearMove = #$76F4#$7DDA#$79FB#$52D5;
  TextVolume = #$97F3#$91CF;
  TextPan = #$5DE6#$53F3;

function FloatText(Value: Double; const NumberFormat: string): string;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';
  Result := FormatFloat(NumberFormat, Value, FormatSettings);
end;

function AviUtl2SoundDandD(Sound: TExplorerFileSoundItem): string;
var
  AliasBuilder: TExplorerAliasBuilder;
  Duration: Double;
  FadeInFrame: Integer;
  FadeOutFrame: Integer;
  FrameDuration: Double;
  FrameEnd: Integer;
  Positions: TArray<Integer>;
  VolumeValue: string;
begin
  Result := '';
  if Sound = nil then
    Exit;

  Duration := GetSoundFileLengthSec(Sound.FileName);
  FrameDuration := ExplorerFrameDuration;
  FrameEnd := Ceil(Duration / FrameDuration);
  SetLength(Positions, 0);
  if Sound.FadeMode in [1, 3] then
  begin
    FadeInFrame := Min(Round(Sound.FadeIn / FrameDuration), FrameEnd);
    SetLength(Positions, Length(Positions) + 1);
    Positions[High(Positions)] := FadeInFrame;
  end;
  if Sound.FadeMode in [2, 3] then
  begin
    FadeOutFrame := Max(Round((Duration - Sound.FadeOut) /
      FrameDuration), 0);
    SetLength(Positions, Length(Positions) + 1);
    Positions[High(Positions)] := FadeOutFrame;
  end;

  Result := GetAppFolder('Temp') + 'Temp.object';
  AliasBuilder := TExplorerAliasBuilder.Create;
  try
    AliasBuilder.AddObject(0, 0, FrameEnd, Positions);
    AliasBuilder.AddFilter(TextSoundFile);
    AliasBuilder.AddValue(TextPlaybackPosition,
      FloatText(0, '0.000') + ',' + FloatText(Duration, '0.000') + ',' +
      TextPlaybackRange + ',0');
    AliasBuilder.AddFloat(TextPlaybackSpeed, Sound.PlaySpeed, 2);
    AliasBuilder.AddValue(TextFile, Sound.FileName);
    AliasBuilder.AddValue(TextTrack, Sound.Track);
    AliasBuilder.AddValue(TextLoopPlayback, Sound.PlayLoop);
    AliasBuilder.AddFilter(TextSoundPlayback);
    case Sound.FadeMode of
      1: VolumeValue := FloatText(0, '0.000') + ',' +
        FloatText(Sound.Volume, '0.000') + ',' +
        FloatText(Sound.Volume, '0.000') + ',' + TextLinearMove + ',0';
      2: VolumeValue := FloatText(Sound.Volume, '0.000') + ',' +
        FloatText(Sound.Volume, '0.000') + ',' + FloatText(0, '0.000') +
        ',' + TextLinearMove + ',0';
      3: VolumeValue := FloatText(0, '0.000') + ',' +
        FloatText(Sound.Volume, '0.000') + ',' +
        FloatText(Sound.Volume, '0.000') + ',' + FloatText(0, '0.000') +
        ',' + TextLinearMove + ',0';
    else
      VolumeValue := FloatText(Sound.Volume, '0.000');
    end;
    AliasBuilder.AddValue(TextVolume, VolumeValue);
    AliasBuilder.AddFloat(TextPan, Sound.Pan, 2);
    AliasBuilder.SaveToFile(Result);
  finally
    AliasBuilder.Free;
  end;
end;

end.
