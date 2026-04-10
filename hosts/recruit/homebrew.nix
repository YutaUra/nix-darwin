{ ... }: {
  # aqua (aquaproj/aqua) は nixpkgs に無いため Homebrew tap 経由で導入している
  # aquaproj/homebrew-aqua は formula ではなく cask として配布されているため casks に含める
  homebrew.taps = [ "aquaproj/aqua" ];

  homebrew.casks = [
    "amazon-workspaces"
    "android-studio"
    "aquaproj/aqua/aqua"
    "microsoft-auto-update"
    "microsoft-office"
    "slack-cli"
  ];
}
