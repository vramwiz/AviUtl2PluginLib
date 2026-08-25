unit DressFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,Vcl.ComCtrls,
  ProjectDataChara,ListViewEdit,DataChara,
  DragAndDropV,PsdFile,ListViewEx,DataDress,AnmEdit3CharaData, Vcl.Menus,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ImgList;


type
  TFrameDressThread = class(TThread)
  private
    { Private 宣言 }
    FPsdFile   : TPsdFile;
    FBmpTo     : TBitmap;
    FWidth     : Integer;
    FHeight    : Integer;
    FImages    : TImageList;
    FIndex     : Integer;
    FlvPsd     : TListView;
    FChara     : TDataCharsItem;
    FDress     : TDataDressItems;
    procedure ExecutSub();
  protected
    procedure Execute();override;
  public
    { Public 宣言 }
    constructor Create(lv : TListView;Images: TImageList;dc : TDataCharsItem;dds : TDataDressItems;aPsdFile : TPsdFile);
    destructor Destroy;override;

  end;


type
  TFrameDress = class(TFrame)
    MenuPop: TPopupMenu;
    MenuConfig: TMenuItem;
    MenuReName: TMenuItem;
    MenuUp: TMenuItem;
    MenuDown: TMenuItem;
    N1: TMenuItem;
    MenuAdd: TMenuItem;
    MenuCopy: TMenuItem;
    MenuDel: TMenuItem;
    N4: TMenuItem;
    MenuAviUtlRec: TMenuItem;
    MenuAviUtlSend: TMenuItem;
    MenuSendPsdtool: TMenuItem;
    Panel1: TPanel;
    Panel3: TPanel;
    cboxSend: TComboBox;
    procedure MenuConfigClick(Sender: TObject);
    procedure MenuAddClick(Sender: TObject);
    procedure MenuCopyClick(Sender: TObject);
    procedure MenuDelClick(Sender: TObject);
    procedure MenuReNameClick(Sender: TObject);
    procedure MenuUpClick(Sender: TObject);
    procedure MenuDownClick(Sender: TObject);
    procedure MenuAviUtlSendClick(Sender: TObject);
    procedure MenuAviUtlRecClick(Sender: TObject);
    procedure cboxSendChange(Sender: TObject);
  private
    { Private 宣言 }
    FCharas       : TAnmEdit3CharaDatas;              //キャラリストクラス
    FChara        : TAnmEdit3CharaData;               // 選択中のキャラクラス
    //FCharaExs     : TProjectManagerChars;
    FlvPsd        : TListViewEdit;                    // 服装表示リスト
    FPsdFile      : TPsdFile;                         // PSDデータ管理クラス
    FDragAndDrop  : TDragAndDropV;                    // ドラッグアンドドロップ処理クラス
    FFilename     : string;                           // 開いているキャラのプロジェクトファイル名
    //FCharaEx: TProjectManagerChara;
    procedure ViewMode();
    // PSDファイルを読み込まず表示のみ
    procedure ViewDress();
    procedure ShowColumn();

    procedure ItemAdd();
    procedure ItemCopy();
    procedure ItemDelete();
    procedure ItemReName();
    procedure ItemUp();
    procedure ItemDown();
    procedure ItemEdit();
    procedure ItemAviUtlRect();
    procedure ItemAviUtlSend();

    // 選択されたキャラのデータと服装を取得
    function IndexToDress(var dc : TDataCharsItem;var dd : TDataDressItem;var j : Integer) : Boolean;

    function MakeDropFile() : string;
    // PSD立ち絵データに変換した物をD&D
    function MakeDropFilePsd() : string;
    // 画像データに変換した物をD&D
    function MakeDropFileImage() : string;
    // 画像オブジェクトとしてD&D
    function MakeDropFileExo() : string;
    // 立ち絵画像としてD&D
    function MakeDropFileImagePsd() : string;

    function CharaDressToFilename(Index : Integer) : string;
    function CharaDressToFilenamePsd(Index : Integer) : string;

    procedure ViewDressIndexSub(const Index : Integer);
    // プロジェクトキャラクラスから該当する編集用キャラクラス参照
    //function PjmCharaToAnmChara(dmc : TProjectManagerChara) : TAnmEdit3CharaData;

    procedure OnListMouseDbClick(Sender: TObject);
    procedure OnEditStart(Sender : TObject;var EditStr : string;const aIndex,aColumn : Integer);
    procedure OnEditOk(Sender : TObject;const EditStr : string;const aIndex,aColumn : Integer);

    procedure OnDropDataMake(Sender : TObject;FileNames : TStringList);
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowDress(dc : TAnmEdit3CharaData);
  end;

