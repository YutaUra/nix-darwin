{ pkgs, ... }: {
  # GitHub Actions self-hosted runner 専用ユーザー(_ghrunner)の home 環境。
  #
  # runner バイナリ本体は nixpkgs の github-runner で宣言的に管理する。
  # Nix 管理下に置かないのは以下だけ:
  #   - 登録トークン（秘密情報）
  #   - 実行時状態（$RUNNER_ROOT = ~/.github-runner 配下の .runner / .credentials / _work 等）
  # つまりインストールは Nix、登録(config.sh)と常駐だけ手動、という分離にしている。
  #
  # home/common/default.nix を import しない理由:
  # common は claude-code や colima 自動起動・ghostty 等、対話開発向けの重い設定を含む。
  # 無人の CI runner には不要なので、OS 共通のシェル設定(shell-base)だけを取り込み軽量に保つ。
  imports = [
    ../common/shell-base.nix
  ];

  home.stateVersion = "24.11";

  # runner のロケールを UTF-8 に固定する。
  # macOS は Terminal.app 以外の起動経路(sudo -i / launchd / SSH)では LANG を export せず、
  # その場合 locale が C(POSIX/ASCII) にフォールバックして UTF-8 の multibyte を壊す。
  # CI が起動経路で挙動を変えないよう、login shell で LANG を明示する。
  # ja_JP.UTF-8 ではなく en_US.UTF-8 を使う理由: 地域依存の書式(日付/数値/ソート)を避け、
  # ctype のみ UTF-8 にするため。LC_ALL は設定しない(ツール側の個別上書きを潰さない)。
  #
  # なお login shell 経由での起動を前提とした固定である点に注意。
  # 将来 launchd 常駐へ切り替える場合は launchd の EnvironmentVariables 側で LANG を渡す必要がある。
  home.sessionVariables = {
    LANG = "en_US.UTF-8";
  };

  home.packages = with pkgs; [
    # GitHub Actions self-hosted runner 本体（config.sh / run.sh / Runner.Listener）。
    # nixpkgs 版は self-update を無効化するパッチ済みで、read-only な Nix store から
    # 実行しても壊れない。可変状態は $RUNNER_ROOT(=~/.github-runner) に書かれる。
    github-runner

    # GitHub CLI。runner ユーザーの認証補助やワークフローの確認・runner 登録トークン取得
    # (`gh api ...`)などに使う。
    gh

    # actions/checkout など多くのワークフローが前提とする git を
    # store 版で固定し、Xcode CLT の git バージョンに依存しないようにする。
    git
  ];
}
