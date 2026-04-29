{ config, lib, pkgs, ... }:

let
  cfg = config.personalInfra.services.git;
in
{
  options.personalInfra.services.git = {
    enable = lib.mkEnableOption "self-hosted Git platform (Gitea/Forgejo)";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "git.example.invalid";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/gitea";
    };

    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
    };
  };

  config = lib.mkIf cfg.enable {
    services.gitea = {
      enable = true;
      appName = "Theau Git";
      rootUrl = "https://${cfg.domain}";
      httpPort = cfg.httpPort;
      stateDir = cfg.dataDir;
      settings = {
        server = {
          SSH_PORT = cfg.sshPort;
        };
        service = {
          DISABLE_REGISTRATION = true;
        };
      };
    };
  };
}
