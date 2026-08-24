unit ListViewThumbnail;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Winapi.Windows, Winapi.Messages, Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics, Vcl.ImgList,
  ListViewEx;

const
  WM_THUMBNAIL_DONE = WM_USER + $500;   // サムネイル1件の描画完了通知（スレッド側→UI側）
  WM_FINAL_ADJUST   = WM_USER + 900;    // リサイズ後の最終レイアウト調整用
  WM_ADJUST_EDITBOX = WM_USER + 901;    // サムネイル分だけ編集ボックスを右へ寄せる

type
  TListViewThumbnail = class;
  TListViewThumbnailThread = class;

  // イベント: 表示用テキスト取得
  TListViewThumbnailGetDisplayTextEvent =
    procedure(Sender: TObject; Index: Integer; Column: Integer; var Text: string) of object;

  // イベント: 表示用ビットマップ取得
  TListViewThumbnailGetDisplayBitmapEvent =
    procedure(Sender: TObject; Index: Integer; Bitmap: TBitmap) of object;

  //===============================================================
  // ListView 拡張（サムネイル表示 + OwnerDraw）
  //===============================================================
  TListViewThumbnail = class(TListViewEx)
  private
    FThread       : TListViewThumbnailThread; // サムネイル準備を進めるバックグラウンドスレッド
    FLargeIcons   : TImageList;               // 非レポート表示用のダミー ImageList（描画自体には使わない）
    FBitmap       : TBitmap;                  // サムネイル描画用のワークビットマップ
    FDrawIndex    : Integer;                  // 現在描画対象になっているアイテムのインデックス
    FDrawComplete : Boolean;                  // 1件描画完了をスレッドへ通知するためのフラグ
    FDrawThmbnail : Boolean;                  // True のときだけサムネイル描画を行う
    FThumbReady   : TBits;                    // ImageIndex の代わりに使う「準備済み」管理ビット列
    //FThumbnailVisible : Boolean;            // サムネイルを実際に描画するかどうか（行表示とは独立）

    FOnGetDisplayText   : TListViewThumbnailGetDisplayTextEvent;   // 表示テキスト取得イベント
    FOnGetDisplayBitmap : TListViewThumbnailGetDisplayBitmapEvent; // 表示ビットマップ取得イベント
    FThreadGeneration   : NativeInt;          // 古いスレッド通知を無効化するための世代番号

    // サムネイル準備スレッドを停止する
    procedure StopThread;
    // サムネイル準備スレッドを開始する
    procedure StartThread;
    // 停止後に残ったサムネイル通知を破棄する
    procedure FlushThumbnailMessages;
    // リサイズ後に列幅を最終調整するための遅延メッセージ処理
    procedure WMFinalAdjust(var Msg: TMessage); message WM_FINAL_ADJUST;
    // ラベル編集ボックス位置を遅延補正する
    procedure WMAdjustEditBox(var Msg: TMessage); message WM_ADJUST_EDITBOX;
    // 文字入力でWindows側が再配置した後も編集ボックス位置を補正し直す
    procedure WMCommand(var Msg: TWMCommand); message WM_COMMAND;
    // サムネイル1件分の準備完了を受け取るメッセージ処理
    procedure WmThumbnailDone(var Msg: TMessage); message WM_THUMBNAIL_DONE;
    // サムネイル用ビットマップを ListView の Canvas へ描画する
    procedure DrawThumbnailToCanvas(ACanvas: TCanvas; const ItemRect: TRect; ABmp: TBitmap);
    // 行背景（偶数/奇数・選択状態）を描画する
    procedure DrawItemBackground(Canvas: TCanvas; Item: TListItem; rBackground: TRect; State: TOwnerDrawState);
    // キャプションをサムネイルの右側へ描画する
    procedure DrawCaption(Item: TListItem; r: TRect; State: TOwnerDrawState);
    // 非選択時にサムネイルを少し暗く見せるための合成処理（Bitmap に対して行う）
    //procedure DrawThumbnailDimOverlay(ABmp: TBitmap; State: TOwnerDrawState);
    // Selected row overlay
    procedure DrawSelectedOverlay(Canvas: TCanvas; const r: TRect; State: TOwnerDrawState);
    // サムネイル準備済みフラグ配列を初期化する
    procedure ThumbReadyInit(Count: Integer);
    // 指定インデックスの準備済み状態を設定する
    procedure ThumbReadySet(Index: Integer; Value: Boolean);
    // 指定インデックスの準備済み状態を取得する
    function ThumbReadyGet(Index: Integer): Boolean;
    // レポート表示以外で使う ImageList を更新する
    procedure UpdateLargeIcon(Index: Integer; ABmp: TBitmap);
  protected
    // OwnerDraw による1行分の描画処理
    procedure DrawItem(Item: TListItem; r: TRect; State: TOwnerDrawState); override;
    // キャプション編集開始時に編集ボックス位置を補正する
    procedure DoCaptionEditBegin(Item: TListItem; var AllowEdit: Boolean); override;
    // 表示用テキスト取得（イベントラッパ）
    procedure DoGetDisplayText(Index: Integer; Column: Integer; var Text: string); virtual;
    // 表示用ビットマップ取得（イベントラッパ）
    procedure DoGetDisplayBitmap(Index: Integer; Bitmap: TBitmap); virtual;
    // リサイズ時の処理（レイアウト再調整トリガ）
    procedure Resize; override;
    procedure CreateWnd; override;
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
    // リスト更新前の準備処理
    procedure ShowBegin(StartIndex: Integer = -1);
    // リストへ1件追加する
    procedure ShowItem(const Caption: string; Index: Integer = -1);
    // リスト更新後の後処理
    procedure ShowEnd;
    // 指定アイテムのみ再描画対象にする
    procedure ShowItemRefresh(Index: Integer);
    // 指定インデックスからサムネイル生成を進める
    procedure RequestThumbnail(Index: Integer = 0);
  public
    // コンストラクタ
    constructor Create(AOwner: TComponent); override;
    // デストラクタ
    destructor Destroy; override;
    procedure Clear; override;
    // 全サムネイルを読み直す
    procedure Refresh;
    // サムネイル表示サイズを設定する
    procedure SetThumbnailSize(AStyle : TViewStyle;AHeight  : Integer;AWidth : Integer;AThumbnailVisible : Boolean);
    // 指定インデックスのサムネイルだけ再生成する
    procedure ReLoadThumbnail(Index: Integer);
    property OnGetDisplayText   : TListViewThumbnailGetDisplayTextEvent read FOnGetDisplayText write FOnGetDisplayText;
    property OnGetDisplayBitmap : TListViewThumbnailGetDisplayBitmapEvent read FOnGetDisplayBitmap write FOnGetDisplayBitmap;
  end;

  //===============================================================
  // サムネイル準備用スレッド
  //===============================================================
  TListViewThumbnailThread = class(TThread)
  private
    FOwner     : TListViewThumbnail; // 処理対象の ListView 本体
    FNextIndex : Integer;            // 次に処理するサムネイルインデックス
    FGeneration: NativeInt;
  protected
    // スレッド本体（サムネイル準備ループ）
    procedure Execute; override;
  public
    // コンストラクタ
    constructor Create(AOwner: TListViewThumbnail);
    // 次に処理するインデックスを設定する
    procedure SetNextIndex(AIndex: Integer);
  end;


