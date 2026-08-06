{ pkgs, ... }:
let
  # buildNpmPackage を使わない理由:
  # 頻繁にリリースされる npm パッケージで npmDepsHash 維持コストが高い。
  m365-cli = pkgs.writeShellScriptBin "m365" ''
    exec ${pkgs.lib.getExe pkgs.nodejs} ${pkgs.lib.getExe' pkgs.nodejs "npx"} --yes --package @pnp/cli-microsoft365@latest m365 "$@"
  '';
  deploygate-cli = pkgs.writeShellScriptBin "deploygate" ''
    exec ${pkgs.lib.getExe pkgs.nodejs} ${pkgs.lib.getExe' pkgs.nodejs "npx"} --yes --package deploygate@latest deploygate "$@"
  '';
in
{
  imports = [
    ./git.nix
  ];

  home.packages = with pkgs; [
    # AI コーディングエージェント用のターミナルマルチプレクサ
    herdr

    # Kubernetes
    kubectl
    stern
    kustomize

    # Python
    uv

    # PDF
    poppler-utils

    # Microsoft 365
    m365-cli

    # DeployGate
    deploygate-cli
  ];

  # herdr に「この pane は claude」と同定させるための kubectl exec ラッパー。
  # herdr のエージェント同定は pane の前面プロセスグループに claude という
  # 名前の実行ファイルがいるかで行われ、OSC タイトルはその後の状態判定にしか
  # 使われない。kubectl exec 直叩きでは前面が kubectl になり同定されないため、
  # claude という名前のスクリプトを exec せずに（= 前面プロセスグループに
  # 残したまま）kubectl を子プロセスとして起動する。
  # writeShellScriptBin で home.packages に入れない理由:
  # PATH 上に claude を置くとローカルの claude-code 本体と衝突するため、
  # PATH 外の固定パス（~/.herdr-shims/claude）に配置し alias 経由で呼ぶ。
  home.file.".herdr-shims/claude" = {
    executable = true;
    text = ''
      #!/bin/zsh
      # 接続先 pod を第1引数で選択する（省略時は manage-web）
      case "''${1:-manage-web}" in
        manage-web)  pod="pod/manage-web-0" ;;
        aya-payment) pod="pod/aya-payment-0" ;;
        *)
          echo "usage: claude-k8s [manage-web|aya-payment]" >&2
          exit 1
          ;;
      esac
      # TERM/LANG の上書き理由は programs.zsh.initContent の kubectl 関数を参照
      # （このスクリプトは zsh 関数を継承しないため、ここで再設定する）
      TERM=xterm-256color kubectl exec -it "$pod" -- \
        env LANG=C.UTF-8 LC_ALL=C.UTF-8 \
        tmux new -A -s claude 'claude -c'
    '';
  };
  programs.zsh.shellAliases.claude-k8s = "~/.herdr-shims/claude";

  # ~/.claude-private を別アカウント用 Claude Code 設定ディレクトリとして使う。
  # rules / settings.json は home/common/claude-code.nix で両方に展開済み。
  programs.zsh.shellAliases.claude-private =
    "CLAUDE_CONFIG_DIR=~/.claude-private command claude";

  _claude.extraPlugins = {
    # sapuri-agent-plugins は社内リポジトリのため recruit / qall-k8s のみで有効化する
    "figma-implementation-core@sapuri-agent-plugins" = true;
    "yutaura-tools@sapuri-agent-plugins" = true;
    "m365@sapuri-agent-plugins" = true;
    "k12-manage-web-devs@sapuri-agent-plugins" = true;
  };

  # aqua (aquaproj/aqua) でインストールされた CLI を PATH に追加する
  # XDG_DATA_HOME を設定していないため、デフォルトの $HOME/.local/share/aquaproj-aqua/bin を使用
  home.sessionPath = [
    "$HOME/.local/share/aquaproj-aqua/bin"
  ];

  # グローバル設定ファイルを指定し、どのディレクトリからでも共通の CLI を使えるようにする
  # 実ファイル ~/.config/aquaproj-aqua/aqua.yaml はユーザーが手動で作成する（秘密情報ではないが
  # 個人の好みが強く出るため Nix 管理下には置かない）
  home.sessionVariables = {
    AQUA_GLOBAL_CONFIG = "$HOME/.config/aquaproj-aqua/aqua.yaml";
  };

  # kubectl exec 時に特定 pod/namespace で背景色を変更（危険な操作の視覚的警告）
  programs.zsh.initContent = ''
    kubectl() {
      if [[ "$1" == "exec" ]]; then
        local ESC=$'\e' BEL=$'\a'
        local RESET_BG="''${ESC}]111''${BEL}"
        local color="" namespace="" pod=""

        # 引数から namespace と pod を抽出（exec をスキップして i=2 から）
        local args=("$@")
        local i=2
        while (( i < ''${#args[@]} )); do
          case "''${args[$i]}" in
            -n)
              namespace="''${args[$((i+1))]}"
              ((i+=2))
              ;;
            --namespace=*)
              namespace="''${args[$i]#--namespace=}"
              ((i++))
              ;;
            --namespace)
              namespace="''${args[$((i+1))]}"
              ((i+=2))
              ;;
            --)
              break
              ;;
            -*)
              ((i++))
              ;;
            pod/*)
              [[ -z "$pod" ]] && pod="''${args[$i]}"
              ((i++))
              ;;
            *)
              ((i++))
              ;;
          esac
        done

        # pod で判定（優先）
        case "$pod" in
          "pod/aya-payment-0") color="#360505" ;;
          "pod/manage-web-0")  color="#052336" ;;
        esac

        # namespace で判定（pod で色が決まっていない場合）
        if [[ -z "$color" ]]; then
          case "$namespace" in
            "release") color="#343605" ;;
            "develop") color="#073605" ;;
          esac
        fi

        # "-- " 以降を加工する処理:
        # 1. "-- zsh" を "-- bash -lc zsh" に変換
        #    (コンテナの PATH に zsh がない場合の対策)
        # 2. "--" の直後に "env LANG=C.UTF-8 LC_ALL=C.UTF-8" を注入
        #    (Pod の container default は LANG 未設定。tmux server が
        #    起動時の locale 検出で UTF-8 と判断できず non-UTF-8 mode
        #    で動くと、CJK や `★` 等の multi-byte を `_` に置換する。
        #    shell init 経由なら home.sessionVariables で立つが、
        #    kubectl exec -- tmux のように shell を経由しない経路では
        #    届かないため、kubectl exec の引数として env を明示する。)
        local new_args=()
        local found_dashdash=false
        local injected_env=false
        for arg in "''${args[@]}"; do
          if [[ "$found_dashdash" == true && "$injected_env" == false ]]; then
            new_args+=("env" "LANG=C.UTF-8" "LC_ALL=C.UTF-8")
            injected_env=true
          fi
          if [[ "$found_dashdash" == true && "$arg" == "zsh" ]]; then
            new_args+=("bash" "-lc" "zsh")
          else
            new_args+=("$arg")
          fi
          [[ "$arg" == "--" ]] && found_dashdash=true
        done

        # DECSTR (Soft Terminal Reset) で DEC private モードを一括リセット。
        # Kitty キーボードプロトコルは独自のスタック機構のため別途 pop。
        local RESET_TERM="''${ESC}[!p''${ESC}[<u''${ESC}[<u''${ESC}[<u''${ESC}[<u''${ESC}[<u"

        # Ghostty の xterm-ghostty terminfo を Pod 側に持たない理由で
        # TERM を上書きする:
        # Pod の base image には xterm-ghostty terminfo が無く、
        # kubectl exec -it 経由でそのまま伝播すると Pod 側の tmux が
        # outer terminal の能力を読めず、罫線を ASCII (`_` 等) に
        # フォールバックして claude code の表示が崩れる。
        # exec 用途では Ghostty 固有機能 (kitty keyboard protocol 等) は
        # 不要なので、汎用の xterm-256color に倒して伝播させる。
        if [[ -n "$color" ]]; then
          local SET_BG="''${ESC}]11;''${color}''${BEL}"
          printf '%s' "$SET_BG"
          trap 'printf "%s" "''${RESET_TERM}''${RESET_BG}"' EXIT INT TERM
          TERM=xterm-256color command kubectl "''${new_args[@]}"
          printf '%s' "''${RESET_TERM}''${RESET_BG}"
          trap - EXIT INT TERM
        else
          TERM=xterm-256color command kubectl "''${new_args[@]}"
          printf '%s' "$RESET_TERM"
        fi
      else
        command kubectl "$@"
      fi
    }

    # aqua の zsh 補完を有効化
    # `aqua completion zsh` を毎回実行する実装にしない理由:
    # シェル起動のたびにサブシェルで Go バイナリを叩くのは遅いため、
    # バイナリの mtime と比較してキャッシュを作るパターンを採用した。
    if command -v aqua >/dev/null 2>&1; then
      local aqua_comp_cache="$HOME/.cache/aqua-completion.zsh"
      if [[ ! -f "$aqua_comp_cache" || "$(command -v aqua)" -nt "$aqua_comp_cache" ]]; then
        mkdir -p "$HOME/.cache"
        aqua completion zsh > "$aqua_comp_cache"
      fi
      source "$aqua_comp_cache"
    fi
  '';
}
