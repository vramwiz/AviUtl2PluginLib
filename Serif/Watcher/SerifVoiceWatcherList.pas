unit SerifVoiceWatcherList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,FolderWatch,RTTIPersistent;

//--------------------------------------------------------------------------//
//  アプリが出力するフォルダを管理するクラス                                //
//--------------------------------------------------------------------------//
type
  TSerifVoiceWatcherItem = class(TRTTIPersistentIni)
  private
    { Private 宣言 }
    FName   : string;
    FFolder : string;
  public
    { Public 宣言 }
 published
    property Name   :string read FName   write FName;
    property Folder :string read FFolder write FFolder;

  end;

  TSerifVoiceWatcherList = class(TRTTIPersistentIniList<TSerifVoiceWatcherItem>)
  private
    function GetWatchers(Index: Integer): TSerifVoiceWatcherItem;
  public
    property Watchers[Index : Integer] : TSerifVoiceWatcherItem read GetWatchers;
  end;



implementation

{ TSerifVoiceWatcherList }

function TSerifVoiceWatcherList.GetWatchers(  Index: Integer): TSerifVoiceWatcherItem;
begin
  Result := TSerifVoiceWatcherItem(inherited Items[Index]);
end;

end.
