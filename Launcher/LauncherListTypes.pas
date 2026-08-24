unit LauncherListTypes;
// ランチャー一覧で共有する列挙型と定数。

interface

type
  TLauncherSpeechAppKind = (
    lsakVoiceroid2,
    lsakAivoice,
    lsakAivoice2,
    lsakVoicepeak,
    lsakCeVIOAI
  );

const
  SPEECH_APP_EXECUTABLE_NAMES: array[TLauncherSpeechAppKind] of string = (
    'VoiceroidEditor',
    'AIVoiceEditor',
    'DummyAivoice2',
    'voicepeak',
    'CeVIO AI'
  );

type
  TLauncherRunningState = (
    lrsStopped,         // 起動していない。
    lrsRunningNoWindow, // 起動しているが、管理用ウィンドウハンドルを取得できていない。
    lrsRunningManaged,  // 起動していて、このランチャー側の通常管理対象。
    lrsRunningAdopted   // 外部起動を検出し、管理用ウィンドウハンドルを取得した。
  );

implementation

end.
