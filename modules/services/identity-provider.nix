{ config, lib, ... }:

let
  cfg = config.personalInfra.services.identityProvider;
in
{
  options.personalInfra.services.identityProvider = {
    enable = lib.mkEnableOption "central LLDAP and Authelia identity provider";

    baseDn = lib.mkOption {
      type = lib.types.str;
      default = "dc=infra,dc=theau,dc=local";
      description = "LDAP base DN for personal infrastructure users.";
    };

    publicUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://auth.theau-vps.duckdns.org";
      description = "Public SSO URL exposed through IONOS-VPS2.";
    };

    lldapAdminUser = lib.mkOption {
      type = lib.types.str;
      default = "theau";
      description = "Initial LLDAP super-admin username.";
    };

    lldapAdminEmail = lib.mkOption {
      type = lib.types.str;
      default = "theau@example.invalid";
      description = "Initial LLDAP super-admin email placeholder.";
    };

    lldapAdminPasswordFile = lib.mkOption {
      type = lib.types.path;
      default = "/run/secrets/lldap-admin-password";
      description = "Path to the initial LLDAP admin password file.";
    };

    autheliaInstance = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Authelia instance name.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.lldap = {
      enable = lib.mkDefault true;
      settings = {
        http_host = "127.0.0.1";
        http_port = 17170;
        ldap_host = "127.0.0.1";
        ldap_port = 3890;
        http_url = cfg.publicUrl;
        ldap_base_dn = cfg.baseDn;
        ldap_user_dn = cfg.lldapAdminUser;
        ldap_user_email = cfg.lldapAdminEmail;
        ldap_user_pass_file = cfg.lldapAdminPasswordFile;
      };
      silenceForceUserPassResetWarning = lib.mkDefault true;
    };

    services.authelia.instances.${cfg.autheliaInstance} = {
      enable = lib.mkDefault true;
      settings = {
        theme = lib.mkDefault "dark";
        default_2fa_method = lib.mkDefault "totp";
        server.address = lib.mkDefault "tcp://127.0.0.1:9091";
        authentication_backend.ldap = {
          address = "ldap://127.0.0.1:3890";
          base_dn = cfg.baseDn;
          additional_users_dn = "ou=people";
          users_filter = "(&({username_attribute}={input})(objectClass=person))";
          additional_groups_dn = "ou=groups";
          groups_filter = "(member={dn})";
          user = "uid=${cfg.lldapAdminUser},ou=people,${cfg.baseDn}";
          attributes = {
            username = "uid";
            display_name = "displayName";
            mail = "mail";
            group_name = "cn";
          };
        };
        access_control = {
          default_policy = "deny";
          rules = [
            {
              domain = "*.theau-vps.duckdns.org";
              policy = "one_factor";
            }
            {
              domain = "users.theau-vps.duckdns.org";
              policy = "one_factor";
              subject = [ "group:super-admin" ];
            }
          ];
        };
      };
    };

    # TODO: provide Authelia storage/session/JWT/OIDC secrets via SOPS-backed
    # files before enabling this module on a live host.
    # TODO: expose LLDAP's web UI only behind the VPS reverse proxy and only to
    # users in the `super-admin` group.
  };
}
