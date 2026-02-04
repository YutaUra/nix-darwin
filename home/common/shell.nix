{ lib, ... }: {
  imports = [ ./shell-base.nix ];

  programs.zsh.initContent = lib.mkBefore ''
    # colima 自動起動
    if ! colima list --json 2>/dev/null | jq -e 'select(.name=="default" and .status=="Running")' >/dev/null; then
      colima start
    fi
  '';
}
