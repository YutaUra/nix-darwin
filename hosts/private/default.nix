{ ... }: {
  imports = [
    ../../common
    ../../profiles/private
    ./homebrew.nix
  ];

  # iOS の Moshi アプリ接続に必要な Remote Login(OpenSSH) を宣言的に有効化しない理由:
  # macOS では Remote Login の切り替えに Full Disk Access(TCC) が必要で、systemsetup も
  # switch 時の activation script も TCC に阻まれて失敗する（switch 全体を壊すリスクもある）。
  # そのため「システム設定 > 一般 > 共有 > リモートログイン」を手動で一度 ON にする運用とする。

  nixpkgs.hostPlatform = "aarch64-darwin";
}
