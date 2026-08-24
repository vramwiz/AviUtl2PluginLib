unit SerifConfig;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,RTTIPersistentIni;

//--------------------------------------------------------------------------//
//  セリフに必要な設定を管理するクラス                                      //
//--------------------------------------------------------------------------//
type
  TSerifConfigItem = class(TRTTIPersistentIni)
  private
    { Private 宣言 }
    FSecStart  : Double;     // セリフ前の空白（秒）
    FSecEnd    : Double;     // セリフ後の空白（秒）
    FEnterPos  : Integer;     // 改行位置 0:改行なし
    FSendLab   : Boolean;    // True: send LAB data to AviUtl2
  public
    { Public 宣言 }
    constructor Create(); virtual;
    destructor Destroy;override;

 published
    property SecStart : Double  read FSecStart  write FSecStart;
    property SecEnd   : Double  read FSecEnd    write FSecEnd;
    property EnterPos : Integer read FEnterPos  write FEnterPos;
    property SendLab  : Boolean read FSendLab   write FSendLab;

  end;


implementation

{ TSerifConfigItem }

constructor TSerifConfigItem.Create;
begin
  FSecStart := 0.00;
  FSecEnd   := 0.05;
  FEnterPos := 0;
  FSendLab  := True;
end;

destructor TSerifConfigItem.Destroy;
begin

  inherited;
end;

end.
