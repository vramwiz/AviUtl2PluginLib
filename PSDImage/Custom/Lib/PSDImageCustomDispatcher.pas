unit PSDImageCustomDispatcher;

interface

uses
  PsdImage, PSDImageCustomKindDetector, PSDImageElementList;

// PSD種別ごとの独自マーカー補正を行う。
procedure ApplyCustomMarkers(PsdImage: TPSDImage; Kind: TPSDImageKind);
// 自動仮想マーカー補完で不足した独自マーカーを補う。
procedure ApplyCustomFallbackVirtualMarkers(PsdImage: TPSDImage; Kind: TPSDImageKind);
// PSD種別ごとの独自表示連動ルールを登録する。
procedure ApplyCustomExclusiveGroups(PsdImage: TPSDImage; Kind: TPSDImageKind);
// PSD種別ごとの初期表示補正を行う。
procedure ApplyCustomInitialVisibility(PsdImage: TPSDImage; Kind: TPSDImageKind);
// PSD種別ごとの独自分類補正を行う。
procedure ApplyCustomElementList(PsdImage: TPSDImage; Kind: TPSDImageKind;
  Elements: TPSDElementList);
// 現在のPSDレイヤーツリーをテキストファイルへ保存する。
procedure SavePSDMarkerDebugTree(PsdImage: TPSDImage; Kind: TPSDImageKind;
  const FileName: string);

implementation

uses
  System.SysUtils, System.Classes, PsdImageTree, PSDImageCustomMarkerUtils,
  PSDImageCustomShimaDonpachiMei, PSDImageCustomKarai,
  PSDImageCustomKaraiKotonoha,
  PSDImageCustomKaraiKotonohaAoi,
  PSDImageCustomKosukeSantaMaria, PSDImageCustomMatcher,
  PSDImageCustomYumeNoOwari, PSDImageCustomNishimiya,
  PSDImageCustomKamiyoshi, PSDImageCustomAzuki, PSDImageCustomBlueberry,
  PSDImageCustomPetenshi, PSDImageCustomNanroku, PSDImageCustomAjishio,
  PSDImageCustomMunisaga, PSDImageCustomFurasuko, PSDImageCustomMoiky,
  PSDImageCustomPepechi, PSDImageCustomMiko, PSDImageCustomTaotao,
  PSDImageCustomSaiyouWagashi;

function KindToText(Kind: TPSDImageKind): string;
begin
  case Kind of
    pikKarai:
      Result := 'pikKarai';
    pikShimaDonpachiMei:
      Result := 'pikShimaDonpachiMei';
    pikKosukeSantaMaria:
      Result := 'pikKosukeSantaMaria';
    pikMatcher:
      Result := 'pikMatcher';
    pikYumeNoOwari:
      Result := 'pikYumeNoOwari';
    pikNishimiya:
      Result := 'pikNishimiya';
    pikKamiyoshiGeneric:
      Result := 'pikKamiyoshiGeneric';
    pikKamiyoshiShikokuMetan:
      Result := 'pikKamiyoshiShikokuMetan';
    pikKamiyoshiNo7:
      Result := 'pikKamiyoshiNo7';
    pikAzuki:
      Result := 'pikAzuki';
    pikBlueberry:
      Result := 'pikBlueberry';
    pikPetenshi:
      Result := 'pikPetenshi';
    pikNanroku:
      Result := 'pikNanroku';
    pikYumeNoOwariKiritanSuwariE:
      Result := 'pikYumeNoOwariKiritanSuwariE';
    pikMunisaga:
      Result := 'pikMunisaga';
    pikAjishio:
      Result := 'pikAjishio';
    pikFurasuko:
      Result := 'pikFurasuko';
    pikKaraiKotonoha:
      Result := 'pikKaraiKotonoha';
    pikKaraiKotonohaAoi:
      Result := 'pikKaraiKotonohaAoi';
    pikMoikyShikokuMetan:
      Result := 'pikMoikyShikokuMetan';
    pikMoikyAnkomon:
      Result := 'pikMoikyAnkomon';
    pikMoikyZundamon:
      Result := 'pikMoikyZundamon';
    pikPepechi:
      Result := 'pikPepechi';
    pikMikoDamon:
      Result := 'pikMikoDamon';
    pikTaotaoShikokuMetan:
      Result := 'pikTaotaoShikokuMetan';
    pikSaiyouWagashiTsukuyomi:
      Result := 'pikSaiyouWagashiTsukuyomi';
    pikFurasukoKiritan:
      Result := 'pikFurasukoKiritan';
  else
    Result := 'pikNone';
  end;
