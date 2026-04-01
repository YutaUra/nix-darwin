{ lib, ... }: {
  imports = [ ./shell-base.nix ];

  programs.zsh.initContent = lib.mkBefore ''
    # colima 自動起動（バックグラウンド）
    # シェル起動をブロックしないよう非同期で実行
    (
      if ! colima list --json 2>/dev/null | jq -e 'select(.name=="default" and .status=="Running")' >/dev/null 2>&1; then
        colima start >/dev/null 2>&1
      fi
    ) &!
  '';
}
