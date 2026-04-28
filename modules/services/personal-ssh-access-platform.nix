{ config, lib, ... }:

let
  cfg = config.personalInfra.services.personalSshAccessPlatform;
in
{
  options.personalInfra.services.personalSshAccessPlatform = {
    enable = lib.mkEnableOption "future personal SSH access platform";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Local listen address for a future web/API service.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8088;
      description = "Local listen port for a future web/API service.";
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = [
      "personalInfra.services.personalSshAccessPlatform is a skeleton only and does not implement certificate issuance."
    ];

    # TODO: implement package, database, SSO, CA public key deployment, CA
    # private key file handling, audit logs, and host principal policy.
  };
}
