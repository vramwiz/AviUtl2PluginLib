unit PluginFilterSerifDrawTextEditorFrame;

interface

// 文字設定用の既存VCL部品を設定フォームへ提供するフレーム。

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  TFrameSerifDrawTextEditor = class(TFrame)
    ColorPanel: TPanel;
    FontComboBox: TComboBox;
    LayerComboBox: TComboBox;
    PreviewHostPanel: TPanel;
    TopPanel: TPanel;
  end;

implementation

{$R *.dfm}

end.
