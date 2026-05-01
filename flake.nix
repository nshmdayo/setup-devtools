{
  description = "Personal development tools managed by Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f:
        nixpkgs.lib.genAttrs systems
          (system:
            f system (import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }));

      mkHome = { system, username, homeDirectory }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          modules = [
            ./home
            {
              home.username = username;
              home.homeDirectory = homeDirectory;

              # 最初にHome Managerを導入したバージョンとして固定する。
              # むやみに上げない。
              home.stateVersion = "25.11";

              nixpkgs.config.allowUnfree = true;
            }
          ];
        };
    in
    {
      devShells = forAllSystems (system: pkgs: {
        default = import ./devshells/default.nix { inherit pkgs; };
        go = import ./devshells/go.nix { inherit pkgs; };
      });

      formatter = forAllSystems (system: pkgs: pkgs.nixfmt-rfc-style);

      homeConfigurations = {
        # Ubuntu / Debian / Lightsail / Linuxコンテナ向け
        "dev-linux" = mkHome {
          system = "x86_64-linux";
          username = "dev";
          homeDirectory = "/home/dev";
        };

        # 自分のLinuxユーザー向け。必要に応じて username を変更
        "naoto-linux" = mkHome {
          system = "x86_64-linux";
          username = "naoto";
          homeDirectory = "/home/naoto";
        };

        # Apple Silicon Mac向け
        "naoto-mac" = mkHome {
          system = "aarch64-darwin";
          username = "naoto";
          homeDirectory = "/Users/naoto";
        };

        # Intel Macならこちらを使う
        "naoto-intel-mac" = mkHome {
          system = "x86_64-darwin";
          username = "naoto";
          homeDirectory = "/Users/naoto";
        };
      };
    };
}
