{ pkgs, ... }: {
  imports = [
    ./git.nix
  ];

  home.packages = with pkgs; [
    # Kubernetes
    kubectl
    stern
    kustomize
  ];

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

        # "-- zsh" を "-- bash -lc zsh" に変換（コンテナの PATH に zsh がない場合の対策）
        local new_args=()
        local found_dashdash=false
        for arg in "''${args[@]}"; do
          if [[ "$found_dashdash" == true && "$arg" == "zsh" ]]; then
            new_args+=("bash" "-lc" "zsh")
          else
            new_args+=("$arg")
          fi
          [[ "$arg" == "--" ]] && found_dashdash=true
        done

        if [[ -n "$color" ]]; then
          local SET_BG="''${ESC}]11;''${color}''${BEL}"
          printf '%s' "$SET_BG"
          trap 'printf "%s" "$RESET_BG"' EXIT INT TERM
          command kubectl "''${new_args[@]}"
          printf '%s' "$RESET_BG"
          trap - EXIT INT TERM
        else
          command kubectl "''${new_args[@]}"
        fi
      else
        command kubectl "$@"
      fi
    }
  '';
}
