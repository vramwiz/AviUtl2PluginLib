unit SerifVoiceWatcher;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,FolderWatch,RTTIPersistent,
  SerifVoiceWatcherList;

type
  TSerifVoiceWatcher = class(TPersistent)
  private
    { Private êÈåæ }
    FWatchers: TSerifVoiceWatcherList;
  public
    { Public êÈåæ }
    constructor Create();
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property  Watchers :TSerifVoiceWatcherList read FWatchers;
  end;


implementation

{ TSerifVoiceWatcher }

constructor TSerifVoiceWatcher.Create;
begin
  FWatchers := TSerifVoiceWatcherList.Create;
end;

destructor TSerifVoiceWatcher.Destroy;
begin
  FWatchers.Free;
  inherited;
end;

procedure TSerifVoiceWatcher.Start;
begin

end;

procedure TSerifVoiceWatcher.Stop;
begin

end;

end.
