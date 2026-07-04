{ pkgs, ... }: {
  # private 固有の home.packages
  home.packages = with pkgs; [
    # AI コーディングエージェント用のターミナルマルチプレクサ
    herdr

    # iOS の Moshi アプリから SSH ハンドシェイク後に UDP へ切り替えて接続するための mosh。
    # 回線切替（Wi-Fi↔モバイル）やスリープをまたいでもセッションが維持される。
    mosh
  ];
}
