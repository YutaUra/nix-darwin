{ pkgs, username, ... }: {
  # ユーザー
  users.users.${username}.home = "/Users/${username}";
  # Nix 管理は Determinate Nix に委譲
  nix.enable = false;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "1password-cli"
    ];

  # 最小限のパッケージで動作確認
  environment.systemPackages = [
    pkgs.vim
  ];

  # Touch ID で sudo 認証
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 6;
}
