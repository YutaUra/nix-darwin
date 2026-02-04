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

  # /quipper/dotfiles/install を home.file で管理
  # コンテナ起動時に entrypoint 前に実行され、Nix + home-manager をセットアップする
  home.file.".local/share/dotfiles/install" = {
    executable = true;
    text = ''
      #! /usr/bin/env sh

      set -eu

      echo "install スクリプト起動"

      # curl がなければインストール
      if ! command -v curl > /dev/null 2>&1; then
        echo "curl をインストール中..."
        if command -v apt-get > /dev/null 2>&1; then
          sudo apt-get update && sudo apt-get install -y curl
        elif command -v apk > /dev/null 2>&1; then
          sudo apk add curl
        else
          echo "パッケージマネージャーが見つかりません。curl をインストールできません。"
          exit 1
        fi
      fi

      # Nix がインストールされているか確認
      if [ ! -d /nix ]; then
        echo "Nix をインストール中..."
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
      fi

      # Nix の環境変数を読み込む
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      # 環境変数を設定（コンテナ環境で未設定の場合がある）
      export USER="''${USER:-quipper}"
      export HOME="''${HOME:-/home/quipper}"

      # home-manager 設定リポジトリの準備
      HM_DIR="$HOME/.config/home-manager"
      if [ ! -d "$HM_DIR" ]; then
        echo "home-manager 設定を clone 中..."
        git clone https://github.com/YutaUra/nix-darwin.git "$HM_DIR"
      else
        echo "home-manager 設定を更新中..."
        git -C "$HM_DIR" pull
      fi

      # home-manager を適用
      echo "home-manager を適用中..."
      nix run home-manager -- switch --flake "$HM_DIR#qall-k8s" -b backup

      echo "セットアップ完了"
    '';
  };

  # /quipper/dotfiles/install へシンボリックリンクを作成
  home.activation.linkDotfilesInstall = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    mkdir -p /quipper/dotfiles
    ln -sf "$HOME/.local/share/dotfiles/install" /quipper/dotfiles/install
  '';

  # デフォルトシェルを zsh に変更
  home.activation.setDefaultShell = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ZSH_PATH="$HOME/.nix-profile/bin/zsh"
    if ! grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
      echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi
    if [ "$SHELL" != "$ZSH_PATH" ]; then
      sudo chsh -s "$ZSH_PATH" "''${USER:-quipper}"
    fi
  '';
}
