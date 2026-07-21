{ ... }: {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;

    # bun は node/npm と違い NIX_SSL_CERT_FILE を読まないため、TLS 検証に使う CA バンドルを
    # 明示的に渡す。これが無いと `bunx` の manifest 取得が
    # UNKNOWN_CERTIFICATE_VERIFICATION_ERROR で失敗する（企業ネットワークの CA が nix の
    # バンドルにのみ含まれ、bun のデフォルト信頼ストアには無いため）。herdr の hunk プラグインが
    # `bunx hunkdiff` を使うので必須。node が参照するのと同一ファイルを指すよう NIX_SSL_CERT_FILE を
    # 優先し、未設定環境向けに標準パスをフォールバックにする。
    #
    # home.sessionVariables ではなく envExtra(.zshenv) に置く理由:
    # sessionVariables は login shell 用に .zprofile を生成しにいくが、当環境では .zprofile が
    # prezto 所有の symlink のため home-manager activation が衝突で停止する。.zshenv は既に
    # home-manager 管理下で衝突が無く、かつ全 zsh 起動で読まれるので herdr の pane run 経由の
    # bunx にも確実に届く。
    envExtra = ''
      export NODE_EXTRA_CA_CERTS="''${NIX_SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}"
    '';

    # home-manager 更新により zsh 有効時は .zprofile が必ず生成されるようになった。
    # 当環境の ~/.zprofile は prezto の symlink（login shell の PATH と brew shellenv を設定）
    # だったため、home-manager の .zprofile がそれを置き換えると homebrew PATH が失われる。
    # prezto の zprofile を明示的に source して従来の login 初期化を保持する。
    # prezto の無い環境（Linux コンテナ等）では guard により no-op。
    profileExtra = ''
      [[ -r "$HOME/.zprezto/runcoms/zprofile" ]] && source "$HOME/.zprezto/runcoms/zprofile"
    '';

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
