{ ... }: {
  homebrew = {
    enable = true;
    onActivation = {
      # cleanup = "zap" にしない理由:
      # nix-darwin は zap 指定時に `brew bundle ... --zap --force-cleanup` を生成するが、
      # brew-src を 5.1.10 に override した新しい brew では `--force-cleanup` が廃止され
      # `--cleanup`/`--zap` に分割されたため activation が invalid option で失敗する。
      # 5.1.7 に戻すと cask パースクラッシュ（override の本来理由）が再発するため、
      # cleanup 生成を無効化し、新 brew 構文の zap クリーンアップを extraFlags で補う。
      cleanup = "none";
      extraFlags = [ "--cleanup" "--zap" ];
    };
    casks = [
      "1password"
      "claude"
      "devtoys"
      "displaylink"
      "figma-agent"
      "ghostty"
      "google-chrome"
      "raycast"
      "rectangle"
      "slack"
      "superset"
      "visual-studio-code"
      "zoom"
    ];
  };
}
