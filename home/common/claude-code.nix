{ pkgs, lib, config, ... }:
let
  gwsSkills = import ../../pkgs/gws-skills.nix { inherit (pkgs) lib fetchFromGitHub; };
  yutauraRules = import ../../pkgs/yutaura-rules.nix { inherit (pkgs) lib fetchFromGitHub; };

  # buildNpmPackage を使わない理由:
  # v0.1.1 で頻繁に更新され、alpha 版 playwright 依存で npmDepsHash 維持コストが高い。
  playwright-cli = pkgs.writeShellScriptBin "playwright-cli" ''
    exec ${pkgs.lib.getExe pkgs.nodejs} ${pkgs.lib.getExe' pkgs.nodejs "npx"} --yes @playwright/cli@latest "$@"
  '';

  # ~/.claude へコピーせず nix store の実行ファイルとして持つ理由:
  # 公式サンプルは cp + chmod +x を案内しているが、それだと更新が手作業になる。
  # writeScriptBin なら python3 の解決もシェバンに焼き込まれ、statusLine から
  # 絶対パスで参照できるため宣言的に完結する。
  runcat-statusline = pkgs.writeScriptBin "runcat-statusline" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./runcat-statusline.py}
  '';

  # buildNpmPackage を使わない理由: dependencies ゼロで dist にバンドル済みのため
  # npm install も npmDepsHash 維持も不要。
  # npx を使わない理由: statusLine は毎ターン同期実行されるので、パッケージ解決の
  # 遅延がそのまま体感ラグになる。
  claude-powerline = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "claude-powerline";
    version = "1.30.3";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@owloops/claude-powerline/-/claude-powerline-${finalAttrs.version}.tgz";
      hash = "sha256-mj0BLH25GDmj5Fp2KdvQd+Y/971BNcMcceoydwIzkJo=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];
    dontBuild = true;

    # git を PATH に足す理由: git セグメントが git を spawn するが、
    # K8s コンテナでは PATH に git が居ないことがある。
    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/claude-powerline"
      cp -r dist "$out/lib/claude-powerline/"

      makeWrapper ${lib.getExe' pkgs.nodejs "node"} "$out/bin/claude-powerline" \
        --add-flags "$out/lib/claude-powerline/dist/index.mjs" \
        --prefix PATH : ${lib.makeBinPath [ pkgs.git ]}

      runHook postInstall
    '';

    meta.mainProgram = "claude-powerline";
  });

  # 1 本のラッパーに集約する理由: statusLine はコマンドを 1 つしか取れず、payload は
  # RunCat 連携と描画の両方に必要。stdin は一度しか読めないので配り直す。
  claude-statusline = pkgs.writeShellScriptBin "claude-statusline" ''
    payload="$(cat)"

    # runcat 出力をフォールバックに使う理由: claude-powerline は git と usage API に
    # 依存するため失敗しうるが、空行だとモデル名すら分からなくなる。
    fallback="$(printf '%s' "$payload" | ${lib.getExe' runcat-statusline "runcat-statusline"})"

    # claude-powerline は幅から 45 桁引く (Claude Code が右端に出す更新通知を避けるため)。
    # 110 桁以下ではその通知が下の行に回り右側が空くので、実幅 + 45 を渡して相殺する。
    # COLUMNS を基準にしない理由: Claude Code は子プロセスに COLUMNS=0 を渡してくる。
    find_parent_tty() {
      pid=$$
      depth=0
      while [ "$depth" -lt 10 ]; do
        info="$(ps -o ppid=,tty= -p "$pid" 2>/dev/null)" || return 1
        [ -n "$info" ] || return 1
        set -- $info
        ppid="$1"
        tty_dev="''${2:-}"
        case "$tty_dev" in
          "" | "?" | "??") ;;
          *) printf '%s' "$tty_dev"; return 0 ;;
        esac
        case "$ppid" in
          "" | 0 | 1) return 1 ;;
        esac
        pid="$ppid"
        depth=$((depth + 1))
      done
      return 1
    }

    # 空文字なら powerline 側が自前検出に落ちるため、取得失敗時は素通しでよい。
    powerline_columns=""
    if tty_dev="$(find_parent_tty)"; then
      term_cols="$(stty size < "/dev/$tty_dev" 2>/dev/null | cut -d' ' -f2)"
      case "$term_cols" in
        "" | *[!0-9]*) ;;
        *) [ "$term_cols" -le 110 ] && powerline_columns=$((term_cols + 45)) ;;
      esac
    fi

    if rendered="$(printf '%s' "$payload" | COLUMNS="$powerline_columns" ${lib.getExe claude-powerline})" && [ -n "$rendered" ]; then
      printf '%s\n' "$rendered"
    else
      printf '%s\n' "$fallback"
    fi
  '';

  basePermissions = [
    "WebSearch"
    "Bash(playwright-cli:*)"
    "mcp__plugin_context7_context7__resolve-library-id"
    "mcp__plugin_context7_context7__query-docs"
    # pnpm dlx / --filter / format / build を含めない理由: 任意実行・状態変更になるため。
    "Bash(pnpm vitest:*)"
    "Bash(pnpm lint:*)"
    "Bash(pnpm typecheck:*)"
    "Bash(pnpm test:*)"
    # computer / navigate / javascript_tool を含めない理由: ページ状態変更・任意 JS 実行になるため。
    "mcp__claude-in-chrome__find"
    "mcp__claude-in-chrome__get_page_text"
    "mcp__claude-in-chrome__read_page"
    "mcp__claude-in-chrome__tabs_context_mcp"
  ];

  # settings.json を 1 つ共有せず claude 設定ディレクトリごとに生成する理由:
  # moshi-hook は CLAUDE_CODE_PLUGIN_DIRS が「その設定ディレクトリ配下の moshi-plugin」を
  # 正確に指しているかを文字列比較で検査する。両 root へ同一ファイルを配ると
  # 片方が必ず不一致になり、moshi 側から hooks が「未インストール」と見なされる。
  mkSettingsJson = claudeDir: pkgs.writeText "claude-settings.json" (builtins.toJSON ({
    enabledPlugins = {
      "figma@claude-plugins-official" = true;
      "code-review@claude-plugins-official" = true;
      "commit-commands@claude-plugins-official" = true;
      "frontend-design@claude-plugins-official" = true;
      "pr-review-toolkit@claude-plugins-official" = true;
      "context7@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "feature-dev@claude-plugins-official" = true;
      "security-guidance@claude-plugins-official" = true;
      "explanatory-output-style@claude-plugins-official" = true;
      "ralph-loop@claude-plugins-official" = true;
      "skill-creator@claude-plugins-official" = true;
      # 行削除ではなく false 明示にする理由: marketplace にインストール済みのため、
      # エントリを消すだけだとローカル状態次第で有効に戻り得る。
      "greptile@claude-plugins-official" = false;
      "document-skills@anthropic-agent-skills" = true;
      "yutaura-toolkit@yutaura-marketplace" = true;
      "modern-web-guidance@googlechrome" = true;
      "natural-japanese@natural-japanese" = true;
    } // config._claude.extraPlugins;
    # /plugin marketplace add を手で打たずに宣言する理由: 新しい K8s コンテナでも
    # 初回起動時に marketplace が自動登録され、プロファイル間で状態がずれない。
    # claude-plugins-official 版を使わない理由: 第三者プラグインの更新が
    # 2026-10 に止まり v0.0.194 で固定されたため、上流 marketplace から取得する。
    extraKnownMarketplaces = {
      googlechrome.source = {
        source = "github";
        repo = "GoogleChrome/modern-web-guidance";
      };
      # fetchFromGitHub で rev 固定しない理由: 更新頻度が高く hash 追従の手間に
      # 見合わないため、FORCE_AUTOUPDATE_PLUGINS で上流に追従させる。
      natural-japanese.source = {
        source = "github";
        repo = "coji/natural-japanese";
      };
    };
    env = {
      CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
      DISABLE_AUTOUPDATER = "1";
      # DISABLE_AUTOUPDATER=1 だけだと plugin の auto-update も止まるため、
      # plugin だけは更新を受け取りたいので FORCE_AUTOUPDATE_PLUGINS で復活させる。
      # 個別 marketplace の auto-update on/off は /plugin UI で別途 toggle する必要あり。
      FORCE_AUTOUPDATE_PLUGINS = "1";
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      # Code Mode (experimental): Claude が個別の tool 呼び出しの代わりに
      # JavaScript を書いて複数の tool 呼び出しを 1 ステップで実行するモード。
      # project の settings.json ではなく user settings 側で指定している理由:
      # clone したリポジトリが勝手に Code Mode を有効化できないよう、
      # Claude Code は project settings の env にあるこの変数を無視する。
      # agent teams と併用するには v2.1.326 以降が必要
      # (overlays/claude-code-manifest.json 側で担保)。
      CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = "1";
      CLAUDE_CODE_NO_FLICKER = "1";
      # 下の effortLevel ではなく環境変数で指定している理由:
      # Claude Code 2.1.210 時点では settings.json の effortLevel が effort に反映されず、
      # 常にモデル既定値 (high) になる。--settings で明示しても high のままだが、
      # CLAUDE_CODE_EFFORT_LEVEL は反映されることを実測で確認したため env 側で指定する。
      # 将来 effortLevel が機能するようになったらこの行は削除してよい。
      CLAUDE_CODE_EFFORT_LEVEL = config._claude.effortLevel;
      # CLAUDE_CODE_USE_BEDROCK = "1";
      # AWS_PROFILE = "jp-sandbox";
      # ANTHROPIC_MODEL = "jp.anthropic.claude-sonnet-4-5-20250929-v1:0";
      # AWS_REGION = "ap-northeast-1";
    }
    // config._claude.extraEnv
    // lib.optionalAttrs (config._claude.pluginDir != null) {
      CLAUDE_CODE_PLUGIN_DIRS = "${claudeDir}/${config._claude.pluginDir}";
    };
    permissions = {
      allow = basePermissions ++ config._claude.extraPermissions;
      defaultMode = "auto";
    };
    # auto mode 有効化時の opt-in dialog を抑制する。
    # 一度 "Yes, and make it my default mode" を選んだ場合に Claude が自動で書き込む値だが、
    # ここで宣言的に true にしておくことで dialog 表示自体をスキップできる。
    skipAutoPermissionPrompt = true;
    # 共通デフォルトを Fable ではなく Opus にする理由:
    # Fable は最高性能だが料金が Opus の約2倍で、高 effort だと 1 ターン数分かかる
    # こともある。日常用途では Opus で十分なため、コストと速度のバランスで Opus を既定にする。
    # effortLevel は 2.1.210 時点では機能しないため、実効値は env の
    # CLAUDE_CODE_EFFORT_LEVEL 側で指定している。ここは宣言的な意図の記録として残す。
    # effort を auto にする理由:
    # Fable と違い Opus は「low でも常に十分深い」とは言えないため、
    # 固定値ではなくタスクの重さに応じてモデル側に選ばせる。
    # "fable"/"opus" エイリアスを使わない理由:
    # Claude Code 独自エイリアスは最新世代に自動追従するが、実際に解決される
    # モデル ID が CLI 側の更新タイミングに依存し不透明。
    # 公式 docs (docs.claude.com) でも 4.6 世代以降のモデル ID は pinned snapshot と
    # 明記されているため、宣言的設定では具体的な ID を直接指定する。
    # 出力先 JSON は常に ~/.claude/runcat-usage.json 固定なので、
    # .claude-private 側で動かしても RunCat Neo の参照先は 1 つで済む。
    statusLine = {
      type = "command";
      command = lib.getExe' claude-statusline "claude-statusline";
    };
    model = config._claude.model;
    effortLevel = config._claude.effortLevel;
    autoMemoryEnabled = false;
    language = "日本語";
    feedbackSurveyRate = 0;
  } // lib.optionalAttrs (config._claude.extraHooks != {}) {
    hooks = config._claude.extraHooks;
  }));
