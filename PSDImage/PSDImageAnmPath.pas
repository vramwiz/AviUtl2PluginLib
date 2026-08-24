unit PSDImageAnmPath;

interface

uses
  PsdImageLayer;

function AssignPSDImageAnmPaths(Layers: TPsdFileLayers): Boolean;

implementation

uses
  Classes;

function StringListToText(ts: TStringList): string;
var
  i: Integer;
  s: string;
begin
  s := '';
  for i := 0 to ts.Count - 1 do
  begin
    if ts[i] = '' then Continue;
    s := s + ts[i] + '/';
  end;
  Result := s;
end;

function AssignPSDImageAnmPaths(Layers: TPsdFileLayers): Boolean;
var
  j: Integer;
  dl: TPsdFileLayer;
  ts: TStringList;
  s: string;
begin
  Result := False;
  if Layers = nil then Exit;

  ts := TStringList.Create;
  try
    for j := Layers.Count - 1 downto 0 do
    begin
      dl := Layers[j];
      case dl.LayerType of
        0:
          begin
            dl.AnmGroup2 := StringListToText(ts);
            s := StringListToText(ts) + dl.Name;
            dl.AnmText := s;
            if ts.Count > 0 then
              dl.AnmGroup := ts[ts.Count - 1]
            else
              dl.AnmGroup := dl.Name;
          end;
        1, 2:
          begin
            dl.AnmGroup2 := StringListToText(ts);
            s := StringListToText(ts) + dl.Name;
            dl.AnmText := s;
            ts.Add(dl.Name);
          end;
        3:
          begin
            if ts.Count > 0 then
              ts.Delete(ts.Count - 1);
          end;
      end;
    end;
  finally
    ts.Free;
  end;

  Result := True;
end;

end.
