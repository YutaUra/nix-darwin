{ pkgs, lib, config, ... }:
let
  gwsSkills = import ../../pkgs/gws-skills.nix { inherit (pkgs) lib fetchFromGitHub; };
  yutauraRules = import ../../pkgs/yutaura-rules.nix { inherit (pkgs) lib fetchFromGitHub; };

  # buildNpmPackage を使わない理由:
  # v0.1.1 で頻繁に更新され、alpha 版 playwright 依存で npmDepsHash 維持コストが高い。
  playwright-cli = pkgs.writeShellScriptBin "playwright-cli" ''
    exec ${pkgs.lib.getExe pkgs.nodejs} ${pkgs.lib.getExe' pkgs.nodejs "npx"} --yes @playwright/cli@latest "$@"
  '';

  basePermissions = [
    "WebSearch"
    "mcp__plugin_context7_context7__resolve-library-id"
    "mcp__plugin_context7_context7__query-docs"
  ];

  settingsJson = pkgs.writeText "claude-settings.json" (builtins.toJSON {
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
      "learning-output-style@claude-plugins-official" = true;
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
      # CLAUDE_CODE_USE_BEDROCK = "1";
      # AWS_PROFILE = "jp-sandbox";
      # ANTHROPIC_MODEL = "jp.anthropic.claude-sonnet-4-5-20250929-v1:0";
      # AWS_REGION = "ap-northeast-1";
    };
    permissions = {
      allow = basePermissions ++ config._claude.extraPermissions;
    };
    model = "opus";
    effortLevel = "high";
    autoMemoryEnabled = false;
    defaultMode = "auto";
    language = "日本語";
    feedbackSurveyRate = 0;
  });
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
  };

  config = {
    home.packages = [ playwright-cli ];

    home.file = {
      ".claude/CLAUDE.md".source = ./claude-md/CLAUDE.md;
    } // gwsSkills.skillFiles // yutauraRules.ruleFiles;

    # settings.json を symlink ではなくコピーで配置する理由:
    # cctx (Claude Code context manager) は ~/.claude/settings.json を直接書き換える。
    # home.file は Nix store への read-only symlink を作るため cctx の write が
    # 失敗する。よって activation 時に「ファイルが存在しない場合のみ」コピーし、
    # 以降は cctx の管理に委ねる。Nix 側で設定を更新したい場合は当該ファイルを
    # 手動削除して home-manager switch を再実行する。
    home.activation.installClaudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      claudeSettings="${config.home.homeDirectory}/.claude/settings.json"
      if [[ ! -e "$claudeSettings" && ! -L "$claudeSettings" ]]; then
        run mkdir -p "${config.home.homeDirectory}/.claude"
        run install -m 644 ${settingsJson} "$claudeSettings"
      fi
    '';
  };
}
