unit SerifScenarioFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,SerifScenarioCharaList,SerifScenarioMsgList,
  Vcl.ExtCtrls,SerifScenarioCharaFrame,SerifScenarioMsgFrame, Vcl.Menus;

type
  TFrameSerifScenario = class(TFrame)
    PanelChara: TPanel;
    PanelMsg: TPanel;
    Splitter1: TSplitter;
  private
    { Private 宣言 }
    FFrameChara    : TFrameSerifScenarioChara;
    FFrameMsg      : TFrameSerifScenarioMsg;
  public
    { Public 宣言 }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy;override;

    procedure ShowScenario(Charas: TSerifScenarioCharaList;Msgs : TSerifScenarioMsgList);
  end;

implementation

{$R *.dfm}

{ TFrameSerifScenario }

constructor TFrameSerifScenario.Create(AOwner: TComponent);
begin
  inherited;
  FFrameChara := TFrameSerifScenarioChara.Create(Self);
  FFrameChara.Parent := PanelChara;
  FFrameChara.Align := alClient;

  FFrameMsg := TFrameSerifScenarioMsg.Create(Self);
  FFrameMsg.Parent := PanelMsg;
  FFrameMsg.Align := alClient;
end;

destructor TFrameSerifScenario.Destroy;
begin
  FFrameMsg.Free;
  FFrameChara.Free;
  inherited;
end;

procedure TFrameSerifScenario.ShowScenario(Charas: TSerifScenarioCharaList; Msgs: TSerifScenarioMsgList);
begin
  FFrameChara.ShowCharas(Charas);
  FFrameMsg.ShowMsg(Charas,Msgs);

  FFrameChara.ColumnAlign(1);
  FFrameMsg.ColumnAlign(1);
end;

end.
