unit VectorRendererData;

// SVGなどのベクター画像をDelphiで扱いやすいpath単位のデータとして管理する。

interface

uses
  System.Classes,
  Vcl.Graphics,
  RTTIPersistentIni;

type
  // ベクター画像全体のサイズと座標系を管理する。
  TVectorRendererRootItem = class(TRTTIPersistentIni)
  private
    FWidth: Integer;                       // 画像の横幅
    FHeight: Integer;                      // 画像の高さ
    FViewBoxX: Double;                     // ViewBoxの左位置
    FViewBoxY: Double;                     // ViewBoxの上位置
    FViewBoxWidth: Double;                 // ViewBoxの横幅
    FViewBoxHeight: Double;                // ViewBoxの高さ
    FPreserveAspectRatio: string;          // SVGのpreserveAspectRatio属性
  public
    // 初期値を設定する。
    constructor Create;
  published
    property Width: Integer read FWidth write FWidth;
    property Height: Integer read FHeight write FHeight;
    property ViewBoxX: Double read FViewBoxX write FViewBoxX;
    property ViewBoxY: Double read FViewBoxY write FViewBoxY;
    property ViewBoxWidth: Double read FViewBoxWidth write FViewBoxWidth;
    property ViewBoxHeight: Double read FViewBoxHeight write FViewBoxHeight;
    property PreserveAspectRatio: string read FPreserveAspectRatio write FPreserveAspectRatio;
  end;

  // path一つ分の描画属性とpathデータを管理する。
  TVectorRendererElementItem = class(TRTTIPersistentIni)
  private
    FName: string;                         // 要素名
    FSourceTransform: string;              // 変換前のtransform属性
    FTranslateX: Double;                   // X方向の移動量
    FTranslateY: Double;                   // Y方向の移動量
    FMatrixA: Double;
    FMatrixB: Double;
    FMatrixC: Double;
    FMatrixD: Double;
    FMatrixE: Double;
    FMatrixF: Double;
    FFillSource: string;                   // 変換前のfill属性
    FFillColor: TColor;                    // 塗り色
    FPathData: string;                     // pathのd属性
  public
    // 初期値を設定する。
    constructor Create;
  published
    property Name: string read FName write FName;
    property SourceTransform: string read FSourceTransform write FSourceTransform;
    property TranslateX: Double read FTranslateX write FTranslateX;
    property TranslateY: Double read FTranslateY write FTranslateY;
    property MatrixA: Double read FMatrixA write FMatrixA;
    property MatrixB: Double read FMatrixB write FMatrixB;
    property MatrixC: Double read FMatrixC write FMatrixC;
    property MatrixD: Double read FMatrixD write FMatrixD;
    property MatrixE: Double read FMatrixE write FMatrixE;
    property MatrixF: Double read FMatrixF write FMatrixF;
    property FillSource: string read FFillSource write FFillSource;
    property FillColor: TColor read FFillColor write FFillColor;
    property PathData: string read FPathData write FPathData;
  end;

  // ベクター画像全体とpath要素リストをRTTI保存可能な形式で管理する。
  TVectorRendererDataList = class(TRTTIPersistentIniList<TVectorRendererElementItem>)
  private
    FRoot: TVectorRendererRootItem;        // 画像全体の情報
    // 指定位置のpath要素を返す。
    function GetElements(Index: Integer): TVectorRendererElementItem;
  protected
    // Rootセクションを保存する。
    procedure DoSaveSection(ItemSL: TStringList); override;
    // Rootセクションを読み込む。
    procedure DoLoadSection(ItemSL: TStringList); override;
  public
    // 所有権ありでリストを生成する。
    constructor Create; overload;
    // 所有権を指定してリストを生成する。
    constructor Create(AOwnsObjects: Boolean); overload;
    // Root情報を破棄する。
    destructor Destroy; override;
    // Root情報とpath要素を初期化する。
    procedure ClearData;
    // path要素を追加する。
    function AddElement: TVectorRendererElementItem;
    property Root: TVectorRendererRootItem read FRoot;
    property Elements[Index: Integer]: TVectorRendererElementItem read GetElements;
  end;

implementation

{ TVectorRendererRootItem }

// 初期値を設定する。
constructor TVectorRendererRootItem.Create;
begin
  inherited Create;
  FWidth := 0;
  FHeight := 0;
  FViewBoxX := 0;
  FViewBoxY := 0;
  FViewBoxWidth := 0;
  FViewBoxHeight := 0;
  FPreserveAspectRatio := '';
end;

{ TVectorRendererElementItem }

// 初期値を設定する。
constructor TVectorRendererElementItem.Create;
begin
  inherited Create;
  FName := '';
  FSourceTransform := '';
  FTranslateX := 0;
  FTranslateY := 0;
  FMatrixA := 1;
  FMatrixB := 0;
  FMatrixC := 0;
  FMatrixD := 1;
  FMatrixE := 0;
  FMatrixF := 0;
  FFillSource := '';
  FFillColor := clBlack;
  FPathData := '';
end;

{ TVectorRendererDataList }

// 所有権ありでリストを生成する。
constructor TVectorRendererDataList.Create;
begin
  Create(True);
end;

// 所有権を指定してリストを生成する。
constructor TVectorRendererDataList.Create(AOwnsObjects: Boolean);
begin
  inherited Create(AOwnsObjects);
  FRoot := TVectorRendererRootItem.Create;
end;

// Root情報を破棄する。
destructor TVectorRendererDataList.Destroy;
begin
  FRoot.Free;
  inherited;
end;

// path要素を追加する。
function TVectorRendererDataList.AddElement: TVectorRendererElementItem;
begin
  Result := AddNew;
end;

// Root情報とpath要素を初期化する。
procedure TVectorRendererDataList.ClearData;
begin
  Clear;
  FRoot.Free;
  FRoot := TVectorRendererRootItem.Create;
end;

// Rootセクションを読み込む。
procedure TVectorRendererDataList.DoLoadSection(ItemSL: TStringList);
begin
  FRoot.DeserializeFromStrings(FRoot, ItemSL);
end;

// Rootセクションを保存する。
procedure TVectorRendererDataList.DoSaveSection(ItemSL: TStringList);
begin
  FRoot.SerializeToStrings(FRoot, ItemSL);
end;

// 指定位置のpath要素を返す。
function TVectorRendererDataList.GetElements(
  Index: Integer): TVectorRendererElementItem;
begin
  Result := TVectorRendererElementItem(inherited Items[Index]);
end;

end.
