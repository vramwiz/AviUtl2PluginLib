{*******************************************************************************
  PsdFileTreeView
  -------------------------------------------------------------------------------
  ■ 概要
    PSD（Photoshop）レイヤー構造をツリー表示するための TTreeView 派生クラス。
    レイヤー名・階層・可視状態（○●）・サムネイル画像を用いて
    AviUtl2 用「立ち絵・服装・表情ツリー」を視覚的に操作できる。

  ■ 主な機能
    - PSD のレイヤーツリー（TPsdImage.Trees）を元にノードを構築
    - ノードの展開・折りたたみに応じて子レイヤーを動的読み込み
    - 各レイヤーのサムネイル（簡易縮小画像）を自動生成して ImageList に格納
    - レイヤーの Visible フラグ（ON/OFF）をツリー上の ○● で表示
    - Visible のトグルクリックを検知して外部へ通知（OnTreeClick）
    - 展開済みツリーの管理（無駄な二重展開を防止）
    - AviUtl2 の制約に対応するため、非同期展開スレッドは PostMessage ベースで実装
      （Synchronize を使用しないことで DLL 内 UI のクラッシュを防止）

  ■ 設計上の重要ポイント
    ● 同期（TThread.Synchronize）は使用しない
      AviUtl2 の GUI では Synchronize が正常に動作せず、不正描画やノード消失を招く。
      そのため、スレッドから UI 操作を行う場合は PostMessage を使用する。

    ● WM_PSDTREE_ADDNODE / WM_PSDTREE_FINISH
      展開スレッドからツリーへのノード追加／削除／完了通知は
      上記のカスタムメッセージでメインスレッドへ伝達する。

    ● スレッドは “ノード構造だけ” を処理する
      UI への直接アクセスはすべてメインスレッド側のメッセージハンドラで行う。
      これにより VCL スレッドセーフ性を担保する。

    ● ツリー更新は BeginUpdate / EndUpdate で集中的に行う
      表示のちらつきや途中描画を防止する。

  ■ 使用方法（呼び出し側）
    1) PsdImage をセット
       PsdTreeView.PsdImage := MyPsdImage;

    2) ツリー生成
       PsdTreeView.ShowTree;

    3) ユーザーが可視状態を変更したら OnTreeClick で通知される

  ■ 注意事項
    - TreeView の Parent を設定した後に ShowTree を呼び出すこと
      （ハンドル未生成状態でアイコン追加を行うと例外が発生するため）

    - PsdImage が変更された場合は、必ず Clear → ShowTree で再構築すること

    - 大量画像を含む PSD はサムネイル生成コストが高いため、
      必要に応じてキャッシュ化の拡張が可能
*******************************************************************************}

unit PsdFileTreeView;

interface

uses
  Winapi.Windows,Winapi.Messages,System.SysUtils,System.Variants,
  System.Classes,Vcl.Graphics,Vcl.Controls,Vcl.Forms,Vcl.Dialogs,
  Vcl.ImgList, Vcl.ComCtrls,Vcl.StdCtrls,Vcl.ExtCtrls,System.ImageList,
  PsdImage,PsdImageLayer,PsdImageTree;

const
  WM_PSDTREE_ADDNODE = WM_USER + $200;
  WM_PSDTREE_FINISH  = WM_USER + $201;

//--------------------------------------------------------------------------//
//  展開済みツリーを記憶するクラス                                          //
//--------------------------------------------------------------------------//
type
  TPsdFileTreeViewExpands = class(TList)
  public
    function IsExpand(Trees: TPsdFileTrees): Boolean;
    procedure AddExpand(Trees: TPsdFileTrees);
  end;

//--------------------------------------------------------------------------//
//  サムネイル生成用スレッド                                                //
//--------------------------------------------------------------------------//
type
  TPsdFileTreeViewThread = class(TThread)
  private
    FTreeView: TTreeView;                  // 対象ツリービュー
    FParentNode: TTreeNode;                // 展開対象のノード
    FExpands: TPsdFileTreeViewExpands;     // 展開済みツリー管理
    FOnFinish: TNotifyEvent;               // 終了イベント（フラグ変更のみ）

    FWorkTrees: TPsdFileTrees;             // 処理中の子ツリー
    FWorkTree: TPsdFileTree;               // 処理中ツリー
    FWorkLayer: TPsdFileLayer;             // 処理中レイヤー

  protected
    procedure Execute; override;
  public
    constructor Create(ATreeView: TTreeView; AParentNode: TTreeNode;
                       AExpands: TPsdFileTreeViewExpands; AOnFinish: TNotifyEvent);
    destructor Destroy; override;
  end;

