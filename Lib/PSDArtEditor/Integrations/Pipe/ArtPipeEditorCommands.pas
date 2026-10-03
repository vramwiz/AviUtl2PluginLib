// 編集フォームの公開APIを、対象IDと世代を確認したパイプ操作へ接続する。
unit ArtPipeEditorCommands;

interface

uses System.JSON, PsdArtEditorForm;

// 実装済みコマンド名を返す。返却したJSONの所有権は呼び出し側へ渡す。
function EditorPipeCommands: TJSONArray;
// 座標・階層・選択状態を含む文書情報を返す。JSONの所有権は呼び出し側へ渡す。
function EditorDocumentJson(Editor: TPsdArtEditorForm): TJSONObject;
// 編集コマンドだけを処理する。未対応ならFalse、成功時のDataは呼び出し側が所有する。
function TryEditorPipeCommand(Editor: TPsdArtEditorForm; const Command: string;
  Args: TJSONObject; out Data: TJSONObject): Boolean;

implementation

uses System.SysUtils, System.Generics.Collections, ArtDocument, ArtPipeProtocol;

function EditorPipeCommands: TJSONArray;
begin
  Result := TJSONArray.Create;
  for var Command in ['status', 'document', 'update-layer', 'save', 'rename-file',
    'new-from-png', 'import-png', 'replace-png', 'move-layer', 'reorder-layer', 'swap-layers',
    'delete-layer', 'create-group', 'select-part',
    'export', 'import', 'progress', 'cancel', 'recover', 'undo', 'redo'] do Result.Add(Command);
end;

function BoundsJson(const Bounds: TArtBounds): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('left', TJSONNumber.Create(Bounds.Left));
  Result.AddPair('top', TJSONNumber.Create(Bounds.Top));
  Result.AddPair('right', TJSONNumber.Create(Bounds.Right));
  Result.AddPair('bottom', TJSONNumber.Create(Bounds.Bottom));
end;

function EditorDocumentJson(Editor: TPsdArtEditorForm): TJSONObject;
var Layers: TJSONArray;
  procedure AddLayers(List: TList<TArtLayer>; const Parent: string);
  var Item: TArtLayer; Json: TJSONObject; Index: Integer;
  begin
    for Index := 0 to List.Count - 1 do begin
      Item := List[Index];
      Json := TJSONObject.Create; Layers.AddElement(Json);
      Json.AddPair('id', Item.Id); Json.AddPair('parentId', Parent); Json.AddPair('name', Item.Name);
      Json.AddPair('index', TJSONNumber.Create(Index));
      Json.AddPair('kind', TJSONNumber.Create(Ord(Item.Kind)));
      Json.AddPair('visible', TJSONBool.Create(Item.Visible));
      Json.AddPair('opacity', TJSONNumber.Create(Item.Opacity));
      Json.AddPair('bounds', BoundsJson(Item.Bounds));
      Json.AddPair('hasMask', TJSONBool.Create(Item.HasMask));
      if Item.HasMask then Json.AddPair('maskBounds', BoundsJson(Item.MaskBounds));
      AddLayers(Item.Children, Item.Id);
    end;
  end;
begin
  if Editor.Document = nil then raise EArtFormat.Create('No PSD is open');
  Result := TJSONObject.Create;
  try
    Result.AddPair('documentId', Editor.Document.SessionId);
    Result.AddPair('revision', UIntToStr(Editor.Document.Revision));
    Result.AddPair('fileName', Editor.FileName);
    Result.AddPair('managed', TJSONBool.Create(Editor.ManagedDocument));
    Result.AddPair('canEdit', TJSONBool.Create(Editor.CanEdit));
    Result.AddPair('modified', TJSONBool.Create(Editor.Modified));
    Result.AddPair('width', TJSONNumber.Create(Editor.Document.Width));
    Result.AddPair('height', TJSONNumber.Create(Editor.Document.Height));
    Result.AddPair('layerOrder', 'topmost-first');
    if Editor.LayerList.Selected = nil then Result.AddPair('selectedLayerId', '')
    else Result.AddPair('selectedLayerId', Editor.LayerList.Selected.Id);
    Layers := TJSONArray.Create; Result.AddPair('layers', Layers);
    AddLayers(Editor.Document.Roots, '');
  except Result.Free; raise; end;
end;

function TryEditorPipeCommand(Editor: TPsdArtEditorForm; const Command: string;
  Args: TJSONObject; out Data: TJSONObject): Boolean;
