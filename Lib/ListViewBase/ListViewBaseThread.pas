unit ListViewBaseThread;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  ListViewEdit,ListViewEx,Vcl.Menus,System.Generics.Collections,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ImgList,PsdImage,RTTIPersistent,ListViewBaseCache,ListViewBaseList,
  ThreadMessage,System.SyncObjs,BitmapList,PNGImage;

type
  TListViewBaseThreadSender = class(TThreadMessageSender)
  private
    FPsdFile   : TPsdImage;              // PSD画像データ本体（描画元）
    FImages    : TImageList;             // 結果を反映するイメージリスト（UI側）
    FListView  : TListView;              // 対象のTListView（UI側）
    FCaches    : TListViewBaseCacheList; // 描画結果のキャッシュ管理
    FBitmapList : TBitmapList;           // メイン側で前割り当てしたビットマップ一覧
  protected
    procedure Execute; override;          // スレッド本体（描画処理）
  public
  end;


type
  TListViewBaseThreadReceiver = class(TThreadMessageReceiver)
  private
    FPsdFile    : TPsdImage;              // PSD画像データ本体（共有参照）
    FImages     : TImageList;             // 描画後のビットマップを追加するImageList
    FListView   : TListView;              // 対象のTListView（ImageIndexを書き換える）
    FCaches     : TListViewBaseCacheList; // 描画キャッシュ管理
    FBitmapList : TBitmapList;            // スレッド用に前準備したBitmapリスト
    FBitmapIndex : Integer;               // 取り出すBitmapの現在位置
    FBusy        : Boolean;
  protected
    // メイン側処理（UI更新）
    procedure DoMessage(Index: Integer); override;
    procedure DoFinish(); override;
    // Sender生成（依存注入）
    function  DoCreate():TThreadMessageSender; override;
  public
    // Receiver生成（BitmapList生成）
    constructor Create; override;
    // Receiver破棄（Sender停止・解放）
    destructor Destroy; override;
    // 前準備＋スレッド開始
    procedure StartThread; override;
    // 外部設定：PSD
    property PsdFile   : TPsdImage read FPsdFile write FPsdFile;
    // 外部設定：ImageList
    property Images    : TImageList read FImages write FImages;
    // 外部設定：ListView
    property ListView  : TListView read FListView write FListView;
    // 外部設定：Cache
    property Caches    : TListViewBaseCacheList read FCaches write FCaches;
    // 外部設定：BitmapList
    property BitmapList : TBitmapList read FBitmapList write FBitmapList;
  end;




implementation


{ TListViewBaseThreadReceiver }

constructor TListViewBaseThreadReceiver.Create;
begin
  inherited;
  FBitmapList := TBitmapList.Create;
end;

destructor TListViewBaseThreadReceiver.Destroy;
begin
  if FSender<>nil then begin
    FSender.Terminate;
    FSender.WaitFor;
  end;
  //FSender.Free;
  FBitmapList.Free;
  inherited;
end;

function TListViewBaseThreadReceiver.DoCreate: TThreadMessageSender;
var
  ASender : TListViewBaseThreadSender;
begin
  ASender := TListViewBaseThreadSender.Create(Self);
  //ASender.FWidth := FWidth;
  //ASender.FHeight := FHeight;
  ASender.FListView := FListView;
  ASender.FPsdFile := FPsdFile;
  ASender.FImages := FImages;
  //ASender.FItems := FItems;
  ASender.FCaches := FCaches;
  ASender.FBitmapList := FBitmapList;
  Result := ASender;
end;

procedure TListViewBaseThreadReceiver.DoMessage(Index: Integer);
var
  i,j : Integer;
  dl : TListItem;
begin
  {
  FImages.Add(FBitmapList.Bitmaps(FBitmapIndex),nil);            // イメージリストに追加
  FListView.Items[Index].ImageIndex := FImages.Count-1;        // 追加したイメージ番号を指定
  FBitmapIndex := FBitmapIndex + 1;
  }
   {
  //ASender := TListViewBaseThreadSender.Create(Self);
  //for i := 0 to FBitmapList.Count-1 do begin
    FImages.Add(FBitmapList.Items(FBitmapIndex),nil);            // イメージリストに追加
    FListView.Items[Index].ImageIndex := FImages.Count-1;        // 追加したイメージ番号を指定
    FBitmapIndex := FBitmapIndex + 1;
  //end;
  }

  {
  bmp := TBitmap.Create;
  try
    bmp.SetSize(FWidth,FHeight);
    item := FItems[Index];
    id := Item.GetUDI;
    if not FCaches.GetCache(id,FWidth,FHeight,bmp) then begin
      Item.DoDraw(bmp,FPsdFile);
      FCaches.AddCache(id,FWidth,FHeight,bmp);
    end;
    FImages.Add(bmp,nil);                            // イメージリストに追加
    //FImages.Add(FBmpTo,nil);                            // イメージリストに追加
    FListView.Items[Index].ImageIndex := FImages.Count-1;          // 追加したイメージ番号を指定
  finally
    bmp.Free;
  end;
  }
  FSender.ResetAck();
