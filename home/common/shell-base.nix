{ ... }: {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;

    initContent = ''
      # キーバインド: 上下矢印で履歴の前方一致検索
      autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey -r '^[[A' '^[[B' '^[OA' '^[OB' 2>/dev/null
      for km in emacs viins vicmd; do
        bindkey -M $km '^[[A' up-line-or-beginning-search
        bindkey -M $km '^[[B' down-line-or-beginning-search
        bindkey -M $km '^[OA' up-line-or-beginning-search
        bindkey -M $km '^[OB' down-line-or-beginning-search
      done

      # ローカル設定（トークン等）
      [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
    '';
  };
}
