# moshi-hook を nixpkgs ではなく自前パッケージ化する理由:
# moshi-hook はソース非公開でビルド済みバイナリのみ配布（cdn.getmoshi.app）されており、
# nixpkgs にも存在しない。そのため buildGoModule は使えず、公式配布の darwin arm64 バイナリを
# fetchurl で取得して wrap する。バージョン追従は brew と異なり手動（version と hash の更新）。
#
# 古い version をピンし続けられない理由:
# cdn.getmoshi.app は旧リリースを残さず削除する（v0.2.x 系は全て 404）。
# fetchurl の出力は固定出力派生なので GC 対象になり、nixpkgs 更新で
# この derivation のハッシュが変わると再ビルド = 再ダウンロードが走る。
# その時点で CDN から消えていると switch 全体が落ちるため、
# 「動いているから放置」はできず、最新版へ追従し続ける必要がある。
# 最新 version は https://cdn.getmoshi.app/hook/latest/version.txt で取得でき、
# sha256 は同リリースの checksums.txt に載っている。
{ stdenvNoCC, fetchurl, darwin }:

stdenvNoCC.mkDerivation rec {
  pname = "moshi-hook";
  version = "0.4.60";

  src = fetchurl {
    url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_Darwin_arm64.tar.gz";
    sha256 = "2929595c7cceed3c56beeebb3a1b4dd0376565fb4a21ff2deb41b37614630e69";
  };

  # GoReleaser 配布の tarball はサブディレクトリを持たずファイルが直下に並ぶため sourceRoot を明示する。
  # v0.4.60 時点では直下に moshi-hook / mata / README.md と docs/ が並ぶ。
  sourceRoot = ".";

  # Apple Silicon は arm64 バイナリに署名を要求する。GoReleaser 配布物は未署名のことがあり、
  # そのままだと実行時に SIGKILL されるため ad-hoc 署名を付与する。
  nativeBuildInputs = [ darwin.autoSignDarwinBinariesHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 moshi-hook $out/bin/moshi-hook
    # brew formula 同様に moshi エイリアスも張る。
    ln -s moshi-hook $out/bin/moshi
    runHook postInstall
  '';

  meta = {
    description = "Moshi notification hook daemon for Claude Code and other CLI agents";
    homepage = "https://getmoshi.app";
    platforms = [ "aarch64-darwin" ];
    mainProgram = "moshi-hook";
  };
}