var Layer, Parent, Other: TArtLayer; Version: UInt64; Name, Path, PreviousId: string;
    Visible, Exclusive: Boolean; Opacity, X, Y, Index: Integer;
  function Target(const Key: string; AllowRoot: Boolean = False): TArtLayer;
  var Id: string;
  begin
    Id := CommandString(Args, Key);
    if AllowRoot and (Id = '') then Exit(nil);
    Result := Editor.Document.FindLayer(Id);
    if Result = nil then raise EArtFormat.Create('Unknown ' + Key);
  end;
  function BooleanArg(const Key: string): Boolean;
  var Value: TJSONValue;
  begin
    Value := Args.GetValue(Key);
    if not (Value is TJSONBool) then raise EArtFormat.Create('Boolean required: ' + Key);
    Result := TJSONBool(Value).AsBoolean;
  end;
  procedure RequireManaged;
  begin
    if not Editor.ManagedDocument then
      raise EArtFormat.Create('外部PSDでは補助記号・表示状態・切替だけを変更できます。');
  end;
begin
  Data := nil;
  Result := (Command = 'document') or (Command = 'update-layer') or (Command = 'save') or
    (Command = 'rename-file') or (Command = 'new-from-png') or (Command = 'import-png') or
    (Command = 'replace-png') or (Command = 'move-layer') or (Command = 'reorder-layer') or
    (Command = 'swap-layers') or (Command = 'delete-layer') or (Command = 'create-group') or
    (Command = 'select-part');
  if not Result then Exit;
  if Command = 'document' then begin Data := EditorDocumentJson(Editor); Exit; end;
  Editor.LayerList.FinishRename(True);
  if Editor.Document = nil then raise EArtFormat.Create('No PSD is open');
  if CommandString(Args, 'documentId') <> Editor.Document.SessionId then
    raise EArtFormat.Create('Stale document');
  if not TryStrToUInt64(CommandString(Args, 'ifRevision'), Version) or
    (Version <> Editor.Document.Revision) then raise EArtFormat.Create('Stale revision');
  if Command = 'save' then Editor.SavePsdFile(Editor.FileName)
  else if Command = 'rename-file' then Editor.RenamePsdFile(CommandString(Args, 'fileName'))
  else if Command = 'new-from-png' then begin
    RequireManaged;
    if Editor.Modified then raise EArtFormat.Create('Save the current document before PNG initialization');
    Editor.NewFromPng(CommandString(Args, 'fileName'));
  end else begin
    PreviousId := '';
    if Editor.LayerList.Selected <> nil then PreviousId := Editor.LayerList.Selected.Id;
    try
      if Command = 'update-layer' then begin
        Layer := Target('layerId'); Name := Layer.Name; Visible := Layer.Visible; Opacity := Layer.Opacity;
        if Args.GetValue('name') <> nil then Name := CommandString(Args, 'name');
        if Args.GetValue('visible') <> nil then Visible := BooleanArg('visible');
        if Args.GetValue('opacity') <> nil then begin
          RequireManaged; Opacity := CommandInteger(Args, 'opacity');
          if (Opacity < 0) or (Opacity > 255) then raise EArtFormat.Create('Opacity must be between 0 and 255');
        end;
        Editor.LayerList.Selected := Layer;
        Editor.ApplySelectedLayer(Name, Visible, Byte(Opacity));
      end else if Command = 'select-part' then Editor.SelectPart(Target('layerId'))
      else begin
        RequireManaged;
        if Command = 'delete-layer' then Editor.DeleteLayer(Target('layerId'))
        else if Command = 'reorder-layer' then begin
          Layer := Target('layerId'); Parent := Target('parentId', True);
          Index := CommandInteger(Args, 'index'); Editor.ReorderLayer(Layer, Parent, Index);
        end else if Command = 'swap-layers' then begin
          Layer := Target('layerId'); Other := Target('otherLayerId'); Editor.SwapLayers(Layer, Other);
        end else if (Command = 'import-png') or (Command = 'create-group') then begin
          Layer := Target('parentId', True);
          if (Layer <> nil) and (Layer.Kind <> alkGroup) then raise EArtFormat.Create('Parent must be a group');
          if Command = 'import-png' then begin
            Path := CommandString(Args, 'fileName'); Editor.LayerList.Selected := Layer;
            Editor.ImportPngFile(Path);
          end else begin
            Name := CommandString(Args, 'name'); Exclusive := BooleanArg('exclusive');
            if (Trim(Name) = '') or (Length(Name) > 255) or (Exclusive and (Length(Name) = 255)) then
              raise EArtFormat.Create('Invalid layer name');
            Editor.LayerList.Selected := Layer; Editor.CreateGroup(Name, Exclusive);
          end;
        end else begin
          Layer := Target('layerId');
          if Layer.Kind <> alkImage then raise EArtFormat.Create('Image layer required');
          if Command = 'replace-png' then begin
            Path := CommandString(Args, 'fileName'); Editor.LayerList.Selected := Layer;
            Editor.ReplaceSelectedPng(Path);
          end else begin
            X := CommandInteger(Args, 'x'); Y := CommandInteger(Args, 'y');
            Editor.LayerList.Selected := Layer; Editor.MoveSelectedLayer(X, Y);
          end;
        end;
      end;
    except Editor.LayerList.Selected := Editor.Document.FindLayer(PreviousId); raise; end;
  end;
  Data := EditorDocumentJson(Editor);
end;

end.
