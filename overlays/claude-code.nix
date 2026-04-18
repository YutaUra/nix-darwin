# nixpkgs の claude-code が古い場合に最新版へ差し替える overlay
# nixpkgs が追いついたらこのファイルと claude-code-package-lock.json を削除する
final: prev: {
  claude-code = prev.buildNpmPackage (finalAttrs: {
    pname = "claude-code";
    version = "2.1.114";

    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${finalAttrs.version}.tgz";
      hash = "sha256-r78N6eE/8JQsHP8XTWP9efkbzkmuV+o7JSB1GxrlE3E=";
    };

    npmDepsHash = "sha256-ymfM4CGoBnotxinqsf51Mjr7Uh5Rl1EIFfLhd14a3uc=";

    strictDeps = true;

    postPatch = ''
      cp ${./claude-code-package-lock.json} package-lock.json

      substituteInPlace cli.js \
            --replace-fail '#!/bin/sh' '#!/usr/bin/env sh'
    '';

    dontNpmBuild = true;

    env.AUTHORIZED = "1";

    postInstall = ''
      wrapProgram $out/bin/claude \
        --set DISABLE_AUTOUPDATER 1 \
        --set DISABLE_INSTALLATION_CHECKS 1 \
        --unset DEV \
        --prefix PATH : ${
          prev.lib.makeBinPath (
            [ prev.procps ]
            ++ prev.lib.optionals prev.stdenv.hostPlatform.isLinux [
              prev.bubblewrap
              prev.socat
            ]
          )
        }
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [
      prev.writableTmpDirAsHomeHook
      prev.versionCheckHook
    ];
    versionCheckKeepEnvironment = [ "HOME" ];

    meta = {
      description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
      homepage = "https://github.com/anthropics/claude-code";
      license = prev.lib.licenses.unfree;
      mainProgram = "claude";
    };
  });
}