implementation

uses DressEditForm,Exo3,Exos,Exo3Psd,ExoEffect,AviUtlCtrl,FaceForm2,FolderLib,BitmapEx;

{$R *.dfm}

{ TFrameDressEdit }

procedure TFrameDress.cboxSendChange(Sender: TObject);
var
  i : Integer;
begin
  i := cboxSend.ItemIndex;
  if i = -1 then exit;
  DMFaceConfig.SendImageDress := i;
  DMFaceConfig.SaveToFile;
end;

constructor TFrameDress.Create(AOwner: TComponent);
begin
  inherited;

  FCharas    := TAnmEdit3CharaDatas.Create;

  FPsdFile := TPsdFile.Create;
  //FPsdFile.BackgroundColor := RGB(255,255,254);

  FlvPsd := TListViewEdit.Create(Self);
  FlvPsd.Parent := Self;
  FlvPsd.Align := alClient;
  FlvPsd.PopupMenu := MenuPop;
  FlvPsd.FixedCol := 1;
  FlvPsd.DataTypes.Add(dtText);
  FlvPsd.DataTypes.Add(dtText);
  FlvPsd.OnEditStart := OnEditStart;
  FlvPsd.OnEditOk    := OnEditOk;
  FlvPsd.OnDblClick := OnListMouseDbClick;
  FlvPsd.ViewMode := vmBig;
  FlvPsd.DoubleBuffered := True;
  FlvPsd.Images.ColorDepth := cd32Bit;
  FlvPsd.IconOptions.AutoArrange := True;

  FDragAndDrop := TDragAndDropV.Create(nil);
  FDragAndDrop.OnDropDataMake := OnDropDataMake;
  //FDragAndDrop.OnDropCancel   := OnDropCancel;
  FDragAndDrop.SetDragTarget(FlvPsd);

  FlvPsd.OnMouseDown := FDragAndDrop.CtrlMouseDown;
  FlvPsd.OnDragOver := FDragAndDrop.CtrlDragOver;
  FlvPsd.OnMouseMove := FDragAndDrop.CtrlMouseMove;
  FlvPsd.OnMouseUp := FDragAndDrop.CtrlMouseUp;

end;

destructor TFrameDress.Destroy;
begin
  FlvPsd.Free;
  FPsdFile.Free;

  FDragAndDrop.Free;

  FCharas.Free;

  inherited;
end;

// データを新規追加
procedure TFrameDress.ItemAdd;
var
  dc : TDataCharsItem;
  dd : TDataDressItem;
  dl : TListItem;
  i,j : Integer;
