{ pkgs, ... }: {
  imports = [
    ./shell.nix
    ./starship.nix
    ./git.nix
    ./ghostty.nix
    ./claude-code.nix
    ./direnv.nix
    ./lazygit.nix
    ./zellij.nix
    ./zyouz.nix
    ./herdr.nix
  ];

  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    # CLI ツール
    fd
    ripgrep
    duckdb
    awscli2
    ffmpeg
    ncdu
    watch

    # 開発ツール
    claude-code
    gati
    gws
    google-cloud-sdk
    zed-editor

    # Docker 関連
    colima
    docker-client
    docker-buildx
    docker-compose
    lima

    # ランタイム
    nodejs_22
    # herdr の hunk プラグインが `bunx hunkdiff` で hunk バイナリを解決するため
    bun
    # doInstallCheck = false: nixpkgs upstream の Disable.test.ts が失敗するため一時的にテストをスキップ
    (corepack.overrideAttrs (old: { doInstallCheck = false; meta = old.meta // { priority = 0; }; }))

    # IaC
    opentofu

    # その他
    _1password-cli
  ];

  # gh は home.packages ではなく programs.gh で管理する理由:
  # extensions（gh-stack 等）を宣言的に管理できるのは programs.gh のみのため。
  programs.gh = {
    enable = true;
    extensions = with pkgs; [
      gh-stack
    ];
    # 既存の ~/.config/gh/config.yml にあった設定を宣言に取り込んだもの。
    # hosts.yml（認証情報）は home-manager 管理外なのでそのまま残る。
    settings = {
      git_protocol = "https";
      aliases = {
        co = "pr checkout";
      };
    };
  };

  programs.zsh.shellAliases = {
    terraform = "tofu";
  };
}