implementation

uses Math,AviUtl2StyleColors,Winapi.CommCtrl;

{=================================================================
  TListViewThumbnail
=================================================================}

constructor TListViewThumbnail.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  DoubleBuffered := True;
  OwnerDraw := True;
  HintsEnabled := False;
  Color := clBlack;

  FDrawThmbnail := False;

  // ImageList（ダミー: 非レポート表示用）
  FLargeIcons := TImageList.Create(Self);
  FLargeIcons.Width  := 96;
  FLargeIcons.Height := 96;
  LargeImages := nil;
  SmallImages := nil;

  // 描画用ビットマップ（固定サイズ）
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf32bit;
  FBitmap.SetSize(96, 96);

  // 準備済み管理（ビット列）
  FThumbReady := TBits.Create;

  FThread := nil;
  FDrawIndex := -1;
  FDrawComplete := False;
  FThreadGeneration := 0;
  Color := A2SCListViewAltBackground;
end;

procedure TListViewThumbnail.CreateWnd;
begin
  inherited;
  ListView_SetExtendedListViewStyleEx(Handle, LVS_EX_DOUBLEBUFFER, LVS_EX_DOUBLEBUFFER);
  ShowScrollBar(Handle, SB_HORZ, False);
end;

destructor TListViewThumbnail.Destroy;
begin
  StopThread;
  FLargeIcons.Free;
  FBitmap.Free;
  FThumbReady.Free;
  inherited;
