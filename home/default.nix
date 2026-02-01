{ pkgs, ... }: {
  home.stateVersion = "24.11";

  # 動作確認用に1つだけ
  home.packages = [
    pkgs.ripgrep
  ];
}
