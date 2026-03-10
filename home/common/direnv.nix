{ ... }: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global.hide_env_diff = true;
  };

  # Claude Code の Bash ツールは非インタラクティブシェルを起動するため、
  # .zshrc の direnv hook (precmd ベース) が発火しない。
  # .zshenv で $CLAUDECODE 環境変数をガードに direnv を手動トリガーする。
  # ref: https://github.com/anthropics/claude-code/issues/2110
  programs.zsh.envExtra = ''
    if command -v direnv >/dev/null 2>&1; then
      if [[ -n "$CLAUDECODE" ]]; then
        eval "$(direnv hook zsh)"
        eval "$(DIRENV_LOG_FORMAT= direnv export zsh)"
      fi
    fi
  '';
}
