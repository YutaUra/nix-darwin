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

  # Nix の C++ ランタイムライブラリをシステムの場所にシンボリックリンク
  # これにより LD_PRELOAD の jemalloc が必要なライブラリを見つけられる
  home.activation.setupCppRuntime = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    LIBDIR="/lib/aarch64-linux-gnu"
    NIXLIBDIR="${pkgs.stdenv.cc.cc.lib}/lib"

    /usr/bin/sudo mkdir -p "$LIBDIR"

    # libstdc++.so.6
    if [ ! -L "$LIBDIR/libstdc++.so.6" ]; then
      echo "Creating symlink: $LIBDIR/libstdc++.so.6"
      /usr/bin/sudo ln -sf "$NIXLIBDIR/libstdc++.so.6" "$LIBDIR/libstdc++.so.6"
    fi

    # libgcc_s.so.1
    if [ ! -L "$LIBDIR/libgcc_s.so.1" ]; then
      echo "Creating symlink: $LIBDIR/libgcc_s.so.1"
      /usr/bin/sudo ln -sf "$NIXLIBDIR/libgcc_s.so.1" "$LIBDIR/libgcc_s.so.1"
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
