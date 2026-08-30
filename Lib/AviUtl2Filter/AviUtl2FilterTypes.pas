unit AviUtl2FilterTypes;

{$ALIGN 8}

interface

uses
  Winapi.Windows;

type
  LPCWSTR = PWideChar;
  OBJECT_HANDLE = Pointer;

  PEDIT_SECTION = ^TEDIT_SECTION;
  TSetObjectItemValueFunc = function(Obj: OBJECT_HANDLE; Effect: LPCWSTR;
    Item: LPCWSTR; Value: PAnsiChar): LongBool; cdecl;
  TGetFocusObjectFunc = function: OBJECT_HANDLE; cdecl;

  TEDIT_SECTION = record
    Info: Pointer;
    CreateObjectFromAlias: Pointer;
    FindObject: Pointer;
    CountObjectEffect: Pointer;
    GetObjectLayerFrame: Pointer;
    GetObjectAlias: Pointer;
    GetObjectItemValue: Pointer;
    SetObjectItemValue: TSetObjectItemValueFunc;
    MoveObject: Pointer;
    DeleteObject: Pointer;
    GetFocusObject: TGetFocusObjectFunc;
  end;

  // =============================================================
  //  設定項目
  // =============================================================

  PFILTER_ITEM_TRACK = ^TFILTER_ITEM_TRACK;
  TFILTER_ITEM_TRACK = record
    ItemType: LPCWSTR;  // 'track'
    Name: LPCWSTR;
    Value: Double;
    S, E: Double;
    Step: Double;
  end;

  PFILTER_ITEM_CHECK = ^TFILTER_ITEM_CHECK;
  TFILTER_ITEM_CHECK = record
    ItemType: LPCWSTR;  // 'check'
    Name: LPCWSTR;
    Value: Byte;        // bool (1byte)
  end;

  PFILTER_ITEM_COLOR = ^TFILTER_ITEM_COLOR;
  TFILTER_ITEM_COLOR = record
    ItemType: LPCWSTR;  // 'color'
    Name: LPCWSTR;
    B, G, R, X: Byte;
  end;

  PFILTER_ITEM_SELECT = ^TFILTER_ITEM_SELECT;
  TFILTER_ITEM_SELECT_ITEM = record
    Name: LPCWSTR;
    Value: Integer;
  end;

  TFILTER_ITEM_SELECT = record
    ItemType: LPCWSTR;  // 'select'
    Name: LPCWSTR;
    Value: Integer;
    List: ^TFILTER_ITEM_SELECT_ITEM; // NULL終端
  end;

  PFILTER_ITEM_FILE = ^TFILTER_ITEM_FILE;
  TFILTER_ITEM_FILE = record
    ItemType: LPCWSTR;  // 'file'
    Name: LPCWSTR;
    Value: LPCWSTR;     // AviUtl側が代入
    FileFilter: LPCWSTR;
  end;

  // ---- beta29 追加（非ジェネリック data）----
  PFILTER_ITEM_DATA = ^TFILTER_ITEM_DATA;
  TFILTER_ITEM_DATA = record
    ItemType: LPCWSTR;  // 'data'
    Name: LPCWSTR;
    Value: Pointer;    // void*
    Size: Integer;     // sizeof(data)
    DefaultValue: Pointer; // void*
  end;

  // =============================================================
  //  beta29 追加GUI（AviUtl2FilterTypes.pas の interface に追加）
  // =============================================================

  // group
  PFILTER_ITEM_GROUP = ^TFILTER_ITEM_GROUP;
  TFILTER_ITEM_GROUP = record
    ItemType: LPCWSTR;       // 'group'
    Name: LPCWSTR;
    DefaultVisible: Byte;    // bool(1byte)
  end;

  // string
  PFILTER_ITEM_STRING = ^TFILTER_ITEM_STRING;
  TFILTER_ITEM_STRING = record
    ItemType: LPCWSTR;       // 'string'
    Name: LPCWSTR;
    Value: LPCWSTR;          // AviUtl側がポインタ更新
  end;

  // text
  PFILTER_ITEM_TEXT = ^TFILTER_ITEM_TEXT;
  TFILTER_ITEM_TEXT = record
    ItemType: LPCWSTR;       // 'text'
    Name: LPCWSTR;
    Value: LPCWSTR;          // AviUtl側がポインタ更新
  end;

  // folder
  PFILTER_ITEM_FOLDER = ^TFILTER_ITEM_FOLDER;
  TFILTER_ITEM_FOLDER = record
    ItemType: LPCWSTR;       // 'folder'
    Name: LPCWSTR;
    Value: LPCWSTR;          // AviUtl側がポインタ更新
  end;

  TFILTER_ITEM_BUTTON_CALLBACK = procedure(Edit: PEDIT_SECTION); cdecl;

  PFILTER_ITEM_BUTTON = ^TFILTER_ITEM_BUTTON;
  TFILTER_ITEM_BUTTON = record
    ItemType: LPCWSTR;       // 'button'
    Name: LPCWSTR;
    Callback: TFILTER_ITEM_BUTTON_CALLBACK;
  end;


  // =============================================================
  //  シーン・オブジェクト情報
  // =============================================================

  PSCENE_INFO = ^TSCENE_INFO;
  TSCENE_INFO = record
    Width, Height: Integer;
    Rate, Scale: Integer;
    SampleRate: Integer;
  end;

  POBJECT_INFO = ^TOBJECT_INFO;
  TOBJECT_INFO = record
    ID: Int64;
    Frame: Integer;
    FrameTotal: Integer;
    Time: Double;
    TimeTotal: Double;
    Width, Height: Integer;
    SampleIndex: Int64;
    SampleTotal: Int64;
    SampleNum: Integer;
    ChannelNum: Integer;
    EffectID: Int64;
    Flag: Integer; // SDK 50: FLAG_FILTER_OBJECT など
    Layer: Integer;
    Index: Integer;
    Num: Integer;
    FrameS: Integer; // 全体(シーン)基準のオブジェクト開始フレーム
    FrameE: Integer; // 全体(シーン)基準のオブジェクト終了フレーム
    EffectLayer: Integer;
  end;

  POBJECT_IMAGE_PARAM = ^TOBJECT_IMAGE_PARAM;
  TOBJECT_IMAGE_PARAM = record
    X, Y, Z: Single;
    RX, RY, RZ: Single;
    SX, SY, SZ: Single;
    CX, CY, CZ: Single;
    Alpha: Single;
  end;

  // =============================================================
  //  フィルタ処理
  // =============================================================

  PIXEL_RGBA = packed record
    R, G, B, A: Byte;
  end;
  PPIXEL_RGBA = ^PIXEL_RGBA;

  PID3D11Texture2D = Pointer;

  TFILTER_PROC_VIDEO_GET_TEX2D = function: PID3D11Texture2D; cdecl;
  TFILTER_PROC_VIDEO_GET_OUTPUT_IMAGE_PARAM = function(Obj: OBJECT_HANDLE;
    Offset: Double; Param: POBJECT_IMAGE_PARAM; ParamSize: Integer): Byte; cdecl;
  TFILTER_PROC_VIDEO_GET_IMAGE_OBJECT = function(Layer: Integer;
    Offset: Double): OBJECT_HANDLE; cdecl;

  PFILTER_PROC_VIDEO = ^TFILTER_PROC_VIDEO;
  TFILTER_PROC_VIDEO = record
    Scene: PSCENE_INFO;
    Object_: POBJECT_INFO;

    GetImageData: procedure(Buffer: PPIXEL_RGBA); cdecl;
    SetImageData: procedure(Buffer: PPIXEL_RGBA; Width, Height: Integer); cdecl;

    // beta29 追加（未使用でも問題なし）
    GetImageTexture2D: TFILTER_PROC_VIDEO_GET_TEX2D;
    GetFramebufferTexture2D: TFILTER_PROC_VIDEO_GET_TEX2D;
    Edit: PEDIT_SECTION;
    Param: POBJECT_IMAGE_PARAM;
    GetOutputImageParam: TFILTER_PROC_VIDEO_GET_OUTPUT_IMAGE_PARAM;
    GetImageObject: TFILTER_PROC_VIDEO_GET_IMAGE_OBJECT;
  end;

  PFILTER_PROC_AUDIO = ^TFILTER_PROC_AUDIO;
  TFILTER_PROC_AUDIO = record
    Scene: PSCENE_INFO;
    Object_: POBJECT_INFO;
    GetSampleData: procedure(Buffer: PSingle; Channel: Integer); cdecl;
    SetSampleData: procedure(Buffer: PSingle; Channel: Integer); cdecl;
  end;

  // =============================================================
  //  FILTER_PLUGIN_TABLE
  // =============================================================

  TFuncProcVideo = function(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
  TFuncProcAudio = function(Audio: PFILTER_PROC_AUDIO): Byte; cdecl;

  PFILTER_PLUGIN_TABLE = ^TFILTER_PLUGIN_TABLE;
  TFILTER_PLUGIN_TABLE = record
    Flag: Integer;
    Name: LPCWSTR;
    Label_: LPCWSTR;
    Information: LPCWSTR;
    Items: ^Pointer; // void** (NULL終端)
    Func_Proc_Video: TFuncProcVideo;
    Func_Proc_Audio: TFuncProcAudio;
  end;

const
  FILTER_FLAG_VIDEO  = 1;
  FILTER_FLAG_AUDIO  = 2;
  FILTER_FLAG_INPUT  = 4;
  FILTER_FLAG_FILTER = 8;

  OBJECT_FLAG_FILTER_OBJECT = 1;

implementation
end.

