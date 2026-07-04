# moshi-hook を nixpkgs ではなく自前パッケージ化する理由:
# moshi-hook はソース非公開でビルド済みバイナリのみ配布（cdn.getmoshi.app）されており、
# nixpkgs にも存在しない。そのため buildGoModule は使えず、公式配布の darwin arm64 バイナリを
# fetchurl で取得して wrap する。バージョン追従は brew と異なり手動（version と hash の更新）。
{ stdenvNoCC, fetchurl, darwin }:

stdenvNoCC.mkDerivation rec {
  pname = "moshi-hook";
  version = "0.2.38";

  src = fetchurl {
    url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_Darwin_arm64.tar.gz";
    sha256 = "def83c441be94c100dc30b6fff35b53c1e6f4ff4d15642f59708b4218ca0514f";
  };

  # GoReleaser 配布の tarball はサブディレクトリを持たずファイルが直下に並ぶため sourceRoot を明示する。
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