end;

procedure TListViewThumbnail.Clear;
begin
  ShowBegin;
  inherited;
  ThumbReadyInit(0);
  FDrawIndex := -1;
  FDrawComplete := True;
end;

procedure TListViewThumbnail.ThumbReadyInit(Count: Integer);
var
  i: Integer;
begin
  if FThumbReady = nil then Exit;

  FThumbReady.Size := Count;

  for i := 0 to Count - 1 do
    FThumbReady[i] := False;
end;

procedure TListViewThumbnail.ThumbReadySet(Index: Integer; Value: Boolean);
begin
  if (FThumbReady = nil) then Exit;
  if (Index < 0) then Exit;
  if (Index >= FThumbReady.Size) then FThumbReady.Size := Index + 1;
  FThumbReady[Index] := Value;
end;

function TListViewThumbnail.ThumbReadyGet(Index: Integer): Boolean;
begin
  Result := False;
  if (FThumbReady = nil) then Exit;
  if (Index < 0) or (Index >= FThumbReady.Size) then Exit;
  Result := FThumbReady[Index];
end;

{-----------------------------------------------------------------
  スレッド停止
-----------------------------------------------------------------}
procedure TListViewThumbnail.StopThread;
begin
  Inc(FThreadGeneration);
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  FlushThumbnailMessages;
  FDrawComplete := True;
end;

{-----------------------------------------------------------------
  スレッド開始
-----------------------------------------------------------------}
procedure TListViewThumbnail.StartThread;
begin
  StopThread;
  FThread := TListViewThumbnailThread.Create(Self);
end;

procedure TListViewThumbnail.FlushThumbnailMessages;
var
  Msg: TMsg;
begin
  if HandleAllocated then
    while PeekMessage(Msg, Handle, WM_THUMBNAIL_DONE, WM_THUMBNAIL_DONE, PM_REMOVE) do
    begin
    end;
end;

{-----------------------------------------------------------------
  サムネイル要求
-----------------------------------------------------------------}
procedure TListViewThumbnail.RequestThumbnail(Index: Integer=0);
begin
  if not Assigned(FThread) then Exit;
  FThread.SetNextIndex(Index);
end;

procedure TListViewThumbnail.Resize;
begin
  inherited;
  PostMessage(Handle, WM_FINAL_ADJUST, 0, 0);
  ShowScrollBar(Handle, SB_HORZ, False);
end;

procedure TListViewThumbnail.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  // Hint の表示/非表示などで露出した領域は OS/VCL の背景消去に任せる。
  // ここを握りつぶすと、再描画されなかった領域に残像が出やすい。
  inherited;
end;

const
  LVM_FIRST   = $1000;
  LVM_ARRANGE = LVM_FIRST + 22;

  LVA_DEFAULT = 0;

procedure TListViewThumbnail.SetThumbnailSize(AStyle : TViewStyle;AHeight  : Integer;AWidth : Integer;AThumbnailVisible : Boolean);
var
  i: Integer;
  Scale : Double;
