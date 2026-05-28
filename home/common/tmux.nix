{ ... }: {
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    mouse = false;
    historyLimit = 10000;

    extraConfig = ''
      # tmux 起動時の global 環境に LANG/LC_ALL を持たせる。
      # home.sessionVariables 経由の設定だけにしない理由:
      # `kubectl exec -- tmux new` のように shell init を経由せずに
      # tmux を直接起動した場合、hm-session-vars.sh が読まれないため
      # LANG が空のまま tmux server が起動する。
      # 結果として中の Node 系 TUI (Ink / cli-boxes 等) の
      # is-unicode-supported が false を返し、claude code の罫線が
      # ASCII にフォールバックして `_` 混じりに崩れる。
      # set-environment -g で tmux 自身に locale を持たせると、
      # 起動経路を問わず spawn される window で UTF-8 が有効になる。
      set-environment -g LANG C.UTF-8
      set-environment -g LC_ALL C.UTF-8

      # true color を有効化（terminfo は tmux-256color のまま）
      set -ga terminal-overrides ",*256col*:Tc"

      # attach 時に他クライアントのサイズに引きずられないよう
      # 各 window をクライアントのサイズに自動追従させる。
      # VPN 切替や別マシンから再 attach する運用で罫線崩れを抑える。
      setw -g aggressive-resize on
    '';
  };
}
