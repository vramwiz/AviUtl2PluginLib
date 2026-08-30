unit SerifAviUtlSyncroh2Adapter;


interface

implementation

uses
  AliasManager,
  AliasManagerNormalAudio,
  AliasManagerObjectPicture,
  AliasManagerScriptSerif,
  AliasManagerStringList,
  SerifAviUtlAliasProvider,
  SerifAviUtlDrawAliasBuilder,
  SerifAviUtlProfile;

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

procedure RegisterSyncroh2Profile;
var
  Profile: TSerifAviUtlProfile;
begin
  Profile := Default(TSerifAviUtlProfile);
  Profile.ProductID := 'Syncroh2';
  Profile.ProjectFolderKey := 'SerifFolderName';
  Profile.SerifEffectName := 'セリフ入力@Syncroh2_Script';
  Profile.SerifTextItem := 'セリフ';
  Profile.CharacterItem := 'キャラ';
  Profile.EmotionItem := '感情';
  Profile.DirectionItem := '演出';
  Profile.AiueoItem := '母音';
  Profile.LabItem := 'LAB';
  Profile.UIDItem := 'UID';
  Profile.AudioEffectName := '音声ファイル';
  Profile.AudioFileItem := 'ファイル';
  Profile.AudioPlaybackItem := '再生位置';
  Profile.FilterObjectName := 'フィルタオブジェクト';
  Profile.SerifDrawEffectName := '新旧朗2 セリフ表示';
  RegisterSerifAviUtlProfile(Profile);
end;

procedure BeginSyncroh2AliasBatch;
begin
  GAliasManager.Clear;
end;

procedure AddSyncroh2AudioAlias(const Data: TSerifAviUtlAudioAliasData);
var
  Item: TAliasManagerNormalAudio;
begin
  Item := GAliasManager.AddAudio;
  Item.Filename := Data.FileName;
  Item.Layer := Data.Layer;
  Item.StartPos := Data.StartPos;
  Item.EndPos := Data.EndPos;
  Item.FrameStart := Data.FrameStart;
  Item.FrameLength := Data.FrameLength;
  Item.Group := Data.Group;
  Item.Volume := Data.Volume;
  Item.Pan := Data.Pan;
end;

procedure AddSyncroh2InputAlias(const Data: TSerifAviUtlInputAliasData;
  out FrameEnd: Integer);
var
  Item: TAliasManagerScriptSerifInput;
begin
  Item := GAliasManager.AddSerifIn;
  Item.Character := Data.Character;
  Item.Emotion := Data.Emotion;
  Item.Direction := Data.Direction;
  Item.Serif := Data.Serif;
  Item.LAB := Data.Lab;
  Item.UID := Data.UID;
  Item.Layer := Data.Layer;
  Item.FrameStart := Data.FrameStart;
  Item.FrameLength := Data.FrameLength;
  Item.Group := Data.Group;
  FrameEnd := Item.FrameEnd;
end;

function CreateSyncroh2OutputAlias(const Layer,
  FrameLength: Integer): string;
var
  Item: TAliasManagerScriptSerifOutput;
begin
  GAliasManager.ObjectName := '';
  GAliasManager.Clear;
  Item := GAliasManager.AddSerifOut;
  Item.LayerView := Layer;
  Item.FrameStart := 0;
  Item.FrameLength := FrameLength;
  GAliasManager.SaveToAlias;
  Result := GAliasManager.FileName;
end;

function BuildSyncroh2DrawAlias: string;
begin
  Result := BuildDefaultSerifDrawAlias(
    CurrentSerifAviUtlProfile.FilterObjectName,
    CurrentSerifAviUtlProfile.SerifDrawEffectName);
end;

function BuildSyncroh2AliasBatch: string;
begin
  Result := GAliasManager.SaveToText;
end;

function SaveSyncroh2AliasBatch: string;
begin
  GAliasManager.SaveToAlias;
  Result := GAliasManager.FileName;
end;

function CreateSyncroh2BoardAlias(
  const Data: TSerifAviUtlBoardAliasData): string;
var
  Item: TAliasManagerObjectPictureFile;
begin
  GAliasManager.ObjectName := '';
  GAliasManager.Clear;
  Item := GAliasManager.AddPictureFile;
  Item.PictureFileName := Data.FileName;
  Item.EnableScript := Data.EnableScript;
  Item.RefLayer := Data.RefLayer;
  Item.Hold := Data.Hold;
  Item.Fade := Data.Fade;
  Item.Layer := Data.Layer;
  Item.FrameStart := Data.FrameStart;
  Item.FrameLength := Data.FrameLength;
  GAliasManager.SaveToAlias;
  Result := GAliasManager.FileName;
end;

procedure RegisterSyncroh2AliasProvider;
var
  Provider: TSerifAviUtlAliasProvider;
begin
  Provider := Default(TSerifAviUtlAliasProvider);
  Provider.ProductID := 'Syncroh2';
  Provider.BeginAliasBatch := BeginSyncroh2AliasBatch;
  Provider.AddAudioAlias := AddSyncroh2AudioAlias;
  Provider.AddInputAlias := AddSyncroh2InputAlias;
  Provider.BuildAliasBatch := BuildSyncroh2AliasBatch;
  Provider.SaveAliasBatch := SaveSyncroh2AliasBatch;
  Provider.CreateBoardAlias := CreateSyncroh2BoardAlias;
  Provider.CreateOutputAlias := CreateSyncroh2OutputAlias;
  Provider.BuildDrawAlias := BuildSyncroh2DrawAlias;
  RegisterSerifAviUtlAliasProvider(Provider);
end;

initialization
  RegisterSyncroh2Profile;
  RegisterSyncroh2AliasProvider;

end.
