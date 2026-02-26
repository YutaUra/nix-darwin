{ pkgs, ... }: {
  imports = [
    ./shell.nix
    ./starship.nix
    ./git.nix
    ./ghostty.nix
    ./claude-code.nix
  ];

  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    # CLI ツール
    ripgrep
    awscli2
    ffmpeg
    ncdu
    watch

    # 開発ツール
    claude-code
    gh

    # Docker 関連
    colima
    docker-client
    docker-buildx
    docker-compose
    lima

    # ランタイム
    nodejs_22
    # doInstallCheck = false: nixpkgs upstream の Disable.test.ts が失敗するため一時的にテストをスキップ
    (corepack.overrideAttrs (old: { doInstallCheck = false; meta = old.meta // { priority = 0; }; }))

    # IaC
    opentofu

    # その他
    _1password-cli
  ];

  programs.zsh.shellAliases = {
    terraform = "tofu";
  };
}
