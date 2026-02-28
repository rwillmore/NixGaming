{ lib
, rustPlatform
, fetchFromGitHub
, buildNpmPackage
, makeDesktopItem
, pkg-config
, openssl
, dbus
, glib
, gtk3
, cairo
, pango
, gdk-pixbuf
, atk
, webkitgtk_4_1
, libsoup_3
, wrapGAppsHook3
, librsvg
}:

let
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "rwillmore";
    repo = "nixos-manager";
    rev = "a9b6d3269f4d35de4361cf0079f4ae2387daf8cd";
    hash = "sha256-+E2VE4a1EYTRsahf5ClzRWQksodSk0KjTPIjaq2HHuQ=";
  };

  desktopFile = makeDesktopItem {
    name = "nixie";
    desktopName = "Nixie";
    exec = "nixie";
    icon = "nixie";
    comment = "NixOS flake config manager";
    categories = [ "System" "Settings" ];
    terminal = false;
    startupWMClass = "nixie";
  };

  frontend = buildNpmPackage {
    pname = "nixie-frontend";
    inherit version src;
    npmDepsHash = "sha256-yUGCNMuTU37advuWj3hMt0FY8ZigcbEx7Xdvyr+BPHk=";
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist $out/
      runHook postInstall
    '';
  };

in
rustPlatform.buildRustPackage {
  pname = "nixie";
  inherit version src;

  cargoRoot = "src-tauri";
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    openssl
    dbus
    glib
    gtk3
    cairo
    pango
    gdk-pixbuf
    atk
    webkitgtk_4_1
    libsoup_3
    librsvg
  ];

  preBuild = ''
    cp -r ${frontend}/dist dist/
  '';

  doCheck = false;

  # Prepend NixOS system paths so the app can find nix, git, sudo, etc.
  # when launched from a KDE desktop session without a login shell.
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : /run/wrappers/bin:/run/current-system/sw/bin
    )
  '';

  # cargoRoot sets up vendor/lockfile correctly but the build hook doesn't
  # cd into it; override buildPhase to run cargo from src-tauri/ directly.
  # Cargo traverses parent dirs for .cargo/config.toml so vendor still works.
  buildPhase = ''
    runHook preBuild
    pushd src-tauri
    cargo build --release --offline
    popd
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 src-tauri/target/release/nixie $out/bin/nixie
    install -Dm644 src-tauri/icons/128x128@2x.png \
      $out/share/icons/hicolor/256x256/apps/nixie.png
    install -Dm644 ${desktopFile}/share/applications/nixie.desktop \
      $out/share/applications/nixie.desktop
    runHook postInstall
  '';

  meta = with lib; {
    description = "NixOS flake config manager (Tauri/React)";
    homepage = "https://github.com/rwillmore/nixos-manager";
    license = licenses.mit;
    mainProgram = "nixie";
    platforms = platforms.linux;
  };
}
