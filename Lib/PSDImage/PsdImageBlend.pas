unit PsdImageBlend;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,PsdImageDefine,PsdImageFileStreamBuf;

type
  TPsdFileBlend = class(TPersistent)
  private
    { Private 宣言 }
    FSource: Integer;
    FAddress: Integer;
  public
    { Public 宣言 }
    function LoadFromStream(fs : TFileStreamBuf) : Boolean;

    property Source : Integer read FSource;
    property Address : Integer read FAddress;
  end;

type
	TPsdFileBlends = class(TList)
	private
		{ Private 宣言 }
    function GetItems(Index: Integer): TPsdFileBlend;
	public
		{ Public 宣言 }
    destructor Destroy;override;
    function Add() : TPsdFileBlend;
    procedure Delete(i : Integer);
    procedure Clear();override;

		property Blends[Index: Integer] : TPsdFileBlend read GetItems ;default;

	end;

implementation

{ TPsdFileBlends }

destructor TPsdFileBlends.Destroy;
begin
  Clear();
  inherited;
end;

function TPsdFileBlends.Add: TPsdFileBlend;
var
  d : TPsdFileBlend;
begin
  d := TPsdFileBlend.Create;
  inherited Add(d);
  result := d;
end;

procedure TPsdFileBlends.Clear;
var
  i : Integer;
begin
  for i := 0 to Count-1 do begin
    Blends[i].Free;
  end;
  inherited;
end;

procedure TPsdFileBlends.Delete(i: Integer);
begin
  Blends[i].Free;
  inherited Delete(i);
end;

function TPsdFileBlends.GetItems(Index: Integer): TPsdFileBlend;
begin
  result := inherited Items[Index];
end;

{ TPsdFileBlend }

function TPsdFileBlend.LoadFromStream(fs: TFileStreamBuf): Boolean;
begin
  FSource := fs.ReadBin(4);
  FAddress := fs.ReadBin(4);
  result := True;
end;



end.
