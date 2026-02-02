{ ... }: {
  imports = [
    ../../common
    ../../profiles/private
    ./homebrew.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
}
