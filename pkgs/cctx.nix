{ lib, rustPlatform, fetchFromGitHub, stdenv, libiconv }:

rustPlatform.buildRustPackage {
  pname = "cctx";
  version = "0.1.6";

  src = fetchFromGitHub {
    owner = "nwiizo";
    repo = "cctx";
    rev = "v0.1.6";
    hash = "sha256-Al+k0UQdUQg4i/j+EkebKcIbtS8adBWSzplHk0imLxU=";
  };

  cargoHash = "sha256-tVRwPxAvcNJDtAmU+NZ1bBvB04wtrRLElchoY4jgxMA=";

  # libiconv は新しい nixpkgs の apple-sdk が自動で propagate するが、
  # Linux 向けにも明示しておく
  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    libiconv
  ];

  doCheck = false;

  meta = with lib; {
    description = "Claude Code context manager for switching between multiple settings.json configurations";
    homepage = "https://github.com/nwiizo/cctx";
    license = licenses.mit;
    mainProgram = "cctx";
  };
}
