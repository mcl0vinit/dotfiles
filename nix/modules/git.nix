{ ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Sam Powell";
        email = "sam@sampowell.dev";
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
      fetch.prune = true;
      push.autoSetupRemote = true;
    };
  };
}
