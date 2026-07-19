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
      # 入力中に薄いグレーで先読み候補が出るライブ予測変換を無効化
      NSAutomaticInlinePredictionEnabled = false;
    };
  };

  # フォント
  fonts.packages = [
    pkgs.plemoljp-nf
  ];

  # nixpkgs-unstable の nixos-render-docs が --toc-depth を削除したが、
  # nix-darwin(master) がまだ --toc-depth を渡すコードのままで、マニュアル生成が
  # `--toc-depth has been removed` で失敗し switch 全体がブロックされる。
  # nix-darwin が --sidebar-depth へ追従するまでの一時的な回避として、
  # マニュアルを生成する2経路の両方を無効化する。
  #
  # (1) 本システムの darwin-manual-html/darwin-help 生成を止める。
  documentation.enable = false;
  # (2) darwin-uninstaller は eval-config.nix でデフォルト設定の nix-darwin を
  #     内部で丸ごと再評価して同梱するため、上の documentation.enable=false が
  #     届かず、その nested eval が documentation.enable=true のままマニュアルを
  #     生成して同じエラーで落ちる。uninstaller の同梱自体を外して経路を断つ。
  #     失うのは nix-darwin 自体を消す darwin-uninstaller コマンドのみ。
  system.tools.darwin-uninstaller.enable = false;

  # Touch ID で sudo 認証
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 6;
}
