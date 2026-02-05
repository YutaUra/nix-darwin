{ pkgs, lib, ... }: {
  imports = [
    ../common/shell-base.nix
    ../common/starship.nix
    ../common/git.nix
    ../common/claude-code.nix
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "claude-code"
    ];

  home.stateVersion = "24.11";
  home.sessionVariables = {
    # コンテナ環境で未設定の場合があるため明示的に設定
    USER = "quipper";
  };

  home.packages = with pkgs; [
    # CLI ツール
    ripgrep
    gh

    # 開発ツール
    claude-code

    # Docker（build 用）
    docker-client
    docker-buildx

    # ランタイム
    nodejs_22
    (corepack.overrideAttrs (old: { meta = old.meta // { priority = 0; }; }))
    ruby
  ];

  # Nix の libstdc++ をシステムの場所にシンボリックリンク
  # これにより LD_PRELOAD の jemalloc が libstdc++ を見つけられる
  home.activation.setupLibstdcpp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    LIBDIR="/lib/aarch64-linux-gnu"
    NIXLIB="${pkgs.stdenv.cc.cc.lib}/lib/libstdc++.so.6"

    /usr/bin/sudo mkdir -p "$LIBDIR"
    if [ ! -L "$LIBDIR/libstdc++.so.6" ] || [ "$(/usr/bin/readlink -f "$LIBDIR/libstdc++.so.6" 2>/dev/null)" != "$(/usr/bin/readlink -f "$NIXLIB" 2>/dev/null)" ]; then
      echo "Creating symlink: $LIBDIR/libstdc++.so.6 -> $NIXLIB"
      /usr/bin/sudo ln -sf "$NIXLIB" "$LIBDIR/libstdc++.so.6"
    fi
  '';

  # デフォルトシェルを Nix の zsh に設定
  home.activation.setDefaultShell = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ZSH_PATH="${pkgs.zsh}/bin/zsh"
    if ! /usr/bin/grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
      echo "$ZSH_PATH" | /usr/bin/sudo tee -a /etc/shells
    fi
  '';
}