begin
  LargeImages       := nil;
  SmallImages       := nil;
  FDrawThmbnail     := AThumbnailVisible;

  if FLargeIcons <> nil then
  begin
    FLargeIcons.Clear;
    FLargeIcons.Width  := AWidth;
    FLargeIcons.Height := AHeight;
  end;

  ViewStyle := AStyle;
  Perform(LVM_ARRANGE, LVA_DEFAULT, 0);

  if (AWidth > 0) and (AHeight > 0) then
  begin

    // 高解像度描画用（今は倍率を持たせたまま使う）
    //FBitmap.SetSize(AWidth*4, AHeight*4);
    if ViewStyle = vsReport then begin
      Scale := CurrentPPI / 96 * 2;   // 必要なら GetDpiForWindow(Handle) / 96
      FBitmap.SetSize(Round(AWidth  * Scale),Round(AHeight * Scale));

      // レポート表示の行高は明示的に締めて、横長サムネイル幅に引きずられないようにする。
      ItemHeight := AHeight + 4;
      SetImageSizeWH(1, AHeight);
      LargeImages := nil;
      SmallImages := Images;
    end
    else begin
      FBitmap.SetSize(AWidth,AHeight);

      // ダミー ImageList を割り当てる（非レポート表示用）
      LargeImages := FLargeIcons;
      SmallImages := FLargeIcons;
    end;
    FBitmap.PixelFormat := pf32bit;

    // ImageIndex は使わないので常に -1
    for i := 0 to Items.Count - 1 do
      Items[i].ImageIndex := -1;

    // 準備済みフラグを初期化
    ThumbReadyInit(Items.Count);
  end;

  Invalidate;

  if not FDrawThmbnail then Exit;

  if Items.Count > 0 then
  begin
    StartThread;
    RequestThumbnail(0);
  end;
end;

procedure TListViewThumbnail.Refresh;
var
  i : Integer;
begin
  ShowBegin(0);
  for i := 0 to Items.Count-1 do
  begin
    Items[i].ImageIndex := -1;
    ThumbReadySet(i, False);
  end;

  // ImageList はダミー用途なので Images.Clear は不要
  // Images.Clear;

  ShowEnd();
  inherited;
end;

procedure TListViewThumbnail.ReLoadThumbnail(Index: Integer);
begin
  ShowBegin(Index);
  Items[Index].ImageIndex := -1;
  ThumbReadySet(Index, False);
  ShowEnd();
end;

procedure TListViewThumbnail.ShowBegin(StartIndex : Integer = -1);
begin
  ShowColumnHeaders := False;
  StopThread;

  if (StartIndex = -1) and (FLargeIcons <> nil) then
    FLargeIcons.Clear;

  if StartIndex = -1 then
    FDrawIndex := Items.Count
  else
    FDrawIndex := StartIndex;
end;

procedure TListViewThumbnail.ShowEnd;
begin
  Columns.Clear;
  Columns.Add();
  AutoAdjustColumnWidth(0);

  Items.BeginUpdate;
  try
    if not FDrawThmbnail then Exit;

    if FDrawIndex < Items.Count then
    begin
      StartThread;
      RequestThumbnail(FDrawIndex);
    end;
  finally
    Items.EndUpdate();
  end;
end;

procedure TListViewThumbnail.ShowItem(const Caption: string;Index : Integer = -1);
var
  i: Integer;
  txt: string;
  Item: TListItem;
begin
  if Index = -1 then Item := Items.Add()
                else Item := Insert(Index);

  Item.ImageIndex := -1;
  ThumbReadySet(Item.Index, False);
  txt := ChangeFileExt(ExtractFileName(Caption),'');
  DoGetDisplayText(FDrawIndex,0,txt);
  Item.Caption := txt;

  for i := 1 to Columns.Count - 1 do
  begin
    txt := '';
    DoGetDisplayText(FDrawIndex,i,txt);
    Item.SubItems.Add(txt);
  end;
