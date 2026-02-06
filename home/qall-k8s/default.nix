{ pkgs, lib, ... }:
let
  # LD_PRELOAD の jemalloc がシステムの libstdc++ を必要とするため、
  # zsh 起動前に LD_PRELOAD を解除するラッパー
  zshWrapped = pkgs.symlinkJoin {
    name = "zsh-wrapped";
    paths = [ pkgs.zsh ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zsh --unset LD_PRELOAD
    '';
  };
in
{
  imports = [
    ../common/shell-base.nix
    ../common/starship.nix
    ../common/git.nix
    ../common/claude-code.nix
  ];

  # zsh パッケージをラッパー版に置き換え
  programs.zsh.package = zshWrapped;

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "claude-code"
    ];

  home.stateVersion = "24.11";
  home.sessionVariables = {
    # コンテナ環境で未設定の場合があるため明示的に設定
    USER = "quipper";
    # NOTE: LD_LIBRARY_PATH は sessionVariables ではなく zsh initContent で設定
    # sessionVariables で設定すると VS Code Server など非シェルプロセスにも影響し、
    # システムの glibc (2.35) と Nix の libstdc++ (glibc 2.38 要求) の不整合でエラーになる
  };

  # シェル内でのみ LD_LIBRARY_PATH を設定（VS Code Server などには影響しない）
  programs.zsh.initContent = ''
    # Nix パッケージが必要とする C++ ランタイムライブラリのパスを設定
    # LD_PRELOAD の jemalloc や一部の Nix パッケージが libstdc++.so.6 を必要とする
    export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  '';

  # bash 起動時に自動で zsh に切り替え（kubectl exec -- bash 対応）
  programs.bash = {
    enable = true;
    initExtra = ''
      # インタラクティブシェルかつ zsh が利用可能な場合、zsh に切り替え
      if [[ $- == *i* ]] && command -v zsh &> /dev/null; then
        exec zsh
      fi
    '';
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