end;

procedure TListViewBaseThreadReceiver.DoFinish;
var
  i,j : Integer;
  dl : TListItem;
begin
  i := 0;
  for j := 0 to FListView.Items.Count-1 do begin           // リスト数ループ
    dl := FListView.Items[j];                              // リストデータを取得
    if dl.ImageIndex<>-1 then Continue;                    // アイコン表示済みの場合処理しない
    FImages.Add(FBitmapList.Bitmaps(i),nil);            // イメージリストに追加
    FListView.Items[j].ImageIndex := FImages.Count-1;        // 追加したイメージ番号を指定
    Inc(i);
  end;
  FBusy := False;

  Exit;
end;



procedure TListViewBaseThreadReceiver.StartThread;
var
  j: Integer;
  id : string;
  dl : TListItem;
  bmp : TBitmap;
  Item : TListViewBaseItem;
  f : Boolean;
begin
  if FBusy then Exit;

  f := False;
  FBitmapIndex := 0;
  FBitmapList.Clear;                                       // あらかじめビットマップリストを生成
  for j := 0 to FListView.Items.Count-1 do begin           // リスト数ループ
    dl := FListView.Items[j];                              // リストデータを取得
    Item := TListViewBaseItem(dl.Data);
    id := Item.GetUDI;

    if dl.ImageIndex<>-1 then Continue;                    // アイコン表示済みの場合処理しない
    bmp := TBitmap.Create;                                 // ビットマップ生成
    bmp.SetSize(FImages.Width,FImages.Height);             // ビットマップサイズ割り当て
    FBitmapList.Add(bmp);                                  // ビットマップリストに追加

    if FCaches.GetCache(id,Images.Width,Images.Height,bmp) then begin
      FImages.Add(bmp,nil);            // イメージリストに追加
      FListView.Items[j].ImageIndex := Images.Count-1;        // 追加したイメージ番号を指定
      Continue;
    end
    else begin
        f := true;
    end;
  end;
  if f then  begin                                         // 画像読み込みが必要な場合
    FBusy := True;
    inherited;                                             // スレッド実行
  end;

end;

procedure TListViewBaseThreadSender.Execute;
var
  i,j: Integer;
  id : string;
  dl : TListItem;
  Item : TListViewBaseItem;
  bmp : TBitmap;
  png  : TPngImage;
  psd : TPSDImage;
begin
  i := 0;
  for j := 0 to FListView.Items.Count-1 do begin              // 表情の数だけループ
    if Terminated then Exit;
    dl := FListView.Items[j];
    if dl.ImageIndex<>-1 then Continue;
    Item := TListViewBaseItem(dl.Data);
    bmp := FBitmapList.Bitmaps(i);
    png := FBitmapList.PNGs(i);
    psd := FBitmapList.PSDg(i);
    //bmp := TBitmap.Create;
    //bmp.SetSize(FWidth,FHeight);
    //item := FItems[j];
    id := Item.GetUDI;
    if not FCaches.GetCache(id,FImages.Width,FImages.Height,bmp) then begin
      //Item.DoDraw(bmp,psd);
      Item.DoDraw(bmp,FPsdFile);
      Sleep(500);
      //FCaches.AddCache(id,FImages.Width,FImages.Height,bmp,png);
      Sleep(500);
    end;
    //FBitmapList.Add(bmp);
    while not SendMessageToReceiver(j) do  begin // ここで送信成功まで待つ
      if Terminated then Exit;
      Sleep(10);                                  // ←メインスレッドに処理を渡す
    end;
    Inc(i);
    Sleep(100);                                  // ←メインスレッドに処理を渡す
  end;
  while not SendFinishToReceiver() do  begin // ここで送信成功まで待つ
    if Terminated then Exit;
    Sleep(10);                                  // ←メインスレッドに処理を渡す
  end;
end;



end.
