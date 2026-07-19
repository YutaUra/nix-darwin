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

  basePermissions = [
    "WebSearch"
    "Bash(playwright-cli:*)"
    "mcp__plugin_context7_context7__resolve-library-id"
    "mcp__plugin_context7_context7__query-docs"
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
      "greptile@claude-plugins-official" = true;
      "document-skills@anthropic-agent-skills" = true;
      "figma-implementation-core@sapuri-agent-plugins" = true;
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
      CLAUDE_CODE_EFFORT_LEVEL = "low";
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
    # デフォルトを最上位モデル Fable にする理由:
    # Fable は Anthropic 最高性能のモデル（料金は Opus の約2倍、高 effort だと
    # 1ターン数分かかることもある）。全会話の起点となる default に据えることで、
    # 素の能力の高さを常時活かす。
    # effortLevel は 2.1.210 時点では機能しないため、実効値は env の
    # CLAUDE_CODE_EFFORT_LEVEL 側で指定している。ここは宣言的な意図の記録として残す。
    # effort を low にする理由:
    # default は毎ターン走るためコストとレイテンシが直接効く。Fable は low でも
    # 旧モデルの xhigh/max を上回ることが多く「low=浅い」が当てはまらないため、
    # 軽快さとコストを優先して low を既定にする。重いタスクは都度 effort を上げて escalate する。
    # "fable"/"opus" エイリアスを使わない理由:
    # Claude Code 独自エイリアスは最新世代に自動追従するが、実際に解決される
    # モデル ID が CLI 側の更新タイミングに依存し不透明。
    # 公式 docs (docs.claude.com) でも 4.6 世代以降のモデル ID は pinned snapshot と
    # 明記されているため、宣言的設定では具体的な ID を直接指定する。
    # 出力先 JSON は常に ~/.claude/runcat-usage.json 固定なので、
    # .claude-private 側で動かしても RunCat Neo の参照先は 1 つで済む。
    statusLine = {
      type = "command";
      command = lib.getExe' runcat-statusline "runcat-statusline";
    };
    model = "claude-fable-5";
    effortLevel = "low";
    autoMemoryEnabled = false;
    language = "日本語";
    feedbackSurveyRate = 0;
  } // lib.optionalAttrs (config._claude.extraHooks != {}) {
    hooks = config._claude.extraHooks;
  }));
in
{
  options._claude = {
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
