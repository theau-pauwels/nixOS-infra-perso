{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.personalInfra.services.smtp;
  relayHost = "[${cfg.gmail.smtpHost}]:${toString cfg.gmail.smtpPort}";
  postfixPackage = config.services.postfix.package;
  dangerousNetworks = [
    "0.0.0.0/0"
    "::/0"
  ];
  customSmtpdArgs = [
    "-o"
    "smtpd_sasl_auth_enable=no"
    "-o"
    "smtpd_client_restrictions=permit_mynetworks,reject"
    "-o"
    "smtpd_relay_restrictions=permit_mynetworks,reject_unauth_destination"
    "-o"
    "smtpd_recipient_restrictions=permit_mynetworks,reject_unauth_destination"
    "-o"
    "milter_macro_daemon_name=ORIGINATING"
  ];
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

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "loopback-only";
      description = ''
        Postfix inet_interfaces value. Use loopback-only by default; set a
        concrete LAN or VPN address before opening the firewall.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 587;
      description = "Internal SMTP listener port for trusted LAN/VPN clients.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the SMTP port in the host firewall. Keep false unless the bind address is LAN/VPN-only.";
    };

    allowedNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "127.0.0.0/8"
        "10.224.10.0/24"
        "10.224.20.0/24"
        "10.8.0.0/24"
        "100.64.0.0/10"
      ];
      description = "Trusted networks allowed to relay mail through this SMTP service.";
    };

    senderAddress = lib.mkOption {
      type = lib.types.str;
      default = "alerts@example.invalid";
      description = "Canonical sender address used for infrastructure notifications.";
    };

    rewriteSender = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Rewrite root and local-domain senders to senderAddress for Gmail compatibility.";
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
        description = "Runtime path to the Gmail app password secret file. Do not commit this secret.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (network: !(builtins.elem network dangerousNetworks)) cfg.allowedNetworks;
        message = "personalInfra.services.smtp.allowedNetworks must not include a default route; that would create an open relay risk.";
      }
      {
        assertion = !(lib.hasPrefix "/nix/store/" (toString cfg.gmail.passwordFile));
        message = "personalInfra.services.smtp.gmail.passwordFile must be a runtime secret path outside the Nix store.";
      }
      {
        assertion =
          !(
            cfg.openFirewall
            && builtins.elem cfg.bindAddress [
              "all"
              "0.0.0.0"
              "::"
            ]
          );
        message = "personalInfra.services.smtp.openFirewall requires a concrete LAN/VPN bindAddress, not a public wildcard listener.";
      }
    ];

    services.postfix = {
      enable = true;
      enableSmtp = false;
      enableSubmission = false;
      settings.main = {
        myhostname = cfg.hostname;
        mydomain = cfg.domain;
        myorigin = cfg.domain;
        mynetworks = cfg.allowedNetworks;
        mynetworks_style = "host";
        mydestination = [
          "$myhostname"
          "localhost.$mydomain"
          "localhost"
        ];
        inet_interfaces = cfg.bindAddress;
        relayhost = [ relayHost ];
        relay_domains = [ ];
        smtp_sasl_auth_enable = true;
        smtp_sasl_password_maps = [ "hash:/etc/postfix/sasl_passwd" ];
        smtp_sasl_security_options = "noanonymous";
        smtp_sasl_tls_security_options = "noanonymous";
        smtp_tls_security_level = "encrypt";
        smtp_tls_CAfile = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        smtpd_client_restrictions = [
          "permit_mynetworks"
          "reject"
        ];
        smtpd_relay_restrictions = [
          "permit_mynetworks"
          "reject_unauth_destination"
        ];
        smtpd_recipient_restrictions = [
          "permit_mynetworks"
          "reject_unauth_destination"
        ];
        smtp_generic_maps = lib.mkIf cfg.rewriteSender [ "regexp:/etc/postfix/generic" ];
      };
      settings.master."${toString cfg.port}" = {
        type = "inet";
        private = false;
        privileged = false;
        chroot = false;
        command = "smtpd";
        args = customSmtpdArgs;
      };
    };

    systemd.services.postfix-setup.script = lib.mkAfter ''
      if [ ! -r '${toString cfg.gmail.passwordFile}' ]; then
        echo 'Missing Gmail SMTP app-password secret: ${toString cfg.gmail.passwordFile}' >&2
        exit 1
      fi

      umask 077
      password="$(${pkgs.coreutils}/bin/cat '${toString cfg.gmail.passwordFile}')"
      ${pkgs.coreutils}/bin/printf '%s %s:%s\n' '${relayHost}' '${cfg.gmail.username}' "$password" > /var/lib/postfix/conf/sasl_passwd
      ${lib.getExe' postfixPackage "postmap"} /var/lib/postfix/conf/sasl_passwd
      ${pkgs.coreutils}/bin/chown root:root /var/lib/postfix/conf/sasl_passwd /var/lib/postfix/conf/sasl_passwd.db
      ${pkgs.coreutils}/bin/chmod 0600 /var/lib/postfix/conf/sasl_passwd /var/lib/postfix/conf/sasl_passwd.db

      ${lib.optionalString cfg.rewriteSender ''
        ${pkgs.coreutils}/bin/cat > /var/lib/postfix/conf/generic <<'EOF'
        /^(.+)@${cfg.domain}$/ ${cfg.senderAddress}
        /^root@.+$/ ${cfg.senderAddress}
        EOF
        ${pkgs.coreutils}/bin/chown root:root /var/lib/postfix/conf/generic
        ${pkgs.coreutils}/bin/chmod 0644 /var/lib/postfix/conf/generic
      ''}
    '';

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
