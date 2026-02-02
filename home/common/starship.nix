{ ... }: {
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$character";

      directory = {
        style = "bold cyan";
        truncation_length = 4;
        truncate_to_repo = false;
        fish_style_pwd_dir_length = 1;
      };

      git_branch = {
        symbol = " ";
        style = "bold purple";
        format = " [$symbol$branch]($style)";
      };

      git_status = {
        style = "yellow";
        format = "([$all_status$ahead_behind]($style))";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };
}
