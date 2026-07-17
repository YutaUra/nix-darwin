{ ... }: {
  # bun は node/npm と違い NIX_SSL_CERT_FILE を読まないため、TLS 検証に使う CA バンドルを
  # 明示的に渡す。これが無いと `bunx` の manifest 取得が
  # UNKNOWN_CERTIFICATE_VERIFICATION_ERROR で失敗する（企業ネットワークの CA が nix の
  # バンドルにのみ含まれ、bun のデフォルト信頼ストアには無いため）。herdr の hunk プラグインが
  # `bunx hunkdiff` を使うので必須。node が参照するのと同一ファイルを指すよう NIX_SSL_CERT_FILE を
  # 優先し、未設定環境向けに標準パスをフォールバックにする。
  home.sessionVariables = {
    NODE_EXTRA_CA_CERTS = "\${NIX_SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}";
  };

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
