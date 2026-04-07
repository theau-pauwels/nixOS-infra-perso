{
  lib,
  pkgs,
  src,
}:

let
  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      bcrypt
      certifi
      flask
      gunicorn
      icmplib
      jinja2
      packaging
      psutil
      pydantic
      pyotp
      requests
      sqlalchemy
      tzlocal
      (ps."flask-cors")
      (ps."python-jose")
      (ps."sqlalchemy-utils")
    ]
  );
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "wgdashboard";
  version = "4.3.2";
  inherit src;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/wgdashboard" "$out/bin"
    cp -R "$src/src/." "$out/share/wgdashboard/"
    chmod -R u+w "$out/share/wgdashboard"

    cp ${./files/gunicorn.conf.py} "$out/share/wgdashboard/gunicorn.conf.py"
    cp ${./files/DashboardPlugins.py} "$out/share/wgdashboard/modules/DashboardPlugins.py"
    cp ${./files/ConnectionString.py} "$out/share/wgdashboard/modules/ConnectionString.py"

    chmod +x "$out/share/wgdashboard/wgd.sh"

    makeWrapper ${pythonEnv}/bin/gunicorn "$out/bin/wgdashboard-gunicorn" \
      --chdir "$out/share/wgdashboard" \
      --prefix PYTHONPATH : "$out/share/wgdashboard:$out/share/wgdashboard/modules" \
      --prefix PATH : "${lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.findutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.iproute2
        pkgs.iputils
        pkgs.procps
        pkgs.traceroute
        pkgs.wireguard-tools
      ]}" \
      --add-flags "-c $out/share/wgdashboard/gunicorn.conf.py dashboard:app"

    runHook postInstall
  '';
}
