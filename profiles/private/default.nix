{ pkgs, ... }: {
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "1password-cli"
      "claude-code"
    ];
}
