unit PSDImageElementDisplayList;

interface

uses
  System.SysUtils,
  PSDImageElementList;

type
  // 画面ごとに必要な大分類/小分類の見せ方を切り替えるための用途。
  TPSDElementDisplayPurpose = (
    edpFaceWheel,
    edpEyeBlink,
    edpLipTalk,
    edpLipSong,
    edpAnime
  );

// 元のPSD分類リストから、指定画面で表示する分類リストを作る。
procedure BuildPSDDisplayElements(Source, Dest: TPSDElementList;
  Purpose: TPSDElementDisplayPurpose);

// 表示用に並べ替えた小分類から、元PSD上の Group/Element/Part 名を復元する。
function ResolveDisplayPart(Source: TPSDElementList; DisplayPart: TPSDElementPart;
  out GroupName, ElementName, PartName: string): Boolean; overload;
function ResolveDisplayPart(Source: TPSDElementList; DisplayElement: TPSDElementItem;
  DisplayPart: TPSDElementPart; out GroupName, ElementName, PartName: string): Boolean; overload;

implementation

procedure BuildPSDDisplayElements(Source, Dest: TPSDElementList;
  Purpose: TPSDElementDisplayPurpose);
begin
  if Dest = nil then
    Exit;

  Dest.Clear;
  if Source = nil then
    Exit;

  // 表示用リストは、実レイヤーへ反映するルート索引とは分けて扱う。
  // 今後、画面別に分類を組み替える場合も Dest だけを編集し、
  // Part.ElementPartIndex は元分類へ戻るための参照として維持する。
  Dest.Assign(Source);
end;

// 表示用 Part が保持している元分類インデックスから、実際に操作する分類名を引き直す。
function ResolveDisplayPart(Source: TPSDElementList; DisplayPart: TPSDElementPart;
  out GroupName, ElementName, PartName: string): Boolean; overload;
begin
  GroupName := '';
  ElementName := '';
  PartName := '';
  Result := False;

  if (Source = nil) or (DisplayPart = nil) then
    Exit;
  if DisplayPart.ElementPartIndex = 0 then
    Exit;

  Result := Source.IndexToElementPartName(DisplayPart.ElementPartIndex,
    GroupName, ElementName, PartName);
end;

function ResolveDisplayPart(Source: TPSDElementList; DisplayElement: TPSDElementItem;
  DisplayPart: TPSDElementPart; out GroupName, ElementName, PartName: string): Boolean; overload;
var
  i, j: Integer;
  SourceElement: TPSDElementItem;
  SourcePart: TPSDElementPart;
begin
  GroupName := '';
  ElementName := '';
  PartName := '';
  Result := False;

  if (Source = nil) or (DisplayElement = nil) or (DisplayPart = nil) then
    Exit;

  // 同じ ElementPartIndex が別分類にも存在するPSDでは、表示行の分類を優先する。
  for i := 0 to Source.Count - 1 do
  begin
    SourceElement := Source[i];
    if (SourceElement = nil) or
       (not SameText(Trim(SourceElement.Group), Trim(DisplayElement.Group))) or
       (not SameText(Trim(SourceElement.Name), Trim(DisplayElement.Name))) then
      Continue;

    for j := 0 to SourceElement.Parts.Count - 1 do
    begin
      SourcePart := SourceElement.Parts[j];
      if SourcePart = nil then
        Continue;

      if ((DisplayPart.ElementPartIndex <> 0) and
          (SourcePart.ElementPartIndex = DisplayPart.ElementPartIndex)) or
         SameText(Trim(SourcePart.Name), Trim(DisplayPart.Name)) then
      begin
        GroupName := SourceElement.Group;
        ElementName := SourceElement.Name;
        PartName := SourcePart.Name;
        Exit(True);
      end;
    end;
  end;

  Result := ResolveDisplayPart(Source, DisplayPart, GroupName, ElementName, PartName);
end;

end.