//--------------------------------------------------------------------------//
//  PSD用レイヤーツリーコントロール（TTreeView派生）                        //
//--------------------------------------------------------------------------//
type
  TPsdFileTreeView = class(TTreeView)
  private
    FPsdImage: TPsdImage;                  // PSD解析済みオブジェクト
    FExpanding: Boolean;                   // 展開／折りたたみ直後のクリック抑制
    FExpands: TPsdFileTreeViewExpands;     // 展開済みツリー
    FThreading: Boolean;                   // スレッド実行中フラグ
    FThread: TPsdFileTreeViewThread;       // サムネイル生成スレッド
    FDestroying: Boolean;                  // 破棄中フラグ

    FSelectTrees: TPsdFileTrees;           // 選択中ツリーの子リスト
    FSelectTree: TPsdFileTree;             // 選択中ツリー

    FImageLayers: TImageList;              // レイヤーサムネイル
    FImageStates: TImageList;              // ○●の表示状態用

    FTempBmpFrom: TBitmap;
    FTempBmpTo: TBitmap;

    FOnTreeClick: TNotifyEvent;             // 可視状態変更時イベント

    // ○●状態画像を作成して登録
    procedure InitStateImages;
    // Visibleフラグをツリーの StateIndex に反映
    procedure RefreshCheckStates;
    procedure FlushPendingMessages;
    procedure StopThread;
    procedure ExpandNodeLevel(Node: TTreeNode; Level: Integer);

    function GetSelectTreeOwner: TPsdFileTree;

    // TreeViewイベント用ハンドラ
    procedure HandleNodeExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure HandleNodeCollapsing(Sender: TObject; Node: TTreeNode;
      var AllowCollapse: Boolean);
    procedure HandleNodeExpanded(Sender: TObject; Node: TTreeNode);
    procedure HandleNodeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);

    // スレッド終了イベント（フラグだけ変更）
    procedure OnThreadFinished(Sender: TObject);
    // マウス降下処理を内部で済ませる
    procedure WMLButtonDown(var Message: TWMLButtonDown); message WM_LBUTTONDOWN;
  protected
    procedure DoTreeClick;virtual;
    procedure WMPsdAddNode(var Msg: TMessage); message WM_PSDTREE_ADDNODE;
    procedure WMPsdFinish(var Msg: TMessage);  message WM_PSDTREE_FINISH;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // PSDツリーをルートから再構築
    procedure ShowTree;
    // 表示状態（Visible）に合わせてチェック画像だけ更新
    procedure ShowTreeCheck;

    // True: サムネイル生成スレッドが動作中
    function IsThread: Boolean;

    procedure ExpandLevel(Level: Integer);

    property PsdImage: TPsdImage read FPsdImage write FPsdImage;
    property SelectTrees: TPsdFileTrees read FSelectTrees;
    property SelectTree: TPsdFileTree read FSelectTree;
    property SelectTreeOwner: TPsdFileTree read GetSelectTreeOwner;

    property OnTreeClick: TNotifyEvent read FOnTreeClick write FOnTreeClick;
  end;

implementation

uses AviUtl2StyleColors;

//--------------------------------------------------------------------------//
//  ヘルパー：アスペクト比を維持した描画範囲を計算                         //
//--------------------------------------------------------------------------//
procedure RectToStreachRect(var r: TRect; const aWidth, aHeight: Integer);
var
  xh, yh, xhr, yhr: Integer;
begin
  if (aWidth = 0) or (aHeight = 0) then
    Exit;

  xhr := r.Width;
  yhr := r.Height;

  if aWidth > aHeight then
  begin
    yh := r.Width * aHeight div aWidth;
    r.Top := (yhr - yh) div 2;
    r.Height := yh;
  end
  else
  begin
    xh := r.Height * aWidth div aHeight;
    r.Left := (xhr - xh) div 2;
    r.Width := xh;
  end;
end;

//==========================================================================
//  TPsdFileTreeViewExpands
//==========================================================================//
function TPsdFileTreeViewExpands.IsExpand(Trees: TPsdFileTrees): Boolean;
var
  i: Integer;
begin
  Result := False;
  if Trees = nil then
    Exit;

  for i := 0 to Count - 1 do
  begin
    if Items[i] = Trees then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TPsdFileTreeViewExpands.AddExpand(Trees: TPsdFileTrees);
