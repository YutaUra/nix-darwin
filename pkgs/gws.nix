{ lib, rustPlatform, fetchFromGitHub, pkg-config, libiconv, stdenv }:

rustPlatform.buildRustPackage {
  pname = "gws";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "googleworkspace";
    repo = "cli";
    rev = "6ed836c81c6ed4834a434adc40a14bb2e6f3f3b9";
    hash = "sha256-Ar21dUPuHoJY+z1I80ckT5EcIrpGrmMpi2VAXpBSDwA=";
  };

  cargoHash = "sha256-zmFQEtDisZ7lpgiMv0X6F3R/j/1SHw9vmWA3qnauO0Y=";

  nativeBuildInputs = [ pkg-config ];
  # libiconv は新しい nixpkgs の apple-sdk が自動で propagate するが、
  # Linux 向けにも明示しておく
  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    libiconv
  ];

  doCheck = false;

  meta = with lib; {
    description = "Google Workspace CLI — dynamic command surface from Discovery Service";
    homepage = "https://github.com/googleworkspace/cli";
    license = licenses.asl20;
    mainProgram = "gws";
  };
}
