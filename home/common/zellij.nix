{ ... }: {
  programs.zellij = {
    enable = true;

    # keybinds は KDL の複雑な構造（shared_except 等）を使うため extraConfig で記述
    extraConfig = ''
      keybinds {
          // kubectl exec が Ctrl+p を detach シーケンスとして横取りするため、
          // Pane モードのキーを Ctrl+b に変更
          shared_except "pane" "locked" {
              unbind "Ctrl p"
              bind "Ctrl b" { SwitchToMode "Pane"; }
          }
          pane {
              unbind "Ctrl p"
              bind "Ctrl b" { SwitchToMode "Normal"; }
          }
      }
    '';

    layouts = {
      "main" = ''
        layout {
            default_tab_template {
                pane size=1 borderless=true {
                    plugin location="zellij:tab-bar"
                }
                children
                pane size=2 borderless=true {
                    plugin location="zellij:status-bar"
                }
            }

            tab name="main" focus=true {
                pane split_direction="vertical" {
                    pane size="60%" split_direction="horizontal" {
                        pane size="75%" name="editor" command="fresh"
                        pane size="25%" name="terminal" command="zsh"
                    }
                    pane size="40%" focus=true name="claude" command="claude"
                }
            }
        }
      '';
    };
  };
}