begin
  if (Trees <> nil) and (not IsExpand(Trees)) then
    Add(Trees);
end;

//==========================================================================
//  TPsdFileTreeViewThread
//==========================================================================//
constructor TPsdFileTreeViewThread.Create(ATreeView: TTreeView;
  AParentNode: TTreeNode; AExpands: TPsdFileTreeViewExpands;
  AOnFinish: TNotifyEvent);
begin
  inherited Create(False);

  FreeOnTerminate := False;
  FTreeView := ATreeView;
  FParentNode := AParentNode;
  FExpands := AExpands;
  FOnFinish := AOnFinish;

  FWorkTrees := nil;
  FWorkTree := nil;
  FWorkLayer := nil;
end;

destructor TPsdFileTreeViewThread.Destroy;
begin
  // 参照だけなので特別な解放は不要
  inherited;
end;



procedure TPsdFileTreeViewThread.Execute;
var
  i: Integer;
begin
  // 親ノードが無効なら終了
  if (FParentNode = nil) or (FParentNode.Data = nil) then Exit;

  // 子ツリー取得
  FWorkTree := TPsdFileTree(FParentNode.Data);
  FWorkTrees := TPsdFileTrees(FWorkTree.Trees);
  if FWorkTrees = nil then Exit;

  // 展開済みなら再展開しない
  if FExpands.IsExpand(FWorkTrees) then Exit;

  // 展開済みに登録
  FExpands.AddExpand(FWorkTrees);

  // ダミーノード（最初の子）を削除
  if FParentNode.Count > 0 then
    PostMessage(FTreeView.Handle, WM_PSDTREE_ADDNODE,
      WPARAM(FParentNode.Item[0]), LPARAM(nil)); // 削除命令

  // 子ノードを順に追加
  for i := 0 to FWorkTrees.Count - 1 do
  begin
    if Terminated then Break;

    FWorkTree := FWorkTrees[i];
    PostMessage(FTreeView.Handle, WM_PSDTREE_ADDNODE,
      WPARAM(FParentNode), LPARAM(FWorkTree));
  end;

  // スレッド終了通知
  PostMessage(FTreeView.Handle, WM_PSDTREE_FINISH, 0, 0);
end;


//==========================================================================
//  TPsdFileTreeView
//==========================================================================//
constructor TPsdFileTreeView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Color := A2SCTreeViewBackground;
  Font.Color := clWhite;
  Font.Height := - 12;

  // イメージリスト作成（サムネイル）
  FImageLayers := TImageList.Create(Self);
  FImageLayers.Width := 32;
  FImageLayers.Height := 32;

  // 状態表示用（○●）
  FImageStates := TImageList.Create(Self);
  FImageStates.Width := 16;
  FImageStates.Height := 16;

  Images := FImageLayers;
  StateImages := FImageStates;

  FTempBmpFrom := TBitmap.Create;
  FTempBmpTo   := TBitmap.Create;

  FExpands := TPsdFileTreeViewExpands.Create;
  FPsdImage := nil;
  FThread := nil;
  FThreading := False;
  FDestroying := False;
  FExpanding := False;
  FSelectTrees := nil;
  FSelectTree := nil;

  // TreeView 設定
  ReadOnly := True;
  HideSelection := False;
  RowSelect := True;
  DoubleBuffered := True;

  // イベント割り当て
  OnExpanding := HandleNodeExpanding;
  OnCollapsing := HandleNodeCollapsing;
  OnExpanded := HandleNodeExpanded;
end;

destructor TPsdFileTreeView.Destroy;
begin
  // 破棄開始後は新しい UI 更新を受け付けない
  FDestroying := True;
  StopThread;

  FTempBmpFrom.Free;
  FTempBmpTo.Free;

  FExpands.Free;
  FImageLayers.Free;
  FImageStates.Free;

  inherited;
end;

procedure TPsdFileTreeView.FlushPendingMessages;
var
  Msg: TMsg;
begin
  if not HandleAllocated then
    Exit;

  // 破棄前に未処理のスレッド通知を捨てる
  while PeekMessage(Msg, Handle, WM_PSDTREE_ADDNODE, WM_PSDTREE_ADDNODE, PM_REMOVE) do
  begin
  end;
  while PeekMessage(Msg, Handle, WM_PSDTREE_FINISH, WM_PSDTREE_FINISH, PM_REMOVE) do
  begin
  end;
end;

