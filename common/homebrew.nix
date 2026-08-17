{ ... }: {
  homebrew = {
    enable = true;
    onActivation = {
      # extraFlags の "--cleanup --zap" にしない理由: 確認プロンプトで activation が
      # 対話待ちになる。cleanup = "zap" が生成する --force-cleanup は brew 6 で復活済み。
      cleanup = "zap";
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