end;

procedure TListViewThumbnail.ShowItemRefresh(Index: Integer);
var
  dl : TListItem;
begin
  if Index = -1 then Exit;
  dl := Items[Index];
  dl.ImageIndex := -1;
  ThumbReadySet(Index, False);
  ShowBegin(0);
  ShowEnd();
end;

const
  LVM_REDRAWITEMS = LVM_FIRST + 21;

procedure TListViewThumbnail.WMFinalAdjust(var Msg: TMessage);
begin
  AutoAdjustColumnWidth(0);
  ShowScrollBar(Handle, SB_HORZ, False);
end;

procedure TListViewThumbnail.WMAdjustEditBox(var Msg: TMessage);
var
  Item: TListItem;
  EditHandle: HWND;
  ItemRect: TRect;
  EditRect: TRect;
  ThumbWidth: Integer;
  EditLeft: Integer;
  EditWidth: Integer;
begin
  if not FDrawThmbnail then Exit;
  if ViewStyle <> vsReport then Exit;
  if (Msg.WParam < 0) or (Msg.WParam >= Items.Count) then Exit;

  // ラベル編集エディットをサムネイル右側へ寄せてWindows風の見た目を保つ。
  EditHandle := ListView_GetEditControl(Handle);
  if EditHandle = 0 then Exit;

  Item := Items[Msg.WParam];
  if Item = nil then Exit;

  ItemRect := Item.DisplayRect(drBounds);
  if IsRectEmpty(ItemRect) then Exit;

  GetWindowRect(EditHandle, EditRect);
  MapWindowPoints(HWND_DESKTOP, Handle, EditRect, 2);

  ThumbWidth := ItemRect.Height;
  if (FLargeIcons <> nil) and (FLargeIcons.Width > 0) then
    ThumbWidth := FLargeIcons.Width;

  EditLeft := ItemRect.Left + ThumbWidth + 8;
  EditWidth := ItemRect.Right - EditLeft - 4;
  if EditWidth < 24 then
    EditWidth := 24;

  SetWindowPos(
    EditHandle,
    0,
    EditLeft,
    EditRect.Top,
    EditWidth,
    EditRect.Bottom - EditRect.Top,
    SWP_NOZORDER or SWP_NOACTIVATE
  );
end;

procedure TListViewThumbnail.WMCommand(var Msg: TWMCommand);
var
  EditHandle: HWND;
begin
  inherited;

  if not FDrawThmbnail then Exit;
  if ViewStyle <> vsReport then Exit;
  if ItemIndex < 0 then Exit;

  EditHandle := ListView_GetEditControl(Handle);
  if EditHandle = 0 then Exit;
  if HWND(Msg.Ctl) <> EditHandle then Exit;

  case Msg.NotifyCode of
    EN_CHANGE,
    EN_UPDATE:
      // 1文字入力後にエディットが左へ戻るので、その都度位置補正を掛け直す。
      PostMessage(Handle, WM_ADJUST_EDITBOX, ItemIndex, 0);
  end;
end;

procedure TListViewThumbnail.WmThumbnailDone(var Msg: TMessage);
var
  idx: Integer;
  topIdx,perPage,lastIdx: Integer;
begin
  if NativeInt(Msg.LParam) <> FThreadGeneration then
  begin
    FDrawComplete := True;
    Exit;
  end;

  idx := Msg.WParam;

  if (idx < 0) or (idx >= Items.Count) then
  begin
    FDrawComplete := True;
    Exit;
  end;

  FDrawIndex := idx;

  if ViewStyle <> vsReport then begin
    DoGetDisplayBitmap(FDrawIndex,FBitmap);
    UpdateLargeIcon(idx, FBitmap);
  end
  else begin
    // レポート表示では ImageList を使わず準備済みフラグだけ立てる
    ThumbReadySet(idx, True);
  end;
  // 表示中の範囲だけ再描画して負荷を抑える
  if ViewStyle = vsReport then
  begin
    if Assigned(TopItem) then
      topIdx := TopItem.Index
    else
      topIdx := 0;

    perPage := ListView_GetCountPerPage(Handle);
    if perPage < 1 then perPage := 1;
    lastIdx := topIdx + perPage;

    if (idx >= topIdx) and (idx <= lastIdx) then
      Perform(LVM_REDRAWITEMS, idx, idx);
  end
  else
    Perform(LVM_REDRAWITEMS, idx, idx);

  FDrawComplete := True;
