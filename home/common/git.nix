{ ... }: {
  programs.git = {
    enable = true;
    settings = {
      user.name = "YutaUra";
      user.email = "yuuta3594@gmail.com";
      pull.rebase = true;
      pager.branch = false;
      init.defaultBranch = "main";
      core.editor = "code --wait";
      core.ignorecase = false;
      push.autoSetupRemote = true;
      advice.skippedCherryPicks = false;
      fetch.prune = true;
    };
  };
}