begin
  dc :=  FChara;                                // 選択中のキャラ参照
  if dc = nil then exit;                        // キャラが未選択であれば処理終了

  i := FlvPsd.ItemIndex;                        // カーソル位置を取得
  if i = -1 then begin                          // カーソルが無い場合
    dd := dc.Dress.Add();                       // 一番下に追加
    dl := FlvPsd.Items.Add();                   // リストの表示も追加
    FlvPsd.ItemIndex := FlvPsd.Items.Count-1;   // 追加したリストにカーソルを合わせる
    FlvPsd.SetTopIndex(FlvPsd.ItemIndex);       // カーソルが表示されるようにスクロール
  end
  else begin                                    // 選択中の場合
    dd := dc.Dress.Add();
    dl := FlvPsd.Items.Add();                   // 一番下に追加※TListViewのバグ対策
    for j := dc.Dress.Count-1 downto i + 1 do begin  // 一番下から順に入れ替える
      dc.Dress.Exchange(j,j-1);                 // 1つ上のデータと入れ替え
      FlvPsd.Exchange(j,j-1);                   // 表示リストも1つ上のデータと入れ替え
    end;
    FlvPsd.ItemIndex := i;                      // 追加したリストにカーソルを合わせる
    FlvPsd.SetTopIndex(FlvPsd.ItemIndex);       // カーソルが表示されるようにスクロール
  end;
  FPsdFile.VisibleInit();                       // PSDファイルのレイヤー状態を初期状態に
  dd.Name := '新しい服装';                      // 名称を作成
  //dl.Caption := df.Name;
  dl.SubItems.Add(dd.Name);
  dl.ImageIndex := -1;

  ViewDressIndexSub(FlvPsd.ItemIndex);          // 指定したインデックスのリスト表示更新
  FChara.SaveToFile(FFilename);                 // キャラデータ保存
end;

procedure TFrameDress.ItemCopy;
var
  dc : TDataCharsItem;
  ddf,ddt : TDataDressItem;
  //df : TFormTemplateSetting;
  dl : TListItem;
  i,j : Integer;
begin
  dc :=  FChara;                                // 選択中のキャラ参照
  if dc = nil then exit;                        // キャラが未選択であれば処理終了
  i := FlvPsd.ItemIndex;                        // カーソル位置を取得
  if i = -1 then exit;                          // キャラが未選択であれば処理終了
  ddf := dc.Dress[i];                           // 服装データ参照
  ddt := dc.Dress.Add();                        // 服装リストに追加
  ddt.Assign(ddf);                              // 追加したデータにカーソル位置のデータをコピー
  ddt.Name := ddt.Name + '(コピー)';            // 名称にコピーを追加
  dl := FlvPsd.Items.Add();                     // リストに追加
  //dl.Caption := dtt.Name;
  dl.SubItems.Add(ddt.Name);
  dl.ImageIndex := -1;
  //FlvPsd.ItemIndex := dc.Dress.Count-1;        // カーソル位置を一端一番下へ
  FPsdFile.ToolStr := ddt.LayerStr;             // レイヤー状態を反映
  ViewDressIndexSub(dc.Dress.Count-1);           // 指定したインデックスのリスト表示更新
  for j := dc.Dress.Count-1 downto i + 2 do begin  // 一番下から順に入れ替える
    dc.Dress.Exchange(j,j-1);                    // 1つ上のデータと入れ替え
    FlvPsd.Exchange(j,j-1);                      // 表示リストも1つ上のデータと入れ替え
  end;
  FlvPsd.ItemIndex := i + 1;                    // カーソル位置を追加したデータに移動
  FlvPsd.SetTopIndex(FlvPsd.ItemIndex);         // カーソルが表示されるようにスクロール

  FChara.SaveToFile(FFilename);
end;

// カーソル上のデータを削除
procedure TFrameDress.ItemDelete;
var
  i : Integer;
  dc : TDataCharsItem;
begin
  dc :=  FChara;
  if dc = nil then exit;
  i := FlvPsd.ItemIndex;
  if i = -1 then exit;
  dc.Dress.Delete(i);
  FlvPsd.Items.Delete(i);
  FlvPsd.ItemIndex := i - 1;
  FlvPsd.SetTopIndex(FlvPsd.ItemIndex);
  FChara.SaveToFile(FFilename);
end;

// カーソル上のデータを編集
procedure TFrameDress.ItemEdit;
var
  df : TFormDressEdit;
  i : Integer;
