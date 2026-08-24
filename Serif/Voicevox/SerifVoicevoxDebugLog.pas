// VOICEVOX入力画面の生成・準備・API呼び出し順をDebugビルドで記録する。
unit SerifVoicevoxDebugLog;

interface

// Debugビルドでは時刻付きでログへ追記し、Releaseビルドでは何もしない。
procedure VoicevoxDebugLog(const Text: string);
// 実行ファイルと同じフォルダに置くVOICEVOXデバッグログのパスを返す。
function VoicevoxDebugLogFileName: string;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils;

var
  LogLock: TObject;
  StartTick: UInt64;

function VoicevoxDebugLogFileName: string;
begin
  Result := TPath.Combine(TPath.Combine(TPath.GetTempPath, 'Syncroh2\Temp'),
    'Syncroh2_Voicevox.log');
end;

procedure VoicevoxDebugLog(const Text: string);
{$IFDEF DEBUG}
var
  Line: string;
{$ENDIF}
begin
{$IFDEF DEBUG}
  Line := Format('%s +%dms [pid=%d tid=%d] %s%s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
     GetTickCount64 - StartTick, GetCurrentProcessId, GetCurrentThreadId,
     Text, sLineBreak]);
  OutputDebugString(PChar('[Voicevox] ' + Text));
  TMonitor.Enter(LogLock);
  try
    try
      TFile.AppendAllText(VoicevoxDebugLogFileName, Line, TEncoding.UTF8);
    except
      // ログ失敗で本処理を止めない。
    end;
  finally
    TMonitor.Exit(LogLock);
  end;
{$ENDIF}
end;

initialization
  LogLock := TObject.Create;
  StartTick := GetTickCount64;
{$IFDEF DEBUG}
  try
    TDirectory.CreateDirectory(TPath.GetDirectoryName(
      VoicevoxDebugLogFileName));
    TFile.WriteAllText(VoicevoxDebugLogFileName, '', TEncoding.UTF8);
  except
    // ログを作れない環境でもプラグインの起動を継続する。
  end;
  VoicevoxDebugLog('session begin');
{$ENDIF}

finalization
{$IFDEF DEBUG}
  VoicevoxDebugLog('session end');
{$ENDIF}
  LogLock.Free;

end.
