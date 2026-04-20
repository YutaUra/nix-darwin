# nixpkgs の claude-code が古い場合に最新版へ差し替える overlay
# nixpkgs が追いついたらこのファイルと claude-code-manifest.json を削除する
final: prev:
let
  stdenv = prev.stdenvNoCC;
  baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
  manifest = prev.lib.importJSON ./claude-code-manifest.json;
  platformKey = "${stdenv.hostPlatform.node.platform}-${stdenv.hostPlatform.node.arch}";
  platformManifestEntry = manifest.platforms.${platformKey};
in
{
  claude-code = stdenv.mkDerivation (finalAttrs: {
    pname = "claude-code";
    inherit (manifest) version;

    src = prev.fetchurl {
      url = "${baseUrl}/${finalAttrs.version}/${platformKey}/claude";
      sha256 = platformManifestEntry.checksum;
    };

    dontUnpack = true;
    dontBuild = true;
    __noChroot = stdenv.hostPlatform.isDarwin;
    # bun ランタイムとして実行されないよう strip を無効化
    dontStrip = true;

    nativeBuildInputs = [
      prev.installShellFiles
      prev.makeBinaryWrapper
    ]
    ++ prev.lib.optionals stdenv.hostPlatform.isElf [ prev.autoPatchelfHook ];

    strictDeps = true;

    installPhase = ''
      runHook preInstall

      installBin $src

      wrapProgram $out/bin/claude \
        --set DISABLE_AUTOUPDATER 1 \
        --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
        --set DISABLE_INSTALLATION_CHECKS 1 \
        --set USE_BUILTIN_RIPGREP 0 \
        --prefix PATH : ${
          prev.lib.makeBinPath (
            [
              prev.procps
              prev.ripgrep
            ]
            ++ prev.lib.optionals stdenv.hostPlatform.isLinux [
              prev.bubblewrap
              prev.socat
            ]
          )
        }

      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [
      prev.writableTmpDirAsHomeHook
      prev.versionCheckHook
    ];
    versionCheckKeepEnvironment = [ "HOME" ];
    versionCheckProgramArg = "--version";

    meta = {
      description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
      homepage = "https://github.com/anthropics/claude-code";
      license = prev.lib.licenses.unfree;
      mainProgram = "claude";
    };
  });
}
