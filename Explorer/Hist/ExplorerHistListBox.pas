unit ExplorerHistListBox;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,ListBoxEdit,ExplorerHist,
  Vcl.Menus, System.ImageList, Vcl.ImgList,ShortcutAction, Vcl.ComCtrls,
  Vcl.ToolWin;

// エクスプローラー履歴用リストボックス
type
  TListBoxExplorerHist = class(TListBoxEditColor)
	private
		{ Private 宣言 }
    FImageList : TImageList;
    function GetHists(Index: Integer): TExplorerHistItem;
  protected
    FHists         : TExplorerHistList;

    procedure DrawItem(Index: Integer; r: TRect; State: TOwnerDrawState); override;
    procedure DoEdited(Index: Integer; var NewText: string); override;

  public
		{ Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowList(Hists : TExplorerHistList);
    procedure ViewList();

    procedure ItemUp;
    procedure ItemDown;
    procedure ItemDelete;
    procedure ItemEditName;

    // 表示するフォルダを設定
    procedure SetSelectFolder(const Value: string);

    // 選択中の履歴クラス参照
    function GetSelectItem : TExplorerHistItem;

    property Hists[Index : Integer] : TExplorerHistItem read GetHists;

    //    property Hists     : TExplorerHistList read FHists write FHists;
    property ImageList : TImageList read FImageList write FImageList;
  end;


implementation

{ TListBoxExplorerHist }

constructor TListBoxExplorerHist.Create(AOwner: TComponent);
begin
  inherited;

end;

destructor TListBoxExplorerHist.Destroy;
begin

  inherited;
end;

procedure TListBoxExplorerHist.ShowList(Hists: TExplorerHistList);
begin
  FHists := Hists;
  ViewList;
end;

procedure TListBoxExplorerHist.ViewList;
var
  i,j: Integer;
  s: string;
  Hist : TExplorerHistItem;
begin
  j := ItemIndex;
  Items.BeginUpdate;
  Clear;
  for i := 0 to FHists.Count-1 do begin
    Hist := FHists[i];
    s := ExtractFileName(Hist.Name);
    Items.AddObject(s,Hist);
  end;
  if j <> -1 then begin
    if j < Items.Count then ItemIndex := j;
  end
  else begin
    if Items.Count > 0 then begin
      ItemIndex := 0;
    end;
  end;

  Items.EndUpdate;
end;


procedure TListBoxExplorerHist.DrawItem(Index: Integer; r: TRect;State: TOwnerDrawState);
var
  i : Integer;
  rr : TRect;
  Hist : TExplorerHistItem;
begin
  DrawItemBackground(Canvas,Index,r,State);
  Hist := TExplorerHistItem(Items.Objects[Index]);
  if Hist = nil then Exit;

  {
  if (odFocused in State) or (odSelected in State)  then begin
    FImageList.DrawingStyle := dsSelected;
    //FImageList.BlendColor := clWhite;
    FImageList.BkColor := clBlack;
  end
  else begin
    FImageList.BkColor := clBlue;
    FImageList.DrawingStyle := dsFocus;
  end;
  }
  FImageList.BkColor := clBlack;
  rr := r;
  rr.Width := rr.Height;
  i := Hist.Style;
  if (i >= 0) and (i <= FImageList.Count) then
  begin
    var bmp := TBitmap.Create;
    try
      bmp.PixelFormat := pf32bit;
      bmp.SetSize(FImageList.Width, FImageList.Height);

      // i は 1-based のため i-1 が実際のインデックス
      FImageList.GetBitmap(i, bmp);

      // rr 領域にストレッチ描画
      Canvas.StretchDraw(rr, bmp);
    finally
      bmp.Free;
    end;
  end;

  rr := r;
  rr.Left := rr.Left + rr.Height;
  DrawTextOut(Canvas,rr,State,Hist.Name);
end;

function TListBoxExplorerHist.GetHists(Index: Integer): TExplorerHistItem;
var
  i: Integer;
begin
  Result := nil;
  i := Index;
  if i = -1 then Exit;
  if i >= Count then Exit;
  if FHists = nil then Exit;
  Result := TExplorerHistItem(Items.Objects[i]);
end;

function TListBoxExplorerHist.GetSelectItem: TExplorerHistItem;
var
  i: Integer;
begin
  Result := nil;
  i := ItemIndex;
  if i = -1 then Exit;
  if i >= Count then Exit;
  Result := Hists[i];
end;

procedure TListBoxExplorerHist.ItemDelete;
var
  i: Integer;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if i >= FHists.Count then Exit;

  Items.Delete(i);       // 表示リストから削除
  FHists.DeleteHist(i);           // データから削除
  FHists.SaveToFile();            // データを保存

  if i >= Count then Dec(i);

  ItemIndex := i;
end;

procedure TListBoxExplorerHist.ItemUp;
var
  i: Integer;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if i < 1  then Exit;
  if FHists = nil then Exit;

  FHists.Exchange(i,i-1);
  Items.Exchange(i,i-1);
  FHists.SaveToFile();
  ItemIndex := i - 1;
  TopIndex := ItemIndex;
end;

procedure TListBoxExplorerHist.ItemDown;
var
  i: Integer;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if i >= Items.Count-1  then Exit;
  if FHists = nil then Exit;

  FHists.Exchange(i,i+1);
  Items.Exchange(i,i+1);
  FHists.SaveToFile();
  ItemIndex := i + 1;
  TopIndex := ItemIndex;
end;

procedure TListBoxExplorerHist.ItemEditName;
var
  i: Integer;
begin
  i := ItemIndex;
  if i = -1 then Exit;
  if i >= FHists.Count then Exit;
  BeginEdit(i);
end;

procedure TListBoxExplorerHist.SetSelectFolder(const Value: string);
var
  i: Integer;
  Hist : TExplorerHistItem;
begin
  for i := 0 to Count-1 do begin
    Hist := TExplorerHistItem(Items.Objects[i]);
    if Hist = nil then COntinue;
    if Hist.FolderName = Value then begin
      ItemIndex := i;
      TopIndex := i;
      Exit;
    end;
  end;
end;

procedure TListBoxExplorerHist.DoEdited(Index: Integer; var NewText: string);
var
  i : Integer;
  Hist : TExplorerHistItem;
begin
  i := Index;
  if i = -1 then Exit;
  Hist := TExplorerHistItem(Items.Objects[i]);
  if Hist = nil then Exit;
  Hist.Name := NewText;
  FHists.SaveToFile();
end;


end.
