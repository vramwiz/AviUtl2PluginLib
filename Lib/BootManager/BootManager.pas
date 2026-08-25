{
  TBootManager ユニット
  ---------------------------------------------------------------------------
  このユニットは、アプリケーション内の複数ツールフォームを
  一元管理し、起動方法を統合するための仕組みを提供します。

  【主な役割】

  ■ 1. ツールフォームの登録管理
      - ID、コマンドライン引数、フォームクラスを関連付けて保持します。
      - インスタンスは必要に応じて Application.CreateForm により生成され、
        再利用されます。

  ■ 2. 起動ルートの切替（通常起動／引数起動）
      - 通常起動：Launcher フォーム（例：ToolBar）をメインフォームとして開始。
      - 引数起動：Launcher を生成せず、指定されたツールフォーム単体を実行。

  ■ 3. フォーム破棄の検知
      - FreeNotification によりツールフォームが閉じられたことを検知し、
        Instance を nil へ戻し、必要に応じてランチャーを復帰表示します。

  ■ 4. プラグインや外部モジュールからの呼び出しにも対応
      - 起動ロジックが dpr 側と BootManager に明確に分離されているため、
        AviUtl2 等からの外部起動にも安定して対応できます。

  【特徴】

      - Application.CreateForm を統一使用し、MainForm 管理を安全に制御
      - MainFormOnTaskbar の操作は不要（副作用防止のため非使用）
      - RunByArg と RunByID により外部／内部両方向から柔軟に起動可能
      - TComponent による FreeNotification を活用した破棄検知

  【想定用途】

      - 複数のツールフォームを持つ統合アプリケーション
      - ランチャーを介したツール切り替え
      - コマンドライン引数によるツール単体起動（デバッグ・外部連携）
      - プラグインからの単体ツール呼び出し

  ---------------------------------------------------------------------------
  このユニットにより、アプリケーションの「起動」「管理」「復帰」処理を
  一つの統合された流れとして構築できます。
}

unit BootManager;

interface

uses
  System.SysUtils, System.Classes, Vcl.Forms;

type
  TToolFormClass = class of TForm;

  TBootEntry = record
    ID       : Integer;        // 登録ID（ToolBarボタンや外部指定と対応）
    Arg      : string;         // コマンドライン引数名（例：'anm'）
    FormClass: TToolFormClass; // 起動するフォームのクラス
    Instance : TForm;          // 実際に生成されたフォームインスタンス
  end;

  TBootManager = class(TComponent)
  private
    FEntries      : array of TBootEntry; // 登録済みツール一覧
    FLauncherForm : TForm;               // ランチャーフォーム（通常起動時のMainForm）
    FRunningForm  : TForm;               // 現在起動中のツールフォーム

    FOnToolFinish : TNotifyEvent;       // ツール終了イベント
    // ID を指定して登録リストから検索し、Index を返す
    function FindByID(const ID: Integer): Integer;
    // Arg を指定して登録リストから検索し、Index を返す
    function FindByArg(const Arg: string): Integer;
    // 登録されたフォームを通常起動として開始（CreateForm 統一）
    procedure StartForm(const Index: Integer);
    // コマンドライン引数から起動 → ランチャーを生成せず動作する
    procedure StartFormArg(const Index: Integer);
  protected
    // Instance が Free されたときに呼ばれ、ランチャー復帰などを行う
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    //   ツールフォームが終了し、BootManager が制御を取り戻した直後に呼ばれる
    procedure DoToolFinish(); virtual;
  public
    // Tool を登録する（ID・Arg・フォームクラス）
    procedure RegisterTool(const ID: Integer; const Arg: string; AClass: TToolFormClass);
    // ランチャーフォームを登録する（通常起動時にのみ使用）
    procedure SetLauncher(AForm: TForm);
    // ID を指定してツールを起動する（ToolBar 経由）
    function RunByID(const ID: Integer): Boolean;
    // 引数を指定してツール単体起動する（dpr 側から使用）
    function RunByArg(const Arg: string): Boolean;
  public
    property OnToolFinish: TNotifyEvent read FOnToolFinish write FOnToolFinish;
  end;


