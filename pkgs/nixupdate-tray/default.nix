{ lib
, stdenvNoCC
, makeWrapper
, python3
}:

stdenvNoCC.mkDerivation {
  pname = "nixupdate-tray";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: !(lib.hasSuffix ".bak" (baseNameOf path));
  };
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec
    install -Dm755 nixupdate-tray.py $out/libexec/nixupdate-tray.py

    makeWrapper ${python3.withPackages (ps: with ps; [ pyqt6 ])}/bin/python3 $out/bin/nixupdate-tray \
      --add-flags $out/libexec/nixupdate-tray.py

    runHook postInstall
  '';

  meta = with lib; {
    description = "Lightweight NixOS flake update tray app";
    mainProgram = "nixupdate-tray";
    platforms = platforms.linux;
  };
}
