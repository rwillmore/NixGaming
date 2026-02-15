{ lib
, stdenvNoCC
, fetchFromGitHub
, makeWrapper
, python3
, python3Packages
, xdg-utils
, git
}:

stdenvNoCC.mkDerivation rec {
  pname = "leshade";
  version = "2.0";

  src = fetchFromGitHub {
    owner = "Ishidawg";
    repo = "LeShade";
    rev = "2.0";
    sha256 = lib.fakeSha256;
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  # Runtime deps
  propagatedBuildInputs = [
    (python3.withPackages (ps: with ps; [
      pyside6
      certifi
    ]))
    xdg-utils
    git
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/leshade
    cp -r ./* $out/share/leshade/

    mkdir -p $out/bin

    makeWrapper ${python3}/bin/python $out/bin/leshade \
      --add-flags "$out/share/leshade/main.py" \
      --set PYTHONPATH "$out/share/leshade" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils git ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "LeShade, a simple ReShade installer helper";
    homepage = "https://github.com/Ishidawg/LeShade";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
