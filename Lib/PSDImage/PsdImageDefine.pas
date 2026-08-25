unit PsdImageDefine;

interface

type TPsdFileBlandType = (btNil,   // ブレンドモードを示す物では無い
                          btPass,  //   パススルー、
                          btNorm,  //  通常、
                          btDiss,  //  ディゾルブ、
                          btDark,  //  暗く、
                          btMul,   //  乗算、
                          btIdiv,  //  カラーバーン、
                          btLbrn,  //  リニアバーン、
                          btDkCl,  //  ダークcolor、
                          btLite,  //  lighten、
                          btScrn,  //  screen、
                          btDiv,   //  color dodge
                          btLddg,  //  linear dodge、
                          btLgCl,  //  lighter color、
                          btOver,  //  overlay、
                          btSLit,  //  soft light、
                          btHLit,  //  ハードライト、
                          btVLit,  //  ビビッドライト、
                          btLLit,  //  リニアライト、
                          btPLit,  //  ピンライト、
                          btHMix,  //  ハードミックス、
                          btDiff,  //  差、
                          btSmud,  //  除外、
                          btFsub,  //  減算、
                          btFdiv,  //  除算
                          btHue,   //  色相、
                          btSat,   //  飽和、
                          btCol,   //  色、
                          btLum    //  明るさ、
                          );


const BLEND_KEY: array[0..27] of AnsiString = ('pass','norm','diss','dark','mul ',
                                               'idiv','lbrn','dkCl','lite','scrn',
                                               'div ','lddg','lgCl','over','sLit',
                                               'hLit','vLit','lLit','pLit','hMix',
                                               'diff','smud','fsub','fdiv','hue ',
                                               'sat ','col ','lum ');

type TPsdFileColorType = (ctNil,   // チャンネル毎の色モード
                          ctR,     // 赤
                          ctG,     // 緑
                          ctB,     // 青
                          ctAlpha, // アルファチャンネル透明度 0:不透明 255:透明
                          ctMask   // マスク
                          );


// 表情（大分類／小分類）探索時の探索範囲を指定する
type
TPsdElementSearchScope = (
  pssVisibleOnly,          // 表示中のレイヤーのみを探索する
  pssUnmarkedOrVisible,    // 非表示でもマーク（* 等）が付いていないレイヤーを探索対象に含める
  pssAll                  // 表示状態やマーク有無に関係なくすべて探索する
);

type
  TPsdElementProcessMode = (
    pepmSetVisible,     // 対象が見つかったら Visible := True にする
    pepmCheckVisible    // 対象が見つかったら 現在の Visible 状態を返す
  );


type  TFourth = packed record
    B,G,R,A : Byte;
  end;
TFourthArray = array[0..40000000] of TFourth;
PFourthArray = ^TFourthArray;


type  TTriple = packed record
    B,G,R : Byte;
  end;
TTripleArray = array[0..40000000] of TTriple;
PTripleArray = ^TTripleArray;



implementation

end.
