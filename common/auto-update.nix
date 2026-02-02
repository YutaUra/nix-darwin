{ pkgs, username, configName, ... }:
let
  flakeDir = "/Users/${username}/.config/nix-darwin";
  logFile = "/tmp/nix-darwin-auto-update.log";

  updateScript = pkgs.writeShellScriptBin "nix-darwin-auto-update" ''
    export PATH=/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin

    echo "=== $(date) ===" >> ${logFile}

    cd ${flakeDir} || exit 1

    echo "git pull..." >> ${logFile}
    git pull >> ${logFile} 2>&1 || exit 1

    echo "darwin-rebuild switch..." >> ${logFile}
    sudo darwin-rebuild switch --flake ${flakeDir}#${configName} >> ${logFile} 2>&1

    echo "done: $?" >> ${logFile}
  '';
in
{
  # darwin-rebuild switch を passwordless sudo で許可
  environment.etc."sudoers.d/nix-darwin-auto-update".text = ''
    ${username} ALL=(root) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild *
  '';

  launchd.user.agents.nix-darwin-auto-update = {
    serviceConfig = {
      Program = "${updateScript}/bin/nix-darwin-auto-update";
      StartCalendarInterval = [
        { Hour = 9; Minute = 0; }
        { Hour = 23; Minute = 0; }
      ];
      StandardOutPath = logFile;
      StandardErrorPath = logFile;
    };
  };
}