begin
  df := TFormDressEdit.Create(Self);
  try
    if FChara = nil then exit;
    i := FlvPsd.ItemIndex;
    if i = -1 then exit;

    FPsdFile.ToolStr :=  FChara.Dress[i].LayerStr;  // データからレイヤー表示を再現
    FPsdFile.DrawBitmap;

    df.PsdFile := FPsdFile;
    df.Dress := FChara.Dress[i];
    if df.ShowModal() <> mrOk then exit;

    FChara.Dress[i].LayerStr := FPsdFile.ToolStr;   // レイヤー表示をデータとして格納
    FChara.Dress[i].Name     := FPsdFile.LayerCaption;
    FChara.SaveToFile(FFilename);

    ViewDressIndexSub(i);

  finally
    df.Free;
  end;
end;


procedure TFrameDress.ItemReName;
begin
  FlvPsd.Editing;
end;

// カーソル上のデータを１つ上へ移動
procedure TFrameDress.ItemUp;
var
  i : Integer;
  ds : TDataCharsItem;
begin
  ds :=  FChara;
  if ds = nil then exit;
  i := FlvPsd.ItemIndex;
  if i = -1 then exit;
  if i-1 < 0 then exit;
  ds.Dress.Exchange(i,i-1);
  FlvPsd.Exchange(i,i-1);
  FlvPsd.ItemIndex := i - 1;
  FlvPsd.SetTopIndex(FlvPsd.ItemIndex);
  FChara.SaveToFile(FFilename);
end;

// カーソル上のデータを１つ下へ移動
procedure TFrameDress.ItemDown;
var
  i : Integer;
  ds : TDataCharsItem;
begin
  ds :=  FChara;
  if ds = nil then exit;
  i := FlvPsd.ItemIndex;
  if i = -1 then exit;
  if i+1 >= FlvPsd.Items.Count then exit;
  ds.Dress.Exchange(i,i+1);
  FlvPsd.Exchange(i,i+1);
  FlvPsd.ItemIndex := i + 1;
  FlvPsd.SetTopIndex(FlvPsd.ItemIndex);
  FChara.SaveToFile(FFilename);
end;

procedure TFrameDress.ItemAviUtlRect;
begin

end;


// AviUtlのPSDtoolkitにデータを反映させる
procedure TFrameDress.ItemAviUtlSend;
var
  i: Integer;
  avi : TAviUtlCtrlPsd;
begin
  avi := TAviUtlCtrlPsd.Create;
  try
    i := FlvPsd.ItemIndex;
    if i = -1 then exit;
    avi.Ptkl := FChara.Dress[i].LayerStr;
  finally
    avi.Free;
  end;
end;

function TFrameDress.MakeDropFile: string;
begin
  result := '';
  case DMFaceConfig.SendImageDress of
    0 : result := MakeDropFilePsd;
    1 : result := MakeDropFileImage;
    2 : result := MakeDropFileExo;
    3 : result := MakeDropFileImagePsd;
  end;
end;

function TFrameDress.IndexToDress(var dc: TDataCharsItem; var dd: TDataDressItem;var j : Integer): Boolean;
begin
  result := False;
  j := FlvPsd.ItemIndex;
  if j = -1 then exit;
  dc :=  FChara;
  if dc = nil then exit;
  dd := dc.Dress[j];
  if dd = nil then exit;
  result := True;
end;


function TFrameDress.MakeDropFilePsd: string;
var
  s : string;
  dp : TExo3Psd;
  j : Integer;
  dc : TDataCharsItem;
  dd : TDataDressItem;
  exos : TExo3s;
begin
  result := '';
  if not IndexToDress(dc,dd,j) then exit;   // 選択中のキャラと服装を取得
  exos := TExo3s.Create;
  try
    dp := TExo3Psd.Create;
    dp.DataStart := 1;                   // 開始フレームを1に　※0だと動かない
    dp.DataEnd := 60;                    // 60フレーム分とする
    dp.Chara := dc;                      // PSDtoolkitに渡すキャラデータを代入
    dp.Ptkl := dd.LayerStr;
    exos.Add(dp);                        // EXOオブジェクトにPSDtoolkitを追加

    s := exos.SaveToFileTemp();
    result := s;
  finally
    exos.Free;
  end;
