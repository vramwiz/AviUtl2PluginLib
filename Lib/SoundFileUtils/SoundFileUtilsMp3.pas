unit SoundFileUtilsMp3;

interface

uses
  System.SysUtils, System.Classes, System.Math;

function GetMp3LengthMs(const AbsoluteFileName: string): Integer;
function IsRealMp3File(const AbsoluteFileName: string): Boolean;

implementation

// MP3 本物判定関数
function IsRealMp3File(const AbsoluteFileName: string): Boolean;
var
  FS: TFileStream;
  Header: Cardinal;
begin
  Result := False;

  if not FileExists(AbsoluteFileName) then Exit;

  FS := TFileStream.Create(AbsoluteFileName, fmOpenRead or fmShareDenyNone);
  try
    // ID3 の可能性
    var Sig: array[0..2] of Byte;
    FS.Read(Sig, 3);
    if (Sig[0] = Ord('I')) and (Sig[1] = Ord('D')) and (Sig[2] = Ord('3')) then
    begin
      var Rest: array[0..6] of Byte;
      FS.Read(Rest, 7);
      var Size := ((Rest[3] and $7F) shl 21) or
                  ((Rest[4] and $7F) shl 14) or
                  ((Rest[5] and $7F) shl 7)  or
                   (Rest[6] and $7F);

      FS.Position := 10 + Size;
    end
    else
      FS.Position := 0;

    // MPEG Frame Header 読み取り
    if FS.Read(Header, 4) = 4 then
    begin
      if (Header and $FFE00000) = $FFE00000 then
        Result := True;
    end;

  finally
    FS.Free;
  end;
end;

function GetMp3LengthMs(const AbsoluteFileName: string): Integer;
type
  TBitRates = array[0..15] of Integer;
  TSampleRates = array[0..2] of Integer;

const
  // ビットレートテーブル (kbps)
  BitRateTable: array[0..2, 0..2] of TBitRates = (
    // MPEG1
    (
      (0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,0), // Layer1
      (0,32,48,56,64,80,96,112,128,160,192,224,256,320,384,0), // Layer2
      (0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,0)  // Layer3
    ),
    // MPEG2
    (
      (0,32,48,56,64,80,96,112,128,144,160,176,192,224,256,0),
      (0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0),
      (0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0)
    ),
    // MPEG2.5
    (
      (0,32,48,56,64,80,96,112,128,144,160,176,192,224,256,0),
      (0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0),
      (0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0)
    )
  );

  SampleRateTable: array[0..2] of TSampleRates = (
    (44100, 48000, 32000),
    (22050, 24000, 16000),
    (11025, 12000, 8000)
  );

var
  FS: TFileStream;
  Header: Cardinal;
  VersionIdx, LayerIdx, BitrateIdx, SampleRateIdx: Integer;
  BitRate, SampleRate: Integer;

  Sig3: array[0..2] of Byte;
  Rest7: array[0..6] of Byte;

  MPEGVer, LayerVer: Integer;
  TotalFrames: Cardinal;

  XHeader: array[0..3] of AnsiChar;
  VBRIHeader: array[0..3] of AnsiChar;
  XFlags: Cardinal;

  FrameHeaderPos: Int64;
  Ms: Double;

  function SyncSafeToInt(B1,B2,B3,B4: Byte): Integer;
  begin
    Result :=
      (B1 and $7F) shl 21 or
      (B2 and $7F) shl 14 or
      (B3 and $7F) shl 7  or
      (B4 and $7F);
  end;

begin
  Result := 0;

  if not FileExists(AbsoluteFileName) then
    Exit;

  try
    FS := TFileStream.Create(AbsoluteFileName, fmOpenRead or fmShareDenyWrite);
    try
      if FS.Size < 10 then Exit;

      // -------------------------------------------------------------
      // ID3v2 チェック（最初の 3 バイト）
      // -------------------------------------------------------------
      FS.ReadBuffer(Sig3, 3);

      if (Sig3[0] = Ord('I')) and (Sig3[1] = Ord('D')) and (Sig3[2] = Ord('3')) then
      begin
        // 残りの7バイト
        FS.ReadBuffer(Rest7, 7);
        var ID3v2Size := SyncSafeToInt(Rest7[3], Rest7[4], Rest7[5], Rest7[6]);

        // ヘッダ10 + 本体サイズ
        FS.Position := 10 + ID3v2Size;
      end
      else
      begin
        FS.Position := 0;
      end;

      // -------------------------------------------------------------
      // MPEG フレームヘッダ読み取り位置を記録
      // -------------------------------------------------------------
      FrameHeaderPos := FS.Position;

      FS.ReadBuffer(Header, 4);

      // MPEG シンク確認
      if (Header and $FFE00000) <> $FFE00000 then
        Exit;

      // -------------------------------------------------------------
      // MPEG フレームヘッダ解析
      // -------------------------------------------------------------
      MPEGVer       := (Header shr 19) and $3;
      LayerVer      := (Header shr 17) and $3;
      BitrateIdx    := (Header shr 12) and $F;
      SampleRateIdx := (Header shr 10) and $3;
      //Padding       := (Header shr 9)  and $1;

      case MPEGVer of
        3: VersionIdx := 0; // MPEG1
        2: VersionIdx := 1; // MPEG2
        0: VersionIdx := 2; // MPEG2.5
      else
        Exit;
      end;

      LayerIdx := 2 - (LayerVer - 1);

      if (BitrateIdx = 0) or (BitrateIdx = 15) then Exit;
      if SampleRateIdx > 2 then Exit;

      BitRate    := BitRateTable[VersionIdx][LayerIdx][BitrateIdx] * 1000;
      SampleRate := SampleRateTable[VersionIdx][SampleRateIdx];

      // -------------------------------------------------------------
      // Xing / Info チェック
      // -------------------------------------------------------------
      FS.Position := FrameHeaderPos + 4 + 32;
      FS.ReadBuffer(XHeader, 4);

      if (string(XHeader) = 'Xing') or (string(XHeader) = 'Info') then
      begin
        FS.ReadBuffer(XFlags, 4);

        if (XFlags and 1) <> 0 then
        begin
          FS.ReadBuffer(TotalFrames, 4);

          Ms := (TotalFrames * 1152 / SampleRate) * 1000;
          Result := Ceil(Ms);
          Exit;
        end;
      end;

      // -------------------------------------------------------------
      // VBRI チェック
      // -------------------------------------------------------------
      FS.Position := FrameHeaderPos + 4 + 36;
      FS.ReadBuffer(VBRIHeader, 4);

      if (string(VBRIHeader) = 'VBRI') then
      begin
        FS.Seek(10, soFromCurrent);
        FS.ReadBuffer(TotalFrames, 4);

        Ms := (TotalFrames * 1152 / SampleRate) * 1000;
        Result := Ceil(Ms);
        Exit;
      end;

      // -------------------------------------------------------------
      // CBR → ファイルの残りバイト + ビットレートから計算
      // -------------------------------------------------------------
      FS.Position := FrameHeaderPos + 4;  // 最初のフレーム直後へ

      var AudioBytes := FS.Size - FS.Position;
      var Sec := (AudioBytes * 8) / BitRate;

      Result := Ceil(Sec * 1000);

    finally
      FS.Free;
    end;

  except
    Result := 0;
  end;
end;

end.

