{ pkgs, username, ... }: {
  imports = [
    ./homebrew.nix
    # ./auto-update.nix  # 一旦無効化
  ];

  # ユーザー
  users.users.${username}.home = "/Users/${username}";

  # Nix 管理は Determinate Nix に委譲
  nix.enable = false;

  # Determinate Nix のカスタム設定（/etc/nix/nix.custom.conf）
  # nix.enable = false のため nix.settings は使えないので environment.etc で直接書き込む
  environment.etc."nix/nix.custom.conf".text = ''
    extra-substituters = https://yutaura.cachix.org
    extra-trusted-public-keys = yutaura.cachix.org-1:uoMGhQXiri/CBTK1IByqBipk42mkEfWhYo2q9ENseJ8=

    # lazy-trees を無効化する理由:
    # Determinate Nix が /etc/nix/nix.conf で lazy-trees = true を強制している。
    # この機能は flake input を必要なファイルだけ git-protocol で fetch するが、
    # 特定のコミットで「object not found - no match for id」エラーが固定で再現し
    # build できなくなる事象が発生した（cache クリアでも復旧せず）。
    # 全 input を従来通り tarball で完全取得させて回避する。
    lazy-trees = false
  '';

  # system.defaults 等のユーザー固有設定の適用先
  system.primaryUser = username;

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

  # フォント
  fonts.packages = [
    pkgs.plemoljp-nf
  ];

  # Touch ID で sudo 認証
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 6;
}