end;

function GetFolderName() : string;
var
  sp : string;
begin
  sp := GetMyDocFolder();
  CheckFolderAndMake(sp);
  sp := sp + 'DressImage\';
  CheckFolderAndMake(sp);
  result := sp;
end;


// 画像ファイルに使用するファイル名を取得
function TFrameDress.CharaDressToFilename(Index : Integer): string;
begin
  result := GetFolderName() + FChara.Name +'_' + IntToHex(Index,4) + '.png';
end;
function TFrameDress.CharaDressToFilenamePsd(Index: Integer): string;
begin
  result := GetFolderName() + FChara.Name +'_Psd_' + FormatDateTime('yyyymmddhhmmsszzz',Now) + '.png';
end;

{
function TFrameDress.CharaDressToFilename(dd: TDataDressItem): string;
begin
  result := GetFolderName() + FCharaEx.Name +'_' + dd.GetLayerFilename() + '.png';
end;
}

procedure SaveToFileTransparentBitmap(bmpFrom : TBitmapEx;const FileName: string);
var
  xh,yh : Integer;
  bmp : TBitmapEx;
begin
  bmp := TBitmapEx.Create;
  try
    bmp.PixelFormat := pf32bit;
    xh := bmpFrom.Width;
    yh := bmpFrom.Height;
    bmp.StretchDraw(xh,yh,bmpFrom);
    bmp.AlphaFormat := afDefined;
    bmp.SaveToFile(FileName);
  finally
    bmp.Free;
  end;
end;

procedure SaveToFileTransparentBitmap2(bmpFrom : TBitmapEx;const FileName: string;  const aWidth, aHeight, aX, aY, aScale: Integer;const  aReverse : Boolean);
var
  x,y,xh,yh : Integer;
  bmp,bmp2 : TBitmapEx;
  r : TRect;
begin
  bmp := TBitmapEx.Create;
  bmp2 := TBitmapEx.Create;
  try
    bmp2.PixelFormat := pf32bit;
    bmp2.AlphaFormat := afDefined;
    bmp.PixelFormat := pf32bit;
    bmp.AlphaFormat := afDefined;
    bmp.SetSize(aWidth,aHeight);
    bmp.Clear;
    xh := bmpFrom.Width * aScale div 100;
    yh := bmpFrom.Height * aScale div 100;

    x := aWidth div 2 - xh div 2 + aX;              // 描画開始座標を計算
    y := aHeight div 2 - yh div 2 + aY;

    r := Rect(x,y,x+xh,y+yh);
    if not aReverse then begin                      //
      bmp2.DrawInvert(bmpFrom,0);
    end
    else begin                                      // 反転させる場合
      bmp2.DrawInvert(bmpFrom,1);
      //r := Rect(x,y,x+xh,y+yh);
      //r := Rect(x+xh,y,x,y+yh);
    end;

    bmp.Canvas.StretchDraw(r,bmp2);
    bmp.SaveToFile(FileName);
  finally
    bmp.Free;
    bmp2.Free;
  end;
end;


function TFrameDress.MakeDropFileImage: string;
var
  s : string;
  j : Integer;
  dc : TDataCharsItem;
  dd : TDataDressItem;
begin
  result := '';
  if not IndexToDress(dc,dd,j) then exit;   // 選択中のキャラと服装を取得
  s := CharaDressToFilename(j);                  // 画像ファイルに使用するファイル名を取得
  FPsdFile.ToolStr := dd.LayerStr;
  FPsdFile.DrawBitmap();
  FPsdFile.Bitmap.SaveToFile(s);
  //SaveToFileTransparentBitmap(FPsdFile.Bitmap,s);
  result := s;
end;

