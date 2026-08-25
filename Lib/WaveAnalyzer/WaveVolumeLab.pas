unit WaveVolumeLab;

interface

uses
  System.Classes;

function WaveFileToVolumeLabLines(const WaveFileName: string; Lines: TStrings;
  IntervalSec: Double = 0.02): Boolean;
function WaveFileActiveEndSec(const WaveFileName: string; MinVolume: Integer = 20;
  IntervalSec: Double = 0.02): Double;

implementation

uses
  WaveAnalyzer;

function WaveFileToVolumeLabLines(const WaveFileName: string; Lines: TStrings;
  IntervalSec: Double): Boolean;
var
  Analyzer: TWaveAnalyzer;
begin
  Result := False;
  if Lines = nil then Exit;

  Analyzer := TWaveAnalyzer.Create;
  try
    Analyzer.IntervalSec := IntervalSec;
    Analyzer.ChannelIndex := 0;
    Analyzer.NormalizeMax := 100;

    Lines.Clear;
    Result := Analyzer.Analyze(WaveFileName);
    if Result then
      Analyzer.AddToLabLines(Lines);
  finally
    Analyzer.Free;
  end;
end;

function WaveFileActiveEndSec(const WaveFileName: string; MinVolume: Integer;
  IntervalSec: Double): Double;
var
  Analyzer: TWaveAnalyzer;
  i: Integer;
  Item: TWaveVolumeItem;
begin
  Result := 0;

  Analyzer := TWaveAnalyzer.Create;
  try
    Analyzer.IntervalSec := IntervalSec;
    Analyzer.ChannelIndex := 0;
    Analyzer.NormalizeMax := 100;

    if not Analyzer.Analyze(WaveFileName) then Exit;

    for i := 0 to Analyzer.Items.Count - 1 do
    begin
      Item := Analyzer.Items[i];
      if Item.Volume > MinVolume then
        Result := Item.EndSec;
    end;
  finally
    Analyzer.Free;
  end;
end;

end.
