{ username, homeDirectory, ... }:

{
  imports = [
    ./modules/core.nix
    ./modules/shell.nix
    ./modules/git.nix
    ./modules/apps.nix
    ./modules/tmux.nix
  ];

  home.username = username;
  home.homeDirectory = homeDirectory;
}