end;

procedure DumpTree(Tree: TPsdFileTree; Depth: Integer; Lines: TStrings);
var
  i: Integer;
  ChildTrees: TPsdFileTrees;
  Name: string;
  Marker: string;
begin
  if Tree = nil then Exit;

  Name := LayerName(Tree);
  Marker := MarkerOfName(Name);
  if Marker = '' then
    Marker := ' ';

  Lines.Add(Format('D=%d V=%d M=%s Name="%s"',
    [Depth, Ord(Tree.Visible), Marker, Name]));

  ChildTrees := TPsdFileTrees(Tree.Trees);
  if ChildTrees = nil then Exit;

  for i := 0 to ChildTrees.Count - 1 do
    DumpTree(ChildTrees[i], Depth + 1, Lines);
end;

procedure SavePSDMarkerDebugTree(PsdImage: TPSDImage; Kind: TPSDImageKind;
  const FileName: string);
var
  i: Integer;
  Lines: TStringList;
begin
  if PsdImage = nil then Exit;
  if Trim(FileName) = '' then Exit;

  Lines := TStringList.Create;
  try
    Lines.Add(Format('[PSDMarkerDump] Kind=%s Caption="%s" File="%s"',
      [KindToText(Kind), PSDImageKindCaption(Kind), PsdImage.FileName]));
    if Trim(PsdImage.DebugMarkerRoute) <> '' then
      Lines.Add(Format('[PSDMarkerRoute] %s', [PsdImage.DebugMarkerRoute]));
    Lines.Add('');

    for i := 0 to PsdImage.Trees.Count - 1 do
      DumpTree(PsdImage.Trees[i], 0, Lines);

    Lines.Add('');
    Lines.Add('[PSDMarkerDumpEnd]');
    Lines.SaveToFile(FileName, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

procedure ApplyCustomMarkers(PsdImage: TPSDImage; Kind: TPSDImageKind);
begin
  case Kind of
    pikKarai:
      ApplyKaraiMarkers(PsdImage);
    pikKaraiKotonoha:
      ApplyKaraiKotonohaMarkers(PsdImage);
    pikKaraiKotonohaAoi:
      ApplyKaraiKotonohaAoiMarkers(PsdImage);
    pikKosukeSantaMaria:
      ApplyKosukeSantaMariaMarkers(PsdImage);
    pikShimaDonpachiMei:
      ApplyShimaDonpachiMeiMarkers(PsdImage);
    pikMatcher:
      ApplyMatcherMarkers(PsdImage);
    pikYumeNoOwari:
      ApplyYumeNoOwariMarkers(PsdImage);
    pikNishimiya:
      begin
        ApplyNishimiyaTreeRelinks(PsdImage);
        ApplyNishimiyaMarkers(PsdImage);
      end;
    pikAzuki:
      ApplyAzukiMarkers(PsdImage);
    pikBlueberry:
      ApplyBlueberryMarkers(PsdImage);
    pikPetenshi:
      ApplyPetenshiMarkers(PsdImage);
    pikNanroku:
      ApplyNanrokuMarkers(PsdImage);
    pikMunisaga:
      ApplyMunisagaMarkers(PsdImage);
    pikAjishio:
      ApplyAjishioMarkers(PsdImage);
    pikFurasuko:
      ApplyFurasukoMarkers(PsdImage);
    pikFurasukoKiritan:
      ApplyFurasukoKiritanMarkers(PsdImage);
    pikMoikyShikokuMetan:
      ApplyMoikyShikokuMetanMarkers(PsdImage);
    pikMoikyAnkomon:
      ApplyMoikyAnkomonMarkers(PsdImage);
    pikMoikyZundamon:
      ApplyMoikyZundamonMarkers(PsdImage);
    pikPepechi:
      ApplyPepechiMarkers(PsdImage);
    pikTaotaoShikokuMetan:
      ApplyTaotaoShikokuMetanMarkers(PsdImage);
    pikSaiyouWagashiTsukuyomi:
      ApplySaiyouWagashiTsukuyomiMarkers(PsdImage);
  end;
end;

procedure ApplyCustomFallbackVirtualMarkers(PsdImage: TPSDImage; Kind: TPSDImageKind);
begin
  case Kind of
    pikMoikyZundamon:
      ApplyMoikyZundamonFallbackPlusMarkers(PsdImage);
  end;
end;

procedure ApplyCustomExclusiveGroups(PsdImage: TPSDImage; Kind: TPSDImageKind);
begin
  case Kind of
    pikKosukeSantaMaria:
      ApplyKosukeSantaMariaExclusiveGroups(PsdImage);
    pikYumeNoOwariKiritanSuwariE:
      ApplyYumeNoOwariKiritanSuwariEExclusiveGroups(PsdImage);
    pikKamiyoshiGeneric,
    pikKamiyoshiShikokuMetan,
    pikKamiyoshiNo7:
      ApplyKamiyoshiExclusiveGroups(PsdImage);
    pikAzuki:
      ApplyAzukiExclusiveGroups(PsdImage);
    pikBlueberry:
      ApplyBlueberryExclusiveGroups(PsdImage);
    pikPetenshi:
      ApplyPetenshiExclusiveGroups(PsdImage);
    pikNanroku:
      ApplyNanrokuExclusiveGroups(PsdImage);
    pikAjishio:
      ApplyAjishioExclusiveGroups(PsdImage);
    pikKaraiKotonoha:
      ApplyKaraiKotonohaExclusiveGroups(PsdImage);
    pikKaraiKotonohaAoi:
      ApplyKaraiKotonohaAoiExclusiveGroups(PsdImage);
    pikMoikyShikokuMetan:
      ApplyMoikyShikokuMetanExclusiveGroups(PsdImage);
    pikMoikyAnkomon:
      ApplyMoikyAnkomonExclusiveGroups(PsdImage);
    pikPepechi:
      ApplyPepechiExclusiveGroups(PsdImage);
  end;
end;

procedure ApplyCustomInitialVisibility(PsdImage: TPSDImage; Kind: TPSDImageKind);
begin
  case Kind of
    pikFurasuko:
      ApplyFurasukoInitialVisibility(PsdImage);
    pikKarai:
      ApplyKaraiInitialVisibility(PsdImage);
    pikYumeNoOwari:
      ApplyYumeNoOwariInitialVisibility(PsdImage);
    pikYumeNoOwariKiritanSuwariE:
      ApplyYumeNoOwariKiritanSuwariEInitialVisibility(PsdImage);
    pikNishimiya:
      ApplyNishimiyaInitialVisibility(PsdImage);
    pikKamiyoshiGeneric,
    pikKamiyoshiShikokuMetan,
    pikKamiyoshiNo7:
      ApplyKamiyoshiInitialVisibility(PsdImage);
    pikAzuki:
      ApplyAzukiInitialVisibility(PsdImage);
    pikBlueberry:
      ApplyBlueberryInitialVisibility(PsdImage);
    pikKosukeSantaMaria:
      ApplyKosukeSantaMariaInitialVisibility(PsdImage);
    pikPetenshi:
      ApplyPetenshiInitialVisibility(PsdImage);
    pikNanroku:
      ApplyNanrokuInitialVisibility(PsdImage);
    pikMunisaga:
      ApplyMunisagaInitialVisibility(PsdImage);
    pikAjishio:
      ApplyAjishioInitialVisibility(PsdImage);
    pikKaraiKotonoha:
      ApplyKaraiKotonohaInitialVisibility(PsdImage);
    pikKaraiKotonohaAoi:
      ApplyKaraiKotonohaAoiInitialVisibility(PsdImage);
    pikMikoDamon:
      ApplyMikoDamonInitialVisibility(PsdImage);
    pikSaiyouWagashiTsukuyomi:
      ApplySaiyouWagashiTsukuyomiInitialVisibility(PsdImage);
    pikFurasukoKiritan:
      ApplyFurasukoKiritanInitialVisibility(PsdImage);
  end;
end;

procedure ApplyCustomElementList(PsdImage: TPSDImage; Kind: TPSDImageKind;
  Elements: TPSDElementList);
begin
  case Kind of
    pikKarai, pikKosukeSantaMaria:
      ApplyKaraiArmElementList(Elements);
  end;

  case Kind of
    pikKarai:
      ApplyKaraiBodyElementList(PsdImage, Elements);
    pikKaraiKotonoha:
      ApplyKaraiKotonohaElementList(PsdImage, Elements);
    pikKaraiKotonohaAoi:
      ApplyKaraiKotonohaAoiElementList(PsdImage, Elements);
    pikKosukeSantaMaria:
      ApplyKosukeSantaMariaElementList(PsdImage, Elements);
    pikYumeNoOwari:
      ApplyYumeNoOwariElementCaptions(Elements);
    pikMoikyShikokuMetan:
      ApplyMoikyShikokuMetanElementList(PsdImage, Elements);
    pikMoikyZundamon:
      ApplyMoikyZundamonElementList(PsdImage, Elements);
  end;
end;

end.
