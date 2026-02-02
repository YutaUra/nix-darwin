{ ... }: {
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
    };
    casks = [
      "1password"
      "displaylink"
      "font-blex-mono-nerd-font"
      "font-cica"
      "ghostty"
      "google-chrome"
      "raycast"
      "rectangle"
      "slack"
      "visual-studio-code"
    ];
  };
}