procedure TPsdFileTreeView.StopThread;
begin
  if FThread = nil then
    Exit;

  // 破棄時は UI を回さずにスレッド停止を待つ
  FThread.Terminate;
  FThread.WaitFor;
  FreeAndNil(FThread);
  FThreading := False;
  FlushPendingMessages;
end;

procedure TPsdFileTreeView.ExpandLevel(Level: Integer);
var
  Node: TTreeNode;
begin
  if Level <= 0 then Exit;

  Node := Items.GetFirstNode;
  while Node <> nil do
  begin
    ExpandNodeLevel(Node, Level);
    Node := Node.GetNextSibling;
  end;
end;


procedure TPsdFileTreeView.ExpandNodeLevel(Node: TTreeNode; Level: Integer);
var
  Child: TTreeNode;
begin
  if (Node = nil) or (Level <= 0) then Exit;

  Node.Expand(False);  // ← 子生成トリガ

  Child := Node.getFirstChild;
  while Child <> nil do
  begin
    ExpandNodeLevel(Child, Level - 1);
    Child := Child.getNextSibling;
  end;
end;


procedure TPsdFileTreeView.InitStateImages;
var
  bmp: TBitmap;
begin
  if FImageStates = nil then
    Exit;

  FImageStates.Clear;

  bmp := TBitmap.Create;
  try
    // 0: 使わない or 空
    bmp.SetSize(FImageStates.Width, FImageStates.Height);
    bmp.Canvas.Brush.Color := A2SCTreeViewBackground;
    bmp.Canvas.Font.Color := A2SCTreeViewText;
    bmp.Canvas.FillRect(Rect(0, 0, bmp.Width, bmp.Height));
    FImageStates.AddMasked(bmp, A2SCTreeViewBackground);

    // 1: OFF ○
    bmp.SetSize(FImageStates.Width, FImageStates.Height);
    bmp.Canvas.Brush.Color := A2SCTreeViewBackground;
    bmp.Canvas.Font.Color := A2SCTreeViewText;
    bmp.Canvas.FillRect(Rect(0, 0, bmp.Width, bmp.Height));
    bmp.Canvas.Font.Name := 'MS UI Gothic';
    bmp.Canvas.Font.Height := -13;
    bmp.Canvas.TextOut(2, 2, '○');
    FImageStates.AddMasked(bmp, A2SCTreeViewBackground);

    // 2: ON ●
    bmp.SetSize(FImageStates.Width, FImageStates.Height);
    bmp.Canvas.Brush.Color := A2SCTreeViewBackground;
    bmp.Canvas.Font.Color := A2SCTreeViewText;
    bmp.Canvas.FillRect(Rect(0, 0, bmp.Width, bmp.Height));
    bmp.Canvas.Font.Name := 'MS UI Gothic';
    bmp.Canvas.Font.Height := -13;
    bmp.Canvas.TextOut(2, 2, '●');
    FImageStates.AddMasked(bmp, A2SCTreeViewBackground);
  finally
    bmp.Free;
  end;
end;

procedure TPsdFileTreeView.RefreshCheckStates;
var
  i: Integer;
  tn: TTreeNode;
  ts: TPsdFileTree;
begin
  for i := 0 to Items.Count - 1 do
  begin
    tn := Items[i];
    if (tn = nil) or (tn.Data = nil) then
      Continue;

    ts := TPsdFileTree(tn.Data);
    tn.StateIndex := Integer(ts.Visible) + 1;
  end;
end;

procedure TPsdFileTreeView.DoTreeClick;
begin
  if Assigned(FOnTreeClick) then  FOnTreeClick(Self);
end;

procedure TPsdFileTreeView.HandleNodeCollapsing(Sender: TObject;
  Node: TTreeNode; var AllowCollapse: Boolean);
begin
  // 折りたたみ直後のクリックを無効にするフラグ
  FExpanding := True;
end;

procedure TPsdFileTreeView.HandleNodeExpanded(Sender: TObject; Node: TTreeNode);
begin
  // 現状は特に処理なし
end;

procedure TPsdFileTreeView.HandleNodeExpanding(Sender: TObject;
  Node: TTreeNode; var AllowExpansion: Boolean);
var
  ts: TPsdFileTree;
  tss: TPsdFileTrees;
