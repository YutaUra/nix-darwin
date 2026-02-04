{ pkgs, ... }: {
  imports = [
    ../common/shell-base.nix
    ../common/starship.nix
    ../common/git.nix
    ../common/claude-code.nix
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
}
