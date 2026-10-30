// 辞書APIの読取・解析・更新をGUIスレッドから分離する。呼び出し側が1件ずつ所有する。
unit SerifVoicevoxDictionaryWorker;

interface

uses
  Winapi.Windows, Winapi.Messages, System.Classes, SerifVoicevoxUserDictionary;

const
  VOICEVOX_DICTIONARY_COMPLETE = WM_APP + $5725;

type
  TSerifVoicevoxDictionaryAction = (vdaAnalyze, vdaLoad, vdaSave, vdaDelete);

  TSerifVoicevoxDictionaryWorker = class(TThread)
  private
    FAction: TSerifVoicevoxDictionaryAction;
    FErrorMessage: string;
    FNotifyHandle: HWND;
    FRevision: Cardinal;
    FStyleId: Integer;
    FSuccess: Boolean;
    FWord: TSerifVoicevoxDictionaryWord;
    FWords: TArray<TSerifVoicevoxDictionaryWord>;
  protected
    procedure Execute; override;
  public
    // 作成後にStartする。単語と版をコピーし、完了時は通知先へメッセージだけを送る。
    constructor Create(const NotifyHandle: HWND; const Action: TSerifVoicevoxDictionaryAction;
      const Revision: Cardinal; const StyleId: Integer; const Word: TSerifVoicevoxDictionaryWord);
    property Action: TSerifVoicevoxDictionaryAction read FAction;
    property ErrorMessage: string read FErrorMessage;
    property Revision: Cardinal read FRevision;
    property Success: Boolean read FSuccess;
    property Word: TSerifVoicevoxDictionaryWord read FWord;
    property Words: TArray<TSerifVoicevoxDictionaryWord> read FWords;
  end;

implementation

uses
  System.SysUtils;

constructor TSerifVoicevoxDictionaryWorker.Create(const NotifyHandle: HWND;
  const Action: TSerifVoicevoxDictionaryAction; const Revision: Cardinal;
  const StyleId: Integer; const Word: TSerifVoicevoxDictionaryWord);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FNotifyHandle := NotifyHandle;
  FAction := Action;
  FRevision := Revision;
  FStyleId := StyleId;
  FWord := Word;
end;

procedure TSerifVoicevoxDictionaryWorker.Execute;
var
  Pronunciation: string;
  AccentType: Integer;
begin
  try
    if not Terminated then
      case FAction of
        vdaAnalyze:
          begin
            FSuccess := TSerifVoicevoxUserDictionary.Analyze(FWord.Surface, FStyleId,
              Pronunciation, AccentType, FErrorMessage);
            if FSuccess then
            begin
              FWord.Pronunciation := Pronunciation;
              FWord.AccentType := AccentType;
            end;
          end;
        vdaLoad: FSuccess := TSerifVoicevoxUserDictionary.Load(FWords, FErrorMessage);
        vdaSave: FSuccess := TSerifVoicevoxUserDictionary.Save(FWord, FErrorMessage);
        vdaDelete: FSuccess := TSerifVoicevoxUserDictionary.Delete(FWord.UUID, FErrorMessage);
      end;
  except
    on E: Exception do FErrorMessage := E.Message;
  end;
  PostMessage(FNotifyHandle, VOICEVOX_DICTIONARY_COMPLETE, WPARAM(FRevision), 0);
end;

end.
