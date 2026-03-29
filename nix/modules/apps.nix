{ lib, pkgs, ... }:

{
  home.file = lib.mkMerge [
    {
      "bin/codex" = {
        source = ../../bin/codex;
        executable = true;
      };

      "bin/hm-switch" = {
        source = ../../bin/hm-switch;
        executable = true;
      };

      "bin/bootstrap-dotfiles" = {
        source = ../../bin/bootstrap;
        executable = true;
      };

      ".codex/rules/default.rules".source = ../../config/codex/default.rules;
      ".config/htop/htoprc".source = ../../config/htop/htoprc;
    }

    (lib.mkIf pkgs.stdenv.isDarwin {
      ".ssh/config".source = ../../config/ssh/config;
    })
  ];

  xdg.configFile = lib.mkMerge [
    {
      "nix/nix.conf".source = ../../config/nix/nix.conf;
      "direnv/direnvrc".source = ../../config/direnv/direnvrc;
      "gh/config.yml".source = ../../config/gh/config.yml;
      "zed/settings.json".source = ../../config/zed/settings.json;
      "nvim" = {
        source = ../../config/nvim;
        recursive = true;
      };
    }

    (lib.mkIf pkgs.stdenv.isDarwin {
      "ghostty/config".source = ../../config/ghostty/config;
    })
  ];
}
