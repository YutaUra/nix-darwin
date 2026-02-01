{ pkgs, username, ... }: {
  # ユーザー
  users.users.${username}.home = "/Users/${username}";
  # Nix 管理は Determinate Nix に委譲
  nix.enable = false;

  # system.defaults 等のユーザー固有設定の適用先
  system.primaryUser = username;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "1password-cli"
    ];

  environment.systemPackages = [
    pkgs.vim
  ];

  # macOS システム設定
  system.defaults = {
    dock = {
      autohide = true;
      orientation = "left";
    };

    finder = {
      FXPreferredViewStyle = "glyv";
    };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      ApplePressAndHoldEnabled = false;
      AppleEnableSwipeNavigateWithScrolls = false;
    };
  };

  # Touch ID で sudo 認証
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 6;
}
