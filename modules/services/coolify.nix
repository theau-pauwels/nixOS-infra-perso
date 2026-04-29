{ config, lib, pkgs, ... }:

let
  cfg = config.personalInfra.services.coolify;
in
{
  options.personalInfra.services.coolify = {
    enable = lib.mkEnableOption "Coolify self-hosted PaaS";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "coolify.example.invalid";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/coolify";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;

    systemd.services.coolify = {
      description = "Coolify PaaS";
      after = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = ''
          ${pkgs.docker}/bin/docker run \
            -p ${toString cfg.port}:8000 \
            -v ${cfg.dataDir}:/data \
            ghcr.io/coollabsio/coolify:latest
        '';
        Restart = "always";
      };
    };
  };
}