begin
  if FDestroying then
  begin
    // 破棄中の再展開開始を防ぐ
    AllowExpansion := False;
    Exit;
  end;

  FExpanding := True;

  // スレッド実行中なら何もしない
  if (FThread <> nil) and (not FThread.Finished) then
  begin
    Exit;
  end;

  if (Node = nil) or (Node.Data = nil) then
    Exit;

  ts := TPsdFileTree(Node.Data);
  tss := TPsdFileTrees(ts.Trees);
  if tss = nil then
    Exit;

  // すでに展開済みなら何もしない
  if FExpands.IsExpand(tss) then
  begin
    AllowExpansion := True;
    Exit;
  end;

  AllowExpansion := True;

  // 展開中であることを示すダミーノード追加（なくても良いが元実装に合わせる）
  Items.AddChildObject(Node, ts.Layer.Name, ts);

  FThreading := True;
  FThread := TPsdFileTreeViewThread.Create(Self, Node, FExpands, OnThreadFinished);
end;

procedure TPsdFileTreeView.HandleNodeMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Node: TTreeNode;
  ts: TPsdFileTree;
  tss: TPsdFileTrees;
  HitTests: THitTests;
begin
  Node := GetNodeAt(X, Y);
  if Node = nil then Exit;

  if Node.Data = nil then Exit;

  ts := TPsdFileTree(Node.Data);
  tss := TPsdFileTrees(ts.Trees);

  FSelectTree := ts;
  FSelectTrees := tss;

  // 展開／折りたたみ直後のクリックは無視
  if FExpanding then
  begin
    FExpanding := False;
    Exit;
  end;

  if Button <> mbLeft then Exit;
  HitTests := GetHitTestInfoAt(X, Y);
  if not (htOnStateIcon in HitTests) then Exit;

  // 状態アイコン（○●）クリック時だけ、そのノード単体を反転
  ts.SetVisibleLocalAndApplyRules(not ts.Visible);

  // 描画処理のイベントが重い場合でも、丸の反応だけは先に見せる
  Node.StateIndex := Integer(ts.Visible) + 1;
  Invalidate;
  Update;

  // イベント通知
  DoTreeClick;
end;

procedure TPsdFileTreeView.OnThreadFinished(Sender: TObject);
begin
  // スレッドから直接呼ばれるので軽い処理のみ
  FThreading := False;
end;

function TPsdFileTreeView.GetSelectTreeOwner: TPsdFileTree;
var
  ts: TPsdFileTree;
  i: Integer;
begin
  Result := nil;
  ts := FSelectTree;
  if ts = nil then
    Exit;

  i := ts.Owners.Count;
  if i = 0 then
    Exit;

  Result := TPsdFileTree(ts.Owners[i - 1]);
end;

function TPsdFileTreeView.IsThread: Boolean;
begin
  Result := False;
  if FThread = nil then
    Exit;

  Result := FThreading;
end;

procedure TPsdFileTreeView.ShowTree;
var
  i: Integer;
  ts: TPsdFileTree;
  tn: TTreeNode;
  dl: TPsdFileLayer;
  Msg: TMsg;
begin
  if FPsdImage = nil then Exit;

  {-----------------------------}
  { 1. TreeView ハンドルを強制生成 }
  {-----------------------------}
  if not HandleAllocated then HandleNeeded;

  {-----------------------------}
  { 2. 念のためハンドル再チェック }
  {-----------------------------}
  if not HandleAllocated then Exit;  // ← 安全装置（通常はここに来ない）

  {------------------------------------------------------------}
  { 3. 前回 ShowTree の残りを掃除して、まっさらな状態から作り直す }
  {------------------------------------------------------------}
  // 前回の非同期展開の残骸が新しいツリーに混ざらないよう、再構築前に必ず掃除する
  if FThread <> nil then
    StopThread;

  FThreading := False;
  FExpanding := False;
  FSelectTree := nil;
  FSelectTrees := nil;

  while PeekMessage(Msg, Handle, WM_PSDTREE_ADDNODE, WM_PSDTREE_ADDNODE, PM_REMOVE) do
  begin
  end;
  while PeekMessage(Msg, Handle, WM_PSDTREE_FINISH, WM_PSDTREE_FINISH, PM_REMOVE) do
  begin
  end;

  Items.BeginUpdate;
  try
    Items.Clear;
    FExpands.Clear;
    FImageLayers.Clear;
    FImageStates.Clear;

    InitStateImages;
    Images := FImageLayers;
    StateImages := FImageStates;

    // ルートノード
    for i := 0 to FPsdImage.Trees.Count - 1 do
    begin
      ts := FPsdImage.Trees[i];
      dl := ts.Layer;

      tn := Items.AddChildObject(nil, dl.Name, ts);
      ts.Node := tn;

      tn.StateIndex := Integer(ts.Visible) + 1;
      tn.HasChildren := ts.IsChildren;
    end;

    // 初期表示では子ノードを自動展開しない。
    // 展開時はメインスレッドでサムネイルを生成するため、未操作ノードまで前倒し生成すると負荷が大きい。
    // 子ノードとサムネイルは、ユーザーが実際に開いたノードだけ生成する。
    FExpanding := False;

  finally
    Items.EndUpdate;
  end;
