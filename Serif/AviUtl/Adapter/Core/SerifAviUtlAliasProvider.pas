unit SerifAviUtlAliasProvider;

// セリフ用AviUtl2エイリアス生成を製品実装へ委譲する登録境界。
// 共通Serifは製品固有のAliasManager派生型やエイリアス本文を参照しない。

interface

type
  TSerifAviUtlAudioAliasData = record
    FileName: string;
    Layer: Integer;
    StartPos: Double;
    EndPos: Double;
    FrameStart: Integer;
    FrameLength: Integer;
    Group: Integer;
    Volume: Double;
    Pan: Double;
  end;

  TSerifAviUtlBoardAliasData = record
    FileName: string;
    EnableScript: Boolean;
    RefLayer: Integer;
    Hold: Integer;
    Fade: Integer;
    Layer: Integer;
    FrameStart: Integer;
    FrameLength: Integer;
  end;

  TSerifAviUtlInputAliasData = record
    Character: string;
    Emotion: string;
    Direction: Integer;
    Serif: string;
    Lab: string;
    UID: string;
    Layer: Integer;
    FrameStart: Integer;
    FrameLength: Integer;
    Group: Integer;
  end;

  TSerifAviUtlAddInputAliasProc = procedure(
    const Data: TSerifAviUtlInputAliasData; out FrameEnd: Integer);
  TSerifAviUtlBeginAliasBatchProc = procedure;
  TSerifAviUtlAddAudioAliasProc = procedure(
    const Data: TSerifAviUtlAudioAliasData);
  TSerifAviUtlBuildAliasBatchFunc = function: string;
  TSerifAviUtlSaveAliasBatchFunc = function: string;
  TSerifAviUtlCreateBoardAliasFunc = function(
    const Data: TSerifAviUtlBoardAliasData): string;
  TSerifAviUtlCreateOutputAliasFunc = function(const Layer,
    FrameLength: Integer): string;
  TSerifAviUtlBuildDrawAliasFunc = function: string;

  TSerifAviUtlAliasProvider = record
    ProductID: string;
    BeginAliasBatch: TSerifAviUtlBeginAliasBatchProc;
    AddAudioAlias: TSerifAviUtlAddAudioAliasProc;
    AddInputAlias: TSerifAviUtlAddInputAliasProc;
    BuildAliasBatch: TSerifAviUtlBuildAliasBatchFunc;
    SaveAliasBatch: TSerifAviUtlSaveAliasBatchFunc;
    CreateBoardAlias: TSerifAviUtlCreateBoardAliasFunc;
    CreateOutputAlias: TSerifAviUtlCreateOutputAliasFunc;
    BuildDrawAlias: TSerifAviUtlBuildDrawAliasFunc;
  end;

// プロセスで使用する製品実装を一度だけ登録する。
procedure RegisterSerifAviUtlAliasProvider(
  const Provider: TSerifAviUtlAliasProvider);
// 登録済みProviderの製品IDを返す。未登録なら構成エラーにする。
function CurrentSerifAviUtlAliasProviderProductID: string;
// セリフと音声を同じエイリアスへ積む生成セッションを初期化する。
procedure BeginSerifAviUtlAliasBatch;
// 音声オブジェクトを現在のエイリアス生成セッションへ追加する。
procedure AddSerifAviUtlAudioAlias(const Data: TSerifAviUtlAudioAliasData);
// セリフ入力オブジェクトを現在のエイリアス生成セッションへ追加する。
procedure AddSerifAviUtlInputAlias(const Data: TSerifAviUtlInputAliasData;
  out FrameEnd: Integer);
// 現在の生成セッションをAviUtl2へ直接渡せる本文として取得する。
function BuildSerifAviUtlAliasBatch: string;
// 現在の生成セッションをD&D可能なファイルへ保存する。
function SaveSerifAviUtlAliasBatch: string;
// セリフ連動画像オブジェクトをD&D可能なファイルとして生成する。
function CreateSerifAviUtlBoardAlias(
  const Data: TSerifAviUtlBoardAliasData): string;
// 旧セリフ表示オブジェクトをD&D可能なファイルとして生成する。
function CreateSerifAviUtlOutputAlias(const Layer,
  FrameLength: Integer): string;
// 新セリフ表示フィルターの完全エイリアス本文を生成する。
function BuildSerifAviUtlDrawAlias: string;

implementation

uses
  System.SysUtils;

var
  GProvider: TSerifAviUtlAliasProvider;
  GProviderRegistered: Boolean;

procedure RequireRegisteredProvider;
begin
  if not GProviderRegistered then
    raise EInvalidOp.Create('Serif AviUtl alias provider is not registered.');
end;

procedure RegisterSerifAviUtlAliasProvider(
  const Provider: TSerifAviUtlAliasProvider);
begin
  if Provider.ProductID = '' then
    raise EArgumentException.Create('Serif AviUtl alias provider ProductID is empty.');
  if not Assigned(Provider.BeginAliasBatch) or
     not Assigned(Provider.AddAudioAlias) or
     not Assigned(Provider.AddInputAlias) or
     not Assigned(Provider.BuildAliasBatch) or
     not Assigned(Provider.SaveAliasBatch) or
     not Assigned(Provider.CreateBoardAlias) or
     not Assigned(Provider.CreateOutputAlias) or
     not Assigned(Provider.BuildDrawAlias) then
    raise EArgumentException.Create('Serif AviUtl alias provider is incomplete.');

  if GProviderRegistered then
  begin
    if not SameText(GProvider.ProductID, Provider.ProductID) then
      raise EInvalidOp.CreateFmt(
        'Serif AviUtl alias provider is already registered for %s.',
        [GProvider.ProductID]);
    Exit;
  end;

  GProvider := Provider;
  GProviderRegistered := True;
end;

function CurrentSerifAviUtlAliasProviderProductID: string;
begin
  RequireRegisteredProvider;
  Result := GProvider.ProductID;
end;

procedure BeginSerifAviUtlAliasBatch;
begin
  RequireRegisteredProvider;
  GProvider.BeginAliasBatch;
end;

procedure AddSerifAviUtlAudioAlias(const Data: TSerifAviUtlAudioAliasData);
begin
  RequireRegisteredProvider;
  GProvider.AddAudioAlias(Data);
end;

procedure AddSerifAviUtlInputAlias(const Data: TSerifAviUtlInputAliasData;
  out FrameEnd: Integer);
begin
  RequireRegisteredProvider;
  GProvider.AddInputAlias(Data, FrameEnd);
end;

function BuildSerifAviUtlAliasBatch: string;
begin
  RequireRegisteredProvider;
  Result := GProvider.BuildAliasBatch;
end;

function SaveSerifAviUtlAliasBatch: string;
begin
  RequireRegisteredProvider;
  Result := GProvider.SaveAliasBatch;
end;

function CreateSerifAviUtlBoardAlias(
  const Data: TSerifAviUtlBoardAliasData): string;
begin
  RequireRegisteredProvider;
  Result := GProvider.CreateBoardAlias(Data);
end;

function CreateSerifAviUtlOutputAlias(const Layer,
  FrameLength: Integer): string;
begin
  RequireRegisteredProvider;
  Result := GProvider.CreateOutputAlias(Layer, FrameLength);
end;

function BuildSerifAviUtlDrawAlias: string;
begin
  RequireRegisteredProvider;
  Result := GProvider.BuildDrawAlias;
end;

end.
