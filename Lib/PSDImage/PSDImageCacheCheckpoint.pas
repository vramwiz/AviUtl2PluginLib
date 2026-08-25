unit PSDImageCacheCheckpoint;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  TPSDImageCheckpointCacheItem = class
  private
    FKeyFileName: string;
    FKeyPrefix: string;
    FCheckpointIndex: Integer;
    FBuffer: Pointer;
    FBufferSize: Integer;
    FWidth: Integer;
    FHeight: Integer;
  public
    destructor Destroy; override;

    function HasBuffer: Boolean;
    procedure InitKeys(const FileName, PrefixKey: string; const CheckpointIndex: Integer);
    procedure SetBuffer(const Src: Pointer; const BufferSize, AWidth, AHeight: Integer);
    function CopyBufferTo(const Dest: Pointer; const BufferSize: Integer): Boolean;

    property KeyFileName: string read FKeyFileName;
    property KeyPrefix: string read FKeyPrefix;
    property CheckpointIndex: Integer read FCheckpointIndex;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property Size: Integer read FBufferSize;
  end;

  TPSDImageCheckpointCacheList = class(TObjectList<TPSDImageCheckpointCacheItem>)
  public
    function FindItem(
      const FileName: string;
      const PrefixKey: string;
      const CheckpointIndex: Integer;
      const Width: Integer;
      const Height: Integer
    ): TPSDImageCheckpointCacheItem;

    function GetBuffer(
      const Dest: Pointer;
      const Size: Integer;
      const FileName: string;
      const PrefixKey: string;
      const CheckpointIndex: Integer;
      const Width: Integer;
      const Height: Integer
    ): Boolean;

    procedure AddBuffer(
      const Src: Pointer;
      const Size: Integer;
      const FileName: string;
      const PrefixKey: string;
      const CheckpointIndex: Integer;
      const Width: Integer;
      const Height: Integer
    );
  end;

implementation

destructor TPSDImageCheckpointCacheItem.Destroy;
begin
  if FBuffer <> nil then
  begin
    FreeMem(FBuffer);
    FBuffer := nil;
  end;
  inherited;
end;

function TPSDImageCheckpointCacheItem.HasBuffer: Boolean;
begin
  Result := (FBuffer <> nil) and (FBufferSize > 0);
end;

procedure TPSDImageCheckpointCacheItem.InitKeys(
  const FileName, PrefixKey: string;
  const CheckpointIndex: Integer
);
begin
  FKeyFileName := FileName;
  FKeyPrefix := PrefixKey;
  FCheckpointIndex := CheckpointIndex;
end;

procedure TPSDImageCheckpointCacheItem.SetBuffer(
  const Src: Pointer;
  const BufferSize, AWidth, AHeight: Integer
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
  FWidth := AWidth;
  FHeight := AHeight;
end;

function TPSDImageCheckpointCacheItem.CopyBufferTo(
  const Dest: Pointer;
  const BufferSize: Integer
): Boolean;
begin
  Result := False;
  if (Dest = nil) or (not HasBuffer) then Exit;
  if BufferSize <> FBufferSize then Exit;

  Move(FBuffer^, Dest^, BufferSize);
  Result := True;
end;

function TPSDImageCheckpointCacheList.FindItem(
  const FileName: string;
  const PrefixKey: string;
  const CheckpointIndex: Integer;
  const Width: Integer;
  const Height: Integer
): TPSDImageCheckpointCacheItem;
var
  Item: TPSDImageCheckpointCacheItem;
begin
  Result := nil;
  for Item in Self do
  begin
    if (Item.KeyFileName = FileName) and
       (Item.KeyPrefix = PrefixKey) and
       (Item.CheckpointIndex = CheckpointIndex) and
       (Item.Width = Width) and
       (Item.Height = Height) then
      Exit(Item);
  end;
end;

function TPSDImageCheckpointCacheList.GetBuffer(
  const Dest: Pointer;
  const Size: Integer;
  const FileName: string;
  const PrefixKey: string;
  const CheckpointIndex: Integer;
  const Width: Integer;
  const Height: Integer
): Boolean;
var
  Item: TPSDImageCheckpointCacheItem;
begin
  Result := False;
  Item := FindItem(FileName, PrefixKey, CheckpointIndex, Width, Height);
  if Item = nil then Exit;

  Result := Item.CopyBufferTo(Dest, Size);
end;

procedure TPSDImageCheckpointCacheList.AddBuffer(
  const Src: Pointer;
  const Size: Integer;
  const FileName: string;
  const PrefixKey: string;
  const CheckpointIndex: Integer;
  const Width: Integer;
  const Height: Integer
);
var
  Item: TPSDImageCheckpointCacheItem;
begin
  if (Src = nil) or (Size <= 0) then Exit;

  Item := FindItem(FileName, PrefixKey, CheckpointIndex, Width, Height);
  if Item = nil then
  begin
    Item := TPSDImageCheckpointCacheItem.Create;
    Item.InitKeys(FileName, PrefixKey, CheckpointIndex);
    Add(Item);
  end;

  Item.SetBuffer(Src, Size, Width, Height);
end;

end.
