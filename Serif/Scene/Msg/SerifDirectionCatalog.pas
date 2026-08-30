unit SerifDirectionCatalog;


// セリフ編集UIが順送りに利用する製品非依存の演出名一覧。

interface

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

const
  SerifDirectionNames: array[0..29] of string = (
    '涙', '汗', '怒', '困', '驚', '照', '泣', '笑', '赤面', '青ざめ',
    '震え', '沈黙', '目閉じ', 'ハート', '音符', '星', 'はてな',
    'びっくり', '集中線', '影', '焦り', '閃き', '呆れ', '落ち込み',
    '混乱', 'ため息', '吐息', '湯気', '花', '血');

implementation

end.
