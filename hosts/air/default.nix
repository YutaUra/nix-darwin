{ pkgs, ... }: {
  # Nix 管理は Determinate Nix に委譲
  nix.enable = false;

  nixpkgs.hostPlatform = "aarch64-darwin";

  # 最小限のパッケージで動作確認
  environment.systemPackages = [
    pkgs.vim
  ];

  system.stateVersion = 6;
}
