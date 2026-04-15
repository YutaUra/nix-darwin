{ pkgs, lib, config, ... }:
let
  gwsSkills = import ../../pkgs/gws-skills.nix { inherit (pkgs) lib fetchFromGitHub; };

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
      ".claude/rules/documentation-principles.md".source = ./claude-md/rules/documentation-principles.md;
      ".claude/rules/tdd-guidelines.md".source = ./claude-md/rules/tdd-guidelines.md;

      # Skills
      ".claude/skills/claude-code-rules/SKILL.md".source = ./claude-md/skills/claude-code-rules/SKILL.md;
      ".claude/skills/claude-code-rules/references/rule-format.md".source = ./claude-md/skills/claude-code-rules/references/rule-format.md;

      ".claude/skills/playwright-cli/SKILL.md".source = ./claude-md/skills/playwright-cli/SKILL.md;
      ".claude/skills/playwright-cli/references/request-mocking.md".source = ./claude-md/skills/playwright-cli/references/request-mocking.md;
      ".claude/skills/playwright-cli/references/running-code.md".source = ./claude-md/skills/playwright-cli/references/running-code.md;
      ".claude/skills/playwright-cli/references/session-management.md".source = ./claude-md/skills/playwright-cli/references/session-management.md;
      ".claude/skills/playwright-cli/references/storage-state.md".source = ./claude-md/skills/playwright-cli/references/storage-state.md;
      ".claude/skills/playwright-cli/references/test-generation.md".source = ./claude-md/skills/playwright-cli/references/test-generation.md;
      ".claude/skills/playwright-cli/references/tracing.md".source = ./claude-md/skills/playwright-cli/references/tracing.md;
      ".claude/skills/playwright-cli/references/video-recording.md".source = ./claude-md/skills/playwright-cli/references/video-recording.md;

      ".claude/skills/tuning/SKILL.md".source = ./claude-md/skills/tuning/SKILL.md;
      ".claude/skills/tuning/references/config-hierarchy.md".source = ./claude-md/skills/tuning/references/config-hierarchy.md;

      ".claude/settings.json".text = builtins.toJSON {
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
        } // config._claude.extraPlugins;
        env = {
          CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
          DISABLE_AUTOUPDATER = "1";
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
      };
    } // gwsSkills.skillFiles;
  };
}
