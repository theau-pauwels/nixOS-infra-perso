{ config, lib, pkgs, ... }:

let
  cfg = config.personalInfra.services.smtp;
  relayHost = "[${cfg.gmail.smtpHost}]:${toString cfg.gmail.smtpPort}";
  saslPasswd = pkgs.writeText "postfix-gmail-sasl-passwd" ''
    ${relayHost} ${cfg.gmail.username}:${cfg.gmail.passwordFilePlaceholder}
  '';
in
{
  options.personalInfra.services.smtp = {
    enable = lib.mkEnableOption "internal SMTP relay through Gmail";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "infra.theau.local";
      description = "Local mail domain used by the internal relay.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "smtp.infra.theau.local";
      description = "Hostname announced by Postfix.";
    };

    allowedNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "127.0.0.0/8"
        "10.0.0.0/8"
        "100.64.0.0/10"
      ];
      description = "Trusted networks allowed to relay mail through this SMTP service.";
    };

    listenInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "loopback-only" ];
      description = "Postfix inet_interfaces value. Keep loopback-only unless host firewall restricts LAN/VPN access.";
    };

    senderAddress = lib.mkOption {
      type = lib.types.str;
      default = "alerts@example.invalid";
      description = "Canonical sender address used for infrastructure notifications.";
    };

    gmail = {
      smtpHost = lib.mkOption {
        type = lib.types.str;
        default = "smtp.gmail.com";
        description = "Gmail SMTP submission host.";
      };

      smtpPort = lib.mkOption {
        type = lib.types.port;
        default = 587;
        description = "Gmail SMTP submission port.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "alerts@example.invalid";
        description = "Gmail or Google Workspace account used as upstream relay sender.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/gmail-smtp-app-password";
        description = "Path to the Gmail app password secret file. Do not commit this secret.";
      };

      passwordFilePlaceholder = lib.mkOption {
        type = lib.types.str;
        default = "REPLACE_WITH_RUNTIME_SECRET";
        description = "Build-safe placeholder. Replace this module with runtime secret wiring before production.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.postfix = {
      enable = true;
      inherit (cfg) domain hostname;
      networks = cfg.allowedNetworks;
      relayHost = relayHost;
      config = {
        inet_interfaces = lib.concatStringsSep ", " cfg.listenInterfaces;
        smtp_use_tls = "yes";
        smtp_tls_security_level = "encrypt";
        smtp_tls_CAfile = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        smtp_sasl_auth_enable = "yes";
        smtp_sasl_password_maps = "texthash:${saslPasswd}";
        smtp_sasl_security_options = "noanonymous";
        smtp_sasl_tls_security_options = "noanonymous";
        mynetworks = lib.concatStringsSep ", " cfg.allowedNetworks;
        relay_domains = "";
        smtp_generic_maps = "regexp:/etc/postfix/generic";
      };
    };

    environment.etc."postfix/generic".text = ''
      /^(.+)@${cfg.domain}$/ ${cfg.senderAddress}
      /^root@.+$/ ${cfg.senderAddress}
    '';

    assertions = [
      {
        assertion = !(builtins.elem "0.0.0.0/0" cfg.allowedNetworks);
        message = "personalInfra.services.smtp.allowedNetworks must not include 0.0.0.0/0; this would create an open relay risk.";
      }
    ];
  };
}
