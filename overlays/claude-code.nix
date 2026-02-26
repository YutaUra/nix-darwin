# nixpkgs の claude-code が古い場合に最新版へ差し替える overlay
# nixpkgs が追いついたらこのファイルと claude-code-package-lock.json を削除する
final: prev: {
  claude-code = prev.buildNpmPackage (finalAttrs: {
    pname = "claude-code";
    version = "2.1.59";

    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${finalAttrs.version}.tgz";
      hash = "sha256-Dam9aJ0qBdqU40ACfzGQHuytW6ur0fMLm8D5fIKd1TE=";
    };

    npmDepsHash = "sha256-K+8xoBc3apvxQ9hCpYywqgBcfLxMWSxacgJcMH8mK7E=";

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