end;

procedure TListViewThumbnail.UpdateLargeIcon(Index: Integer; ABmp: TBitmap);
var
  PadBitmap: TBitmap;
begin
  if (FLargeIcons = nil) or (ABmp = nil) then Exit;
  if Index < 0 then Exit;

  PadBitmap := TBitmap.Create;
  try
    PadBitmap.PixelFormat := ABmp.PixelFormat;
    PadBitmap.SetSize(FLargeIcons.Width, FLargeIcons.Height);
    PadBitmap.Canvas.Brush.Style := bsSolid;
    PadBitmap.Canvas.Brush.Color := Color;
    PadBitmap.Canvas.FillRect(Rect(0, 0, PadBitmap.Width, PadBitmap.Height));

    while FLargeIcons.Count < Index do
      FLargeIcons.Add(PadBitmap, nil);

    if FLargeIcons.Count = Index then
      FLargeIcons.Add(ABmp, nil)
    else
      FLargeIcons.Replace(Index, ABmp, nil);
  finally
    PadBitmap.Free;
  end;

  ThumbReadySet(Index, True);
  Items[Index].ImageIndex := Index;
end;

procedure TListViewThumbnail.DoGetDisplayBitmap(Index: Integer;Bitmap: TBitmap);
begin
  if Assigned(FOnGetDisplayBitmap) then FOnGetDisplayBitmap(Self, Index, Bitmap);
end;

procedure TListViewThumbnail.DoCaptionEditBegin(Item: TListItem; var AllowEdit: Boolean);
begin
  inherited;
  if not AllowEdit then Exit;
  if not FDrawThmbnail then Exit;
  if ViewStyle <> vsReport then Exit;
  if Item = nil then Exit;
  // BeginLabelEdit直後は位置補正が早すぎるため、1テンポ遅らせて補正する。
  PostMessage(Handle, WM_ADJUST_EDITBOX, Item.Index, 0);
end;

procedure TListViewThumbnail.DoGetDisplayText(Index, Column: Integer;  var Text: string);
begin
  if Assigned(FOnGetDisplayText) then FOnGetDisplayText(Self, Index, Column, Text);
end;

procedure TListViewThumbnail.DrawCaption(
  Item: TListItem; r: TRect; State: TOwnerDrawState);
var
  txt : string;
  RText : TRect;
  ThumbWidth: Integer;
begin
  txt := Item.Caption;

  DoGetDisplayText(Item.Index, 0, txt);

  // テキスト領域をサムネイル右側へずらす
  RText := r;
  ThumbWidth := r.Height;
  if (FLargeIcons <> nil) and (FLargeIcons.Width > 0) then
    ThumbWidth := FLargeIcons.Width;

  if FDrawThmbnail then Inc(RText.Left, ThumbWidth + 8) // サムネイル分の左余白
                   else Inc(RText.Left, r.Height + 8);  // アイコン相当の余白

  // 背景はすでに塗っているので透過描画にする
  Canvas.Brush.Style := bsClear;

  DrawText(Canvas.Handle,PChar(txt),-1,RText,
    DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS
  );
end;


