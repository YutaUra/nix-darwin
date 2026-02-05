{ pkgs, lib, ... }:
let
  # Nix バイナリが必要とする libstdc++ を含むライブラリパス
  nixLdLibraryPath = "${pkgs.stdenv.cc.cc.lib}/lib:/usr/lib/aarch64-linux-gnu";
in
{
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
    NIX_LD = "/lib/ld-linux-aarch64.so.1";
    # Nix の libstdc++ を優先し、システムライブラリをフォールバックとして使用
    NIX_LD_LIBRARY_PATH = nixLdLibraryPath;
  };

  # LD_PRELOAD に設定された共有ライブラリ（jemalloc 等）が Nix 環境と競合するため解除
  programs.zsh.initContent = lib.mkBefore ''
    unset LD_PRELOAD
  '';

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

  # /usr/bin/zsh をラッパーに置き換え（kubectl exec -- zsh で使われるため）
  home.activation.setupSystemZshWrapper = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    WRAPPER='#!/bin/sh
# Nix zsh ラッパー - LD_PRELOAD の jemalloc が Nix 環境と競合するため unset
export USER="''${USER:-quipper}"
export HOME="''${HOME:-/home/quipper}"
unset LD_PRELOAD
exec ${pkgs.zsh}/bin/zsh "$@"'

    # /usr/bin/zsh がラッパーでなければ置き換え
    if [ ! -f /usr/bin/zsh ] || ! /usr/bin/grep -q "unset LD_PRELOAD" /usr/bin/zsh 2>/dev/null; then
      echo "Setting up /usr/bin/zsh wrapper..."
      echo "$WRAPPER" | /usr/bin/sudo tee /usr/bin/zsh > /dev/null
      /usr/bin/sudo chmod +x /usr/bin/zsh
    fi
  '';

  # デフォルトシェルを /usr/bin/zsh に設定
  home.activation.setDefaultShell = lib.hm.dag.entryAfter [ "setupSystemZshWrapper" ] ''
    ZSH_PATH="/usr/bin/zsh"
    if ! /usr/bin/grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
      echo "$ZSH_PATH" | /usr/bin/sudo tee -a /etc/shells
    fi
    if [ "$SHELL" != "$ZSH_PATH" ]; then
      /usr/bin/sudo chsh -s "$ZSH_PATH" "''${USER:-quipper}"
    fi
  '';
}
