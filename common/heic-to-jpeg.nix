{ pkgs, username, ... }:
let
  downloadsDir = "/Users/${username}/Downloads";
  logFile = "/tmp/heic-to-jpeg.log";

  # ロジックを .sh に分離: nix 文字列埋め込みだと test-heic-to-jpeg.sh で単体テストできないため
  convertScript = pkgs.writeShellScriptBin "heic-to-jpeg"
    (builtins.readFile ./heic-to-jpeg.sh);
in
{
  launchd.user.agents.heic-to-jpeg = {
    serviceConfig = {
      Program = "${convertScript}/bin/heic-to-jpeg";
      # symlink 生成自体でも再発火するが、ループ防止はスクリプト側の変換済みスキップで担保
      # （ThrottleInterval は発火頻度を抑えるだけの保険）
      WatchPaths = [ downloadsDir ];
      ThrottleInterval = 10;
      StandardOutPath = logFile;
      StandardErrorPath = logFile;
    };
  };
}
