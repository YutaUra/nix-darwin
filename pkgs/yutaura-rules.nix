{ lib, fetchFromGitHub }:

let
  src = fetchFromGitHub {
    owner = "YutaUra";
    repo = "claude-marketplace";
    rev = "3a56db9c3d761f8d55f964ef343206fd441b4278";
    hash = "sha256-HoUowO4+BapeNGRS78fdDJ1MU6u/+2Z2qnwGReijn64=";
  };

  selectedRules = [
    "tdd-guidelines"
    "documentation-principles"
  ];

  ruleFiles = builtins.listToAttrs (map (name: {
    name = ".claude/rules/${name}.md";
    value = { source = "${src}/rules/${name}.md"; };
  }) selectedRules);
in
{
  inherit ruleFiles;
}
