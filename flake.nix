{
  description = "nix-darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # brew 5.1.7 では cask の `depends_on macos: {}` パースで `nil.to_sym` クラッシュが発生する。
    # 5.1.10 で修正済み (Homebrew/brew@1c8cbf3) のため brew-src を直接 override する。
    # nix-homebrew 上流が 5.1.7 ピンのままなので、flake update では追従できない。
    brew-src = {
      url = "github:Homebrew/brew/5.1.10";
      flake = false;
    };
    nix-homebrew.inputs.brew-src.follows = "brew-src";
    gati.url = "github:YutaUra/gati";
    zyouz.url = "github:YutaUra/zyouz";
    # herdr は nixpkgs を nixos-unstable にピンしているが follows 未宣言のため、
    # こちらから追従させて nixpkgs の二重取り込みを防ぐ（単体バイナリなので安全）。
    herdr.url = "github:ogulcancelik/herdr";
    herdr.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, nix-homebrew, zyouz, ... }:
    let
      # macOS self-hosted GitHub Actions runner 用のサービスユーザー _ghrunner を
      # 宣言的に作成し、その home 環境を home-manager で管理する再利用モジュール。
      # 複数マシンで同じ runner ユーザーを用意できるよう、mkDarwin の extraModules に
      # 渡して opt-in する（recruit のような runner 不要なホストには入れない）。
      ghrunner = {
        # nix-darwin にこのユーザーの作成・管理を許可する（未列挙のユーザーは触らない安全弁）。
        users.knownUsers = [ "_ghrunner" ];
        users.users._ghrunner = {
          # uid 502 は macOS の通常ユーザー(501=管理者)の次に割り当てられる番号。
          # 既存マシンで手動作成済みの _ghrunner と一致させ、activation での uid 変更衝突を避ける。
          uid = 502;
          gid = 20; # staff（通常ユーザーと同じプライマリグループ）
          home = "/Users/_ghrunner";
          createHome = true; # 新規マシンではホームを自動作成する
          isHidden = true; # サービスアカウントなのでログイン画面には出さない
          shell = "/bin/zsh";
          description = "GitHub Runner";
        };
        home-manager.users._ghrunner = {
          imports = [ ./home/_ghrunner/default.nix ];
          home.username = "_ghrunner";
          home.homeDirectory = "/Users/_ghrunner";
        };
      };

      mkDarwin = { hostname, username, profile, extraModules ? [ ], system ? "aarch64-darwin" }:
        let configName = profile; in
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit username configName; };
          modules = [
            { nixpkgs.overlays = [ (import ./overlays/claude-code.nix) (import ./overlays/gws.nix) (import ./overlays/github-runner.nix) (final: _: { gati = inputs.gati.packages.${final.system}.default; zyouz = inputs.zyouz.packages.${final.system}.default; herdr = inputs.herdr.packages.${final.system}.default; }) ]; }
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
                  zyouz.homeManagerModules.default
                  ./home/common/default.nix
                  ./home/${profile}/default.nix
                ];
                home.username = username;
                home.homeDirectory = "/Users/${username}";
              };
            }
          ] ++ extraModules;
        };
    in
    {
      darwinConfigurations."private" = mkDarwin {
        hostname = "private";
        username = "yutaura";
        profile = "private";
        # 個人マシンを self-hosted GitHub Actions runner としても使うため _ghrunner を同居させる。
        extraModules = [ ghrunner ];
      };

      darwinConfigurations."recruit" = mkDarwin {
        hostname = "recruit";
        username = "01051961";
        profile = "recruit";
      };

      homeConfigurations."qall-k8s" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-linux";
          overlays = [
            (import ./overlays/claude-code.nix)
            (import ./overlays/gws.nix)
            # コンテナ環境では TTY がなく gati のテストが失敗するため doCheck を無効化
            (final: _: { gati = inputs.gati.packages.${final.system}.default.overrideAttrs { doCheck = false; }; zyouz = inputs.zyouz.packages.${final.system}.default; herdr = inputs.herdr.packages.${final.system}.default; })
          ];
        };
        modules = [
          zyouz.homeManagerModules.default
          ./home/qall-k8s/default.nix
          {
            home.username = "quipper";
            home.homeDirectory = "/home/quipper";
          }
        ];
      };
    };
}