function TFrameDress.MakeDropFileImagePsd: string;
var
  s : string;
  j,x,y,scale : Integer;
  f : Boolean;
  dc : TDataCharsItem;
  dd : TDataDressItem;
begin
  result := '';
  if not IndexToDress(dc,dd,j) then exit;   // 選択中のキャラと服装を取得
  s := CharaDressToFilenamePsd(j);            // 画像ファイルに使用するファイル名を取得
  FPsdFile.ToolStr := dd.LayerStr;
  FPsdFile.DrawBitmap();
  x := Trunc(dc.Psd.x);
  y := Trunc(dc.Psd.y);
  scale := Trunc(dc.Psd.Scale * (dc.psd.Small / 100));
  f := (dc.Psd.Inversion = 1);
  SaveToFileTransparentBitmap2(FPsdFile.Bitmap,s,1920,1080,x,y,scale,f);
  result := s;
end;

function GetTempFilenameExo() : string;
var
  s,sp :string;
begin
  sp := GetMyDocFolder();
  CheckFolderAndMake(sp);             // データ格納用フォルダを作成
  sp := sp + 'temp\';
  CheckFolderAndMake(sp);             // データ格納用フォルダを作成
  s := sp + 'temp.exo';
  result := s;
end;


function TFrameDress.MakeDropFileExo: string;
var
  s : string;
  j : Integer;
  dc : TDataCharsItem;
  dd : TDataDressItem;
  exos : TExo3s;
  exo : TExo3ImageFile;
  effect : TExo3EffectReversal;
begin
  result := '';
  if not IndexToDress(dc,dd,j) then exit;   // 選択中のキャラと服装を取得
  s := CharaDressToFilename(j);                  // 画像ファイルに使用するファイル名を取得
  FPsdFile.ToolStr := dd.LayerStr;
  FPsdFile.DrawBitmap();
  FPsdFile.Bitmap.SaveToFile(s);
  //FPsdFile.SaveToFileTransparentBitmap(s);
  exos := TExo3s.Create;
  try

    exo := TExo3ImageFile.Create;
    exo.Filename := s;
    exo.DataStart := 1;
    exo.DataEnd   := 30*2;

    effect := TExo3EffectReversal.Create;
    effect.LeftRight := False;
    exo.Effects.Add(effect);

    //dc.FaceImage.SavetoExo(exo);
    exos.Add(exo);
    s := GetTempFilenameExo;
    exos.SaveToFile(s);
    result := s;

  finally
    exos.Free;
  end;
end;



procedure TFrameDress.MenuAddClick(Sender: TObject);
begin
  ItemAdd();
end;


procedure TFrameDress.MenuAviUtlRecClick(Sender: TObject);
begin
  ItemAviUtlRect();
end;

procedure TFrameDress.MenuAviUtlSendClick(Sender: TObject);
begin
  ItemAviUtlSend();
end;

procedure TFrameDress.MenuConfigClick(Sender: TObject);
begin
  ItemEdit();
end;

procedure TFrameDress.MenuCopyClick(Sender: TObject);
begin
  ItemCopy();
end;

procedure TFrameDress.MenuDelClick(Sender: TObject);
begin
  ItemDelete();
end;

procedure TFrameDress.MenuReNameClick(Sender: TObject);
begin
  ItemReName();
end;

procedure TFrameDress.MenuUpClick(Sender: TObject);
begin
  ItemUp();
end;

procedure TFrameDress.MenuDownClick(Sender: TObject);
begin
  ItemDown();
end;

procedure TFrameDress.ShowColumn;
var
  lc : TListColumn;
begin
  FlvPsd.Columns.Clear;
  lc := FlvPsd.Columns.Add;
  lc.Caption := '服装';
  lc.Width := 128+4;
  lc := FlvPsd.Columns.Add;
  lc.Caption := '名称';
  //lc.Width := 128;
  FlvPsd.ColumnAlign(1);
end;

procedure TFrameDress.ShowDress(dc : TAnmEdit3CharaData);
var
  s : string;