procedure TListViewThumbnail.DrawItem(Item: TListItem; r: TRect; State: TOwnerDrawState);
begin
  if FDrawThmbnail then begin
    // 背景を先に全面描画
    DrawItemBackground(Canvas, Item, r, State);

    if ThumbReadyGet(Item.Index) then
    begin
      // サムネイル描画用ビットマップを更新
      FBitmap.Canvas.Brush.Style := bsSolid;
      FBitmap.Canvas.Brush.Color := A2SCListViewAltBackground;
      FBitmap.Canvas.FillRect(Rect(0, 0, FBitmap.Width, FBitmap.Height));
      DoGetDisplayBitmap(Item.Index, FBitmap);

      // 必要なら非選択時の暗色オーバーレイを重ねる
      //DrawThumbnailDimOverlay(FBitmap, State);
      DrawThumbnailToCanvas(Canvas, r, FBitmap);
    end;

    DrawSelectedOverlay(Canvas, r, State);
    DrawCaption(Item,r,State);
  end
  else begin
    // 背景を先に全面描画
    DrawItemBackground(Canvas, Item, r, State);
    DrawSelectedOverlay(Canvas, r, State);
    DrawCaption(Item,r,State);

  end;
end;

const
  COLOR_CURSOL = clNavy;

procedure TListViewThumbnail.DrawItemBackground(Canvas: TCanvas;
  Item: TListItem; rBackground: TRect; State: TOwnerDrawState);
var
  cF, cB: TColor;
begin
  // 偶数行 / 奇数行
  if (Item.Index mod 2) = 0 then
    cB := A2SCListViewBackground
  else
    cB := A2SCListViewAltBackground;

  cF := A2SCListViewText;

  // 選択 / フォーカス
  if (odFocused in State) or (odSelected in State) then
  begin
    cF := A2SCListViewSelectionText;
  end;

  Canvas.Brush.Color := cB;
  Canvas.Font.Color  := cF;
  Canvas.FillRect(rBackground);
end;

{
procedure TListViewThumbnail.DrawThumbnailDimOverlay(ABmp: TBitmap;State: TOwnerDrawState);
var
  Overlay : TBitmap;
  BF      : BLENDFUNCTION;
begin
  if (ABmp = nil) or ABmp.Empty then Exit;

  if (odSelected in State) or (odFocused in State) then
    Exit;

  Overlay := TBitmap.Create;
  try
    Overlay.PixelFormat := pf32bit;
    Overlay.SetSize(ABmp.Width, ABmp.Height);

    // 全面塗りつぶし
    Overlay.Canvas.Brush.Style := bsSolid;
    Overlay.Canvas.Brush.Color := A2SCListViewAltBackground;
    Overlay.Canvas.FillRect(Rect(0, 0, Overlay.Width, Overlay.Height));

    // 半透明合成の設定
    BF.BlendOp             := AC_SRC_OVER;
    BF.BlendFlags          := 0;
    BF.SourceConstantAlpha := 80; // 少し暗くする
    BF.AlphaFormat         := 0;

    // 上から半透明で重ねる
    AlphaBlend(
      ABmp.Canvas.Handle,
      0, 0, ABmp.Width, ABmp.Height,
      Overlay.Canvas.Handle,
      0, 0, Overlay.Width, Overlay.Height,
      BF
    );
  finally
    Overlay.Free;
  end;
end;
}

procedure TListViewThumbnail.DrawSelectedOverlay(Canvas: TCanvas;
  const r: TRect; State: TOwnerDrawState);
var
  Overlay: TBitmap;
  BF: BLENDFUNCTION;
  DrawRect: TRect;