in
{
  options._claude = {
    model = lib.mkOption {
      type = lib.types.str;
      # claude-opus-5 のままにしない理由: Code Mode (experimental) は
      # Opus 5.5 / Sonnet 5.5 / Haiku 5.5 / Fable 5.2 以降でしか起動せず、
      # claude-opus-5 では "it only works with Opus 5.5, Sonnet 5.5 and
      # later models" で無効化される。
      default = "claude-opus-5-5";
      description = "Claude Code のデフォルトモデル ID";
    };
    effortLevel = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = "Claude Code のデフォルト effort レベル";
    };
    extraPermissions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "プロファイル固有の Claude Code パーミッションルール";
    };
    extraPlugins = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
      description = "プロファイル固有の Claude Code プラグイン";
    };
    extraHooks = lib.mkOption {
      # types.attrs にしない理由: 複数モジュールが同じイベント（SessionStart 等）を定義すると
      # 浅いマージで後勝ちになり、片方の hook が黙って消える。listOf なら連結される。
      type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
      default = {};
      description = "プロファイル固有の Claude Code hooks（settings.json の hooks に merge される）";
    };
    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "プロファイル固有の環境変数（settings.json の env に merge される）";
    };
    extraFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = {};
      description = ''
        claude 設定ディレクトリ配下へ配置する追加ファイル。
        キーは設定ディレクトリからの相対パスで、.claude と .claude-private の両方へ展開される。
      '';
    };
    # listOf ではなく単一値にしている理由: CLAUDE_CODE_PLUGIN_DIRS の区切り文字を
    # 実機で確認できていない。moshi-plugin 1 つで足りる間は曖昧さを持ち込まない。
    pluginDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        CLAUDE_CODE_PLUGIN_DIRS へ渡すプラグインディレクトリ。
        claude 設定ディレクトリからの相対パスで指定し、root ごとに絶対パスへ展開される。
      '';
    };
  };

  config = {
    # uv を common に置く理由: natural-japanese skill の lint.py は PEP 723 形式で
    # `uv run` 前提のため、uv が無い環境では検出工程が丸ごと動かない。
    # pkgs.typescript を入れない理由: typescript-language-server は fallback に typescript_5 の
    # tsserver を焼き込み済みで、pkgs.typescript (7.x) は tsserver.js を前提にできない。
    home.packages = [ playwright-cli pkgs.uv pkgs.typescript-language-server ];

    # ~/.claude と ~/.claude-private の双方に同一内容を配置する理由:
    # 個人アカウント用の設定ディレクトリを CLAUDE_CONFIG_DIR=~/.claude-private で
    # 切り替えて使うため、ルール・プラグイン定義など宣言的に管理したいファイルは
    # 両方に展開する必要がある。一方で credentials やプロジェクト履歴などの
    # 動的データは home-manager 管理外のため自然にディレクトリごとに分離される。
    home.file =
      let
        # ベース定義（".claude/" prefix なし）。これを各 root に展開する。
        baseFiles = claudeDir: {
          "CLAUDE.md".source = ./claude-md/CLAUDE.md;
          "settings.json".source = mkSettingsJson claudeDir;
          # nix attrset に変換せず JSON 原文を置く理由: powerline.owloops.com が
          # 生成する設定で、再編集は GUI への貼り付け往復になるため。
          # .claude-private 側にも置く理由: v1.30.3 の探索パスは
          # os.homedir()/.claude 固定で CLAUDE_CONFIG_DIR を見ないが、
          # 上流が対応したとき片側だけ効かなくなるのを避ける。
          # autocompactBuffer に Studio 既定の 33000 を使わない理由: 33000 は warn 開始点
          # (window - 33000) で、auto-compact 発火点 (window - 13000) ではない。直前 20000
          # トークンが 0% に潰れる。GUI から貼り直すと既定値に戻るので注意。
          "claude-powerline.json".source = ./claude-powerline.json;
        }
        # gwsSkills / yutauraRules の attrset から ".claude/" prefix を剥がす
        // (lib.mapAttrs' (n: v:
              lib.nameValuePair (lib.removePrefix ".claude/" n) v
            ) gwsSkills.skillFiles)
        // (lib.mapAttrs' (n: v:
              lib.nameValuePair (lib.removePrefix ".claude/" n) v
            ) yutauraRules.ruleFiles)
        // config._claude.extraFiles;

        withRoot = root: lib.mapAttrs' (n: v:
          lib.nameValuePair "${root}/${n}" v
        ) (baseFiles "${config.home.homeDirectory}/${root}");
      in
        withRoot ".claude" // withRoot ".claude-private";
  };
}
