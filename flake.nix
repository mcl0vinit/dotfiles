{
  description = "Portable dotfiles for local and cloud machines";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      lib = nixpkgs.lib;

      envOr =
        name: fallback:
        let
          value = builtins.getEnv name;
        in
        if value != "" then value else fallback;

      defaultHome =
        username: system:
        if lib.hasSuffix "darwin" system then "/Users/${username}" else "/home/${username}";

      mkHome =
        {
          system,
          username ? envOr "DOTFILES_USER" (envOr "USER" "mcl0vin"),
          homeDirectory ? envOr "DOTFILES_HOME" (defaultHome username system),
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          extraSpecialArgs = {
            inherit username homeDirectory system;
            dotfilesDir = envOr "DOTFILES_DIR" "${homeDirectory}/.dotfiles";
          };

          modules = [ ./nix/home.nix ];
        };
    in
    {
      homeConfigurations = {
        mcl0vin-darwin = mkHome {
          system = "aarch64-darwin";
          username = "mcl0vin";
          homeDirectory = "/Users/mcl0vin";
        };

        portable-darwin = mkHome {
          system = envOr "DOTFILES_SYSTEM" "aarch64-darwin";
        };

        portable-linux = mkHome {
          system = envOr "DOTFILES_SYSTEM" "x86_64-linux";
        };

        portable-linux-arm = mkHome {
          system = envOr "DOTFILES_SYSTEM" "aarch64-linux";
        };
      };
    };
}
