{ lib
, rustPlatform
, fetchFromGitHub
, buildNpmPackage
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
    rev = "a5a372c4a0feb268d85596212939ae1605fd50aa";
    hash = "sha256-6OyqjVqIdLZex/FOz/R0xTNvEJ2i2O7V/9VCFQp8zNA=";
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

  installPhase = ''
    runHook preInstall
    install -Dm755 src-tauri/target/release/nixie $out/bin/nixie
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
