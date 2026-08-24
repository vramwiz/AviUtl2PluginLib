unit ToolBarActionFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, System.ImageList,
  Vcl.ImgList, Vcl.ComCtrls, Vcl.ToolWin,System.Generics.Collections;

type
  // ツールバーで扱う操作の種別
  TToolBarActionKind = (
    taUp,        // 上に移動
    taDown,      // 下に移動
    taReverse,   // 逆順並び替え
    taAdd,       // 追加
    taCopy,      // コピー
    taDelete,    // 削除
    taOpen,      // ファイル開く
    taMusic,     // 音楽再読込
    taRefresh,   // 画面更新
    taFace,      // 表情再取得
    taRead,      // 読み込み
    taWrite      // 書き込み
  );

type
  TToolBarActionDef = record
    Caption    : string;
    Hint       : string;
    ImageIndex : Integer;
  end;

  const
  ToolBarActionDefs: array[TToolBarActionKind] of TToolBarActionDef = (
    (Caption : '上へ';Hint : '選択した要素を上へ移動';ImageIndex : Ord(taUp)),
    (Caption : '下へ';Hint : '選択した要素を下へ移動';ImageIndex : Ord(taDown)),
    (Caption : '逆順';Hint : '逆順に並び替える'      ;ImageIndex : Ord(taReverse)),
    (Caption : '追加';Hint : '要素を追加'            ;ImageIndex : Ord(taAdd)),
    (Caption : '複製';Hint : '要素をコピーして追加'  ;ImageIndex : Ord(taCopy)),
    (Caption : '削除';Hint : '要素を削除'            ;ImageIndex : Ord(taDelete)),
    (Caption : '開く';Hint : 'ファイルを開く'        ;ImageIndex : Ord(taOpen)),
    (Caption : '音楽';Hint : '音楽データを再読込'    ;ImageIndex : Ord(taMusic)),
    (Caption : '更新';Hint : '画面を更新し再読込'    ;ImageIndex : Ord(taRefresh)),
    (Caption : '表情';Hint : '表情を再取得'          ;ImageIndex : Ord(taFace)),
    (Caption : '読込';Hint : 'AviUtl2から読み込み'   ;ImageIndex : Ord(taRead)),
    (Caption : '書込';Hint : 'AviUtl2へ書き込み'     ;ImageIndex : Ord(taWrite))
  );


type
  TFrameToolBarAction = class(TFrame)
    imgList: TImageList;
    ActionToolBar: TToolBar;
  private
    { Private 宣言 }
    FProcs      : TList<TProc>;
    FTotalWidth : Integer;
    // ActionKind から ToolButton を生成する
    function CreateToolButton(Kind: TToolBarActionKind; ProcIndex: Integer): TToolButton;
    procedure ToolButtonClick(Sender: TObject);
    function GetCount: Integer;
    function GetVisibleImage: Boolean;
    procedure SetVisibleImage(const Value: Boolean);
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure Add(Kind: TToolBarActionKind; AProc: TProc);
    function AddSeparator(AWidth: Integer): TToolButton;

    procedure Clear;
    property Count: Integer read GetCount;
    property VisibleImage : Boolean read GetVisibleImage write SetVisibleImage;
  end;

implementation

{$R *.dfm}

{ TFrameToolBarAction }

constructor TFrameToolBarAction.Create(AOwner: TComponent);
begin
  inherited;
  FProcs := TList<TProc>.Create;
  FTotalWidth := 0;
end;

destructor TFrameToolBarAction.Destroy;
begin
  Clear;
  FProcs.Free;
  inherited;
end;

procedure TFrameToolBarAction.Add(Kind: TToolBarActionKind; AProc: TProc);
var
  Index: Integer;
begin
  if not Assigned(AProc) then Exit;
  ActionToolBar.Images := imgList;
  //ActionToolBar.Images := nil;

  Index := FProcs.Count;
  FProcs.Add(AProc);

  CreateToolButton(Kind, Index);
end;

function TFrameToolBarAction.AddSeparator(AWidth: Integer): TToolButton;
begin
  Result := TToolButton.Create(Self);
  Result.Style := tbsSeparator;
  Result.Width := AWidth;

  Result.Left := FTotalWidth+1;
  Result.Parent := ActionToolBar;

  Inc(FTotalWidth, AWidth);
end;

procedure TFrameToolBarAction.Clear;
var
  i: Integer;
begin
  // ToolButton を全破棄
  for i := ActionToolBar.ButtonCount - 1 downto 0 do
    ActionToolBar.Buttons[i].Free;

  // 登録済み Proc をクリア
  FProcs.Clear;
  FTotalWidth := 0;
end;


function TFrameToolBarAction.CreateToolButton(
  Kind: TToolBarActionKind; ProcIndex: Integer): TToolButton;
var
  Def: TToolBarActionDef;
begin
  Def := ToolBarActionDefs[Kind];

  Result := TToolButton.Create(Self);
  Result.Style := tbsButton;
  Result.AutoSize := True;
  Result.Tag := ProcIndex;

  Result.Caption := Def.Caption;
  Result.Hint := Def.Hint;
  Result.ImageIndex := Def.ImageIndex;
  Result.ShowHint := True;
  Result.OnClick := ToolButtonClick;

  Result.Left := FTotalWidth+1;      // ★ 先に位置を決める
  Result.Parent := ActionToolBar;  // ★ 最後に Parent

  Inc(FTotalWidth, Result.Width);
end;


procedure TFrameToolBarAction.ToolButtonClick(Sender: TObject);
var
  Idx: Integer;
begin
  if not (Sender is TToolButton) then Exit;

  Idx := TToolButton(Sender).Tag;
  if (Idx >= 0) and (Idx < FProcs.Count) then
    FProcs[Idx]();
end;

function TFrameToolBarAction.GetCount: Integer;
begin
  Result := FProcs.Count;
end;


function TFrameToolBarAction.GetVisibleImage: Boolean;
begin
  Result :=  (ActionToolBar.Images <> nil);
end;

procedure TFrameToolBarAction.SetVisibleImage(const Value: Boolean);
begin
  if Value then begin
    ActionToolBar.Images := imgList;
  end
  else begin
    ActionToolBar.Images := nil;
  end;
end;

end.
