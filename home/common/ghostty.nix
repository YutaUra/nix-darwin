{ lib, ... }: {
  programs.ghostty = {
    enable = true;
    package = null;  # macOS では Homebrew Cask でインストール済み
    enableZshIntegration = true;
    settings = {
      font-family = "PlemolJP Console NF";
      font-size = 14;
      theme = "GitHub Dark Default";
      background-opacity = 0.40;
      background-blur-radius = 12;
      window-padding-x = 10;
      window-padding-y = 10;
      window-padding-balance = true;
    };
  };
}
