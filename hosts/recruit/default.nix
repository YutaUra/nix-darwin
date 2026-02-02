{ ... }: {
  imports = [
    ../../common
    ../../profiles/recruit
    ./homebrew.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
}
