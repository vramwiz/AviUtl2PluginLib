unit PSDImageCacheRender;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  {--------------------------------------------------------------
    PSD 描画結果キャッシュ（1要素）
    ・Create ではバッファを確保しない
    ・AddBuffer / SetBuffer 時のみメモリ確保
    ・バッファ所有権は Item が持つ
  --------------------------------------------------------------}
  TPSDImageCacheItem = class
  private
    FKeyFileName : string;   // PSD ファイル名
    FKeyLayer    : string;   // レイヤー状態キー（反転含まない）
    FFlipMode    : Integer;  // 反転状態（0～3）

    FBuffer      : Pointer;  // 描画済み RGBA バッファ
    FBufferSize  : Integer;  // バッファサイズ（bytes）
    FWidth       : Integer;  // 描画幅
    FHeight      : Integer;  // 描画高さ
  public
    destructor Destroy; override;

    function HasBuffer: Boolean;

    procedure InitKeys(
      const FileName : string;  // PSD ファイル名
      const LayerKey : string;  // レイヤー状態キー
      const FlipMode : Integer  // 反転状態
    );

    procedure SetBuffer(
      const Src        : Pointer; // コピー元バッファ
      const BufferSize : Integer; // バッファサイズ
      const AWidth     : Integer; // 描画幅
      const AHeight    : Integer  // 描画高さ
    );

    function CopyBufferTo(
      const Dest       : Pointer; // コピー先バッファ
      const BufferSize : Integer  // 要求サイズ
    ): Boolean;

    property KeyFileName : string  read FKeyFileName;
    property KeyLayer    : string  read FKeyLayer;
    property FlipMode    : Integer read FFlipMode;
    property Width       : Integer read FWidth;
    property Height      : Integer read FHeight;
    property Size        : Integer read FBufferSize;
  end;


  {--------------------------------------------------------------
    PSD 描画結果キャッシュ（リスト）
  --------------------------------------------------------------}
  TPSDImageCacheItemList = class(TObjectList<TPSDImageCacheItem>)
  public
    function FindItem(
      const FileName : string;   // PSD ファイル名
      const LayerKey : string;   // レイヤー状態キー
      const FlipMode : Integer;  // 反転状態
      const Width    : Integer;  // 描画幅
      const Height   : Integer   // 描画高さ
    ): TPSDImageCacheItem;

    function GetBuffer(
      const Dest     : Pointer;  // 出力先バッファ
      const Size     : Integer;  // 出力先サイズ
      const FileName : string;   // PSD ファイル名
      const LayerKey : string;   // レイヤー状態キー
      const FlipMode : Integer;  // 反転状態
      const Width    : Integer;  // 描画幅
      const Height   : Integer   // 描画高さ
    ): Boolean;

    procedure AddBuffer(
      const Src      : Pointer;  // 描画済みバッファ（Data2）
      const Size     : Integer;  // バッファサイズ
      const FileName : string;   // PSD ファイル名
      const LayerKey : string;   // レイヤー状態キー
      const FlipMode : Integer;  // 反転状態
      const Width    : Integer;  // 描画幅
      const Height   : Integer   // 描画高さ
    );
  end;


{--------------------------------------------------------------
  グローバルキャッシュ管理関数（描画結果）
--------------------------------------------------------------}
//procedure InitializePSDImageCacheRenders;
//procedure FinalizePSDImageCacheRenders;

implementation

{------------------------------------------------------------------------------}
{  TPSDImageCacheItem                                                          }
{------------------------------------------------------------------------------}
destructor TPSDImageCacheItem.Destroy;
begin
  if FBuffer <> nil then
  begin
    FreeMem(FBuffer);
    FBuffer := nil;
  end;
  inherited;
end;

function TPSDImageCacheItem.HasBuffer: Boolean;
begin
  Result := (FBuffer <> nil) and (FBufferSize > 0);
end;

procedure TPSDImageCacheItem.InitKeys(
  const FileName : string;
  const LayerKey : string;
  const FlipMode : Integer
);
begin
  FKeyFileName := FileName;
  FKeyLayer    := LayerKey;
  FFlipMode    := FlipMode;
end;

procedure TPSDImageCacheItem.SetBuffer(
  const Src        : Pointer;
  const BufferSize : Integer;
  const AWidth     : Integer;
  const AHeight    : Integer
);
begin
  if (Src = nil) or (BufferSize <= 0) then Exit;

  if FBuffer <> nil then
  begin
    FreeMem(FBuffer);
    FBuffer := nil;
  end;

  GetMem(FBuffer, BufferSize);
  Move(Src^, FBuffer^, BufferSize);

  FBufferSize := BufferSize;
  FWidth      := AWidth;
  FHeight     := AHeight;
end;

function TPSDImageCacheItem.CopyBufferTo(
  const Dest       : Pointer;
  const BufferSize : Integer
): Boolean;
begin
  Result := False;

  if (Dest = nil) or (not HasBuffer) then Exit;
  if BufferSize <> FBufferSize then Exit;

  Move(FBuffer^, Dest^, BufferSize);
  Result := True;
end;

{------------------------------------------------------------------------------}
{  TPSDImageCacheItemList                                                      }
{------------------------------------------------------------------------------}
function TPSDImageCacheItemList.FindItem(
  const FileName : string;
  const LayerKey : string;
  const FlipMode : Integer;
  const Width    : Integer;
  const Height   : Integer
): TPSDImageCacheItem;
var
  Item : TPSDImageCacheItem;
begin
  Result := nil;

  for Item in Self do
  begin
    if (Item.KeyFileName = FileName) and
       (Item.KeyLayer    = LayerKey)  and
       (Item.FlipMode    = FlipMode)  and
       (Item.Width       = Width)     and
       (Item.Height      = Height) then
    begin
      Exit(Item);
    end;
  end;
end;

function TPSDImageCacheItemList.GetBuffer(
  const Dest     : Pointer;
  const Size     : Integer;
  const FileName : string;
  const LayerKey : string;
  const FlipMode : Integer;
  const Width    : Integer;
  const Height   : Integer
): Boolean;
var
  Item : TPSDImageCacheItem;
begin
  Result := False;

  Item := FindItem(FileName, LayerKey, FlipMode, Width, Height);
  if Item = nil then Exit;

  Result := Item.CopyBufferTo(Dest, Size);
end;

procedure TPSDImageCacheItemList.AddBuffer(
  const Src      : Pointer;
  const Size     : Integer;
  const FileName : string;
  const LayerKey : string;
  const FlipMode : Integer;
  const Width    : Integer;
  const Height   : Integer
);
var
  Item : TPSDImageCacheItem;
begin
  if (Src = nil) or (Size <= 0) then Exit;

  Item := FindItem(FileName, LayerKey, FlipMode, Width, Height);

  if Item = nil then
  begin
    Item := TPSDImageCacheItem.Create;
    Item.InitKeys(FileName, LayerKey, FlipMode);
    Add(Item);
  end;

  Item.SetBuffer(Src, Size, Width, Height);
end;

{
procedure InitializePSDImageCacheRenders;
begin
  if GPSDImageCacheRenders = nil then
    GPSDImageCacheRenders := TPSDImageCacheItemList.Create(True);
end;

procedure FinalizePSDImageCacheRenders;
begin
  FreeAndNil(GPSDImageCacheRenders);
end;

}
end.

