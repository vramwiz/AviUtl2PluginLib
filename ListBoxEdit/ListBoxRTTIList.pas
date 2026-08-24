unit ListBoxRTTIList;

interface

uses
  Windows, Messages, SysUtils, Classes,   Forms, Dialogs,
  StdCtrls, ExtCtrls,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,RTTIPersistentIni,
  RTTISectionPersistent;

type
  //--------------------------------------------------------------------------
  //  ListBox 表示用 RTTI 要素（最小契約）
  //--------------------------------------------------------------------------
  TListBoxRTTIItem = class(TRTTIPersistentIni)
  private
    FCaption : string;   // ListBox に表示する文字列（必須）
    FHint    : string;   // 補足説明（任意）
  protected
  public
    procedure DeleteItem();virtual;
  published
    property Caption : string read FCaption write FCaption;
    property Hint    : string read FHint    write FHint;
  end;

  // オブジェクトリストを使ったIniファイル管理
type
  TListBoxRTTIList<T: TListBoxRTTIItem, constructor> =class(TRTTISectionPersistentList<T>)
  private
  public
  end;

implementation



{ TListBoxRTTIItem }

procedure TListBoxRTTIItem.DeleteItem;
begin

end;

end.

