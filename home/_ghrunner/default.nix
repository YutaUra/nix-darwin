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
