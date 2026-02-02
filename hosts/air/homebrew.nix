{ ... }: {
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
    };
    casks = [
      "1password"
      "displaylink"
      "ghostty"
      "google-chrome"
      "raycast"
      "rectangle"
      "slack"
      "visual-studio-code"
    ];
  };
}
