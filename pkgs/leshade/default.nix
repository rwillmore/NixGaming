{ lib
, stdenv
, fetchFromGitHub
, python3
, qt6
, bash
}:

let
  py = python3.withPackages (ps: [
    ps.pyside6
  ]);
in
stdenv.mkDerivation {
  pname = "leshade";
  version = "2.1";

  src = fetchFromGitHub {
    owner = "Ishidawg";
    repo = "LeShade";
    rev = "8f9f0b419a7b3d0bf6559b8db74baf11f1f8a581";
    hash = "sha256-uRRUX1jdIaHsGuEQwZtWK0DiwtCrRziePYzCxSlsex4=";
  };

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtwayland
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/leshade
    cp -R . $out/share/leshade

    mkdir -p $out/bin
    cat > $out/bin/leshade <<SH
#!${bash}/bin/bash
set -euo pipefail
cd "$out/share/leshade"
exec ${py.interpreter} "$out/share/leshade/main.py" "\$@"
SH
    chmod +x $out/bin/leshade

    runHook postInstall
  '';

  postFixup = ''
    wrapQtApp $out/bin/leshade
  '';

  meta = with lib; {
    description = "LeShade, a ReShade manager for Linux";
    homepage = "https://github.com/Ishidawg/LeShade";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "leshade";
  };
}
