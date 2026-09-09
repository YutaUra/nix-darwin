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

    if rendered="$(printf '%s' "$payload" | ${lib.getExe claude-powerline})" && [ -n "$rendered" ]; then
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

  settingsJson = pkgs.writeText "claude-settings.json" (builtins.toJSON ({
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
    } // config._claude.extraPlugins;
    env = {
      CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
      DISABLE_AUTOUPDATER = "1";
      # DISABLE_AUTOUPDATER=1 だけだと plugin の auto-update も止まるため、
      # plugin だけは更新を受け取りたいので FORCE_AUTOUPDATE_PLUGINS で復活させる。
      # 個別 marketplace の auto-update on/off は /plugin UI で別途 toggle する必要あり。
      FORCE_AUTOUPDATE_PLUGINS = "1";
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
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
      default = "claude-opus-5";
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
      type = lib.types.attrs;
      default = {};
      description = "プロファイル固有の Claude Code hooks（settings.json の hooks に merge される）";
    };
  };

  config = {
    home.packages = [ playwright-cli ];

    # ~/.claude と ~/.claude-private の双方に同一内容を配置する理由:
    # 個人アカウント用の設定ディレクトリを CLAUDE_CONFIG_DIR=~/.claude-private で
    # 切り替えて使うため、ルール・プラグイン定義など宣言的に管理したいファイルは
    # 両方に展開する必要がある。一方で credentials やプロジェクト履歴などの
    # 動的データは home-manager 管理外のため自然にディレクトリごとに分離される。
    home.file =
      let
        # ベース定義（".claude/" prefix なし）。これを各 root に展開する。
        baseFiles = {
          "CLAUDE.md".source = ./claude-md/CLAUDE.md;
          "settings.json".source = settingsJson;
          # nix attrset に変換せず JSON 原文を置く理由: powerline.owloops.com が
          # 生成する設定で、再編集は GUI への貼り付け往復になるため。
          # .claude-private 側にも置く理由: v1.30.3 の探索パスは
          # os.homedir()/.claude 固定で CLAUDE_CONFIG_DIR を見ないが、
          # 上流が対応したとき片側だけ効かなくなるのを避ける。
          "claude-powerline.json".source = ./claude-powerline.json;
        }
        # gwsSkills / yutauraRules の attrset から ".claude/" prefix を剥がす
        // (lib.mapAttrs' (n: v:
              lib.nameValuePair (lib.removePrefix ".claude/" n) v
            ) gwsSkills.skillFiles)
        // (lib.mapAttrs' (n: v:
              lib.nameValuePair (lib.removePrefix ".claude/" n) v
            ) yutauraRules.ruleFiles);

        withRoot = root: lib.mapAttrs' (n: v:
          lib.nameValuePair "${root}/${n}" v
        ) baseFiles;
      in
        withRoot ".claude" // withRoot ".claude-private";
  };
}
