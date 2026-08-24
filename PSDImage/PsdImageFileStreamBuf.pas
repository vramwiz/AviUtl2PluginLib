unit PsdImageFileStreamBuf;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls,Jpeg,PngImage,System.StrUtils,PsdImageDefine;

//--------------------------------------------------------------------------//
//  高速バッファ型ファイルストリームクラス（完全メモリ展開版）                //
//  既存の TFileStreamBuf と同名・同I/F互換で動作                            //
//--------------------------------------------------------------------------//
type
  TFileStreamBuf = class(TPersistent)
  private
    FBuffer: PByte;          // ファイル全体のメモリバッファ
    FSize: Integer;          // バッファ全体サイズ
    FPos: Integer;           // 現在の読み取り位置
    FFileName: string;       // デバッグ・確認用に保持
  public
    constructor Create(const AFileName: string); virtual;
    destructor Destroy; override;

    // 現在位置／サイズ取得
    function Position: Integer;
    function Size: Integer;

    // ポジション制御
    procedure Seek(NewPos: Integer);
    procedure Skip(Count: Integer);

    // バイト・数値読み込み
    function ReadByte: Byte;
    function ReadBin(const Length: Integer): Integer;     // BigEndianで読む
    function ReadInt(const Length: Integer): Integer;     // LittleEndianで読む

    // 文字列系（既存と同名）
    function ReadStr(const Length: Integer): AnsiString;
    function ReadStrPascal(const Length: Integer): AnsiString;
    function ReadStrPascal2(const Length: Integer): AnsiString;
    function ReadStrUnicodeSizeLenData: string;

    // 読み捨て
    procedure ReadDumy(const Length: Integer);
  end;


implementation


//--------------------------------------------------------------------------//
//  高速バッファ型ファイルストリームクラス（完全メモリ展開版）             //
//  TFileStreamBuf : 旧版と同名・同I/F互換                                 //
//--------------------------------------------------------------------------//


{ TFileStreamBuf }

constructor TFileStreamBuf.Create(const AFileName: string);
var
  FS: TFileStream;
begin
  inherited Create;
  FFileName := AFileName;

  FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    FSize := FS.Size;
    GetMem(FBuffer, FSize);
    FS.ReadBuffer(FBuffer^, FSize);
  finally
    FS.Free;
  end;

  FPos := 0;
end;

destructor TFileStreamBuf.Destroy;
begin
  if FBuffer <> nil then
    FreeMem(FBuffer);
  inherited;
end;

function TFileStreamBuf.Position: Integer;
begin
  Result := FPos;
end;

function TFileStreamBuf.Size: Integer;
begin
  Result := FSize;
end;

procedure TFileStreamBuf.Seek(NewPos: Integer);
begin
  if (NewPos < 0) or (NewPos > FSize) then
    raise Exception.CreateFmt('Seek position %d out of range', [NewPos]);
  FPos := NewPos;
end;

procedure TFileStreamBuf.Skip(Count: Integer);
begin
  Seek(FPos + Count);
end;

function TFileStreamBuf.ReadByte: Byte;
begin
  if FPos >= FSize then
    raise Exception.Create('Read beyond end of buffer');
  Result := FBuffer[FPos];
  Inc(FPos);
end;

//---------------------------------------------------------------------------
// BigEndian 読み込み
//---------------------------------------------------------------------------
function TFileStreamBuf.ReadBin(const Length: Integer): Integer;
var
  i: Integer;
  b: Byte;
begin
  Result := 0;
  for i := 0 to Length - 1 do
  begin
    if FPos >= FSize then
      raise Exception.Create('Read beyond end of buffer');
    b := FBuffer[FPos];
    Inc(FPos);
    Result := (Result shl 8) or b;
  end;
end;

//---------------------------------------------------------------------------
// LittleEndian 読み込み
//---------------------------------------------------------------------------
function TFileStreamBuf.ReadInt(const Length: Integer): Integer;
var
  i: Integer;
  b: Byte;
begin
  Result := 0;
  for i := 0 to Length - 1 do
  begin
    if FPos >= FSize then
      raise Exception.Create('Read beyond end of buffer');
    b := FBuffer[FPos];
    Inc(FPos);
    Result := Result or (b shl (i * 8));
  end;
end;

//---------------------------------------------------------------------------
// 読み捨て（高速）
//---------------------------------------------------------------------------
procedure TFileStreamBuf.ReadDumy(const Length: Integer);
begin
  if (Length <= 0) then Exit;
  if FPos + Length > FSize then
    raise Exception.Create('ReadDumy beyond end of buffer');
  Inc(FPos, Length);
end;

//---------------------------------------------------------------------------
// 文字列（ANSI）
//---------------------------------------------------------------------------
function TFileStreamBuf.ReadStr(const Length: Integer): AnsiString;
var
  i: Integer;
begin
  SetLength(Result, Length);
  for i := 1 to Length do
  begin
    if FPos >= FSize then
      raise Exception.Create('ReadStr beyond end of buffer');
    Result[i] := AnsiChar(FBuffer[FPos]);
    Inc(FPos);
  end;
end;

//---------------------------------------------------------------------------
// Pascal形式文字列（4バイト境界調整付き）
//---------------------------------------------------------------------------
function TFileStreamBuf.ReadStrPascal(const Length: Integer): AnsiString;
var
  m: Integer;
begin
  Result := ReadStr(Length);
  m := (Length + 1) mod 4;
  if m <> 0 then
    ReadDumy(4 - m);
end;

//---------------------------------------------------------------------------
// Pascal形式文字列（2バイト境界調整付き）
//---------------------------------------------------------------------------
function TFileStreamBuf.ReadStrPascal2(const Length: Integer): AnsiString;
begin
  if Length = 0 then
  begin
    ReadDumy(1);
    Result := '';
    Exit;
  end;
  Result := ReadStr(Length);
  if (Length mod 2) = 0 then
    ReadDumy(1);
end;

//---------------------------------------------------------------------------
// Unicodeサイズ付き文字列（PSD用）
//---------------------------------------------------------------------------
function TFileStreamBuf.ReadStrUnicodeSizeLenData: string;
var
  s: string;
  i, size, len: Integer;
  Tbl: TBytes;
begin
  s := '';
  size := ReadBin(4); // 全体サイズ
  len  := ReadBin(4); // 実際の文字列長

  if size < 4 then
    Exit('');

  SetLength(Tbl, size);
  for i := 0 to size - 5 do
  begin
    if (i mod 2) = 0 then
      Tbl[i + 1] := ReadByte
    else
      Tbl[i - 1] := ReadByte;
  end;

  s := PChar(@Tbl[0]);
  SetLength(s, len);
  Result := s;
end;


end.
