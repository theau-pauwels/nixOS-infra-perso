{
  lib,
  stdenv,
  fetchurl,
  jre,
  makeWrapper,
}:

stdenv.mkDerivation rec {
  pname = "joal";
  version = "2.1.37";

  src = fetchurl {
    url = "https://github.com/anthonyraymond/joal/releases/download/${version}/joal.tar.gz";
    hash = "sha256-B4lwzlO71pyacjLGEX6L10fqzULC5vhOC5enIrrcLrg=";
  };

  nativeBuildInputs = [ makeWrapper ];

  unpackPhase = ''
    runHook preUnpack
    mkdir -p src
    tar xzf "$src" -C src
    cd src
    runHook postUnpack
  '';

  installPhase = ''
    mkdir -p "$out/share/joal" "$out/bin"

    cp *.jar "$out/share/joal/"
    cp -r config "$out/share/joal/" 2>/dev/null || true

    makeWrapper "${jre}/bin/java" "$out/bin/joal" \
      --add-flags "-jar $out/share/joal/jack-of-all-trades-${version}.jar" \
      --add-flags "--joal-conf=\''${JOAL_CONF_DIR:-/var/lib/joal}" \
      --add-flags "--server.port=\''${JOAL_PORT:-5082}" \
      --add-flags "--server.address=127.0.0.1"
  '';

  meta = with lib; {
    description = "An open source command line ratio booster for torrent";
    homepage = "https://github.com/anthonyraymond/joal";
    license = licenses.asl20;
    platforms = platforms.linux;
    mainProgram = "joal";
  };
}