begin
  if not ((odSelected in State) or (odFocused in State)) then Exit;
  if (r.Right <= r.Left) or (r.Bottom <= r.Top) then Exit;

  Overlay := TBitmap.Create;
  try
    Overlay.PixelFormat := pf32bit;
    Overlay.SetSize(r.Right - r.Left, r.Bottom - r.Top);
    Overlay.Canvas.Brush.Style := bsSolid;
    Overlay.Canvas.Brush.Color := RGB(70, 120, 220);
    Overlay.Canvas.FillRect(Rect(0, 0, Overlay.Width, Overlay.Height));

    BF.BlendOp             := AC_SRC_OVER;
    BF.BlendFlags          := 0;
    BF.SourceConstantAlpha := 72;
    BF.AlphaFormat         := 0;

    AlphaBlend(
      Canvas.Handle,
      r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top,
      Overlay.Canvas.Handle,
      0, 0, Overlay.Width, Overlay.Height,
      BF
    );
  finally
    Overlay.Free;
  end;

  DrawRect := r;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := RGB(110, 160, 255);
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(DrawRect);
end;

procedure TListViewThumbnail.DrawThumbnailToCanvas(ACanvas: TCanvas;
  const ItemRect: TRect; ABmp: TBitmap);
var
  ThumbRect : TRect;
  S         : Double;
  DW, DH    : Integer;
  BoxW, BoxH: Integer;
  X, Y      : Integer;
  OldMode   : Integer;
begin
  if (ABmp = nil) or ABmp.Empty then Exit;

  ThumbRect := ItemRect;
  ThumbRect.Left  := ItemRect.Left + 4;
  BoxW := ItemRect.Height;
  BoxH := ItemRect.Height;
  if FLargeIcons <> nil then
  begin
    if FLargeIcons.Width > 0 then
      BoxW := FLargeIcons.Width;
    if FLargeIcons.Height > 0 then
      BoxH := FLargeIcons.Height;
  end;
  ThumbRect.Right := ThumbRect.Left + BoxW;
  ThumbRect.Top := ItemRect.Top + Max(0, (ItemRect.Height - BoxH) div 2);
  ThumbRect.Bottom := ThumbRect.Top + BoxH;

  S  := Min(
          (ThumbRect.Width  / ABmp.Width),
          (ThumbRect.Height / ABmp.Height)
        );
  DW := Round(ABmp.Width  * S);
  DH := Round(ABmp.Height * S);

  X := ThumbRect.Left + Max(0, (ThumbRect.Width  - DW) div 2);
  Y := ThumbRect.Top  + Max(0, (ThumbRect.Height - DH) div 2);
  ThumbRect := Rect(X, Y, X + DW, Y + DH);

  OldMode := SetStretchBltMode(ACanvas.Handle, HALFTONE);
  SetBrushOrgEx(ACanvas.Handle, 0, 0, nil);
  try
    ACanvas.StretchDraw(ThumbRect, ABmp);
  finally
    SetStretchBltMode(ACanvas.Handle, OldMode);
  end;
end;

{=================================================================
  TListViewThumbnailThread
=================================================================}

constructor TListViewThumbnailThread.Create(AOwner: TListViewThumbnail);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FNextIndex := -1;
  FGeneration := AOwner.FThreadGeneration;
end;

procedure TListViewThumbnailThread.SetNextIndex(AIndex: Integer);
begin
  FNextIndex := AIndex;
end;

procedure TListViewThumbnailThread.Execute;
var
  idx: Integer;
begin
  while not Terminated do
  begin
    if FNextIndex < 0 then
    begin
      Sleep(10);
      Continue;
    end;

    idx := FNextIndex;

    if (idx >= 0) and (idx < FOwner.Items.Count) then
    begin
      // ImageIndex ではなくフラグで準備済み判定する
      if FOwner.ThumbReadyGet(idx) then
      begin
        Inc(idx);
        if idx >= FOwner.Items.Count then Exit;
        FNextIndex := idx;
        Continue;
      end;

      FOwner.FDrawComplete := False;
      PostMessage(FOwner.Handle, WM_THUMBNAIL_DONE, idx, LPARAM(FGeneration));

      while (not Terminated) and (not FOwner.FDrawComplete) do
        Sleep(1);

      Sleep(15);

      Inc(idx);
      if idx >= FOwner.Items.Count then Exit;

      FNextIndex := idx;
    end;
  end;
end;

end.