var
  GBootManager: TBootManager;

implementation

{ TBootManager }

//-----------------------------------------------
// ランチャー登録
//-----------------------------------------------
procedure TBootManager.SetLauncher(AForm: TForm);
begin
  FLauncherForm := AForm;
end;

//-----------------------------------------------
// ツール登録
//-----------------------------------------------
procedure TBootManager.RegisterTool(const ID: Integer; const Arg: string;
  AClass: TToolFormClass);
var
  i: Integer;
begin
  i := Length(FEntries);
  SetLength(FEntries, i + 1);
  FEntries[i].ID        := ID;
  FEntries[i].Arg       := LowerCase(Arg);
  FEntries[i].FormClass := AClass;
  FEntries[i].Instance  := nil;
end;

//-----------------------------------------------
// ID検索
//-----------------------------------------------
function TBootManager.FindByID(const ID: Integer): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FEntries) do
    if FEntries[i].ID = ID then
      Exit(i);
  Result := -1;
end;

procedure TBootManager.DoToolFinish();
begin
  if Assigned(FOnToolFinish) then   FOnToolFinish(Self);
end;

//-----------------------------------------------
// Arg検索
//-----------------------------------------------
function TBootManager.FindByArg(const Arg: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FEntries) do
    if SameText(FEntries[i].Arg, Arg) then
      Exit(i);
  Result := -1;
end;

//-----------------------------------------------
// ツール起動本体
//-----------------------------------------------
procedure TBootManager.StartForm(const Index: Integer);
var
  Form: TForm;
begin

  // 既存があればそのまま・なければ生成
  if FEntries[Index].Instance = nil then
  begin
    FEntries[Index].Instance :=
      FEntries[Index].FormClass.Create(Application);
    FEntries[Index].Instance.FreeNotification(Self);
  end;

  FRunningForm := FEntries[Index].Instance;

  Form := FEntries[Index].Instance;
  Form.Show;
end;

procedure TBootManager.StartFormArg(const Index: Integer);
var
  Form: TForm;
begin
  // ツール単体起動時の Application.Run 対策
  Application.MainFormOnTaskbar := False;

  // 既存があればそのまま・なければ生成
  if FEntries[Index].Instance = nil then
  begin
    Application.CreateForm(FEntries[Index].FormClass, FEntries[Index].Instance);
    FEntries[Index].Instance.FreeNotification(Self);
  end;

  FRunningForm := FEntries[Index].Instance;

  Form := FEntries[Index].Instance;
  Form.Show;
end;

//-----------------------------------------------
// Argによる起動
//-----------------------------------------------
function TBootManager.RunByArg(const Arg: string): Boolean;
var
  idx: Integer;
begin
  idx := FindByArg(LowerCase(Arg));
  if idx >= 0 then
  begin
    StartFormArg(idx);
    Exit(True);
  end;
  Result := False;
end;

//-----------------------------------------------
// IDによる起動
//-----------------------------------------------
function TBootManager.RunByID(const ID: Integer): Boolean;
var
  idx: Integer;
begin
  idx := FindByID(ID);
  if idx >= 0 then
  begin
    //FArgLaunch := False;  // ← ランチャー経由
    StartForm(idx);
    Exit(True);
  end;
  Result := False;
end;

//-----------------------------------------------
// フォーム終了監視
//-----------------------------------------------
procedure TBootManager.Notification(AComponent: TComponent; Operation: TOperation);
var
  i: Integer;
begin
  inherited;

  if (Operation = opRemove) and (AComponent = FRunningForm) then
  begin
    // Running を消す
    FRunningForm := nil;

    // 登録リスト側も同期してnilにする
    for i := 0 to High(FEntries) do
      if FEntries[i].Instance = AComponent then
      begin
        FEntries[i].Instance := nil;
        Break;
      end;

    DoToolFinish();
  end;
end;

initialization
  GBootManager := TBootManager.Create(nil);

finalization
  GBootManager.Free;

end.