end;


procedure TPsdFileTreeView.ShowTreeCheck;
begin
  RefreshCheckStates;
end;

procedure TPsdFileTreeView.WMPsdAddNode(var Msg: TMessage);
var
  ParentNode: TTreeNode;
  DelNode: TTreeNode;
  pTree: TPsdFileTree;
  NewNode: TTreeNode;
  Layer: TPsdFileLayer;
  bmpFrom, bmpTo: TBitmap;
  R: TRect;
begin
  if FDestroying or (csDestroying in ComponentState) then
    // 破棄開始後に届いた追加通知は無視する
    Exit;

  // ---------------------------------------------------
  // 削除命令
  // ---------------------------------------------------
  if Msg.LParam = 0 then
  begin
    DelNode := TTreeNode(Msg.WParam);
    if (DelNode <> nil) and (DelNode.TreeView = Self) then
      Items.Delete(DelNode);
    Exit;
  end;

  // ---------------------------------------------------
  // 追加命令
  // ---------------------------------------------------
  ParentNode := TTreeNode(Msg.WParam);
  pTree := TPsdFileTree(Msg.LParam);

  if (ParentNode = nil) or (pTree = nil) then
    Exit;

  Layer := pTree.Layer;

  // ---------------------------------------------------
  // ノード追加
  // ---------------------------------------------------
  NewNode := Items.AddChildObject(ParentNode, Layer.Name, pTree);
  pTree.Node := NewNode;

  NewNode.HasChildren := pTree.IsChildren;
  NewNode.StateIndex  := Integer(pTree.Visible) + 1;

  // ---------------------------------------------------
  // アイコン（レイヤーのサムネイル or ダミー）
  // ---------------------------------------------------
  if Images <> nil then
  begin
    bmpFrom := TBitmap.Create;
    bmpTo   := TBitmap.Create;
    try
      // レイヤー画像が取得できる場合
      if Layer.ImageToBitmap(bmpFrom) then
      begin
        bmpTo.SetSize(Images.Width, Images.Height);

        R := Rect(0, 0, bmpTo.Width, bmpTo.Height);
        RectToStreachRect(R, bmpFrom.Width, bmpFrom.Height);

        bmpTo.Canvas.Brush.Color := A2SCTreeViewBackground;
        bmpTo.Canvas.FillRect(Rect(0, 0, bmpTo.Width, bmpTo.Height));

        bmpTo.Canvas.StretchDraw(R, bmpFrom);
      end
      else
      begin
        bmpTo.SetSize(Images.Width, Images.Height);

        bmpTo.Canvas.Brush.Color := A2SCTreeViewBackground;
        bmpTo.Canvas.FillRect(Rect(0, 0, bmpTo.Width, bmpTo.Height));
      end;

      Images.Add(bmpTo, nil);
      NewNode.ImageIndex := Images.Count - 1;
      NewNode.SelectedIndex := NewNode.ImageIndex;

    finally
      bmpTo.Free;
      bmpFrom.Free;
    end;
  end;
end;



procedure TPsdFileTreeView.WMPsdFinish(var Msg: TMessage);
begin
  if FDestroying or (csDestroying in ComponentState) then
    // 破棄開始後に届いた完了通知は無視する
    Exit;

  FThreading := False;
  // 展開完了後にさらに自動展開すると、未操作ノードのサムネイル生成まで連鎖して重くなる。
  // ここでは追加展開せず、次の展開操作を待つ。
  FExpanding := False;
end;

procedure TPsdFileTreeView.WMLButtonDown(var Message: TWMLButtonDown);
var
  P : TPoint;
begin
  if FDestroying then
    // 破棄中のクリック再入を防ぐ
    Exit;

  inherited;
  // クライアント座標へ変換
  P.X := Message.XPos;
  P.Y := Message.YPos;
  //P := ScreenToClient(P);

  // 既存処理へ委譲
  HandleNodeMouseDown(
    Self,                 // Sender
    TMouseButton.mbLeft,            // Button
    [],                 // Shift（必要なら GetKeyShiftState 等）
    P.X,
    P.Y
  );
end;

end.

