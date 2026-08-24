unit SongReader;

interface

uses
  SysUtils, Classes,SongData;

type
  // ‰ğÍŠî’êƒNƒ‰ƒX
  TSongReader = class
  public
    function LoadFromFile(const FileName: string; SongData: TSongData) : Boolean; virtual; abstract;
  end;

  TSongReaderClass = class of TSongReader;

implementation

end.