//  j : Integer;
  dd : TDataDressItem;
 // dc : TAnmEdit3CharaData;
begin

  FChara := dc;
  FFilename := FChara.FileName;

  s := FChara.Psd.FileName;
  if not FileExists((s)) then exit;
  FlvPsd.Clear;
  ViewMode();
  ShowColumn();
  FPsdFile.LoadFromFile(s);
  if FChara.Dress.Count = 0 then begin  // 1件も表情が無い場合
    dd := FChara.Dress.Add;             // 表情リストに追加
    dd.Name := '新しい服装';                // 初期値を設定
    FChara.SaveToFile(FFilename);
  end;
  FlvPsd.RowSelect := True;
  FlvPsd.ColumnClick := False;
  ViewDress();

  cboxSend.ItemIndex := DMFaceConfig.SendImageDress;

end;

procedure TFrameDress.ViewDress;
var
  j : Integer;
  dd : TDataDressItem;
  dl : TListItem;
begin

  FlvPsd.Items.BeginUpdate();
  FlvPsd.Clear;
  for j := 0 to FChara.Dress.Count-1 do begin
    dd :=FChara.Dress[j];
    dl := FlvPsd.Items.Add();
    dl.ImageIndex := -1;
    dl.SubItems.Add(dd.Name);
  end;
  FlvPsd.Items.EndUpdate();
  TFrameDressThread.Create(FlvPsd,FlvPsd.Images,FChara,FChara.Dress,FPsdFile);
end;

// アスペクトル比を合わせた範囲を取得 r : 変形先としての範囲 aWidth,aHeight:元画像ファイル
procedure RectToStreachRect(var r : TRect;const aWidth,aHeight : Integer);
var
  xh,yh,xhr,yhr : Integer;
begin
  //if aWidth = aHeight then exit;
  if aWidth = 0 then exit;
  if aHeight = 0 then exit;

  xhr := r.Width;
  yhr := r.Height;
  if aWidth > aHeight then begin
    yh := r.Width * aHeight div aWidth;
    r.Top := (yhr - yh) div 2;
    r.Height := yh;
  end
  else begin
    xh := r.Height * aWidth div aHeight;
    r.Left := (xhr - xh) div 2;
    r.Width := xh;
  end;
end;


procedure TFrameDress.ViewDressIndexSub(const Index: Integer);
var
  i : Integer;
  dd : TDataDressItem;
  bmpFrom,bmpTo,bmpPsd : TBitmap;
  imgs : TImageList;
begin
  dd := FChara.Dress[Index];                            // キャラの服装リスト取得
  FlvPsd.Items[Index].Caption := dd.Name;
  FlvPsd.Items[Index].SubItems.Clear;
  FlvPsd.Items[Index].SubItems.Add(dd.Name);

  bmpFrom := TBitmap.Create;
  bmpTo := TBitmap.Create;
  try
    FPsdFile.DrawBitmap;                                 // スレッド無しで描画
    bmpPsd := FPsdFile.Bitmap;                           // 描画したビットマップ参照
    imgs := FlvPsd.Images;                               // イメージリスト参照
    bmpTo.SetSize(imgs.Width,imgs.Height);               // イメージリストの画像サイズに合わせる
    dd.DrawPsd(bmpTo,bmpPsd);
    if Index < FlvPsd.Images.Count then begin            // 指定された値が画像範囲内
      i := FlvPsd.Items[Index].ImageIndex;               // リストが表示中の画像Noを取得
      if i = -1 then begin                               // 追加された要素の描画の場合
        FlvPsd.Images.Add(bmpto,nil);                    // 画像を新規追加
        FlvPsd.Items[Index].ImageIndex := imgs.Count-1;  // 画像をリストに割り当て
      end
      else begin                                         // 画像の更新指示の場合
        imgs.Replace(i,bmpto,nil);                       // 画像を差し替え
      end;
    end
    else begin                                           // 画像数の範囲外の場合
      imgs.Add(bmpto,nil);                               // 画像を新規追加
      FlvPsd.Items[Index].ImageIndex := imgs.Count-1;    // 画像をリストに割り当て
    end;
  finally
    bmpto.free;
    bmpFrom.Free;
  end;
