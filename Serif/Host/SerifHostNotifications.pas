unit SerifHostNotifications;

// 共有Serifから製品ホスト固有の表示同期へ通知するための最小境界。
// 未登録ホストでは通知を捨て、共有UI自体の操作は継続する。

interface

type
  TSerifHostVisualRefreshProc = procedure;

procedure RegisterSerifHostVisualRefresh(
  AProc: TSerifHostVisualRefreshProc);
procedure NotifySerifHostVisualRefresh;

implementation

var
  GVisualRefreshProc: TSerifHostVisualRefreshProc;

procedure RegisterSerifHostVisualRefresh(
  AProc: TSerifHostVisualRefreshProc);
begin
  GVisualRefreshProc := AProc;
end;

procedure NotifySerifHostVisualRefresh;
begin
  if not Assigned(GVisualRefreshProc) then Exit;
  try
    GVisualRefreshProc;
  except
    // 製品固有の補助更新失敗を共有Serifの編集操作へ伝播させない。
  end;
end;

end.
