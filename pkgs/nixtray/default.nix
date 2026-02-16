
 { lib
, python3
, libnotify
}:

python3.pkgs.buildPythonApplication rec {
  pname = "nixtray";
  version = "0.1.0";
  pyproject = false;

  src = ./.;

  propagatedBuildInputs = with python3.pkgs; [
    pyqt6
  ];

  nativeBuildInputs = [
    python3.pkgs.setuptools
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/${python3.libPrefix}/site-packages
    cp -r nixtray $out/lib/${python3.libPrefix}/site-packages/

    mkdir -p $out/bin
    cat > $out/bin/nixtray <<EOF
#!${python3}/bin/python3
import runpy, sys
sys.exit(runpy.run_module("nixtray", run_name="__main__") is None)
EOF
    chmod +x $out/bin/nixtray

    runHook postInstall
  '';

  meta = with lib; {
    description = "NixOS Update Tray (Qt system tray app)";
    platforms = platforms.linux;
  };
}

