{ pkgs, ... }: {
  imports = [
    ./shell.nix
    ./starship.nix
    ./git.nix
  ];

  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    # CLI ツール
    ripgrep
    awscli2
    ffmpeg
    ncdu

    # 開発ツール
    gh

    # Docker 関連
    colima
    docker-client
    docker-buildx
    docker-compose
    lima

    # ランタイム
    nodejs_22

    # その他
    _1password-cli
  ];
}
