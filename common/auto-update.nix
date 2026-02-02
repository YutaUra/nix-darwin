{ pkgs, username, configName, ... }:
let
  flakeDir = "/Users/${username}/.config/nix-darwin";
  logFile = "/tmp/nix-darwin-auto-update.log";

  notify = title: message:
    ''osascript -e 'display notification "${message}" with title "${title}"' '';

  updateScript = pkgs.writeShellScriptBin "nix-darwin-auto-update" ''
    export PATH=/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin

    echo "=== $(date) ===" >> ${logFile}

    ${notify "nix-darwin" "自動更新を開始します"}

    cd ${flakeDir} || exit 1

    echo "git pull..." >> ${logFile}
    if ! git pull >> ${logFile} 2>&1; then
      echo "git pull failed" >> ${logFile}
      ${notify "nix-darwin" "自動更新失敗: git pull に失敗しました"}
      exit 1
    fi

    echo "darwin-rebuild switch..." >> ${logFile}
    if sudo darwin-rebuild switch --flake ${flakeDir}#${configName} >> ${logFile} 2>&1; then
      echo "done: 0" >> ${logFile}
      ${notify "nix-darwin" "自動更新が完了しました"}
    else
      echo "done: $?" >> ${logFile}
      ${notify "nix-darwin" "自動更新失敗: darwin-rebuild に失敗しました"}
      exit 1
    fi
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
      ];
      StandardOutPath = logFile;
      StandardErrorPath = logFile;
    };
  };
}
