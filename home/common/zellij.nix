{ ... }: {
  programs.zellij = {
    enable = true;

    # default_mode を locked にすることで、通常時は全キーがアプリに透過する。
    # Ctrl+G で unlock → モードキーの2ステップで zellij を操作する。
    # これにより Ctrl+B, Ctrl+P 等のキーバインド衝突が解消される。
    extraConfig = ''
      default_mode "locked"
    '';

    layouts = {
      "main" = ''
        layout {
            tab name="main" focus=true {
                pane split_direction="vertical" {
                    pane size="60%" split_direction="horizontal" {
                        pane size="75%" name="editor" command="gati" {
                            args "."
                        }
                        pane size="25%" name="terminal" command="zsh"
                    }
                    pane size="40%" focus=true name="claude" command="claude" {
                        args "-c" "--permission-mode" "auto"
                    }
                }
            }
        }
      '';
    };
  };
}
