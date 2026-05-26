{ lib, stdenv, fetchFromGitHub, jdk21, maven, makeWrapper, nodejs }:

stdenv.mkDerivation rec {
  pname = "joal";
  version = "2.1.37-patched";

  src = fetchFromGitHub {
    owner = "anthonyraymond";
    repo = "joal";
    rev = "2.1.37";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # placeholder, will be fixed by build
  };

  nativeBuildInputs = [ jdk21 maven makeWrapper nodejs ];

  patches = [ ./stomp-permit.patch ];

  buildPhase = ''
    mvn package -DskipTests -pl '!src/test' 2>&1
  '';

  installPhase = ''
    mkdir -p "$out/share/joal" "$out/bin"
    cp target/jack-of-all-trades-*.jar "$out/share/joal/"
    makeWrapper "${jdk21}/bin/java" "$out/bin/joal" \
      --add-flags "-jar $out/share/joal/jack-of-all-trades-${version}.jar" \
      --add-flags "--joal-conf=\''${JOAL_CONF_DIR:-/var/lib/joal}" \
      --add-flags "--server.port=\''${JOAL_PORT:-8080}" \
      --add-flags "--server.address=127.0.0.1" \
      --add-flags "--spring.main.web-environment=true" \
      --add-flags "--spring.profiles.active=default,web-environment" \
      --add-flags "--joal.ui.path.prefix=\''${JOAL_UI_PATH:-joal-vps}" \
      --add-flags "--joal.ui.secret-token=\''${JOAL_UI_SECRET:-}"
  '';
}
