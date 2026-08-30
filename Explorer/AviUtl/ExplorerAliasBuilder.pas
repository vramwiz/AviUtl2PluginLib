unit ExplorerAliasBuilder;

interface

uses
  System.Classes,
  System.SysUtils;

type
  TExplorerAliasBuilder = class
  private
    FFilterIndex: Integer;
    FFormatSettings: TFormatSettings;
    FStrings: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddFilter(const EffectName: string);
    procedure AddFloat(const Key: string; Value: Double; Digits: Integer);
    procedure AddObject(Layer, FrameStart, FrameEnd: Integer;
      const Positions: array of Integer);
    procedure AddValue(const Key, Value: string); overload;
    procedure AddValue(const Key: string; Value: Integer); overload;
    procedure SaveToFile(const FileName: string);
  end;

implementation

constructor TExplorerAliasBuilder.Create;
begin
  inherited;
  FStrings := TStringList.Create;
  FFormatSettings := TFormatSettings.Create;
  FFormatSettings.DecimalSeparator := '.';
end;

destructor TExplorerAliasBuilder.Destroy;
begin
  FStrings.Free;
  inherited;
end;

procedure TExplorerAliasBuilder.AddFilter(const EffectName: string);
begin
  FStrings.Add(Format('[0.%d]', [FFilterIndex]));
  Inc(FFilterIndex);
  AddValue('effect.name', EffectName);
end;

procedure TExplorerAliasBuilder.AddFloat(const Key: string; Value: Double;
  Digits: Integer);
var
  NumberFormat: string;
begin
  NumberFormat := '0.' + StringOfChar('0', Digits);
  AddValue(Key, FormatFloat(NumberFormat, Value, FFormatSettings));
end;

procedure TExplorerAliasBuilder.AddObject(Layer, FrameStart,
  FrameEnd: Integer; const Positions: array of Integer);
var
  Index: Integer;
  FrameValue: string;
begin
  FFilterIndex := 0;
  FStrings.Add('[0]');
  FStrings.Add('layer=' + IntToStr(Layer));
  FrameValue := 'frame=' + IntToStr(FrameStart);
  for Index := Low(Positions) to High(Positions) do
    FrameValue := FrameValue + ',' + IntToStr(Positions[Index]);
  FrameValue := FrameValue + ',' + IntToStr(FrameEnd);
  FStrings.Add(FrameValue);
end;

procedure TExplorerAliasBuilder.AddValue(const Key, Value: string);
begin
  FStrings.Add(Key + '=' + Value);
end;

procedure TExplorerAliasBuilder.AddValue(const Key: string; Value: Integer);
begin
  AddValue(Key, IntToStr(Value));
end;

procedure TExplorerAliasBuilder.SaveToFile(const FileName: string);
var
  Encoding: TEncoding;
  Folder: string;
begin
  Folder := ExtractFilePath(FileName);
  if Folder <> '' then
    ForceDirectories(Folder);
  Encoding := TUTF8Encoding.Create(False);
  try
    FStrings.SaveToFile(FileName, Encoding);
  finally
    Encoding.Free;
  end;
end;

end.
