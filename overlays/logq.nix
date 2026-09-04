# MnO2/logq — Web サーバーログを SQL で分析する CLI。
# nixpkgs に存在しないため overlay で追加する。
# buildRustPackage でソースビルドしない理由:
# 公式リリースに aarch64-darwin の prebuilt binary が提供されており、
# Rust toolchain でのフルビルドを避けられる。
# 更新するときは version と hash を書き換える（hash は
# `nix store prefetch-file <url>` で取得できる）。
final: _prev: {
  logq = final.stdenvNoCC.mkDerivation rec {
    pname = "logq";
    version = "0.2.0";
    src = final.fetchurl {
      url = "https://github.com/MnO2/logq/releases/download/v${version}/logq-aarch64-apple-darwin.tar.xz";
      hash = "sha256-Hqo7ggC5nvaulYdP9rtkkSgSH5hr3Ve3UsxD48VSHjs=";
    };
    installPhase = ''
      runHook preInstall
      install -Dm755 logq $out/bin/logq
      runHook postInstall
    '';
    meta = {
      description = "Analyzing log files in SQL with command-line toolkit";
      homepage = "https://github.com/MnO2/logq";
      platforms = [ "aarch64-darwin" ];
      mainProgram = "logq";
    };
  };
}
