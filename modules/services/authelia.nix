{ config, lib, ... }:

let
  cfg = config.personalInfra.services.authelia;

  mkRule =
    host: service:
    {
      domain = host;
      policy = service.policy;
    }
    // lib.optionalAttrs (service.groups != [ ]) {
      subject = map (group: "group:${group}") service.groups;
    };
in
{
  options.personalInfra.services.authelia = {
    enable = lib.mkEnableOption "central Authelia SSO and service authorization";

    instanceName = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Authelia instance name.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "tcp://127.0.0.1:9091";
      description = "Authelia local listen address.";
    };

    baseDn = lib.mkOption {
      type = lib.types.str;
      default = "dc=infra,dc=theau,dc=local";
      description = "LDAP base DN.";
    };

    ldapUrl = lib.mkOption {
      type = lib.types.str;
      default = "ldap://127.0.0.1:3890";
      description = "LDAP URL used by Authelia.";
    };

    ldapUser = lib.mkOption {
      type = lib.types.str;
      default = "uid=theau,ou=people,dc=infra,dc=theau,dc=local";
      description = "LDAP bind user placeholder.";
    };

    secrets = {
      jwtSecretFile = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/authelia-jwt-secret";
        description = "Runtime path for the Authelia JWT secret.";
      };

      storageEncryptionKeyFile = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/authelia-storage-encryption-key";
        description = "Runtime path for the Authelia storage encryption key.";
      };

      ldapPasswordFile = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/authelia-ldap-password";
        description = "Runtime path for the LDAP bind password.";
      };
    };

    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            policy = lib.mkOption {
              type = lib.types.enum [
                "one_factor"
                "two_factor"
              ];
              default = "one_factor";
              description = "Authelia policy required for this service.";
            };

            groups = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "LDAP groups allowed to access this service. Empty means any authenticated user.";
            };
          };
        }
      );
      default = {
        "users.theau-vps.duckdns.org" = {
          groups = [ "super-admin" ];
        };
        "jellyfin.theau-vps.duckdns.org" = { };
        "jellyseerr.theau-vps.duckdns.org" = { };
        "seedbox.theau-vps.duckdns.org" = {
          groups = [ "super-admin" ];
        };
      };
      description = "Central service authorization matrix enforced by Authelia.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.authelia.instances.${cfg.instanceName} = {
      enable = lib.mkDefault true;
      secrets = {
        jwtSecretFile = cfg.secrets.jwtSecretFile;
        storageEncryptionKeyFile = cfg.secrets.storageEncryptionKeyFile;
      };
      environmentVariables.AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = toString cfg.secrets.ldapPasswordFile;
      settings = {
        theme = lib.mkDefault "dark";
        default_2fa_method = lib.mkDefault "totp";
        server.address = cfg.listenAddress;
        authentication_backend.ldap = {
          address = cfg.ldapUrl;
          base_dn = cfg.baseDn;
          additional_users_dn = "ou=people";
          additional_groups_dn = "ou=groups";
          user = cfg.ldapUser;
          users_filter = "(&({username_attribute}={input})(objectClass=person))";
          groups_filter = "(member={dn})";
          attributes = {
            username = "uid";
            display_name = "displayName";
            mail = "mail";
            group_name = "cn";
          };
        };
        access_control = {
          default_policy = "deny";
          rules = lib.mapAttrsToList mkRule cfg.services;
        };
      };
    };

    # The secret paths above are runtime paths. Populate them through SOPS or
    # another secret manager before switching this host.
  };
}
