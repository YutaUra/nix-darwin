{ config, ... }: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      global.hide_env_diff = true;

      # git worktree を作るたびに direnv allow を求められる問題への対処。
      # direnv は .envrc をパス+内容ハッシュ単位で許可管理するため、
      # 同じ .envrc でも worktree ごとに別パス = 未許可 とみなされる。
      # worktree の置き場を prefix ごと信頼し、自動ロードを許可する。
      # 自分専用の worktree 置き場に限定しているので任意コード実行リスクは実質ない。
      whitelist.prefix = [ "${config.home.homeDirectory}/.herdr/worktrees" ];
    };
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
