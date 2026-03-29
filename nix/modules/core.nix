{ pkgs, ... }:

{
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    bashInteractive
    bat
    bun
    curl
    direnv
    fd
    fzf
    gh
    git
    home-manager
    htop
    jq
    nix-direnv
    neovim
    python3
    ripgrep
    tmux
    tree
    wget
  ];
}
