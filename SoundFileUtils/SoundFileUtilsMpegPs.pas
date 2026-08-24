unit SoundFileUtilsMpegPs;

interface

uses
  System.SysUtils, System.Classes, System.Math;

{--------------------------------------------------------------
  MPEG-PS（Program Stream）内の音声長をミリ秒で返す簡易版。

  対応音声:
    ・MPEG-1 Layer II（MP2）
  非対応:
    ・AC3 / LPCM / DTS（必要あれば追加可能）

  戻り値:
    0  = 判定失敗 or 非対応形式
--------------------------------------------------------------}
function GetMpegPsLengthMs(const AbsoluteFileName: string): Integer;

{ MPEG-PS であるかの簡易判定（先頭?512バイト内に 00 00 01 BA がある） }
function IsMpegPsFile(const AbsoluteFileName: string): Boolean;

implementation

// PS の Pack Header 判定
function IsMpegPsFile(const AbsoluteFileName: string): Boolean;
var
  FS: TFileStream;
  Buf: array[0..4095] of Byte; // 4KB バッファ
  ReadSize: Integer;
  i: Integer;
  MaxScan: Int64;
begin
  Result := False;

  if not FileExists(AbsoluteFileName) then
    Exit;

  FS := TFileStream.Create(AbsoluteFileName, fmOpenRead or fmShareDenyNone);
  try
    // 最大 1MB までスキャン（PS の pack header は必ずこの範囲内に複数ある）
    MaxScan := Min(FS.Size, 1024 * 1024);

    while (FS.Position < MaxScan) do
    begin
      ReadSize := FS.Read(Buf, SizeOf(Buf));
      if ReadSize <= 0 then Break;

      for i := 0 to ReadSize - 4 do
      begin
        // 00 00 01 BA (pack header)
        if (Buf[i] = $00) and (Buf[i+1] = $00) and (Buf[i+2] = $01) then
        begin
          if (Buf[i+3] = $BA) or  // Pack Header
             (Buf[i+3] = $BB) or  // System Header
             (Buf[i+3] = $E0) or  // Video PES
             (Buf[i+3] = $C0)     // Audio PES (MP2)
          then
          begin
            Result := True;
            Exit;
          end;
        end;
      end;
    end;

  finally
    FS.Free;
  end;
end;


{--------------------------------------------------------------
 MP2 フレーム長（バイト）を計算する
--------------------------------------------------------------}
function Mp2FrameLength(SampleRate, BitRateKbps: Integer): Integer;
begin
  // MPEG-1 Layer II のフレーム長式（固定）
  Result := (144000 * BitRateKbps) div SampleRate;
end;

{--------------------------------------------------------------
 MP2 のビットレートテーブル（MPEG-1 Layer II）
--------------------------------------------------------------}
const
  Mp2BitRateTable: array[0..15] of Integer =
    (0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 0);

  Mp2SampleRateTable: array[0..3] of Integer =
    (44100, 48000, 32000, 0);

{--------------------------------------------------------------
  MPEG-PS の Audio PES を走査して MP2 フレームをカウントし、
  総フレーム数 × フレーム時間 → ms を返す簡易版
--------------------------------------------------------------}
function GetMpegPsLengthMs(const AbsoluteFileName: string): Integer;
var
  FS: TFileStream;
  Buf: array[0..2047] of Byte;
  ReadSize: Integer;
  i: Integer;
  Frames: Integer;
  BitRateKbps: Integer;
  SampleRate: Integer;
  FrameLen: Integer;
begin
  Result := 0;
  Frames := 0;

  if not FileExists(AbsoluteFileName) then Exit;

  // 簡易版：固定値（最も一般的なDVD録画音声）
  BitRateKbps := 192;   // ほとんどが 192 kbps
  SampleRate  := 48000; // 48 kHz が一般的
  FrameLen := Mp2FrameLength(SampleRate, BitRateKbps);

  FS := TFileStream.Create(AbsoluteFileName, fmOpenRead or fmShareDenyNone);
  try
    // PS であることを確認
    if not IsMpegPsFile(AbsoluteFileName) then
      Exit(0);

    // 2KB ずつ読み込みながらフレームを検出する簡易版
    while True do
    begin
      ReadSize := FS.Read(Buf, SizeOf(Buf));
      if ReadSize <= 0 then Break;

      i := 0;
      while i < ReadSize - 4 do
      begin
        // MP2 フレームヘッダ  FF FC / FF F4 / FF F8 など
        if (Buf[i] = $FF) and ((Buf[i+1] and $F0) = $F0) then
        begin
          // MPEG-1 Layer2 チェック
          // Layer = '10'
          if ((Buf[i+1] shr 1) and $03) = 2 then
          begin
            Inc(Frames);
            Inc(i, FrameLen);
            Continue;
          end;
        end;

        Inc(i);
      end;
    end;

    // MP2：1フレーム = 1152 samples
    // 時間 = 1152 / SampleRate sec
    var MsPerFrame := (1152 / SampleRate) * 1000;

    Result := Ceil(Frames * MsPerFrame);

  finally
    FS.Free;
  end;
end;

end.

