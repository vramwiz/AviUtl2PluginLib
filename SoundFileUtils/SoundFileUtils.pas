unit SoundFileUtils;

interface

uses
  System.SysUtils, System.Classes, System.Math,
  SoundFileUtilsMp3,
  SoundFileUtilsWave,SoundFileUtilsMpegPs,SoundFileUtilsEtc;

function GetSoundFileLengthSec(const AbsoluteFileName: string): Double;

implementation

function GetSoundFileLengthSec(const AbsoluteFileName: string): Double;
var
  Ext: string;
begin
  Result := 0;

  if not FileExists(AbsoluteFileName) then
    Exit;

  Ext := LowerCase(ExtractFileExt(AbsoluteFileName));

  // WAV
  if Ext = '.wav' then begin
    Exit(GetWaveLengthSec(AbsoluteFileName));
     Exit;
  end;
  {
  // MP3 (ãUëïä‹Çﬁ)
  if Ext = '.mp3' then begin
    if IsRealMp3File(AbsoluteFileName) then begin
      Exit(GetMp3LengthMs(AbsoluteFileName));
    end;

    if IsMpegPsFile(AbsoluteFileName) then
    begin
      // è´óàé¿ëïÅFMPEG-PS / MP2 / AC3 Ç»Ç«
      Result := GetMpegPsLengthMs(AbsoluteFileName);
      Exit;
    end;
  end;
  }

  // ÇªÇÃëºñ¢ëŒâûå`éÆ
  Result := GetMediaDurationFallbackSec(AbsoluteFileName);
end;

end.

