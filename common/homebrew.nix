{ ... }: {
  homebrew = {
    enable = true;
    onActivation = {
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
      "visual-studio-code"
      "zoom"
    ];
  };
}
