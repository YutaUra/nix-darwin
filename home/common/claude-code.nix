{ pkgs, ... }:
let
  gwsSkills = import ../../pkgs/gws-skills.nix { inherit (pkgs) lib fetchFromGitHub; };
in
{
  home.file = {
    ".claude/CLAUDE.md".source = ./claude-md/CLAUDE.md;
    ".claude/rules/documentation-principles.md".source = ./claude-md/rules/documentation-principles.md;
    ".claude/rules/tdd-guidelines.md".source = ./claude-md/rules/tdd-guidelines.md;

    # Skills
    ".claude/skills/claude-code-rules/SKILL.md".source = ./claude-md/skills/claude-code-rules/SKILL.md;
    ".claude/skills/claude-code-rules/references/rule-format.md".source = ./claude-md/skills/claude-code-rules/references/rule-format.md;

    ".claude/settings.json".text = builtins.toJSON {
      enabledPlugins = {
        "figma@claude-plugins-official" = true;
        "code-review@claude-plugins-official" = true;
        "commit-commands@claude-plugins-official" = true;
        "frontend-design@claude-plugins-official" = true;
        "playwright@claude-plugins-official" = true;
        "pr-review-toolkit@claude-plugins-official" = true;
        "context7@claude-plugins-official" = true;
        "typescript-lsp@claude-plugins-official" = true;
        "serena@claude-plugins-official" = true;
        "feature-dev@claude-plugins-official" = true;
        "security-guidance@claude-plugins-official" = true;
        "explanatory-output-style@claude-plugins-official" = true;
        "ralph-loop@claude-plugins-official" = true;
        "learning-output-style@claude-plugins-official" = true;
        "greptile@claude-plugins-official" = true;
        "stripe@claude-plugins-official" = true;
        "superpowers@claude-plugins-official" = true;
        "example-skills@anthropic-agent-skills" = true;
        "document-skills@anthropic-agent-skills" = true;
      };
      env = {
        DISABLE_AUTOUPDATER = "1";
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      };
      language = "日本語";
    };
  } // gwsSkills.skillFiles;
}
