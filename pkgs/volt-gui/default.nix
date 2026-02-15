{ lib
, stdenv
, fetchFromGitHub
, makeWrapper
, python3
, pkexecPath ? "/run/wrappers/bin/pkexec"
}:

let
  py = python3.withPackages (ps: with ps; [
    pyside6
    requests
  ]);
in
stdenv.mkDerivation rec {
  pname = "volt-gui";
  version = "unstable-2026-02-15";

  src = fetchFromGitHub {
    owner = "pythonlover02";
    repo = "volt-gui";
    rev = "main";
    hash = "sha256-ElyeCsFja8HKfj9mjnZu68nRaX+GsK8/c+iwAfo+MkY=";
  };

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/volt-gui
    cp -r src/* $out/lib/volt-gui/

    mkdir -p $out/bin
    install -m755 scripts/volt-helper $out/bin/volt-helper-upstream

    substituteInPlace $out/lib/volt-gui/volt-gui.py \
      --replace '["pkexec", "/usr/local/bin/volt-helper"]' \
                '["$$${pkexecPath}", "$$${placeholder "out"}/bin/volt-helper"]'

    cat > $out/bin/volt-helper <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail

  "$${0%/*}/volt-helper-upstream" "$@"

uid="$${PKEXEC_UID:-0}"
  if [ "$uid" = "0" ] && [ -n "$${SUDO_UID:-}" ]; then
  uid="$SUDO_UID"
fi

home="$(getent passwd "$uid" | cut -d: -f6)"
destdir="$home/.local/bin"
dest="$destdir/volt"

src="/usr/local/bin/volt"
if [ ! -f "$src" ]; then
  src="/usr/bin/volt"
fi

if [ ! -f "$src" ]; then
  echo "Could not find generated volt script at /usr/local/bin/volt or /usr/bin/volt" >&2
  exit 1
fi

mkdir -p "$destdir"
cp -f "$src" "$dest"
chown "$uid":"$uid" "$destdir" "$dest" 2>/dev/null || true
chmod 755 "$dest" || true

echo "Installed volt to $dest"
WRAP
    chmod 755 $out/bin/volt-helper

    makeWrapper ${py}/bin/python $out/bin/volt-gui \
      --add-flags $out/lib/volt-gui/volt-gui.py \
      --prefix PYTHONPATH : $out/lib/volt-gui

    mkdir -p $out/share/applications
    cat > $out/share/applications/volt-gui.desktop <<DESK
[Desktop Entry]
Name=volt-gui
Comment=Gaming tuning GUI
Exec=volt-gui
Icon=preferences-system
Terminal=false
Type=Application
Categories=Utility;System;
DESK

    runHook postInstall
  '';

  meta = with lib; {
    description = "Linux gaming tuning GUI (CPU/GPU/Disk/Kernel) with profile support";
    homepage = "https://github.com/pythonlover02/volt-gui";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    mainProgram = "volt-gui";
  };
}