end;

procedure TFrameDress.ViewMode;
begin
  FlvPsd.RowColored := False;
  FlvPsd.ItemHeight := 128+1;
  FlvPsd.ViewMode := vmDetail;
  FlvPsd.IconSize := is128;
  FlvPsd.Images.Height := 128;
  FlvPsd.Images.Width := 128;

end;

procedure TFrameDress.OnEditStart(Sender: TObject; var EditStr: string; const aIndex, aColumn: Integer);
begin
  if FChara = nil then exit;

  if aColumn <> 1 then exit;
  EditStr :=  FChara.Dress[aIndex].Name;

end;

procedure TFrameDress.OnEditOk(Sender: TObject; const EditStr: string; const aIndex, aColumn: Integer);
var
  d: TListItem;
begin
  if FChara = nil then exit;
  if aColumn <> 1 then exit;
  FChara.Dress[aIndex].Name := EditStr;
  d := FlvPsd.Items[aIndex];
  //d.Caption := EditStr;
  d.SubItems.Clear;
  d.SubItems.Add(EditStr);
  FChara.SaveToFile(FFilename);
end;

// 編集フォームを開く
procedure TFrameDress.OnListMouseDbClick(Sender: TObject);
begin
  ItemEdit();
end;

{
function TFrameDress.PjmCharaToAnmChara(dmc: TProjectManagerChara): TAnmEdit3CharaData;
var
  i : Integer;
begin
  result := nil;
  i := FCharas.IndexOfFilename(dmc.Filename);
  if i = -1 then exit;
  result := FCharas[i];
end;
}


procedure TFrameDress.OnDropDataMake(Sender : TObject;FileNames : TStringList);
begin
  FileNames.Add(MakeDropFile());
end;

{ TFrameDressThread }

constructor TFrameDressThread.Create(lv: TListView; Images: TImageList;  dc: TDataCharsItem; dds: TDataDressItems; aPsdFile: TPsdFile);
begin
  inherited create(False);
  FWidth := Images.Width;
  FHeight := Images.Height;
  FlvPsd := lv;
  FPsdFile := aPsdFile;
  FreeOnTerminate := True;
  FImages := Images;
  FChara := dc;
  FDress := dds;
end;

destructor TFrameDressThread.Destroy;
begin
  inherited;
end;

procedure TFrameDressThread.Execute;
var
  j: Integer;
  d : TDataDressItem;
begin
  for j := 0 to FDress.Count-1 do begin              // 表情の数だけループ
    FIndex := j;
    FBmpTo := TBitmap.Create;
    try
      FBmpTo.SetSize(FWidth,FHeight);
      d :=FDress[j];                                // 表情を参照
      FPsdFile.VisibleInit;                          // レイヤーの表示情報を初期値に
      FPsdFile.ToolStr := d.LayerStr;
      Synchronize(ExecutSub);
      sleep(1);
    finally
      FBmpTo.Free;
    end;
  end;
end;

procedure TFrameDressThread.ExecutSub;
var
  bmp : TBitmap;
  d : TDataDressItem;
begin
  bmp := TBitmap.Create;
  try
    FPsdFile.DrawBitmap;                                // スレッド無しでPSDを描画
    d := FDress[FIndex];                               // 表情を参照
    d.DrawPsd(FBmpTo, FPsdFile.Bitmap);
    //FBmpTo.SaveToFile('test.bmp');
    FImages.Add(FBmpTo,nil);                            // イメージリストに追加
    FlvPsd.Items[FIndex].ImageIndex := FImages.Count-1;          // 追加したイメージ番号を指定
  finally
    bmp.Free;
  end;
end;

end.
