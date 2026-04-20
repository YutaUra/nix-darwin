{ pkgs, lib, ... }:
let
  # LD_PRELOAD の jemalloc がシステムの libstdc++ を必要とするため、
  # zsh 起動前に LD_PRELOAD を解除するラッパー
  # wrapProgram を使わない理由:
  # wrapProgram は Nix の bash を shebang に使うが、その bash 自体が
  # libstdc++.so.6 に依存するため、symlink 未作成の環境で起動できない。
  # /bin/sh ならシステムの sh を使うので依存がない。
  zshWrapped = pkgs.symlinkJoin {
    name = "zsh-wrapped";
    paths = [ pkgs.zsh ];
    postBuild = ''
      rm $out/bin/zsh
      echo '#!/bin/sh' > $out/bin/zsh
      echo 'unset LD_PRELOAD' >> $out/bin/zsh
      echo 'exec ${pkgs.zsh}/bin/zsh "$@"' >> $out/bin/zsh
      chmod +x $out/bin/zsh
    '';
  };
in
{
  imports = [
    ../common/shell-base.nix
    ../common/starship.nix
    ../common/git.nix
    ../common/claude-code.nix
    ../common/zellij.nix
    ../common/yazi.nix
    ../common/direnv.nix
  ];

  # zsh パッケージをラッパー版に置き換え
  programs.zsh.package = zshWrapped;

  _claude.extraPermissions = [
    "Read(//quipper/monorepo/**)"
    "Edit(//quipper/monorepo/**)"
    "Write(//quipper/monorepo/**)"
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

  programs.zsh.initContent = ''
    # PATH を「image > aqua > nix > 既存」の順に構成する。
    #
    # 既存値に依存しない形で書く理由:
    # kubectl exec 経由の zsh が何らかの経路で login shell 相当になると
    # /etc/zsh/zprofile 経由で /etc/profile が走り、PATH が
    # /usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games に上書きされる。
    # この場合 $path には既に nix-profile も aqua も含まれないため、単なる
    # 先頭追加では補強にならない。必要なディレクトリを明示的に積み直す。
    typeset -U path
    path=(
      /usr/local/bin
      /usr/bin
      /home/quipper/.local/share/aquaproj-aqua/bin
      /home/quipper/.nix-profile/bin
      $path
    )
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
    fd
    ripgrep
    duckdb
    gh
    gati

    # 開発ツール
    claude-code
    google-cloud-sdk

    # Docker（build 用）
    docker-client
    docker-buildx

    # ランタイム
    nodejs_22
    # doInstallCheck = false: nixpkgs upstream の Disable.test.ts が失敗するため一時的にテストをスキップ
    (corepack.overrideAttrs (old: { doInstallCheck = false; meta = old.meta // { priority = 0; }; }))
    ruby
    python3
  ];

  # install スクリプトを最新版に同期
  home.activation.deployInstallScript = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p /quipper/dotfiles
    install -m 755 ${../../scripts/install} /quipper/dotfiles/install
  '';

  # デフォルトシェルを Nix の zsh に設定
  home.activation.setDefaultShell = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ZSH_PATH="${pkgs.zsh}/bin/zsh"
    if ! /usr/bin/grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
      echo "$ZSH_PATH" | /usr/bin/sudo tee -a /etc/shells
    fi
  '';

  # /usr/local/bin/zsh に zshWrapped の shim を設置する。
  # kubectl exec -- zsh は PATH 解決で /usr/bin/zsh を拾うため、zshWrapped の
  # unset LD_PRELOAD が走らず、後続の Nix プロセス（starship 等）で
  # LD_PRELOAD=/usr/lib/libjemalloc.so.2 が生きたまま走り、jemalloc の
  # libstdc++.so.6 依存を Nix 動的リンカが解決できずに失敗する。
  # /usr/local/bin は PATH で /usr/bin より優先されるので、ここに shim を
  # 置けば zsh の経路だけ確実に zshWrapped を通せる。
  # PATH を並べ替える方式を採らない理由: overlay の path-env.yaml が
  # 「image > aqua > nix」を明示ポリシーとしているため、ruby や node など
  # image 側 CLI の解決順序を崩さないようにする。
  home.activation.installZshShim = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    /usr/bin/sudo /usr/bin/ln -sfn "${zshWrapped}/bin/zsh" /usr/local/bin/zsh
  '';
}
