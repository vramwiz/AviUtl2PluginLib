unit SerifScenarioMsgList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,RTTIPersistentIni;

type
  TSerifScenarioMsgItem = class(TRTTIPersistentIni)
  private
    { Private 宣言 }
    FChara : string;   // このセリフを担当する配役（キャラ）の名前
    FSerif : string;   // セリフ本文（文章）
    FColor   : TColor;   // 配役の背景色（Name列に使用）
  public
    { Public 宣言 }
  published
    property Chara : string read FChara write FChara;   // 話者
    property Serif : string read FSerif write FSerif;   // セリフ内容
    property Color   : TColor read FColor   write FColor;
end;

  TSerifScenarioMsgList = class(TRTTIPersistentIniList<TSerifScenarioMsgItem>)
  private
    function GetMsgs(Index: Integer): TSerifScenarioMsgItem;
  public
    property Msgs[Index : Integer] : TSerifScenarioMsgItem read GetMsgs;
  end;


implementation

{ TSerifScenarioMsgList }

function TSerifScenarioMsgList.GetMsgs(Index: Integer): TSerifScenarioMsgItem;
begin
  Result := TSerifScenarioMsgItem(inherited Items[Index]);
end;

end.
