{ pkgs, ... }: {
  # private 固有の home.packages
  home.packages = with pkgs; [
    # AI コーディングエージェント用のターミナルマルチプレクサ
    herdr
  ];
}
