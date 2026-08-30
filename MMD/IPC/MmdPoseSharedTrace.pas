unit MmdPoseSharedTrace;

// Pose送信とModel受信を同一ファイルへ時系列記録する一時診断境界。
// ログ失敗は描画や共有メモリ処理へ影響させない。

interface

// 診断ログの絶対パスを返す。保存先を確保できない場合は空文字を返す。
function MmdPoseSharedTraceFileName: string;
// 1回の送受信イベントを、比較に必要な識別値だけに限定して追記する。
procedure TraceMmdPoseShared(const Role, EventName: string; Layer,
  TimelineFrame: Integer; ObjectID, EffectID: Int64; ModelPathHash: UInt64;
  DataLength: Integer; const Detail: string = '');

implementation

uses
  Winapi.Windows,
  System.Classes,
  System.IOUtils,
  System.SysUtils;

const
  MaxTraceFileSize = 32 * 1024 * 1024;
  TraceFileName = 'PoseSharedMemory.log';
  TraceMutexName = 'Local\MMD.Pose.Trace.Mutex';

{$IFDEF DEBUG}
var
  TraceMutex: THandle;
{$ENDIF}

function CleanField(const Value: string): string;
begin
  Result := StringReplace(Value, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
end;

function MmdPoseSharedTraceFileName: string;
var
  Folder: string;
begin
  Result := '';
  try
    Folder := TPath.Combine(TPath.GetDocumentsPath, 'MMDAnimationStudio');
    Folder := TPath.Combine(Folder, 'Logs');
    ForceDirectories(Folder);
    Result := TPath.Combine(Folder, TraceFileName);
  except
    try
      Folder := TPath.Combine(TPath.GetTempPath, 'MMDAnimationStudio');
      Folder := TPath.Combine(Folder, 'Logs');
      ForceDirectories(Folder);
      Result := TPath.Combine(Folder, TraceFileName);
    except
      Result := '';
    end;
  end;
end;

procedure TraceMmdPoseShared(const Role, EventName: string; Layer,
  TimelineFrame: Integer; ObjectID, EffectID: Int64; ModelPathHash: UInt64;
  DataLength: Integer; const Detail: string);
{$IFDEF DEBUG}
var
  Bytes: TBytes;
  FileName: string;
  Stream: TFileStream;
  WaitResult: Cardinal;
{$ENDIF}
begin
  {$IFDEF DEBUG}
  try
    FileName := MmdPoseSharedTraceFileName;
    if (FileName = '') or (TraceMutex = 0) then Exit;
    WaitResult := WaitForSingleObject(TraceMutex, 1000);
    if not (WaitResult in [WAIT_OBJECT_0, WAIT_ABANDONED]) then Exit;
    try
      if TFile.Exists(FileName) then
        Stream := TFileStream.Create(FileName,
          fmOpenReadWrite or fmShareDenyNone)
      else
        Stream := TFileStream.Create(FileName, fmCreate or fmShareDenyNone);
      try
        if Stream.Size >= MaxTraceFileSize then Exit;
        Stream.Position := Stream.Size;
        Bytes := TEncoding.UTF8.GetBytes(Format(
          '%s pid=%d role=%s event=%s layer=%d frame=%d object=%d effect=%d model=%s bytes=%d detail=%s%s',
          [FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', Now), GetCurrentProcessId,
           CleanField(Role), CleanField(EventName), Layer, TimelineFrame,
           ObjectID, EffectID, IntToHex(ModelPathHash, 16), DataLength,
           CleanField(Detail), sLineBreak]));
        if Length(Bytes) > 0 then Stream.WriteBuffer(Bytes[0], Length(Bytes));
      finally
        Stream.Free;
      end;
    finally
      ReleaseMutex(TraceMutex);
    end;
  except
    { 診断失敗は描画と共有メモリ通信へ影響させない。 }
  end;
  {$ENDIF}
end;

initialization
  {$IFDEF DEBUG}
  TraceMutex := CreateMutex(nil, False, TraceMutexName);
  {$ENDIF}

finalization
  {$IFDEF DEBUG}
  if TraceMutex <> 0 then CloseHandle(TraceMutex);
  {$ENDIF}

end.
