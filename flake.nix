{
  description = "nix-darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, nix-homebrew, ... }:
    let
      mkDarwin = { hostname, username, profile, system ? "aarch64-darwin" }:
        let configName = profile; in
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit username configName; };
          modules = [
            ./hosts/${hostname}/default.nix
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                user = username;
                autoMigrate = true;
              };
            }
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "before-nix";
              home-manager.extraSpecialArgs = { inherit username; };
              home-manager.users.${username} = {
                imports = [
                  ./home/common/default.nix
                  ./home/${profile}/default.nix
                ];
                home.username = username;
                home.homeDirectory = "/Users/${username}";
              };
            }
          ];
        };
    in
    {
      darwinConfigurations."private" = mkDarwin {
        hostname = "private";
        username = "yutaura";
        profile = "private";
      };

      darwinConfigurations."recruit" = mkDarwin {
        hostname = "recruit";
        username = "01051961";
        profile = "recruit";
      };

      homeConfigurations."qall-k8s" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home/qall-k8s/default.nix
          {
            home.username = "quipper";
            home.homeDirectory = "/home/quipper";
          }
        ];
      };
    };
}
